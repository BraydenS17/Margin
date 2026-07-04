import SwiftUI
import SwiftData

struct NotebookSidebarView: View {
    let workspace: Workspace?
    @Binding var selectedNotebook: Notebook?
    @Binding var selectedPage: Page?

    @Environment(\.modelContext) private var modelContext
    @State private var searchText = ""
    @State private var renameTarget: Notebook?

    private var rootNotebooks: [Notebook] {
        guard let workspace else { return [] }
        return (workspace.notebooks ?? [])
            .filter { $0.parent == nil }
            .sorted { $0.sortIndex < $1.sortIndex }
    }

    private var searchResults: [Page] {
        let query = searchText.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return [] }
        let pages = (try? modelContext.fetch(FetchDescriptor<Page>())) ?? []
        return pages
            .filter { $0.title.localizedCaseInsensitiveContains(query) }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    var body: some View {
        VStack(spacing: 0) {
            brandHeader
            searchField
            if searchText.trimmingCharacters(in: .whitespaces).isEmpty {
                notebookList
            } else {
                searchResultsList
            }
        }
        .background(Theme.background)
        #if os(iOS)
        .toolbar(.hidden, for: .navigationBar)
        #endif
    }

    private var notebookList: some View {
        List(selection: $selectedNotebook) {
            Section {
                ForEach(rootNotebooks) { notebook in
                    NotebookRow(notebook: notebook, onRename: { renameTarget = $0 })
                }
                .onDelete(perform: deleteNotebooks)
            } header: {
                Text("Notebooks").metaLabel()
            }
        }
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
        .renameAlert(item: $renameTarget, title: "Rename Notebook") { notebook, newTitle in
            notebook.title = newTitle
            notebook.updatedAt = Date()
        }
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.muted)
            TextField("Search pages", text: $searchText)
                .font(.system(size: 14))
                .textFieldStyle(.plain)
                .autocorrectionDisabled()
                .accessibilityIdentifier("Search Pages")
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.muted)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear Search")
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .strokeBorder(Theme.border, lineWidth: 1)
        )
        .padding(.horizontal, 20)
        .padding(.bottom, 10)
    }

    private var searchResultsList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text(searchResults.isEmpty
                     ? "No Results"
                     : "\(searchResults.count) \(searchResults.count == 1 ? "Result" : "Results")")
                    .metaLabel()
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                ForEach(searchResults) { page in
                    Button {
                        openSearchResult(page)
                    } label: {
                        SearchResultRow(page: page)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func openSearchResult(_ page: Page) {
        selectedNotebook = page.notebook
        selectedPage = page
        searchText = ""
    }

    private var brandHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("MARGIN")
                    .font(.editorialDisplay(26))
                    .tracking(1)
                    .foregroundStyle(Theme.text)
                Circle()
                    .fill(Theme.accent)
                    .frame(width: 7, height: 7)
                Spacer()
                FlatIconButton(systemName: "plus", label: "New Notebook", action: addNotebook)
                    .accessibilityIdentifier("New Notebook")
            }
            AccentRule()
            Text(workspace?.name ?? "Workspace")
                .metaLabel()
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 16)
    }

    private func addNotebook() {
        guard let workspace else { return }
        let notebook = Notebook(workspace: workspace, sortIndex: rootNotebooks.count)
        modelContext.insert(notebook)
        selectedNotebook = notebook
    }

    private func deleteNotebooks(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(rootNotebooks[index])
        }
    }
}

private struct SearchResultRow: View {
    let page: Page

    var body: some View {
        HStack(spacing: 13) {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(Theme.accent)
                .frame(width: 3, height: 34)
            VStack(alignment: .leading, spacing: 3) {
                Text(page.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.text)
                    .lineLimit(1)
                Text(page.notebook?.title ?? "No Notebook")
                    .metaLabel()
            }
            Spacer(minLength: 0)
            Image(systemName: "arrow.forward")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Theme.muted)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 7)
        .contentShape(Rectangle())
    }
}

private struct NotebookRow: View {
    @Bindable var notebook: Notebook
    var onRename: (Notebook) -> Void

    private var children: [Notebook] {
        (notebook.children ?? []).sorted { $0.sortIndex < $1.sortIndex }
    }

    private var pageCount: Int {
        notebook.pages?.count ?? 0
    }

    var body: some View {
        if children.isEmpty {
            rowLabel.tag(notebook)
        } else {
            DisclosureGroup {
                ForEach(children) { child in
                    NotebookRow(notebook: child, onRename: onRename)
                }
            } label: {
                rowLabel.tag(notebook)
            }
        }
    }

    private var rowLabel: some View {
        HStack(spacing: 11) {
            Image(systemName: "book.closed.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.accent)
                .frame(width: 18)
            Text(notebook.title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.text)
                .lineLimit(1)
            Spacer(minLength: 4)
            if pageCount > 0 {
                Text("\(pageCount)")
                    .metaLabel()
            }
        }
        .padding(.vertical, 3)
        .contextMenu {
            Button("Rename", systemImage: "pencil") { onRename(notebook) }
        }
    }
}
