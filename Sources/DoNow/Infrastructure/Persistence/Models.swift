import Foundation
import SwiftData

@Model
final class TaskTemplate {
    @Attribute(.unique) var id: UUID
    var name: String
    var estimatedDurationSeconds: Int
    var sortOrder: Int
    var isArchived: Bool
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        estimatedDurationSeconds: Int,
        sortOrder: Int = 0,
        isArchived: Bool = false,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.estimatedDurationSeconds = estimatedDurationSeconds
        self.sortOrder = sortOrder
        self.isArchived = isArchived
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

@Model
final class FocusSession {
    @Attribute(.unique) var id: UUID
    var taskID: UUID?
    var taskNameSnapshot: String
    var plannedDurationSeconds: Int
    var startedAt: Date
    var expectedEndAt: Date
    var pausedAt: Date?
    var remainingWhenPaused: Double?
    var totalPausedSeconds: Int
    var finishedAt: Date?
    var phaseRawValue: String
    var calendarSyncStateRawValue: String
    var calendarEventIdentifier: String?
    var calendarSyncError: String?

    var phase: TimerPhase {
        get { TimerPhase(rawValue: phaseRawValue) ?? .abandoned }
        set { phaseRawValue = newValue.rawValue }
    }

    var calendarSyncState: CalendarSyncState {
        get { CalendarSyncState(rawValue: calendarSyncStateRawValue) ?? .notRequested }
        set { calendarSyncStateRawValue = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        taskID: UUID?,
        taskNameSnapshot: String,
        plannedDurationSeconds: Int,
        startedAt: Date,
        expectedEndAt: Date,
        phase: TimerPhase = .running
    ) {
        self.id = id
        self.taskID = taskID
        self.taskNameSnapshot = taskNameSnapshot
        self.plannedDurationSeconds = plannedDurationSeconds
        self.startedAt = startedAt
        self.expectedEndAt = expectedEndAt
        self.totalPausedSeconds = 0
        self.phaseRawValue = phase.rawValue
        self.calendarSyncStateRawValue = CalendarSyncState.notRequested.rawValue
    }
}

extension FocusSession {
    var activeSnapshot: ActiveTimerSnapshot {
        ActiveTimerSnapshot(
            sessionID: id,
            taskName: taskNameSnapshot,
            expectedEndAt: expectedEndAt,
            pausedAt: pausedAt,
            remainingWhenPaused: remainingWhenPaused
        )
    }
}
