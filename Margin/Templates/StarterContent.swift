import Foundation
import SwiftData

/// First-launch seed: a Getting Started notebook so a new install opens onto real,
/// explorable content instead of an empty library.
enum StarterContent {
    static let notebookTitle = "Getting Started"

    static func seed(into workspace: Workspace, context: ModelContext) {
        let notebook = Notebook(title: notebookTitle, workspace: workspace)
        notebook.color = .ocean
        context.insert(notebook)

        let guide = Page(title: "Welcome to Margin", notebook: notebook, background: .blank, sortIndex: 0)
        guide.icon = "👋"
        context.insert(guide)

        let guideSpecs: [BlockSpec] = [
            BlockSpec(type: .heading, text: "Welcome to Margin"),
            BlockSpec(type: .paragraph, text: "Every page has two layers: **typed blocks** like this one, and a full-page **ink canvas** for your Apple Pencil. Use the Edit / Draw toggle at the top of the page to switch layers."),
            BlockSpec(type: .callout, text: "Try it now — switch to Draw and scribble right over this text."),
            BlockSpec(type: .divider),
            BlockSpec(type: .heading, text: "Things to try"),
            BlockSpec(type: .checkbox, text: "Type `/` on an empty line to see every block type"),
            BlockSpec(type: .checkbox, text: "Type `@` to mention a page or a date"),
            BlockSpec(type: .checkbox, text: "Wrap text in `**stars**` for bold, `==equals==` to highlight"),
            BlockSpec(type: .checkbox, text: "Long-press this line and choose Make Flashcard"),
            BlockSpec(type: .checkbox, text: "Import a lecture PDF from the notebook's + menu and ink on it"),
            BlockSpec(type: .divider),
            BlockSpec(type: .quote, text: "The Library (back arrow, top left) shows every page across your notebooks — filter by tag, or flip to the Board view to track what still needs review."),
        ]
        for (index, spec) in guideSpecs.enumerated() {
            let block = Block(type: spec.type, textContent: spec.text, sortIndex: index, page: guide)
            block.isChecked = spec.isChecked
            if let table = spec.table {
                block.table = table
            }
            context.insert(block)
        }

        let canvas = Page(title: "Scratch Paper", notebook: notebook, background: .ruled, sortIndex: 1)
        canvas.kind = .canvas
        canvas.icon = "✏️"
        context.insert(canvas)
    }
}
