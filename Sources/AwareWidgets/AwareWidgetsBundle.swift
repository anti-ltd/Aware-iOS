import WidgetKit
import SwiftUI

/// The widget extension's entry point. Only the safety Live Activity for now;
/// home-screen widgets (quick-SOS, nearest service) can join the bundle later.
@main
struct AwareWidgetsBundle: WidgetBundle {
    var body: some Widget {
        SafetyLiveActivity()
    }
}
