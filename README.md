# Margin

A unified notes workspace for iPad: **Notion-style structured docs + GoodNotes/Notability-style handwritten ink, in one app.** Typed content and freehand Apple Pencil ink live on the same page — plus PDF import/annotation and nested notebook organization. Deliberately **not** AI-based.

See [`ROADMAP.md`](ROADMAP.md) for what's built and what's next, and [`Margin/CLAUDE.md`](Margin/CLAUDE.md) for the full product/architecture spec.

## Future idea: toolkits

Major-specific feature packs (e.g. circuit-design tools for EE students, dosage-calc tables for nursing) toggled on per user, instead of cluttering the base app for everyone. Not committed or scoped — worth revisiting post-launch once there's real data on which majors/programs are actually using the app. Note: true third-party installable plugins aren't viable on iOS (App Store guidelines block downloading executable code post-install), so this would have to be app-bundled feature packs unlocked by a setting, not a real plugin marketplace.

## Tech stack

- SwiftUI, iPad-first (also iPhone/Mac)
- **PencilKit** — ink
- **PDFKit** — PDF render + per-page ink overlay
- **SwiftData** — local-first persistence, CloudKit-compatible schema (sync deferred)
- Deployment target: iOS 17+

## Project structure

```
Margin/
  App/           entry point + ModelContainer setup
  Models/        SwiftData entities (Workspace, Notebook, Page, Block, PDFAsset, Tag,
                 Deck, ...) plus non-UI helpers (RichText, MathExpression, audio)
  Views/         navigation shell, block editor, ink canvas, library, settings
  DesignSystem/  theme (Modern Editorial), shared UI modifiers
  Export/        PDF export + PDF import pipelines
  Templates/     page templates (Day Planner, Course Landing Page, ...) + starter content
  Spike/         throwaway prototypes, not part of the shipped app
MarginTests/     unit tests (Swift Testing)
MarginUITests/   UI tests (XCTest)
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
