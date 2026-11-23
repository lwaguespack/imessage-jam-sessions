import Foundation
import Messages
import Observation

@MainActor
@Observable
final class MessagesSpike {
    private(set) var baseEntries = ""
    private(set) var status = "Start a new session or capture a selected spike bubble."

    @ObservationIgnored private let report: SpikeReport
    @ObservationIgnored private weak var controller: MessagesViewController?
    @ObservationIgnored private var baseSession: MSSession?
    @ObservationIgnored private var lastMessage: MSMessage?

    init(report: SpikeReport, controller: MessagesViewController) {
        self.report = report
        self.controller = controller
    }

    func newSession() {
        baseEntries = ""
        baseSession = nil
        status = "New session; no captured entries."
        report.record("S2 new synthetic session")
    }

    func captureSelected() {
        baseEntries = ""
        baseSession = nil
        guard let conversation = controller?.activeConversation,
            let message = conversation.selectedMessage,
            let url = message.url,
            let session = message.session
        else {
            fail("Select a spike message with a session first.")
            return
        }
        do {
            let payload = try SpikePayload.read(url)
            baseEntries = payload.entries
            baseSession = session
            status = "Captured base entries: \(payload.entries)"
            report.record(
                "S2 CAPTURE entries=\(payload.entries) nonce=\(payload.nonce) "
                    + "length=\(payload.length) form=\(payload.form.rawValue)"
            )
        } catch {
            fail("Selected bubble: \(error.localizedDescription)")
        }
    }

    func send(
        role: String,
        length: Int,
        form: SpikeURLForm,
        useInsert: Bool,
        usePlaceholder: Bool,
        includeSummary: Bool,
        includeAccessibility: Bool
    ) {
        guard let conversation = controller?.activeConversation else {
            fail("There is no active Messages conversation.")
            return
        }
        do {
            let entries = try SpikePayload.adding(role, to: baseEntries)
            let nonce = UUID().uuidString.replacingOccurrences(of: "-", with: "")
            let url = try SpikePayload.makeURL(
                entries: entries, nonce: nonce, length: length, form: form)
            let message = MSMessage(session: baseSession ?? MSSession())
            message.url = url
            let layout = MSMessageTemplateLayout()
            let caption =
                usePlaceholder ? "$\(conversation.localParticipantIdentifier.uuidString)" : "Spike player \(role)"
            layout.caption = caption
            layout.subcaption = "Synthetic entries: \(entries)"
            message.layout = layout
            if includeSummary { message.summaryText = "\(caption) sent synthetic entries \(entries)" }
            if includeAccessibility {
                message.accessibilityLabel = "Device spike message. Synthetic entries \(entries)."
            }
            lastMessage = message
            let operation = useInsert ? "insert" : "send"
            report.record(
                "S2 \(operation) entries=\(entries) nonce=\(nonce) payloadChars=\(length) "
                    + "urlBytes=\(url.absoluteString.utf8.count) "
                    + "urlSHA256=\(SpikePayload.fingerprint(url.absoluteString)) form=\(form.rawValue) "
                    + "capturedBase=\(baseEntries) placeholder=\(usePlaceholder) "
                    + "summary=\(includeSummary) accessibility=\(includeAccessibility) "
                    + "pendingBefore=\(message.isPending)"
            )
            status = "\(operation) requested; check the report for the result."
            let completion: @Sendable (Error?) -> Void = { [weak self] error in
                let description = error?.localizedDescription
                Task { @MainActor in
                    guard let self else { return }
                    if let description {
                        self.fail("\(operation) failed: \(description)")
                    } else {
                        self.status = "\(operation) accepted by Messages."
                        self.report.record("S2 \(operation) completion accepted (not delivery confirmation)")
                    }
                }
            }
            if useInsert {
                conversation.insert(message, completionHandler: completion)
            } else {
                conversation.send(message, completionHandler: completion)
            }
        } catch {
            fail(error.localizedDescription)
        }
    }

    func snapshot(_ event: String, conversation: MSConversation, message: MSMessage? = nil) {
        let remote = conversation.remoteParticipantIdentifiers.map(\.uuidString).sorted()
        let selected = conversation.selectedMessage
        report.record(
            "S2 \(event) local=\(conversation.localParticipantIdentifier.uuidString) "
                + "remoteCount=\(remote.count) rosterCount=\(remote.count + 1) "
                + "remote=\(remote.joined(separator: ",")) "
                + "selected=\(selected == nil ? "none" : "present")"
        )
        if let message { describe(message, label: event) }
        if let selected, selected !== message { describe(selected, label: "\(event).selected") }
    }

    func inspectCurrentConversation() {
        guard let conversation = controller?.activeConversation else {
            fail("There is no active Messages conversation.")
            return
        }
        snapshot("manual snapshot", conversation: conversation)
    }

    func inspectLastMessage() {
        guard let lastMessage else {
            fail("There is no locally created test message to inspect.")
            return
        }
        describe(lastMessage, label: "manual last message")
    }

    func showStore(appID: String) {
        guard let controller else {
            fail("The Messages view controller is unavailable.")
            return
        }
        controller.showSpikeStore(appID: appID)
    }

    private func describe(_ message: MSMessage, label: String) {
        let sender = message.isPending ? "pending" : message.senderParticipantIdentifier.uuidString
        guard let url = message.url else {
            report.record("S2 \(label) sender=\(sender) pending=\(message.isPending) url=none")
            return
        }
        do {
            let payload = try SpikePayload.read(url)
            report.record(
                "S2 \(label) sender=\(sender) pending=\(message.isPending) "
                    + "form=\(payload.form.rawValue) payloadChars=\(payload.length) "
                    + "entries=\(payload.entries) nonce=\(payload.nonce) payloadVerified=true "
                    + "urlBytes=\(url.absoluteString.utf8.count) "
                    + "urlSHA256=\(SpikePayload.fingerprint(url.absoluteString))"
            )
        } catch {
            report.record(
                "S2 \(label) sender=\(sender) pending=\(message.isPending) "
                    + "scheme=\(url.scheme ?? "none") urlBytes=\(url.absoluteString.utf8.count) "
                    + "urlSHA256=\(SpikePayload.fingerprint(url.absoluteString)) "
                    + "ERROR \(error.localizedDescription)"
            )
        }
    }

    private func fail(_ message: String) {
        status = message
        report.record("S2 ERROR \(message)")
    }
}
