import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct PageListView: View {
    @Bindable var notebook: Notebook
    @Binding var selectedPage: Page?
    @Binding var columnVisibility: NavigationSplitViewVisibility

    @Environment(\.modelContext) private var modelContext
    @State private var showingTemplatePicker = false
    @State private var showingPDFImporter = false
    @State private var renameTarget: Page?

    private var pages: [Page] {
        (notebook.pages ?? []).sorted { $0.sortIndex < $1.sortIndex }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            if pages.isEmpty {
                emptyState
            } else {
                List(selection: $selectedPage) {
                    ForEach(pages) { page in
                        PageRow(page: page)
                            .tag(page)
                            .contextMenu {
                                Button("Rename", systemImage: "pencil") { renameTarget = page }
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
                FlatIconButton(systemName: "sidebar.leading", label: "Toggle Sidebar") {
                    columnVisibility = columnVisibility == .all ? .doubleColumn : .all
                }
                Spacer()
                FlatIconButton(systemName: "arrow.down.doc", label: "Import PDF") {
                    showingPDFImporter = true
                }
                .accessibilityIdentifier("Import PDF")
                FlatIconButton(systemName: "plus", label: "New Page") {
                    showingTemplatePicker = true
                }
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
}

private struct PageRow: View {
    @Bindable var page: Page

    private var blockCount: Int { page.blocks?.count ?? 0 }

    private var meta: String {
        let blocks = "\(blockCount) \(blockCount == 1 ? "block" : "blocks")"
        return "\(blocks) · \(page.background.rawValue)"
    }

    var body: some View {
        HStack(spacing: 13) {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(Theme.accent)
                .frame(width: 3, height: 46)
            PageThumbnailView(page: page)
            VStack(alignment: .leading, spacing: 4) {
                Text(page.title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Theme.text)
                    .lineLimit(1)
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
