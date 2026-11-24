import SwiftUI

struct MessagesSpikeView: View {
    let messages: MessagesSpike
    let report: SpikeReport
    @State private var role = "A"
    @State private var length = 300
    @State private var form: SpikeURLForm = .data
    @State private var usePlaceholder = false
    @State private var includeSummary = true
    @State private var includeAccessibility = true
    @State private var appID = ""

    var body: some View {
        Form {
            Section("S2 Messages") {
                Text(messages.status)
                Button("Record conversation and selected bubble") {
                    messages.inspectCurrentConversation()
                }
                Button("Start a new synthetic session") { messages.newSession() }
                Button("Capture selected bubble as base") { messages.captureSelected() }
                Text("Captured entries: \(messages.baseEntries.isEmpty ? "none" : messages.baseEntries)")
            }
            Section("Synthetic message") {
                Picker("Your test role", selection: $role) {
                    ForEach(["A", "B", "C"], id: \.self) { Text($0) }
                }
                Picker("Payload size", selection: $length) {
                    Text("300 characters").tag(300)
                    Text("4,000 characters").tag(4_000)
                }
                Picker("URL form", selection: $form) {
                    ForEach(SpikeURLForm.allCases, id: \.self) { value in
                        Text(value.rawValue).tag(value)
                    }
                }
                Toggle("Use undocumented $UUID caption", isOn: $usePlaceholder)
                Toggle("Set summary text", isOn: $includeSummary)
                Toggle("Set accessibility label", isOn: $includeAccessibility)
                Button("Insert draft") { send(useInsert: true) }
                Button("Send from this button") { send(useInsert: false) }
                Button("Inspect last created message") { messages.inspectLastMessage() }
                Text(
                    "Only synthetic entries are sent. The query and fragment use riff.invalid, "
                        + "which has no web page. The $UUID experiment may reveal contact details "
                        + "in the visible bubble."
                )
                .font(.footnote)
            }
            Section("S2.8 Store sheet") {
                TextField("Published App Store numeric ID", text: $appID)
                    .keyboardType(.numberPad)
                Button("Open product sheet") { messages.showStore(appID: appID) }
            }
            Section("Observe manually") {
                Text(
                    "Compare two conversations, a second device, extension disable/re-enable, "
                        + "reinstall, and a group member without the app. For the race, B and C "
                        + "capture A's bubble before either sends. Record taps, drafts, "
                        + "VoiceOver, SMS/RCS and Mac behavior."
                )
            }
            SpikeReportControls(report: report)
        }
        .navigationTitle("S2 Messages")
    }

    private func send(useInsert: Bool) {
        messages.send(
            role: role, length: length, form: form, useInsert: useInsert,
            usePlaceholder: usePlaceholder, includeSummary: includeSummary,
            includeAccessibility: includeAccessibility)
    }
}
