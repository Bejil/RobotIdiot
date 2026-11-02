import XCTest
@testable import RobotIdiotCore

final class ProgramTextTests: XCTestCase {
    func testPrintedProgramParsesBackToTheSameShape() {
        let loop = Instruction(
            command: .forever,
            children: [
                Instruction(command: .ifBlock, condition: .obstacleAhead, children: [Instruction(command: .turnLeft)]),
                Instruction(command: .moveForward)
            ]
        )
        let program = Program(instructions: [loop, Instruction(command: .pickUp)])
        let rendered = ProgramText.render(program)
        XCTAssertEqual(
            rendered.source,
            """
            REPETE
              SI OBSTACLE_DEVANT
                TOURNE_GAUCHE
              AVANCE
            RAMASSE

            """
        )
        let parsed = ProgramText.parse(rendered.source, allowed: CommandType.allCases)
        XCTAssertEqual(ProgramText.render(parsed.program ?? Program()).source, rendered.source)
        XCTAssertEqual(rendered.lineIDs.compactMap { $0 }.count, 5)
    }

    func testRepeatNeverAcceptsACounter() {
        let counted = ProgramText.parse("REPETE 3\n  AVANCE\n", allowed: CommandType.allCases)
        XCTAssertNil(counted.program)
        XCTAssertEqual(counted.diagnostics.first?.message, "Répète n'a pas de nombre de tours.")

        let call = ProgramText.parse("REPETE(4)\n", allowed: [.forever])
        XCTAssertNil(call.program)
        XCTAssertEqual(call.diagnostics.first?.message, "Répète n'a pas de nombre de tours.")
    }

    func testInvalidDraftReportsTheLineAndKeepsNoProgram() {
        let missing = ProgramText.parse("SI\n  AVANCE\n", allowed: [.ifBlock, .moveForward])
        XCTAssertNil(missing.program)
        XCTAssertEqual(missing.diagnostics.first?.line, 1)

        let deep = ProgramText.parse("AVANCE\n    RECULE\n", allowed: CommandType.movement)
        XCTAssertNil(deep.program)
        XCTAssertEqual(deep.diagnostics.first?.line, 2)

        let odd = ProgramText.parse(" AVANCE\n", allowed: CommandType.movement)
        XCTAssertEqual(odd.diagnostics.first?.message, "L'indentation doit aller de deux en deux.")

        let unknown = ProgramText.parse("SAUTE\n", allowed: CommandType.movement)
        XCTAssertEqual(unknown.diagnostics.first?.message, "Commande inconnue.")

        let blocked = ProgramText.parse("REPETE\n  AVANCE\n", allowed: CommandType.movement)
        XCTAssertEqual(blocked.diagnostics.first?.message, "Cette commande n'est pas disponible dans ce niveau.")
    }

    func testLowercaseStillBuildsTheCommand() {
        let parsed = ProgramText.parse("avance\nsi obstacle_devant\n  tourne_gauche\n", allowed: [.moveForward, .ifBlock, .turnLeft])
        let program = parsed.program
        XCTAssertEqual(program?.instructions.map(\.command), [.moveForward, .ifBlock])
        XCTAssertEqual(program?.instructions[1].condition, .obstacleAhead)
        XCTAssertEqual(program?.instructions[1].children.map(\.command), [.turnLeft])
    }

    func testCompletionsFollowTheWordUnderTheCursor() {
        let moves = ProgramText.completions(in: "AV", cursorUTF16: 2, allowed: CommandType.movement)
        XCTAssertEqual(moves.items, [.command(.moveForward)])
        XCTAssertEqual(moves.replacementUTF16, NSRange(location: 0, length: 2))

        let conditions = ProgramText.completions(in: "SI OBS", cursorUTF16: 6, allowed: [.ifBlock])
        XCTAssertEqual(conditions.items, [.condition(.obstacleAhead)])

        let shared = ProgramText.completions(in: "SI OB", cursorUTF16: 5, allowed: [.ifBlock])
        XCTAssertEqual(shared.items, [.condition(.obstacleAhead), .condition(.objectPresent)])

        let all = ProgramText.completions(in: "SI ", cursorUTF16: 3, allowed: [.ifBlock])
        XCTAssertEqual(all.items.count, ConditionType.allCases.count)
    }

    func testRelocateDropsACommandIntoALoopAndRefusesACycle() {
        let loop = Instruction(command: .forever, children: [Instruction(command: .moveForward)])
        let extra = Instruction(command: .turnLeft)
        var program = Program(instructions: [loop, extra])
        XCTAssertTrue(program.relocate(extra.id, to: .into(loop.id)))
        XCTAssertEqual(program.instructions.count, 1)
        XCTAssertEqual(program.instructions[0].children.map(\.command), [.moveForward, .turnLeft])

        let child = program.instructions[0].children[0].id
        XCTAssertFalse(program.relocate(program.instructions[0].id, to: .into(child)))
        XCTAssertEqual(program.instructions.count, 1)

        XCTAssertTrue(program.relocate(child, to: .atRootEnd))
        XCTAssertEqual(program.instructions.map(\.command), [.forever, .moveForward])
    }

    func testAdoptedLinesKeepTheExistingIdentifiers() {
        let program = Program(instructions: [
            Instruction(command: .moveForward),
            Instruction(command: .turnRight)
        ])
        let parsed = ProgramText.parse("AVANCE\n\nTOURNE_DROITE\n", allowed: CommandType.movement)
        let lines = ProgramText.adoptedLineIDs(parsed.lineIDs, program: program)
        XCTAssertEqual(lines.map { $0 }, [program.instructions[0].id, nil, program.instructions[1].id])
    }
}
