import Foundation

/// PT-v4 catch policy and progression arithmetic. These rules are independent of
/// UI, networking and reward ledgers so a catch cannot award wallet XP twice.
enum RepeatCatchTraining {
    static let maxCredit = 1_000_000_000_000_000

    struct Candidate: Equatable, Sendable {
        let baseID: Int
        let form: String?
        let isShiny: Bool
        let isUnrevealedDitto: Bool
    }

    /// Storage order breaks ties in old saves containing multiple normal partners.
    /// Historical graduates/releases never enter this list; shiny catches remain individuals.
    static func targetIndex(for incoming: Candidate, stored: [Candidate?]) -> Int? {
        guard !incoming.isShiny, !incoming.isUnrevealedDitto else { return nil }
        return stored.firstIndex { candidate in
            guard let candidate else { return false }
            return !candidate.isShiny && !candidate.isUnrevealedDitto
                && candidate.baseID == incoming.baseID && candidate.form == incoming.form
        }
    }

    static func clampedCredit(_ value: Int) -> Int { min(maxCredit, max(0, value)) }

    static func addingCredit(_ amount: Int, to previous: Int) -> Int {
        let previous = clampedCredit(previous)
        return previous + min(maxCredit - previous, clampedCredit(amount))
    }

    /// Reprice every banked stage/egg as well as the active slot when Settings changes.
    /// An incomplete phase must stay incomplete despite rounding to a smaller threshold.
    static func repricedUsage(_ usage: Int, oldThreshold: Int, newThreshold: Int) -> Int {
        let old = max(1, oldThreshold), new = max(1, newThreshold)
        let usage = clampedCredit(usage)
        let fraction = Double(usage) / Double(old)
        let rounded = Int(min(Double(maxCredit), max(0, (fraction * Double(new)).rounded(.down))))
        return usage < old ? min(new - 1, rounded) : rounded
    }

    /// Level XP uses standard balance units; raw stage XP can have a difficulty or repeat boost.
    static func standardGrowth(completed: Int, currentUsage: Int, adjustedThreshold: Int,
                               standardPhase: Int, graduationTotal: Int) -> Int {
        let fraction = min(1, Double(clampedCredit(currentUsage)) / Double(max(1, adjustedThreshold)))
        let phaseGrowth = Int(min(Double(maxCredit), (Double(max(0, standardPhase)) * fraction).rounded(.down)))
        return min(clampedCredit(graduationTotal), addingCredit(phaseGrowth, to: completed))
    }
}
