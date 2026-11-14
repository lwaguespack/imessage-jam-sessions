import Messages
import Observation

/// What the placeholder screen shows about the extension's current state.
@MainActor
@Observable
final class AppModel {
    private(set) var isExpanded = false
    private(set) var remoteParticipantCount = 0
    private(set) var hasSelectedMessage = false

    func update(style: MSMessagesAppPresentationStyle, conversation: MSConversation?) {
        isExpanded = style == .expanded
        remoteParticipantCount = conversation?.remoteParticipantIdentifiers.count ?? 0
        hasSelectedMessage = conversation?.selectedMessage != nil
    }
}
