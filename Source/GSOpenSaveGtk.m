#import "GSOpenSaveGtk.h"
#import <GNUstepGUI/GSDisplayServer.h>

#include <stdint.h>
#include <string.h>

@interface NSOpenPanel (GSOpenSaveState)
- (void)setFilenames:(NSArray *)filenames;
@end

@interface NSSavePanel (GSOpenSaveState)
- (void)setFilename:(NSString *)filename;
@end

#if defined(GS_OPENSAVE_HAVE_GTK4)
#include <gtk/gtk.h>

static BOOL gsGtkInitialized = NO;

static BOOL GSOpenSaveEnsureGtk(void)
{
  if (gsGtkInitialized) {
    return YES;
  }
  if (gtk_init_check() == FALSE) {
    return NO;
  }
  gsGtkInitialized = YES;
  return YES;
}

static BOOL GSOpenSaveTypeIsMimeType(NSString *type)
{
  if (![type isKindOfClass:[NSString class]]) {
    return NO;
  }
  if ([type length] == 0) {
    return NO;
  }
  return [type rangeOfString:@"/"].location != NSNotFound;
}

static NSString *GSOpenSavePatternForType(NSString *type)
{
  if (![type isKindOfClass:[NSString class]] || [type length] == 0) {
    return nil;
  }
  if ([type hasPrefix:@"."]) {
    return [NSString stringWithFormat:@"*%@", type];
  }
  if ([type rangeOfString:@"*"].location != NSNotFound ||
      [type rangeOfString:@"?"].location != NSNotFound) {
    return type;
  }
  if ([type rangeOfString:@"."].location == NSNotFound &&
      [type rangeOfString:@"/"].location == NSNotFound) {
    return [NSString stringWithFormat:@"*.%@", type];
  }
  return type;
}

static void GSOpenSaveFilterAddType(GtkFileFilter *filter, NSString *type)
{
  NSString *pattern = nil;

  if (GSOpenSaveTypeIsMimeType(type)) {
    gtk_file_filter_add_mime_type(filter, [type UTF8String]);
    return;
  }

  pattern = GSOpenSavePatternForType(type);
  if (pattern != nil) {
    gtk_file_filter_add_pattern(filter, [pattern UTF8String]);
  }
}

static GtkFileFilter *GSOpenSaveBuildFilter(NSArray *fileTypes, const char *name)
{
  if (fileTypes == nil || [fileTypes count] == 0) {
    return NULL;
  }

  GtkFileFilter *filter = gtk_file_filter_new();
  if (name != NULL) {
    gtk_file_filter_set_name(filter, name);
  }

  for (NSString *type in fileTypes) {
    GSOpenSaveFilterAddType(filter, type);
  }

  return filter;
}

static GListModel *GSOpenSaveBuildFilters(NSArray *fileTypes,
                                          NSString *requiredFileType,
                                          BOOL allowsOtherFileTypes,
                                          GtkFileFilter **outDefault)
{
  GListStore *store = g_list_store_new(GTK_TYPE_FILE_FILTER);
  GtkFileFilter *defaultFilter = NULL;

  GtkFileFilter *allowed = GSOpenSaveBuildFilter(fileTypes, "Allowed Types");
  if (allowed != NULL) {
    g_list_store_append(store, allowed);
    if (defaultFilter == NULL) {
      defaultFilter = allowed;
    }
    g_object_unref(allowed);
  }

  if (requiredFileType != nil && [requiredFileType length] > 0) {
    NSArray *required = [NSArray arrayWithObject:requiredFileType];
    GtkFileFilter *requiredFilter = GSOpenSaveBuildFilter(required, "Required Type");
    if (requiredFilter != NULL) {
      g_list_store_append(store, requiredFilter);
      defaultFilter = requiredFilter;
      g_object_unref(requiredFilter);
    }
  }

  if (allowsOtherFileTypes) {
    GtkFileFilter *allFiles = gtk_file_filter_new();
    gtk_file_filter_set_name(allFiles, "All Files");
    gtk_file_filter_add_pattern(allFiles, "*");
    g_list_store_append(store, allFiles);
    if (defaultFilter == NULL) {
      defaultFilter = allFiles;
    }
    g_object_unref(allFiles);
  }

  if (outDefault != NULL) {
    *outDefault = defaultFilter;
  }
  return G_LIST_MODEL(store);
}

typedef struct {
  GObject *result;
  GError *error;
  BOOL done;
} GSOpenSaveDialogResult;

typedef struct {
  guint response;
  GVariant *results;
  BOOL done;
} GSOpenSavePortalResponseState;

NSString *GSOpenSaveGtkParentWindowIdentifierForX11Handle(void *windowRef)
{
  uintptr_t xWindow = (uintptr_t)windowRef;

  if (xWindow == 0) {
    return nil;
  }
  return [NSString stringWithFormat:@"x11:%lx", (unsigned long)xWindow];
}

static NSString *GSOpenSaveGtkParentWindowIdentifierForWindow(NSWindow *window)
{
  GSDisplayServer *server = nil;
  NSString *serverClassName = nil;

  if (window == nil) {
    return nil;
  }

  server = GSServerForWindow(window);
  if (server == nil) {
    return nil;
  }

  serverClassName = NSStringFromClass([server class]);
  if ([serverClassName rangeOfString:@"XGServer"].location == NSNotFound) {
    return nil;
  }

  return GSOpenSaveGtkParentWindowIdentifierForX11Handle([window windowRef]);
}

static NSString *GSOpenSaveGtkPreferredParentWindowIdentifier(NSWindow *parentWindow)
{
  NSApplication *app = NSApp;
  NSString *identifier = nil;
  NSArray *orderedWindows = nil;

  identifier = GSOpenSaveGtkParentWindowIdentifierForWindow(parentWindow);
  if (identifier != nil) {
    return identifier;
  }

  if (app == nil) {
    return nil;
  }

  identifier = GSOpenSaveGtkParentWindowIdentifierForWindow([app keyWindow]);
  if (identifier != nil) {
    return identifier;
  }

  identifier = GSOpenSaveGtkParentWindowIdentifierForWindow([app mainWindow]);
  if (identifier != nil) {
    return identifier;
  }

  orderedWindows = [app orderedWindows];
  for (NSWindow *window in orderedWindows) {
    identifier = GSOpenSaveGtkParentWindowIdentifierForWindow(window);
    if (identifier != nil) {
      return identifier;
    }
  }

  return nil;
}

static GVariant *GSOpenSaveVariantForPath(NSString *path)
{
  const char *fileSystemPath = NULL;
  gsize length = 0;
  char *copy = NULL;

  if (path == nil || [path length] == 0) {
    return NULL;
  }

  fileSystemPath = [path fileSystemRepresentation];
  if (fileSystemPath == NULL) {
    return NULL;
  }

  length = strlen(fileSystemPath) + 1;
  copy = g_malloc(length);
  memcpy(copy, fileSystemPath, length);
  return g_variant_new_from_data(G_VARIANT_TYPE("ay"), copy, length, TRUE, g_free, copy);
}

static GVariant *GSOpenSaveCreatePortalFilter(NSArray *fileTypes, NSString *name)
{
  GVariantBuilder entries;
  BOOL hasEntries = NO;

  if (fileTypes == nil || [fileTypes count] == 0) {
    return NULL;
  }

  g_variant_builder_init(&entries, G_VARIANT_TYPE("a(us)"));

  for (NSString *type in fileTypes) {
    NSString *pattern = nil;

    if (GSOpenSaveTypeIsMimeType(type)) {
      g_variant_builder_add(&entries, "(us)", 1, [type UTF8String]);
      hasEntries = YES;
      continue;
    }

    pattern = GSOpenSavePatternForType(type);
    if (pattern != nil) {
      g_variant_builder_add(&entries, "(us)", 0, [pattern UTF8String]);
      hasEntries = YES;
    }
  }

  if (!hasEntries) {
    return NULL;
  }

  return g_variant_new("(s@a(us))",
                       name != nil ? [name UTF8String] : "",
                       g_variant_builder_end(&entries));
}

static GVariant *GSOpenSaveBuildPortalFilters(NSArray *fileTypes,
                                              NSString *requiredFileType,
                                              BOOL allowsOtherFileTypes,
                                              GVariant **outDefaultFilter)
{
  GVariantBuilder filters;
  GVariant *defaultFilter = NULL;
  BOOL hasFilters = NO;
  GVariant *filter = NULL;

  g_variant_builder_init(&filters, G_VARIANT_TYPE("a(sa(us))"));

  filter = GSOpenSaveCreatePortalFilter(fileTypes, @"Allowed Types");
  if (filter != NULL) {
    g_variant_builder_add_value(&filters, filter);
    if (defaultFilter == NULL) {
      defaultFilter = GSOpenSaveCreatePortalFilter(fileTypes, @"Allowed Types");
    }
    hasFilters = YES;
  }

  if (requiredFileType != nil && [requiredFileType length] > 0) {
    NSArray *required = [NSArray arrayWithObject:requiredFileType];

    filter = GSOpenSaveCreatePortalFilter(required, @"Required Type");
    if (filter != NULL) {
      g_variant_builder_add_value(&filters, filter);
      defaultFilter = GSOpenSaveCreatePortalFilter(required, @"Required Type");
      hasFilters = YES;
    }
  }

  if (allowsOtherFileTypes) {
    filter = GSOpenSaveCreatePortalFilter([NSArray arrayWithObject:@"*"], @"All Files");
    if (filter != NULL) {
      g_variant_builder_add_value(&filters, filter);
      if (defaultFilter == NULL) {
        defaultFilter = GSOpenSaveCreatePortalFilter([NSArray arrayWithObject:@"*"], @"All Files");
      }
      hasFilters = YES;
    }
  }

  if (!hasFilters) {
    return NULL;
  }

  if (outDefaultFilter != NULL) {
    *outDefaultFilter = defaultFilter;
  }

  return g_variant_builder_end(&filters);
}

static NSString *GSOpenSavePortalHandleToken(void)
{
  NSString *uuid = [[[NSUUID UUID] UUIDString]
    stringByReplacingOccurrencesOfString:@"-"
                              withString:@""];
  return [NSString stringWithFormat:@"gsopensave_%@", [uuid lowercaseString]];
}

static NSArray *GSOpenSaveBeginAppModalWindowBlock(void)
{
  NSApplication *app = NSApp;
  NSMutableArray *windowStates = [NSMutableArray array];

  if (app == nil) {
    return windowStates;
  }

  for (NSWindow *window in [app orderedWindows]) {
    if (window == nil) {
      continue;
    }
    [windowStates addObject:[NSDictionary dictionaryWithObjectsAndKeys:
                               window, @"window",
                               [NSNumber numberWithBool:[window ignoresMouseEvents]], @"ignoresMouseEvents",
                               nil]];
    [window setIgnoresMouseEvents:YES];
  }

  return windowStates;
}

static void GSOpenSaveEndAppModalWindowBlock(NSArray *windowStates)
{
  for (NSDictionary *entry in windowStates) {
    NSWindow *window = [entry objectForKey:@"window"];
    NSNumber *ignoresMouseEvents = [entry objectForKey:@"ignoresMouseEvents"];

    if (window == nil || ignoresMouseEvents == nil) {
      continue;
    }
    [window setIgnoresMouseEvents:[ignoresMouseEvents boolValue]];
  }
}

static BOOL GSOpenSaveShouldDispatchAppKitEvent(NSEvent *event)
{
  if (event == nil) {
    return NO;
  }

  switch ([event type]) {
    case NSLeftMouseDown:
    case NSLeftMouseUp:
    case NSRightMouseDown:
    case NSRightMouseUp:
    case NSMouseMoved:
    case NSLeftMouseDragged:
    case NSRightMouseDragged:
    case NSMouseEntered:
    case NSMouseExited:
    case NSKeyDown:
    case NSKeyUp:
    case NSFlagsChanged:
    case NSCursorUpdate:
    case NSScrollWheel:
    case NSOtherMouseDown:
    case NSOtherMouseUp:
    case NSOtherMouseDragged:
#if OS_API_VERSION(MAC_OS_X_VERSION_10_4, GS_API_LATEST)
    case NSTabletPoint:
    case NSTabletProximity:
#endif
      return NO;
    default:
      return YES;
  }
}

static void GSOpenSaveDialogDone(GObject *source, GAsyncResult *res, gpointer userData)
{
  (void)source;
  GSOpenSaveDialogResult *result = (GSOpenSaveDialogResult *)userData;
  result->result = g_object_ref(G_OBJECT(res));
  result->done = YES;
}

static void GSOpenSavePortalResponse(GDBusConnection *connection,
                                     const gchar *senderName,
                                     const gchar *objectPath,
                                     const gchar *interfaceName,
                                     const gchar *signalName,
                                     GVariant *parameters,
                                     gpointer userData)
{
  GSOpenSavePortalResponseState *state = (GSOpenSavePortalResponseState *)userData;

  (void)connection;
  (void)senderName;
  (void)objectPath;
  (void)interfaceName;
  (void)signalName;

  if (state == NULL || state->done) {
    return;
  }

  g_variant_get(parameters, "(u@a{sv})", &state->response, &state->results);
  state->done = YES;
}

static void GSOpenSaveSpinMainLoops(BOOL *done)
{
  NSArray *windowStates = GSOpenSaveBeginAppModalWindowBlock();
  NSApplication *app = NSApp;

  @try {
    while (done != NULL && !*done) {
      NSEvent *event = nil;

      while (g_main_context_iteration(NULL, FALSE)) {
      }

      if (app == nil) {
        [NSThread sleepForTimeInterval:0.01];
        continue;
      }

      event = [app nextEventMatchingMask:NSAnyEventMask
                               untilDate:[NSDate dateWithTimeIntervalSinceNow:0.01]
                                  inMode:NSDefaultRunLoopMode
                                 dequeue:YES];
      while (event != nil) {
        if (GSOpenSaveShouldDispatchAppKitEvent(event)) {
          [app sendEvent:event];
        }
        event = [app nextEventMatchingMask:NSAnyEventMask
                                 untilDate:[NSDate distantPast]
                                    inMode:NSDefaultRunLoopMode
                                   dequeue:YES];
      }
    }
  }
  @finally {
    GSOpenSaveEndAppModalWindowBlock(windowStates);
  }
}

static void GSOpenSaveCollectPortalFilenames(GVariant *results,
                                             NSMutableArray **outFilenames)
{
  GVariant *uris = NULL;
  GVariantIter iter;
  const gchar *uri = NULL;

  if (results == NULL || outFilenames == NULL) {
    return;
  }

  uris = g_variant_lookup_value(results, "uris", G_VARIANT_TYPE("as"));
  if (uris == NULL) {
    return;
  }

  *outFilenames = [NSMutableArray array];
  g_variant_iter_init(&iter, uris);
  while (g_variant_iter_next(&iter, "&s", &uri)) {
    GFile *file = g_file_new_for_uri(uri);
    char *path = g_file_get_path(file);

    if (path != NULL) {
      [*outFilenames addObject:[NSString stringWithUTF8String:path]];
      g_free(path);
    }
    g_object_unref(file);
  }

  if ([*outFilenames count] == 0) {
    *outFilenames = nil;
  }

  g_variant_unref(uris);
}

static BOOL GSOpenSaveRunPortalRequest(const char *method,
                                       NSString *parentWindowIdentifier,
                                       NSString *title,
                                       GVariant *options,
                                       NSMutableArray **outFilenames,
                                       NSInteger *outResult)
{
  GDBusConnection *connection = NULL;
  GVariant *reply = NULL;
  GError *error = NULL;
  const gchar *requestPath = NULL;
  guint subscription = 0;
  GSOpenSavePortalResponseState state = {0};
  BOOL didHandleRequest = NO;

  if (parentWindowIdentifier == nil || [parentWindowIdentifier length] == 0) {
    return NO;
  }

  connection = g_bus_get_sync(G_BUS_TYPE_SESSION, NULL, &error);
  if (connection == NULL) {
    if (error != NULL) {
      g_error_free(error);
    }
    return NO;
  }

  reply = g_dbus_connection_call_sync(connection,
                                      "org.freedesktop.portal.Desktop",
                                      "/org/freedesktop/portal/desktop",
                                      "org.freedesktop.portal.FileChooser",
                                      method,
                                      g_variant_new("(ss@a{sv})",
                                                    [parentWindowIdentifier UTF8String],
                                                    title != nil ? [title UTF8String] : "",
                                                    options),
                                      G_VARIANT_TYPE("(o)"),
                                      G_DBUS_CALL_FLAGS_NONE,
                                      -1,
                                      NULL,
                                      &error);
  if (reply == NULL) {
    if (error != NULL) {
      g_error_free(error);
    }
    g_object_unref(connection);
    return NO;
  }

  g_variant_get(reply, "(&o)", &requestPath);
  if (requestPath == NULL || requestPath[0] == '\0') {
    g_variant_unref(reply);
    g_object_unref(connection);
    return NO;
  }

  subscription = g_dbus_connection_signal_subscribe(connection,
                                                    "org.freedesktop.portal.Desktop",
                                                    "org.freedesktop.portal.Request",
                                                    "Response",
                                                    requestPath,
                                                    NULL,
                                                    G_DBUS_SIGNAL_FLAGS_NONE,
                                                    GSOpenSavePortalResponse,
                                                    &state,
                                                    NULL);

  GSOpenSaveSpinMainLoops(&state.done);
  didHandleRequest = YES;

  if (subscription != 0) {
    g_dbus_connection_signal_unsubscribe(connection, subscription);
  }

  if (outResult != NULL) {
    *outResult = NSFileHandlingPanelCancelButton;
  }
  if (state.response == 0) {
    GSOpenSaveCollectPortalFilenames(state.results, outFilenames);
    if (outResult != NULL &&
        outFilenames != NULL &&
        *outFilenames != nil &&
        [*outFilenames count] > 0) {
      *outResult = NSFileHandlingPanelOKButton;
    }
  }

  if (state.results != NULL) {
    g_variant_unref(state.results);
  }
  g_variant_unref(reply);
  g_object_unref(connection);
  return didHandleRequest;
}

static NSInteger GSOpenSaveRunDialogOpen(GtkFileDialog *dialog,
                                         BOOL allowMultiple,
                                         NSMutableArray **outFilenames)
{
  if (GSOpenSaveEnsureGtk() == NO) {
    return NSFileHandlingPanelCancelButton;
  }

  GSOpenSaveDialogResult state = {0};

  if (allowMultiple) {
    gtk_file_dialog_open_multiple(dialog, NULL, NULL, GSOpenSaveDialogDone, &state);
  } else {
    gtk_file_dialog_open(dialog, NULL, NULL, GSOpenSaveDialogDone, &state);
  }

  GSOpenSaveSpinMainLoops(&state.done);

  NSInteger resultCode = NSFileHandlingPanelCancelButton;
  if (state.result != NULL) {
    if (allowMultiple) {
      GListModel *model = gtk_file_dialog_open_multiple_finish(dialog, G_ASYNC_RESULT(state.result), &state.error);
      if (model != NULL) {
        if (outFilenames != NULL) {
          *outFilenames = [NSMutableArray array];
          guint n = g_list_model_get_n_items(model);
          for (guint i = 0; i < n; i++) {
            GFile *file = g_list_model_get_item(model, i);
            char *path = g_file_get_path(file);
            if (path != NULL) {
              [*outFilenames addObject:[NSString stringWithUTF8String:path]];
              g_free(path);
            }
            g_object_unref(file);
          }
        }
        g_object_unref(model);
        resultCode = NSFileHandlingPanelOKButton;
      }
    } else {
      GFile *file = gtk_file_dialog_open_finish(dialog, G_ASYNC_RESULT(state.result), &state.error);
      if (file != NULL) {
        if (outFilenames != NULL) {
          *outFilenames = [NSMutableArray array];
          char *path = g_file_get_path(file);
          if (path != NULL) {
            [*outFilenames addObject:[NSString stringWithUTF8String:path]];
            g_free(path);
          }
        }
        g_object_unref(file);
        resultCode = NSFileHandlingPanelOKButton;
      }
    }
    g_object_unref(state.result);
  }

  if (state.error != NULL) {
    g_error_free(state.error);
  }
  return resultCode;
}

static NSInteger GSOpenSaveRunDialogSelectFolder(GtkFileDialog *dialog,
                                                 NSMutableArray **outFilenames)
{
  if (GSOpenSaveEnsureGtk() == NO) {
    return NSFileHandlingPanelCancelButton;
  }

  GSOpenSaveDialogResult state = {0};
  gtk_file_dialog_select_folder(dialog, NULL, NULL, GSOpenSaveDialogDone, &state);
  GSOpenSaveSpinMainLoops(&state.done);

  NSInteger resultCode = NSFileHandlingPanelCancelButton;
  if (state.result != NULL) {
    GFile *file = gtk_file_dialog_select_folder_finish(dialog, G_ASYNC_RESULT(state.result), &state.error);
    if (file != NULL) {
      if (outFilenames != NULL) {
        *outFilenames = [NSMutableArray array];
        char *path = g_file_get_path(file);
        if (path != NULL) {
          [*outFilenames addObject:[NSString stringWithUTF8String:path]];
          g_free(path);
        }
      }
      g_object_unref(file);
      resultCode = NSFileHandlingPanelOKButton;
    }
    g_object_unref(state.result);
  }

  if (state.error != NULL) {
    g_error_free(state.error);
  }
  return resultCode;
}

static NSInteger GSOpenSaveRunDialogSelectMultipleFolders(GtkFileDialog *dialog,
                                                          NSMutableArray **outFilenames)
{
  if (GSOpenSaveEnsureGtk() == NO) {
    return NSFileHandlingPanelCancelButton;
  }

  GSOpenSaveDialogResult state = {0};
  gtk_file_dialog_select_multiple_folders(dialog, NULL, NULL, GSOpenSaveDialogDone, &state);
  GSOpenSaveSpinMainLoops(&state.done);

  NSInteger resultCode = NSFileHandlingPanelCancelButton;
  if (state.result != NULL) {
    GListModel *model = gtk_file_dialog_select_multiple_folders_finish(dialog, G_ASYNC_RESULT(state.result), &state.error);
    if (model != NULL) {
      if (outFilenames != NULL) {
        *outFilenames = [NSMutableArray array];
        guint n = g_list_model_get_n_items(model);
        for (guint i = 0; i < n; i++) {
          GFile *file = g_list_model_get_item(model, i);
          char *path = g_file_get_path(file);
          if (path != NULL) {
            [*outFilenames addObject:[NSString stringWithUTF8String:path]];
            g_free(path);
          }
          g_object_unref(file);
        }
      }
      g_object_unref(model);
      resultCode = NSFileHandlingPanelOKButton;
    }
    g_object_unref(state.result);
  }

  if (state.error != NULL) {
    g_error_free(state.error);
  }
  return resultCode;
}

static NSInteger GSOpenSaveRunDialogSave(GtkFileDialog *dialog,
                                         NSMutableArray **outFilenames)
{
  if (GSOpenSaveEnsureGtk() == NO) {
    return NSFileHandlingPanelCancelButton;
  }

  GSOpenSaveDialogResult state = {0};
  gtk_file_dialog_save(dialog, NULL, NULL, GSOpenSaveDialogDone, &state);
  GSOpenSaveSpinMainLoops(&state.done);

  NSInteger resultCode = NSFileHandlingPanelCancelButton;
  if (state.result != NULL) {
    GFile *file = gtk_file_dialog_save_finish(dialog, G_ASYNC_RESULT(state.result), &state.error);
    if (file != NULL) {
      if (outFilenames != NULL) {
        *outFilenames = [NSMutableArray array];
        char *path = g_file_get_path(file);
        if (path != NULL) {
          [*outFilenames addObject:[NSString stringWithUTF8String:path]];
          g_free(path);
        }
      }
      g_object_unref(file);
      resultCode = NSFileHandlingPanelOKButton;
    }
    g_object_unref(state.result);
  }

  if (state.error != NULL) {
    g_error_free(state.error);
  }
  return resultCode;
}

static BOOL GSOpenSaveTryPortalOpenPanel(NSOpenPanel *panel,
                                         NSString *directory,
                                         NSString *filename,
                                         NSArray *fileTypes,
                                         NSWindow *parentWindow,
                                         NSMutableArray **outFilenames,
                                         NSInteger *outResult)
{
  NSString *parentWindowIdentifier = GSOpenSaveGtkPreferredParentWindowIdentifier(parentWindow);
  NSString *title = [panel title];
  NSString *prompt = [panel prompt];
  NSString *handleToken = nil;
  GVariantBuilder options;
  GVariant *filters = NULL;
  GVariant *defaultFilter = NULL;
  GVariant *currentFolder = NULL;

  (void)filename;

  if (parentWindowIdentifier == nil) {
    return NO;
  }

  handleToken = GSOpenSavePortalHandleToken();
  g_variant_builder_init(&options, G_VARIANT_TYPE_VARDICT);
  g_variant_builder_add(&options, "{sv}", "handle_token",
                        g_variant_new_string([handleToken UTF8String]));
  g_variant_builder_add(&options, "{sv}", "modal", g_variant_new_boolean(TRUE));
  if ([panel allowsMultipleSelection]) {
    g_variant_builder_add(&options, "{sv}", "multiple", g_variant_new_boolean(TRUE));
  }
  if ([panel canChooseDirectories] && ![panel canChooseFiles]) {
    g_variant_builder_add(&options, "{sv}", "directory", g_variant_new_boolean(TRUE));
  }
  if (prompt != nil && [prompt length] > 0) {
    g_variant_builder_add(&options, "{sv}", "accept_label",
                          g_variant_new_string([prompt UTF8String]));
  }

  currentFolder = GSOpenSaveVariantForPath(directory);
  if (currentFolder != NULL) {
    g_variant_builder_add(&options, "{sv}", "current_folder", currentFolder);
  }

  filters = GSOpenSaveBuildPortalFilters(fileTypes, nil, NO, &defaultFilter);
  if (filters != NULL) {
    g_variant_builder_add(&options, "{sv}", "filters", filters);
    if (defaultFilter != NULL) {
      g_variant_builder_add(&options, "{sv}", "current_filter", defaultFilter);
    }
  }

  return GSOpenSaveRunPortalRequest("OpenFile",
                                    parentWindowIdentifier,
                                    title,
                                    g_variant_builder_end(&options),
                                    outFilenames,
                                    outResult);
}

static BOOL GSOpenSaveTryPortalSavePanel(NSSavePanel *panel,
                                         NSString *directory,
                                         NSString *filename,
                                         NSArray *fileTypes,
                                         NSWindow *parentWindow,
                                         NSMutableArray **outFilenames,
                                         NSInteger *outResult)
{
  NSString *parentWindowIdentifier = GSOpenSaveGtkPreferredParentWindowIdentifier(parentWindow);
  NSString *title = [panel title];
  NSString *defaultName = filename;
  NSString *handleToken = nil;
  GVariantBuilder options;
  GVariant *filters = NULL;
  GVariant *defaultFilter = NULL;
  GVariant *currentFolder = NULL;
  GVariant *currentFile = NULL;

  if (parentWindowIdentifier == nil) {
    return NO;
  }

  if (title == nil || [title length] == 0) {
    title = [panel message];
  }
  if (directory == nil || [directory length] == 0) {
    directory = [panel directory];
  }
  if (defaultName == nil || [defaultName length] == 0) {
    defaultName = [panel nameFieldStringValue];
  }
  if ([defaultName isAbsolutePath]) {
    if (directory == nil || [directory length] == 0) {
      directory = [defaultName stringByDeletingLastPathComponent];
    }
    currentFile = GSOpenSaveVariantForPath(defaultName);
    defaultName = [defaultName lastPathComponent];
  }

  handleToken = GSOpenSavePortalHandleToken();
  g_variant_builder_init(&options, G_VARIANT_TYPE_VARDICT);
  g_variant_builder_add(&options, "{sv}", "handle_token",
                        g_variant_new_string([handleToken UTF8String]));
  g_variant_builder_add(&options, "{sv}", "modal", g_variant_new_boolean(TRUE));
  if ([panel prompt] != nil && [[panel prompt] length] > 0) {
    g_variant_builder_add(&options, "{sv}", "accept_label",
                          g_variant_new_string([[panel prompt] UTF8String]));
  }

  currentFolder = GSOpenSaveVariantForPath(directory);
  if (currentFolder != NULL) {
    g_variant_builder_add(&options, "{sv}", "current_folder", currentFolder);
  }
  if (currentFile != NULL) {
    g_variant_builder_add(&options, "{sv}", "current_file", currentFile);
  } else if (defaultName != nil && [defaultName length] > 0) {
    g_variant_builder_add(&options, "{sv}", "current_name",
                          g_variant_new_string([defaultName UTF8String]));
  }

  filters = GSOpenSaveBuildPortalFilters(fileTypes,
                                         [panel requiredFileType],
                                         [panel allowsOtherFileTypes],
                                         &defaultFilter);
  if (filters != NULL) {
    g_variant_builder_add(&options, "{sv}", "filters", filters);
    if (defaultFilter != NULL) {
      g_variant_builder_add(&options, "{sv}", "current_filter", defaultFilter);
    }
  }

  return GSOpenSaveRunPortalRequest("SaveFile",
                                    parentWindowIdentifier,
                                    title,
                                    g_variant_builder_end(&options),
                                    outFilenames,
                                    outResult);
}

BOOL GSOpenSaveGtkIsAvailable(void)
{
  return GSOpenSaveEnsureGtk();
}

NSInteger GSOpenSaveGtkRunOpenPanel(NSOpenPanel *panel,
                                    NSString *directory,
                                    NSString *filename,
                                    NSArray *fileTypes,
                                    NSWindow *parentWindow)
{
  NSMutableArray *filenames = nil;
  NSInteger result = NSFileHandlingPanelCancelButton;

  if (GSOpenSaveEnsureGtk() == NO) {
    return NSFileHandlingPanelCancelButton;
  }
  if (directory == nil) {
    NSURL *dirURL = [panel directoryURL];
    if (dirURL != nil) {
      directory = [dirURL path];
    } else {
      directory = [panel directory];
    }
  }

  if (GSOpenSaveTryPortalOpenPanel(panel,
                                   directory,
                                   filename,
                                   fileTypes,
                                   parentWindow,
                                   &filenames,
                                   &result)) {
    if (result == NSFileHandlingPanelOKButton) {
      [panel setFilenames:filenames];
    }
    return result;
  }

  GtkFileDialog *dialog = gtk_file_dialog_new();
  gtk_file_dialog_set_modal(dialog, TRUE);
  NSString *title = [panel title];
  if (title != nil) {
    gtk_file_dialog_set_title(dialog, [title UTF8String]);
  }
  if (directory != nil) {
    GFile *folder = g_file_new_for_path([directory UTF8String]);
    gtk_file_dialog_set_initial_folder(dialog, folder);
    g_object_unref(folder);
  }
  if (filename != nil) {
    gtk_file_dialog_set_initial_name(dialog, [filename UTF8String]);
  }
  GtkFileFilter *defaultFilter = NULL;
  GListModel *filters = GSOpenSaveBuildFilters(fileTypes, nil, NO, &defaultFilter);
  if (filters != NULL) {
    gtk_file_dialog_set_filters(dialog, filters);
    if (defaultFilter != NULL) {
      gtk_file_dialog_set_default_filter(dialog, defaultFilter);
    }
    g_object_unref(filters);
  }

  if ([panel canChooseDirectories] && ![panel canChooseFiles]) {
    if ([panel allowsMultipleSelection]) {
      result = GSOpenSaveRunDialogSelectMultipleFolders(dialog, &filenames);
    } else {
      result = GSOpenSaveRunDialogSelectFolder(dialog, &filenames);
    }
  } else {
    result = GSOpenSaveRunDialogOpen(dialog, [panel allowsMultipleSelection], &filenames);
  }
  g_object_unref(dialog);
  if (result == NSFileHandlingPanelOKButton) {
    [panel setFilenames:filenames];
  }
  return result;
}

NSInteger GSOpenSaveGtkRunSavePanel(NSSavePanel *panel,
                                    NSString *directory,
                                    NSString *filename,
                                    NSArray *fileTypes,
                                    NSWindow *parentWindow)
{
  NSMutableArray *filenames = nil;
  NSInteger result = NSFileHandlingPanelCancelButton;

  if (GSOpenSaveEnsureGtk() == NO) {
    return NSFileHandlingPanelCancelButton;
  }

  if (GSOpenSaveTryPortalSavePanel(panel,
                                   directory,
                                   filename,
                                   fileTypes,
                                   parentWindow,
                                   &filenames,
                                   &result)) {
    if (result == NSFileHandlingPanelOKButton && [filenames count] > 0) {
      [panel setFilename:[filenames objectAtIndex:0]];
    }
    return result;
  }

  GtkFileDialog *dialog = gtk_file_dialog_new();
  gtk_file_dialog_set_modal(dialog, TRUE);
  NSString *title = [panel title];
  if (title == nil || [title length] == 0) {
    title = [panel message];
  }
  if (title != nil) {
    gtk_file_dialog_set_title(dialog, [title UTF8String]);
  }
  if (directory != nil) {
    GFile *folder = g_file_new_for_path([directory UTF8String]);
    gtk_file_dialog_set_initial_folder(dialog, folder);
    g_object_unref(folder);
  }
  if ([panel prompt] != nil) {
    gtk_file_dialog_set_accept_label(dialog, [[panel prompt] UTF8String]);
  }

  NSString *defaultName = filename;
  if (defaultName == nil || [defaultName length] == 0) {
    defaultName = [panel nameFieldStringValue];
  }
  if (defaultName != nil) {
    gtk_file_dialog_set_initial_name(dialog, [defaultName UTF8String]);
  }
  GtkFileFilter *defaultFilter = NULL;
  GListModel *filters = GSOpenSaveBuildFilters(fileTypes,
                                               [panel requiredFileType],
                                               [panel allowsOtherFileTypes],
                                               &defaultFilter);
  if (filters != NULL) {
    gtk_file_dialog_set_filters(dialog, filters);
    if (defaultFilter != NULL) {
      gtk_file_dialog_set_default_filter(dialog, defaultFilter);
    }
    g_object_unref(filters);
  }

  result = GSOpenSaveRunDialogSave(dialog, &filenames);
  g_object_unref(dialog);
  if (result == NSFileHandlingPanelOKButton && [filenames count] > 0) {
    [panel setFilename:[filenames objectAtIndex:0]];
  }
  return result;
}

#else

BOOL GSOpenSaveGtkIsAvailable(void)
{
  return NO;
}

NSInteger GSOpenSaveGtkRunOpenPanel(NSOpenPanel *panel,
                                    NSString *directory,
                                    NSString *filename,
                                    NSArray *fileTypes,
                                    NSWindow *parentWindow)
{
  (void)panel;
  (void)directory;
  (void)filename;
  (void)fileTypes;
  (void)parentWindow;
  return NSFileHandlingPanelCancelButton;
}

NSInteger GSOpenSaveGtkRunSavePanel(NSSavePanel *panel,
                                    NSString *directory,
                                    NSString *filename,
                                    NSArray *fileTypes,
                                    NSWindow *parentWindow)
{
  (void)panel;
  (void)directory;
  (void)filename;
  (void)fileTypes;
  (void)parentWindow;
  return NSFileHandlingPanelCancelButton;
}

NSString *GSOpenSaveGtkParentWindowIdentifierForX11Handle(void *windowRef)
{
  (void)windowRef;
  return nil;
}

#endif
