import Foundation
import SwiftData

/// A flashcard deck — the "knowledge base" space type. Sits beside notebooks in the
/// library; notebooks store notes, decks store recall material.
@Model
final class Deck {
    var id: UUID = UUID()
    var title: String = "Untitled Deck"
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    // Stored as a raw String (not the enum) for CloudKit compatibility; use `color`.
    var colorRaw: String = NotebookColor.orange.rawValue

    @Relationship(deleteRule: .cascade, inverse: \Flashcard.deck)
    var cards: [Flashcard]? = []

    init(title: String = "Untitled Deck") {
        self.id = UUID()
        self.title = title
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    var color: NotebookColor {
        get { NotebookColor(rawValue: colorRaw) ?? .orange }
        set { colorRaw = newValue.rawValue }
    }
}

@Model
final class Flashcard {
    var id: UUID = UUID()
    var front: String = ""
    var back: String = ""
    var sortIndex: Int = 0
    var createdAt: Date = Date()

    var deck: Deck?

    init(front: String = "", back: String = "", sortIndex: Int = 0, deck: Deck? = nil) {
        self.id = UUID()
        self.front = front
        self.back = back
        self.sortIndex = sortIndex
        self.deck = deck
    }
}
