import Foundation
import XCTest
@testable import PokeTaskBar

final class ConsolidatedStatsTests: XCTestCase {
    func testPreparedConsolidationDecodesWithoutLosingRecords() throws {
        guard let path = ProcessInfo.processInfo.environment["POKETASKS_MERGE_DIR"] else {
            throw XCTSkip("Run with POKETASKS_MERGE_DIR to validate a prepared local merge")
        }
        let directory = URL(fileURLWithPath: path)
        let companionData = try Data(contentsOf: directory.appendingPathComponent("companion-state.json"))
        let rawCompanion = try XCTUnwrap(JSONSerialization.jsonObject(with: companionData) as? [String: Any])
        let companion = try JSONDecoder().decode(CompanionState.self, from: companionData)
        XCTAssertEqual(companion.dex.count, (rawCompanion["dex"] as? [Any])?.count)
        XCTAssertEqual(companion.pokemonStorage.count, (rawCompanion["pokemonStorage"] as? [Any])?.count)
        XCTAssertEqual(companion.linearIssueXP.count, (rawCompanion["linearIssueXP"] as? [Any])?.count)
        let focusData = try Data(contentsOf: directory.appendingPathComponent("focus-session.json"))
        let rawFocus = try XCTUnwrap(JSONSerialization.jsonObject(with: focusData) as? [String: Any])
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let focus = try decoder.decode(FocusPersistedState.self, from: focusData)
        XCTAssertEqual(focus.sessionRecords.count, (rawFocus["sessionRecords"] as? [Any])?.count)
        XCTAssertEqual(Set(focus.sessionRecords.map(\.id)).count, focus.sessionRecords.count)
        XCTAssertGreaterThan(TaskTimeReport.recordedSeconds(focus.sessionRecords, from: .distantPast, until: .distantFuture),
                             TaskTimeReport.seconds(focus.sessionRecords, from: .distantPast, until: .distantFuture))
    }

    func testLegacyDurationContributesToOverallButNotMeasuredCharts() {
        let from = Date(timeIntervalSince1970: 1_000)
        let until = Date(timeIntervalSince1970: 2_000)
        let measured = record(id: "measured", seconds: 100, at: 1_500, partial: false)
        let legacy = record(id: "legacy", seconds: 600, at: 1_600, partial: true)
        let outside = record(id: "outside", seconds: 900, at: 2_000, partial: true)
        XCTAssertEqual(TaskTimeReport.recordedSeconds([measured, legacy, outside], from: from, until: until), 700)
        XCTAssertEqual(TaskTimeReport.seconds([measured, legacy], from: from, until: until), 100)
        XCTAssertTrue(TaskTimeReport.secondsByDay([legacy]).isEmpty)
    }

    func testUntimedCompletionsAndRepeatedSessionsCountEachTaskOnce() {
        let records = [record(id: "same", seconds: 100, at: 1_500, partial: false),
                       record(id: "same", seconds: 200, at: 1_600, partial: true)]
        let awards = [LinearIssueXPRecord(id: "same", identifier: "PKT-1", xp: 2_000_000,
                                         awardedAt: Date(timeIntervalSince1970: 1_500)),
                      LinearIssueXPRecord(id: "untimed", identifier: "PKT-2", xp: 2_000_000,
                                         awardedAt: Date(timeIntervalSince1970: 1_700)),
                      LinearIssueXPRecord(id: "outside", identifier: "PKT-3", xp: 2_000_000,
                                         awardedAt: Date(timeIntervalSince1970: 2_000))]
        XCTAssertEqual(TaskTimeReport.completedTaskCount(records, awards: awards,
            from: Date(timeIntervalSince1970: 1_000), until: Date(timeIntervalSince1970: 2_000)), 2)
    }

    private func record(id: String, seconds: Double, at: Double, partial: Bool) -> TaskSessionRecord {
        TaskSessionRecord(id: id, issueID: id, identifier: id, title: id,
            projectID: nil, projectName: nil, blockID: nil,
            segments: partial ? [] : [.init(start: Date(timeIntervalSince1970: at - seconds),
                                            end: Date(timeIntervalSince1970: at))],
            activeSeconds: seconds, plannedSeconds: seconds,
            finishedAt: Date(timeIntervalSince1970: at), finish: .doneOnTime, xp: 0, partial: partial)
    }
}
