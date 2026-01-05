#import "GSOpenSave.h"

static GSOpenSaveMode gsOpenSaveMode = GSOpenSaveModeGtk;

void GSOpenSaveSetMode(GSOpenSaveMode mode)
{
  gsOpenSaveMode = mode;
}

GSOpenSaveMode GSOpenSaveGetMode(void)
{
  return gsOpenSaveMode;
}
