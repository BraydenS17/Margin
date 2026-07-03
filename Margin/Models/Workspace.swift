import Foundation
import SwiftData

@Model
final class Workspace {
    var id: UUID = UUID()
    var name: String = "My Workspace"
    var createdAt: Date = Date()

    @Relationship(deleteRule: .cascade, inverse: \Notebook.workspace)
    var notebooks: [Notebook]? = []

    init(name: String = "My Workspace") {
        self.id = UUID()
        self.name = name
        self.createdAt = Date()
    }
}
