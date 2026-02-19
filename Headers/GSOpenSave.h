#ifndef GS_OPENSAVE_H
#define GS_OPENSAVE_H

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, GSOpenSaveMode) {
  GSOpenSaveModeAuto = 0,
  GSOpenSaveModeGtk = 1,
  GSOpenSaveModeGNUstep = 2,
  GSOpenSaveModeWin32 = 3
};

void GSOpenSaveSetMode(GSOpenSaveMode mode);
GSOpenSaveMode GSOpenSaveGetMode(void);

#endif
