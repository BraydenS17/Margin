import SwiftUI

/// Curated emoji picker for page icons, matching the flat editorial style.
struct IconPickerView: View {
    let current: String
    let onSelect: (String) -> Void

    @Environment(\.dismiss) private var dismiss

    private static let emoji: [String] = [
        "📚", "📖", "📝", "✏️", "🧠", "🔬", "🧪", "🧬", "⚗️", "🔭",
        "📐", "📏", "🧮", "💻", "⌨️", "🌍", "🗺️", "🏛️", "⚖️", "🎨",
        "🎭", "🎵", "📊", "📈", "💡", "🎯", "🗓️", "⏰", "✅", "⭐️",
        "🔥", "🚀", "🌱", "☕️", "🏃", "❤️", "🇫🇷", "🇪🇸", "🇩🇪", "🇯🇵",
    ]

    private let columns = [GridItem(.adaptive(minimum: 52), spacing: 8)]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Page Icon")
                            .font(.editorialDisplay(28))
                            .foregroundStyle(Theme.text)
                        AccentRule()
                    }

                    Button {
                        onSelect("")
                        dismiss()
                    } label: {
                        Label("No Icon", systemImage: "circle.slash")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(current.isEmpty ? Color.white : Theme.text)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(current.isEmpty ? Theme.accent : Theme.surface, in: Capsule())
                            .overlay(Capsule().strokeBorder(Theme.border, lineWidth: current.isEmpty ? 0 : 1))
                    }
                    .buttonStyle(.plain)

                    LazyVGrid(columns: columns, spacing: 8) {
                        ForEach(Self.emoji, id: \.self) { emoji in
                            Button {
                                onSelect(emoji)
                                dismiss()
                            } label: {
                                Text(emoji)
                                    .font(.system(size: 30))
                                    .frame(width: 52, height: 52)
                                    .background(Theme.surface, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .strokeBorder(current == emoji ? Theme.accent : Theme.border, lineWidth: current == emoji ? 2 : 1)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(20)
            }
            .background(Theme.background)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
