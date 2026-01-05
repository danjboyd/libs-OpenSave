# Assets Policy

This document defines how we source, store, license, and maintain non-code assets
for this repository. The goal is to keep assets minimal, traceable, and safe for
redistribution in a small, single-developer project.

## Scope
- In scope: icons, screenshots, sample dialog images, mock data files, and any
  third-party binaries or media required by the proof-of-concept app.
- Out of scope: system-provided GTK/GNOME themes, fonts, or icons that are not
  redistributed with this repository.
- Architecture and planning details live in `docs/ARCHITECTURE.md`.

## Principles
- Prefer generating assets ourselves or using permissive licenses.
- Keep assets small and versioned in-repo only when necessary.
- Always document the source, license, and modifications.
- Avoid bundling system resources that are expected to exist on user machines.

## Repository Layout
- `assets/` for source assets (editable originals).
- `assets/export/` for derived assets (rendered or exported formats).
- `assets/README.md` for per-asset metadata (source, license, author, date).
- `docs/screenshots/` for documentation images used in README or releases.

## Licensing and Attribution
- Only include assets with licenses compatible with redistribution.
- Align asset licensing with GNUstep and GNOME where possible; document any
  deviations.
- Preferred asset licenses: LGPL-2.1-or-later, LGPL-3.0-or-later, CC0-1.0,
  CC-BY-4.0, CC-BY-SA-4.0.
- Rationale: LGPL keeps the library linkable by proprietary apps while requiring
  modifications to the library itself to remain open.
- Each asset must have:
  - Source URL or origin description.
  - License identifier and full text if required.
  - Author/creator and modification notes.
- If attribution is required, record it in `assets/README.md` and mention it in
  `README.md`.

## Creation and Modification
- Prefer ASCII filenames with kebab-case.
- Do not edit exported files directly; update the source and re-export.
- Keep editable source formats (e.g., SVG, XCF) in `assets/`.
- Maintain deterministic export steps (documented in `assets/README.md`).

## Proof-of-Concept App Assets
- Keep proof-of-concept assets minimal and focused on testing functionality.
- Use generic, non-branded icons.
- Keep screenshots for documentation in `docs/screenshots/`.
- If sample files are required for dialog testing, keep them small and clearly
  named (e.g., `sample-text.txt`, `sample-image.png`).

## Third-Party Assets and Binaries
- Avoid committing third-party binaries unless strictly necessary.
- If required, document checksum and provenance.
- Prefer build-time or system-provided dependencies over vendored assets.

## Review Checklist
- Source and license documented?
- Redistributable and compatible with project license?
- File size reasonable?
- Stored in correct directory?

## Updates
- Update this policy when project scope or distribution model changes.

## Development Process
- Before asking for manual app runs, build the app and run the full test suite
  to ensure all tests are green.
- When the app is run manually, stdout and stderr will be captured to
  `./debug.log` via a pipe to `tee` for later review.
- Track unresolved issues in `OpenIssues.md`.
