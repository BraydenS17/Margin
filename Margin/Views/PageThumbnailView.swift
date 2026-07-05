import SwiftUI

#if os(iOS)
import PDFKit

/// Live miniature preview of a page (blocks + ink), shown in the page list.
///
/// Reuses the PDF export pipeline rather than a separate renderer, so what the thumbnail
/// shows is exactly what export produces. Rendered off the critical path in a .task and
/// memoized in an NSCache keyed on content-change heuristics.
struct PageThumbnailView: View {
    let page: Page

    @State private var image: UIImage?

    private static let cache = NSCache<NSString, UIImage>()
    private static let size = CGSize(width: 44, height: 58)

    private var cacheKey: NSString {
        let blocks = (page.blocks ?? [])
        let latestEdit = blocks.map(\.updatedAt).max() ?? page.updatedAt
        return "\(page.id)-\(page.updatedAt.timeIntervalSince1970)-\(latestEdit.timeIntervalSince1970)-\(blocks.count)-\(page.inkData?.count ?? 0)-\(page.backgroundRaw)" as NSString
    }

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Rectangle()
                    .fill(Theme.surface)
            }
        }
        .frame(width: Self.size.width, height: Self.size.height)
        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .strokeBorder(Theme.border, lineWidth: 1)
        )
        .task(id: cacheKey) {
            if let cached = Self.cache.object(forKey: cacheKey) {
                image = cached
                return
            }
            guard let data = PageExporter.pdfData(for: page),
                  let document = PDFDocument(data: data),
                  let pdfPage = document.page(at: 0) else { return }
            let bounds = pdfPage.bounds(for: .mediaBox)
            guard bounds.width > 0, bounds.height > 0 else { return }
            // Draw the page ourselves instead of PDFPage.thumbnail(of:for:) — that ObjC API
            // can bridge back a nil UIImage, which then crashes NSCache.setObject with
            // NSInvalidArgumentException. UIGraphicsImageRenderer.image never returns nil.
            // 2x the display size so the thumbnail stays crisp on retina.
            let target = CGSize(width: Self.size.width * 2, height: Self.size.height * 2)
            let scale = min(target.width / bounds.width, target.height / bounds.height)
            let renderSize = CGSize(width: bounds.width * scale, height: bounds.height * scale)
            let rendered = UIGraphicsImageRenderer(size: renderSize).image { ctx in
                UIColor.white.setFill()
                ctx.fill(CGRect(origin: .zero, size: renderSize))
                ctx.cgContext.translateBy(x: 0, y: renderSize.height)
                ctx.cgContext.scaleBy(x: scale, y: -scale)
                pdfPage.draw(with: .mediaBox, to: ctx.cgContext)
            }
            Self.cache.setObject(rendered, forKey: cacheKey)
            image = rendered
        }
    }
}
#else
struct PageThumbnailView: View {
    let page: Page

    var body: some View {
        RoundedRectangle(cornerRadius: 5, style: .continuous)
            .fill(Theme.surface)
            .frame(width: 44, height: 58)
    }
}
#endif
