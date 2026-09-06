# Continuous-scroll pages + swipe paging

Status: planned, implementation starting on `feature/continuous-scroll-pages`.

## Context

Today, moving between pages in a notebook means tapping a chevron button, and a single page can already grow arbitrarily tall on screen (no real page-size boundary — Letter size only exists inside the PDF exporter). The goal is GoodNotes/Notability-style behavior instead: pages are a fixed size, stacked in one continuous scroll, and a new blank page silently appears once you start writing on the current last one — so you never hit a wall and never have to tap "new page." There's also a **global** preference to switch between that continuous-scroll mode and a "swipe left/right between single pages" mode. Confirmed decisions: preference is global (not per-notebook), page size is US Letter (612×792, matching the existing exporter constant), and — importantly — **pinch-zoom must keep working in continuous-scroll mode**, even though that's the harder path (the alternative, dropping zoom, was rejected).

## Shared groundwork

**New file `DesignSystem/PageGeometry.swift`**: `enum PageGeometry { static let width: CGFloat = 612; static let height: CGFloat = 792 }`. Update `Export/PageExporter.swift`'s `pageWidth`/`minHeight` constants to reference this instead of hardcoding — one source of truth so on-screen pages match exported PDFs exactly.

**`DesignSystem/ThemeSettings.swift`**: add `pageNavigationMode: PageNavigationMode` (`.continuousScroll` / `.paged`, default `.paged` so existing behavior is unchanged until opted in) following the exact `liquidGlass` property pattern already there (`didSet` persists to `UserDefaults`, init reads it back). Add a picker in `SettingsView.swift` (same section style as the Appearance capsule control) bound to it.

**Toolbar/chrome split** (needed by both new modes): `PageDetailView.swift` currently mixes its top bar (`pageNavigator`, undo/redo, export, markup toggle) and the per-page content (`pageArea`/`pageContent`, reset via `.id(page.id)`) in one view/state bag. Split into:
- A persistent chrome layer (top bar + the ink toolbar overlay) that operates on an **active page** rather than being rebuilt per page.
- The swappable/scrollable page content, which becomes either a `TabView` page or a row in the continuous stack.

This split is the single biggest structural change and both new modes depend on it — do it once, first.

## Paged mode (swipe)

Replace the chevron-driven single view with `TabView(selection: $selectedPage)` over `siblingPages` (same `sortIndex`-sorted list `pageNavigator` already computes), `.tabViewStyle(.page(indexDisplayMode: .never))` for native swipe physics without page dots. Each tab hosts the page-content pane (still wrapped in `ZoomablePageView` per page, unchanged — per-page zoom already works today and nothing about paged mode needs to change that). Keep the chevron buttons in the persistent chrome as an alternate way to page (tap or swipe both just change `selectedPage`/tab selection, reusing the same underlying index logic that exists today).

## Continuous-scroll mode

**New file `Views/ContinuousPageScrollView.swift`**: renders a notebook's pages, sorted by `sortIndex`, stacked vertically with a visible gap between them (PDF-style page breaks), each row's content clamped to `PageGeometry.width × PageGeometry.height` instead of today's `minHeight: 1000`. Reuse the existing per-page `pageContent` composition (blocks/ink/textboxes) unchanged inside each row — a page's ink stays local to that page (`PKDrawing` per page, not a shared canvas); "continuous" describes the scroll container only.

**Zoom**: wrap the *entire* vertical stack (not each row) in the existing `ZoomablePageView` (`Views/ZoomablePageView.swift`, a generic `UIViewRepresentable` over `UIScrollView` — already content-agnostic, so it can host the whole stack instead of one page) so pinch-zoom applies to the whole scroll the way a real PDF viewer's continuous+zoom mode works. Flag as an accepted tradeoff to verify empirically: because the stack is hosted inside a `UIScrollView` rather than a SwiftUI `ScrollView`, `LazyVStack`'s laziness may not kick in the way it would under a native `ScrollView`, meaning all pages' content (including their `PKCanvasView`s) could realize eagerly. This is fine for small-to-medium notebooks; if a large notebook (50+ pages) is sluggish, the follow-up is a proper recycling rewrite (closer to `UICollectionView`) — out of scope for v1, called out here so it isn't a surprise later.

**Selection**: `PageListView` selecting a page still sets `selectedPage`; `ContinuousPageScrollView` wraps its stack in `ScrollViewReader` and does `proxy.scrollTo(page.id, anchor: .top)` on change, and updates the chrome's "active page" (see below) so the ink toolbar follows it.

**Active page for drawing**: with many pages visible at once, only one can be "active" for the ink toolbar (matches GoodNotes — the toolbar is global, not per-page). Track `activePage` in the chrome layer, set on tap/pencil-touch within a row (reusing today's pencil-touch detection) and on scroll-driven selection; each row's canvas only accepts drawing input when it is `activePage`.

## Auto-append-on-first-edit

**New shared helper** (e.g. `Models/PageAutoAppend.swift`): a function that, given a page and its `modelContext`, checks if that page is the notebook's current last page (`sortIndex` is the max among siblings) and — if a page with `sortIndex + 1` doesn't already exist — inserts a fresh blank `Page` right after it (same construction `pageNavigator`'s existing "create if at last page" branch already does, just triggered differently and shared by both modes).

Hook it at the two points where a page transitions from empty to non-empty:
1. **Ink**: `.onChange(of: page.inkData)` at the page-row/page-pane level, firing the helper when it goes from `nil` to non-nil. (Cleaner than threading a callback through `InkCanvasView`.)
2. **Blocks**: call the helper from the same block-insert paths that already touch `page.updatedAt` (`BlockListView.swift`, `PageDetailView.swift`'s add-block flow), guarded to only matter on a transition from zero blocks.

Keep `pageNavigator`'s existing "synthesize a page if I try to go past the last one" as a fallback (it'll rarely fire once auto-append is in place, but covers a brand-new empty notebook where nothing has been edited yet).

## Canvas-kind pages

`.canvas` pages (dedicated ink pages, `TextBox`es positioned by absolute x/y) get the same fixed 612×792 bounds in both modes — clamping is strictly more correct than today's unbounded height. Note as a minor cosmetic edge case: any existing canvas page with text boxes placed below y=792 (written before any height cap existed) will now render past the visible page boundary — acceptable, no data loss.

## Critical files

- `Views/PageDetailView.swift` — chrome/content split, becomes the paged-mode tab content
- `Views/RootView.swift` — switches between paged/continuous based on `ThemeSettings.shared.pageNavigationMode`
- `Views/ZoomablePageView.swift` — reused as-is, now sometimes wrapping a multi-page stack
- `Views/ContinuousPageScrollView.swift` — new
- `DesignSystem/PageGeometry.swift` — new
- `DesignSystem/ThemeSettings.swift` / `Views/SettingsView.swift` — new preference + UI
- `Export/PageExporter.swift` — reference shared page-size constant
- `Models/PageAutoAppend.swift` — new shared helper

## Verification

- Build (`xcodebuild ... build`) after each stage.
- Manual pass in simulator/device: write to the bottom of a page in continuous mode and confirm a blank page appears below without any tap; switch the preference and confirm swipe works between pages; pinch-zoom in continuous mode across a multi-page stack; select a page from the sidebar in both modes and confirm it scrolls/switches to the right one; check a `.canvas` page with existing text boxes still looks reasonable.
- Test with a notebook with many pages (create ~50 blank pages) to sanity-check continuous-scroll scroll performance before considering this done.

## Related / not yet scoped

A "whiteboard" note type (Apple Freeform-style: infinite 2D pan/zoom canvas, freely placed/resizable ink/text/images) was discussed separately and is **not** part of this plan — see the product owner for the fuller spec before starting that one. It was initially conflated with "infinite page" but the two are distinct: this plan is about multi-page continuous scrolling of fixed-size pages, not a free-form 2D canvas.
