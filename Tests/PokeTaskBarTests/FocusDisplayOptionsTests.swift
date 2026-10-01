import AppKit
import XCTest
@testable import PokeTaskBar

@MainActor
final class FocusDisplayOptionsTests: XCTestCase {
    func testOptionsDefaultOffAndSurviveRelaunch() throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        let usage = fixture.usage
        XCTAssertFalse(usage.showFocusedIssueTitleInMenu)
        XCTAssertFalse(usage.floatingTimerDetached)
        XCTAssertFalse(usage.floatingTimerPinned)
        usage.showFocusedIssueTitleInMenu = true
        usage.floatingTimerDetached = true
        usage.floatingTimerPinned = true
        let restored = fixture.makeUsage()
        XCTAssertTrue(restored.showFocusedIssueTitleInMenu)
        XCTAssertTrue(restored.floatingTimerDetached)
        XCTAssertTrue(restored.floatingTimerPinned)
        XCTAssertTrue(restored.focusOverlayEnabled, "The detached timer hosts prompts with the pet off")
    }

    func testDetachedTimerMovesIndependentlyPinsAndRestores() async throws {
        let app = NSApplication.shared
        let activationPolicy = app.activationPolicy()
        app.setActivationPolicy(.accessory)
        defer { app.setActivationPolicy(activationPolicy) }
        let fixture = try Fixture()
        defer { fixture.remove() }
        let screen = try XCTUnwrap(NSScreen.main)
        fixture.companion.setLanguage(.en)
        fixture.usage.floatingPetEnabled = true
        fixture.defaults.set(screen.visibleFrame.maxX - 180, forKey: "floatingPetOriginX")
        fixture.defaults.set(screen.visibleFrame.minY + 100, forKey: "floatingPetOriginY")
        var issue = FocusPinnedIssue.pomodoro(title: "Keep the focused task in sight").summary
        issue.id = "test-focus-display"
        issue.identifier = "TEST-42"
        fixture.focus.pin(issue, openDesk: false, minutes: 50)
        let controller = FloatingPetController(store: fixture.usage, companion: fixture.companion,
            session: fixture.focus, defaults: fixture.defaults)
        defer { controller.setDisplayAwake(false) }
        let pet = try XCTUnwrap(NSApp.windows.compactMap { $0 as? FloatingPetPanel }.first { $0.isVisible })
        let petAnchor = NSPoint(x: pet.frame.maxX - 96, y: pet.frame.minY)
        try await settle()
        try snapshot(pet, name: "attached")
        fixture.usage.floatingTimerDetached = true
        try await settle()
        let timer = try XCTUnwrap(NSApp.windows.first {
            $0.identifier?.rawValue == FloatingPetController.timerPanelIdentifier && $0.isVisible
        })
        XCTAssertTrue(timer.canBecomeKey)
        XCTAssertEqual(timer.frame.width, 384)
        XCTAssertEqual(timer.frame.height, FloatingTimerMetrics.height)
        XCTAssertEqual(pet.frame.width, 96, "The pet no longer contains a timer")
        XCTAssertEqual(pet.frame.maxX - 96, petAnchor.x, accuracy: 1)
        XCTAssertEqual(pet.frame.minY, petAnchor.y, accuracy: 1)
        timer.setFrameOrigin(NSPoint(x: screen.visibleFrame.minX + 120, y: screen.visibleFrame.minY + 180))
        let timerFrame = timer.frame
        pet.setFrameOrigin(NSPoint(x: pet.frame.minX - 8, y: pet.frame.minY + 8))
        XCTAssertEqual(timer.frame, timerFrame)
        let petFrame = pet.frame
        try snapshot(timer, name: "detached")
        let move = try XCTUnwrap(handles(in: timer.contentView).first { $0.mode == .move })
        let right = try key(timer, code: 124)
        move.keyDown(with: right)
        XCTAssertEqual(timer.frame.minX, timerFrame.minX + 8)
        XCTAssertEqual(pet.frame, petFrame)
        fixture.usage.floatingTimerPinned = true
        try await settle()
        XCTAssertTrue(move.movementLocked)
        let pinned = timer.frame
        move.keyDown(with: right)
        XCTAssertEqual(timer.frame, pinned, "Pinning blocks the keyboard movement path")
        let resize = try XCTUnwrap(handles(in: timer.contentView).first { $0.mode == .resize })
        XCTAssertTrue(resize.accessibilityPerformIncrement())
        try await settle()
        XCTAssertEqual(timer.frame.width, 400)
        XCTAssertEqual(timer.frame.maxX, pinned.maxX, accuracy: 1)
        XCTAssertEqual(pet.frame, petFrame)
        try snapshot(timer, name: "detached-pinned")

        fixture.usage.floatingPetEnabled = false
        try await settle()
        XCTAssertFalse(pet.isVisible)
        XCTAssertTrue(timer.isVisible)
        let anchored = timer.frame
        fixture.focus.toggleNoteComposer()
        try await settle()
        try type("Note", into: timer)
        try await settle()
        XCTAssertEqual(fixture.focus.noteDraft, "Note", "Native typing must reach the detached note field")
        XCTAssertGreaterThan(timer.frame.height, anchored.height)
        XCTAssertEqual(timer.frame.minY, anchored.minY, accuracy: 1)
        XCTAssertLessThanOrEqual(try XCTUnwrap(timer.contentView).fittingSize.height, timer.frame.height + 1)
        fixture.focus.toggleNoteComposer()
        try await settle()
        XCTAssertEqual(timer.frame, anchored)
        fixture.focus.tick(now: fixture.now.addingTimeInterval(30 * 60))
        try await settle()
        XCTAssertEqual(fixture.focus.prompt, .checkIn)
        try type("Check", into: timer)
        try await settle()
        XCTAssertEqual(fixture.focus.checkInDraft, "Check")
        try snapshot(timer, name: "detached-check-in")
        await fixture.focus.answerCheckIn(.skip)
        try await settle()
        XCTAssertEqual(timer.frame, anchored)

        controller.setDisplayAwake(false)
        XCTAssertFalse(timer.isVisible)
        XCTAssertNil(timer.contentView)
        let restored = FloatingPetController(store: fixture.makeUsage(), companion: fixture.companion,
            session: fixture.focus, defaults: fixture.defaults)
        defer { restored.setDisplayAwake(false) }
        try await settle()
        let restoredTimer = try XCTUnwrap(NSApp.windows.first {
            $0.identifier?.rawValue == FloatingPetController.timerPanelIdentifier && $0.isVisible
        })
        XCTAssertEqual(restoredTimer.frame, anchored)
        XCTAssertTrue(try XCTUnwrap(handles(in: restoredTimer.contentView).first { $0.mode == .move }).movementLocked)
        restored.setDisplayAwake(false)
        controller.setDisplayAwake(true)
        fixture.usage.floatingTimerPinned = false
        fixture.usage.floatingPetEnabled = true
        fixture.usage.floatingTimerDetached = false
        try await settle()
        XCTAssertFalse(timer.isVisible)
        XCTAssertTrue(pet.isVisible)
        XCTAssertEqual(pet.frame.width, 400 + 144, accuracy: 1)
        XCTAssertEqual(pet.frame.maxX - 96, petFrame.maxX - 96, accuracy: 1)
        XCTAssertEqual(pet.frame.minY, petFrame.minY, accuracy: 1)
        fixture.usage.floatingTimerDetached = true
        try await settle()
        XCTAssertEqual(timer.frame, anchored, "Re-detaching returns to the independent anchor")
        fixture.focus.finishLeavingInProgress()
        try await settle()
        XCTAssertFalse(timer.isVisible)
        fixture.usage.floatingPetEnabled = false
        fixture.focus.openPomodoroSetup()
        try await settle()
        XCTAssertTrue(timer.isVisible, "Timer setup works without a pet")
        XCTAssertEqual(handles(in: timer.contentView).count, 2)
        try snapshot(timer, name: "detached-setup")
        controller.resizeTimer(to: 350, keepingRightEdge: NSPoint(x: timer.frame.maxX, y: timer.frame.minY))
        fixture.focus.startPomodoro()
        try await settle()
        XCTAssertEqual(timer.frame.width, 350)
        XCTAssertEqual(timer.frame.height, FloatingTimerMetrics.height)
        XCTAssertFalse(pet.isVisible)
    }

    private func handles(in view: NSView?) -> [FloatingTimerDragView] {
        guard let view else { return [] }
        return (view as? FloatingTimerDragView).map { [$0] } ?? view.subviews.flatMap { handles(in: $0) }
    }

    private func key(_ window: NSWindow, code: UInt16) throws -> NSEvent {
        try XCTUnwrap(NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [],
            timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: window.windowNumber,
            context: nil, characters: "", charactersIgnoringModifiers: "", isARepeat: false, keyCode: code))
    }

    private func type(_ text: String, into window: NSWindow) throws {
        func fields(_ view: NSView) -> [NSTextField] {
            (view as? NSTextField).map { [$0] } ?? view.subviews.flatMap(fields)
        }
        let field = try XCTUnwrap(window.contentView.flatMap { fields($0).first { $0.isEditable } })
        let point = field.convert(NSPoint(x: field.bounds.midX, y: field.bounds.midY), to: nil)
        let up = try XCTUnwrap(NSEvent.mouseEvent(with: .leftMouseUp, location: point,
            modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime,
            windowNumber: window.windowNumber, context: nil, eventNumber: 1, clickCount: 1, pressure: 0))
        NSApp.postEvent(up, atStart: true)
        window.sendEvent(try XCTUnwrap(NSEvent.mouseEvent(with: .leftMouseDown, location: point,
            modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime,
            windowNumber: window.windowNumber, context: nil, eventNumber: 1, clickCount: 1, pressure: 1)))
        let editor = try XCTUnwrap(field.currentEditor() as? NSTextView,
                                  "The first click must focus the detached text field")
        editor.insertText(text, replacementRange: NSRange(location: NSNotFound, length: 0))
    }

    private func settle() async throws {
        try await Task.sleep(for: .milliseconds(150))
        for window in NSApp.windows where window.isVisible { window.contentView?.layoutSubtreeIfNeeded() }
    }

    private func snapshot(_ window: NSWindow, name: String) throws {
        guard let path = ProcessInfo.processInfo.environment["PTB_FOCUS_DISPLAY_PREVIEW_DIR"] else { return }
        let directory = URL(fileURLWithPath: path)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let view = try XCTUnwrap(window.contentView)
        view.layoutSubtreeIfNeeded()
        let bitmap = try XCTUnwrap(view.bitmapImageRepForCachingDisplay(in: view.bounds))
        view.cacheDisplay(in: view.bounds, to: bitmap)
        try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
            .write(to: directory.appendingPathComponent("\(name).png"))
    }

    @MainActor private final class Fixture {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let suite = "FocusDisplayOptionsTests-\(UUID().uuidString)"
        let defaults: UserDefaults
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let companion: CompanionStore
        lazy var usage = makeUsage()
        lazy var focus = FocusSessionStore(usage: usage, companion: companion, clock: { self.now },
            fileURL: directory.appendingPathComponent("focus.json"), ticksOnTimer: false)

        init() throws {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
            companion = CompanionStore(provider: StubProvider(value: EvoLine(
                baseID: 131, tree: EvoNode(speciesID: 131, children: []), rarity: .rare, names: [:])),
                fileURL: directory.appendingPathComponent("companion.json"), defaults: defaults)
        }
        func makeUsage() -> UsageStore {
            UsageStore(providers: [], autoRefresh: false, defaults: defaults,
                linearAPIKeys: LinearAPIKeyStore(fileURL: directory.appendingPathComponent("key.json")))
        }
        func remove() {
            defaults.removePersistentDomain(forName: suite)
            try? FileManager.default.removeItem(at: directory)
        }
    }
}
