import AppKit
import SwiftUI
import XCTest
@testable import PokeTaskBar

@MainActor
final class FloatingTimerOverlayTests: XCTestCase {
    func testNativeTimerHoverGraceClearsMouseFocusAndCancelsOnReturn() async throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        fixture.companion.setLanguage(.en)
        fixture.focus.startPomodoro()
        let root = FloatingTimerStrip()
            .environment(fixture.usage).environment(fixture.companion).environment(fixture.focus)
            .environment(\.colorScheme, .dark)
        let host = NSHostingView(rootView: root)
        let window = FloatingPetPanel(contentRect: NSRect(x: 30, y: 30, width: 384, height: 42),
            styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = host
        defer { window.close(); window.contentView = nil }
        func settle(_ milliseconds: Int = 300) async throws {
            try await Task.sleep(for: .milliseconds(milliseconds))
            host.layoutSubtreeIfNeeded()
        }
        func descendants(_ view: NSView) -> [NSView] { [view] + view.subviews.flatMap(descendants) }
        func snapshot() throws -> Data {
            let bitmap = try XCTUnwrap(host.bitmapImageRepForCachingDisplay(in: host.bounds))
            host.cacheDisplay(in: host.bounds, to: bitmap)
            return try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
        }
        try await settle()
        let hover = try XCTUnwrap(descendants(host).compactMap { $0 as? FloatingTimerHoverView }.first)
        hover.updateTrackingAreas()
        let unrelated = NSTrackingArea(rect: .zero, options: [.mouseEnteredAndExited, .activeAlways],
            owner: host, userInfo: nil)
        hover.addTrackingArea(unrelated)
        hover.updateTrackingAreas()
        hover.updateTrackingAreas()
        XCTAssertTrue(hover.trackingAreas.contains { $0 === unrelated })
        XCTAssertEqual(hover.trackingAreas.count, 2, "Refreshing must replace only the timer's tracking area")
        XCTAssertTrue(hover.trackingAreas.contains { $0.options.contains(.activeAlways) })
        XCTAssertNil(hover.hitTest(.zero), "Tracking must not intercept timer clicks or dragging")
        let handle = try XCTUnwrap(descendants(host).compactMap { $0 as? FloatingTimerDragView }
            .first { $0.mode == .move })
        func pointer(_ inside: Bool) throws {
            let event = try XCTUnwrap(NSEvent.enterExitEvent(with: inside ? .mouseEntered : .mouseExited,
                location: NSPoint(x: 180, y: 21), modifierFlags: [], timestamp: 0,
                windowNumber: window.windowNumber, context: nil, eventNumber: 1, trackingNumber: 0, userData: nil))
            if inside { hover.mouseEntered(with: event) } else { hover.mouseExited(with: event) }
        }
        let title = try snapshot()
        try pointer(true)
        _ = handle.becomeFirstResponder() // A mouse-used handle can stay first responder after exit.
        try await settle()
        let controls = try snapshot()
        XCTAssertNotEqual(controls, title)
        try pointer(false)
        try await settle(1_000)
        XCTAssertEqual(try snapshot(), controls, "Keep controls visible during the two-second grace")
        try await settle(1_500)
        XCTAssertEqual(try snapshot(), title, "Exit must clear lingering native focus and restore the title")

        try pointer(true)
        try pointer(false)
        try await settle(1_000)
        try pointer(true)
        try await settle(1_200)
        XCTAssertEqual(try snapshot(), controls, "Returning cancels the old fade deadline")
        try pointer(false)
        try await settle(2_500)
        XCTAssertEqual(try snapshot(), title)

        // Keyboard movement during the grace keeps its focused controls available.
        try pointer(true)
        _ = handle.becomeFirstResponder()
        try pointer(false)
        let key = try XCTUnwrap(NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [],
            timestamp: 0, windowNumber: window.windowNumber, context: nil, characters: "",
            charactersIgnoringModifiers: "", isARepeat: false, keyCode: 123))
        handle.keyDown(with: key)
        try await settle(2_500)
        XCTAssertEqual(try snapshot(), controls, "Keyboard input cancels the mouse fade")
        _ = handle.resignFirstResponder()
        try await settle()
        XCTAssertEqual(try snapshot(), title, "Keyboard focus release restores the title")
    }

    func testTimerScalePersistsAndBoundsSavedValues() throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        XCTAssertEqual(fixture.usage.floatingTimerScale, 1)
        fixture.usage.floatingTimerScale = 0.75
        XCTAssertEqual(fixture.makeUsage().floatingTimerScale, 0.75)
        for (value, expected) in [(-1.0, 0.5), (10.0, 2.0), (.nan, 1.0), (.infinity, 1.0)] {
            fixture.usage.floatingTimerScale = value
            XCTAssertEqual(fixture.usage.floatingTimerScale, expected)
            fixture.defaults.set(value, forKey: FloatingTimerMetrics.scaleKey)
            XCTAssertEqual(fixture.makeUsage().floatingTimerScale, expected)
        }
    }

    func testFloatingEggRendersAtHalfThePokemonSize() throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        fixture.usage.floatingTimerDetached = true
        fixture.focus.startPomodoro() // The detached timer leaves only the sprite in this view.
        XCTAssertNil(fixture.companion.representativeSubject.speciesID)
        func opaqueBounds(_ content: some View) throws -> NSRect {
            let bitmap = NSBitmapImageRep(cgImage: try XCTUnwrap(ImageRenderer(content: content).cgImage))
            var bounds = NSRect.null
            for x in 0..<bitmap.pixelsWide {
                for y in 0..<bitmap.pixelsHigh where (bitmap.colorAt(x: x, y: y)?.alphaComponent ?? 0) > 0.1 {
                    bounds = bounds.union(NSRect(x: x, y: y, width: 1, height: 1))
                }
            }
            XCTAssertFalse(bounds.isNull)
            return bounds
        }
        for size: CGFloat in [48, 96, 384] {
            fixture.usage.floatingPetSize = Double(size)
            let actual = try opaqueBounds(FloatingPetView(animated: false)
                .environment(fixture.usage).environment(fixture.companion).environment(fixture.focus)
                .frame(width: size, height: size))
            let expected = try opaqueBounds(SpriteView(speciesID: nil, size: size / 2)
                .frame(width: size, height: size))
            XCTAssertEqual(actual, expected, "The egg must share the Pokémon setting at half its size")
            let old = try opaqueBounds(SpriteView(speciesID: nil, size: size))
            XCTAssertEqual(actual.height, old.height / 2, accuracy: 2)
        }
    }

    func testNativeTimerScaleUpdatesAllModesAndKeepsControlsUsable() async throws {
        let screen = try XCTUnwrap(NSScreen.main)
        let fixture = try Fixture()
        defer { fixture.remove() }
        fixture.companion.setLanguage(.en)
        fixture.usage.floatingPetEnabled = true
        fixture.usage.floatingPetSize = 48
        fixture.defaults.set(screen.visibleFrame.maxX - 100, forKey: "floatingPetOriginX")
        fixture.defaults.set(screen.visibleFrame.minY + 100, forKey: "floatingPetOriginY")
        let controller = FloatingPetController(store: fixture.usage, companion: fixture.companion,
            session: fixture.focus, defaults: fixture.defaults)
        defer { controller.setDisplayAwake(false) }
        let pet = try XCTUnwrap(NSApp.windows.compactMap { $0 as? FloatingPetPanel }.first { $0.isVisible })
        let petAnchor = pet.frame.maxX - 48
        func settle() async throws {
            try await Task.sleep(for: .milliseconds(120))
            for window in NSApp.windows where window.isVisible { window.contentView?.layoutSubtreeIfNeeded() }
        }
        func handles(_ view: NSView) -> [FloatingTimerDragView] {
            (view as? FloatingTimerDragView).map { [$0] } ?? view.subviews.flatMap(handles)
        }
        func click(_ window: NSWindow, x: CGFloat, y: CGFloat) throws {
            for type in [NSEvent.EventType.leftMouseDown, .leftMouseUp] {
                window.sendEvent(try XCTUnwrap(NSEvent.mouseEvent(with: type, location: NSPoint(x: x, y: y),
                    modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime,
                    windowNumber: window.windowNumber, context: nil, eventNumber: 1, clickCount: 1, pressure: 1)))
            }
        }
        for appearance in [NSAppearance.Name.aqua, .darkAqua] {
            pet.appearance = NSAppearance(named: appearance)
            for scale: CGFloat in [0.5, 1, 2] {
                fixture.usage.floatingTimerScale = Double(scale)
                fixture.usage.floatingTimerWidth = 384
                for mode in ["idle", "setup", "expanded", "compact", "detached", "detached-setup", "note", "check-in", "detached-note", "detached-check-in"] {
                    fixture.usage.floatingTimerDetached = mode.hasPrefix("detached")
                    fixture.usage.floatingPetIslandFolded = mode == "compact"
                    if mode.hasSuffix("note") || mode.hasSuffix("check-in") {
                        var issue = FocusPinnedIssue.pomodoro(title: "Scaled prompt").summary
                        issue.id = "scale-prompt"
                        fixture.focus.pin(issue, openDesk: false, minutes: 50)
                        if mode.hasSuffix("note") { fixture.focus.toggleNoteComposer() }
                        else { fixture.focus.tick(now: Date(timeIntervalSince1970: 1_700_000_000 + 30 * 60)) }
                    } else if mode == "setup" || mode == "detached-setup" { fixture.focus.openPomodoroSetup() }
                    else if mode != "idle" { fixture.focus.startPomodoro() }
                    try await settle()
                    let detached = fixture.usage.floatingTimerDetached
                    let window = detached ? try XCTUnwrap(NSApp.windows.first {
                        $0.identifier?.rawValue == FloatingPetController.timerPanelIdentifier && $0.isVisible
                    }) : pet
                    window.appearance = NSAppearance(named: appearance)
                    let host = try XCTUnwrap(window.contentView)
                    if mode == "idle" {
                        XCTAssertEqual(pet.frame.width, 48 + 40 * scale, accuracy: 1)
                    } else if mode == "compact" {
                        XCTAssertEqual(pet.frame.width, 48 + 161 * scale, accuracy: 1)
                        try click(pet, x: 80 * scale, y: 17 * scale)
                        XCTAssertTrue(fixture.focus.session?.userPaused == true, "Scaled compact Pause must accept clicks")
                    } else {
                        XCTAssertEqual(window.frame.width, detached ? 384 * scale : 48 + 432 * scale, accuracy: 1)
                        let contentHeight: CGFloat = mode.hasSuffix("note") ? 110 : mode.hasSuffix("check-in") ? 226 : 42
                        XCTAssertEqual(window.frame.height, detached ? contentHeight * scale : max(48, contentHeight * scale), accuracy: 1)
                        let resize = try XCTUnwrap(handles(host).first { $0.mode == .resize })
                        XCTAssertEqual(resize.timerScale, scale)
                        XCTAssertEqual(resize.convert(resize.bounds, to: host).width, 12 * scale, accuracy: 1)
                        if mode.hasSuffix("note") || mode.hasSuffix("check-in") {
                            func fields(_ view: NSView) -> [NSTextField] {
                                (view as? NSTextField).map { [$0] } ?? view.subviews.flatMap(fields)
                            }
                            let field = try XCTUnwrap(fields(host).first { $0.isEditable })
                            let point = field.convert(NSPoint(x: field.bounds.midX, y: field.bounds.midY), to: nil)
                            NSApp.postEvent(try XCTUnwrap(NSEvent.mouseEvent(with: .leftMouseUp, location: point,
                                modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime,
                                windowNumber: window.windowNumber, context: nil, eventNumber: 1, clickCount: 1, pressure: 0)), atStart: true)
                            window.sendEvent(try XCTUnwrap(NSEvent.mouseEvent(with: .leftMouseDown, location: point,
                                modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime,
                                windowNumber: window.windowNumber, context: nil, eventNumber: 1, clickCount: 1, pressure: 1)))
                            if let release = NSApp.nextEvent(matching: .leftMouseUp, until: Date(), inMode: .default, dequeue: true) {
                                window.sendEvent(release)
                            }
                            XCTAssertNil(NSApp.nextEvent(matching: .leftMouseUp, until: Date(), inMode: .default, dequeue: false),
                                         "Native typing must not leak mouse releases into later tests")
                            let editor = try XCTUnwrap(field.currentEditor() as? NSTextView,
                                                       "Scaled text fields must accept clicks")
                            XCTAssertTrue(window.firstResponder === editor,
                                          "\(mode), \(scale): the clicked editor must receive keyboard events; key=\(window.isKeyWindow)")
                            // Use native text input after the real click; desktop focus can steal synthetic key events.
                            editor.insertText("N", replacementRange: NSRange(location: NSNotFound, length: 0))
                            try await settle()
                            XCTAssertEqual(mode.hasSuffix("note") ? fixture.focus.noteDraft : fixture.focus.checkInDraft, "N",
                                           "\(mode), \(scale), \(appearance): typed input must reach the draft")
                        } else if mode == "setup" || mode == "detached-setup" {
                            try click(window, x: (384 - 64.5) * scale, y: 21 * scale)
                            XCTAssertTrue(fixture.focus.isActive, "Scaled Start must accept clicks")
                        } else {
                            _ = try XCTUnwrap(handles(host).first { $0.mode == .move }).becomeFirstResponder()
                            try await settle()
                            try click(window, x: 117.5 * scale, y: 21 * scale)
                            XCTAssertTrue(fixture.focus.session?.userPaused == true, "Scaled Pause must accept clicks")
                        }
                        let right = window.frame.maxX
                        resize.keyDown(with: try XCTUnwrap(NSEvent.keyEvent(with: .keyDown, location: .zero,
                            modifierFlags: [], timestamp: 0, windowNumber: window.windowNumber, context: nil,
                            characters: "", charactersIgnoringModifiers: "", isARepeat: false, keyCode: 123)))
                        try await settle()
                        XCTAssertEqual(window.frame.width, (detached ? 384 * scale : 48 + 432 * scale) + 8, accuracy: 1)
                        XCTAssertEqual(window.frame.maxX, right, accuracy: 1)
                    }
                    XCTAssertEqual(pet.frame.maxX - 48, petAnchor, accuracy: 1)
                    XCTAssertLessThanOrEqual(host.fittingSize.width, window.frame.width + 1)
                    XCTAssertLessThanOrEqual(host.fittingSize.height, window.frame.height + 1)
                    if let path = ProcessInfo.processInfo.environment["PTB_FLOATING_PREVIEW_DIR"] {
                        let directory = URL(fileURLWithPath: path)
                        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                        let bitmap = try XCTUnwrap(host.bitmapImageRepForCachingDisplay(in: host.bounds))
                        host.cacheDisplay(in: host.bounds, to: bitmap)
                        try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
                            .write(to: directory.appendingPathComponent("scale-\(mode)-\(scale)-\(appearance.rawValue).png"))
                    }
                    fixture.focus.cancelPomodoroSetup()
                    fixture.focus.finishLeavingInProgress()
                    fixture.usage.floatingTimerWidth = 384
                    try await settle()
                }
            }
        }
    }

    func testEdgePeekGeometryStaysOnItsDisplay() {
        for visible in [NSRect(x: 0, y: 40, width: 1440, height: 860),
                        NSRect(x: -1440, y: -300, width: 1440, height: 900)] {
            for edge in [FloatingPetController.TuckEdge.left, .right] {
                for petSize: CGFloat in [48, 96, 384] {
                    let expanded = NSRect(x: visible.midX, y: visible.maxY - 10,
                                          width: 720, height: petSize + 72)
                    for tucked in [true, false] {
                        let frame = FloatingPetController.edgeFrame(expanded: expanded, edge: edge,
                            visible: visible, petSize: petSize, tucked: tucked)
                        XCTAssertTrue(visible.contains(frame))
                        XCTAssertEqual(frame.width, tucked ? 24 : expanded.width)
                        XCTAssertEqual(edge == .left ? frame.minX : frame.maxX,
                                       edge == .left ? visible.minX : visible.maxX)
                    }
                }
            }
        }
    }

    func testEdgePeekContainsSpritePixelsAtAllPetSizes() throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        for petSize: Double in [48, 96, 384] {
            fixture.usage.floatingPetSize = petSize
            for edge in [FloatingPetController.TuckEdge.left, .right] {
                let root = FloatingPetView(animated: false, tuckedEdge: edge)
                    .environment(fixture.usage).environment(fixture.companion).environment(fixture.focus)
                let bitmap = NSBitmapImageRep(cgImage: try XCTUnwrap(ImageRenderer(content: root).cgImage))
                XCTAssertEqual(bitmap.pixelsWide, 24)
                let visiblePixels = (0..<bitmap.pixelsWide).contains { x in
                    (0..<bitmap.pixelsHigh).contains { y in
                        (bitmap.colorAt(x: x, y: y)?.alphaComponent ?? 0) > 0.1
                    }
                }
                XCTAssertTrue(visiblePixels, "\(edge), \(petSize): transparent sprite padding must not hide the peek")
            }
        }
    }

    func testNativeEdgeMenuHoverTimerAndRestore() async throws {
        let screen = try XCTUnwrap(NSScreen.main)
        let originalMouse = NSEvent.mouseLocation
        func movePointer(_ point: NSPoint) {
            CGWarpMouseCursorPosition(CGPoint(x: point.x,
                y: (NSScreen.screens.first?.frame.maxY ?? 0) - point.y))
        }
        defer { movePointer(originalMouse) }
        movePointer(NSPoint(x: screen.visibleFrame.midX, y: screen.visibleFrame.maxY - 5))
        let output = ProcessInfo.processInfo.environment["PTB_EDGE_PREVIEW_DIR"].map { URL(fileURLWithPath: $0) }
        if let output { try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true) }

        for edge in [FloatingPetController.TuckEdge.left, .right] {
            let fixture = try Fixture()
            defer { fixture.remove() }
            fixture.companion.setLanguage(.en)
            fixture.usage.floatingPetEnabled = true
            fixture.defaults.set(edge == .left ? screen.visibleFrame.minX + 48 : screen.visibleFrame.maxX - 160,
                                 forKey: "floatingPetOriginX")
            fixture.defaults.set(screen.visibleFrame.minY + 100, forKey: "floatingPetOriginY")
            fixture.focus.startPomodoro()
            let controller = FloatingPetController(store: fixture.usage, companion: fixture.companion,
                session: fixture.focus, defaults: fixture.defaults)
            defer { controller.setDisplayAwake(false) }
            let panel = try XCTUnwrap(NSApp.windows.compactMap { $0 as? FloatingPetPanel }.first { $0.isVisible })
            let host = try XCTUnwrap(panel.contentView as? PetHostingView)
            let normal = panel.frame
            let savedX = fixture.defaults.double(forKey: "floatingPetOriginX")
            let savedY = fixture.defaults.double(forKey: "floatingPetOriginY")

            func settle() async throws { try await Task.sleep(for: .milliseconds(100)) }
            func toggleFromMenu() throws {
                let menu = host.makeContextMenu()
                let index = menu.indexOfItem(withTitle: "Tuck at screen edge")
                XCTAssertGreaterThanOrEqual(index, 0)
                let item = try XCTUnwrap(menu.item(at: index))
                XCTAssertEqual(item.state, controller.tuckEdge == nil ? .off : .on)
                menu.performActionForItem(at: index)
            }
            func snapshot(_ name: String) throws {
                guard let output else { return }
                host.layoutSubtreeIfNeeded()
                let bitmap = try XCTUnwrap(host.bitmapImageRepForCachingDisplay(in: host.bounds))
                host.cacheDisplay(in: host.bounds, to: bitmap)
                try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
                    .write(to: output.appendingPathComponent("edge-\(edge)-\(name).png"))
            }

            try toggleFromMenu()
            try await settle()
            XCTAssertEqual(controller.tuckEdge, edge)
            XCTAssertEqual(panel.frame.width, 24)
            XCTAssertEqual(panel.frame.height, 96)
            XCTAssertEqual(host.fittingSize.width, 24, accuracy: 1, "Tucked mode contains only the cropped sprite")
            XCTAssertFalse(host.hasIsland)
            XCTAssertEqual(fixture.defaults.string(forKey: FloatingPetController.tuckEdgeKey), edge.rawValue)
            try snapshot("tucked")

            host.onHoverChange?(true)
            try await settle()
            XCTAssertNil(host.tuckedEdge)
            XCTAssertTrue(host.hasIsland)
            XCTAssertEqual(panel.frame.size, normal.size)
            XCTAssertTrue(screen.visibleFrame.contains(panel.frame))
            XCTAssertEqual(edge == .left ? panel.frame.minX : panel.frame.maxX,
                           edge == .left ? screen.visibleFrame.minX : screen.visibleFrame.maxX)
            try snapshot("revealed")
            controller.resizeTimer(to: 350, keepingRightEdge: NSPoint(x: panel.frame.maxX, y: panel.frame.minY))
            try await settle()
            XCTAssertEqual(controller.tuckEdge, edge, "Resizing must retain edge mode")
            XCTAssertEqual(fixture.usage.floatingTimerWidth, 350)

            fixture.usage.floatingPetIslandFolded = true
            try await settle()
            for type in [NSEvent.EventType.leftMouseDown, .leftMouseUp] {
                panel.sendEvent(try XCTUnwrap(NSEvent.mouseEvent(with: type, location: NSPoint(x: 82, y: 17),
                    modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime,
                    windowNumber: panel.windowNumber, context: nil, eventNumber: 1, clickCount: 1, pressure: 1)))
            }
            XCTAssertTrue(fixture.focus.session?.userPaused == true, "Revealed controls must receive real clicks")

            host.onHoverChange?(false)
            try await Task.sleep(for: .milliseconds(100))
            host.onHoverChange?(true)
            try await Task.sleep(for: .milliseconds(400))
            XCTAssertGreaterThan(panel.frame.width, 24, "Returning before the delay cancels tucking")

            host.onMenuTrackingChange?(true)
            host.onHoverChange?(false)
            try await Task.sleep(for: .milliseconds(450))
            XCTAssertGreaterThan(panel.frame.width, 24, "A right-click menu must hold the overlay open")
            host.onMenuTrackingChange?(false)
            host.onHoverChange?(true)
            try await settle()
            for type in [NSEvent.EventType.leftMouseDown, .leftMouseUp] {
                panel.sendEvent(try XCTUnwrap(NSEvent.mouseEvent(with: type, location: NSPoint(x: 45, y: 17),
                    modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime,
                    windowNumber: panel.windowNumber, context: nil, eventNumber: 1, clickCount: 1, pressure: 1)))
            }
            try await Task.sleep(for: .milliseconds(300))
            func fields(_ view: NSView) -> [NSTextField] {
                (view as? NSTextField).map { [$0] } ?? view.subviews.flatMap(fields)
            }
            let field = try XCTUnwrap(NSApp.windows.filter(\.isVisible).compactMap(\.contentView)
                .flatMap(fields).first { $0.isEditable && $0.placeholderString == "Minutes" })
            let editorWindow = try XCTUnwrap(field.window)
            XCTAssertNotNil(field.currentEditor())
            host.onHoverChange?(false)
            try await Task.sleep(for: .milliseconds(450))
            XCTAssertGreaterThan(panel.frame.width, 24, "Open timer popovers must keep the overlay revealed")
            editorWindow.sendEvent(try XCTUnwrap(NSEvent.keyEvent(with: .keyDown, location: .zero,
                modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime,
                windowNumber: editorWindow.windowNumber, context: nil, characters: "\u{1b}",
                charactersIgnoringModifiers: "\u{1b}", isARepeat: false, keyCode: 53)))
            for _ in 0..<20 where editorWindow.isVisible || panel.frame.width != 24 {
                try await Task.sleep(for: .milliseconds(100))
            }
            XCTAssertFalse(editorWindow.isVisible)
            XCTAssertEqual(panel.frame.width, 24, "Leaving tucks after the popover closes")
            XCTAssertEqual(fixture.defaults.double(forKey: "floatingPetOriginX"), savedX)
            XCTAssertEqual(fixture.defaults.double(forKey: "floatingPetOriginY"), savedY)

            controller.setDisplayAwake(false)
            controller.setDisplayAwake(true)
            XCTAssertEqual(panel.frame.width, 24, "Wake returns to the edge peek")
            fixture.usage.floatingTimerWidth = 384
            try toggleFromMenu()
            fixture.usage.floatingPetIslandFolded = false
            try await settle()
            XCTAssertNil(controller.tuckEdge)
            XCTAssertNil(fixture.defaults.string(forKey: FloatingPetController.tuckEdgeKey))
            XCTAssertEqual(panel.frame.maxX - 96, normal.maxX - 96, accuracy: 1)
            XCTAssertEqual(panel.frame.minY, normal.minY, accuracy: 1)

            try toggleFromMenu()
            controller.setDisplayAwake(false)
            let restored = FloatingPetController(store: fixture.usage, companion: fixture.companion,
                session: fixture.focus, defaults: fixture.defaults)
            XCTAssertEqual(restored.tuckEdge, edge, "Edge choice survives relaunch")
            let restoredPanel = try XCTUnwrap(NSApp.windows.compactMap { $0 as? FloatingPetPanel }.first { $0.isVisible })
            XCTAssertEqual(restoredPanel.frame.width, 24)
            let restoredHost = try XCTUnwrap(restoredPanel.contentView as? PetHostingView)
            XCTAssertTrue(restoredHost.accessibilityPerformPress(), "The edge peek can be revealed without a pointer")
            XCTAssertGreaterThan(restoredPanel.frame.width, 24)
            let handle = FloatingTimerDragView(frame: NSRect(x: 0, y: 0, width: 16, height: 30))
            restoredHost.addSubview(handle)
            let beforeMove = restoredPanel.frame.minY
            handle.keyDown(with: try XCTUnwrap(NSEvent.keyEvent(with: .keyDown, location: .zero,
                modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime,
                windowNumber: restoredPanel.windowNumber, context: nil, characters: "",
                charactersIgnoringModifiers: "", isARepeat: false, keyCode: 126)))
            XCTAssertEqual(restoredPanel.frame.minY, beforeMove + 8)
            XCTAssertNil(restored.tuckEdge, "Repositioning leaves edge mode instead of snapping the drag back")
            XCTAssertNil(fixture.defaults.string(forKey: FloatingPetController.tuckEdgeKey))
            restored.setDisplayAwake(false)
        }
    }

    func testPetHostingPreservesOtherTrackingAreasForSwiftUIHover() {
        let host = PetHostingView(rootView: AnyView(Color.clear))
        host.frame = NSRect(x: 0, y: 0, width: 500, height: 96)
        let ownedElsewhere = NSTrackingArea(rect: host.bounds,
            options: [.activeAlways, .mouseEnteredAndExited], owner: host, userInfo: nil)
        host.addTrackingArea(ownedElsewhere)
        for _ in 0..<3 {
            host.updateTrackingAreas()
            XCTAssertTrue(host.trackingAreas.contains { $0 === ownedElsewhere })
        }
    }

    func testWidthRestoresAndRejectsInvalidSavedSizes() throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        XCTAssertEqual(fixture.usage.floatingTimerWidth, 384)
        fixture.usage.floatingTimerWidth = 562
        XCTAssertEqual(fixture.defaults.double(forKey: FloatingTimerMetrics.widthKey), 562)
        XCTAssertEqual(fixture.makeUsage().floatingTimerWidth, 562)
        for value in [-100.0, 0.0, 10_000.0, Double.nan, Double.infinity] {
            fixture.usage.floatingTimerWidth = value
            XCTAssertTrue(fixture.usage.floatingTimerWidth.isFinite)
            XCTAssertTrue((288...720).contains(fixture.usage.floatingTimerWidth))
        }
        fixture.defaults.set(10_000, forKey: FloatingTimerMetrics.widthKey)
        XCTAssertEqual(fixture.makeUsage().floatingTimerWidth, 720)
    }

    func testResizingKeepsHeightAndFoldedPromptsAndPetAnchor() {
        for width: CGFloat in [288, 384, 720] {
            let expanded = FloatingPetController.panelSize(petSize: 96, showingBubble: false,
                hasIsland: true, prompt: .none, timerWidth: width)
            XCTAssertEqual(expanded.height, 96)
            XCTAssertEqual(expanded.width, width + 96 + FloatingPetController.islandFoldChevronSize + 16)
            let folded = FloatingPetController.panelSize(petSize: 96, showingBubble: false,
                hasIsland: true, prompt: .none, islandFolded: true, timerWidth: width)
            XCTAssertEqual(folded.width, 96 + 88 + 32 + 16 + 25)
            for prompt in [FocusPrompt.zeroTime, .checkIn] {
                let prompted = FloatingPetController.panelSize(petSize: 96, showingBubble: false,
                    hasIsland: true, prompt: prompt, timerWidth: width)
                XCTAssertGreaterThan(prompted.height, expanded.height)
                XCTAssertEqual(prompted.width, expanded.width)
            }
            let pet = NSPoint(x: 600, y: 180)
            let origin = FloatingPetController.panelOrigin(petOrigin: pet, petSize: 96,
                panelSize: expanded, hasIsland: true)
            XCTAssertEqual(FloatingPetController.petOrigin(panelOrigin: origin, petSize: 96,
                panelSize: expanded, hasIsland: true), pet)
        }
        let screen = NSRect(x: -1280, y: 40, width: 1280, height: 760)
        let fitted = FloatingTimerMetrics.constrained(NSRect(x: -2000, y: -100, width: 600, height: 96), to: screen)
        XCTAssertTrue(screen.contains(fitted))
        XCTAssertEqual(FloatingTimerMetrics.width(650, available: 500), 500)
    }

    func testNativeResizeAndKeyboardMovePersistAndSurviveFold() async throws {
        let screen = try XCTUnwrap(NSScreen.main, "Native overlay validation needs a display server")
        let fixture = try Fixture()
        defer { fixture.remove() }
        fixture.defaults.set(screen.visibleFrame.maxX - 140, forKey: "floatingPetOriginX")
        fixture.defaults.set(screen.visibleFrame.minY + 100, forKey: "floatingPetOriginY")
        fixture.usage.floatingPetEnabled = true
        fixture.focus.startPomodoro()
        let controller = FloatingPetController(store: fixture.usage, companion: fixture.companion,
                                               session: fixture.focus, defaults: fixture.defaults)
        defer { controller.setDisplayAwake(false) }
        let panel = try XCTUnwrap(NSApp.windows.compactMap { $0 as? FloatingPetPanel }.first { $0.isVisible })
        let original = panel.frame
        controller.resizeTimer(to: 350, keepingRightEdge: NSPoint(x: original.maxX, y: original.minY))
        XCTAssertEqual(panel.frame.maxX, original.maxX, accuracy: 0.1)
        XCTAssertEqual(panel.frame.height, original.height)
        XCTAssertEqual(panel.frame.width, original.width - 34, accuracy: 0.1)
        try await Task.sleep(for: .milliseconds(70))
        XCTAssertEqual(panel.frame.maxX, original.maxX, accuracy: 0.1, "Observation must not jump the strip back")
        let anchor = NSPoint(x: fixture.defaults.double(forKey: "floatingPetOriginX"),
                             y: fixture.defaults.double(forKey: "floatingPetOriginY"))
        fixture.usage.floatingPetIslandFolded = true
        try await Task.sleep(for: .milliseconds(70))
        XCTAssertEqual(panel.frame.maxX - 96, anchor.x, accuracy: 0.1)
        fixture.usage.floatingPetIslandFolded = false
        try await Task.sleep(for: .milliseconds(70))
        XCTAssertEqual(fixture.usage.floatingTimerWidth, 350)
        XCTAssertEqual(panel.frame.maxX - 96, anchor.x, accuracy: 0.1)

        let handle = FloatingTimerDragView(frame: NSRect(x: 0, y: 0, width: 16, height: 34))
        panel.contentView?.addSubview(handle)
        handle.mode = .move
        let before = panel.frame.origin
        let key = try XCTUnwrap(NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [],
            timestamp: 0, windowNumber: panel.windowNumber, context: nil,
            characters: "", charactersIgnoringModifiers: "", isARepeat: false, keyCode: 123))
        handle.keyDown(with: key)
        XCTAssertEqual(panel.frame.minX, before.x - 8, accuracy: 0.1)
        handle.mode = .resize
        handle.timerWidth = 350
        handle.onResize = { width, anchor in controller.resizeTimer(to: width, keepingRightEdge: anchor) }
        XCTAssertTrue(handle.accessibilityPerformIncrement())
        XCTAssertEqual(fixture.usage.floatingTimerWidth, 366)
        let rightEdge = panel.frame.maxX
        handle.timerWidth = 366
        handle.keyDown(with: key)
        XCTAssertEqual(fixture.usage.floatingTimerWidth, 374, "Moving the left resize edge left widens the timer")
        XCTAssertEqual(panel.frame.maxX, rightEdge, accuracy: 0.1, "Resizing keeps the pet stationary")
    }

    func testNativeStripFitsBothAppearancesAndAllLanguages() async throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        fixture.focus.startPomodoro()
        let output = ProcessInfo.processInfo.environment["PTB_FLOATING_PREVIEW_DIR"].map { URL(fileURLWithPath: $0) }
        if let output { try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true) }
        for scheme in [ColorScheme.dark, .light] {
            for language in AppLanguage.allCases {
                fixture.companion.setLanguage(language)
                for width: Double in [288, 384, 720] {
                    fixture.usage.floatingTimerWidth = width
                    let root = FloatingTimerStrip(hovering: true)
                        .environment(fixture.usage).environment(fixture.companion).environment(fixture.focus)
                        .environment(\.colorScheme, scheme)
                    let host = NSHostingView(rootView: root)
                    let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: width, height: 42),
                        styleMask: .borderless, backing: .buffered, defer: false)
                    window.appearance = NSAppearance(named: scheme == .dark ? .darkAqua : .aqua)
                    window.contentView = host
                    host.frame = NSRect(x: 0, y: 0, width: width, height: 42)
                    host.layoutSubtreeIfNeeded()
                    XCTAssertEqual(host.fittingSize.width, width, accuracy: 1, "\(scheme), \(language)")
                    XCTAssertEqual(host.fittingSize.height, 42, accuracy: 1)
                    if let output, language == .en, width <= 384 {
                        try await Task.sleep(for: .milliseconds(60))
                        let bitmap = try XCTUnwrap(host.bitmapImageRepForCachingDisplay(in: host.bounds))
                        host.cacheDisplay(in: host.bounds, to: bitmap)
                        try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
                            .write(to: output.appendingPathComponent("strip-\(scheme)-\(Int(width)).png"))
                    }
                    window.contentView = nil
                }
            }
        }
        fixture.focus.togglePause()
        XCTAssertTrue(fixture.focus.session?.userPaused == true)
        fixture.focus.addRemainingMinutes(5)
        XCTAssertFalse(fixture.focus.session?.userPaused ?? true, "Adding time retains the existing resume behavior")
        XCTAssertEqual(fixture.focus.clockDisplay().text, "55:00")
        fixture.focus.finishLeavingInProgress()
        XCTAssertNil(fixture.focus.session)
        if let output { try await renderPromptPreviews(output: output) }
    }

    /// Optional native visual review of the pop-outs in the real overlay layout.
    /// Keep the existing strip/compact/drag interaction checks independent of screenshots.
    private func renderPromptPreviews(output: URL) async throws {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        var issue = FocusPinnedIssue.pomodoro(title: "Shape the next small task").summary
        issue.id = "prompt-preview"
        issue.identifier = "TEST-1"
        for scheme in [ColorScheme.dark, .light] {
            for folded in [false, true] {
                for mode in ["check-in", "time-up", "reset", "forfeit", "note"] {
                    let fixture = try Fixture()
                    defer { fixture.remove() }
                    fixture.companion.setLanguage(.en)
                    fixture.usage.floatingPetEnabled = true
                    fixture.usage.floatingPetSize = 96
                    fixture.usage.floatingTimerWidth = 288
                    fixture.usage.floatingPetIslandFolded = folded
                    var previewNow = now
                    let focus = FocusSessionStore(usage: fixture.usage, companion: fixture.companion,
                        clock: { previewNow }, fileURL: fixture.directory.appendingPathComponent("preview-focus.json"),
                        ticksOnTimer: false)
                    focus.checkInMinutes = 5
                    focus.pin(issue, openDesk: false, minutes: 25)
                    switch mode {
                    case "check-in":
                        previewNow = now.addingTimeInterval(5 * 60)
                        focus.tick()
                    case "time-up":
                        previewNow = now.addingTimeInterval(25 * 60)
                        focus.tick()
                    case "reset":
                        previewNow = now.addingTimeInterval(60)
                        focus.tick()
                        focus.requestReset()
                    case "forfeit": focus.requestUnfocus()
                    default: focus.toggleNoteComposer()
                    }
                    let size = FloatingPetController.panelSize(petSize: 96,
                        showingBubble: fixture.usage.currentSpeechBubble != nil,
                        hasIsland: true, prompt: focus.prompt, composingNote: focus.isComposingNote,
                        confirm: mode == "forfeit" ? .forfeit : mode == "reset" ? .reset : .none,
                        islandFolded: folded, timerWidth: 288)
                    let host = NSHostingView(rootView: FloatingPetView(animated: false)
                        .environment(fixture.usage).environment(fixture.companion).environment(focus)
                        .environment(\.colorScheme, scheme))
                    let window = NSWindow(contentRect: NSRect(origin: .zero, size: size),
                        styleMask: .borderless, backing: .buffered, defer: false)
                    let appearance: NSAppearance.Name = folded
                        ? (scheme == .dark ? .accessibilityHighContrastDarkAqua : .accessibilityHighContrastAqua)
                        : (scheme == .dark ? .darkAqua : .aqua)
                    window.appearance = NSAppearance(named: appearance)
                    window.isOpaque = false
                    window.backgroundColor = .clear
                    window.contentView = host
                    host.frame = NSRect(origin: .zero, size: size)
                    host.layoutSubtreeIfNeeded()
                    try await Task.sleep(for: .milliseconds(80))
                    let bitmap = try XCTUnwrap(host.bitmapImageRepForCachingDisplay(in: host.bounds))
                    host.cacheDisplay(in: host.bounds, to: bitmap)
                    try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
                        .write(to: output.appendingPathComponent("prompt-\(mode)-\(scheme)-\(folded ? "compact-high-contrast" : "expanded").png"))
                    window.contentView = nil
                    focus.cancelReset()
                    focus.cancelForfeit()
                    focus.finishLeavingInProgress()
                }
            }
        }
    }

    func testNativeCompactAndPetOnlyControlsInBothAppearances() async throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        fixture.usage.floatingPetSize = 96
        let output = ProcessInfo.processInfo.environment["PTB_FLOATING_PREVIEW_DIR"].map { URL(fileURLWithPath: $0) }
        if let output { try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true) }

        for scheme in [ColorScheme.dark, .light] {
            for language in AppLanguage.allCases {
                fixture.companion.setLanguage(language)
                let root = FloatingPetView(animated: false)
                    .environment(fixture.usage).environment(fixture.companion).environment(fixture.focus)
                    .environment(\.colorScheme, scheme)
                let host = PetHostingView(rootView: AnyView(root))
                host.hasIsland = true
                host.petSize = 96
                let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 136, height: 96),
                    styleMask: .borderless, backing: .buffered, defer: false)
                window.appearance = NSAppearance(named: scheme == .dark ? .darkAqua : .aqua)
                window.contentView = host
                window.orderBack(nil)

                func settle() async throws {
                    let size = FloatingPetController.panelSize(petSize: 96, showingBubble: false,
                        hasIsland: fixture.focus.isActive, prompt: fixture.focus.prompt,
                        islandFolded: fixture.usage.floatingPetIslandFolded,
                        showsTimerToggle: true, setupIsland: fixture.focus.pomodoroSetupOpen)
                    window.setContentSize(size)
                    host.frame = NSRect(origin: .zero, size: size)
                    host.layoutSubtreeIfNeeded()
                    try await Task.sleep(for: .milliseconds(60))
                    XCTAssertEqual(host.fittingSize.width, size.width, accuracy: 1)
                    XCTAssertLessThanOrEqual(host.fittingSize.height, size.height + 1,
                        "The panel may reserve prompt/setup space, but must never clip the controls")
                }
                func click(x: CGFloat, y: CGFloat = 17) throws {
                    for type in [NSEvent.EventType.leftMouseDown, .leftMouseUp] {
                        let event = try XCTUnwrap(NSEvent.mouseEvent(with: type,
                            location: NSPoint(x: x, y: y), modifierFlags: [],
                            timestamp: ProcessInfo.processInfo.systemUptime,
                            windowNumber: window.windowNumber, context: nil,
                            eventNumber: 1, clickCount: 1, pressure: type == .leftMouseDown ? 1 : 0))
                        window.sendEvent(event)
                    }
                }
                func snapshot(_ name: String) throws {
                    guard let output, language == .en else { return }
                    let bitmap = try XCTUnwrap(host.bitmapImageRepForCachingDisplay(in: host.bounds))
                    host.cacheDisplay(in: host.bounds, to: bitmap)
                    try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
                        .write(to: output.appendingPathComponent("\(name)-\(scheme).png"))
                }

                try await settle()
                try snapshot("pet-only")
                try click(x: 16)
                XCTAssertTrue(fixture.focus.pomodoroSetupOpen)
                try await settle()
                fixture.focus.cancelPomodoroSetup()
                XCTAssertFalse(fixture.focus.pomodoroSetupOpen)

                fixture.focus.startPomodoro()
                fixture.usage.floatingPetIslandFolded = true
                try await settle()
                try snapshot("compact")
                try click(x: 82)
                XCTAssertTrue(fixture.focus.session?.userPaused == true)
                XCTAssertTrue(fixture.usage.floatingPetIslandFolded, "Pause must not expand the timer")
                try await settle()
                try snapshot("compact-paused")
                try click(x: 82)
                XCTAssertFalse(fixture.focus.session?.userPaused ?? true)
                try await settle()
                try click(x: 108)
                XCTAssertFalse(fixture.usage.floatingPetIslandFolded)
                fixture.focus.finishLeavingInProgress()
                window.orderOut(nil)
                window.contentView = nil
            }
        }
    }

    func testExpandedSetupAndRunningFlowDrawsAndRetainsControls() async throws {
        let screen = try XCTUnwrap(NSScreen.main, "Native overlay validation needs a display server")
        let fixture = try Fixture()
        defer { fixture.remove() }
        fixture.companion.setLanguage(.en)
        fixture.usage.floatingPetEnabled = true
        fixture.usage.floatingPetIslandFolded = false
        fixture.usage.floatingPetSize = 96
        fixture.defaults.set(screen.visibleFrame.maxX - 200, forKey: "floatingPetOriginX")
        fixture.defaults.set(screen.visibleFrame.minY + 100, forKey: "floatingPetOriginY")
        let controller = FloatingPetController(store: fixture.usage, companion: fixture.companion,
            session: fixture.focus, defaults: fixture.defaults)
        defer { controller.setDisplayAwake(false) }
        let panel = try XCTUnwrap(NSApp.windows.compactMap { $0 as? FloatingPetPanel }.first { $0.isVisible })
        let host = try XCTUnwrap(panel.contentView)
        let output = ProcessInfo.processInfo.environment["PTB_FLOATING_PREVIEW_DIR"].map { URL(fileURLWithPath: $0) }
        if let output { try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true) }

        func handles(in view: NSView) -> [FloatingTimerDragView] {
            (view as? FloatingTimerDragView).map { [$0] } ?? view.subviews.flatMap { handles(in: $0) }
        }
        func settle() async throws {
            try await Task.sleep(for: .milliseconds(120))
            host.layoutSubtreeIfNeeded()
        }
        func click(x: CGFloat, y: CGFloat) throws {
            for type in [NSEvent.EventType.leftMouseDown, .leftMouseUp] {
                let event = try XCTUnwrap(NSEvent.mouseEvent(with: type,
                    location: NSPoint(x: x, y: y), modifierFlags: [],
                    timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: panel.windowNumber,
                    context: nil, eventNumber: 1, clickCount: 1,
                    pressure: type == .leftMouseDown ? 1 : 0))
                panel.sendEvent(event)
            }
        }
        func checkStrip(_ name: String) throws {
            XCTAssertEqual(panel.frame.width, CGFloat(fixture.usage.floatingTimerWidth) + 144, accuracy: 1)
            XCTAssertEqual(panel.frame.height, 96, accuracy: 1, "Opening the timer stays horizontal")
            XCTAssertEqual(handles(in: host).count, 2, "Both drag handles must be present in the actual expanded panel")
            let resize = try XCTUnwrap(handles(in: host).first { $0.mode == .resize })
            let move = try XCTUnwrap(handles(in: host).first { $0.mode == .move })
            XCTAssertLessThan(resize.convert(resize.bounds, to: host).maxX,
                              move.convert(move.bounds, to: host).minX, "Resize belongs on the left and move on the right")
            let bitmap = try XCTUnwrap(host.bitmapImageRepForCachingDisplay(in: host.bounds))
            host.cacheDisplay(in: host.bounds, to: bitmap)
            let scale = CGFloat(bitmap.pixelsWide) / host.bounds.width
            let pixel = try XCTUnwrap(bitmap.colorAt(x: Int(150 * scale),
                y: bitmap.pixelsHigh - Int(24 * scale)))
            XCTAssertGreaterThan(pixel.alphaComponent, 0.95, "The actual timer surface must be drawn, not transparent reserved space")
            if let output {
                try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
                    .write(to: output.appendingPathComponent(name + ".png"))
            }
        }

        for appearance in [NSAppearance.Name.darkAqua, .aqua] {
            panel.appearance = NSAppearance(named: appearance)
            try await settle()
            try click(x: 16, y: 16)
            XCTAssertTrue(fixture.focus.pomodoroSetupOpen)
            try await settle()
            try checkStrip("setup-\(appearance.rawValue)")
            let resize = try XCTUnwrap(handles(in: host).first { $0.mode == .resize })
            let beforeResize = fixture.usage.floatingTimerWidth
            let rightEdge = panel.frame.maxX
            XCTAssertTrue(resize.accessibilityPerformIncrement())
            try await settle()
            XCTAssertEqual(fixture.usage.floatingTimerWidth, beforeResize + 16)
            XCTAssertEqual(panel.frame.maxX, rightEdge, accuracy: 0.1)
            let width = CGFloat(fixture.usage.floatingTimerWidth)
            let petX = panel.frame.maxX - 96
            try click(x: width - 64.5, y: 21)
            XCTAssertTrue(fixture.focus.isActive, "Start must work from the actual setup strip")
            try await settle()
            XCTAssertFalse(fixture.focus.pomodoroSetupOpen)
            XCTAssertEqual(panel.frame.maxX - 96, petX, accuracy: 0.1)
            try checkStrip("running-\(appearance.rawValue)")
            let move = try XCTUnwrap(handles(in: host).first { $0.mode == .move })
            _ = move.becomeFirstResponder()
            try await settle()
            try click(x: 117.5, y: 21)
            XCTAssertTrue(fixture.focus.session?.userPaused == true, "Pause must work inside the complete expanded overlay")
            try checkStrip("controls-\(appearance.rawValue)")
            try click(x: width + 24, y: 16)
            try await settle()
            XCTAssertTrue(fixture.usage.floatingPetIslandFolded)
            XCTAssertTrue(handles(in: host).isEmpty)
            try click(x: 108, y: 17)
            try await settle()
            XCTAssertFalse(fixture.usage.floatingPetIslandFolded)
            XCTAssertEqual(panel.frame.maxX - 96, petX, accuracy: 0.1)
            try checkStrip("reexpanded-\(appearance.rawValue)")
            fixture.focus.finishLeavingInProgress()
            try await settle()
        }
    }

    func testClockOpensNativeMinutesEditorAndAppliesCustomValues() async throws {
        let screen = try XCTUnwrap(NSScreen.main)
        let fixture = try Fixture()
        defer { fixture.remove() }
        fixture.companion.setLanguage(.en)
        fixture.usage.floatingPetEnabled = true
        fixture.defaults.set(screen.visibleFrame.maxX - 200, forKey: "floatingPetOriginX")
        fixture.defaults.set(screen.visibleFrame.minY + 200, forKey: "floatingPetOriginY")
        let controller = FloatingPetController(store: fixture.usage, companion: fixture.companion,
            session: fixture.focus, defaults: fixture.defaults)
        defer { controller.setDisplayAwake(false) }
        let panel = try XCTUnwrap(NSApp.windows.compactMap { $0 as? FloatingPetPanel }.first { $0.isVisible })
        func fields(_ view: NSView) -> [NSTextField] {
            (view as? NSTextField).map { [$0] } ?? view.subviews.flatMap(fields)
        }
        func clickClock() async throws -> NSTextField {
            try await Task.sleep(for: .milliseconds(150))
            for type in [NSEvent.EventType.leftMouseDown, .leftMouseUp] {
                let event = try XCTUnwrap(NSEvent.mouseEvent(with: type, location: NSPoint(x: 45, y: 21),
                    modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime,
                    windowNumber: panel.windowNumber, context: nil, eventNumber: 1, clickCount: 1, pressure: 1))
                panel.sendEvent(event)
            }
            try await Task.sleep(for: .milliseconds(300))
            let field = try XCTUnwrap(NSApp.windows.filter { $0.isVisible }.flatMap {
                $0.contentView.map(fields) ?? []
            }.first { $0.isEditable && $0.placeholderString == "Minutes" })
            XCTAssertTrue(field.window?.isKeyWindow == true, "The editor must receive typing in the floating panel")
            XCTAssertNotNil(field.currentEditor())
            if let path = ProcessInfo.processInfo.environment["PTB_FLOATING_PREVIEW_DIR"],
               let content = field.window?.contentView {
                let output = URL(fileURLWithPath: path)
                try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
                let bitmap = try XCTUnwrap(content.bitmapImageRepForCachingDisplay(in: content.bounds))
                content.cacheDisplay(in: content.bounds, to: bitmap)
                let mode = fixture.focus.isActive ? "remaining" : "setup"
                try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
                    .write(to: output.appendingPathComponent("editor-\(mode)-\(panel.appearance!.name.rawValue).png"))
            }
            return field
        }
        func type(_ text: String, into field: NSTextField, commit: Bool = true) async throws {
            let window = try XCTUnwrap(field.window)
            let editor = try XCTUnwrap(field.currentEditor() as? NSTextView)
            editor.selectAll(nil)
            for character in text {
                let event = try XCTUnwrap(NSEvent.keyEvent(with: .keyDown, location: .zero,
                    modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime,
                    windowNumber: window.windowNumber, context: nil, characters: String(character),
                    charactersIgnoringModifiers: String(character), isARepeat: false, keyCode: 0))
                window.sendEvent(event)
            }
            if commit {
                window.sendEvent(try XCTUnwrap(NSEvent.keyEvent(with: .keyDown, location: .zero,
                    modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime,
                    windowNumber: window.windowNumber, context: nil, characters: "\r",
                    charactersIgnoringModifiers: "\r", isARepeat: false, keyCode: 36)))
            }
            try await Task.sleep(for: .milliseconds(180))
        }
        func clickEditor(_ field: NSTextField, x: CGFloat, fromTop: CGFloat) async throws {
            let window = try XCTUnwrap(field.window)
            let content = try XCTUnwrap(window.contentView)
            let y = content.isFlipped ? fromTop : content.bounds.height - fromTop
            let point = content.convert(NSPoint(x: x, y: y), to: nil)
            for type in [NSEvent.EventType.leftMouseDown, .leftMouseUp] {
                window.sendEvent(try XCTUnwrap(NSEvent.mouseEvent(with: type, location: point,
                    modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime,
                    windowNumber: window.windowNumber, context: nil, eventNumber: 1, clickCount: 1, pressure: 1)))
            }
            try await Task.sleep(for: .milliseconds(180))
        }
        for appearance in [NSAppearance.Name.darkAqua, .aqua] {
            panel.appearance = NSAppearance(named: appearance)
            fixture.focus.openPomodoroSetup()
            var field = try await clickClock()
            try await clickEditor(field, x: 58, fromTop: 66)
            XCTAssertEqual(fixture.focus.plannedMinutes, 25, "Clicking a preset applies it directly")
            field = try await clickClock()
            try await type("17", into: field)
            XCTAssertEqual(fixture.focus.plannedMinutes, 17)
            XCTAssertFalse(fixture.focus.isActive)
            fixture.focus.startPomodoro()
            field = try await clickClock()
            try await type("12", into: field)
            XCTAssertEqual(fixture.focus.clockDisplay().text, "12:00")
            fixture.focus.togglePause()
            fixture.usage.floatingPetIslandFolded = true
            field = try await clickClock()
            try await type("8", into: field, commit: false)
            try await clickEditor(field, x: 220, fromTop: 162)
            XCTAssertEqual(fixture.focus.clockDisplay().text, "8:00")
            XCTAssertTrue(fixture.focus.session?.userPaused == true)
            XCTAssertTrue(fixture.usage.floatingPetIslandFolded)
            field = try await clickClock()
            try await type("abc", into: field)
            XCTAssertEqual(fixture.focus.clockDisplay().text, "8:00", "Invalid input must not change the clock")
            XCTAssertNotNil(field.currentEditor(), "Invalid input leaves the editor open")
            try await type("15", into: field, commit: false)
            let editorWindow = try XCTUnwrap(field.window)
            editorWindow.sendEvent(try XCTUnwrap(NSEvent.keyEvent(with: .keyDown, location: .zero,
                modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime,
                windowNumber: editorWindow.windowNumber, context: nil, characters: "\u{1b}",
                charactersIgnoringModifiers: "\u{1b}", isARepeat: false, keyCode: 53)))
            try await Task.sleep(for: .milliseconds(180))
            XCTAssertEqual(fixture.focus.clockDisplay().text, "8:00", "Escape cancels the pending edit")
            XCTAssertFalse(editorWindow.isVisible)
            fixture.focus.finishLeavingInProgress()
            fixture.usage.floatingPetIslandFolded = false
        }
    }

    func testNewIssueButtonOpensSharedComposerInEveryTimerState() async throws {
        let screen = try XCTUnwrap(NSScreen.main)
        let fixture = try Fixture()
        defer { fixture.remove() }
        fixture.companion.setLanguage(.en)
        fixture.usage.floatingPetEnabled = true
        fixture.usage.floatingTimerWidth = 288
        fixture.defaults.set(screen.visibleFrame.maxX - 200, forKey: "floatingPetOriginX")
        fixture.defaults.set(screen.visibleFrame.minY + 200, forKey: "floatingPetOriginY")
        // This fixture has no saved API key, so opening the real composer cannot fetch or create live issues.
        let composer = LinearIssueComposerController(usage: fixture.usage,
            companion: fixture.companion, session: fixture.focus)
        defer { composer.close() }
        let controller = FloatingPetController(store: fixture.usage, companion: fixture.companion,
            session: fixture.focus, defaults: fixture.defaults)
        defer { controller.setDisplayAwake(false) }
        let panel = try XCTUnwrap(NSApp.windows.compactMap { $0 as? FloatingPetPanel }.first { $0.isVisible })
        func composerWindow() -> NSWindow? {
            NSApp.windows.first { $0.identifier?.rawValue == LaunchWindowPolicy.newLinearIssueIdentifier && $0.isVisible }
        }
        func settle() async throws {
            try await Task.sleep(for: .milliseconds(180))
            panel.contentView?.layoutSubtreeIfNeeded()
        }
        func clickNewIssue(mode: String) async throws {
            func click(_ target: NSWindow, x: CGFloat, y: CGFloat) throws {
                func event(_ type: NSEvent.EventType) throws -> NSEvent {
                    try XCTUnwrap(NSEvent.mouseEvent(with: type, location: NSPoint(x: x, y: y),
                        modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime,
                        windowNumber: target.windowNumber, context: nil, eventNumber: 1, clickCount: 1, pressure: 1))
                }
                NSApp.postEvent(try event(.leftMouseUp), atStart: false)
                target.sendEvent(try event(.leftMouseDown))
                if let up = NSApp.nextEvent(matching: .leftMouseUp, until: Date(), inMode: .default, dequeue: true) {
                    target.sendEvent(up)
                }
            }
            let point = mode == "compact" ? NSPoint(x: 133, y: 17)
                : NSPoint(x: CGFloat(fixture.usage.floatingTimerWidth) - 36.5, y: 21)
            if mode == "expanded" {
                func findMove(_ view: NSView) -> FloatingTimerDragView? {
                    if let handle = view as? FloatingTimerDragView, handle.mode == .move { return handle }
                    return view.subviews.compactMap(findMove).first
                }
                _ = findMove(try XCTUnwrap(panel.contentView))?.becomeFirstResponder()
                try await settle()
                let windows = Set(NSApp.windows.map(\.windowNumber))
                try click(panel, x: 219, y: 21)
                try await settle()
                let popup = try XCTUnwrap(NSApp.windows.first { $0.isVisible && !windows.contains($0.windowNumber) })
                func descendants(_ view: NSView) -> [NSView] {
                    [view] + view.subviews.flatMap(descendants)
                }
                let hover = try XCTUnwrap(descendants(try XCTUnwrap(panel.contentView))
                    .compactMap { $0 as? FloatingTimerHoverView }.first)
                let exit = try XCTUnwrap(NSEvent.enterExitEvent(with: .mouseExited, location: .zero,
                    modifierFlags: [], timestamp: 0, windowNumber: panel.windowNumber, context: nil,
                    eventNumber: 1, trackingNumber: 0, userData: nil))
                hover.mouseExited(with: exit)
                try await Task.sleep(for: .milliseconds(2_500))
                XCTAssertTrue(popup.isVisible, "Leaving the timer must not dismiss its open menu")
                let host = try XCTUnwrap(descendants(try XCTUnwrap(popup.contentView)).first {
                    NSStringFromClass(type(of: $0)).contains("HostingView")
                })
                let location = host.convert(NSPoint(x: host.bounds.width - 37,
                    y: host.isFlipped ? 35 : host.bounds.height - 35), to: nil)
                try click(popup, x: location.x, y: location.y)
                try await settle()
                if popup.isVisible { popup.close() }
                return
            }
            for type in [NSEvent.EventType.leftMouseDown, .leftMouseUp] {
                panel.sendEvent(try XCTUnwrap(NSEvent.mouseEvent(with: type, location: point,
                    modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime,
                    windowNumber: panel.windowNumber, context: nil, eventNumber: 1, clickCount: 1, pressure: 1)))
            }
        }
        for appearance in [NSAppearance.Name.darkAqua, .aqua] {
            panel.appearance = NSAppearance(named: appearance)
            for mode in ["setup", "expanded", "compact"] {
                if mode == "setup" { fixture.focus.openPomodoroSetup() }
                else { fixture.focus.startPomodoro() }
                fixture.usage.floatingPetIslandFolded = mode == "compact"
                fixture.usage.linearIntegrationEnabled = false
                fixture.usage.linearAPIKeyConfigured = false
                try await settle()
                try await clickNewIssue(mode: mode)
                XCTAssertNil(composerWindow(), "Disconnected Linear must not open a composer")
                fixture.usage.linearIntegrationEnabled = true
                fixture.usage.linearAPIKeyConfigured = true
                try await settle()
                let beforeSession = fixture.focus.session
                let beforeFrame = panel.frame
                if mode == "expanded" {
                    func findMove(_ view: NSView) -> FloatingTimerDragView? {
                        if let handle = view as? FloatingTimerDragView, handle.mode == .move { return handle }
                        return view.subviews.compactMap(findMove).first
                    }
                    _ = findMove(try XCTUnwrap(panel.contentView))?.becomeFirstResponder()
                    try await settle()
                }
                try await clickNewIssue(mode: mode)
                try await settle()
                let window = try XCTUnwrap(composerWindow(), "The plus must open the shared composer in \(mode)")
                XCTAssertTrue(window.isKeyWindow)
                XCTAssertEqual(fixture.focus.session, beforeSession, "Opening the composer must not alter the timer")
                XCTAssertEqual(panel.frame, beforeFrame)
                composer.close()
                try await settle()
                XCTAssertNil(composerWindow())
                XCTAssertEqual(fixture.focus.session, beforeSession)
                if let path = ProcessInfo.processInfo.environment["PTB_FLOATING_PREVIEW_DIR"], let host = panel.contentView {
                    let output = URL(fileURLWithPath: path)
                    try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
                    let bitmap = try XCTUnwrap(host.bitmapImageRepForCachingDisplay(in: host.bounds))
                    host.cacheDisplay(in: host.bounds, to: bitmap)
                    try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
                        .write(to: output.appendingPathComponent("new-issue-\(mode)-\(appearance.rawValue).png"))
                }
                fixture.focus.cancelPomodoroSetup()
                fixture.focus.finishLeavingInProgress()
            }
        }
    }

    func testIssueFocusEntryPointsAskForTimeBeforeStartingInBothAppearances() async throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        fixture.companion.setLanguage(.en)
        var issue = FocusPinnedIssue.pomodoro(title: "Plan the next task").summary
        issue.id = "duration-issue"
        issue.identifier = "TEST-1"
        var navigations = 0
        var keyboardWindow: NSWindow?

        func settle() async throws { try await Task.sleep(for: .milliseconds(200)) }
        func click(_ window: NSWindow, x: CGFloat, fromTop: CGFloat) async throws {
            let content = try XCTUnwrap(window.contentView)
            let y = content.isFlipped ? fromTop : content.bounds.height - fromTop
            let point = content.convert(NSPoint(x: x, y: y), to: nil)
            for type in [NSEvent.EventType.leftMouseDown, .leftMouseUp] {
                window.sendEvent(try XCTUnwrap(NSEvent.mouseEvent(with: type, location: point,
                    modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime,
                    windowNumber: window.windowNumber, context: nil, eventNumber: 1, clickCount: 1, pressure: 1)))
            }
            try await settle()
        }
        func textFields(_ view: NSView) -> [NSTextField] {
            (view as? NSTextField).map { [$0] } ?? view.subviews.flatMap(textFields)
        }
        func minutesField() throws -> NSTextField {
            try XCTUnwrap(NSApp.windows.filter(\.isVisible).compactMap(\.contentView)
                .flatMap(textFields).first { $0.isEditable && $0.placeholderString == "Minutes" })
        }
        func key(_ text: String, code: UInt16 = 0) throws {
            let window = try XCTUnwrap(keyboardWindow)
            window.sendEvent(try XCTUnwrap(NSEvent.keyEvent(with: .keyDown, location: .zero,
                modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime,
                windowNumber: window.windowNumber, context: nil, characters: text,
                charactersIgnoringModifiers: text, isARepeat: false, keyCode: code)))
        }
        func type(_ text: String, into field: NSTextField) throws {
            let editor = try XCTUnwrap(field.currentEditor() as? NSTextView)
            editor.selectAll(nil)
            for character in text { try key(String(character)) }
        }

        for scheme in [ColorScheme.dark, .light] {
            for entry in ["issues", "today"] {
                fixture.focus.plannedMinutes = 50
                navigations = 0
                let content: AnyView
                if entry == "issues" {
                    content = AnyView(LinearFocusButton(issue: issue, openDeskOnPin: false,
                        onPinned: { navigations += 1 }))
                } else {
                    content = AnyView(TodayDeskPinRow(issue: issue, pinned: false) { minutes in
                        fixture.focus.pin(issue, openDesk: false, minutes: minutes)
                        navigations += 1
                    })
                }
                let root = content.frame(maxWidth: .infinity, maxHeight: .infinity)
                    .environment(fixture.usage).environment(fixture.companion)
                    .environment(fixture.focus).environment(\.colorScheme, scheme)
                let host = NSHostingView(rootView: root)
                let window = NSWindow(contentRect: NSRect(x: 200, y: 300, width: 360, height: 80),
                    styleMask: [.titled, .closable], backing: .buffered, defer: false)
                window.isReleasedWhenClosed = false
                window.appearance = NSAppearance(named: scheme == .dark ? .darkAqua : .aqua)
                window.contentView = host
                keyboardWindow = window
                host.frame = NSRect(x: 0, y: 0, width: 360, height: 80)
                NSApp.activate(ignoringOtherApps: true)
                window.makeKeyAndOrderFront(nil)
                defer { window.close() }
                try await settle()
                let buttonX: CGFloat = entry == "issues" ? 180 : 100
                try await click(window, x: buttonX, fromTop: 40)
                var field = try minutesField()
                var picker = try XCTUnwrap(field.window)
                XCTAssertNotNil(field.currentEditor(), "Custom minutes must accept typing immediately")
                XCTAssertTrue(window.firstResponder === field.currentEditor(),
                    "An attached popover routes keyboard input through its parent window")
                XCTAssertEqual(field.stringValue, "50")
                XCTAssertNil(fixture.focus.session)
                XCTAssertEqual(navigations, 0, "Opening the picker must not navigate or start")
                // Presets are drafts; the explicit Start focus action commits the choice.
                try await click(picker, x: 58, fromTop: 95)
                XCTAssertEqual(field.stringValue, "25")
                XCTAssertNil(fixture.focus.session)
                XCTAssertEqual(fixture.focus.plannedMinutes, 50)
                // Re-focus after clicking a preset, then verify invalid and cancelled drafts.
                picker.makeFirstResponder(field)
                try type("181", into: field)
                try key("\r", code: 36)
                try await settle()
                XCTAssertNil(fixture.focus.session)
                XCTAssertTrue(picker.isVisible)
                try type("17", into: field)
                if scheme == .dark { try key("\u{1b}", code: 53) }
                else { try await click(picker, x: 58, fromTop: 191) }
                try await settle()
                XCTAssertFalse(picker.isVisible)
                XCTAssertNil(fixture.focus.session)
                XCTAssertEqual(fixture.focus.plannedMinutes, 50)
                try await click(window, x: buttonX, fromTop: 40)
                field = try minutesField()
                picker = try XCTUnwrap(field.window)
                XCTAssertEqual(field.stringValue, "50", "Cancelled drafts must not replace the default")
                try type("17", into: field)
                if let path = ProcessInfo.processInfo.environment["PTB_FLOATING_PREVIEW_DIR"],
                   let view = picker.contentView {
                    let output = URL(fileURLWithPath: path)
                    try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
                    let bitmap = try XCTUnwrap(view.bitmapImageRepForCachingDisplay(in: view.bounds))
                    view.cacheDisplay(in: view.bounds, to: bitmap)
                    try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
                        .write(to: output.appendingPathComponent("focus-duration-\(entry)-\(scheme).png"))
                }
                if scheme == .dark { try key("\r", code: 36) }
                else { try await click(picker, x: 234, fromTop: 191) }
                try await settle()
                XCTAssertEqual(fixture.focus.session?.plannedSeconds, 17 * 60)
                XCTAssertEqual(navigations, 1)
                XCTAssertFalse(picker.isVisible)
                fixture.focus.finishLeavingInProgress()
                window.close()
            }
        }
    }

    func testComposerChoosesDurationBeforeCreatingAnIssue() async throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        fixture.companion.setLanguage(.en)
        let keyStore = LinearAPIKeyStore(fileURL: fixture.directory.appendingPathComponent("key.json"))
        try keyStore.save(.init(key: "isolated-test-key"))
        let usage = UsageStore(providers: [], autoRefresh: false, defaults: fixture.defaults,
            linearClient: LinearClient(http: DurationCatalogHTTP()), linearAPIKeys: keyStore)
        usage.linearIntegrationEnabled = true
        var creations = 0
        var closes = 0
        var issue = FocusPinnedIssue.pomodoro(title: "New task").summary
        issue.id = "new-duration-issue"
        let focus = FocusSessionStore(usage: usage, companion: fixture.companion,
            fileURL: fixture.directory.appendingPathComponent("composer-focus.json"), ticksOnTimer: false,
            createIssue: { _ in creations += 1; return issue })
        let host = NSHostingView(rootView: LinearIssueComposerView(onClose: { closes += 1 })
            .environment(usage).environment(fixture.companion).environment(focus))
        let window = NSWindow(contentRect: NSRect(x: 200, y: 200, width: 480, height: 620),
            styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = host
        window.makeKeyAndOrderFront(nil)
        defer { window.close() }
        try await Task.sleep(for: .milliseconds(250))

        func fields(_ view: NSView) -> [NSTextField] {
            (view as? NSTextField).map { [$0] } ?? view.subviews.flatMap(fields)
        }
        func key(_ text: String, code: UInt16 = 0) throws {
            window.sendEvent(try XCTUnwrap(NSEvent.keyEvent(with: .keyDown, location: .zero,
                modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime,
                windowNumber: window.windowNumber, context: nil, characters: text,
                charactersIgnoringModifiers: text, isARepeat: false, keyCode: code)))
        }
        let title = try XCTUnwrap(fields(host).first { $0.placeholderString == fixture.companion.l.linearIssueTitle })
        window.makeFirstResponder(title)
        for character in "New task" { try key(String(character)) }
        try await Task.sleep(for: .milliseconds(100))
        XCTAssertNotNil(usage.linearCreateCatalog)
        func clickCreateAndFocus() throws {
            let point = host.convert(NSPoint(x: 400, y: host.bounds.height - 31), to: nil)
            for type in [NSEvent.EventType.leftMouseDown, .leftMouseUp] {
                window.sendEvent(try XCTUnwrap(NSEvent.mouseEvent(with: type, location: point,
                    modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime,
                    windowNumber: window.windowNumber, context: nil, eventNumber: 1, clickCount: 1, pressure: 1)))
            }
        }
        for cancelled in [true, false] {
            try clickCreateAndFocus()
            try await Task.sleep(for: .milliseconds(200))
            let field = try XCTUnwrap(NSApp.windows.filter(\.isVisible).compactMap(\.contentView)
                .flatMap(fields).first { $0.placeholderString == "Minutes" })
            let editor = try XCTUnwrap(field.currentEditor() as? NSTextView)
            editor.selectAll(nil)
            try key("3")
            try key("7")
            XCTAssertEqual(creations, 0, "Choosing time must not create an issue")
            XCTAssertNil(focus.session)
            XCTAssertEqual(closes, 0)
            try key(cancelled ? "\u{1b}" : "\r", code: cancelled ? 53 : 36)
            try await Task.sleep(for: .milliseconds(200))
            if cancelled {
                XCTAssertEqual(creations, 0)
                XCTAssertNil(focus.session)
                XCTAssertEqual(closes, 0)
            }
        }
        XCTAssertEqual(creations, 1)
        XCTAssertEqual(closes, 1)
        XCTAssertEqual(focus.session?.issue.id, issue.id)
        XCTAssertEqual(focus.session?.plannedSeconds, 37 * 60)

        // Creating another task preserves its chosen duration through the existing switch warning.
        issue.id = "new-duration-issue-2"
        try clickCreateAndFocus()
        try await Task.sleep(for: .milliseconds(200))
        let field = try XCTUnwrap(NSApp.windows.filter(\.isVisible).compactMap(\.contentView)
            .flatMap(fields).first { $0.placeholderString == "Minutes" })
        let editor = try XCTUnwrap(field.currentEditor() as? NSTextView)
        editor.selectAll(nil)
        try key("4")
        try key("2")
        try key("\r", code: 36)
        try await Task.sleep(for: .milliseconds(200))
        XCTAssertNotNil(focus.forfeitPrompt)
        XCTAssertEqual(creations, 1)
        XCTAssertEqual(closes, 1)
        XCTAssertEqual(focus.session?.plannedSeconds, 37 * 60)
        await focus.confirmForfeit()
        try await Task.sleep(for: .milliseconds(200))
        XCTAssertEqual(creations, 2)
        XCTAssertEqual(closes, 2)
        XCTAssertEqual(focus.session?.issue.id, issue.id)
        XCTAssertEqual(focus.session?.plannedSeconds, 42 * 60)
    }

    private struct DurationCatalogHTTP: LinearHTTPClient {
        func postGraphQL(apiKey: String, body: Data) async throws -> (status: Int, data: Data) {
            let response = """
            {"data":{"viewer":{"id":"me","name":"Test"},
              "teams":{"nodes":[{"id":"team-1","name":"Test","key":"TEST",
                "states":{"nodes":[]}}]},
              "users":{"nodes":[]},"issueLabels":{"nodes":[]},"projects":{"nodes":[]}}}
            """
            return (200, Data(response.utf8))
        }
    }

    @MainActor private final class Fixture {
        let activationPolicy: NSApplication.ActivationPolicy
        let directory: URL
        let suite = "FloatingTimerOverlayTests-\(UUID().uuidString)"
        let defaults: UserDefaults
        let companion: CompanionStore
        lazy var usage = makeUsage()
        lazy var focus = FocusSessionStore(usage: usage, companion: companion,
            clock: { Date(timeIntervalSince1970: 1_700_000_000) },
            fileURL: directory.appendingPathComponent("focus.json"), ticksOnTimer: false)

        init() throws {
            let app = NSApplication.shared
            activationPolicy = app.activationPolicy()
            app.setActivationPolicy(.accessory)
            directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
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
            NSApp.setActivationPolicy(activationPolicy)
            defaults.removePersistentDomain(forName: suite)
            try? FileManager.default.removeItem(at: directory)
        }
    }
}
