import SwiftUI

struct HistoryView: View {
    @ObservedObject var appModel: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("历史记录")
                .font(.title2.bold())

            if appModel.recentSessions.isEmpty {
                ContentUnavailableView("还没有记录", systemImage: "clock")
            } else {
                List(appModel.recentSessions) { session in
                    HStack(spacing: 12) {
                        Image(systemName: icon(for: session.phase))
                            .foregroundStyle(color(for: session.phase))
                        VStack(alignment: .leading, spacing: 3) {
                            Text(session.taskNameSnapshot).fontWeight(.medium)
                            Text(session.startedAt, format: .dateTime.month().day().hour().minute())
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 3) {
                            Text("\(session.plannedDurationSeconds / 60) 分钟")
                            if session.phase == .completed {
                                Label(syncLabel(session.calendarSyncState), systemImage: syncIcon(session.calendarSyncState))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            } else {
                                Text("已放弃")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .onAppear { appModel.reload() }
    }

    private func icon(for phase: TimerPhase) -> String {
        phase == .completed ? "checkmark.circle.fill" : "xmark.circle"
    }

    private func color(for phase: TimerPhase) -> Color {
        phase == .completed ? .green : .secondary
    }

    private func syncLabel(_ state: CalendarSyncState) -> String {
        switch state {
        case .notRequested: "未同步"
        case .pending: "同步中"
        case .synced: "已写入日历"
        case .failed: "日历同步失败"
        }
    }

    private func syncIcon(_ state: CalendarSyncState) -> String {
        switch state {
        case .synced: "calendar.badge.checkmark"
        case .failed: "exclamationmark.triangle"
        default: "calendar"
        }
    }
}
