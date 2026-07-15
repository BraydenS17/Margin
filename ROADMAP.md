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

### M4 — PDF import & annotation (`feature/pdf-import`)
- Import a PDF from Files; one `PDFAsset` + one Page per PDF page (background `.pdf`, `pdfPageIndex` mapping).
- Pages render the source PDF page as a static rasterized background — the layer model stays identical to other pages, so ink annotation works unchanged and the spike's PDFView gesture-ownership risk is designed out entirely. Trade-off: no pinch-zoom in v1.
- Export of an imported page produces the source PDF page with ink composited on top (aspect preserved).
- Because no live PDFView is used, the on-device spike verification is no longer a gate; the `Spike/` prototype remains only as reference for a future zoomable viewer.

### Sub-notebooks (`feature/sub-notebooks`)
- "New Sub-notebook" in the notebook context menu — the nesting the model always supported, now creatable in UI.

### Notion-style block editor (`feature/notion-editor`)
- **Slash commands**: typing `/` in any textual block opens an inline, filter-as-you-type block menu that converts the block in place.
- **Return-key flow**: return splits the block at the caret into a new focused block; lists continue their type, return on an empty list item exits to a paragraph.
- **Toggle blocks**: collapsible headers that hide the blocks indented beneath them (nesting supported).
- **Code blocks**: monospaced, autocorrect-off surface.
- **Page links + backlinks**: a block that jumps to any page in any notebook, with "Linked From" chips on the target page.

### Page database (`feature/page-database`) — the "personal database" milestone
- **Tags**: many-to-many labels on pages (`Tag` model), created/applied from a properties bar under the page title; colors auto-assigned.
- **Status property**: per-page study status (Unsorted / In Progress / Needs Review / Mastered).
- **Index space**: a Library card opening the page database — every page across every notebook in a **Table** view (notebook, tags, status, recency) or a **Board** view (kanban columns by status), filterable by notebook and tag; status editable from context menus; rows/cards open the page directly.
- This supersedes the old "no real database" caveat: properties + views over live pages now exist. Still out of scope: user-defined property *types* and calendar views.

### Handwritten pages (`feature/handwritten-pages`)
- **Page kinds**: every page is a `document` (block editor) or a `canvas` (dedicated drawing surface — no block editor, no default text edit at all).
- **Handwritten template** in the New Page picker; canvas pages open in Draw mode, and flipping past the last page continues the same kind.
- **Text boxes** on canvas pages: freely positioned, dragged by a grip handle (so dragging never fights text editing), width presets, context-menu delete, cascade-deleted with the page; rendered in PDF export/thumbnails at their stored positions.

### iPad touch ergonomics (`feature/ipad-ergonomics`)
- All icon buttons, the mode toggle, and ink-toolbar controls brought up to the 44pt minimum touch target (small visuals keep 44pt hit frames where a big glyph would look heavy).
- Page rows gained swipe actions (favorite / rename / delete) so no essential action is long-press-only; list rows and property chips loosened for finger use.
- Text-box grip bar enlarged for fingertip dragging.

### Image blocks (`feature/image-blocks`)
- The block editor's last placeholder is real: image blocks hold a photo picked from the library (PhotosPicker), rendered inline; empty ones show a dashed "Add a photo" target.
- Long-press to replace or remove; oversized photos are downscaled/re-encoded (~1600pt JPEG) before hitting the store (`.externalStorage`, CloudKit-safe optional).
- Images render in PDF export and thumbnails, ride page/block duplication, and are offered by the slash menu (previously excluded).

## In progress / next up

- **On-device check of Pencil auto-detection** (Simulator can't produce real Pencil touches).
- Slash menu / return-key feel on a physical keyboard, and Pencil features (see deferred device checks).

## Not yet planned (per CLAUDE.md, deliberately out of v1 scope)

- **M5 — remaining polish**: onboarding, pinch-zoom for PDF pages.
- **M6 — Beta & monetize**: TestFlight, StoreKit subscription + free-tier limits, App Store submission, then CloudKit sync.
- **Real Notion-style databases**: custom properties (date/select/checkbox/text) on a live collection, with table/calendar/board views over that data — distinct from the static block-based templates shipped above. Explicitly scoped as a stretch goal, not required for v1; would be its own milestone if pursued.
- **Image blocks**: currently a placeholder in the block editor, no picker/storage implemented.
- **Cross-device sync**: architected for via CloudKit-compatible schema, but not enabled — deferred past v1 per plan.
