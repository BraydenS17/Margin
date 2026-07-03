//
//  PDFInkSpikeView.swift
//  Margin
//
//  THROWAWAY SPIKE — not integrated with the app's Page/Block data model.
//  Its only job is to prove (or disprove) that PencilKit ink can be drawn
//  on top of a zoomed/scrolled PDFKit page without blurring, drifting out
//  of alignment, or having touches swallowed by PDFView's own pan/pinch
//  gesture recognizers.
//
//  See "Biggest technical risk" in Margin/CLAUDE.md — this file is that
//  spike. Delete this whole folder once M4 lands with a real answer.
//
//  Reach this view for manual testing via the flask-icon toolbar button
//  added to RootView (#if DEBUG only, ~3 lines).
//

#if os(iOS)
import SwiftUI
import PDFKit
import PencilKit

// MARK: - Sample PDF generation

/// Generates a small multi-page PDF at runtime so this spike has no
/// bundled-asset dependency. Includes fine text + a thin ruled grid + a
/// couple of reference shapes so blur/misalignment from canvas scaling is
/// easy to spot visually once you pinch-zoom.
enum SamplePDFFactory {
    static func makeDocument() -> PDFDocument {
        let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792) // US Letter
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)
        let data = renderer.pdfData { context in
            for pageIndex in 1...2 {
                context.beginPage()
                let cgContext = context.cgContext

                let title = "Spike Test Page \(pageIndex)" as NSString
                let titleAttrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.boldSystemFont(ofSize: 28),
                    .foregroundColor: UIColor.black
                ]
                title.draw(at: CGPoint(x: 36, y: 36), withAttributes: titleAttrs)

                let body = """
                Draw with Apple Pencil on top of this PDF page, then pinch \
                to zoom in and out with two fingers. Watch whether the ink \
                stays crisp and perfectly aligned with the ruled lines and \
                shapes below, or whether it blurs / drifts relative to the \
                page content.
                """ as NSString
                let bodyAttrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 11),
                    .foregroundColor: UIColor.darkGray
                ]
                body.draw(with: CGRect(x: 36, y: 80, width: 540, height: 80),
                          options: .usesLineFragmentOrigin,
                          attributes: bodyAttrs, context: nil)

                // Fine ruled grid — great for spotting misalignment/blur at zoom.
                cgContext.setStrokeColor(UIColor.systemBlue.withAlphaComponent(0.5).cgColor)
                cgContext.setLineWidth(0.5)
                var y: CGFloat = 180
                while y < 750 {
                    cgContext.move(to: CGPoint(x: 36, y: y))
                    cgContext.addLine(to: CGPoint(x: 576, y: y))
                    y += 18
                }
                cgContext.strokePath()

                // Reference shapes to align ink against.
                cgContext.setStrokeColor(UIColor.systemRed.cgColor)
                cgContext.setLineWidth(1.5)
                cgContext.stroke(CGRect(x: 100, y: 200, width: 120, height: 120))
                cgContext.strokeEllipse(in: CGRect(x: 300, y: 200, width: 120, height: 120))
            }
        }
        return PDFDocument(data: data) ?? PDFDocument()
    }
}

// MARK: - Host view

struct PDFInkSpikeView: View {
    var body: some View {
        VStack(spacing: 0) {
            Text("Pinch to zoom, then draw with Apple Pencil. Ink should stay crisp & aligned with the page underneath.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(8)
                .frame(maxWidth: .infinity)
                .background(.thinMaterial)
            SpikePDFKitView()
        }
        .navigationTitle("PDF + Ink Spike")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - UIViewRepresentable wrapper

/// Hosts a `PDFView` configured per the two concrete mitigations named in
/// CLAUDE.md: a `PDFPageOverlayViewProvider` supplying one `PKCanvasView`
/// per page, and `usePageViewController(false)`.
private struct SpikePDFKitView: UIViewRepresentable {
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.document = SamplePDFFactory.makeDocument()
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical

        // Mitigation #1: PDFPageOverlayViewProvider is only reliably
        // consulted with the page-turning UIPageViewController disabled.
        pdfView.usePageViewController(false)

        pdfView.pageOverlayViewProvider = context.coordinator
        context.coordinator.pdfView = pdfView

        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.scaleDidChange),
            name: Notification.Name.PDFViewScaleChanged,
            object: pdfView
        )

        return pdfView
    }

    func updateUIView(_ uiView: PDFView, context: Context) {}

    // MARK: Coordinator

    final class Coordinator: NSObject, PDFPageOverlayViewProvider, PKCanvasViewDelegate, UIGestureRecognizerDelegate {
        weak var pdfView: PDFView?

        // Keyed by ObjectIdentifier rather than PDFPage itself since
        // PDFPage doesn't reliably conform to Hashable across SDKs.
        private var canvasesByPage: [ObjectIdentifier: PKCanvasView] = [:]
        private var drawingsByPage: [ObjectIdentifier: PKDrawing] = [:]
        private let toolPicker = PKToolPicker()
        private var gestureDelegateInstalled = false

        // MARK: PDFPageOverlayViewProvider

        func pdfView(_ pdfView: PDFView, overlayViewFor page: PDFPage) -> UIView? {
            let key = ObjectIdentifier(page)
            installGestureWorkaroundIfNeeded(on: pdfView)

            if let existing = canvasesByPage[key] {
                return existing
            }

            let canvas = PKCanvasView()
            canvas.backgroundColor = .clear
            canvas.isOpaque = false
            // .anyInput (rather than .pencilOnly) so this is also pokeable
            // with a mouse/finger in Simulator, which has no real Apple
            // Pencil. Production would likely use the app's mode toggle
            // instead of relying on input-type alone.
            canvas.drawingPolicy = .anyInput
            canvas.delegate = self

            if let restored = drawingsByPage[key] {
                canvas.drawing = restored
            }

            // Keep the canvas's backing store rendered at native screen
            // scale. PencilKit ink itself is vector data (PKDrawing), but
            // the canvas's CALayer is still a bitmap-backed layer at
            // `contentScaleFactor`. If PDFKit ever moves/scales the
            // overlay view via a CGAffineTransform instead of relayout,
            // a stale low contentScaleFactor is what makes strokes look
            // soft. Forcing this here — and re-asserting it in
            // scaleDidChange() below — is the "drive canvas scale from
            // PDF zoom" mitigation called out in CLAUDE.md.
            canvas.contentScaleFactor = UIScreen.main.scale

            canvasesByPage[key] = canvas
            return canvas
        }

        func pdfView(_ pdfView: PDFView, willDisplayOverlayView overlayView: UIView, for page: PDFPage) {
            guard let canvas = overlayView as? PKCanvasView else { return }
            canvas.becomeFirstResponder()
            toolPicker.setVisible(true, forFirstResponder: canvas)
            toolPicker.addObserver(canvas)
        }

        func pdfView(_ pdfView: PDFView, didEndDisplayingOverlayView overlayView: UIView, for page: PDFPage) {
            guard let canvas = overlayView as? PKCanvasView else { return }
            drawingsByPage[ObjectIdentifier(page)] = canvas.drawing
        }

        // MARK: Zoom handling

        @objc func scaleDidChange() {
            // Empirically (see report), PDFKit resizes each overlay
            // view's *frame* to match the page's on-screen size at the
            // current zoom rather than leaving bounds fixed and applying
            // a transform. Because PKCanvasView re-renders its vector
            // strokes at whatever frame size it's given, that alone keeps
            // ink crisp with no manual transform math. Re-assert
            // contentScaleFactor here as a defensive measure in case
            // UIKit resets it during the resize.
            for canvas in canvasesByPage.values {
                canvas.contentScaleFactor = UIScreen.main.scale
            }
        }

        // MARK: Gesture conflict workaround

        /// The crux of the "touches swallowed" risk: PDFView installs its
        /// own pan (scroll) and pinch (zoom) gesture recognizers on its
        /// internal document view, hit-tested before/alongside the
        /// PKCanvasView overlay sitting on top of it. Left alone, a
        /// one-finger or Pencil drag can be claimed by PDFView's pan
        /// recognizer, starving the canvas of touches entirely.
        ///
        /// Fix used here: become the delegate of PDFView's own gesture
        /// recognizers and refuse touches whose `type == .pencil`. Finger
        /// touches still drive PDFView's native pan/pinch-to-zoom;
        /// Apple Pencil touches are ignored by PDFView and fall through
        /// to the PKCanvasView, which freely draws. In production this
        /// still leaves finger-drawing vs. finger-scrolling ambiguous,
        /// which is exactly what the app's planned per-page draw/edit
        /// mode toggle is for.
        private func installGestureWorkaroundIfNeeded(on pdfView: PDFView) {
            guard !gestureDelegateInstalled else { return }
            gestureDelegateInstalled = true
            for recognizer in pdfView.gestureRecognizers ?? [] {
                recognizer.delegate = self
            }
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldReceive touch: UITouch
        ) -> Bool {
            touch.type != .pencil
        }
    }
}

#Preview {
    NavigationStack {
        PDFInkSpikeView()
    }
}
#endif
