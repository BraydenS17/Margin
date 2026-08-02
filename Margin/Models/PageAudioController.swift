import Foundation
import Observation

#if os(iOS)
import AVFoundation

/// Drives one page's lecture-audio recording/playback session. Owned per-page by
/// `PageDetailView`: while recording, newly created blocks stamp `currentTimestamp` as
/// their `audioTimestamp` so tapping them later seeks playback to that moment.
@Observable
final class PageAudioController: NSObject {
    enum State: Equatable {
        case idle
        case recording
        case playing
        case paused
    }

    private(set) var state: State = .idle
    private(set) var elapsed: TimeInterval = 0
    private(set) var duration: TimeInterval = 0
    private(set) var permissionDenied = false

    private var recorder: AVAudioRecorder?
    private var player: AVAudioPlayer?
    private var timer: Timer?
    private var recordingURL: URL?

    var isRecording: Bool { state == .recording }
    var isPlaying: Bool { state == .playing }

    /// Elapsed seconds into the current recording, for stamping a newly created block —
    /// nil when not actively recording.
    var currentTimestamp: TimeInterval? {
        state == .recording ? elapsed : nil
    }

    func startRecording() {
        AVAudioApplication.requestRecordPermission { [weak self] granted in
            DispatchQueue.main.async {
                guard let self else { return }
                guard granted else {
                    self.permissionDenied = true
                    return
                }
                self.beginRecording()
            }
        }
    }

    private func beginRecording() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try session.setActive(true)
        } catch {
            return
        }

        let url = FileManager.default.temporaryDirectory.appendingPathComponent("margin-recording-\(UUID().uuidString).m4a")
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 44_100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
        ]
        guard let recorder = try? AVAudioRecorder(url: url, settings: settings) else { return }
        self.recorder = recorder
        self.recordingURL = url
        recorder.record()
        state = .recording
        elapsed = 0
        startTimer { [weak self] in
            guard let self, let recorder = self.recorder else { return }
            self.elapsed = recorder.currentTime
        }
    }

    /// Stops recording and returns the captured audio, or nil if nothing was recorded.
    func stopRecording() -> Data? {
        guard let recorder, let url = recordingURL else { return nil }
        let finalDuration = recorder.currentTime
        recorder.stop()
        stopTimer()
        self.recorder = nil
        self.recordingURL = nil
        state = .idle
        elapsed = 0
        defer { try? FileManager.default.removeItem(at: url) }
        guard let data = try? Data(contentsOf: url) else { return nil }
        duration = finalDuration
        return data
    }

    func discardRecording() {
        guard let recorder, let url = recordingURL else { return }
        recorder.stop()
        stopTimer()
        self.recorder = nil
        self.recordingURL = nil
        try? FileManager.default.removeItem(at: url)
        state = .idle
        elapsed = 0
    }

    /// Prepares an existing recording for playback without starting it.
    func loadForPlayback(_ data: Data) {
        guard let player = try? AVAudioPlayer(data: data) else { return }
        player.delegate = self
        self.player = player
        duration = player.duration
        elapsed = 0
        state = .idle
    }

    func play() {
        guard let player else { return }
        try? AVAudioSession.sharedInstance().setCategory(.playback)
        try? AVAudioSession.sharedInstance().setActive(true)
        player.play()
        state = .playing
        startTimer { [weak self] in
            guard let self, let player = self.player else { return }
            self.elapsed = player.currentTime
        }
    }

    func pause() {
        player?.pause()
        stopTimer()
        state = .paused
    }

    func seek(to time: TimeInterval) {
        player?.currentTime = max(0, min(time, duration))
        elapsed = player?.currentTime ?? time
    }

    private func startTimer(_ tick: @escaping () -> Void) {
        stopTimer()
        let t = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { _ in tick() }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
}

extension PageAudioController: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        stopTimer()
        state = .idle
        elapsed = 0
    }
}
#else
/// Non-iOS platforms don't get lecture-audio recording (no microphone story on macOS
/// build target here); this stub keeps the type available so views compile unchanged.
@Observable
final class PageAudioController: NSObject {
    enum State: Equatable { case idle, recording, playing, paused }
    private(set) var state: State = .idle
    private(set) var elapsed: TimeInterval = 0
    private(set) var duration: TimeInterval = 0
    private(set) var permissionDenied = false
    var isRecording: Bool { false }
    var isPlaying: Bool { false }
    var currentTimestamp: TimeInterval? { nil }
    func startRecording() {}
    func stopRecording() -> Data? { nil }
    func discardRecording() {}
    func loadForPlayback(_ data: Data) {}
    func play() {}
    func pause() {}
    func seek(to time: TimeInterval) {}
}
#endif
