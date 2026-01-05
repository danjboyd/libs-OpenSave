#import <XCTest/XCTest.h>
#import "GSOpenSave.h"

@interface GSOpenSaveModeTests : XCTestCase
@end

@implementation GSOpenSaveModeTests

- (void)testDefaultModeIsGtk
{
  XCTAssertEqual(GSOpenSaveGetMode(), GSOpenSaveModeGtk);
}

- (void)testModeRoundTrip
{
  GSOpenSaveSetMode(GSOpenSaveModeGNUstep);
  XCTAssertEqual(GSOpenSaveGetMode(), GSOpenSaveModeGNUstep);
  GSOpenSaveSetMode(GSOpenSaveModeGtk);
}

@end
