import AppKit
import SwiftUI
import XCTest
@testable import PokeTaskBar

@MainActor
final class LinearIssueCardTests: XCTestCase {
    func testCardMetadataParsesRealValuesAndMissingValuesStayAbsent() throws {
        let issue = try Self.issue()
        XCTAssertEqual(issue.stateColor, "#e5df00")
        XCTAssertEqual(issue.projectColor, "#45b785")
        XCTAssertEqual(issue.labelColors["Business Admin"], "#94a3b8")
        XCTAssertEqual(issue.cycleNumber, 38)
        XCTAssertEqual(issue.milestoneName, "Define the routine")
        XCTAssertNotNil(issue.startedAt)
        let empty = try LinearClient.parseIssueSummary(["id": "empty", "identifier": "PER-1", "title": "Empty"])
        XCTAssertNil(empty.assigneeAvatarURL)
        XCTAssertNil(empty.startedAt)
        XCTAssertNil(empty.cycleNumber)
        XCTAssertNil(empty.milestoneName)
        XCTAssertTrue(empty.labelColors.isEmpty)

        let withAvatar = try LinearClient.parseIssueSummary([
            "id": "avatar", "identifier": "PER-2", "title": "Avatar",
            "assignee": ["name": "Alex", "avatarUrl": "https://example.com/avatar.png"],
        ])
        XCTAssertEqual(withAvatar.assigneeAvatarURL?.absoluteString, "https://example.com/avatar.png")
    }

    func testDateOnlyDueDateKeepsItsDayAcrossTimeZones() throws {
        let date = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-09-19T00:00:00Z"))
        for name in ["America/Los_Angeles", "Australia/Perth", "Pacific/Auckland"] {
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = try XCTUnwrap(TimeZone(identifier: name))
            let local = LinearCardDate.localDay(date, calendar: calendar)
            XCTAssertEqual(calendar.component(.day, from: local), 19, name)
            XCTAssertEqual(calendar.component(.hour, from: local), 0, name)
        }
    }

    func testStateMutationCarriesTheNewWorkflowColor() throws {
        let data = Data(##"{"data":{"issueUpdate":{"success":true,"issue":{"id":"i","identifier":"PER-1","title":"Done","state":{"id":"done","name":"Done","type":"completed","color":"#00ff00"}}}}}"##.utf8)
        XCTAssertEqual(try LinearClient.parseIssueStateUpdate(data).stateColor, "#00ff00")
    }

    /// Opt-in native captures exercise the exact production card, including real mouse expansion.
    func testRenderCards() async throws {
        guard let path = ProcessInfo.processInfo.environment["PTB_ISSUE_CARD_PREVIEW_DIR"] else {
            throw XCTSkip("Set PTB_ISSUE_CARD_PREVIEW_DIR for native card verification")
        }
        try XCTSkipIf(NSScreen.screens.isEmpty, "Requires the macOS display server")
        let directory = URL(fileURLWithPath: path)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let suite = "LinearIssueCardTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        let stateDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(suite)
        try FileManager.default.createDirectory(at: stateDirectory, withIntermediateDirectories: true)
        defer {
            defaults.removePersistentDomain(forName: suite)
            try? FileManager.default.removeItem(at: stateDirectory)
        }
        var state = CompanionState(); state.language = .en
        let file = stateDirectory.appendingPathComponent("companion.json")
        try JSONEncoder().encode(state).write(to: file)
        let companion = CompanionStore(provider: StubProvider(value: EvoLine(baseID: 1,
            tree: EvoNode(speciesID: 1, children: []), rarity: .common, names: [:])), fileURL: file, defaults: defaults)
        let usage = UsageStore(providers: [], autoRefresh: false, defaults: defaults,
            linearAPIKeys: LinearAPIKeyStore(fileURL: stateDirectory.appendingPathComponent("key.json")))
        let focus = FocusSessionStore(usage: usage, companion: companion,
            fileURL: stateDirectory.appendingPathComponent("focus.json"), ticksOnTimer: false)

        for scheme in [ColorScheme.dark, .light] {
            for all in [false, true] {
                for width: CGFloat in [340, 240, 620] {
                    var standaloneHeight: CGFloat = 0
                    for context in ["standalone", "project", "initiative", "other-project"] {
                        defaults.set(all, forKey: "linearIssueCardAllMetadata")
                        var issue = try Self.issue()
                        if !all {
                            issue.title = "Write up Weekly Reflection"
                            issue.identifier = "PER-240"
                            let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
                            var utc = Calendar(identifier: .gregorian); utc.timeZone = TimeZone(secondsFromGMT: 0)!
                            issue.dueDate = utc.date(from: Calendar.current.dateComponents([.year, .month, .day], from: tomorrow))
                        }
                        let nested = context != "standalone"
                        let parentID = context == "project" ? "routine" : (context == "other-project" ? "other" : nil)
                        let root = LinearIssueEntityRow(issue: issue, nested: nested, parentProjectID: parentID, onPin: {})
                            .padding(10).frame(width: width)
                            .background(scheme == .dark ? Color(red: 0.12, green: 0.13, blue: 0.135) : Color(white: 0.95))
                            .environment(usage).environment(companion).environment(focus)
                            .environment(\.colorScheme, scheme)
                            .defaultAppStorage(defaults)
                        let host = NSHostingView(rootView: root)
                        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: width, height: 400),
                                              styleMask: .borderless, backing: .buffered, defer: false)
                        window.isReleasedWhenClosed = false
                        window.appearance = NSAppearance(named: scheme == .dark ? .darkAqua : .aqua)
                        window.contentView = host
                        window.orderFrontRegardless()
                        defer { window.orderOut(nil); window.contentView = nil }
                        try await Task.sleep(for: .milliseconds(150))
                        host.setFrameSize(host.fittingSize)
                        host.layoutSubtreeIfNeeded()
                        let collapsedHeight = host.fittingSize.height
                        XCTAssertEqual(host.fittingSize.width, width, accuracy: 1)
                        XCTAssertGreaterThan(collapsedHeight, nested ? 50 : 80)
                        XCTAssertLessThan(collapsedHeight, 400)
                        if !nested { standaloneHeight = collapsedHeight }
                        if context == "project", !all, width >= 340 {
                            XCTAssertLessThan(collapsedHeight, standaloneHeight - 12,
                                              "Nested issues must reclaim height, not just hide a badge")
                        }
                        XCTAssertEqual(try containsProjectTint(host), context != "project",
                                       "Only the matching enclosing project may replace the project badge")
                        let prefix = nested ? context + "-" : ""
                        let name = "\(prefix)\(all ? "all" : "minimal")-\(scheme)-\(Int(width))"
                        try capture(host, to: directory.appendingPathComponent("\(name).png"))
                        if !all, width == 340 {
                            // Empty header space belongs to the expand button; ID/status remain separate controls.
                            let point = host.convert(NSPoint(x: 180, y: host.isFlipped ? 26 : host.bounds.height - 26), to: nil)
                            for type in [NSEvent.EventType.leftMouseDown, .leftMouseUp] {
                                window.sendEvent(try XCTUnwrap(NSEvent.mouseEvent(with: type, location: point,
                                    modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime,
                                    windowNumber: window.windowNumber, context: nil, eventNumber: 1,
                                    clickCount: 1, pressure: 1)))
                            }
                            try await Task.sleep(for: .milliseconds(250))
                            XCTAssertGreaterThan(host.fittingSize.height, collapsedHeight + 30,
                                                 "Clicking the native card must reveal its details and Focus action")
                            host.setFrameSize(host.fittingSize)
                            host.layoutSubtreeIfNeeded()
                            try capture(host, to: directory.appendingPathComponent("\(prefix)expanded-\(scheme).png"))
                            XCTAssertEqual(try containsProjectTint(host), context != "project",
                                           "Opening issue details must also respect inherited project context")
                            XCTAssertNil(focus.session, "Expanding a card must not start a focus session")
                        }
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

    private func containsProjectTint(_ host: NSView) throws -> Bool {
        let bitmap = try XCTUnwrap(host.bitmapImageRepForCachingDisplay(in: host.bounds))
        host.cacheDisplay(in: host.bounds, to: bitmap)
        // The fixture's green project glyph is distinct from its yellow status and blue labels.
        for y in 0..<bitmap.pixelsHigh {
            for x in 0..<bitmap.pixelsWide {
                guard let color = bitmap.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB) else { continue }
                if color.greenComponent > color.redComponent + 0.15,
                   color.greenComponent > color.blueComponent + 0.1,
                   color.blueComponent > color.redComponent + 0.08 { return true }
            }
        }
        return false
    }

    private static func issue() throws -> LinearIssueSummary {
        try LinearClient.parseIssueSummary([
            "id": "card", "identifier": "PER-199", "title": "Figure out Scrum Workflow Implementation",
            "url": "https://linear.app/example/issue/PER-199", "priority": 3, "estimate": 2,
            "state": ["id": "started", "name": "In Progress", "type": "started", "color": "#e5df00"],
            "assignee": ["name": "Alex Brown"],
            "project": ["id": "routine", "name": "Goal: Stick to a Routine", "color": "#45b785"],
            "team": ["key": "PER", "name": "Personal", "states": ["nodes": [
                ["id": "started", "name": "In Progress", "type": "started"],
                ["id": "done", "name": "Done", "type": "completed"],
            ]]],
            "labels": ["nodes": [["name": "Business Admin", "color": "#94a3b8"],
                                    ["name": "Plan & Organise", "color": "#22b8cf"]]],
            "createdAt": "2026-09-13T00:00:00Z", "updatedAt": "2026-09-19T00:00:00Z",
            "startedAt": "2026-09-13T00:00:00Z", "dueDate": "2026-09-13",
            "cycle": ["name": "Cycle 38", "number": 38], "projectMilestone": ["name": "Define the routine"],
            "description": "Decide on a small, practical workflow for the week.",
        ])
    }
}
