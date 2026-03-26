include $(GNUSTEP_MAKEFILES)/common.make

LIBRARY_NAME = OpenSave

OpenSave_OBJC_FILES = \
	GSOpenSave.m \
	OpenSavePanels.m \
	GSOpenSaveBackend.m \
	GSOpenSaveGtk.m \
	GSOpenSaveWin32.m

OpenSave_HEADER_FILES = GSOpenSave.h
OpenSave_HEADER_FILES_DIR = ../Headers

OpenSave_LIBRARIES_DEPEND_UPON = -lgnustep-gui -lgnustep-base
GNUSTEP_SYSTEM_LIBS_DIR := $(shell gnustep-config --variable=GNUSTEP_SYSTEM_LIBRARIES 2>/dev/null)
ifneq ($(GNUSTEP_SYSTEM_LIBS_DIR),)
  ADDITIONAL_LIB_DIRS += -L$(GNUSTEP_SYSTEM_LIBS_DIR)
endif
OpenSave_LIBRARIES_DEPEND_UPON += -ldispatch

ADDITIONAL_INCLUDE_DIRS += -I../Headers

GTK4_CFLAGS := $(shell pkg-config --cflags gtk4 2>/dev/null)
GTK4_LIBS := $(shell pkg-config --libs gtk4 2>/dev/null)
ifneq ($(GTK4_CFLAGS),)
  ADDITIONAL_OBJCFLAGS += $(GTK4_CFLAGS) -DGS_OPENSAVE_HAVE_GTK4=1
  OpenSave_LIBRARIES_DEPEND_UPON += $(GTK4_LIBS)
endif

ifneq (,$(findstring mingw,$(GNUSTEP_HOST_OS)))
  ADDITIONAL_OBJCFLAGS += -include sys/types.h "-Dmode_t=unsigned short" -DGS_OPENSAVE_HAVE_WIN32=1
  OpenSave_LIBRARIES_DEPEND_UPON += -lcomdlg32 -lshell32 -lole32 -luuid
endif

include $(GNUSTEP_MAKEFILES)/library.make
