import SwiftUI
import SwiftData

struct PageDetailView: View {
    @Bindable var page: Page
    var selectedPage: Binding<Page?>? = nil
    var onOpenPage: ((Page) -> Void)? = nil
    @Binding var columnVisibility: NavigationSplitViewVisibility
    @Environment(\.modelContext) private var modelContext

    @State private var mode: PageMode = .edit
    @State private var inkTool: InkToolKind = .pen
    @State private var inkColor: Color = .black
    @State private var inkWidth: CGFloat = 4
    @State private var inkUndoController = InkUndoController()
    @State private var previousInkTool: InkToolKind = .pen
    @State private var pencilDetected = false
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

    enum PageMode: String, CaseIterable, Identifiable {
        case edit = "Edit"
        case draw = "Draw"
        var id: String { rawValue }
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
        .overlay(alignment: .bottom) {
            if mode == .draw {
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
            if mode == .edit && page.background != .pdf {
                addBlockMenu
            }
            Spacer()
            pageNavigator
            Spacer()
            modeToggle
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

    private var modeToggle: some View {
        HStack(spacing: 0) {
            ForEach(PageMode.allCases) { m in
                Button {
                    mode = m
                } label: {
                    Text(m.rawValue)
                        .font(.system(size: 13, weight: .bold))
                        .tracking(0.5)
                        .foregroundStyle(mode == m ? Color.white : Theme.muted)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 7)
                        .background(mode == m ? Theme.accent : Color.clear, in: Capsule())
                }
                .buttonStyle(.plain)
                .keyboardShortcut(m == .edit ? "1" : "2", modifiers: .command)
            }
        }
        .padding(3)
        .background(Theme.surface, in: Capsule())
        .overlay(Capsule().strokeBorder(Theme.border, lineWidth: 1))
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
                                                .font(.system(size: 18))
                                                .foregroundStyle(Theme.muted)
                                                .frame(width: 34, height: 34)
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
                                Text(mode == .draw ? "Draw Mode" : "\(page.background.rawValue) · edit mode")
                                    .metaLabel()
                            }
                            .padding(.horizontal, 22)
                            .padding(.top, 20)
                            BlockListView(page: page, onOpenPage: onOpenPage)
                            BacklinksView(page: page, onOpenPage: onOpenPage)
                        }
                        .allowsHitTesting(mode == .edit)
                        .sheet(isPresented: $showingIconPicker) {
                            IconPickerView(current: page.icon) { emoji in
                                page.icon = emoji
                                page.updatedAt = Date()
                            }
                        }
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
                    .allowsHitTesting(mode == .draw)
                }
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
                addBlockButton(.divider)
            }
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.accent)
                .frame(width: 36, height: 34)
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
            modelContext.insert(Block(type: type, sortIndex: count, page: page))
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
                    systemName: index < pages.count - 1 ? "chevron.right" : "plus.square.on.square.dashed",
                    label: index < pages.count - 1 ? "Next Page" : "New Page at End"
                ) {
                    if index < pages.count - 1 {
                        selectedPage.wrappedValue = pages[index + 1]
                    } else if let notebook = page.notebook {
                        let fresh = Page(title: "Untitled Page", notebook: notebook, background: page.background, sortIndex: pages.count)
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

    private func handlePencilGesture(_ action: PencilGestureAction) {
        // A Pencil gesture while typing means "I want to draw" — switch modes first.
        guard mode == .draw else {
            mode = .draw
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
        switch mode {
        case .edit: modelContext.undoManager?.undo()
        case .draw: inkUndoController.undo()
        }
    }

    private func redo() {
        switch mode {
        case .edit: modelContext.undoManager?.redo()
        case .draw: inkUndoController.redo()
        }
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
