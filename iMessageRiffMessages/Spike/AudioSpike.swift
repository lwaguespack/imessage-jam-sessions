import AVFoundation
import Foundation
import Observation
import QuartzCore

@MainActor
@Observable
final class AudioSpike {
    enum Mode: String {
        case stems = "90-second stems"
        case clock = "3-minute clock"
        case taps = "tap-along"
    }

    private(set) var status = "Stopped"
    private(set) var mode: Mode?
    private(set) var tapCount = 0

    @ObservationIgnored let report: SpikeReport
    @ObservationIgnored var engine: AVAudioEngine?
    @ObservationIgnored var nodes: [AVAudioPlayerNode] = []
    @ObservationIgnored private var files: [AVAudioFile] = []
    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored var observers: [NSObjectProtocol] = []
    @ObservationIgnored private var sessionActive = false
    @ObservationIgnored private var startHostTime = 0.0
    @ObservationIgnored var endHostTime = 0.0
    @ObservationIgnored private var latency = 0.0
    @ObservationIgnored private var offsets: [Double] = []
    @ObservationIgnored private var matchedClicks: Set<Int> = []
    @ObservationIgnored var baseline: [ClockSample]?
    @ObservationIgnored var sampleNumber = 0

    init(report: SpikeReport) {
        self.report = report
        observeAudioNotifications()
    }

    isolated deinit {
        timer?.invalidate()
        for observer in observers { NotificationCenter.default.removeObserver(observer) }
        for node in nodes { node.stop() }
        engine?.stop()
        if sessionActive {
            do {
                try AVAudioSession.sharedInstance().setActive(
                    false, options: .notifyOthersOnDeactivation)
            } catch {
                NSLog("Spike audio deactivation failed: %@", error.localizedDescription)
            }
        }
    }

    func inspectStems() {
        do {
            let a = try openStem("a")
            let b = try openStem("b")
            report.record(
                "S1.6 stemA frames=\(a.length) rate=\(a.processingFormat.sampleRate) "
                    + "stemB frames=\(b.length) rate=\(b.processingFormat.sampleRate) "
                    + "equalFrames=\(a.length == b.length)"
            )
        } catch {
            report.record("S1.6 ERROR \(error.localizedDescription)")
            status = "Error: \(error.localizedDescription)"
        }
    }

    func start(_ requestedMode: Mode) {
        if mode != nil { stop(reason: "restarted") }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default)
            try session.setActive(true)
            sessionActive = true

            let newEngine = AVAudioEngine()
            engine = newEngine
            let count = requestedMode == .taps ? 1 : 2
            nodes = (0..<count).map { _ in AVAudioPlayerNode() }
            files = []
            if requestedMode == .taps {
                let format = try clickFormat()
                newEngine.attach(nodes[0])
                newEngine.connect(nodes[0], to: newEngine.mainMixerNode, format: format)
                try scheduleClicks(on: nodes[0], format: format)
            } else {
                for (index, suffix) in ["a", "b"].enumerated() {
                    newEngine.attach(nodes[index])
                    let first = try openStem(suffix)
                    files.append(first)
                    newEngine.connect(
                        nodes[index], to: newEngine.mainMixerNode, format: first.processingFormat)
                    nodes[index].scheduleFile(first, at: nil)
                    if requestedMode == .clock {
                        let second = try openStem(suffix)
                        files.append(second)
                        nodes[index].scheduleFile(second, at: nil)
                    }
                }
                inspectStems()
            }

            newEngine.prepare()
            try newEngine.start()
            startHostTime = CACurrentMediaTime() + 1
            let time = AVAudioTime(hostTime: AVAudioTime.hostTime(forSeconds: startHostTime))
            for node in nodes { node.play(at: time) }

            mode = requestedMode
            status = "Running \(requestedMode.rawValue)"
            latency = nodes[0].outputPresentationLatency
            if latency <= 0 { latency = session.outputLatency }
            offsets = []
            matchedClicks = []
            tapCount = 0
            baseline = nil
            sampleNumber = 0
            let duration = requestedMode == .clock ? 180.0 : requestedMode == .stems ? 90.0 : 22.0
            endHostTime = startHostTime + duration
            report.record(
                "S1 START mode=\(requestedMode.rawValue) host=\(startHostTime) "
                    + "duration=\(duration) latencyApplied=\(latency)"
            )
            recordRoute()
            SpikeMemory.record("audio started", report: report)
            let newTimer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
                Task { @MainActor in self?.sample() }
            }
            timer = newTimer
            RunLoop.main.add(newTimer, forMode: .common)
        } catch {
            report.record("S1 START ERROR \(error.localizedDescription)")
            stop(reason: "start failed")
            status = "Error: \(error.localizedDescription)"
        }
    }

    func stop(reason: String = "user") {
        timer?.invalidate()
        timer = nil
        if mode == .taps { reportTapSummary() }
        for node in nodes { node.stop() }
        engine?.stop()
        nodes = []
        files = []
        engine = nil
        if sessionActive {
            do {
                try AVAudioSession.sharedInstance().setActive(
                    false, options: .notifyOthersOnDeactivation)
                sessionActive = false
            } catch {
                report.record("S1 DEACTIVATE ERROR \(error.localizedDescription)")
                status = "Audio deactivation failed: \(error.localizedDescription)"
                return
            }
        }
        report.record("S1 STOP reason=\(reason)")
        mode = nil
        status = "Stopped"
    }

    func tap(timestamp: TimeInterval) {
        guard mode == .taps else {
            report.record("S1 TAP ignored: tap-along is not running")
            return
        }
        let adjusted = timestamp - startHostTime - latency
        let click = Int((adjusted / 0.6).rounded())
        guard (0..<36).contains(click) else {
            report.record("S1 TAP outside click sequence timestamp=\(timestamp)")
            return
        }
        guard matchedClicks.insert(click).inserted else {
            report.record("S1 TAP duplicate click=\(click + 1)")
            return
        }
        let offset = (adjusted - Double(click) * 0.6) * 1_000
        let delivery = (CACurrentMediaTime() - timestamp) * 1_000
        if click >= 4 {
            offsets.append(offset)
            tapCount = offsets.count
        }
        report.record(
            "S1 TAP click=\(click + 1) warmup=\(click < 4) "
                + "offsetMs=\(String(format: "%.3f", offset)) "
                + "deliveryMs=\(String(format: "%.3f", delivery))"
        )
    }

    private func openStem(_ suffix: String) throws -> AVAudioFile {
        guard let url = Bundle.main.url(forResource: "spike-stem-\(suffix)", withExtension: "m4a")
        else { throw AudioError.missingStem(suffix) }
        return try AVAudioFile(forReading: url)
    }

    private func clickFormat() throws -> AVAudioFormat {
        guard let format = AVAudioFormat(standardFormatWithSampleRate: 48_000, channels: 1) else {
            throw AudioError.clickFormat
        }
        return format
    }

    private func scheduleClicks(on node: AVAudioPlayerNode, format: AVAudioFormat) throws {
        guard
            let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 480),
            let samples = buffer.floatChannelData?[0]
        else { throw AudioError.clickBuffer }
        buffer.frameLength = buffer.frameCapacity
        for frame in 0..<Int(buffer.frameLength) {
            let envelope = 1 - Float(frame) / Float(buffer.frameLength)
            samples[frame] = 0.25 * envelope * sin(Float(frame) * 2 * .pi * 1_000 / 48_000)
        }
        for click in 0..<36 {
            let time = AVAudioTime(sampleTime: AVAudioFramePosition(click * 28_800), atRate: 48_000)
            node.scheduleBuffer(buffer, at: time, options: [])
        }
    }

    private func reportTapSummary() {
        guard let median = SpikeStatistics.median(offsets),
            let spread = SpikeStatistics.robustSpread(offsets)
        else {
            report.record("S1 TAP RESULT matched=0; no median or spread")
            return
        }
        report.record(
            "S1 TAP RESULT matched=\(offsets.count)/32 medianMs=\(String(format: "%.3f", median)) "
                + "robustSpreadMs=\(String(format: "%.3f", spread))"
        )
    }

    private enum AudioError: LocalizedError {
        case missingStem(String)
        case clickFormat
        case clickBuffer

        var errorDescription: String? {
            switch self {
            case .missingStem(let stem): "Spike audio stem \(stem) is missing from the bundle."
            case .clickFormat: "Could not create the click audio format."
            case .clickBuffer: "Could not create the click audio buffer."
            }
        }
    }
}
