#import <XCTest/XCTest.h>
#import <AppKit/AppKit.h>
#import <objc/runtime.h>

#import "GSOpenSave.h"

@interface NSOpenPanel (GSOpenSaveTestState)
- (void)setFilenames:(NSArray *)filenames;
@end

@interface NSSavePanel (GSOpenSaveTestState)
- (void)setFilename:(NSString *)filename;
@end

@interface GSOpenSavePanelAccessorTests : XCTestCase
@end

static id GSOpenSaveCreateHeadlessPanel(Class panelClass)
{
  /* These regressions only exercise our swizzled accessors and associated
     state, so a raw runtime instance avoids AppKit window-server setup. */
  return class_createInstance(panelClass, 0);
}

@implementation GSOpenSavePanelAccessorTests

- (void)setUp
{
  [super setUp];
  GSOpenSaveSetMode(GSOpenSaveModeAuto);
}

- (void)tearDown
{
  GSOpenSaveSetMode(GSOpenSaveModeAuto);
  [super tearDown];
}

- (void)testOpenPanelURLSwizzleDoesNotReuseSavePanelImplementation
{
  Method openURL = class_getInstanceMethod([NSOpenPanel class], @selector(URL));
  Method saveURL = class_getInstanceMethod([NSSavePanel class], @selector(URL));

  XCTAssertNotEqual(openURL, saveURL);
  XCTAssertNotEqual(method_getImplementation(openURL),
                    method_getImplementation(saveURL));
}

- (void)testOpenPanelStoredSelectionKeepsAccessorsInSync
{
  NSOpenPanel *panel = GSOpenSaveCreateHeadlessPanel([NSOpenPanel class]);
  NSArray *paths = [NSArray arrayWithObjects:@"/tmp/alpha.png",
                                              @"/tmp/beta.png",
                                              nil];
  NSArray *urls = nil;

  XCTAssertNotNil(panel);
  GSOpenSaveSetMode(GSOpenSaveModeGNUstep);
  @try {
    [panel setFilenames:paths];

    XCTAssertEqualObjects([[panel URL] path], @"/tmp/alpha.png");

    urls = [panel URLs];
    XCTAssertEqual([urls count], (NSUInteger)2);
    XCTAssertEqualObjects([[urls objectAtIndex:0] path], @"/tmp/alpha.png");
    XCTAssertEqualObjects([[urls objectAtIndex:1] path], @"/tmp/beta.png");

    XCTAssertEqualObjects([panel filename], @"/tmp/alpha.png");
    XCTAssertEqualObjects([panel filenames], paths);
  }
  @finally {
    object_dispose(panel);
  }
}

- (void)testSavePanelStoredSelectionKeepsAccessorsInSync
{
  NSSavePanel *panel = GSOpenSaveCreateHeadlessPanel([NSSavePanel class]);

  XCTAssertNotNil(panel);
  GSOpenSaveSetMode(GSOpenSaveModeGNUstep);
  @try {
    [panel setFilename:@"/tmp/output.png"];

    XCTAssertEqualObjects([[panel URL] path], @"/tmp/output.png");
    XCTAssertEqualObjects([panel filename], @"/tmp/output.png");
  }
  @finally {
    object_dispose(panel);
  }
}

@end
