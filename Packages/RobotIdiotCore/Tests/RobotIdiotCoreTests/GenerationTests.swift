import XCTest
@testable import RobotIdiotCore

final class GenerationTests: XCTestCase {
    func testSameRequestRebuildsTheSameLevel() {
        let first = LevelGenerator.generate(request(seed: 42, level: 3))
        let second = LevelGenerator.generate(request(seed: 42, level: 3))
        XCTAssertEqual(first.level, second.level)
        XCTAssertEqual(shape(first.referenceProgram), shape(second.referenceProgram))
        XCTAssertFalse(first.usedFallback)
        XCTAssertEqual(first.level.generatorVersion, LevelGenerator.version)
        XCTAssertEqual(first.level.seed, 42)
    }

    func testLevelNumberChangesThePuzzle() {
        let first = LevelGenerator.generate(request(seed: 7, level: 1))
        let second = LevelGenerator.generate(request(seed: 7, level: 2))
        XCTAssertNotEqual(signature(first.level), signature(second.level))
    }

    func testGeneratedLevelsStayInsideASmallBoardAndAreSolvedByTheReference() {
        var signatures = Set<String>()
        for seed in UInt64(1)...24 {
            let generated = LevelGenerator.generate(request(seed: seed, level: 1))
            signatures.insert(signature(generated.level))
            XCTAssertTrue(LevelIntegrity.issues(in: generated.level).isEmpty, generated.level.id)
            XCTAssertLessThanOrEqual(generated.level.grid.width, 10)
            XCTAssertLessThanOrEqual(generated.level.grid.height, 10)
            XCTAssertLessThanOrEqual(max(generated.level.grid.width, generated.level.grid.height), 10)
            var engine = SimulationEngine(level: generated.level, program: generated.referenceProgram)
            let final = engine.runUntilTerminal()
            XCTAssertEqual(final.status, .succeeded, "graine \(seed)")
            XCTAssertFalse(generated.usedFallback, "graine \(seed) \(generated.validation.rejectionReasons)")
            let rating = ScoreEvaluator.rating(
                succeeded: true,
                blockCount: generated.referenceProgram.blockCount,
                executedInstructions: final.game.metrics.executedInstructions,
                rules: generated.level.scoringRules
            )
            XCTAssertEqual(rating.count, 3, "graine \(seed)")
        }
        XCTAssertGreaterThanOrEqual(signatures.count, 8)
    }

    func testCorridorFamilyNeedsTheLoop() {
        let generated = LevelGenerator.generate(request(seed: 3, level: 1, family: .infiniteCorridor))
        XCTAssertFalse(generated.usedFallback)
        XCTAssertEqual(generated.validation.solverConclusion, .absent)
        XCTAssertLessThanOrEqual(generated.referenceProgram.blockCount, 2)
        XCTAssertEqual(generated.level.programConstraints.maxBlocks, 2)
        let sequential = ProgramSolver.search(
            level: generated.level,
            sequentialLimit: 2,
            includeLoops: false,
            budget: SolverBudget(maxPrograms: 200, maxSteps: 2_000)
        )
        XCTAssertEqual(sequential.conclusion, .absent)
        let withLoops = ProgramSolver.search(
            level: generated.level,
            sequentialLimit: 2,
            includeLoops: true,
            budget: SolverBudget(maxPrograms: 200, maxSteps: 2_000)
        )
        XCTAssertEqual(withLoops.conclusion, .found)
        XCTAssertEqual(withLoops.program?.blockCount, 2)
    }

    func testWallFollowNeedsTheCondition() {
        for seed in UInt64(1)...12 {
            let generated = LevelGenerator.generate(request(seed: seed, level: 4, family: .wallFollow))
            XCTAssertFalse(generated.usedFallback, "graine \(seed) \(generated.validation.rejectionReasons)")
            XCTAssertEqual(generated.level.programConstraints.maxBlocks, 4)
            XCTAssertTrue(generated.level.allowedCommands.contains(.ifBlock))
            let blind = Program(instructions: [
                Instruction(command: .forever, children: [Instruction(command: .moveForward)])
            ])
            var engine = SimulationEngine(level: generated.level, program: blind)
            XCTAssertNotEqual(engine.runUntilTerminal().status, .succeeded, "graine \(seed)")
            let sequential = ProgramSolver.search(
                level: generated.level,
                sequentialLimit: 4,
                includeLoops: false,
                budget: SolverBudget(maxPrograms: 800, maxSteps: 8_000)
            )
            XCTAssertEqual(sequential.conclusion, .absent, "graine \(seed)")
        }
    }

    func testKnownCornerIsFoundByTheLoopCatalog() {
        let found = ProgramSolver.search(
            level: PrototypeLevel.corner,
            sequentialLimit: 4,
            includeLoops: true,
            budget: SolverBudget(maxPrograms: 400, maxSteps: 8_000)
        )
        XCTAssertEqual(found.conclusion, .found)
        guard let program = found.program else {
            return XCTFail("Le catalogue doit proposer une solution")
        }
        var engine = SimulationEngine(level: PrototypeLevel.corner, program: program)
        XCTAssertEqual(engine.runUntilTerminal().status, .succeeded)
    }

    func testTinyBudgetInterruptsInsteadOfClaimingAbsence() {
        let result = ProgramSolver.search(
            level: PrototypeLevel.corridor,
            sequentialLimit: 2,
            includeLoops: false,
            budget: SolverBudget(maxPrograms: 1, maxSteps: 10)
        )
        XCTAssertEqual(result.conclusion, .interrupted)
    }

    func testUnknownVersionAndEmptyBudgetUseAValidatedFallback() {
        var request = self.request(seed: 9, level: 1)
        request.generatorVersion = 99
        let unknown = LevelGenerator.generate(request)
        XCTAssertTrue(unknown.usedFallback)
        var engine = SimulationEngine(level: unknown.level, program: unknown.referenceProgram)
        XCTAssertEqual(engine.runUntilTerminal().status, .succeeded)

        let empty = LevelGenerator.generate(
            self.request(seed: 9, level: 2),
            budget: GenerationBudget(maxAttempts: 0, solver: SolverBudget(maxPrograms: 10, maxSteps: 10))
        )
        XCTAssertTrue(empty.usedFallback)
        engine = SimulationEngine(level: empty.level, program: empty.referenceProgram)
        XCTAssertEqual(engine.runUntilTerminal().status, .succeeded)
        XCTAssertEqual(LevelGenerator.generate(request).level, unknown.level)
    }

    func testDifficultySpanStaysSmall() {
        var rng = SeededGenerator(seed: 1)
        for target in stride(from: 0.0, through: 1.0, by: 0.1) {
            let profile = DifficultyModel.profile(target: target, rng: &rng)
            XCTAssertLessThanOrEqual(profile.maximumSpan, 8)
            XCTAssertGreaterThanOrEqual(profile.maximumSpan, 6)
        }
    }

    private func request(seed: UInt64, level: Int, family: PuzzleFamily? = nil) -> GenerationRequest {
        GenerationRequest(
            seed: seed,
            generatorVersion: LevelGenerator.version,
            worldNumber: 1,
            levelNumber: level,
            targetDifficulty: LevelGenerator.difficulty(forSeed: seed),
            family: family
        )
    }

    private func signature(_ level: Level) -> String {
        let walls = level.grid.cells
            .filter { $0.terrain == .wall }
            .map { "\($0.coordinate.x):\($0.coordinate.y)" }
            .sorted()
            .joined(separator: ",")
        let robot = level.initialRobot
        let flag = level.objectives.first?.position
        return "\(level.grid.width)x\(level.grid.height) \(robot.position.x),\(robot.position.y) \(robot.orientation.rawValue) \(flag?.x ?? -1),\(flag?.y ?? -1) \(walls)"
    }

    private func shape(_ program: Program) -> [String] {
        program.instructions.map(describe)
    }

    private func describe(_ instruction: Instruction) -> String {
        let children = instruction.children.map(describe).joined(separator: ",")
        let condition = instruction.condition?.rawValue ?? ""
        return "\(instruction.command.rawValue)|\(condition)[\(children)]"
    }
}
