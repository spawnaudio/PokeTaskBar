import AppKit
import SwiftUI
import XCTest
@testable import PokeTaskBar

@MainActor
final class LinearContainerPinTests: XCTestCase {
    private final class HTTP: LinearHTTPClient, @unchecked Sendable {
        var projectStatus = "started"
        var initiativeStatus = "Active"
        var missing = false
        var failPins = false
        var failed = false
        var pinBatches: [[String]] = []

        func postGraphQL(apiKey: String, body: Data) async throws -> (status: Int, data: Data) {
            if failed { throw URLError(.notConnectedToInternet) }
            let request = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
            let query = try XCTUnwrap(request["query"] as? String)
            let variables = request["variables"] as? [String: Any] ?? [:]
            let initiative: [String: Any] = ["id": "i", "name": "Initiative", "status": initiativeStatus,
                "projects": ["nodes": [], "pageInfo": ["hasNextPage": false]]]
            var payload: [String: Any] = [:]
            if query.contains("PinnedInitiativeStatuses") {
                pinBatches.append(try XCTUnwrap(variables["ids"] as? [String]))
                if failPins { return (200, Data(#"{"errors":[{"message":"Unavailable"}]}"#.utf8)) }
                payload = ["initiatives": ["nodes": missing ? [] : [initiative]]]
            } else if query.contains("IssueContainers") || query.contains("ProjectCardMetadata") {
                payload = ["projects": ["nodes": missing ? [] : [["id": "p", "name": "Project",
                    "status": ["name": "Custom status", "type": projectStatus]]]],
                    "initiatives": ["nodes": missing || initiativeStatus == "Completed" ? [] : [initiative]]]
            } else if query.contains("InitiativeCardMetadata") {
                payload = ["initiatives": ["nodes": [initiative]]]
            } else {
                payload = ["inProgress": ["nodes": []], "completedRecent": ["nodes": []],
                           "projectStatuses": ["nodes": []]]
            }
            return (200, try JSONSerialization.data(withJSONObject: ["data": payload]))
        }
    }

    func testPinsPersistUnpinAndClearOnlyOnConfirmedCompletion() async throws {
        let suite = "LinearPins-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(suite)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { defaults.removePersistentDomain(forName: suite); try? FileManager.default.removeItem(at: directory) }
        defaults.set(true, forKey: "linearIntegrationEnabled")
        defaults.set(0, forKey: "refreshInterval")
        let keys = LinearAPIKeyStore(fileURL: directory.appendingPathComponent("key.json"))
        try keys.save(.init(key: "lin_api_fixture"))
        let http = HTTP()
        func reopen() -> UsageStore {
            UsageStore(providers: [], autoRefresh: false, defaults: UserDefaults(suiteName: suite)!,
                       linearClient: LinearClient(http: http), linearAPIKeys: keys)
        }
        var store = reopen()
        _ = await store.refreshLinearIssues()
        XCTAssertTrue(http.pinBatches.isEmpty, "No extra request without saved initiative pins")
        var project = try XCTUnwrap(store.linearProjects.first)
        var initiative = try XCTUnwrap(store.linearInitiatives.first)
        store.toggleLinearProjectPin(project)
        store.toggleLinearInitiativePin(initiative)
        store = reopen()
        XCTAssertEqual(store.pinnedLinearProjectIDs, ["p"])
        XCTAssertEqual(store.pinnedLinearInitiativeIDs, ["i"])
        store.toggleLinearProjectPin(project)
        store.toggleLinearInitiativePin(initiative)
        store = reopen()
        XCTAssertTrue(store.pinnedLinearProjectIDs.isEmpty)
        XCTAssertTrue(store.pinnedLinearInitiativeIDs.isEmpty)
        store.toggleLinearProjectPin(project)
        store.toggleLinearInitiativePin(initiative)

        http.failed = true
        _ = await store.refreshLinearIssues()
        http.failed = false
        http.missing = true
        _ = await store.refreshLinearIssues()
        XCTAssertEqual(store.pinnedLinearProjectIDs, ["p"])
        XCTAssertEqual(store.pinnedLinearInitiativeIDs, ["i"], "Absence is not proof of completion")
        http.missing = false
        http.projectStatus = "paused"
        http.initiativeStatus = "Planned"
        _ = await store.refreshLinearIssues()
        XCTAssertEqual(store.pinnedLinearProjectIDs, ["p"])
        XCTAssertEqual(store.pinnedLinearInitiativeIDs, ["i"])

        http.projectStatus = "completed"
        http.initiativeStatus = "Completed"
        http.failPins = true
        _ = await store.refreshLinearIssues()
        XCTAssertTrue(store.pinnedLinearProjectIDs.isEmpty, "Use the project status type, including custom status names")
        XCTAssertEqual(store.pinnedLinearInitiativeIDs, ["i"], "Failed status lookup must preserve pins")
        http.failPins = false
        _ = await store.refreshLinearIssues()
        XCTAssertTrue(store.linearInitiatives.isEmpty, "Completed initiatives are absent from the page feed")
        XCTAssertTrue(store.pinnedLinearInitiativeIDs.isEmpty)
        XCTAssertEqual(http.pinBatches.last, ["i"])
        store = reopen()
        XCTAssertTrue(store.pinnedLinearProjectIDs.isEmpty)
        XCTAssertTrue(store.pinnedLinearInitiativeIDs.isEmpty)
        project.statusType = "completed"
        initiative.statusName = "Completed"
        store.toggleLinearProjectPin(project)
        store.toggleLinearInitiativePin(initiative)
        XCTAssertTrue(store.pinnedLinearProjectIDs.isEmpty)
        XCTAssertTrue(store.pinnedLinearInitiativeIDs.isEmpty)
        http.projectStatus = "started"
        http.initiativeStatus = "Active"
        _ = await store.refreshLinearIssues()
        XCTAssertTrue(store.pinnedLinearProjectIDs.isEmpty, "Reopening completed work must not restore its pin")
        XCTAssertTrue(store.pinnedLinearInitiativeIDs.isEmpty)
    }

    func testPinnedOrderPreservesSortAndFiltersAndBatchesStatusChecks() async throws {
        let projects = ["c", "a", "b", "d"].map { LinearProjectSummary(id: $0, name: $0, issues: []) }
        XCTAssertEqual(LinearContainerOrder.pinnedFirst(projects, ids: ["b", "c"]).map(\.id), ["c", "b", "a", "d"])
        for sort in LinearProjectSort.allCases {
            XCTAssertEqual(LinearContainerOrder.pinnedFirst(sort.sorted(projects), ids: ["b", "c"]).map(\.id), ["b", "c", "a", "d"])
        }
        XCTAssertEqual(LinearContainerOrder.pinnedFirst(projects.filter { $0.id != "c" }, ids: ["c"]).map(\.id), ["a", "b", "d"])
        let http = HTTP()
        let ids = Set((0..<51).map { "i\($0)" })
        _ = try await LinearClient(http: http).fetchIssueDashboard(apiKey: "fixture", completedSince: Date(), pinnedInitiativeIDs: ids)
        XCTAssertEqual(http.pinBatches.map(\.count), [50, 1])
        XCTAssertEqual(Set(http.pinBatches.flatMap { $0 }), ids)
    }

    func testNativePinButtonsDoNotExpandCardsOrStartFocus() async throws {
        try XCTSkipIf(NSScreen.screens.isEmpty, "Requires the macOS display server")
        let suite = "LinearPinButtons-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defaults.set(0, forKey: "refreshInterval")
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(suite)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { defaults.removePersistentDomain(forName: suite); try? FileManager.default.removeItem(at: directory) }
        var state = CompanionState(); state.language = .en
        let file = directory.appendingPathComponent("companion.json")
        try JSONEncoder().encode(state).write(to: file)
        let companion = CompanionStore(provider: StubProvider(value: EvoLine(baseID: 1,
            tree: EvoNode(speciesID: 1, children: []), rarity: .common, names: [:])), fileURL: file, defaults: defaults)
        let usage = UsageStore(providers: [], autoRefresh: false, defaults: defaults,
                              linearAPIKeys: LinearAPIKeyStore(fileURL: directory.appendingPathComponent("key.json")))
        let focus = FocusSessionStore(usage: usage, companion: companion,
                                     fileURL: directory.appendingPathComponent("focus.json"), ticksOnTimer: false)
        let project = LinearProjectSummary(id: "p", name: "Project", statusType: "started", issues: [])
        let initiative = LinearInitiativeSummary(id: "i", name: "Initiative", statusName: "Active", issues: [])
        for isProject in [true, false] {
            let card = isProject
                ? AnyView(LinearProjectCard(project: project, onPin: { XCTFail("Must not route to Focus") }))
                : AnyView(LinearInitiativeCard(initiative: initiative) { Text("Expanded content").frame(height: 100) })
            let root = card.padding(10).frame(width: 350)
                .environment(usage).environment(companion).environment(focus).defaultAppStorage(defaults)
            let host = NSHostingView(rootView: root)
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 350, height: 500),
                                  styleMask: .borderless, backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false
            window.contentView = host; window.orderFrontRegardless()
            defer { window.orderOut(nil); window.contentView = nil }
            try await Task.sleep(for: .milliseconds(150))
            host.setFrameSize(host.fittingSize); host.layoutSubtreeIfNeeded()
            let collapsedHeight = host.fittingSize.height
            for pinned in [true, false] {
                let point = host.convert(NSPoint(x: 317, y: host.isFlipped ? 33 : host.bounds.height - 33), to: nil)
                for type in [NSEvent.EventType.leftMouseDown, .leftMouseUp] {
                    window.sendEvent(try XCTUnwrap(NSEvent.mouseEvent(with: type, location: point,
                        modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime,
                        windowNumber: window.windowNumber, context: nil, eventNumber: 1, clickCount: 1, pressure: 1)))
                }
                try await Task.sleep(for: .milliseconds(100))
                XCTAssertEqual(isProject ? usage.pinnedLinearProjectIDs.contains("p") : usage.pinnedLinearInitiativeIDs.contains("i"), pinned)
                XCTAssertEqual(host.fittingSize.height, collapsedHeight, accuracy: 1)
                XCTAssertNil(focus.session)
            }
        }
        XCTAssertTrue(usage.pinnedLinearProjectIDs.isEmpty)
        XCTAssertTrue(usage.pinnedLinearInitiativeIDs.isEmpty)
    }
}
