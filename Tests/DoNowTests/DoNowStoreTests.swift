import XCTest
@testable import DoNow

@MainActor
final class DoNowStoreTests: XCTestCase {
    func testSeedCreatesDefaultTasksOnlyOnce() throws {
        let store = try DoNowStore(inMemory: true)

        try store.seedIfNeeded()
        try store.seedIfNeeded()

        XCTAssertEqual(try store.tasks().count, 3)
    }

    func testStartingNewSessionAbandonsPreviousSession() throws {
        let store = try DoNowStore(inMemory: true)
        let firstTask = try store.addTask(name: "阅读", durationMinutes: 25)
        let secondTask = try store.addTask(name: "运动", durationMinutes: 30)
        let now = Date(timeIntervalSince1970: 10_000)

        let firstSession = try store.startSession(for: firstTask, now: now)
        let secondSession = try store.startSession(for: secondTask, now: now.addingTimeInterval(10))

        XCTAssertEqual(firstSession.phase, .abandoned)
        XCTAssertEqual(firstSession.finishedAt, now.addingTimeInterval(10))
        XCTAssertEqual(try store.activeSession()?.id, secondSession.id)
    }

    func testArchivedTaskDisappearsWithoutChangingSessionSnapshot() throws {
        let store = try DoNowStore(inMemory: true)
        let task = try store.addTask(name: "写作", durationMinutes: 45)
        let session = try store.startSession(for: task, now: .now)

        try store.archiveTask(task)

        XCTAssertTrue(try store.tasks().isEmpty)
        XCTAssertEqual(session.taskNameSnapshot, "写作")
        XCTAssertEqual(session.plannedDurationSeconds, 45 * 60)
    }
}
