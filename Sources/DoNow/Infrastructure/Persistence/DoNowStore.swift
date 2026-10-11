import Foundation
import SwiftData

@MainActor
final class DoNowStore {
    let container: ModelContainer
    private var context: ModelContext { container.mainContext }

    init(inMemory: Bool = false) throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: inMemory)
        container = try ModelContainer(
            for: TaskTemplate.self,
            FocusSession.self,
            configurations: configuration
        )
    }

    func seedIfNeeded() throws {
        var descriptor = FetchDescriptor<TaskTemplate>()
        descriptor.fetchLimit = 1
        guard try context.fetch(descriptor).isEmpty else { return }

        context.insert(TaskTemplate(name: "阅读", estimatedDurationSeconds: 25 * 60, sortOrder: 0))
        context.insert(TaskTemplate(name: "运动", estimatedDurationSeconds: 30 * 60, sortOrder: 1))
        context.insert(TaskTemplate(name: "整理桌面", estimatedDurationSeconds: 10 * 60, sortOrder: 2))
        try context.save()
    }

    func tasks() throws -> [TaskTemplate] {
        let descriptor = FetchDescriptor<TaskTemplate>(
            predicate: #Predicate { !$0.isArchived },
            sortBy: [SortDescriptor(\TaskTemplate.sortOrder), SortDescriptor(\TaskTemplate.createdAt)]
        )
        return try context.fetch(descriptor)
    }

    @discardableResult
    func addTask(name: String, durationMinutes: Int) throws -> TaskTemplate {
        let nextOrder = (try tasks().map(\.sortOrder).max() ?? -1) + 1
        let task = TaskTemplate(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            estimatedDurationSeconds: durationMinutes * 60,
            sortOrder: nextOrder
        )
        context.insert(task)
        try context.save()
        return task
    }

    func updateTask(_ task: TaskTemplate, name: String, durationMinutes: Int) throws {
        task.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        task.estimatedDurationSeconds = durationMinutes * 60
        task.updatedAt = .now
        try context.save()
    }

    func archiveTask(_ task: TaskTemplate) throws {
        task.isArchived = true
        task.updatedAt = .now
        try context.save()
    }

    func startSession(for task: TaskTemplate, now: Date) throws -> FocusSession {
        if let active = try activeSession() {
            active.phase = .abandoned
            active.finishedAt = now
        }

        let session = FocusSession(
            taskID: task.id,
            taskNameSnapshot: task.name,
            plannedDurationSeconds: task.estimatedDurationSeconds,
            startedAt: now,
            expectedEndAt: now.addingTimeInterval(TimeInterval(task.estimatedDurationSeconds))
        )
        context.insert(session)
        try context.save()
        return session
    }

    func activeSession() throws -> FocusSession? {
        let running = TimerPhase.running.rawValue
        let paused = TimerPhase.paused.rawValue
        var descriptor = FetchDescriptor<FocusSession>(
            predicate: #Predicate { $0.phaseRawValue == running || $0.phaseRawValue == paused },
            sortBy: [SortDescriptor(\FocusSession.startedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    func recentSessions(limit: Int = 100) throws -> [FocusSession] {
        var descriptor = FetchDescriptor<FocusSession>(
            sortBy: [SortDescriptor(\FocusSession.startedAt, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        return try context.fetch(descriptor)
    }

    func session(id: UUID) throws -> FocusSession? {
        var descriptor = FetchDescriptor<FocusSession>(
            predicate: #Predicate { $0.id == id }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    func save() throws {
        try context.save()
    }
}
