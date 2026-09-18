import AppKit
import XCTest
@testable import PokeTaskBar

final class MenuBarPanelTests: XCTestCase {
    func testDefaultIsCompactAndMaxStaysBelowToday() {
        XCTAssertEqual(PopoverMetrics.width, 360, "compact layout tests keep 360")
        XCTAssertEqual(MenuBarPanelMetrics.minWidth, 400)
        XCTAssertEqual(MenuBarPanelMetrics.defaultWidth, 400)
        XCTAssertEqual(MenuBarPanelMetrics.attachedMaxWidth, 500)
        XCTAssertLessThan(MenuBarPanelMetrics.attachedMaxWidth, TodayDeskMetrics.defaultWidth)
        XCTAssertLessThan(MenuBarPanelMetrics.attachedMaxHeight, TodayDeskMetrics.defaultHeight)
        XCTAssertEqual(MenuBarPanelMetrics.minHeight, 240, "attached panel hugs short tabs instead of a 520pt floor")
        XCTAssertEqual(MenuBarPanelMetrics.shellGap, 8)
        XCTAssertGreaterThan(MenuBarPanelMetrics.detachedMaxWidth, MenuBarPanelMetrics.attachedMaxWidth)
    }

    func testIdentifiersAreNotSettingsPlaceholders() {
        XCTAssertEqual(LaunchWindowPolicy.menuBarPanelIdentifier, "PokeTaskBar.MenuBarPanel")
        XCTAssertEqual(LaunchWindowPolicy.menuBarPanelAutosaveName, "PokeTaskBarMenuBarPanel")
        XCTAssertFalse(LaunchWindowPolicy.isSwiftUISettingsPlaceholder(
            identifier: LaunchWindowPolicy.menuBarPanelIdentifier,
            autosaveName: LaunchWindowPolicy.menuBarPanelAutosaveName))
    }

    @MainActor
    func testConfigureAttachedLocksUnderMenuBar() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 640),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: true)
        MenuBarPanelMetrics.configure(window, detached: false)
        XCTAssertFalse(window.isMovable)
        XCTAssertFalse(window.isMovableByWindowBackground)
        XCTAssertFalse(window.hidesOnDeactivate)
        XCTAssertTrue(window.styleMask.contains(.borderless))
        XCTAssertFalse(window.styleMask.contains(.titled))
        XCTAssertTrue(window.styleMask.contains(.resizable))
        XCTAssertEqual(window.contentMinSize.width, 400)
        XCTAssertEqual(window.contentMaxSize.width, 500)
        XCTAssertFalse(window.isOpaque)
        XCTAssertEqual(window.backgroundColor, NSColor.clear)
        XCTAssertEqual(window.contentView?.layer?.cornerRadius, 12)
    }

    @MainActor
    func testConfigureDetachedIsMovableTitledWindow() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 640),
            styleMask: [.borderless],
            backing: .buffered,
            defer: true)
        MenuBarPanelMetrics.configure(window, detached: true)
        XCTAssertTrue(window.isMovable)
        XCTAssertTrue(window.styleMask.contains(.titled))
        XCTAssertTrue(window.styleMask.contains(.closable))
        XCTAssertTrue(window.styleMask.contains(.resizable))
        XCTAssertTrue(window.styleMask.contains(.fullSizeContentView))
        XCTAssertTrue(window.titlebarAppearsTransparent)
        XCTAssertEqual(window.titleVisibility, .hidden)
        XCTAssertGreaterThan(window.contentMaxSize.width, MenuBarPanelMetrics.attachedMaxWidth)
    }

    func testOnlyTheButtonDetachesFromTheMenuBar() {
        XCTAssertTrue(MenuBarPanelMetrics.shouldPlaceBelowStatusItem(detached: false))
        XCTAssertFalse(MenuBarPanelMetrics.shouldPlaceBelowStatusItem(detached: true))
    }

    func testClampedContentSizePinsToMinAndMax() {
        XCTAssertEqual(
            MenuBarPanelMetrics.clampedContentSize(NSSize(width: 200, height: 100), detached: false),
            NSSize(width: 400, height: 240))
        XCTAssertEqual(
            MenuBarPanelMetrics.clampedContentSize(NSSize(width: 200, height: 100), detached: true),
            NSSize(width: 400, height: 400))
        XCTAssertEqual(
            MenuBarPanelMetrics.clampedContentSize(NSSize(width: 900, height: 900), detached: false),
            NSSize(width: 500, height: 660))
        XCTAssertEqual(
            MenuBarPanelMetrics.clampedContentSize(NSSize(width: 900, height: 900), detached: true),
            NSSize(width: 900, height: 900))
        XCTAssertEqual(
            MenuBarPanelMetrics.clampedContentSize(NSSize(width: 500, height: 600), detached: false),
            NSSize(width: 500, height: 600))
        XCTAssertEqual(MenuBarPanelMetrics.maxWidth(detached: false), 500)
        XCTAssertEqual(MenuBarPanelMetrics.maxWidth(detached: true), 2400)
    }

    func testFrameBelowStatusItemCentersAndClampsToScreen() {
        let button = NSRect(x: 620, y: 800, width: 40, height: 22)
        let screen = NSRect(x: 0, y: 0, width: 1280, height: 800)
        let size = NSSize(width: 360, height: 640)
        let frame = MenuBarPanelMetrics.frame(below: button, size: size, visibleScreen: screen)
        XCTAssertEqual(frame.width, 360)
        XCTAssertEqual(frame.height, 640)
        XCTAssertEqual(frame.midX, button.midX, accuracy: 0.5)
        XCTAssertEqual(frame.maxY, button.minY - MenuBarPanelMetrics.statusItemGap, accuracy: 0.5)

        let tight = NSRect(x: 0, y: 0, width: 300, height: 400)
        let clamped = MenuBarPanelMetrics.frame(
            below: NSRect(x: 0, y: 400, width: 20, height: 22),
            size: NSSize(width: 360, height: 640),
            visibleScreen: tight)
        XCTAssertEqual(clamped.width, 300)
        XCTAssertEqual(clamped.height, 400)
        XCTAssertGreaterThanOrEqual(clamped.minX, tight.minX)
        XCTAssertLessThanOrEqual(clamped.maxX, tight.maxX)
        XCTAssertGreaterThanOrEqual(clamped.minY, tight.minY)
        XCTAssertLessThanOrEqual(clamped.maxY, tight.maxY)
    }

    @MainActor
    func testBackLeavesNonFocusTabsAndSettings() {
        let nav = PopoverNavigation()
        XCTAssertFalse(nav.canGoBack)
        nav.tab = .linear
        XCTAssertTrue(nav.canGoBack)
        nav.goBack()
        XCTAssertEqual(nav.tab, .focus)
        XCTAssertFalse(nav.canGoBack)

        nav.tab = .collection
        nav.showSettings = true
        XCTAssertTrue(nav.canGoBack)
        nav.goBack()
        XCTAssertFalse(nav.showSettings)
        XCTAssertEqual(nav.tab, .collection)
        nav.goBack()
        XCTAssertEqual(nav.tab, .focus)
    }

    func testPopoverShellUsesInsetContentPanel() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/PokeTaskBar/UI")
        let popover = try String(
            contentsOf: root.appendingPathComponent("PopoverView.swift"), encoding: .utf8)
        let chrome = try String(
            contentsOf: root.appendingPathComponent("PopoverChrome.swift"), encoding: .utf8)
        XCTAssertTrue(popover.contains("PopoverShellToolbar"))
        XCTAssertTrue(popover.contains("canvasFill"))
        XCTAssertTrue(popover.contains("shellFill"))
        XCTAssertTrue(popover.contains("attachedCornerRadius"))
        XCTAssertTrue(popover.contains("shellGap"))
        XCTAssertTrue(chrome.contains("struct PopoverShellToolbar"))
        XCTAssertTrue(chrome.contains("chevron.left"))
        XCTAssertTrue(chrome.contains("ViewThatFits"))
        XCTAssertTrue(popover.contains("ignoresSafeArea"))
        XCTAssertTrue(popover.contains("fixedSize(horizontal: false, vertical: !detached)"))
        XCTAssertTrue(popover.contains("padding(.bottom, gap)"))
        XCTAssertTrue(popover.contains("padding(.trailing, gap)"))
        let panel = try String(
            contentsOf: root.appendingPathComponent("MenuBarPanel.swift"), encoding: .utf8)
        XCTAssertTrue(panel.contains("sizingOptions"))
        XCTAssertTrue(panel.contains("hugAttachedContent") || panel.contains("preferredContentSize"))
    }

    func testShellBottomInsetStaysOutsideScrollingContent() throws {
        XCTAssertEqual(MenuBarPanelMetrics.shellGap, 8)
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/PokeTaskBar/UI")
        let popover = try String(
            contentsOf: root.appendingPathComponent("PopoverView.swift"), encoding: .utf8)
        let companion = try String(
            contentsOf: root.appendingPathComponent("CompanionView.swift"), encoding: .utf8)
        let usage = try String(
            contentsOf: root.appendingPathComponent("UsageTabView.swift"), encoding: .utf8)
        XCTAssertTrue(popover.contains("let panelHeight = min(geo.size.height"))
        XCTAssertTrue(popover.contains("padding(.bottom, gap)"))
        XCTAssertTrue(popover.contains("padding(.trailing, gap)"))
        XCTAssertFalse(
            companion.contains("contentHeight: CGFloat = 520"),
            "a 520pt Collection minHeight pushes the shell inset off the window")
        XCTAssertFalse(companion.contains("minHeight: Self.contentHeight"))
        XCTAssertFalse(
            usage.contains("minHeight: 420"),
            "Usage must not force a content floor that eats the bottom inset")
    }

    func testStatusItemPillDrawsCapsuleHairline() {
        XCTAssertEqual(MenuBarStatusItemChrome.borderWidth, 1)
        XCTAssertEqual(MenuBarLinearCountGlyph.inProgressSymbol, "circle.fill")
        XCTAssertEqual(MenuBarLinearCountGlyph.completedSymbol, "checkmark.circle.fill")
        XCTAssertEqual(MenuBarLinearCountGlyph.inProgressColor, NSColor.systemYellow)
        XCTAssertEqual(MenuBarLinearCountGlyph.completedColor, NSColor.systemBlue)
    }

    func testFocusTabKeepsPomodoroUsageAndTimeXPSeparate() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/PokeTaskBar/UI")
        let focus = try String(contentsOf: root.appendingPathComponent("FocusTabView.swift"), encoding: .utf8)
        XCTAssertTrue(focus.contains("focusSessionSection"))
        XCTAssertTrue(focus.contains("idleFocusPrompt"))
        XCTAssertTrue(focus.contains("TimeXPView"))
        XCTAssertTrue(focus.contains("session.openPomodoroSetup()"))
        XCTAssertTrue(focus.contains("l.pomoTimer"))
        XCTAssertTrue(focus.contains("l.focusIssueOrTimerPrompt"))
        XCTAssertTrue(focus.contains("l.openLinearTab"))
        XCTAssertTrue(focus.contains("l.todayDeskMenuOpen"))
        XCTAssertFalse(focus.contains("pomodoroSection"))
        XCTAssertFalse(focus.contains("idleLinearPrompt"))
        XCTAssertFalse(focus.contains("l.focusIdlePrompt"))
        XCTAssertFalse(focus.contains("l.pomodoroTitle"))
        XCTAssertTrue(focus.contains("CompanionHeader(store: companion)"))
        XCTAssertTrue(focus.contains(".popoverCard()"))
        XCTAssertFalse(
            focus.contains("storePartnerControl"),
            "Store in Storage sits on the companion header evo row, not under the sprite")
        XCTAssertFalse(
            focus.contains("l.storeInStorage"),
            "Focus tab must not keep a full-width Store button below the header")
        let companionRange = try XCTUnwrap(focus.range(of: "CompanionHeader(store: companion)"))
        let nextToken = focus[companionRange.upperBound...]
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .first { !$0.isEmpty } ?? ""
        XCTAssertFalse(
            nextToken.hasPrefix(".popoverCard("),
            "CompanionHeader is a canvas hero, not a hairline content card")
        XCTAssertTrue(
            nextToken.hasPrefix("ScoreBoard"),
            "ScoreBoard follows the header; Store in Storage is not a sibling row")
    }

    func testCompanionHeaderPutsEvoLineAndStoreOnStatusRow() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/PokeTaskBar/UI/CompanionView.swift")
        let source = try String(contentsOf: root, encoding: .utf8)
        guard let start = source.range(of: "struct CompanionHeader") else {
            return XCTFail("CompanionHeader missing")
        }
        let rest = source[start.lowerBound...]
        guard let end = rest.range(of: "enum DexHeaderFilter") else {
            return XCTFail("CompanionHeader bounds missing")
        }
        let header = String(rest[..<end.lowerBound])
        XCTAssertTrue(header.contains("Text(statusLine)"))
        XCTAssertTrue(header.contains("EvoLineView"), "evo line lives in the header right column")
        XCTAssertTrue(header.contains("storeInStorage"), "Store in Storage is on the evo row")
        XCTAssertTrue(header.contains("storePartnerReplacingWithStoredEgg"))
        XCTAssertTrue(header.contains("storageNeedsEgg"))
        let statusIdx = try XCTUnwrap(header.range(of: "Text(statusLine)"))
        let evoIdx = try XCTUnwrap(header.range(of: "EvoLineView"))
        let storeIdx = try XCTUnwrap(header.range(of: "storeInStorage"))
        XCTAssertLessThan(statusIdx.lowerBound, evoIdx.lowerBound,
                          "evo line sits under the status/caption line")
        XCTAssertLessThan(evoIdx.lowerBound, storeIdx.lowerBound,
                          "Store in Storage stays to the right of the evo line in source order")
        XCTAssertFalse(
            header.contains("maxWidth: popoverContentWidth)"),
            "evo line uses the right-column budget, not the full popover width under the sprite")
    }

    func testSettingsFooterFillsWindowHeight() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/PokeTaskBar/UI/SettingsView.swift")
        let settings = try String(contentsOf: root, encoding: .utf8)
        XCTAssertFalse(
            settings.contains(".frame(height: 460)"),
            "fixed 460pt Settings clips the footer above the window bottom")
        XCTAssertTrue(settings.contains("maxHeight: .infinity"))
        XCTAssertTrue(settings.contains("footer"))
        XCTAssertTrue(settings.contains("showScoreInMenu"))
        XCTAssertTrue(settings.contains("showLinearIssuesInMenu"))
        XCTAssertTrue(settings.contains("l.scoreLabel"))
        XCTAssertTrue(settings.contains("l.menuBarLinearIssuesLabel"))
    }

    func testMenuBarApplyStateHonorsScoreAndLinearIssueFlags() throws {
        let app = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/PokeTaskBar/PokeTaskBarApp.swift")
        let source = try String(contentsOf: app, encoding: .utf8)
        XCTAssertTrue(source.contains("MenuBarStatusItemChrome.apply"))
        XCTAssertTrue(source.contains("MenuBarLines.attributedTitle"))
        XCTAssertTrue(source.contains("MenuBarLines.pillText"))
        XCTAssertTrue(source.contains("MenuBarLines.focusedIssueTitle"))
        XCTAssertTrue(source.contains("MenuBarLines.pillTrailing"))
        XCTAssertTrue(source.contains("showScoreInMenu ? TokenFormatter.compact(companion.lifetimeXP) : nil"))
        XCTAssertTrue(source.contains("store.menuLinearIssueCounts") || source.contains("store.menuLinearIssuesLine"))
        XCTAssertTrue(source.contains("_ = store.showScoreInMenu"))
        XCTAssertTrue(source.contains("_ = store.menuLinearIssuesLine"))
        XCTAssertTrue(source.contains("_ = sessionStore.session?.issue.title"))
    }

    func testHairlineStrokeLivesOnTheFillShape() throws {
        XCTAssertEqual(TahoeHairline.width, 1, "0.5pt continuous strokes drop corners")
        let chrome = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/PokeTaskBar/UI/PopoverChrome.swift")
        let source = try String(contentsOf: chrome, encoding: .utf8)
        XCTAssertTrue(source.contains("struct TahoeStrokedFill"))
        XCTAssertTrue(source.contains("struct HoverHairlineSeparator"))
        let card = structSource(source, named: "PopoverCardModifier", until: "TahoeButtonKind")
        XCTAssertTrue(card.contains("TahoeStrokedFill"))
        XCTAssertFalse(
            card.contains(".overlay {\n                RoundedRectangle"),
            "card stroke must ride the fill, not a sibling overlay that clips")
    }

    func testLightAndDarkShellMatchLinearSurfaces() throws {
        let light = try XCTUnwrap(NSAppearance(named: .aqua))
        let dark = try XCTUnwrap(NSAppearance(named: .darkAqua))
        let shellLight = Self.snapshot(MenuBarPanelMetrics.shellFill, for: light)
        let canvasLight = Self.snapshot(MenuBarPanelMetrics.canvasFill, for: light)
        let cardLight = Self.snapshot(MenuBarPanelMetrics.cardFill, for: light)
        let controlLight = Self.snapshot(.controlBackgroundColor, for: light)
        let underPageLight = Self.snapshot(.underPageBackgroundColor, for: light)

        XCTAssertFalse(
            shellLight.isEqual(controlLight),
            "light shell must be Linear sidebar grey (#F3F4F6), not system controlBackground")
        XCTAssertFalse(
            canvasLight.isEqual(underPageLight),
            "light canvas must be white, not underPageBackground grey")
        XCTAssertEqual(canvasLight.redComponent, 1, accuracy: 0.02)
        XCTAssertEqual(canvasLight.greenComponent, 1, accuracy: 0.02)
        XCTAssertEqual(canvasLight.blueComponent, 1, accuracy: 0.02)
        XCTAssertEqual(cardLight.redComponent, 1, accuracy: 0.02)
        XCTAssertEqual(shellLight.redComponent, 0.953, accuracy: 0.02)
        XCTAssertEqual(shellLight.greenComponent, 0.957, accuracy: 0.02)
        XCTAssertEqual(shellLight.blueComponent, 0.965, accuracy: 0.02)

        let shellDark = Self.snapshot(MenuBarPanelMetrics.shellFill, for: dark)
        let canvasDark = Self.snapshot(MenuBarPanelMetrics.canvasFill, for: dark)
        XCTAssertFalse(shellLight.isEqual(shellDark))
        XCTAssertFalse(canvasLight.isEqual(canvasDark))
        XCTAssertGreaterThan(canvasDark.brightnessComponent, 0)
        XCTAssertLessThan(canvasDark.brightnessComponent, 0.2)
    }

    @MainActor
    func testAttachedMenuBarWindowCanBecomeKeyForSecureFields() {
        let stock = NSWindow(
            contentRect: .zero,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false)
        XCTAssertFalse(
            stock.canBecomeKey,
            "stock borderless windows drop SecureField keystrokes")
        let panel = MenuBarPanelWindow(
            contentRect: .zero,
            styleMask: MenuBarPanelMetrics.attachedStyleMask,
            backing: .buffered,
            defer: false)
        XCTAssertTrue(panel.canBecomeKey)
        XCTAssertTrue(panel.canBecomeMain)
    }

    func testDexHeaderIncludesShinyFilterAndCompactLetters() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/PokeTaskBar/UI/CompanionView.swift")
        let source = try String(contentsOf: root, encoding: .utf8)
        XCTAssertTrue(source.contains("enum DexHeaderFilter"))
        XCTAssertTrue(source.contains("case shiny"))
        XCTAssertTrue(source.contains("dexShinyLabel"))
        XCTAssertTrue(source.contains("ViewThatFits(in: .horizontal)"))
        XCTAssertTrue(source.contains("prefix(1)"))
        XCTAssertTrue(source.contains("compact"))
        let en = L(.en)
        XCTAssertEqual(String(en.rarityLabel(.legendary).prefix(1)), "L")
        XCTAssertEqual(String(en.rarityLabel(.rare).prefix(1)), "R")
        XCTAssertEqual(String(en.rarityLabel(.uncommon).prefix(1)), "U")
        XCTAssertEqual(String(en.rarityLabel(.common).prefix(1)), "C")
        XCTAssertEqual(String(en.dexShinyLabel.prefix(1)), "S")
    }

    func testLinearAPIKeyLivesInVisibleGeneralSettings() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/PokeTaskBar/UI/SettingsView.swift")
        let settings = try String(contentsOf: root, encoding: .utf8)
        guard let general = settings.range(of: "private func generalGroup"),
              let advanced = settings.range(of: "private func advancedGroup")
        else {
            return XCTFail("expected general and advanced settings groups")
        }
        let generalBody = settings[general.lowerBound..<advanced.lowerBound]
        XCTAssertTrue(
            generalBody.contains("linearIntegrationRows"),
            "Linear API key must not be buried in collapsed Advanced")
        XCTAssertFalse(settings[advanced.lowerBound...].contains("linearIntegrationRows(store)"))
    }

    private func structSource(_ source: String, named name: String, until nextName: String) -> String {
        guard let start = source.range(of: "struct \(name)") else { return "" }
        let rest = source[start.lowerBound...]
        guard let end = rest.range(of: "enum \(nextName)") ?? rest.range(of: "struct \(nextName)") else {
            return String(rest)
        }
        return String(rest[..<end.lowerBound])
    }

    private static func snapshot(_ color: NSColor, for appearance: NSAppearance) -> NSColor {
        var resolved = color
        appearance.performAsCurrentDrawingAppearance {
            resolved = NSColor(cgColor: color.cgColor) ?? color
        }
        return resolved.usingColorSpace(.sRGB) ?? resolved
    }
}
