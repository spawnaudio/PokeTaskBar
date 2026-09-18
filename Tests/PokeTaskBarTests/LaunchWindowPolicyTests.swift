import XCTest
@testable import PokeTaskBar

final class LaunchWindowPolicyTests: XCTestCase {
    func testRecognizesSwiftUISettingsPlaceholderIdentifier() {
        XCTAssertTrue(LaunchWindowPolicy.isSwiftUISettingsPlaceholder(
            identifier: "com_apple_SwiftUI_Settings-actual",
            autosaveName: "main"))
    }

    func testRecognizesSwiftUISettingsPlaceholderAutosaveName() {
        XCTAssertTrue(LaunchWindowPolicy.isSwiftUISettingsPlaceholder(
            identifier: nil,
            autosaveName: "com_apple_SwiftUI_Settings_1234"))
    }

    func testIgnoresUnrelatedWindows() {
        XCTAssertFalse(LaunchWindowPolicy.isSwiftUISettingsPlaceholder(
            identifier: "PokeTaskBarPopover",
            autosaveName: "popover"))
    }

    func testTodayDeskIdentifierIsNotASettingsPlaceholder() {
        XCTAssertFalse(LaunchWindowPolicy.isSwiftUISettingsPlaceholder(
            identifier: LaunchWindowPolicy.todayDeskIdentifier,
            autosaveName: LaunchWindowPolicy.todayDeskAutosaveName))
    }

    func testNewLinearIssueIdentifierIsNotASettingsPlaceholder() {
        XCTAssertFalse(LaunchWindowPolicy.isSwiftUISettingsPlaceholder(
            identifier: LaunchWindowPolicy.newLinearIssueIdentifier,
            autosaveName: LaunchWindowPolicy.newLinearIssueAutosaveName))
    }

    func testMenuBarPanelIdentifierIsNotASettingsPlaceholder() {
        XCTAssertFalse(LaunchWindowPolicy.isSwiftUISettingsPlaceholder(
            identifier: LaunchWindowPolicy.menuBarPanelIdentifier,
            autosaveName: LaunchWindowPolicy.menuBarPanelAutosaveName))
    }
}
