import Foundation
import SwiftData

@Model
final class Page {
    var id: UUID = UUID()
    var title: String = "Untitled Page"
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var sortIndex: Int = 0

    // Emoji shown next to the title; empty string means no icon.
    var icon: String = ""
    var isFavorite: Bool = false

    // Stored as a raw String (not the enum) for CloudKit compatibility; use `background`.
    var backgroundRaw: String = PageBackground.blank.rawValue

    // Stored as a raw String (not the enum) for CloudKit compatibility; use `status`.
    var statusRaw: String = PageStatus.none.rawValue

    // Stored as a raw String (not the enum) for CloudKit compatibility; use `kind`.
    var kindRaw: String = PageKind.document.rawValue

    // Many-to-many; the inverse is declared on Tag.pages.
    var tags: [Tag]? = []

    var inkData: Data?

    var notebook: Notebook?

    @Relationship(deleteRule: .cascade, inverse: \Block.page)
    var blocks: [Block]? = []

    @Relationship(deleteRule: .cascade, inverse: \TextBox.page)
    var textBoxes: [TextBox]? = []

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

    var status: PageStatus {
        get { PageStatus(rawValue: statusRaw) ?? .none }
        set { statusRaw = newValue.rawValue }
    }

    var kind: PageKind {
        get { PageKind(rawValue: kindRaw) ?? .document }
        set { kindRaw = newValue.rawValue }
    }
}
