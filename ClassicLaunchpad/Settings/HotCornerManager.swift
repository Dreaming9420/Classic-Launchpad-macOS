import AppKit
import Dispatch

final class HotCornerManager {
    var handler: (() -> Void)?

    private var configuration = HotCornerConfiguration()
    private var systemConflicts = Set<HotCornerPosition>()
    private var isStarted = false
    private var timer: DispatchSourceTimer?
    private var activity: NSObjectProtocol?
    private var occupiedZone: HotCornerZone?

    func start() {
        guard !isStarted else { return }
        isStarted = true
        refreshMonitoringState()
    }

    func stop() {
        isStarted = false
        stopPolling()
        occupiedZone = nil
    }

    func update(
        configuration: HotCornerConfiguration,
        systemConflicts: Set<HotCornerPosition>
    ) {
        self.configuration = configuration
        self.systemConflicts = systemConflicts
        refreshMonitoringState()
    }

    private func refreshMonitoringState() {
        if isStarted && !configuration.enabledPositions.isEmpty {
            startPolling()
        } else {
            stopPolling()
        }
    }

    private func startPolling() {
        guard timer == nil else { return }

        activity = ProcessInfo.processInfo.beginActivity(
            options: .userInitiatedAllowingIdleSystemSleep,
            reason: HotCornerActivity.reason
        )

        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(
            deadline: .now(),
            repeating: HotCornerTiming.pollInterval,
            leeway: HotCornerTiming.leeway
        )
        timer.setEventHandler { [weak self] in
            self?.checkPointerLocation()
        }
        self.timer = timer
        timer.resume()
    }

    private func stopPolling() {
        if let timer {
            timer.setEventHandler {}
            timer.cancel()
            self.timer = nil
        }
        if let activity {
            ProcessInfo.processInfo.endActivity(activity)
            self.activity = nil
        }
    }

    private func checkPointerLocation() {
        guard let zone = hotCornerZone(at: NSEvent.mouseLocation) else {
            occupiedZone = nil
            return
        }
        guard zone != occupiedZone else { return }
        occupiedZone = zone

        let assignment = configuration[zone.position]
        guard
            assignment.isEnabled,
            !systemConflicts.contains(zone.position),
            NSEvent.modifierFlags
                .intersection(HotCornerModifier.supported)
                .isSuperset(of: assignment.modifierFlags)
        else {
            return
        }
        handler?()
    }

    private func hotCornerZone(at point: CGPoint) -> HotCornerZone? {
        for screen in NSScreen.screens {
            let frame = screen.frame
            let nearLeft = point.x <= frame.minX + HotCornerGeometry.edgeTolerance
                && point.x >= frame.minX - HotCornerGeometry.edgeTolerance
            let nearRight = point.x >= frame.maxX - HotCornerGeometry.edgeTolerance
                && point.x <= frame.maxX + HotCornerGeometry.edgeTolerance
            let nearBottom = point.y <= frame.minY + HotCornerGeometry.edgeTolerance
                && point.y >= frame.minY - HotCornerGeometry.edgeTolerance
            let nearTop = point.y >= frame.maxY - HotCornerGeometry.edgeTolerance
                && point.y <= frame.maxY + HotCornerGeometry.edgeTolerance

            let position: HotCornerPosition
            if nearLeft && nearTop {
                position = .topLeft
            } else if nearRight && nearTop {
                position = .topRight
            } else if nearLeft && nearBottom {
                position = .bottomLeft
            } else if nearRight && nearBottom {
                position = .bottomRight
            } else {
                continue
            }
            return HotCornerZone(screenFrame: frame, position: position)
        }
        return nil
    }
}

private struct HotCornerZone: Equatable {
    let screenFrame: CGRect
    let position: HotCornerPosition
}

private enum HotCornerGeometry {
    static let edgeTolerance: CGFloat = 2
}

private enum HotCornerTiming {
    static let pollInterval: DispatchTimeInterval = .milliseconds(50)
    static let leeway: DispatchTimeInterval = .milliseconds(5)
}

private enum HotCornerActivity {
    static let reason = "Monitor the selected hot corner"
}
