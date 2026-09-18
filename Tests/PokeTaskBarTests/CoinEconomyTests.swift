import XCTest
@testable import PokeTaskBar

final class CoinEconomyTests: XCTestCase {
    func testSeedShopPricesMatchKickoffTable() {
        XCTAssertEqual(Mint.price, 1_000)
        XCTAssertEqual(RareCandy.price, 5_000)
        XCTAssertEqual(FreshEgg.price, 10_000)
        XCTAssertEqual(FreshEgg.price(guaranteeing: .uncommon), 25_000)
        XCTAssertEqual(ShinyCharm.price, 30_000)
        XCTAssertEqual(FreshEgg.price(guaranteeing: .rare), 40_000)
    }

    func testCoinsAreFloorXPOver1000() {
        XCTAssertEqual(EconomyScale.xpPerCoin, 1_000)
        XCTAssertEqual(EconomyScale.coinsFromXP(0), 0)
        XCTAssertEqual(EconomyScale.coinsFromXP(999), 0)
        XCTAssertEqual(EconomyScale.coinsFromXP(1_000), 1)
        XCTAssertEqual(EconomyScale.coinsFromXP(1_999), 1)
        XCTAssertEqual(EconomyScale.xpForCoins(5_000), 5_000_000)
    }
}

@MainActor
final class UniqueHatchTests: XCTestCase {
    private struct OneSpeciesProvider: PokeProviding {
        func line(baseSpeciesID: Int) async throws -> EvoLine {
            EvoLine(baseID: 1, tree: EvoNode(speciesID: 1, children: []),
                    rarity: .common, names: [1: ["en": "Bulba"]])
        }
        func baseSpeciesIndex() async throws -> [BaseSpecies] { [BaseSpecies(id: 1, captureRate: 255)] }
        func baseSpecies(id: Int) async throws -> BaseSpecies? { BaseSpecies(id: 1, captureRate: 255) }
    }

    private func eggStore(dexJSON: String, seed: UInt64) -> CompanionStore {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("unique-hatch-\(UUID().uuidString).json")
        let json = "{\"installBaselineSet\":true,\"usedSinceInstall\":10000000,\"spentTokens\":0,"
            + "\"lastDate\":\"d\",\"active\":null,\"dex\":[\(dexJSON)],\"collectedFinals\":[],"
            + "\"eggUsage\":\(PokemonBalance.eggHatchThreshold)}"
        try? json.data(using: .utf8)!.write(to: url)
        return CompanionStore(provider: OneSpeciesProvider(), clock: { Date(timeIntervalSince1970: 1) },
                              fileURL: url, rng: SeededRNG(seed: seed),
                              dittoDisguiseRollingEnabled: false)
    }

    func testAlreadyCaughtSpeciesDoesNotHatchUnlessShiny() async {
        let dex = "{\"baseID\":1,\"finalID\":1,\"chainOrder\":[1],\"rarity\":\"common\"}"
        var nonShiny: UInt64?
        var shiny: UInt64?
        for seed: UInt64 in 1...10_000 {
            var rng = SeededRNG(seed: seed)
            let roll = rng.next()
            if CompanionStore.rollsShiny(roll: roll, charmOwned: false) {
                if shiny == nil { shiny = seed }
            } else if nonShiny == nil {
                nonShiny = seed
            }
            if shiny != nil, nonShiny != nil { break }
        }
        let blocked = eggStore(dexJSON: dex, seed: try! XCTUnwrap(nonShiny))
        await blocked.hatch(baseID: 1)
        XCTAssertNil(blocked.state.active, "이미 잡은 종은 이로치가 아니면 다시 부화하지 않는다")
        XCTAssertTrue(blocked.isEgg)

        let allowed = eggStore(dexJSON: dex, seed: try! XCTUnwrap(shiny))
        await allowed.hatch(baseID: 1)
        XCTAssertEqual(allowed.state.active?.baseID, 1)
        XCTAssertTrue(allowed.currentIsShiny)
    }
}

@MainActor
final class LinearProjectCreditTests: XCTestCase {
    private struct NoProvider: PokeProviding {
        func line(baseSpeciesID: Int) async throws -> EvoLine { throw URLError(.notConnectedToInternet) }
        func baseSpeciesIndex() async throws -> [BaseSpecies] { [] }
        func baseSpecies(id: Int) async throws -> BaseSpecies? { nil }
    }

    func testProjectCreditIsTenTimesIssueAndCountsAsCoins() {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("proj-xp-\(UUID().uuidString).json")
        try? "{\"installBaselineSet\":true,\"usedSinceInstall\":0,\"lastDate\":\"d\",\"dex\":[],\"collectedFinals\":[],\"linearProjectSeeded\":true}".data(using: .utf8)!.write(to: url)
        let s = CompanionStore(provider: NoProvider(), clock: { Date(timeIntervalSince1970: 1) },
                               fileURL: url, rng: SeededRNG(seed: 1))
        let project = LinearCompletedProject(
            id: "p-1", name: "Ship", completedAt: Date(timeIntervalSince1970: 2))
        let outcome = s.creditLinearProjects([project])
        XCTAssertEqual(outcome.xp, LinearRewards.xpPerProject)
        XCTAssertEqual(s.state.bonusXP, LinearRewards.xpPerProject)
        XCTAssertEqual(s.availableCoins, EconomyScale.coinsFromXP(LinearRewards.xpPerProject))
    }
}
