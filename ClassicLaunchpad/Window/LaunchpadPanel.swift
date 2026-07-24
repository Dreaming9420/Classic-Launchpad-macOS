import AppKit

final class LaunchpadPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    init(screen: NSScreen) {
        super.init(
            contentRect: screen.frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        animationBehavior = .none
        level = NSWindow.Level(rawValue: NSWindow.Level.mainMenu.rawValue + 1)
        collectionBehavior = [
            .canJoinAllApplications,
            .canJoinAllSpaces,
            .stationary,
            .ignoresCycle
        ]
        isMovable = false
        hidesOnDeactivate = false
        acceptsMouseMovedEvents = true
    }
}
