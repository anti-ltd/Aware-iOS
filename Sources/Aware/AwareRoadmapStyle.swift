/**
 Aware roadmap timeline styling — accent colours and SF Symbols keyed off
 section titles in ROADMAP.md.
 */
import SwiftUI
import iUXiOS

enum AwareRoadmapStyle {
    static let timeline = RoadmapTimelineStyle(
        sectionColor: { section in
            let t = section.title.lowercased()
            if t.contains("the app") || t.contains("app shell") { return .blue }
            if t.contains("map") || t.contains("route") { return .green }
            if t.contains("safety") || t.contains("sos") { return .red }
            if t.contains("crime") || t.contains("data") { return .orange }
            if t.contains("contact") || t.contains("profile") { return .purple }
            if t.contains("live activit") || t.contains("widget") { return .pink }
            if t.contains("summary") { return .mint }
            return .secondary
        },
        sectionSymbol: { section in
            let t = section.title.lowercased()
            if t.contains("the app") || t.contains("app shell") { return "square.grid.2x2.fill" }
            if t.contains("map") || t.contains("route") { return "map.fill" }
            if t.contains("safety") || t.contains("sos") { return "shield.fill" }
            if t.contains("crime") || t.contains("data") { return "flame.fill" }
            if t.contains("contact") || t.contains("profile") { return "person.crop.circle.fill" }
            if t.contains("live activit") || t.contains("widget") { return "rectangle.on.rectangle.angled" }
            if t.contains("summary") { return "flag.checkered" }
            return "circle.fill"
        }
    )

    static let sections = RoadmapParser.sections(from: RoadmapData.markdown)
}
