/**
 Parses the build-time-baked CHANGELOG.md for Settings → Changelog.
 */
import Foundation

enum ChangelogBlock {
    case section(String)
    case bullet(String)
    case paragraph(String)
}

struct ChangelogVersion: Identifiable {
    let id: Int
    let number: String
    let build: String?
    let date: String?
    var isLatest: Bool { id == 0 }
    let blocks: [ChangelogBlock]

    var intro: String? {
        var lines: [String] = []
        for block in blocks {
            if case .section = block { break }
            if case .paragraph(let text) = block { lines.append(text) }
        }
        let joined = lines.joined(separator: " ").trimmingCharacters(in: .whitespaces)
        return joined.isEmpty ? nil : joined
    }

    var sectionHeadlines: [(section: String, headlines: [String])] {
        var raw: [(String, [String])] = []
        var current = ""
        var headlines: [String] = []
        func flush() {
            guard !current.isEmpty, !headlines.isEmpty else { return }
            raw.append((current, headlines))
        }
        for block in blocks {
            switch block {
            case .section(let name):
                flush()
                current = name
                headlines = []
            case .bullet(let raw):
                headlines.append(Self.headline(from: raw))
            case .paragraph:
                break
            }
        }
        flush()

        var merged: [(String, [String])] = []
        for (name, bullets) in raw {
            if let idx = merged.firstIndex(where: { $0.0.caseInsensitiveCompare(name) == .orderedSame }) {
                merged[idx].1.append(contentsOf: bullets)
            } else {
                merged.append((name, bullets))
            }
        }

        let order = ["added", "changed", "deprecated", "removed", "fixed", "security"]
        merged.sort { lhs, rhs in
            let li = order.firstIndex(of: lhs.0.lowercased()) ?? order.count
            let ri = order.firstIndex(of: rhs.0.lowercased()) ?? order.count
            if li != ri { return li < ri }
            return false
        }
        return merged
    }

    static func headline(from raw: String) -> String {
        if let open = raw.range(of: "**"),
           let close = raw[open.upperBound...].range(of: "**") {
            return String(raw[open.upperBound..<close.lowerBound])
        }
        if let dot = raw.firstIndex(of: ".") {
            return String(raw[...dot])
        }
        return raw
    }
}

enum ChangelogParser {
    static let versions: [ChangelogVersion] = parse()

    static func version(forBuild tag: String) -> ChangelogVersion? {
        versions.first { $0.build?.caseInsensitiveCompare(tag) == .orderedSame }
    }

    static func version(forCurrentBuild: Void = ()) -> ChangelogVersion? {
        version(forBuild: AppBuild.changelogTag)
    }

    private static func parse() -> [ChangelogVersion] {
        var out: [ChangelogVersion] = []
        var title: String?
        var bodyLines: [String] = []
        func flush() {
            guard let title else { return }
            let (number, build, date) = splitTitle(title)
            let parsed = blocks(from: bodyLines)
            if number.caseInsensitiveCompare("Unreleased") == .orderedSame, parsed.isEmpty {
                bodyLines = []
                return
            }
            out.append(.init(id: out.count, number: number, build: build, date: date,
                             blocks: parsed))
            bodyLines = []
        }
        for raw in ChangelogData.markdown.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = String(raw)
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("## ") {
                flush()
                title = String(trimmed.dropFirst(3))
                    .replacingOccurrences(of: "[", with: "")
                    .replacingOccurrences(of: "]", with: "")
            } else if title != nil {
                bodyLines.append(line)
            }
        }
        flush()
        return out
    }

    private static func splitTitle(_ title: String) -> (String, String?, String?) {
        var rest = title.trimmingCharacters(in: .whitespaces)
        var build: String? = nil
        if let match = rest.range(of: #"\(B\d+\)"#, options: .regularExpression) {
            build = String(rest[match]).trimmingCharacters(in: CharacterSet(charactersIn: "()"))
            rest.removeSubrange(match)
            rest = rest.trimmingCharacters(in: .whitespaces)
        }
        for sep in [" — ", " - "] {
            let parts = rest.components(separatedBy: sep)
            if parts.count > 1 {
                return (parts[0].trimmingCharacters(in: .whitespaces), build,
                        parts[1].trimmingCharacters(in: .whitespaces))
            }
        }
        return (rest, build, nil)
    }

    private static func blocks(from bodyLines: [String]) -> [ChangelogBlock] {
        var out: [ChangelogBlock] = []
        var buf: String? = nil
        var bufIsBullet = false
        func flush() {
            guard let text = buf else { return }
            out.append(bufIsBullet ? .bullet(text) : .paragraph(text))
            buf = nil
        }
        for line in bodyLines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { flush(); continue }
            if trimmed.hasPrefix("### ") {
                flush()
                out.append(.section(String(trimmed.dropFirst(4))))
                continue
            }
            if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") {
                flush()
                buf = String(trimmed.dropFirst(2))
                bufIsBullet = true
                continue
            }
            if buf != nil { buf! += " " + trimmed }
            else { buf = trimmed; bufIsBullet = false }
        }
        flush()
        return out
    }
}
