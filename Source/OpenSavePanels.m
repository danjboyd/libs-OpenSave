#import <AppKit/AppKit.h>
#import <objc/runtime.h>
#import "GSOpenSave.h"
#import "GSOpenSaveBackend.h"

static void GSOpenSaveSwizzle(Class cls, SEL original, SEL replacement, BOOL isClassMethod)
{
  Class targetClass = isClassMethod ? object_getClass((id)cls) : cls;
  Method originalMethod = NULL;
  Method replacementMethod = NULL;
  BOOL didAddOriginal = NO;

  originalMethod = class_getInstanceMethod(targetClass, original);
  replacementMethod = class_getInstanceMethod(targetClass, replacement);

  if (originalMethod == NULL || replacementMethod == NULL) {
    return;
  }

  /* Preserve superclass methods on subclasses such as NSOpenPanel.URL.
     A plain method_exchangeImplementations() would swap the inherited
     NSSavePanel method object twice and leave NSOpenPanel routed through the
     save-panel accessor path. */
  didAddOriginal = class_addMethod(targetClass,
                                   original,
                                   method_getImplementation(replacementMethod),
                                   method_getTypeEncoding(replacementMethod));
  if (didAddOriginal) {
    class_replaceMethod(targetClass,
                        replacement,
                        method_getImplementation(originalMethod),
                        method_getTypeEncoding(originalMethod));
    return;
  }

  method_exchangeImplementations(originalMethod, replacementMethod);
}

static BOOL GSOpenSaveShouldUseNativeBackend(void)
{
  return GSOpenSaveHasNativeBackend();
}

static const void *GSOpenSaveAllowedFileTypesKey = &GSOpenSaveAllowedFileTypesKey;
static const void *GSOpenSaveCanChooseDirectoriesKey = &GSOpenSaveCanChooseDirectoriesKey;
static const void *GSOpenSaveCanChooseFilesKey = &GSOpenSaveCanChooseFilesKey;
static const void *GSOpenSaveAllowsMultipleSelectionKey = &GSOpenSaveAllowsMultipleSelectionKey;
static const void *GSOpenSaveResolvesAliasesKey = &GSOpenSaveResolvesAliasesKey;
static const void *GSOpenSaveOpenURLsKey = &GSOpenSaveOpenURLsKey;
static const void *GSOpenSaveOpenFilenamesKey = &GSOpenSaveOpenFilenamesKey;

static const void *GSOpenSaveAccessoryViewKey = &GSOpenSaveAccessoryViewKey;
static const void *GSOpenSaveTitleKey = &GSOpenSaveTitleKey;
static const void *GSOpenSavePromptKey = &GSOpenSavePromptKey;
static const void *GSOpenSaveNameFieldValueKey = &GSOpenSaveNameFieldValueKey;
static const void *GSOpenSaveNameFieldLabelKey = &GSOpenSaveNameFieldLabelKey;
static const void *GSOpenSaveMessageKey = &GSOpenSaveMessageKey;
static const void *GSOpenSaveCanSelectHiddenExtensionKey = &GSOpenSaveCanSelectHiddenExtensionKey;
static const void *GSOpenSaveExtensionHiddenKey = &GSOpenSaveExtensionHiddenKey;
static const void *GSOpenSaveShowsHiddenFilesKey = &GSOpenSaveShowsHiddenFilesKey;
static const void *GSOpenSaveDirectoryKey = &GSOpenSaveDirectoryKey;
static const void *GSOpenSaveDirectoryURLKey = &GSOpenSaveDirectoryURLKey;
static const void *GSOpenSaveRequiredFileTypeKey = &GSOpenSaveRequiredFileTypeKey;
static const void *GSOpenSaveAllowsOtherFileTypesKey = &GSOpenSaveAllowsOtherFileTypesKey;
static const void *GSOpenSaveTreatsPackagesAsDirsKey = &GSOpenSaveTreatsPackagesAsDirsKey;
static const void *GSOpenSaveCanCreateDirectoriesKey = &GSOpenSaveCanCreateDirectoriesKey;
static const void *GSOpenSaveSaveFilenameKey = &GSOpenSaveSaveFilenameKey;

static void GSOpenSaveSetAssociatedObject(id obj, const void *key, id value)
{
  objc_setAssociatedObject(obj, key, value, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

static id GSOpenSaveGetAssociatedObject(id obj, const void *key)
{
  return objc_getAssociatedObject(obj, key);
}

static BOOL GSOpenSaveBoolForKey(id obj, const void *key, BOOL defaultValue)
{
  NSNumber *value = GSOpenSaveGetAssociatedObject(obj, key);
  return value != nil ? [value boolValue] : defaultValue;
}

static BOOL GSOpenSaveHasStoredOpenSelection(NSOpenPanel *panel)
{
  return (GSOpenSaveGetAssociatedObject(panel, GSOpenSaveOpenURLsKey) != nil ||
          GSOpenSaveGetAssociatedObject(panel, GSOpenSaveOpenFilenamesKey) != nil);
}

static BOOL GSOpenSaveHasStoredSaveSelection(NSSavePanel *panel)
{
  return GSOpenSaveGetAssociatedObject(panel, GSOpenSaveSaveFilenameKey) != nil;
}

@interface NSOpenPanel (GSOpenSaveState)
- (void)setFilenames:(NSArray *)filenames;
@end

@interface NSSavePanel (GSOpenSaveState)
- (void)setFilename:(NSString *)filename;
@end

@implementation NSOpenPanel (GSOpenSave)

+ (void)load
{
  GSOpenSaveSwizzle(self, @selector(openPanel), @selector(gs_openPanel), YES);
  GSOpenSaveSwizzle(self, @selector(runModal), @selector(gs_runModal), NO);
  GSOpenSaveSwizzle(self, @selector(runModalForDirectory:file:),
                    @selector(gs_runModalForDirectory:file:), NO);
  GSOpenSaveSwizzle(self, @selector(runModalForDirectory:file:types:),
                    @selector(gs_runModalForDirectory:file:types:), NO);
  GSOpenSaveSwizzle(self, @selector(runModalForTypes:),
                    @selector(gs_runModalForTypes:), NO);
  GSOpenSaveSwizzle(self, @selector(runModalForDirectory:file:types:relativeToWindow:),
                    @selector(gs_runModalForDirectory:file:types:relativeToWindow:), NO);
  GSOpenSaveSwizzle(self, @selector(beginSheetForDirectory:file:types:modalForWindow:modalDelegate:didEndSelector:contextInfo:),
                    @selector(gs_beginSheetForDirectory:file:types:modalForWindow:modalDelegate:didEndSelector:contextInfo:), NO);
  GSOpenSaveSwizzle(self, @selector(beginForDirectory:file:types:modelessDelegate:didEndSelector:contextInfo:),
                    @selector(gs_beginForDirectory:file:types:modelessDelegate:didEndSelector:contextInfo:), NO);
  GSOpenSaveSwizzle(self, @selector(beginSheetModalForWindow:completionHandler:),
                    @selector(gs_beginSheetModalForWindow:completionHandler:), NO);
  GSOpenSaveSwizzle(self, @selector(setAllowedFileTypes:),
                    @selector(gs_setAllowedFileTypes:), NO);
  GSOpenSaveSwizzle(self, @selector(setCanChooseDirectories:),
                    @selector(gs_setCanChooseDirectories:), NO);
  GSOpenSaveSwizzle(self, @selector(setCanChooseFiles:),
                    @selector(gs_setCanChooseFiles:), NO);
  GSOpenSaveSwizzle(self, @selector(setAllowsMultipleSelection:),
                    @selector(gs_setAllowsMultipleSelection:), NO);
  GSOpenSaveSwizzle(self, @selector(setResolvesAliases:),
                    @selector(gs_setResolvesAliases:), NO);
  GSOpenSaveSwizzle(self, @selector(allowedFileTypes),
                    @selector(gs_allowedFileTypes), NO);
  GSOpenSaveSwizzle(self, @selector(canChooseDirectories),
                    @selector(gs_canChooseDirectories), NO);
  GSOpenSaveSwizzle(self, @selector(canChooseFiles),
                    @selector(gs_canChooseFiles), NO);
  GSOpenSaveSwizzle(self, @selector(allowsMultipleSelection),
                    @selector(gs_allowsMultipleSelection), NO);
  GSOpenSaveSwizzle(self, @selector(resolvesAliases),
                    @selector(gs_resolvesAliases), NO);
  GSOpenSaveSwizzle(self, @selector(URL), @selector(gs_URL), NO);
  GSOpenSaveSwizzle(self, @selector(URLs), @selector(gs_URLs), NO);
  GSOpenSaveSwizzle(self, @selector(filename), @selector(gs_filename), NO);
  GSOpenSaveSwizzle(self, @selector(filenames), @selector(gs_filenames), NO);
}

+ (NSOpenPanel *)gs_openPanel
{
  if (!GSOpenSaveHasNativeBackend()) {
    return [self gs_openPanel];
  }
  return [self gs_openPanel];
}

- (NSInteger)gs_runModal
{
  if (!GSOpenSaveShouldUseNativeBackend()) {
    return [self gs_runModal];
  }
  return GSOpenSaveRunOpenPanel(self, nil, nil, [self allowedFileTypes], nil);
}

- (NSInteger)gs_runModalForDirectory:(NSString *)path file:(NSString *)name
{
  if (!GSOpenSaveShouldUseNativeBackend()) {
    return [self gs_runModalForDirectory:path file:name];
  }
  return GSOpenSaveRunOpenPanel(self, path, name, [self allowedFileTypes], nil);
}

- (NSInteger)gs_runModalForDirectory:(NSString *)path
                                file:(NSString *)name
                               types:(NSArray *)fileTypes
{
  if (!GSOpenSaveShouldUseNativeBackend()) {
    return [self gs_runModalForDirectory:path file:name types:fileTypes];
  }
  return GSOpenSaveRunOpenPanel(self, path, name, fileTypes, nil);
}

- (NSInteger)gs_runModalForTypes:(NSArray *)fileTypes
{
  if (!GSOpenSaveShouldUseNativeBackend()) {
    return [self gs_runModalForTypes:fileTypes];
  }
  return GSOpenSaveRunOpenPanel(self, nil, nil, fileTypes, nil);
}

- (NSInteger)gs_runModalForDirectory:(NSString *)path
                                file:(NSString *)name
                               types:(NSArray *)fileTypes
                     relativeToWindow:(NSWindow *)window
{
  if (!GSOpenSaveShouldUseNativeBackend()) {
    return [self gs_runModalForDirectory:path file:name types:fileTypes relativeToWindow:window];
  }
  return GSOpenSaveRunOpenPanel(self, path, name, fileTypes, window);
}

- (void)gs_beginSheetForDirectory:(NSString *)path
                             file:(NSString *)name
                            types:(NSArray *)fileTypes
                   modalForWindow:(NSWindow *)window
                    modalDelegate:(id)delegate
                   didEndSelector:(SEL)didEndSelector
                      contextInfo:(void *)contextInfo
{
  if (!GSOpenSaveShouldUseNativeBackend()) {
    [self gs_beginSheetForDirectory:path
                               file:name
                              types:fileTypes
                     modalForWindow:window
                      modalDelegate:delegate
                     didEndSelector:didEndSelector
                        contextInfo:contextInfo];
    return;
  }
  (void)path;
  (void)name;
  (void)fileTypes;
  (void)window;
  (void)delegate;
  (void)didEndSelector;
  (void)contextInfo;
}

- (void)gs_beginForDirectory:(NSString *)absoluteDirectoryPath
                        file:(NSString *)filename
                       types:(NSArray *)fileTypes
            modelessDelegate:(id)delegate
               didEndSelector:(SEL)didEndSelector
                  contextInfo:(void *)contextInfo
{
  if (!GSOpenSaveShouldUseNativeBackend()) {
    [self gs_beginForDirectory:absoluteDirectoryPath
                          file:filename
                         types:fileTypes
              modelessDelegate:delegate
                 didEndSelector:didEndSelector
                    contextInfo:contextInfo];
    return;
  }
  (void)absoluteDirectoryPath;
  (void)filename;
  (void)fileTypes;
  (void)delegate;
  (void)didEndSelector;
  (void)contextInfo;
}

- (void)gs_beginSheetModalForWindow:(NSWindow *)window
                  completionHandler:(void (^)(NSInteger result))handler
{
  if (!GSOpenSaveShouldUseNativeBackend()) {
    [self gs_beginSheetModalForWindow:window completionHandler:handler];
    return;
  }
  NSInteger result = GSOpenSaveRunOpenPanel(self, nil, nil, [self allowedFileTypes], window);
  if (handler != NULL) {
    handler(result);
  }
}

- (void)gs_setAllowedFileTypes:(NSArray *)types
{
  if (!GSOpenSaveHasNativeBackend()) {
    [self gs_setAllowedFileTypes:types];
    return;
  }
  GSOpenSaveSetAssociatedObject(self, GSOpenSaveAllowedFileTypesKey, types);
}

- (void)gs_setCanChooseDirectories:(BOOL)flag
{
  if (!GSOpenSaveHasNativeBackend()) {
    [self gs_setCanChooseDirectories:flag];
    return;
  }
  GSOpenSaveSetAssociatedObject(self, GSOpenSaveCanChooseDirectoriesKey,
                                [NSNumber numberWithBool:flag]);
}

- (void)gs_setCanChooseFiles:(BOOL)flag
{
  if (!GSOpenSaveHasNativeBackend()) {
    [self gs_setCanChooseFiles:flag];
    return;
  }
  GSOpenSaveSetAssociatedObject(self, GSOpenSaveCanChooseFilesKey,
                                [NSNumber numberWithBool:flag]);
}

- (void)gs_setAllowsMultipleSelection:(BOOL)flag
{
  if (!GSOpenSaveHasNativeBackend()) {
    [self gs_setAllowsMultipleSelection:flag];
    return;
  }
  GSOpenSaveSetAssociatedObject(self, GSOpenSaveAllowsMultipleSelectionKey,
                                [NSNumber numberWithBool:flag]);
}

- (void)gs_setResolvesAliases:(BOOL)flag
{
  if (!GSOpenSaveHasNativeBackend()) {
    [self gs_setResolvesAliases:flag];
    return;
  }
  GSOpenSaveSetAssociatedObject(self, GSOpenSaveResolvesAliasesKey,
                                [NSNumber numberWithBool:flag]);
}

- (NSArray *)gs_allowedFileTypes
{
  if (!GSOpenSaveShouldUseNativeBackend()) {
    return [self gs_allowedFileTypes];
  }
  return GSOpenSaveGetAssociatedObject(self, GSOpenSaveAllowedFileTypesKey);
}

- (BOOL)gs_canChooseDirectories
{
  if (!GSOpenSaveShouldUseNativeBackend()) {
    return [self gs_canChooseDirectories];
  }
  return GSOpenSaveBoolForKey(self, GSOpenSaveCanChooseDirectoriesKey, NO);
}

- (BOOL)gs_canChooseFiles
{
  if (!GSOpenSaveShouldUseNativeBackend()) {
    return [self gs_canChooseFiles];
  }
  return GSOpenSaveBoolForKey(self, GSOpenSaveCanChooseFilesKey, YES);
}

- (BOOL)gs_allowsMultipleSelection
{
  if (!GSOpenSaveShouldUseNativeBackend()) {
    return [self gs_allowsMultipleSelection];
  }
  return GSOpenSaveBoolForKey(self, GSOpenSaveAllowsMultipleSelectionKey, NO);
}

- (BOOL)gs_resolvesAliases
{
  if (!GSOpenSaveShouldUseNativeBackend()) {
    return [self gs_resolvesAliases];
  }
  return GSOpenSaveBoolForKey(self, GSOpenSaveResolvesAliasesKey, NO);
}

- (NSURL *)gs_URL
{
  if (!GSOpenSaveShouldUseNativeBackend() && !GSOpenSaveHasStoredOpenSelection(self)) {
    return [self gs_URL];
  }
  NSArray *urls = GSOpenSaveGetAssociatedObject(self, GSOpenSaveOpenURLsKey);
  return [urls count] > 0 ? [urls objectAtIndex:0] : nil;
}

- (NSArray *)gs_URLs
{
  if (!GSOpenSaveShouldUseNativeBackend() && !GSOpenSaveHasStoredOpenSelection(self)) {
    return [self gs_URLs];
  }
  return GSOpenSaveGetAssociatedObject(self, GSOpenSaveOpenURLsKey);
}

- (NSString *)gs_filename
{
  if (!GSOpenSaveShouldUseNativeBackend() && !GSOpenSaveHasStoredOpenSelection(self)) {
    return [self gs_filename];
  }
  NSArray *names = GSOpenSaveGetAssociatedObject(self, GSOpenSaveOpenFilenamesKey);
  return [names count] > 0 ? [names objectAtIndex:0] : nil;
}

- (NSArray *)gs_filenames
{
  if (!GSOpenSaveShouldUseNativeBackend() && !GSOpenSaveHasStoredOpenSelection(self)) {
    return [self gs_filenames];
  }
  return GSOpenSaveGetAssociatedObject(self, GSOpenSaveOpenFilenamesKey);
}

- (void)setFilenames:(NSArray *)filenames
{
  GSOpenSaveSetAssociatedObject(self, GSOpenSaveOpenFilenamesKey, filenames);
  if (filenames == nil) {
    GSOpenSaveSetAssociatedObject(self, GSOpenSaveOpenURLsKey, nil);
    return;
  }
  NSMutableArray *urls = [NSMutableArray arrayWithCapacity:[filenames count]];
  for (NSString *path in filenames) {
    NSURL *url = [NSURL fileURLWithPath:path];
    if (url != nil) {
      [urls addObject:url];
    }
  }
  GSOpenSaveSetAssociatedObject(self, GSOpenSaveOpenURLsKey, urls);
}

@end

@implementation NSSavePanel (GSOpenSave)

+ (void)load
{
  GSOpenSaveSwizzle(self, @selector(savePanel), @selector(gs_savePanel), YES);
  GSOpenSaveSwizzle(self, @selector(runModal), @selector(gs_runModal), NO);
  GSOpenSaveSwizzle(self, @selector(beginSheetModalForWindow:completionHandler:),
                    @selector(gs_beginSheetModalForWindow:completionHandler:), NO);
  GSOpenSaveSwizzle(self, @selector(beginWithCompletionHandler:),
                    @selector(gs_beginWithCompletionHandler:), NO);
  GSOpenSaveSwizzle(self, @selector(runModalForDirectory:file:),
                    @selector(gs_runModalForDirectory:file:), NO);
  GSOpenSaveSwizzle(self, @selector(runModalForDirectory:file:relativeToWindow:),
                    @selector(gs_runModalForDirectory:file:relativeToWindow:), NO);
  GSOpenSaveSwizzle(self, @selector(beginSheetForDirectory:file:modalForWindow:modalDelegate:didEndSelector:contextInfo:),
                    @selector(gs_beginSheetForDirectory:file:modalForWindow:modalDelegate:didEndSelector:contextInfo:), NO);
  GSOpenSaveSwizzle(self, @selector(setAllowedFileTypes:),
                    @selector(gs_setAllowedFileTypes:), NO);
  GSOpenSaveSwizzle(self, @selector(setAccessoryView:),
                    @selector(gs_setAccessoryView:), NO);
  GSOpenSaveSwizzle(self, @selector(setTitle:),
                    @selector(gs_setTitle:), NO);
  GSOpenSaveSwizzle(self, @selector(setPrompt:),
                    @selector(gs_setPrompt:), NO);
  GSOpenSaveSwizzle(self, @selector(setNameFieldStringValue:),
                    @selector(gs_setNameFieldStringValue:), NO);
  GSOpenSaveSwizzle(self, @selector(setNameFieldLabel:),
                    @selector(gs_setNameFieldLabel:), NO);
  GSOpenSaveSwizzle(self, @selector(setMessage:),
                    @selector(gs_setMessage:), NO);
  GSOpenSaveSwizzle(self, @selector(setCanSelectHiddenExtension:),
                    @selector(gs_setCanSelectHiddenExtension:), NO);
  GSOpenSaveSwizzle(self, @selector(setExtensionHidden:),
                    @selector(gs_setExtensionHidden:), NO);
  GSOpenSaveSwizzle(self, @selector(setShowsHiddenFiles:),
                    @selector(gs_setShowsHiddenFiles:), NO);
  GSOpenSaveSwizzle(self, @selector(setDirectory:),
                    @selector(gs_setDirectory:), NO);
  GSOpenSaveSwizzle(self, @selector(setDirectoryURL:),
                    @selector(gs_setDirectoryURL:), NO);
  GSOpenSaveSwizzle(self, @selector(setRequiredFileType:),
                    @selector(gs_setRequiredFileType:), NO);
  GSOpenSaveSwizzle(self, @selector(setAllowsOtherFileTypes:),
                    @selector(gs_setAllowsOtherFileTypes:), NO);
  GSOpenSaveSwizzle(self, @selector(setTreatsFilePackagesAsDirectories:),
                    @selector(gs_setTreatsFilePackagesAsDirectories:), NO);
  GSOpenSaveSwizzle(self, @selector(validateVisibleColumns),
                    @selector(gs_validateVisibleColumns), NO);
  GSOpenSaveSwizzle(self, @selector(setCanCreateDirectories:),
                    @selector(gs_setCanCreateDirectories:), NO);
  GSOpenSaveSwizzle(self, @selector(allowedFileTypes),
                    @selector(gs_allowedFileTypes), NO);
  GSOpenSaveSwizzle(self, @selector(accessoryView),
                    @selector(gs_accessoryView), NO);
  GSOpenSaveSwizzle(self, @selector(title),
                    @selector(gs_title), NO);
  GSOpenSaveSwizzle(self, @selector(prompt),
                    @selector(gs_prompt), NO);
  GSOpenSaveSwizzle(self, @selector(nameFieldStringValue),
                    @selector(gs_nameFieldStringValue), NO);
  GSOpenSaveSwizzle(self, @selector(nameFieldLabel),
                    @selector(gs_nameFieldLabel), NO);
  GSOpenSaveSwizzle(self, @selector(message),
                    @selector(gs_message), NO);
  GSOpenSaveSwizzle(self, @selector(canSelectHiddenExtension),
                    @selector(gs_canSelectHiddenExtension), NO);
  GSOpenSaveSwizzle(self, @selector(isExtensionHidden),
                    @selector(gs_isExtensionHidden), NO);
  GSOpenSaveSwizzle(self, @selector(showsHiddenFiles),
                    @selector(gs_showsHiddenFiles), NO);
  GSOpenSaveSwizzle(self, @selector(directory),
                    @selector(gs_directory), NO);
  GSOpenSaveSwizzle(self, @selector(directoryURL),
                    @selector(gs_directoryURL), NO);
  GSOpenSaveSwizzle(self, @selector(requiredFileType),
                    @selector(gs_requiredFileType), NO);
  GSOpenSaveSwizzle(self, @selector(allowsOtherFileTypes),
                    @selector(gs_allowsOtherFileTypes), NO);
  GSOpenSaveSwizzle(self, @selector(treatsFilePackagesAsDirectories),
                    @selector(gs_treatsFilePackagesAsDirectories), NO);
  GSOpenSaveSwizzle(self, @selector(canCreateDirectories),
                    @selector(gs_canCreateDirectories), NO);
  GSOpenSaveSwizzle(self, @selector(URL), @selector(gs_URL), NO);
  GSOpenSaveSwizzle(self, @selector(filename), @selector(gs_filename), NO);
}

+ (NSSavePanel *)gs_savePanel
{
  if (!GSOpenSaveHasNativeBackend()) {
    return [self gs_savePanel];
  }
  return [self gs_savePanel];
}

- (NSInteger)gs_runModal
{
  if (!GSOpenSaveShouldUseNativeBackend()) {
    return [self gs_runModal];
  }
  return GSOpenSaveRunSavePanel(self, [self directory], [self filename], [self allowedFileTypes], nil);
}

- (void)gs_beginSheetModalForWindow:(NSWindow *)window
                  completionHandler:(void (^)(NSInteger result))handler
{
  if (!GSOpenSaveShouldUseNativeBackend()) {
    [self gs_beginSheetModalForWindow:window completionHandler:handler];
    return;
  }
  NSInteger result = GSOpenSaveRunSavePanel(self, [self directory], [self filename], [self allowedFileTypes], window);
  if (handler != NULL) {
    handler(result);
  }
}

- (void)gs_beginWithCompletionHandler:(GSSavePanelCompletionHandler)handler
{
  if (!GSOpenSaveShouldUseNativeBackend()) {
    [self gs_beginWithCompletionHandler:handler];
    return;
  }
  NSInteger result = GSOpenSaveRunSavePanel(self, [self directory], [self filename], [self allowedFileTypes], nil);
  if (handler != NULL) {
    handler(result);
  }
}

- (NSInteger)gs_runModalForDirectory:(NSString *)path file:(NSString *)filename
{
  if (!GSOpenSaveShouldUseNativeBackend()) {
    return [self gs_runModalForDirectory:path file:filename];
  }
  return GSOpenSaveRunSavePanel(self, path, filename, [self allowedFileTypes], nil);
}

- (NSInteger)gs_runModalForDirectory:(NSString *)path
                                file:(NSString *)filename
                   relativeToWindow:(NSWindow *)window
{
  if (!GSOpenSaveShouldUseNativeBackend()) {
    return [self gs_runModalForDirectory:path file:filename relativeToWindow:window];
  }
  return GSOpenSaveRunSavePanel(self, path, filename, [self allowedFileTypes], window);
}

- (void)gs_beginSheetForDirectory:(NSString *)path
                             file:(NSString *)filename
                   modalForWindow:(NSWindow *)window
                    modalDelegate:(id)delegate
                   didEndSelector:(SEL)didEndSelector
                      contextInfo:(void *)contextInfo
{
  if (!GSOpenSaveShouldUseNativeBackend()) {
    [self gs_beginSheetForDirectory:path
                               file:filename
                     modalForWindow:window
                      modalDelegate:delegate
                     didEndSelector:didEndSelector
                        contextInfo:contextInfo];
    return;
  }
  (void)window;
  (void)delegate;
  (void)didEndSelector;
  (void)contextInfo;
  GSOpenSaveRunSavePanel(self, path, filename, [self allowedFileTypes], window);
}

- (void)gs_setAllowedFileTypes:(NSArray *)types
{
  if (!GSOpenSaveHasNativeBackend()) {
    [self gs_setAllowedFileTypes:types];
    return;
  }
  GSOpenSaveSetAssociatedObject(self, GSOpenSaveAllowedFileTypesKey, types);
}

- (void)gs_setAccessoryView:(NSView *)aView
{
  if (!GSOpenSaveHasNativeBackend()) {
    [self gs_setAccessoryView:aView];
    return;
  }
  GSOpenSaveSetAssociatedObject(self, GSOpenSaveAccessoryViewKey, aView);
}

- (void)gs_setTitle:(NSString *)title
{
  if (!GSOpenSaveHasNativeBackend()) {
    [self gs_setTitle:title];
    return;
  }
  GSOpenSaveSetAssociatedObject(self, GSOpenSaveTitleKey, title);
}

- (void)gs_setPrompt:(NSString *)prompt
{
  if (!GSOpenSaveHasNativeBackend()) {
    [self gs_setPrompt:prompt];
    return;
  }
  GSOpenSaveSetAssociatedObject(self, GSOpenSavePromptKey, prompt);
}

- (void)gs_setNameFieldStringValue:(NSString *)value
{
  if (!GSOpenSaveHasNativeBackend()) {
    [self gs_setNameFieldStringValue:value];
    return;
  }
  GSOpenSaveSetAssociatedObject(self, GSOpenSaveNameFieldValueKey, value);
}

- (void)gs_setNameFieldLabel:(NSString *)label
{
  if (!GSOpenSaveHasNativeBackend()) {
    [self gs_setNameFieldLabel:label];
    return;
  }
  GSOpenSaveSetAssociatedObject(self, GSOpenSaveNameFieldLabelKey, label);
}

- (void)gs_setMessage:(NSString *)message
{
  if (!GSOpenSaveHasNativeBackend()) {
    [self gs_setMessage:message];
    return;
  }
  GSOpenSaveSetAssociatedObject(self, GSOpenSaveMessageKey, message);
}

- (void)gs_setCanSelectHiddenExtension:(BOOL)flag
{
  if (!GSOpenSaveHasNativeBackend()) {
    [self gs_setCanSelectHiddenExtension:flag];
    return;
  }
  GSOpenSaveSetAssociatedObject(self, GSOpenSaveCanSelectHiddenExtensionKey,
                                [NSNumber numberWithBool:flag]);
}

- (void)gs_setExtensionHidden:(BOOL)flag
{
  if (!GSOpenSaveHasNativeBackend()) {
    [self gs_setExtensionHidden:flag];
    return;
  }
  GSOpenSaveSetAssociatedObject(self, GSOpenSaveExtensionHiddenKey,
                                [NSNumber numberWithBool:flag]);
}

- (void)gs_setShowsHiddenFiles:(BOOL)flag
{
  if (!GSOpenSaveHasNativeBackend()) {
    [self gs_setShowsHiddenFiles:flag];
    return;
  }
  GSOpenSaveSetAssociatedObject(self, GSOpenSaveShowsHiddenFilesKey,
                                [NSNumber numberWithBool:flag]);
}

- (void)gs_setDirectory:(NSString *)path
{
  if (!GSOpenSaveHasNativeBackend()) {
    [self gs_setDirectory:path];
    return;
  }
  GSOpenSaveSetAssociatedObject(self, GSOpenSaveDirectoryKey, path);
}

- (void)gs_setDirectoryURL:(NSURL *)url
{
  if (!GSOpenSaveHasNativeBackend()) {
    [self gs_setDirectoryURL:url];
    return;
  }
  GSOpenSaveSetAssociatedObject(self, GSOpenSaveDirectoryURLKey, url);
  if (url != nil) {
    GSOpenSaveSetAssociatedObject(self, GSOpenSaveDirectoryKey, [url path]);
  }
}

- (void)gs_setRequiredFileType:(NSString *)fileType
{
  if (!GSOpenSaveHasNativeBackend()) {
    [self gs_setRequiredFileType:fileType];
    return;
  }
  GSOpenSaveSetAssociatedObject(self, GSOpenSaveRequiredFileTypeKey, fileType);
}

- (void)gs_setAllowsOtherFileTypes:(BOOL)flag
{
  if (!GSOpenSaveHasNativeBackend()) {
    [self gs_setAllowsOtherFileTypes:flag];
    return;
  }
  GSOpenSaveSetAssociatedObject(self, GSOpenSaveAllowsOtherFileTypesKey,
                                [NSNumber numberWithBool:flag]);
}

- (void)gs_setTreatsFilePackagesAsDirectories:(BOOL)flag
{
  if (!GSOpenSaveHasNativeBackend()) {
    [self gs_setTreatsFilePackagesAsDirectories:flag];
    return;
  }
  GSOpenSaveSetAssociatedObject(self, GSOpenSaveTreatsPackagesAsDirsKey,
                                [NSNumber numberWithBool:flag]);
}

- (void)gs_validateVisibleColumns
{
  if (!GSOpenSaveHasNativeBackend()) {
    [self gs_validateVisibleColumns];
  }
}

- (void)gs_setCanCreateDirectories:(BOOL)flag
{
  if (!GSOpenSaveHasNativeBackend()) {
    [self gs_setCanCreateDirectories:flag];
    return;
  }
  GSOpenSaveSetAssociatedObject(self, GSOpenSaveCanCreateDirectoriesKey,
                                [NSNumber numberWithBool:flag]);
}

- (NSArray *)gs_allowedFileTypes
{
  if (!GSOpenSaveShouldUseNativeBackend()) {
    return [self gs_allowedFileTypes];
  }
  return GSOpenSaveGetAssociatedObject(self, GSOpenSaveAllowedFileTypesKey);
}

- (NSView *)gs_accessoryView
{
  if (!GSOpenSaveShouldUseNativeBackend()) {
    return [self gs_accessoryView];
  }
  return GSOpenSaveGetAssociatedObject(self, GSOpenSaveAccessoryViewKey);
}

- (NSString *)gs_title
{
  if (!GSOpenSaveShouldUseNativeBackend()) {
    return [self gs_title];
  }
  return GSOpenSaveGetAssociatedObject(self, GSOpenSaveTitleKey);
}

- (NSString *)gs_prompt
{
  if (!GSOpenSaveShouldUseNativeBackend()) {
    return [self gs_prompt];
  }
  return GSOpenSaveGetAssociatedObject(self, GSOpenSavePromptKey);
}

- (NSString *)gs_nameFieldStringValue
{
  if (!GSOpenSaveShouldUseNativeBackend()) {
    return [self gs_nameFieldStringValue];
  }
  return GSOpenSaveGetAssociatedObject(self, GSOpenSaveNameFieldValueKey);
}

- (NSString *)gs_nameFieldLabel
{
  if (!GSOpenSaveShouldUseNativeBackend()) {
    return [self gs_nameFieldLabel];
  }
  return GSOpenSaveGetAssociatedObject(self, GSOpenSaveNameFieldLabelKey);
}

- (NSString *)gs_message
{
  if (!GSOpenSaveShouldUseNativeBackend()) {
    return [self gs_message];
  }
  return GSOpenSaveGetAssociatedObject(self, GSOpenSaveMessageKey);
}

- (BOOL)gs_canSelectHiddenExtension
{
  if (!GSOpenSaveShouldUseNativeBackend()) {
    return [self gs_canSelectHiddenExtension];
  }
  return GSOpenSaveBoolForKey(self, GSOpenSaveCanSelectHiddenExtensionKey, NO);
}

- (BOOL)gs_isExtensionHidden
{
  if (!GSOpenSaveShouldUseNativeBackend()) {
    return [self gs_isExtensionHidden];
  }
  return GSOpenSaveBoolForKey(self, GSOpenSaveExtensionHiddenKey, NO);
}

- (BOOL)gs_showsHiddenFiles
{
  if (!GSOpenSaveShouldUseNativeBackend()) {
    return [self gs_showsHiddenFiles];
  }
  return GSOpenSaveBoolForKey(self, GSOpenSaveShowsHiddenFilesKey, NO);
}

- (NSString *)gs_directory
{
  if (!GSOpenSaveShouldUseNativeBackend()) {
    return [self gs_directory];
  }
  return GSOpenSaveGetAssociatedObject(self, GSOpenSaveDirectoryKey);
}

- (NSURL *)gs_directoryURL
{
  if (!GSOpenSaveShouldUseNativeBackend()) {
    return [self gs_directoryURL];
  }
  NSURL *url = GSOpenSaveGetAssociatedObject(self, GSOpenSaveDirectoryURLKey);
  if (url != nil) {
    return url;
  }
  NSString *path = GSOpenSaveGetAssociatedObject(self, GSOpenSaveDirectoryKey);
  return path != nil ? [NSURL fileURLWithPath:path] : nil;
}

- (NSString *)gs_requiredFileType
{
  if (!GSOpenSaveShouldUseNativeBackend()) {
    return [self gs_requiredFileType];
  }
  return GSOpenSaveGetAssociatedObject(self, GSOpenSaveRequiredFileTypeKey);
}

- (BOOL)gs_allowsOtherFileTypes
{
  if (!GSOpenSaveShouldUseNativeBackend()) {
    return [self gs_allowsOtherFileTypes];
  }
  return GSOpenSaveBoolForKey(self, GSOpenSaveAllowsOtherFileTypesKey, NO);
}

- (BOOL)gs_treatsFilePackagesAsDirectories
{
  if (!GSOpenSaveShouldUseNativeBackend()) {
    return [self gs_treatsFilePackagesAsDirectories];
  }
  return GSOpenSaveBoolForKey(self, GSOpenSaveTreatsPackagesAsDirsKey, NO);
}

- (BOOL)gs_canCreateDirectories
{
  if (!GSOpenSaveShouldUseNativeBackend()) {
    return [self gs_canCreateDirectories];
  }
  return GSOpenSaveBoolForKey(self, GSOpenSaveCanCreateDirectoriesKey, NO);
}

- (NSURL *)gs_URL
{
  if (!GSOpenSaveShouldUseNativeBackend() && !GSOpenSaveHasStoredSaveSelection(self)) {
    return [self gs_URL];
  }
  NSString *path = GSOpenSaveGetAssociatedObject(self, GSOpenSaveSaveFilenameKey);
  return path != nil ? [NSURL fileURLWithPath:path] : nil;
}

- (NSString *)gs_filename
{
  if (!GSOpenSaveShouldUseNativeBackend() && !GSOpenSaveHasStoredSaveSelection(self)) {
    return [self gs_filename];
  }
  return GSOpenSaveGetAssociatedObject(self, GSOpenSaveSaveFilenameKey);
}

- (void)setFilename:(NSString *)filename
{
  GSOpenSaveSetAssociatedObject(self, GSOpenSaveSaveFilenameKey, filename);
}

@end
