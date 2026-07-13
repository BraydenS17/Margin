import Foundation
import SwiftData

/// A user-defined label shared across pages in every notebook — the "property" half
/// of the page database. Tags are many-to-many with pages: one page can carry several
/// tags, one tag spans notebooks.
@Model
final class Tag {
    var id: UUID = UUID()
    var name: String = ""
    var createdAt: Date = Date()

    // Stored as a raw String (not the enum) for CloudKit compatibility; use `color`.
    var colorRaw: String = NotebookColor.ocean.rawValue

    @Relationship(inverse: \Page.tags)
    var pages: [Page]? = []

    init(name: String = "", color: NotebookColor = .ocean) {
        self.id = UUID()
        self.name = name
        self.colorRaw = color.rawValue
        self.createdAt = Date()
    }

    var color: NotebookColor {
        get { NotebookColor(rawValue: colorRaw) ?? .ocean }
        set { colorRaw = newValue.rawValue }
    }
}
