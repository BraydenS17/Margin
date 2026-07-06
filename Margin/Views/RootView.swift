import SwiftUI
import SwiftData

struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Workspace.createdAt) private var workspaces: [Workspace]

    @State private var selectedNotebook: Notebook?
    @State private var selectedPage: Page?
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    #if DEBUG
    @State private var showPDFInkSpike = false
    #endif

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            NotebookSidebarView(workspace: workspaces.first, selectedNotebook: $selectedNotebook, selectedPage: $selectedPage)
        } content: {
            if let notebook = selectedNotebook {
                PageListView(notebook: notebook, selectedPage: $selectedPage, columnVisibility: $columnVisibility)
            } else {
                EditorialEmptyState(
                    systemImage: "books.vertical",
                    title: "Pick a Notebook",
                    message: "Choose one on the left to see its pages"
                )
            }
        } detail: {
            if let page = selectedPage {
                PageDetailView(page: page, columnVisibility: $columnVisibility)
            } else {
                EditorialEmptyState(
                    systemImage: "doc.text",
                    title: "Nothing Open",
                    message: "Select or create a page to start writing"
                )
            }
        }
        .tint(Theme.accent)
        .onAppear(perform: ensureWorkspaceExists)
        .onChange(of: selectedNotebook) { _, notebook in
            // Jump straight into the notebook's first page instead of leaving the detail
            // column empty (or showing a page from the previously selected notebook).
            selectedPage = notebook?.pages?.sorted { $0.sortIndex < $1.sortIndex }.first
        }
        #if DEBUG
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button("PDF Ink Spike", systemImage: "testtube.2") {
                    showPDFInkSpike = true
                }
            }
        }
        .sheet(isPresented: $showPDFInkSpike) {
            NavigationStack { PDFInkSpikeView() }
        }
        #endif
    }

    private func ensureWorkspaceExists() {
        guard workspaces.isEmpty else { return }
        modelContext.insert(Workspace())
    }

}

#Preview {
    RootView()
        .modelContainer(for: Workspace.self, inMemory: true)
}
