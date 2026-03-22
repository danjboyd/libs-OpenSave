#import "GSOpenSaveBackend.h"

#import "GSOpenSave.h"
#import "GSOpenSaveGtk.h"
#import "GSOpenSaveWin32.h"

typedef NS_ENUM(NSInteger, GSOpenSaveBackendKind) {
  GSOpenSaveBackendKindNone = 0,
  GSOpenSaveBackendKindGtk = 1,
  GSOpenSaveBackendKindWin32 = 2
};

static GSOpenSaveBackendKind GSOpenSaveSelectBackend(void)
{
  switch (GSOpenSaveGetMode()) {
    case GSOpenSaveModeGNUstep:
      return GSOpenSaveBackendKindNone;
    case GSOpenSaveModeGtk:
      return GSOpenSaveGtkIsAvailable() ? GSOpenSaveBackendKindGtk : GSOpenSaveBackendKindNone;
    case GSOpenSaveModeWin32:
      return GSOpenSaveWin32IsAvailable() ? GSOpenSaveBackendKindWin32 : GSOpenSaveBackendKindNone;
    case GSOpenSaveModeAuto:
    default:
#if defined(_WIN32)
      if (GSOpenSaveWin32IsAvailable()) {
        return GSOpenSaveBackendKindWin32;
      }
#endif
      if (GSOpenSaveGtkIsAvailable()) {
        return GSOpenSaveBackendKindGtk;
      }
      return GSOpenSaveBackendKindNone;
  }
}

BOOL GSOpenSaveHasNativeBackend(void)
{
  return GSOpenSaveSelectBackend() != GSOpenSaveBackendKindNone;
}

NSInteger GSOpenSaveRunOpenPanel(NSOpenPanel *panel,
                                 NSString *directory,
                                 NSString *filename,
                                 NSArray *fileTypes,
                                 NSWindow *parentWindow)
{
  switch (GSOpenSaveSelectBackend()) {
    case GSOpenSaveBackendKindGtk:
      return GSOpenSaveGtkRunOpenPanel(panel, directory, filename, fileTypes, parentWindow);
    case GSOpenSaveBackendKindWin32:
      return GSOpenSaveWin32RunOpenPanel(panel, directory, filename, fileTypes, parentWindow);
    case GSOpenSaveBackendKindNone:
    default:
      return NSFileHandlingPanelCancelButton;
  }
}

NSInteger GSOpenSaveRunSavePanel(NSSavePanel *panel,
                                 NSString *directory,
                                 NSString *filename,
                                 NSArray *fileTypes,
                                 NSWindow *parentWindow)
{
  switch (GSOpenSaveSelectBackend()) {
    case GSOpenSaveBackendKindGtk:
      return GSOpenSaveGtkRunSavePanel(panel, directory, filename, fileTypes, parentWindow);
    case GSOpenSaveBackendKindWin32:
      return GSOpenSaveWin32RunSavePanel(panel, directory, filename, fileTypes, parentWindow);
    case GSOpenSaveBackendKindNone:
    default:
      return NSFileHandlingPanelCancelButton;
  }
}
