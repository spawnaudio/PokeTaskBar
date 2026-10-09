import AppKit
import XCTest
@testable import PokeTaskBar

@MainActor
final class FloatingDisplayMenuTests: XCTestCase {
    private var trackedMenu: NSMenu?

    @objc private func menuBeganTracking(_ notification: Notification) {
        trackedMenu = notification.object as? NSMenu
        NSApp.postEvent(NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [],
            timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: NSApp.keyWindow?.windowNumber ?? 0,
            context: nil, characters: "\u{1b}", charactersIgnoringModifiers: "\u{1b}",
            isARepeat: false, keyCode: 53)!, atStart: true)
    }

    private func fixture() throws -> (UsageStore, CompanionStore, FocusSessionStore, UserDefaults) {
        let app = NSApplication.shared
        let policy = app.activationPolicy()
        app.setActivationPolicy(.accessory)
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let suite = "FloatingDisplayMenuTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        let usage = UsageStore(providers: [], autoRefresh: false, defaults: defaults,
            linearAPIKeys: LinearAPIKeyStore(fileURL: directory.appendingPathComponent("key.json")))
        let companion = CompanionStore(provider: StubProvider(value: EvoLine(baseID: 131,
            tree: EvoNode(speciesID: 131, children: []), rarity: .rare, names: [:])),
            fileURL: directory.appendingPathComponent("companion.json"), defaults: defaults)
        companion.setLanguage(.en)
        let focus = FocusSessionStore(usage: usage, companion: companion,
            clock: { Date(timeIntervalSince1970: 1_700_000_000) },
            fileURL: directory.appendingPathComponent("focus.json"), ticksOnTimer: false)
        addTeardownBlock {
            MainActor.assumeIsolated {
                app.setActivationPolicy(policy)
                defaults.removePersistentDomain(forName: suite)
                try? FileManager.default.removeItem(at: directory)
            }
        }
        return (usage, companion, focus, defaults)
    }

    private func settle(_ condition: () -> Bool) async throws {
        for _ in 0..<80 {
            if condition() { return }
            try await Task.sleep(for: .milliseconds(25))
        }
        XCTAssertTrue(condition())
    }

    private func select(_ title: String, in panel: FloatingPetPanel) throws {
        let menu = try XCTUnwrap(panel.contextMenuProvider?())
        let item = try XCTUnwrap(menu.item(withTitle: title))
        XCTAssertTrue(NSApp.sendAction(try XCTUnwrap(item.action), to: item.target, from: item))
    }

    private func resize(_ title: String, to value: Double, in panel: FloatingPetPanel) throws {
        let menu = try XCTUnwrap(panel.contextMenuProvider?())
        let view = try XCTUnwrap(menu.item(withTitle: title)?.view as? FloatingSizeMenuView)
        view.slider.doubleValue = value
        XCTAssertTrue(view.slider.sendAction(try XCTUnwrap(view.slider.action), to: view.slider.target))
    }

    func testNativeMenuSwitchesEverySurfaceWithoutChangingTheSession() async throws {
        let (usage, companion, focus, defaults) = try fixture()
        usage.floatingDisplayMode = .classic
        focus.startLocalTask(title: "Keep working", description: "", minutes: 25)
        focus.togglePause()
        let original = focus.session
        let coins = companion.availableCoins
        let controller = FloatingPetController(store: usage, companion: companion, session: focus, defaults: defaults)
        defer { controller.setDisplayAwake(false) }
        let pet = try XCTUnwrap(NSApp.windows.compactMap { $0 as? FloatingPetPanel }.first { $0.isVisible })
        for (title, mode) in [("Battle Window Mode", UsageStore.FloatingDisplayMode.battle),
                              ("Classic Floating Pet Mode", .classic),
                              ("Floating Timer Only Mode", .timerOnly)] {
            try select(title, in: pet)
            try await settle { mode == .timerOnly ? !pet.isVisible : pet.isVisible &&
                (mode == .battle ? pet.contentView is BattlePanelContent : pet.contentView is PetHostingView) }
            let surface = mode == .timerOnly ? try XCTUnwrap(NSApp.windows.compactMap { $0 as? FloatingPetPanel }
                .first { $0.isVisible && $0.identifier?.rawValue == FloatingPetController.timerPanelIdentifier }) : pet
            let menu = try XCTUnwrap(surface.contextMenuProvider?())
            XCTAssertEqual(menu.item(withTitle: title)?.state, .on)
            XCTAssertEqual(menu.items.filter { $0.action == NSSelectorFromString("selectMode:") && $0.state == .on }.count, 1)
            XCTAssertEqual(usage.floatingDisplayMode, mode)
            XCTAssertEqual(UsageStore(providers: [], autoRefresh: false, defaults: defaults).floatingDisplayMode, mode)
            XCTAssertEqual(focus.session, original)
            XCTAssertEqual(companion.availableCoins, coins)
        }
        let timer = try XCTUnwrap(NSApp.windows.compactMap { $0 as? FloatingPetPanel }
            .first { $0.isVisible && $0.identifier?.rawValue == FloatingPetController.timerPanelIdentifier })
        try select("Battle Window Mode", in: timer)
        try await settle { pet.isVisible && !timer.isVisible }
        usage.battleWindowFolded = true
        try await settle { pet.contentView is PetHostingView }
        let gameBoy = try XCTUnwrap(pet.contentView as? PetHostingView)
        XCTAssertEqual(gameBoy.makeContextMenu().item(withTitle: "Battle Window Mode")?.state, .on)
        try select("Classic Floating Pet Mode", in: pet)
        try await settle { pet.title == "PokeTasks · Floating companion" }
        XCTAssertEqual(focus.session, original)
    }

    func testFloatOnTopUpdatesEverySurfaceAndPersists() async throws {
        let (usage, companion, focus, defaults) = try fixture()
        XCTAssertTrue(usage.floatingDisplaysFloatOnTop)
        XCTAssertTrue(usage.menuBarPanelFloatsOnTop)
        usage.menuBarPanelFloatsOnTop = false
        usage.floatingDisplayMode = .classic
        focus.startPomodoro()
        let original = focus.session
        let controller = FloatingPetController(store: usage, companion: companion, session: focus, defaults: defaults)
        defer { controller.setDisplayAwake(false) }
        let pet = try XCTUnwrap(NSApp.windows.compactMap { $0 as? FloatingPetPanel }.first { $0.isVisible })
        let cover = NSWindow(contentRect: .zero, styleMask: .borderless, backing: .buffered, defer: false)
        cover.isReleasedWhenClosed = false
        cover.backgroundColor = .white
        cover.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        defer { cover.close() }
        NSApp.activate(ignoringOtherApps: true)
        func isAbove(_ front: NSWindow, _ back: NSWindow) throws -> Bool {
            let windows = try XCTUnwrap(CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements],
                kCGNullWindowID) as? [[String: Any]])
            let numbers = windows.compactMap { $0[kCGWindowNumber as String] as? Int }
            return try XCTUnwrap(numbers.firstIndex(of: front.windowNumber)) <
                XCTUnwrap(numbers.firstIndex(of: back.windowNumber))
        }
        for mode in [UsageStore.FloatingDisplayMode.classic, .battle, .timerOnly] {
            usage.floatingDisplayMode = mode
            try await settle { mode == .timerOnly ? !pet.isVisible : pet.isVisible &&
                (mode == .battle ? pet.contentView is BattlePanelContent : pet.contentView is PetHostingView) }
            let surface = mode == .timerOnly ? try XCTUnwrap(NSApp.windows.compactMap { $0 as? FloatingPetPanel }
                .first { $0.isVisible && $0.identifier?.rawValue == FloatingPetController.timerPanelIdentifier }) : pet
            for enabled in [false, true] {
                try select("Float on Top", in: surface)
                try await settle { surface.level == (enabled ? .floating : .normal) }
                XCTAssertEqual(surface.contextMenuProvider?().item(withTitle: "Float on Top")?.state, enabled ? .on : .off)
                cover.setFrame(surface.frame, display: true)
                cover.orderFrontRegardless()
                try await Task.sleep(for: .milliseconds(100))
                XCTAssertEqual(try isAbove(surface, cover), enabled,
                    "The native window stack must follow Float on Top: \(mode), enabled=\(enabled)")
                if !enabled, mode == .classic {
                    usage.floatingPetSize = 128
                    try await settle { (surface.contentView as? PetHostingView)?.petSize == 128 }
                    XCTAssertTrue(try isAbove(cover, surface),
                        "A layout refresh must not bring a normal-level pet above another app window")
                }
                let restored = UsageStore(providers: [], autoRefresh: false, defaults: defaults)
                XCTAssertEqual(restored.floatingDisplaysFloatOnTop, enabled)
                XCTAssertFalse(restored.menuBarPanelFloatsOnTop, "The menu-bar preference is independent")
                XCTAssertEqual(focus.session, original)
            }
            cover.orderOut(nil)
            if mode == .battle {
                usage.battleWindowFolded = true
                try await settle { pet.contentView is PetHostingView }
                try select("Float on Top", in: pet)
                try await settle { pet.level == .normal }
                XCTAssertEqual((pet.contentView as? PetHostingView)?.makeContextMenu().item(withTitle: "Float on Top")?.state, .off)
                try select("Float on Top", in: pet)
                try await settle { pet.level == .floating }
            }
        }
        usage.floatingDisplayMode = .classic
        usage.floatingTimerDetached = true
        try await settle { pet.isVisible }
        let timer = try XCTUnwrap(NSApp.windows.first {
            $0.isVisible && $0.identifier?.rawValue == FloatingPetController.timerPanelIdentifier
        })
        try select("Float on Top", in: pet)
        try await settle { pet.level == .normal && timer.level == .normal }
        try select("Float on Top", in: try XCTUnwrap(timer as? FloatingPetPanel))
        try await settle { pet.level == .floating && timer.level == .floating }
    }

    func testMenuBarClickAwayDetachedFloatAndNativeContextMenu() async throws {
        let (usage, companion, focus, defaults) = try fixture()
        let navigation = PopoverNavigation()
        navigation.tab = .linear
        let controller = MenuBarPanelController(usage: usage, companion: companion, session: focus,
            updater: UpdateChecker(), navigation: navigation)
        defer { controller.close() }
        controller.present(from: nil, resetNavigation: false)
        let window = try XCTUnwrap(NSApp.windows.compactMap { $0 as? MenuBarPanelWindow }.first { $0.isVisible })
        XCTAssertEqual(window.title, "PokeTasks")
        let outside = NSWindow(contentRect: NSRect(x: 30, y: 30, width: 100, height: 100),
            styleMask: .borderless, backing: .buffered, defer: false)
        outside.isReleasedWhenClosed = false
        outside.orderFrontRegardless()
        defer { outside.close() }
        func click(_ target: NSWindow) throws -> NSEvent {
            try XCTUnwrap(NSEvent.mouseEvent(with: .rightMouseDown, location: NSPoint(x: 20, y: 20),
                modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime,
                windowNumber: target.windowNumber, context: nil, eventNumber: 1, clickCount: 1, pressure: 1))
        }
        XCTAssertEqual(window.level, .floating)
        func headerMenu() async throws -> NSMenu {
            window.contentView?.layoutSubtreeIfNeeded()
            try await Task.sleep(for: .milliseconds(100))
            trackedMenu = nil
            NotificationCenter.default.addObserver(self, selector: #selector(menuBeganTracking),
                name: NSMenu.didBeginTrackingNotification, object: nil)
            defer {
                NotificationCenter.default.removeObserver(self, name: NSMenu.didBeginTrackingNotification, object: nil)
            }
            let point = NSPoint(x: window.frame.width / 2, y: window.contentView!.bounds.height - 20)
            window.sendEvent(try XCTUnwrap(NSEvent.mouseEvent(with: .rightMouseDown, location: point,
                modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime,
                windowNumber: window.windowNumber, context: nil, eventNumber: 1, clickCount: 1, pressure: 1)))
            try await settle { self.trackedMenu != nil }
            return try XCTUnwrap(trackedMenu, "Native header right-click must open the context menu")
        }
        let attachedMenu = try await headerMenu()
        XCTAssertEqual(attachedMenu.item(withTitle: "Float on Top")?.state, .on)
        XCTAssertTrue(controller.isShown, "The menu's own context menu must not dismiss it")
        NSApp.sendEvent(try click(outside))
        XCTAssertFalse(controller.isShown, "A click in another window must close the attached menu")
        XCTAssertNil(window.contentView, "Dismissal must release the hidden hosting tree")
        controller.present(from: nil, resetNavigation: false)
        NotificationCenter.default.post(name: NSApplication.didResignActiveNotification, object: NSApp)
        XCTAssertFalse(controller.isShown, "Switching to another app must also dismiss the attached menu")
        usage.menuBarPanelDetached = true
        controller.present(from: nil, resetNavigation: false)
        try await settle { window.styleMask.contains(.titled) }
        XCTAssertEqual(window.title, "PokeTasks", "Detaching keeps the same product title")
        NSApp.sendEvent(try click(outside))
        NotificationCenter.default.post(name: NSApplication.didResignActiveNotification, object: NSApp)
        XCTAssertTrue(controller.isShown, "A detached window must stay open")
        for enabled in [false, true] {
            let menu = try await headerMenu()
            let item = try XCTUnwrap(menu.item(withTitle: "Float on Top"))
            XCTAssertTrue(NSApp.sendAction(try XCTUnwrap(item.action), to: item.target, from: item))
            try await settle { window.level == (enabled ? .floating : .normal) }
            let updatedMenu = try await headerMenu()
            XCTAssertEqual(updatedMenu.item(withTitle: "Float on Top")?.state, enabled ? .on : .off)
            XCTAssertEqual(UsageStore(providers: [], autoRefresh: false, defaults: defaults).menuBarPanelFloatsOnTop, enabled)
            XCTAssertTrue(usage.floatingDisplaysFloatOnTop)
        }
        usage.menuBarPanelDetached = false
        try await settle { !window.styleMask.contains(.titled) }
        NSApp.sendEvent(try click(outside))
        XCTAssertFalse(controller.isShown, "Reattaching restores click-away dismissal")
    }

    func testSizeSlidersResizeBattleGameBoyPetAndTimerAndPersistSeparately() async throws {
        let (usage, companion, focus, defaults) = try fixture()
        usage.floatingDisplayMode = .battle
        focus.startPomodoro()
        let original = focus.session
        let controller = FloatingPetController(store: usage, companion: companion, session: focus, defaults: defaults)
        defer { controller.setDisplayAwake(false) }
        let pet = try XCTUnwrap(NSApp.windows.compactMap { $0 as? FloatingPetPanel }.first { $0.isVisible })
        for value in [0.5, 1.25, 2] {
            try resize("Battle Window / Game Boy Size", to: value, in: pet)
            try await settle { abs(pet.frame.width - 360 * value) < 0.1 }
            XCTAssertEqual(usage.battleWindowScale, value)
        }
        usage.battleWindowFolded = true
        try await settle { pet.contentView is PetHostingView }
        try resize("Battle Window / Game Boy Size", to: 1.5, in: pet)
        try await settle { abs(pet.frame.width - 120) < 0.1 }
        XCTAssertEqual(pet.frame.height, 144, accuracy: 0.1)
        try select("Classic Floating Pet Mode", in: pet)
        try await settle { pet.title == "PokeTasks · Floating companion" }
        try resize("Pet Size", to: 128, in: pet)
        try await settle { (pet.contentView as? PetHostingView)?.petSize == 128 }
        try select("Floating Timer Only Mode", in: pet)
        try await settle { !pet.isVisible }
        let timer = try XCTUnwrap(NSApp.windows.compactMap { $0 as? FloatingPetPanel }
            .first { $0.isVisible && $0.identifier?.rawValue == FloatingPetController.timerPanelIdentifier })
        try resize("Floating Timer Size", to: 0.75, in: timer)
        try await settle { abs(timer.frame.width - usage.floatingTimerWidth * 0.75) < 0.1 }
        let restored = UsageStore(providers: [], autoRefresh: false, defaults: defaults)
        XCTAssertEqual(restored.battleWindowScale, 1.5)
        XCTAssertEqual(restored.floatingPetSize, 128)
        XCTAssertEqual(restored.floatingTimerScale, 0.75)
        XCTAssertEqual(focus.session, original)
    }

    func testTimerOnlyRestoresAnIdleStartSurfaceAndCanSwitchBackOrHide() async throws {
        let (usage, companion, focus, defaults) = try fixture()
        usage.floatingDisplayMode = .timerOnly
        XCTAssertFalse(focus.pomodoroSetupOpen)
        let restored = UsageStore(providers: [], autoRefresh: false, defaults: defaults)
        let controller = FloatingPetController(store: restored, companion: companion, session: focus, defaults: defaults)
        defer { controller.setDisplayAwake(false) }
        let timer = try XCTUnwrap(NSApp.windows.compactMap { $0 as? FloatingPetPanel }
            .first { $0.isVisible && $0.identifier?.rawValue == FloatingPetController.timerPanelIdentifier })
        XCTAssertEqual(timer.frame.height, FloatingTimerMetrics.height, accuracy: 0.1)
        let menu = try XCTUnwrap(timer.contextMenuProvider?())
        XCTAssertEqual(menu.item(withTitle: "Floating Timer Only Mode")?.state, .on)
        try select("Classic Floating Pet Mode", in: timer)
        try await settle { !timer.isVisible }
        let pet = try XCTUnwrap(NSApp.windows.compactMap { $0 as? FloatingPetPanel }
            .first { $0.isVisible && $0.contentView is PetHostingView })
        try select("Floating Timer Only Mode", in: pet)
        try await settle { timer.isVisible }
        try select("Turn off floating timer", in: timer)
        try await settle { !timer.isVisible }
        XCTAssertFalse(restored.floatingTimerDetached)
        XCTAssertFalse(restored.floatingPetEnabled)
        XCTAssertNil(focus.session)
    }

    func testRightClickAndControlClickOpenTheSharedMenuOnEverySurface() async throws {
        let (usage, companion, focus, defaults) = try fixture()
        usage.floatingDisplayMode = .battle
        let controller = FloatingPetController(store: usage, companion: companion, session: focus, defaults: defaults)
        defer { controller.setDisplayAwake(false) }
        let pet = try XCTUnwrap(NSApp.windows.compactMap { $0 as? FloatingPetPanel }.first { $0.isVisible })
        for surface in ["Battle", "Game Boy", "Pet", "Timer"] {
            switch surface {
            case "Game Boy": usage.battleWindowFolded = true
            case "Pet": usage.floatingDisplayMode = .classic
            case "Timer": usage.floatingDisplayMode = .timerOnly
            default: break
            }
            try await settle {
                switch surface {
                case "Game Boy": return pet.contentView is PetHostingView
                case "Pet": return pet.title == "PokeTasks · Floating companion"
                case "Timer": return !pet.isVisible
                default: return pet.contentView is BattlePanelContent
                }
            }
            let panel = surface == "Timer" ? try XCTUnwrap(NSApp.windows.compactMap { $0 as? FloatingPetPanel }
                .first { $0.isVisible && $0.identifier?.rawValue == FloatingPetController.timerPanelIdentifier }) : pet
            let tracking = panel.onMenuTrackingChange
            var opened = 0
            panel.onMenuTrackingChange = { active in
                tracking?(active)
                guard active else { return }
                opened += 1
                NSApp.postEvent(NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [],
                    timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: panel.windowNumber,
                    context: nil, characters: "\u{1b}", charactersIgnoringModifiers: "\u{1b}",
                    isARepeat: false, keyCode: 53)!, atStart: true)
            }
            for (type, modifiers) in [(NSEvent.EventType.rightMouseDown, NSEvent.ModifierFlags()),
                                       (.leftMouseDown, .control)] {
                let event = try XCTUnwrap(NSEvent.mouseEvent(with: type,
                    location: NSPoint(x: panel.frame.width / 2, y: panel.frame.height / 2),
                    modifierFlags: modifiers, timestamp: ProcessInfo.processInfo.systemUptime,
                    windowNumber: panel.windowNumber, context: nil, eventNumber: 1, clickCount: 1, pressure: 1))
                panel.sendEvent(event)
            }
            panel.onMenuTrackingChange = tracking
            XCTAssertEqual(opened, 2, surface)
            let menu = try XCTUnwrap(panel.contextMenuProvider?())
            XCTAssertNotNil(menu.item(withTitle: "Battle Window Mode"))
            XCTAssertNotNil(menu.item(withTitle: "Classic Floating Pet Mode"))
            XCTAssertNotNil(menu.item(withTitle: "Floating Timer Only Mode"))
            XCTAssertTrue(menu.items.contains { $0.view is FloatingSizeMenuView })
            XCTAssertNil(focus.session)
        }
    }
}
