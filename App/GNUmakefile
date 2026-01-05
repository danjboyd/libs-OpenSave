include $(GNUSTEP_MAKEFILES)/common.make

APP_NAME = OpenSaveTest

OpenSaveTest_OBJC_FILES = \
	main.m \
	AppDelegate.m

ADDITIONAL_INCLUDE_DIRS += -I../Headers
ADDITIONAL_LIB_DIRS += -L../Source/$(GNUSTEP_OBJ_DIR_NAME)
ADDITIONAL_LIB_DIRS += -L/usr/GNUstep/System/Library/Libraries
ADDITIONAL_GUI_LIBS += -lOpenSave
ADDITIONAL_OBJC_LIBS += -ldispatch

include $(GNUSTEP_MAKEFILES)/application.make

run: all
	LD_LIBRARY_PATH=/usr/GNUstep/System/Library/Libraries:../Source/$(GNUSTEP_OBJ_DIR_NAME) \
	$(GNUSTEP_BUILD_DIR)/$(APP_NAME).app/$(GNUSTEP_TARGET_LDIR)/$(APP_NAME)$(EXEEXT)

debug: all
	LD_LIBRARY_PATH=/usr/GNUstep/System/Library/Libraries:../Source/$(GNUSTEP_OBJ_DIR_NAME) \
	gdb --args $(GNUSTEP_BUILD_DIR)/$(APP_NAME).app/$(GNUSTEP_TARGET_LDIR)/$(APP_NAME)$(EXEEXT)
