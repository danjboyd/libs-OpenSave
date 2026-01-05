#ifndef GS_OPENSAVE_GTK_H
#define GS_OPENSAVE_GTK_H

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>

BOOL GSOpenSaveGtkIsAvailable(void);
NSInteger GSOpenSaveGtkRunOpenPanel(NSOpenPanel *panel,
                                    NSString *directory,
                                    NSString *filename,
                                    NSArray *fileTypes);
NSInteger GSOpenSaveGtkRunSavePanel(NSSavePanel *panel,
                                    NSString *directory,
                                    NSString *filename,
                                    NSArray *fileTypes);

#endif
