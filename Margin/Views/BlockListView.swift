import SwiftUI
import SwiftData

private struct BlockHeightPreferenceKey: PreferenceKey {
    static var defaultValue: [UUID: CGFloat] = [:]
    static func reduce(value: inout [UUID: CGFloat], nextValue: () -> [UUID: CGFloat]) {
        value.merge(nextValue()) { _, new in new }
    }
}

struct BlockListView: View {
    @Bindable var page: Page
    @Environment(\.modelContext) private var modelContext
    @State private var rowHeights: [UUID: CGFloat] = [:]

    private var blocks: [Block] {
        (page.blocks ?? []).sorted { $0.sortIndex < $1.sortIndex }
    }

    /// List doesn't self-size inside an outer ScrollView, so total height is measured per row
    /// and summed here — rows vary a lot (tables, multi-line text, dividers).
    private var totalListHeight: CGFloat {
        blocks.reduce(0) { $0 + (rowHeights[$1.id] ?? 44) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if blocks.isEmpty {
                Text("Use + in the top bar to add content")
                    .font(.callout)
                    .foregroundStyle(.tertiary)
                    .padding(.vertical, 20)
            } else {
                List {
                    ForEach(blocks) { block in
                        BlockRowView(
                            block: block,
                            numberedListIndex: numberedListIndex(for: block),
                            onDelete: { delete(block) },
                            onDuplicate: { duplicate(block) }
                        )
                        .padding(.vertical, 3)
                        .background(
                            GeometryReader { proxy in
                                Color.clear.preference(
                                    key: BlockHeightPreferenceKey.self,
                                    value: [block.id: proxy.size.height]
                                )
                            }
                        )
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets())
                    }
                    .onMove(perform: moveBlocks)
                    .onDelete(perform: deleteBlocks)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .scrollDisabled(true)
                // Without this, List pads short rows up to its default minimum row height
                // (~44pt) while the GeometryReader only measures the content — the summed
                // frame then undercounts and the last row(s) clip under the add-block menu.
                .environment(\.defaultMinListRowHeight, 1)
                .frame(height: totalListHeight)
                .onPreferenceChange(BlockHeightPreferenceKey.self) { rowHeights = $0 }
            }
        }
        .padding(.horizontal)
        .padding(.bottom, 60)
    }



    private func delete(_ block: Block) {
        modelContext.delete(block)
        renumber()
    }

    private func duplicate(_ block: Block) {
        let copy = Block(type: block.type, textContent: block.textContent, sortIndex: block.sortIndex + 1, page: page)
        copy.isChecked = block.isChecked
        copy.indentLevel = block.indentLevel
        copy.tableData = block.tableData
        for sibling in blocks where sibling.sortIndex > block.sortIndex {
            sibling.sortIndex += 1
        }
        modelContext.insert(copy)
    }

    private func deleteBlocks(at offsets: IndexSet) {
        let current = blocks
        for offset in offsets {
            modelContext.delete(current[offset])
        }
        renumber()
    }

    private func moveBlocks(from source: IndexSet, to destination: Int) {
        var reordered = blocks
        reordered.move(fromOffsets: source, toOffset: destination)
        for (index, block) in reordered.enumerated() {
            block.sortIndex = index
        }
    }

    private func renumber() {
        for (index, block) in blocks.enumerated() {
            block.sortIndex = index
        }
    }

    /// Numbered-list blocks restart their count whenever interrupted by a different block type.
    private func numberedListIndex(for block: Block) -> Int {
        var count = 0
        for b in blocks {
            if b.type == .numberedList {
                count += 1
            } else {
                count = 0
            }
            if b.id == block.id { return count }
        }
        return count
    }
}
