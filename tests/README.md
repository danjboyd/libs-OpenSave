# Tests

This repository uses GNUstep-make and tools-xctest for unit and integration
tests. Tests are compiled as `.bundle` targets and executed with `xctest`.

## Structure
- `Tests/Unit/`: headless unit tests.
- `Tests/Integration/`: GTK dialog integration tests.

## Running Tests
From MSYS2 `clang64` shell:
```sh
source /clang64/share/GNUstep/Makefiles/GNUstep.sh
```

Build tests:
```sh
make -C Tests
```

Run unit tests:
```sh
make -C Tests run-unit
```

Run GTK integration tests (optional):
```sh
make -C Tests run-integration
```

## Proof-of-Concept App
To launch the test app for manual checks:
```sh
make -C App run
```
