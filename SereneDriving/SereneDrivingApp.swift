import SwiftUI

@main
struct SereneDrivingApp: App {
    init() {
        UIApplication.shared.isIdleTimerDisabled = true
        OneSignalPush.start()
    }

    var body: some Scene {
        WindowGroup {
            GameView()
                .preferredColorScheme(.dark)
        }
    }
}
