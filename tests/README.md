# Tests

This repository uses GNUstep-make and tools-xctest for unit and integration
tests. Tests are compiled as `.bundle` targets and executed with `xctest`.

## Structure
- `tests/unit/`: headless unit tests.
- `tests/integration/`: GTK dialog integration tests.

## Running Tests
Ensure `.gnustep-test.conf` exists and is only writable by its owner:
```sh
chmod 600 .gnustep-test.conf
```

Build and run unit tests:
```sh
make -C Tests
GNUSTEP_CONFIG_FILE=./.gnustep-test.conf \
LD_LIBRARY_PATH=/usr/GNUstep/System/Library/Libraries:$(pwd)/Source/obj \
xctest $(find Tests -name "GSOpenSaveUnitTests.bundle")
```

Run GTK integration tests (optional):
```sh
GS_OPENSAVE_RUN_GTK_TESTS=1 \
GNUSTEP_CONFIG_FILE=./.gnustep-test.conf \
LD_LIBRARY_PATH=/usr/GNUstep/System/Library/Libraries:$(pwd)/Source/obj \
xctest $(find Tests -name "GSOpenSaveGtkTests.bundle")
```

## Proof-of-Concept App
To launch the test app for manual checks:
```sh
make -C App run
```
