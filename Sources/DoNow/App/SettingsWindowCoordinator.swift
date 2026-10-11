import AppKit
import SwiftUI

@MainActor
final class SettingsWindowCoordinator: NSObject, NSWindowDelegate {
    private let comfortableSize = NSSize(width: 900, height: 680)
    private let minimumSize = NSSize(width: 780, height: 580)
    private let appModel: AppModel
    private var window: NSWindow?

    init(appModel: AppModel) {
        self.appModel = appModel
    }

    func show() {
        let window = window ?? makeWindow()
        ensureComfortableSize(window)
        if window.isMiniaturized {
            window.deminiaturize(nil)
        }
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    private func makeWindow() -> NSWindow {
        let content = SettingsRootView(appModel: appModel)
        let controller = NSHostingController(rootView: content)
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: comfortableSize),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "DoNow 设置"
        window.contentViewController = controller
        window.isReleasedWhenClosed = false
        window.minSize = minimumSize
        window.setFrameAutosaveName("DoNowSettingsWindow")
        ensureComfortableSize(window)
        window.center()
        window.delegate = self
        self.window = window
        return window
    }

    private func ensureComfortableSize(_ window: NSWindow) {
        guard window.frame.width < comfortableSize.width || window.frame.height < comfortableSize.height else {
            return
        }

        let currentCenter = NSPoint(x: window.frame.midX, y: window.frame.midY)
        var frame = window.frame
        frame.size.width = max(frame.width, comfortableSize.width)
        frame.size.height = max(frame.height, comfortableSize.height)
        frame.origin = NSPoint(
            x: currentCenter.x - frame.width / 2,
            y: currentCenter.y - frame.height / 2
        )
        if let visibleFrame = window.screen?.visibleFrame ?? NSScreen.main?.visibleFrame {
            frame.size.width = min(frame.width, visibleFrame.width)
            frame.size.height = min(frame.height, visibleFrame.height)
            frame.origin.x = min(max(frame.origin.x, visibleFrame.minX), visibleFrame.maxX - frame.width)
            frame.origin.y = min(max(frame.origin.y, visibleFrame.minY), visibleFrame.maxY - frame.height)
        }
        window.setFrame(frame, display: false)
    }
}
