import Foundation
import XCTest
@testable import PokeTaskBar

@MainActor
final class PokeTasksV2Tests: XCTestCase {
    private func issue(_ id: String = "task") -> LinearIssueSummary {
        var issue = FocusPinnedIssue.pomodoro(title: "Ship \"v2\", calmly").summary
        issue.id = id; issue.identifier = "PKT-42"; issue.stateId = "todo"
        issue.stateName = "Todo"; issue.stateType = "unstarted"
        issue.projectID = "project"; issue.projectName = "PokeTasks"
        issue.priority = 2; issue.dueDate = Date(timeIntervalSince1970: 1_800_000_000)
        issue.teamStates = [
            .init(id: "today", name: "In Progress", type: "started", position: 0),
            .init(id: "soon", name: "Planned", type: "unstarted", position: 1),
            .init(id: "todo", name: "Todo", type: "unstarted", position: 2)]
        return issue
    }

    func testPersonalMovesFoldReorderAndRelaunchNeverWriteStatus() async throws {
        let f = try Fixture(); defer { f.remove() }
        let plan = f.focus.plan
        var calls = 0
        let update: (LinearIssueSummary, String) async -> Bool = { _, _ in calls += 1; return true }
        await plan.move(issue(), to: .today, usage: f.usage, update: update)
        await plan.move(issue("other"), to: .today, usage: f.usage, update: update)
        plan.reorder("other", before: "task")
        XCTAssertLessThan(try XCTUnwrap(plan.entry("other")).order, try XCTUnwrap(plan.entry("task")).order)
        plan.fold(.soon); plan.fold(.later)
        plan.sort = .title
        await plan.move(issue(), to: .soon, usage: f.usage, update: update)
        XCTAssertNil(plan.entry("task")?.day)
        await plan.undo(usage: f.usage, update: update)
        XCTAssertEqual(plan.entry("task")?.group, .today)
        XCTAssertEqual(calls, 0)
        XCTAssertEqual(issue().priority, 2)
        let restored = TaskPlanningStore(fileURL: f.directory.appendingPathComponent("task-planning.json"), clock: { f.now })
        XCTAssertEqual(restored.entries.count, 2)
        XCTAssertEqual(restored.folded, [.soon, .later])
        XCTAssertEqual(restored.sort, .title)
        XCTAssertFalse(restored.linked)
        restored.foldAll(true); XCTAssertEqual(restored.folded.count, 3)
        restored.foldAll(false); XCTAssertTrue(restored.folded.isEmpty)
        restored.fold(.today); restored.fold(.today); XCTAssertTrue(restored.folded.isEmpty)
    }

    func testIssueTrayMatchesExistingStatusSemantics() {
        var task = issue()
        XCTAssertEqual(PlanningGroup.allCases.filter { $0.matchesStatus(task) }, [.later])
        task.stateName = "PLANNED"
        XCTAssertEqual(PlanningGroup.allCases.filter { $0.matchesStatus(task) }, [.soon])
        task.stateName = "In Progress"; task.stateType = "started"
        XCTAssertEqual(PlanningGroup.allCases.filter { $0.matchesStatus(task) }, [.today])
        task.stateName = "Backlog"; task.stateType = "backlog"
        XCTAssertTrue(PlanningGroup.allCases.filter { $0.matchesStatus(task) }.isEmpty)
        task.stateName = "Planned"; task.stateType = "completed"
        XCTAssertTrue(PlanningGroup.allCases.filter { $0.matchesStatus(task) }.isEmpty)
    }

    func testLinkedMovesFailureRetryUndoMissingMappingsAndClosedIssues() async throws {
        let f = try Fixture(); defer { f.remove() }
        let plan = f.focus.plan
        var targets: [String] = []
        let ok: (LinearIssueSummary, String) async -> Bool = { _, id in targets.append(id); return true }
        plan.linked = true
        plan.foldAll(true)
        _ = plan.schedule(issue(), start: 600, duration: 25)
        XCTAssertTrue(targets.isEmpty, "Enabling, folding and scheduling do not sync statuses")
        await plan.move(issue(), to: .soon, usage: f.usage, update: { _, id in targets.append(id); return false })
        XCTAssertEqual(plan.entry("task")?.group, .soon)
        XCTAssertTrue(plan.canRetry); XCTAssertNotNil(plan.syncError)
        await plan.retry(usage: f.usage, update: ok)
        XCTAssertFalse(plan.canRetry); XCTAssertNil(plan.syncError)
        await plan.undo(usage: f.usage, update: ok)
        XCTAssertEqual(plan.entry("task")?.group, .today)
        XCTAssertEqual(targets, ["soon", "soon"]) // Original status already was Todo.
        var missing = issue("missing"); missing.teamStates.removeLast()
        await plan.move(missing, to: .today, usage: f.usage, update: ok)
        XCTAssertEqual(plan.entry("missing")?.group, .today)
        XCTAssertNotNil(plan.syncError); XCTAssertFalse(plan.canRetry)
        var closed = issue("closed"); closed.stateType = "completed"
        await plan.move(closed, to: .today, usage: f.usage, update: ok)
        XCTAssertNil(plan.entry("closed")); XCTAssertNil(plan.schedule(closed, start: 800))
        var ambiguous = issue(); ambiguous.teamStates.append(ambiguous.teamStates[0])
        XCTAssertNil(TaskPlanningStore.stateID(for: .today, issue: ambiguous))
    }

    func testBlockSnappingConflictUndoAndPersistence() throws {
        let f = try Fixture(); defer { f.remove() }
        let plan = f.focus.plan
        let block = try XCTUnwrap(plan.schedule(issue(), start: 603, duration: 32))
        XCTAssertEqual(block.startMinute, 605); XCTAssertEqual(block.durationMinutes, 30)
        XCTAssertEqual(block.endAt?.timeIntervalSince(try XCTUnwrap(block.startAt)), 1800)
        XCTAssertNil(plan.schedule(issue("other"), start: 610, duration: 25))
        XCTAssertNotNil(plan.blockError); XCTAssertEqual(plan.blocks.count, 1)
        XCTAssertTrue(plan.edit(block, start: 700, duration: 50))
        XCTAssertEqual(plan.blocks.first?.startMinute, 700)
        plan.undoBlock(); XCTAssertEqual(plan.blocks.first, block)
        XCTAssertFalse(plan.edit(block, start: 600, duration: 25, day: "invalid-day"))
        XCTAssertEqual(plan.blocks.first, block, "Invalid persisted/edit dates cannot reuse stale instants")
        plan.removeBlock(block.id); XCTAssertTrue(plan.blocks.isEmpty)
        plan.undoBlock(); XCTAssertEqual(plan.blocks.first, block)
        let adjacent = try XCTUnwrap(plan.schedule(issue("other"), start: 635, duration: 25))
        XCTAssertFalse(plan.edit(adjacent, start: 610, duration: 25))
        XCTAssertTrue(plan.edit(adjacent, start: 600, duration: 25, day: "2026-10-05"))
        XCTAssertEqual(plan.blocks.last?.day, "2026-10-05", "Keyboard date editing reschedules the same block")
        plan.undoBlock(); XCTAssertEqual(plan.blocks.last, adjacent)
        plan.undoBlock(); XCTAssertEqual(plan.blocks.count, 2) // No second undo.
        plan.removeBlock(adjacent.id); XCTAssertEqual(plan.blocks.count, 1)
        let restored = TaskPlanningStore(fileURL: f.directory.appendingPathComponent("task-planning.json"))
        XCTAssertEqual(restored.blocks, [block])
        var edge = block; edge.set(start: Int.max, duration: Int.max)
        XCTAssertEqual(edge.endMinute, 1440); XCTAssertEqual(edge.durationMinutes, 180)
        XCTAssertEqual(TaskTimeBlock.snapped(.infinity), 0)
    }

    func testCompleteLedgerKeepsRepeatedSessionsPauseSleepAndRestoresPaused() throws {
        let f = try Fixture(); defer { f.remove() }
        f.focus.pin(issue(), openDesk: false, minutes: 25)
        f.advance(60); f.focus.togglePause()
        f.advance(600); f.focus.tick()
        f.focus.togglePause()
        f.advance(60); f.focus.setDisplayAwake(false)
        f.advance(600); f.focus.tick()
        f.focus.setDisplayAwake(true)
        f.advance(60); f.focus.finishLeavingInProgress()
        XCTAssertEqual(f.focus.sessionRecords.first?.activeSeconds, 180)
        f.focus.pin(issue(), openDesk: false, minutes: 25)
        f.advance(120); f.focus.tick()
        let resumed = f.reload()
        XCTAssertTrue(resumed.session?.userPaused == true)
        f.advance(3600); resumed.tick()
        resumed.togglePause(); f.advance(60); resumed.finishLeavingInProgress()
        XCTAssertEqual(resumed.sessionRecords.count, 2)
        XCTAssertEqual(resumed.sessionRecords.last?.activeSeconds, 180)
        XCTAssertNotEqual(resumed.sessionRecords[0].id, resumed.sessionRecords[1].id)
        XCTAssertEqual(resumed.issueHistory.count, 1, "Keep existing latest-session summary behavior")
        let final = f.reload()
        XCTAssertEqual(final.sessionRecords.count, 2)
        XCTAssertEqual(final.sessionRecords.reduce(0) { $0 + $1.activeSeconds }, 360)
        XCTAssertEqual(final.sessionRecords.first?.projectName, "PokeTasks")
        final.pin(issue(), openDesk: false, minutes: 25)
        f.advance(0.375); final.finishLeavingInProgress()
        XCTAssertEqual(f.reload().sessionRecords.last?.segments.first?.seconds, 0.375)
    }

    func testResetZeroWaitAndForfeitPreserveMeasuredTimeWithoutExtraRewards() async throws {
        let f = try Fixture(); defer { f.remove() }
        f.focus.pin(issue(), openDesk: false, minutes: 5)
        f.advance(120); f.focus.requestReset(); f.focus.confirmReset()
        f.advance(400); f.focus.tick()
        XCTAssertEqual(f.focus.session?.phase, .awaitingChoice)
        f.advance(900); f.focus.finishLeavingInProgress()
        XCTAssertEqual(f.focus.sessionRecords.first?.activeSeconds, 420, "Reset keeps measured work; time past zero is excluded")
        f.focus.pin(issue(), openDesk: false, minutes: 25)
        f.advance(65)
        f.focus.pin(issue("next"), openDesk: false, minutes: 50)
        XCTAssertNotNil(f.focus.forfeitPrompt)
        await f.focus.confirmForfeit()
        XCTAssertEqual(f.focus.sessionRecords.last?.activeSeconds, 65)
        XCTAssertEqual(f.focus.sessionRecords.last?.finish, .forfeited)
        XCTAssertEqual(f.focus.session?.issue.id, "next")
    }

    func testDailySplitDSTCoverageAndCSV() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "America/New_York"))
        let start = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 3, day: 7, hour: 23, minute: 30)))
        let end = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 3, day: 8, hour: 3, minute: 30)))
        var block = TaskTimeBlock(issueID: "task", identifier: "PKT-42", title: "A", day: "2026-03-08",
            startMinute: 90, durationMinutes: 120, timeZoneID: "America/New_York")
        block.set(start: 90, duration: 120)
        XCTAssertEqual(try XCTUnwrap(block.endAt).timeIntervalSince(try XCTUnwrap(block.startAt)), 7200)
        XCTAssertEqual(block.timeRange, "01:30 – 04:30")
        var nonexistent = block; nonexistent.set(start: 150, duration: 30)
        XCTAssertNil(nonexistent.startAt, "Reject a nonexistent spring-forward wall time")
        let record = TaskSessionRecord(id: "id", issueID: "task", identifier: "PKT-42",
            title: "Ship \"v2\", calmly\nnow", projectID: "p", projectName: "P", blockID: block.id,
            segments: [.init(start: start, end: end)], activeSeconds: end.timeIntervalSince(start),
            plannedSeconds: 7200, finishedAt: end, finish: .leftInProgress, xp: 0, partial: false)
        let split = TaskTimeReport.secondsByDay([record], calendar: calendar)
        XCTAssertEqual(split["2026-03-07"], 1800)
        XCTAssertEqual(split["2026-03-08"], 9000, "Spring-forward hour is not invented")
        XCTAssertEqual(TaskTimeReport.seconds([record], from: start, until: end), 10800)
        XCTAssertEqual(TaskTimeReport.planCoverage(records: [record], blocks: [block]), 1)
        XCTAssertNil(TaskTimeReport.planCoverage(records: [record], blocks: []))
        XCTAssertTrue(TaskTimeReport.csv([record]).contains("\"Ship \"\"v2\"\", calmly\nnow\""))
        XCTAssertTrue(TaskTimeReport.csv([record]).contains("finished_at_utc,timezone,partial"))
    }

    func testLegacyHistoryIsPartialAndUnreadableFilesArePreserved() async throws {
        let f = try Fixture(); defer { f.remove() }
        f.focus.pin(issue(), openDesk: false, minutes: 25)
        f.advance(60); f.focus.finishLeavingInProgress()
        let file = f.directory.appendingPathComponent("focus.json")
        var legacy = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: file)) as? [String: Any])
        legacy.removeValue(forKey: "sessionRecords"); legacy.removeValue(forKey: "trackingBeganAt")
        try JSONSerialization.data(withJSONObject: legacy).write(to: file)
        let imported = f.reload()
        XCTAssertEqual(imported.sessionRecords.count, 1)
        XCTAssertTrue(imported.sessionRecords[0].partial)
        XCTAssertTrue(TaskTimeReport.secondsByDay(imported.sessionRecords).isEmpty)
        imported.startPomodoro()
        f.advance(120); imported.tick()
        var activeLegacy = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: file)) as? [String: Any])
        var active = try XCTUnwrap(activeLegacy["session"] as? [String: Any])
        active.removeValue(forKey: "activeSegments"); active.removeValue(forKey: "recordID")
        activeLegacy["session"] = active
        try JSONSerialization.data(withJSONObject: activeLegacy).write(to: file)
        let adopted = f.reload()
        XCTAssertTrue(adopted.session?.userPaused == true)
        adopted.togglePause(); f.advance(60); adopted.finishLeavingInProgress()
        XCTAssertEqual(adopted.sessionRecords.last?.activeSeconds, 60, "A resumed legacy timer measures only work after v2 adoption")
        XCTAssertFalse(try XCTUnwrap(adopted.sessionRecords.last).partial)
        XCTAssertEqual(adopted.issueHistory.first?.durationSeconds, 180, "The legacy clock summary remains intact")
        let corrupt = Data("unfinished json".utf8)
        try corrupt.write(to: file)
        let unreadable = f.reload()
        XCTAssertNotNil(unreadable.storageError)
        unreadable.startPomodoro()
        XCTAssertEqual(try Data(contentsOf: file), corrupt)
        let planURL = f.directory.appendingPathComponent("corrupt-plan.json")
        try corrupt.write(to: planURL)
        let plan = TaskPlanningStore(fileURL: planURL)
        plan.foldAll(true)
        XCTAssertNotNil(plan.storageError); XCTAssertEqual(try Data(contentsOf: planURL), corrupt)
        let unsavable = TaskPlanningStore(fileURL: f.directory.appendingPathComponent("missing-parent/plan.json"))
        unsavable.linked = true
        var mutations = 0
        await unsavable.move(issue(), to: .today, usage: f.usage, update: { _, _ in mutations += 1; return true })
        XCTAssertNotNil(unsavable.storageError)
        XCTAssertEqual(mutations, 0, "A failed local save must not mutate Linear")
    }

    func testNavigationHidesInitiativesAndRailPreservesWidths() {
        XCTAssertFalse(MainWindowPage.visiblePages.contains(.initiatives))
        let nav = MainWindowNavigation(); nav.select(.initiatives)
        XCTAssertEqual(nav.page, .projects)
        nav.projectExpansion["p"] = true
        nav.select(.insights); nav.back()
        XCTAssertEqual(nav.projectExpansion["p"], true)
        var layout = TodayDeskLayout.default; layout.leftCollapsed = true
        let resolved = layout.resolved(containerWidth: 836, collapsedLeftWidth: 56)
        XCTAssertEqual(resolved.leftWidth, 56)
        XCTAssertGreaterThanOrEqual(resolved.centerWidth, 360)
        XCTAssertEqual(layout.togglingLeft().leftWidth, TodayDeskMetrics.leftSidebarWidth)
    }

    @MainActor private final class Fixture {
        let directory: URL
        let suite = "PokeTasksV2Tests-\(UUID())"
        let defaults: UserDefaults
        var now = Date(timeIntervalSince1970: 1_790_858_000)
        let usage: UsageStore
        let companion: CompanionStore
        lazy var focus = reload()
        init() throws {
            directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
            usage = UsageStore(providers: [], autoRefresh: false, defaults: defaults)
            companion = CompanionStore(provider: StubProvider(value: EvoLine(baseID: 1,
                tree: EvoNode(speciesID: 1, children: []), rarity: .common, names: [:])),
                fileURL: directory.appendingPathComponent("companion.json"), defaults: defaults)
        }
        func advance(_ seconds: Double) { now = now.addingTimeInterval(seconds) }
        func reload() -> FocusSessionStore {
            FocusSessionStore(usage: usage, companion: companion, clock: { self.now },
                fileURL: directory.appendingPathComponent("focus.json"), ticksOnTimer: false)
        }
        func remove() {
            defaults.removePersistentDomain(forName: suite)
            try? FileManager.default.removeItem(at: directory)
        }
    }
}
