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

    private func toggleRow(_ title: String, isOn: Binding<Bool>) -> some View {
        Toggle(title, isOn: isOn)
            .font(.system(size: 15, weight: .semibold))
            .tint(Theme.accent)
            .padding(.vertical, 6)
    }
}
