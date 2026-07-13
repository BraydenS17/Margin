import Foundation

enum PageBackground: String, CaseIterable {
    case blank
    case ruled
    case grid
    case dotted
    case pdf

    var displayName: String {
        switch self {
        case .blank: return "Blank"
        case .ruled: return "Ruled"
        case .grid: return "Grid"
        case .dotted: return "Dotted"
        case .pdf: return "PDF"
        }
    }

    var systemImage: String {
        switch self {
        case .blank: return "rectangle"
        case .ruled: return "text.justify"
        case .grid: return "grid"
        case .dotted: return "circle.grid.3x3"
        case .pdf: return "doc.richtext"
        }
    }

    /// Backgrounds a user can freely switch between. `.pdf` is excluded — it's set by
    /// PDF import and switching away/into it by hand would orphan the page/PDF mapping.
    static var selectable: [PageBackground] { [.blank, .ruled, .grid, .dotted] }
}

enum BlockType: String, CaseIterable {
    case heading
    case paragraph
    case bulletList
    case numberedList
    case checkbox
    case image
    case divider
    case callout
    case quote
    case table
    case toggle
    case code
    case pageLink

    var displayName: String {
        switch self {
        case .heading: return "Heading"
        case .paragraph: return "Paragraph"
        case .bulletList: return "Bulleted List"
        case .numberedList: return "Numbered List"
        case .checkbox: return "Checkbox"
        case .image: return "Image"
        case .divider: return "Divider"
        case .callout: return "Callout"
        case .quote: return "Quote"
        case .table: return "Table"
        case .toggle: return "Toggle"
        case .code: return "Code"
        case .pageLink: return "Page Link"
        }
    }

    var systemImage: String {
        switch self {
        case .heading: return "textformat.size.larger"
        case .paragraph: return "text.alignleft"
        case .bulletList: return "list.bullet"
        case .numberedList: return "list.number"
        case .checkbox: return "checklist"
        case .image: return "photo"
        case .divider: return "minus"
        case .callout: return "lightbulb"
        case .quote: return "quote.opening"
        case .table: return "tablecells"
        case .toggle: return "chevron.forward.square"
        case .code: return "curlybraces"
        case .pageLink: return "link"
        }
    }

    /// Block types whose main content is an editable text line — these participate in
    /// the return-key split flow and the slash-command menu.
    var isTextual: Bool {
        switch self {
        case .heading, .paragraph, .bulletList, .numberedList, .checkbox, .callout, .quote, .toggle:
            return true
        case .image, .divider, .table, .code, .pageLink:
            return false
        }
    }
}

enum NotebookColor: String, CaseIterable {
    case orange
    case ocean
    case forest
    case plum
    case crimson
    case graphite

    var displayName: String {
        switch self {
        case .orange: return "Orange"
        case .ocean: return "Ocean"
        case .forest: return "Forest"
        case .plum: return "Plum"
        case .crimson: return "Crimson"
        case .graphite: return "Graphite"
        }
    }
}
