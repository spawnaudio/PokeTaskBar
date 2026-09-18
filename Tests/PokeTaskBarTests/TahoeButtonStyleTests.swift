import XCTest
@testable import PokeTaskBar

/// Action buttons in the UI sources must go through `tahoeButtonStyle` so Linear
/// filled / chip / plain chrome stays in one place. Raw `.bordered` / `.glass`
/// styles are not used on information surfaces.
final class TahoeButtonStyleTests: XCTestCase {
    func testUIButtonsUseTahoeHelperInsteadOfRawBorderedStyles() throws {
        let ui = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/PokeTaskBar/UI")
        let enumerator = try XCTUnwrap(FileManager.default.enumerator(
            at: ui, includingPropertiesForKeys: nil))
        let forbidden = [
            ".buttonStyle(.borderedProminent)",
            ".buttonStyle(.bordered)",
            ".buttonStyle(.borderless)",
            ".buttonStyle(.glassProminent)",
            ".buttonStyle(.glass)",
        ]
        var offenders: [String] = []

        for case let url as URL in enumerator where url.pathExtension == "swift" {
            if url.lastPathComponent == "PopoverChrome.swift" { continue }
            let lines = try String(contentsOf: url, encoding: .utf8)
                .split(separator: "\n", omittingEmptySubsequences: false)
            for (index, line) in lines.enumerated() {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if forbidden.contains(where: { trimmed.contains($0) }) {
                    offenders.append("\(url.lastPathComponent):\(index + 1)")
                }
            }
        }

        XCTAssertTrue(offenders.isEmpty, """
            Use tahoeButtonStyle(.prominent/.regular/.accessory) so Linear chrome stays in one \
            place. Offenders: \(offenders.joined(separator: ", "))
            """)
    }

    func testPopoverChromeOwnsLinearChrome() throws {
        let chrome = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/PokeTaskBar/UI/PopoverChrome.swift")
        let source = try String(contentsOf: chrome, encoding: .utf8)
        XCTAssertTrue(source.contains("func tahoeButtonStyle"))
        XCTAssertFalse(source.contains(".glassProminent"))
        XCTAssertFalse(source.contains(".buttonStyle(.glass)"))
        XCTAssertFalse(source.contains("GlassEffectContainer"))
        XCTAssertFalse(source.contains("glassEffect"))
        XCTAssertTrue(source.contains("TahoeMenuLabel"))
        XCTAssertTrue(source.contains("TahoePopupMenu"))
        XCTAssertTrue(source.contains("TahoeTabBar"))
        XCTAssertTrue(source.contains("TahoeChromeSymbol.menuChevron"))
        XCTAssertTrue(source.contains("func popoverBottomBarChrome"))
        XCTAssertTrue(source.contains("struct PopoverShellToolbar"))
        XCTAssertTrue(source.contains("func linearChipChrome"))
        XCTAssertTrue(source.contains("func linearSegmentChrome"))
        XCTAssertTrue(source.contains("struct TahoeChromeButtonStyle: ButtonStyle"))
        XCTAssertTrue(source.contains("struct LinearSegmentButtonStyle: ButtonStyle"))
        XCTAssertTrue(source.contains("struct TahoeIconButtonStyle: ButtonStyle"))
        XCTAssertTrue(source.contains("buttonStyle(TahoeChromeButtonStyle"))
        XCTAssertTrue(source.contains("configuration.label"))
        XCTAssertTrue(source.contains("struct LinearTagChip"))
        XCTAssertTrue(source.contains("struct LinearPropertyRow"))
        XCTAssertTrue(source.contains(".linearChipChrome(expands: expands, tint: tint)"))
        XCTAssertTrue(source.contains(".linearSegmentChrome(selected: selected, expands: expands)"))
        XCTAssertTrue(source.contains("enum TahoeHairline"))
        XCTAssertTrue(source.contains("func tahoeIconChrome"))
        XCTAssertTrue(source.contains("TahoeHairline.idle"))
        XCTAssertTrue(source.contains("MenuBarPanelMetrics.hairline"))
        XCTAssertTrue(source.contains("MenuBarPanelMetrics.selectedFill"))
        XCTAssertTrue(source.contains("selected ? TahoeHairline.selected : TahoeHairline.idle"))
        XCTAssertTrue(source.contains("detachMenuBarPanel") || source.contains("menuBarPanelDetached"))
        XCTAssertFalse(
            source.contains("selected ? Color.accentColor"),
            "selected tabs must use Linear fill, not accent tint")
        XCTAssertFalse(
            popupMenuContainsTahoeButtonStyle(source),
            "TahoePopupMenu must stay a quiet chip, not a glass button")
        let chromeStyle = structSource(source, named: "TahoeChromeButtonStyle", until: "LinearSegmentButtonStyle")
        XCTAssertTrue(chromeStyle.contains("configuration.label"))
        XCTAssertTrue(chromeStyle.contains("TahoeCapsuleChrome") || chromeStyle.contains("contentShape"))
        XCTAssertFalse(
            tahoeButtonStyleUsesPlain(source),
            "tahoeButtonStyle must wrap chrome in ButtonStyle, not .plain + outer padding")
    }

    private func tahoeButtonStyleUsesPlain(_ source: String) -> Bool {
        guard let range = source.range(of: "func tahoeButtonStyle") else { return true }
        let rest = source[range.lowerBound...]
        guard let end = rest.range(of: "func tahoeFloatingChrome") else {
            return rest.contains(".buttonStyle(.plain)")
        }
        return rest[..<end.lowerBound].contains(".buttonStyle(.plain)")
    }

    func testUIPickersDoNotUseNativeMenuOrSegmentedStyles() throws {
        let ui = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/PokeTaskBar/UI")
        let enumerator = try XCTUnwrap(FileManager.default.enumerator(
            at: ui, includingPropertiesForKeys: nil))
        let forbidden = [".pickerStyle(.segmented)", ".pickerStyle(.menu)", ".menuIndicator(.visible)"]
        var offenders: [String] = []

        for case let url as URL in enumerator where url.pathExtension == "swift" {
            if url.lastPathComponent == "PopoverChrome.swift" { continue }
            let lines = try String(contentsOf: url, encoding: .utf8)
                .split(separator: "\n", omittingEmptySubsequences: false)
            for (index, line) in lines.enumerated() {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if forbidden.contains(where: { trimmed.contains($0) }) {
                    offenders.append("\(url.lastPathComponent):\(index + 1)")
                }
            }
        }

        XCTAssertTrue(offenders.isEmpty, """
            Tabs use TahoeTabBar and dropdowns use TahoePopupMenu / TahoeMenuLabel \
            (quiet chip + chevron). Offenders: \(offenders.joined(separator: ", "))
            """)
    }

    func testMenuChevronIsTheTahoePopupGlyph() {
        XCTAssertEqual(TahoeChromeSymbol.menuChevron, "chevron.down")
    }

    @MainActor
    func testCompanionHeaderSpriteIsLargeAndUnboxed() {
        XCTAssertEqual(CompanionHeader.spriteSize, 120)
    }

    @MainActor
    func testStorageRowMatchesEggAndPartnerThumbSlots() throws {
        XCTAssertEqual(StorageRow.thumbSlot, 48)
        XCTAssertEqual(StorageRow.thumbSprite, 48)
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/PokeTaskBar/UI/PokemonStorageView.swift")
        let source = try String(contentsOf: url, encoding: .utf8)
        XCTAssertTrue(source.contains("size: Self.thumbSprite"))
        XCTAssertTrue(source.contains("width: Self.thumbSlot"))
        XCTAssertTrue(source.contains("HStack(alignment: .top"))
        XCTAssertTrue(source.contains("trainActions(l)"))
        let titleIdx = try XCTUnwrap(source.range(of: "title"))
        let trainIdx = try XCTUnwrap(source.range(of: "trainActions(l)"))
        let subtitleIdx = try XCTUnwrap(source.range(of: "subtitle(l)"))
        XCTAssertLessThan(trainIdx.lowerBound, subtitleIdx.lowerBound,
                          "Train sits on the name row, not below the subtitle")
        XCTAssertLessThan(titleIdx.lowerBound, trainIdx.lowerBound)
        XCTAssertTrue(
            source.contains("cropToContent: true"),
            "partner thumbs crop the 96px padded PNG so they match the cropped egg")
        XCTAssertTrue(source.contains("displayName(for:"),
                      "stored partner row title is the species name")
        XCTAssertFalse(source.contains("Training partner"))
        XCTAssertFalse(source.contains("Training Partner"))
        let localization = try String(
            contentsOf: url.deletingLastPathComponent().deletingLastPathComponent()
                .appendingPathComponent("Core/Localization.swift"), encoding: .utf8)
        XCTAssertFalse(localization.contains("Training partner"),
                       "L() no longer ships a Training partner row title")
        XCTAssertFalse(localization.contains("var storagePartner:"))
    }

    func testLinearInformationSurfacesStayQuietAndUnboxed() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/PokeTaskBar/UI")
        let linear = try String(
            contentsOf: root.appendingPathComponent("LinearIntegrationView.swift"), encoding: .utf8)
        let today = try String(
            contentsOf: root.appendingPathComponent("TodayDeskView.swift"), encoding: .utf8)
        let controls = try String(
            contentsOf: root.appendingPathComponent("LinearIssueControls.swift"), encoding: .utf8)
        let composer = try String(
            contentsOf: root.appendingPathComponent("LinearIssueComposer.swift"), encoding: .utf8)
        let usage = try String(
            contentsOf: root.appendingPathComponent("UsageTabView.swift"), encoding: .utf8)
        let chrome = try String(
            contentsOf: root.appendingPathComponent("PopoverChrome.swift"), encoding: .utf8)

        XCTAssertTrue(linear.contains("LinearIssueEntityRow"))
        XCTAssertTrue(linear.contains("LinearTagChip"))
        XCTAssertTrue(linear.contains("LinearMarkdownText"))
        XCTAssertTrue(linear.contains("LinearPriorityButton"))
        XCTAssertTrue(linear.contains("static let initiative = \"flag\""))
        XCTAssertFalse(linear.contains("flag.fill"))
        XCTAssertFalse(linear.contains("LinearPriorityTint.gold"))
        XCTAssertTrue(linear.contains("VStack(alignment: .leading, spacing: 0)"))
        XCTAssertFalse(linear.contains("popoverCard()"))
        XCTAssertFalse(linear.contains("ChromeTabBar"))
        XCTAssertFalse(linear.contains("linearNestedPanel()"))
        XCTAssertFalse(linear.contains("HoverHairlineSeparator"))
        XCTAssertFalse(linear.contains("hoveringHeader ? 0.08 : 0.04"))
        XCTAssertFalse(linear.contains("strokeBorder(Color.primary.opacity(0.08)"))

        XCTAssertTrue(today.contains("LinearPropertyRow"))
        XCTAssertTrue(today.contains("TodayDeskPinRow"))
        XCTAssertFalse(today.contains("pinned ? Color.accentColor.opacity(0.14)"))

        XCTAssertTrue(controls.contains(".buttonStyle(.plain)"))
        XCTAssertTrue(controls.contains(".contentShape(Capsule())"), "issue ID and chip buttons fill their chrome")
        XCTAssertFalse(idButtonUsesTahoeGlass(controls))
        XCTAssertTrue(controls.contains(".linearChipChrome()"))
        XCTAssertTrue(controls.contains("struct LinearPriorityButton"))
        XCTAssertTrue(controls.contains("struct LinearMarkdownText"))
        XCTAssertTrue(controls.contains("tint: LinearWorkflowTint.color(for: issue.stateType)"))
        XCTAssertTrue(controls.contains("enum LinearTeamTint"))
        XCTAssertTrue(chrome.contains("ViewThatFits"))
        XCTAssertFalse(chrome.contains("struct ChromeTabBar"))
        XCTAssertTrue(chrome.contains(".contentShape(shape)"), "button chrome hitboxes fill the capsule/circle")
        XCTAssertTrue(chrome.contains(".contentShape(Capsule())"), "toolbar tabs hit the full pill")

        XCTAssertTrue(composer.contains("LinearPropertyRow(label: l.linearIssueTeam)"))
        XCTAssertTrue(composer.contains(".linearChipChrome(expands: true)"))

        XCTAssertTrue(usage.contains("linearSegmentChrome(selected: isSelected)"))
        XCTAssertFalse(usage.contains("TahoeGlassCluster"))

        let issueRow = structSource(linear, named: "LinearIssueEntityRow", until: "LinearContainerRow")
        XCTAssertTrue(issueRow.contains("foldedTeamLine"))
        XCTAssertTrue(issueRow.contains("foldedProjectLine"))
        XCTAssertTrue(issueRow.contains("foldedLabelsLine"))
        XCTAssertTrue(issueRow.contains(".background {"))
        XCTAssertTrue(issueRow.contains(".contentShape("))
        XCTAssertTrue(issueRow.contains("allowsHitTesting(false)"))
        XCTAssertTrue(issueRow.contains("LinearIssueIDButton"))
        XCTAssertTrue(issueRow.contains("LinearPriorityButton"))
        XCTAssertTrue(issueRow.contains("LinearIssueStatusPicker"))
        XCTAssertTrue(issueRow.contains("LinearFocusButton"))
        XCTAssertTrue(issueRow.contains("LinearMarkdownText"))
        XCTAssertFalse(issueRow.contains("expandControl"))
        XCTAssertFalse(issueRow.contains("foldedChips"))
        XCTAssertFalse(issueRow.contains("popoverCard()"))
        XCTAssertFalse(issueRow.contains("Color.clear.frame(height: 1)"))
        XCTAssertFalse(
            issueRow.contains("ScrollView(.horizontal"),
            "folded project and labels must not share a horizontal chip strip with team")
    }

    private func structSource(_ source: String, named name: String, until nextName: String) -> String {
        guard let start = source.range(of: "struct \(name)") else { return "" }
        let rest = source[start.lowerBound...]
        guard let end = rest.range(of: "struct \(nextName)") else { return String(rest) }
        return String(rest[..<end.lowerBound])
    }

    private func popupMenuContainsTahoeButtonStyle(_ source: String) -> Bool {
        guard let range = source.range(of: "struct TahoePopupMenu") else { return true }
        let rest = source[range.lowerBound...]
        guard let end = rest.range(of: "struct TahoeTabItem") else {
            return rest.contains("tahoeButtonStyle")
        }
        return rest[..<end.lowerBound].contains("tahoeButtonStyle")
    }

    private func idButtonUsesTahoeGlass(_ source: String) -> Bool {
        guard let range = source.range(of: "struct LinearIssueIDButton") else { return true }
        let rest = source[range.lowerBound...]
        guard let end = rest.range(of: "struct LinearIssueCompletionStats") else {
            return rest.contains("tahoeButtonStyle")
        }
        return rest[..<end.lowerBound].contains("tahoeButtonStyle")
    }
}
