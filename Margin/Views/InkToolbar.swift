import SwiftUI

/// Flat, custom drawing toolbar that replaces PencilKit's system tool picker.
struct InkToolbar: View {
    @Binding var tool: InkToolKind
    @Binding var color: Color
    @Binding var width: CGFloat
    @Binding var inputMode: InkInputMode
    var pencilDetected: Bool

    static let palette: [Color] = [.black, Theme.accent, .red, .blue, .green, .purple]
    private var palette: [Color] { Self.palette }
    private let widths: [CGFloat] = [2, 4, 9, 16, 28]

    var body: some View {
        VStack(spacing: 8) {
            if inputMode == .auto {
                statusPill
            }
            HStack(spacing: 10) {
                inputModeMenu
                separator

                ForEach(InkToolKind.allCases) { kind in
                    toolButton(kind)
                }

                separator

                if tool != .eraser {
                    HStack(spacing: 2) {
                        ForEach(palette, id: \.self) { swatch($0) }
                    }
                    separator
                }

                HStack(spacing: 2) {
                    ForEach(widths, id: \.self) { widthDot($0) }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Theme.surface, in: Capsule())
            .overlay(Capsule().strokeBorder(Theme.border, lineWidth: 1))
            .shadow(color: .black.opacity(0.08), radius: 12, y: 4)
        }
    }

    private var statusPill: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(pencilDetected ? Theme.accent : Theme.muted)
                .frame(width: 6, height: 6)
            Text(pencilDetected ? "PENCIL DETECTED · FINGER SCROLLS" : "AUTO · WAITING FOR PENCIL")
        }
        .font(.system(size: 10, weight: .bold))
        .tracking(0.8)
        .foregroundStyle(pencilDetected ? Theme.accent : Theme.muted)
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(Theme.surface, in: Capsule())
        .overlay(Capsule().strokeBorder(Theme.border, lineWidth: 1))
    }

    /// Taps cycle Auto → Finger+Pencil → Pencil Only → Auto. A plain cycling button (rather
    /// than a system Menu) keeps this consistent with the rest of the flat, chrome-free
    /// toolbar — an icon-only Menu label picks up an automatic tinted-capsule "hint" style
    /// on iOS that clashes with the custom look everywhere else here.
    private var inputModeMenu: some View {
        Button {
            let all = InkInputMode.allCases
            let next = all[(all.firstIndex(of: inputMode)! + 1) % all.count]
            inputMode = next
        } label: {
            Image(systemName: inputMode.systemImage)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Theme.text)
                .frame(width: 44, height: 44)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Input Mode: \(inputMode.label). Tap to change.")
    }

    private var separator: some View {
        Rectangle().fill(Theme.border).frame(width: 1, height: 24)
    }

    private func toolButton(_ kind: InkToolKind) -> some View {
        let selected = tool == kind
        return Button {
            tool = kind
        } label: {
            Image(systemName: kind.systemImage)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(selected ? Color.white : Theme.text)
                .frame(width: 44, height: 44)
                .background(selected ? Theme.accent : Color.clear, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(kind.label)
    }

    private func swatch(_ c: Color) -> some View {
        let selected = color == c
        return Button {
            color = c
        } label: {
            Circle()
                .fill(c)
                .frame(width: 24, height: 24)
                .overlay(Circle().strokeBorder(Theme.border, lineWidth: c == .black ? 0 : 0.5))
                .overlay(
                    Circle()
                        .strokeBorder(Theme.accent, lineWidth: selected ? 2.5 : 0)
                        .padding(-3)
                )
                // The visible dot stays small; the finger target doesn't.
                .frame(width: 32, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func widthDot(_ w: CGFloat) -> some View {
        let selected = width == w
        return Button {
            width = w
        } label: {
            Circle()
                .fill(selected ? Theme.accent : Theme.muted)
                .frame(width: min(w + 6, 26), height: min(w + 6, 26))
                .frame(width: 36, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
