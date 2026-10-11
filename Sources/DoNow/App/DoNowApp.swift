import SwiftUI

@main
struct DoNowApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            SettingsRootView(appModel: appDelegate.appModel)
                .frame(minWidth: 780, minHeight: 580)
        }
    }
}
