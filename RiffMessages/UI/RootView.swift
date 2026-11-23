import Messages
import RiffCore
import SwiftUI

/// Placeholder screen for the scaffold: proves the extension opens in Messages and that RiffCore links.
struct RootView: View {
    let model: AppModel
    let report: SpikeReport
    let audio: AudioSpike
    let messages: MessagesSpike
    let requestStyle: @MainActor (MSMessagesAppPresentationStyle) -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text(AppInfo.displayName)
                        .font(.largeTitle.bold())
                    Text("Placeholder build. Nothing is playable yet.")
                        .foregroundStyle(.secondary)
                    LabeledContent("App version", value: AppInfo.version)
                    LabeledContent("Core version", value: RiffCoreInfo.version)
                    LabeledContent("Lanes", value: "\(GameConfig.standard.highway.laneCount)")
                    LabeledContent("View", value: model.isExpanded ? "Expanded" : "Compact")
                    LabeledContent("Other participants", value: "\(model.remoteParticipantCount)")
                    LabeledContent("Bubble selected", value: model.hasSelectedMessage ? "Yes" : "No")
                    Button(model.isExpanded ? "Collapse" : "Expand") {
                        requestStyle(model.isExpanded ? .compact : .expanded)
                    }
                    .buttonStyle(.borderedProminent)
                    NavigationLink("Device spike") {
                        SpikeMenuView(
                            report: report, audio: audio, messages: messages,
                            requestStyle: requestStyle)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}
