import XCTest
@testable import RobotIdiotCore

final class RewardV7Tests: XCTestCase {
    func testThirtyBonusLevelsAndSingleCollectibleCap() throws {
        let pack = try LevelPackLoader.loadBundled()
        XCTAssertEqual(pack.schemaVersion, "7.0")
        let bonus = pack.levels.filter { !($0.rewards?.collectibles ?? []).isEmpty }
        let plain = pack.levels.filter { ($0.rewards?.collectibles ?? []).isEmpty }
        XCTAssertEqual(bonus.count, 30)
        XCTAssertEqual(plain.count, 70)
        for level in pack.levels {
            XCTAssertLessThanOrEqual(level.rewards?.collectibles.count ?? 0, 1, level.id)
        }
        XCTAssertEqual(LevelPackChecker.issues(in: pack), [])
    }

    func testStarTargetsMatchValidationRoutes() throws {
        let pack = try LevelPackLoader.loadBundled()
        let url = try XCTUnwrap(
            Bundle.module.url(forResource: "robot_idiot_v7_validation", withExtension: "json")
        )
        let data = try Data(contentsOf: url)
        let validation = try JSONDecoder().decode(V7ValidationFile.self, from: data)
        XCTAssertEqual(validation.bonusLevels, 30)
        for result in validation.levelResults {
            let level = try XCTUnwrap(pack.levels.first { $0.id == result.id })
            let stars = try XCTUnwrap(level.starTargets)
            XCTAssertEqual(stars.withoutBonus.threeStarsMax, result.directOptimal, result.id)
            XCTAssertEqual(stars.withBonus?.threeStarsMax, result.withBonusOptimal, result.id)
            XCTAssertEqual(level.rewards?.collectibles.first?.x, result.bonus[0], result.id)
            XCTAssertEqual(level.rewards?.collectibles.first?.y, result.bonus[1], result.id)
        }
        for result in validation.noBonusResults {
            let level = try XCTUnwrap(pack.levels.first { $0.id == result.id })
            XCTAssertEqual(level.starTargets?.withoutBonus.threeStarsMax, result.optimal, result.id)
            XCTAssertNil(level.starTargets?.withBonus, result.id)
        }
    }

    func testAutoPickupDoesNotCostAnAction() throws {
        let source = try XCTUnwrap(CatalogCampaign.pack.levels.first { $0.id == "RI-004" })
        let level = CatalogCampaign.playableLevel(source)
        XCTAssertEqual(level.collectibles.count, 1)
        let bolt = try XCTUnwrap(level.collectibles.first)
        var game = GameState.initial(from: level)
        // Place the robot next to the bolt and step onto it.
        let toward = bolt.position
        game.robot.position = GridCoordinate(x: toward.x - 1, y: toward.y)
        game.robot.orientation = .east
        let before = game.metrics.executedInstructions
        guard case .success(let applied) = WorldRules.apply(command: .moveForward, to: game, level: level) else {
            return XCTFail("move")
        }
        XCTAssertEqual(applied.game.metrics.executedInstructions, before + 1)
        XCTAssertTrue(applied.game.collectedBonusThisAttempt)
        XCTAssertTrue(applied.game.remainingCollectibles.isEmpty)
        XCTAssertEqual(applied.game.collectedThisAttempt.first?.id, bolt.id)
    }

    func testStarsUseBonusThresholdWhenCollected() throws {
        let rules = ScoringRules(
            compactProgramMaxBlocks: nil,
            efficientExecutionMaxSteps: 8,
            efficientExecutionMaxStepsWithBonus: 14,
            referenceNote: ""
        )
        let without = ScoreEvaluator.rating(
            succeeded: true,
            blockCount: 4,
            executedInstructions: 8,
            rules: rules,
            bonusCollected: false
        )
        XCTAssertEqual(without.count, 3)
        let withTooLong = ScoreEvaluator.rating(
            succeeded: true,
            blockCount: 4,
            executedInstructions: 14,
            rules: rules,
            bonusCollected: false
        )
        XCTAssertEqual(withTooLong.count, 1)
        let withBonus = ScoreEvaluator.rating(
            succeeded: true,
            blockCount: 4,
            executedInstructions: 14,
            rules: rules,
            bonusCollected: true
        )
        XCTAssertEqual(withBonus.count, 3)
    }

    func testFailedAttemptDoesNotKeepCollectionAcrossReset() throws {
        let source = try XCTUnwrap(CatalogCampaign.pack.levels.first { $0.id == "RI-004" })
        let level = CatalogCampaign.playableLevel(source)
        var engine = SimulationEngine(level: level, program: Program(instructions: [
            Instruction(command: .moveForward)
        ]))
        _ = engine.runUntilTerminal()
        engine.reset(program: Program())
        XCTAssertFalse(engine.state.game.collectedBonusThisAttempt)
        XCTAssertEqual(engine.state.game.remainingCollectibles.count, level.collectibles.count)
    }

    func testOfficialSolutionsWinWithoutRequiringBonus() throws {
        for source in CatalogCampaign.pack.levels {
            let level = CatalogCampaign.playableLevel(source)
            var engine = SimulationEngine(level: level, program: CatalogCampaign.referenceProgram(for: source))
            let final = engine.runUntilTerminal()
            XCTAssertEqual(final.status, .succeeded, source.id)
            XCTAssertTrue(final.game.isVictory, source.id)
            // Trois étoiles restent atteignables via le seuil du parcours suivi.
            let rating = ScoreEvaluator.rating(
                succeeded: true,
                blockCount: CatalogCampaign.referenceProgram(for: source).blockCount,
                executedInstructions: final.game.metrics.executedInstructions,
                rules: level.scoringRules,
                bonusCollected: final.game.collectedBonusThisAttempt
            )
            XCTAssertGreaterThanOrEqual(rating.count, 1, source.id)
            if let maxSteps = level.scoringRules.efficientLimit(bonusCollected: final.game.collectedBonusThisAttempt),
               final.game.metrics.executedInstructions <= maxSteps {
                XCTAssertEqual(rating.count, 3, source.id)
            }
        }
    }

    func testBonusOverlaysGrassAndAwardsTwoBolts() throws {
        let pack = try LevelPackLoader.loadBundled()
        for source in pack.levels {
            guard let item = source.rewards?.collectibles.first else { continue }
            XCTAssertEqual(item.type, "BoardBolt", source.id)
            XCTAssertEqual(item.amount, RewardEconomy.defaultAwardAmount, source.id)
            XCTAssertTrue(item.optional, source.id)
            let cell = Array(source.grid[item.y])[item.x]
            XCTAssertEqual(cell, "g", "\(source.id) bolt must overlay grass at \(item.x),\(item.y)")
            let level = CatalogCampaign.playableLevel(source)
            XCTAssertEqual(level.collectibles.count, 1, source.id)
            XCTAssertEqual(level.scoringRules.efficientExecutionMaxStepsWithBonus, source.starTargets?.withBonus?.threeStarsMax, source.id)
        }
        XCTAssertEqual(RewardEconomy.hintCost, 3)
        XCTAssertEqual(RewardEconomy.adFreeRetryCost, 1)
        XCTAssertEqual(RewardEconomy.fullSolutionCost, 6)
    }
}

private struct V7ValidationFile: Decodable {
    var bonusLevels: Int
    var levelResults: [BonusResult]
    var noBonusResults: [PlainResult]

    struct BonusResult: Decodable {
        var id: String
        var bonus: [Int]
        var directOptimal: Int
        var withBonusOptimal: Int
    }

    struct PlainResult: Decodable {
        var id: String
        var optimal: Int
    }
}
