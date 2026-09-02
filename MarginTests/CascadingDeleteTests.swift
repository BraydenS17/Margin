import Testing
import Foundation
import SwiftData
@testable import Margin

/// Regression coverage for a reported crash when deleting notebooks/decks with deep
/// cascading relationships while the app's UndoManager is attached to the context
/// (see LibraryView.deleteCascading).
@MainActor
struct CascadingDeleteTests {

    private func makeAppLikeContext() throws -> ModelContext {
        let schema = Schema([Workspace.self, Notebook.self, Page.self, Block.self, PDFAsset.self, Assignment.self, Deck.self, Flashcard.self, Tag.self, TextBox.self])
        let container = try ModelContainer(for: schema, configurations: [ModelConfiguration(isStoredInMemoryOnly: true)])
        container.mainContext.undoManager = UndoManager()
        return container.mainContext
    }

    @Test func deleteNotebookWithDeepCascadeDoesNotCrash() throws {
        let context = try makeAppLikeContext()
        let workspace = Workspace()
        context.insert(workspace)
        let notebook = Notebook(title: "Biology", workspace: workspace)
        context.insert(notebook)
        let child = Notebook(title: "Unit 1", workspace: workspace, parent: notebook)
        context.insert(child)

        for pageIndex in 0..<12 {
            let page = Page(title: "Page \(pageIndex)", notebook: pageIndex.isMultiple(of: 2) ? notebook : child)
            context.insert(page)
            for blockIndex in 0..<8 {
                context.insert(Block(type: .paragraph, textContent: "Line \(blockIndex)", sortIndex: blockIndex, page: page))
            }
            context.insert(TextBox(x: 0, y: 0, page: page))
        }
        try context.save()

        context.undoManager?.disableUndoRegistration()
        context.delete(notebook)
        try context.save()
        context.undoManager?.enableUndoRegistration()

        #expect((workspace.notebooks ?? []).isEmpty)
    }

    @Test func deleteDeckWithManyFlashcardsDoesNotCrash() throws {
        let context = try makeAppLikeContext()
        let deck = Deck(title: "Vocab")
        context.insert(deck)
        for index in 0..<40 {
            context.insert(Flashcard(front: "Q\(index)", back: "A\(index)", deck: deck))
        }
        try context.save()

        context.undoManager?.disableUndoRegistration()
        context.delete(deck)
        try context.save()
        context.undoManager?.enableUndoRegistration()

        let remaining = try context.fetch(FetchDescriptor<Flashcard>())
        #expect(remaining.isEmpty)
    }
}
