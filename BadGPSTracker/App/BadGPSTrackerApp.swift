import SwiftUI

@main
struct BadGPSTrackerApp: App {
    @StateObject private var appModel = AppModel()

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environmentObject(appModel.permissions)
                .environmentObject(appModel.store)
                .environmentObject(appModel.sessionController)
        }
    }
}
