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
            if (try? await battle.webView.evaluateJavaScript("document.querySelector('.game-title')?.textContent === 'A new Task wants to Battle!' && getComputedStyle(document.querySelector('main')).visibility === 'visible'")) as? Bool == true { break }
            try await Task.sleep(for: .milliseconds(50))
        }
        let result = try await battle.webView.evaluateJavaScript("({visible:getComputedStyle(document.querySelector('main')).visibility,hp:document.querySelector('.hp').offsetWidth,xp:document.querySelector('.xp').offsetWidth,title:document.querySelector('.game-title').textContent})") as? [String: Any]
        XCTAssertEqual(result?["visible"] as? String, "visible")
        XCTAssertEqual(result?["title"] as? String, "A new Task wants to Battle!")
        XCTAssertEqual(result?["hp"] as? Int, result?["xp"] as? Int)
        XCTAssertEqual(result?["hp"] as? Int, 127)
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
    }
}
