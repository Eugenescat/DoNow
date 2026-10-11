@preconcurrency import EventKit
import Foundation

enum CalendarServiceError: LocalizedError {
    case permissionDenied
    case noWritableCalendar

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            "没有日历写入权限"
        case .noWritableCalendar:
            "没有可写入的日历"
        }
    }
}

@MainActor
protocol CalendarServing: AnyObject {
    func requestWriteAccess() async -> Bool
    func createEvent(_ event: CalendarEventPayload) async throws -> String
}

struct CalendarEventPayload: Sendable {
    let sessionID: UUID
    let taskName: String
    let startDate: Date
    let endDate: Date
}

@MainActor
final class CalendarService: CalendarServing {
    private let store = EKEventStore()

    func requestWriteAccess() async -> Bool {
        do {
            return try await store.requestWriteOnlyAccessToEvents()
        } catch {
            return false
        }
    }

    func createEvent(_ payload: CalendarEventPayload) async throws -> String {
        let status = EKEventStore.authorizationStatus(for: .event)
        guard status == .writeOnly || status == .fullAccess else {
            throw CalendarServiceError.permissionDenied
        }
        guard let calendar = store.defaultCalendarForNewEvents, calendar.allowsContentModifications else {
            throw CalendarServiceError.noWritableCalendar
        }

        let event = EKEvent(eventStore: store)
        event.calendar = calendar
        event.title = "DoNow · \(payload.taskName)"
        event.startDate = payload.startDate
        event.endDate = payload.endDate
        event.notes = "DoNow Session: \(payload.sessionID.uuidString)"
        try store.save(event, span: .thisEvent, commit: true)
        return event.eventIdentifier
    }
}
