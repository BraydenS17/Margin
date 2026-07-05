import SwiftUI

#if os(iOS)
import PencilKit
import PDFKit
import UIKit

/// Renders a Page (blocks + ink, composited) into a single-page PDF.
///
/// The content layer is a static SwiftUI rendition of the blocks drawn via ImageRenderer;
/// the ink layer is rasterized from the page's PKDrawing and composited on top, mirroring
/// the two-layer page architecture. Fixed US-Letter width; the page grows vertically to
/// fit whichever is taller, the blocks or the ink.
@MainActor
enum PageExporter {
    static let pageWidth: CGFloat = 612
    static let minHeight: CGFloat = 792

    static func pdfData(for page: Page) -> Data? {
        let drawing: PKDrawing? = page.inkData.flatMap { try? PKDrawing(data: $0) }

        // Imported PDF pages export as the source page with ink composited on top —
        // no synthetic title/blocks header defacing the original document.
        if page.background == .pdf, let sourcePage = PDFImporter.sourcePage(for: page) {
            return annotatedPDFData(sourcePage: sourcePage, drawing: drawing)
        }

        let renderer = ImageRenderer(content: PageExportContent(page: page).frame(width: pageWidth))
        renderer.proposedSize = ProposedViewSize(width: pageWidth, height: nil)

        let pdfData = NSMutableData()
        renderer.render { size, renderContent in
            let inkBottom = drawing.map { $0.bounds.maxY + 40 } ?? 0
            var mediaBox = CGRect(
                x: 0, y: 0,
                width: pageWidth,
                height: max(size.height, inkBottom, minHeight)
            )
            guard let consumer = CGDataConsumer(data: pdfData),
                  let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else { return }

            context.beginPDFPage(nil)

            // PDF origin is bottom-left; shift so the SwiftUI content sits at the top.
            context.saveGState()
            context.translateBy(x: 0, y: mediaBox.height - size.height)
            renderContent(context)
            context.restoreGState()

            if let drawing, !drawing.strokes.isEmpty {
                let inkImage = drawing.image(from: CGRect(origin: .zero, size: mediaBox.size), scale: 2)
                if let cgImage = inkImage.cgImage {
                    // Flip into UIKit orientation so the ink isn't mirrored vertically.
                    context.saveGState()
                    context.translateBy(x: 0, y: mediaBox.height)
                    context.scaleBy(x: 1, y: -1)
                    context.draw(cgImage, in: CGRect(origin: .zero, size: mediaBox.size))
                    context.restoreGState()
                }
            }

            context.endPDFPage()
            context.closePDF()
        }

        return pdfData.length > 0 ? pdfData as Data : nil
    }

    private static func annotatedPDFData(sourcePage: PDFPage, drawing: PKDrawing?) -> Data? {
        let bounds = sourcePage.bounds(for: .mediaBox)
        guard bounds.width > 0, bounds.height > 0 else { return nil }
        let scale = pageWidth / bounds.width
        var mediaBox = CGRect(x: 0, y: 0, width: pageWidth, height: bounds.height * scale)

        let pdfData = NSMutableData()
        guard let consumer = CGDataConsumer(data: pdfData),
              let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else { return nil }

        context.beginPDFPage(nil)
        context.saveGState()
        context.scaleBy(x: scale, y: scale)
        sourcePage.draw(with: .mediaBox, to: context)
        context.restoreGState()

        if let drawing, !drawing.strokes.isEmpty {
            let inkImage = drawing.image(from: CGRect(origin: .zero, size: mediaBox.size), scale: 2)
            if let cgImage = inkImage.cgImage {
                context.saveGState()
                context.translateBy(x: 0, y: mediaBox.height)
                context.scaleBy(x: 1, y: -1)
                context.draw(cgImage, in: CGRect(origin: .zero, size: mediaBox.size))
                context.restoreGState()
            }
        }

        context.endPDFPage()
        context.closePDF()
        return pdfData.length > 0 ? pdfData as Data : nil
    }

    static func writeTemporaryPDF(for page: Page) -> URL? {
        guard let data = pdfData(for: page) else { return nil }
        let safeName = page.title.replacingOccurrences(of: "/", with: "-")
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(safeName.isEmpty ? "Page" : safeName)
            .appendingPathExtension("pdf")
        do {
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }
}

/// Static, non-interactive rendition of a page's content layer for export.
private struct PageExportContent: View {
    let page: Page

    private var blocks: [Block] {
        (page.blocks ?? []).sorted { $0.sortIndex < $1.sortIndex }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(page.title)
                .font(.system(size: 28, weight: .heavy))
            Rectangle()
                .fill(Color(red: 1, green: 0.35, blue: 0.12))
                .frame(width: 22, height: 2)

            let numberedIndices = numberedListIndices()
            ForEach(Array(blocks.enumerated()), id: \.element.id) { index, block in
                blockView(block, numberedIndex: numberedIndices[index])
            }
        }
        .padding(28)
        .frame(width: PageExporter.pageWidth, alignment: .topLeading)
        .background(Color.white)
        .environment(\.colorScheme, .light)
    }

    /// Numbered lists restart when interrupted by another block type, matching the editor.
    private func numberedListIndices() -> [Int] {
        var count = 0
        return blocks.map { block in
            if block.type == .numberedList {
                count += 1
            } else {
                count = 0
            }
            return count
        }
    }

    @ViewBuilder
    private func blockView(_ block: Block, numberedIndex: Int) -> some View {
        switch block.type {
        case .heading:
            Text(block.textContent).font(.system(size: 19, weight: .bold))
        case .paragraph:
            Text(block.textContent).font(.system(size: 13))
        case .bulletList:
            HStack(alignment: .top, spacing: 8) {
                Text("•")
                Text(block.textContent)
            }
            .font(.system(size: 13))
        case .numberedList:
            HStack(alignment: .top, spacing: 8) {
                Text("\(numberedIndex).").foregroundStyle(.secondary)
                Text(block.textContent)
            }
            .font(.system(size: 13))
        case .checkbox:
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: block.isChecked ? "checkmark.square.fill" : "square")
                Text(block.textContent)
                    .strikethrough(block.isChecked)
            }
            .font(.system(size: 13))
        case .divider:
            Divider()
        case .callout:
            HStack(alignment: .top, spacing: 8) {
                Text("💡")
                Text(block.textContent)
            }
            .font(.system(size: 13))
            .padding(10)
            .background(.yellow.opacity(0.15), in: RoundedRectangle(cornerRadius: 8))
        case .quote:
            HStack(spacing: 8) {
                Rectangle().fill(.secondary).frame(width: 3)
                Text(block.textContent).italic()
            }
            .font(.system(size: 13))
        case .image:
            EmptyView()
        case .table:
            tableView(block.table)
        }
    }

    private func tableView(_ table: BlockTableData) -> some View {
        Grid(alignment: .leading, horizontalSpacing: 0, verticalSpacing: 0) {
            ForEach(table.rows.indices, id: \.self) { r in
                GridRow {
                    ForEach(table.rows[r].indices, id: \.self) { c in
                        Text(table.rows[r][c])
                            .font(.system(size: 11))
                            .padding(6)
                            .frame(minWidth: 60, alignment: .leading)
                            .border(Color.gray.opacity(0.35), width: 0.5)
                    }
                }
            }
        }
    }
}

/// UIActivityViewController wrapper for sharing the exported file.
struct ShareSheet: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
#endif
