import XCTest
@testable import RobotIdiotCore

/// Spotlight V14.1 (dérivé du rollback V14) : portails, primitives, score actions.
final class V14RollbackSpotlightTests: XCTestCase {
    private let spotlightIDs = [
        "RI-061", "RI-070", "RI-071", "RI-080",
        "RI-081", "RI-082", "RI-083", "RI-090",
        "RI-100", "RI-101", "RI-140", "RI-150"
    ]

    func testSchemaAndScoreMetricAreV14_1() throws {
        let pack = try LevelPackLoader.loadBundled()
        XCTAssertEqual(pack.schemaVersion, "14.1")
        XCTAssertEqual(LevelPack.supportedSchemaVersion, "14.1")
        for level in pack.levels {
            XCTAssertEqual(level.starTargets?.metric, "executedPrimitiveActions", level.id)
        }
        XCTAssertEqual(CatalogCampaign.contentRevision, "V14.1-aventure")
    }

    func testWorld7And8DoNotUnlockControlFlow() throws {
        let pack = try LevelPackLoader.loadBundled()
        for level in pack.levels where (7...15).contains(level.world) {
            XCTAssertFalse(level.unlockedCommands.contains("REPETE"), level.id)
            XCTAssertFalse(level.unlockedCommands.contains("SI"), level.id)
        }
    }

    func testAllReferenceProgramsWinOnEngine() throws {
        let pack = try LevelPackLoader.loadBundled()
        XCTAssertEqual(pack.levels.count, 150)
        var wins = 0
        for source in pack.levels {
            let level = CatalogCampaign.playableLevel(source)
            var engine = SimulationEngine(level: level, program: CatalogCampaign.referenceProgram(for: source))
            let final = engine.runUntilTerminal()
            XCTAssertEqual(final.status, .succeeded, source.id)
            XCTAssertTrue(final.game.isVictory, source.id)
            XCTAssertEqual(
                final.game.metrics.executedInstructions,
                source.solution.actionCount,
                "\(source.id) actions"
            )
            wins += 1
        }
        XCTAssertEqual(wins, 150)
    }

    func testSpotlightLevelsWinAndMatchPortalExpectations() throws {
        let pack = try LevelPackLoader.loadBundled()
        for id in spotlightIDs {
            let source = try XCTUnwrap(pack.levels.first { $0.id == id }, id)
            let level = CatalogCampaign.playableLevel(source)
            var engine = SimulationEngine(level: level, program: CatalogCampaign.referenceProgram(for: source))
            let final = engine.runUntilTerminal()
            XCTAssertEqual(final.status, .succeeded, id)
            XCTAssertEqual(final.game.metrics.executedInstructions, source.solution.actionCount, id)
            XCTAssertFalse(source.unlockedCommands.contains("REPETE"), id)
            XCTAssertFalse(source.unlockedCommands.contains("SI"), id)

            switch id {
            case "RI-061", "RI-070", "RI-071", "RI-080":
                XCTAssertTrue(source.portalLinks.isEmpty, id)
            case "RI-081":
                XCTAssertEqual(source.portalLinks.count, 1, id)
            case "RI-082":
                XCTAssertEqual(source.portalLinks.count, 2, id)
            case "RI-083", "RI-090", "RI-100", "RI-101", "RI-140", "RI-150":
                XCTAssertEqual(source.portalLinks.count, 3, id)
                XCTAssertEqual(Set(source.portalLinks.map(\.visualVariant)), Set(["A", "B", "C"]), id)
            default:
                break
            }

            if source.world >= 11 {
                XCTAssertEqual(source.width, 8, id)
                XCTAssertEqual(source.height, 8, id)
            } else {
                XCTAssertEqual(source.width, 7, id)
                XCTAssertEqual(source.height, 7, id)
            }
        }
    }

    func testStarsUseExecutedPrimitiveActionsNotBlockCount() throws {
        let rules = ScoringRules(
            compactProgramMaxBlocks: nil,
            efficientExecutionMaxSteps: 10,
            efficientExecutionMaxStepsWithBonus: 16,
            referenceNote: ""
        )
        let short = ScoreEvaluator.rating(
            succeeded: true,
            blockCount: 99,
            executedInstructions: 10,
            rules: rules,
            bonusCollected: false
        )
        XCTAssertEqual(short.count, 3)
        let long = ScoreEvaluator.rating(
            succeeded: true,
            blockCount: 1,
            executedInstructions: 20,
            rules: rules,
            bonusCollected: false
        )
        XCTAssertEqual(long.count, 1)
        let withBonus = ScoreEvaluator.rating(
            succeeded: true,
            blockCount: 1,
            executedInstructions: 16,
            rules: rules,
            bonusCollected: true
        )
        XCTAssertEqual(withBonus.count, 3)
    }

    func testCrateCannotEnterPortal() throws {
        let source = try XCTUnwrap(CatalogCampaign.pack.levels.first { $0.id == "RI-090" })
        let level = CatalogCampaign.playableLevel(source)
        guard let portal = level.portalLinks.first?.endpoints.first else {
            return XCTFail("portail attendu")
        }
        let crateCell = GridCoordinate(x: portal.x - 1, y: portal.y)
        let robotCell = GridCoordinate(x: portal.x - 2, y: portal.y)
        var game = GameState.initial(from: level)
        game.robot.position = robotCell
        game.robot.orientation = .east
        game.grid.updateCell(at: crateCell) { cell in
            cell.objects = [PlacedObject(id: "crate-test", kind: ObjectKind.crate)]
        }
        let result = WorldRules.apply(command: .push, to: game, level: level)
        if case .success = result {
            XCTFail("pousser une caisse dans un portail ne doit pas réussir")
        }
    }
}
