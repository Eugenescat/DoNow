import Foundation

@MainActor
final class TimerCoordinator: ObservableObject {
    private enum CalendarSyncOutcome {
        case success(String)
        case failure(String)
    }

    @Published private(set) var activeSession: FocusSession?
    @Published private(set) var now: Date
    @Published private(set) var lastError: String?

    private let store: DoNowStore
    private let notifications: any NotificationServing
    private let calendar: any CalendarServing
    private let currentDate: () -> Date
    private var tickerTask: Task<Void, Never>?

    init(
        store: DoNowStore,
        notifications: any NotificationServing,
        calendar: any CalendarServing,
        currentDate: @escaping () -> Date = { Date() }
    ) {
        self.store = store
        self.notifications = notifications
        self.calendar = calendar
        self.currentDate = currentDate
        self.now = currentDate()
    }

    deinit {
        tickerTask?.cancel()
    }

    var remainingSeconds: Int {
        guard let activeSession else { return 0 }
        return Int(ceil(activeSession.activeSnapshot.remaining(at: now)))
    }

    func restore() {
        do {
            activeSession = try store.activeSession()
            reconcile()
            updateTicker()
        } catch {
            lastError = error.localizedDescription
        }
    }

    func start(task: TaskTemplate) {
        do {
            // Keep the first rendered countdown and the persisted session on
            // exactly the same time reference. While idle the ticker is stopped,
            // so `now` may otherwise be hours old until its first tick.
            let startDate = currentDate()
            now = startDate
            let session = try store.startSession(for: task, now: startDate)
            activeSession = session
            lastError = nil
            updateTicker()
            let notification = completionNotification(for: session)
            Task {
                _ = await notifications.requestAuthorization()
                try? await notifications.scheduleCompletion(notification)
            }
        } catch {
            lastError = error.localizedDescription
        }
    }

    func pause() {
        guard let session = activeSession, session.phase == .running else { return }
        now = .now
        session.remainingWhenPaused = session.activeSnapshot.remaining(at: now)
        session.pausedAt = now
        session.phase = .paused
        notifications.cancelCompletion(sessionID: session.id)
        persistAndRefreshTicker()
    }

    func resume() {
        guard let session = activeSession, session.phase == .paused else { return }
        now = .now
        let remaining = session.remainingWhenPaused ?? 0
        if let pausedAt = session.pausedAt {
            session.totalPausedSeconds += max(0, Int(now.timeIntervalSince(pausedAt)))
        }
        session.expectedEndAt = TimerRules.resumedEndDate(remaining: remaining, now: now)
        session.pausedAt = nil
        session.remainingWhenPaused = nil
        session.phase = .running
        persistAndRefreshTicker()
        let notification = completionNotification(for: session)
        Task { try? await notifications.scheduleCompletion(notification) }
    }

    func abandon() {
        guard let session = activeSession else { return }
        session.phase = .abandoned
        session.finishedAt = .now
        notifications.cancelCompletion(sessionID: session.id)
        do {
            try store.save()
            activeSession = nil
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
        updateTicker()
    }

    func reconcile() {
        now = .now
        guard let session = activeSession else { return }
        if TimerRules.transition(for: session.activeSnapshot, at: now) == .complete {
            complete(session)
        }
    }

    private func complete(_ session: FocusSession) {
        guard session.phase == .running else { return }
        session.phase = .completed
        session.finishedAt = session.expectedEndAt
        session.calendarSyncState = .pending
        notifications.cancelCompletion(sessionID: session.id)

        do {
            try store.save()
            activeSession = nil
            lastError = nil
        } catch {
            lastError = error.localizedDescription
            return
        }
        updateTicker()

        let sessionID = session.id
        let payload = CalendarEventPayload(
            sessionID: sessionID,
            taskName: session.taskNameSnapshot,
            startDate: session.startedAt,
            endDate: session.expectedEndAt
        )
        Task { [weak self] in
            guard let self else { return }
            let result = await syncCalendar(payload)
            applyCalendarResult(result, to: sessionID)
        }
    }

    private func persistAndRefreshTicker() {
        do {
            try store.save()
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
        updateTicker()
    }

    private func completionNotification(for session: FocusSession) -> CompletionNotificationPayload {
        CompletionNotificationPayload(
            sessionID: session.id,
            taskName: session.taskNameSnapshot,
            expectedEndAt: session.expectedEndAt
        )
    }

    private func syncCalendar(_ payload: CalendarEventPayload) async -> CalendarSyncOutcome {
        let granted = await calendar.requestWriteAccess()
        guard granted else {
            return .failure(CalendarServiceError.permissionDenied.localizedDescription)
        }
        do {
            return .success(try await calendar.createEvent(payload))
        } catch {
            return .failure(error.localizedDescription)
        }
    }

    private func applyCalendarResult(_ result: CalendarSyncOutcome, to sessionID: UUID) {
        guard let session = try? store.session(id: sessionID) else { return }
        switch result {
        case let .success(identifier):
            session.calendarEventIdentifier = identifier
            session.calendarSyncState = .synced
            session.calendarSyncError = nil
        case let .failure(message):
            session.calendarSyncState = .failed
            session.calendarSyncError = message
        }
        try? store.save()
    }

    private func updateTicker() {
        tickerTask?.cancel()
        guard activeSession?.phase == .running else { return }
        tickerTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }
                self?.reconcile()
            }
        }
    }
}
