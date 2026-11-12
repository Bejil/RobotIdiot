import XCTest
@testable import RobotIdiotCore

/// Mondes 7 (conditions) et 8 (boucles) : conditions environnementales et boucles.
final class ConditionsAndLoopsWorldTests: XCTestCase {
    private var worldLevels: [CatalogLevel] {
        CatalogCampaign.pack.levels.filter { $0.world == 7 || $0.world == 8 }
    }

    // MARK: - Conditions

    func testFacingConditionsFollowTheRobotOrientation() throws {
        let source = board([
            "gKgUgCg",
            "ggggggg",
            "ggggggg",
            "ggggggg",
            "ggggggg",
            "ggggggg",
            "^ggggFg"
        ], mechanics: [("BoardKey", 1, 0), ("BoardLock", 3, 0), ("BoardCrate", 5, 0)])
        let level = CatalogCampaign.playableLevel(source)

        func game(_ x: Int, _ y: Int, _ facing: Direction) -> GameState {
            var state = GameState.initial(from: level)
            state.robot.position = GridCoordinate(x: x, y: 6 - y)
            state.robot.orientation = facing
            return state
        }

        XCTAssertTrue(ConditionEvaluator.evaluate(.keyAhead, game: game(0, 0, .east)))
        XCTAssertFalse(ConditionEvaluator.evaluate(.keyAhead, game: game(0, 0, .south)))
        XCTAssertFalse(ConditionEvaluator.evaluate(.crateAhead, game: game(0, 0, .east)))
        XCTAssertTrue(ConditionEvaluator.evaluate(.lockAhead, game: game(2, 0, .east)))
        XCTAssertTrue(ConditionEvaluator.evaluate(.obstacleAhead, game: game(2, 0, .east)))
        XCTAssertFalse(ConditionEvaluator.evaluate(.lockAhead, game: game(2, 0, .west)))
        XCTAssertTrue(ConditionEvaluator.evaluate(.crateAhead, game: game(4, 0, .east)))
        XCTAssertTrue(ConditionEvaluator.evaluate(.crateAhead, game: game(6, 0, .west)))
        XCTAssertFalse(ConditionEvaluator.evaluate(.crateAhead, game: game(6, 0, .south)))
        XCTAssertTrue(ConditionEvaluator.evaluate(.obstacleAhead, game: game(0, 0, .north)), "le bord compte comme obstacle")
    }

    func testPackHasNoMarkersOrPortals() {
        for level in CatalogCampaign.pack.levels {
            let joined = level.grid.joined()
            XCTAssertFalse(joined.contains("c"), level.id)
            XCTAssertFalse(joined.contains("l"), level.id)
            XCTAssertFalse(joined.contains(where: \.isNumber), level.id)
            let playable = CatalogCampaign.playableLevel(level)
            XCTAssertFalse(playable.grid.cells.contains { $0.terrain.rawValue.contains("marker") }, level.id)
        }
    }

    func testLoopOfFalseConditionsStopsInsteadOfHanging() {
        let source = board([
            "gggFggg",
            "ggggggg",
            "ggggggg",
            "ggggggg",
            "ggggggg",
            "ggggggg",
            ">gggggg"
        ], program: [.repete([.si(condition: "SI_CLE_DEVANT", body: [.avance])])])
        XCTAssertEqual(CatalogInterpreter.execute(source).result, .infiniteCycle)
    }

    func testConstraintsAreReachableWithoutControlFlowUnlocks() throws {
        for source in worldLevels {
            let level = CatalogCampaign.playableLevel(source)
            let reference = CatalogCampaign.referenceProgram(for: source)
            XCTAssertEqual(ProgramValidator.issues(in: reference, level: level), [], source.id)
            // V14.1 Aventure : SI/REPETE restent verrouillés aux mondes 7–8.
            XCTAssertFalse(source.unlockedCommands.contains("REPETE"), source.id)
            XCTAssertFalse(source.unlockedCommands.contains("SI"), source.id)
            XCTAssertFalse(reference.containsAny(of: [.forever, .ifBlock]), source.id)
        }
    }

    func testBonusLevelsKeepTwoReferenceTargets() throws {
        let bonus = worldLevels.filter { !($0.rewards?.collectibles ?? []).isEmpty }.map(\.id)
        XCTAssertFalse(bonus.isEmpty)
        for id in bonus {
            let source = try XCTUnwrap(worldLevels.first { $0.id == id })
            let stars = try XCTUnwrap(source.starTargets?.withBonus, id)
            XCTAssertGreaterThan(stars.threeStarsMax, source.starTargets!.withoutBonus.threeStarsMax, id)
        }
    }

    // MARK: - Aides

    private func board(
        _ grid: [String],
        mechanics: [(String, Int, Int)] = [],
        links: [String] = [],
        program: [CatalogInstruction] = [.avance]
    ) -> CatalogLevel {
        var level = CatalogCampaign.pack.levels.first { $0.id == "RI-061" }!
        level.grid = grid
        for (y, row) in grid.enumerated() {
            for (x, symbol) in row.enumerated() {
                if let orientation = ["^": "N", ">": "E", "v": "S", "<": "W"][String(symbol)] {
                    level.start = CatalogLevel.Start(x: x, y: y, orientation: orientation)
                }
                if symbol == "F" {
                    level.finish = CatalogLevel.Finish(x: x, y: y)
                }
            }
        }
        level.mechanics = mechanics.map { type, x, y in
            CatalogLevel.Mechanic(type: type, x: x, y: y, linkId: ["BoardDoor", "BoardPlate"].contains(type) ? links.first : nil)
        }
        level.unlockedCommands = ["AVANCE", "TOURNE_GAUCHE", "TOURNE_DROITE", "RECULE", "RAMASSE", "UTILISE", "POUSSE", "ACTIVE", "REPETE", "SI"]
        level.rewards = nil
        level.starTargets = nil
        level.solution.program = program
        return level
    }
}
