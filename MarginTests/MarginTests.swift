//
//  MarginTests.swift
//  MarginTests
//
//  Created by Brayden Sally on 2026-07-02.
//

import Testing
import Foundation
import SwiftData
@testable import Margin

@MainActor
struct MarginTests {

    private func makeContext() throws -> ModelContext {
        let schema = Schema([Workspace.self, Notebook.self, Page.self, Block.self, PDFAsset.self])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        return ModelContext(container)
    }

    // MARK: - Relationship chain

    @Test func workspaceNotebookPageBlockChainResolvesBothDirections() throws {
        let context = try makeContext()

        let workspace = Workspace(name: "School")
        context.insert(workspace)

        let notebook = Notebook(title: "Biology", workspace: workspace)
        context.insert(notebook)

        let page = Page(title: "Chapter 1", notebook: notebook)
        context.insert(page)

        let block = Block(type: .heading, textContent: "Cells", page: page)
        context.insert(block)

        try context.save()

        #expect(notebook.workspace === workspace)
        #expect(workspace.notebooks?.contains(where: { $0 === notebook }) == true)

        #expect(page.notebook === notebook)
        #expect(notebook.pages?.contains(where: { $0 === page }) == true)

        #expect(block.page === page)
        #expect(page.blocks?.contains(where: { $0 === block }) == true)
    }

    // MARK: - Nested notebooks

    @Test func nestedNotebooksResolveParentChildRelationship() throws {
        let context = try makeContext()

        let workspace = Workspace()
        context.insert(workspace)

        let parent = Notebook(title: "Parent", workspace: workspace)
        context.insert(parent)

        let child = Notebook(title: "Child", workspace: workspace, parent: parent)
        context.insert(child)

        try context.save()

        #expect(child.parent === parent)
        #expect(parent.children?.contains(where: { $0 === child }) == true)
    }

    // MARK: - Cascade deletes

    @Test func deletingNotebookCascadesToPages() throws {
        let context = try makeContext()

        let workspace = Workspace()
        context.insert(workspace)

        let notebook = Notebook(title: "Notebook", workspace: workspace)
        context.insert(notebook)

        let page = Page(title: "Page", notebook: notebook)
        context.insert(page)

        try context.save()
        #expect(try context.fetch(FetchDescriptor<Page>()).count == 1)

        context.delete(notebook)
        try context.save()

        #expect(try context.fetch(FetchDescriptor<Page>()).isEmpty)
    }

    @Test func deletingWorkspaceCascadesToNotebooks() throws {
        let context = try makeContext()

        let workspace = Workspace()
        context.insert(workspace)

        let notebook = Notebook(title: "Notebook", workspace: workspace)
        context.insert(notebook)

        try context.save()
        #expect(try context.fetch(FetchDescriptor<Notebook>()).count == 1)

        context.delete(workspace)
        try context.save()

        #expect(try context.fetch(FetchDescriptor<Notebook>()).isEmpty)
    }

    @Test func deletingPageCascadesToBlocks() throws {
        let context = try makeContext()

        let workspace = Workspace()
        context.insert(workspace)

        let notebook = Notebook(title: "Notebook", workspace: workspace)
        context.insert(notebook)

        let page = Page(title: "Page", notebook: notebook)
        context.insert(page)

        let block = Block(type: .paragraph, textContent: "Hello", page: page)
        context.insert(block)

        try context.save()
        #expect(try context.fetch(FetchDescriptor<Block>()).count == 1)

        context.delete(page)
        try context.save()

        #expect(try context.fetch(FetchDescriptor<Block>()).isEmpty)
    }

    // MARK: - Raw string round-tripping

    @Test func pageBackgroundRoundTripsThroughRawValue() throws {
        let context = try makeContext()

        let page = Page()
        context.insert(page)

        page.background = .ruled
        #expect(page.backgroundRaw == "ruled")
        #expect(page.background == .ruled)

        page.background = .grid
        #expect(page.backgroundRaw == "grid")
        #expect(page.background == .grid)
    }

    @Test func pageBackgroundFallsBackToBlankForInvalidRawValue() throws {
        let context = try makeContext()

        let page = Page()
        context.insert(page)

        page.backgroundRaw = "not-a-real-background"
        #expect(page.background == .blank)
    }

    @Test func blockTypeRoundTripsThroughRawValue() throws {
        let context = try makeContext()

        let block = Block()
        context.insert(block)

        block.type = .checkbox
        #expect(block.typeRaw == "checkbox")
        #expect(block.type == .checkbox)

        block.type = .bulletList
        #expect(block.typeRaw == "bulletList")
        #expect(block.type == .bulletList)
    }

    @Test func blockTypeFallsBackToParagraphForInvalidRawValue() throws {
        let context = try makeContext()

        let block = Block()
        context.insert(block)

        block.typeRaw = "not-a-real-type"
        #expect(block.type == .paragraph)
    }

    // MARK: - Defaults

    @Test func pageDefaultsAreExpected() throws {
        let page = Page()

        #expect(page.title == "Untitled Page")
        #expect(page.background == .blank)
        #expect(page.backgroundRaw == "blank")
        #expect(page.sortIndex == 0)
        #expect(page.blocks?.isEmpty == true)
        #expect(page.notebook == nil)
        #expect(page.pdfAsset == nil)
    }

    // MARK: - New BlockType cases

    @Test func newBlockTypesRoundTripThroughRawValue() throws {
        let context = try makeContext()

        let block = Block()
        context.insert(block)

        block.type = .callout
        #expect(block.typeRaw == "callout")
        #expect(block.type == .callout)

        block.type = .quote
        #expect(block.typeRaw == "quote")
        #expect(block.type == .quote)

        block.type = .table
        #expect(block.typeRaw == "table")
        #expect(block.type == .table)
    }

    @Test func blockTypeDisplayNameAndSystemImageAreNonEmptyForAllCases() throws {
        for type in BlockType.allCases {
            #expect(!type.displayName.isEmpty)
            #expect(!type.systemImage.isEmpty)
        }
    }

    // MARK: - BlockTableData round-tripping

    @Test func blockTableRoundTripsThroughTableData() throws {
        let context = try makeContext()

        let block = Block()
        context.insert(block)

        block.table = BlockTableData(rows: [["a", "b"], ["c", "d"]])

        #expect(block.table.rows == [["a", "b"], ["c", "d"]])
        #expect(block.tableData != nil)
        #expect((try? JSONDecoder().decode(BlockTableData.self, from: block.tableData!)) != nil)
    }

    @Test func blockTableFallsBackToEmptyWhenTableDataIsNil() throws {
        let context = try makeContext()

        let block = Block()
        context.insert(block)

        #expect(block.tableData == nil)
        #expect(block.table == BlockTableData.empty)
    }

    @Test func blockTableFallsBackToEmptyForGarbageData() throws {
        let context = try makeContext()

        let block = Block()
        context.insert(block)

        block.tableData = Data("not json".utf8)
        #expect(block.table == BlockTableData.empty)
    }

    // MARK: - PageTemplate

    @Test func everyPageTemplateHasANonEmptyName() throws {
        for template in PageTemplate.all {
            #expect(!template.name.isEmpty)
        }
    }

    @Test func pageTemplateBlockSpecsApplyToRealBlocksInContext() throws {
        let context = try makeContext()

        let workspace = Workspace()
        context.insert(workspace)

        let notebook = Notebook(title: "Notebook", workspace: workspace)
        context.insert(notebook)

        for template in PageTemplate.all {
            let page = Page(title: template.name, notebook: notebook, background: template.background)
            context.insert(page)

            for (index, spec) in template.blockSpecs.enumerated() {
                let block = Block(type: spec.type, textContent: spec.text, sortIndex: index, page: page)
                block.isChecked = spec.isChecked
                if let table = spec.table {
                    block.table = table
                }
                context.insert(block)
            }

            try context.save()

            let blocks = (page.blocks ?? []).sorted { $0.sortIndex < $1.sortIndex }
            #expect(blocks.count == template.blockSpecs.count)

            for (index, block) in blocks.enumerated() {
                #expect(block.sortIndex == index)
            }

            for (index, spec) in template.blockSpecs.enumerated() {
                if let table = spec.table {
                    #expect(blocks[index].table.rows == table.rows)
                }
            }
        }
    }
}
