import Foundation
import SwiftUI

/// Lightweight inline markdown-style formatting for block text — **bold**, *italic*,
/// __underline__, ~~strikethrough~~, `code`, ==highlight==, ^superscript^, ~subscript~,
/// plus LaTeX-lite math (`\sqrt{x}`, `\frac{a}{b}`). The raw markers stay in
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
        var isMention = false
        var superscript = false
        var subscriptText = false
        var isMath = false
    }

    // Longest/most-specific markers first so e.g. "**bold**" doesn't get eaten by "*",
    // and "~~strike~~" doesn't get eaten by the single-tilde subscript marker.
    private static let styleRegex = try! NSRegularExpression(
        pattern: #"\*\*(.+?)\*\*|\*(.+?)\*|__(.+?)__|~~(.+?)~~|`(.+?)`|==(.+?)==|\^(.+?)\^|~(.+?)~"#
    )

    // A resolved @-mention token: @[[Display Title|PAGE:uuid]] or @[[Jul 29|DATE:2026-07-29]].
    // Kept in plain textContent (like the style markers) so export/search/duplication
    // keep working unchanged without knowing about mentions at all.
    private static let mentionRegex = try! NSRegularExpression(
        pattern: #"@\[\[(.+?)\|(?:PAGE:[0-9A-Fa-f-]+|DATE:\d{4}-\d{2}-\d{2})\]\]"#
    )

    // LaTeX-lite math constructs typed directly (no menu, unlike mentions): \sqrt{x}
    // and \frac{a}{b}. Rendered as a precomposed display string (√(x), a⁄b) rather than
    // true stacked layout — v1 scope, no nesting with other markers inside the braces.
    private static let mathRegex = try! NSRegularExpression(
        pattern: #"\\sqrt\{(.+?)\}|\\frac\{(.+?)\}\{(.+?)\}"#
    )

    /// Splits raw text into alternating plain/styled/mention/math spans.
    static func spans(from text: String) -> [Span] {
        guard !text.isEmpty else { return [] }
        let ns = text as NSString
        var result: [Span] = []
        var lastEnd = 0
        let mentionMatches = mentionRegex.matches(in: text, range: NSRange(location: 0, length: ns.length))
        for match in mentionMatches {
            if match.range.location > lastEnd {
                let plain = ns.substring(with: NSRange(location: lastEnd, length: match.range.location - lastEnd))
                result.append(contentsOf: mathAwareSpans(from: plain))
            }
            let title = ns.substring(with: match.range(at: 1))
            result.append(Span(text: "@\(title)", isMention: true))
            lastEnd = match.range.location + match.range.length
        }
        if lastEnd < ns.length {
            result.append(contentsOf: mathAwareSpans(from: ns.substring(from: lastEnd)))
        }
        return result
    }

    /// The text a reader would actually see, with every marker/mention token stripped —
    /// used anywhere raw markup would look wrong (flashcard fronts, share text).
    static func plainText(from text: String) -> String {
        spans(from: text).map(\.text).joined()
    }

    /// Whether the text has any recognizable marker at all — used to decide between
    /// showing an editable `TextField` (raw markers) and a rendered `Text` (styled).
    static func hasFormatting(_ text: String) -> Bool {
        let ns = text as NSString
        let range = NSRange(location: 0, length: ns.length)
        return styleRegex.firstMatch(in: text, range: range) != nil
            || mentionRegex.firstMatch(in: text, range: range) != nil
            || mathRegex.firstMatch(in: text, range: range) != nil
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
            if span.superscript || span.subscriptText {
                font = .footnote
            }
            if span.isMath {
                font = font.italic()
            }
            if span.bold || span.isMention { font = font.bold() }
            if span.italic { font = font.italic() }
            piece.font = font
            if span.underline { piece.underlineStyle = .single }
            if span.strikethrough { piece.strikethroughStyle = .single }
            if span.highlight { piece.backgroundColor = Color.yellow.opacity(0.35) }
            if span.superscript { piece.baselineOffset = 5 }
            if span.subscriptText { piece.baselineOffset = -3 }
            if span.isMention {
                piece.foregroundColor = Color.accentColor
                piece.backgroundColor = Color.accentColor.opacity(0.12)
            }
            result += piece
        }
    }

    private static func mathAwareSpans(from text: String) -> [Span] {
        guard !text.isEmpty else { return [] }
        let ns = text as NSString
        var result: [Span] = []
        var lastEnd = 0
        let matches = mathRegex.matches(in: text, range: NSRange(location: 0, length: ns.length))
        for match in matches {
            if match.range.location > lastEnd {
                let plain = ns.substring(with: NSRange(location: lastEnd, length: match.range.location - lastEnd))
                result.append(contentsOf: styledSpans(from: plain))
            }
            if match.range(at: 1).location != NSNotFound {
                let inner = ns.substring(with: match.range(at: 1))
                result.append(Span(text: "√(\(inner))", isMath: true))
            } else {
                let numerator = ns.substring(with: match.range(at: 2))
                let denominator = ns.substring(with: match.range(at: 3))
                result.append(Span(text: "\(numerator)⁄\(denominator)", isMath: true))
            }
            lastEnd = match.range.location + match.range.length
        }
        if lastEnd < ns.length {
            result.append(contentsOf: styledSpans(from: ns.substring(from: lastEnd)))
        }
        return result
    }

    private static func styledSpans(from text: String) -> [Span] {
        guard !text.isEmpty else { return [] }
        let ns = text as NSString
        var result: [Span] = []
        var lastEnd = 0
        let matches = styleRegex.matches(in: text, range: NSRange(location: 0, length: ns.length))
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

    private static func styledGroup(in match: NSTextCheckingResult) -> Int? {
        for i in 1...8 where match.range(at: i).location != NSNotFound {
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
        case 7: span.superscript = true
        case 8: span.subscriptText = true
        default: break
        }
        return span
    }

    // MARK: - Mention insertion

    /// The trailing "@query" the user is actively typing, if the caret (assumed to be
    /// at the end of the block, since SwiftUI's TextField doesn't expose real caret
    /// position) is right after an unclosed "@" — e.g. "see @chem" -> "chem". Already
    /// resolved mention tokens (`@[[...]]`) never match, since `[` breaks the query
    /// character class.
    private static let activeMentionRegex = try! NSRegularExpression(pattern: #"(?:^|\s)@([^\s\[\]]*)$"#)

    static func activeMentionQuery(in text: String) -> String? {
        let ns = text as NSString
        guard let match = activeMentionRegex.firstMatch(in: text, range: NSRange(location: 0, length: ns.length)) else {
            return nil
        }
        return ns.substring(with: match.range(at: 1))
    }

    /// Replaces the trailing active "@query" with a resolved mention token plus a
    /// trailing space, so typing continues naturally after the inserted mention.
    static func inserting(mentionToken token: String, replacingQuery query: String, in text: String) -> String {
        let suffixLength = query.count + 1 // +1 for the "@"
        guard text.count >= suffixLength else { return text }
        return String(text.dropLast(suffixLength)) + token + " "
    }

    static func pageMentionToken(title: String, id: UUID) -> String {
        "@[[\(sanitizedMentionTitle(title))|PAGE:\(id.uuidString)]]"
    }

    static func dateMentionToken(date: Date) -> String {
        let display = date.formatted(.dateTime.month(.abbreviated).day().year())
        let iso = mentionDateFormatter.string(from: date)
        return "@[[\(display)|DATE:\(iso)]]"
    }

    private static let mentionDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = .current
        return formatter
    }()

    /// Strips characters that would break the `@[[title|...]]` token's own delimiters.
    private static func sanitizedMentionTitle(_ title: String) -> String {
        title.replacingOccurrences(of: "|", with: "-").replacingOccurrences(of: "]]", with: "")
    }
}
