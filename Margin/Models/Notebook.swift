import Foundation
import SwiftData

@Model
final class Notebook {
    var id: UUID = UUID()
    var title: String = "Untitled Notebook"
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var sortIndex: Int = 0

    // Stored as a raw String (not the enum) for CloudKit compatibility; use `color`.
    var colorRaw: String = NotebookColor.orange.rawValue

    var workspace: Workspace?
    var parent: Notebook?

    @Relationship(deleteRule: .cascade, inverse: \Notebook.parent)
    var children: [Notebook]? = []

    @Relationship(deleteRule: .cascade, inverse: \Page.notebook)
    var pages: [Page]? = []

    init(
        title: String = "Untitled Notebook",
        workspace: Workspace? = nil,
        parent: Notebook? = nil,
        sortIndex: Int = 0
    ) {
        self.id = UUID()
        self.title = title
        self.createdAt = Date()
        self.updatedAt = Date()
        self.sortIndex = sortIndex
        self.workspace = workspace
        self.parent = parent
    }

    var color: NotebookColor {
        get { NotebookColor(rawValue: colorRaw) ?? .orange }
        set { colorRaw = newValue.rawValue }
    }
}
