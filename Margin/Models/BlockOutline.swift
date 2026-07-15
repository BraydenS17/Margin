import Foundation

/// Pure helpers for the block editor's Notion-style outline behavior — kept off the
/// views so they can be unit-tested.
enum BlockOutline {
    /// Filters a sorted block list down to what should be on screen: a collapsed
    /// toggle hides every following block that is indented deeper than it, until the
    /// outline returns to the toggle's level (or shallower).
    static func visible(_ sorted: [Block]) -> [Block] {
        var result: [Block] = []
        var hiddenBelow: Int? = nil
        for block in sorted {
            if let level = hiddenBelow {
                if block.indentLevel > level { continue }
                hiddenBelow = nil
            }
            result.append(block)
            if block.type == .toggle && block.isCollapsed {
                hiddenBelow = block.indentLevel
            }
        }
        return result
    }

    /// The block types offered by the slash-command menu, filtered by the query the
    /// user has typed after "/". Empty query returns the full menu.
    static func slashMatches(_ query: String) -> [BlockType] {
        let insertable = BlockType.allCases
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return insertable }
        return insertable.filter {
            $0.displayName.range(of: trimmed, options: [.caseInsensitive]) != nil
        }
    }

    /// Splits a text block's content at the first return keystroke. Returns nil when
    /// there is no newline. Notion semantics: text before the newline stays put, text
    /// after it moves into a fresh block of the same type.
    static func splitOnReturn(_ text: String) -> (head: String, tail: String)? {
        guard let index = text.firstIndex(of: "\n") else { return nil }
        let head = String(text[..<index])
        let tail = String(text[text.index(after: index)...])
        return (head, tail)
    }
}
