import Foundation
import SwiftData

@Model
final class Block {
    var id: UUID = UUID()

    // Stored as a raw String (not the enum) for CloudKit compatibility; use `type`.
    var typeRaw: String = BlockType.paragraph.rawValue

    var sortIndex: Int = 0
    var textContent: String = ""
    var isChecked: Bool = false
    // Nesting depth for list-style blocks (0 = top level), clamped in the UI.
    var indentLevel: Int = 0
    // Only meaningful when type == .toggle: a collapsed toggle hides the blocks
    // indented beneath it.
    var isCollapsed: Bool = false
    // Only meaningful when type == .pageLink: the Page.id this block points at.
    var linkedPageID: UUID?
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    // JSON-encoded BlockTableData; only meaningful when type == .table.
    var tableData: Data?

    // The picked photo, only meaningful when type == .image. External storage keeps
    // the blob out of the SQLite row; optional keeps the schema CloudKit-compatible.
    @Attribute(.externalStorage) var imageData: Data?

    var page: Page?

    init(
        type: BlockType = .paragraph,
        textContent: String = "",
        sortIndex: Int = 0,
        page: Page? = nil
    ) {
        self.id = UUID()
        self.typeRaw = type.rawValue
        self.textContent = textContent
        self.sortIndex = sortIndex
        self.page = page
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    var type: BlockType {
        get { BlockType(rawValue: typeRaw) ?? .paragraph }
        set { typeRaw = newValue.rawValue }
    }

    var table: BlockTableData {
        get {
            guard let tableData, let decoded = try? JSONDecoder().decode(BlockTableData.self, from: tableData) else {
                return BlockTableData.empty
            }
            return decoded
        }
        set { tableData = try? JSONEncoder().encode(newValue) }
    }
}

struct BlockTableData: Codable, Equatable {
    var rows: [[String]]

    static var empty: BlockTableData {
        BlockTableData(rows: [["", ""], ["", ""]])
    }
}
