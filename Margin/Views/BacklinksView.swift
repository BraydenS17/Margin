import SwiftUI
import SwiftData

/// "Linked from" footer, Notion-style: every page containing a page-link block that
/// points at this page, shown as tappable chips.
struct BacklinksView: View {
    let page: Page
    var onOpenPage: ((Page) -> Void)? = nil

    @Query private var allBlocks: [Block]

    private var linkingPages: [Page] {
        let target = page.id
        var seen = Set<UUID>()
        var result: [Page] = []
        for block in allBlocks where block.linkedPageID == target {
            guard let source = block.page, source.id != target, !seen.contains(source.id) else { continue }
            seen.insert(source.id)
            result.append(source)
        }
        return result.sorted { $0.title < $1.title }
    }

    var body: some View {
        let sources = linkingPages
        if !sources.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("Linked From").metaLabel()
                FlowChips(pages: sources, onOpenPage: onOpenPage)
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 40)
        }
    }
}

private struct FlowChips: View {
    let pages: [Page]
    var onOpenPage: ((Page) -> Void)?

    var body: some View {
        // A simple wrapping row is overkill for the handful of backlinks a student
        // page collects — a horizontal scroll keeps it one line and never clips.
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(pages) { page in
                    Button {
                        onOpenPage?(page)
                    } label: {
                        HStack(spacing: 6) {
                            if page.icon.isEmpty {
                                Image(systemName: "doc.text")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(Theme.accent)
                            } else {
                                Text(page.icon).font(.system(size: 13))
                            }
                            Text(page.title)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Theme.text)
                                .lineLimit(1)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(Theme.surface, in: Capsule())
                        .overlay(Capsule().strokeBorder(Theme.border, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Open \(page.title)")
                }
            }
        }
    }
}
