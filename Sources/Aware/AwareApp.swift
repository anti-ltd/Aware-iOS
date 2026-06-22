import SwiftUI
import iUXiOS

@main
struct AwareApp: App {
    @State private var model = AppModel()
    @State private var settings = AppSettings()
    @State private var planner = RoutePlanner()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .environment(settings)
                .environment(planner)
                .tint(.accentColor)
        }
    }
}
