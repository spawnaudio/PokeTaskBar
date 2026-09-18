import AppKit
import QuartzCore
import XCTest
@testable import PokeTaskBar

private struct XPFeedbackNoProvider: PokeProviding {
    func line(baseSpeciesID: Int) async throws -> EvoLine { throw URLError(.notConnectedToInternet) }
    func baseSpeciesIndex() async throws -> [BaseSpecies] { [] }
    func baseSpecies(id: Int) async throws -> BaseSpecies? { nil }
}

@MainActor
final class XPFeedbackTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    private func store(state: CompanionState = CompanionState(), clock: (() -> Date)? = nil,
                       provider: any PokeProviding = XPFeedbackNoProvider()) throws -> CompanionStore {
        let id = "xp-feedback-\(UUID().uuidString)"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(id + ".json")
        try JSONEncoder().encode(state).write(to: url)
        let defaults = try XCTUnwrap(UserDefaults(suiteName: id))
        addTeardownBlock {
            try? FileManager.default.removeItem(at: url)
            UserDefaults(suiteName: id)?.removePersistentDomain(forName: id)
        }
        return CompanionStore(provider: provider, clock: clock ?? { self.now },
                              fileURL: url, defaults: defaults)
    }

    func testAwardsReportActualMintScaledAmountsAndIgnoreZero() throws {
        var state = CompanionState()
        state.mintExpiresAt = now.addingTimeInterval(600)
        let store = try store(state: state)
        var rewards: [XPReward] = []
        store.onXPEarned = { rewards.append($0) }
        store.creditEarnedXP(250, fromTokens: true)
        store.applyProgressXP(400)
        store.applyProgressXP(0)
        store.applyProgressXP(-10)
        XCTAssertEqual(rewards, [XPReward(amount: 500, source: .tokens), XPReward(amount: 800, source: .timeOpen)])
        XCTAssertEqual(rewards.reduce(0) { $0 + $1.amount }, store.lifetimeXP)
    }

    func testIssueAndProjectSeedPollsAndDuplicatesDoNotAnimate() throws {
        let store = try store()
        var rewards: [XPReward] = []
        store.onXPEarned = { rewards.append($0) }
        let old = LinearCompletedIssue(id: "old", identifier: "APP-1", title: "Old", completedAt: now)
        let new = LinearCompletedIssue(id: "new", identifier: "APP-2", title: "New", completedAt: now)
        let project = LinearCompletedProject(id: "project", name: "Ship", completedAt: now)
        store.creditLinearCompletions([old])
        store.creditLinearProjects([])
        XCTAssertTrue(rewards.isEmpty)
        store.creditLinearCompletions([old, new])
        store.creditLinearCompletions([new])
        store.creditLinearProjects([project])
        store.creditLinearProjects([project])
        XCTAssertEqual(rewards, [XPReward(amount: LinearRewards.xpPerIssue, source: .issue),
                                 XPReward(amount: LinearRewards.xpPerProject, source: .project)])
    }

    private func completionStores(state: CompanionState = CompanionState()) throws
        -> (UsageStore, CompanionStore, FocusSessionStore) {
        let id = "project-feedback-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: id))
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(id + ".json")
        addTeardownBlock {
            UserDefaults(suiteName: id)?.removePersistentDomain(forName: id)
            try? FileManager.default.removeItem(at: url)
        }
        let usage = UsageStore(providers: [], autoRefresh: false, defaults: defaults)
        usage.localizationLanguage = .en
        let companion = try store(state: state)
        let session = FocusSessionStore(usage: usage, companion: companion,
                                       fileURL: url, ticksOnTimer: false)
        return (usage, companion, session)
    }

    func testProjectPollShowsMintScaledXPAndCompletionPopupOnlyForNewWork() throws {
        var state = CompanionState()
        state.mintExpiresAt = now.addingTimeInterval(600)
        let (usage, companion, session) = try completionStores(state: state)
        var rewards: [XPReward] = []
        companion.onXPEarned = { rewards.append($0) }
        let old = LinearCompletedProject(id: "old-project", name: "Earlier release", completedAt: now)
        let fresh = LinearCompletedProject(id: "new-project", name: "Ship the album", completedAt: now)

        AppDelegate.applyLinearCompletions([], projects: [old], store: usage,
                                           companion: companion, sessionStore: session)
        XCTAssertTrue(rewards.isEmpty, "First poll only seeds completed project IDs")
        XCTAssertNil(usage.currentSpeechBubble)

        AppDelegate.applyLinearCompletions([], projects: [old, fresh], store: usage,
                                           companion: companion, sessionStore: session)
        XCTAssertEqual(rewards, [XPReward(amount: 2 * LinearRewards.xpPerProject, source: .project)])
        XCTAssertEqual(usage.currentSpeechBubble?.title, "Project complete!")
        XCTAssertEqual(usage.currentSpeechBubble?.body, "Ship the album")
        XCTAssertEqual(usage.menuLines, ["Done", "Ship the album"])

        // A repeated poll must not replace another message with a stale celebration.
        usage.announceTimesUp("FOCUS-1")
        let bubble = usage.currentSpeechBubble
        let lines = usage.menuLines
        AppDelegate.applyLinearCompletions([], projects: [old, fresh], store: usage,
                                           companion: companion, sessionStore: session)
        XCTAssertEqual(rewards.count, 1)
        XCTAssertEqual(usage.currentSpeechBubble, bubble)
        XCTAssertEqual(usage.menuLines, lines)
    }

    func testMixedCompletionPollKeepsBothXPReceiptsAndOneCombinedPopup() async throws {
        let (usage, companion, session) = try completionStores()
        AppDelegate.applyLinearCompletions([], projects: [], store: usage,
                                           companion: companion, sessionStore: session)
        let controller = XPFeedbackController(duration: 0.02)
        var shown: [XPReward] = []
        let drained = expectation(description: "issue and project receipts displayed")
        controller.onChange = { reward in
            if let reward { shown.append(reward) }
            else if shown.count == 2 { drained.fulfill() }
        }
        companion.onXPEarned = { controller.receive($0) }
        let issue = LinearCompletedIssue(id: "issue", identifier: "APP-42", title: "Mix track", completedAt: now)
        let projects = ["Album", "Website"].map {
            LinearCompletedProject(id: $0, name: $0, completedAt: now)
        }
        AppDelegate.applyLinearCompletions([issue], projects: projects, store: usage,
                                           companion: companion, sessionStore: session)
        XCTAssertEqual(usage.currentSpeechBubble?.title, "3 completions!")
        XCTAssertEqual(usage.currentSpeechBubble?.body, "Album · APP-42")
        XCTAssertEqual(usage.menuLines, ["3 done", "Album"])
        await fulfillment(of: [drained], timeout: 2)
        XCTAssertEqual(shown, [XPReward(amount: LinearRewards.xpPerIssue, source: .issue),
                               XPReward(amount: 2 * LinearRewards.xpPerProject, source: .project)])
        XCTAssertEqual(shown.map { XPFeedbackStyle.title(for: $0).string }, ["✓ +2M XP", "✓ +40M XP"])
        XCTAssertNil(controller.current)
    }

    func testMultipleProjectPopupLocalizesAndBoundsMenuName() throws {
        let longName = String(repeating: "🎵 Album ", count: 10)
        let projects = [longName, "Website"].map {
            LinearCompletedProject(id: $0, name: $0, completedAt: now)
        }
        let (usage, companion, session) = try completionStores()
        AppDelegate.applyLinearCompletions([], projects: [], store: usage,
                                           companion: companion, sessionStore: session)
        AppDelegate.applyLinearCompletions([], projects: projects, store: usage,
                                           companion: companion, sessionStore: session)
        XCTAssertEqual(usage.currentSpeechBubble?.title, "2 projects complete!")
        XCTAssertEqual(usage.currentSpeechBubble?.body, longName)
        XCTAssertEqual(usage.menuLines, ["2 done", String(longName.prefix(24)) + "…"])
        for language in AppLanguage.allCases {
            let l = L(language)
            let single = try XCTUnwrap(UsageStore.linearCompletionFeedback(
                issues: [], projects: [projects[0]], l: l))
            let multiple = try XCTUnwrap(UsageStore.linearCompletionFeedback(
                issues: [], projects: projects, l: l))
            XCTAssertNotEqual(single.bubble.title, multiple.bubble.title)
            XCTAssertTrue(multiple.bubble.title.contains("2"))
            if language != .en {
                XCTAssertNotEqual(single.bubble.title, "Project complete!")
                XCTAssertNotEqual(l.linearMixedCompletedBubbleTitle(3), "3 completions!")
            }
        }
    }

    func testSessionFeedbackUsesCappedGrantThenMintAndStopsAtCap() throws {
        var state = CompanionState()
        state.timeOpenAwardDay = "today"
        state.timeOpenAwardedToday = TimeOpenXP.dailyCap - 123
        state.mintExpiresAt = now.addingTimeInterval(600)
        let store = try store(state: state)
        var rewards: [XPReward] = []
        store.onXPEarned = { rewards.append($0) }
        XCTAssertEqual(store.applyCappedProgressXP(1_000, today: "today"), 123)
        XCTAssertEqual(store.applyCappedProgressXP(1_000, today: "today"), 0)
        XCTAssertEqual(rewards, [XPReward(amount: 246, source: .focus)])
    }

    func testTimeOpenOnlyAnimatesWhenAnIntervalIsGranted() throws {
        var time = now
        let store = try store(clock: { time })
        var rewards: [XPReward] = []
        store.onXPEarned = { rewards.append($0) }
        store.awardTimeOpenXP(today: "today", enabled: true)
        time = time.addingTimeInterval(5)
        store.awardTimeOpenXP(today: "today", enabled: true)
        XCTAssertTrue(rewards.isEmpty)
        time = now.addingTimeInterval(TimeOpenXP.awardIntervalSeconds)
        store.awardTimeOpenXP(today: "today", enabled: true)
        store.awardTimeOpenXP(today: "today", enabled: true)
        XCTAssertEqual(rewards, [XPReward(amount: TimeOpenXP.tokensPerAward, source: .timeOpen)])
    }

    func testCandyReportsGrowthWithoutMintOrWalletCredit() async throws {
        var state = CompanionState()
        state.inventory[ItemKind.rareCandy.rawValue] = 1
        state.mintExpiresAt = now.addingTimeInterval(600)
        let line = EvoLine(baseID: 144, tree: EvoNode(speciesID: 144, children: []), rarity: .legendary, names: [:])
        let store = try store(state: state, provider: StubProvider(value: line))
        await store.hatch(baseID: 144)
        var rewards: [XPReward] = []
        store.onXPEarned = { rewards.append($0) }
        XCTAssertEqual(store.useRareCandy(), .progressed)
        XCTAssertEqual(store.useRareCandy(), .unavailable)
        XCTAssertEqual(rewards, [XPReward(amount: RareCandy.xp, source: .candy)])
        XCTAssertEqual(store.lifetimeXP, 0)
        XCTAssertEqual(store.state.active?.usedAtStage, RareCandy.xp)
    }

    func testBackgroundBatchPreservesEveryAwardAndPrioritizesCompletion() {
        var queue = XPFeedbackQueue()
        queue.append(XPReward(amount: 10, source: .tokens))
        XCTAssertEqual(queue.next(at: now, backgroundInterval: 30)?.amount, 10)
        for _ in 0..<100 { queue.append(XPReward(amount: 5, source: .focus)) }
        queue.append(XPReward(amount: 70, source: .tokens))
        queue.append(XPReward(amount: 0, source: .timeOpen))
        XCTAssertEqual(queue.pending.count, 2)
        XCTAssertNil(queue.next(at: now.addingTimeInterval(29), backgroundInterval: 30))
        queue.append(XPReward(amount: 1_000, source: .issue))
        queue.append(XPReward(amount: 2_000, source: .issue))
        XCTAssertEqual(queue.next(at: now.addingTimeInterval(29), backgroundInterval: 30),
                       XPReward(amount: 3_000, source: .issue))
        XCTAssertEqual(queue.next(at: now.addingTimeInterval(30), backgroundInterval: 30)?.amount, 570)
        XCTAssertTrue(queue.pending.isEmpty)
        XCTAssertNil(queue.next(at: now.addingTimeInterval(90), backgroundInterval: 30))
    }

    func testControllerFinishesReceiptsAndCancelsEverythingOnSleep() async throws {
        let controller = XPFeedbackController(duration: 0.03, backgroundInterval: 60)
        var shown: [XPReward] = []
        let first = expectation(description: "first receipt dismissed")
        controller.onChange = { reward in
            if let reward { shown.append(reward) }
            else { first.fulfill() }
        }
        controller.receive(XPReward(amount: 0, source: .tokens))
        XCTAssertNil(controller.current)
        controller.receive(XPReward(amount: 10, source: .tokens))
        await fulfillment(of: [first], timeout: 2)
        XCTAssertNil(controller.current)
        controller.onChange = { if let reward = $0 { shown.append(reward) } }
        controller.receive(XPReward(amount: 20, source: .tokens))
        XCTAssertNil(controller.current, "Background receipt is batched until the cooldown ends")
        controller.receive(XPReward(amount: 30, source: .issue))
        XCTAssertEqual(controller.current?.amount, 30, "Completion interrupts the background wait")
        controller.setDisplayAwake(false)
        controller.receive(XPReward(amount: 40, source: .issue))
        controller.setDisplayAwake(true)
        try await Task.sleep(for: .milliseconds(80))
        XCTAssertNil(controller.current)
        XCTAssertEqual(shown.map(\.amount), [10, 30], "No delayed or asleep receipts replay on wake")
        controller.receive(XPReward(amount: 50, source: .tokens))
        XCTAssertEqual(controller.current?.amount, 50)
        controller.setDisplayAwake(false)
    }

    func testControllerDrainsQueuedCompletionAndBackgroundTotal() async {
        let controller = XPFeedbackController(duration: 0.02, backgroundInterval: 0.08)
        var shown: [XPReward] = []
        let drained = expectation(description: "all receipts dismissed")
        controller.onChange = { reward in
            if let reward { shown.append(reward) }
            else if shown.count == 3 { drained.fulfill() }
        }
        controller.receive(XPReward(amount: 10, source: .tokens))
        controller.receive(XPReward(amount: 20, source: .focus))
        controller.receive(XPReward(amount: 30, source: .focus))
        controller.receive(XPReward(amount: 40, source: .issue))
        await fulfillment(of: [drained], timeout: 2)
        XCTAssertEqual(shown, [XPReward(amount: 10, source: .tokens),
                               XPReward(amount: 40, source: .issue),
                               XPReward(amount: 50, source: .focus)])
        XCTAssertNil(controller.current)
    }

    func testPetReceiptStaysOnScreenAndCannotTakeFocusOrClicks() {
        let screen = NSRect(x: -1440, y: 30, width: 1440, height: 870)
        for pet in [NSRect(x: -1440, y: 30, width: 40, height: 40),
                    NSRect(x: -50, y: 860, width: 40, height: 40)] {
            let frame = XPRewardPanel.anchoredFrame(size: NSSize(width: 140, height: 46), pet: pet, visibleScreen: screen)
            XCTAssertTrue(screen.contains(frame))
        }
        let panel = XPRewardPanel(reward: XPReward(amount: 1_000_000, source: .issue))
        defer { panel.close() }
        XCTAssertFalse(panel.canBecomeKey)
        XCTAssertFalse(panel.canBecomeMain)
        XCTAssertTrue(panel.ignoresMouseEvents)
        XCTAssertEqual(XPFeedbackStyle.title(for: XPReward(amount: 1_500_000, source: .issue)).string, "✓ +1.5M XP")
        XCTAssertEqual(XPFeedbackStyle.title(for: XPReward(amount: 15_000_000, source: .project)).string, "✓ +15M XP")
        let tokenReward = XPReward(amount: 1_234, source: .tokens)
        XCTAssertEqual(XPFeedbackStyle.title(for: tokenReward).string, "+1.2K XP")
        XCTAssertEqual(tokenReward.exactText, "+\(TokenFormatter.grouped(1_234)) XP")
    }

    func testGlowOnlyDrawsEdgesWithAnEmptyCentre() {
        let layer = CALayer()
        let bounds = CGRect(x: 0, y: 0, width: 1440, height: 900)
        XPBoundaryGlow.addEdges(to: layer, bounds: bounds, color: NSColor.systemTeal.cgColor)
        let edges = layer.sublayers?.compactMap { $0 as? CAGradientLayer } ?? []
        XCTAssertEqual(edges.count, 4)
        XCTAssertTrue(edges.allSatisfy { !$0.frame.contains(CGPoint(x: 720, y: 450)) })
        let border = layer.sublayers?.compactMap { $0 as? CAShapeLayer }.first
        XCTAssertNotNil(border)
        XCTAssertNil(border?.fillColor)
    }

    /// Native receipts in both appearances, isolated from the user's app and save.
    func testRenderFeedbackPreview() async throws {
        guard let path = ProcessInfo.processInfo.environment["PTB_XP_PREVIEW_DIR"] else {
            throw XCTSkip("Set PTB_XP_PREVIEW_DIR to render native feedback")
        }
        let directory = URL(fileURLWithPath: path)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        for (name, appearance) in [("light", NSAppearance.Name.aqua), ("dark", .darkAqua)] {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 560, height: 220),
                                  styleMask: .borderless, backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false
            window.appearance = NSAppearance(named: appearance)
            let host = NSView(frame: NSRect(x: 0, y: 0, width: 560, height: 220))
            host.wantsLayer = true
            window.contentView = host
            window.appearance?.performAsCurrentDrawingAppearance {
                host.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
                XPBoundaryGlow.addEdges(to: host.layer!, bounds: host.bounds, color: NSColor.systemTeal.cgColor)
            }
            var receipts: [XPRewardPanel] = []
            for (index, source) in [XPReward.Source.tokens, .issue, .candy].enumerated() {
                let reward = XPReward(amount: 1_500_000, source: source)
                let receipt = XPRewardPanel(reward: reward)
                receipt.appearance = window.appearance
                let content = try XCTUnwrap(receipt.contentView)
                content.frame.origin = NSPoint(x: 36 + index * 170, y: 50)
                for child in content.subviews {
                    child.layer?.removeAllAnimations()
                    child.layer?.opacity = 1
                    window.appearance?.performAsCurrentDrawingAppearance {
                        child.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
                        child.layer?.borderColor = XPFeedbackStyle.color(for: reward).withAlphaComponent(0.45).cgColor
                    }
                }
                host.addSubview(content)
                let menu = NSTextField(labelWithAttributedString: XPFeedbackStyle.title(for: reward))
                menu.sizeToFit()
                menu.frame.origin = NSPoint(x: 40 + index * 170, y: 156)
                host.addSubview(menu)
                receipts.append(receipt)
            }
            try await Task.sleep(for: .milliseconds(80))
            host.layoutSubtreeIfNeeded()
            let bitmap = try XCTUnwrap(host.bitmapImageRepForCachingDisplay(in: host.bounds))
            host.cacheDisplay(in: host.bounds, to: bitmap)
            try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
                .write(to: directory.appendingPathComponent("xp-feedback-\(name).png"))
            for receipt in receipts { receipt.contentView = nil; receipt.close() }
            window.contentView = nil
            window.close()
        }
    }
}
