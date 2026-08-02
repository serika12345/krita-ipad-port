# Initial feature scope

## P0: required for the first useful build

- New/open/save/save-as for KRA, ORA, PNG, and JPEG.
- Pixel brush and eraser with presets.
- Freehand/basic shape, selection, move, transform, crop, fill, and gradient tools.
- Layer operations, undo/redo, canvas pan/zoom/rotate.
- Layer, Brush Presets, Tool Options, Advanced Color Selector, and touch UI.
- Apple Pencil pressure and separation of Pencil drawing from finger gestures.
- Files document picker, autosave recovery, background/foreground restoration.

## P1: after the first useful build

- Additional Krita brush engines and common filters.
- Resource bundle import/export.
- Split View, Stage Manager, external keyboard, and external display polish.
- WebP/TIFF when their dependency cost is acceptable.

## Deferred

- Animation UI without audio/video export.
- OpenEXR, HEIF, JPEG XL, RAW, PDF, and uncommon import/export formats.
- Optional dockers, generators, assistants, and specialized filters.

## Excluded from the port baseline

- Python/PyQt scripting and downloadable executable plugins.
- G'MIC.
- Printing and Qt PrintSupport.
- FFmpeg/MLT/SDL audio/video processing and external process execution.
- Built-in updater and desktop integration.
- App Store/marketplace distribution, notarization, and iPhone layouts.

## Android adaptations to reuse or generalize

| Area | Existing code | iPadOS action |
|---|---|---|
| Touch scrolling/long press | `KisKineticScroller`, `KisLongPressEventFilter` | Generalize to a mobile/touch capability instead of Android macro |
| Compact main window | `KisMainWindow`, `KisWelcomePageWidget` | Extract shared tablet policy |
| File dialog behavior | `KoFileDialog`, recent files | Reuse UX policy; replace Android URI handling with UIDocumentPicker |
| Resource locations | `KoResourcePaths`, Android asset setup | Reuse container-safe assumptions; implement Apple bundle paths |
| High-DPI/canvas setup | Android branches in UI/OpenGL | Validate and move shared parts behind a mobile feature flag |
| Text input | Android SVG text tool branches | Reuse intent; implement iOS keyboard bridge separately |
| Logging/crash handling | Android log handlers | Implement OSLog equivalent, not JNI code |
| Recorder/video | extensive Android specialization | Exclude from the initial port |
