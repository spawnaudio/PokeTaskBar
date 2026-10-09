import XCTest
@testable import PokeTaskBar

private actor HatchRetryProvider: PokeProviding {
    let duplicatesOnly: Bool
    let offline: Bool
    private(set) var requestedIDs: [Int] = []

    init(duplicatesOnly: Bool = false, offline: Bool = false) {
        self.duplicatesOnly = duplicatesOnly
        self.offline = offline
    }

    func baseSpeciesIndex() async throws -> [BaseSpecies] {
        [BaseSpecies(id: duplicatesOnly ? 1 : 4, captureRate: 255)]
    }

    func line(baseSpeciesID: Int) async throws -> EvoLine {
        requestedIDs.append(baseSpeciesID)
        if offline { throw URLError(.notConnectedToInternet) }
        return EvoLine(baseID: baseSpeciesID, tree: EvoNode(speciesID: baseSpeciesID, children: [
            EvoNode(speciesID: baseSpeciesID + 1, children: [
                EvoNode(speciesID: baseSpeciesID + 2, children: [])
            ])
        ]), rarity: .common, names: [:])
    }
}

@MainActor
final class EggHatchRetryTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_700_000_000)
    private let day = "2026-09-06"

    private func makeStore(_ provider: HatchRetryProvider) throws -> CompanionStore {
        var state = CompanionState()
        state.installBaselineSet = true
        state.lastDate = day
        state.claimedTodayTokensByProvider = ["test": 0]
        state.pendingHatchID = 1
        state.lastTimeOpenAwardAt = now.addingTimeInterval(-TimeOpenXP.awardIntervalSeconds)
        state.timeOpenAwardDay = day
        state.dex = [DexEntry(baseID: 1, finalID: 3, chainOrder: [1, 2, 3],
                              rarity: .common, caughtAt: now, isShiny: true)]
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("hatch-retry-\(UUID().uuidString).json")
        try JSONEncoder().encode(state).write(to: url)
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        let suite = "hatch-retry-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.set(1.0, forKey: "growthDifficulty")
        addTeardownBlock { defaults.removePersistentDomain(forName: suite) }
        return CompanionStore(provider: provider, clock: { self.now }, fileURL: url,
                              rng: SeededRNG(seed: 1), dittoDisguiseRollingEnabled: false,
                              defaults: defaults)
    }

    private func waitForHatch(_ store: CompanionStore) async {
        let deadline = Date().addingTimeInterval(1)
        while store.state.active == nil, Date() < deadline {
            try? await Task.sleep(for: .milliseconds(1))
        }
    }

    func testTimeOpenAwardRerollsOwnedPendingSpeciesWithoutAnotherRefresh() async throws {
        let provider = HatchRetryProvider()
        let store = try makeStore(provider)
        store.awardTimeOpenXP(today: day, enabled: true)
        await waitForHatch(store)

        XCTAssertEqual(store.state.active?.baseID, 4)
        XCTAssertEqual(store.state.eggUsage, 0)
        XCTAssertEqual(store.state.timeOpenAwardedToday, TimeOpenXP.tokensPerAward)
        XCTAssertEqual(store.state.bonusXP, TimeOpenXP.tokensPerAward)
        XCTAssertEqual(store.state.usedSinceInstall, 0)
        let ids = await provider.requestedIDs
        XCTAssertEqual(ids, [1, 4])
        XCTAssertEqual(store.state.dex.count, 1, "reject the duplicate without touching the collection")
    }

    func testAllXPPathsRerollDuplicateAndPreserveOverflow() async throws {
        for source: XPReward.Source in [.tokens, .focus, .issue, .project] {
            let provider = HatchRetryProvider()
            let store = try makeStore(provider)
            let xp = PokemonBalance.eggHatchThreshold + 123
            if source == .tokens {
                store.creditEarnedXP(xp, fromTokens: true)
            } else {
                store.applyProgressXP(xp, source: source)
            }
            await waitForHatch(store)

            XCTAssertEqual(store.state.active?.baseID, 4, "\(source)")
            XCTAssertEqual(store.state.active?.usedAtStage, 123, "\(source)")
            XCTAssertEqual(store.lifetimeXP, xp, "retries must not award XP again")
        }
    }

    func testDuplicateOnlyPoolStopsAndKeepsReadyEggForLaterRetry() async throws {
        let provider = HatchRetryProvider(duplicatesOnly: true)
        let store = try makeStore(provider)
        store.applyProgressXP(PokemonBalance.eggHatchThreshold)
        await store.hatchIfNeeded()

        XCTAssertTrue(store.isEgg)
        XCTAssertTrue(store.isHatchRetryDelayed)
        XCTAssertEqual(store.state.eggUsage, PokemonBalance.eggHatchThreshold)
        let ids = await provider.requestedIDs
        XCTAssertEqual(ids.count, 16, "a completed collection must not cause an endless retry loop")
    }

    func testNetworkFailureDoesNotRepeatRequestsOrConsumeEggXP() async throws {
        let provider = HatchRetryProvider(offline: true)
        let store = try makeStore(provider)
        store.applyProgressXP(PokemonBalance.eggHatchThreshold)
        await store.hatchIfNeeded()

        XCTAssertTrue(store.isHatchRetryDelayed)
        XCTAssertEqual(store.state.eggUsage, PokemonBalance.eggHatchThreshold)
        let ids = await provider.requestedIDs
        XCTAssertEqual(ids, [1])
    }
}
