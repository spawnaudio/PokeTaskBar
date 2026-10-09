import XCTest
import ServiceManagement
@testable import PokeTaskBar

@MainActor
final class LoginItemTests: XCTestCase {
    func testLocalBuildUsesMainAppLoginItem() {
        XCTAssertTrue(LoginItem.prefersMainApp(info: ["PTBDevelopmentBuild": "1"]))
    }

    func testDistributionAndUnspecifiedBuildsKeepTheAgent() {
        for info: [String: Any] in [[:], ["PTBDevelopmentBuild": "0"], ["PTBDevelopmentBuild": true]] {
            XCTAssertFalse(LoginItem.prefersMainApp(info: info))
        }
    }

    func testMigrationEnablesReplacementBeforeRemovingPreviousService() throws {
        var status: SMAppService.Status = .notRegistered
        var calls: [String] = []
        XCTAssertTrue(try LoginItem.migrateService(status: { status }, register: {
            calls.append("register")
            status = .enabled
        }, unregisterPrevious: { calls.append("unregister") }))
        XCTAssertEqual(calls, ["register", "unregister"])
    }

    func testMigrationRetainsPreviousServiceWhileApprovalIsPending() throws {
        var status: SMAppService.Status = .notRegistered
        var removed = false
        XCTAssertFalse(try LoginItem.migrateService(status: { status }, register: {
            status = .requiresApproval
        }, unregisterPrevious: { removed = true }))
        XCTAssertFalse(removed)
    }

    func testMigrationRetainsPreviousServiceWhenRegistrationFails() {
        var removed = false
        XCTAssertThrowsError(try LoginItem.migrateService(status: { .notRegistered }, register: {
            throw NSError(domain: "LoginItemTests", code: 1)
        }, unregisterPrevious: { removed = true }))
        XCTAssertFalse(removed)
    }

    func testMigrationDoesNotReregisterAnEnabledReplacement() throws {
        var registered = false
        var removed = false
        XCTAssertTrue(try LoginItem.migrateService(status: { .enabled }, register: { registered = true },
                                                unregisterPrevious: { removed = true }))
        XCTAssertFalse(registered)
        XCTAssertTrue(removed)
    }
}
