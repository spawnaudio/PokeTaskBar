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
        let existing = Set(NSApp.windows.map(\.windowNumber))
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

    private func click(_ window: NSWindow, in view: NSView, x: CGFloat, top: CGFloat) async throws {
        let point = view.convert(NSPoint(x: x, y: view.isFlipped ? top : view.bounds.height - top), to: nil)
        for type in [NSEvent.EventType.leftMouseDown, .leftMouseUp] {
            window.sendEvent(try XCTUnwrap(NSEvent.mouseEvent(with: type, location: point,
                modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime,
                windowNumber: window.windowNumber, context: nil, eventNumber: 1, clickCount: 1, pressure: 1)))
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
            let issue: [String: Any] = ["id": "issue", "identifier": "PKT-142", "title": "Refine the main app window",
                "state": ["id": "started", "name": "In Progress", "type": "started"],
                "description": "Bring the approved dashboard and navigation to the native app.",
                "project": ["id": "project", "name": "PokeTasks"], "priority": 2, "team": team]
            let project: [String: Any] = ["id": "project", "name": "PokeTasks", "status": ["id": "started", "type": "started", "name": "In Progress"],
                "description": "A calmer place to focus on your work.", "issues": ["nodes": [issue]]]
            let planned: [String: Any] = ["id": "planned", "identifier": "PKT-143", "title": "Plan the next focus session",
                "state": ["id": "planned-state", "name": "Planned", "type": "unstarted"],
                "project": ["id": "project", "name": "PokeTasks"], "priority": 3, "team": team]
            let todo: [String: Any] = ["id": "todo", "identifier": "PKT-144", "title": "Choose the next small task",
                "state": ["id": "todo-state", "name": "Todo", "type": "unstarted"],
                "project": ["id": "project", "name": "PokeTasks"], "priority": 2, "team": team]
            return (200, try JSONSerialization.data(withJSONObject: ["data": [
                "projectStatuses": ["nodes": projectStatuses, "pageInfo": ["hasNextPage": false]],
                "inProgress": ["nodes": [issue]], "completedRecent": ["nodes": []], "planned": ["nodes": [planned]], "todo": ["nodes": [todo]],
                "project": ["issues": ["nodes": [issue, planned, todo], "pageInfo": ["hasNextPage": false]]],
                "projects": ["nodes": [project, ["id": "other-project", "name": "Weekly Planning",
                    "status": ["id": "planned", "type": "planned", "name": "Planned"], "issues": ["nodes": []]]]],
                "initiatives": ["nodes": [["id": "initiative", "name": "Fun Side Projects",
                    "status": "Active", "projects": ["nodes": [project]]],
                    ["id": "other-initiative", "name": "Studio Refresh", "status": "Active", "projects": ["nodes": []]]]],
                "teams": ["nodes": []]]]))
        }
    }
}
