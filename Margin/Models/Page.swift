import Foundation
import SwiftData

@Model
final class Page {
    var id: UUID = UUID()
    var title: String = "Untitled Page"
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var sortIndex: Int = 0

    // Stored as a raw String (not the enum) for CloudKit compatibility; use `background`.
    var backgroundRaw: String = PageBackground.blank.rawValue

    var inkData: Data?

    var notebook: Notebook?

    @Relationship(deleteRule: .cascade, inverse: \Block.page)
    var blocks: [Block]? = []

    var pdfAsset: PDFAsset?
    var pdfPageIndex: Int?

    init(
        title: String = "Untitled Page",
        notebook: Notebook? = nil,
        background: PageBackground = .blank,
        sortIndex: Int = 0
    ) {
        self.id = UUID()
        self.title = title
        self.createdAt = Date()
        self.updatedAt = Date()
        self.sortIndex = sortIndex
        self.backgroundRaw = background.rawValue
        self.notebook = notebook
    }

    var background: PageBackground {
        get { PageBackground(rawValue: backgroundRaw) ?? .blank }
        set { backgroundRaw = newValue.rawValue }
    }
}
