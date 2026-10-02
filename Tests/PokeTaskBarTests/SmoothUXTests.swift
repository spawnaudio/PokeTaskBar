import AppKit
import SwiftUI
import XCTest
@testable import PokeTaskBar

@MainActor
final class SmoothUXTests: XCTestCase {
    func testDailyActivityCountsSessionsOnceAcrossPausesMidnightAndDST() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "America/New_York"))
        func date(_ day: Int, _ hour: Int, _ minute: Int) throws -> Date {
            try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 3,
                day: day, hour: hour, minute: minute)))
        }
        let start = try date(7, 23, 30)
        let end = try date(8, 3, 30)
        var record = TaskSessionRecord(id: "one", issueID: "task", identifier: "PKT-1", title: "Task",
            segments: [.init(start: start, end: end), .init(start: try date(8, 5, 0), end: try date(8, 5, 10))],
            activeSeconds: 11400, plannedSeconds: 11400, finishedAt: try date(8, 5, 10),
            finish: .leftInProgress, xp: 0, partial: false)
        var repeatSession = record; repeatSession.id = "two"
        var partial = record; partial.id = "legacy"; partial.partial = true
        var empty = record; empty.id = "empty"; empty.segments = [.init(start: start, end: start)]
        let records = [record, repeatSession, partial, empty]
        let activity = TaskTimeReport.activityByDay(records, calendar: calendar)
        XCTAssertEqual(activity.count, 2)
        XCTAssertEqual(activity["2026-03-07"]?.seconds, 3600)
        XCTAssertEqual(activity["2026-03-08"]?.seconds, 19200)
        XCTAssertEqual(activity["2026-03-07"]?.sessions, 2)
        XCTAssertEqual(activity["2026-03-08"]?.sessions, 2, "Resuming on the same day must not count a new session")
        for day in 7...8 {
            let from = try date(day, 0, 0)
            let until = try XCTUnwrap(calendar.date(byAdding: .day, value: 1, to: from))
            let key = TaskPlanningStore.dayKey(from, calendar: calendar)
            XCTAssertEqual(activity[key]?.seconds, TaskTimeReport.seconds(records, from: from, until: until))
            XCTAssertEqual(activity[key]?.sessions, records.filter {
                TaskTimeReport.seconds([$0], from: from, until: until) > 0
            }.count)
        }
        record.segments = []
        XCTAssertTrue(TaskTimeReport.activityByDay([record, partial, empty], calendar: calendar).isEmpty)
    }

    func testPlannerMountsOnlyVisibleTaskCards() async throws {
        try XCTSkipIf(NSScreen.screens.isEmpty, "Requires the macOS display server")
        for planned in [false, true] {
            let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let suite = "SmoothUXTests-\(UUID())"
            let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
            defer {
                defaults.removePersistentDomain(forName: suite)
                try? FileManager.default.removeItem(at: directory)
            }
            defaults.set(true, forKey: "linearIntegrationEnabled")
            let count = 300
            let issues: [[String: Any]] = (0..<count).map {
                ["id": "task-\($0)", "identifier": "PKT-\($0)", "title": "Task \($0)",
                 "state": ["id": "todo", "name": "Todo", "type": "unstarted"]]
            }
            let payload = try JSONSerialization.data(withJSONObject: ["data": [
                "inProgress": ["nodes": []], "planned": ["nodes": []], "todo": ["nodes": issues],
                "completedRecent": ["nodes": []], "projects": ["nodes": []],
                "projectStatuses": ["nodes": []], "initiatives": ["nodes": []]]])
            let keys = LinearAPIKeyStore(fileURL: directory.appendingPathComponent("key.json"))
            try keys.save(.init(key: "lin_api_test_not_a_real_key"))
            let usage = UsageStore(providers: [], autoRefresh: false, defaults: defaults,
                linearClient: LinearClient(http: SmoothHTTP(payload: payload)), linearAPIKeys: keys)
            _ = await usage.refreshLinearIssues()
            XCTAssertEqual(usage.linearTodoIssues.count, count)
            if planned {
                let entries: [[String: Any]] = (0..<count).map {
                    ["id": "task-\($0)", "group": "today", "day": TaskPlanningStore.dayKey(Date()), "order": $0]
                }
                let state = try JSONSerialization.data(withJSONObject: ["entries": entries,
                    "blocks": [], "folded": [], "linked": false, "sort": "manual"])
                try state.write(to: directory.appendingPathComponent("task-planning.json"))
            }
            let companion = CompanionStore(provider: StubProvider(value: EvoLine(baseID: 1,
                tree: EvoNode(speciesID: 1, children: []), rarity: .common, names: [:])),
                fileURL: directory.appendingPathComponent("companion.json"), defaults: defaults)
            let focus = FocusSessionStore(usage: usage, companion: companion,
                fileURL: directory.appendingPathComponent("focus.json"), ticksOnTimer: false)
            let nav = MainWindowNavigation()
            let host = NSHostingView(rootView: TaskPlanningView()
                .environment(usage).environment(companion).environment(focus)
                .environment(nav))
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 600, height: 720),
                styleMask: [.titled], backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false
            window.contentView = host
            window.orderFrontRegardless()
            defer { window.orderOut(nil); window.contentView = nil }
            try await Task.sleep(for: .milliseconds(250))
            host.layoutSubtreeIfNeeded()
            let mounted = descendants(host).compactMap { $0 as? LinearIssueDragView }
            print("Planner \(planned ? "planned" : "tray"): \(mounted.count)/\(count) task cards mounted")
            XCTAssertFalse(mounted.isEmpty, "Visible task controls must still mount")
            XCTAssertLessThan(mounted.count, count / 3, "Off-screen cards must stay unmounted, including inside groups")
            let first = try XCTUnwrap(mounted.first)
            first.onClick()
            XCTAssertEqual(nav.issueExpansion[first.issueID], true, "Card state must survive leaving the lazy viewport")
            let scroll = try XCTUnwrap(descendants(host).compactMap { $0 as? NSScrollView }.first)
            let document = try XCTUnwrap(scroll.documentView)
            for _ in 0..<5 {
                scroll.contentView.scroll(to: NSPoint(x: 0, y: document.bounds.height - scroll.contentView.bounds.height))
                scroll.reflectScrolledClipView(scroll.contentView)
                try await Task.sleep(for: .milliseconds(100))
                host.layoutSubtreeIfNeeded()
            }
            let tail = descendants(host).compactMap { $0 as? LinearIssueDragView }
            let lastID = planned ? "task-299" : try XCTUnwrap(usage.linearTodoIssues.last).id
            XCTAssertTrue(tail.contains { $0.issueID == lastID }, "Scrolling must mount the final task")
            XCTAssertLessThan(tail.count, count / 3)
            scroll.contentView.scroll(to: .zero)
            scroll.reflectScrolledClipView(scroll.contentView)
            try await Task.sleep(for: .milliseconds(250))
            host.layoutSubtreeIfNeeded()
            let restored = try XCTUnwrap(descendants(host).compactMap { $0 as? LinearIssueDragView }
                .first { $0.issueID == first.issueID })
            XCTAssertEqual(restored.accessibilityValue() as? String, "Expanded")
        }
    }

    private func descendants(_ view: NSView) -> [NSView] {
        view.subviews.flatMap { [$0] + descendants($0) }
    }
}

private struct SmoothHTTP: LinearHTTPClient {
    let payload: Data
    func postGraphQL(apiKey: String, body: Data) async throws -> (status: Int, data: Data) {
        (200, payload)
    }
}
