import AppKit
import SwiftUI
import XCTest
@testable import PokeTaskBar

@MainActor
final class MenuBarOverhaulTests: XCTestCase {
    func testProgressFreezesWhilePausedAndClampsAtCompletion() throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        let focus = fixture.focus
        XCTAssertEqual(focus.plannedProgress, 0)
        focus.plannedMinutes = 50
        focus.startPomodoro()
        fixture.now = fixture.now.addingTimeInterval(25 * 60)
        XCTAssertEqual(focus.plannedProgress, 0.5, accuracy: 0.001)
        focus.togglePause()
        fixture.now = fixture.now.addingTimeInterval(10 * 60)
        XCTAssertEqual(focus.plannedProgress, 0.5, accuracy: 0.001)
        focus.togglePause()
        fixture.now = fixture.now.addingTimeInterval(25 * 60)
        focus.tick()
        XCTAssertEqual(focus.plannedProgress, 1)
        focus.continueOvertime()
        fixture.now = fixture.now.addingTimeInterval(10 * 60)
        focus.tick()
        XCTAssertEqual(focus.plannedProgress, 1)
        focus.finishLeavingInProgress()
        XCTAssertEqual(focus.plannedProgress, 0)
    }

    func testTextAndAccentContrastInBothAppearances() throws {
        for scheme in [ColorScheme.light, .dark] {
            let theme = MenuBarTheme(scheme: scheme)
            for background in [theme.shell, theme.canvas, theme.surface, theme.selected] {
                for foreground in [theme.text, theme.secondary, theme.accent] {
                    XCTAssertGreaterThanOrEqual(try contrast(foreground, background), 4.5,
                                                "Small text must remain readable in \(scheme)")
                }
            }
        }
    }

    func testHeaderFitsEveryLanguageAtMinimumWindowWidth() throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        for language in AppLanguage.allCases {
            fixture.companion.setLanguage(language)
            for detached in [false, true] {
                fixture.usage.menuBarPanelDetached = detached
                let host = NSHostingController(rootView: PopoverShellToolbar()
                    .environment(fixture.usage).environment(fixture.companion).environment(fixture.nav))
                let size = host.sizeThatFits(in: CGSize(width: 384, height: 100))
                XCTAssertLessThanOrEqual(size.width, 384, "\(language), detached=\(detached)")
                XCTAssertLessThanOrEqual(size.height, 100)
            }
        }
    }

    /// Opt-in native screenshots; sample state and credentials are isolated.
    /// PTB_MENU_BAR_PREVIEW_DIR=/tmp/previews swift test --filter MenuBarOverhaulTests
    func testRenderMenuBarStates() async throws {
        guard let path = ProcessInfo.processInfo.environment["PTB_MENU_BAR_PREVIEW_DIR"] else {
            throw XCTSkip("Set PTB_MENU_BAR_PREVIEW_DIR to render the real SwiftUI window")
        }
        let fixture = try Fixture()
        defer { fixture.remove() }
        let previousIcon = NSApplication.shared.applicationIconImage
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
        NSApplication.shared.applicationIconImage = NSImage(contentsOf: root.appendingPathComponent("assets/icon_1024.png"))
        defer { NSApplication.shared.applicationIconImage = previousIcon }
        let directory = URL(fileURLWithPath: path)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        fixture.companion.update(todayTokensByProvider: [:], todayDate: "2026-09-18",
                                 monthTotal: 0, burnTier: .idle, limitWarning: false, hasUsageData: false)
        // Let the injected local provider populate the companion's names.
        await Task.yield()
        fixture.focus.pin(Self.issue, openDesk: false, minutes: fixture.focus.plannedMinutes)
        fixture.now = fixture.now.addingTimeInterval(25 * 60 + 42)
        fixture.focus.tick()
        for scheme in [ColorScheme.dark, .light] {
            try await render(fixture, scheme: scheme, name: "focus-\(scheme)", directory: directory)
        }
        fixture.focus.togglePause()
        try await render(fixture, scheme: .light, name: "paused-light", directory: directory)
        fixture.focus.togglePause()
        fixture.now = fixture.now.addingTimeInterval(24 * 60 + 18)
        fixture.focus.tick()
        try await render(fixture, scheme: .dark, name: "timer-ended-dark", directory: directory)
        fixture.focus.continueOvertime()
        fixture.now = fixture.now.addingTimeInterval(2 * 60)
        fixture.focus.tick()
        try await render(fixture, scheme: .light, name: "overtime-light", directory: directory)
        fixture.focus.finishLeavingInProgress()
        try await render(fixture, scheme: .light, name: "idle-light", directory: directory)
        fixture.focus.startPomodoro()
        try await render(fixture, scheme: .dark, name: "pomodoro-small-dark", height: 520, directory: directory)
        for tab in [PopoverTab.linear, .usage, .collection] {
            fixture.nav.tab = tab
            try await render(fixture, scheme: .light, name: "\(tab)-light", directory: directory)
        }
        fixture.nav.showSettings = true
        try await render(fixture, scheme: .light, name: "settings-light", directory: directory)
        fixture.nav.showSettings = false
        fixture.nav.tab = .focus
        fixture.usage.menuBarPanelDetached = true
        try await render(fixture, scheme: .light, name: "detached-light", directory: directory)
    }

    private func render(_ fixture: Fixture, scheme: ColorScheme, name: String,
                        height: CGFloat = 640, directory: URL) async throws {
        let root = PopoverView()
            .environment(fixture.usage).environment(fixture.companion)
            .environment(fixture.focus).environment(fixture.nav).environment(UpdateChecker())
            .environment(\.colorScheme, scheme)
            .frame(width: 400, height: height)
        let host = NSHostingView(rootView: root)
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 400, height: height),
                              styleMask: .borderless, backing: .buffered, defer: false)
        window.appearance = NSAppearance(named: scheme == .dark ? .darkAqua : .aqua)
        window.contentView = host
        host.frame = NSRect(x: 0, y: 0, width: 400, height: height)
        defer { window.contentView = nil }
        try await Task.sleep(for: .milliseconds(100))
        host.layoutSubtreeIfNeeded()
        XCTAssertEqual(host.bounds.width, 400)
        XCTAssertEqual(host.bounds.height, height)
        let bitmap = try XCTUnwrap(host.bitmapImageRepForCachingDisplay(in: host.bounds))
        host.cacheDisplay(in: host.bounds, to: bitmap)
        try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
            .write(to: directory.appendingPathComponent("\(name).png"))
    }

    private func contrast(_ first: Color, _ second: Color) throws -> Double {
        func luminance(_ color: Color) throws -> Double {
            let rgb = try XCTUnwrap(NSColor(color).usingColorSpace(.sRGB))
            func linear(_ value: Double) -> Double {
                value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
            }
            return 0.2126 * linear(rgb.redComponent) + 0.7152 * linear(rgb.greenComponent)
                + 0.0722 * linear(rgb.blueComponent)
        }
        let a = try luminance(first), b = try luminance(second)
        return (max(a, b) + 0.05) / (min(a, b) + 0.05)
    }

    private static let issue = LinearIssueSummary(
        id: "preview-issue", identifier: "PKT-142", title: "Refine the menu bar experience",
        issueURL: URL(string: "https://linear.app"), priority: 2, estimate: nil,
        stateId: "started", stateName: "In Progress", stateType: "started",
        assigneeName: nil, assigneeEmail: nil, projectName: "PokeTaskBar", teamName: "PokeTaskBar",
        teamKey: "PKT", teamID: "preview-team", teamStates: [
            LinearWorkflowState(id: "started", name: "In Progress", type: "started", position: 1),
            LinearWorkflowState(id: "done", name: "Done", type: "completed", position: 2)
        ], completedStateId: "done", labelNames: [], createdAt: nil, updatedAt: nil,
        dueDate: nil, completedAt: nil, descriptionText: nil)

    @MainActor
    private final class Fixture {
        let directory: URL
        let suite = "MenuBarOverhaulTests-\(UUID().uuidString)"
        let defaults: UserDefaults
        let companion: CompanionStore
        let usage: UsageStore
        let nav = PopoverNavigation()
        var now = Date(timeIntervalSince1970: 1_700_000_000)
        lazy var focus = FocusSessionStore(usage: usage, companion: companion, clock: { [unowned self] in self.now },
                                          fileURL: directory.appendingPathComponent("focus.json"), ticksOnTimer: false)

        init() throws {
            directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
            defaults.set(1.0, forKey: "growthDifficulty")
            var state = CompanionState()
            state.language = .en
            state.active = MonState(baseID: 131, pathIDs: [131], stageIndex: 0,
                                    usedAtStage: 2_000_000, rarity: .rare, totalForms: 1, nature: .calm)
            state.usedSinceInstall = 12_600_000
            let file = directory.appendingPathComponent("companion.json")
            try JSONEncoder().encode(state).write(to: file)
            companion = CompanionStore(provider: StubProvider(value: EvoLine(
                baseID: 131, tree: EvoNode(speciesID: 131, children: []), rarity: .rare,
                names: [131: ["en": "Lapras"]])), fileURL: file, defaults: defaults)
            usage = UsageStore(providers: [], autoRefresh: false, defaults: defaults,
                               linearAPIKeys: LinearAPIKeyStore(fileURL: directory.appendingPathComponent("key.json")))
        }

        func remove() {
            defaults.removePersistentDomain(forName: suite)
            try? FileManager.default.removeItem(at: directory)
        }
    }
}
