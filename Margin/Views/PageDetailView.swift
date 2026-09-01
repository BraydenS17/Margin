import SwiftUI
import SwiftData
#if os(iOS)
import UIKit
#endif

struct PageDetailView: View {
    @Bindable var page: Page
    var selectedPage: Binding<Page?>? = nil
    var onOpenPage: ((Page) -> Void)? = nil
    @Binding var columnVisibility: NavigationSplitViewVisibility
    @Environment(\.modelContext) private var modelContext

    // Apple Notes-style markup: the page is always typeable; drawing is a temporary
    // markup state entered via the pencil button or by touching the page with a Pencil.
    @State private var isDrawing = false
    @State private var inkTool: InkToolKind = .pen
    @State private var inkColor: Color = .black
    @State private var inkWidth: CGFloat = 4
    @State private var inkUndoController = InkUndoController()
    @State private var previousInkTool: InkToolKind = .pen
    @State private var pencilDetected = false
    @State private var audioController = PageAudioController()
    @AppStorage("inkInputMode") private var inputModeRaw = InkInputMode.auto.rawValue
    #if os(iOS)
    @State private var exportedFile: ExportedFile?
    #endif

    private var inputMode: InkInputMode {
        InkInputMode(rawValue: inputModeRaw) ?? .auto
    }

    private var inputModeBinding: Binding<InkInputMode> {
        Binding(
            get: { inputMode },
            set: { inputModeRaw = $0.rawValue }
        )
    }

    #if os(iOS)
    struct ExportedFile: Identifiable {
        let url: URL
        var id: URL { url }
    }
    #endif

    @State private var showingIconPicker = false

    var body: some View {
        VStack(spacing: 0) {
            topBar
            Rectangle().fill(Theme.border).frame(height: 1)
            pageArea
        }
        .background(Theme.background)
        #if os(iOS)
        .toolbar(.hidden, for: .navigationBar)
        #endif
        // Handwritten pages are drawing-first: land with markup active, not the text tools.
        .onChange(of: page.id, initial: true) { _, _ in
            isDrawing = page.kind == .canvas
        }
        .overlay(alignment: .bottom) {
            if isDrawing {
                InkToolbar(
                    tool: $inkTool,
                    color: $inkColor,
                    width: $inkWidth,
                    inputMode: inputModeBinding,
                    pencilDetected: pencilDetected
                )
                .padding(.bottom, 18)
            }
        }
    }

    private var topBar: some View {
        HStack(spacing: 10) {
            FlatIconButton(systemName: "sidebar.leading", label: "Toggle Panels") { toggleColumns() }
            FlatIconButton(systemName: "arrow.uturn.backward", label: "Undo", action: undo)
                .keyboardShortcut("z", modifiers: .command)
            FlatIconButton(systemName: "arrow.uturn.forward", label: "Redo", action: redo)
                .keyboardShortcut("z", modifiers: [.command, .shift])
            if page.background != .pdf {
                FlatIconButton(
                    systemName: page.background.systemImage,
                    label: "Background: \(page.background.displayName). Tap to change.",
                    action: cycleBackground
                )
            }
            #if os(iOS)
            FlatIconButton(systemName: "square.and.arrow.up", label: "Export PDF", action: exportPDF)
            #endif
            if !isDrawing && page.background != .pdf {
                if page.kind == .canvas {
                    FlatIconButton(systemName: "character.textbox", label: "Add Text Box", action: addTextBox)
                } else {
                    addBlockMenu
                }
            }
            Spacer()
            pageNavigator
            Spacer()
            markupToggle
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Theme.background)
        #if os(iOS)
        .sheet(item: $exportedFile) { file in
            ShareSheet(url: file.url)
        }
        #endif
    }

    #if os(iOS)
    private func exportPDF() {
        guard let url = PageExporter.writeTemporaryPDF(for: page) else { return }
        exportedFile = ExportedFile(url: url)
    }
    #endif

    private func cycleBackground() {
        let options = PageBackground.selectable
        guard let index = options.firstIndex(of: page.background) else {
            page.background = options[0]
            return
        }
        page.background = options[(index + 1) % options.count]
        page.updatedAt = Date()
    }

    /// Apple Notes-style markup button: one pencil-tip toggle instead of Edit/Draw tabs.
    /// Tapping it (or touching the page with an Apple Pencil) enters drawing; tapping it
    /// again puts the pencil away and the page is typeable again.
    private var markupToggle: some View {
        Button {
            setDrawing(!isDrawing)
        } label: {
            Image(systemName: "pencil.tip.crop.circle")
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(isDrawing ? Color.white : Theme.text)
                .frame(width: 44, height: 44)
                .background(isDrawing ? Theme.accent : Theme.surface, in: Circle())
                .overlay(Circle().strokeBorder(isDrawing ? Theme.accent : Theme.border, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .keyboardShortcut("d", modifiers: .command)
        .accessibilityLabel(isDrawing ? "Finish Markup" : "Markup")
    }

    private func setDrawing(_ drawing: Bool) {
        guard isDrawing != drawing else { return }
        isDrawing = drawing
        if drawing { dismissKeyboard() }
    }

    private var pageArea: some View {
        #if os(iOS)
        ZoomablePageView { pageContent }
        #else
        ScrollView { pageContent }
        #endif
    }

    private var pageContent: some View {
            pageBackground
                .frame(minHeight: 1000)
                .contentShape(Rectangle())
                .onTapGesture { dismissKeyboard() }
                .overlay(alignment: .top) {
                    // Imported PDF pages are annotation-first: the document itself is the
                    // content layer, so no typed title/blocks are drawn over it.
                    if page.background != .pdf {
                        VStack(alignment: .leading, spacing: 16) {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack(alignment: .firstTextBaseline, spacing: 10) {
                                    Button {
                                        showingIconPicker = true
                                    } label: {
                                        if page.icon.isEmpty {
                                            Image(systemName: "face.smiling")
                                                .font(.system(size: 19))
                                                .foregroundStyle(Theme.muted)
                                                .frame(width: 40, height: 40)
                                                .background(Theme.surface, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                                        .strokeBorder(Theme.border, lineWidth: 1)
                                                )
                                        } else {
                                            Text(page.icon)
                                                .font(.system(size: 34))
                                        }
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityLabel("Page Icon")
                                    Text(page.title)
                                        .font(.editorialDisplay(34))
                                        .foregroundStyle(Theme.text)
                                        .lineLimit(3)
                                }
                                AccentRule()
                                Text(metaLine)
                                    .metaLabel()
                                PagePropertiesBar(page: page)
                                    .padding(.top, 2)
                                if page.kind == .document {
                                    AudioBar(page: page, controller: audioController)
                                        .padding(.top, 2)
                                }
                            }
                            .padding(.horizontal, 22)
                            .padding(.top, 20)
                            if page.kind == .document {
                                BlockListView(page: page, onOpenPage: onOpenPage, audioController: audioController, isEditing: !isDrawing)
                            }
                            BacklinksView(page: page, onOpenPage: onOpenPage)
                        }
                        .allowsHitTesting(!isDrawing)
                        .sheet(isPresented: $showingIconPicker) {
                            IconPickerView(current: page.icon) { emoji in
                                page.icon = emoji
                                page.updatedAt = Date()
                            }
                        }
                    }
                }
                .overlay {
                    if page.kind == .canvas {
                        TextBoxLayer(page: page)
                            .allowsHitTesting(!isDrawing)
                    }
                }
                .overlay {
                    InkCanvasView(
                        inkData: $page.inkData,
                        tool: inkTool,
                        color: inkColor,
                        width: inkWidth,
                        inputMode: inputMode,
                        pencilDetected: $pencilDetected,
                        undoController: inkUndoController,
                        onPencilGesture: handlePencilGesture
                    )
                    // PageDetailView keeps the same view identity across page switches (it's
                    // reused at the same NavigationSplitView.detail slot), so without an
                    // explicit id tied to the page, SwiftUI reuses the same PKCanvasView and
                    // never reloads its drawing — ink then appears "stuck" on screen across
                    // pages instead of following the page's own inkData.
                    .id(page.id)
                    .allowsHitTesting(isDrawing)
                }
                #if os(iOS)
                // Touching the page with an Apple Pencil enters markup automatically,
                // the way it does in Apple Notes — no button press needed. That first
                // touch only activates markup; strokes ink from the next touch on.
                .background {
                    PencilTouchObserver {
                        setDrawing(true)
                    }
                    .allowsHitTesting(false)
                }
                #endif
    }

    private var metaLine: String {
        if isDrawing { return "markup · tap the pencil to finish" }
        if page.kind == .canvas { return "handwritten · move boxes by their grip" }
        return page.background.rawValue
    }

    /// Drops a fresh text box, staggered so consecutive boxes don't stack exactly.
    private func addTextBox() {
        let count = page.textBoxes?.count ?? 0
        let box = TextBox(
            x: 40 + Double((count % 5)) * 26,
            y: 150 + Double((count % 7)) * 34,
            page: page
        )
        modelContext.insert(box)
        page.updatedAt = Date()
    }

    private var addBlockMenu: some View {
        Menu {
            Section("Text") {
                addBlockButton(.heading)
                addBlockButton(.paragraph)
                addBlockButton(.quote)
                addBlockButton(.callout)
            }
            Section("Lists") {
                addBlockButton(.bulletList)
                addBlockButton(.numberedList)
                addBlockButton(.checkbox)
            }
            Section("Structure") {
                addBlockButton(.toggle)
                addBlockButton(.table)
                addBlockButton(.code)
                addBlockButton(.pageLink)
                addBlockButton(.image)
                addBlockButton(.graph)
                addBlockButton(.divider)
            }
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Theme.accent)
                .frame(width: 44, height: 44)
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .strokeBorder(Theme.border, lineWidth: 1)
                )
        }
        .accessibilityLabel("Add Block")
    }

    private func addBlockButton(_ type: BlockType) -> some View {
        Button {
            let count = page.blocks?.count ?? 0
            let block = Block(type: type, sortIndex: count, page: page)
            block.audioTimestamp = audioController.currentTimestamp
            modelContext.insert(block)
        } label: {
            Label(type.displayName, systemImage: type.systemImage)
        }
    }

    private var siblingPages: [Page] {
        (page.notebook?.pages ?? []).sorted { $0.sortIndex < $1.sortIndex }
    }

    /// Flip between a notebook's pages like sheets of paper. Flipping forward past the
    /// last page starts a fresh blank one, so writing never dead-ends.
    @ViewBuilder
    private var pageNavigator: some View {
        if let selectedPage {
            let pages = siblingPages
            let index = pages.firstIndex(where: { $0.id == page.id }) ?? 0
            HStack(spacing: 10) {
                FlatIconButton(systemName: "chevron.left", label: "Previous Page") {
                    guard index > 0 else { return }
                    selectedPage.wrappedValue = pages[index - 1]
                }
                .opacity(index > 0 ? 1 : 0.35)
                Text("PAGE \(index + 1) OF \(pages.count)")
                    .metaLabel()
                    .fixedSize()
                FlatIconButton(
                    systemName: index < pages.count - 1 ? "chevron.right" : "plus.square.dashed",
                    label: index < pages.count - 1 ? "Next Page" : "New Page at End"
                ) {
                    if index < pages.count - 1 {
                        selectedPage.wrappedValue = pages[index + 1]
                    } else if let notebook = page.notebook {
                        let fresh = Page(title: "Untitled Page", notebook: notebook, background: page.background, sortIndex: pages.count)
                        // Flipping past the end continues the same kind of page.
                        fresh.kind = page.kind
                        modelContext.insert(fresh)
                        selectedPage.wrappedValue = fresh
                    }
                }
            }
        }
    }

    private func toggleColumns() {
        columnVisibility = columnVisibility == .detailOnly ? .all : .detailOnly
    }

    /// Tapping anywhere outside the focused text field — blank page, background, mode
    /// switch — ends typing the same way tapping away does in Notes/Notion.
    private func dismissKeyboard() {
        #if os(iOS)
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        #endif
    }

    private func handlePencilGesture(_ action: PencilGestureAction) {
        // A Pencil gesture while typing means "I want to draw" — enter markup first.
        guard isDrawing else {
            setDrawing(true)
            return
        }
        switch action {
        case .toggleEraser:
            if inkTool == .eraser {
                inkTool = previousInkTool
            } else {
                previousInkTool = inkTool
                inkTool = .eraser
            }
        case .previousTool:
            let current = inkTool
            inkTool = previousInkTool
            previousInkTool = current
        case .cycleColor:
            let palette = InkToolbar.palette
            let index = palette.firstIndex(of: inkColor) ?? -1
            inkColor = palette[(index + 1) % palette.count]
        }
    }

    private func undo() {
        if isDrawing { inkUndoController.undo() } else { modelContext.undoManager?.undo() }
    }

    private func redo() {
        if isDrawing { inkUndoController.redo() } else { modelContext.undoManager?.redo() }
    }

    @ViewBuilder
    private var pageBackground: some View {
        switch page.background {
        case .blank:
            Rectangle().fill(Theme.background)
        case .ruled:
            RuledBackground()
        case .grid:
            GridBackground()
        case .dotted:
            DottedBackground()
        case .pdf:
            PDFPageBackgroundView(page: page)
        }
    }
}

#if os(iOS)
/// Watches for Apple Pencil contact on the page surface without consuming any touches.
///
/// The ink canvas is only hit-testable while markup is active, so something outside it
/// has to notice "the user put Pencil to paper" while they're in typing mode. This view
/// attaches a pencil-only, zero-delay recognizer to the enclosing scroll container
/// (`cancelsTouchesInView = false`, recognizes simultaneously), so it observes every
/// pencil touch on the page while finger touches and existing gestures behave as before.
private struct PencilTouchObserver: UIViewRepresentable {
    var onPencilTouch: () -> Void

    func makeUIView(context: Context) -> ObserverView {
        let view = ObserverView()
        view.onPencilTouch = onPencilTouch
        return view
    }

    func updateUIView(_ view: ObserverView, context: Context) {
        view.onPencilTouch = onPencilTouch
    }

    final class ObserverView: UIView, UIGestureRecognizerDelegate {
        var onPencilTouch: (() -> Void)?
        private weak var recognizer: UIGestureRecognizer?

        override func didMoveToWindow() {
            super.didMoveToWindow()
            if let recognizer {
                recognizer.view?.removeGestureRecognizer(recognizer)
                self.recognizer = nil
            }
            guard window != nil else { return }
            // Attach to the page's scroll container so the whole page surface is
            // observed, not just this (zero-hit-testing) background view's frame.
            var host: UIView? = superview
            while let view = host, !(view is UIScrollView) { host = view.superview }
            guard let target = host else { return }
            let press = UILongPressGestureRecognizer(target: self, action: #selector(pencilTouched(_:)))
            press.minimumPressDuration = 0
            press.allowedTouchTypes = [NSNumber(value: UITouch.TouchType.pencil.rawValue)]
            press.cancelsTouchesInView = false
            press.delaysTouchesBegan = false
            press.delegate = self
            target.addGestureRecognizer(press)
            recognizer = press
        }

        @objc private func pencilTouched(_ gesture: UIGestureRecognizer) {
            guard gesture.state == .began else { return }
            onPencilTouch?()
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            true
        }
    }
}
#endif

private struct RuledBackground: View {
    var body: some View {
        Canvas { context, size in
            let lineSpacing: CGFloat = 32
            var y: CGFloat = lineSpacing
            while y < size.height {
                var path = Path()
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
                context.stroke(path, with: .color(.gray.opacity(0.3)), lineWidth: 1)
                y += lineSpacing
            }
        }
        .background(Theme.background)
    }
}

private struct GridBackground: View {
    var body: some View {
        Canvas { context, size in
            let spacing: CGFloat = 24
            var x: CGFloat = spacing
            while x < size.width {
                var path = Path()
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
                context.stroke(path, with: .color(.gray.opacity(0.2)), lineWidth: 1)
                x += spacing
            }
            var y: CGFloat = spacing
            while y < size.height {
                var path = Path()
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
                context.stroke(path, with: .color(.gray.opacity(0.2)), lineWidth: 1)
                y += spacing
            }
        }
        .background(Theme.background)
    }
}

private struct DottedBackground: View {
    var body: some View {
        Canvas { context, size in
            let spacing: CGFloat = 26
            var y: CGFloat = spacing
            while y < size.height {
                var x: CGFloat = spacing
                while x < size.width {
                    let dot = CGRect(x: x - 1, y: y - 1, width: 2.4, height: 2.4)
                    context.fill(Path(ellipseIn: dot), with: .color(.gray.opacity(0.35)))
                    x += spacing
                }
                y += spacing
            }
        }
        .background(Theme.background)
    }
}
