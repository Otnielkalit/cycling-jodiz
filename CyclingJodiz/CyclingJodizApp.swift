import SwiftUI

@main
struct CyclingJodizApp: App {
    init() {
        // Start WatchConnectivity early so the first ride payload isn’t dropped before activation finishes.
        _ = WatchSessionManager.shared
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
