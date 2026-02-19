#import <XCTest/XCTest.h>
#import "GSOpenSave.h"

@interface GSOpenSaveModeTests : XCTestCase
@end

@implementation GSOpenSaveModeTests

- (void)testDefaultModeIsAuto
{
  XCTAssertEqual(GSOpenSaveGetMode(), GSOpenSaveModeAuto);
}

- (void)testModeRoundTrip
{
  GSOpenSaveSetMode(GSOpenSaveModeAuto);
  XCTAssertEqual(GSOpenSaveGetMode(), GSOpenSaveModeAuto);

  GSOpenSaveSetMode(GSOpenSaveModeGtk);
  XCTAssertEqual(GSOpenSaveGetMode(), GSOpenSaveModeGtk);

  GSOpenSaveSetMode(GSOpenSaveModeWin32);
  XCTAssertEqual(GSOpenSaveGetMode(), GSOpenSaveModeWin32);

  GSOpenSaveSetMode(GSOpenSaveModeGNUstep);
  XCTAssertEqual(GSOpenSaveGetMode(), GSOpenSaveModeGNUstep);
  GSOpenSaveSetMode(GSOpenSaveModeAuto);
}

@end
