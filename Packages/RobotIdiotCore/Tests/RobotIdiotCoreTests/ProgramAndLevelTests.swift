import XCTest
@testable import RobotIdiotCore

final class ProgramAndLevelTests: XCTestCase {
    func testPrototypeLevelIsCoherent() {
        XCTAssertEqual(LevelIntegrity.issues(in: PrototypeLevel.firstSteps), [])
        XCTAssertEqual(PrototypeLevel.referenceProgram().blockCount, 9)
        XCTAssertEqual(PrototypeLevel.referenceProgram().nestingDepth, 1)
        XCTAssertEqual(ProgramValidator.issues(
            in: PrototypeLevel.referenceProgram(),
            level: PrototypeLevel.firstSteps
        ), [])
    }

    func testLevelRoundTripsThroughJSON() throws {
        let data = try JSONEncoder().encode(PrototypeLevel.firstSteps)
        let decoded = try JSONDecoder().decode(Level.self, from: data)
        XCTAssertEqual(decoded, PrototypeLevel.firstSteps)
    }

    func testProgramEditsKeepSemantics() {
        var program = Program()
        program.appendRoot(.moveForward)
        program.appendRoot(.turnLeft)
        program.appendRoot(.moveBackward)
        let first = program.instructions[0].id
        XCTAssertTrue(program.duplicate(id: first))
        XCTAssertEqual(program.instructions.map(\.command), [.moveForward, .moveForward, .turnLeft, .moveBackward])
        XCTAssertNotEqual(program.instructions[0].id, program.instructions[1].id)

        program.relocateRoot(from: 3, to: 0)
        XCTAssertEqual(program.instructions.map(\.command), [.moveBackward, .moveForward, .moveForward, .turnLeft])

        let removed = program.instructions[0].id
        XCTAssertTrue(program.remove(id: removed))
        XCTAssertEqual(program.blockCount, 3)
    }

    func testNestedBlockCountIncludesChildren() {
        let body = Instruction(command: .moveForward)
        let loop = Instruction(command: .forever, children: [body, Instruction(command: .turnRight)])
        let program = Program(instructions: [loop])
        XCTAssertEqual(program.blockCount, 3)
        XCTAssertEqual(program.nestingDepth, 2)
    }

    func testValidatorRejectsIllegalShapes() {
        let level = PrototypeLevel.firstSteps
        let leaf = Instruction(command: .moveForward, children: [Instruction(command: .turnLeft)])
        let forever = Instruction(command: .forever, children: [])
        let conditional = Instruction(command: .ifBlock, children: [Instruction(command: .moveForward)])
        let program = Program(instructions: [leaf, forever, conditional])
        let issues = ProgramValidator.issues(in: program, level: level)
        XCTAssertTrue(issues.contains(.leafHasChildren(.moveForward)))
        XCTAssertTrue(issues.contains(.commandNotAllowed(.forever)))
        XCTAssertTrue(issues.contains(.emptyForever))
        XCTAssertTrue(issues.contains(.commandNotAllowed(.ifBlock)))
        XCTAssertTrue(issues.contains(.missingCondition))
        XCTAssertTrue(issues.contains(.nestingTooDeep(limit: 1)))
    }

    func testConditionOnAMoveIsRejected() {
        let program = Program(instructions: [
            Instruction(command: .moveForward, condition: .obstacleAhead)
        ])
        let issues = ProgramValidator.issues(in: program, level: PrototypeLevel.firstSteps)
        XCTAssertEqual(issues, [.unexpectedCondition(.moveForward)])
    }

    func testDuplicateNestedInstructionKeepsNewIdentifiers() throws {
        let inner = Instruction(command: .moveForward)
        var program = Program(instructions: [
            Instruction(command: .forever, children: [inner])
        ])
        XCTAssertTrue(program.duplicate(id: inner.id))
        let children = try XCTUnwrap(program.instructions.first?.children)
        XCTAssertEqual(children.count, 2)
        XCTAssertEqual(children.map(\.command), [.moveForward, .moveForward])
        XCTAssertNotEqual(children[0].id, children[1].id)
    }
}

enum TestLevels {
    static func openRoom(robot: RobotState, walls: Set<GridCoordinate> = []) -> Level {
        Level(
            id: "test-room",
            version: 1,
            seed: 0,
            generatorVersion: 0,
            worldNumber: 0,
            levelNumber: 0,
            difficulty: 0,
            theme: .laboratory,
            grid: Grid(width: 5, height: 5, walls: walls),
            initialRobot: robot,
            objectives: [
                Objective(id: "flag", kind: .reachFlag, position: GridCoordinate(x: 4, y: 4))
            ],
            allowedCommands: CommandType.movement,
            programConstraints: .flat,
            scoringRules: ScoringRules(
                compactProgramMaxBlocks: nil,
                efficientExecutionMaxSteps: nil,
                referenceNote: "Salle de test"
            ),
            validation: ValidationMetadata(status: .handcrafted)
        )
    }

    static func room(robot: RobotState, terrain: [GridCoordinate: TerrainType]) -> Level {
        var level = openRoom(robot: robot)
        for (coordinate, surface) in terrain {
            level.grid.updateCell(at: coordinate) { cell in
                cell.terrain = surface
            }
        }
        return level
    }
}
