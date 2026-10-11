import Foundation

enum TimerPhase: String, Codable, Sendable {
    case running
    case paused
    case completed
    case abandoned
}

enum CalendarSyncState: String, Codable, Sendable {
    case notRequested
    case pending
    case synced
    case failed
}

struct ActiveTimerSnapshot: Equatable, Sendable {
    let sessionID: UUID
    let taskName: String
    let expectedEndAt: Date
    let pausedAt: Date?
    let remainingWhenPaused: TimeInterval?

    var isPaused: Bool { pausedAt != nil }

    func remaining(at now: Date) -> TimeInterval {
        if let remainingWhenPaused {
            return max(0, remainingWhenPaused)
        }
        return max(0, expectedEndAt.timeIntervalSince(now))
    }
}

enum TimerTransition: Equatable, Sendable {
    case none
    case complete
}

enum TimerRules {
    static func transition(for snapshot: ActiveTimerSnapshot, at now: Date) -> TimerTransition {
        guard !snapshot.isPaused else { return .none }
        return now >= snapshot.expectedEndAt ? .complete : .none
    }

    static func resumedEndDate(remaining: TimeInterval, now: Date) -> Date {
        now.addingTimeInterval(max(0, remaining))
    }
}
