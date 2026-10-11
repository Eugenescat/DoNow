import XCTest
@testable import DoNow

final class TimerRulesTests: XCTestCase {
    func testRunningTimerCompletesAtExpectedEnd() {
        let end = Date(timeIntervalSince1970: 1_000)
        let snapshot = ActiveTimerSnapshot(
            sessionID: UUID(),
            taskName: "阅读",
            expectedEndAt: end,
            pausedAt: nil,
            remainingWhenPaused: nil
        )

        XCTAssertEqual(TimerRules.transition(for: snapshot, at: end), .complete)
    }

    func testPausedTimerNeverAutoCompletes() {
        let end = Date(timeIntervalSince1970: 1_000)
        let snapshot = ActiveTimerSnapshot(
            sessionID: UUID(),
            taskName: "阅读",
            expectedEndAt: end,
            pausedAt: end.addingTimeInterval(-20),
            remainingWhenPaused: 20
        )

        XCTAssertEqual(TimerRules.transition(for: snapshot, at: end.addingTimeInterval(500)), .none)
        XCTAssertEqual(snapshot.remaining(at: end.addingTimeInterval(500)), 20)
    }

    func testResumeUsesRemainingDurationInsteadOfOldEndDate() {
        let now = Date(timeIntervalSince1970: 2_000)
        XCTAssertEqual(
            TimerRules.resumedEndDate(remaining: 90, now: now),
            Date(timeIntervalSince1970: 2_090)
        )
    }
}
