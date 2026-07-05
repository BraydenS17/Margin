import SwiftUI
import PDFKit

#if os(iOS)
/// Renders an imported PDF page as a static background image.
///
/// Deliberately NOT a PDFView: rasterizing the page keeps the page-detail layer model
/// identical to blank/ruled/grid pages, so the ink canvas overlays and receives touches
/// exactly as it does everywhere else — the PDFView pan/pinch gesture-ownership risk
/// identified in the spike never comes into play.
struct PDFPageBackgroundView: View {
    let page: Page

    @State private var image: UIImage?

    private static let cache = NSCache<NSString, UIImage>()

    private var cacheKey: NSString {
        "\(page.id)-\(page.pdfPageIndex ?? -1)" as NSString
    }

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, alignment: .top)
            } else {
                Rectangle().fill(Theme.surface)
            }
        }
        .task(id: cacheKey) {
            if let cached = Self.cache.object(forKey: cacheKey) {
                image = cached
                return
            }
            guard let pdfPage = PDFImporter.sourcePage(for: page) else { return }
            let bounds = pdfPage.bounds(for: .mediaBox)
            guard bounds.width > 0, bounds.height > 0 else { return }
            // Render at 2x a comfortable reading width; the Image scales to fit the column.
            let scale = (900 * 2) / bounds.width
            let size = CGSize(width: bounds.width * scale, height: bounds.height * scale)
            let rendered = UIGraphicsImageRenderer(size: size).image { ctx in
                UIColor.white.setFill()
                ctx.fill(CGRect(origin: .zero, size: size))
                ctx.cgContext.translateBy(x: 0, y: size.height)
                ctx.cgContext.scaleBy(x: scale, y: -scale)
                pdfPage.draw(with: .mediaBox, to: ctx.cgContext)
            }
            Self.cache.setObject(rendered, forKey: cacheKey)
            image = rendered
        }
    }
}
#else
struct PDFPageBackgroundView: View {
    let page: Page

    var body: some View {
        Rectangle().fill(Theme.surface)
    }
}
#endif
