import Messages
import SwiftUI
import UIKit

/// The class Messages instantiates, named by `NSExtensionPrincipalClass` in Info.plist.
final class MessagesViewController: MSMessagesAppViewController {
    private let model = AppModel()

    override func viewDidLoad() {
        super.viewDidLoad()
        let root = RootView(model: model) { [weak self] style in
            self?.requestPresentationStyle(style)
        }
        let host = UIHostingController(rootView: root)
        addChild(host)
        host.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(host.view)
        NSLayoutConstraint.activate([
            host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            host.view.topAnchor.constraint(equalTo: view.topAnchor),
            host.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        host.didMove(toParent: self)
    }

    override func willBecomeActive(with conversation: MSConversation) {
        super.willBecomeActive(with: conversation)
        model.update(style: presentationStyle, conversation: conversation)
    }

    override func didTransition(to presentationStyle: MSMessagesAppPresentationStyle) {
        super.didTransition(to: presentationStyle)
        model.update(style: presentationStyle, conversation: activeConversation)
    }
}
