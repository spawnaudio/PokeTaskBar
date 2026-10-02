import Foundation

/// Paid timer additions must fit in full and preserve pause/sleep accounting.
enum FocusPotion {
    static let kinds: [ItemKind] = [.potion, .superPotion, .hyperPotion, .revive, .fullRestore]

    static func extending(_ session: FocusSession, minutes: Int, now: Date) -> FocusSession? {
        guard (1...SessionXP.maxMinutes).contains(minutes) else { return nil }
        let base = max(session.plannedSeconds, FocusTick.elapsedSeconds(session, now: now))
        guard base + Double(minutes * 60) <= Double(SessionXP.maxMinutes * 60),
              var next = FocusTick.addRemaining(session, minutes: minutes, now: now) else { return nil }
        if session.userPaused || session.phase == .paused {
            next = FocusTick.pause(next, now: now)
        }
        return next
    }
}

/// Replay after interruption; the companion transaction ID makes consumption idempotent.
struct FocusPotionJournal: Codable {
    var id: String
    var kind: ItemKind
    var session: FocusSession
}
