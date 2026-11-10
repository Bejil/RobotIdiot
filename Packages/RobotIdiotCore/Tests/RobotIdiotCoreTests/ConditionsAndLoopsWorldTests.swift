import XCTest
@testable import RobotIdiotCore

/// Mondes 7 (conditions) et 8 (boucles) : conditions, balises, contraintes et optimalité.
final class ConditionsAndLoopsWorldTests: XCTestCase {
    private var worldLevels: [CatalogLevel] {
        CatalogCampaign.pack.levels.filter { $0.world == 7 || $0.world == 8 }
    }

    // MARK: - Conditions

    func testFacingConditionsFollowTheRobotOrientation() throws {
        let source = board([
            "gKgUgCg",
            "cglgggg",
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
        XCTAssertTrue(ConditionEvaluator.evaluate(.onCircle, game: game(0, 1, .north)))
        XCTAssertFalse(ConditionEvaluator.evaluate(.onDiamond, game: game(0, 1, .north)))
        XCTAssertTrue(ConditionEvaluator.evaluate(.onDiamond, game: game(2, 1, .east)))
        XCTAssertFalse(ConditionEvaluator.evaluate(.onCircle, game: game(1, 1, .east)))
        XCTAssertTrue(ConditionEvaluator.evaluate(.obstacleAhead, game: game(0, 0, .north)), "le bord compte comme obstacle")
    }

    func testMarkersAreWalkableAndHarmless() {
        XCTAssertFalse(TerrainType.markerCircle.blocksMovement)
        XCTAssertFalse(TerrainType.markerDiamond.blocksMovement)
        XCTAssertFalse(TerrainType.markerCircle.isLethal)
        XCTAssertFalse(TerrainType.markerDiamond.isLethal)
        let level = CatalogCampaign.playableLevel(worldLevels.first { $0.id == "RI-062" }!)
        let markers = level.grid.cells.filter { $0.terrain == .markerCircle || $0.terrain == .markerDiamond }
        XCTAssertFalse(markers.isEmpty)
    }

    func testBothEnginesFollowMarkersInsideALoop() {
        let source = board([
            "gggFggg",
            "ggggggg",
            "ggggggg",
            "ggggggg",
            "ggggggg",
            "ggggggg",
            ">ggcggg"
        ], program: [
            .repete([.si(condition: "SI_SUR_CERCLE", body: [.tourneGauche]), .avance])
        ])
        let catalog = CatalogInterpreter.execute(source)
        XCTAssertEqual(catalog.result, .victory)
        XCTAssertEqual(catalog.actions, 10)

        var engine = SimulationEngine(
            level: CatalogCampaign.playableLevel(source),
            program: CatalogCampaign.referenceProgram(for: source)
        )
        let final = engine.runUntilTerminal()
        XCTAssertEqual(final.status, .succeeded)
        XCTAssertEqual(final.game.metrics.executedInstructions, 10)
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

        var engine = SimulationEngine(
            level: CatalogCampaign.playableLevel(source),
            program: CatalogCampaign.referenceProgram(for: source)
        )
        let final = engine.runUntilTerminal()
        XCTAssertNotEqual(final.status, .succeeded)
        XCTAssertTrue(final.status.isTerminal)
    }

    func testAKeyCannotOpenAPlateDoor() throws {
        let source = board([
            "ggggggg",
            "ggggggg",
            "ggggggg",
            "ggggggg",
            "ggggggg",
            "AgggggF",
            ">KDgggg"
        ], mechanics: [("BoardKey", 1, 6), ("BoardDoor", 2, 6), ("BoardPlate", 0, 5)],
           links: ["g-test"], program: [.avance, .ramasse, .utilise])
        XCTAssertNotEqual(CatalogInterpreter.execute(source).result, .victory)
        var engine = SimulationEngine(
            level: CatalogCampaign.playableLevel(source),
            program: CatalogCampaign.referenceProgram(for: source)
        )
        let final = engine.runUntilTerminal()
        guard case .incompatibleUse? = final.fault else {
            return XCTFail("UTILISE sur une porte à plaque : \(String(describing: final.fault))")
        }
    }

    // MARK: - Pack

    func testWorldsSevenAndEightUnlockConditionsBeforeLoops() {
        for level in worldLevels {
            let commands = Set(level.unlockedCommands)
            XCTAssertTrue(commands.contains("SI"), level.id)
            XCTAssertEqual(commands.contains("REPETE"), level.world >= 8, level.id)
            XCTAssertFalse(level.unlockedCommands.contains("REPETE") && level.world == 7, level.id)
        }
    }

    func testReferenceProgramsReachTheExactOptimum() throws {
        for source in worldLevels {
            let level = CatalogCampaign.playableLevel(source)
            let shortest = try XCTUnwrap(ActionSearch.shortest(level: level), source.id)
            let stars = try XCTUnwrap(source.starTargets, source.id)
            XCTAssertEqual(shortest.actionCount, stars.withoutBonus.threeStarsMax, source.id)
            XCTAssertEqual(source.solution.actionCount, shortest.actionCount, source.id)
        }
    }

    func testConstraintsAreReachableAndForceTheNewCommand() throws {
        for source in worldLevels {
            let level = CatalogCampaign.playableLevel(source)
            let reference = CatalogCampaign.referenceProgram(for: source)
            XCTAssertEqual(ProgramValidator.issues(in: reference, level: level), [], source.id)

            let flat = Program(instructions: source.solution.expandedOptimalCommands.compactMap {
                CatalogCampaign.commandType(named: $0).map { Instruction(command: $0) }
            })
            let issues = ProgramValidator.issues(in: flat, level: level)
            if source.world == 7 {
                XCTAssertEqual(issues, [.conditionRequired], source.id)
            } else {
                XCTAssertTrue(issues.contains(.loopRequired), source.id)
                let limit = try XCTUnwrap(level.programConstraints.maxBlocks, source.id)
                XCTAssertLessThan(limit, source.solution.actionCount, "\(source.id) : sans boucle il faut un bloc par action")
                XCTAssertTrue(issues.contains(.tooManyBlocks(limit: limit)), source.id)
            }
        }
    }

    func testBonusLevelsKeepTwoReferenceTargets() throws {
        let bonus = worldLevels.filter { !($0.rewards?.collectibles ?? []).isEmpty }.map(\.id)
        XCTAssertEqual(bonus, ["RI-064", "RI-067", "RI-070", "RI-072", "RI-077", "RI-080"])
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
        level.programConstraints = nil
        level.rewards = nil
        level.starTargets = nil
        level.solution.program = program
        return level
    }
}
