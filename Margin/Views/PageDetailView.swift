import SwiftUI
import SwiftData

struct PageDetailView: View {
    @Bindable var page: Page
    @Environment(\.modelContext) private var modelContext
    @State private var mode: PageMode = .edit
    @State private var inkUndoController = InkUndoController()

    enum PageMode: String, CaseIterable, Identifiable {
        case edit = "Edit"
        case draw = "Draw"
        var id: String { rawValue }
    }

    var body: some View {
        ScrollView {
            pageBackground
                .frame(minHeight: 1000)
                .overlay(alignment: .top) {
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
                .overlay {
                    InkCanvasView(inkData: $page.inkData, undoController: inkUndoController)
                        .allowsHitTesting(mode == .draw)
                }
        }
        .navigationTitle(page.title)
        .toolbar {
            ToolbarItemGroup(placement: .navigation) {
                Button("Undo", systemImage: "arrow.uturn.backward", action: undo)
                Button("Redo", systemImage: "arrow.uturn.forward", action: redo)
            }
            ToolbarItem(placement: .primaryAction) {
                Picker("Mode", selection: $mode) {
                    ForEach(PageMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .fixedSize()
            }
        }
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
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
            Rectangle().fill(.background)
        case .ruled:
            RuledBackground()
        case .grid:
            GridBackground()
        case .pdf:
            Rectangle().fill(.quaternary)
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
        .background(.background)
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
        .background(.background)
    }
}
