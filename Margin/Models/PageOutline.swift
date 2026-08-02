import Foundation

/// Pure helpers for the page list's Notion-style nested-page outline, kept off the
/// views so they can be unit-tested.
enum PageOutline {
    struct Node {
        let page: Page
        let depth: Int
        let hasChildren: Bool
    }

    /// Flattens a page tree into display order, expanding only pages whose id is in
    /// `expanded`. Mirrors `BlockOutline.visible`'s collapse behavior for toggle blocks.
    static func visible(topLevel: [Page], expanded: Set<UUID>) -> [Node] {
        var result: [Node] = []
        func walk(_ pages: [Page], depth: Int) {
            for page in pages.sorted(by: { $0.sortIndex < $1.sortIndex }) {
                let children = page.subpages ?? []
                result.append(Node(page: page, depth: depth, hasChildren: !children.isEmpty))
                if !children.isEmpty && expanded.contains(page.id) {
                    walk(children, depth: depth + 1)
                }
            }
        }
        walk(topLevel, depth: 0)
        return result
    }
}
