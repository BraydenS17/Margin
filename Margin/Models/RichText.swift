import Foundation
import SwiftUI

/// Lightweight inline markdown-style formatting for block text — **bold**, *italic*,
/// __underline__, ~~strikethrough~~, `code`, ==highlight==. The raw markers stay in
/// `Block.textContent` (so plain-text export/search/editing keep working unchanged);
/// this just parses them into styled spans for display. Kept off the views so the
/// parser can be unit-tested, matching `BlockOutline`/`PageOutline`.
enum RichText {
    struct Span: Equatable {
        var text: String
        var bold = false
        var italic = false
        var underline = false
        var strikethrough = false
        var code = false
        var highlight = false
    }

    // Longest/most-specific markers first so e.g. "**bold**" doesn't get eaten by "*".
    private static let regex = try! NSRegularExpression(
        pattern: #"\*\*(.+?)\*\*|\*(.+?)\*|__(.+?)__|~~(.+?)~~|`(.+?)`|==(.+?)=="#
    )

    /// Splits raw text into alternating plain and styled spans.
    static func spans(from text: String) -> [Span] {
        guard !text.isEmpty else { return [] }
        let ns = text as NSString
        var result: [Span] = []
        var lastEnd = 0
        let matches = regex.matches(in: text, range: NSRange(location: 0, length: ns.length))
        for match in matches {
            if match.range.location > lastEnd {
                result.append(Span(text: ns.substring(with: NSRange(location: lastEnd, length: match.range.location - lastEnd))))
            }
            if let group = styledGroup(in: match) {
                let inner = ns.substring(with: match.range(at: group))
                result.append(styledSpan(text: inner, group: group))
            }
            lastEnd = match.range.location + match.range.length
        }
        if lastEnd < ns.length {
            result.append(Span(text: ns.substring(from: lastEnd)))
        }
        return result
    }

    /// Whether the text has any recognizable marker at all — used to decide between
    /// showing an editable `TextField` (raw markers) and a rendered `Text` (styled).
    static func hasFormatting(_ text: String) -> Bool {
        regex.firstMatch(in: text, range: NSRange(location: 0, length: (text as NSString).length)) != nil
    }

    /// Renders spans as a single `AttributedString`, so callers get one `Text` view
    /// with mixed styling (bold/italic/etc. all combine with `baseFont`).
    static func attributedString(from text: String, baseFont: Font = .body) -> AttributedString {
        spans(from: text).reduce(into: AttributedString()) { result, span in
            var piece = AttributedString(span.text)
            var font = baseFont
            if span.code {
                font = .system(.body, design: .monospaced)
            }
            if span.bold { font = font.bold() }
            if span.italic { font = font.italic() }
            piece.font = font
            if span.underline { piece.underlineStyle = .single }
            if span.strikethrough { piece.strikethroughStyle = .single }
            if span.highlight { piece.backgroundColor = Color.yellow.opacity(0.35) }
            result += piece
        }
    }

    private static func styledGroup(in match: NSTextCheckingResult) -> Int? {
        for i in 1...6 where match.range(at: i).location != NSNotFound {
            return i
        }
        return nil
    }

    private static func styledSpan(text: String, group: Int) -> Span {
        var span = Span(text: text)
        switch group {
        case 1: span.bold = true
        case 2: span.italic = true
        case 3: span.underline = true
        case 4: span.strikethrough = true
        case 5: span.code = true
        case 6: span.highlight = true
        default: break
        }
        return span
    }
}
