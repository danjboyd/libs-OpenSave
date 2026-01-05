#ifndef GS_OPENSAVE_H
#define GS_OPENSAVE_H

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, GSOpenSaveMode) {
  GSOpenSaveModeGtk = 1,
  GSOpenSaveModeGNUstep = 2
};

void GSOpenSaveSetMode(GSOpenSaveMode mode);
GSOpenSaveMode GSOpenSaveGetMode(void);

#endif
