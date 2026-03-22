#ifndef GS_OPENSAVE_BACKEND_H
#define GS_OPENSAVE_BACKEND_H

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>

BOOL GSOpenSaveHasNativeBackend(void);
NSInteger GSOpenSaveRunOpenPanel(NSOpenPanel *panel,
                                 NSString *directory,
                                 NSString *filename,
                                 NSArray *fileTypes,
                                 NSWindow *parentWindow);
NSInteger GSOpenSaveRunSavePanel(NSSavePanel *panel,
                                 NSString *directory,
                                 NSString *filename,
                                 NSArray *fileTypes,
                                 NSWindow *parentWindow);

#endif
