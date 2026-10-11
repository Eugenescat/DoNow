import AppKit
import UserNotifications

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    let appModel = AppModel()
    private var panelCoordinator: FloatingPanelCoordinator?
    private lazy var settingsWindowCoordinator = SettingsWindowCoordinator(appModel: appModel)

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        if Bundle.main.bundleURL.pathExtension.lowercased() == "app" {
            UNUserNotificationCenter.current().delegate = self
        }

        panelCoordinator = FloatingPanelCoordinator(appModel: appModel)
        panelCoordinator?.show()
        appModel.settingsPresentationHandler = { [weak self] in
            self?.settingsWindowCoordinator.show()
        }

        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(workspaceDidWake),
            name: NSWorkspace.didWakeNotification,
            object: nil
        )
    }

    func applicationWillTerminate(_ notification: Notification) {
        appModel.settingsPresentationHandler = nil
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    @objc private func workspaceDidWake() {
        appModel.timer.reconcile()
        appModel.reload()
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}
