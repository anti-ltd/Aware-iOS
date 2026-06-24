/**
 Settings → Roadmap. Renders baked ROADMAP.md via the shared iUX timeline.
 */
import SwiftUI
import iUXiOS

struct RoadmapPage: View {
    var body: some View {
        RoadmapTimelineView(
            sections: AwareRoadmapStyle.sections,
            style: AwareRoadmapStyle.timeline)
    }
}
