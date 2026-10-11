import AppKit
import SwiftUI

enum FloatingExpansionPlacement: Equatable {
    case leftUp
    case rightUp
    case leftDown
    case rightDown

    var expandsRight: Bool {
        self == .rightUp || self == .rightDown
    }

    var expandsDown: Bool {
        self == .leftDown || self == .rightDown
    }
}

private enum FloatingDockEdge: String {
    case left
    case right
}

private final class EdgeDockingPanel: NSPanel {
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
        // The docked state intentionally keeps most of the panel outside the
        // visible frame, leaving only a narrow hover target on screen.
        frameRect
    }
}

@MainActor
final class FloatingPanelCoordinator: NSObject, NSWindowDelegate {
    private let appModel: AppModel
    private let panel: NSPanel
    private var isExpanded = false
    private var expansionPlacement: FloatingExpansionPlacement = .leftUp
    private var dockEdge: FloatingDockEdge?
    private var isDockHidden = false
    private var suppressRevealUntilMouseLeaves = false
    private var dockDecisionTask: Task<Void, Never>?
    private var hideTask: Task<Void, Never>?
    private var ignoreMoveEventsUntil = Date.distantPast
    private let compactSize = NSSize(width: 72, height: 72)
    private let expandedSize = NSSize(width: 360, height: 470)
    private let dockingThreshold: CGFloat = 14
    private let activationStripWidth: CGFloat = 7

    init(appModel: AppModel) {
        self.appModel = appModel
        panel = EdgeDockingPanel(
            contentRect: NSRect(origin: .zero, size: compactSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        super.init()

        panel.delegate = self
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.isMovableByWindowBackground = true

        let root = FloatingRootView(
            appModel: appModel,
            expansionPlacementRequested: { [weak self] in
                self?.prepareExpansion() ?? .leftUp
            },
            expandedStateChanged: { [weak self] expanded, placement in
                self?.setExpanded(expanded, placement: placement)
            },
            hoverChanged: { [weak self] hovering in
                self?.pointerHoverChanged(hovering)
            }
        )
        panel.contentView = NSHostingView(rootView: root)
        restorePosition()
    }

    func show() {
        panel.orderFrontRegardless()
    }

    private func prepareExpansion() -> FloatingExpansionPlacement {
        hideTask?.cancel()
        if isDockHidden {
            revealDockedBall(animated: false)
        }
        expansionPlacement = preferredExpansionPlacement(for: panel.frame)
        return expansionPlacement
    }

    private func setExpanded(
        _ expanded: Bool,
        placement: FloatingExpansionPlacement
    ) {
        guard expanded != isExpanded else { return }
        hideTask?.cancel()
        expansionPlacement = placement
        isExpanded = expanded
        applyPanelSize(expanded: expanded)
    }

    private func applyPanelSize(expanded: Bool) {
        let oldFrame = panel.frame
        let newSize = expanded ? expandedSize : compactSize
        let newOrigin = NSPoint(
            x: expansionPlacement.expandsRight
                ? oldFrame.minX
                : oldFrame.maxX - newSize.width,
            y: expansionPlacement.expandsDown
                ? oldFrame.maxY - newSize.height
                : oldFrame.minY
        )
        // Never animate the window frame here. Even when its corner is
        // mathematically anchored, AppKit and SwiftUI interpolate on different
        // timelines and the ball appears to jump. The picker content may
        // animate independently without moving the window or the ball.
        setPanelFrame(NSRect(origin: newOrigin, size: newSize), animated: false)
        if expanded {
            panel.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        } else {
            panel.resignKey()
            panel.orderFrontRegardless()
        }
        if !expanded {
            clampToVisibleScreen()
        }
        if !expanded, dockEdge != nil {
            scheduleHide()
        }
    }

    private func preferredExpansionPlacement(for ballFrame: NSRect) -> FloatingExpansionPlacement {
        let screen = NSScreen.screens.first(where: { $0.frame.intersects(ballFrame) }) ?? NSScreen.main
        guard let visibleFrame = screen?.visibleFrame else { return .leftUp }

        let availableLeft = ballFrame.minX - visibleFrame.minX
        let availableRight = visibleFrame.maxX - ballFrame.maxX
        let availableAbove = visibleFrame.maxY - ballFrame.maxY
        let availableBelow = ballFrame.minY - visibleFrame.minY
        let extraWidth = expandedSize.width - compactSize.width
        let extraHeight = expandedSize.height - compactSize.height

        let expandRight = preferredPositiveDirection(
            positiveSpace: availableRight,
            negativeSpace: availableLeft,
            requiredSpace: extraWidth
        )
        let expandDown = preferredPositiveDirection(
            positiveSpace: availableBelow,
            negativeSpace: availableAbove,
            requiredSpace: extraHeight
        )

        switch (expandRight, expandDown) {
        case (true, true): return .rightDown
        case (true, false): return .rightUp
        case (false, true): return .leftDown
        case (false, false): return .leftUp
        }
    }

    private func preferredPositiveDirection(
        positiveSpace: CGFloat,
        negativeSpace: CGFloat,
        requiredSpace: CGFloat
    ) -> Bool {
        switch (positiveSpace >= requiredSpace, negativeSpace >= requiredSpace) {
        case (true, false): true
        case (false, true): false
        default: positiveSpace >= negativeSpace
        }
    }

    func windowDidMove(_ notification: Notification) {
        guard !isExpanded, Date() >= ignoreMoveEventsUntil else { return }
        hideTask?.cancel()
        UserDefaults.standard.set(panel.frame.origin.x, forKey: "floatingBallX")
        UserDefaults.standard.set(panel.frame.origin.y, forKey: "floatingBallY")

        if dockEdge != nil, !isDockHidden, hasMovedAwayFromDockEdge() {
            clearDocking()
        }
        scheduleDockDecision()
    }

    func windowDidResignKey(_ notification: Notification) {
        if isExpanded {
            NotificationCenter.default.post(name: .collapseFloatingPanel, object: nil)
        }
    }

    private func restorePosition() {
        let defaults = UserDefaults.standard
        if let rawEdge = defaults.string(forKey: "floatingBallDockEdge") {
            dockEdge = FloatingDockEdge(rawValue: rawEdge)
        }
        if defaults.object(forKey: "floatingBallX") != nil {
            panel.setFrameOrigin(NSPoint(
                x: defaults.double(forKey: "floatingBallX"),
                y: defaults.double(forKey: "floatingBallY")
            ))
        } else if let screen = NSScreen.main {
            panel.setFrameOrigin(NSPoint(
                x: screen.visibleFrame.maxX - compactSize.width - 24,
                y: screen.visibleFrame.midY
            ))
        }
        clampToVisibleScreen()
        if dockEdge != nil {
            hideDockedBall(animated: false)
        }
    }

    private func clampToVisibleScreen() {
        let targetScreen = NSScreen.screens.first(where: { $0.frame.intersects(panel.frame) }) ?? NSScreen.main
        guard let visible = targetScreen?.visibleFrame else { return }
        var frame = panel.frame
        frame.origin.y = min(max(frame.origin.y, visible.minY), visible.maxY - frame.height)
        if let dockEdge, !isExpanded {
            switch (dockEdge, isDockHidden) {
            case (.left, true):
                frame.origin.x = visible.minX - frame.width + activationStripWidth
            case (.right, true):
                frame.origin.x = visible.maxX - activationStripWidth
            case (.left, false):
                frame.origin.x = visible.minX
            case (.right, false):
                frame.origin.x = visible.maxX - frame.width
            }
        } else {
            frame.origin.x = min(max(frame.origin.x, visible.minX), visible.maxX - frame.width)
        }
        setPanelFrame(frame, animated: false)
    }

    private func pointerHoverChanged(_ hovering: Bool) {
        if hovering {
            hideTask?.cancel()
            guard !suppressRevealUntilMouseLeaves else { return }
            if dockEdge != nil, isDockHidden, !isExpanded {
                revealDockedBall(animated: true)
            }
        } else {
            suppressRevealUntilMouseLeaves = false
            if dockEdge != nil, !isExpanded {
                scheduleHide()
            }
        }
    }

    private func scheduleDockDecision() {
        dockDecisionTask?.cancel()
        dockDecisionTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(280))
            guard !Task.isCancelled else { return }
            self?.finishMoving()
        }
    }

    private func finishMoving() {
        guard !isExpanded else { return }
        let screen = NSScreen.screens.first(where: { $0.frame.intersects(panel.frame) }) ?? NSScreen.main
        guard let visible = screen?.visibleFrame else { return }

        let touchesLeftEdge = panel.frame.minX <= visible.minX + dockingThreshold
        let touchesRightEdge = panel.frame.maxX >= visible.maxX - dockingThreshold
        if touchesLeftEdge || touchesRightEdge {
            let leftDistance = abs(panel.frame.minX - visible.minX)
            let rightDistance = abs(visible.maxX - panel.frame.maxX)
            dock(to: touchesLeftEdge && (!touchesRightEdge || leftDistance <= rightDistance) ? .left : .right)
        }
    }

    private func dock(to edge: FloatingDockEdge) {
        dockDecisionTask?.cancel()
        dockEdge = edge
        suppressRevealUntilMouseLeaves = true
        UserDefaults.standard.set(edge.rawValue, forKey: "floatingBallDockEdge")
        UserDefaults.standard.set(panel.frame.origin.y, forKey: "floatingBallY")
        hideDockedBall(animated: true)
    }

    private func clearDocking() {
        dockEdge = nil
        isDockHidden = false
        suppressRevealUntilMouseLeaves = false
        hideTask?.cancel()
        UserDefaults.standard.removeObject(forKey: "floatingBallDockEdge")
    }

    private func hasMovedAwayFromDockEdge() -> Bool {
        guard let dockEdge else { return false }
        let screen = NSScreen.screens.first(where: { $0.frame.intersects(panel.frame) }) ?? NSScreen.main
        guard let visible = screen?.visibleFrame else { return false }
        switch dockEdge {
        case .left:
            return panel.frame.minX > visible.minX + dockingThreshold * 2
        case .right:
            return panel.frame.maxX < visible.maxX - dockingThreshold * 2
        }
    }

    private func scheduleHide() {
        hideTask?.cancel()
        hideTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(700))
            guard !Task.isCancelled else { return }
            self?.hideDockedBall(animated: true)
        }
    }

    private func hideDockedBall(animated: Bool) {
        guard let dockEdge, !isExpanded else { return }
        let screen = NSScreen.screens.first(where: { $0.frame.intersects(panel.frame) }) ?? NSScreen.main
        guard let visible = screen?.visibleFrame else { return }
        var frame = panel.frame
        frame.size = compactSize
        frame.origin.y = min(max(frame.origin.y, visible.minY), visible.maxY - frame.height)
        frame.origin.x = dockEdge == .left
            ? visible.minX - frame.width + activationStripWidth
            : visible.maxX - activationStripWidth
        isDockHidden = true
        setPanelFrame(frame, animated: animated)
    }

    private func revealDockedBall(animated: Bool) {
        guard let dockEdge else { return }
        let screen = NSScreen.screens.first(where: { $0.frame.intersects(panel.frame) }) ?? NSScreen.main
        guard let visible = screen?.visibleFrame else { return }
        var frame = panel.frame
        frame.size = compactSize
        frame.origin.y = min(max(frame.origin.y, visible.minY), visible.maxY - frame.height)
        frame.origin.x = dockEdge == .left ? visible.minX : visible.maxX - frame.width
        isDockHidden = false
        setPanelFrame(frame, animated: animated)
    }

    private func setPanelFrame(_ frame: NSRect, animated: Bool) {
        ignoreMoveEventsUntil = Date().addingTimeInterval(animated ? 0.45 : 0.08)
        panel.setFrame(frame, display: true, animate: animated)
    }
}

extension Notification.Name {
    static let collapseFloatingPanel = Notification.Name("DoNow.collapseFloatingPanel")
}
