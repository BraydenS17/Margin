import SwiftUI
import SwiftData

struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Workspace.createdAt) private var workspaces: [Workspace]

    @State private var selectedNotebook: Notebook?
    @State private var selectedPage: Page?
    #if DEBUG
    @State private var showPDFInkSpike = false
    #endif

    var body: some View {
        NavigationSplitView {
            NotebookSidebarView(workspace: workspaces.first, selectedNotebook: $selectedNotebook)
        } content: {
            if let notebook = selectedNotebook {
                PageListView(notebook: notebook, selectedPage: $selectedPage)
            } else {
                ContentUnavailableView("Select a Notebook", systemImage: "book.closed")
            }
        } detail: {
            if let page = selectedPage {
                PageDetailView(page: page)
            } else {
                ContentUnavailableView("Select a Page", systemImage: "doc.text")
            }
        }
        .onAppear {
            ensureWorkspaceExists()
            if modelContext.undoManager == nil {
                modelContext.undoManager = UndoManager()
            }
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
