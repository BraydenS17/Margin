import SwiftUI
import SwiftData
import UniformTypeIdentifiers
#if os(iOS)
import PencilKit
#endif

struct PageListView: View {
    @Bindable var notebook: Notebook
    @Binding var selectedNotebook: Notebook?
    @Binding var selectedPage: Page?
    @Binding var columnVisibility: NavigationSplitViewVisibility
    var onExitToLibrary: () -> Void = {}

    @Environment(\.modelContext) private var modelContext
    @State private var showingTemplatePicker = false
    @State private var showingPDFImporter = false
    @State private var renameTarget: Page?
    @State private var notebookRenameTarget: Notebook?

    private var pages: [Page] {
        (notebook.pages ?? []).sorted { $0.sortIndex < $1.sortIndex }
    }

    private var childNotebooks: [Notebook] {
        (notebook.children ?? []).sorted { $0.sortIndex < $1.sortIndex }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            if pages.isEmpty && childNotebooks.isEmpty {
                emptyState
            } else {
                List(selection: $selectedPage) {
                    if !childNotebooks.isEmpty {
                        Section {
                            ForEach(childNotebooks) { child in
                                Button {
                                    selectedNotebook = child
                                } label: {
                                    HStack(spacing: 11) {
                                        Image(systemName: "book.closed.fill")
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundStyle(Theme.accent)
                                        Text(child.title)
                                            .font(.system(size: 15, weight: .semibold))
                                            .foregroundStyle(Theme.text)
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 11, weight: .semibold))
                                            .foregroundStyle(Theme.muted)
                                    }
                                    .padding(.vertical, 4)
                                }
                                .buttonStyle(.plain)
                                .listRowSeparatorTint(Theme.border)
                            }
                        } header: {
                            Text("Sub-notebooks").metaLabel()
                        }
                    }
                    ForEach(pages) { page in
                        PageRow(page: page)
                            .tag(page)
                            .contextMenu {
                                Button("Rename", systemImage: "pencil") { renameTarget = page }
                                Button(
                                    page.isFavorite ? "Remove from Favorites" : "Add to Favorites",
                                    systemImage: page.isFavorite ? "star.slash" : "star"
                                ) {
                                    page.isFavorite.toggle()
                                    page.updatedAt = Date()
                                }
                                Button("Duplicate", systemImage: "plus.square.on.square") {
                                    duplicate(page)
                                }
                                if otherNotebooks.count > 0 {
                                    Menu("Move To", systemImage: "folder") {
                                        ForEach(otherNotebooks) { destination in
                                            Button(destination.title) { move(page, to: destination) }
                                        }
                                    }
                                }
                            }
                    }
                    .onDelete(perform: deletePages)
                    .listRowSeparatorTint(Theme.border)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
        .background(Theme.background)
        #if os(iOS)
        .toolbar(.hidden, for: .navigationBar)
        #endif
        .sheet(isPresented: $showingTemplatePicker) {
            TemplatePickerView(onSelect: addPage)
        }
        .fileImporter(isPresented: $showingPDFImporter, allowedContentTypes: [.pdf]) { result in
            guard case .success(let url) = result else { return }
            importPDF(from: url)
        }
        .renameAlert(item: $renameTarget, title: "Rename Page") { page, newTitle in
            page.title = newTitle
            page.updatedAt = Date()
        }
        .renameAlert(item: $notebookRenameTarget, title: "Rename Notebook") { nb, newTitle in
            nb.title = newTitle
            nb.updatedAt = Date()
        }
    }

    private func importPDF(from url: URL) {
        // Files-app URLs are security-scoped; access must be balanced around the read.
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url) else { return }
        let imported = PDFImporter.importPDF(
            data: data,
            fileName: url.lastPathComponent,
            into: notebook,
            context: modelContext
        )
        selectedPage = imported.first
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                FlatIconButton(systemName: "books.vertical", label: "Back to Library", action: onExitToLibrary)
                notebookMenu
                Spacer()
                FlatIconButton(systemName: "arrow.down.doc", label: "Import PDF") {
                    showingPDFImporter = true
                }
                .accessibilityIdentifier("Import PDF")
                FlatIconButton(systemName: "plus", label: "New Page") {
                    showingTemplatePicker = true
                }
                .keyboardShortcut("n", modifiers: .command)
                .accessibilityIdentifier("New Page")
            }
            Text(notebook.title)
                .font(.editorialDisplay(30))
                .foregroundStyle(Theme.text)
                .lineLimit(2)
            AccentRule()
            Text("\(pages.count) \(pages.count == 1 ? "Page" : "Pages")")
                .metaLabel()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 16)
    }

    private var notebookMenu: some View {
        Menu {
            Button("Rename Notebook", systemImage: "pencil") { notebookRenameTarget = notebook }
            Button("New Sub-notebook", systemImage: "plus.rectangle.on.folder") {
                let child = Notebook(
                    title: "Untitled Notebook",
                    workspace: notebook.workspace,
                    parent: notebook,
                    sortIndex: childNotebooks.count
                )
                modelContext.insert(child)
                selectedNotebook = child
            }
            if let parent = notebook.parent {
                Button("Up to \(parent.title)", systemImage: "arrow.turn.left.up") {
                    selectedNotebook = parent
                }
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.accent)
                .frame(width: 36, height: 34)
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .strokeBorder(Theme.border, lineWidth: 1)
                )
        }
        .accessibilityLabel("Notebook Options")
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Spacer()
            Image(systemName: "doc.badge.plus")
                .font(.system(size: 34))
                .foregroundStyle(Theme.accent)
            Text("No pages yet")
                .font(.editorialDisplay(20))
                .foregroundStyle(Theme.text)
            Text("Tap + to start from a template")
                .metaLabel()
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private func addPage(from template: PageTemplate) {
        let title = template.name == "Blank" ? "Untitled Page" : template.name
        let page = Page(title: title, notebook: notebook, background: template.background, sortIndex: pages.count)
        modelContext.insert(page)

        for (index, spec) in template.blockSpecs.enumerated() {
            let block = Block(type: spec.type, textContent: spec.text, sortIndex: index, page: page)
            block.isChecked = spec.isChecked
            if let table = spec.table {
                block.table = table
            }
            modelContext.insert(block)
        }

        selectedPage = page
    }

    private func deletePages(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(pages[index])
        }
    }

    /// Sibling notebooks a page could move to (flattened, excluding the current one).
    private var otherNotebooks: [Notebook] {
        guard let workspace = notebook.workspace else { return [] }
        var result: [Notebook] = []
        func collect(_ notebooks: [Notebook]) {
            for nb in notebooks.sorted(by: { $0.sortIndex < $1.sortIndex }) {
                if nb !== notebook { result.append(nb) }
                collect(nb.children ?? [])
            }
        }
        collect((workspace.notebooks ?? []).filter { $0.parent == nil })
        return result
    }

    private func duplicate(_ page: Page) {
        let copy = Page(
            title: "\(page.title) Copy",
            notebook: notebook,
            background: page.background,
            sortIndex: page.sortIndex + 1
        )
        copy.icon = page.icon
        copy.inkData = page.inkData
        modelContext.insert(copy)
        for block in (page.blocks ?? []).sorted(by: { $0.sortIndex < $1.sortIndex }) {
            let blockCopy = Block(
                type: block.type,
                textContent: block.textContent,
                sortIndex: block.sortIndex,
                page: copy
            )
            blockCopy.isChecked = block.isChecked
            blockCopy.indentLevel = block.indentLevel
            blockCopy.tableData = block.tableData
            modelContext.insert(blockCopy)
        }
        for (index, sibling) in pages.enumerated() {
            sibling.sortIndex = index >= copy.sortIndex ? index + 1 : index
        }
        selectedPage = copy
    }

    private func move(_ page: Page, to destination: Notebook) {
        if selectedPage === page { selectedPage = nil }
        page.notebook = destination
        page.sortIndex = destination.pages?.count ?? 0
        page.updatedAt = Date()
    }
}

private struct PageRow: View {
    @Bindable var page: Page

    private var blockCount: Int { page.blocks?.count ?? 0 }

    private var latestEdit: Date {
        ((page.blocks ?? []).map(\.updatedAt) + [page.updatedAt]).max() ?? page.updatedAt
    }

    private var hasInk: Bool {
        #if os(iOS)
        guard let data = page.inkData, let drawing = try? PKDrawing(data: data) else { return false }
        return !drawing.strokes.isEmpty
        #else
        return page.inkData != nil
        #endif
    }

    private var meta: String {
        var parts = ["\(blockCount) \(blockCount == 1 ? "block" : "blocks")", page.background.rawValue]
        if hasInk { parts.append("ink") }
        parts.append(latestEdit.formatted(.relative(presentation: .named)))
        return parts.joined(separator: " · ")
    }

    var body: some View {
        HStack(spacing: 13) {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(Theme.accent)
                .frame(width: 3, height: 46)
            PageThumbnailView(page: page)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    if !page.icon.isEmpty {
                        Text(page.icon).font(.system(size: 15))
                    }
                    Text(page.title)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Theme.text)
                        .lineLimit(1)
                    if page.isFavorite {
                        Image(systemName: "star.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(Theme.accent)
                    }
                }
                Text(meta)
                    .metaLabel()
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.muted)
        }
        .padding(.vertical, 6)
    }
}
