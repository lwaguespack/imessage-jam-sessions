import Foundation
import Observation
import QuartzCore
import UIKit

@MainActor
@Observable
final class RenderSpikeModel {
    private(set) var frameStatus = "Start a 60-second frame sample."
    private(set) var touchCounts = [0, 0, 0, 0]
    private(set) var cancelledTouches = 0
    private(set) var deliveryStatus = "No touch samples."
    private(set) var allocatedMiB = 0
    var lineInsideZone = false
    var hapticsEnabled = true

    @ObservationIgnored let report: SpikeReport
    @ObservationIgnored private var maximumFPS: Int?
    @ObservationIgnored private var sampleStart: TimeInterval?
    @ObservationIgnored private var lastFrame: TimeInterval?
    @ObservationIgnored private var frameIntervals: [Double] = []
    @ObservationIgnored private var measuring = false
    @ObservationIgnored private var nextCheckpoint = 10.0
    @ObservationIgnored private var lastGeometry = ""
    @ObservationIgnored private var touches: [ObjectIdentifier: TrackedTouch] = [:]
    @ObservationIgnored private var deliveryDelays: [Double] = []
    @ObservationIgnored private var allocations: [Data] = []
    @ObservationIgnored private let haptic = UIImpactFeedbackGenerator(style: .medium)

    init(report: SpikeReport) {
        self.report = report
        haptic.prepare()
    }

    func geometry(size: CGSize, safeArea: UIEdgeInsets, maximumFPS: Int) {
        self.maximumFPS = maximumFPS
        let value =
            "size=\(Int(size.width))x\(Int(size.height)) "
            + "safe=\(safeArea.top),\(safeArea.left),\(safeArea.bottom),\(safeArea.right) "
            + "displayMaximumFPS=\(maximumFPS) requestedFPS=120"
        guard value != lastGeometry else { return }
        lastGeometry = value
        report.record("S3 GEOMETRY \(value)")
    }

    func startFrameSample() {
        guard let maximumFPS, maximumFPS > 0 else {
            frameStatus = "The view is not attached to a display."
            report.record("S3 ERROR \(frameStatus)")
            return
        }
        sampleStart = nil
        lastFrame = nil
        frameIntervals = []
        measuring = true
        nextCheckpoint = 10
        frameStatus = "Sampling for 60 seconds."
        report.record("S3 START targetFPS=\(min(120, maximumFPS))")
    }

    func frame(at time: TimeInterval) {
        guard measuring else { return }
        if sampleStart == nil { sampleStart = time }
        if let lastFrame, time > lastFrame {
            frameIntervals.append(time - lastFrame)
        }
        lastFrame = time
        guard let sampleStart else { return }
        let elapsed = time - sampleStart
        if elapsed >= nextCheckpoint, elapsed < 60, let maximumFPS {
            let fps = min(120, maximumFPS)
            let drops = estimatedDrops(fps: fps)
            report.record(
                "S3 PROGRESS elapsed=\(elapsed) frames=\(frameIntervals.count) estimatedDropped=\(drops)"
            )
            SpikeMemory.record("render sample", report: report)
            nextCheckpoint += 10
        }
        guard elapsed >= 60 else { return }
        measuring = false
        guard
            let maximumFPS,
            let median = SpikeStatistics.median(frameIntervals),
            let p95 = SpikeStatistics.percentile(frameIntervals, fraction: 0.95)
        else {
            frameStatus = "No frame intervals were measured."
            report.record("S3 ERROR \(frameStatus)")
            return
        }
        let fps = min(120, maximumFPS)
        let drops = estimatedDrops(fps: fps)
        let expected = frameIntervals.count + drops
        let percent = expected > 0 ? Double(drops) * 100 / Double(expected) : 0
        frameStatus =
            "Frames \(frameIntervals.count), estimated dropped \(String(format: "%.2f", percent))%."
        report.record(
            "S3 RESULT elapsed=\(elapsed) frames=\(frameIntervals.count) "
                + "intervalMedianMs=\(median * 1_000) intervalP95Ms=\(p95 * 1_000) "
                + "targetFPS=\(fps) estimatedDropped=\(drops) droppedPercent=\(percent)"
        )
    }

    func resetTouches(mode: String) {
        touchCounts = [0, 0, 0, 0]
        cancelledTouches = 0
        deliveryDelays = []
        touches = [:]
        deliveryStatus = "No touch samples."
        report.record("S5 START mode=\(mode)")
    }

    func touch(_ touch: UITouch, phase: String, point: CGPoint, size: CGSize, mode: String) {
        guard size.width > 0, size.height > 0 else {
            report.record("S5 ERROR touch view has no size")
            return
        }
        let id = ObjectIdentifier(touch)
        let lane = min(3, max(0, Int(point.x / size.width * 4)))
        switch phase {
        case "began":
            let delay = (CACurrentMediaTime() - touch.timestamp) * 1_000
            deliveryDelays.append(delay)
            touchCounts[lane] += 1
            touches[id] = TrackedTouch(lane: lane, start: touch.timestamp, y: point.y, maxDrift: 0)
            if hapticsEnabled {
                haptic.impactOccurred()
                haptic.prepare()
            }
            updateDeliveryStatus()
            report.record(
                "S5 \(mode) began lane=\(lane + 1) timestamp=\(touch.timestamp) "
                    + "deliveryMs=\(String(format: "%.3f", delay)) hapticRequested=\(hapticsEnabled)"
            )
        case "moved":
            if var tracked = touches[id] {
                tracked.maxDrift = max(tracked.maxDrift, abs(point.y - tracked.y))
                touches[id] = tracked
            }
        case "ended", "cancelled":
            if phase == "cancelled" { cancelledTouches += 1 }
            guard let tracked = touches.removeValue(forKey: id) else {
                report.record("S5 \(mode) \(phase) without a recorded start")
                return
            }
            let drift = max(tracked.maxDrift, abs(point.y - tracked.y))
            report.record(
                "S5 \(mode) \(phase) lane=\(tracked.lane + 1) "
                    + "durationMs=\((touch.timestamp - tracked.start) * 1_000) maxDriftPoints=\(drift)"
            )
        default:
            report.record("S5 ERROR unknown touch phase \(phase)")
        }
    }

    func reportTouchSummary(mode: String) {
        report.record(
            "S5 RESULT mode=\(mode) laneStarts=\(touchCounts) cancelled=\(cancelledTouches) "
                + "delivery=\(deliveryStatus)"
        )
    }

    func allocateMemory() {
        allocations.append(Data(repeating: 0xA5, count: 10 * 1_024 * 1_024))
        allocatedMiB += 10
        SpikeMemory.record("allocatedMiB=\(allocatedMiB)", report: report)
    }

    func releaseMemory() {
        allocations.removeAll()
        allocatedMiB = 0
        SpikeMemory.record("released allocations", report: report)
    }

    private func updateDeliveryStatus() {
        guard let median = SpikeStatistics.median(deliveryDelays),
            let p95 = SpikeStatistics.percentile(deliveryDelays, fraction: 0.95),
            let maximum = deliveryDelays.max()
        else { return }
        deliveryStatus = String(format: "median %.2f ms, p95 %.2f ms, max %.2f ms", median, p95, maximum)
    }

    private func estimatedDrops(fps: Int) -> Int {
        frameIntervals.reduce(0) { count, interval in
            count + max(0, Int((interval * Double(fps)).rounded()) - 1)
        }
    }

    private struct TrackedTouch {
        let lane: Int
        let start: TimeInterval
        let y: CGFloat
        var maxDrift: CGFloat
    }
}
