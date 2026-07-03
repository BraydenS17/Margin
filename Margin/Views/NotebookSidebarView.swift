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
        List(selection: $selectedNotebook) {
            ForEach(rootNotebooks) { notebook in
                NotebookRow(notebook: notebook)
            }
            .onDelete(perform: deleteNotebooks)
        }
        .navigationTitle(workspace?.name ?? "Margin")
        .toolbar {
            ToolbarItem {
                Button(action: addNotebook) {
                    Label("New Notebook", systemImage: "plus")
                }
                .accessibilityIdentifier("New Notebook")
            }
        }
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

    var body: some View {
        if children.isEmpty {
            Label(notebook.title, systemImage: "book")
                .tag(notebook)
        } else {
            DisclosureGroup {
                ForEach(children) { child in
                    NotebookRow(notebook: child)
                }
            } label: {
                Label(notebook.title, systemImage: "book")
                    .tag(notebook)
            }
        }
    }
}
