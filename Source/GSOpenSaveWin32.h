#ifndef GS_OPENSAVE_WIN32_H
#define GS_OPENSAVE_WIN32_H

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>

BOOL GSOpenSaveWin32IsAvailable(void);
NSInteger GSOpenSaveWin32RunOpenPanel(NSOpenPanel *panel,
                                      NSString *directory,
                                      NSString *filename,
                                      NSArray *fileTypes,
                                      NSWindow *parentWindow);
NSInteger GSOpenSaveWin32RunSavePanel(NSSavePanel *panel,
                                      NSString *directory,
                                      NSString *filename,
                                      NSArray *fileTypes,
                                      NSWindow *parentWindow);

#endif
