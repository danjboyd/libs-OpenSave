#import <XCTest/XCTest.h>
#import <stdint.h>

extern NSString *GSOpenSaveGtkParentWindowIdentifierForX11Handle(void *windowRef);

@interface GSOpenSaveGtkTests : XCTestCase
@end

@implementation GSOpenSaveGtkTests

- (void)testX11ParentWindowIdentifierRejectsNullHandle
{
  XCTAssertNil(GSOpenSaveGtkParentWindowIdentifierForX11Handle(NULL));
}

- (void)testX11ParentWindowIdentifierFormatsNativeHandleAsPortalIdentifier
{
  NSString *identifier = GSOpenSaveGtkParentWindowIdentifierForX11Handle((void *)(uintptr_t)0x1234ABCDu);

  XCTAssertEqualObjects(identifier, @"x11:1234abcd");
}

@end
