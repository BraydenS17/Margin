import SwiftUI

final class InkUndoController {
    var undo: () -> Void = {}
    var redo: () -> Void = {}
}

#if os(iOS)
import PencilKit

struct InkCanvasView: UIViewRepresentable {
    @Binding var inkData: Data?
    var undoController: InkUndoController

    func makeUIView(context: Context) -> PKCanvasView {
        let canvasView = PKCanvasView()
        canvasView.backgroundColor = .clear
        canvasView.isOpaque = false
        canvasView.drawingPolicy = .anyInput
        canvasView.delegate = context.coordinator
        canvasView.drawing = context.coordinator.loadDrawing()

        let toolPicker = PKToolPicker()
        toolPicker.addObserver(canvasView)
        toolPicker.setVisible(true, forFirstResponder: canvasView)
        context.coordinator.toolPicker = toolPicker

        // The tool picker only shows/tracks undo-redo while the canvas is first responder.
        DispatchQueue.main.async {
            canvasView.becomeFirstResponder()
        }

        context.coordinator.wireUndoController(canvasView: canvasView)
        return canvasView
    }

    func updateUIView(_ canvasView: PKCanvasView, context: Context) {
        context.coordinator.parent = self
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
        var toolPicker: PKToolPicker?
        var saveWorkItem: DispatchWorkItem?

        init(_ parent: InkCanvasView) {
            self.parent = parent
        }

        func loadDrawing() -> PKDrawing {
            guard let data = parent.inkData else { return PKDrawing() }
            return (try? PKDrawing(data: data)) ?? PKDrawing()
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
    var undoController: InkUndoController

    var body: some View {
        Text("Ink editing is only available on iOS/iPadOS")
            .foregroundStyle(.secondary)
    }
}
#endif
