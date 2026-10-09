import XCTest
@testable import PokeTaskBar

final class AppStatePathsTests: XCTestCase {
    func testRenamedV3BuildRetainsExistingSaveFolder() {
        XCTAssertEqual(AppStatePaths.folderName(info: [
            "CFBundleName": "PokeTasks v3", "PTBStateFolderName": "PokeTasks v2.5"
        ]), "PokeTasks v2.5")
    }

    func testExistingBundlesAndInvalidOverridesKeepTheirFallbacks() {
        XCTAssertEqual(AppStatePaths.folderName(info: ["CFBundleName": "PokeTasks v2.5"]), "PokeTasks v2.5")
        for override in ["   " as Any, 3] {
            XCTAssertEqual(AppStatePaths.folderName(info: [
                "CFBundleName": "PokeTasks v3", "PTBStateFolderName": override
            ]), "PokeTasks v3")
        }
        XCTAssertEqual(AppStatePaths.folderName(info: [:]), "PokeTaskBar v1")
    }
}
