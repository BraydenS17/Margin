import SwiftUI

enum InkToolKind: String, CaseIterable, Identifiable {
    case pen, marker, eraser
    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .pen: return "pencil.tip"
        case .marker: return "highlighter"
        case .eraser: return "eraser"
        }
    }

    var label: String {
        switch self {
        case .pen: return "Pen"
        case .marker: return "Marker"
        case .eraser: return "Eraser"
        }
    }
}

/// Mirrors Notability's palm-rejection modes. `.auto` starts out accepting any input
/// and permanently switches to pencil-only the moment a real Apple Pencil touch is seen.
enum InkInputMode: String, CaseIterable, Identifiable {
    case auto, anyInput, pencilOnly
    var id: String { rawValue }

    var label: String {
        switch self {
        case .auto: return "Auto"
        case .anyInput: return "Finger + Pencil"
        case .pencilOnly: return "Pencil Only"
        }
    }

    var systemImage: String {
        switch self {
        case .auto: return "wand.and.stars"
        case .anyInput: return "hand.draw"
        case .pencilOnly: return "pencil.tip"
        }
    }
}

final class InkUndoController {
    var undo: () -> Void = {}
    var redo: () -> Void = {}
}

/// What a Pencil double-tap/squeeze should do, derived from the user's system-level
/// Apple Pencil preference (Settings > Apple Pencil) rather than hardcoded.
enum PencilGestureAction {
    case toggleEraser
    case previousTool
    case cycleColor
}

#if os(iOS)
import PencilKit

/// Detects real Apple Pencil touches at the UIKit level — PKCanvasView/PKCanvasViewDelegate
/// don't expose touch type directly, so this is the only reliable way to tell Pencil from
/// finger (as opposed to just "any input reached the canvas").
private final class PencilAwareCanvasView: PKCanvasView {
    var onTouches: ((Set<UITouch>) -> Void)?

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        onTouches?(touches)
        super.touchesBegan(touches, with: event)
    }
}

struct InkCanvasView: UIViewRepresentable {
    @Binding var inkData: Data?
    var tool: InkToolKind
    var color: Color
    var width: CGFloat
    var inputMode: InkInputMode
    @Binding var pencilDetected: Bool
    var undoController: InkUndoController
    var onPencilGesture: (PencilGestureAction) -> Void = { _ in }

    func makeUIView(context: Context) -> PKCanvasView {
        let canvasView = PencilAwareCanvasView()
        canvasView.backgroundColor = .clear
        canvasView.isOpaque = false
        canvasView.drawingPolicy = context.coordinator.drawingPolicy()
        canvasView.delegate = context.coordinator
        canvasView.drawing = context.coordinator.loadDrawing()
        canvasView.tool = context.coordinator.pkTool()
        canvasView.onTouches = { [weak canvasView] touches in
            guard touches.contains(where: { $0.type == .pencil }) else { return }
            DispatchQueue.main.async {
                guard let canvasView, !context.coordinator.parent.pencilDetected else { return }
                context.coordinator.parent.pencilDetected = true
                canvasView.drawingPolicy = context.coordinator.drawingPolicy()
            }
        }

        // Become first responder so the canvas has a live undo manager — but we never
        // attach a PKToolPicker, so no system drawing UI appears (we supply our own).
        DispatchQueue.main.async {
            canvasView.becomeFirstResponder()
        }

        let pencilInteraction = UIPencilInteraction()
        pencilInteraction.delegate = context.coordinator
        canvasView.addInteraction(pencilInteraction)

        context.coordinator.wireUndoController(canvasView: canvasView)
        return canvasView
    }

    func updateUIView(_ canvasView: PKCanvasView, context: Context) {
        context.coordinator.parent = self
        canvasView.tool = context.coordinator.pkTool()
        canvasView.drawingPolicy = context.coordinator.drawingPolicy()
        context.coordinator.wireUndoController(canvasView: canvasView)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    static func dismantleUIView(_ uiView: PKCanvasView, coordinator: Coordinator) {
        coordinator.saveNow(drawing: uiView.drawing)
    }

    final class Coordinator: NSObject, PKCanvasViewDelegate, UIPencilInteractionDelegate {
        var parent: InkCanvasView
        var saveWorkItem: DispatchWorkItem?

        init(_ parent: InkCanvasView) {
            self.parent = parent
        }

        func loadDrawing() -> PKDrawing {
            guard let data = parent.inkData else { return PKDrawing() }
            return (try? PKDrawing(data: data)) ?? PKDrawing()
        }

        func drawingPolicy() -> PKCanvasViewDrawingPolicy {
            switch parent.inputMode {
            case .auto: return parent.pencilDetected ? .pencilOnly : .anyInput
            case .anyInput: return .anyInput
            case .pencilOnly: return .pencilOnly
            }
        }

        func pkTool() -> PKTool {
            switch parent.tool {
            case .pen:
                return PKInkingTool(.pen, color: UIColor(parent.color), width: parent.width)
            case .marker:
                return PKInkingTool(.marker, color: UIColor(parent.color), width: parent.width * 3)
            case .eraser:
                return PKEraserTool(.bitmap)
            }
        }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            saveWorkItem?.cancel()
            let drawing = canvasView.drawing
            let workItem = DispatchWorkItem { [weak self] in
                self?.saveNow(drawing: drawing)
            }
            saveWorkItem = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6, execute: workItem)
        }

        func saveNow(drawing: PKDrawing) {
            saveWorkItem?.cancel()
            // An empty drawing round-trips as ~40 bytes of non-nil data; storing nil instead
            // keeps "has ink" checks (page rows, export) meaningful.
            parent.inkData = drawing.strokes.isEmpty ? nil : drawing.dataRepresentation()
        }

        func wireUndoController(canvasView: PKCanvasView) {
            parent.undoController.undo = { [weak canvasView] in canvasView?.undoManager?.undo() }
            parent.undoController.redo = { [weak canvasView] in canvasView?.undoManager?.redo() }
        }

        func pencilInteraction(_ interaction: UIPencilInteraction, didReceiveTap tap: UIPencilInteraction.Tap) {
            route(UIPencilInteraction.preferredTapAction)
        }

        func pencilInteraction(_ interaction: UIPencilInteraction, didReceiveSqueeze squeeze: UIPencilInteraction.Squeeze) {
            guard squeeze.phase == .ended else { return }
            route(UIPencilInteraction.preferredSqueezeAction)
        }

        private func route(_ preferred: UIPencilPreferredAction) {
            switch preferred {
            case .switchEraser:
                parent.onPencilGesture(.toggleEraser)
            case .switchPrevious:
                parent.onPencilGesture(.previousTool)
            case .showColorPalette, .showInkAttributes, .showContextualPalette:
                // No system palette in our custom toolbar — cycling the color is the
                // closest useful equivalent.
                parent.onPencilGesture(.cycleColor)
            default:
                break
            }
        }
    }
}
#else
struct InkCanvasView: View {
    @Binding var inkData: Data?
    var tool: InkToolKind
    var color: Color
    var width: CGFloat
    var inputMode: InkInputMode
    @Binding var pencilDetected: Bool
    var undoController: InkUndoController
    var onPencilGesture: (PencilGestureAction) -> Void = { _ in }

    var body: some View {
        Text("Ink editing is only available on iOS/iPadOS")
            .foregroundStyle(.secondary)
    }
}
#endif
