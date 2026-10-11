import AppKit
import Foundation

@MainActor
final class AppModel: ObservableObject {
    let store: DoNowStore
    let timer: TimerCoordinator
    let loginItem = LoginItemService()

    @Published private(set) var tasks: [TaskTemplate] = []
    @Published private(set) var recentSessions: [FocusSession] = []
    @Published var errorMessage: String?
    var settingsPresentationHandler: (() -> Void)?

    init(inMemory: Bool = false) {
        do {
            let store = try DoNowStore(inMemory: inMemory)
            self.store = store
            self.timer = TimerCoordinator(
                store: store,
                notifications: NotificationService(),
                calendar: CalendarService()
            )
            try store.seedIfNeeded()
            reload()
            timer.restore()
        } catch {
            fatalError("Unable to initialize DoNow storage: \(error)")
        }
    }

    func reload() {
        do {
            tasks = try store.tasks()
            recentSessions = try store.recentSessions()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func addTask(name: String, minutes: Int) {
        guard validate(name: name, minutes: minutes) else { return }
        do {
            try store.addTask(name: name, durationMinutes: minutes)
            reload()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func updateTask(_ task: TaskTemplate, name: String, minutes: Int) {
        guard validate(name: name, minutes: minutes) else { return }
        do {
            try store.updateTask(task, name: name, durationMinutes: minutes)
            reload()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func archiveTask(_ task: TaskTemplate) {
        do {
            try store.archiveTask(task)
            reload()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func start(_ task: TaskTemplate) {
        timer.start(task: task)
        reload()
    }

    func showSettings() {
        settingsPresentationHandler?()
    }

    private func validate(name: String, minutes: Int) -> Bool {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty, cleanName.count <= 80 else {
            errorMessage = "事项名称需要包含 1–80 个字符。"
            return false
        }
        guard (1...(24 * 60)).contains(minutes) else {
            errorMessage = "预计时长需要在 1 分钟到 24 小时之间。"
            return false
        }
        return true
    }
}
