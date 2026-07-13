import SwiftUI
import SwiftData

/// The page database: every page in every notebook as one filterable collection.
/// Table mode reads like a book index; board mode groups pages into study-status
/// columns, Notion-style.
struct PageIndexView: View {
    /// Invoked when the user taps through to a page; the presenter dismisses and opens it.
    var onOpen: (Notebook, Page) -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Page.updatedAt, order: .reverse) private var pages: [Page]
    @Query(sort: \Tag.createdAt) private var tags: [Tag]
    @Query(sort: \Notebook.sortIndex) private var notebooks: [Notebook]

    @State private var viewMode: ViewMode = .table
    @State private var filterTagID: UUID?
    @State private var filterNotebookID: UUID?

    enum ViewMode: String, CaseIterable, Identifiable {
        case table = "Table"
        case board = "Board"
        var id: String { rawValue }
    }

    private var filtered: [Page] {
        PageIndexQuery.filter(pages, tagID: filterTagID, notebookID: filterNotebookID)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    filterRow
                    if filtered.isEmpty {
                        emptyState
                    } else if viewMode == .table {
                        tableView
                    } else {
                        boardView
                    }
                }
                .padding(24)
            }
            .background(Theme.background)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("Index")
                    .font(.editorialDisplay(36))
                    .foregroundStyle(Theme.text)
                Spacer()
                modePill
            }
            AccentRule()
            Text("\(filtered.count) of \(pages.count) \(pages.count == 1 ? "page" : "pages") · every notebook")
                .metaLabel()
        }
    }

    private var modePill: some View {
        HStack(spacing: 0) {
            ForEach(ViewMode.allCases) { m in
                Button {
                    viewMode = m
                } label: {
                    Text(m.rawValue)
                        .font(.system(size: 13, weight: .bold))
                        .tracking(0.5)
                        .foregroundStyle(viewMode == m ? Color.white : Theme.muted)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6)
                        .background(viewMode == m ? Theme.accent : Color.clear, in: Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("\(m.rawValue) View")
            }
        }
        .padding(3)
        .background(Theme.surface, in: Capsule())
        .overlay(Capsule().strokeBorder(Theme.border, lineWidth: 1))
    }

    // MARK: - Filters

    private var filterRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                notebookFilterMenu
                ForEach(tags) { tag in
                    tagFilterChip(tag)
                }
                if filterTagID != nil || filterNotebookID != nil {
                    Button {
                        filterTagID = nil
                        filterNotebookID = nil
                    } label: {
                        Label("Clear", systemImage: "xmark.circle.fill")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Theme.muted)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Clear Filters")
                }
            }
        }
    }

    private var notebookFilterMenu: some View {
        Menu {
            Button {
                filterNotebookID = nil
            } label: {
                Label("All Notebooks", systemImage: filterNotebookID == nil ? "checkmark" : "books.vertical")
            }
            Divider()
            ForEach(notebooks) { notebook in
                Button {
                    filterNotebookID = notebook.id
                } label: {
                    Label(notebook.title, systemImage: filterNotebookID == notebook.id ? "checkmark" : "book.closed")
                }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "books.vertical")
                    .font(.system(size: 11, weight: .semibold))
                Text(notebooks.first(where: { $0.id == filterNotebookID })?.title ?? "All Notebooks")
                    .font(.system(size: 12, weight: .bold))
                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .bold))
            }
            .foregroundStyle(filterNotebookID == nil ? Theme.muted : Theme.accent)
            .padding(.horizontal, 11)
            .padding(.vertical, 6)
            .background(Theme.surface, in: Capsule())
            .overlay(Capsule().strokeBorder(
                filterNotebookID == nil ? Theme.border : Theme.accent.opacity(0.5), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Filter by Notebook")
    }

    private func tagFilterChip(_ tag: Tag) -> some View {
        let active = filterTagID == tag.id
        return Button {
            filterTagID = active ? nil : tag.id
        } label: {
            HStack(spacing: 6) {
                Circle().fill(tag.color.swatch).frame(width: 7, height: 7)
                Text(tag.name)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(active ? Color.white : Theme.text)
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 6)
            .background(active ? tag.color.swatch : tag.color.swatch.opacity(0.08), in: Capsule())
            .overlay(Capsule().strokeBorder(tag.color.swatch.opacity(active ? 0 : 0.35), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Filter by \(tag.name)")
    }

    // MARK: - Table mode

    private var tableView: some View {
        VStack(spacing: 0) {
            ForEach(filtered) { page in
                tableRow(page)
                if page.id != filtered.last?.id {
                    Rectangle().fill(Theme.border).frame(height: 1)
                }
            }
        }
        .background(Theme.surface.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                .strokeBorder(Theme.border, lineWidth: 1)
        )
    }

    private func tableRow(_ page: Page) -> some View {
        Button {
            open(page)
        } label: {
            HStack(spacing: 12) {
                Text(page.icon.isEmpty ? "📄" : page.icon)
                    .font(.system(size: 16))
                VStack(alignment: .leading, spacing: 3) {
                    Text(page.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.text)
                        .lineLimit(1)
                    HStack(spacing: 6) {
                        if let notebook = page.notebook {
                            Circle().fill(notebook.color.swatch).frame(width: 7, height: 7)
                            Text(notebook.title).metaLabel()
                        }
                        Text("· \(page.updatedAt.formatted(.relative(presentation: .named)))")
                            .metaLabel()
                    }
                }
                Spacer()
                ForEach((page.tags ?? []).sorted { $0.name < $1.name }.prefix(3)) { tag in
                    HStack(spacing: 5) {
                        Circle().fill(tag.color.swatch).frame(width: 6, height: 6)
                        Text(tag.name)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Theme.text)
                    }
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(tag.color.swatch.opacity(0.08), in: Capsule())
                }
                statusBadge(page)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 11)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu { statusContextMenu(page) }
    }

    private func statusBadge(_ page: Page) -> some View {
        HStack(spacing: 5) {
            Image(systemName: page.status.systemImage)
                .font(.system(size: 10, weight: .semibold))
            Text(page.status.displayName)
                .font(.system(size: 11, weight: .bold))
        }
        .foregroundStyle(page.status == .none ? Theme.muted : Theme.accent)
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
        .background(Theme.surface, in: Capsule())
        .overlay(Capsule().strokeBorder(
            page.status == .none ? Theme.border : Theme.accent.opacity(0.5), lineWidth: 1))
    }

    // MARK: - Board mode

    private var boardView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 14) {
                ForEach(PageIndexQuery.board(filtered), id: \.0) { status, columnPages in
                    boardColumn(status, columnPages)
                }
            }
        }
    }

    private func boardColumn(_ status: PageStatus, _ columnPages: [Page]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 7) {
                Image(systemName: status.systemImage)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.accent)
                Text(status.displayName.uppercased())
                    .metaLabel()
                Text("\(columnPages.count)")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Theme.muted)
            }
            if columnPages.isEmpty {
                Text("No pages")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.muted)
                    .frame(maxWidth: .infinity, minHeight: 60)
                    .background(Theme.surface.opacity(0.4), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(Theme.border, style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
                    )
            } else {
                ForEach(columnPages) { page in
                    boardCard(page)
                }
            }
        }
        .frame(width: 230)
    }

    private func boardCard(_ page: Page) -> some View {
        Button {
            open(page)
        } label: {
            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 7) {
                    Text(page.icon.isEmpty ? "📄" : page.icon)
                        .font(.system(size: 14))
                    Text(page.title)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Theme.text)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                if let notebook = page.notebook {
                    HStack(spacing: 6) {
                        Circle().fill(notebook.color.swatch).frame(width: 7, height: 7)
                        Text(notebook.title).metaLabel()
                    }
                }
                let pageTags = (page.tags ?? []).sorted { $0.name < $1.name }
                if !pageTags.isEmpty {
                    HStack(spacing: 5) {
                        ForEach(pageTags.prefix(3)) { tag in
                            HStack(spacing: 4) {
                                Circle().fill(tag.color.swatch).frame(width: 5, height: 5)
                                Text(tag.name)
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(Theme.text)
                            }
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(tag.color.swatch.opacity(0.08), in: Capsule())
                        }
                    }
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Theme.border, lineWidth: 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu { statusContextMenu(page) }
    }

    // MARK: - Shared

    @ViewBuilder
    private func statusContextMenu(_ page: Page) -> some View {
        Menu("Set Status", systemImage: "circle.dashed") {
            ForEach(PageStatus.allCases, id: \.self) { status in
                Button {
                    page.status = status
                    page.updatedAt = Date()
                } label: {
                    Label(status.displayName, systemImage: page.status == status ? "checkmark" : status.systemImage)
                }
            }
        }
        Button("Open Page", systemImage: "arrow.up.right") { open(page) }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "tray")
                .font(.system(size: 40))
                .foregroundStyle(Theme.accent)
            Text(pages.isEmpty ? "No pages yet" : "Nothing matches")
                .font(.editorialDisplay(24))
                .foregroundStyle(Theme.text)
            Text(pages.isEmpty
                 ? "PAGES FROM EVERY NOTEBOOK SHOW UP HERE"
                 : "TRY CLEARING A FILTER")
                .metaLabel()
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    private func open(_ page: Page) {
        guard let notebook = page.notebook else { return }
        dismiss()
        onOpen(notebook, page)
    }
}
