import SwiftUI
import SwiftData

/// The landing screen: an editorial shelf of notebooks, separate from the notes workspace.
/// Opening a notebook hands off to the split-view editor; a Library button there returns.
struct LibraryView: View {
    let workspace: Workspace?
    let onOpen: (Notebook, Page?) -> Void

    @Environment(\.modelContext) private var modelContext
    @State private var renameTarget: Notebook?
    @State private var notebookPendingDelete: Notebook?
    @State private var searchText = ""

    private var notebooks: [Notebook] {
        guard let workspace else { return [] }
        return (workspace.notebooks ?? [])
            .filter { $0.parent == nil }
            .sorted { $0.sortIndex < $1.sortIndex }
    }

    private var favoritePages: [Page] {
        let descriptor = FetchDescriptor<Page>(predicate: #Predicate { $0.isFavorite })
        return ((try? modelContext.fetch(descriptor)) ?? [])
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    private var searchResults: [Page] {
        let query = searchText.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return [] }
        let pages = (try? modelContext.fetch(FetchDescriptor<Page>())) ?? []
        return pages
            .filter { $0.title.localizedCaseInsensitiveContains(query) }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    private let columns = [GridItem(.adaptive(minimum: 210), spacing: 18)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                header
                searchField

                if !searchText.trimmingCharacters(in: .whitespaces).isEmpty {
                    searchResultsList
                } else {
                    if !favoritePages.isEmpty {
                        favoritesRow
                    }

                    VStack(alignment: .leading, spacing: 14) {
                        Text("Notebooks").metaLabel()
                        if notebooks.isEmpty {
                            emptyShelf
                        } else {
                            LazyVGrid(columns: columns, spacing: 18) {
                                ForEach(notebooks) { notebook in
                                    notebookCard(notebook)
                                }
                                newNotebookCard
                            }
                        }
                    }
                }
            }
            .padding(28)
        }
        .background(Theme.background)
        .renameAlert(item: $renameTarget, title: "Rename Notebook") { notebook, newTitle in
            notebook.title = newTitle
            notebook.updatedAt = Date()
        }
        .confirmationDialog(
            "Delete \"\(notebookPendingDelete?.title ?? "")\"?",
            isPresented: Binding(
                get: { notebookPendingDelete != nil },
                set: { if !$0 { notebookPendingDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete Notebook", role: .destructive) {
                if let notebook = notebookPendingDelete {
                    modelContext.delete(notebook)
                }
                notebookPendingDelete = nil
            }
            Button("Cancel", role: .cancel) { notebookPendingDelete = nil }
        } message: {
            let count = notebookPendingDelete?.pages?.count ?? 0
            Text("This also deletes its \(count) \(count == 1 ? "page" : "pages") and any sub-notebooks.")
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("MARGIN")
                    .font(.editorialDisplay(44))
                    .tracking(1.5)
                    .foregroundStyle(Theme.text)
                Circle()
                    .fill(Theme.accent)
                    .frame(width: 11, height: 11)
                Spacer()
                FlatIconButton(systemName: "plus", label: "New Notebook", action: addNotebook)
                    .keyboardShortcut("n", modifiers: [.command, .shift])
                    .accessibilityIdentifier("New Notebook")
            }
            AccentRule()
            Text(libraryMeta).metaLabel()
        }
    }

    private var libraryMeta: String {
        let pageCount = notebooks.reduce(0) { $0 + ($1.pages?.count ?? 0) }
        return "\(notebooks.count) \(notebooks.count == 1 ? "notebook" : "notebooks") · \(pageCount) \(pageCount == 1 ? "page" : "pages")"
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.muted)
            TextField("Search all pages", text: $searchText)
                .font(.system(size: 15))
                .textFieldStyle(.plain)
                .autocorrectionDisabled()
                .accessibilityIdentifier("Search Pages")
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.muted)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear Search")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Theme.border, lineWidth: 1)
        )
        .frame(maxWidth: 460)
    }

    private var searchResultsList: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(searchResults.isEmpty
                 ? "No Results"
                 : "\(searchResults.count) \(searchResults.count == 1 ? "Result" : "Results")")
                .metaLabel()
            ForEach(searchResults) { page in
                Button {
                    if let notebook = page.notebook {
                        searchText = ""
                        onOpen(notebook, page)
                    }
                } label: {
                    HStack(spacing: 13) {
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(Theme.accent)
                            .frame(width: 3, height: 34)
                        if !page.icon.isEmpty {
                            Text(page.icon).font(.system(size: 16))
                        }
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
                    .padding(.vertical, 6)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var favoritesRow: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Favorites").metaLabel()
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(favoritePages) { page in
                        Button {
                            if let notebook = page.notebook {
                                onOpen(notebook, page)
                            }
                        } label: {
                            HStack(spacing: 9) {
                                Text(page.icon.isEmpty ? "⭐️" : page.icon)
                                    .font(.system(size: 16))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(page.title)
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundStyle(Theme.text)
                                        .lineLimit(1)
                                    Text(page.notebook?.title ?? "")
                                        .metaLabel()
                                }
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(Theme.surface, in: Capsule())
                            .overlay(Capsule().strokeBorder(Theme.border, lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func notebookCard(_ notebook: Notebook) -> some View {
        let pages = (notebook.pages ?? []).sorted { $0.sortIndex < $1.sortIndex }
        let lastEdit = ((notebook.pages ?? []).map(\.updatedAt) + [notebook.updatedAt]).max() ?? notebook.updatedAt
        return Button {
            onOpen(notebook, pages.first)
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                // "Cover": first page thumbnail on a spine-accented card.
                HStack(spacing: 0) {
                    Rectangle()
                        .fill(Theme.accent)
                        .frame(width: 5)
                    ZStack {
                        Theme.surface
                        if let first = pages.first {
                            PageThumbnailView(page: first)
                                .scaleEffect(1.9)
                        } else {
                            Image(systemName: "book.closed")
                                .font(.system(size: 30))
                                .foregroundStyle(Theme.muted)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .clipped()
                }
                .frame(height: 130)

                Rectangle().fill(Theme.border).frame(height: 1)

                VStack(alignment: .leading, spacing: 5) {
                    Text(notebook.title)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(Theme.text)
                        .lineLimit(1)
                    Text("\(pages.count) \(pages.count == 1 ? "page" : "pages") · \(lastEdit.formatted(.relative(presentation: .named)))")
                        .metaLabel()
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(Theme.background)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                    .strokeBorder(Theme.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Rename", systemImage: "pencil") { renameTarget = notebook }
            Button("Delete", systemImage: "trash", role: .destructive) { notebookPendingDelete = notebook }
        }
    }

    private var newNotebookCard: some View {
        Button(action: addNotebook) {
            VStack(spacing: 10) {
                Image(systemName: "plus")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(Theme.accent)
                Text("New Notebook")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Theme.muted)
            }
            .frame(maxWidth: .infinity, minHeight: 196)
            .background(Theme.surface.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                    .strokeBorder(Theme.border, style: StrokeStyle(lineWidth: 1.5, dash: [6, 5]))
            )
        }
        .buttonStyle(.plain)
    }

    private var emptyShelf: some View {
        VStack(spacing: 16) {
            Image(systemName: "books.vertical")
                .font(.system(size: 40))
                .foregroundStyle(Theme.accent)
            Text("Your library is empty")
                .font(.editorialDisplay(24))
                .foregroundStyle(Theme.text)
            Button(action: addNotebook) {
                Text("Create your first notebook")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 11)
                    .background(Theme.accent, in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 70)
    }

    private func addNotebook() {
        guard let workspace else { return }
        let notebook = Notebook(workspace: workspace, sortIndex: notebooks.count)
        modelContext.insert(notebook)
        onOpen(notebook, nil)
    }
}
