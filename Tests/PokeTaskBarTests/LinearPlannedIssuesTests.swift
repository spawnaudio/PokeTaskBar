import XCTest
@testable import PokeTaskBar

@MainActor
final class LinearPlannedIssuesTests: XCTestCase {
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

    private func node(_ id: String, name: String = "Planned", type: String = "unstarted",
                      priority: Int = 0, projectID: String? = "project") -> [String: Any] {
        var value: [String: Any] = ["id": id, "identifier": "ENG-\(id)", "title": id,
            "priority": priority, "state": ["id": type, "name": name, "type": type]]
        if let projectID { value["project"] = ["id": projectID, "name": "Same name"] }
        return value
    }

    private func data(_ value: [String: Any]) throws -> Data {
        try JSONSerialization.data(withJSONObject: ["data": value])
    }

    private func dashboardData() throws -> Data {
        try data([
            "completedRecent": ["nodes": []],
            "inProgress": ["nodes": [node("active", name: "In Progress", type: "started")]],
            "planned": ["nodes": [node("planned")]],
            "todo": ["nodes": [node("todo", name: "Todo")]],
        ])
    }

    private func containersData(includeTodo: Bool = false) throws -> Data {
        try data([
            "projects": ["nodes": [
                ["id": "project", "name": "Same name", "status": ["name": "In Progress", "type": "started"],
                 "issues": ["nodes": [node("active", name: "In Progress", type: "started")]
                            + (includeTodo ? [node("todo", name: "Todo")] : [])]],
                ["id": "other-project", "name": "Same name", "status": ["name": "In Progress", "type": "started"],
                 "issues": ["nodes": []]],
            ]],
            "initiatives": ["nodes": [
                ["id": "initiative", "name": "Active initiative", "status": "Active",
                 "projects": ["nodes": [["id": "project", "name": "Same name"]]]],
                ["id": "planned-initiative", "name": "Planned initiative", "status": "Planned",
                 "projects": ["nodes": [["id": "project", "name": "Same name"]]]],
            ]],
        ])
    }

    func testPlannedMatchesNamedStatusSortsAndExcludesOtherUnstartedWork() throws {
        let payload = try data([
            "completedRecent": ["nodes": []],
            "inProgress": ["nodes": [node("active", name: "In Progress", type: "started"),
                                        node("custom", type: "started")]],
            "planned": ["nodes": [node("low"), node("high", name: "PLANNED", priority: 1),
                node("todo", name: "Todo"), node("backlog", name: "Backlog", type: "backlog"),
                node("done", type: "completed"), node("canceled", type: "canceled"),
                node("cancelled", type: "cancelled"), node("custom", type: "started", priority: 2)]],
        ])
        let dashboard = try LinearClient.parseIssueDashboard(payload)
        XCTAssertEqual(dashboard.planned.map(\.id), ["high", "custom", "low"])
        XCTAssertEqual(dashboard.inProgress.map(\.id), ["active"])
        XCTAssertEqual(dashboard.planned.first?.projectID, "project")
    }

    func testTodoOnlyMatchesNamedOpenStatusAndProjectRoute() throws {
        let payload = try data([
            "completedRecent": ["nodes": []], "inProgress": ["nodes": [node("custom", name: "Todo", type: "started")]],
            "todo": ["nodes": [node("normal", name: "Todo"), node("urgent", name: "TODO", priority: 1),
                node("planned"), node("backlog", name: "Backlog", type: "backlog"),
                node("done", name: "Todo", type: "completed"), node("canceled", name: "Todo", type: "canceled"),
                node("custom", name: "Todo", type: "started", priority: 2)]],
        ])
        let dashboard = try LinearClient.parseIssueDashboard(payload)
        XCTAssertEqual(dashboard.todo.map(\.id), ["urgent", "custom", "normal"])
        XCTAssertTrue(dashboard.inProgress.isEmpty)
        let nav = MainWindowNavigation()
        nav.showProjectIssues(LinearProjectSummary(id: "project", name: "Todo only", issues: dashboard.todo))
        XCTAssertEqual(nav.issuesTab, .todo)
        XCTAssertEqual(LinearIssuesTab.completedToday.title(L(.en)), "Completed")
    }

    func testFetchIncludesPlannedIssuesBeyondContainerPreviewByStableProjectID() async throws {
        let http = HTTP([try dashboardData(), try containersData()])
        let result = try await LinearClient(http: http).fetchIssueDashboard(apiKey: "fixture", completedSince: Date())
        XCTAssertEqual(result.projects.first { $0.id == "project" }?.issues.map(\.id), ["active", "planned", "todo"])
        XCTAssertTrue(try XCTUnwrap(result.projects.first { $0.id == "other-project" }).issues.isEmpty)
        XCTAssertEqual(result.initiatives.count, 2)
        for initiative in result.initiatives {
            XCTAssertEqual(initiative.issues.map(\.id), ["active", "planned", "todo"])
        }
        XCTAssertEqual(result.todo.map(\.id), ["todo"])
        let query = try XCTUnwrap((JSONSerialization.jsonObject(with: http.bodies[0]) as? [String: Any])?["query"] as? String)
        XCTAssertTrue(query.contains("planned: issues(first: 100, filter: { state: { name: { eqIgnoreCase: \"Planned\" } } })"))
        XCTAssertTrue(query.contains("project { id name color }"))
        XCTAssertTrue(query.contains("todo: issues(first: 100, filter: { state: { name: { eqIgnoreCase: \"Todo\" } } })"))
    }

    func testContainerMergeDeduplicatesAndIncludesIssuesFromProjectsOutsideVisibleProjectTabs() throws {
        var dashboard = try LinearClient.parseIssueDashboard(dashboardData())
        dashboard.todo = []
        let planned = try XCTUnwrap(dashboard.planned.first)
        dashboard.projects = [LinearProjectSummary(id: "project", name: "Project", issues: [planned])]
        dashboard.initiatives = [LinearInitiativeSummary(id: "initiative", name: "Initiative", issues: [planned],
                                                       projectIDs: ["project"])]
        let merged = LinearClient.includingQueuedIssuesInContainers(dashboard)
        XCTAssertEqual(merged.projects.first?.issues.map(\.id), ["planned"])
        XCTAssertEqual(merged.initiatives.first?.issues.map(\.id), ["planned"])
        let nav = MainWindowNavigation()
        nav.showProjectIssues(try XCTUnwrap(merged.projects.first))
        XCTAssertEqual(nav.issuesTab, .planned, "Projects with only planned work should open a populated tab")
        dashboard.projects = []
        dashboard.initiatives[0].issues = []
        XCTAssertEqual(LinearClient.includingQueuedIssuesInContainers(dashboard).initiatives.first?.issues.map(\.id), ["planned"])
    }

    func testQueuedOnlyTeamsReceiveWorkflowControls() async throws {
        for (key, name) in [("planned", "Planned"), ("todo", "Todo")] {
            var planned = node("planned", name: name, projectID: nil)
            planned["team"] = ["id": "team", "name": "Engineering", "key": "ENG"]
            let states = [["id": "start", "name": "In Progress", "type": "started"],
                          ["id": "done", "name": "Done", "type": "completed"]]
            let http = HTTP([
                try data(["completedRecent": ["nodes": []], "inProgress": ["nodes": []], key: ["nodes": [planned]]]),
                try data(["projects": ["nodes": []], "initiatives": ["nodes": []]]),
                try data(["teams": ["nodes": [["id": "team", "states": ["nodes": states]]]]]),
            ])
            let dashboard = try await LinearClient(http: http).fetchIssueDashboard(apiKey: "fixture", completedSince: Date())
            let queued = key == "todo" ? dashboard.todo : dashboard.planned
            XCTAssertEqual(queued.first?.teamStates.map(\.id), ["start", "done"])
            XCTAssertEqual(queued.first?.completedStateId, "done")
            XCTAssertTrue(LinearClient.missingTeamIDs(in: dashboard).isEmpty)
        }
    }

    func testPlannedStoreControlsAndNavigationStayConsistentWhenRefreshFails() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let suite = "LinearPlanned-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer {
            defaults.removePersistentDomain(forName: suite)
            try? FileManager.default.removeItem(at: directory)
        }
        defaults.set(true, forKey: "linearIntegrationEnabled")
        let keys = LinearAPIKeyStore(fileURL: directory.appendingPathComponent("key.json"))
        try keys.save(.init(key: "lin_api_fixture"))
        let http = HTTP([try dashboardData(), try containersData(includeTodo: true), try data(["projects": ["nodes": []]])])
        let store = UsageStore(providers: [], autoRefresh: false, defaults: defaults,
                               linearClient: LinearClient(http: http), linearAPIKeys: keys)
        _ = await store.refreshLinearIssues()
        XCTAssertEqual(LinearIssuesTab.planned.issues(in: store).map(\.id), ["planned"])
        XCTAssertEqual(LinearIssuesTab.planned.issues(in: store, projectID: "project").map(\.id), ["planned"])
        XCTAssertEqual(LinearIssuesTab.inProgress.issues(in: store, projectID: "project").map(\.id), ["active"])

        XCTAssertEqual(LinearIssuesTab.todo.issues(in: store).map(\.id), ["todo"])
        XCTAssertEqual(LinearIssuesTab.todo.issues(in: store, projectID: "project").map(\.id), ["todo"])
        let nav = MainWindowNavigation()
        nav.workspaceQueries[.issues] = "old search"
        nav.showProjectIssues(try XCTUnwrap(store.linearProjects.first { $0.id == "project" }), tab: .planned)
        XCTAssertEqual(nav.page, .issues)
        XCTAssertEqual(nav.issuesTab, .planned)
        XCTAssertEqual(nav.projectFilter, "project")
        XCTAssertEqual(nav.workspaceQueries[.issues], "")
        nav.select(.projects); nav.back()
        XCTAssertEqual(nav.issuesTab, .planned)

        http.responses = [try data(["issueUpdate": ["success": true, "issue": ["id": "planned"]]])]
        await store.updateLinearIssuePriority(try XCTUnwrap(store.linearIssue(id: "planned")), priority: 1)
        XCTAssertEqual(store.linearPlannedIssues.first?.priority, 1)
        XCTAssertEqual(store.linearInitiatives.first?.issues.first?.priority, 1)

        for (name, type) in [("Todo", "unstarted"), ("In Progress", "started"), ("Planned", "unstarted"), ("Done", "completed"), ("Todo", "unstarted"), ("Planned", "unstarted")] {
            http.responses = [try data(["issueUpdate": ["success": true, "issue": node("planned", name: name, type: type)]])]
            _ = await store.updateLinearIssueState(try XCTUnwrap(store.linearIssue(id: "planned")), stateID: type)
            XCTAssertEqual(store.linearTodoIssues.contains { $0.id == "planned" }, name == "Todo")
            XCTAssertEqual(store.linearPlannedIssues.contains { $0.id == "planned" }, name == "Planned")
            XCTAssertEqual(store.linearInProgressIssues.contains { $0.id == "planned" }, type == "started")
            XCTAssertEqual(store.linearProjects.first { $0.id == "project" }?.issues.contains { $0.id == "planned" }, type != "completed")
            XCTAssertEqual(store.linearInitiatives.first?.issues.contains { $0.id == "planned" }, type != "completed")
        }
        http.responses = [try data(["issueUpdate": ["success": true, "issue": ["id": "todo"]]])]
        await store.updateLinearIssuePriority(try XCTUnwrap(store.linearIssue(id: "todo")), priority: 2)
        XCTAssertEqual(store.linearTodoIssues.first?.priority, 2)
        store.clearLinearAPIKey()
        XCTAssertTrue(store.linearPlannedIssues.isEmpty)
        XCTAssertTrue(store.linearTodoIssues.isEmpty)
        XCTAssertNil(store.linearIssue(id: "planned"))
    }
}
