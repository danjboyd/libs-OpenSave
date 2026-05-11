#import <XCTest/XCTest.h>
#import <stdint.h>

#import "GSOpenSave.h"

extern NSString *GSOpenSaveGtkParentWindowIdentifierForX11Handle(void *windowRef);
extern NSString *GSOpenSaveGtkOpenAcceptLabelForPrompt(NSString *prompt);
extern NSString *GSOpenSaveGtkSaveAcceptLabelForPrompt(NSString *prompt);

@interface GSOpenSaveGtkTests : XCTestCase
@end

@implementation GSOpenSaveGtkTests

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

- (void)testX11ParentWindowIdentifierRejectsNullHandle
{
  XCTAssertNil(GSOpenSaveGtkParentWindowIdentifierForX11Handle(NULL));
}

- (void)testX11ParentWindowIdentifierFormatsNativeHandleAsPortalIdentifier
{
  NSString *identifier = GSOpenSaveGtkParentWindowIdentifierForX11Handle((void *)(uintptr_t)0x1234ABCDu);

  XCTAssertEqualObjects(identifier, @"x11:1234abcd");
}

- (void)testOpenAcceptLabelDefaultsToOpen
{
  XCTAssertEqualObjects(GSOpenSaveGtkOpenAcceptLabelForPrompt(nil), @"Open");
  XCTAssertEqualObjects(GSOpenSaveGtkOpenAcceptLabelForPrompt(@""), @"Open");
  XCTAssertEqualObjects(GSOpenSaveGtkOpenAcceptLabelForPrompt(@"Name:"), @"Open");
}

- (void)testOpenAcceptLabelUsesPromptWhenProvided
{
  XCTAssertEqualObjects(GSOpenSaveGtkOpenAcceptLabelForPrompt(@"Choose"), @"Choose");
}

- (void)testSaveAcceptLabelDefaultsToSave
{
  XCTAssertEqualObjects(GSOpenSaveGtkSaveAcceptLabelForPrompt(nil), @"Save");
  XCTAssertEqualObjects(GSOpenSaveGtkSaveAcceptLabelForPrompt(@""), @"Save");
  XCTAssertEqualObjects(GSOpenSaveGtkSaveAcceptLabelForPrompt(@"Name:"), @"Save");
}

- (void)testSaveAcceptLabelUsesPromptWhenProvided
{
  XCTAssertEqualObjects(GSOpenSaveGtkSaveAcceptLabelForPrompt(@"Export"), @"Export");
}

@end
