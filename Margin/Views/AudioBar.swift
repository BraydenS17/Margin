import SwiftUI

/// Recording/playback control strip for a page's lecture audio. No recording yet ->
/// a Record button. Mid-recording -> elapsed time + Stop. Recorded -> a compact
/// play/pause/scrub bar plus a delete-to-rerecord option.
struct AudioBar: View {
    @Bindable var page: Page
    var controller: PageAudioController

    var body: some View {
        HStack(spacing: 12) {
            if controller.isRecording {
                recordingRow
            } else if page.audioData != nil {
                playbackRow
            } else {
                recordButton
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Theme.border, lineWidth: 1))
        .onAppear {
            if let data = page.audioData {
                controller.loadForPlayback(data)
            }
        }
        .onChange(of: page.audioData) { _, data in
            if let data {
                controller.loadForPlayback(data)
            }
        }
        .alert("Microphone Access Needed", isPresented: Binding(
            get: { controller.permissionDenied },
            set: { _ in }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Enable microphone access in Settings to record lecture audio.")
        }
    }

    private var recordButton: some View {
        Button {
            controller.startRecording()
        } label: {
            Label("Record Lecture Audio", systemImage: "mic.circle.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.accent)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("Record Lecture Audio")
    }

    private var recordingRow: some View {
        HStack(spacing: 12) {
            Circle().fill(Color.red).frame(width: 8, height: 8)
            Text(Self.format(controller.elapsed))
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundStyle(Theme.text)
            Spacer()
            Button {
                if let data = controller.stopRecording() {
                    page.audioData = data
                    page.audioDuration = controller.duration
                    page.updatedAt = Date()
                }
            } label: {
                Label("Stop", systemImage: "stop.circle.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.red)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("Stop Recording")
        }
    }

    private var playbackRow: some View {
        HStack(spacing: 12) {
            Button {
                controller.isPlaying ? controller.pause() : controller.play()
            } label: {
                Image(systemName: controller.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(Theme.accent)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier(controller.isPlaying ? "Pause Audio" : "Play Audio")

            Slider(
                value: Binding(
                    get: { controller.elapsed },
                    set: { controller.seek(to: $0) }
                ),
                in: 0...max(controller.duration, 0.1)
            )
            .tint(Theme.accent)

            Text("\(Self.format(controller.elapsed)) / \(Self.format(controller.duration))")
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(Theme.muted)
                .fixedSize()

            Button(role: .destructive) {
                controller.pause()
                page.audioData = nil
                page.audioDuration = nil
                page.updatedAt = Date()
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.muted)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Delete Recording")
        }
    }

    private static func format(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds.rounded()))
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}
