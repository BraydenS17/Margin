import SwiftUI
import SwiftData

/// A flashcard deck: manage cards, then drill them in study mode.
struct DeckView: View {
    @Bindable var deck: Deck

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var newFront = ""
    @State private var newBack = ""
    @State private var studying = false

    private var cards: [Flashcard] {
        (deck.cards ?? []).sorted { $0.sortIndex < $1.sortIndex }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    header
                    composer
                    if !cards.isEmpty {
                        cardList
                    }
                }
                .padding(24)
            }
            .background(Theme.background)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .fullScreenCover(isPresented: $studying) {
                StudyView(deck: deck)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Circle().fill(deck.color.swatch).frame(width: 12, height: 12)
                Text(deck.title)
                    .font(.editorialDisplay(32))
                    .foregroundStyle(Theme.text)
                Spacer()
                if cards.count > 0 {
                    Button {
                        studying = true
                    } label: {
                        Label("Study", systemImage: "rectangle.stack")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(Color.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 9)
                            .background(Theme.accent, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("Study Deck")
                }
            }
            AccentRule()
            Text("\(cards.count) \(cards.count == 1 ? "card" : "cards")").metaLabel()
        }
    }

    private var composer: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Add a Card").metaLabel()
            HStack(spacing: 10) {
                TextField("Front (term)", text: $newFront)
                    .textFieldStyle(.plain)
                    .padding(10)
                    .background(Theme.surface, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous).strokeBorder(Theme.border, lineWidth: 1))
                TextField("Back (definition)", text: $newBack)
                    .textFieldStyle(.plain)
                    .padding(10)
                    .background(Theme.surface, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous).strokeBorder(Theme.border, lineWidth: 1))
                FlatIconButton(systemName: "plus", label: "Add Card") {
                    let front = newFront.trimmingCharacters(in: .whitespaces)
                    guard !front.isEmpty else { return }
                    let card = Flashcard(front: front, back: newBack.trimmingCharacters(in: .whitespaces), sortIndex: cards.count, deck: deck)
                    modelContext.insert(card)
                    deck.updatedAt = Date()
                    newFront = ""
                    newBack = ""
                }
            }
        }
    }

    private var cardList: some View {
        VStack(spacing: 0) {
            ForEach(cards) { card in
                HStack(alignment: .top, spacing: 14) {
                    Text(card.front)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Theme.text)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(card.back)
                        .font(.system(size: 15))
                        .foregroundStyle(Theme.muted)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(14)
                .contentShape(Rectangle())
                .contextMenu {
                    Button("Delete", systemImage: "trash", role: .destructive) {
                        modelContext.delete(card)
                        deck.updatedAt = Date()
                    }
                }
                if card.id != cards.last?.id {
                    Rectangle().fill(Theme.border).frame(height: 1)
                }
            }
        }
        .background(Theme.surface.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                .strokeBorder(Theme.border, lineWidth: 1)
        )
    }
}

/// Full-screen drill: tap to flip, arrows to move, shuffled each session.
private struct StudyView: View {
    let deck: Deck

    @Environment(\.dismiss) private var dismiss
    @State private var order: [Flashcard] = []
    @State private var index = 0
    @State private var revealed = false

    var body: some View {
        VStack(spacing: 28) {
            HStack {
                Text(deck.title.uppercased())
                    .metaLabel()
                Spacer()
                Button("End") { dismiss() }
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Theme.accent)
            }
            Spacer()

            if order.indices.contains(index) {
                let card = order[index]
                VStack(spacing: 18) {
                    Text(revealed ? "BACK" : "FRONT")
                        .metaLabel()
                    Text(revealed ? card.back : card.front)
                        .font(.editorialDisplay(30))
                        .foregroundStyle(Theme.text)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 560)
                }
                // Counter-rotate the text so the back face reads normally instead of mirrored.
                .rotation3DEffect(.degrees(revealed ? 180 : 0), axis: (x: 0, y: 1, z: 0))
                .frame(maxWidth: .infinity, minHeight: 300)
                .padding(30)
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(deck.color.swatch, lineWidth: 2)
                )
                .rotation3DEffect(.degrees(revealed ? 180 : 0), axis: (x: 0, y: 1, z: 0))
                .animation(.snappy(duration: 0.3), value: revealed)
                .onTapGesture { revealed.toggle() }
            }

            Spacer()
            HStack(spacing: 18) {
                FlatIconButton(systemName: "chevron.left", label: "Previous Card") {
                    guard index > 0 else { return }
                    index -= 1
                    revealed = false
                }
                .opacity(index > 0 ? 1 : 0.35)
                Text("\(min(index + 1, order.count)) OF \(order.count)")
                    .metaLabel()
                FlatIconButton(systemName: "chevron.right", label: "Next Card") {
                    guard index < order.count - 1 else { return }
                    index += 1
                    revealed = false
                }
                .opacity(index < order.count - 1 ? 1 : 0.35)
            }
        }
        .padding(28)
        .background(Theme.background)
        .onAppear {
            order = (deck.cards ?? []).shuffled()
        }
    }
}
