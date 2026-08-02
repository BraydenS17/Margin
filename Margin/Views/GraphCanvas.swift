import SwiftUI

/// Draws axes and each sampled run of a `MathExpression` plot (a separate path per run,
/// so discontinuities like 1/x don't connect across the asymptote). Shared between the
/// live graph block (`BlockRowView`) and the static PDF export (`PageExporter`).
struct GraphCanvas: View {
    let runs: [[MathExpression.Point]]
    let xRange: ClosedRange<Double>
    let yRange: ClosedRange<Double>

    var body: some View {
        Canvas { context, size in
            func point(_ p: MathExpression.Point) -> CGPoint {
                let nx = (p.x - xRange.lowerBound) / (xRange.upperBound - xRange.lowerBound)
                let ny = (p.y - yRange.lowerBound) / (yRange.upperBound - yRange.lowerBound)
                return CGPoint(x: nx * size.width, y: size.height - ny * size.height)
            }

            // Axes (only drawn if they fall within the visible range).
            if yRange.contains(0) {
                let y = point(MathExpression.Point(x: xRange.lowerBound, y: 0)).y
                var axis = Path()
                axis.move(to: CGPoint(x: 0, y: y))
                axis.addLine(to: CGPoint(x: size.width, y: y))
                context.stroke(axis, with: .color(Theme.border), lineWidth: 1)
            }
            if xRange.contains(0) {
                let x = point(MathExpression.Point(x: 0, y: yRange.lowerBound)).x
                var axis = Path()
                axis.move(to: CGPoint(x: x, y: 0))
                axis.addLine(to: CGPoint(x: x, y: size.height))
                context.stroke(axis, with: .color(Theme.border), lineWidth: 1)
            }

            for run in runs {
                guard let first = run.first else { continue }
                var path = Path()
                path.move(to: point(first))
                for p in run.dropFirst() {
                    path.addLine(to: point(p))
                }
                context.stroke(path, with: .color(Theme.accent), lineWidth: 2)
            }
        }
    }
}
