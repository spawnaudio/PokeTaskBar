import WebKit
import XCTest
@testable import PokeTaskBar

@MainActor
final class BattleWindowTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    private func stores() throws -> (UsageStore, CompanionStore, FocusSessionStore, URL) {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("battle-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: dir) }
        let defaults = UserDefaults(suiteName: "battle-\(UUID().uuidString)")!
        let usage = UsageStore(providers: [], autoRefresh: false, defaults: defaults)
        let companion = CompanionStore(provider: StubProvider(value: EvoLine(baseID: 1,
            tree: EvoNode(speciesID: 1, children: []), rarity: .common, names: [:])),
            clock: { self.now }, fileURL: dir.appendingPathComponent("companion.json"), defaults: defaults)
        companion.creditEarnedXP(100_000_000, fromTokens: false)
        let focus = FocusSessionStore(usage: usage, companion: companion, clock: { self.now },
            fileURL: dir.appendingPathComponent("focus.json"), ticksOnTimer: false)
        return (usage, companion, focus, dir)
    }

    func testDefaultStyleAndNativeInputValidation() throws {
        let (usage, _, _, _) = try stores()
        XCTAssertEqual(usage.floatingPetStyle, .classic)
        for value: Any in [true, 0, -1, 1.5, 181, Double.infinity, "5"] {
            XCTAssertNil(BattleWindow.wholeMinutes(value))
        }
        XCTAssertEqual(BattleWindow.wholeMinutes(5), 5)
        XCTAssertEqual(BattleWindow.wholeMinutes(180), 180)
        XCTAssertNotEqual(SpriteStore.cacheKey(speciesID: 131, animated: false, shiny: true),
                          SpriteStore.cacheKey(speciesID: 131, animated: false, shiny: true, back: true))
        XCTAssertTrue(SpriteStore.spriteURL(speciesID: 201, animated: false, shiny: true,
            unownForm: .b, back: true).absoluteString.hasSuffix("back/shiny/201-b.png"))
    }

    func testBattleScalePersistsIndependentlyOfClassicSettings() throws {
        let suite = "battle-scale-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(1.25, forKey: FloatingTimerMetrics.scaleKey)
        let usage = UsageStore(providers: [], autoRefresh: false, defaults: defaults)
        XCTAssertFalse(usage.battleWindowFolded)
        usage.floatingPetIslandFolded = true
        XCTAssertFalse(usage.battleWindowFolded, "Classic folding must not fold the Battle window")
        usage.battleWindowFolded = true
        XCTAssertEqual(usage.battleWindowScale, 1.25, "Keep the existing Battle size on upgrade")
        usage.floatingTimerScale = 0.5
        XCTAssertEqual(UsageStore(providers: [], autoRefresh: false, defaults: defaults).battleWindowScale, 1.25)
        usage.battleWindowScale = 1.75
        usage.floatingTimerScale = 0.5
        usage.floatingPetSize = 384
        let restored = UsageStore(providers: [], autoRefresh: false, defaults: defaults)
        XCTAssertEqual(restored.battleWindowScale, 1.75)
        XCTAssertTrue(restored.battleWindowFolded)
        XCTAssertEqual(restored.floatingTimerScale, 0.5)
        for (value, expected) in [(-1.0, 0.5), (10.0, 2.0), (.nan, 1.0), (.infinity, 1.0)] {
            usage.battleWindowScale = value
            XCTAssertEqual(usage.battleWindowScale, expected)
            defaults.set(value, forKey: "battleWindowScale")
            XCTAssertEqual(UsageStore(providers: [], autoRefresh: false, defaults: defaults).battleWindowScale, expected)
        }
    }

    func testPotionPreservesPauseRejectsPartialBoostAndRevivesZero() throws {
        let started = FocusSession.start(issue: .localTask(title: "Work", description: ""), plannedMinutes: 25,
            checkInMinutes: 30, now: now)
        let paused = FocusTick.pause(started, now: now.addingTimeInterval(60))
        let extended = try XCTUnwrap(FocusPotion.extending(paused, minutes: 5, now: now.addingTimeInterval(120)))
        XCTAssertTrue(extended.userPaused)
        XCTAssertEqual(extended.clockDisplay(at: now.addingTimeInterval(600)).text, "29:00")
        XCTAssertNil(FocusPotion.extending(started, minutes: 156, now: now))
        XCTAssertNil(FocusPotion.extending(started, minutes: 0, now: now))
        let zero = FocusTick.apply(started, now: now.addingTimeInterval(1500)).session
        let revived = try XCTUnwrap(FocusPotion.extending(zero, minutes: 15, now: now.addingTimeInterval(1800)))
        XCTAssertEqual(revived.phase, .running)
        XCTAssertEqual(revived.clockDisplay(at: now.addingTimeInterval(1800)).text, "15:00")
    }

    func testOwnedPotionIsConsumedOnceAndTimerSurvivesReload() throws {
        let (usage, companion, focus, dir) = try stores()
        XCTAssertTrue(companion.buy(.potion, count: 2))
        focus.startPomodoro()
        focus.togglePause()
        XCTAssertNil(focus.usePotion(.potion, customMinutes: nil))
        XCTAssertEqual(companion.itemCount(.potion), 1)
        XCTAssertEqual(focus.session?.plannedSeconds, 55 * 60)
        XCTAssertTrue(focus.session?.userPaused == true)
        XCTAssertFalse(FileManager.default.fileExists(atPath: dir.appendingPathComponent("focus-potion-pending.json").path))
        let restored = FocusSessionStore(usage: usage, companion: companion, clock: { self.now },
            fileURL: dir.appendingPathComponent("focus.json"), ticksOnTimer: false)
        XCTAssertEqual(restored.session?.plannedSeconds, 55 * 60)
        XCTAssertEqual(companion.itemCount(.potion), 1)
        XCTAssertNotNil(restored.usePotion(.fullRestore, customMinutes: 7))
        XCTAssertEqual(restored.session?.plannedSeconds, 55 * 60)
    }

    func testCrashJournalReplaysWithoutConsumingTwice() throws {
        let (usage, companion, focus, dir) = try stores()
        XCTAssertTrue(companion.buy(.hyperPotion, count: 2))
        focus.startPomodoro()
        let next = try XCTUnwrap(FocusPotion.extending(try XCTUnwrap(focus.session), minutes: 30, now: now))
        let journal = FocusPotionJournal(id: "crash-after-inventory-save", kind: .hyperPotion, session: next)
        let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601
        let journalURL = dir.appendingPathComponent("focus-potion-pending.json")
        let data = try encoder.encode(journal)
        try data.write(to: journalURL)
        try companion.consumeFocusPotion(.hyperPotion, transactionID: journal.id)
        let restored = FocusSessionStore(usage: usage, companion: companion, clock: { self.now },
            fileURL: dir.appendingPathComponent("focus.json"), ticksOnTimer: false)
        XCTAssertEqual(companion.itemCount(.hyperPotion), 1)
        XCTAssertEqual(restored.session?.plannedSeconds, 80 * 60)
        XCTAssertTrue(restored.session?.userPaused == true)
        // Replay a journal whose timer write succeeded: no resurrection after task completion.
        restored.finishLeavingInProgress()
        try data.write(to: journalURL)
        let again = FocusSessionStore(usage: usage, companion: companion, clock: { self.now },
            fileURL: dir.appendingPathComponent("focus.json"), ticksOnTimer: false)
        XCTAssertNil(again.session)
        XCTAssertEqual(companion.itemCount(.hyperPotion), 1)
    }

    func testFailedInventorySaveKeepsItemAndJournalForRecovery() throws {
        let (usage, companion, focus, dir) = try stores()
        XCTAssertTrue(companion.buy(.potion))
        focus.startPomodoro()
        let companionURL = dir.appendingPathComponent("companion.json")
        try FileManager.default.removeItem(at: companionURL)
        try FileManager.default.createDirectory(at: companionURL, withIntermediateDirectories: false)
        let coins = companion.availableCoins
        XCTAssertFalse(companion.buy(.potion))
        XCTAssertEqual(companion.availableCoins, coins)
        XCTAssertEqual(companion.itemCount(.potion), 1)
        XCTAssertNotNil(focus.usePotion(.potion, customMinutes: nil))
        XCTAssertEqual(companion.itemCount(.potion), 1)
        XCTAssertEqual(focus.session?.plannedSeconds, 50 * 60)
        XCTAssertNotNil(focus.usePotion(.potion, customMinutes: nil))
        try FileManager.default.removeItem(at: companionURL)
        let restored = FocusSessionStore(usage: usage, companion: companion, clock: { self.now },
            fileURL: dir.appendingPathComponent("focus.json"), ticksOnTimer: false)
        XCTAssertEqual(restored.session?.plannedSeconds, 55 * 60)
        XCTAssertEqual(companion.itemCount(.potion), 0)
        XCTAssertNil(restored.storageError)
    }

    func testForfeitPreservesEarnedXPAndRestFinishesLocalTask() async throws {
        let (usage, companion, focus, _) = try stores()
        usage.floatingPetStyle = .battle
        focus.startPomodoro()
        XCTAssertTrue(focus.session?.battleRewardsDeferred == true)
        let earned = companion.lifetimeXP
        focus.tick(now: now.addingTimeInterval(50 * 60))
        focus.continueOvertime()
        XCTAssertEqual(focus.session?.phase, .awaitingChoice)
        XCTAssertEqual(companion.lifetimeXP, earned)
        focus.requestUnfocus()
        await focus.confirmForfeit()
        XCTAssertNil(focus.session)
        XCTAssertEqual(companion.lifetimeXP, earned)
        focus.startPomodoro()
        focus.tick(now: now.addingTimeInterval(50 * 60))
        let finished = await focus.finishBattleTask()
        XCTAssertTrue(finished)
        XCTAssertNil(focus.session)
        XCTAssertEqual(focus.sessionRecords.last?.finish, .doneOnTime)
        XCTAssertGreaterThan(companion.lifetimeXP, earned)
        let repeated = await focus.finishBattleTask()
        XCTAssertFalse(repeated)
    }

    func testFailedTimerSaveRecoversExtensionAndKeepsLocalReceiptOnImport() throws {
        let (usage, companion, focus, dir) = try stores()
        XCTAssertTrue(companion.buy(.potion))
        focus.startPomodoro()
        let file = dir.appendingPathComponent("focus.json")
        let previous = try Data(contentsOf: file)
        try FileManager.default.removeItem(at: file)
        try FileManager.default.createDirectory(at: file, withIntermediateDirectories: false)
        XCTAssertNotNil(focus.usePotion(.potion, customMinutes: nil))
        XCTAssertEqual(companion.itemCount(.potion), 0)
        XCTAssertNotNil(focus.storageError)
        try FileManager.default.removeItem(at: file)
        try previous.write(to: file)
        let restored = FocusSessionStore(usage: usage, companion: companion, clock: { self.now },
            fileURL: file, ticksOnTimer: false)
        XCTAssertEqual(restored.session?.plannedSeconds, 55 * 60)
        XCTAssertEqual(companion.itemCount(.potion), 0)
        let receipt = try XCTUnwrap(companion.state.focusPotionTransactionID)
        var imported = CompanionState(); imported.focusPotionTransactionID = "another-device"
        let rebased = SaveTransfer.rebasedForThisDevice(imported, current: companion.state,
            todayTokensByProvider: [:], todayDate: "", hasUsageData: false)
        XCTAssertEqual(rebased.focusPotionTransactionID, receipt)
    }

    func testNativeBattleScalesEntireWindowWithoutClippingOrClassicSizeMovement() async throws {
        _ = NSApplication.shared
        let (usage, companion, focus, _) = try stores()
        let suite = "battle-layout-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let screen = try XCTUnwrap(NSScreen.main)
        defaults.set(screen.visibleFrame.maxX - 120, forKey: "floatingPetOriginX")
        defaults.set(screen.visibleFrame.minY + 24, forKey: "floatingPetOriginY")
        usage.floatingPetStyle = .battle
        usage.floatingPetEnabled = true
        let controller = FloatingPetController(store: usage, companion: companion, session: focus, defaults: defaults)
        defer { controller.setDisplayAwake(false) }
        let panel = try XCTUnwrap(NSApp.windows.first { $0.isVisible && $0.identifier?.rawValue == "PokeTasks.BattleWindow" })
        let content = try XCTUnwrap(panel.contentView as? BattlePanelContent)
        let web = try XCTUnwrap(content.subviews.compactMap { $0 as? WKWebView }.first)
        let measure = """
        (() => { const g=document.querySelector('.game'), c=document.querySelector('.commands');
        if(!g || getComputedStyle(document.querySelector('main')).visibility !== 'visible') return null;
        const r=g.getBoundingClientRect(), b=c.getBoundingClientRect();
        return {x:r.x,y:r.y,width:r.width,height:r.height,bottom:b.bottom,
        viewportWidth:innerWidth,viewportHeight:innerHeight,clipHeight:document.body.getBoundingClientRect().height,
        hp:document.querySelector('.hp')?.getBoundingClientRect().width ?? 0}; })()
        """
        for scale in [0.5, 1.0, 1.5, 2.0] {
            usage.battleWindowScale = scale
            var result: [String: Double]?
            for _ in 0..<100 {
                try await Task.sleep(for: .milliseconds(30))
                content.layoutSubtreeIfNeeded()
                result = try? await web.evaluateJavaScript(measure) as? [String: Double]
                if abs((result?["width"] ?? 0) - 360 * scale) < 0.1 { break }
            }
            let rect = try XCTUnwrap(result)
            XCTAssertEqual(panel.frame.width, 360 * scale, accuracy: 0.1)
            XCTAssertEqual(panel.frame.height, 180 * scale, accuracy: 0.1)
            XCTAssertEqual(rect["x"]!, 0, accuracy: 0.1)
            XCTAssertEqual(rect["y"]!, 0, accuracy: 0.1)
            XCTAssertEqual(rect["width"]!, 360 * scale, accuracy: 0.1)
            XCTAssertEqual(rect["height"]!, 180 * scale, accuracy: 0.1)
            XCTAssertLessThanOrEqual(rect["bottom"]!, rect["viewportHeight"]!)
            XCTAssertLessThanOrEqual(rect["bottom"]!, rect["clipHeight"]!, "The body must not clip the scaled buttons")
            XCTAssertEqual(rect["hp"]!, 127 * scale, accuracy: 0.1)
        }
        let image = try await web.takeSnapshot(configuration: nil)
        let pixels = try XCTUnwrap(NSBitmapImageRep(data: try XCTUnwrap(image.tiffRepresentation)))
        XCTAssertGreaterThan(try XCTUnwrap(pixels.colorAt(x: pixels.pixelsWide / 2, y: pixels.pixelsHigh - 2)).alphaComponent, 0.9,
                             "The enlarged window's bottom border must actually render")
        for action in ["[...document.querySelectorAll('button')].find(b=>b.textContent==='More').click()",
                       "window.pokeTasksOpenBag()"] {
            _ = try await web.evaluateJavaScript(action)
            var result: [String: Double]?
            for _ in 0..<100 {
                try await Task.sleep(for: .milliseconds(30))
                content.layoutSubtreeIfNeeded()
                result = try? await web.evaluateJavaScript(measure) as? [String: Double]
                if panel.frame.height == 520, result?["viewportHeight"] == 520 { break }
            }
            let rect = try XCTUnwrap(result)
            XCTAssertEqual(rect["height"]!, 520, accuracy: 0.1)
            XCTAssertLessThanOrEqual(rect["bottom"]!, rect["clipHeight"]!)
        }
        panel.setFrameOrigin(NSPoint(x: panel.frame.minX - 40, y: panel.frame.minY + 30))
        let frame = panel.frame
        usage.floatingPetSize = 384
        usage.floatingTimerScale = 0.5
        try await Task.sleep(for: .milliseconds(200))
        XCTAssertEqual(panel.frame, frame, "Classic pet size must not move the Battle window")
        controller.setDisplayAwake(false)
        controller.setDisplayAwake(true)
        XCTAssertEqual(panel.frame.maxX, frame.maxX, accuracy: 0.1)
        XCTAssertEqual(panel.frame.minY, frame.minY, accuracy: 0.1)
        controller.toggleEdgeTucking()
        XCTAssertEqual(panel.frame.width, FloatingPetController.edgePeekWidth)
        controller.toggleEdgeTucking()
        XCTAssertEqual(panel.frame.maxX, frame.maxX, accuracy: 0.1)
        controller.setDisplayAwake(false)
        defaults.removeObject(forKey: "battleWindowAnchorX")
        defaults.removeObject(forKey: "battleWindowAnchorY")
        defaults.set("left", forKey: FloatingPetController.tuckEdgeKey)
        let tucked = FloatingPetController(store: usage, companion: companion, session: focus, defaults: defaults)
        defer { tucked.setDisplayAwake(false) }
        XCTAssertEqual(defaults.double(forKey: "battleWindowAnchorX"), screen.visibleFrame.maxX, accuracy: 0.1,
                       "Migrating while tucked must save the full window's anchor, not the 24pt peek")
        tucked.toggleEdgeTucking()
        let restored = try XCTUnwrap(NSApp.windows.first { $0.isVisible && $0.identifier?.rawValue == "PokeTasks.BattleWindow" })
        XCTAssertEqual(restored.frame.maxX, screen.visibleFrame.maxX, accuracy: 0.1)
    }

    func testGameBoyFoldButtonPreservesTimerAndPeeksFromBothEdges() async throws {
        _ = NSApplication.shared
        let screen = try XCTUnwrap(NSScreen.main)
        let (usage, companion, focus, dir) = try stores()
        let suite = "gameboy-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let pointer = NSEvent.mouseLocation
        func movePointer(_ point: NSPoint) {
            CGWarpMouseCursorPosition(CGPoint(x: point.x, y: (NSScreen.screens.first?.frame.maxY ?? 0) - point.y))
        }
        defer { movePointer(pointer) }
        movePointer(NSPoint(x: screen.visibleFrame.midX, y: screen.visibleFrame.maxY - 5))
        usage.floatingPetStyle = .battle
        usage.floatingPetEnabled = true
        usage.battleWindowScale = 1
        focus.startPomodoro()
        let controller = FloatingPetController(store: usage, companion: companion, session: focus, defaults: defaults)
        defer { controller.setDisplayAwake(false) }
        let panel = try XCTUnwrap(NSApp.windows.first { $0.isVisible && $0.identifier?.rawValue == "PokeTasks.BattleWindow" })
        let content = try XCTUnwrap(panel.contentView as? BattlePanelContent)
        let web = try XCTUnwrap(content.subviews.compactMap { $0 as? WKWebView }.first)
        for _ in 0..<100 {
            if (try? await web.evaluateJavaScript("!!document.querySelector('.fold-window') && getComputedStyle(document.querySelector('main')).visibility === 'visible'")) as? Bool == true { break }
            try await Task.sleep(for: .milliseconds(30))
        }
        let buttonX = try await web.evaluateJavaScript("document.querySelector('.fold-window').getBoundingClientRect().left") as? Double
        let drag = try XCTUnwrap(content.subviews.first { NSStringFromClass(type(of: $0)).contains("BattleHeaderDragView") })
        XCTAssertLessThanOrEqual(drag.frame.maxX, try XCTUnwrap(buttonX), "The drag surface must leave the fold button clickable")
        _ = try await web.evaluateJavaScript("document.querySelector('.commands button:last-child').click()")
        try await Task.sleep(for: .milliseconds(100))
        let before = focus.session
        XCTAssertTrue(panel.makeFirstResponder(web))
        _ = try await web.evaluateJavaScript("document.querySelector('.fold-window').click()")
        for _ in 0..<100 where !(panel.contentView is PetHostingView) { try await Task.sleep(for: .milliseconds(30)) }
        XCTAssertTrue(usage.battleWindowFolded)
        XCTAssertEqual(focus.session, before)
        let firstIcon = try XCTUnwrap(panel.contentView as? PetHostingView)
        XCTAssertTrue(panel.firstResponder === firstIcon, "Folding must move event focus away from the hidden web view")
        XCTAssertEqual(firstIcon.accessibilityRole(), .button)
        usage.limitDisplayMode = usage.limitDisplayMode == .used ? .remaining : .used
        try await Task.sleep(for: .milliseconds(150))
        XCTAssertEqual(firstIcon.toolTip, "Open Battle window · Right-click to tuck at screen edge")
        for scale in [0.5, 1.0, 2.0] {
            usage.battleWindowScale = scale
            try await Task.sleep(for: .milliseconds(150))
            panel.contentView?.layoutSubtreeIfNeeded()
            XCTAssertEqual(panel.frame.width, 80 * scale, accuracy: 0.1)
            XCTAssertEqual(panel.frame.height, 96 * scale, accuracy: 0.1)
        }
        // Folding leaves the native session accruing while web updates are suspended.
        focus.tick(now: now.addingTimeInterval(1800))
        XCTAssertTrue(focus.session?.isAccruing == true)
        XCTAssertEqual(focus.session?.displayedSeconds(at: now.addingTimeInterval(1800)), 1800)
        XCTAssertEqual(focus.prompt, .checkIn)
        let active = focus.session
        usage.battleWindowScale = 1
        var peeks: [Data] = []
        for edge in [FloatingPetController.TuckEdge.left, .right] {
            usage.battleWindowFolded = true
            try await Task.sleep(for: .milliseconds(150))
            if controller.tuckEdge != nil { controller.toggleEdgeTucking() }
            panel.setFrameOrigin(NSPoint(x: edge == .left ? screen.visibleFrame.minX + 20 : screen.visibleFrame.maxX - 100,
                                         y: screen.visibleFrame.minY + 100))
            let host = try XCTUnwrap(panel.contentView as? PetHostingView)
            let menu = host.makeContextMenu()
            XCTAssertNotNil(menu.item(withTitle: "Open Battle window"))
            let tuck = try XCTUnwrap(menu.item(withTitle: "Tuck at screen edge"))
            XCTAssertTrue(NSApp.sendAction(try XCTUnwrap(tuck.action), to: tuck.target, from: tuck))
            try await Task.sleep(for: .milliseconds(220))
            host.layoutSubtreeIfNeeded()
            XCTAssertEqual(controller.tuckEdge, edge)
            XCTAssertEqual(host.tuckedEdge, edge)
            XCTAssertEqual(panel.frame.width, 40, accuracy: 0.1, "Half of the Game Boy stays visible")
            XCTAssertEqual(host.fittingSize.width, 40, accuracy: 1)
            XCTAssertTrue(screen.visibleFrame.contains(panel.frame), "Cropping must not spill onto an adjacent display")
            let bitmap = try XCTUnwrap(host.bitmapImageRepForCachingDisplay(in: host.bounds))
            host.cacheDisplay(in: host.bounds, to: bitmap)
            XCTAssertTrue((0..<bitmap.pixelsHigh).contains { y in
                (0..<bitmap.pixelsWide).contains { x in (bitmap.colorAt(x: x, y: y)?.alphaComponent ?? 0) > 0.5 }
            }, "The tilted peek must contain visible artwork")
            let png = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
            peeks.append(png)
            if let output = ProcessInfo.processInfo.environment["PTB_GAMEBOY_PREVIEW_DIR"] {
                try FileManager.default.createDirectory(atPath: output, withIntermediateDirectories: true)
                try png.write(to: URL(fileURLWithPath: output).appendingPathComponent("gameboy-\(edge).png"))
            }
            host.onHoverChange?(true)
            try await Task.sleep(for: .milliseconds(220))
            XCTAssertNil(host.tuckedEdge)
            XCTAssertEqual(panel.frame.width, 80, accuracy: 0.1)
            host.onHoverChange?(false)
            for _ in 0..<40 where panel.frame.width != 40 { try await Task.sleep(for: .milliseconds(50)) }
            XCTAssertEqual(panel.frame.width, 40, accuracy: 0.1)
            if edge == .left {
                for type in [NSEvent.EventType.leftMouseDown, .leftMouseUp] {
                    panel.sendEvent(try XCTUnwrap(NSEvent.mouseEvent(with: type, location: NSPoint(x: 20, y: 48),
                        modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime,
                        windowNumber: panel.windowNumber, context: nil, eventNumber: 1, clickCount: 1, pressure: 1)))
                }
            } else { XCTAssertTrue(host.accessibilityPerformPress()) }
            try await Task.sleep(for: .milliseconds(150))
            XCTAssertFalse(usage.battleWindowFolded)
            XCTAssertTrue(panel.contentView is BattlePanelContent)
            XCTAssertEqual(panel.frame.width, 360, accuracy: 0.1)
            let reopened = try XCTUnwrap((panel.contentView as? BattlePanelContent)?.subviews.compactMap { $0 as? WKWebView }.first)
            let reopenedTitle = try await reopened.evaluateJavaScript("document.querySelector('.game-title').textContent") as? String
            XCTAssertEqual(reopenedTitle, "MORE", "Unfolding must restore the existing Battle view, not recreate its initial screen")
            XCTAssertEqual(focus.session, active, "Folding, hover and opening must not change the timer or rewards")
        }
        XCTAssertNotEqual(peeks[0], peeks[1], "Each edge has its own inward tilt and crop")
        XCTAssertTrue(FileManager.default.fileExists(atPath: dir.appendingPathComponent("focus.json").path))
        // A saved fold must also work when switching from Classic without opening WebKit first.
        usage.floatingPetStyle = .classic
        try await Task.sleep(for: .milliseconds(150))
        usage.battleWindowFolded = true
        usage.floatingPetStyle = .battle
        try await Task.sleep(for: .milliseconds(150))
        let foldedHost = try XCTUnwrap(panel.contentView as? PetHostingView)
        usage.floatingPetStyle = .classic
        try await Task.sleep(for: .milliseconds(150))
        XCTAssertFalse(panel.contentView === foldedHost, "Classic must replace the Game Boy artwork and interactions")
        let classic = try XCTUnwrap(panel.contentView as? PetHostingView)
        XCTAssertNotEqual(classic.accessibilityRole(), .button)
        XCTAssertNil(classic.accessibilityValue(), "Classic must not expose the folded Game Boy's clock")
        let classicMenu = try XCTUnwrap(classic.menu(for: try XCTUnwrap(NSEvent.mouseEvent(with: .rightMouseDown,
            location: .zero, modifierFlags: [], timestamp: 0, windowNumber: panel.windowNumber,
            context: nil, eventNumber: 1, clickCount: 1, pressure: 1))))
        XCTAssertNotNil(classicMenu.item(withTitle: "Open Token Bar"))
        XCTAssertNil(classicMenu.item(withTitle: "Open Battle window"))
        XCTAssertEqual(classicMenu.item(withTitle: "Classic Floating Pet Mode")?.state, .on)
    }

    func testFoldedGameBoyDisplaysCountdownAndReceivesNativeMouseClicks() async throws {
        _ = NSApplication.shared
        let activationPolicy = NSApp.activationPolicy()
        NSApp.setActivationPolicy(.accessory)
        NSApp.finishLaunching()
        defer { NSApp.setActivationPolicy(activationPolicy) }
        let (usage, companion, _, dir) = try stores()
        var instant = now
        let focus = FocusSessionStore(usage: usage, companion: companion, clock: { instant },
            fileURL: dir.appendingPathComponent("gameboy-focus.json"), ticksOnTimer: false)
        let suite = "gameboy-mouse-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        usage.floatingPetEnabled = true
        usage.floatingPetStyle = .battle
        usage.battleWindowScale = 1
        usage.battleWindowFolded = true
        defaults.set(500.0, forKey: "battleWindowAnchorX")
        defaults.set(300.0, forKey: "battleWindowAnchorY")
        focus.plannedMinutes = 5
        let controller = FloatingPetController(store: usage, companion: companion, session: focus, defaults: defaults)
        defer { controller.setDisplayAwake(false) }
        let panel = try XCTUnwrap(NSApp.windows.first { $0.isVisible && $0.identifier?.rawValue == "PokeTasks.BattleWindow" })
        let host = try XCTUnwrap(panel.contentView as? PetHostingView)
        func settle() async throws {
            try await Task.sleep(for: .milliseconds(150))
            host.layoutSubtreeIfNeeded()
        }
        func pixels() throws -> Data {
            let bitmap = try XCTUnwrap(host.bitmapImageRepForCachingDisplay(in: host.bounds))
            host.cacheDisplay(in: host.bounds, to: bitmap)
            return try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
        }
        try await settle()
        XCTAssertEqual(host.accessibilityValue() as? String, "No active timer")
        let idle = try pixels()
        focus.startPomodoro()
        try await settle()
        XCTAssertEqual(host.accessibilityValue() as? String, "5:00")
        XCTAssertNotEqual(try pixels(), idle, "Starting a timer must populate the folded LCD")
        let point = NSPoint(x: 40, y: 60) // The actual LCD click surface in window coordinates.
        let local = host.convert(point, from: nil)
        XCTAssertTrue(host.hitTest(local) === host, "Native clicks must reach the Game Boy's mouse/menu handler")
        XCTAssertFalse(panel.ignoresMouseEvents)
        let screenPoint = panel.convertPoint(toScreen: point)
        XCTAssertEqual(NSWindow.windowNumber(at: screenPoint, belowWindowWithWindowNumber: 0), panel.windowNumber,
            "The visible LCD must receive clicks through WindowServer, not only direct sendEvent calls")
        let first = try pixels()
        instant = instant.addingTimeInterval(1)
        focus.tick()
        try await settle()
        XCTAssertNotEqual(try pixels(), first, "The LCD must visibly count down while folded")
        XCTAssertEqual(host.accessibilityValue() as? String, "4:59")
        focus.togglePause()
        try await settle()
        let paused = try pixels()
        instant = instant.addingTimeInterval(30)
        focus.tick()
        try await settle()
        XCTAssertEqual(try pixels(), paused, "Pausing must freeze the folded LCD")
        XCTAssertEqual(host.accessibilityValue() as? String, "4:59")
        let savedSession = focus.session
        var trackedMenu = false
        let originalTracking = host.onMenuTrackingChange
        host.onMenuTrackingChange = { tracking in
            originalTracking?(tracking)
            guard tracking else { return }
            trackedMenu = true
            // Dismiss the real popup through its event loop; do not bypass right-click routing.
            NSApp.postEvent(NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [],
                timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: panel.windowNumber,
                context: nil, characters: "\u{1b}", charactersIgnoringModifiers: "\u{1b}",
                isARepeat: false, keyCode: 53)!, atStart: true)
        }
        func event(_ type: NSEvent.EventType) throws -> NSEvent {
            try XCTUnwrap(NSEvent.mouseEvent(with: type, location: point, modifierFlags: [],
                timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: panel.windowNumber,
                context: nil, eventNumber: 1, clickCount: 1, pressure: 1))
        }
        let contextual = try XCTUnwrap(host.menu(for: try event(.rightMouseDown)),
            "AppKit's context-menu lookup must find the Game Boy menu")
        XCTAssertNotNil(contextual.item(withTitle: "Open Battle window"))
        XCTAssertNotNil(contextual.item(withTitle: "Tuck at screen edge"))
        panel.sendEvent(try event(.rightMouseDown))
        XCTAssertTrue(trackedMenu, "An actual right-click must open the existing context menu")
        XCTAssertTrue(usage.battleWindowFolded)
        XCTAssertEqual(focus.session, savedSession)
        if CGPreflightPostEventAccess() {
            NSApp.activate(ignoringOtherApps: true)
            let oldPointer = CGEvent(source: nil)?.location
            defer { if let oldPointer { CGWarpMouseCursorPosition(oldPointer) } }
            let quartz = CGPoint(x: screenPoint.x, y: NSScreen.screens[0].frame.maxY - screenPoint.y)
            func screenClick(right: Bool) async throws {
                let down: CGEventType = right ? .rightMouseDown : .leftMouseDown
                let up: CGEventType = right ? .rightMouseUp : .leftMouseUp
                let button: CGMouseButton = right ? .right : .left
                let tag = Int64.random(in: 1...Int64.max)
                XCTAssertEqual(CGWarpMouseCursorPosition(quartz), .success)
                for type in [down, up] {
                    let posted = try XCTUnwrap(CGEvent(mouseEventSource: nil, mouseType: type,
                        mouseCursorPosition: quartz, mouseButton: button))
                    posted.setIntegerValueField(.eventSourceUserData, value: tag)
                    posted.post(tap: .cghidEventTap)
                }
                var delivered = false
                var released = false
                let deadline = Date().addingTimeInterval(2)
                while Date() < deadline {
                    guard let next = NSApp.nextEvent(matching: .any, until: Date().addingTimeInterval(0.05),
                        inMode: .default, dequeue: true) else { continue }
                    let ours = next.cgEvent?.getIntegerValueField(.eventSourceUserData) == tag
                    if ours, next.type == (right ? .rightMouseDown : .leftMouseDown) {
                        delivered = next.windowNumber == panel.windowNumber
                    }
                    if ours, next.type == (right ? .rightMouseUp : .leftMouseUp) {
                        released = next.windowNumber == panel.windowNumber
                    }
                    NSApp.sendEvent(next)
                    // Menu tracking can consume its release; drain any remaining release before the next click.
                    if ours, next.type == (right ? .rightMouseUp : .leftMouseUp) { break }
                }
                XCTAssertTrue(delivered, "WindowServer must deliver the screen click to the Game Boy")
                if !right {
                    XCTAssertTrue(released, "WindowServer must deliver the screen release to the same Game Boy")
                }
            }
            trackedMenu = false
            try await screenClick(right: true)
            XCTAssertTrue(trackedMenu, "A screen right-click must open the menu")
            try await screenClick(right: false)
        } else {
            for type in [NSEvent.EventType.leftMouseDown, .leftMouseUp] { panel.sendEvent(try event(type)) }
        }
        try await Task.sleep(for: .milliseconds(200))
        XCTAssertFalse(usage.battleWindowFolded, "An ordinary screen click must unfold Battle")
        let content = try XCTUnwrap(panel.contentView as? BattlePanelContent)
        let web = try XCTUnwrap(content.subviews.compactMap { $0 as? WKWebView }.first)
        for _ in 0..<100 {
            if (try? await web.evaluateJavaScript("document.querySelector('.time strong')?.textContent")) as? String == "4:59" { break }
            try await Task.sleep(for: .milliseconds(30))
        }
        let restoredClock = try await web.evaluateJavaScript("document.querySelector('.time strong').textContent") as? String
        XCTAssertEqual(restoredClock, "4:59")
        XCTAssertEqual(focus.session, savedSession, "Unfolding must preserve the same paused session")
        _ = try await web.evaluateJavaScript("document.querySelector('.fold-window').click()")
        for _ in 0..<100 where !(panel.contentView is PetHostingView) { try await Task.sleep(for: .milliseconds(30)) }
        focus.togglePause()
        instant = instant.addingTimeInterval(299)
        focus.tick()
        try await Task.sleep(for: .milliseconds(200))
        let zeroIcon = try XCTUnwrap(panel.contentView as? PetHostingView)
        XCTAssertEqual(zeroIcon.accessibilityValue() as? String, "0:00")
        XCTAssertEqual(focus.session?.phase, .awaitingChoice)
        if let output = ProcessInfo.processInfo.environment["PTB_GAMEBOY_PREVIEW_DIR"] {
            try FileManager.default.createDirectory(atPath: output, withIntermediateDirectories: true)
            try paused.write(to: URL(fileURLWithPath: output).appendingPathComponent("gameboy-paused-lcd.png"))
            zeroIcon.layoutSubtreeIfNeeded()
            let bitmap = try XCTUnwrap(zeroIcon.bitmapImageRepForCachingDisplay(in: zeroIcon.bounds))
            zeroIcon.cacheDisplay(in: zeroIcon.bounds, to: bitmap)
            try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
                .write(to: URL(fileURLWithPath: output).appendingPathComponent("gameboy-zero-lcd.png"))
        }
    }

    func testBundledWebViewUsesNativeStateAndEqualBars() async throws {
        _ = NSApplication.shared
        let (usage, companion, _, dir) = try stores()
        let focus = FocusSessionStore(usage: usage, companion: companion, clock: Date.init,
            fileURL: dir.appendingPathComponent("focus.json"), ticksOnTimer: false)
        usage.floatingPetStyle = .battle
        let battle = BattleWindow(usage: usage, companion: companion, focus: focus)
        defer { battle.stop() }
        battle.content.gameSize = NSSize(width: 360, height: 180)
        battle.content.frame = NSRect(x: 0, y: 0, width: 360, height: 180)
        battle.content.layoutSubtreeIfNeeded()
        for _ in 0..<100 {
            if (try? await battle.webView.evaluateJavaScript("document.querySelector('.game-title')?.textContent === 'A new Task wants to Battle!' && getComputedStyle(document.querySelector('main')).visibility === 'visible' && document.fonts.status === 'loaded'")) as? Bool == true { break }
            try await Task.sleep(for: .milliseconds(50))
        }
        let result = try await battle.webView.evaluateJavaScript("({visible:getComputedStyle(document.querySelector('main')).visibility,hp:document.querySelector('.hp').offsetWidth,xp:document.querySelector('.xp').offsetWidth,title:document.querySelector('.game-title').textContent})") as? [String: Any]
        XCTAssertEqual(result?["visible"] as? String, "visible")
        XCTAssertEqual(result?["title"] as? String, "A new Task wants to Battle!")
        XCTAssertEqual(result?["hp"] as? Int, result?["xp"] as? Int)
        XCTAssertEqual(result?["hp"] as? Int, 127)
        let typography = try await battle.webView.evaluateJavaScript("({pixelLoaded:Array.from(document.fonts).some(font => font.family.includes('Departure Mono') && font.status === 'loaded'),body:getComputedStyle(document.querySelector('.dialogue')).fontFamily})") as? [String: Any]
        XCTAssertEqual(typography?["pixelLoaded"] as? Bool, true, "The packaged pixel font must load from the local app bundle")
        XCTAssertTrue((typography?["body"] as? String)?.contains("Menlo") == true)
        XCTAssertEqual(battle.snapshot()["coins"] as? Int, companion.availableCoins)
        XCTAssertEqual((battle.snapshot()["bag"] as? [String: Int])?["potion"], 0)
        _ = try await battle.webView.evaluateJavaScript("document.querySelector('.commands button').click()")
        for _ in 0..<50 where !focus.isActive { try await Task.sleep(for: .milliseconds(20)) }
        XCTAssertTrue(focus.isActive, "The bundled Start button must reach the native timer")
        for _ in 0..<50 {
            if try await battle.webView.evaluateJavaScript("document.querySelector('.commands button').textContent === 'Pause' && !document.querySelector('.commands button').disabled") as? Bool == true { break }
            try await Task.sleep(for: .milliseconds(20))
        }
        _ = try await battle.webView.evaluateJavaScript("document.querySelector('.commands button').click()")
        for _ in 0..<50 where focus.session?.userPaused != true { try await Task.sleep(for: .milliseconds(20)) }
        XCTAssertTrue(focus.session?.userPaused == true, "The bundled Pause button must pause the native timer")

        let movingControls = try await battle.webView.evaluateJavaScript("Array.from(document.styleSheets).flatMap(sheet => Array.from(sheet.cssRules)).filter(rule => rule.selectorText?.includes('.game button') && (rule.selectorText.includes(':hover') || rule.selectorText.includes(':active')) && rule.style.transform && rule.style.transform !== 'none').length") as? Int
        XCTAssertEqual(movingControls, 0, "Hover/press must not move a control's hit target under a stationary pointer")
        XCTAssertTrue(companion.buy(.potion, count: 2))
        XCTAssertTrue(companion.buy(.superPotion))
        XCTAssertTrue(companion.buy(.fullRestore))
        battle.publish()
        func openBag() async throws {
            battle.openBag()
            for _ in 0..<50 {
                if try await battle.webView.evaluateJavaScript("!!document.querySelector('.item-list')") as? Bool == true { return }
                try await Task.sleep(for: .milliseconds(20))
            }
            XCTFail("The potion bag did not open")
        }
        func doubleClick(_ index: Int) async throws {
            _ = try await battle.webView.evaluateJavaScript("document.querySelectorAll('.item')[\(index)].dispatchEvent(new MouseEvent('dblclick', { bubbles: true }))")
            try await Task.sleep(for: .milliseconds(100))
        }
        let planned = try XCTUnwrap(focus.session?.plannedSeconds)
        try await openBag()
        _ = try await battle.webView.evaluateJavaScript("document.querySelectorAll('.item')[0].click()")
        XCTAssertEqual(companion.itemCount(.potion), 2, "Single-click only selects the item")
        try await doubleClick(1)
        XCTAssertEqual(companion.itemCount(.superPotion), 0, "Double-click uses the clicked item, even if another was selected")
        XCTAssertEqual(companion.itemCount(.potion), 2)
        XCTAssertEqual(focus.session?.plannedSeconds, planned + 15 * 60)
        XCTAssertTrue(focus.session?.userPaused == true)
        try await openBag()
        try await doubleClick(1)
        XCTAssertEqual(focus.session?.plannedSeconds, planned + 15 * 60, "An empty item cannot add time")
        try await doubleClick(4)
        let customInput = try await battle.webView.evaluateJavaScript("document.querySelector('#minute-input')?.getAttribute('aria-label')") as? String
        XCTAssertEqual(customInput, "Extra minutes")
        XCTAssertEqual(companion.itemCount(.fullRestore), 1, "Full Restore waits for custom minutes")
        _ = try await battle.webView.evaluateJavaScript("const input = document.querySelector('#minute-input'); Object.getOwnPropertyDescriptor(HTMLInputElement.prototype, 'value').set.call(input, '7'); input.dispatchEvent(new Event('input', { bubbles: true }));")
        _ = try await battle.webView.evaluateJavaScript("document.querySelector('.commands button').click()")
        for _ in 0..<50 where companion.itemCount(.fullRestore) != 0 { try await Task.sleep(for: .milliseconds(20)) }
        XCTAssertEqual(companion.itemCount(.fullRestore), 0)
        XCTAssertEqual(focus.session?.plannedSeconds, planned + 22 * 60)
        try await openBag()
        _ = try await battle.webView.evaluateJavaScript("document.querySelectorAll('.commands button')[1].click()")
        let coins = companion.availableCoins
        try await doubleClick(0)
        XCTAssertEqual(companion.availableCoins, coins, "Shop double-click must not buy or use an item")
        XCTAssertEqual(companion.itemCount(.potion), 2)
    }

    func testTaskChooserKeepsSharedIssueCardsAndSwitchConfirmationInsideBattle() async throws {
        _ = NSApplication.shared
        let (_, companion, _, dir) = try stores()
        let data = try JSONSerialization.data(withJSONObject: ["data": [
            "inProgress": ["nodes": [["id": "active", "identifier": "TEST-1", "title": "Current work",
                "state": ["id": "started", "name": "In Progress", "type": "started"]]]],
            "planned": ["nodes": [["id": "planned", "identifier": "TEST-2", "title": "Next task",
                "state": ["id": "planned", "name": "Planned", "type": "unstarted"]]]],
            "todo": ["nodes": []], "completedRecent": ["nodes": []],
            "projects": ["nodes": []], "initiatives": ["nodes": []], "projectStatuses": ["nodes": []]
        ]])
        struct HTTP: LinearHTTPClient {
            let data: Data
            func postGraphQL(apiKey: String, body: Data) async throws -> (status: Int, data: Data) { (200, data) }
        }
        let suite = "battle-picker-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(true, forKey: "linearIntegrationEnabled")
        let keys = LinearAPIKeyStore(fileURL: dir.appendingPathComponent("test-key.json"))
        try keys.save(.init(key: "lin_api_fixture"))
        let usage = UsageStore(providers: [], autoRefresh: false, defaults: defaults,
            linearClient: LinearClient(http: HTTP(data: data)), linearAPIKeys: keys)
        _ = await usage.refreshLinearIssues()
        let focus = FocusSessionStore(usage: usage, companion: companion, clock: { self.now },
            fileURL: dir.appendingPathComponent("picker-focus.json"), ticksOnTimer: false)
        var openedDesk = false
        focus.onOpenDesk = { openedDesk = true }
        let battle = BattleWindow(usage: usage, companion: companion, focus: focus)
        defer { battle.stop() }
        battle.onLayout = { [weak battle] height, _ in
            guard let battle else { return }
            let scale = usage.battleWindowScale
            battle.content.gameSize = NSSize(width: 360 * scale, height: height * scale)
            battle.content.setFrameSize(battle.content.gameSize)
            battle.content.layoutSubtreeIfNeeded()
        }
        let window = NSWindow(contentRect: NSRect(x: 350, y: 300, width: 360, height: 180),
            styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = battle.content
        window.orderFrontRegardless()
        defer { window.orderOut(nil); window.contentView = nil }
        for _ in 0..<100 {
            if (try? await battle.webView.evaluateJavaScript("!!Array.from(document.querySelectorAll('button')).find(b => b.textContent === 'Choose task' && !b.disabled)")) as? Bool == true { break }
            try await Task.sleep(for: .milliseconds(30))
        }
        _ = try await battle.webView.evaluateJavaScript("Array.from(document.querySelectorAll('button')).find(b => b.textContent === 'Choose task').click()")
        for _ in 0..<50 where battle.content.taskPicker == nil { try await Task.sleep(for: .milliseconds(20)) }
        XCTAssertNotNil(battle.content.taskPicker, "Choose task must open inside the same Battle panel")
        XCTAssertTrue(battle.webView.isHidden)
        func cards(_ view: NSView) -> [LinearIssueDragView] {
            guard !view.isHiddenOrHasHiddenAncestor else { return [] }
            return (view as? LinearIssueDragView).map { [$0] } ?? view.subviews.flatMap(cards)
        }
        for scale in [0.5, 1.0, 2.0] {
            usage.battleWindowScale = scale
            battle.content.gameSize = NSSize(width: 360 * scale, height: 380 * scale)
            battle.content.setFrameSize(battle.content.gameSize)
            try await Task.sleep(for: .milliseconds(100))
            battle.content.layoutSubtreeIfNeeded()
            let picker = try XCTUnwrap(battle.content.taskPicker)
            XCTAssertEqual(picker.frame.width, 360 * scale, accuracy: 0.1)
            XCTAssertEqual(picker.frame.height, 380 * scale, accuracy: 0.1)
            XCTAssertEqual(Set(cards(picker).map(\.issueID)), ["active", "planned"], "Reuse the existing interactive card views")
            if scale == 1, let output = ProcessInfo.processInfo.environment["PTB_BATTLE_PREVIEW_DIR"] {
                let bitmap = try XCTUnwrap(picker.bitmapImageRepForCachingDisplay(in: picker.bounds))
                picker.cacheDisplay(in: picker.bounds, to: bitmap)
                try FileManager.default.createDirectory(atPath: output, withIntermediateDirectories: true)
                try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
                    .write(to: URL(fileURLWithPath: output).appendingPathComponent("battle-task-chooser.png"))
            }
        }
        usage.battleWindowScale = 1
        battle.content.gameSize = NSSize(width: 360, height: 380)
        battle.content.setFrameSize(battle.content.gameSize)
        battle.content.layoutSubtreeIfNeeded()
        window.makeKeyAndOrderFront(nil)
        func fields(_ view: NSView) -> [NSTextField] {
            (view as? NSTextField).map { [$0] } ?? view.subviews.flatMap(fields)
        }
        let picker = try XCTUnwrap(battle.content.taskPicker)
        let search = try XCTUnwrap(fields(picker).first { $0.isEditable && $0.placeholderString == "Search issues" })
        func searchFor(_ text: String) async throws {
            window.makeFirstResponder(search)
            let editor = try XCTUnwrap(search.currentEditor() as? NSTextView)
            editor.selectAll(nil)
            editor.insertText(text, replacementRange: editor.selectedRange())
            try await Task.sleep(for: .milliseconds(100))
            picker.layoutSubtreeIfNeeded()
        }
        try await searchFor("TEST-2")
        XCTAssertEqual(cards(picker).map(\.issueID), ["planned"])
        try await searchFor("No matching task")
        XCTAssertTrue(cards(picker).isEmpty)
        try await searchFor("")
        XCTAssertEqual(Set(cards(picker).map(\.issueID)), ["active", "planned"])
        let active = try XCTUnwrap(usage.linearIssue(id: "active"))
        let next = try XCTUnwrap(usage.linearIssue(id: "planned"))
        focus.pin(active, openDesk: false, minutes: 15)
        try await Task.sleep(for: .milliseconds(100))
        XCTAssertNil(battle.content.taskPicker, "Starting a selected task restores the Battle view")
        battle.openTaskPicker()
        focus.pin(next, openDesk: false, minutes: 30)
        try await Task.sleep(for: .milliseconds(100))
        XCTAssertNotNil(focus.forfeitPrompt)
        XCTAssertNotNil(battle.content.taskPicker, "Switch confirmation stays in Battle")
        XCTAssertEqual(focus.session?.issue.id, "active")
        battle.closeTaskPicker()
        XCTAssertNil(focus.forfeitPrompt)
        XCTAssertEqual(focus.session?.issue.id, "active", "Closing the picker cancels switching")
        battle.openTaskPicker()
        focus.pin(next, openDesk: false, minutes: 30)
        await focus.confirmForfeit()
        try await Task.sleep(for: .milliseconds(100))
        XCTAssertEqual(focus.session?.issue.id, "planned")
        XCTAssertEqual(focus.session?.plannedSeconds, 30 * 60)
        XCTAssertNil(battle.content.taskPicker)
        XCTAssertFalse(battle.webView.isHidden)
        XCTAssertFalse(openedDesk, "Selection must not open the separate task window")
    }
}
