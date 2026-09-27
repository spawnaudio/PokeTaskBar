import AppKit
import SwiftUI
import XCTest
@testable import PokeTaskBar

@MainActor
final class LinearProjectCardTests: XCTestCase {
    private final class HTTP: LinearHTTPClient, @unchecked Sendable {
        var responses: [Data]
        var bodies: [Data] = []
        init(_ responses: [Data]) { self.responses = responses }
        func postGraphQL(apiKey: String, body: Data) async throws -> (status: Int, data: Data) {
            bodies.append(body)
            guard !responses.isEmpty else { throw URLError(.notConnectedToInternet) }
            return (200, responses.removeFirst())
        }
    }

    private func data(_ value: [String: Any]) throws -> Data {
        let payload = ["inProgress": ["nodes": []], "completedRecent": ["nodes": []]]
            .merging(value) { _, new in new }
        return try JSONSerialization.data(withJSONObject: ["data": payload])
    }

    private func issue(_ id: String, state: String = "Todo", type: String = "unstarted", priority: Int = 0) -> [String: Any] {
        ["id": id, "identifier": "PER-\(id)", "title": "Task \(id)", "priority": priority,
         "project": ["id": "project", "name": "Goal: Stick to a Routine"],
         "state": ["id": state, "name": state, "type": type, "color": "#4cb782"]]
    }

    private func projectNode() -> [String: Any] {
        ["id": "project", "identifier": "P-PER-61", "name": "Goal: Stick to a Routine",
         "url": "https://linear.app/example/project/routine",
         "icon": "Calendar", "color": "#4cb782", "health": "onTrack", "priority": 2,
         "description": "Establish the beginning of a consistent, sustainable routine that supports healthier habits, better sleep, and more time to focus.",
         "status": ["name": "In Progress", "type": "started", "color": "#F2C94C"],
         "lead": ["name": "Alex Brown"], "startDate": "2026-09-14", "targetDate": "2026-10-31",
         "targetDateResolution": "month", "currentProgress": ["scopeCount": 32],
         "teams": ["nodes": [["id": "team", "name": "Personal", "key": "PER", "icon": "Terminal", "color": "#26b5ce"]]],
         "initiatives": ["nodes": [["id": "rhythm", "name": "Build a Sustainable Personal Operating Rhythm", "icon": "Refresh", "color": "#26b5ce"],
                                    ["id": "goals", "name": "Goals & Habits"], ["id": "dashboard", "name": "Dashboard"]]],
         "labels": ["nodes": [["id": "goals", "name": "Goals & Routines", "color": "#4cb782"],
                               ["id": "personal", "name": "Personal", "color": "#26b5ce"]]],
         "projectMilestones": ["nodes": [["id": "milestone", "name": "Define the routines", "targetDate": "2026-09-21", "status": "overdue"]]],
         "needs": ["nodes": [["customer": ["id": "customer", "name": "[SPAWN] Audio"]],
                               ["customer": ["id": "customer", "name": "[SPAWN] Audio"]]]],
         "issues": ["nodes": [issue("1", state: "Planned"), issue("2"),
                              issue("3", state: "In Progress", type: "started")]]]
    }

    func testMetadataUsesRealValuesAndSeparateQueryPreservesIssues() async throws {
        let http = HTTP([try data(["inProgress": ["nodes": []], "completedRecent": ["nodes": []]]),
                         try data(["projects": ["nodes": [projectNode()]]]),
                         try data(["projects": ["nodes": [projectNode()]]])])
        let result = try await LinearClient(http: http).fetchIssueDashboard(apiKey: "fixture", completedSince: Date())
        let project = try XCTUnwrap(result.projects.first)
        XCTAssertEqual(project.identifier, "P-PER-61")
        XCTAssertEqual(project.icon, "Calendar")
        XCTAssertEqual(project.statusColor, "#F2C94C")
        XCTAssertEqual(project.health, "onTrack")
        XCTAssertEqual(project.priority, 2)
        XCTAssertEqual(project.teams.first?.name, "PER")
        XCTAssertEqual(project.initiatives.count, 3)
        XCTAssertEqual(project.labels.first?.color, "#4cb782")
        XCTAssertEqual(project.customers.count, 1, "Repeated requests from a customer must not repeat their badge")
        XCTAssertEqual(project.milestones.first?.status, "overdue")
        XCTAssertEqual(project.targetDateResolution, "month")
        XCTAssertEqual(project.issueCount, 32)
        XCTAssertEqual(project.issues.count, 3)
        let query = try XCTUnwrap((JSONSerialization.jsonObject(with: http.bodies[2]) as? [String: Any])?["query"] as? String)
        XCTAssertTrue(query.contains("ProjectCardMetadata"))
        XCTAssertTrue(query.contains("projects(first: 50"))
        XCTAssertFalse(query.contains("issues("), "Relationship metadata must not multiply nested issue complexity")
        let empty = try XCTUnwrap(LinearClient.parseIssueDashboard(data(["projects": ["nodes": [["id": "p", "name": "Empty",
            "status": ["type": "started", "name": "In Progress"]]]]])).projects.first)
        XCTAssertNil(empty.identifier); XCTAssertNil(empty.issueCount)
        XCTAssertTrue(empty.labels.isEmpty); XCTAssertTrue(empty.customers.isEmpty)
    }

    func testSectionsKeepCustomStatesSeparateAndOrderIssuesWithinEachStatus() throws {
        var nodes = [issue("low", state: "Review", type: "started", priority: 4),
                     issue("urgent", state: "Review", type: "started", priority: 1),
                     issue("active", state: "In Progress", type: "started"), issue("todo"),
                     issue("planned", state: "Planned"), issue("done", state: "Done", type: "completed"),
                     issue("cancel", state: "Canceled", type: "canceled")]
        nodes.append(["id": "unknown", "identifier": "PER-unknown", "title": "No state"])
        let issues = try nodes.map(LinearClient.parseIssueSummary)
        let groups = LinearIssueStatusSection.sections(issues)
        XCTAssertEqual(groups.map(\.state.name), ["Planned", "Todo", "In Progress", "Review", "Done", "Canceled", ""])
        XCTAssertEqual(groups.first { $0.state.name == "Review" }?.issues.map(\.id), ["urgent", "low"])
        XCTAssertEqual(groups.flatMap(\.issues).count, nodes.count)
        XCTAssertTrue(LinearIssueStatusSection.sections([]).isEmpty)
        var otherTeam = issues[0]; otherTeam.id = "other"; otherTeam.stateId = "other-review"; otherTeam.teamKey = "ENG"
        XCTAssertEqual(LinearIssueStatusSection.sections([issues[0], otherTeam]).count, 2)
    }

    func testProjectIssuePaginationIncludesClosedWorkAndRejectsPartialResults() async throws {
        func page(_ nodes: [[String: Any]], more: Bool, cursor: String) throws -> Data {
            try data(["project": ["issues": ["nodes": nodes, "pageInfo": ["hasNextPage": more, "endCursor": cursor]]]])
        }
        let first = try page([issue("todo")], more: true, cursor: "next")
        let last = try page([issue("done", state: "Done", type: "completed"),
                             issue("cancel", state: "Canceled", type: "canceled"), issue("todo")], more: false, cursor: "end")
        let http = HTTP([first, last])
        let values = try await LinearClient(http: http).fetchProjectIssues(apiKey: "fixture", projectID: "project")
        XCTAssertEqual(Set(values.map(\.id)), ["todo", "done", "cancel"])
        let body = try XCTUnwrap(JSONSerialization.jsonObject(with: http.bodies[1]) as? [String: Any])
        XCTAssertEqual((body["variables"] as? [String: String])?["after"], "next")
        XCTAssertFalse((body["query"] as? String ?? "").contains("nin:"))
        for responses in [[first], [first, first]] {
            do {
                _ = try await LinearClient(http: HTTP(responses)).fetchProjectIssues(apiKey: "fixture", projectID: "project")
                XCTFail("Failed or repeated pages must not be accepted as a complete issue list")
            } catch { }
        }
    }

    func testProjectDatesKeepDayAndMonthQuarterResolution() throws {
        let date = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-10-31T00:00:00Z"))
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "America/Los_Angeles"))
        let locale = Locale(identifier: "en_US")
        XCTAssertEqual(LinearProjectCardDate.text(date, locale: locale, calendar: calendar), "Oct 31")
        XCTAssertEqual(LinearProjectCardDate.text(date, resolution: "month", locale: locale, calendar: calendar), "Oct 2026")
        XCTAssertEqual(LinearProjectCardDate.text(date, resolution: "quarter", locale: locale, calendar: calendar), "Q4 2026")
        XCTAssertEqual(LinearProjectCardDate.text(date, resolution: "halfYear", locale: locale, calendar: calendar), "H2 2026")
        XCTAssertEqual(LinearProjectCardDate.text(date, resolution: "year", locale: locale, calendar: calendar), "2026")
    }

    func testLoadedProjectMovesIssuesBetweenSectionsWhenRefreshFails() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let suite = "ProjectCardStore-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite); try? FileManager.default.removeItem(at: directory) }
        defaults.set(true, forKey: "linearIntegrationEnabled")
        let keys = LinearAPIKeyStore(fileURL: directory.appendingPathComponent("key.json"))
        try keys.save(.init(key: "lin_api_fixture"))
        let http = HTTP([try data([:]), try data(["projects": ["nodes": [projectNode()]]]),
                         try data(["projects": ["nodes": [projectNode()]]]), try data(["projects": ["nodes": []]])])
        let store = UsageStore(providers: [], autoRefresh: false, defaults: defaults,
                               linearClient: LinearClient(http: http), linearAPIKeys: keys)
        _ = await store.refreshLinearIssues()
        XCTAssertFalse(try XCTUnwrap(store.linearProjects.first).issuesFullyLoaded)
        do { try await store.loadLinearProjectIssues(projectID: "project"); XCTFail("An offline load should fail") }
        catch { }
        XCTAssertEqual(store.linearProjects.first?.issues.count, 3, "A failed full fetch must preserve the preview")
        http.responses = [try data(["project": ["issues": ["nodes": [issue("1"), issue("2", state: "Done", type: "completed")],
                                                                          "pageInfo": ["hasNextPage": false]]]])]
        try await store.loadLinearProjectIssues(projectID: "project")
        XCTAssertTrue(try XCTUnwrap(store.linearProjects.first).issuesFullyLoaded)
        for (name, type) in [("Done", "completed"), ("Review", "started"), ("Canceled", "canceled")] {
            http.responses = [try data(["issueUpdate": ["success": true, "issue": issue("1", state: name, type: type)]])]
            _ = await store.updateLinearIssueState(try XCTUnwrap(store.linearIssue(id: "1")), stateID: name)
            let project = try XCTUnwrap(store.linearProjects.first)
            XCTAssertEqual(project.issues.count, 2, "Completed/canceled work must remain in a fully loaded project")
            let sections = LinearIssueStatusSection.sections(project.issues)
            XCTAssertTrue(try XCTUnwrap(sections.first { $0.state.name == name }).issues.contains { $0.id == "1" })
        }
        store.clearLinearAPIKey()
        XCTAssertTrue(store.linearProjects.isEmpty)
    }

    func testRenderAndClickProjectCards() async throws {
        guard let path = ProcessInfo.processInfo.environment["PTB_PROJECT_CARD_PREVIEW_DIR"] else {
            throw XCTSkip("Set PTB_PROJECT_CARD_PREVIEW_DIR for native card verification")
        }
        try XCTSkipIf(NSScreen.screens.isEmpty, "Requires the macOS display server")
        let directory = URL(fileURLWithPath: path)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let suite = "LinearProjectCardTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        let stateDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(suite)
        try FileManager.default.createDirectory(at: stateDirectory, withIntermediateDirectories: true)
        defer { defaults.removePersistentDomain(forName: suite); try? FileManager.default.removeItem(at: stateDirectory) }
        var state = CompanionState(); state.language = .en
        let file = stateDirectory.appendingPathComponent("companion.json")
        try JSONEncoder().encode(state).write(to: file)
        let companion = CompanionStore(provider: StubProvider(value: EvoLine(baseID: 1,
            tree: EvoNode(speciesID: 1, children: []), rarity: .common, names: [:])), fileURL: file, defaults: defaults)
        let usage = UsageStore(providers: [], autoRefresh: false, defaults: defaults,
            linearAPIKeys: LinearAPIKeyStore(fileURL: stateDirectory.appendingPathComponent("key.json")))
        let focus = FocusSessionStore(usage: usage, companion: companion,
            fileURL: stateDirectory.appendingPathComponent("focus.json"), ticksOnTimer: false)
        var project = try XCTUnwrap(LinearClient.parseIssueDashboard(data(["projects": ["nodes": [projectNode()]]])).projects.first)
        project.issues += try [issue("4", state: "Review", type: "started"), issue("5", state: "Done", type: "completed")].map(LinearClient.parseIssueSummary)
        project.issuesFullyLoaded = true
        for scheme in [ColorScheme.light, .dark] {
            for width: CGFloat in [240, 350, 620] {
                func content(hiding hidden: Set<String> = []) -> some View {
                    LinearProjectCard(project: project, hiddenIssueStatuses: hidden, onPin: {})
                    .padding(10).frame(width: width)
                    .background(scheme == .light ? Color(white: 0.97) : Color(white: 0.12))
                    .environment(usage).environment(companion).environment(focus)
                    .environment(\.colorScheme, scheme).defaultAppStorage(defaults)
                }
                let host = NSHostingView(rootView: content())
                let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: width, height: 500),
                                      styleMask: .borderless, backing: .buffered, defer: false)
                window.isReleasedWhenClosed = false
                window.appearance = NSAppearance(named: scheme == .light ? .aqua : .darkAqua)
                window.contentView = host; window.orderFrontRegardless()
                defer { window.orderOut(nil); window.contentView = nil }
                try await Task.sleep(for: .milliseconds(150))
                host.setFrameSize(host.fittingSize); host.layoutSubtreeIfNeeded()
                let collapsed = host.fittingSize.height
                XCTAssertEqual(host.fittingSize.width, width, accuracy: 1)
                XCTAssertGreaterThan(collapsed, 220); XCTAssertLessThan(collapsed, 390)
                try capture(host, to: directory.appendingPathComponent("project-\(scheme)-\(Int(width)).png"))
                let point = host.convert(NSPoint(x: width / 2, y: host.isFlipped ? 85 : host.bounds.height - 85), to: nil)
                func click() throws {
                    for type in [NSEvent.EventType.leftMouseDown, .leftMouseUp] {
                        window.sendEvent(try XCTUnwrap(NSEvent.mouseEvent(with: type, location: point,
                            modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime,
                            windowNumber: window.windowNumber, context: nil, eventNumber: 1, clickCount: 1, pressure: 1)))
                    }
                }
                try click()
                try await Task.sleep(for: .milliseconds(250))
                XCTAssertGreaterThan(host.fittingSize.height, collapsed + 300, "Card body click must reveal status sections and issues")
                host.setFrameSize(host.fittingSize); host.layoutSubtreeIfNeeded()
                try capture(host, to: directory.appendingPathComponent("project-expanded-\(scheme)-\(Int(width)).png"))
                let expandedHeight = host.fittingSize.height
                host.rootView = content(hiding: ["completed:done", "unstarted:todo"])
                try await Task.sleep(for: .milliseconds(100))
                XCTAssertLessThan(host.fittingSize.height, expandedHeight - 100,
                                  "Filtering must remove hidden status sections from an already expanded card")
                XCTAssertGreaterThan(host.fittingSize.height, collapsed + 100)
                host.setFrameSize(host.fittingSize); host.layoutSubtreeIfNeeded()
                try capture(host, to: directory.appendingPathComponent("project-filtered-\(scheme)-\(Int(width)).png"))
                host.rootView = content(hiding: Set(LinearProjectIssueFilter.options([project]).map(\.id)))
                try await Task.sleep(for: .milliseconds(100))
                XCTAssertLessThan(host.fittingSize.height, collapsed + 120, "All hidden statuses must show the filtered empty state")
                host.rootView = content()
                try await Task.sleep(for: .milliseconds(100))
                host.setFrameSize(host.fittingSize); host.layoutSubtreeIfNeeded()
                // Recalculate the window coordinate after expansion changes the hosting view's height.
                let collapsePoint = host.convert(NSPoint(x: width / 2, y: host.isFlipped ? 85 : host.bounds.height - 85), to: nil)
                for type in [NSEvent.EventType.leftMouseDown, .leftMouseUp] {
                    window.sendEvent(try XCTUnwrap(NSEvent.mouseEvent(with: type, location: collapsePoint,
                        modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime,
                        windowNumber: window.windowNumber, context: nil, eventNumber: 1, clickCount: 1, pressure: 1)))
                }
                try await Task.sleep(for: .milliseconds(200))
                XCTAssertEqual(host.fittingSize.height, collapsed, accuracy: 1)
                XCTAssertNil(focus.session, "Expanding or collapsing a project must not start a timer")
            }
        }
    }

    private func capture(_ host: NSView, to url: URL) throws {
        let bitmap = try XCTUnwrap(host.bitmapImageRepForCachingDisplay(in: host.bounds))
        host.cacheDisplay(in: host.bounds, to: bitmap)
        try XCTUnwrap(bitmap.representation(using: .png, properties: [:])).write(to: url)
    }
}
