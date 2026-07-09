//
//  MarginTests.swift
//  MarginTests
//
//  Created by Brayden Sally on 2026-07-02.
//

import Testing
import Foundation
import SwiftData
#if os(iOS)
import PDFKit
#endif
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

    @Test func pageIconAndFavoriteDefaultsAndPersist() throws {
        let context = try makeContext()
        let page = Page()
        context.insert(page)
        try context.save()
        #expect(page.icon.isEmpty)
        #expect(page.isFavorite == false)

        page.icon = "📚"
        page.isFavorite = true
        try context.save()

        let favorites = try context.fetch(FetchDescriptor<Page>(predicate: #Predicate { $0.isFavorite }))
        #expect(favorites.count == 1)
        #expect(favorites.first?.icon == "📚")
    }

    @Test func blockIndentLevelDefaultsToZeroAndPersists() throws {
        let context = try makeContext()
        let page = Page()
        context.insert(page)
        let block = Block(type: .bulletList, textContent: "nested", sortIndex: 0, page: page)
        context.insert(block)
        #expect(block.indentLevel == 0)
        block.indentLevel = 2
        try context.save()
        let fetched = try context.fetch(FetchDescriptor<Block>()).first
        #expect(fetched?.indentLevel == 2)
    }

    @Test func notebookColorDefaultsAndRoundTrips() throws {
        let context = try makeContext()
        let notebook = Notebook(title: "Colored")
        context.insert(notebook)
        #expect(notebook.color == .orange)
        notebook.color = .ocean
        try context.save()
        #expect(notebook.colorRaw == "ocean")
        notebook.colorRaw = "garbage"
        #expect(notebook.color == .orange)
    }

    @Test func dottedBackgroundRoundTrips() throws {
        let context = try makeContext()
        let page = Page(title: "Dots", background: .dotted)
        context.insert(page)
        try context.save()
        #expect(page.backgroundRaw == "dotted")
        #expect(PageBackground.selectable.contains(.dotted))
    }

    #if os(iOS)
    private func makeSamplePDF(pageCount: Int) -> Data {
        let data = NSMutableData()
        var mediaBox = CGRect(x: 0, y: 0, width: 612, height: 792)
        let consumer = CGDataConsumer(data: data)!
        let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil)!
        for _ in 0..<pageCount {
            context.beginPDFPage(nil)
            context.setFillColor(CGColor(red: 1, green: 0, blue: 0, alpha: 1))
            context.fill(CGRect(x: 100, y: 100, width: 200, height: 200))
            context.endPDFPage()
        }
        context.closePDF()
        return data as Data
    }

    @Test func importingPDFCreatesAssetAndMappedPages() throws {
        let context = try makeContext()
        let notebook = Notebook(title: "Slides")
        context.insert(notebook)
        let existing = Page(title: "Existing", notebook: notebook, sortIndex: 0)
        context.insert(existing)

        let pdf = makeSamplePDF(pageCount: 3)
        let imported = PDFImporter.importPDF(data: pdf, fileName: "lecture.pdf", into: notebook, context: context)
        try context.save()

        #expect(imported.count == 3)
        let assets = try context.fetch(FetchDescriptor<PDFAsset>())
        #expect(assets.count == 1)
        #expect(assets.first?.pageCount == 3)
        for (offset, page) in imported.enumerated() {
            #expect(page.background == .pdf)
            #expect(page.pdfPageIndex == offset)
            #expect(page.pdfAsset === assets.first)
            #expect(page.sortIndex == 1 + offset)
            #expect(page.title.contains("lecture"))
        }
        #expect(PDFImporter.sourcePage(for: imported[1]) != nil)
        #expect(PDFImporter.sourcePage(for: existing) == nil)
    }

    @Test func importedPDFPageExportsAnnotatedPDF() throws {
        let context = try makeContext()
        let notebook = Notebook(title: "Slides")
        context.insert(notebook)
        let pdf = makeSamplePDF(pageCount: 1)
        let imported = PDFImporter.importPDF(data: pdf, fileName: "doc.pdf", into: notebook, context: context)
        let page = try #require(imported.first)

        let exported = try #require(PageExporter.pdfData(for: page))
        let document = try #require(PDFDocument(data: exported))
        #expect(document.pageCount == 1)
        // Aspect ratio of the source page survives export.
        let bounds = try #require(document.page(at: 0)).bounds(for: .mediaBox)
        #expect(abs(bounds.width / bounds.height - 612.0 / 792.0) < 0.01)
    }

    @Test func rejectsInvalidPDFData() throws {
        let context = try makeContext()
        let notebook = Notebook(title: "Slides")
        context.insert(notebook)
        let imported = PDFImporter.importPDF(data: Data("not a pdf".utf8), fileName: "junk.pdf", into: notebook, context: context)
        #expect(imported.isEmpty)
        let assets = try context.fetch(FetchDescriptor<PDFAsset>())
        #expect(assets.isEmpty)
    }

    @Test func pageExportsToValidPDF() throws {
        let context = try makeContext()
        let notebook = Notebook(title: "Export")
        context.insert(notebook)
        let page = Page(title: "Export Me", notebook: notebook)
        context.insert(page)
        context.insert(Block(type: .heading, textContent: "A Heading", sortIndex: 0, page: page))
        context.insert(Block(type: .paragraph, textContent: "Some body text.", sortIndex: 1, page: page))
        let checkbox = Block(type: .checkbox, textContent: "Done thing", sortIndex: 2, page: page)
        checkbox.isChecked = true
        context.insert(checkbox)
        let tableBlock = Block(type: .table, sortIndex: 3, page: page)
        tableBlock.table = BlockTableData(rows: [["a", "b"], ["c", "d"]])
        context.insert(tableBlock)
        try context.save()

        let data = try #require(PageExporter.pdfData(for: page))
        #expect(String(decoding: data.prefix(5), as: UTF8.self) == "%PDF-")

        let document = try #require(PDFDocument(data: data))
        #expect(document.pageCount == 1)
        let text = document.page(at: 0)?.string ?? ""
        #expect(text.contains("Export Me"))
        #expect(text.contains("A Heading"))
    }
    #endif
}
