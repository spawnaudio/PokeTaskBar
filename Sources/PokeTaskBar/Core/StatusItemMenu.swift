import AppKit

/// What a status-item menu row does. AppDelegate maps each case onto the stores.
enum StatusItemMenuAction: Equatable {
    case togglePause
    case finishTimer
    case markDone
    case quickStart(minutes: Int)
    case openToday
    case openSettings
    case quit
}

struct StatusItemMenuEntry: Equatable {
    let title: String
    let action: StatusItemMenuAction
}

/// Right-click menu on the status item — quick actions without opening the panel. Pure, testable.
enum StatusItemMenu {
    /// Sections are separated in the NSMenu. Session controls first, then app navigation.
    static func sections(session: FocusSession?, l: L) -> [[StatusItemMenuEntry]] {
        var result: [[StatusItemMenuEntry]] = []
        if let session {
            var controls: [StatusItemMenuEntry] = []
            if session.phase != .awaitingChoice {
                let paused = session.userPaused || session.phase == .paused
                controls.append(StatusItemMenuEntry(
                    title: paused ? l.resumeTimer : l.pauseTimer, action: .togglePause))
            }
            if session.issue.isLocal {
                controls.append(StatusItemMenuEntry(title: l.statusMenuFinishTimer, action: .finishTimer))
            } else {
                controls.append(StatusItemMenuEntry(title: l.markDone, action: .markDone))
                controls.append(StatusItemMenuEntry(title: l.timesUpFinishLeave, action: .finishTimer))
            }
            result.append(controls)
        } else {
            result.append(SessionXP.plannedPresets.map { minutes in
                StatusItemMenuEntry(
                    title: "\(l.startFocus) · \(l.minutesValue(minutes))",
                    action: .quickStart(minutes: minutes))
            })
        }
        result.append([
            StatusItemMenuEntry(title: l.todayDeskMenuOpen, action: .openToday),
            StatusItemMenuEntry(title: "\(l.settings)…", action: .openSettings),
        ])
        result.append([StatusItemMenuEntry(title: l.quit, action: .quit)])
        return result
    }

    /// Right click, or control-click as on any macOS status item, opens the menu.
    /// A plain left click keeps toggling the panel.
    static func isMenuRequest(type: NSEvent.EventType?, modifiers: NSEvent.ModifierFlags) -> Bool {
        guard let type else { return false }
        switch type {
        case .rightMouseUp, .rightMouseDown: return true
        case .leftMouseUp, .leftMouseDown: return modifiers.contains(.control)
        default: return false
        }
    }
}
