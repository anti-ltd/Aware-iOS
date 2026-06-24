/**
 Settings → Changelog. Renders `ChangelogData.markdown` as expandable version cards.
 */
import SwiftUI
import iUXiOS

struct ChangelogPage: View {
    var body: some View {
        ScrollView {
            LazyVStack(spacing: UX.cardSpacing) {
                ForEach(ChangelogMarkdown.versions) { version in
                    ChangelogCard(version: version)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(UX.screenPadding)
        }
        .background {
            AmbientBackdrop(tint: .accentColor)
                .ignoresSafeArea()
        }
        .navigationTitle("Changelog")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private enum ChangelogStyledBlock {
    case section(String)
    case bullet(AttributedString)
    case paragraph(AttributedString)
}

private struct ChangelogStyledVersion: Identifiable {
    let id: Int
    let number: String
    let build: String?
    let date: String?
    var isLatest: Bool { id == 0 }
    let blocks: [ChangelogStyledBlock]

    init(_ version: ChangelogVersion) {
        id = version.id
        number = version.number
        build = version.build
        date = version.date
        blocks = version.blocks.map { block in
            switch block {
            case .section(let name): return .section(name)
            case .bullet(let raw): return .bullet(ChangelogMarkdown.inline(raw))
            case .paragraph(let raw): return .paragraph(ChangelogMarkdown.inline(raw))
            }
        }
    }
}

private enum ChangelogMarkdown {
    static let versions: [ChangelogStyledVersion] = ChangelogParser.versions.map(ChangelogStyledVersion.init)

    static func inline(_ s: String) -> AttributedString {
        (try? AttributedString(
            markdown: s,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        )) ?? AttributedString(s)
    }
}

private struct ChangelogCard: View {
    @Environment(\.cardCornerRadius) private var cardCornerRadius
    @Environment(\.cardTint) private var cardTint
    let version: ChangelogStyledVersion
    private var isLatest: Bool { version.isLatest }
    @State private var expanded: Bool

    init(version: ChangelogStyledVersion) {
        self.version = version
        _expanded = State(initialValue: version.isLatest)
    }

    private func sectionColor(_ name: String) -> Color {
        switch name.lowercased() {
        case "added":            return .green
        case "changed":          return .blue
        case "fixed":            return .orange
        case let s where s.hasPrefix("security"): return .purple
        case "removed", "deprecated": return .red
        default:                 return .secondary
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            if expanded {
                Divider().opacity(0.5).padding(.horizontal, 14)
                body(content)
            }
        }
        .settingsCardChrome(cornerRadius: cardCornerRadius, tint: cardTint)
        .overlay {
            if isLatest {
                RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
                    .strokeBorder(.tint.opacity(0.45), lineWidth: 1)
            }
        }
    }

    private var header: some View {
        Button {
            withAnimation(.snappy(duration: 0.28)) { expanded.toggle() }
        } label: {
            HStack(spacing: 8) {
                Text(version.number)
                    .font(.headline)
                    .foregroundStyle(.primary)
                if let build = version.build {
                    Text(build)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(RoundedRectangle(cornerRadius: min(cardCornerRadius, 10), style: .continuous)
                            .fill(.quaternary))
                }
                if let date = version.date {
                    Text(date)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                if isLatest {
                    Text("LATEST")
                        .font(.caption2.weight(.bold))
                        .tracking(0.5)
                        .foregroundStyle(.tint)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(RoundedRectangle(cornerRadius: min(cardCornerRadius, 10), style: .continuous)
                            .fill(.tint.opacity(0.15)))
                }
                Spacer()
                Image(systemName: "chevron.down")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                    .rotationEffect(.degrees(expanded ? 0 : -90))
            }
            .padding(14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder private var content: some View {
        ForEach(Array(version.blocks.enumerated()), id: \.offset) { _, block in
            switch block {
            case .section(let s):
                HStack(spacing: 6) {
                    Circle().fill(sectionColor(s)).frame(width: 6, height: 6)
                    Text(s.uppercased())
                        .font(.caption2.weight(.bold))
                        .tracking(0.8)
                        .foregroundStyle(sectionColor(s))
                }
                .padding(.top, 10)
            case .bullet(let a):
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Circle().fill(.tertiary).frame(width: 4, height: 4)
                        .padding(.top, 6)
                    Text(a)
                        .font(.callout)
                        .foregroundStyle(.primary.opacity(0.85))
                        .fixedSize(horizontal: false, vertical: true)
                }
            case .paragraph(let a):
                Text(a)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func body(_ inner: some View) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            inner
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .transition(.opacity)
    }
}
