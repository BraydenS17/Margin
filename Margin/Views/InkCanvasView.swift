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

final class InkUndoController {
    var undo: () -> Void = {}
    var redo: () -> Void = {}
}

#if os(iOS)
import PencilKit

struct InkCanvasView: UIViewRepresentable {
    @Binding var inkData: Data?
    var tool: InkToolKind
    var color: Color
    var width: CGFloat
    var undoController: InkUndoController

    func makeUIView(context: Context) -> PKCanvasView {
        let canvasView = PKCanvasView()
        canvasView.backgroundColor = .clear
        canvasView.isOpaque = false
        canvasView.drawingPolicy = .anyInput
        canvasView.delegate = context.coordinator
        canvasView.drawing = context.coordinator.loadDrawing()
        canvasView.tool = context.coordinator.pkTool()

        // Become first responder so the canvas has a live undo manager — but we never
        // attach a PKToolPicker, so no system drawing UI appears (we supply our own).
        DispatchQueue.main.async {
            canvasView.becomeFirstResponder()
        }

        context.coordinator.wireUndoController(canvasView: canvasView)
        return canvasView
    }

    func updateUIView(_ canvasView: PKCanvasView, context: Context) {
        context.coordinator.parent = self
        canvasView.tool = context.coordinator.pkTool()
        context.coordinator.wireUndoController(canvasView: canvasView)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    static func dismantleUIView(_ uiView: PKCanvasView, coordinator: Coordinator) {
        coordinator.saveNow(drawing: uiView.drawing)
    }

    final class Coordinator: NSObject, PKCanvasViewDelegate {
        var parent: InkCanvasView
        var saveWorkItem: DispatchWorkItem?

        init(_ parent: InkCanvasView) {
            self.parent = parent
        }

        func loadDrawing() -> PKDrawing {
            guard let data = parent.inkData else { return PKDrawing() }
            return (try? PKDrawing(data: data)) ?? PKDrawing()
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
            parent.inkData = drawing.dataRepresentation()
        }

        func wireUndoController(canvasView: PKCanvasView) {
            parent.undoController.undo = { [weak canvasView] in canvasView?.undoManager?.undo() }
            parent.undoController.redo = { [weak canvasView] in canvasView?.undoManager?.redo() }
        }
    }
}
#else
struct InkCanvasView: View {
    @Binding var inkData: Data?
    var tool: InkToolKind
    var color: Color
    var width: CGFloat
    var undoController: InkUndoController

    var body: some View {
        Text("Ink editing is only available on iOS/iPadOS")
            .foregroundStyle(.secondary)
    }
}
#endif
