#import <XCTest/XCTest.h>
#import <AppKit/AppKit.h>

@interface GSOpenSaveGtkSmokeTests : XCTestCase
@end

@implementation GSOpenSaveGtkSmokeTests

- (void)testGtkDialogsSmoke
{
  const char *flag = getenv("GS_OPENSAVE_RUN_GTK_TESTS");
  if (flag == NULL || flag[0] == '\0') {
    return;
  }

  NSOpenPanel *panel = [NSOpenPanel openPanel];
  NSInteger result = [panel runModal];
  XCTAssertTrue(result == NSFileHandlingPanelOKButton ||
                result == NSFileHandlingPanelCancelButton);
}

@end
