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
        let schema = Schema([Workspace.self, Notebook.self, Page.self, Block.self, PDFAsset.self, Assignment.self, Deck.self, Flashcard.self, Tag.self, TextBox.self])
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

    @Test func plannerSectionsBucketByUrgency() throws {
        let context = try makeContext()
        let calendar = Calendar.current
        let now = Date()
        let overdue = Assignment(title: "Late lab", dueDate: calendar.date(byAdding: .day, value: -2, to: now))
        let today = Assignment(title: "Quiz", dueDate: now)
        let soon = Assignment(title: "Essay", dueDate: calendar.date(byAdding: .day, value: 3, to: now))
        let later = Assignment(title: "Final", dueDate: calendar.date(byAdding: .day, value: 30, to: now))
        let undated = Assignment(title: "Reading")
        let finished = Assignment(title: "Done thing", dueDate: now)
        finished.isDone = true
        for a in [overdue, today, soon, later, undated, finished] { context.insert(a) }

        let grouped = Dictionary(uniqueKeysWithValues: PlannerSection.grouped(
            [overdue, today, soon, later, undated, finished], now: now
        ).map { ($0.0, $0.1) })
        #expect(grouped[.overdue]?.map(\.title) == ["Late lab"])
        #expect(grouped[.today]?.map(\.title) == ["Quiz"])
        #expect(grouped[.thisWeek]?.map(\.title) == ["Essay"])
        #expect(grouped[.later]?.map(\.title) == ["Final", "Reading"])
        #expect(grouped[.done]?.map(\.title) == ["Done thing"])
    }

    @Test func deletingCourseNotebookOrphansAssignmentsWithoutDeleting() throws {
        let context = try makeContext()
        let course = Notebook(title: "Bio")
        context.insert(course)
        let assignment = Assignment(title: "Lab report", course: course)
        context.insert(assignment)
        try context.save()
        #expect(assignment.course === course)

        context.delete(course)
        try context.save()
        let remaining = try context.fetch(FetchDescriptor<Assignment>())
        #expect(remaining.count == 1)
        #expect(remaining.first?.course == nil)
    }

    @Test func themeSettingsPersistAndReload() throws {
        let suite = "test.themesettings.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        let settings = ThemeSettings(defaults: defaults)
        #expect(settings.accent == .orange)
        #expect(settings.appearance == .system)
        #expect(settings.showDueSoon && settings.showRecents && settings.showFavorites)

        settings.accent = .plum
        settings.appearance = .dark
        settings.showRecents = false

        let reloaded = ThemeSettings(defaults: defaults)
        #expect(reloaded.accent == .plum)
        #expect(reloaded.appearance == .dark)
        #expect(reloaded.showRecents == false)
        #expect(reloaded.showDueSoon == true)
    }

    @Test func deckCascadeDeletesCardsAndColorRoundTrips() throws {
        let context = try makeContext()
        let deck = Deck(title: "Bio Terms")
        deck.color = .forest
        context.insert(deck)
        context.insert(Flashcard(front: "Mitochondria", back: "Powerhouse of the cell", sortIndex: 0, deck: deck))
        context.insert(Flashcard(front: "Ribosome", back: "Protein synthesis", sortIndex: 1, deck: deck))
        try context.save()

        #expect(deck.colorRaw == "forest")
        #expect((deck.cards ?? []).count == 2)

        context.delete(deck)
        try context.save()
        #expect(try context.fetch(FetchDescriptor<Flashcard>()).isEmpty)
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

    // MARK: - Notion editor: outline visibility

    @Test func collapsedToggleHidesOnlyItsIndentedChildren() throws {
        let context = try makeContext()
        let page = Page(title: "Outline")
        context.insert(page)

        let toggle = Block(type: .toggle, textContent: "Details", sortIndex: 0, page: page)
        toggle.isCollapsed = true
        let childA = Block(type: .paragraph, textContent: "hidden", sortIndex: 1, page: page)
        childA.indentLevel = 1
        let childB = Block(type: .bulletList, textContent: "also hidden", sortIndex: 2, page: page)
        childB.indentLevel = 2
        let after = Block(type: .paragraph, textContent: "visible again", sortIndex: 3, page: page)
        for block in [toggle, childA, childB, after] { context.insert(block) }

        let visible = BlockOutline.visible([toggle, childA, childB, after])
        #expect(visible.map(\.textContent) == ["Details", "visible again"])
    }

    @Test func expandedToggleHidesNothing() throws {
        let context = try makeContext()
        let page = Page(title: "Outline")
        context.insert(page)

        let toggle = Block(type: .toggle, textContent: "Details", sortIndex: 0, page: page)
        toggle.isCollapsed = false
        let child = Block(type: .paragraph, textContent: "child", sortIndex: 1, page: page)
        child.indentLevel = 1
        context.insert(toggle)
        context.insert(child)

        #expect(BlockOutline.visible([toggle, child]).count == 2)
    }

    @Test func nestedCollapsedToggleInsideExpandedToggleStillHidesItsOwnChildren() throws {
        let context = try makeContext()
        let page = Page(title: "Outline")
        context.insert(page)

        let outer = Block(type: .toggle, textContent: "outer", sortIndex: 0, page: page)
        let inner = Block(type: .toggle, textContent: "inner", sortIndex: 1, page: page)
        inner.indentLevel = 1
        inner.isCollapsed = true
        let innerChild = Block(type: .paragraph, textContent: "buried", sortIndex: 2, page: page)
        innerChild.indentLevel = 2
        let outerChild = Block(type: .paragraph, textContent: "outer child", sortIndex: 3, page: page)
        outerChild.indentLevel = 1
        for block in [outer, inner, innerChild, outerChild] { context.insert(block) }

        let visible = BlockOutline.visible([outer, inner, innerChild, outerChild])
        #expect(visible.map(\.textContent) == ["outer", "inner", "outer child"])
    }

    // MARK: - Notion editor: slash commands

    @Test func slashMenuEmptyQueryOffersEverythingExceptImages() {
        let matches = BlockOutline.slashMatches("")
        #expect(!matches.isEmpty)
        #expect(!matches.contains(.image))
        #expect(matches.contains(.toggle))
        #expect(matches.contains(.code))
        #expect(matches.contains(.pageLink))
    }

    @Test func slashMenuFiltersCaseInsensitively() {
        #expect(BlockOutline.slashMatches("head") == [.heading])
        #expect(BlockOutline.slashMatches("HEAD") == [.heading])
        let listMatches = BlockOutline.slashMatches("list")
        #expect(listMatches.contains(.bulletList))
        #expect(listMatches.contains(.numberedList))
        #expect(BlockOutline.slashMatches("zzz").isEmpty)
    }

    // MARK: - Notion editor: return-key split

    @Test func splitOnReturnDividesAtFirstNewline() {
        let split = BlockOutline.splitOnReturn("before\nafter")
        #expect(split?.head == "before")
        #expect(split?.tail == "after")

        let trailing = BlockOutline.splitOnReturn("done\n")
        #expect(trailing?.head == "done")
        #expect(trailing?.tail == "")

        #expect(BlockOutline.splitOnReturn("no newline here") == nil)
    }

    // MARK: - Notion editor: page links

    @Test func pageLinkFieldsRoundTripAndDefaultOff() throws {
        let context = try makeContext()
        let notebook = Notebook(title: "Bio")
        context.insert(notebook)
        let source = Page(title: "Lecture 4", notebook: notebook)
        let target = Page(title: "Glossary", notebook: notebook)
        context.insert(source)
        context.insert(target)

        let link = Block(type: .pageLink, sortIndex: 0, page: source)
        #expect(link.linkedPageID == nil)
        #expect(link.isCollapsed == false)
        link.linkedPageID = target.id
        context.insert(link)
        try context.save()

        let targetID = target.id
        var descriptor = FetchDescriptor<Block>(predicate: #Predicate { $0.linkedPageID == targetID })
        descriptor.fetchLimit = 10
        let backlinks = try context.fetch(descriptor)
        #expect(backlinks.count == 1)
        #expect(backlinks.first?.page?.title == "Lecture 4")
    }

    @Test func newBlockTypeRawValuesRoundTrip() {
        for type in [BlockType.toggle, .code, .pageLink] {
            let block = Block(type: type)
            #expect(BlockType(rawValue: block.typeRaw) == type)
            #expect(block.type == type)
        }
    }

    // MARK: - Page database: tags

    @Test func tagsAreManyToManyAcrossNotebooks() throws {
        let context = try makeContext()
        let bio = Notebook(title: "Biology")
        let chem = Notebook(title: "Chemistry")
        context.insert(bio)
        context.insert(chem)
        let bioPage = Page(title: "Enzymes", notebook: bio)
        let chemPage = Page(title: "Catalysts", notebook: chem)
        context.insert(bioPage)
        context.insert(chemPage)

        let exam = Tag(name: "Exam 2", color: .crimson)
        context.insert(exam)
        bioPage.tags = [exam]
        chemPage.tags = [exam]
        try context.save()

        #expect((exam.pages ?? []).count == 2)
        #expect((bioPage.tags ?? []).first?.name == "Exam 2")

        // Removing the tag from one page must not touch the other.
        bioPage.tags?.removeAll { $0.id == exam.id }
        try context.save()
        #expect((exam.pages ?? []).count == 1)
        #expect((chemPage.tags ?? []).first?.name == "Exam 2")
    }

    @Test func deletingTagLeavesPagesIntact() throws {
        let context = try makeContext()
        let page = Page(title: "Lecture 9")
        context.insert(page)
        let tag = Tag(name: "Midterm")
        context.insert(tag)
        page.tags = [tag]
        try context.save()

        context.delete(tag)
        try context.save()
        #expect((page.tags ?? []).isEmpty)
        #expect(page.title == "Lecture 9")
    }

    // MARK: - Page database: status

    @Test func pageStatusDefaultsToNoneAndRoundTrips() throws {
        let context = try makeContext()
        let page = Page(title: "Fresh")
        context.insert(page)
        #expect(page.status == PageStatus.none)

        page.status = .needsReview
        try context.save()
        #expect(PageStatus(rawValue: page.statusRaw) == .needsReview)

        page.statusRaw = "garbage"
        #expect(page.status == PageStatus.none)
    }

    // MARK: - Page database: index queries

    @Test func indexFilterByTagNotebookAndStatus() throws {
        let context = try makeContext()
        let bio = Notebook(title: "Biology")
        let chem = Notebook(title: "Chemistry")
        context.insert(bio)
        context.insert(chem)

        let tag = Tag(name: "Exam")
        context.insert(tag)

        let a = Page(title: "A", notebook: bio)
        a.tags = [tag]
        a.status = .needsReview
        let b = Page(title: "B", notebook: bio)
        let c = Page(title: "C", notebook: chem)
        c.tags = [tag]
        for page in [a, b, c] { context.insert(page) }
        try context.save()

        let pages = [a, b, c]
        #expect(PageIndexQuery.filter(pages).count == 3)
        #expect(PageIndexQuery.filter(pages, tagID: tag.id).map(\.title).sorted() == ["A", "C"])
        #expect(PageIndexQuery.filter(pages, notebookID: bio.id).map(\.title).sorted() == ["A", "B"])
        #expect(PageIndexQuery.filter(pages, tagID: tag.id, notebookID: bio.id).map(\.title) == ["A"])
        #expect(PageIndexQuery.filter(pages, status: .needsReview).map(\.title) == ["A"])
    }

    // MARK: - Handwritten pages

    @Test func pageKindDefaultsToDocumentAndRoundTrips() throws {
        let context = try makeContext()
        let page = Page(title: "Old Page")
        context.insert(page)
        #expect(page.kind == .document)

        page.kind = .canvas
        try context.save()
        #expect(PageKind(rawValue: page.kindRaw) == .canvas)

        page.kindRaw = "garbage"
        #expect(page.kind == .document)
    }

    @Test func textBoxesPersistPositionAndCascadeWithPage() throws {
        let context = try makeContext()
        let notebook = Notebook(title: "Sketches")
        context.insert(notebook)
        let page = Page(title: "Diagram", notebook: notebook)
        page.kind = .canvas
        context.insert(page)

        let box = TextBox(text: "Mitochondria", x: 120, y: 300, width: 170, page: page)
        context.insert(box)
        try context.save()

        #expect((page.textBoxes ?? []).count == 1)
        let stored = try #require(page.textBoxes?.first)
        #expect(stored.text == "Mitochondria")
        #expect(stored.x == 120)
        #expect(stored.y == 300)
        #expect(stored.width == 170)

        context.delete(page)
        try context.save()
        let remaining = try context.fetch(FetchDescriptor<TextBox>())
        #expect(remaining.isEmpty)
    }

    @Test func handwrittenTemplateCreatesCanvasKind() {
        let template = PageTemplate.handwritten
        #expect(template.kind == .canvas)
        #expect(template.blockSpecs.isEmpty)
        // Every other stock template stays a document page.
        for other in PageTemplate.all where other.name != "Handwritten" {
            #expect(other.kind == .document)
        }
    }

    @Test func indexBoardAlwaysHasEveryStatusColumn() throws {
        let context = try makeContext()
        let page = Page(title: "Only One")
        page.status = .mastered
        context.insert(page)

        let board = PageIndexQuery.board([page])
        #expect(board.map(\.0) == PageStatus.allCases)
        #expect(board.first { $0.0 == .mastered }?.1.map(\.title) == ["Only One"])
        #expect(board.first { $0.0 == .inProgress }?.1.isEmpty == true)
    }
}
