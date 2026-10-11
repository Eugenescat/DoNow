import XCTest
@testable import DoNow

@MainActor
final class TimerCoordinatorTests: XCTestCase {
    func testStartingAfterLongIdleUsesFreshTimeImmediately() throws {
        let staleDate = Date(timeIntervalSince1970: 1_000)
        let startDate = staleDate.addingTimeInterval(28 * 60 * 60)
        var requestedDates = [staleDate, startDate]

        let store = try DoNowStore(inMemory: true)
        let task = try store.addTask(name: "阅读", durationMinutes: 25)
        let timer = TimerCoordinator(
            store: store,
            notifications: NotificationStub(),
            calendar: CalendarStub(),
            currentDate: { requestedDates.removeFirst() }
        )

        timer.start(task: task)

        XCTAssertEqual(timer.now, startDate)
        XCTAssertEqual(timer.activeSession?.startedAt, startDate)
        XCTAssertEqual(timer.remainingSeconds, 25 * 60)
    }
}

@MainActor
private final class NotificationStub: NotificationServing {
    func requestAuthorization() async -> Bool { false }
    func scheduleCompletion(_ payload: CompletionNotificationPayload) async throws {}
    func cancelCompletion(sessionID: UUID) {}
}

@MainActor
private final class CalendarStub: CalendarServing {
    func requestWriteAccess() async -> Bool { false }
    func createEvent(_ event: CalendarEventPayload) async throws -> String { "" }
}
