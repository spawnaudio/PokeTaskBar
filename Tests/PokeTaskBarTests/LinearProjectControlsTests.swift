import XCTest
@testable import PokeTaskBar

final class LinearProjectControlsTests: XCTestCase {
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

    private func data(_ payload: [String: Any]) throws -> Data {
        try JSONSerialization.data(withJSONObject: ["data": payload])
    }

    func testProjectSortsUseRealMetadataPutMissingValuesLastAndBreakTies() {
        let older = Date(timeIntervalSince1970: 1), newer = Date(timeIntervalSince1970: 2)
        let a = LinearProjectSummary(id: "a", name: "Beta", targetDate: older, issues: [], priority: 1,
                                     startDate: newer, createdAt: older, updatedAt: newer)
        let b = LinearProjectSummary(id: "b", name: "Alpha", targetDate: newer, issues: [], priority: 3,
                                     startDate: older, createdAt: newer, updatedAt: older)
        let missing = LinearProjectSummary(id: "c", name: "Zebra", issues: [], priority: 0)
        let projects = [missing, b, a]
        XCTAssertEqual(LinearProjectSort.name.sorted(projects).map(\.id), ["b", "a", "c"])
        XCTAssertEqual(LinearProjectSort.priority.sorted(projects).map(\.id), ["a", "b", "c"])
        XCTAssertEqual(LinearProjectSort.targetDate.sorted(projects).map(\.id), ["a", "b", "c"])
        XCTAssertEqual(LinearProjectSort.startDate.sorted(projects).map(\.id), ["b", "a", "c"])
        XCTAssertEqual(LinearProjectSort.updated.sorted(projects).map(\.id), ["a", "b", "c"])
        XCTAssertEqual(LinearProjectSort.created.sorted(projects).map(\.id), ["b", "a", "c"])
        for sort in LinearProjectSort.allCases {
            let ties = ["c", "a", "b"].map { LinearProjectSummary(id: $0, name: "Same", issues: []) }
            XCTAssertEqual(sort.sorted(ties).map(\.id), ["a", "b", "c"])
        }
    }

    func testStatusTabsIncludeUnusedStatusesAndKeepCustomStartedStatesSeparate() {
        let catalog = [
            LinearWorkflowState(id: "backlog", name: "Backlog", type: "backlog", position: 0),
            LinearWorkflowState(id: "planned", name: "Planned", type: "planned", position: 1),
            LinearWorkflowState(id: "progress", name: "In Progress", type: "started", position: 2),
            LinearWorkflowState(id: "production", name: "Production", type: "started", position: 3),
            LinearWorkflowState(id: "review", name: "In Review", type: "started", position: 4),
            LinearWorkflowState(id: "done", name: "Completed", type: "completed", position: 3),
            LinearWorkflowState(id: "cancel", name: "Canceled", type: "canceled", position: 4),
        ]
        let projects = [
            LinearProjectSummary(id: "1", name: "Work", statusName: "In Progress", statusType: "started", issues: [], statusID: "progress"),
            LinearProjectSummary(id: "2", name: "Live", statusName: "Production", statusType: "started", issues: [], statusID: "production"),
            LinearProjectSummary(id: "3", name: "Later", statusName: "Planned", statusType: "planned", issues: []),
        ]
        XCTAssertEqual(LinearProjectStatuses.options(projects: projects, catalog: catalog).map(\.id), catalog.map(\.id))
        XCTAssertEqual(LinearProjectStatuses.matching(projects, selection: "", catalog: catalog).count, 3)
        XCTAssertEqual(LinearProjectStatuses.matching(projects, selection: "production", catalog: catalog).map(\.id), ["2"])
        XCTAssertEqual(LinearProjectStatuses.matching(projects, selection: "planned", catalog: catalog).map(\.id), ["3"])
        XCTAssertTrue(LinearProjectStatuses.matching(projects, selection: "review", catalog: catalog).isEmpty)
        XCTAssertEqual(LinearProjectStatuses.options(projects: projects, catalog: []).count, 3)
    }

    func testIssueFilterKeepsNamedStatusesDistinctAndOffersUnpopulatedTeamStates() throws {
        func issue(_ id: String, name: String, type: String) throws -> LinearIssueSummary {
            try LinearClient.parseIssueSummary(["id": id, "identifier": id, "title": id,
                "state": ["id": id, "name": name, "type": type], "team": ["states": ["nodes": [
                    ["id": "backlog", "name": "Backlog", "type": "backlog"],
                    ["id": "todo", "name": "Todo", "type": "unstarted"],
                    ["id": "planned", "name": "Planned", "type": "unstarted"],
                    ["id": "review", "name": "Review", "type": "started"],
                    ["id": "done", "name": "Done", "type": "completed"],
                ]]]])
        }
        let issues = try [issue("1", name: "Todo", type: "unstarted"), issue("2", name: "Planned", type: "unstarted"),
                          issue("3", name: "Done", type: "completed"), issue("4", name: "Done", type: "completed")]
        let options = LinearProjectIssueFilter.options([LinearProjectSummary(id: "p", name: "P", issues: issues)])
        XCTAssertEqual(Set(options.map(\.name)), ["Backlog", "Todo", "Planned", "Review", "Done"])
        XCTAssertEqual(options.filter { $0.name == "Done" }.count, 1)
        let hidden: Set<String> = [LinearProjectIssueFilter.key(name: "Todo", type: "unstarted"),
                                   LinearProjectIssueFilter.key(name: "Done", type: "completed")]
        XCTAssertEqual(LinearProjectIssueFilter.visible(issues, hiding: hidden).map(\.id), ["2"])
        XCTAssertEqual(LinearProjectIssueFilter.visible(issues, hiding: []).count, 4)
        XCTAssertTrue(LinearProjectIssueFilter.visible(issues, hiding: Set(options.map(\.id))).isEmpty)
    }

    func testFetchAllProjectPagesAndStatusCatalogPages() async throws {
        func project(_ id: String, type: String) -> [String: Any] {
            ["id": id, "name": id, "status": ["id": type, "name": type, "type": type, "position": 1],
             "createdAt": "2026-09-01T00:00:00Z", "updatedAt": "2026-09-27T00:00:00Z"]
        }
        let statuses = [["id": "empty", "name": "Mix & Mastering", "type": "started", "position": 2]]
        let http = HTTP([
            try data(["inProgress": ["nodes": []], "completedRecent": ["nodes": []]]),
            try data(["projects": ["nodes": [project("p1", type: "backlog")], "pageInfo": ["hasNextPage": true, "endCursor": "next-project"]]]),
            try data(["projects": ["nodes": [project("p2", type: "completed")], "pageInfo": ["hasNextPage": false]]]),
            try data(["projects": ["nodes": [project("p1", type: "backlog"), project("p2", type: "completed")]]]),
            try data(["projectStatuses": ["nodes": statuses, "pageInfo": ["hasNextPage": true, "endCursor": "next-status"]]]),
            try data(["projectStatuses": ["nodes": [["id": "closed", "name": "Completed", "type": "completed", "position": 3]], "pageInfo": ["hasNextPage": false]]]),
        ])
        let result = try await LinearClient(http: http).fetchIssueDashboard(apiKey: "fixture", completedSince: Date())
        XCTAssertEqual(result.projects.map(\.id), ["p1", "p2"])
        XCTAssertEqual(result.projects.map(\.statusID), ["backlog", "completed"])
        XCTAssertNotNil(result.projects.first?.createdAt); XCTAssertNotNil(result.projects.first?.updatedAt)
        XCTAssertEqual(result.projectStatuses.map(\.id), ["empty", "closed"])
        for (index, cursor) in [(2, "next-project"), (5, "next-status")] {
            let body = try XCTUnwrap(JSONSerialization.jsonObject(with: http.bodies[index]) as? [String: Any])
            XCTAssertEqual((body["variables"] as? [String: String])?["after"], cursor)
        }
    }

    @MainActor
    func testProjectControlsSurviveNavigationWithoutChangingIssuePreferences() {
        let nav = MainWindowNavigation()
        nav.projectStatus = "planned"; nav.projectSort = .targetDate
        nav.initiativeSort = .priority
        nav.issueSorts[.todo] = .priority
        nav.select(.projects); nav.select(.issues); nav.back()
        XCTAssertEqual(nav.projectStatus, "planned")
        XCTAssertEqual(nav.projectSort, .targetDate)
        XCTAssertEqual(nav.initiativeSort, .priority)
        XCTAssertEqual(nav.issueSorts[.todo], .priority)
    }

    @MainActor
    func testIssueFilterPersistsAcrossStoreReloadsAndReset() throws {
        let suite = "IssueFilter-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defaults.set(0, forKey: "refreshInterval")
        defer { defaults.removePersistentDomain(forName: suite) }
        let keys = LinearAPIKeyStore(fileURL: FileManager.default.temporaryDirectory.appendingPathComponent(suite))
        func reopen() -> UsageStore {
            UsageStore(providers: [], autoRefresh: false, defaults: UserDefaults(suiteName: suite)!, linearAPIKeys: keys)
        }
        var store = reopen()
        store.hiddenLinearIssueStatuses = ["completed:done", "unstarted:todo"]
        store = reopen()
        XCTAssertEqual(store.hiddenLinearIssueStatuses, ["completed:done", "unstarted:todo"])
        store.hiddenLinearIssueStatuses.remove("unstarted:todo")
        XCTAssertEqual(reopen().hiddenLinearIssueStatuses, ["completed:done"])
        store.hiddenLinearIssueStatuses.removeAll()
        XCTAssertTrue(reopen().hiddenLinearIssueStatuses.isEmpty)
    }

    func testInitiativeSortsAndPinnedDividerRespectMissingValuesAndVisibleItems() {
        let a = LinearInitiativeSummary(id: "a", name: "Beta", targetDate: Date(timeIntervalSince1970: 1), issues: [], priority: 1)
        let b = LinearInitiativeSummary(id: "b", name: "Alpha", targetDate: Date(timeIntervalSince1970: 2), issues: [], priority: 3)
        let c = LinearInitiativeSummary(id: "c", name: "Zebra", issues: [], priority: 0)
        let values = [c, b, a]
        XCTAssertEqual(LinearInitiativeSort.name.sorted(values).map(\.id), ["b", "a", "c"])
        XCTAssertEqual(LinearInitiativeSort.priority.sorted(values).map(\.id), ["a", "b", "c"])
        XCTAssertEqual(LinearInitiativeSort.targetDate.sorted(values).map(\.id), ["a", "b", "c"])
        for sort in LinearInitiativeSort.allCases {
            let ties = ["c", "a", "b"].map { LinearInitiativeSummary(id: $0, name: "Same", issues: []) }
            XCTAssertEqual(sort.sorted(ties).map(\.id), ["a", "b", "c"])
        }
        let ordered = LinearContainerOrder.pinnedFirst(values, ids: ["b"])
        XCTAssertEqual(ordered.map(\.id), ["b", "c", "a"])
        XCTAssertEqual(LinearContainerOrder.dividerID(ordered, ids: ["b"]), "c")
        XCTAssertNil(LinearContainerOrder.dividerID(values, ids: []))
        XCTAssertNil(LinearContainerOrder.dividerID(values, ids: ["a", "b", "c"]))
        XCTAssertNil(LinearContainerOrder.dividerID(values.filter { $0.id != "b" }, ids: ["b"]))
    }
}
