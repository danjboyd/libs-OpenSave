# libs-OpenSave

GNUstep library that implements the Cocoa/GNUstep Open and Save panels
using native platform dialogs (GTK/GNOME on Linux, Win32 dialogs on
Windows). Includes a small proof-of-concept app used for internal testing.

## Components
- Library: drop-in implementation of Open/Save panels for GNUstep apps.
- Proof-of-concept app: exercises dialog behavior and integration.

## Status
Early development.

## Build
Build everything from a GNUstep-configured shell.

MSYS2 `clang64` example:
```sh
source /clang64/share/GNUstep/Makefiles/GNUstep.sh
make
```

Run the test app:
```sh
make -C App run
```

Unit tests (see `Tests/README.md` for details):
```sh
make -C Tests run-unit
```

## Native Backend Dependencies
- Linux: GTK 4 (`GtkFileDialog`) is used when `pkg-config gtk4` is available.
- Windows (MSYS2 MinGW/clang toolchains): native Win32 dialogs are used.

When no native backend is available, panels fall back to GNUstep dialogs.

## License
LGPL-2.1-or-later. See `LICENSE`.

## Assets
Asset handling policy lives in `ASSETS.md`.

## Architecture
Design and implementation plan lives in `docs/ARCHITECTURE.md`.
