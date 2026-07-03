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
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    // JSON-encoded BlockTableData; only meaningful when type == .table.
    var tableData: Data?

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
