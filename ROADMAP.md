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
- Per-page **Edit / Draw** mode toggle gates the block layer vs. the ink layer (the two-layer "typed + ink on one page" architecture). *Superseded by the Apple Notes-style markup flow below — the gating survives, the visible tabs don't.*

### M3 — Block editor (built ahead of schedule)
- All 10 block types render and edit inline: heading, paragraph, bullet/numbered list, checkbox, divider, callout, quote, image (placeholder), and **table** (JSON-backed editable grid).
- Drag-to-reorder and swipe-to-delete.
- Sectioned "add block" menu, empty-state hint, typography/spacing pass.

### Page templates (not in the original plan — added to cover Notion-style "day planner" / "course page" use cases)
- Template picker on "New Page": **Blank**, **Day Planner**, **Course Landing Page** (info table, syllabus, week-by-week calendar, assignments), **Weekly Study Planner**, **Lecture/Cornell Notes**, **Reading & Assignment Tracker**.
- Deliberately *not* a real Notion-style database (no custom properties, no calendar/board views over live data) — see "Not yet planned" below.

### Undo/redo
- Toolbar Undo/Redo buttons, mode-aware: routes to SwiftData's `ModelContext.undoManager` while typing, and the ink canvas's own `UndoManager` while marking up.

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
- **Handwritten template** in the New Page picker; canvas pages open with markup active, and flipping past the last page continues the same kind.
- **Text boxes** on canvas pages: freely positioned, dragged by a grip handle (so dragging never fights text editing), width presets, context-menu delete, cascade-deleted with the page; rendered in PDF export/thumbnails at their stored positions.

### iPad touch ergonomics (`feature/ipad-ergonomics`)
- All icon buttons, the markup toggle, and ink-toolbar controls brought up to the 44pt minimum touch target (small visuals keep 44pt hit frames where a big glyph would look heavy).
- Page rows gained swipe actions (favorite / rename / delete) so no essential action is long-press-only; list rows and property chips loosened for finger use.
- Text-box grip bar enlarged for fingertip dragging.

### Apple Notes-style unified editing (`feature/apple-notes-editing`)
- The visible **Edit / Draw tabs are gone**: a page is always typeable, like Apple Notes.
- Drawing is a **markup state**: one pencil-tip toggle in the top bar (⌘D) enters/exits it; the ink toolbar appears at the bottom while active.
- **Pencil-to-paper auto-entry**: touching the page with an Apple Pencil activates markup automatically (a non-consuming pencil-only recognizer on the page's scroll container); the activating touch itself doesn't ink — strokes land from the next touch on. Finger input keeps typing/scrolling as before.
- Under the hood the deterministic layer gating is unchanged (hit-testing swaps between block layer and ink canvas); only the visible mode UI was replaced.

### Liquid Glass setting (`feature/liquid-glass-setting`)
- Opt-in **Liquid Glass** toggle in Settings → Appearance (iOS 26+ only; hidden on older systems), off by default.
- When on, only the floating drawing chrome — ink toolbar, its status pill, and the inactive markup button — renders as the system glass material via a shared `floatingChrome(in:)` helper; layout, controls, and the flat editorial look everywhere else are unchanged.

### Image blocks (`feature/image-blocks`)
- The block editor's last placeholder is real: image blocks hold a photo picked from the library (PhotosPicker), rendered inline; empty ones show a dashed "Add a photo" target.
- Long-press to replace or remove; oversized photos are downscaled/re-encoded (~1600pt JPEG) before hitting the store (`.externalStorage`, CloudKit-safe optional).
- Images render in PDF export and thumbnails, ride page/block duplication, and are offered by the slash menu (previously excluded).

### Content search (`feature/content-search`)
- Library search matches block text, not just page titles, and shows an excerpt centered on the hit.

### Nested sub-pages (`feature/nested-pages`)
- Pages can nest inside other pages (`Page.parentPage`/`subpages`, cascade delete), independent of notebook grouping.
- The page-link block offers "New sub-page" alongside "Link a page…", creating and jumping straight into a child page.
- The page list shows nested pages as expandable/collapsible rows under their parent (`PageOutline.visible`, mirroring the toggle-block collapse logic).

### Inline rich text formatting (`feature/rich-text`)
- Block text supports markdown-style inline markers — `**bold**`, `*italic*`, `__underline__`, `~~strikethrough~~`, `` `code` ``, `==highlight==` — parsed by a pure, unit-tested `RichText` helper.
- Rendered as real styling (bold weight, italic, underline, strikethrough, monospaced, yellow highlight background) whenever a block isn't focused; editing drops back to the raw markers so typing stays a plain `TextField` (SwiftUI has no native live-formatting text view).
- Applies to heading, paragraph, bullet/numbered list, callout, and quote blocks; renders in PDF export too. Checkbox/toggle/code blocks stay plain text.

### @-mentions (`feature/mentions`)
- Typing `@` inline (anywhere in a textual block, not just at the start) opens a filter-as-you-type menu offering Today/Tomorrow date mentions plus any page whose title matches.
- Resolves to a stable inline token (`@[[Title|PAGE:uuid]]` / `@[[date|DATE:iso]]`) stored in plain `textContent`, parsed by `RichText` alongside the style markers and rendered as an accent-tinted pill.
- v1 scope: mentions are a styled inline reference, not yet tap-to-navigate (consistent with how all formatted text currently behaves — tapping unfocused text re-enters edit mode).

### Flashcard-from-block (`feature/flashcard-from-block`)
- "Make Flashcard" in any textual block's context menu, prefilling the front from the block's text (markers/mentions stripped via `RichText.plainText`) and letting the student fill in the back before saving into an existing or brand-new deck.
- Connects the note-taking and flashcard/recall spaces, which were previously fully separate.

### Inline math notation (`feature/math-notation`)
- `RichText` now also parses `^superscript^`, `~subscript~`, `\sqrt{x}`, and `\frac{a}{b}` — typed directly like the other markers, no menu.
- Superscript/subscript render via `AttributedString.baselineOffset`; `\sqrt`/`\frac` render as a precomposed display string (√(x), a⁄b). v1 scope: no nested markers inside `\sqrt{}`/`\frac{}{}` braces.

### Function grapher (`feature/grapher`)
- New **Graph** block type: type an expression (`y = x^2 - 3`, `y = 3sin(x)`, implicit multiplication supported) and it renders a live axis + curve plot below the input.
- `MathExpression` is a small hand-written recursive-descent parser/evaluator (`+ - * / ^`, parens, `sin/cos/tan/sqrt/abs/log/ln/exp`, constants `pi`/`e`) — no third-party dependency. Domain errors (sqrt of negative, div by zero, log of non-positive) return `nil` per-point rather than drawing garbage, and the curve breaks into separate runs at discontinuities (e.g. `1/x`) instead of connecting across the asymptote.
- Fixed x domain (−10…10) with auto-scaled, outlier-clamped y range; `GraphCanvas` is shared between the live block and PDF export.

### Audio recording synced to notes (`feature/audio-sync`)
- Record lecture audio per page (`Page.audioData`/`audioDuration`, `.externalStorage`, CloudKit-safe optional) via a compact record/playback bar under the page properties.
- Every block created while a recording is active stamps `Block.audioTimestamp` — the elapsed recording time at creation. Those blocks show a small "⌇ 3:42"-style chip that seeks and plays the page's recording from that moment.
- `PageAudioController` wraps `AVAudioRecorder`/`AVAudioPlayer`; iOS-only (stubbed no-op on other platforms, matching the PencilKit pattern elsewhere). Requires `NSMicrophoneUsageDescription` (added to the Xcode build settings' generated Info.plist).
- **Needs on-device verification** — the record→stop→playback round trip couldn't be driven interactively in Simulator (no scripted-tap capability); only the static UI state and the underlying model round-trips were verified this session.

### Onboarding + TestFlight readiness (`feature/testflight-readiness`)
- First-run welcome tour (`OnboardingView`, 4 panels), gated by a persisted flag, replayable from Settings.
- First launch seeds a "Getting Started" notebook (`StarterContent`): a walkthrough page and a blank scratch canvas, so a fresh install has real content instead of an empty library.
- Settings gained an About section: app version/build string, mailto beta-feedback link.
- `PrivacyInfo.xcprivacy` added (declares UserDefaults + file-timestamp required-reason API usage). `ITSAppUsesNonExemptEncryption = NO` set so TestFlight builds skip the export-compliance prompt.

## In progress / next up

### Continuous-scroll pages + swipe paging (`feature/continuous-scroll-pages`)

GoodNotes/Notability-style page navigation: fixed-size (Letter) pages stacked in one continuous, pinch-zoomable scroll, auto-appending a blank page once you write on the current last one, plus a global preference to switch to swipe-between-single-pages instead. Full design in [`docs/plans/continuous-scroll-pages.md`](docs/plans/continuous-scroll-pages.md). A separate "whiteboard" (Freeform-style infinite 2D canvas) note type was discussed but is explicitly out of scope for this plan — still needs its own spec.

## TestFlight checklist

Code-side readiness is essentially done. What's left is mostly outside this repo:

- **App Store Connect record**: create the app listing (bundle ID `com.braydensally.Margin` already reserved via the project), fill in beta app description, screenshots (iPad required), and beta review "what to test" notes.
- **On-device verification pass** (Simulator can't do these): Pencil auto-detection, lecture-audio record/playback round trip, PDF-import ink alignment/gesture ownership, and the tap-away-to-dismiss-keyboard / draw-mode UI change from the previous session. Do this on a real iPad + Apple Pencil before the first TestFlight build.
- **App icon**: current icon is a placeholder wordmark ("M."). Fine for internal/beta testing; consider a real icon before wider distribution.
- **Archive + upload**: `xcodebuild archive` + upload via Xcode Organizer or `xcodebuild -exportArchive`/Transporter — untested from this environment since it requires a signed archive against a real provisioning profile.
- Slash menu / return-key feel on a physical keyboard (needs real keyboard, not Simulator).

## Not yet planned (per CLAUDE.md, deliberately out of v1 scope)

- **M5 — remaining polish**: pinch-zoom for PDF pages (onboarding shipped with `feature/testflight-readiness` above).
- **M6 — monetize**: StoreKit subscription + free-tier limits, App Store submission, then CloudKit sync. (The TestFlight half of M6 is in the checklist above.)
- **User-defined database properties**: custom property *types* (date/select/checkbox/text) and calendar views — the parts of "real Notion databases" that the shipped page database (tags, status, table/board views) doesn't cover. Stretch goal, not required for v1.
- **Cross-device sync**: architected for via CloudKit-compatible schema, but not enabled — deferred past v1 per plan.
