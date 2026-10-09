import AppKit
import SwiftUI
import XCTest
@testable import PokeTaskBar

@MainActor
private final class TimelineDragInfo: NSObject, NSDraggingInfo {
    let draggingDestinationWindow: NSWindow?
    let draggingPasteboard: NSPasteboard
    var draggingLocation: NSPoint
    var draggingSourceOperationMask: NSDragOperation { .copy }
    var draggedImageLocation: NSPoint { draggingLocation }
    nonisolated var draggedImage: NSImage? { nil }
    var draggingSource: Any? { nil }
    var draggingSequenceNumber: Int { 1 }
    var draggingFormation: NSDraggingFormation = .none
    var animatesToDestination = false
    var numberOfValidItemsForDrop = 1
    var springLoadingHighlight: NSSpringLoadingHighlight { .none }
    init(window: NSWindow, pasteboard: NSPasteboard, location: NSPoint) {
        draggingDestinationWindow = window; draggingPasteboard = pasteboard; draggingLocation = location
    }
    func slideDraggedImage(to screenPoint: NSPoint) {}
    nonisolated override func namesOfPromisedFilesDropped(atDestination dropDestination: URL) -> [String]? { nil }
    func resetSpringLoading() {}
    func enumerateDraggingItems(options: NSDraggingItemEnumerationOptions, for view: NSView?,
        classes classArray: [AnyClass], searchOptions: [NSPasteboard.ReadingOptionKey: Any],
        using block: (NSDraggingItem, Int, UnsafeMutablePointer<ObjCBool>) -> Void) {
        let items = draggingPasteboard.readObjects(forClasses: classArray, options: searchOptions) ?? []
        for (index, item) in items.enumerated() {
            guard let item = item as? NSPasteboardWriting else { continue }
            var stop: ObjCBool = false
            block(NSDraggingItem(pasteboardWriter: item), index, &stop)
            if stop.boolValue { break }
        }
    }
}

@MainActor
private final class NativeDragPayload {
    var issueID: String?
    var released = false
}

@MainActor
final class MainWindowTests: XCTestCase {
    func testIssueSubtabsKeepParentsAndExpandedChildrenWithinTheirStatus() async throws {
        try XCTSkipIf(NSScreen.screens.isEmpty, "Requires the macOS display server")
        let fixture = try Fixture(statusHierarchy: true); defer { fixture.remove() }
        await fixture.prepare()
        XCTAssertFalse(fixture.usage.allLinearIssues.contains { $0.id == "same-status" })
        func descendants(_ view: NSView) -> [NSView] { [view] + view.subviews.flatMap(descendants) }
        func cards(_ host: NSView) -> [LinearIssueDragView] {
            // Lazy stacks retain offscreen rows; check only the rendered cards.
            descendants(host).compactMap { $0 as? LinearIssueDragView }
                .filter { !$0.isHiddenOrHasHiddenAncestor && !$0.visibleRect.isEmpty }
        }
        let window = NSWindow(contentRect: NSRect(x: 300, y: 300, width: 640, height: 900),
            styleMask: .borderless, backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        defer { window.orderOut(nil); window.contentView = nil }
        let cases: [(LinearIssuesTab, String, Set<String>)] = [
            (.inProgress, "issue", ["issue", "same-status"]), (.todo, "todo", ["todo"]),
            (.planned, "planned", ["planned"]), (.completedToday, "completed", ["completed"]),
        ]
        for projectID in [String?.none, "project"] {
            fixture.nav.projectFilter = projectID
            if let projectID { try await fixture.usage.loadLinearProjectIssues(projectID: projectID) }
            let host = NSHostingView(rootView: MainWindowWorkspacesView(page: .issues)
                .padding(16).frame(width: 640, height: 900)
                .environment(fixture.usage).environment(fixture.companion).environment(fixture.focus)
                .environment(fixture.nav).defaultAppStorage(fixture.defaults))
            window.contentView = host; window.orderFrontRegardless()
            for (tab, rootID, expected) in cases {
                fixture.nav.issueExpansion = [:]
                fixture.nav.issuesTab = tab
                try await Task.sleep(for: .milliseconds(180))
                host.layoutSubtreeIfNeeded()
                XCTAssertEqual(cards(host).map(\.issueID), [rootID], "\(tab), project: \(projectID ?? "all")")
                XCTAssertTrue(try XCTUnwrap(cards(host).first).accessibilityPerformPress())
                try await Task.sleep(for: .milliseconds(180))
                host.layoutSubtreeIfNeeded()
                XCTAssertEqual(Set(cards(host).map(\.issueID)), expected, "Expanded \(tab) must exclude other statuses")
            }
        }
        let compact = NSHostingView(rootView: LinearIntegrationView(store: fixture.usage)
            .padding(16).frame(width: 640, height: 900)
            .environment(fixture.usage).environment(fixture.companion).environment(fixture.focus)
            .environment(fixture.nav.content).defaultAppStorage(fixture.defaults))
        window.contentView = compact
        try await Task.sleep(for: .milliseconds(180))
        for (index, item) in cases.enumerated() {
            let (tab, rootID, expected) = item
            try await click(window, in: compact, x: [70, 158, 236, 335][index], top: 105)
            try await Task.sleep(for: .milliseconds(180))
            compact.layoutSubtreeIfNeeded()
            XCTAssertEqual(cards(compact).map(\.issueID), [rootID], "Compact \(tab)")
            XCTAssertTrue(try XCTUnwrap(cards(compact).first).accessibilityPerformPress())
            try await Task.sleep(for: .milliseconds(180))
            compact.layoutSubtreeIfNeeded()
            XCTAssertEqual(Set(cards(compact).map(\.issueID)), expected, "Expanded compact \(tab)")
        }
    }

    func testV2NativeIssueWhitespaceStartsDrag() async throws {
        try XCTSkipIf(NSScreen.screens.isEmpty, "Requires the macOS display server")
        let fixture = try Fixture(); defer { fixture.remove() }
        await fixture.prepare()
        let issue = try XCTUnwrap(fixture.usage.linearInProgressIssues.first)
        let host = NSHostingView(rootView: LinearIssueEntityRow(issue: issue,
            minimization: Binding(get: { fixture.nav.issueMinimization[issue.id] ?? false },
                set: { fixture.nav.issueMinimization[issue.id] = $0 }),
            expansion: Binding(get: { fixture.nav.issueExpansion[issue.id] ?? false },
                set: { fixture.nav.issueExpansion[issue.id] = $0 }), onPin: {})
            .fixedSize(horizontal: false, vertical: true).padding(10).frame(width: 540)
            .environment(fixture.usage).environment(fixture.companion).environment(fixture.focus)
            .defaultAppStorage(fixture.defaults))
        let window = NSWindow(contentRect: NSRect(x: 300, y: 300, width: 540, height: 220),
            styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false; window.isMovableByWindowBackground = true
        window.contentView = host; window.orderFrontRegardless()
        defer { window.orderOut(nil); window.contentView = nil }
        try await Task.sleep(for: .milliseconds(250))
        host.setFrameSize(host.fittingSize); host.layoutSubtreeIfNeeded()
        let pasteboard = NSPasteboard(name: .drag)
        for (point, stationary) in [(NSPoint(x: 240, y: 25), false), (NSPoint(x: 240, y: 45), false),
                                    (NSPoint(x: 15, y: 45), false), (NSPoint(x: 240, y: 25), true)] {
            let origin = window.frame.origin
            let location = host.convert(NSPoint(x: point.x,
                y: host.isFlipped ? point.y : host.bounds.height - point.y), to: nil)
            let payload = try await nativeIssuePickup(window, at: location, stationary: stationary)
            XCTAssertEqual(payload, issue.id, "Whitespace at \(point), hold: \(stationary) must start the issue drag")
            XCTAssertEqual(window.frame.origin, origin, "Dragging an issue must not move the window")
            XCTAssertFalse(fixture.nav.issueExpansion[issue.id] ?? false, "Dragging must not expand the issue")
        }
        try await Task.sleep(for: .milliseconds(200))
        host.layoutSubtreeIfNeeded()
        let location = host.convert(NSPoint(x: 240, y: host.isFlipped ? 25 : host.bounds.height - 25), to: nil)
        func heldEvent(_ type: NSEvent.EventType, at point: NSPoint? = nil) throws -> NSEvent {
            try XCTUnwrap(NSEvent.mouseEvent(with: type, location: point ?? location, modifierFlags: [],
                timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: window.windowNumber,
                context: nil, eventNumber: 1, clickCount: 1, pressure: type == .leftMouseUp ? 0 : 1))
        }
        pasteboard.clearContents()
        try await click(window, in: host, x: 240, top: 45)
        XCTAssertEqual(fixture.nav.issueExpansion[issue.id], true, "A quick click still expands exactly once")
        XCTAssertNil(pasteboard.string(forType: .string), "Releasing a quick click cancels the pending drag")
        try await click(window, in: host, x: 240, top: 45)
        XCTAssertEqual(fixture.nav.issueExpansion[issue.id], false)
        try await click(window, in: host, x: 510, top: 48)
        XCTAssertEqual(fixture.nav.issueMinimization[issue.id], true, "Foreground controls keep their own click actions")
        XCTAssertEqual(fixture.nav.issueExpansion[issue.id], false)
        XCTAssertNil(fixture.focus.session)
        let local = NSPoint(x: 240, y: host.isFlipped ? 25 : host.bounds.height - 25)
        let source = try XCTUnwrap(host.hitTest(local) as? LinearIssueDragView)
        XCTAssertTrue(source.accessibilityPerformPress())
        XCTAssertEqual(fixture.nav.issueMinimization[issue.id], false)
        XCTAssertTrue(window.makeFirstResponder(source))
        for key: UInt16 in [49, 36] {
            window.sendEvent(try XCTUnwrap(NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [],
                timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: window.windowNumber, context: nil,
                characters: key == 49 ? " " : "\r", charactersIgnoringModifiers: key == 49 ? " " : "\r",
                isARepeat: false, keyCode: key)))
            XCTAssertEqual(fixture.nav.issueExpansion[issue.id], key == 49)
        }
        pasteboard.clearContents()
        try await Task.sleep(for: .milliseconds(200))
        let cancelPoint = source.convert(NSPoint(x: source.bounds.midX, y: source.bounds.midY), to: nil)
        window.sendEvent(try heldEvent(.leftMouseDown, at: cancelPoint))
        XCTAssertTrue(window.firstResponder === source, "A pointer press gives the card keyboard focus")
        window.sendEvent(try XCTUnwrap(NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [],
            timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: window.windowNumber, context: nil,
            characters: "\u{001B}", charactersIgnoringModifiers: "\u{001B}", isARepeat: false, keyCode: 53)))
        window.sendEvent(try heldEvent(.leftMouseUp, at: cancelPoint))
        try await Task.sleep(for: .milliseconds(200))
        XCTAssertNil(pasteboard.string(forType: .string), "Escape cancels a pending pickup")
        XCTAssertEqual(fixture.nav.issueExpansion[issue.id], false)
    }

    func testV2ParentUnfoldShowsChildAndChildUsesSharedFocusSession() async throws {
        try XCTSkipIf(NSScreen.screens.isEmpty, "Requires the macOS display server")
        let fixture = try Fixture(hierarchy: true); defer { fixture.remove() }
        await fixture.prepare()
        let parent = try XCTUnwrap(fixture.usage.linearInProgressIssues.first)
        let child = try XCTUnwrap(fixture.usage.linearTodoIssues.first)
        XCTAssertEqual(child.parentID, parent.id)
        XCTAssertEqual(LinearIssueHierarchy.roots([parent, child], in: fixture.usage.allLinearIssues).map(\.id), [parent.id])
        let host = NSHostingView(rootView: LinearIssueEntityRow(issue: parent,
            expansion: Binding(get: { fixture.nav.issueExpansion[parent.id] ?? false },
                set: { fixture.nav.issueExpansion[parent.id] = $0 }), onPin: { fixture.nav.select(.focus) })
            .fixedSize(horizontal: false, vertical: true).padding(10).frame(width: 540).environment(fixture.usage).environment(fixture.companion)
            .environment(fixture.focus).defaultAppStorage(fixture.defaults))
        let window = NSWindow(contentRect: NSRect(x: 300, y: 300, width: 540, height: 700),
            styleMask: .borderless, backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false; window.contentView = host; window.orderFrontRegardless()
        defer { window.orderOut(nil); window.contentView = nil }
        try await Task.sleep(for: .milliseconds(200))
        host.setFrameSize(host.fittingSize); host.layoutSubtreeIfNeeded()
        let foldedHeight = host.fittingSize.height
        try await click(window, in: host, x: 240, top: 45)
        host.setFrameSize(host.fittingSize); host.layoutSubtreeIfNeeded()
        XCTAssertEqual(fixture.nav.issueExpansion[parent.id], true)
        XCTAssertGreaterThan(host.fittingSize.height, foldedHeight + 100)
        XCTAssertNil(fixture.focus.session, "Expanding a parent must not start a timer")
        fixture.focus.pin(child, openDesk: false, minutes: 25)
        XCTAssertEqual(fixture.focus.session?.issue.id, child.id)
        XCTAssertEqual(fixture.focus.session?.issue.title, child.title)
        XCTAssertEqual(fixture.focus.session?.issue.completedStateId, "done")
        await fixture.focus.plan.move(child, to: .today, usage: fixture.usage)
        XCTAssertEqual(fixture.focus.plan.entry(child.id)?.group, .today)
        XCTAssertNil(fixture.focus.plan.entry(parent.id), "Planning a child must not move its parent")
        try await click(window, in: host, x: 240, top: 45)
        XCTAssertEqual(fixture.nav.issueExpansion[parent.id], false)
        XCTAssertEqual(host.fittingSize.height, foldedHeight, accuracy: 1)
        XCTAssertEqual(fixture.focus.session?.issue.id, child.id)
        let project = try XCTUnwrap(fixture.usage.linearProjects.first { $0.id == "project" })
        let projectHost = NSHostingView(rootView: LinearProjectCard(project: project,
            expansion: Binding(get: { fixture.nav.projectExpansion[project.id] ?? false },
                set: { fixture.nav.projectExpansion[project.id] = $0 }), onPin: {})
            .fixedSize(horizontal: false, vertical: true).frame(width: 540)
            .environment(fixture.usage).environment(fixture.companion).environment(fixture.focus))
        window.contentView = projectHost
        try await Task.sleep(for: .milliseconds(200))
        projectHost.setFrameSize(projectHost.fittingSize)
        let closedProjectHeight = projectHost.fittingSize.height
        try await click(window, in: projectHost, x: 240, top: 36)
        XCTAssertEqual(fixture.nav.projectExpansion[project.id], true)
        XCTAssertGreaterThan(projectHost.fittingSize.height, closedProjectHeight + 70)
    }

    func testRenderV2RevisedTodayAndSubIssues() async throws {
        guard let path = ProcessInfo.processInfo.environment["PTB_V2_REVISION_PREVIEW_DIR"] else {
            throw XCTSkip("Set PTB_V2_REVISION_PREVIEW_DIR for revised native previews")
        }
        let fixture = try Fixture(hierarchy: true); defer { fixture.remove() }
        fixture.now = Date()
        await fixture.prepare()
        let tray = try Fixture(); defer { tray.remove() }
        tray.now = Date(); await tray.prepare()
        let directory = URL(fileURLWithPath: path)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        fixture.usage.todayDeskLayout.rightWidth = 300
        tray.usage.todayDeskLayout.rightWidth = 300
        for scheme in [ColorScheme.light, .dark] {
            tray.nav.select(.today)
            try await render(tray, scheme: scheme, name: "v2-revised-today-\(scheme)", height: 1080, directory: directory)
            fixture.nav.select(.issues)
            fixture.nav.issueExpansion["issue"] = true
            try await render(fixture, scheme: scheme, name: "v2-sub-issues-\(scheme)", directory: directory)
        }
    }

    func testV2NativeCalendarChoosesDayWithoutChangingSession() async throws {
        try XCTSkipIf(NSScreen.screens.isEmpty, "Requires the macOS display server")
        let fixture = try Fixture(); defer { fixture.remove() }
        await fixture.prepare()
        fixture.focus.startPomodoro()
        let beforeSession = fixture.focus.session
        let beforeDay = fixture.focus.plan.selectedDay
        let host = NSHostingView(rootView: MainWindowView().environment(fixture.usage)
            .environment(fixture.companion).environment(fixture.focus).environment(fixture.nav)
            .environment(UpdateChecker()).defaultAppStorage(fixture.defaults))
        let window = NSWindow(contentRect: NSRect(x: 100, y: 100, width: 1280, height: 860),
            styleMask: .borderless, backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false; window.contentView = host; window.orderFrontRegardless()
        defer { window.orderOut(nil); window.contentView = nil }
        try await Task.sleep(for: .milliseconds(200))
        let existing = Set(NSApp.windows.filter(\.isVisible).map(\.windowNumber))
        try await click(window, in: host, x: 350, top: 167)
        let popup = try XCTUnwrap(NSApp.windows.first { $0.isVisible && !existing.contains($0.windowNumber) })
        defer { popup.orderOut(nil) }
        func descendants(_ view: NSView) -> [NSView] { [view] + view.subviews.flatMap(descendants) }
        let picker = try XCTUnwrap(descendants(try XCTUnwrap(popup.contentView)).compactMap { $0 as? NSDatePicker }.first)
        XCTAssertEqual(picker.datePickerStyle, .clockAndCalendar)
        if let path = ProcessInfo.processInfo.environment["PTB_V2_REVISION_PREVIEW_DIR"] {
            // NSDatePicker draws through native layers; capture the visible popup rather than its backing bitmap.
            let capture = Process()
            capture.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
            capture.arguments = ["-x", "-l", String(popup.windowNumber),
                URL(fileURLWithPath: path).appendingPathComponent("v2-planning-calendar.png").path]
            try capture.run(); capture.waitUntilExit()
            XCTAssertEqual(capture.terminationStatus, 0)
        }
        picker.dateValue = try XCTUnwrap(Calendar.current.date(byAdding: .day, value: 1, to: beforeDay))
        if let action = picker.action { picker.sendAction(action, to: picker.target) }
        try await Task.sleep(for: .milliseconds(200))
        XCTAssertEqual(fixture.focus.plan.dayKey, TaskPlanningStore.dayKey(picker.dateValue))
        XCTAssertNotEqual(fixture.focus.plan.dayKey, TaskPlanningStore.dayKey(beforeDay))
        XCTAssertEqual(fixture.focus.session, beforeSession)
    }

    func testRenderV2PlannerAndInsights() async throws {
        guard let path = ProcessInfo.processInfo.environment["PTB_V2_PREVIEW_DIR"] else {
            throw XCTSkip("Set PTB_V2_PREVIEW_DIR for native v2 visual verification")
        }
        let fixture = try Fixture(); defer { fixture.remove() }
        fixture.now = Date().addingTimeInterval(-3600)
        await fixture.prepare()
        let issues = TaskPlanningStore.issues(in: fixture.usage)
        XCTAssertEqual(issues.count, 3)
        await fixture.focus.plan.move(issues[0], to: .today, usage: fixture.usage)
        await fixture.focus.plan.move(issues[1], to: .soon, usage: fixture.usage)
        await fixture.focus.plan.move(issues[2], to: .later, usage: fixture.usage)
        let block = try XCTUnwrap(fixture.focus.plan.schedule(issues[0], start: 570, duration: 50))
        _ = fixture.focus.plan.schedule(issues[1], start: 660, duration: 30)
        // Return the scheduled second task to Soon without changing its saved block.
        await fixture.focus.plan.move(issues[1], to: .soon, usage: fixture.usage)
        fixture.focus.pin(issues[0], openDesk: false, minutes: 50, blockID: block.id)
        fixture.now = fixture.now.addingTimeInterval(1200)
        fixture.focus.finishLeavingInProgress()
        fixture.focus.pin(issues[1], openDesk: false, minutes: 25)
        fixture.now = fixture.now.addingTimeInterval(600)
        fixture.focus.finishLeavingInProgress()
        let directory = URL(fileURLWithPath: path)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        fixture.usage.todayDeskLayout.rightWidth = 300
        for scheme in [ColorScheme.light, .dark] {
            fixture.nav.select(.today)
            try await render(fixture, scheme: scheme, name: "v2-today-\(scheme)", directory: directory)
            fixture.nav.select(.insights)
            try await render(fixture, scheme: scheme, name: "v2-insights-\(scheme)", directory: directory)
            fixture.nav.select(.projects)
            fixture.nav.projectExpansion["project"] = true
            try await render(fixture, scheme: scheme, name: "v2-projects-\(scheme)", directory: directory)
        }
        fixture.nav.select(.today)
        fixture.usage.todayDeskLayout.leftCollapsed = true
        fixture.focus.plan.fold(.soon); fixture.focus.plan.fold(.later)
        try await render(fixture, scheme: .dark, name: "v2-icon-rail", width: 860, height: 620, directory: directory)
        fixture.usage.todayDeskLayout.rightCollapsed = true
        try await render(fixture, scheme: .dark, name: "v2-panels-folded", width: 860, height: 620, directory: directory)
    }

    func testV2FloatingTimerFixedClockAndNativePause() async throws {
        try XCTSkipIf(NSScreen.screens.isEmpty, "Requires access to the macOS display server")
        let fixture = try Fixture(); defer { fixture.remove() }
        await fixture.prepare()
        fixture.focus.pin(try XCTUnwrap(fixture.usage.linearInProgressIssues.first), openDesk: false, minutes: 50)
        let directory = ProcessInfo.processInfo.environment["PTB_V2_PREVIEW_DIR"].map { URL(fileURLWithPath: $0) }
        for width in [288.0, 384.0] {
            fixture.usage.floatingTimerWidth = width
            var bitmaps: [NSBitmapImageRep] = []
            for hovering in [false, true] {
                let host = NSHostingView(rootView: FloatingTimerStrip(hovering: hovering)
                    .environment(fixture.usage).environment(fixture.companion).environment(fixture.focus)
                    .environment(\.colorScheme, .dark))
                let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: width, height: 42),
                    styleMask: .borderless, backing: .buffered, defer: false)
                window.isReleasedWhenClosed = false
                window.appearance = NSAppearance(named: .darkAqua)
                window.contentView = host
                window.orderFrontRegardless()
                defer { window.orderOut(nil); window.contentView = nil }
                try await Task.sleep(for: .milliseconds(180))
                host.layoutSubtreeIfNeeded()
                let bitmap = try XCTUnwrap(host.bitmapImageRepForCachingDisplay(in: host.bounds))
                host.cacheDisplay(in: host.bounds, to: bitmap)
                bitmaps.append(bitmap)
                if let directory {
                    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                    try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
                        .write(to: directory.appendingPathComponent("v2-timer-\(Int(width))-\(hovering ? "hover" : "rest").png"))
                }
                if hovering {
                    let before = fixture.focus.session?.userPaused ?? false
                    try await click(window, in: host, x: 117.5, top: 21)
                    XCTAssertEqual(fixture.focus.session?.userPaused, !before, "\(width): Pause accepts a native click in the title slot")
                    if fixture.focus.session?.userPaused == true { fixture.focus.togglePause() }
                    if width == 384, let path = ProcessInfo.processInfo.environment["PTB_V2_REVISION_PREVIEW_DIR"] {
                        let existing = Set(NSApp.windows.filter(\.isVisible).map(\.windowNumber))
                        try await click(window, in: host, x: 317, top: 21)
                        let popup = try XCTUnwrap(NSApp.windows.first { $0.isVisible && !existing.contains($0.windowNumber) })
                        let content = try XCTUnwrap(popup.contentView)
                        let menuBitmap = try XCTUnwrap(content.bitmapImageRepForCachingDisplay(in: content.bounds))
                        content.cacheDisplay(in: content.bounds, to: menuBitmap)
                        try menuBitmap.representation(using: .png, properties: [:])?.write(to:
                            URL(fileURLWithPath: path).appendingPathComponent("v2-timer-more-menu.png"))
                        popup.close()
                    }
                }
            }
            XCTAssertEqual(bitmaps[0].pixelsWide, bitmaps[1].pixelsWide)
            XCTAssertEqual(bitmaps[0].pixelsHigh, bitmaps[1].pixelsHigh)
            let scale = bitmaps[0].pixelsWide / Int(width)
            for x in (22 * scale)..<(93 * scale) {
                for y in (8 * scale)..<(32 * scale) {
                    XCTAssertEqual(bitmaps[0].colorAt(x: x, y: y), bitmaps[1].colorAt(x: x, y: y),
                        "Hover must not move or redraw the clock")
                }
            }
        }
    }

    func testV2NativeFoldAndTimeBlockMoveResizeCancel() async throws {
        try XCTSkipIf(NSScreen.screens.isEmpty, "Requires access to the macOS display server")
        let fixture = try Fixture(); defer { fixture.remove() }
        fixture.now = Calendar.current.startOfDay(for: Date())
        await fixture.prepare()
        let issue = try XCTUnwrap(fixture.usage.linearInProgressIssues.first)
        await fixture.focus.plan.move(issue, to: .today, usage: fixture.usage)
        _ = try XCTUnwrap(fixture.focus.plan.schedule(issue, start: 570, duration: 50))
        fixture.usage.todayDeskLayout.rightWidth = 300
        let host = NSHostingView(rootView: MainWindowView()
            .environment(fixture.usage).environment(fixture.companion).environment(fixture.focus)
            .environment(fixture.nav).environment(UpdateChecker()).defaultAppStorage(fixture.defaults))
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1280, height: 860),
            styleMask: .borderless, backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false; window.contentView = host; window.orderFrontRegardless()
        defer { window.orderOut(nil); window.contentView = nil }
        func settle() async throws { try await Task.sleep(for: .milliseconds(250)); host.layoutSubtreeIfNeeded() }
        func event(_ type: NSEvent.EventType, x: CGFloat, top: CGFloat) throws {
            let point = host.convert(NSPoint(x: x, y: host.isFlipped ? top : host.bounds.height - top), to: nil)
            window.sendEvent(try XCTUnwrap(NSEvent.mouseEvent(with: type, location: point,
                modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime,
                windowNumber: window.windowNumber, context: nil, eventNumber: 1, clickCount: 1, pressure: 1)))
        }
        try await settle()
        try await click(window, in: host, x: 330, top: 311)
        XCTAssertTrue(fixture.focus.plan.folded.contains(.today))
        try await click(window, in: host, x: 330, top: 311)
        XCTAssertFalse(fixture.focus.plan.folded.contains(.today))
        try await settle()
        if let path = ProcessInfo.processInfo.environment["PTB_V2_TIMELINE_DEBUG_DIR"] {
            let bitmap = try XCTUnwrap(host.bitmapImageRepForCachingDisplay(in: host.bounds))
            host.cacheDisplay(in: host.bounds, to: bitmap)
            try bitmap.representation(using: .png, properties: [:])?.write(to:
                URL(fileURLWithPath: path).appendingPathComponent("timeline-drag-start.png"))
        }
        try event(.leftMouseDown, x: 1100, top: 280)
        for delta: CGFloat in [10, 20, 15, 25, 30] {
            try event(.leftMouseDragged, x: 1100, top: 280 + delta)
            try await settle()
        }
        try event(.leftMouseUp, x: 1100, top: 310)
        try await settle()
        XCTAssertEqual(fixture.focus.plan.blocks.first?.startMinute, 600, "Native block drag moves by 30 minutes")
        // The moved block is 50 pt high; its lower edge is now near 340.
        try event(.leftMouseDown, x: 1150, top: 339)
        for delta: CGFloat in [5, 10, 15, 20] {
            try event(.leftMouseDragged, x: 1150, top: 339 + delta)
            try await settle()
        }
        try event(.leftMouseUp, x: 1150, top: 359)
        try await settle()
        XCTAssertEqual(fixture.focus.plan.blocks.first?.durationMinutes, 70, "Native lower-edge drag resizes by 20 minutes")
        let beforeCancel = try XCTUnwrap(fixture.focus.plan.blocks.first)
        try event(.leftMouseDown, x: 1100, top: 310)
        try event(.leftMouseDragged, x: 1100, top: 340)
        window.sendEvent(try XCTUnwrap(NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [],
            timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: window.windowNumber, context: nil,
            characters: "\u{001B}", charactersIgnoringModifiers: "\u{001B}", isARepeat: false, keyCode: 53)))
        try event(.leftMouseUp, x: 1100, top: 340)
        try await settle()
        XCTAssertEqual(fixture.focus.plan.blocks.first, beforeCancel, "Escape discards the in-progress drag")
        fixture.focus.plan.undoBlock()
        XCTAssertEqual(fixture.focus.plan.blocks.first?.durationMinutes, 50)
        XCTAssertFalse(fixture.focus.plan.canUndoBlock)
    }

    func testV2NativeIssueWhitespaceDragDropsIntoPrioritiesAndTimeline() async throws {
        try XCTSkipIf(NSScreen.screens.isEmpty, "Requires the macOS display server")
        let fixture = try Fixture(); defer { fixture.remove() }
        await fixture.prepare()
        let host = NSHostingView(rootView: MainWindowView().environment(fixture.usage)
            .environment(fixture.companion).environment(fixture.focus).environment(fixture.nav)
            .environment(UpdateChecker()).defaultAppStorage(fixture.defaults))
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1280, height: 860),
            styleMask: .borderless, backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false; window.isMovableByWindowBackground = true
        window.contentView = host; window.orderFrontRegardless()
        defer { window.orderOut(nil); window.contentView = nil }
        try await Task.sleep(for: .milliseconds(250))
        func descendants(_ view: NSView) -> [NSView] { [view] + view.subviews.flatMap(descendants) }
        let source = try XCTUnwrap(descendants(host).compactMap { $0 as? LinearIssueDragView }.first { $0.issueID == "issue" })
        let point = source.convert(NSPoint(x: source.bounds.midX, y: source.bounds.midY), to: nil)
        let pickup = try await nativeIssuePickup(window, at: point)
        let payload = try XCTUnwrap(pickup)
        XCTAssertEqual(payload, "issue")
        let pasteboard = NSPasteboard.withUniqueName()
        defer { pasteboard.releaseGlobally() }
        pasteboard.writeObjects([payload as NSString])
        let targets = descendants(host).filter { !$0.registeredDraggedTypes.isEmpty && $0.bounds.width > 400 }
            .sorted { $0.convert($0.bounds, to: host).minY < $1.convert($1.bounds, to: host).minY }
        XCTAssertEqual(targets.count, 3)
        for (group, destination) in zip(PlanningGroup.allCases, targets) {
            let info = TimelineDragInfo(window: window, pasteboard: pasteboard,
                location: destination.convert(NSPoint(x: destination.bounds.midX, y: destination.bounds.midY), to: nil))
            XCTAssertEqual(destination.draggingEntered(info), .copy)
            try await Task.sleep(for: .milliseconds(150))
            XCTAssertTrue(destination.prepareForDragOperation(info))
            XCTAssertTrue(destination.performDragOperation(info))
            destination.concludeDragOperation(info)
            try await Task.sleep(for: .milliseconds(250))
            XCTAssertEqual(fixture.focus.plan.entry("issue")?.group, group)
            XCTAssertEqual(fixture.focus.plan.entry("issue")?.day, group == .today ? fixture.focus.plan.dayKey : nil)
            XCTAssertEqual(fixture.usage.linearIssue(id: "issue")?.stateName, "In Progress")
            XCTAssertNil(fixture.focus.session)
        }
        let timeline = try XCTUnwrap(descendants(host).first { !$0.registeredDraggedTypes.isEmpty && $0.bounds.height == 1440 })
        let info = TimelineDragInfo(window: window, pasteboard: pasteboard,
            location: timeline.convert(NSPoint(x: 100, y: timeline.isFlipped ? 663 : 777), to: nil))
        XCTAssertEqual(timeline.draggingEntered(info), .copy)
        try await Task.sleep(for: .milliseconds(150))
        XCTAssertTrue(timeline.prepareForDragOperation(info))
        XCTAssertTrue(timeline.performDragOperation(info))
        timeline.concludeDragOperation(info)
        try await Task.sleep(for: .milliseconds(250))
        XCTAssertEqual(fixture.focus.plan.blocks.first?.issueID, "issue")
        XCTAssertEqual(fixture.focus.plan.blocks.first?.startMinute, 665)
        XCTAssertEqual(fixture.focus.plan.entry("issue")?.group, .today)
        XCTAssertNil(fixture.focus.session)
    }

    func testV2NativeIssueDropOntoTimeline() async throws {
        try XCTSkipIf(NSScreen.screens.isEmpty, "Requires the macOS display server")
        let fixture = try Fixture(); defer { fixture.remove() }
        fixture.now = Calendar.current.startOfDay(for: Date())
        await fixture.prepare()
        fixture.usage.todayDeskLayout.rightWidth = 300
        let host = NSHostingView(rootView: MainWindowView().environment(fixture.usage)
            .environment(fixture.companion).environment(fixture.focus).environment(fixture.nav)
            .environment(UpdateChecker()).defaultAppStorage(fixture.defaults))
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1280, height: 860),
            styleMask: .borderless, backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false; window.contentView = host; window.orderFrontRegardless()
        defer { window.orderOut(nil); window.contentView = nil }
        try await Task.sleep(for: .milliseconds(250))
        try await click(window, in: host, x: 350, top: 584)
        XCTAssertEqual(fixture.nav.planningIssueFolded, [.today])
        XCTAssertTrue(fixture.focus.plan.folded.isEmpty, "Status disclosures are independent of personal priorities")
        try await click(window, in: host, x: 350, top: 584)
        XCTAssertTrue(fixture.nav.planningIssueFolded.isEmpty)
        func descendants(_ view: NSView) -> [NSView] { [view] + view.subviews.flatMap(descendants) }
        let destination = try XCTUnwrap(descendants(host).first {
            !$0.registeredDraggedTypes.isEmpty && $0.bounds.height == 1440
        })
        let pasteboard = NSPasteboard.withUniqueName()
        defer { pasteboard.releaseGlobally() }
        XCTAssertTrue(pasteboard.writeObjects(["todo" as NSString]))
        let info = TimelineDragInfo(window: window, pasteboard: pasteboard,
            location: destination.convert(NSPoint(x: 100, y: destination.isFlipped ? 663 : 777), to: nil))
        XCTAssertEqual(destination.draggingEntered(info), .copy)
        try await Task.sleep(for: .milliseconds(150))
        XCTAssertEqual(destination.draggingUpdated(info), .copy)
        XCTAssertTrue(destination.prepareForDragOperation(info))
        XCTAssertTrue(destination.performDragOperation(info))
        destination.concludeDragOperation(info)
        try await Task.sleep(for: .milliseconds(250))
        XCTAssertEqual(fixture.focus.plan.blocks.first?.issueID, "todo")
        XCTAssertEqual(fixture.focus.plan.blocks.first?.startMinute, 665)
        XCTAssertEqual(fixture.focus.plan.entry("todo")?.group, .today)
        XCTAssertEqual(fixture.usage.linearIssue(id: "todo")?.stateName, "Todo")
        XCTAssertNil(fixture.focus.session, "Scheduling must not start the focus timer")
        pasteboard.clearContents()
        XCTAssertTrue(pasteboard.writeObjects(["planned" as NSString]))
        XCTAssertEqual(destination.draggingEntered(info), .copy)
        try await Task.sleep(for: .milliseconds(150))
        XCTAssertTrue(destination.performDragOperation(info))
        destination.concludeDragOperation(info)
        try await Task.sleep(for: .milliseconds(250))
        XCTAssertEqual(fixture.focus.plan.blocks.count, 1, "An overlapping drop is rejected")
        XCTAssertNotNil(fixture.focus.plan.blockError)
        XCTAssertNil(fixture.focus.plan.entry("planned"))
        fixture.focus.plan.undoBlock()
        XCTAssertTrue(fixture.focus.plan.blocks.isEmpty)
        XCTAssertNil(fixture.focus.plan.entry("todo"))
        var ancestor: NSView? = destination.superview
        while ancestor != nil && !(ancestor is NSScrollView) { ancestor = ancestor?.superview }
        let scroll = try XCTUnwrap(ancestor as? NSScrollView)
        let wheel = try XCTUnwrap(CGEvent(scrollWheelEvent2Source: nil, units: .pixel,
            wheelCount: 1, wheel1: -180, wheel2: 0, wheel3: 0))
        scroll.scrollWheel(with: try XCTUnwrap(NSEvent(cgEvent: wheel)))
        try await Task.sleep(for: .milliseconds(250))
        XCTAssertEqual(fixture.focus.plan.timelineHour, 11, "Scrolling retains the visible timeline hour")
        fixture.usage.todayDeskLayout.rightCollapsed = true
        try await Task.sleep(for: .milliseconds(250))
        fixture.usage.todayDeskLayout.rightCollapsed = false
        try await Task.sleep(for: .milliseconds(350))
        let restored = try XCTUnwrap(descendants(host).compactMap { $0 as? NSScrollView }.first {
            ($0.documentView?.bounds.height ?? 0) > 1400 && $0.bounds.width < 350
        })
        XCTAssertEqual(restored.documentVisibleRect.minY, 668, accuracy: 2, "Unfolding restores the actual viewport")
    }

    func testNavigationHistoryPreservesCollectionSelection() {
        let nav = MainWindowNavigation()
        nav.select(.collection)
        nav.content.collectionSegment = .storage
        nav.selectedStorageID = "saved-individual"
        nav.select(.issues)
        nav.back()
        XCTAssertEqual(nav.page, .collection)
        XCTAssertEqual(nav.content.tab, .collection)
        XCTAssertEqual(nav.content.collectionSegment, .storage)
        XCTAssertEqual(nav.selectedStorageID, "saved-individual")
        nav.forward()
        XCTAssertEqual(nav.page, .issues)
        nav.back(); nav.select(.usage)
        XCTAssertFalse(nav.canGoForward)
    }

    func testProjectRouteAndNavigationDoNotStartOrResetTimer() throws {
        let fixture = try Fixture(); defer { fixture.remove() }
        fixture.focus.plannedMinutes = 25
        fixture.focus.startPomodoro()
        let original = try XCTUnwrap(fixture.focus.session)
        let project = LinearProjectSummary(id: "p", name: "Main window", issues: [])
        fixture.nav.showProjectIssues(project)
        fixture.usage.todayDeskLayout = fixture.usage.todayDeskLayout.togglingLeft().togglingRight()
        fixture.nav.select(.settings); fixture.nav.back()
        XCTAssertEqual(fixture.nav.page, .issues)
        XCTAssertEqual(fixture.nav.projectFilter, "p")
        XCTAssertEqual(fixture.focus.session?.issue.id, original.issue.id)
        XCTAssertEqual(fixture.focus.session?.plannedSeconds, original.plannedSeconds)
        XCTAssertEqual(fixture.focus.clockDisplay().text, "25:00")
    }

    func testShopPurchaseBanksEggAndPreservesTrainingPartner() throws {
        let fixture = try Fixture(); defer { fixture.remove() }
        let current = fixture.companion.currentSpeciesID
        let before = fixture.companion.availableCoins
        let price = fixture.companion.price(of: .egg(nil))
        XCTAssertTrue(fixture.companion.buyEgg(nil))
        XCTAssertEqual(fixture.companion.currentSpeciesID, current)
        XCTAssertEqual(fixture.companion.availableCoins, before - price)
        XCTAssertEqual(fixture.companion.storedCompanions.filter(\.isEgg).count, 2)
        XCTAssertFalse(fixture.companion.canBuy(.shinyCharm))
    }

    func testNativeNavigationCollapseResizeAndClosePreserveSession() async throws {
        try XCTSkipIf(NSScreen.screens.isEmpty, "Requires access to the macOS display server")
        let fixture = try Fixture(); defer { fixture.remove() }
        fixture.focus.startPomodoro()
        let original = try XCTUnwrap(fixture.focus.session)
        let host = NSHostingView(rootView: MainWindowView()
            .environment(fixture.usage).environment(fixture.companion).environment(fixture.focus)
            .environment(fixture.nav).environment(UpdateChecker()).defaultAppStorage(fixture.defaults))
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1280, height: 860),
                              styleMask: .borderless, backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = host
        window.orderFrontRegardless()
        defer { window.orderOut(nil); window.contentView = nil }
        func settle() async throws { try await Task.sleep(for: .milliseconds(250)); host.layoutSubtreeIfNeeded() }
        func event(_ type: NSEvent.EventType, x: CGFloat, top: CGFloat) throws {
            let point = host.convert(NSPoint(x: x, y: host.isFlipped ? top : host.bounds.height - top), to: nil)
            window.sendEvent(try XCTUnwrap(NSEvent.mouseEvent(with: type, location: point,
                modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime,
                windowNumber: window.windowNumber, context: nil, eventNumber: 1, clickCount: 1, pressure: 1)))
        }
        func click(x: CGFloat, top: CGFloat) async throws {
            try await self.click(window, in: host, x: x, top: top)
            try await settle()
        }
        try await settle()
        try await click(x: 1245, top: 74)
        XCTAssertFalse(fixture.usage.todayDeskLayout.rightCollapsed,
                       "The Day plan header must not duplicate the toolbar fold control")
        fixture.usage.todayDeskLayout.rightCollapsed = false
        try await settle()
        try await click(x: 1245, top: 24)
        XCTAssertTrue(fixture.usage.todayDeskLayout.rightCollapsed)
        try await click(x: 1245, top: 24)
        XCTAssertFalse(fixture.usage.todayDeskLayout.rightCollapsed,
                       "The top control must also reopen the timeline")
        try await click(x: 100, top: 341)
        XCTAssertEqual(fixture.nav.page, .projects, "The native navigation row must route the main window")
        try await click(x: 1245, top: 24)
        XCTAssertTrue(fixture.usage.todayDeskLayout.rightCollapsed)
        try event(.leftMouseDown, x: 230, top: 450)
        for delta: CGFloat in [16, 32, 24, 40, 48] {
            try event(.leftMouseDragged, x: 230 + delta, top: 450)
            try await settle()
        }
        try event(.leftMouseUp, x: 278, top: 450)
        try await settle()
        XCTAssertGreaterThan(fixture.usage.todayDeskLayout.leftWidth, TodayDeskMetrics.leftSidebarWidth,
                             "Native drag must resize; event coalescing can shorten the synthetic translation")
        XCTAssertEqual(fixture.defaults.double(forKey: "todayDeskLeftWidth"), fixture.usage.todayDeskLayout.leftWidth)
        try await click(x: 102, top: 24)
        XCTAssertTrue(fixture.usage.todayDeskLayout.leftCollapsed)
        try await click(x: 140, top: 24)
        XCTAssertEqual(fixture.nav.page, .today)
        XCTAssertEqual(fixture.focus.session?.issue.id, original.issue.id)
        XCTAssertEqual(fixture.focus.session?.plannedSeconds, original.plannedSeconds)
        window.close()
        XCTAssertNotNil(fixture.focus.session)
    }

    /// Actual SwiftUI renders, with isolated credentials, state and an injected Linear transport.
    func testRenderMainWindow() async throws {
        guard let path = ProcessInfo.processInfo.environment["PTB_MAIN_WINDOW_PREVIEW_DIR"] else {
            throw XCTSkip("Set PTB_MAIN_WINDOW_PREVIEW_DIR for native visual verification")
        }
        let fixture = try Fixture(); defer { fixture.remove() }
        await fixture.prepare()
        let directory = URL(fileURLWithPath: path)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        for scheme in [ColorScheme.light, .dark] {
            fixture.nav.select(.today)
            try await render(fixture, scheme: scheme, name: "today-\(scheme)", directory: directory)
        }
        fixture.usage.todayDeskLayout = fixture.usage.todayDeskLayout.togglingLeft().togglingRight()
        try await render(fixture, name: "today-collapsed", width: 860, height: 620, directory: directory)
        fixture.usage.todayDeskLayout = .default
        for page in [MainWindowPage.issues, .projects, .initiatives, .usage, .settings] {
            fixture.nav.select(page)
            try await render(fixture, name: page.rawValue, directory: directory)
        }
        fixture.nav.select(.collection)
        fixture.usage.todayDeskLayout = fixture.usage.todayDeskLayout.togglingRight()
        for segment in CollectionSegment.allCases {
            fixture.nav.content.collectionSegment = segment
            try await render(fixture, name: "collection-\(segment)", directory: directory)
        }
        fixture.nav.content.collectionSegment = .dex
        fixture.nav.content.showingCollectionLog = true
        try await render(fixture, name: "catch-log", directory: directory)
        fixture.nav.select(.focus)
        fixture.focus.pin(try XCTUnwrap(fixture.usage.linearInProgressIssues.first), openDesk: false, minutes: 25)
        try await render(fixture, name: "focus", directory: directory)
        fixture.focus.togglePause()
        XCTAssertTrue(try XCTUnwrap(fixture.focus.session).userPaused)
        try await render(fixture, scheme: .dark, name: "focus-paused-dark", directory: directory)
    }

    func testRenderProjectControlsAtNarrowAndWideWindowSizes() async throws {
        guard let path = ProcessInfo.processInfo.environment["PTB_PROJECT_CONTROLS_PREVIEW_DIR"] else {
            throw XCTSkip("Set PTB_PROJECT_CONTROLS_PREVIEW_DIR for project toolbar verification")
        }
        let fixture = try Fixture(); defer { fixture.remove() }
        await fixture.prepare()
        let directory = URL(fileURLWithPath: path)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        fixture.nav.select(.projects)
        XCTAssertEqual(fixture.usage.linearProjectStatuses.count, 9)
        fixture.usage.toggleLinearProjectPin(try XCTUnwrap(fixture.usage.linearProjects.last))
        fixture.usage.toggleLinearInitiativePin(try XCTUnwrap(fixture.usage.linearInitiatives.last))
        for scheme in [ColorScheme.light, .dark] {
            fixture.nav.projectSort = .targetDate
            fixture.usage.hiddenLinearIssueStatuses = ["completed:done"]
            fixture.defaults.set(false, forKey: "mainWindowProjectsGrid")
            try await render(fixture, scheme: scheme, name: "projects-list-\(scheme)", width: 860, height: 680, directory: directory)
            fixture.defaults.set(true, forKey: "mainWindowProjectsGrid")
            try await render(fixture, scheme: scheme, name: "projects-grid-\(scheme)", directory: directory)
        }
        fixture.nav.projectStatus = "mix"
        try await render(fixture, name: "projects-empty-status", directory: directory)
        fixture.nav.select(.initiatives)
        for scheme in [ColorScheme.light, .dark] {
            try await render(fixture, scheme: scheme, name: "initiatives-\(scheme)", width: 860, height: 680, directory: directory)
        }
    }

    func testNativeStatusHeadersFoldAndNestedInitiativeIssuesStartMinimized() async throws {
        try XCTSkipIf(NSScreen.screens.isEmpty, "Requires the macOS display server")
        let fixture = try Fixture(); defer { fixture.remove() }
        await fixture.prepare()
        try await fixture.usage.loadLinearProjectIssues(projectID: "project")
        let project = try XCTUnwrap(fixture.usage.linearProjects.first { $0.id == "project" })
        let initiative = try XCTUnwrap(fixture.usage.linearInitiatives.first { $0.id == "initiative" })
        var expansionHeights: [CGFloat] = []
        for nested in [false, true] {
            let card = nested ? AnyView(LinearInitiativeProjects(initiative: initiative, onPin: {}))
                : AnyView(LinearProjectCard(project: project, onPin: {}))
            let host = NSHostingView(rootView: card.padding(10).frame(width: 400)
                .environment(fixture.usage).environment(fixture.companion).environment(fixture.focus)
                .defaultAppStorage(fixture.defaults))
            let window = NSWindow(contentRect: NSRect(x: 400, y: 400, width: 400, height: 500),
                                  styleMask: .borderless, backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false
            window.contentView = host; window.orderFrontRegardless()
            defer { window.orderOut(nil); window.contentView = nil }
            try await Task.sleep(for: .milliseconds(150))
            host.setFrameSize(host.fittingSize); host.layoutSubtreeIfNeeded()
            let summaryHeight = host.fittingSize.height
            try await click(window, in: host, x: 100, top: 56)
            host.setFrameSize(host.fittingSize); host.layoutSubtreeIfNeeded()
            let expandedHeight = host.fittingSize.height
            expansionHeights.append(expandedHeight - summaryHeight)
            XCTAssertGreaterThan(expandedHeight, summaryHeight + 150)
            // The first status title sits immediately below the project's summary.
            try await click(window, in: host, x: 100, top: summaryHeight + 10)
            XCTAssertLessThan(host.fittingSize.height, expandedHeight - 50)
            host.setFrameSize(host.fittingSize); host.layoutSubtreeIfNeeded()
            try await click(window, in: host, x: 100, top: summaryHeight + 10)
            XCTAssertEqual(host.fittingSize.height, expandedHeight, accuracy: 1)
            XCTAssertNil(fixture.focus.session)
        }
        XCTAssertLessThan(expansionHeights[1], expansionHeights[0] - 30,
                          "Projects inside initiatives must start with minimized issue cards")
    }

    func testNativeIssueFilterCheckboxesAllowRepeatedSelectionWithoutClosing() async throws {
        try XCTSkipIf(NSScreen.screens.isEmpty, "Requires the macOS display server")
        let fixture = try Fixture(); defer { fixture.remove() }
        await fixture.prepare()
        let host = NSHostingView(rootView: LinearProjectIssueFilterMenu().padding(20).frame(width: 300, height: 60)
            .environment(fixture.usage).environment(fixture.companion).defaultAppStorage(fixture.defaults))
        let window = NSWindow(contentRect: NSRect(x: 400, y: 500, width: 300, height: 60),
                              styleMask: .borderless, backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = host; window.orderFrontRegardless()
        defer { window.orderOut(nil); window.contentView = nil }
        try await Task.sleep(for: .milliseconds(150))
        let existing = Set(NSApp.windows.filter(\.isVisible).map(\.windowNumber))
        try await click(window, in: host, x: 150, top: 30)
        let popup = try XCTUnwrap(NSApp.windows.first { $0.isVisible && !existing.contains($0.windowNumber) })
        defer { popup.orderOut(nil) }
        let content = try XCTUnwrap(popup.contentView)
        if let path = ProcessInfo.processInfo.environment["PTB_PROJECT_CONTROLS_PREVIEW_DIR"] {
            let bitmap = try XCTUnwrap(content.bitmapImageRepForCachingDisplay(in: content.bounds))
            content.cacheDisplay(in: content.bounds, to: bitmap)
            try XCTUnwrap(bitmap.representation(using: .png, properties: [:])).write(to:
                URL(fileURLWithPath: path).appendingPathComponent("issue-filter.png"))
        }
        // Popover chrome differs across macOS releases; use the actual scroll document.
        func descendants(of view: NSView) -> [NSView] {
            [view] + view.subviews.flatMap { descendants(of: $0) }
        }
        let views = descendants(of: content)
        let document = try XCTUnwrap(views.compactMap { $0 as? NSScrollView }.first?.documentView)
        let options = LinearProjectIssueFilter.options(fixture.usage.linearProjects,
            additionalIssues: fixture.usage.linearInitiatives.flatMap(\.issues))
        let selections: [(String, Set<String>)] = [
            ("Planned", ["unstarted:planned"]),
            ("Todo", ["unstarted:planned", "unstarted:todo"]),
            ("Planned", ["unstarted:todo"]),
        ]
        for (label, expected) in selections {
            let index = try XCTUnwrap(options.firstIndex { $0.name == label })
            try await click(popup, in: document, x: 10, top: CGFloat(index) * 28 + 14)
            XCTAssertTrue(popup.isVisible, "Changing a checkbox must leave Issue Filter open")
            XCTAssertEqual(fixture.usage.hiddenLinearIssueStatuses, expected)
        }
        XCTAssertEqual(fixture.usage.hiddenLinearIssueStatuses, ["unstarted:todo"])
        let reset = try XCTUnwrap(views.compactMap { $0 as? NSButton }.first)
        try await click(popup, in: reset, x: reset.bounds.midX, top: reset.bounds.midY)
        XCTAssertTrue(popup.isVisible)
        XCTAssertTrue(fixture.usage.hiddenLinearIssueStatuses.isEmpty, "Show all statuses resets every checkbox")
    }

    private func nativeIssuePickup(_ window: NSWindow, at point: NSPoint, stationary: Bool = false) async throws -> String? {
        try XCTSkipUnless(CGPreflightPostEventAccess(), "Requires permission to post native mouse events")
        let oldPolicy = NSApp.activationPolicy()
        NSApp.setActivationPolicy(.accessory)
        defer { NSApp.setActivationPolicy(oldPolicy) }
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        let oldPointer = CGEvent(source: nil)?.location
        defer { if let oldPointer { CGWarpMouseCursorPosition(oldPointer) } }
        NSPasteboard(name: .drag).clearContents()
        let payload = NativeDragPayload()
        let eventTag = Int64.random(in: 1...Int64.max)
        let post: @MainActor @Sendable (CGEventType, NSPoint) -> Void = { type, point in
            let screen = window.convertPoint(toScreen: point)
            let event = CGEvent(mouseEventSource: nil, mouseType: type,
                mouseCursorPosition: CGPoint(x: screen.x, y: NSScreen.screens[0].frame.maxY - screen.y), mouseButton: .left)
            XCTAssertNotNil(event)
            event?.setIntegerValueField(.eventSourceUserData, value: eventTag)
            event?.post(tap: .cghidEventTap)
        }
        let end = NSPoint(x: point.x + (stationary ? 0 : 20), y: point.y)
        let release = Timer(timeInterval: 0.25, repeats: false) { _ in
            MainActor.assumeIsolated {
                // Capture the live drag payload before WindowServer ends the session.
                payload.issueID = NSPasteboard(name: .drag).string(forType: .string)
                payload.released = true
                post(.leftMouseUp, end)
            }
        }
        let movement = Timer(timeInterval: 0.05, repeats: false) { _ in
            MainActor.assumeIsolated { if !stationary { post(.leftMouseDragged, end) } }
        }
        let finish = Timer(timeInterval: 0.7, repeats: false) { _ in
            MainActor.assumeIsolated { NSApp.stopModal() }
        }
        let monitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .leftMouseDragged]) { event in
            MainActor.assumeIsolated {
                if event.cgEvent?.getIntegerValueField(.eventSourceUserData) == eventTag {
                    XCTAssertEqual(event.windowNumber, window.windowNumber)
                }
            }
            return event
        }
        defer {
            for timer in [movement, release, finish] { timer.invalidate() }
            if let monitor { NSEvent.removeMonitor(monitor) }
            if !payload.released { post(.leftMouseUp, end) }
        }
        post(.leftMouseDown, point)
        let down = try XCTUnwrap(NSApp.nextEvent(matching: .leftMouseDown,
            until: Date().addingTimeInterval(0.2), inMode: .default, dequeue: true))
        XCTAssertEqual(down.cgEvent?.getIntegerValueField(.eventSourceUserData), eventTag)
        NSApp.sendEvent(down)
        for timer in [movement, release, finish] { RunLoop.main.add(timer, forMode: .common) }
        if stationary { try await Task.sleep(for: .milliseconds(180)) }
        // Drive AppKit's real event loop, including the drag session's own release handling.
        NSApp.runModal(for: window)
        while let up = NSApp.nextEvent(matching: .leftMouseUp, until: Date().addingTimeInterval(0.1),
            inMode: .default, dequeue: true) { NSApp.sendEvent(up) }
        return payload.issueID
    }

    private func click(_ window: NSWindow, in view: NSView, x: CGFloat, top: CGFloat) async throws {
        let point = view.convert(NSPoint(x: x, y: view.isFlipped ? top : view.bounds.height - top), to: nil)
        func event(_ type: NSEvent.EventType) throws -> NSEvent {
            try XCTUnwrap(NSEvent.mouseEvent(with: type, location: point,
                modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime,
                windowNumber: window.windowNumber, context: nil, eventNumber: 1, clickCount: 1, pressure: 1))
        }
        // AppKit controls can track synchronously inside mouseDown until mouseUp arrives.
        NSApp.postEvent(try event(.leftMouseUp), atStart: false)
        window.sendEvent(try event(.leftMouseDown))
        if let release = NSApp.nextEvent(matching: .leftMouseUp, until: Date(), inMode: .default, dequeue: true) {
            window.sendEvent(release) // SwiftUI gestures do not consume the queued release synchronously.
        }
        try await Task.sleep(for: .milliseconds(180))
    }

    private func render(_ fixture: Fixture, scheme: ColorScheme = .light, name: String,
                        width: CGFloat = 1280, height: CGFloat = 860, directory: URL) async throws {
        let host = NSHostingView(rootView: MainWindowView()
            .environment(fixture.usage).environment(fixture.companion).environment(fixture.focus)
            .environment(fixture.nav).environment(UpdateChecker())
            .environment(\.colorScheme, scheme).defaultAppStorage(fixture.defaults)
            .frame(width: width, height: height))
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: width, height: height),
                              styleMask: .borderless, backing: .buffered, defer: false)
        window.appearance = NSAppearance(named: scheme == .dark ? .darkAqua : .aqua)
        window.contentView = host
        host.frame = NSRect(x: 0, y: 0, width: width, height: height)
        defer { window.contentView = nil }
        try await Task.sleep(for: .milliseconds(180))
        host.layoutSubtreeIfNeeded()
        XCTAssertEqual(host.bounds.size, NSSize(width: width, height: height))
        let bitmap = try XCTUnwrap(host.bitmapImageRepForCachingDisplay(in: host.bounds))
        host.cacheDisplay(in: host.bounds, to: bitmap)
        try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
            .write(to: directory.appendingPathComponent("\(name).png"))
    }

    func testRenderPlannedWorkspaces() async throws {
        guard let path = ProcessInfo.processInfo.environment["PTB_PLANNED_PREVIEW_DIR"] else {
            throw XCTSkip("Set PTB_PLANNED_PREVIEW_DIR for planned issue visual verification")
        }
        let fixture = try Fixture(); defer { fixture.remove() }
        await fixture.prepare()
        let directory = URL(fileURLWithPath: path)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        fixture.nav.issuesTab = .todo
        fixture.nav.select(.issues)
        try await render(fixture, name: "todo-issues", directory: directory)
        fixture.nav.issuesTab = .planned
        for page in [MainWindowPage.issues, .projects, .initiatives] {
            fixture.nav.select(page)
            try await render(fixture, name: "planned-\(page)", directory: directory)
        }
        fixture.nav.select(.issues)
        try await render(fixture, scheme: .dark, name: "planned-issues-dark", width: 860, height: 620, directory: directory)

        let root = VStack(alignment: .leading, spacing: 12) {
            LinearIntegrationView(store: fixture.usage)
            Divider()
            LinearContainerIssuesView(issues: fixture.usage.linearProjects.first?.issues ?? [], nested: true) {}
        }.padding(16)
            .background(Color.white)
            .environment(fixture.usage).environment(fixture.companion).environment(fixture.focus)
            .environment(fixture.nav.content).environment(UpdateChecker()).defaultAppStorage(fixture.defaults)
            .environment(\.colorScheme, .light)
            .frame(width: 400, height: 680)
        let host = NSHostingView(rootView: root)
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 400, height: 680),
                              styleMask: .borderless, backing: .buffered, defer: false)
        window.appearance = NSAppearance(named: .aqua)
        window.contentView = host
        window.orderFrontRegardless()
        defer { window.orderOut(nil); window.contentView = nil }
        try await Task.sleep(for: .milliseconds(180))
        host.layoutSubtreeIfNeeded()
        // Exercise the actual compact Planned tab as well as the shared parent issue group.
        let point = host.convert(NSPoint(x: 113, y: host.isFlipped ? 105 : host.bounds.height - 105), to: nil)
        for type in [NSEvent.EventType.leftMouseDown, .leftMouseUp] {
            window.sendEvent(try XCTUnwrap(NSEvent.mouseEvent(with: type, location: point,
                modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime,
                windowNumber: window.windowNumber, context: nil, eventNumber: 1, clickCount: 1, pressure: 1)))
        }
        try await Task.sleep(for: .milliseconds(100))
        host.layoutSubtreeIfNeeded()
        let bitmap = try XCTUnwrap(host.bitmapImageRepForCachingDisplay(in: host.bounds))
        host.cacheDisplay(in: host.bounds, to: bitmap)
        try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
            .write(to: directory.appendingPathComponent("planned-compact.png"))
    }

    @MainActor private final class Fixture {
        let directory: URL
        let suite = "MainWindowTests-\(UUID().uuidString)"
        let defaults: UserDefaults
        let companion: CompanionStore
        let usage: UsageStore
        let nav = MainWindowNavigation()
        var now = Date(timeIntervalSince1970: 1_789_740_000)
        lazy var focus = FocusSessionStore(usage: usage, companion: companion,
            clock: { self.now },
            fileURL: directory.appendingPathComponent("focus.json"), ticksOnTimer: false)
        init(hierarchy: Bool = false, statusHierarchy: Bool = false) throws {
            directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
            defaults.set(true, forKey: "linearIntegrationEnabled")
            defaults.set(1.0, forKey: "shopDifficulty")
            var state = CompanionState(); state.language = .en
            state.active = MonState(baseID: 131, pathIDs: [131], stageIndex: 0,
                                    usedAtStage: 12_000_000, rarity: .rare, totalForms: 1, nature: .calm)
            state.usedSinceInstall = 12_500_000
            state.inventory = ["rareCandy": 5, "mint": 2, "shinyCharm": 1]
            state.pokemonStorage = [.egg(id: "egg", tier: nil, usage: 0),
                .partner(id: "bulbasaur", mon: MonState(baseID: 1, pathIDs: [1, 2, 3], stageIndex: 0,
                    usedAtStage: 0, rarity: .uncommon, totalForms: 3, nature: .bold))]
            let file = directory.appendingPathComponent("companion.json")
            try JSONEncoder().encode(state).write(to: file)
            companion = CompanionStore(provider: StubProvider(value: EvoLine(baseID: 131,
                tree: EvoNode(speciesID: 131, children: []), rarity: .rare, names: [131: ["en": "Lapras"]])),
                fileURL: file, defaults: defaults)
            let keys = LinearAPIKeyStore(fileURL: directory.appendingPathComponent("key.json"))
            try keys.save(.init(key: "lin_api_preview_fixture_not_a_real_key"))
            usage = UsageStore(providers: [], autoRefresh: false, defaults: defaults,
                               linearClient: LinearClient(http: PreviewHTTP(hierarchy: hierarchy, statusHierarchy: statusHierarchy)), linearAPIKeys: keys)
        }
        func prepare() async {
            companion.update(todayTokensByProvider: [:], todayDate: "2026-09-18", monthTotal: 0,
                             burnTier: .idle, limitWarning: false, hasUsageData: false)
            await Task.yield()
            _ = await usage.refreshLinearIssues()
        }
        func remove() {
            defaults.removePersistentDomain(forName: suite)
            try? FileManager.default.removeItem(at: directory)
        }
    }

    private struct PreviewHTTP: LinearHTTPClient {
        var hierarchy = false
        var statusHierarchy = false
        func postGraphQL(apiKey: String, body: Data) async throws -> (status: Int, data: Data) {
            let projectStatuses: [[String: Any]] = [
                ["id": "backlog", "name": "Backlog", "type": "backlog", "position": 0],
                ["id": "planned", "name": "Planned", "type": "planned", "position": 1],
                ["id": "production", "name": "Production", "type": "started", "position": 2],
                ["id": "started", "name": "In Progress", "type": "started", "position": 3],
                ["id": "mix", "name": "Mix & Mastering", "type": "started", "position": 4],
                ["id": "review", "name": "In Review", "type": "started", "position": 5],
                ["id": "release", "name": "Release Ready", "type": "completed", "position": 6],
                ["id": "done", "name": "Completed", "type": "completed", "position": 7],
                ["id": "canceled", "name": "Canceled", "type": "canceled", "position": 8],
            ]
            let team: [String: Any] = ["id": "team", "key": "PKT", "name": "PokeTasks", "states": ["nodes": [
                ["id": "todo-state", "name": "Todo", "type": "unstarted"],
                ["id": "planned-state", "name": "Planned", "type": "unstarted"],
                ["id": "started", "name": "In Progress", "type": "started"],
                ["id": "done", "name": "Done", "type": "completed"],
            ]]]
            var issue: [String: Any] = ["id": "issue", "identifier": "PKT-142", "title": "Refine the main app window",
                "state": ["id": "started", "name": "In Progress", "type": "started"],
                "description": "Bring the approved dashboard and navigation to the native app.",
                "project": ["id": "project", "name": "PokeTasks"], "priority": 2, "team": team]
            let project: [String: Any] = ["id": "project", "name": "PokeTasks", "status": ["id": "started", "type": "started", "name": "In Progress"],
                "description": "A calmer place to focus on your work.", "issues": ["nodes": [issue]]]
            var planned: [String: Any] = ["id": "planned", "identifier": "PKT-143", "title": "Plan the next focus session",
                "state": ["id": "planned-state", "name": "Planned", "type": "unstarted"],
                "project": ["id": "project", "name": "PokeTasks"], "priority": 3, "team": team]
            var todo: [String: Any] = ["id": "todo", "identifier": "PKT-144", "title": "Choose the next small task",
                "state": ["id": "todo-state", "name": "Todo", "type": "unstarted"],
                "project": ["id": "project", "name": "PokeTasks"], "priority": 2, "team": team]
            var sameStatus = issue
            sameStatus["id"] = "same-status"; sameStatus["identifier"] = "PKT-145"
            sameStatus["parent"] = ["id": "issue"]
            var waiting = sameStatus
            waiting["id"] = "waiting"; waiting["identifier"] = "PKT-147"
            waiting["state"] = ["id": "waiting-state", "name": "Waiting", "type": "started"]
            var completed = planned
            completed["id"] = "completed"; completed["identifier"] = "PKT-146"
            completed["state"] = ["id": "done", "name": "Done", "type": "completed"]
            completed["completedAt"] = ISO8601DateFormatter().string(from: Date())
            if hierarchy || statusHierarchy {
                issue["children"] = ["nodes": [["id": "todo"]]]
                todo["parent"] = ["id": "issue"]
            }
            if statusHierarchy {
                todo["children"] = ["nodes": [["id": "planned"]]]
                planned["parent"] = ["id": "todo"]
                planned["children"] = ["nodes": [["id": "completed"]]]
                completed["parent"] = ["id": "planned"]
            }
            let request = try JSONSerialization.jsonObject(with: body) as? [String: Any]
            let parentID = (request?["variables"] as? [String: Any])?["id"] as? String
            let children = statusHierarchy ? [sameStatus, waiting, todo, planned, completed].filter {
                ($0["parent"] as? [String: String])?["id"] == parentID
            } : (hierarchy ? [todo] : [])
            return (200, try JSONSerialization.data(withJSONObject: ["data": [
                "projectStatuses": ["nodes": projectStatuses, "pageInfo": ["hasNextPage": false]],
                "inProgress": ["nodes": [issue] + (statusHierarchy ? [waiting] : [])],
                "completedRecent": ["nodes": statusHierarchy ? [completed] : []], "planned": ["nodes": [planned]], "todo": ["nodes": [todo]],
                "issue": ["children": ["nodes": children, "pageInfo": ["hasNextPage": false]]],
                "project": ["issues": ["nodes": [issue, planned, todo] + (statusHierarchy ? [sameStatus, waiting, completed] : []), "pageInfo": ["hasNextPage": false]]],
                "projects": ["nodes": [project, ["id": "other-project", "name": "Weekly Planning",
                    "status": ["id": "planned", "type": "planned", "name": "Planned"], "issues": ["nodes": []]]]],
                "initiatives": ["nodes": [["id": "initiative", "name": "Fun Side Projects",
                    "status": "Active", "projects": ["nodes": [project]]],
                    ["id": "other-initiative", "name": "Studio Refresh", "status": "Active", "projects": ["nodes": []]]]],
                "teams": ["nodes": []]]]))
        }
    }
}
