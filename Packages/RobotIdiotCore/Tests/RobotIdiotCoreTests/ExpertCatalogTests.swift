import XCTest
@testable import RobotIdiotCore

final class ExpertCatalogTests: XCTestCase {
    func testBundledExpertPacksDecode() throws {
        let pack = try ExpertCatalog.loadSimulationsBundled()
        let tutorial = try ExpertCatalog.loadTutorialBundled()
        let config = try ExpertCatalog.loadConfigBundled()

        XCTAssertEqual(pack.simulations.count, 40)
        XCTAssertEqual(Set(pack.simulations.map(\.id)).count, 40)
        XCTAssertEqual(tutorial.pages.count, 5)
        XCTAssertEqual(tutorial.microTutorials.count, 6)
        XCTAssertEqual(config.schemaVersion, "expert-config/1.0")
        XCTAssertEqual(config.mode, "expert")
    }

    func testWrittenBlocksCountsASTOnceNotLoopIterations() {
        let body = Instruction(command: .moveForward)
        let loop = Instruction(command: .forever, children: [body])
        let program = Program(instructions: [loop])
        // REPETE + AVANCE = 2 nœuds, même si la boucle tourne 20 fois à l'exécution.
        XCTAssertEqual(ExpertScoring.countWrittenBlocks(program), 2)
        XCTAssertEqual(program.blockCount, 2)

        let rating3 = ExpertScoring.rating(writtenBlocks: 2, threeStarsMax: 3, twoStarsMax: 5)
        XCTAssertEqual(rating3.count, 3)
        let rating2 = ExpertScoring.rating(writtenBlocks: 4, threeStarsMax: 3, twoStarsMax: 5)
        XCTAssertEqual(rating2.count, 2)
        let rating1 = ExpertScoring.rating(writtenBlocks: 9, threeStarsMax: 3, twoStarsMax: 5)
        XCTAssertEqual(rating1.count, 1)
    }

    func testUnlockThresholds() throws {
        let first = try XCTUnwrap(ExpertCatalog.simulation(id: "EX-001"))
        XCTAssertEqual(first.unlockedControlCommands, ["REPETE"])
        XCTAssertTrue(first.unlockedConditions.isEmpty)
        XCTAssertEqual(ExpertCatalog.lockedControls(for: first), [.ifBlock])
        XCTAssertTrue(first.allowedHas(.forever))
        XCTAssertFalse(first.allowedHas(.ifBlock))

        let beforeIf = try XCTUnwrap(ExpertCatalog.simulation(id: "EX-008"))
        XCTAssertEqual(beforeIf.unlockedControlCommands, ["REPETE"])
        XCTAssertEqual(ExpertCatalog.lockedControls(for: beforeIf), [.ifBlock])

        let ifUnlock = try XCTUnwrap(ExpertCatalog.simulation(id: "EX-009"))
        XCTAssertEqual(ifUnlock.unlockedControlCommands, ["REPETE", "SI"])
        XCTAssertEqual(ifUnlock.unlockedConditions, ["OBSTACLE_DEVANT"])
        XCTAssertTrue(ExpertCatalog.lockedControls(for: ifUnlock).isEmpty)
        XCTAssertEqual(ExpertCatalog.unlockedConditions(for: ifUnlock), [.obstacleAhead])

        let keyUnlock = try XCTUnwrap(ExpertCatalog.simulation(id: "EX-017"))
        XCTAssertEqual(
            Set(ExpertCatalog.unlockedConditions(for: keyUnlock)),
            Set([.obstacleAhead, .keyHere, .lockAhead])
        )

        let plateUnlock = try XCTUnwrap(ExpertCatalog.simulation(id: "EX-021"))
        XCTAssertTrue(ExpertCatalog.unlockedConditions(for: plateUnlock).contains(.onPlate))

        let crateUnlock = try XCTUnwrap(ExpertCatalog.simulation(id: "EX-030"))
        XCTAssertTrue(ExpertCatalog.unlockedConditions(for: crateUnlock).contains(.crateAhead))
    }

    func testConditionAliasesMapForExpert() {
        XCTAssertEqual(CatalogCampaign.mapCondition("CLE_ICI"), .keyHere)
        XCTAssertEqual(CatalogCampaign.mapCondition("CADENAS_DEVANT"), .lockAhead)
        XCTAssertEqual(CatalogCampaign.mapCondition("CAISSE_DEVANT"), .crateAhead)
        XCTAssertEqual(CatalogCampaign.mapCondition("SUR_BOUTON"), .onPlate)
        XCTAssertEqual(CatalogCampaign.mapCondition("OBSTACLE_DEVANT"), .obstacleAhead)
        // Valeurs historiques Aventure inchangées.
        XCTAssertEqual(ConditionType.lockAhead.rawValue, "SI_CADENAS_DEVANT")
        XCTAssertEqual(ConditionType.crateAhead.rawValue, "SI_CAISSE_DEVANT")
    }

    func testEveryExpertReferenceProgramWins() throws {
        let pack = try ExpertCatalog.loadSimulationsBundled()
        for simulation in pack.simulations.sorted(by: { $0.sequence < $1.sequence }) {
            let level = ExpertCatalog.playableLevel(for: simulation)
            let program = ExpertCatalog.referenceProgram(for: simulation)
            XCTAssertFalse(level.id.isEmpty, simulation.id)
            XCTAssertEqual(level.worldNumber, simulation.visualThemeWorld, simulation.id)

            var engine = SimulationEngine(
                level: level,
                program: program,
                safetyLimits: .expert
            )
            let final = engine.runUntilTerminal()
            XCTAssertEqual(
                final.status,
                .succeeded,
                "\(simulation.id) \(String(describing: final.fault))"
            )
            XCTAssertTrue(final.game.isVictory, simulation.id)

            if let expected = simulation.reference.writtenBlocks {
                XCTAssertEqual(
                    ExpertScoring.countWrittenBlocks(program),
                    expected,
                    "\(simulation.id) writtenBlocks"
                )
            }
        }
    }

    func testExpertDoesNotAlterAdventurePack() throws {
        let adventure = CatalogCampaign.pack
        XCTAssertGreaterThanOrEqual(adventure.levels.count, 100)
        for source in adventure.levels {
            XCTAssertFalse(source.id.hasPrefix("EX-"), source.id)
            XCTAssertTrue(
                Set(source.unlockedCommands).isDisjoint(with: ["SI", "REPETE"]),
                "\(source.id) ne doit pas débloquer SI/REPETE"
            )
        }
        // Quotidiens : pack intact et sans contrôle Expert.
        let challenges = try DailyCatalog.loadChallengesBundled()
        XCTAssertEqual(challenges.levels.count, 100)
        for level in challenges.levels {
            XCTAssertTrue(Set(level.unlockedCommands).isDisjoint(with: ["SI", "REPETE"]), level.id)
        }
    }

    /// Chaque sim a exactement un objectif Goal (`reachFlag`) à `finish` (Y retourné).
    func testEveryExpertSimulationHasExactlyOneGoalAtFinish() throws {
        let pack = try ExpertCatalog.loadSimulationsBundled()
        let focus = ["EX-001", "EX-003", "EX-011", "EX-024", "EX-033"]
        for simulation in pack.simulations {
            let asciiGoals = goalCells(in: simulation)
            XCTAssertEqual(asciiGoals.count, 1, "\(simulation.id) doit avoir un seul F")
            let ascii = try XCTUnwrap(asciiGoals.first, simulation.id)
            XCTAssertEqual(ascii.x, simulation.finish.x, "\(simulation.id) F.x ≠ finish")
            XCTAssertEqual(ascii.y, simulation.finish.y, "\(simulation.id) F.y ≠ finish")

            let level = ExpertCatalog.playableLevel(for: simulation)
            let goals = level.objectives.filter { $0.kind == .reachFlag }
            XCTAssertEqual(goals.count, 1, "\(simulation.id) objectifs Goal")
            let expected = ExpertCatalog.goalPosition(for: simulation)
            XCTAssertEqual(goals[0].position, expected, "\(simulation.id) position Goal")
            XCTAssertEqual(level.worldNumber, simulation.visualThemeWorld, simulation.id)

            let cell = try XCTUnwrap(level.grid.cell(at: expected), simulation.id)
            XCTAssertEqual(cell.terrain, .floor, "\(simulation.id) case Goal praticable")
            XCTAssertFalse(cell.terrain.blocksMovement, simulation.id)
        }

        for id in focus {
            let simulation = try XCTUnwrap(ExpertCatalog.simulation(id: id))
            let level = ExpertCatalog.playableLevel(for: simulation)
            let goal = try XCTUnwrap(level.objectives.first { $0.kind == .reachFlag })
            XCTAssertEqual(goal.position, ExpertCatalog.goalPosition(for: simulation), id)
            // Coins critiques : le Goal doit rester visible (pas sous un décor de coin).
            let atEdge = goal.position.x == 0
                || goal.position.x == level.grid.width - 1
                || goal.position.y == 0
                || goal.position.y == level.grid.height - 1
            XCTAssertTrue(atEdge || id == "EX-033", "\(id) attendu en bordure ou EX-033")
        }
    }
}

private func goalCells(in simulation: ExpertSimulation) -> [GridCoordinate] {
    var found: [GridCoordinate] = []
    for y in 0..<simulation.height {
        let row = Array(simulation.grid[y])
        for x in 0..<min(row.count, simulation.width) where row[x] == "F" {
            found.append(GridCoordinate(x: x, y: y))
        }
    }
    return found
}

private extension ExpertSimulation {
    func allowedHas(_ command: CommandType) -> Bool {
        let level = ExpertCatalog.playableLevel(for: self)
        return level.allowedCommands.contains(command)
    }
}
