import SwiftUI

/// Interface customization: accent color, appearance, and which home sections show.
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable private var settings = ThemeSettings.shared

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Make It Yours")
                            .font(.editorialDisplay(32))
                            .foregroundStyle(Theme.text)
                        AccentRule()
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Accent Color").metaLabel()
                        HStack(spacing: 12) {
                            ForEach(NotebookColor.allCases, id: \.self) { option in
                                Button {
                                    settings.accent = option
                                } label: {
                                    Circle()
                                        .fill(option.swatch)
                                        .frame(width: 38, height: 38)
                                        .overlay(
                                            Circle()
                                                .strokeBorder(Theme.text, lineWidth: settings.accent == option ? 2.5 : 0)
                                                .padding(-4)
                                        )
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(option.displayName)
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Appearance").metaLabel()
                        HStack(spacing: 0) {
                            ForEach(ThemeSettings.Appearance.allCases, id: \.self) { option in
                                Button {
                                    settings.appearance = option
                                } label: {
                                    Text(option.label)
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundStyle(settings.appearance == option ? Color.white : Theme.muted)
                                        .padding(.horizontal, 18)
                                        .padding(.vertical, 8)
                                        .background(settings.appearance == option ? Theme.accent : Color.clear, in: Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(3)
                        .background(Theme.surface, in: Capsule())
                        .overlay(Capsule().strokeBorder(Theme.border, lineWidth: 1))
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Home Screen").metaLabel()
                            .padding(.bottom, 8)
                        toggleRow("Due Soon", isOn: $settings.showDueSoon)
                        toggleRow("Jump Back In", isOn: $settings.showRecents)
                        toggleRow("Favorites", isOn: $settings.showFavorites)
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("About").metaLabel()

                        Text("Margin \(Self.versionString)")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Theme.text)
                        Text("Your notes are stored on this device. No account, no tracking.")
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.muted)

                        if let feedbackURL = Self.feedbackURL {
                            Link(destination: feedbackURL) {
                                Label("Send Beta Feedback", systemImage: "envelope")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(Theme.accent)
                            }
                            .padding(.top, 2)
                        }

                        Button {
                            settings.hasCompletedOnboarding = false
                            dismiss()
                        } label: {
                            Label("Replay Welcome Tour", systemImage: "sparkles")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(Theme.accent)
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 2)
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
        }
        .presentationDetents([.medium, .large])
    }

    private static var versionString: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "\(version) (\(build))"
    }

    private static var feedbackURL: URL? {
        let subject = "Margin Beta Feedback \(versionString)"
            .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        return URL(string: "mailto:braydensally@gmail.com?subject=\(subject)")
    }

    private func toggleRow(_ title: String, isOn: Binding<Bool>) -> some View {
        Toggle(title, isOn: isOn)
            .font(.system(size: 15, weight: .semibold))
            .tint(Theme.accent)
            .padding(.vertical, 6)
    }
}
