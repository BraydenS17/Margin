import SwiftUI

#if os(iOS)
import UIKit

/// Native pinch-zoom + pan container for a page.
///
/// The whole composited page (background, blocks, ink canvas) is hosted inside a real
/// UIScrollView, so zooming uses the platform's scroll/zoom machinery. Because the ink
/// canvas is part of the zoomed content, touch coordinates map through the zoom transform
/// and drawing stays positionally correct at any scale. At 1x this behaves exactly like
/// the plain vertical ScrollView it replaces.
struct ZoomablePageView<Content: View>: UIViewRepresentable {
    @ViewBuilder var content: Content

    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.minimumZoomScale = 1
        scrollView.maximumZoomScale = 4
        scrollView.bouncesZoom = true
        scrollView.delegate = context.coordinator
        scrollView.backgroundColor = .clear

        let host = UIHostingController(rootView: content)
        host.view.backgroundColor = .clear
        host.view.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(host.view)
        NSLayoutConstraint.activate([
            host.view.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            host.view.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            host.view.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            // Content matches the visible width at 1x, giving a plain vertical page.
            host.view.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),
        ])
        context.coordinator.host = host
        return scrollView
    }

    func updateUIView(_ scrollView: UIScrollView, context: Context) {
        context.coordinator.host?.rootView = content
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator: NSObject, UIScrollViewDelegate {
        var host: UIHostingController<Content>?

        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            host?.view
        }

        func scrollViewDidEndZooming(_ scrollView: UIScrollView, with view: UIView?, atScale scale: CGFloat) {
            // Zooming scales the already-rasterized layer, which blurs text and strokes.
            // Re-rasterizing the hosted tree at the effective scale keeps them crisp.
            let effective = min(UIScreen.main.scale * scale, UIScreen.main.scale * 4)
            applyContentScale(effective, to: view ?? scrollView)
        }

        private func applyContentScale(_ scale: CGFloat, to view: UIView) {
            view.contentScaleFactor = scale
            view.layer.contentsScale = scale
            for subview in view.subviews {
                applyContentScale(scale, to: subview)
            }
        }
    }
}
#endif
