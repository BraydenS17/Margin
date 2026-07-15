import SwiftUI
import SwiftData

/// The typed layer of a handwritten (canvas) page: freely positioned text boxes over
/// the drawing surface. Each box drags by its grip handle — the text area itself stays
/// a plain editing target so dragging and typing never fight.
struct TextBoxLayer: View {
    @Bindable var page: Page

    @Environment(\.modelContext) private var modelContext

    private var boxes: [TextBox] {
        (page.textBoxes ?? []).sorted { $0.createdAt < $1.createdAt }
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Give the ZStack the full page area without stealing touches from it.
            Color.clear
            ForEach(boxes) { box in
                DraggableTextBox(box: box) {
                    modelContext.delete(box)
                    page.updatedAt = Date()
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

private struct DraggableTextBox: View {
    @Bindable var box: TextBox
    var onDelete: () -> Void

    @State private var dragOffset: CGSize = .zero
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 0) {
            grip
            TextField("Text", text: $box.text, axis: .vertical)
                .font(.system(size: 15))
                .foregroundStyle(Theme.text)
                .focused($focused)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
        }
        .frame(width: box.width)
        .background(Theme.background.opacity(focused ? 0.97 : 0.85), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .strokeBorder(focused ? Theme.accent : Theme.border, lineWidth: focused ? 1.5 : 1)
        )
        .offset(
            x: box.x + dragOffset.width,
            y: box.y + dragOffset.height
        )
        .animation(nil, value: dragOffset)
        .onChange(of: box.text) { _, _ in
            box.page?.updatedAt = Date()
        }
    }

    /// The drag handle: a dotted bar across the top of the box — sized for a fingertip,
    /// not a cursor.
    private var grip: some View {
        HStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { _ in
                Circle().fill(Theme.muted.opacity(0.7)).frame(width: 4.5, height: 4.5)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 28)
        .background(Theme.surface, in: UnevenRoundedRectangle(topLeadingRadius: 9, topTrailingRadius: 9))
        .contentShape(Rectangle())
        .gesture(
            DragGesture()
                .onChanged { value in
                    dragOffset = value.translation
                }
                .onEnded { value in
                    box.x = max(0, box.x + value.translation.width)
                    box.y = max(0, box.y + value.translation.height)
                    dragOffset = .zero
                    box.page?.updatedAt = Date()
                }
        )
        .contextMenu {
            Menu("Width", systemImage: "arrow.left.and.right") {
                Button("Narrow") { box.width = 170 }
                Button("Medium") { box.width = 240 }
                Button("Wide") { box.width = 330 }
            }
            Button("Delete Text Box", systemImage: "trash", role: .destructive, action: onDelete)
        }
        .accessibilityLabel("Move Text Box")
    }
}
