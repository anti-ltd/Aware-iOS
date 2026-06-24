/**
 Thin wrapper over UIKit feedback generators for map and settings interactions.
 */
import UIKit

@MainActor
enum Haptics {
    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    static func select() {
        UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 0.55)
    }
}
