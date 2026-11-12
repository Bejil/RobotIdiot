import XCTest
@testable import RobotIdiotCore

/// V14.1 Aventure : SI/REPETE verrouillés partout, solutions plates, score actions.
final class V14_1AdventureTests: XCTestCase {
    func testSchemaPolicyAndUnlockProgression() throws {
        let pack = try LevelPackLoader.loadBundled()
        XCTAssertEqual(pack.schemaVersion, "14.1")
        let policy = try XCTUnwrap(pack.adventureCommandPolicy)
        XCTAssertEqual(Set(policy.lockedCommands), Set(["SI", "REPETE"]))
        XCTAssertTrue(policy.lockedInEveryWorld)
        XCTAssertFalse(policy.allowLockedCommandsInEditor)
        XCTAssertFalse(policy.allowLockedCommandsInAdventureRuntime)
        XCTAssertTrue(policy.showLockedButtonsInEditor)

        let progression: [[String]] = [
            ["AVANCE", "TOURNE_GAUCHE", "TOURNE_DROITE"],
            ["RECULE"],
            ["RAMASSE"],
            ["UTILISE"],
            ["POUSSE"],
            ["ACTIVE"]
        ]
        for level in pack.levels {
            let expected = Set(progression.prefix(min(level.world, 6)).flatMap { $0 })
            XCTAssertEqual(Set(level.unlockedCommands), expected, level.id)
            XCTAssertTrue(Set(["SI", "REPETE"]).isDisjoint(with: Set(level.unlockedCommands)), level.id)
            if level.world >= 7 {
                XCTAssertNil(level.newCommand, level.id)
            }
            XCTAssertEqual(level.starTargets?.metric, "executedPrimitiveActions", level.id)
        }
    }

    func testAllReferenceProgramsAreFlatPrimitivesAndWin() throws {
        let pack = try LevelPackLoader.loadBundled()
        XCTAssertEqual(pack.levels.count, 150)
        var maxActions = 0
        for source in pack.levels {
            let program = CatalogCampaign.referenceProgram(for: source)
            XCTAssertFalse(program.containsAny(of: [.forever, .ifBlock]), source.id)
            XCTAssertEqual(program.blockCount, source.solution.actionCount, source.id)
            maxActions = max(maxActions, program.blockCount)

            let level = CatalogCampaign.playableLevel(source)
            XCTAssertFalse(level.allowedCommands.contains(.forever), source.id)
            XCTAssertFalse(level.allowedCommands.contains(.ifBlock), source.id)
            XCTAssertTrue(ProgramValidator.issues(in: program, level: level).isEmpty, source.id)

            var engine = SimulationEngine(level: level, program: program)
            let final = engine.runUntilTerminal()
            XCTAssertEqual(final.status, .succeeded, source.id)
            XCTAssertEqual(final.game.metrics.executedInstructions, source.solution.actionCount, source.id)
        }
        XCTAssertEqual(maxActions, 71)
    }

    func testBonusCollectiblesAndStarRoutesPreserved() throws {
        let pack = try LevelPackLoader.loadBundled()
        let bonuses = pack.levels.filter { !($0.rewards?.collectibles ?? []).isEmpty }
        XCTAssertEqual(bonuses.count, 45)
        for source in bonuses {
            XCTAssertEqual(source.rewards?.collectibles.count, 1, source.id)
            XCTAssertNotNil(source.starTargets?.withBonus, source.id)
            let level = CatalogCampaign.playableLevel(source)
            XCTAssertEqual(level.collectibles.count, 1, source.id)
            // Le JSON V14.1 ne fournit pas les programmes « avec écrou » embarqués ;
            // les seuils withBonus restent ceux de la V14.
            XCTAssertEqual(
                level.scoringRules.efficientExecutionMaxStepsWithBonus,
                source.starTargets?.withBonus?.threeStarsMax,
                source.id
            )
        }
    }

    func testLockedCommandsRejectedByEngineAndValidator() throws {
        let source = try XCTUnwrap(CatalogCampaign.pack.levels.first { $0.id == "RI-061" })
        let level = CatalogCampaign.playableLevel(source)
        let locked = Program(instructions: [
            Instruction(command: .forever, children: [Instruction(command: .moveForward)])
        ])
        XCTAssertFalse(ProgramValidator.issues(in: locked, level: level).isEmpty)
        var engine = SimulationEngine(level: level, program: locked)
        let final = engine.runUntilTerminal()
        XCTAssertNotEqual(final.status, .succeeded)
    }

    func testPortalCapAndWorldSizesPreserved() throws {
        let pack = try LevelPackLoader.loadBundled()
        XCTAssertEqual(pack.levels.filter { !($0.rewards?.collectibles ?? []).isEmpty }.count, 45)
        for level in pack.levels {
            XCTAssertLessThanOrEqual(level.portalLinks.count, 3, level.id)
            if level.world < 9 {
                XCTAssertTrue(level.portalLinks.isEmpty, level.id)
            }
            let side = level.world <= 10 ? 7 : 8
            XCTAssertEqual(level.width, side, level.id)
            XCTAssertEqual(level.height, side, level.id)
        }
    }

    func testStarsStillUseExecutedActions() throws {
        let rules = ScoringRules(
            compactProgramMaxBlocks: nil,
            efficientExecutionMaxSteps: 12,
            efficientExecutionMaxStepsWithBonus: 20,
            referenceNote: ""
        )
        let ok = ScoreEvaluator.rating(
            succeeded: true,
            blockCount: 99,
            executedInstructions: 12,
            rules: rules,
            bonusCollected: false
        )
        XCTAssertEqual(ok.count, 3)
        let long = ScoreEvaluator.rating(
            succeeded: true,
            blockCount: 1,
            executedInstructions: 30,
            rules: rules,
            bonusCollected: false
        )
        XCTAssertEqual(long.count, 1)
    }
}
