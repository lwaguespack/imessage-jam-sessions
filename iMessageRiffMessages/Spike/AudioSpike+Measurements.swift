import AVFoundation
import Foundation
import QuartzCore

extension AudioSpike {
    struct ClockSample {
        let hostTime: Double
        let sampleTime: AVAudioFramePosition
        let sampleRate: Double
    }

    func sample() {
        guard mode != nil else { return }
        sampleNumber += 1
        let samples = nodes.compactMap { node -> ClockSample? in
            guard
                let render = node.lastRenderTime, render.isHostTimeValid,
                let player = node.playerTime(forNodeTime: render), player.isSampleTimeValid
            else { return nil }
            return ClockSample(
                hostTime: AVAudioTime.seconds(forHostTime: render.hostTime),
                sampleTime: player.sampleTime, sampleRate: player.sampleRate)
        }
        if samples.count == nodes.count {
            if baseline == nil { baseline = samples }
            let details = samples.enumerated().map { index, sample in
                let first = baseline?[index] ?? sample
                let elapsed = sample.hostTime - first.hostTime
                let audio = Double(sample.sampleTime - first.sampleTime) / sample.sampleRate
                let ppm = elapsed > 0 ? (audio / elapsed - 1) * 1_000_000 : 0
                return "node\(index) host=\(sample.hostTime) frames=\(sample.sampleTime) "
                    + "rate=\(sample.sampleRate) skewPpm=\(String(format: "%.2f", ppm))"
            }.joined(separator: " ")
            var alignment = ""
            if samples.count == 2, samples[0].sampleRate == samples[1].sampleRate {
                let difference =
                    Double(samples[0].sampleTime - samples[1].sampleTime)
                    - (samples[0].hostTime - samples[1].hostTime) * samples[0].sampleRate
                alignment = " hostAlignedDifferenceSamples=\(String(format: "%.2f", difference))"
            }
            report.record("S1 CLOCK \(details)\(alignment)")
        } else {
            report.record("S1 CLOCK waiting for rendered samples (\(samples.count)/\(nodes.count))")
        }
        if sampleNumber.isMultiple(of: 10) { SpikeMemory.record("audio sample", report: report) }
        if CACurrentMediaTime() >= endHostTime { stop(reason: "elapsed") }
    }

    func recordRoute() {
        let session = AVAudioSession.sharedInstance()
        let outputs = session.currentRoute.outputs.map { $0.portType.rawValue }.joined(separator: ",")
        let presentation = nodes.first?.outputPresentationLatency
        report.record(
            "S1 ROUTE outputs=\(outputs) sessionOutputLatency=\(session.outputLatency) "
                + "nodePresentationLatency=\(presentation.map(String.init(describing:)) ?? "unavailable") "
                + "ioBufferDuration=\(session.ioBufferDuration)"
        )
    }

    func observeAudioNotifications() {
        let names: [(Notification.Name, String)] = [
            (AVAudioSession.interruptionNotification, "interruption"),
            (AVAudioSession.routeChangeNotification, "routeChange"),
            (AVAudioSession.mediaServicesWereResetNotification, "mediaServicesReset"),
            (.AVAudioEngineConfigurationChange, "engineConfigurationChange"),
        ]
        for (name, label) in names {
            let observer = NotificationCenter.default.addObserver(
                forName: name, object: nil, queue: nil
            ) { [weak self] notification in
                let interruption =
                    (notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? NSNumber)?.uintValue
                let route = (notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? NSNumber)?.uintValue
                Task { @MainActor in
                    guard let self else { return }
                    self.report.record(
                        "S1 NOTIFICATION \(label) interruption=\(interruption.map(String.init) ?? "-") "
                            + "routeReason=\(route.map(String.init) ?? "-") "
                            + "engineRunning=\(self.engine?.isRunning.description ?? "unavailable") "
                            + "playing=\(self.nodes.map(\.isPlaying))"
                    )
                    self.recordRoute()
                }
            }
            observers.append(observer)
        }
    }
}
