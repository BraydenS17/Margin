# Margin

A unified notes workspace for iPad: **Notion-style structured docs + GoodNotes/Notability-style handwritten ink, in one app.** The defining feature is that typed structured content and freehand Apple Pencil ink live on the *same page* — plus PDF import + annotation and nested notebook organization. Deliberately **not** AI-based.

Full plan: `~/.claude/plans/can-you-come-up-precious-dongarra.md`

## Product

- **Target user:** university/high-school students taking notes on iPad + Apple Pencil, especially annotating lecture slides/PDFs.
- **Monetization:** freemium subscription (~$2–5/mo), free tier capped on notebook/PDF page count.
- **Non-goals for v1:** AI features (explicitly excluded), real-time collaboration, Windows/Android/web, cross-device sync (architected for, shipped later).

## Tech stack

- iPad-first native (also iPhone/Mac), **SwiftUI**
- **PencilKit** (`PKCanvasView`/`PKDrawing`) — ink
- **PDFKit** (`PDFView`/`PDFPage`) — PDF render + per-page ink overlay
- Rich text: native SwiftUI (`AttributedString`/`TextEditor`, iOS 17+/26 APIs) per block
- **SwiftData** — local-first persistence; **CloudKit sync deferred** past v1 but the schema must stay CloudKit-compatible (optional relationships, explicit inverses, defaulted attributes, no enum-typed attributes — store enums as raw `String`)
- Deployment target: iOS 17+

## Architecture — the core idea

Every `Page` is two composited layers:
1. **Content layer** — ordered `Block`s (typed, structured; the "Notion" half)
2. **Ink layer** — a full-page `PKCanvasView` overlay (freehand; the "GoodNotes" half)

A page's **background** is blank/ruled/grid *or* an imported **PDF page**. PDF annotation is just "a page whose background is a PDF page and whose primary interaction is ink" — this unifies all three MVP pillars under one `Page` model. A per-page mode toggle switches Pencil input between "edit blocks" and "draw ink" to avoid gesture conflicts (no heuristics in v1).

Data model: `Workspace → Notebook (nestable) → Page → Block`, plus `PDFAsset` (imported file + per-page mapping to `Page`s).

## MVP (v1) — build in this order

1. **M1 — Foundations:** SwiftData model, workspace/notebook/page navigation shell (`NavigationSplitView`), blank-page rendering.
2. **M2 — Ink engine:** PencilKit overlay on a blank page, tools (pen/highlighter/eraser, color, width), undo/redo, persist `PKDrawing`.
3. **M3 — Block editor:** typed block model + native rich text per block, add/reorder/delete, two-layer composited page + draw/edit toggle.
4. **M4 — PDF:** import, per-page ink overlay (watch zoom/pixelation + gesture-conflict pitfalls), annotated-PDF export.
5. **M5 — Organization & polish:** nested notebooks, reorder/move, search, thumbnails, export/share, onboarding.
6. **M6 — Beta & monetize:** TestFlight, StoreKit subscription + free-tier limits, App Store submission, then CloudKit sync.

## Biggest technical risk

**Ink over a zoomed PDF page.** `PKCanvasView` doesn't zoom with `PDFView`'s scroll view — strokes can go blurry/misaligned at zoom, and touches can get swallowed as PDF scroll gestures instead of reaching the canvas. Mitigate via PDFKit's per-page overlay provider, driving canvas scale from PDF zoom, and disabling `usePageViewController`. **Spike this before investing in M3/M4** — a throwaway prototype proving ink stays crisp and aligned at zoom.

## Current status

- Xcode project created (SwiftUI, SwiftData storage, no CloudKit yet, own git repo at this path).
- **Not yet re-added:** the SwiftData model (`Workspace`/`Notebook`/`Page`/`Block`/`PDFAsset`) and the navigation shell were scaffolded once but got overwritten by Xcode's project creation — only the default `MarginApp.swift`/`ContentView.swift` exist right now. Next step is re-adding the model + shell, then doing the ink-over-PDF spike before M2.

## File layout (once re-scaffolded)

```
Margin/Margin/          # app target source
  App/                  # entry point + ModelContainer setup
  Models/                # SwiftData entities
  Views/                 # navigation shell, editor, ink, PDF views (as they land)
