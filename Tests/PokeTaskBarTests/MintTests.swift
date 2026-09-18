import XCTest
@testable import PokeTaskBar

// MARK: Mint — timed 2× XP, not a nature reroll

private struct MintNoProvider: PokeProviding {
    func line(baseSpeciesID: Int) async throws -> EvoLine { throw URLError(.notConnectedToInternet) }
    func baseSpeciesIndex() async throws -> [BaseSpecies] { [] }
    func baseSpecies(id: Int) async throws -> BaseSpecies? { nil }
}

@MainActor
final class MintTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    private func store(nature: String? = "adamant", mint: Int = 1, used: Int = 1_000_000_000,
                       spent: Int = 0, usedAtStage: Int = 50_000_000, shiny: Bool = false,
                       seed: UInt64 = 7, clock: (() -> Date)? = nil) -> CompanionStore {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("mint-\(UUID().uuidString).json")
        let natureField = nature.map { ",\"nature\":\"\($0)\"" } ?? ""
        let active = "{\"baseID\":1,\"pathIDs\":[1],\"stageIndex\":0,\"usedAtStage\":\(usedAtStage),"
            + "\"rarity\":\"common\",\"totalForms\":3,\"isShiny\":\(shiny)\(natureField)}"
        let inv = mint > 0 ? ",\"inventory\":{\"mint\":\(mint)}" : ""
        let json = "{\"installBaselineSet\":true,\"usedSinceInstall\":\(used),\"spentTokens\":\(spent),"
            + "\"lastDate\":\"d\",\"active\":\(active),\"dex\":[],\"collectedFinals\":[]\(inv)}"
        try? json.data(using: .utf8)!.write(to: url)
        let tick = clock ?? { self.now }
        return CompanionStore(provider: MintNoProvider(), clock: tick, fileURL: url, rng: SeededRNG(seed: seed))
    }

    func testUseMintActivatesMultiplierWithoutChangingIdentity() {
        let s = store(nature: "adamant", mint: 1, usedAtStage: 50_000_000, shiny: true)
        XCTAssertEqual(s.state.active?.nature, .adamant)
        XCTAssertTrue(s.useMint())
        XCTAssertEqual(s.state.active?.nature, .adamant, "민트는 성격 리롤이 아니다")
        XCTAssertEqual(s.itemCount(.mint), 0)
        XCTAssertTrue(s.mintIsActive)
        XCTAssertEqual(s.mintMultiplier, 2)
        XCTAssertEqual(s.state.active?.usedAtStage, 50_000_000)
        XCTAssertTrue(s.currentIsShiny)
        XCTAssertEqual(s.currentSpeciesID, 1)
    }

    func testMintCanBeUsedOnEgg() {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("mint-egg-\(UUID().uuidString).json")
        let json = "{\"installBaselineSet\":true,\"usedSinceInstall\":1,\"lastDate\":\"d\","
            + "\"dex\":[],\"collectedFinals\":[],\"inventory\":{\"mint\":2}}"
        try? json.data(using: .utf8)!.write(to: url)
        let s = CompanionStore(provider: MintNoProvider(), clock: { self.now }, fileURL: url, rng: SeededRNG(seed: 1))
        XCTAssertTrue(s.isEgg)
        XCTAssertTrue(s.canUseMint)
        XCTAssertTrue(s.useMint())
        XCTAssertEqual(s.itemCount(.mint), 1)
        XCTAssertTrue(s.mintIsActive)
        XCTAssertTrue(s.isEgg)
    }

    func testCannotUseMintWithoutStock() {
        let s = store(nature: "adamant", mint: 0)
        XCTAssertFalse(s.canUseMint)
        XCTAssertFalse(s.useMint())
    }

    func testMintDoublesIncomingXPAndExpires() {
        var t = now
        let s = store(mint: 1, clock: { t })
        XCTAssertTrue(s.useMint())
        s.creditEarnedXP(1_000, fromTokens: false)
        XCTAssertEqual(s.state.bonusXP, 2_000)
        t = now.addingTimeInterval(Mint.duration + 1)
        XCTAssertFalse(s.mintIsActive)
        XCTAssertEqual(s.mintMultiplier, 1)
        s.creditEarnedXP(1_000, fromTokens: false)
        XCTAssertEqual(s.state.bonusXP, 3_000)
    }

    func testTokenMintSurplusGoesToBonusXP() {
        let s = store(mint: 1, used: 0)
        XCTAssertTrue(s.useMint())
        s.creditEarnedXP(1_000, fromTokens: true)
        XCTAssertEqual(s.state.usedSinceInstall, 1_000)
        XCTAssertEqual(s.state.bonusXP, 1_000)
        XCTAssertEqual(s.lifetimeXP, 2_000)
    }

    func testMintFeedbackSeqIncrements() {
        let s = store(mint: 1)
        let before = s.mintFeedbackSeq
        XCTAssertTrue(s.useMint())
        XCTAssertEqual(s.mintFeedbackSeq, before + 1)
        s.consumeMintFeedback()
        XCTAssertEqual(s.mintFeedbackSeq, before + 1)
    }

    func testUseMintPersistsAcrossRestart() {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("mint-persist-\(UUID().uuidString).json")
        let json = "{\"installBaselineSet\":true,\"usedSinceInstall\":1,\"lastDate\":\"d\","
            + "\"active\":{\"baseID\":1,\"pathIDs\":[1],\"stageIndex\":0,\"usedAtStage\":0,\"rarity\":\"common\",\"totalForms\":3,\"nature\":\"adamant\"},"
            + "\"inventory\":{\"mint\":2},\"dex\":[],\"collectedFinals\":[]}"
        try? json.data(using: .utf8)!.write(to: url)
        let s1 = CompanionStore(provider: MintNoProvider(), clock: { self.now }, fileURL: url, rng: SeededRNG(seed: 3))
        XCTAssertTrue(s1.useMint())
        XCTAssertEqual(s1.state.active?.nature, .adamant)

        let s2 = CompanionStore(provider: MintNoProvider(), clock: { self.now }, fileURL: url, rng: SeededRNG(seed: 3))
        XCTAssertEqual(s2.state.active?.nature, .adamant)
        XCTAssertEqual(s2.itemCount(.mint), 1)
        XCTAssertTrue(s2.mintIsActive)
        XCTAssertEqual(s2.state.active?.stageIndex, 0)
    }

    func testMintShopPriceAndPurchasable() {
        XCTAssertEqual(ItemKind.mint.shopPrice, Mint.price)
        XCTAssertEqual(Mint.price, 1_000)
        XCTAssertEqual(ItemKind.mint.shopPrice, EconomyScale.coins(100_000_000))
        let s = store(mint: 0)
        XCTAssertTrue(s.purchasableItems.contains(.rareCandy))
        XCTAssertTrue(s.purchasableItems.contains(.mint))
    }

    func testBuyMintDebitsWalletAndCredits() {
        let s = store(mint: 0, used: EconomyScale.xpForCoins(2_000))
        XCTAssertTrue(s.canBuy(.mint))
        XCTAssertTrue(s.buy(.mint))
        XCTAssertEqual(s.itemCount(.mint), 1)
        XCTAssertEqual(s.state.spentTokens, Mint.price)
        XCTAssertEqual(s.availableCoins, 2_000 - Mint.price)
    }

    func testCannotBuyMintBelowPrice() {
        let s = store(mint: 0, used: EconomyScale.xpForCoins(Mint.price) - 1)
        XCTAssertFalse(s.canBuy(.mint))
        XCTAssertFalse(s.buy(.mint))
        XCTAssertEqual(s.itemCount(.mint), 0)
    }
}
