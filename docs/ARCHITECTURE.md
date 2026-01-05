# Architecture Plan

This document captures the initial design and implementation plan for
libs-OpenSave.

## Goals
- Provide native GTK/GNOME open/save dialogs while preserving the
  GNUstep/Cocoa Open/Save panel API.
- Require only relinking (no code changes) for default usage.
- Allow optional runtime switching between GTK and GNUstep dialogs.
- Keep a small proof-of-concept app for internal testing.

## Non-Goals
- Perfect parity with every GNUstep panel edge case; best-effort is
  acceptable.
- Bundling GNOME themes, fonts, or other system assets.

## High-Level Approach
- Implement replacement `NSOpenPanel` and `NSSavePanel` classes in this
  library so symbols resolve to our versions at link time.
- Default behavior uses `GtkFileChooserNative`.
- Provide a public toggle API so apps can switch modes at runtime.
- Support a GNUstep fallback build for cases where GTK dialogs are not
  desired.

## Runtime Toggle API
Public header `GSOpenSave.h`:
```objc
typedef NS_ENUM(NSInteger, GSOpenSaveMode) {
  GSOpenSaveModeGtk = 1,
  GSOpenSaveModeGNUstep = 2
};
void GSOpenSaveSetMode(GSOpenSaveMode mode);
GSOpenSaveMode GSOpenSaveGetMode(void);
```
Default mode is `GSOpenSaveModeGtk`.

## API Coverage (Best Effort)
Core methods to implement:
- `+openPanel`, `+savePanel`
- `-runModal`, `-runModalForDirectory:file:`, `-runModalForDirectory:file:types:`
- `-beginSheetModalForWindow:completionHandler:` (if available)
- `-setAllowedFileTypes:`, `-allowedFileTypes`
- `-setCanChooseDirectories:`, `-canChooseDirectories`
- `-setCanChooseFiles:`, `-canChooseFiles`
- `-setAllowsMultipleSelection:`
- `-URL`, `-URLs`, `-filename`/`-filenames` (as supported by GNUstep)
- `-setTitle:`, `-setMessage:`

## GTK Mapping (Best Effort)
- Use GTK 4 `GtkFileDialog` for dialogs.
- Map actions: open/save/select-folder.
- Map file types to `GtkFileFilter` patterns.
- Support multiple selection when requested.
- Store selected URLs and filenames in the panel instance.
- If GTK 4 is unavailable at build time, GTK dialogs are disabled and panels
  fall back to GNUstep.

## Proof-of-Concept App
- Exercise: open single file, open multiple, choose directory, save with
  extension filters, and runtime toggle.

## Build Outputs
- `libOpenSave.so`: GTK implementation (default).
- `libOpenSave-gnustep.so`: GNUstep fallback build.

## Testing and CI
- Use GNUstep-make and tools-xctest to build test bundles (`.bundle`).
- Unit tests are headless and cover mapping logic, mode switching, and
  selection state handling.
- Integration tests exercise GTK dialogs via `GtkFileChooserNative` and can be
  gated by an env var (e.g., `GS_OPENSAVE_RUN_GTK_TESTS=1`).
- Tests run via `xctest path/to/TestBundle.bundle`.
- `make run` in the PoC app target launches the test app for manual checks.
