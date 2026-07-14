import Foundation
import SwiftData

/// A freely positioned text box on a handwritten (canvas) page — the typed layer of a
/// drawing-first page, moved by its grip handle rather than flowing like blocks do.
/// Coordinates are in the page's content space, anchored top-leading.
@Model
final class TextBox {
    var id: UUID = UUID()
    var text: String = ""
    var x: Double = 40
    var y: Double = 120
    var width: Double = 240
    var createdAt: Date = Date()

    var page: Page?

    init(text: String = "", x: Double = 40, y: Double = 120, width: Double = 240, page: Page? = nil) {
        self.id = UUID()
        self.text = text
        self.x = x
        self.y = y
        self.width = width
        self.page = page
        self.createdAt = Date()
    }
}
