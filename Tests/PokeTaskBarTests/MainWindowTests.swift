import AppKit
import SwiftUI
import XCTest
@testable import PokeTaskBar

@MainActor
final class MainWindowTests: XCTestCase {
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
        func settle() async throws { try await Task.sleep(for: .milliseconds(180)); host.layoutSubtreeIfNeeded() }
        func event(_ type: NSEvent.EventType, x: CGFloat, top: CGFloat) throws {
            let point = host.convert(NSPoint(x: x, y: host.isFlipped ? top : host.bounds.height - top), to: nil)
            window.sendEvent(try XCTUnwrap(NSEvent.mouseEvent(with: type, location: point,
                modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime,
                windowNumber: window.windowNumber, context: nil, eventNumber: 1, clickCount: 1, pressure: 1)))
        }
        func click(x: CGFloat, top: CGFloat) async throws {
            try event(.leftMouseDown, x: x, top: top); try event(.leftMouseUp, x: x, top: top)
            try await settle()
        }
        try await settle()
        try await click(x: 100, top: 341)
        XCTAssertEqual(fixture.nav.page, .projects, "The native navigation row must route the main window")
        try await click(x: 1245, top: 24)
        XCTAssertTrue(fixture.usage.todayDeskLayout.rightCollapsed)
        try event(.leftMouseDown, x: 230, top: 450)
        try event(.leftMouseDragged, x: 278, top: 450)
        try event(.leftMouseUp, x: 278, top: 450)
        try await settle()
        XCTAssertGreaterThan(fixture.usage.todayDeskLayout.leftWidth, TodayDeskMetrics.leftSidebarWidth)
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

    @MainActor private final class Fixture {
        let directory: URL
        let suite = "MainWindowTests-\(UUID().uuidString)"
        let defaults: UserDefaults
        let companion: CompanionStore
        let usage: UsageStore
        let nav = MainWindowNavigation()
        lazy var focus = FocusSessionStore(usage: usage, companion: companion,
            clock: { Date(timeIntervalSince1970: 1_789_740_000) },
            fileURL: directory.appendingPathComponent("focus.json"), ticksOnTimer: false)
        init() throws {
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
                               linearClient: LinearClient(http: PreviewHTTP()), linearAPIKeys: keys)
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
        func postGraphQL(apiKey: String, body: Data) async throws -> (status: Int, data: Data) {
            let issue: [String: Any] = ["id": "issue", "identifier": "PKT-142", "title": "Refine the main app window",
                "state": ["id": "started", "name": "In Progress", "type": "started"],
                "description": "Bring the approved dashboard and navigation to the native app.",
                "project": ["id": "project", "name": "PokeTasks"], "priority": 2]
            let project: [String: Any] = ["id": "project", "name": "PokeTasks", "status": ["type": "started", "name": "In Progress"],
                "description": "A calmer place to focus on your work.", "issues": ["nodes": [issue]]]
            return (200, try JSONSerialization.data(withJSONObject: ["data": [
                "inProgress": ["nodes": [issue]], "completedRecent": ["nodes": []],
                "projects": ["nodes": [project]], "initiatives": ["nodes": [["id": "initiative", "name": "Fun Side Projects",
                "status": "Active", "projects": ["nodes": [project]]]]], "teams": ["nodes": []]]]))
        }
    }
}
