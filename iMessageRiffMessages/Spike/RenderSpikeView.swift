import SwiftUI

struct RenderSpikeView: View {
    let audio: AudioSpike
    let report: SpikeReport
    @State private var model: RenderSpikeModel

    init(audio: AudioSpike, report: SpikeReport) {
        self.audio = audio
        self.report = report
        _model = State(initialValue: RenderSpikeModel(report: report))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("S3 / S4 / S6").font(.title2.bold())
                Text("200 pooled sprites. The shaded region is the touch zone.")
                HighwaySceneView(model: model) { touch, phase, point, size in
                    model.touch(touch, phase: phase, point: point, size: size, mode: "scene")
                }
                .frame(height: 400)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                Toggle("Strike line inside the touch zone", isOn: $model.lineInsideZone)
                Toggle("Request a haptic on each tap", isOn: $model.hapticsEnabled)
                Button("Measure 60 seconds") { model.startFrameSample() }
                Text(model.frameStatus).accessibilityIdentifier("spike-frame-status")
                Text("Frame intervals estimate drops; actual visual smoothness and haptics need device observations.")
                    .font(.footnote)
                Button("Stream both 90-second stems") { audio.start(.stems) }
                Button("Stop audio") { audio.stop() }
                Button("Record memory footprint") { SpikeMemory.record("manual", report: report) }
                Text("Held for the optional memory-pressure test: \(model.allocatedMiB) MiB")
                Button("Allocate another 10 MiB") { model.allocateMemory() }
                Button("Release test allocations") { model.releaseMemory() }
                Text("Allocating repeatedly can cause the system to terminate the extension.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Form {
                    SpikeReportControls(report: report)
                }
                .frame(height: 360)
            }
            .padding()
        }
        .navigationTitle("Rendering & memory")
    }
}
