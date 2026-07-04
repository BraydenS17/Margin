import SwiftUI

/// Modern-editorial design system: high contrast, confident type, an electric-orange
/// accent, and thin rules. Colors live in the asset catalog so they adapt light/dark.
enum Theme {
    static let accent = Color.accentColor
    static let background = Color("ThemeBackground")
    static let surface = Color("ThemeSurface")
    static let text = Color("ThemeText")
    static let muted = Color("ThemeMuted")
    static let border = Color("ThemeBorder")

    enum Radius {
        static let card: CGFloat = 14
        static let chip: CGFloat = 10
    }
}

extension Font {
    /// Big, confident heading — heavy weight, tight tracking.
    static func editorialDisplay(_ size: CGFloat) -> Font {
        .system(size: size, weight: .heavy, design: .default)
    }
}

extension View {
    /// Small uppercase, letter-spaced metadata label ("12 PAGES · UPDATED TODAY").
    func metaLabel() -> some View {
        self
            .font(.system(size: 11, weight: .semibold))
            .textCase(.uppercase)
            .tracking(1.3)
            .foregroundStyle(Theme.muted)
    }

    /// Bordered editorial surface used for cards.
    func editorialCard(padding: CGFloat = 16) -> some View {
        self
            .padding(padding)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                    .strokeBorder(Theme.border, lineWidth: 1)
            )
    }
}

/// Flat bordered icon button — the app's replacement for glass toolbar buttons.
struct FlatIconButton: View {
    let systemName: String
    var label: String = ""
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.accent)
                .frame(width: 36, height: 34)
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .strokeBorder(Theme.border, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label.isEmpty ? systemName : label)
    }
}

/// A hairline rule with an accent tick at the leading edge — the recurring editorial motif.
struct AccentRule: View {
    var body: some View {
        HStack(spacing: 0) {
            Rectangle()
                .fill(Theme.accent)
                .frame(width: 22, height: 2)
            Rectangle()
                .fill(Theme.border)
                .frame(height: 1)
        }
    }
}

/// Art-directed empty state: oversized accent glyph, heavy headline, rule, muted subtext.
struct EditorialEmptyState: View {
    let systemImage: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: systemImage)
                .font(.system(size: 44, weight: .regular))
                .foregroundStyle(Theme.accent)
            VStack(spacing: 8) {
                Text(title)
                    .font(.editorialDisplay(26))
                    .foregroundStyle(Theme.text)
                    .multilineTextAlignment(.center)
                Text(message)
                    .metaLabel()
                    .multilineTextAlignment(.center)
            }
            AccentRule()
                .frame(width: 120)
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background)
    }
}
