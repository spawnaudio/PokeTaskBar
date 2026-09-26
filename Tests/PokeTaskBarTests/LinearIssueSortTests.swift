import XCTest
@testable import PokeTaskBar

final class LinearIssueSortTests: XCTestCase {
    func testSortsWithMissingMetadataAndStableTies() throws {
        let issues = try [
            ["id": "2", "identifier": "ENG-2", "title": "zebra", "priority": 0],
            ["id": "10", "identifier": "ENG-10", "title": "Alpha", "priority": 3,
             "dueDate": "2026-09-28", "updatedAt": "2026-09-27T00:00:00Z", "createdAt": "2026-09-20T00:00:00Z"],
            ["id": "1", "identifier": "ENG-1", "title": "alpha", "priority": 1,
             "dueDate": "2026-09-27", "updatedAt": "2026-09-20T00:00:00Z", "createdAt": "2026-09-27T00:00:00Z"],
        ].map(LinearClient.parseIssueSummary)
        XCTAssertEqual(LinearIssueSort.priority.sorted(issues).map(\.id), ["1", "10", "2"])
        XCTAssertEqual(LinearIssueSort.dueDate.sorted(issues).map(\.id), ["1", "10", "2"])
        XCTAssertEqual(LinearIssueSort.updated.sorted(issues).map(\.id), ["10", "1", "2"])
        XCTAssertEqual(LinearIssueSort.created.sorted(issues).map(\.id), ["1", "10", "2"])
        XCTAssertEqual(LinearIssueSort.title.sorted(issues).map(\.id), ["1", "10", "2"])
        let tied = issues.map { issue in
            var copy = issue
            copy.dueDate = nil; copy.updatedAt = nil; copy.createdAt = nil; copy.title = "Same"
            return copy
        }
        for sort in [LinearIssueSort.dueDate, .updated, .created, .title] {
            XCTAssertEqual(sort.sorted(tied).map(\.id), ["1", "2", "10"])
        }
    }

    @MainActor
    func testSortSelectionIsIndependentForEachTabAndSurvivesNavigation() {
        let nav = MainWindowNavigation()
        nav.issueSorts[.todo] = .dueDate
        nav.issueSorts[.planned] = .title
        nav.issuesTab = .todo
        nav.select(.issues); nav.select(.focus); nav.back()
        XCTAssertEqual(nav.issuesTab, .todo)
        XCTAssertEqual(nav.issueSorts[.todo], .dueDate)
        XCTAssertEqual(nav.issueSorts[.planned], .title)
        XCTAssertNil(nav.issueSorts[.inProgress])
        XCTAssertNil(nav.issueSorts[.completedToday])
    }
}
