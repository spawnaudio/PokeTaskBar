import AppKit
import SwiftUI
import XCTest
@testable import PokeTaskBar

@MainActor
final class LinearInitiativeCardTests: XCTestCase {
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
        try JSONSerialization.data(withJSONObject: ["data": value])
    }

    private func project(_ id: String, type: String, health: String? = nil) -> [String: Any] {
        var node: [String: Any] = ["id": id, "name": "Goal: Stick to a Routine",
            "description": "Build a sustainable rhythm with small, repeatable actions.",
            "status": ["type": type, "name": type == "started" ? "In Progress" : type],
            "issues": ["nodes": []]]
        if let health { node["health"] = health }
        return node
    }

    private func initiative() -> [String: Any] {
        ["id": "initiative", "name": "Build a Sustainable Personal Operating Rhythm", "status": "Active",
         "url": "https://linear.app/example/initiative/rhythm", "icon": "Refresh", "color": "#26b5ce",
         "description": "Strengthen planning, finance, communications, and essential routines enough to reduce surprises and sustainably support creative capacity.",
         "priority": 2, "health": "atRisk", "targetDate": "2027-03-31", "targetDateResolution": "quarter",
         "owner": ["name": "Alex Brown", "avatarUrl": "https://example.com/avatar.png"],
         "leadTeam": ["id": "team", "key": "PER", "name": "Personal", "icon": "Terminal", "color": "#26b5ce"],
         "labels": ["nodes": [["id": "setup", "name": "Needs Setup", "color": "#94a3b8"],
                               ["id": "systems", "name": "Systems", "color": "#26b5ce", "parent": ["name": "Area"]],
                               ["id": "efficiency", "name": "Efficiency", "color": "#26b5ce", "parent": ["name": "Outcome"]]]],
         "projects": ["nodes": [project("done", type: "completed"), project("good", type: "started", health: "onTrack"),
                                  project("risk", type: "started", health: "atRisk"), project("planned", type: "planned")],
                      "pageInfo": ["hasNextPage": false]]]
    }

    func testMetadataCountsCompletedAndActiveHealthFromAllPages() async throws {
        var node = initiative()
        node["projects"] = ["nodes": [project("done", type: "completed", health: "onTrack"), project("good", type: "started", health: "onTrack")],
                            "pageInfo": ["hasNextPage": true, "endCursor": "page-2"]]
        let first = try data(["initiatives": ["nodes": [node]]])
        let last = try data(["initiative": ["projects": ["nodes": [project("good", type: "started", health: "onTrack"),
            project("risk", type: "started", health: "atRisk"), project("late", type: "started", health: "offTrack"),
            project("none", type: "started"), project("planned", type: "planned"), project("canceled", type: "canceled"),
            project("backlog-update", type: "backlog", health: "onTrack")],
            "pageInfo": ["hasNextPage": false]]]])
        let http = HTTP([first, last])
        let result = try await LinearClient(http: http).fetchInitiativeCardMetadata(apiKey: "fixture", ids: ["initiative"])
        let value = try XCTUnwrap(result.first)
        XCTAssertEqual(value.projectCount, 8)
        XCTAssertEqual(value.completedProjectCount, 1)
        XCTAssertEqual(value.activeProjectHealthCounts, ["onTrack": 3, "atRisk": 1, "offTrack": 1, "unknown": 1])
        XCTAssertEqual(value.projectIDs.count, 8, "Repeated project pages cannot inflate counts")
        XCTAssertEqual(value.labels.map(\.groupName), [nil, "Area", "Outcome"])
        XCTAssertEqual(value.ownerAvatarURL?.host, "example.com")
        XCTAssertEqual(value.leadTeam?.name, "PER")
        XCTAssertEqual(value.targetDateResolution, "quarter")
        XCTAssertEqual(value.icon, "Refresh"); XCTAssertEqual(value.health, "atRisk")
        let body = try XCTUnwrap(JSONSerialization.jsonObject(with: http.bodies[1]) as? [String: Any])
        XCTAssertEqual((body["variables"] as? [String: String])?["after"], "page-2")
        XCTAssertFalse((body["query"] as? String ?? "").contains("issues("))
        let repeated = try data(["initiative": ["projects": node["projects"]!]])
        for responses in [[first], [first, repeated]] {
            do {
                _ = try await LinearClient(http: HTTP(responses)).fetchInitiativeCardMetadata(apiKey: "fixture", ids: ["initiative"])
                XCTFail("Failed or repeated pages must not become complete project counts")
            } catch { }
        }
    }

    func testMissingMetadataDoesNotInventCountsAndEnrichmentPreservesIssues() async throws {
        let issue: [String: Any] = ["id": "issue", "identifier": "PER-1", "title": "Small next action",
            "state": ["id": "planned", "name": "Planned", "type": "unstarted"], "project": ["id": "good"]]
        var container = initiative()
        container["projects"] = ["nodes": [["id": "good", "issues": ["nodes": [issue]]]]]
        let issues = try data(["inProgress": ["nodes": []], "completedRecent": ["nodes": []]])
        let containers = try data(["initiatives": ["nodes": [container]], "projects": ["nodes": []]])
        let statuses = try data(["projectStatuses": ["nodes": []]])
        let metadata = try data(["initiatives": ["nodes": [initiative()]]])
        for enrichment in [metadata, try JSONSerialization.data(withJSONObject: ["errors": [["message": "Unavailable"]]])] {
            let result = try await LinearClient(http: HTTP([issues, containers, statuses, enrichment]))
                .fetchIssueDashboard(apiKey: "fixture", completedSince: Date())
            XCTAssertEqual(result.initiatives.first?.issues.map(\.id), ["issue"])
        }
        let partial = try LinearClient.parseIssueDashboard(data([
            "inProgress": ["nodes": []], "completedRecent": ["nodes": []],
            "initiatives": ["nodes": [["id": "minimal", "name": "Minimal", "status": "Planned"]]]]))
        let value = try XCTUnwrap(partial.initiatives.first)
        XCTAssertNil(value.projectCount); XCTAssertNil(value.completedProjectCount)
        XCTAssertTrue(value.labels.isEmpty); XCTAssertTrue(value.activeProjectHealthCounts.isEmpty)
        XCTAssertNil(value.leadTeam); XCTAssertNil(value.ownerAvatarURL)
    }

    func testRenderAndClickInitiativeCards() async throws {
        guard let path = ProcessInfo.processInfo.environment["PTB_INITIATIVE_CARD_PREVIEW_DIR"] else {
            throw XCTSkip("Set PTB_INITIATIVE_CARD_PREVIEW_DIR for native card verification")
        }
        try XCTSkipIf(NSScreen.screens.isEmpty, "Requires the macOS display server")
        let directory = URL(fileURLWithPath: path)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let suite = "LinearInitiativeCards-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        let stateDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(suite)
        try FileManager.default.createDirectory(at: stateDirectory, withIntermediateDirectories: true)
        defer { defaults.removePersistentDomain(forName: suite); try? FileManager.default.removeItem(at: stateDirectory) }
        defaults.set(true, forKey: "linearIntegrationEnabled")
        var state = CompanionState(); state.language = .en
        let file = stateDirectory.appendingPathComponent("companion.json")
        try JSONEncoder().encode(state).write(to: file)
        let companion = CompanionStore(provider: StubProvider(value: EvoLine(baseID: 1,
            tree: EvoNode(speciesID: 1, children: []), rarity: .common, names: [:])), fileURL: file, defaults: defaults)
        let keys = LinearAPIKeyStore(fileURL: stateDirectory.appendingPathComponent("key.json"))
        try keys.save(.init(key: "lin_api_fixture"))
        let dashboard = try data(["inProgress": ["nodes": []], "completedRecent": ["nodes": []],
            "projects": ["nodes": [project("good", type: "started", health: "onTrack")]],
            "initiatives": ["nodes": [initiative()]], "projectStatuses": ["nodes": []]])
        let usage = UsageStore(providers: [], autoRefresh: false, defaults: defaults,
            linearClient: LinearClient(http: HTTP(Array(repeating: dashboard, count: 5))), linearAPIKeys: keys)
        _ = await usage.refreshLinearIssues()
        let focus = FocusSessionStore(usage: usage, companion: companion,
            fileURL: stateDirectory.appendingPathComponent("focus.json"), ticksOnTimer: false)
        var value = try XCTUnwrap(usage.linearInitiatives.first)
        value.ownerAvatarURL = nil // Deterministic native render; remote avatar loading is separate.
        for scheme in [ColorScheme.light, .dark] {
            for all in [false, true] {
                defaults.set(all, forKey: "linearIssueCardAllMetadata")
                for width: CGFloat in [240, 360, 1000] {
                    let root = LinearInitiativeCard(initiative: value) {
                        LinearInitiativeProjects(initiative: value, onPin: {})
                    }.padding(10).frame(width: width)
                        .background(scheme == .light ? Color(white: 0.97) : Color(white: 0.12))
                        .environment(usage).environment(companion).environment(focus)
                        .environment(\.colorScheme, scheme)
                        .defaultAppStorage(defaults)
                    let host = NSHostingView(rootView: root)
                    let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: width, height: 500),
                        styleMask: .borderless, backing: .buffered, defer: false)
                    window.isReleasedWhenClosed = false
                    window.appearance = NSAppearance(named: scheme == .light ? .aqua : .darkAqua)
                    window.contentView = host; window.orderFrontRegardless()
                    defer { window.orderOut(nil); window.contentView = nil }
                    try await Task.sleep(for: .milliseconds(120))
                    host.setFrameSize(host.fittingSize); host.layoutSubtreeIfNeeded()
                    let collapsed = host.fittingSize.height
                    XCTAssertEqual(host.fittingSize.width, width, accuracy: 1)
                    XCTAssertLessThan(collapsed, width == 240 ? 380 : 300)
                    if width == 1000 { XCTAssertLessThan(collapsed, all ? 115 : 90, "Wide cards must keep metadata beside the title") }
                    let name = "initiative-\(scheme)-\(all ? "all" : "minimal")-\(Int(width))"
                    try capture(host, to: directory.appendingPathComponent(name + ".png"))
                    for expanded in [true, false] {
                        let point = host.convert(NSPoint(x: width / 2, y: host.isFlipped ? 35 : host.bounds.height - 35), to: nil)
                        for type in [NSEvent.EventType.leftMouseDown, .leftMouseUp] {
                            window.sendEvent(try XCTUnwrap(NSEvent.mouseEvent(with: type, location: point,
                                modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime,
                                windowNumber: window.windowNumber, context: nil, eventNumber: 1, clickCount: 1, pressure: 1)))
                        }
                        try await Task.sleep(for: .milliseconds(220))
                        host.setFrameSize(host.fittingSize); host.layoutSubtreeIfNeeded()
                        if expanded {
                            XCTAssertGreaterThan(host.fittingSize.height, collapsed + 100)
                            try capture(host, to: directory.appendingPathComponent(name + "-expanded.png"))
                        } else { XCTAssertEqual(host.fittingSize.height, collapsed, accuracy: 1) }
                        XCTAssertNil(focus.session, "Initiative expansion must not start a timer")
                    }
                }
            }
        }
    }

    private func capture(_ host: NSView, to url: URL) throws {
        let bitmap = try XCTUnwrap(host.bitmapImageRepForCachingDisplay(in: host.bounds))
        host.cacheDisplay(in: host.bounds, to: bitmap)
        try XCTUnwrap(bitmap.representation(using: .png, properties: [:])).write(to: url)
    }
}
