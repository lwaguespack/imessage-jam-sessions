import SwiftUI
import UIKit

struct AudioSpikeView: View {
    let audio: AudioSpike
    let report: SpikeReport

    var body: some View {
        Form {
            Section("S1 Audio session and clock") {
                Text(audio.status)
                Text("Audio starts only when you tap a button. Use speaker, wired and AirPods.")
                    .font(.footnote)
                Button("Inspect encoded stems") { audio.inspectStems() }
                Button("Play two stems for 90 seconds") { audio.start(.stems) }
                Button("Run 3-minute clock test") { audio.start(.clock) }
                Button("Stop and release audio") { audio.stop() }
            }
            Section("Tap-along") {
                Text("Tap with the clicks: 4 warm-ups, then 32 scored taps. Repeat three times per route.")
                Text("Scored taps: \(audio.tapCount)/32")
                Button("Start 100 BPM tap-along") { audio.start(.taps) }
                ZStack {
                    TapCapture { audio.tap(timestamp: $0) }
                    Text("TAP HERE").font(.title2.bold()).allowsHitTesting(false)
                }
                .frame(height: 110)
                .background(.blue.opacity(0.15), in: RoundedRectangle(cornerRadius: 12))
            }
            Section("Observe manually") {
                Text(
                    "Try compact and expanded, silent mode, lock, other apps, calls, Siri and alarms. "
                        + "Record what you hear and whether other music resumes."
                )
            }
            SpikeReportControls(report: report)
        }
        .navigationTitle("S1 Audio")
    }
}

private struct TapCapture: UIViewRepresentable {
    let onTap: @MainActor (TimeInterval) -> Void

    func makeUIView(context: Context) -> TapCaptureView {
        let view = TapCaptureView()
        view.onTap = onTap
        view.isMultipleTouchEnabled = true
        return view
    }

    func updateUIView(_ view: TapCaptureView, context: Context) {
        view.onTap = onTap
    }
}

private final class TapCaptureView: UIView {
    var onTap: (@MainActor (TimeInterval) -> Void)?

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches { onTap?(touch.timestamp) }
    }
}
