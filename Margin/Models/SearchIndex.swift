import Foundation

/// Pure helpers for content search, kept off the views so they can be unit-tested.
enum SearchIndex {
    /// A short window of text centered on the first match, so a hit inside a long
    /// paragraph still shows the relevant words instead of just the paragraph's start.
    static func excerpt(of text: String, around query: String, radius: Int = 40) -> String {
        guard let range = text.range(of: query, options: .caseInsensitive) else { return text }
        let start = text.index(range.lowerBound, offsetBy: -radius, limitedBy: text.startIndex) ?? text.startIndex
        let end = text.index(range.upperBound, offsetBy: radius, limitedBy: text.endIndex) ?? text.endIndex
        var snippet = String(text[start..<end])
        if start != text.startIndex { snippet = "…" + snippet }
        if end != text.endIndex { snippet += "…" }
        return snippet
    }
}
