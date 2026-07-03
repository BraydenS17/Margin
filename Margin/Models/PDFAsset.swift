import Foundation
import SwiftData

@Model
final class PDFAsset {
    var id: UUID = UUID()
    var fileName: String = "Untitled.pdf"
    var importedAt: Date = Date()
    var pageCount: Int = 0

    @Attribute(.externalStorage)
    var data: Data?

    @Relationship(deleteRule: .nullify, inverse: \Page.pdfAsset)
    var pages: [Page]? = []

    init(fileName: String = "Untitled.pdf", data: Data? = nil, pageCount: Int = 0) {
        self.id = UUID()
        self.fileName = fileName
        self.data = data
        self.pageCount = pageCount
        self.importedAt = Date()
    }
}
