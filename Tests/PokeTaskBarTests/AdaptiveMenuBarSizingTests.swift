import AppKit
import SwiftUI
import XCTest
@testable import PokeTaskBar

@MainActor
final class AdaptiveMenuBarSizingTests: XCTestCase {
    func testNaturalHeightDoesNotDependOnExistingViewportHeight() {
        let id = UUID()
        for viewport: CGFloat in [100, 300, 500] {
            let measurement = MenuBarContentMeasurements(
                heights: [.toolbar: 86, .canvas: viewport + 28, .footer: 32],
                scrollAdjustments: [id: 220 - viewport])
            XCTAssertEqual(measurement.preferredHeight, 374)
        }
        XCTAssertNil(MenuBarContentMeasurements(heights: [.toolbar: 86, .canvas: 200],
                                               pendingScrolls: [id]).preferredHeight)
    }

    func testFittingPreservesAnchorAndWidthAndCapsToUsableScreen() {
        let screen = NSRect(x: 0, y: 50, width: 1440, height: 850)
        let button = NSRect(x: 900, y: 900, width: 40, height: 24)
        var current = NSRect(x: 720, y: 254, width: 400, height: 640)
        for wanted: CGFloat in [290, 640, 337, 1000, 462] {
            let fitted = MenuBarPanelMetrics.contentFittedFrame(
                current: current, preferredHeight: wanted, button: button, screen: screen)
            XCTAssertEqual(fitted.width, 400)
            XCTAssertEqual(fitted.maxY, 894)
            XCTAssertEqual(fitted.midX, button.midX)
            XCTAssertEqual(fitted.height, min(wanted, 660))
            current = fitted
        }
        let tiny = MenuBarPanelMetrics.contentFittedFrame(
            current: current, preferredHeight: 900,
            button: NSRect(x: 1380, y: 420, width: 30, height: 22),
            screen: NSRect(x: 0, y: 50, width: 1440, height: 370))
        XCTAssertEqual(tiny.minY, 50)
        XCTAssertEqual(tiny.maxY, 414)
        XCTAssertEqual(tiny.maxX, 1440)
        XCTAssertEqual(MenuBarPanelMetrics.clampedContentSize(
            NSSize(width: 900, height: 900), detached: true), NSSize(width: 900, height: 900))
    }

    func testNativePagesFitAndLongPagesRemainScrollable() async throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        let probe = Probe(fixture)
        defer { probe.close() }
        fixture.nav.tab = .linear
        try await probe.settle()
        let linear = try XCTUnwrap(probe.preferredHeight)
        XCTAssertLessThan(linear, 400, "Setup state must not retain the old 520/640pt floor")
        try probe.capture("linear")

        fixture.nav.tab = .usage
        try await probe.settle()
        let usage = try XCTUnwrap(probe.preferredHeight)
        XCTAssertGreaterThan(usage, linear)
        XCTAssertLessThan(usage, 520)
        try probe.capture("usage")

        fixture.nav.tab = .collection
        for segment in CollectionSegment.allCases {
            fixture.nav.collectionSegment = segment
            try await probe.settle()
            let measured = try XCTUnwrap(probe.preferredHeight)
            if segment == .shop {
                XCTAssertGreaterThan(measured, 660)
                XCTAssertEqual(probe.window.frame.height, 660)
            } else {
                XCTAssertLessThan(measured, 520, "Small/empty collection pages should fit: \(segment)")
            }
            try probe.capture("collection-\(segment)")
        }
        fixture.nav.collectionSegment = .dex
        fixture.nav.showingCollectionLog = true
        try await probe.settle()
        XCTAssertLessThan(try XCTUnwrap(probe.preferredHeight), 520)
        try probe.capture("catch-log")

        fixture.nav.showSettings = true
        try await probe.settle()
        XCTAssertGreaterThan(try XCTUnwrap(probe.preferredHeight), 660)
        XCTAssertEqual(probe.window.frame.height, 660)
        try probe.capture("settings")

        fixture.nav.showSettings = false
        fixture.nav.tab = .linear
        try await probe.settle()
        XCTAssertEqual(try XCTUnwrap(probe.preferredHeight), linear, accuracy: 1,
                       "Returning from a capped page must shrink without height drift")
    }

    func testNativeFocusRespondsToSessionContentWithoutTimerResizeLoop() async throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        let probe = Probe(fixture)
        defer { probe.close() }
        try await probe.settle()
        let idle = try XCTUnwrap(probe.preferredHeight)
        try probe.capture("focus-idle")
        fixture.focus.startPomodoro()
        try await probe.settle()
        let running = try XCTUnwrap(probe.preferredHeight)
        XCTAssertGreaterThan(running, idle + 80)
        try probe.capture("focus-running")
        fixture.now = fixture.now.addingTimeInterval(1)
        fixture.focus.tick()
        try await probe.settle()
        XCTAssertEqual(try XCTUnwrap(probe.preferredHeight), running, accuracy: 1)
        fixture.focus.togglePause()
        try await probe.settle()
        XCTAssertEqual(try XCTUnwrap(probe.preferredHeight), running, accuracy: 1)
        fixture.focus.finishLeavingInProgress()
        try await probe.settle()
        XCTAssertEqual(try XCTUnwrap(probe.preferredHeight), idle, accuracy: 1)

        fixture.usage.menuBarPanelDetached = true
        try await probe.settle(fit: false)
        probe.window.setContentSize(NSSize(width: 700, height: 800))
        fixture.nav.tab = .linear
        try await probe.settle(fit: false)
        XCTAssertEqual(probe.window.frame.height, 800, "Detached windows keep manual sizing")
    }

    func testNativeLanguageAndWidthChangesRecomputeHeight() async throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        fixture.nav.tab = .linear
        let probe = Probe(fixture)
        defer { probe.close() }
        for language in AppLanguage.allCases {
            fixture.companion.setLanguage(language)
            for width: CGFloat in [400, 500] {
                probe.window.setContentSize(NSSize(width: width, height: 640))
                try await probe.settle()
                XCTAssertGreaterThan(try XCTUnwrap(probe.preferredHeight), 180)
                XCTAssertLessThan(try XCTUnwrap(probe.preferredHeight), 440, "\(language) at \(width)")
                XCTAssertEqual(probe.window.frame.width, width)
            }
        }
    }

    func testPopulatedLinearAndLargeLazyCollectionsUseTheSameSizingPath() async throws {
        for count in [0, 1, 30] {
            let fixture = try Fixture(issueCount: count, dexCount: count)
            defer { fixture.remove() }
            _ = await fixture.usage.refreshLinearIssues()
            XCTAssertEqual(fixture.usage.linearInProgressIssues.count, count)
            fixture.nav.tab = .linear
            let probe = Probe(fixture)
            defer { probe.close() }
            try await probe.settle()
            if count == 30 { XCTAssertEqual(probe.window.frame.height, 660) }
            else { XCTAssertLessThan(probe.window.frame.height, 600) }
            try probe.capture("linear-\(count)-issues")
            fixture.nav.tab = .collection
            try await probe.settle()
            if count == 30 { XCTAssertEqual(probe.window.frame.height, 660) }
            else { XCTAssertLessThan(probe.window.frame.height, 520) }
            fixture.nav.showingCollectionLog = true
            try await probe.settle()
            if count == 30 { XCTAssertEqual(probe.window.frame.height, 660) }
            else { XCTAssertLessThan(probe.window.frame.height, 600) }
        }
    }

    func testRealWindowControllerResizesAndKeepsDetachedSize() async throws {
        try XCTSkipIf(NSScreen.screens.isEmpty, "Requires access to the macOS display server")
        let fixture = try Fixture()
        defer { fixture.remove() }
        fixture.nav.tab = .linear
        let controller = MenuBarPanelController(usage: fixture.usage, companion: fixture.companion,
            session: fixture.focus, updater: UpdateChecker(), navigation: fixture.nav)
        controller.present(from: nil, resetNavigation: false)
        defer { controller.close() }
        let window = try XCTUnwrap(NSApplication.shared.windows.first {
            $0.identifier?.rawValue == LaunchWindowPolicy.menuBarPanelIdentifier && $0.isVisible
        })
        try await settleController(window)
        XCTAssertLessThan(window.frame.height, 400)
        let top = window.frame.maxY
        fixture.nav.tab = .usage
        try await settleController(window)
        XCTAssertGreaterThan(window.frame.height, 400)
        XCTAssertLessThan(window.frame.height, 520)
        XCTAssertEqual(window.frame.maxY, top, accuracy: 1)
        let fitted = window.frame.height
        window.setContentSize(NSSize(width: 400, height: 640))
        controller.windowDidEndLiveResize(Notification(name: NSWindow.didEndLiveResizeNotification, object: window))
        XCTAssertEqual(window.frame.height, fitted, accuracy: 1)
        fixture.usage.menuBarPanelDetached = true
        try await Task.sleep(for: .milliseconds(100))
        window.setContentSize(NSSize(width: 700, height: 800))
        fixture.nav.tab = .linear
        try await settleController(window)
        XCTAssertEqual(window.contentRect(forFrameRect: window.frame).height, 800, accuracy: 1)
        fixture.usage.menuBarPanelDetached = false
        try await settleController(window)
        XCTAssertLessThan(window.frame.height, 400)
        // A queued measurement must not reopen a panel after it has been closed.
        fixture.nav.tab = .usage
        controller.close()
        try await Task.sleep(for: .milliseconds(100))
        XCTAssertFalse(controller.isShown)
    }

    private func settleController(_ window: NSWindow) async throws {
        for _ in 0..<24 {
            window.contentView?.layoutSubtreeIfNeeded()
            try await Task.sleep(for: .milliseconds(30))
        }
    }

    @MainActor
    private final class Probe {
        let window: NSWindow
        var preferredHeight: CGFloat?
        var measurements = 0

        init(_ fixture: Fixture) {
            window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 400, height: 640),
                              styleMask: .borderless, backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false
            window.appearance = NSAppearance(named: .aqua)
            let root = PopoverView(onPreferredHeightChange: { [weak self] height in
                self?.preferredHeight = height
                self?.measurements += 1
            })
                .environment(fixture.usage).environment(fixture.companion)
                .environment(fixture.focus).environment(fixture.nav).environment(UpdateChecker())
                .environment(\.colorScheme, .light)
            window.contentView = NSHostingView(rootView: root)
        }

        func settle(fit: Bool = true) async throws {
            let initialMeasurements = measurements
            for _ in 0..<8 {
                window.contentView?.layoutSubtreeIfNeeded()
                try await Task.sleep(for: .milliseconds(30))
                if fit, let preferredHeight {
                    let target = MenuBarPanelMetrics.contentFittedFrame(
                        current: window.frame, preferredHeight: preferredHeight, button: nil,
                        screen: NSRect(x: 0, y: -2000, width: 3000, height: 4000))
                    if abs(target.height - window.frame.height) >= 1 { window.setFrame(target, display: true) }
                }
            }
            XCTAssertLessThan(measurements - initialMeasurements, 30, "Layout must settle instead of oscillating")
        }

        func capture(_ name: String) throws {
            guard let path = ProcessInfo.processInfo.environment["PTB_ADAPTIVE_PREVIEW_DIR"],
                  let host = window.contentView else { return }
            let directory = URL(fileURLWithPath: path)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let rep = try XCTUnwrap(host.bitmapImageRepForCachingDisplay(in: host.bounds))
            host.cacheDisplay(in: host.bounds, to: rep)
            try XCTUnwrap(rep.representation(using: .png, properties: [:]))
                .write(to: directory.appendingPathComponent("\(name).png"))
        }

        func close() { window.contentView = nil; window.close() }
    }

    @MainActor
    private final class Fixture {
        let directory: URL
        let suite = "AdaptiveMenuBarSizingTests-\(UUID().uuidString)"
        let defaults: UserDefaults
        let companion: CompanionStore
        let usage: UsageStore
        let nav = PopoverNavigation()
        var now = Date(timeIntervalSince1970: 1_700_000_000)
        lazy var focus = FocusSessionStore(usage: usage, companion: companion, clock: { [unowned self] in self.now },
                                          fileURL: directory.appendingPathComponent("focus.json"), ticksOnTimer: false)

        init(issueCount: Int? = nil, dexCount: Int = 0) throws {
            _ = NSApplication.shared
            directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
            defaults.set(1.0, forKey: "growthDifficulty")
            var state = CompanionState()
            state.language = .en
            state.active = MonState(baseID: 131, pathIDs: [131], stageIndex: 0,
                                    usedAtStage: 2_000_000, rarity: .rare, totalForms: 1, nature: .calm)
            state.usedSinceInstall = 12_600_000
            state.dex = (0..<dexCount).map { index in
                DexEntry(baseID: index + 1, finalID: index + 1, chainOrder: [index + 1], rarity: .common,
                         caughtAt: Date(timeIntervalSince1970: 1_700_000_000),
                         names: [index + 1: ["en": "Sample \(index + 1)"]])
            }
            let file = directory.appendingPathComponent("companion.json")
            try JSONEncoder().encode(state).write(to: file)
            companion = CompanionStore(provider: StubProvider(value: EvoLine(
                baseID: 131, tree: EvoNode(speciesID: 131, children: []), rarity: .rare,
                names: [131: ["en": "Lapras"]])), fileURL: file, defaults: defaults)
            let keys = LinearAPIKeyStore(fileURL: directory.appendingPathComponent("key.json"))
            if issueCount != nil { try keys.save(.init(key: "lin_api_" + String(repeating: "x", count: 40))) }
            usage = UsageStore(providers: [], autoRefresh: false, defaults: defaults,
                               linearClient: LinearClient(http: SampleLinearHTTP(count: issueCount ?? 0)),
                               linearAPIKeys: keys)
            usage.linearIntegrationEnabled = issueCount != nil
            companion.update(todayTokensByProvider: [:], todayDate: "2026-09-18",
                             monthTotal: 0, burnTier: .idle, limitWarning: false, hasUsageData: false)
        }

        func remove() {
            defaults.removePersistentDomain(forName: suite)
            try? FileManager.default.removeItem(at: directory)
        }
    }

    private struct SampleLinearHTTP: LinearHTTPClient {
        let count: Int
        func postGraphQL(apiKey: String, body: Data) async throws -> (status: Int, data: Data) {
            let nodes: [[String: Any]] = (0..<count).map { index in
                ["id": "sample-\(index)", "identifier": "SAMPLE-\(index)", "title": "Sample issue \(index)",
                 "state": ["id": "started", "name": "In Progress", "type": "started"]]
            }
            let data = try JSONSerialization.data(withJSONObject: ["data": [
                "completedRecent": ["nodes": []], "inProgress": ["nodes": nodes],
                "projects": ["nodes": []], "initiatives": ["nodes": []]]])
            return (200, data)
        }
    }
}
