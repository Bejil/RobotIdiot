import XCTest
@testable import RobotIdiotCore

final class InteractionTests: XCTestCase {
    func testPickUpTakesTheKeyAndUseOpensTheDoor() {
        let level = corridor(commands: CommandType.movement + [.pickUp, .use])
        var engine = SimulationEngine(level: level, program: program([.moveForward, .pickUp, .use, .moveForward, .moveForward]))
        let final = engine.runUntilTerminal()
        XCTAssertEqual(final.status, .succeeded)
        XCTAssertEqual(final.game.robot.position, GridCoordinate(x: 4, y: 1))
        XCTAssertTrue(final.game.robot.inventory.isEmpty)
        XCTAssertEqual(final.game.metrics.interactions, 2)
        XCTAssertEqual(final.game.grid.cell(at: GridCoordinate(x: 3, y: 1))?.mechanisms.first?.isActive, true)
        XCTAssertTrue(final.game.grid.cell(at: GridCoordinate(x: 2, y: 1))?.objects.isEmpty == true)
    }

    func testMissingKeyOrClosedDoorStopsTheRobot() {
        let level = corridor(commands: CommandType.movement + [.pickUp, .use])
        var missing = SimulationEngine(level: level, program: program([.pickUp]))
        let empty = missing.step()
        XCTAssertEqual(missing.state.status, .failed)
        guard case .nothingToPickUp = empty.state.fault else {
            return XCTFail("\(String(describing: empty.state.fault))")
        }
        XCTAssertEqual(empty.state.game.robot.position, GridCoordinate(x: 1, y: 1))

        var blocked = SimulationEngine(level: level, program: program([.moveForward, .moveForward]))
        let hit = blocked.runUntilTerminal()
        XCTAssertEqual(hit.status, .failed)
        guard case .pathBlocked(_, _, true, let attempted) = hit.fault else {
            return XCTFail("\(String(describing: hit.fault))")
        }
        XCTAssertEqual(attempted, GridCoordinate(x: 3, y: 1))
        XCTAssertEqual(hit.game.robot.position, GridCoordinate(x: 2, y: 1))
    }

    func testUseWithoutAKeyOrOnTheWrongCellKeepsTheInventory() {
        var level = corridor(commands: CommandType.movement + [.pickUp, .use])
        var bare = SimulationEngine(level: level, program: program([.use]))
        XCTAssertEqual(bare.runUntilTerminal().fault, .nothingToUse(instructionID: bare.program.instructions[0].id))

        level.initialRobot.inventory = [CarriedItem(id: "key", kind: ObjectKind.key)]
        var engine = SimulationEngine(level: level, program: program([.use]))
        let final = engine.runUntilTerminal()
        guard case .incompatibleUse = final.fault else {
            return XCTFail("\(String(describing: final.fault))")
        }
        XCTAssertEqual(final.game.robot.inventory.map(\.id), ["key"])
        XCTAssertEqual(final.game.grid.cell(at: GridCoordinate(x: 3, y: 1))?.mechanisms.first?.isActive, false)
    }

    func testPushMovesTheCrateThenTheRobotOntoTheFlag() {
        let level = crateLane()
        var engine = SimulationEngine(level: level, program: program([.push, .push]))
        let final = engine.runUntilTerminal()
        XCTAssertEqual(final.status, .succeeded)
        XCTAssertEqual(final.game.robot.position, GridCoordinate(x: 3, y: 1))
        XCTAssertEqual(final.game.grid.cell(at: GridCoordinate(x: 4, y: 1))?.objects.first?.id, "crate")
        XCTAssertEqual(final.game.metrics.moves, 2)
        XCTAssertEqual(final.game.metrics.interactions, 2)
    }

    func testPushIntoAWallLeavesTheCrate() {
        var level = crateLane()
        level.grid.updateCell(at: GridCoordinate(x: 4, y: 1)) { cell in
            cell.terrain = .wall
        }
        var engine = SimulationEngine(level: level, program: program([.push, .push]))
        let final = engine.runUntilTerminal()
        guard case .pushBlocked(_, let attempted) = final.fault else {
            return XCTFail("\(String(describing: final.fault))")
        }
        XCTAssertEqual(attempted, GridCoordinate(x: 4, y: 1))
        XCTAssertEqual(final.game.robot.position, GridCoordinate(x: 2, y: 1))
        XCTAssertEqual(final.game.grid.cell(at: GridCoordinate(x: 3, y: 1))?.objects.first?.id, "crate")
    }

    func testPushWithoutACrateFails() {
        let level = crateLane()
        var engine = SimulationEngine(level: level, program: program([.turnLeft, .push]))
        let final = engine.runUntilTerminal()
        guard case .nothingToPush = final.fault else {
            return XCTFail("\(String(describing: final.fault))")
        }
        XCTAssertEqual(final.game.robot.position, GridCoordinate(x: 1, y: 1))
    }

    func testActivatePrefersThePlateUnderTheRobotAndTogglesTheLinkedDoor() {
        var level = corridor(commands: CommandType.movement + [.activate])
        level.grid.updateCell(at: GridCoordinate(x: 1, y: 1)) { cell in
            cell.mechanisms = [PlacedMechanism(id: "near", kind: MechanismKind.plate, link: "door")]
        }
        level.grid.updateCell(at: GridCoordinate(x: 2, y: 1)) { cell in
            cell.mechanisms.append(PlacedMechanism(id: "far", kind: MechanismKind.plate, link: "other"))
        }
        var engine = SimulationEngine(level: level, program: program([.activate]))
        let once = engine.runUntilTerminal()
        XCTAssertEqual(once.status, .exhausted)
        XCTAssertEqual(once.game.grid.cell(at: GridCoordinate(x: 1, y: 1))?.mechanisms.first?.isActive, true)
        XCTAssertEqual(once.game.grid.cell(at: GridCoordinate(x: 2, y: 1))?.mechanisms.last?.isActive, false)
        XCTAssertEqual(once.game.grid.cell(at: GridCoordinate(x: 3, y: 1))?.mechanisms.first?.isActive, true)

        var again = SimulationEngine(level: level, program: program([.activate, .activate]))
        let toggled = again.runUntilTerminal()
        XCTAssertEqual(toggled.game.grid.cell(at: GridCoordinate(x: 3, y: 1))?.mechanisms.first?.isActive, false)
    }

    func testActivateUsesThePlateAheadWhenTheRobotIsNotStandingOnOne() {
        let level = corridor(commands: CommandType.movement + [.activate])
        var engine = SimulationEngine(level: level, program: program([.activate]))
        let final = engine.runUntilTerminal()
        XCTAssertEqual(final.status, .exhausted)
        XCTAssertEqual(final.game.grid.cell(at: GridCoordinate(x: 3, y: 1))?.mechanisms.first?.isActive, true)
        XCTAssertEqual(final.game.robot.position, GridCoordinate(x: 1, y: 1))
    }

    func testActivateWithoutAPlateFails() {
        var level = corridor(commands: [.activate])
        level.grid.updateCell(at: GridCoordinate(x: 2, y: 1)) { cell in
            cell.mechanisms.removeAll { $0.kind == MechanismKind.plate }
        }
        var engine = SimulationEngine(level: level, program: program([.activate]))
        guard case .nothingToActivate = engine.runUntilTerminal().fault else {
            return XCTFail("interrupteur absent")
        }
    }

    func testRepeatingActivateWithoutProgressIsACycle() {
        var level = corridor(commands: [.forever, .activate])
        level.programConstraints = ProgramConstraints(maxBlocks: 2, maxNestingDepth: 2)
        level.grid.updateCell(at: GridCoordinate(x: 1, y: 1)) { cell in
            cell.mechanisms = [PlacedMechanism(id: "near", kind: MechanismKind.plate)]
        }
        let loop = Program(instructions: [
            Instruction(command: .forever, children: [Instruction(command: .activate)])
        ])
        var engine = SimulationEngine(level: level, program: loop)
        let final = engine.runUntilTerminal()
        guard case .cycle = final.fault else {
            return XCTFail("\(String(describing: final.fault))")
        }
        XCTAssertLessThan(final.safetyStepCount, 12)
    }

    func testGeneratedInteractionsStaySolvableAndBlockedToMovement() {
        for family in [PuzzleFamily.keyDoor, .switchDoor, .cratePush] {
            for seed in UInt64(1)...8 {
                let request = GenerationRequest(
                    seed: seed,
                    generatorVersion: LevelGenerator.version,
                    worldNumber: 4,
                    levelNumber: Int(seed),
                    targetDifficulty: 0.4,
                    family: family
                )
                let generated = LevelGenerator.generate(request)
                XCTAssertFalse(generated.usedFallback, "\(family) \(seed)")
                XCTAssertFalse(ProgramSolver.movementReachesFlag(generated.level), "\(family) \(seed)")
                var engine = SimulationEngine(level: generated.level, program: generated.referenceProgram)
                XCTAssertEqual(engine.runUntilTerminal().status, .succeeded, "\(family) \(seed)")
                XCTAssertLessThanOrEqual(generated.level.grid.width, 10)
            }
        }
    }

    func testCampaignWorldsIntroduceOneInteractionAtATime() {
        let key = LevelGenerator.generate(WorldGenerator.blueprint(campaignSeed: 4, world: 4).slots[0].request)
        XCTAssertTrue(key.level.allowedCommands.contains(.pickUp))
        XCTAssertFalse(key.level.allowedCommands.contains(.activate))
        XCTAssertFalse(key.level.allowedCommands.contains(.forever))

        let plate = LevelGenerator.generate(WorldGenerator.blueprint(campaignSeed: 4, world: 5).slots.last!.request)
        XCTAssertTrue(plate.level.allowedCommands.contains(.activate))
        XCTAssertFalse(plate.level.allowedCommands.contains(.pickUp))

        let crate = LevelGenerator.generate(WorldGenerator.blueprint(campaignSeed: 4, world: 6).slots.last!.request)
        XCTAssertTrue(crate.level.allowedCommands.contains(.push))
        XCTAssertEqual(WorldGenerator.families(forWorld: 7).first, .openWalk)
        XCTAssertTrue(WorldGenerator.families(forWorld: 7).contains(.cratePush))
    }

    func testSolverFindsAPushLoopAndAKeyLoop() {
        var crates = crateLane()
        crates.allowedCommands = CommandType.movement + [.forever, .push]
        crates.programConstraints = ProgramConstraints(maxBlocks: 2, maxNestingDepth: 2)
        let pushed = ProgramSolver.search(
            level: crates,
            sequentialLimit: 2,
            includeLoops: true,
            budget: SolverBudget(maxPrograms: 40, maxSteps: 400)
        )
        XCTAssertEqual(pushed.conclusion, .found)
        XCTAssertEqual(pushed.program?.instructions.first?.command, .forever)

        var keys = corridor(commands: CommandType.movement + [.forever, .ifBlock, .pickUp, .use])
        keys.programConstraints = ProgramConstraints(maxBlocks: 6, maxNestingDepth: 3)
        let opened = ProgramSolver.simulate(ProgramSolver.keyLoop(), level: keys)
        XCTAssertEqual(opened.status, .succeeded)
        XCTAssertEqual(opened.metrics.interactions, 2)
    }

    func testInteractionFallbackStillWins() {
        let request = GenerationRequest(
            seed: 3,
            generatorVersion: LevelGenerator.version,
            worldNumber: 4,
            levelNumber: 1,
            targetDifficulty: 0.4,
            family: .keyDoor
        )
        let generated = LevelGenerator.generate(
            request,
            budget: GenerationBudget(maxAttempts: 0, solver: SolverBudget(maxPrograms: 1, maxSteps: 1))
        )
        XCTAssertTrue(generated.usedFallback)
        var engine = SimulationEngine(level: generated.level, program: generated.referenceProgram)
        XCTAssertEqual(engine.runUntilTerminal().status, .succeeded)
        XCTAssertTrue(generated.level.allowedCommands.contains(.use))
    }

    private func program(_ commands: [CommandType]) -> Program {
        Program(instructions: commands.map { Instruction(command: $0) })
    }

    private func corridor(commands: [CommandType]) -> Level {
        var grid = Grid.bordered(width: 6, height: 5, interiorWalls: [])
        for x in 1...4 {
            for y in 2...3 {
                grid.updateCell(at: GridCoordinate(x: x, y: y)) { cell in
                    cell.terrain = .wall
                }
            }
        }
        grid.updateCell(at: GridCoordinate(x: 2, y: 1)) { cell in
            cell.objects = [PlacedObject(id: "key", kind: ObjectKind.key)]
            cell.mechanisms = [PlacedMechanism(id: "plate", kind: MechanismKind.plate, link: "door")]
        }
        grid.updateCell(at: GridCoordinate(x: 3, y: 1)) { cell in
            cell.mechanisms = [PlacedMechanism(id: "door", kind: MechanismKind.door)]
        }
        return Level(
            id: "interaction-corridor",
            version: 1,
            seed: 1,
            generatorVersion: 0,
            worldNumber: 4,
            levelNumber: 1,
            difficulty: 0.4,
            theme: .laboratory,
            grid: grid,
            initialRobot: RobotState(position: GridCoordinate(x: 1, y: 1), orientation: .east),
            objectives: [Objective(id: "flag", kind: .reachFlag, position: GridCoordinate(x: 4, y: 1))],
            allowedCommands: commands,
            programConstraints: .flat,
            scoringRules: ScoringRules(compactProgramMaxBlocks: 5, efficientExecutionMaxSteps: 5, referenceNote: "Test."),
            validation: ValidationMetadata(status: .handcrafted, notes: [])
        )
    }

    private func crateLane() -> Level {
        var grid = Grid.bordered(width: 6, height: 5)
        for x in 1...4 {
            for y in 2...3 {
                grid.updateCell(at: GridCoordinate(x: x, y: y)) { cell in
                    cell.terrain = .wall
                }
            }
        }
        grid.updateCell(at: GridCoordinate(x: 2, y: 1)) { cell in
            cell.objects = [PlacedObject(id: "crate", kind: ObjectKind.crate)]
        }
        return Level(
            id: "interaction-crate",
            version: 1,
            seed: 1,
            generatorVersion: 0,
            worldNumber: 6,
            levelNumber: 1,
            difficulty: 0.4,
            theme: .laboratory,
            grid: grid,
            initialRobot: RobotState(position: GridCoordinate(x: 1, y: 1), orientation: .east),
            objectives: [Objective(id: "flag", kind: .reachFlag, position: GridCoordinate(x: 3, y: 1))],
            allowedCommands: CommandType.movement + [.push],
            programConstraints: ProgramConstraints(maxBlocks: 2, maxNestingDepth: 1),
            scoringRules: ScoringRules(compactProgramMaxBlocks: 2, efficientExecutionMaxSteps: 2, referenceNote: "Test."),
            validation: ValidationMetadata(status: .handcrafted, notes: [])
        )
    }
}
