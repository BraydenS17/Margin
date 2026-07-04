# Roadmap

Status against the milestone plan in [`Margin/CLAUDE.md`](Margin/CLAUDE.md). Milestones are M1–M6; anything not under a milestone below was built opportunistically ahead of plan.

## Done

### M1 — Foundations
- SwiftData model: `Workspace → Notebook (nestable) → Page → Block`, plus `PDFAsset`. CloudKit-compatible (optional relationships, explicit inverses, defaulted attributes, enums stored as raw `String`).
- Navigation shell: 3-column `NavigationSplitView` (notebooks → pages → page detail), nested notebooks, add/delete/reorder.
- Blank/ruled/grid page background rendering.

### M2 — Ink engine
- PencilKit overlay (`PKCanvasView`) on the page, with the system `PKToolPicker` (pen/highlighter/eraser, color, width).
- Undo/redo, debounced persistence of `PKDrawing` to `Page.inkData`.
- Per-page **Edit / Draw** mode toggle gates the block layer vs. the ink layer (the two-layer "typed + ink on one page" architecture).

### M3 — Block editor (built ahead of schedule)
- All 10 block types render and edit inline: heading, paragraph, bullet/numbered list, checkbox, divider, callout, quote, image (placeholder), and **table** (JSON-backed editable grid).
- Drag-to-reorder and swipe-to-delete.
- Sectioned "add block" menu, empty-state hint, typography/spacing pass.

### Page templates (not in the original plan — added to cover Notion-style "day planner" / "course page" use cases)
- Template picker on "New Page": **Blank**, **Day Planner**, **Course Landing Page** (info table, syllabus, week-by-week calendar, assignments), **Weekly Study Planner**, **Lecture/Cornell Notes**, **Reading & Assignment Tracker**.
- Deliberately *not* a real Notion-style database (no custom properties, no calendar/board views over live data) — see "Not yet planned" below.

### Undo/redo
- Toolbar Undo/Redo buttons, mode-aware: routes to SwiftData's `ModelContext.undoManager` in Edit mode, and the ink canvas's own `UndoManager` in Draw mode.

### PDF-over-ink zoom spike (risk de-risking ahead of M4)
- Throwaway prototype (`Margin/Spike/PDFInkSpikeView.swift`, debug-only) proving out `PDFPageOverlayViewProvider` + per-page `PKCanvasView` overlay.
- **Finding:** the zoom/blur mitigation is architecturally sound (PencilKit strokes are vector, re-rendered crisp at any size). The **open risk is gesture ownership** — whether `PDFView`'s pan/pinch recognizers swallow Pencil touches meant for the canvas. This needs real iPad + Apple Pencil testing (untestable in Simulator) before M4 work starts.

### M5 items landed early (each on its own `feature/*` branch, merged)
- **Search** (`feature/search`): sidebar search field, live title match across all notebooks, tap-to-open.
- **Rename** (`feature/rename`): context-menu rename for notebooks and pages via a reusable alert modifier.
- **Page appearance** (`feature/page-appearance`): switch a page's background (blank/ruled/grid) after creation; `.pdf` reserved for import.
- **PDF export** (`feature/export-pdf`): share a page as a single-page PDF — static block rendition composited with the rasterized ink layer. Known v1 limit: fixed 612pt layout width means ink can drift slightly vs. on-screen text position.
- **Page thumbnails** (`feature/page-thumbnails`): live miniatures (blocks + ink) in the page list, generated through the same export pipeline and cached.

### Ink & Pencil
- Pencil vs. finger detection (Notability-style palm rejection): Auto/Finger+Pencil/Pencil-Only input modes, auto-switching to pencil-only on first real Pencil touch. Needs real-device confirmation.
- Modern Editorial design system (custom flat chrome, no system tool picker / Liquid Glass).

### Tests
- 18 unit tests (Swift Testing): model relationships, cascade deletes, `PageBackground`/`BlockType` raw-value round-tripping and fallback, table JSON round-tripping, template-to-block instantiation, PDF export validity.
- Functional UI tests (XCTest): notebook creation, page creation, navigation.

## In progress / next up

- **Real on-device verification of the PDF-over-ink spike** — 5 minutes with an iPad + Apple Pencil to confirm strokes stay crisp/aligned at zoom and Pencil-down never triggers PDF scroll. Gates the start of M4.
- **On-device check of Pencil auto-detection** (Simulator can't produce real Pencil touches).

## Not yet planned (per CLAUDE.md, deliberately out of v1 scope)

- **M4 — PDF import/annotation**: import a PDF, per-page ink overlay, annotated-PDF export. Blocked on the spike verification above.
- **M5 — remaining polish**: reorder/move across notebooks, onboarding.
- **M6 — Beta & monetize**: TestFlight, StoreKit subscription + free-tier limits, App Store submission, then CloudKit sync.
- **Real Notion-style databases**: custom properties (date/select/checkbox/text) on a live collection, with table/calendar/board views over that data — distinct from the static block-based templates shipped above. Explicitly scoped as a stretch goal, not required for v1; would be its own milestone if pursued.
- **Image blocks**: currently a placeholder in the block editor, no picker/storage implemented.
- **Cross-device sync**: architected for via CloudKit-compatible schema, but not enabled — deferred past v1 per plan.
