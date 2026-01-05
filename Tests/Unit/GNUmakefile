include $(GNUSTEP_MAKEFILES)/common.make

BUNDLE_NAME = GSOpenSaveUnitTests
BUNDLE_EXTENSION = .bundle

GSOpenSaveUnitTests_OBJC_FILES = \
	GSOpenSaveModeTests.m

ADDITIONAL_INCLUDE_DIRS += -I../../Headers
ADDITIONAL_LIB_DIRS += -L../../Source/$(GNUSTEP_OBJ_DIR_NAME)
ADDITIONAL_LIB_DIRS += -L/usr/GNUstep/System/Library/Libraries
ADDITIONAL_GUI_LIBS += -lXCTest -lOpenSave
ADDITIONAL_OBJC_LIBS += -ldispatch

include $(GNUSTEP_MAKEFILES)/bundle.make
