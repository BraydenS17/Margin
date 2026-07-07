import SwiftUI

struct BlockRowView: View {
    @Bindable var block: Block
    var numberedListIndex: Int = 1
    var onDelete: () -> Void
    var onDuplicate: () -> Void = {}

    private static let maxIndent = 4
    private static let indentStep: CGFloat = 24

    var body: some View {
        content
            .padding(.leading, CGFloat(min(block.indentLevel, Self.maxIndent)) * Self.indentStep)
            .contextMenu {
                Menu("Turn Into", systemImage: "arrow.triangle.2.circlepath") {
                    ForEach(BlockType.allCases.filter { $0 != block.type && $0 != .image }, id: \.self) { type in
                        Button {
                            block.type = type
                            block.updatedAt = Date()
                        } label: {
                            Label(type.displayName, systemImage: type.systemImage)
                        }
                    }
                }
                Button("Duplicate", systemImage: "plus.square.on.square", action: onDuplicate)
                if block.indentLevel < Self.maxIndent {
                    Button("Indent", systemImage: "increase.indent") { block.indentLevel += 1 }
                }
                if block.indentLevel > 0 {
                    Button("Outdent", systemImage: "decrease.indent") { block.indentLevel -= 1 }
                }
                Button("Delete", systemImage: "trash", role: .destructive, action: onDelete)
            }
    }

    @ViewBuilder
    private var content: some View {
        switch block.type {
        case .heading:
            TextField("Heading", text: $block.textContent, axis: .vertical)
                .font(.title2.bold())
                .padding(.vertical, 4)

        case .paragraph:
            TextField("Type something…", text: $block.textContent, axis: .vertical)
                .font(.body)
                .padding(.vertical, 4)

        case .bulletList:
            HStack(alignment: .top, spacing: 10) {
                Text("•")
                    .font(.body)
                    .foregroundStyle(.secondary)
                TextField("List item", text: $block.textContent, axis: .vertical)
                    .font(.body)
            }
            .padding(.vertical, 4)

        case .numberedList:
            HStack(alignment: .top, spacing: 10) {
                Text("\(numberedListIndex).")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .frame(minWidth: 18, alignment: .trailing)
                TextField("List item", text: $block.textContent, axis: .vertical)
                    .font(.body)
            }
            .padding(.vertical, 4)

        case .checkbox:
            HStack(alignment: .top, spacing: 8) {
                Button {
                    block.isChecked.toggle()
                } label: {
                    Image(systemName: block.isChecked ? "checkmark.square.fill" : "square")
                        .font(.title3)
                        .foregroundStyle(block.isChecked ? Color.accentColor : Color.secondary)
                        .frame(width: 32, height: 32)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                TextField("To-do", text: $block.textContent, axis: .vertical)
                    .font(.body)
                    .strikethrough(block.isChecked)
                    .foregroundStyle(block.isChecked ? .secondary : .primary)
                    .padding(.top, 5)
            }

        case .divider:
            Divider()
                .padding(.vertical, 10)

        case .callout:
            HStack(alignment: .top, spacing: 10) {
                Text("💡")
                    .font(.body)
                TextField("Callout", text: $block.textContent, axis: .vertical)
                    .font(.body)
            }
            .padding(12)
            .background(.yellow.opacity(0.15), in: RoundedRectangle(cornerRadius: 10))

        case .quote:
            HStack(spacing: 10) {
                Rectangle()
                    .fill(.secondary)
                    .frame(width: 3)
                TextField("Quote", text: $block.textContent, axis: .vertical)
                    .font(.body)
                    .italic()
            }
            .padding(.vertical, 4)

        case .image:
            Label("Image blocks aren't supported yet", systemImage: "photo")
                .font(.callout)
                .foregroundStyle(.secondary)
                .padding(.vertical, 8)

        case .table:
            TableBlockView(block: block)
                .padding(.vertical, 6)
        }
    }
}
