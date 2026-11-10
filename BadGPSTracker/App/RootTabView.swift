import SwiftUI

struct RootTabView: View {
    var body: some View {
        TabView {
            StartView()
                .tabItem { Label("Start", systemImage: "play.circle") }
            LiveMapView()
                .tabItem { Label("Live", systemImage: "map") }
            PostRunView()
                .tabItem { Label("Post-run", systemImage: "flag.checkered") }
        }
    }
}
