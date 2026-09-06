import SwiftUI

/// First-run welcome tour: a few paged panels introducing the core ideas before the
/// student lands in the Library. Deliberately not a login screen — the app is
/// local-first with no accounts, so the front door just teaches and gets out of the way.
struct OnboardingView: View {
    let onFinish: () -> Void

    @State private var pageIndex = 0

    private struct Panel {
        let systemImage: String
        let kicker: String
        let title: String
        let message: String
    }

    private let panels: [Panel] = [
        Panel(
            systemImage: "square.stack",
            kicker: "Welcome to Margin",
            title: "Type and write on the same page",
            message: "Structured blocks like a doc, freehand Apple Pencil ink like a paper notebook — layered together on every page."
        ),
        Panel(
            systemImage: "pencil.tip.crop.circle",
            kicker: "Just start writing",
            title: "Tap to type. Touch Pencil to draw.",
            message: "Tap anywhere to type, and touch the page with your Apple Pencil to start drawing — or tap the pencil button to mark up by hand. Tap it again when you're done."
        ),
        Panel(
            systemImage: "doc.richtext",
            kicker: "Your semester, one place",
            title: "PDFs, templates, and review",
            message: "Import lecture slides and ink straight onto them. Start pages from course and planner templates. Turn any line into a flashcard, and track it all in the Library."
        ),
        Panel(
            systemImage: "sparkles",
            kicker: "No account needed",
            title: "Everything stays on your iPad",
            message: "Your notes are stored on-device — no sign-up, no login. A Getting Started notebook is waiting with a page to scribble on."
        ),
    ]

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            let panel = panels[pageIndex]
            VStack(spacing: 22) {
                Image(systemName: panel.systemImage)
                    .font(.system(size: 52, weight: .regular))
                    .foregroundStyle(Theme.accent)

                VStack(spacing: 10) {
                    Text(panel.kicker).metaLabel()
                    Text(panel.title)
                        .font(.editorialDisplay(30))
                        .foregroundStyle(Theme.text)
                        .multilineTextAlignment(.center)
                    Text(panel.message)
                        .font(.system(size: 16))
                        .foregroundStyle(Theme.muted)
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                        .frame(maxWidth: 420)
                }

                AccentRule()
                    .frame(width: 120)
            }
            .padding(.horizontal, 32)
            .id(pageIndex)
            .transition(.asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .move(edge: .leading).combined(with: .opacity)
            ))

            Spacer()

            HStack(spacing: 8) {
                ForEach(panels.indices, id: \.self) { index in
                    Capsule()
                        .fill(index == pageIndex ? Theme.accent : Theme.border)
                        .frame(width: index == pageIndex ? 22 : 8, height: 8)
                }
            }
            .padding(.bottom, 26)

            VStack(spacing: 12) {
                Button(action: advance) {
                    Text(isLastPanel ? "Start Taking Notes" : "Continue")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Color.white)
                        .frame(maxWidth: 420)
                        .frame(height: 50)
                        .background(Theme.accent, in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
                }
                .buttonStyle(.plain)

                Button("Skip") { onFinish() }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.muted)
                    .buttonStyle(.plain)
                    .opacity(isLastPanel ? 0 : 1)
                    .disabled(isLastPanel)
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 36)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background)
        .animation(.snappy, value: pageIndex)
    }

    private var isLastPanel: Bool { pageIndex == panels.count - 1 }

    private func advance() {
        if isLastPanel {
            onFinish()
        } else {
            pageIndex += 1
        }
    }
}

#Preview {
    OnboardingView(onFinish: {})
}
