#import "GSOpenSave.h"

static GSOpenSaveMode gsOpenSaveMode = GSOpenSaveModeAuto;

void GSOpenSaveSetMode(GSOpenSaveMode mode)
{
  gsOpenSaveMode = mode;
}

GSOpenSaveMode GSOpenSaveGetMode(void)
{
  return gsOpenSaveMode;
}
