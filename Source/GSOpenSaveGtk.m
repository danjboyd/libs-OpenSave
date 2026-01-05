#import "GSOpenSaveGtk.h"

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

static void GSOpenSaveFilterAddPattern(GtkFileFilter *filter, NSString *type)
{
  if (![type isKindOfClass:[NSString class]]) {
    return;
  }
  if ([type length] == 0) {
    return;
  }
  if ([type hasPrefix:@"."]) {
    NSString *pattern = [NSString stringWithFormat:@"*%@", type];
    gtk_file_filter_add_pattern(filter, [pattern UTF8String]);
  } else if ([type rangeOfString:@"."].location == NSNotFound) {
    NSString *pattern = [NSString stringWithFormat:@"*.%@", type];
    gtk_file_filter_add_pattern(filter, [pattern UTF8String]);
  } else {
    gtk_file_filter_add_pattern(filter, [type UTF8String]);
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
    GSOpenSaveFilterAddPattern(filter, type);
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

static void GSOpenSaveDialogDone(GObject *source, GAsyncResult *res, gpointer userData)
{
  (void)source;
  GSOpenSaveDialogResult *result = (GSOpenSaveDialogResult *)userData;
  result->result = g_object_ref(G_OBJECT(res));
  result->done = YES;
}

static void GSOpenSaveSpinMainLoops(GSOpenSaveDialogResult *state)
{
  NSRunLoop *runLoop = [NSRunLoop currentRunLoop];
  while (!state->done) {
    g_main_context_iteration(NULL, FALSE);
    [runLoop runMode:NSDefaultRunLoopMode
          beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
  }
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

  GSOpenSaveSpinMainLoops(&state);

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
  GSOpenSaveSpinMainLoops(&state);

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
  GSOpenSaveSpinMainLoops(&state);

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
  GSOpenSaveSpinMainLoops(&state);

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

BOOL GSOpenSaveGtkIsAvailable(void)
{
  return GSOpenSaveEnsureGtk();
}

NSInteger GSOpenSaveGtkRunOpenPanel(NSOpenPanel *panel,
                                    NSString *directory,
                                    NSString *filename,
                                    NSArray *fileTypes)
{
  if (GSOpenSaveEnsureGtk() == NO) {
    return NSFileHandlingPanelCancelButton;
  }

  GtkFileDialog *dialog = gtk_file_dialog_new();
  NSString *title = [panel title];
  if (title != nil) {
    gtk_file_dialog_set_title(dialog, [title UTF8String]);
  }
  if (directory == nil) {
    NSURL *dirURL = [panel directoryURL];
    if (dirURL != nil) {
      directory = [dirURL path];
    } else {
      directory = [panel directory];
    }
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

  NSMutableArray *filenames = nil;
  NSInteger result = NSFileHandlingPanelCancelButton;
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
                                    NSArray *fileTypes)
{
  if (GSOpenSaveEnsureGtk() == NO) {
    return NSFileHandlingPanelCancelButton;
  }

  GtkFileDialog *dialog = gtk_file_dialog_new();
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

  NSMutableArray *filenames = nil;
  NSInteger result = GSOpenSaveRunDialogSave(dialog, &filenames);
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
                                    NSArray *fileTypes)
{
  (void)panel;
  (void)directory;
  (void)filename;
  (void)fileTypes;
  return NSFileHandlingPanelCancelButton;
}

NSInteger GSOpenSaveGtkRunSavePanel(NSSavePanel *panel,
                                    NSString *directory,
                                    NSString *filename,
                                    NSArray *fileTypes)
{
  (void)panel;
  (void)directory;
  (void)filename;
  (void)fileTypes;
  return NSFileHandlingPanelCancelButton;
}

#endif
