import AppKit
import SwiftUI
import XCTest
@testable import PokeTaskBar

@MainActor
final class LinearCardMinimizeTests: XCTestCase {
    func testNativeMinimizeRestoresSummaryAndExpandedContentAcrossCardTypes() async throws {
        try XCTSkipIf(NSScreen.screens.isEmpty, "Requires the macOS display server")
        let suite = "LinearCardMinimize-\(UUID().uuidString)"
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
        let issue = try LinearClient.parseIssueSummary([
            "id": "issue", "identifier": "PER-123", "title": "Plan the next small step", "priority": 2,
            "description": "Details that must disappear while minimized.",
            "assignee": ["name": "Alex Brown"], "project": ["id": "project", "name": "Weekly planning"],
            "state": ["id": "started", "name": "In Progress", "type": "started"],
            "createdAt": "2026-09-13T00:00:00Z", "dueDate": "2026-09-30",
            "labels": ["nodes": [["name": "Planning", "color": "#26b5ce"]]],
        ])
        let project = LinearProjectSummary(id: "project", name: "Build a steady routine",
            statusType: "started", leadName: "Alex Brown", targetDate: Date(),
            descriptionText: "Small, repeatable actions that make the week easier.", issues: [issue],
            identifier: "PRJ-1", health: "onTrack", priority: 2, issueCount: 1, issuesFullyLoaded: true)
        let initiative = LinearInitiativeSummary(id: "initiative", name: "Make room for creative work",
            url: URL(string: "https://linear.app/example/initiative"), statusName: "Active",
            ownerName: "Alex Brown", targetDate: Date(), descriptionText: "A sustainable personal operating rhythm.",
            issues: [], priority: 2, health: "onTrack", labels: [.init(id: "label", name: "Planning")],
            projectCount: 3, completedProjectCount: 1)

        for scheme in [ColorScheme.light, .dark] {
            for width: CGFloat in [240, 1000] {
                for kind in ["issue", "nested-issue", "project", "initiative"] {
                    // Both metadata modes must yield the same title-only minimum.
                    for all in [false, true] {
                        defaults.set(all, forKey: "linearIssueCardAllMetadata")
                        let card: AnyView
                        switch kind {
                        case "issue": card = AnyView(LinearIssueEntityRow(issue: issue, onPin: { XCTFail("Unexpected focus navigation") }))
                        case "nested-issue":
                            card = AnyView(LinearIssueEntityRow(issue: issue, nested: true, parentProjectID: project.id,
                                onPin: { XCTFail("Unexpected focus navigation") }))
                        case "project": card = AnyView(LinearProjectCard(project: project, onPin: { XCTFail("Unexpected focus navigation") }))
                        default:
                            card = AnyView(LinearInitiativeCard(initiative: initiative) {
                                    LinearProjectCard(project: project, onPin: {})
                                })
                        }
                        let root = card.padding(10).frame(width: width)
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
                        func settle() async throws {
                            try await Task.sleep(for: .milliseconds(220))
                            host.setFrameSize(host.fittingSize); host.layoutSubtreeIfNeeded()
                        }
                        func click(_ x: CGFloat, _ y: CGFloat) async throws {
                            let point = host.convert(NSPoint(x: x, y: host.isFlipped ? y : host.bounds.height - y), to: nil)
                            for type in [NSEvent.EventType.leftMouseDown, .leftMouseUp] {
                                window.sendEvent(try XCTUnwrap(NSEvent.mouseEvent(with: type, location: point,
                                    modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime,
                                    windowNumber: window.windowNumber, context: nil, eventNumber: 1, clickCount: 1, pressure: 1)))
                            }
                            try await settle()
                        }
                        func capture(_ suffix: String) throws {
                            guard let path = ProcessInfo.processInfo.environment["PTB_MINIMIZE_PREVIEW_DIR"] else { return }
                            let output = URL(fileURLWithPath: path)
                            try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
                            let bitmap = try XCTUnwrap(host.bitmapImageRepForCachingDisplay(in: host.bounds))
                            host.cacheDisplay(in: host.bounds, to: bitmap)
                            try XCTUnwrap(bitmap.representation(using: .png, properties: [:])).write(to:
                                output.appendingPathComponent("\(kind)-\(scheme)-\(Int(width))-\(all)-\(suffix).png"))
                        }
                        let isInitiative = kind == "initiative"
                        let foldX = width - (isInitiative ? 88 : kind == "project" ? 32 : 30)
                        let foldY: CGFloat = isInitiative ? 32 : kind == "project" ? 56 : kind == "nested-issue" ? 30 : 49
                        let titleY: CGFloat = isInitiative ? 32 : kind == "nested-issue" ? 30 : 54
                        try await settle()
                        let summaryHeight = host.fittingSize.height
                        try capture("summary")
                        try await click(foldX, foldY)
                        let minimumHeight = host.fittingSize.height
                        XCTAssertLessThan(minimumHeight, summaryHeight - 10, kind)
                        XCTAssertLessThan(minimumHeight, 115, "\(kind) must hide everything below its title")
                        XCTAssertEqual(host.fittingSize.width, width, accuracy: 1)
                        try capture("minimized")
                        try await click(foldX, foldY)
                        XCTAssertEqual(host.fittingSize.height, summaryHeight, accuracy: 1, kind)
                        try await click(70, titleY)
                        let expandedHeight = host.fittingSize.height
                        XCTAssertGreaterThan(expandedHeight, summaryHeight + 30, kind)
                        try await click(foldX, foldY)
                        XCTAssertEqual(host.fittingSize.height, minimumHeight, accuracy: 1,
                            "\(kind): expanded children and details must also disappear")
                        // Clicking the title restores the view as well as the explicit button.
                        try await click(70, titleY)
                        XCTAssertEqual(host.fittingSize.height, expandedHeight, accuracy: 1,
                            "\(kind): restore must retain the previous expansion state")
                        XCTAssertNil(focus.session)
                        XCTAssertTrue(usage.pinnedLinearProjectIDs.isEmpty)
                        XCTAssertTrue(usage.pinnedLinearInitiativeIDs.isEmpty)
                    }
                }
            }
        }
    }
}
