# Margin

A unified notes workspace for iPad: **Notion-style structured docs + GoodNotes/Notability-style handwritten ink, in one app.** Typed content and freehand Apple Pencil ink live on the same page — plus PDF import/annotation and nested notebook organization. Deliberately **not** AI-based.

See [`ROADMAP.md`](ROADMAP.md) for what's built and what's next, and [`Margin/CLAUDE.md`](Margin/CLAUDE.md) for the full product/architecture spec.

## Tech stack

- SwiftUI, iPad-first (also iPhone/Mac)
- **PencilKit** — ink
- **PDFKit** — PDF render + per-page ink overlay
- **SwiftData** — local-first persistence, CloudKit-compatible schema (sync deferred)
- Deployment target: iOS 17+

## Project structure

```
Margin/
  App/          entry point + ModelContainer setup
  Models/       SwiftData entities (Workspace, Notebook, Page, Block, PDFAsset)
  Views/        navigation shell, block editor, ink canvas
  Templates/    page templates (Day Planner, Course Landing Page, ...)
  Spike/        throwaway prototypes, not part of the shipped app
MarginTests/    unit tests (Swift Testing)
MarginUITests/  UI tests (XCTest)
```

## Building

Open `Margin.xcodeproj` in Xcode and run the `Margin` scheme on an iPad simulator or device, or from the command line:

```
xcodebuild -project Margin.xcodeproj -scheme Margin \
  -destination 'platform=iOS Simulator,name=iPad Pro 11-inch (M5)' build
```

Run tests:

```
xcodebuild -project Margin.xcodeproj -scheme Margin \
  -destination 'platform=iOS Simulator,name=iPad Pro 11-inch (M5)' \
  -only-testing:MarginTests test
```
