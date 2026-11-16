import SwiftUI

@main
struct CoasterApp: App {
    @StateObject private var appState = AppState()
    @UIApplicationDelegateAdaptor(NativeAppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
                .environment(\.layoutDirection, .rightToLeft)
        }
    }
}
