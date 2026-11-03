import XCTest
@testable import RobotIdiotCore

final class SimulationEngineTests: XCTestCase {
    func testProgramReachesTheFlagAndStopsBeforeExtraCommands() {
        let level = PrototypeLevel.firstSteps
        var program = PrototypeLevel.referenceProgram()
        let extra = Instruction(command: .moveForward)
        program.instructions.append(extra)

        var engine = SimulationEngine(level: level, program: program)
        let final = engine.runUntilTerminal()

        XCTAssertEqual(final.status, .succeeded)
        XCTAssertEqual(final.game.robot.position, GridCoordinate(x: 1, y: 4))
        XCTAssertEqual(final.game.metrics.executedInstructions, 9)
        XCTAssertEqual(final.game.metrics.moves, 7)
        XCTAssertEqual(final.game.metrics.turns, 2)
        XCTAssertFalse(final.history.contains { $0.instructionID == extra.id })
        XCTAssertTrue(final.game.isVictory)
    }

    func testReferenceSolutionEarnsThreeStars() {
        var engine = SimulationEngine(level: PrototypeLevel.firstSteps, program: PrototypeLevel.referenceProgram())
        let final = engine.runUntilTerminal()
        let rating = ScoreEvaluator.rating(
            succeeded: final.status == .succeeded,
            blockCount: PrototypeLevel.referenceProgram().blockCount,
            executedInstructions: final.game.metrics.executedInstructions,
            rules: PrototypeLevel.firstSteps.scoringRules
        )
        XCTAssertEqual(rating.count, 3)
    }

    func testLongerSolutionOnlyEarnsCompletion() {
        var instructions = [
            Instruction(command: .turnRight),
            Instruction(command: .turnLeft)
        ]
        instructions.append(contentsOf: PrototypeLevel.referenceProgram().instructions)
        let program = Program(instructions: instructions)
        var engine = SimulationEngine(level: PrototypeLevel.firstSteps, program: program)
        let final = engine.runUntilTerminal()
        let rating = ScoreEvaluator.rating(
            succeeded: final.status == .succeeded,
            blockCount: program.blockCount,
            executedInstructions: final.game.metrics.executedInstructions,
            rules: PrototypeLevel.firstSteps.scoringRules
        )
        XCTAssertEqual(final.status, .succeeded)
        XCTAssertEqual(rating, StarRating(completion: true, compactProgram: false, efficientExecution: false))
    }

    func testBlockedInstructionIsIdentifiedAndDoesNotMutateTheRobot() {
        let failing = Instruction(id: UUID(uuidString: "00000000-0000-0000-0000-000000000004")!, command: .moveForward)
        let program = Program(instructions: [
            Instruction(command: .moveForward),
            Instruction(command: .moveForward),
            Instruction(command: .moveForward),
            failing
        ])
        var engine = SimulationEngine(level: PrototypeLevel.firstSteps, program: program)
        let final = engine.runUntilTerminal()

        XCTAssertEqual(final.status, .failed)
        XCTAssertEqual(final.activeInstructionID, failing.id)
        XCTAssertEqual(final.game.robot.position, GridCoordinate(x: 4, y: 1))
        XCTAssertEqual(final.game.robot.orientation, .east)
        XCTAssertEqual(final.game.metrics.executedInstructions, 3)
        guard case .pathBlocked(_, let id, true, let attempted)? = final.fault else {
            return XCTFail("La quatrième avance devrait heurter le bord")
        }
        XCTAssertEqual(id, failing.id)
        XCTAssertEqual(attempted, GridCoordinate(x: 5, y: 1))
    }

    func testEmptyProgramEndsWithoutVictory() {
        var engine = SimulationEngine(level: PrototypeLevel.firstSteps, program: Program())
        let final = engine.runUntilTerminal()
        XCTAssertEqual(final.status, .exhausted)
        XCTAssertEqual(final.game.robot, PrototypeLevel.firstSteps.initialRobot)
        XCTAssertFalse(final.game.isVictory)
    }

    func testForeverIsRejectedInsteadOfBeingApproximated() {
        let forever = Instruction(command: .forever, children: [Instruction(command: .moveForward)])
        var engine = SimulationEngine(level: PrototypeLevel.firstSteps, program: Program(instructions: [forever]))
        let before = engine.state.game.robot
        let final = engine.runUntilTerminal()
        XCTAssertEqual(final.status, .failed)
        guard case .commandUnavailable(.forever, let id)? = final.fault else {
            return XCTFail("REPETE doit échouer explicitement")
        }
        XCTAssertEqual(id, forever.id)
        XCTAssertEqual(final.game.robot, before)
        XCTAssertEqual(final.safetyStepCount, 1)
    }

    func testResetRestoresTheInitialWorldAndKeepsTheProgram() {
        var engine = SimulationEngine(level: PrototypeLevel.firstSteps, program: PrototypeLevel.referenceProgram())
        _ = engine.step()
        _ = engine.step()
        XCTAssertNotEqual(engine.state.game.robot.position, PrototypeLevel.firstSteps.initialRobot.position)
        let programID = engine.program.id
        engine.reset()
        XCTAssertEqual(engine.state.status, .ready)
        XCTAssertEqual(engine.state.game.robot, PrototypeLevel.firstSteps.initialRobot)
        XCTAssertEqual(engine.state.game.metrics, ExecutionMetrics())
        XCTAssertEqual(engine.program.id, programID)
        XCTAssertNil(engine.state.fault)
    }

    func testTwoRunsAreIdentical() {
        func snapshot() -> (ExecutionStatus, RobotState, ExecutionMetrics) {
            var engine = SimulationEngine(level: PrototypeLevel.firstSteps, program: PrototypeLevel.referenceProgram())
            let final = engine.runUntilTerminal()
            return (final.status, final.game.robot, final.game.metrics)
        }
        XCTAssertEqual(snapshot().0, snapshot().0)
        XCTAssertEqual(snapshot().1, snapshot().1)
        XCTAssertEqual(snapshot().2, snapshot().2)
    }

    func testSafetyLimitStopsWithoutBecomingALanguageCounter() {
        let program = Program(instructions: Array(repeating: Instruction(command: .turnLeft), count: 6))
        var engine = SimulationEngine(
            level: PrototypeLevel.firstSteps,
            program: program,
            safetyLimits: SafetyLimits(maxInstructionSteps: 3)
        )
        let final = engine.runUntilTerminal()
        XCTAssertEqual(final.status, .safetyStopped)
        XCTAssertEqual(final.game.metrics.turns, 3)
        XCTAssertEqual(final.fault, .safetyStop)
        XCTAssertEqual(final.game.robot.orientation, .south)
    }

    func testFingerprintIgnoresMetricsButIncludesCursorAndRobot() {
        var engine = SimulationEngine(level: PrototypeLevel.firstSteps, program: PrototypeLevel.referenceProgram())
        let initial = engine.state.fingerprint
        _ = engine.step()
        let afterMove = engine.state.fingerprint
        XCTAssertNotEqual(initial, afterMove)

        var paused = engine.state
        paused.game.metrics.executedInstructions += 50
        XCTAssertEqual(paused.fingerprint, afterMove)
    }

    func testSteppingAfterTerminalDoesNotContinue() {
        var engine = SimulationEngine(level: PrototypeLevel.firstSteps, program: PrototypeLevel.referenceProgram())
        _ = engine.runUntilTerminal()
        let settled = engine.state
        let outcome = engine.step()
        XCTAssertNil(outcome.event)
        XCTAssertEqual(outcome.state, settled)
    }

    func testEnteringWaterMovesThenFails() {
        let level = TestLevels.room(
            robot: RobotState(position: GridCoordinate(x: 1, y: 1), orientation: .east),
            terrain: [GridCoordinate(x: 2, y: 1): .water]
        )
        let move = Instruction(command: .moveForward)
        var engine = SimulationEngine(level: level, program: Program(instructions: [move]))
        let final = engine.runUntilTerminal()
        XCTAssertEqual(final.status, .failed)
        XCTAssertEqual(final.game.robot.position, GridCoordinate(x: 2, y: 1))
        guard case .hazard(_, let id, .water, let at)? = final.fault else {
            return XCTFail("L'eau doit tuer après l'entrée")
        }
        XCTAssertEqual(id, move.id)
        XCTAssertEqual(at, GridCoordinate(x: 2, y: 1))
        guard case .enteredHazard(_, let to, .water, _, _)? = final.history.last?.event else {
            return XCTFail("L'événement doit montrer l'entrée dans l'eau")
        }
        XCTAssertEqual(to, GridCoordinate(x: 2, y: 1))
    }
}
