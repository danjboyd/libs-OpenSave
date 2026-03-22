# Open Issues

This file tracks known issues and unresolved questions for libs-OpenSave.
Add new entries as they are discovered and move resolved items to the bottom
or remove them.

## 2026-01-05
- GNUstep save panel hang/crash when toggled to GNUstep mode in the test app.
  Save in GTK mode works; GNUstep open panel does not crash. Needs deeper
  investigation in GNUstep GUI stack and a stable fallback strategy.

## 2026-03-22
- ~Received ScreenshotTool bug report: in GTK mode, a successful `NSOpenPanel`
  selection could leave `panel.URL` as `nil` because inherited `URL` accessors
  were swizzled unsafely between `NSOpenPanel` and `NSSavePanel`. Resolved on
  2026-03-22 by making inherited-method swizzles install subclass-local
  overrides before exchange and by adding accessor parity regressions in
  `Tests/Unit/GSOpenSavePanelAccessorTests.m`.~
