import XCTest
@testable import RobotIdiotCore

final class ControlFlowTests: XCTestCase {
    func testCorridorLoopStopsOnTheFlag() {
        let program = PrototypeLevel.corridorReferenceProgram()
        var engine = SimulationEngine(level: PrototypeLevel.corridor, program: program)
        let final = engine.runUntilTerminal()

        XCTAssertEqual(final.status, .succeeded)
        XCTAssertEqual(final.game.robot.position, GridCoordinate(x: 1, y: 6))
        XCTAssertEqual(final.game.robot.orientation, .north)
        XCTAssertEqual(final.game.metrics.moves, 5)
        XCTAssertEqual(final.game.metrics.executedInstructions, 5)
        XCTAssertEqual(program.blockCount, 2)
        let rating = ScoreEvaluator.rating(
            succeeded: true,
            blockCount: program.blockCount,
            executedInstructions: final.game.metrics.executedInstructions,
            rules: PrototypeLevel.corridor.scoringRules
        )
        XCTAssertEqual(rating.count, 3)
    }

    func testUnrolledCorridorExceedsTheBlockCap() {
        let moves = (0..<5).map { _ in Instruction(command: .moveForward) }
        let program = Program(instructions: moves)
        XCTAssertEqual(
            ProgramValidator.issues(in: program, level: PrototypeLevel.corridor),
            [.tooManyBlocks(limit: 2)]
        )
    }

    func testTurnLoopCyclesAfterFourTurns() {
        let turn = Instruction(command: .turnLeft)
        let loop = Instruction(command: .forever, children: [turn])
        let level = levelAllowingControl(TestLevels.openRoom(
            robot: RobotState(position: GridCoordinate(x: 1, y: 1), orientation: .east)
        ))
        var engine = SimulationEngine(level: level, program: Program(instructions: [loop]))
        let final = engine.runUntilTerminal()

        XCTAssertEqual(final.status, .failed)
        guard case .cycle(let id)? = final.fault else {
            return XCTFail("Quatre tours à gauche ramènent le robot au même état")
        }
        XCTAssertEqual(id, turn.id)
        XCTAssertEqual(final.game.metrics.turns, 4)
        XCTAssertEqual(final.game.robot.orientation, .east)
        XCTAssertNotEqual(final.status, .safetyStopped)
    }

    func testFalseConditionSkipsTheBody() {
        let body = Instruction(command: .turnLeft)
        let check = Instruction(command: .ifBlock, condition: .obstacleAhead, children: [body])
        let program = Program(instructions: [check, Instruction(command: .moveForward)])
        var engine = SimulationEngine(level: levelAllowingControl(TestLevels.openRoom(
            robot: RobotState(position: GridCoordinate(x: 1, y: 1), orientation: .east)
        )), program: program)
        let first = engine.step()
        guard case .testedCondition(_, .obstacleAhead, false) = first.event else {
            return XCTFail("La case devant est libre")
        }
        XCTAssertEqual(first.state.status, .inProgress)
        XCTAssertEqual(first.state.game.metrics.tests, 1)
        XCTAssertEqual(first.state.game.metrics.executedInstructions, 0)
        let second = engine.step()
        guard case .moved = second.event else {
            return XCTFail("Le corps du SI faux ne doit pas s'exécuter")
        }
        XCTAssertEqual(second.state.game.robot.orientation, .east)
        XCTAssertEqual(second.state.game.metrics.turns, 0)
    }

    func testTrueConditionRunsTheBody() {
        let body = Instruction(command: .turnLeft)
        let check = Instruction(command: .ifBlock, condition: .obstacleAhead, children: [body])
        var room = TestLevels.openRoom(
            robot: RobotState(position: GridCoordinate(x: 0, y: 1), orientation: .west)
        )
        room.allowedCommands = CommandType.movement + [.ifBlock]
        room.programConstraints = ProgramConstraints(maxBlocks: nil, maxNestingDepth: 2)
        var engine = SimulationEngine(level: room, program: Program(instructions: [check]))
        let test = engine.step()
        guard case .testedCondition(_, .obstacleAhead, true) = test.event else {
            return XCTFail("Le bord ouest est un obstacle")
        }
        let turn = engine.step()
        guard case .turned(_, .south, _) = turn.event else {
            return XCTFail("Le corps doit tourner")
        }
        XCTAssertEqual(turn.state.status, .exhausted)
        XCTAssertEqual(turn.state.game.metrics.turns, 1)
    }

    func testCornerReferenceSucceedsWithExpectedMetrics() {
        let program = PrototypeLevel.cornerReferenceProgram()
        var engine = SimulationEngine(level: PrototypeLevel.corner, program: program)
        let final = engine.runUntilTerminal()

        XCTAssertEqual(final.status, .succeeded)
        XCTAssertEqual(final.game.robot.position, GridCoordinate(x: 1, y: 4))
        XCTAssertEqual(final.game.metrics.tests, 9)
        XCTAssertEqual(final.game.metrics.turns, 2)
        XCTAssertEqual(final.game.metrics.moves, 9)
        XCTAssertEqual(final.game.metrics.executedInstructions, 11)
        XCTAssertEqual(program.blockCount, 4)
        XCTAssertTrue(ProgramValidator.issues(in: program, level: PrototypeLevel.corner).isEmpty)
        let rating = ScoreEvaluator.rating(
            succeeded: true,
            blockCount: program.blockCount,
            executedInstructions: 11,
            rules: PrototypeLevel.corner.scoringRules
        )
        XCTAssertEqual(rating.count, 3)
    }

    func testBlindAdvanceOnTheCornerHitsTheWall() {
        let move = Instruction(command: .moveForward)
        let loop = Instruction(command: .forever, children: [move])
        var engine = SimulationEngine(
            level: PrototypeLevel.corner,
            program: Program(instructions: [loop])
        )
        let final = engine.runUntilTerminal()
        XCTAssertEqual(final.status, .failed)
        guard case .pathBlocked = final.fault else {
            return XCTFail("Avancer sans tester heurte le mur est")
        }
        XCTAssertEqual(final.game.robot.position, GridCoordinate(x: 4, y: 1))
    }

    func testEmptyForeverDoesNotHang() {
        let loop = Instruction(command: .forever)
        let level = levelAllowingControl(PrototypeLevel.corridor)
        var engine = SimulationEngine(
            level: level,
            program: Program(instructions: [loop]),
            safetyLimits: SafetyLimits(maxInstructionSteps: 50)
        )
        let final = engine.runUntilTerminal()
        XCTAssertEqual(final.status, .failed)
        guard case .cycle(let id)? = final.fault else {
            return XCTFail("Une boucle vide est un cycle")
        }
        XCTAssertEqual(id, loop.id)
        XCTAssertLessThan(final.safetyStepCount, 5)
    }

    func testProgressingCorridorHitsTheSafetyLimitInsteadOfACycle() {
        let loop = Instruction(command: .forever, children: [Instruction(command: .moveForward)])
        var engine = SimulationEngine(
            level: PrototypeLevel.corridor,
            program: Program(instructions: [loop]),
            safetyLimits: SafetyLimits(maxInstructionSteps: 3)
        )
        let final = engine.runUntilTerminal()
        XCTAssertEqual(final.status, .safetyStopped)
        XCTAssertEqual(final.fault, .safetyStop)
        XCTAssertNotEqual(final.game.robot.position, PrototypeLevel.corridor.initialRobot.position)
    }

    func testObstacleAndFreeAreNegations() {
        let blocked = TestLevels.openRoom(
            robot: RobotState(position: GridCoordinate(x: 0, y: 1), orientation: .west)
        )
        let open = TestLevels.openRoom(
            robot: RobotState(position: GridCoordinate(x: 1, y: 1), orientation: .east)
        )
        let blockedGame = GameState.initial(from: blocked)
        let openGame = GameState.initial(from: open)
        XCTAssertTrue(ConditionEvaluator.evaluate(.obstacleAhead, game: blockedGame))
        XCTAssertFalse(ConditionEvaluator.evaluate(.cellAheadFree, game: blockedGame))
        XCTAssertFalse(ConditionEvaluator.evaluate(.obstacleAhead, game: openGame))
        XCTAssertTrue(ConditionEvaluator.evaluate(.cellAheadFree, game: openGame))
    }

    func testCarryingAndObjectAreFalseWhenEmpty() {
        let game = GameState.initial(from: PrototypeLevel.corridor)
        XCTAssertFalse(ConditionEvaluator.evaluate(.carryingItem, game: game))
        XCTAssertFalse(ConditionEvaluator.evaluate(.objectPresent, game: game))
        XCTAssertFalse(ConditionEvaluator.evaluate(.doorClosed, game: game))
        XCTAssertFalse(ConditionEvaluator.evaluate(.switchActivated, game: game))
    }

    func testMissingConditionIsAnError() {
        let check = Instruction(command: .ifBlock, condition: nil, children: [Instruction(command: .turnLeft)])
        var room = TestLevels.openRoom(
            robot: RobotState(position: GridCoordinate(x: 1, y: 1), orientation: .east)
        )
        room.allowedCommands = CommandType.movement + [.ifBlock]
        var engine = SimulationEngine(level: room, program: Program(instructions: [check]))
        let final = engine.runUntilTerminal()
        guard case .missingCondition(let id)? = final.fault else {
            return XCTFail("Un SI sans condition est une erreur")
        }
        XCTAssertEqual(id, check.id)
        XCTAssertEqual(final.game.metrics.tests, 0)
    }

    func testLevelsStaySolvableAndHandcrafted() {
        for level in PrototypeLevel.playable {
            XCTAssertTrue(LevelIntegrity.issues(in: level).isEmpty, level.id)
        }
        XCTAssertEqual(PrototypeLevel.level(after: PrototypeLevel.firstSteps.id)?.id, PrototypeLevel.corridor.id)
        XCTAssertEqual(PrototypeLevel.level(after: PrototypeLevel.corridor.id)?.id, PrototypeLevel.corner.id)
        XCTAssertNil(PrototypeLevel.level(after: PrototypeLevel.corner.id))
    }

    func testAppendNestsInsideTheChosenContainer() throws {
        var program = Program()
        let loop = try XCTUnwrap(program.append(.forever, toParent: nil))
        let move = try XCTUnwrap(program.append(.moveForward, toParent: loop))
        let turn = try XCTUnwrap(program.append(.turnLeft, toParent: loop))
        XCTAssertEqual(program.rows.map(\.depth), [0, 1, 1])
        XCTAssertEqual(program.rows.map(\.instruction.command), [.forever, .moveForward, .turnLeft])
        XCTAssertTrue(program.moveSibling(turn, offset: -1))
        XCTAssertEqual(program.instruction(id: loop)?.children.map(\.id), [turn, move])
        let check = try XCTUnwrap(program.append(.ifBlock, toParent: loop))
        XCTAssertEqual(program.instruction(id: check)?.condition, .cellAheadFree)
        XCTAssertTrue(program.setCondition(.cellAheadFree, on: check))
        XCTAssertEqual(program.ancestorIDs(of: check), [loop])
    }

    private func levelAllowingControl(_ level: Level) -> Level {
        var copy = level
        copy.allowedCommands = CommandType.movement + [.forever, .ifBlock]
        copy.programConstraints = ProgramConstraints(maxBlocks: nil, maxNestingDepth: 3)
        return copy
    }
}
