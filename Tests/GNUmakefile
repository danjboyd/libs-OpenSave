include $(GNUSTEP_MAKEFILES)/common.make

SUBPROJECTS = \
	Unit \
	Integration

include $(GNUSTEP_MAKEFILES)/aggregate.make

GNUSTEP_SYSTEM_TOOLS_DIR := $(shell gnustep-config --variable=GNUSTEP_SYSTEM_TOOLS 2>/dev/null)
GNUSTEP_SYSTEM_LIBS_DIR := $(shell gnustep-config --variable=GNUSTEP_SYSTEM_LIBRARIES 2>/dev/null)

run-unit: all
	PATH=$(GNUSTEP_SYSTEM_TOOLS_DIR):../Source/$(GNUSTEP_OBJ_DIR_NAME):$$PATH \
	LD_LIBRARY_PATH=$(GNUSTEP_SYSTEM_LIBS_DIR):../Source/$(GNUSTEP_OBJ_DIR_NAME) \
	xctest $$(find . -name "GSOpenSaveUnitTests.bundle")

run-integration: all
	PATH=$(GNUSTEP_SYSTEM_TOOLS_DIR):../Source/$(GNUSTEP_OBJ_DIR_NAME):$$PATH \
	LD_LIBRARY_PATH=$(GNUSTEP_SYSTEM_LIBS_DIR):../Source/$(GNUSTEP_OBJ_DIR_NAME) \
	GS_OPENSAVE_RUN_GTK_TESTS=1 \
	xctest $$(find . -name "GSOpenSaveGtkTests.bundle")
