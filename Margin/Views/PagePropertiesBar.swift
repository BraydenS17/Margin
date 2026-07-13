import SwiftUI
import SwiftData

/// Notion-style property row under a page title: a study-status pill and tag chips.
/// Both are the raw material the Index space filters and groups by.
struct PagePropertiesBar: View {
    @Bindable var page: Page

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Tag.createdAt) private var allTags: [Tag]
    @State private var newTagName = ""
    @State private var showingNewTag = false

    private var pageTags: [Tag] {
        (page.tags ?? []).sorted { $0.name < $1.name }
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                statusMenu
                ForEach(pageTags) { tag in
                    tagChip(tag)
                }
                addTagMenu
            }
        }
        .alert("New Tag", isPresented: $showingNewTag) {
            TextField("Tag name", text: $newTagName)
            Button("Add") { createTag() }
            Button("Cancel", role: .cancel) { newTagName = "" }
        } message: {
            Text("Tags cut across notebooks — filter by them in the Index.")
        }
    }

    private var statusMenu: some View {
        Menu {
            ForEach(PageStatus.allCases, id: \.self) { status in
                Button {
                    page.status = status
                    page.updatedAt = Date()
                } label: {
                    Label(status.displayName, systemImage: page.status == status ? "checkmark" : status.systemImage)
                }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: page.status.systemImage)
                    .font(.system(size: 11, weight: .semibold))
                Text(page.status.displayName)
                    .font(.system(size: 12, weight: .bold))
            }
            .foregroundStyle(page.status == .none ? Theme.muted : Theme.accent)
            .padding(.horizontal, 11)
            .padding(.vertical, 6)
            .background(Theme.surface, in: Capsule())
            .overlay(Capsule().strokeBorder(
                page.status == .none ? Theme.border : Theme.accent.opacity(0.5), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Page Status")
    }

    private func tagChip(_ tag: Tag) -> some View {
        HStack(spacing: 6) {
            Circle().fill(tag.color.swatch).frame(width: 7, height: 7)
            Text(tag.name)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.text)
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 6)
        .background(tag.color.swatch.opacity(0.08), in: Capsule())
        .overlay(Capsule().strokeBorder(tag.color.swatch.opacity(0.35), lineWidth: 1))
        .contextMenu {
            Button("Remove From Page", systemImage: "minus.circle") {
                page.tags?.removeAll { $0.id == tag.id }
                page.updatedAt = Date()
            }
            Button("Delete Tag Everywhere", systemImage: "trash", role: .destructive) {
                modelContext.delete(tag)
            }
        }
    }

    private var addTagMenu: some View {
        Menu {
            ForEach(allTags) { tag in
                let applied = (page.tags ?? []).contains { $0.id == tag.id }
                Button {
                    if applied {
                        page.tags?.removeAll { $0.id == tag.id }
                    } else {
                        if page.tags == nil { page.tags = [] }
                        page.tags?.append(tag)
                    }
                    page.updatedAt = Date()
                } label: {
                    Label(tag.name, systemImage: applied ? "checkmark" : "tag")
                }
            }
            if !allTags.isEmpty {
                Divider()
            }
            Button("New Tag…", systemImage: "plus") { showingNewTag = true }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "tag")
                    .font(.system(size: 11, weight: .semibold))
                Text(pageTags.isEmpty ? "Add Tag" : "")
                    .font(.system(size: 12, weight: .bold))
            }
            .foregroundStyle(Theme.muted)
            .padding(.horizontal, 11)
            .padding(.vertical, 6)
            .background(Theme.surface, in: Capsule())
            .overlay(Capsule().strokeBorder(Theme.border, style: StrokeStyle(lineWidth: 1, dash: [4, 3])))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Add Tag")
    }

    private func createTag() {
        let name = newTagName.trimmingCharacters(in: .whitespaces)
        newTagName = ""
        guard !name.isEmpty else { return }
        // Reuse an existing tag with the same name instead of minting a duplicate.
        if let existing = allTags.first(where: { $0.name.localizedCaseInsensitiveCompare(name) == .orderedSame }) {
            if !(page.tags ?? []).contains(where: { $0.id == existing.id }) {
                if page.tags == nil { page.tags = [] }
                page.tags?.append(existing)
            }
            return
        }
        let palette = NotebookColor.allCases
        let tag = Tag(name: name, color: palette[allTags.count % palette.count])
        modelContext.insert(tag)
        if page.tags == nil { page.tags = [] }
        page.tags?.append(tag)
        page.updatedAt = Date()
    }
}
