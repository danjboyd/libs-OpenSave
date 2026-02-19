#import "GSOpenSaveWin32.h"

@interface NSOpenPanel (GSOpenSaveState)
- (void)setFilenames:(NSArray *)filenames;
@end

@interface NSSavePanel (GSOpenSaveState)
- (void)setFilename:(NSString *)filename;
@end

#if defined(_WIN32)

#ifndef interface
#define interface struct
#endif

#include <windows.h>
#include <commdlg.h>
#include <shlobj.h>
#include <wchar.h>

static NSString *GSOpenSaveNSStringFromWide(const wchar_t *value)
{
  if (value == NULL) {
    return nil;
  }
  return [NSString stringWithCharacters:(const unichar *)value
                                 length:wcslen(value)];
}

static wchar_t *GSOpenSaveWideFromNSString(NSString *value)
{
  if (value == nil) {
    return NULL;
  }

  NSUInteger len = [value length];
  wchar_t *wide = calloc(len + 1, sizeof(wchar_t));
  if (wide == NULL) {
    return NULL;
  }

  [value getCharacters:(unichar *)wide];
  wide[len] = L'\0';
  return wide;
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
  if ([type rangeOfString:@"."].location == NSNotFound) {
    return [NSString stringWithFormat:@"*.%@", type];
  }
  return type;
}

static wchar_t *GSOpenSaveBuildFilterBuffer(NSArray *fileTypes,
                                            NSString *requiredFileType,
                                            BOOL allowsOtherFileTypes)
{
  NSMutableArray *patterns = [NSMutableArray array];
  for (NSString *type in fileTypes) {
    NSString *pattern = GSOpenSavePatternForType(type);
    if (pattern != nil) {
      [patterns addObject:pattern];
    }
  }

  NSMutableArray *entries = [NSMutableArray array];
  if ([patterns count] > 0) {
    [entries addObject:@[@"Allowed Types", [patterns componentsJoinedByString:@";"]]];
  }

  NSString *required = GSOpenSavePatternForType(requiredFileType);
  if (required != nil) {
    [entries insertObject:@[@"Required Type", required] atIndex:0];
  }

  if (allowsOtherFileTypes || [entries count] == 0) {
    [entries addObject:@[@"All Files", @"*.*"]];
  }

  NSUInteger totalLen = 1;
  for (NSArray *entry in entries) {
    NSString *name = [entry objectAtIndex:0];
    NSString *spec = [entry objectAtIndex:1];
    totalLen += [name length] + 1;
    totalLen += [spec length] + 1;
  }

  wchar_t *buffer = calloc(totalLen, sizeof(wchar_t));
  if (buffer == NULL) {
    return NULL;
  }

  wchar_t *cursor = buffer;
  for (NSArray *entry in entries) {
    wchar_t *wideName = GSOpenSaveWideFromNSString([entry objectAtIndex:0]);
    wchar_t *wideSpec = GSOpenSaveWideFromNSString([entry objectAtIndex:1]);
    if (wideName != NULL) {
      size_t nameLen = wcslen(wideName);
      memcpy(cursor, wideName, nameLen * sizeof(wchar_t));
      cursor += nameLen + 1;
      free(wideName);
    } else {
      cursor++;
    }
    if (wideSpec != NULL) {
      size_t specLen = wcslen(wideSpec);
      memcpy(cursor, wideSpec, specLen * sizeof(wchar_t));
      cursor += specLen + 1;
      free(wideSpec);
    } else {
      cursor++;
    }
  }

  *cursor = L'\0';
  return buffer;
}

static void GSOpenSaveApplyInitialDirectory(OPENFILENAMEW *ofn, NSString *directory)
{
  if (directory == nil || [directory length] == 0) {
    return;
  }
  ofn->lpstrInitialDir = GSOpenSaveWideFromNSString(directory);
}

static NSArray *GSOpenSaveParseOpenResults(const wchar_t *buffer)
{
  if (buffer == NULL || buffer[0] == L'\0') {
    return nil;
  }

  const wchar_t *first = buffer;
  const wchar_t *next = first + wcslen(first) + 1;

  if (*next == L'\0') {
    NSString *fullPath = GSOpenSaveNSStringFromWide(first);
    return fullPath != nil ? [NSArray arrayWithObject:fullPath] : nil;
  }

  NSString *directory = GSOpenSaveNSStringFromWide(first);
  if (directory == nil) {
    return nil;
  }

  NSMutableArray *paths = [NSMutableArray array];
  while (*next != L'\0') {
    NSString *name = GSOpenSaveNSStringFromWide(next);
    if (name != nil) {
      NSString *fullPath = [directory stringByAppendingPathComponent:name];
      [paths addObject:fullPath];
    }
    next += wcslen(next) + 1;
  }

  return [paths count] > 0 ? paths : nil;
}

static NSInteger GSOpenSaveRunDirectoryPicker(NSOpenPanel *panel, NSString *title)
{
  BROWSEINFOW bi;
  memset(&bi, 0, sizeof(bi));
  bi.ulFlags = BIF_RETURNONLYFSDIRS | BIF_NEWDIALOGSTYLE;

  wchar_t *wideTitle = NULL;
  if (title != nil && [title length] > 0) {
    wideTitle = GSOpenSaveWideFromNSString(title);
    bi.lpszTitle = wideTitle;
  }

  LPITEMIDLIST pidl = SHBrowseForFolderW(&bi);
  if (wideTitle != NULL) {
    free(wideTitle);
  }
  if (pidl == NULL) {
    return NSFileHandlingPanelCancelButton;
  }

  wchar_t path[MAX_PATH];
  NSInteger result = NSFileHandlingPanelCancelButton;
  if (SHGetPathFromIDListW(pidl, path)) {
    NSString *str = GSOpenSaveNSStringFromWide(path);
    if (str != nil) {
      [panel setFilenames:[NSArray arrayWithObject:str]];
      result = NSFileHandlingPanelOKButton;
    }
  }
  CoTaskMemFree(pidl);
  return result;
}

BOOL GSOpenSaveWin32IsAvailable(void)
{
  return YES;
}

NSInteger GSOpenSaveWin32RunOpenPanel(NSOpenPanel *panel,
                                      NSString *directory,
                                      NSString *filename,
                                      NSArray *fileTypes)
{
  if ([panel canChooseDirectories] && ![panel canChooseFiles]) {
    return GSOpenSaveRunDirectoryPicker(panel, [panel title]);
  }

  if (directory == nil) {
    NSURL *dirURL = [panel directoryURL];
    if (dirURL != nil) {
      directory = [dirURL path];
    } else {
      directory = [panel directory];
    }
  }

  wchar_t *filterBuffer = GSOpenSaveBuildFilterBuffer(fileTypes, nil, NO);
  wchar_t *titleBuffer = GSOpenSaveWideFromNSString([panel title]);
  wchar_t *initialFile = GSOpenSaveWideFromNSString(filename);
  wchar_t fileBuffer[32768];
  memset(fileBuffer, 0, sizeof(fileBuffer));
  if (initialFile != NULL) {
    wcsncpy(fileBuffer, initialFile, (sizeof(fileBuffer) / sizeof(wchar_t)) - 1);
  }

  OPENFILENAMEW ofn;
  memset(&ofn, 0, sizeof(ofn));
  ofn.lStructSize = sizeof(ofn);
  ofn.lpstrFile = fileBuffer;
  ofn.nMaxFile = sizeof(fileBuffer) / sizeof(wchar_t);
  ofn.lpstrFilter = filterBuffer;
  ofn.lpstrTitle = titleBuffer;
  ofn.Flags = OFN_EXPLORER | OFN_HIDEREADONLY | OFN_PATHMUSTEXIST | OFN_FILEMUSTEXIST;
  if ([panel allowsMultipleSelection]) {
    ofn.Flags |= OFN_ALLOWMULTISELECT;
  }
  GSOpenSaveApplyInitialDirectory(&ofn, directory);

  NSInteger result = NSFileHandlingPanelCancelButton;
  if (GetOpenFileNameW(&ofn)) {
    NSArray *paths = GSOpenSaveParseOpenResults(fileBuffer);
    if (paths != nil && [paths count] > 0) {
      [panel setFilenames:paths];
      result = NSFileHandlingPanelOKButton;
    }
  }

  free((void *)ofn.lpstrInitialDir);
  free(filterBuffer);
  free(titleBuffer);
  free(initialFile);
  return result;
}

NSInteger GSOpenSaveWin32RunSavePanel(NSSavePanel *panel,
                                      NSString *directory,
                                      NSString *filename,
                                      NSArray *fileTypes)
{
  NSString *title = [panel title];
  if (title == nil || [title length] == 0) {
    title = [panel message];
  }

  if (directory == nil || [directory length] == 0) {
    directory = [panel directory];
  }
  if (filename == nil || [filename length] == 0) {
    filename = [panel nameFieldStringValue];
  }

  wchar_t *filterBuffer = GSOpenSaveBuildFilterBuffer(fileTypes,
                                                      [panel requiredFileType],
                                                      [panel allowsOtherFileTypes]);
  wchar_t *titleBuffer = GSOpenSaveWideFromNSString(title);
  wchar_t *initialFile = GSOpenSaveWideFromNSString(filename);
  NSString *requiredType = [panel requiredFileType];
  if ([requiredType hasPrefix:@"."]) {
    requiredType = [requiredType substringFromIndex:1];
  }
  wchar_t *defaultExtBuffer = GSOpenSaveWideFromNSString(requiredType);

  wchar_t fileBuffer[32768];
  memset(fileBuffer, 0, sizeof(fileBuffer));
  if (initialFile != NULL) {
    wcsncpy(fileBuffer, initialFile, (sizeof(fileBuffer) / sizeof(wchar_t)) - 1);
  }

  OPENFILENAMEW ofn;
  memset(&ofn, 0, sizeof(ofn));
  ofn.lStructSize = sizeof(ofn);
  ofn.lpstrFile = fileBuffer;
  ofn.nMaxFile = sizeof(fileBuffer) / sizeof(wchar_t);
  ofn.lpstrFilter = filterBuffer;
  ofn.lpstrTitle = titleBuffer;
  ofn.lpstrDefExt = defaultExtBuffer;
  ofn.Flags = OFN_EXPLORER | OFN_HIDEREADONLY | OFN_PATHMUSTEXIST | OFN_OVERWRITEPROMPT;
  GSOpenSaveApplyInitialDirectory(&ofn, directory);

  NSInteger result = NSFileHandlingPanelCancelButton;
  if (GetSaveFileNameW(&ofn)) {
    NSString *path = GSOpenSaveNSStringFromWide(fileBuffer);
    if (path != nil) {
      [panel setFilename:path];
      result = NSFileHandlingPanelOKButton;
    }
  }

  free((void *)ofn.lpstrInitialDir);
  free(filterBuffer);
  free(titleBuffer);
  free(initialFile);
  free(defaultExtBuffer);
  return result;
}

#else

BOOL GSOpenSaveWin32IsAvailable(void)
{
  return NO;
}

NSInteger GSOpenSaveWin32RunOpenPanel(NSOpenPanel *panel,
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

NSInteger GSOpenSaveWin32RunSavePanel(NSSavePanel *panel,
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
