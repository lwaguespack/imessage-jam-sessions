import Messages
import SwiftUI

struct SpikeMenuView: View {
    let report: SpikeReport
    let audio: AudioSpike
    let messages: MessagesSpike
    let requestStyle: @MainActor (MSMessagesAppPresentationStyle) -> Void

    var body: some View {
        Form {
            Section("Real-device diagnostics") {
                Text(
                    "This is a temporary test build, not the game. Results require real devices; "
                        + "the simulator cannot confirm Messages, audio or touch behavior."
                )
                Button("Expand Messages") { requestStyle(.expanded) }
                Button("Collapse Messages") { requestStyle(.compact) }
                NavigationLink("S1 Audio and clock") {
                    AudioSpikeView(audio: audio, report: report)
                }
                NavigationLink("S2 Messages behavior") {
                    MessagesSpikeView(messages: messages, report: report)
                }
                NavigationLink("S3 / S4 / S6 Rendering, haptics and memory") {
                    RenderSpikeView(audio: audio, report: report)
                }
                NavigationLink("S5 Touch and sheet gestures") {
                    TouchSpikeView(report: report) { requestStyle(.expanded) }
                }
            }
            SpikeReportControls(report: report)
        }
        .navigationTitle("Device spike")
    }
}
