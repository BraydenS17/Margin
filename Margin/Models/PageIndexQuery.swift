import Foundation

/// Pure filtering/grouping for the page database ("Index" space) — kept off the views
/// so it can be unit-tested.
enum PageIndexQuery {
    /// Applies the active filters, newest-edited first. A nil filter means "any".
    static func filter(_ pages: [Page], tagID: UUID? = nil, notebookID: UUID? = nil, status: PageStatus? = nil) -> [Page] {
        pages
            .filter { page in
                if let tagID, !(page.tags ?? []).contains(where: { $0.id == tagID }) { return false }
                if let notebookID, page.notebook?.id != notebookID { return false }
                if let status, page.status != status { return false }
                return true
            }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    /// Board columns in fixed status order; every status gets a column even when empty,
    /// so cards always have somewhere to move.
    static func board(_ pages: [Page]) -> [(PageStatus, [Page])] {
        PageStatus.allCases.map { status in
            (status, filter(pages, status: status))
        }
    }
}
