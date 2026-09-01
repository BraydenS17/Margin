# Margin

A unified notes workspace for iPad: **Notion-style structured docs + GoodNotes/Notability-style handwritten ink, in one app.** The defining feature is that typed structured content and freehand Apple Pencil ink live on the *same page* — plus PDF import + annotation and nested notebook organization. Deliberately **not** AI-based.

Build status lives in [`../ROADMAP.md`](../ROADMAP.md) — keep it updated as features land; this file is the stable product/architecture spec.

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

A page's **background** is blank/ruled/grid *or* an imported **PDF page**. PDF annotation is just "a page whose background is a PDF page and whose primary interaction is ink" — this unifies all three MVP pillars under one `Page` model. Input follows Apple Notes: the page is always typeable, and drawing is a markup state entered via a single pencil-tip toggle or automatically when an Apple Pencil touches the page (a non-consuming pencil-only gesture observer); the two layers still swap hit-testing so the gesture conflicts stay resolved deterministically.

Data model: `Workspace → Notebook (nestable) → Page → Block`, plus `PDFAsset` (imported file + per-page mapping to `Page`s).

## MVP (v1) — build in this order

1. **M1 — Foundations:** SwiftData model, workspace/notebook/page navigation shell (`NavigationSplitView`), blank-page rendering.
2. **M2 — Ink engine:** PencilKit overlay on a blank page, tools (pen/highlighter/eraser, color, width), undo/redo, persist `PKDrawing`.
3. **M3 — Block editor:** typed block model + native rich text per block, add/reorder/delete, two-layer composited page + markup (draw) state.
4. **M4 — PDF:** import, per-page ink overlay (watch zoom/pixelation + gesture-conflict pitfalls), annotated-PDF export.
5. **M5 — Organization & polish:** nested notebooks, reorder/move, search, thumbnails, export/share, onboarding.
6. **M6 — Beta & monetize:** TestFlight, StoreKit subscription + free-tier limits, App Store submission, then CloudKit sync.

## Biggest technical risk (resolved)

**Ink over a zoomed PDF page** was the original risk: `PKCanvasView` doesn't zoom with `PDFView`'s scroll view, and touches can get swallowed by PDF scroll gestures. A spike (`Spike/PDFInkSpikeView.swift`, kept as reference) explored the `PDFPageOverlayViewProvider` route; the shipped M4 design sidesteps it entirely — imported PDF pages render as a static rasterized background, so the ink layer model is identical to every other page. Trade-off: no pinch-zoom on PDF pages in v1.

## Current status

M1–M4 are done, plus most of M5 and substantial unplanned features (page templates, page database with tags/status/table/board views, canvas pages with text boxes, rich text + math markers, @-mentions, flashcards, function grapher, lecture-audio sync, onboarding). Code-side TestFlight readiness is done; what remains is mostly outside the repo (App Store Connect record, on-device verification, signed archive). See [`../ROADMAP.md`](../ROADMAP.md) for the full feature-by-feature status and the TestFlight checklist.

## File layout

```
Margin/Margin/           # app target source
  App/                   # entry point + ModelContainer setup
  Models/                # SwiftData entities + non-UI helpers (RichText, MathExpression, audio)
  Views/                 # navigation shell, block editor, ink canvas, library, settings
  DesignSystem/          # Modern Editorial theme, shared UI modifiers
  Export/                # PDF export + import pipelines
  Templates/             # page templates + first-run starter content
  Spike/                 # throwaway prototypes (debug-only, not shipped)
Margin/MarginTests/      # unit tests (Swift Testing)
Margin/MarginUITests/    # UI tests (XCTest)
```
