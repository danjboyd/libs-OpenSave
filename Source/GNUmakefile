include $(GNUSTEP_MAKEFILES)/common.make

LIBRARY_NAME = OpenSave

OpenSave_OBJC_FILES = \
	GSOpenSave.m \
	OpenSavePanels.m \
	GSOpenSaveGtk.m

OpenSave_HEADER_FILES = GSOpenSave.h
OpenSave_HEADER_FILES_DIR = ../Headers

OpenSave_LIBRARIES_DEPEND_UPON = -lgnustep-gui -lgnustep-base
ADDITIONAL_LIB_DIRS += -L/usr/GNUstep/System/Library/Libraries
OpenSave_LIBRARIES_DEPEND_UPON += -ldispatch

ADDITIONAL_INCLUDE_DIRS += -I../Headers

GTK4_CFLAGS := $(shell pkg-config --cflags gtk4 2>/dev/null)
GTK4_LIBS := $(shell pkg-config --libs gtk4 2>/dev/null)
ifneq ($(GTK4_CFLAGS),)
  ADDITIONAL_OBJCFLAGS += $(GTK4_CFLAGS) -DGS_OPENSAVE_HAVE_GTK4=1
  OpenSave_LIBRARIES_DEPEND_UPON += $(GTK4_LIBS)
endif

include $(GNUSTEP_MAKEFILES)/library.make
