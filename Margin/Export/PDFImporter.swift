import Foundation
import SwiftData
import PDFKit

/// Imports a PDF into a notebook: one PDFAsset holding the file, one Page per PDF page
/// (background .pdf, mapped by pdfPageIndex). Annotation is just ink on those pages —
/// the same two-layer model as every other page.
@MainActor
enum PDFImporter {
    @discardableResult
    static func importPDF(
        data: Data,
        fileName: String,
        into notebook: Notebook,
        context: ModelContext
    ) -> [Page] {
        guard let document = PDFDocument(data: data), document.pageCount > 0 else { return [] }

        let asset = PDFAsset(fileName: fileName, data: data, pageCount: document.pageCount)
        context.insert(asset)

        let baseName = (fileName as NSString).deletingPathExtension
        let startIndex = notebook.pages?.count ?? 0
        var pages: [Page] = []
        for index in 0..<document.pageCount {
            let title = document.pageCount == 1 ? baseName : "\(baseName) — p.\(index + 1)"
            let page = Page(title: title, notebook: notebook, background: .pdf, sortIndex: startIndex + index)
            page.pdfAsset = asset
            page.pdfPageIndex = index
            context.insert(page)
            pages.append(page)
        }
        return pages
    }

    /// The source PDFPage backing an imported page, or nil for non-PDF pages.
    static func sourcePage(for page: Page) -> PDFPage? {
        guard page.background == .pdf,
              let data = page.pdfAsset?.data,
              let index = page.pdfPageIndex,
              let document = PDFDocument(data: data),
              index >= 0, index < document.pageCount else { return nil }
        return document.page(at: index)
    }
}
