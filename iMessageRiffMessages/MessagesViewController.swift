import Messages
import QuartzCore
import StoreKit
import SwiftUI
import UIKit

/// The class Messages instantiates, named by `NSExtensionPrincipalClass` in Info.plist.
final class MessagesViewController: MSMessagesAppViewController {
    private let model = AppModel()
    private let report = SpikeReport()
    private lazy var audio = AudioSpike(report: report)
    private lazy var messages = MessagesSpike(report: report, controller: self)
    private var hostObservers: [NSObjectProtocol] = []
    private var storeController: SKStoreProductViewController?

    isolated deinit {
        for observer in hostObservers { NotificationCenter.default.removeObserver(observer) }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        observeHostNotifications()
        report.record("HOST viewDidLoad")
        let root = RootView(model: model, report: report, audio: audio, messages: messages) { [weak self] style in
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
        messages.snapshot("willBecomeActive", conversation: conversation)
    }

    override func didBecomeActive(with conversation: MSConversation) {
        super.didBecomeActive(with: conversation)
        model.update(style: presentationStyle, conversation: conversation)
        messages.snapshot("didBecomeActive", conversation: conversation)
    }

    override func willResignActive(with conversation: MSConversation) {
        super.willResignActive(with: conversation)
        messages.snapshot("willResignActive", conversation: conversation)
    }

    override func didResignActive(with conversation: MSConversation) {
        super.didResignActive(with: conversation)
        messages.snapshot("didResignActive", conversation: conversation)
    }

    override func willSelect(_ message: MSMessage, conversation: MSConversation) {
        super.willSelect(message, conversation: conversation)
        messages.snapshot("willSelect", conversation: conversation, message: message)
    }

    override func didSelect(_ message: MSMessage, conversation: MSConversation) {
        super.didSelect(message, conversation: conversation)
        model.update(style: presentationStyle, conversation: conversation)
        messages.snapshot("didSelect", conversation: conversation, message: message)
    }

    override func didReceive(_ message: MSMessage, conversation: MSConversation) {
        super.didReceive(message, conversation: conversation)
        messages.snapshot("didReceive", conversation: conversation, message: message)
    }

    override func didStartSending(_ message: MSMessage, conversation: MSConversation) {
        super.didStartSending(message, conversation: conversation)
        messages.snapshot("didStartSending", conversation: conversation, message: message)
    }

    override func didCancelSending(_ message: MSMessage, conversation: MSConversation) {
        super.didCancelSending(message, conversation: conversation)
        messages.snapshot("didCancelSending", conversation: conversation, message: message)
    }

    override func willTransition(to presentationStyle: MSMessagesAppPresentationStyle) {
        super.willTransition(to: presentationStyle)
        report.record("HOST willTransition style=\(presentationStyle.rawValue)")
    }

    override func didTransition(to presentationStyle: MSMessagesAppPresentationStyle) {
        super.didTransition(to: presentationStyle)
        model.update(style: presentationStyle, conversation: activeConversation)
        report.record("HOST didTransition style=\(presentationStyle.rawValue)")
        if let conversation = activeConversation {
            messages.snapshot("didTransition", conversation: conversation)
        }
    }

    func showSpikeStore(appID: String) {
        guard let id = Int64(appID), id > 0 else {
            report.record("S2 STORE ERROR Enter a published numeric App Store ID.")
            return
        }
        guard storeController == nil else {
            report.record("S2 STORE ERROR A product sheet is already loading or open.")
            return
        }
        let store = SKStoreProductViewController()
        store.delegate = self
        storeController = store
        report.record("S2 STORE loading product \(id)")
        store.loadProduct(withParameters: [SKStoreProductParameterITunesItemIdentifier: id]) {
            [weak self] loaded, error in
            let description = error?.localizedDescription
            Task { @MainActor in
                guard let self else { return }
                guard loaded, let store = self.storeController else {
                    self.report.record("S2 STORE ERROR \(description ?? "Product did not load.")")
                    self.storeController = nil
                    return
                }
                guard self.isViewLoaded, self.view.window != nil, self.presentedViewController == nil else {
                    self.report.record("S2 STORE ERROR Messages is not ready to present the product sheet.")
                    self.storeController = nil
                    return
                }
                self.report.record("S2 STORE product loaded; presenting sheet")
                self.present(store, animated: true) {
                    self.report.record("S2 STORE product sheet presentation completed")
                }
            }
        }
    }

    private func observeHostNotifications() {
        let names: [(Notification.Name, String)] = [
            (.NSExtensionHostWillEnterForeground, "willEnterForeground"),
            (.NSExtensionHostDidEnterBackground, "didEnterBackground"),
            (.NSExtensionHostWillResignActive, "willResignActive"),
            (.NSExtensionHostDidBecomeActive, "didBecomeActive"),
            (UIApplication.didReceiveMemoryWarningNotification, "memoryWarning"),
        ]
        for (name, label) in names {
            let observer = NotificationCenter.default.addObserver(
                forName: name, object: nil, queue: nil
            ) { [weak self] _ in
                let observedAt = CACurrentMediaTime()
                Task { @MainActor in
                    guard let self else { return }
                    self.report.record("HOST notification=\(label) observedHost=\(observedAt)")
                    if label == "memoryWarning" {
                        SpikeMemory.record("memory warning", report: self.report)
                    }
                }
            }
            hostObservers.append(observer)
        }
    }
}

extension MessagesViewController: SKStoreProductViewControllerDelegate {
    func productViewControllerDidFinish(_ viewController: SKStoreProductViewController) {
        report.record("S2 STORE product sheet dismissed")
        viewController.dismiss(animated: true)
        storeController = nil
    }
}
