include $(GNUSTEP_MAKEFILES)/common.make

BUNDLE_NAME = GSOpenSaveGtkTests
BUNDLE_EXTENSION = .bundle

GSOpenSaveGtkTests_OBJC_FILES = \
	GSOpenSaveGtkSmokeTests.m

ADDITIONAL_INCLUDE_DIRS += -I../../Headers
ADDITIONAL_LIB_DIRS += -L../../Source/$(GNUSTEP_OBJ_DIR_NAME)
GNUSTEP_SYSTEM_LIBS_DIR := $(shell gnustep-config --variable=GNUSTEP_SYSTEM_LIBRARIES 2>/dev/null)
ifneq ($(GNUSTEP_SYSTEM_LIBS_DIR),)
  ADDITIONAL_LIB_DIRS += -L$(GNUSTEP_SYSTEM_LIBS_DIR)
endif
ADDITIONAL_GUI_LIBS += -lXCTest -lOpenSave
ADDITIONAL_OBJC_LIBS += -ldispatch

include $(GNUSTEP_MAKEFILES)/bundle.make
