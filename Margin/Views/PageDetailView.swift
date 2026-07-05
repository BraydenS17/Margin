import SwiftUI
import SwiftData

struct PageDetailView: View {
    @Bindable var page: Page
    @Binding var columnVisibility: NavigationSplitViewVisibility
    @Environment(\.modelContext) private var modelContext

    @State private var mode: PageMode = .edit
    @State private var inkTool: InkToolKind = .pen
    @State private var inkColor: Color = .black
    @State private var inkWidth: CGFloat = 4
    @State private var inkUndoController = InkUndoController()
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
        ScrollView {
            pageBackground
                .frame(minHeight: 1000)
                .overlay(alignment: .top) {
                    // Imported PDF pages are annotation-first: the document itself is the
                    // content layer, so no typed title/blocks are drawn over it.
                    if page.background != .pdf {
                        VStack(alignment: .leading, spacing: 16) {
                            VStack(alignment: .leading, spacing: 10) {
                                Text(page.title)
                                    .font(.editorialDisplay(34))
                                    .foregroundStyle(Theme.text)
                                    .lineLimit(3)
                                AccentRule()
                                Text(mode == .draw ? "Draw Mode" : "\(page.background.rawValue) · edit mode")
                                    .metaLabel()
                            }
                            .padding(.horizontal, 22)
                            .padding(.top, 20)
                            BlockListView(page: page)
                        }
                        .allowsHitTesting(mode == .edit)
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
                        undoController: inkUndoController
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
    }

    private func toggleColumns() {
        columnVisibility = columnVisibility == .detailOnly ? .all : .detailOnly
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
