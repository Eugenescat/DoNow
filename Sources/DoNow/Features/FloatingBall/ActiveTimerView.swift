import SwiftUI

struct ActiveTimerView: View {
    let session: FocusSession
    @ObservedObject var timer: TimerCoordinator

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(session.phase == .paused ? "已暂停" : "正在进行")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(session.taskNameSnapshot)
                .font(.title2.bold())
            Text(formattedTime)
                .font(.system(size: 48, weight: .semibold, design: .rounded))
                .monospacedDigit()

            HStack {
                Button(session.phase == .paused ? "继续" : "暂停") {
                    session.phase == .paused ? timer.resume() : timer.pause()
                }
                .buttonStyle(.borderedProminent)

                Button("放弃", role: .destructive) {
                    timer.abandon()
                }
                .buttonStyle(.bordered)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var formattedTime: String {
        let seconds = max(0, timer.remainingSeconds)
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let remainder = seconds % 60
        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, remainder)
        }
        return String(format: "%02d:%02d", minutes, remainder)
    }
}
