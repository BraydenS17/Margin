import SwiftUI
import SwiftData

struct NotebookSidebarView: View {
    let workspace: Workspace?
    @Binding var selectedNotebook: Notebook?

    @Environment(\.modelContext) private var modelContext

    private var rootNotebooks: [Notebook] {
        guard let workspace else { return [] }
        return (workspace.notebooks ?? [])
            .filter { $0.parent == nil }
            .sorted { $0.sortIndex < $1.sortIndex }
    }

    var body: some View {
        VStack(spacing: 0) {
            brandHeader
            List(selection: $selectedNotebook) {
                Section {
                    ForEach(rootNotebooks) { notebook in
                        NotebookRow(notebook: notebook)
                    }
                    .onDelete(perform: deleteNotebooks)
                } header: {
                    Text("Notebooks").metaLabel()
                }
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)
        }
        .background(Theme.background)
        .navigationTitle("")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem {
                Button(action: addNotebook) {
                    Label("New Notebook", systemImage: "plus")
                }
                .accessibilityIdentifier("New Notebook")
            }
        }
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

private struct NotebookRow: View {
    @Bindable var notebook: Notebook

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
                    NotebookRow(notebook: child)
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
    }
}
