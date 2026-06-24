/**
 The running app's marketing version and build number from the bundle.
 Used to match changelog sections for future What's New flows.
 */
import Foundation

enum AppBuild {
    static var number: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0"
    }

    static var marketing: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    /// Changelog header tag, e.g. `B3`.
    static var changelogTag: String { "B\(number)" }
}
