import SwiftUI

// Deliberately does NOT inherit Identifiable: Notebook/Page get their Identifiable
// conformance from the @Model macro, and re-stating it here (even indirectly) makes the
// macro's nonisolated PersistentModel conformance fail under default MainActor isolation.
protocol Renamable: AnyObject {
    var title: String { get }
}

extension Notebook: Renamable {}
extension Page: Renamable {}

/// Reusable rename dialog: set the binding to an item and an alert appears pre-filled
/// with its current title; committing a non-empty title calls `onCommit`.
private struct RenameAlert<Item: Renamable>: ViewModifier {
    @Binding var item: Item?
    let title: String
    let onCommit: (Item, String) -> Void

    @State private var draft = ""

    func body(content: Content) -> some View {
        content
            .onChange(of: item == nil) { _, isNil in
                if !isNil, let item { draft = item.title }
            }
            .alert(title, isPresented: Binding(
                get: { item != nil },
                set: { if !$0 { item = nil } }
            )) {
                TextField("Title", text: $draft)
                Button("Cancel", role: .cancel) { item = nil }
                Button("Rename") {
                    let trimmed = draft.trimmingCharacters(in: .whitespaces)
                    if let item, !trimmed.isEmpty {
                        onCommit(item, trimmed)
                    }
                    item = nil
                }
            }
    }
}

extension View {
    func renameAlert<Item: Renamable>(
        item: Binding<Item?>,
        title: String,
        onCommit: @escaping (Item, String) -> Void
    ) -> some View {
        modifier(RenameAlert(item: item, title: title, onCommit: onCommit))
    }
}
