#
# Top-level GNUmakefile for libs-OpenSave
#

ifeq ($(GNUSTEP_MAKEFILES),)
 GNUSTEP_MAKEFILES := $(shell gnustep-config --variable=GNUSTEP_MAKEFILES 2>/dev/null)
endif

ifeq ($(GNUSTEP_MAKEFILES),)
  $(error You need to set GNUSTEP_MAKEFILES before compiling!)
endif

include $(GNUSTEP_MAKEFILES)/common.make

PACKAGE_NAME = libs-OpenSave

SUBPROJECTS = \
	Source \
	App \
	Tests

include $(GNUSTEP_MAKEFILES)/aggregate.make
