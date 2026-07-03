import SwiftUI
import SwiftData

struct PageListView: View {
    @Bindable var notebook: Notebook
    @Binding var selectedPage: Page?

    @Environment(\.modelContext) private var modelContext
    @State private var showingTemplatePicker = false

    private var pages: [Page] {
        (notebook.pages ?? []).sorted { $0.sortIndex < $1.sortIndex }
    }

    var body: some View {
        List(selection: $selectedPage) {
            ForEach(pages) { page in
                Label(page.title, systemImage: "doc.text")
                    .tag(page)
            }
            .onDelete(perform: deletePages)
        }
        .navigationTitle(notebook.title)
        .toolbar {
            ToolbarItem {
                Button {
                    showingTemplatePicker = true
                } label: {
                    Label("New Page", systemImage: "plus")
                }
                .accessibilityIdentifier("New Page")
            }
        }
        .sheet(isPresented: $showingTemplatePicker) {
            TemplatePickerView(onSelect: addPage)
        }
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
