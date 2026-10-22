import AppKit
import XCTest
@testable import PokeTaskBar

/// Status-item right-click menu and menubar-first launch (overhaul phase 1).
@MainActor
final class StatusItemMenuTests: XCTestCase {
    private let t0 = Date(timeIntervalSince1970: 1_800_000_000)
    private let l = L(.en)

    private func session(local: Bool) -> FocusSession {
        var issue = FocusPinnedIssue.pomodoro(title: "Pomodoro")
        if !local { issue.id = "linear-issue-1" }
        return FocusSession.start(issue: issue, plannedMinutes: 50, checkInMinutes: 30, now: t0)
    }

    private func actions(_ sections: [[StatusItemMenuEntry]]) -> [[StatusItemMenuAction]] {
        sections.map { $0.map(\.action) }
    }

    func testIdleMenuOffersQuickStartPresetsThenNavigation() {
        let sections = StatusItemMenu.sections(session: nil, l: l)
        XCTAssertEqual(actions(sections), [
            SessionXP.plannedPresets.map { .quickStart(minutes: $0) },
            [.openToday, .openSettings],
            [.quit],
        ])
        XCTAssertEqual(sections[0].map(\.title), ["Start focus · 25 min", "Start focus · 50 min", "Start focus · 90 min"])
        XCTAssertEqual(sections[1].map(\.title), ["Open Today", "Settings…"])
    }

    func testLocalTimerMenuPausesAndFinishes() {
        let sections = StatusItemMenu.sections(session: session(local: true), l: l)
        XCTAssertEqual(actions(sections).first, [.togglePause, .finishTimer])
        XCTAssertEqual(sections[0].map(\.title), ["Pause", "Finish timer"])
    }

    func testLinearIssueMenuOffersMarkDoneAndLeaveInProgress() {
        let sections = StatusItemMenu.sections(session: session(local: false), l: l)
        XCTAssertEqual(actions(sections).first, [.togglePause, .markDone, .finishTimer])
        XCTAssertEqual(sections[0][1].title, l.markDone)
        XCTAssertEqual(sections[0][2].title, l.timesUpFinishLeave)
    }

    func testPausedSessionOffersResume() {
        let paused = FocusTick.pause(session(local: true), now: t0.addingTimeInterval(60))
        XCTAssertEqual(StatusItemMenu.sections(session: paused, l: l)[0].first?.title, "Resume")
    }

    func testTimesUpHidesPauseButKeepsFinishChoices() {
        let done = FocusTick.apply(session(local: false), now: t0.addingTimeInterval(50 * 60)).session
        XCTAssertEqual(done.phase, .awaitingChoice)
        XCTAssertEqual(actions(StatusItemMenu.sections(session: done, l: l)).first, [.markDone, .finishTimer])
    }

    /// ko/ja/de spell "Finish" and "Quit" the same word; the menu shows both, so its finish row
    /// must not reuse `finishFocusTimer`.
    func testFinishRowNeverReadsLikeQuitInAnyLanguage() {
        for language in AppLanguage.allCases {
            let l = L(language)
            let titles = StatusItemMenu.sections(session: session(local: true), l: l).flatMap { $0 }.map(\.title)
            XCTAssertEqual(Set(titles).count, titles.count, "duplicate menu titles in \(language): \(titles)")
        }
    }

    func testRightClickAndControlClickOpenMenuPlainClickDoesNot() {
        XCTAssertTrue(StatusItemMenu.isMenuRequest(type: .rightMouseUp, modifiers: []))
        XCTAssertTrue(StatusItemMenu.isMenuRequest(type: .leftMouseUp, modifiers: [.control]))
        XCTAssertFalse(StatusItemMenu.isMenuRequest(type: .leftMouseUp, modifiers: []))
        XCTAssertFalse(StatusItemMenu.isMenuRequest(type: .leftMouseUp, modifiers: [.command]))
        XCTAssertFalse(StatusItemMenu.isMenuRequest(type: nil, modifiers: [.control]),
                       "programmatic performClick has no event and must toggle the panel")
    }

    private func repoFile(_ path: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        return try String(contentsOf: root.appendingPathComponent(path), encoding: .utf8)
    }

    func testStatusItemRoutesRightClickAndReopenOpensPanel() throws {
        let app = try repoFile("Sources/PokeTaskBar/PokeTaskBarApp.swift")
        XCTAssertTrue(app.contains("button.sendAction(on: [.leftMouseUp, .rightMouseUp])"),
                      "without rightMouseUp the button never receives right clicks")
        XCTAssertTrue(app.contains("StatusItemMenu.isMenuRequest"))
        let reopen = try XCTUnwrap(app.range(of: "func applicationShouldHandleReopen"))
        let body = String(app[reopen.lowerBound...].prefix(500))
        XCTAssertTrue(body.contains("openPopover()"), "Finder/Spotlight relaunch opens the menubar panel")
    }

    func testV3BuildNoLongerOpensTodayOnLaunch() throws {
        XCTAssertFalse(try repoFile("scripts/rebuild-v3.sh").contains("PTB_OPEN_MAIN_WINDOW=1"))
    }
}
