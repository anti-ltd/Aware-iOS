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
    /// Called when the sheet finishes (sent, cancelled, or failed). `@MainActor`
    /// because it clears the presenting sheet; being main-actor-typed also makes
    /// the closure `Sendable`, so the nonisolated delegate can hold it safely.
    var onFinish: @MainActor (MessageComposeResult) -> Void = { _ in }

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
        let onFinish: @MainActor (MessageComposeResult) -> Void
        init(onFinish: @escaping @MainActor (MessageComposeResult) -> Void) { self.onFinish = onFinish }

        nonisolated func messageComposeViewController(
            _ controller: MFMessageComposeViewController,
            didFinishWith result: MessageComposeResult
        ) {
            // Read the Sendable callback out before hopping — capturing `self` or the
            // (non-Sendable) `controller` into the main-actor closure would race under
            // Swift 6. No manual dismiss needed: clearing the sheet item collapses the
            // `.sheet(item:)`, which tears down this controller. MessageUI always calls
            // this on the main thread, so the isolation assumption holds.
            let finish = onFinish
            MainActor.assumeIsolated { finish(result) }
        }
    }
}
