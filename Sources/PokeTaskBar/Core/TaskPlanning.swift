import Foundation
import Observation

enum PlanningGroup: String, Codable, CaseIterable, Identifiable {
    case today, soon, later
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    var statusName: String { switch self { case .today: "In Progress"; case .soon: "Planned"; case .later: "Todo" } }
    func matchesStatus(_ issue: LinearIssueSummary) -> Bool {
        switch self {
        case .today: LinearClient.isInProgressIssue(issue)
        case .soon: LinearClient.isPlannedIssue(issue)
        case .later: LinearClient.isTodoIssue(issue)
        }
    }
}

struct TaskPlanEntry: Codable, Equatable, Identifiable {
    var id: String
    var group: PlanningGroup
    var day: String?
    var order: Int
}

struct TaskTimeBlock: Codable, Equatable, Identifiable {
    var id = UUID()
    var issueID: String
    var identifier: String
    var title: String
    var projectID: String?
    var day: String
    var startMinute: Int
    var durationMinutes: Int
    var timeZoneID: String? = TimeZone.current.identifier
    var startAt: Date?
    var endAt: Date?
    var endMinute: Int { startMinute + durationMinutes }
    var timeRange: String {
        guard let startAt, let endAt else { return String(format: "%02d:%02d – %02d:%02d", startMinute / 60, startMinute % 60, endMinute / 60, endMinute % 60) }
        let formatter = DateFormatter()
        formatter.timeZone = timeZoneID.flatMap(TimeZone.init(identifier:)) ?? .current
        formatter.dateFormat = "HH:mm"
        return "\(formatter.string(from: startAt)) – \(formatter.string(from: endAt))"
    }

    static func snapped(_ minute: Double) -> Int {
        guard minute.isFinite else { return 0 }
        return Int((min(1440, max(0, minute)) / 5).rounded()) * 5
    }
    mutating func set(start: Int, duration: Int) {
        durationMinutes = min(180, max(5, Self.snapped(Double(duration))))
        startMinute = min(1440 - durationMinutes, max(0, Self.snapped(Double(start))))
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZoneID.flatMap(TimeZone.init(identifier:)) ?? .current
        let parts = day.split(separator: "-").compactMap { Int($0) }
        startAt = nil; endAt = nil
        if parts.count == 3 {
            startAt = calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2],
                hour: startMinute / 60, minute: startMinute % 60))
            if let startAt {
                let c = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: startAt)
                if c.year != parts[0] || c.month != parts[1] || c.day != parts[2] ||
                    c.hour != startMinute / 60 || c.minute != startMinute % 60 { self.startAt = nil }
            }
            endAt = startAt?.addingTimeInterval(Double(durationMinutes * 60))
        }
    }
}

enum PlanningSort: String, Codable, CaseIterable { case manual, priority, title }

private struct TaskPlanningState: Codable {
    var entries: [TaskPlanEntry] = []
    var blocks: [TaskTimeBlock] = []
    var folded: Set<PlanningGroup> = []
    var linked = false
    var sort: PlanningSort = .manual
}

@MainActor @Observable
final class TaskPlanningStore {
    private var state = TaskPlanningState()
    private let fileURL: URL
    private let clock: () -> Date
    private(set) var storageError: String?
    private var canSave = true
    private(set) var syncing = false
    private(set) var syncError: String?
    private(set) var undoMove: Move?
    private var failedMove: Move?
    private var blockUndo: (blocks: [TaskTimeBlock], entries: [TaskPlanEntry])?
    private(set) var blockError: String?
    var canUndoBlock: Bool { blockUndo != nil }
    var canRetry: Bool { failedMove != nil }
    var timelineHour = 8
    var selectedDay: Date
    var projectFilter = ""

    struct Move {
        var issue: LinearIssueSummary
        var before: TaskPlanEntry?
        var after: TaskPlanEntry?
        var priorStateID: String?
        var targetStateID: String?
        var linked: Bool
    }

    init(fileURL: URL, clock: @escaping () -> Date = Date.init) {
        self.fileURL = fileURL
        self.clock = clock
        selectedDay = clock()
        if FileManager.default.fileExists(atPath: fileURL.path) {
            do {
                state = try JSONDecoder().decode(TaskPlanningState.self, from: Data(contentsOf: fileURL))
                // Validate persisted geometry once at the storage boundary.
                for index in state.blocks.indices {
                    state.blocks[index].set(start: state.blocks[index].startMinute, duration: state.blocks[index].durationMinutes)
                }
                var seen = Set<String>()
                state.entries = state.entries.filter { seen.insert($0.id).inserted }
                state.entries.sort { $0.order < $1.order }
                for index in state.entries.indices { state.entries[index].order = index }
            } catch {
                canSave = false
                storageError = "The planning file could not be read. It has been preserved."
            }
        }
    }

    var entries: [TaskPlanEntry] { state.entries }
    var blocks: [TaskTimeBlock] { state.blocks }
    var folded: Set<PlanningGroup> { state.folded }
    var linked: Bool { get { state.linked } set { state.linked = newValue; save() } }
    var sort: PlanningSort { get { state.sort } set { state.sort = newValue; save() } }
    var dayKey: String { Self.dayKey(selectedDay) }
    static func issues(in usage: UsageStore) -> [LinearIssueSummary] {
        usage.allLinearIssues.filter(isOpen)
    }
    nonisolated static func dayKey(_ date: Date, calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }
    func fold(_ group: PlanningGroup) {
        if state.folded.contains(group) { state.folded.remove(group) } else { state.folded.insert(group) }
        save()
    }
    func foldAll(_ folded: Bool) { state.folded = folded ? Set(PlanningGroup.allCases) : []; save() }
    func entry(_ id: String) -> TaskPlanEntry? { state.entries.first { $0.id == id } }
    nonisolated static func isOpen(_ issue: LinearIssueSummary) -> Bool {
        !["completed", "canceled", "cancelled"].contains(issue.stateType?.lowercased() ?? "")
    }
    nonisolated static func stateID(for group: PlanningGroup, issue: LinearIssueSummary) -> String? {
        // All three names must resolve for this team; a missing mapping leaves it personal.
        guard PlanningGroup.allCases.allSatisfy({ group in
            issue.teamStates.filter { $0.name.caseInsensitiveCompare(group.statusName) == .orderedSame &&
                !["completed", "canceled", "cancelled"].contains($0.type.lowercased()) }.count == 1
        }) else { return nil }
        return issue.teamStates.first { $0.name.caseInsensitiveCompare(group.statusName) == .orderedSame }?.id
    }

    func move(_ issue: LinearIssueSummary, to group: PlanningGroup, usage: UsageStore,
              update: ((LinearIssueSummary, String) async -> Bool)? = nil) async {
        guard !syncing, Self.isOpen(issue), canSave else { return }
        let before = entry(issue.id)
        let after = TaskPlanEntry(id: issue.id, group: group, day: group == .today ? dayKey : nil,
                                 order: (state.entries.map(\.order).max() ?? 0) + 1)
        let move = Move(issue: issue, before: before, after: after, priorStateID: issue.stateId,
                        targetStateID: state.linked ? Self.stateID(for: group, issue: issue) : nil, linked: state.linked)
        setEntry(after, id: issue.id)
        undoMove = move
        guard storageError == nil else { return }
        await synchronize(move, usage: usage, update: update)
    }
    func undo(usage: UsageStore, update: ((LinearIssueSummary, String) async -> Bool)? = nil) async {
        guard !syncing, let move = undoMove, canSave else { return }
        setEntry(move.before, id: move.issue.id)
        undoMove = nil
        var restore = move
        restore.targetStateID = move.targetStateID == nil ? nil : move.priorStateID
        await synchronize(restore, usage: usage, update: update)
    }
    func retry(usage: UsageStore, update: ((LinearIssueSummary, String) async -> Bool)? = nil) async {
        guard !syncing, let failedMove else { return }
        await synchronize(failedMove, usage: usage, update: update)
    }
    private func synchronize(_ move: Move, usage: UsageStore,
                             update: ((LinearIssueSummary, String) async -> Bool)? = nil) async {
        syncError = nil; failedMove = nil
        guard move.linked else { return }
        guard let target = move.targetStateID else {
            syncError = "Personal move saved. This team needs valid In Progress, Planned and Todo mappings before linking."
            return
        }
        let current = usage.linearIssue(id: move.issue.id) ?? move.issue
        guard Self.isOpen(current) else {
            syncError = "The issue is closed in Linear. Its status was left unchanged."
            return
        }
        if current.stateId == target { return }
        syncing = true
        defer { syncing = false }
        let succeeded: Bool
        if let update { succeeded = await update(current, target) }
        else { succeeded = await usage.moveLinearIssueToState(current, stateID: target) }
        if !succeeded { failedMove = move; syncError = "The plan was saved, but Linear did not update. Retry or Undo." }
    }
    func remove(_ id: String) { guard !syncing else { return }; setEntry(nil, id: id) }
    private func setEntry(_ entry: TaskPlanEntry?, id: String) {
        state.entries.removeAll { $0.id == id }
        if let entry { state.entries.append(entry) }
        save()
    }
    func reorder(_ issueID: String, before otherID: String) {
        guard let target = entry(otherID), let moving = entry(issueID), target.group == moving.group,
              target.day == moving.day else { return }
        var ordered = state.entries.filter { $0.group == target.group && $0.day == target.day }
            .sorted { $0.order < $1.order }.filter { $0.id != issueID }
        ordered.insert(moving, at: ordered.firstIndex { $0.id == otherID } ?? ordered.endIndex)
        for (order, value) in ordered.enumerated() {
            if let index = state.entries.firstIndex(where: { $0.id == value.id }) { state.entries[index].order = order }
        }
        save()
    }
    @discardableResult
    func schedule(_ issue: LinearIssueSummary, start: Int, duration: Int = 30) -> TaskTimeBlock? {
        guard Self.isOpen(issue), canSave else { return nil }
        var block = TaskTimeBlock(issueID: issue.id, identifier: issue.identifier, title: issue.title,
                                  projectID: issue.projectID, day: dayKey, startMinute: 0, durationMinutes: 30)
        block.set(start: start, duration: duration)
        guard block.startAt != nil else { blockError = "That time is unavailable in this time zone. Choose another time."; return nil }
        guard !hasConflict(block) else { blockError = "That time overlaps another block. Choose a free time."; return nil }
        blockUndo = (state.blocks, state.entries)
        blockError = nil
        state.blocks.append(block)
        // Scheduling chooses a personal day; status linking only runs on explicit group moves.
        setEntry(TaskPlanEntry(id: issue.id, group: .today, day: dayKey,
            order: (state.entries.map(\.order).max() ?? 0) + 1), id: issue.id)
        return block
    }
    @discardableResult
    func edit(_ block: TaskTimeBlock, start: Int, duration: Int, day: String? = nil) -> Bool {
        guard canSave, let index = state.blocks.firstIndex(where: { $0.id == block.id }) else { return false }
        var updated = state.blocks[index]
        if let day { updated.day = day }
        updated.set(start: start, duration: duration)
        guard updated.startAt != nil else { blockError = "That time is unavailable in this time zone. Choose another time."; return false }
        guard !hasConflict(updated, excluding: block.id) else { blockError = "That time overlaps another block. Choose a free time."; return false }
        blockUndo = (state.blocks, state.entries)
        blockError = nil
        state.blocks[index] = updated
        save()
        return storageError == nil
    }
    func hasConflict(_ block: TaskTimeBlock, excluding id: UUID? = nil) -> Bool {
        state.blocks.contains { other in
            guard other.id != id else { return false }
            if let start = block.startAt, let end = block.endAt, let otherStart = other.startAt, let otherEnd = other.endAt {
                return otherStart < end && start < otherEnd
            }
            return other.day == block.day && other.startMinute < block.endMinute && block.startMinute < other.endMinute
        }
    }
    func removeBlock(_ id: UUID) {
        guard canSave else { return }
        blockUndo = (state.blocks, state.entries)
        state.blocks.removeAll { $0.id == id }; blockError = nil; save()
    }
    func undoBlock() {
        guard canSave, let blockUndo else { return }
        state.blocks = blockUndo.blocks; state.entries = blockUndo.entries
        self.blockUndo = nil; blockError = nil; save()
    }
    func save() {
        guard canSave else { return }
        do { try JSONEncoder().encode(state).write(to: fileURL, options: .atomic); storageError = nil }
        catch { storageError = "The plan could not be saved. Check the storage location and try again." }
    }
}
