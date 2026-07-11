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
    @State private var showingPlanner = false
    @State private var openDeck: Deck?
    @State private var showingSettings = false
    private var settings: ThemeSettings { .shared }

    private var notebooks: [Notebook] {
        guard let workspace else { return [] }
        return (workspace.notebooks ?? [])
            .filter { $0.parent == nil }
            .sorted { $0.sortIndex < $1.sortIndex }
    }

    private var decks: [Deck] {
        ((try? modelContext.fetch(FetchDescriptor<Deck>())) ?? [])
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    private var openAssignments: [Assignment] {
        ((try? modelContext.fetch(FetchDescriptor<Assignment>())) ?? []).filter { !$0.isDone }
    }

    private var dueSoon: [Assignment] {
        let all = (try? modelContext.fetch(FetchDescriptor<Assignment>())) ?? []
        return all
            .filter { !$0.isDone }
            .sorted {
                switch ($0.dueDate, $1.dueDate) {
                case let (a?, b?): return a < b
                case (nil, _?): return false
                case (_?, nil): return true
                case (nil, nil): return $0.createdAt < $1.createdAt
                }
            }
            .prefix(4).map { $0 }
    }

    private var recentPages: [Page] {
        let pages = (try? modelContext.fetch(FetchDescriptor<Page>())) ?? []
        return pages
            .filter { !($0.blocks ?? []).isEmpty || $0.inkData != nil }
            .sorted { $0.updatedAt > $1.updatedAt }
            .prefix(4).map { $0 }
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
                    if settings.showDueSoon && !dueSoon.isEmpty {
                        dueSoonRow
                    }
                    if settings.showRecents && !recentPages.isEmpty {
                        pageRow(title: "Jump Back In", pages: recentPages)
                    }
                    if settings.showFavorites && !favoritePages.isEmpty {
                        pageRow(title: "Favorites", pages: favoritePages)
                    }

                    spacesSection

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
        .sheet(isPresented: $showingPlanner) {
            PlannerView()
        }
        .sheet(item: $openDeck) { deck in
            DeckView(deck: deck)
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
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
                FlatIconButton(systemName: "slider.horizontal.3", label: "Customize") { showingSettings = true }
                    .accessibilityIdentifier("Customize")
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

    /// Non-notebook spaces: each classification of "storage" gets its own card.
    /// Notebooks hold notes; the planner holds deadlines; decks hold recall material.
    private var spacesSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Spaces").metaLabel()
            LazyVGrid(columns: columns, spacing: 18) {
                plannerCard
                ForEach(decks) { deck in
                    deckCard(deck)
                }
                newDeckCard
            }
        }
    }

    private var plannerCard: some View {
        Button {
            showingPlanner = true
        } label: {
            spaceCard(
                icon: "checklist",
                tint: Theme.accent,
                title: "Planner",
                meta: plannerMeta
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("Planner")
    }

    private var plannerMeta: String {
        let open = openAssignments
        guard !open.isEmpty else { return "Nothing due" }
        let next = open.compactMap(\.dueDate).min()
        if let next {
            return "\(open.count) open · next \(next.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()))"
        }
        return "\(open.count) open"
    }

    private func deckCard(_ deck: Deck) -> some View {
        Button {
            openDeck = deck
        } label: {
            spaceCard(
                icon: "rectangle.stack",
                tint: deck.color.swatch,
                title: deck.title,
                meta: "\((deck.cards ?? []).count) cards · flashcards"
            )
        }
        .buttonStyle(.plain)
        .contextMenu {
            Menu("Color", systemImage: "paintpalette") {
                ForEach(NotebookColor.allCases, id: \.self) { option in
                    Button(option.displayName) {
                        deck.color = option
                        deck.updatedAt = Date()
                    }
                }
            }
            Button("Delete", systemImage: "trash", role: .destructive) {
                modelContext.delete(deck)
            }
        }
    }

    private var newDeckCard: some View {
        Button {
            let deck = Deck(title: "Untitled Deck")
            modelContext.insert(deck)
            openDeck = deck
        } label: {
            VStack(spacing: 8) {
                Image(systemName: "plus")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Theme.accent)
                Text("New Deck")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Theme.muted)
            }
            .frame(maxWidth: .infinity, minHeight: 96)
            .background(Theme.surface.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                    .strokeBorder(Theme.border, style: StrokeStyle(lineWidth: 1.5, dash: [6, 5]))
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("New Deck")
    }

    private func spaceCard(icon: String, tint: Color, title: String, meta: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 46, height: 46)
                .background(tint.opacity(0.1), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Theme.text)
                    .lineLimit(1)
                Text(meta).metaLabel()
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 96, alignment: .leading)
        .background(Theme.background)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                .strokeBorder(Theme.border, lineWidth: 1)
        )
    }

    private var dueSoonRow: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Due Soon").metaLabel()
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(dueSoon) { assignment in
                        Button {
                            showingPlanner = true
                        } label: {
                            HStack(spacing: 9) {
                                let overdue = (assignment.dueDate ?? .distantFuture) < Calendar.current.startOfDay(for: Date())
                                Circle()
                                    .fill(overdue ? Color.red : (assignment.course?.color.swatch ?? Theme.accent))
                                    .frame(width: 8, height: 8)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(assignment.title)
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundStyle(Theme.text)
                                        .lineLimit(1)
                                    HStack(spacing: 4) {
                                        if let due = assignment.dueDate {
                                            Text(due.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()))
                                                .metaLabel()
                                                .foregroundStyle(overdue ? Color.red : Theme.muted)
                                        }
                                        if let course = assignment.course {
                                            Text("· \(course.title)").metaLabel()
                                        }
                                    }
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

    private func pageRow(title: String, pages: [Page]) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title).metaLabel()
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(pages) { page in
                        Button {
                            if let notebook = page.notebook {
                                onOpen(notebook, page)
                            }
                        } label: {
                            HStack(spacing: 9) {
                                Text(page.icon.isEmpty ? "📝" : page.icon)
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
                        .fill(notebook.color.swatch)
                        .frame(width: 5)
                    ZStack {
                        notebook.color.swatch.opacity(0.08)
                        if let first = pages.first {
                            PageThumbnailView(page: first)
                                .scaleEffect(1.9)
                        } else {
                            Image(systemName: "book.closed")
                                .font(.system(size: 30))
                                .foregroundStyle(notebook.color.swatch)
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
            Menu("Cover Color", systemImage: "paintpalette") {
                ForEach(NotebookColor.allCases, id: \.self) { option in
                    Button {
                        notebook.color = option
                        notebook.updatedAt = Date()
                    } label: {
                        Label(option.displayName, systemImage: notebook.color == option ? "checkmark.circle.fill" : "circle.fill")
                    }
                }
            }
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
