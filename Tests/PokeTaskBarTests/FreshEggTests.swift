import XCTest
@testable import PokeTaskBar

// MARK: Shop eggs bank in Pokémon Storage (do not release the partner)

private struct FreshEggNoProvider: PokeProviding {
    func line(baseSpeciesID: Int) async throws -> EvoLine { throw URLError(.notConnectedToInternet) }
    func baseSpeciesIndex() async throws -> [BaseSpecies] { [] }
    func baseSpecies(id: Int) async throws -> BaseSpecies? { nil }
}

@MainActor
final class FreshEggTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    private func store(active: Bool = true, shiny: Bool = false, used: Int = 5_000_000_000,
                       spent: Int = 0) -> CompanionStore {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("egg-\(UUID().uuidString).json")
        let mon = "{\"baseID\":10,\"pathIDs\":[10],\"stageIndex\":0,\"usedAtStage\":200000000,"
            + "\"rarity\":\"common\",\"totalForms\":3,\"isShiny\":\(shiny)}"
        let dex = "{\"baseID\":1,\"finalID\":3,\"chainOrder\":[1,2,3],\"rarity\":\"common\"}"
        let json = "{\"installBaselineSet\":true,\"usedSinceInstall\":\(used),\"spentTokens\":\(spent),"
            + "\"lastDate\":\"d\",\"active\":\(active ? mon : "null"),\"dex\":[\(dex)],\"collectedFinals\":[\"1:3\"]}"
        try? json.data(using: .utf8)!.write(to: url)
        return CompanionStore(provider: FreshEggNoProvider(), clock: { self.now }, fileURL: url, rng: SeededRNG(seed: 7))
    }

    func testPriceMatchesCoinSeedTable() {
        XCTAssertEqual(FreshEgg.price, 10_000)
        XCTAssertEqual(FreshEgg.price, EconomyScale.coins(1_000_000_000))
    }

    func testBuyFreshEggBanksIntoStorageWithoutReleasing() {
        let s = store()
        let dexBefore = s.state.dex
        XCTAssertTrue(s.hasActive)
        XCTAssertTrue(s.buyFreshEgg())
        XCTAssertNotNil(s.state.active, "현재 포켓몬은 육성 슬롯에 남는다")
        XCTAssertEqual(s.state.active?.baseID, 10)
        XCTAssertEqual(s.state.active?.usedAtStage, 200_000_000)
        XCTAssertEqual(s.state.dex, dexBefore, "놓아줌 기록이 생기지 않는다")
        XCTAssertEqual(s.storedCompanions.count, 1)
        XCTAssertTrue(s.storedCompanions[0].isEgg)
        XCTAssertEqual(s.state.spentTokens, FreshEgg.price)
        XCTAssertEqual(s.availableCoins, 5_000_000 - FreshEgg.price)
    }

    func testBuyEggWhileIncubatingGoesToStorage() {
        let s = store(active: false, used: 5_000_000_000)
        XCTAssertFalse(s.hasActive)
        XCTAssertTrue(s.isEgg)
        XCTAssertTrue(s.canBuyFreshEgg)
        XCTAssertTrue(s.buyFreshEgg())
        XCTAssertTrue(s.isEgg)
        XCTAssertEqual(s.storedCompanions.count, 1)
        XCTAssertEqual(s.state.spentTokens, FreshEgg.price)
    }

    func testCannotBuyEggWithoutFunds() {
        let s = store(used: EconomyScale.xpForCoins(FreshEgg.price) - 1)
        XCTAssertFalse(s.canBuyFreshEgg)
        XCTAssertFalse(s.buyFreshEgg())
        XCTAssertNotNil(s.state.active)
        XCTAssertTrue(s.storedCompanions.isEmpty)
        XCTAssertEqual(s.state.spentTokens, 0)
    }

    func testShinyPartnerStaysWhenBuyingEgg() {
        let s = store(shiny: true)
        XCTAssertTrue(s.currentIsShiny)
        XCTAssertTrue(s.buyFreshEgg())
        XCTAssertTrue(s.currentIsShiny)
        XCTAssertEqual(s.state.active?.baseID, 10)
    }

    func testSwapStorageEggIntoTrainingBanksPartner() {
        let s = store()
        XCTAssertTrue(s.buyFreshEgg())
        let eggID = try! XCTUnwrap(s.storedCompanions.first?.id)
        XCTAssertTrue(s.swapFromStorage(eggID))
        XCTAssertNil(s.state.active)
        XCTAssertTrue(s.isEgg)
        XCTAssertEqual(s.storedCompanions.count, 1)
        if case .partner(_, let mon) = s.storedCompanions[0] {
            XCTAssertEqual(mon.baseID, 10)
        } else {
            XCTFail("partner should be banked")
        }
    }
}
