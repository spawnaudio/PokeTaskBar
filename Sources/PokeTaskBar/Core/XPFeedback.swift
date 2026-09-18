import Foundation

/// Transient receipts for XP actually credited; never persisted or replayed on launch.
struct XPReward: Equatable {
    enum Source: Equatable {
        case tokens, timeOpen, focus, issue, project, candy

        var isBackground: Bool {
            self == .tokens || self == .timeOpen || self == .focus
        }
    }

    var amount: Int
    var source: Source

    var text: String { "+\(TokenFormatter.compact(amount)) XP" }
    var exactText: String { "+\(TokenFormatter.grouped(amount)) XP" }
    var isCompletion: Bool { source == .issue || source == .project }
}

/// At most one pending receipt per source. Completion/candy receipts take priority,
/// while frequent background awards are totalled and shown at most every 30 seconds.
struct XPFeedbackQueue {
    private(set) var pending: [XPReward] = []
    private(set) var nextBackgroundAt = Date.distantPast

    mutating func append(_ reward: XPReward) {
        guard reward.amount > 0 else { return }
        if let index = pending.firstIndex(where: { $0.source == reward.source }) {
            pending[index].amount += reward.amount
        } else {
            pending.append(reward)
        }
    }

    mutating func next(at now: Date, backgroundInterval: TimeInterval) -> XPReward? {
        if let index = pending.firstIndex(where: { !$0.source.isBackground }) {
            return pending.remove(at: index)
        }
        guard !pending.isEmpty, now >= nextBackgroundAt else { return nil }
        // All remaining receipts are background XP; combine them without losing XP.
        let reward = XPReward(amount: pending.reduce(0) { $0 + $1.amount }, source: pending[0].source)
        pending.removeAll()
        nextBackgroundAt = now.addingTimeInterval(backgroundInterval)
        return reward
    }
}

/// One finite task for visible feedback or a pending batch; no idle polling timer.
@MainActor
final class XPFeedbackController {
    private(set) var current: XPReward?
    var onChange: ((XPReward?) -> Void)?
    private var queue = XPFeedbackQueue()
    private var task: Task<Void, Never>?
    private var displayAwake = true
    private let duration: TimeInterval
    private let backgroundInterval: TimeInterval

    init(duration: TimeInterval = 3, backgroundInterval: TimeInterval = 30) {
        self.duration = duration
        self.backgroundInterval = backgroundInterval
    }

    func receive(_ reward: XPReward) {
        guard displayAwake, reward.amount > 0 else { return }
        queue.append(reward)
        if current == nil { advance() }
    }

    func setDisplayAwake(_ awake: Bool) {
        displayAwake = awake
        guard !awake else { return }
        task?.cancel()
        task = nil
        queue = XPFeedbackQueue()
        current = nil
        onChange?(nil)
    }

    private func advance() {
        task?.cancel()
        task = nil
        let now = Date()
        guard let reward = queue.next(at: now, backgroundInterval: backgroundInterval) else {
            guard !queue.pending.isEmpty else { return }
            schedule(after: max(0, queue.nextBackgroundAt.timeIntervalSince(now))) { $0.advance() }
            return
        }
        current = reward
        onChange?(reward)
        schedule(after: duration) { controller in
            controller.current = nil
            controller.onChange?(nil)
            controller.advance()
        }
    }

    private func schedule(after delay: TimeInterval, action: @escaping @MainActor (XPFeedbackController) -> Void) {
        task = Task { [weak self] in
            do { try await Task.sleep(for: .seconds(delay)) }
            catch { return }
            guard let self else { return }
            action(self)
        }
    }
}
