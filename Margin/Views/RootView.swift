import SwiftUI
import SwiftData

struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Workspace.createdAt) private var workspaces: [Workspace]

    @State private var selectedNotebook: Notebook?
    @State private var selectedPage: Page?
    @State private var isInLibrary = true
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    #if DEBUG
    @State private var showPDFInkSpike = false
    #endif

    var body: some View {
        Group {
            if isInLibrary {
                LibraryView(workspace: workspaces.first) { notebook, page in
                    selectedNotebook = notebook
                    selectedPage = page
                    withAnimation(.snappy) { isInLibrary = false }
                }
                .transition(.move(edge: .leading).combined(with: .opacity))
            } else {
                notesWorkspace
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .tint(Theme.accent)
        .preferredColorScheme(ThemeSettings.shared.appearance.colorScheme)
        .onAppear(perform: ensureWorkspaceExists)
        #if DEBUG
        .sheet(isPresented: $showPDFInkSpike) {
            NavigationStack { PDFInkSpikeView() }
        }
        #endif
    }

    private var notesWorkspace: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            // Pages only — switching notebooks means going back to the Library.
            if let notebook = selectedNotebook {
                PageListView(
                    notebook: notebook,
                    selectedNotebook: $selectedNotebook,
                    selectedPage: $selectedPage,
                    columnVisibility: $columnVisibility,
                    onExitToLibrary: {
                        withAnimation(.snappy) { isInLibrary = true }
                    }
                )
            } else {
                EditorialEmptyState(
                    systemImage: "books.vertical",
                    title: "No Notebook Open",
                    message: "Return to the library to pick one"
                )
            }
        } detail: {
            if let page = selectedPage {
                PageDetailView(
                    page: page,
                    selectedPage: $selectedPage,
                    onOpenPage: { target in
                        // Page-link jump: pull the target's notebook into the sidebar too,
                        // so links can cross notebooks like Notion pages cross sections.
                        selectedNotebook = target.notebook ?? selectedNotebook
                        selectedPage = target
                    },
                    columnVisibility: $columnVisibility
                )
            } else {
                EditorialEmptyState(
                    systemImage: "doc.text",
                    title: "Nothing Open",
                    message: "Select or create a page to start writing"
                )
            }
        }
        .onChange(of: selectedNotebook) { _, notebook in
            // Jump straight into the notebook's first page instead of leaving the detail
            // column empty (or showing a page from the previously selected notebook).
            // When the page was already retargeted into this notebook (a page-link jump
            // sets both), leave it alone instead of yanking focus to page one.
            guard selectedPage?.notebook?.id != notebook?.id else { return }
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
