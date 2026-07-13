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
    var onOpenPage: ((Page) -> Void)? = nil

    @Environment(\.modelContext) private var modelContext
    @State private var rowHeights: [UUID: CGFloat] = [:]
    @FocusState private var focusedBlock: UUID?

    private var blocks: [Block] {
        (page.blocks ?? []).sorted { $0.sortIndex < $1.sortIndex }
    }

    /// Blocks actually on screen — collapsed toggles hide their indented children.
    private var visibleBlocks: [Block] {
        BlockOutline.visible(blocks)
    }

    /// List doesn't self-size inside an outer ScrollView, so total height is measured per row
    /// and summed here — rows vary a lot (tables, multi-line text, dividers).
    private var totalListHeight: CGFloat {
        visibleBlocks.reduce(0) { $0 + (rowHeights[$1.id] ?? 44) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if blocks.isEmpty {
                Button {
                    let block = Block(type: .paragraph, sortIndex: 0, page: page)
                    modelContext.insert(block)
                    focusedBlock = block.id
                } label: {
                    Text("Tap here or type “/” to add content")
                        .font(.callout)
                        .foregroundStyle(.tertiary)
                        .padding(.vertical, 20)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Add First Block")
            } else {
                List {
                    ForEach(visibleBlocks) { block in
                        VStack(alignment: .leading, spacing: 0) {
                            BlockRowView(
                                block: block,
                                numberedListIndex: numberedListIndex(for: block),
                                focus: $focusedBlock,
                                onDelete: { delete(block) },
                                onDuplicate: { duplicate(block) },
                                onSplit: { head, tail in split(block, head: head, tail: tail) },
                                onOpenPage: onOpenPage
                            )
                            .padding(.vertical, 3)
                            if isSlashMenuActive(for: block) {
                                SlashCommandMenu(query: String(block.textContent.dropFirst())) { type in
                                    apply(type, to: block)
                                }
                            }
                        }
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

    // MARK: - Slash commands

    /// The slash menu shows under the focused block while its text is a "/" command.
    private func isSlashMenuActive(for block: Block) -> Bool {
        focusedBlock == block.id
            && block.type.isTextual
            && block.textContent.hasPrefix("/")
            && !block.textContent.contains(" ")
    }

    /// Convert the slash-command block into the chosen type and clear the command text.
    private func apply(_ type: BlockType, to block: Block) {
        block.type = type
        block.textContent = ""
        block.updatedAt = Date()
        if type.isTextual {
            focusedBlock = block.id
        } else {
            focusedBlock = nil
        }
    }

    // MARK: - Return-key flow

    /// Notion return semantics: text before the caret stays, text after moves to a new
    /// focused block. Return on an empty list item exits the list back to a paragraph;
    /// a heading's continuation is a paragraph, everything else continues its own type.
    private func split(_ block: Block, head: String, tail: String) {
        let listTypes: Set<BlockType> = [.bulletList, .numberedList, .checkbox]
        if head.isEmpty && tail.isEmpty && listTypes.contains(block.type) {
            block.textContent = ""
            block.type = .paragraph
            block.indentLevel = 0
            block.updatedAt = Date()
            return
        }

        block.textContent = head
        block.updatedAt = Date()

        let continuation: BlockType = listTypes.contains(block.type) ? block.type : .paragraph
        let next = Block(type: continuation, textContent: tail, sortIndex: block.sortIndex + 1, page: page)
        next.indentLevel = block.indentLevel
        for sibling in blocks where sibling.sortIndex > block.sortIndex {
            sibling.sortIndex += 1
        }
        modelContext.insert(next)
        focusedBlock = next.id
    }

    // MARK: - Block housekeeping

    private func delete(_ block: Block) {
        modelContext.delete(block)
        renumber()
    }

    private func duplicate(_ block: Block) {
        let copy = Block(type: block.type, textContent: block.textContent, sortIndex: block.sortIndex + 1, page: page)
        copy.isChecked = block.isChecked
        copy.indentLevel = block.indentLevel
        copy.tableData = block.tableData
        copy.linkedPageID = block.linkedPageID
        for sibling in blocks where sibling.sortIndex > block.sortIndex {
            sibling.sortIndex += 1
        }
        modelContext.insert(copy)
    }

    private func deleteBlocks(at offsets: IndexSet) {
        let current = visibleBlocks
        for offset in offsets {
            modelContext.delete(current[offset])
        }
        renumber()
    }

    private func moveBlocks(from source: IndexSet, to destination: Int) {
        // Reorder within what's visible, then stitch hidden (collapsed) blocks back in
        // behind the toggle they belong to so their order is preserved.
        var reorderedVisible = visibleBlocks
        reorderedVisible.move(fromOffsets: source, toOffset: destination)
        let hidden = blocks.filter { block in !reorderedVisible.contains(where: { $0.id == block.id }) }
        var result: [Block] = []
        for block in reorderedVisible {
            result.append(block)
            if block.type == .toggle && block.isCollapsed {
                result.append(contentsOf: hiddenChildren(of: block, in: hidden))
            }
        }
        for orphan in hidden where !result.contains(where: { $0.id == orphan.id }) {
            result.append(orphan)
        }
        for (index, block) in result.enumerated() {
            block.sortIndex = index
        }
    }

    private func hiddenChildren(of toggle: Block, in hidden: [Block]) -> [Block] {
        var children: [Block] = []
        for block in blocks where block.sortIndex > toggle.sortIndex {
            if block.indentLevel <= toggle.indentLevel { break }
            if hidden.contains(where: { $0.id == block.id }) {
                children.append(block)
            }
        }
        return children
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

/// The Notion-style "/" menu: appears under the block being typed in, filters as the
/// user keeps typing, and converts the block on selection.
private struct SlashCommandMenu: View {
    let query: String
    let onSelect: (BlockType) -> Void

    var body: some View {
        let matches = BlockOutline.slashMatches(query)
        VStack(alignment: .leading, spacing: 0) {
            Text(query.isEmpty ? "Insert a block" : "Blocks matching “\(query)”")
                .metaLabel()
                .padding(.horizontal, 14)
                .padding(.top, 12)
                .padding(.bottom, 6)
            if matches.isEmpty {
                Text("No matches — keep typing or delete the “/”")
                    .font(.callout)
                    .foregroundStyle(Theme.muted)
                    .padding(.horizontal, 14)
                    .padding(.bottom, 12)
            } else {
                ForEach(matches, id: \.self) { type in
                    Button {
                        onSelect(type)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: type.systemImage)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Theme.accent)
                                .frame(width: 24)
                            Text(type.displayName)
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(Theme.text)
                            Spacer()
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.bottom, 6)
        .frame(maxWidth: 340, alignment: .leading)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Theme.border, lineWidth: 1))
        .shadow(color: .black.opacity(0.08), radius: 12, y: 4)
        .padding(.vertical, 6)
    }
}
