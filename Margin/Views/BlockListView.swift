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
                Text("Tap + to add content")
                    .font(.callout)
                    .foregroundStyle(.tertiary)
                    .padding(.vertical, 20)
            } else {
                List {
                    ForEach(blocks) { block in
                        BlockRowView(
                            block: block,
                            numberedListIndex: numberedListIndex(for: block),
                            onDelete: { delete(block) }
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
                .frame(height: totalListHeight)
                .onPreferenceChange(BlockHeightPreferenceKey.self) { rowHeights = $0 }
            }
            addBlockMenu
        }
        .padding(.horizontal)
        .padding(.bottom, 60)
    }

    private var addBlockMenu: some View {
        Menu {
            Section("Text") {
                addButton(.heading)
                addButton(.paragraph)
                addButton(.quote)
                addButton(.callout)
            }
            Section("Lists") {
                addButton(.bulletList)
                addButton(.numberedList)
                addButton(.checkbox)
            }
            Section("Structure") {
                addButton(.table)
                addButton(.image)
                addButton(.divider)
            }
        } label: {
            Label("Add Block", systemImage: "plus.circle.fill")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 10)
    }

    private func addButton(_ type: BlockType) -> some View {
        Button {
            addBlock(type: type)
        } label: {
            Label(type.displayName, systemImage: type.systemImage)
        }
    }

    private func addBlock(type: BlockType) {
        let block = Block(type: type, sortIndex: blocks.count, page: page)
        modelContext.insert(block)
    }

    private func delete(_ block: Block) {
        modelContext.delete(block)
        renumber()
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
