# libs-OpenSave

GNUstep library that implements the Cocoa/GNUstep Open and Save panels
using native GTK/GNOME dialogs. Includes a small proof-of-concept app
used for internal testing.

## Components
- Library: drop-in implementation of Open/Save panels for GNUstep apps.
- Proof-of-concept app: exercises dialog behavior and integration.

## Status
Early development.

## Build
Build everything:
```sh
PATH=/usr/GNUstep/System/Tools:$PATH \
LD_LIBRARY_PATH=/usr/GNUstep/System/Library/Libraries \
make
```

Run the test app:
```sh
make -C App run
```

Unit tests (see `tests/README.md` for details):
```sh
make -C Tests
```

## GTK Dependency
Native dialogs use GTK 4 (`GtkFileDialog`). If GTK 4 headers and pkg-config
files are not available, the library builds but GTK dialogs are disabled
(panels fall back to GNUstep).

## License
LGPL-2.1-or-later. See `LICENSE`.

## Assets
Asset handling policy lives in `ASSETS.md`.

## Architecture
Design and implementation plan lives in `docs/ARCHITECTURE.md`.
