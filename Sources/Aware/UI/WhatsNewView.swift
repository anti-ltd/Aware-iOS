/**
 Aware's What's New sheet — wires `iUXiOS.WhatsNewFlow` to the baked changelog
 for the running `(B{n})` build.
 */
import SwiftUI
import iUXiOS

struct WhatsNewView: View {
    /// When set, shown as a replay from Settings — `onFinish` only dismisses.
    var onClose: (() -> Void)? = nil

    var body: some View {
        WhatsNewFlow(content: ReleaseNotes.content, onFinish: { onClose?() })
    }
}

/// Builds What's New content from the current build's changelog section.
enum ReleaseNotes {
    nonisolated(unsafe) private static let cached: WhatsNewContent? = buildContent()
    static var content: WhatsNewContent? { cached }
    static var hasContent: Bool { cached != nil }

    static func shouldPresent(lastSeenBuild: String) -> Bool {
        let current = AppBuild.number
        guard !current.isEmpty, !lastSeenBuild.isEmpty, lastSeenBuild != current else { return false }
        return content != nil
    }

    private static func buildContent() -> WhatsNewContent? {
        guard let version = ChangelogParser.version(forCurrentBuild: ()) else { return nil }
        let buildLabel = version.build ?? "Build \(AppBuild.number)"
        let intro = version.intro ?? "Here's what changed in this update."
        let sections = version.sectionHeadlines.compactMap { section, headlines -> WhatsNewSection? in
            let cap = headlineCap(for: section)
            let shown = Array(headlines.prefix(cap))
            let overflow = max(0, headlines.count - shown.count)
            guard !shown.isEmpty else { return nil }
            let style = style(for: section)
            return WhatsNewSection(
                id: section,
                title: friendlySectionTitle(section),
                symbol: style.symbol,
                tint: style.tint,
                headlines: shown,
                overflowCount: overflow)
        }
        guard !sections.isEmpty else { return nil }
        return WhatsNewContent(buildLabel: buildLabel, intro: intro, sections: sections)
    }

    private static func headlineCap(for section: String) -> Int {
        switch section.lowercased() {
        case "added":   return 6
        case "changed": return 5
        case "fixed":   return 5
        default:        return 5
        }
    }

    private static func style(for section: String) -> (symbol: String, tint: Color) {
        switch section.lowercased() {
        case "added":   return ("sparkles", .green)
        case "changed": return ("arrow.triangle.2.circlepath", .blue)
        case "fixed":   return ("wrench.and.screwdriver.fill", .orange)
        default:        return ("star.fill", .accentColor)
        }
    }

    private static func friendlySectionTitle(_ section: String) -> String {
        switch section.lowercased() {
        case "added":   return "New"
        case "changed": return "Updates"
        case "fixed":   return "Fixes"
        default:        return section
        }
    }
}
