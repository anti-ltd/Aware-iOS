import SwiftUI
import MessageUI

/// SwiftUI wrapper around `MFMessageComposeViewController` so SOS / live-share /
/// missed-check-in alerts go out as a normal SMS the user sends — no server, no
/// account, exactly the local-first stance Aware promises.
///
/// Present it from a `.sheet`. Check `MessageComposer.canSend` before presenting;
/// the simulator and devices without iMessage/SMS can't compose.
struct MessageComposer: UIViewControllerRepresentable {
    let recipients: [String]
    let body: String
    var onFinish: (MessageComposeResult) -> Void = { _ in }

    static var canSend: Bool { MFMessageComposeViewController.canSendText() }

    func makeUIViewController(context: Context) -> MFMessageComposeViewController {
        let vc = MFMessageComposeViewController()
        vc.messageComposeDelegate = context.coordinator
        vc.recipients = recipients
        vc.body = body
        return vc
    }

    func updateUIViewController(_ vc: MFMessageComposeViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onFinish: onFinish) }

    final class Coordinator: NSObject, MFMessageComposeViewControllerDelegate {
        let onFinish: (MessageComposeResult) -> Void
        init(onFinish: @escaping (MessageComposeResult) -> Void) { self.onFinish = onFinish }

        func messageComposeViewController(_ controller: MFMessageComposeViewController,
                                          didFinishWith result: MessageComposeResult) {
            controller.dismiss(animated: true)
            onFinish(result)
        }
    }
}
