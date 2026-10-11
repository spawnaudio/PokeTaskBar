import XCTest
@testable import PokeTaskBar

final class RepeatCatchTrainingTests: XCTestCase {
    private func candidate(_ base: Int = 1, form: String? = nil,
                           shiny: Bool = false, ditto: Bool = false) -> RepeatCatchTraining.Candidate {
        .init(baseID: base, form: form, isShiny: shiny, isUnrevealedDitto: ditto)
    }

    func testNormalRepeatSelectsFirstMatchingUnfinishedIndividual() {
        let incoming = candidate()
        let stored: [RepeatCatchTraining.Candidate?] = [nil, candidate(4), candidate(), candidate()]
        XCTAssertEqual(RepeatCatchTraining.targetIndex(for: incoming, stored: stored), 2)
    }

    func testEveryShinyCatchCreatesAnotherIndividual() {
        XCTAssertNil(RepeatCatchTraining.targetIndex(for: candidate(shiny: true),
                                                     stored: [candidate(), candidate(shiny: true)]))
    }

    func testNormalCatchNeverAbsorbsIntoShiny() {
        XCTAssertNil(RepeatCatchTraining.targetIndex(for: candidate(), stored: [candidate(shiny: true)]))
        XCTAssertEqual(RepeatCatchTraining.targetIndex(for: candidate(),
                                                       stored: [candidate(shiny: true), candidate()]), 1)
    }

    func testUnownRequiresExactResolvedLetter() {
        XCTAssertNil(RepeatCatchTraining.targetIndex(for: candidate(201, form: "a"),
                                                     stored: [candidate(201, form: "b")]))
        XCTAssertEqual(RepeatCatchTraining.targetIndex(for: candidate(201, form: "b"),
                                                       stored: [candidate(201, form: "a"), candidate(201, form: "b")]), 1)
    }

    func testHiddenDittoNeverAbsorbsDisguiseSpecies() {
        XCTAssertNil(RepeatCatchTraining.targetIndex(for: candidate(1, ditto: true), stored: [candidate()]))
        XCTAssertNil(RepeatCatchTraining.targetIndex(for: candidate(), stored: [candidate(1, ditto: true)]))
        XCTAssertEqual(RepeatCatchTraining.targetIndex(for: candidate(),
                                                       stored: [candidate(1, ditto: true), candidate()]), 1)
    }

    func testNoUnfinishedPartnerCreatesCatchRegardlessOfHistory() {
        XCTAssertNil(RepeatCatchTraining.targetIndex(for: candidate(), stored: []))
        XCTAssertNil(RepeatCatchTraining.targetIndex(for: candidate(), stored: [nil]))
    }

    func testCreditAdditionPreservesIncubationAndOverflowAndBoundsImportedValues() {
        XCTAssertEqual(RepeatCatchTraining.addingCredit(50_123, to: 200), 50_323)
        XCTAssertEqual(RepeatCatchTraining.addingCredit(Int.max, to: Int.max), RepeatCatchTraining.maxCredit)
        XCTAssertEqual(RepeatCatchTraining.addingCredit(-100, to: -200), 0)
    }

    func testDifficultyRepricingPreservesBankedFractionAcrossSliderChanges() {
        let hard = RepeatCatchTraining.repricedUsage(250, oldThreshold: 500, newThreshold: 2_000)
        XCTAssertEqual(hard, 1_000)
        let easy = RepeatCatchTraining.repricedUsage(hard, oldThreshold: 2_000, newThreshold: 100)
        XCTAssertEqual(easy, 50)
        XCTAssertEqual(RepeatCatchTraining.standardGrowth(completed: 100, currentUsage: easy,
            adjustedThreshold: 100, standardPhase: 500, graduationTotal: 1_000), 350)
    }

    func testRepricingNeverCompletesAnIncompleteStageOrEgg() {
        XCTAssertEqual(RepeatCatchTraining.repricedUsage(999, oldThreshold: 1_000, newThreshold: 1), 0)
        XCTAssertEqual(RepeatCatchTraining.repricedUsage(1_500, oldThreshold: 1_000, newThreshold: 100), 150)
    }

    func testStandardGrowthAccountsForCompletedStagesDifficultyAndBoost() {
        XCTAssertEqual(RepeatCatchTraining.standardGrowth(completed: 250, currentUsage: 250,
            adjustedThreshold: 500, standardPhase: 1_000, graduationTotal: 2_000), 750)
        XCTAssertEqual(RepeatCatchTraining.standardGrowth(completed: 250, currentUsage: 250,
            adjustedThreshold: 2_000, standardPhase: 1_000, graduationTotal: 2_000), 375)
    }

    func testStandardGrowthCapsCurrentPhaseUntilEvolutionProcessesOverflow() {
        XCTAssertEqual(RepeatCatchTraining.standardGrowth(completed: 250, currentUsage: 10_000,
            adjustedThreshold: 500, standardPhase: 1_000, graduationTotal: 2_000), 1_250)
        XCTAssertEqual(RepeatCatchTraining.standardGrowth(completed: 1_750, currentUsage: Int.max,
            adjustedThreshold: 500, standardPhase: 1_000, graduationTotal: 2_000), 2_000)
    }
}
