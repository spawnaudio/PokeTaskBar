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

    func testInProgressOnlyMatchesNamedStatusInsteadOfEveryStartedState() throws {
        let payload = try data([
            "completedRecent": ["nodes": []],
            "inProgress": ["nodes": [node("active", name: "In Progress", type: "started"),
                node("uppercase", name: " IN PROGRESS ", type: "started"),
                node("waiting", name: "Waiting", type: "started"),
                node("review", name: "In Review", type: "started"),
                node("blocked", name: "Blocked", type: "started"),
                node("done", name: "In Progress", type: "completed")]],
        ])
        let dashboard = try LinearClient.parseIssueDashboard(payload)
        XCTAssertEqual(dashboard.inProgress.map(\.id), ["active", "uppercase"])
        let waiting = try LinearClient.parseIssueSummary(node("waiting", name: "Waiting", type: "started"))
        XCTAssertFalse(LinearIssuesTab.inProgress.matches(waiting))
        XCTAssertFalse(PlanningGroup.today.matchesStatus(waiting))
    }

    func testParentRelationshipsLoadAcrossStatusesAndPaginatedChildrenKeepTheirOwnControls() async throws {
        var child = node("child", name: "Todo", priority: 2, projectID: nil)
        child["parent"] = ["id": "parent"]
        let states = [["id": "unstarted", "name": "Todo", "type": "unstarted"],
            ["id": "started", "name": "In Progress", "type": "started"],
            ["id": "done", "name": "Done", "type": "completed"]]
        child["team"] = ["id": "team", "key": "ENG", "states": ["nodes": states]]
        var parent = node("parent", name: "Backlog", type: "backlog", projectID: nil)
        parent["children"] = ["nodes": [["id": "child"]]]
        parent["team"] = child["team"]
        let http = HTTP([
            try data(["completedRecent": ["nodes": []], "inProgress": ["nodes": []], "todo": ["nodes": [child]]]),
            try data(["projects": ["nodes": []], "initiatives": ["nodes": []]]),
            try data(["issues": ["nodes": [parent]]]),
        ])
        let client = LinearClient(http: http)
        let dashboard = try await client.fetchIssueDashboard(apiKey: "fixture", completedSince: Date())
        let issue = try XCTUnwrap(dashboard.todo.first)
        let root = try XCTUnwrap(dashboard.relatedIssues.first)
        XCTAssertEqual(issue.parentID, root.id)
        XCTAssertTrue(root.hasSubIssues)
        XCTAssertEqual(root.completedStateId, "done")
        let context = LinearIssueHierarchy.includingAncestors([issue], in: [issue, root])
        XCTAssertEqual(LinearIssueHierarchy.roots([issue, root], in: context).map(\.id), [root.id])
        XCTAssertEqual(LinearIssueHierarchy.roots([issue], in: [issue]).map(\.id), [issue.id], "Missing parents must not hide accessible children")
        var cycleA = root, cycleB = issue
        cycleA.parentID = issue.id; cycleB.parentID = root.id
        XCTAssertEqual(LinearIssueHierarchy.roots([cycleA, cycleB], in: [cycleA, cycleB]).count, 1)
        var next = child
        next["id"] = "second"; next["identifier"] = "ENG-second"; next["title"] = "Second child"
        http.responses = [
            try data(["issue": ["children": ["nodes": [child], "pageInfo": ["hasNextPage": true, "endCursor": "page2"]]]]),
            try data(["issue": ["children": ["nodes": [next, child], "pageInfo": ["hasNextPage": false]]]]),
        ]
        let children = try await client.fetchSubIssues(apiKey: "fixture", issueID: root.id)
        XCTAssertEqual(Set(children.map(\.id)), ["child", "second"])
        XCTAssertTrue(children.allSatisfy { $0.parentID == root.id && $0.completedStateId == "done" })
        let request = try XCTUnwrap(try JSONSerialization.jsonObject(with: http.bodies.last!) as? [String: Any])
        XCTAssertEqual((request["variables"] as? [String: Any])?["after"] as? String, "page2")
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
        XCTAssertTrue(query.contains("inProgress: issues(first: 100, filter: { state: { type: { eq: \"started\" }, name: { eqIgnoreCase: \"In Progress\" } } })"))
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

        for (name, type) in [("Todo", "unstarted"), ("In Progress", "started"), ("Waiting", "started"), ("Planned", "unstarted"), ("Done", "completed"), ("Todo", "unstarted"), ("Planned", "unstarted")] {
            http.responses = [try data(["issueUpdate": ["success": true, "issue": node("planned", name: name, type: type)]])]
            let moved = await store.moveLinearIssueToState(try XCTUnwrap(store.linearIssue(id: "planned")), stateID: type)
            XCTAssertTrue(moved, "Non-completing status changes must report success")
            XCTAssertEqual(store.linearTodoIssues.contains { $0.id == "planned" }, name == "Todo")
            XCTAssertEqual(store.linearPlannedIssues.contains { $0.id == "planned" }, name == "Planned")
            XCTAssertEqual(store.linearInProgressIssues.contains { $0.id == "planned" }, name == "In Progress")
            XCTAssertEqual(store.linearProjects.first { $0.id == "project" }?.issues.contains { $0.id == "planned" }, type != "completed")
            XCTAssertEqual(store.linearInitiatives.first?.issues.contains { $0.id == "planned" }, type != "completed")
        }
        http.responses = [try data(["issueUpdate": ["success": true, "issue": ["id": "todo"]]])]
        await store.updateLinearIssuePriority(try XCTUnwrap(store.linearIssue(id: "todo")), priority: 2)
        XCTAssertEqual(store.linearTodoIssues.first?.priority, 2)
        http.responses = []
        let failed = await store.moveLinearIssueToState(try XCTUnwrap(store.linearIssue(id: "planned")), stateID: "started")
        XCTAssertFalse(failed, "Offline mutations must not report success")
        let plan = TaskPlanningStore(fileURL: directory.appendingPathComponent("plan.json"))
        plan.linked = true
        var mapped = try XCTUnwrap(store.linearIssue(id: "planned"))
        mapped.teamStates = [.init(id: "started", name: "In Progress", type: "started", position: 0),
            .init(id: "planned-state", name: "Planned", type: "unstarted", position: 1),
            .init(id: "unstarted", name: "Todo", type: "unstarted", position: 2)]
        http.responses = [try data(["issueUpdate": ["success": true, "issue": node("planned", name: "In Progress", type: "started")]])]
        await plan.move(mapped, to: .today, usage: store)
        XCTAssertNil(plan.syncError)
        XCTAssertEqual(store.linearIssue(id: "planned")?.stateType, "started", "Linked planning uses the shared mutation path")
        http.responses = [try data(["issueUpdate": ["success": true, "issue": node("planned")]])]
        await plan.undo(usage: store)
        XCTAssertNil(plan.entry("planned"))
        XCTAssertEqual(store.linearIssue(id: "planned")?.stateId, mapped.stateId)
        store.clearLinearAPIKey()
        XCTAssertTrue(store.linearPlannedIssues.isEmpty)
        XCTAssertTrue(store.linearTodoIssues.isEmpty)
        XCTAssertNil(store.linearIssue(id: "planned"))
    }
}
