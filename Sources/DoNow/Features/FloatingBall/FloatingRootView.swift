import SwiftUI

struct FloatingRootView: View {
    @ObservedObject var appModel: AppModel
    @ObservedObject private var timer: TimerCoordinator
    @State private var isExpanded = false
    @State private var expansionPlacement: FloatingExpansionPlacement = .leftUp
    let expansionPlacementRequested: () -> FloatingExpansionPlacement
    let expandedStateChanged: (Bool, FloatingExpansionPlacement) -> Void
    let hoverChanged: (Bool) -> Void

    init(
        appModel: AppModel,
        expansionPlacementRequested: @escaping () -> FloatingExpansionPlacement,
        expandedStateChanged: @escaping (Bool, FloatingExpansionPlacement) -> Void,
        hoverChanged: @escaping (Bool) -> Void
    ) {
        self.appModel = appModel
        self.timer = appModel.timer
        self.expansionPlacementRequested = expansionPlacementRequested
        self.expandedStateChanged = expandedStateChanged
        self.hoverChanged = hoverChanged
    }

    var body: some View {
        ZStack(alignment: panelAlignment) {
            if isExpanded {
                pickerPanel
                    .padding(expansionPlacement.expandsDown ? .top : .bottom, 76)
            }

            ball
                .frame(width: 64, height: 64)
                .padding(4)
        }
        .contentShape(Rectangle())
        .onHover(perform: hoverChanged)
        .onChange(of: isExpanded) { _, expanded in
            // This callback runs after SwiftUI has recomputed the hierarchy
            // with the new corner alignment. Only then may AppKit resize the
            // hosting window, otherwise the ball is rendered in the old
            // corner for one frame and visibly jumps.
            expandedStateChanged(expanded, expansionPlacement)
        }
        .onReceive(NotificationCenter.default.publisher(for: .collapseFloatingPanel)) { _ in
            setExpanded(false)
        }
    }

    private var ball: some View {
        Button {
            setExpanded(!isExpanded)
        } label: {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.indigo, .blue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: .black.opacity(0.25), radius: 10, y: 4)
                if timer.activeSession != nil {
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(.white.opacity(0.9), style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .padding(5)
                    Text(shortTime(timer.remainingSeconds))
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                } else {
                    Image(systemName: "checkmark")
                        .font(.system(size: 25, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(timer.activeSession == nil ? "打开 DoNow" : "查看当前计时")
    }

    @ViewBuilder
    private var pickerPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let session = timer.activeSession {
                ActiveTimerView(session: session, timer: timer)
            } else {
                Text("想做什么？")
                    .font(.title2.bold())

                if appModel.tasks.isEmpty {
                    ContentUnavailableView(
                        "还没有事项",
                        systemImage: "checklist",
                        description: Text("请先在设置中添加一个事项。")
                    )
                } else {
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(appModel.tasks) { task in
                                Button {
                                    appModel.start(task)
                                } label: {
                                    HStack {
                                        Text(task.name)
                                            .fontWeight(.medium)
                                        Spacer()
                                        Text(durationLabel(task.estimatedDurationSeconds))
                                            .foregroundStyle(.secondary)
                                    }
                                    .padding(12)
                                    .background(.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }

            Divider()
            Button("管理事项与设置", systemImage: "gearshape") {
                appModel.showSettings()
                setExpanded(false)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
        .padding(18)
        .frame(width: 340, height: 380, alignment: .topLeading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22))
        .overlay {
            RoundedRectangle(cornerRadius: 22)
                .stroke(.white.opacity(0.16))
        }
        .shadow(color: .black.opacity(0.22), radius: 20, y: 8)
    }

    private var progress: CGFloat {
        guard let session = timer.activeSession else { return 0 }
        let total = max(1, session.plannedDurationSeconds)
        return CGFloat(1 - Double(timer.remainingSeconds) / Double(total)).clamped(to: 0...1)
    }

    private func setExpanded(_ expanded: Bool) {
        if expanded {
            let placement = expansionPlacementRequested()
            expansionPlacement = placement
            isExpanded = true
        } else {
            isExpanded = false
        }
    }

    private var panelAlignment: Alignment {
        switch expansionPlacement {
        case .leftUp: .bottomTrailing
        case .rightUp: .bottomLeading
        case .leftDown: .topTrailing
        case .rightDown: .topLeading
        }
    }

    private func shortTime(_ seconds: Int) -> String {
        let remaining = max(0, seconds)
        if remaining < 3600 {
            return "\(remaining / 60)m"
        }
        let hours = remaining / 3600
        let minutes = (remaining % 3600) / 60
        return "\(hours)h\(minutes)m"
    }

    private func durationLabel(_ seconds: Int) -> String {
        seconds % 3600 == 0 ? "\(seconds / 3600) 小时" : "\(seconds / 60) 分钟"
    }
}

private extension Comparable {
    func clamped(to limits: ClosedRange<Self>) -> Self {
        min(max(self, limits.lowerBound), limits.upperBound)
    }
}
