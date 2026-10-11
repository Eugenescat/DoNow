import Foundation
@preconcurrency import UserNotifications

struct CompletionNotificationPayload: Sendable {
    let sessionID: UUID
    let taskName: String
    let expectedEndAt: Date
}

@MainActor
protocol NotificationServing: AnyObject {
    func requestAuthorization() async -> Bool
    func scheduleCompletion(_ payload: CompletionNotificationPayload) async throws
    func cancelCompletion(sessionID: UUID)
}

@MainActor
final class NotificationService: NotificationServing {
    private let center: UNUserNotificationCenter?

    init() {
        // UserNotifications throws an Objective-C exception when a Swift Package
        // executable is run without an application bundle. The real app target
        // always has a .app bundle; package/test runs safely disable notifications.
        center = Bundle.main.bundleURL.pathExtension.lowercased() == "app"
            ? UNUserNotificationCenter.current()
            : nil
    }

    func requestAuthorization() async -> Bool {
        guard let center else { return false }
        do {
            return try await center.requestAuthorization(options: [.alert, .sound])
        } catch {
            return false
        }
    }

    func scheduleCompletion(_ payload: CompletionNotificationPayload) async throws {
        guard let center else { return }
        let content = UNMutableNotificationContent()
        content.title = "完成了"
        content.body = "“\(payload.taskName)”计时结束。"
        content.sound = .default
        content.userInfo = ["sessionID": payload.sessionID.uuidString]

        let interval = max(1, payload.expectedEndAt.timeIntervalSinceNow)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        let request = UNNotificationRequest(
            identifier: Self.identifier(for: payload.sessionID),
            content: content,
            trigger: trigger
        )
        try await center.add(request)
    }

    func cancelCompletion(sessionID: UUID) {
        center?.removePendingNotificationRequests(withIdentifiers: [Self.identifier(for: sessionID)])
    }

    private static func identifier(for sessionID: UUID) -> String {
        "donow.session.\(sessionID.uuidString)"
    }
}
