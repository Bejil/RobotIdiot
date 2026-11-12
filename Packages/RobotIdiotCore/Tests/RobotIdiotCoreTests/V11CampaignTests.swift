import XCTest
@testable import RobotIdiotCore

/// Mondes 11–15 (V11) : programmes SI+REPETE et parcours bonus.
final class V11CampaignTests: XCTestCase {
    private var advancedLevels: [CatalogLevel] {
        CatalogCampaign.pack.levels.filter { $0.world >= 11 }
    }

    func testAdvancedWorldsAreEightByEightWithFiftyLevels() {
        XCTAssertEqual(advancedLevels.count, 50)
        XCTAssertEqual(Set(advancedLevels.map(\.world)), Set(11...15))
        for level in advancedLevels {
            XCTAssertEqual(level.width, 8, level.id)
            XCTAssertEqual(level.height, 8, level.id)
            XCTAssertEqual(level.grid.count, 8, level.id)
            XCTAssertTrue(level.grid.allSatisfy { $0.count == 8 }, level.id)
            let joined = level.grid.joined()
            XCTAssertFalse(joined.contains("c"), level.id)
            XCTAssertFalse(joined.contains("l"), level.id)
            XCTAssertFalse(joined.contains(where: \.isNumber), level.id)
        }
    }

    func testEveryAdvancedSolutionUsesConditionAndLoop() {
        for level in advancedLevels {
            XCTAssertTrue(contains(level.solution.program, .si), level.id)
            XCTAssertTrue(contains(level.solution.program, .repete), level.id)
            let run = CatalogInterpreter.execute(level)
            XCTAssertEqual(run.result, .victory, "\(level.id) \(run)")
            XCTAssertEqual(run.actions, level.solution.actionCount, level.id)
        }
    }

    func testAdvancedSolutionsReplayOnGameEngine() {
        for source in advancedLevels {
            let level = CatalogCampaign.playableLevel(source)
            XCTAssertEqual(LevelIntegrity.issues(in: level), [], source.id)
            var engine = SimulationEngine(
                level: level,
                program: CatalogCampaign.referenceProgram(for: source)
            )
            let final = engine.runUntilTerminal()
            XCTAssertEqual(final.status, .succeeded, "\(source.id) \(String(describing: final.fault))")
            XCTAssertEqual(final.game.metrics.executedInstructions, source.solution.actionCount, source.id)
            XCTAssertTrue(final.game.isVictory, source.id)
        }
    }

    func testBonusReferenceProgramsWinWhenPresent() throws {
        // Les bonus des mondes 11–15 sont couverts par V13PortalCampaignTests (champ `v13`).
        // Ce test ne s’applique plus qu’aux packs qui exposent encore `v11`.
        let url = try XCTUnwrap(
            Bundle.module.url(forResource: "robot_idiot_100_levels_v7", withExtension: "json")
        )
        let data = try Data(contentsOf: url)
        let file = try JSONDecoder().decode(V11PackFile.self, from: data)
        let bonusLevels = file.levels.filter {
            ($0.v11?.bonusReferenceProgram?.isEmpty == false)
        }
        if bonusLevels.isEmpty {
            return
        }
        XCTAssertEqual(bonusLevels.count, 15)

        let pack = try LevelPackLoader.loadBundled()
        for entry in bonusLevels {
            let source = try XCTUnwrap(pack.levels.first { $0.id == entry.id })
            let program = try XCTUnwrap(entry.v11?.bonusReferenceProgram)
            let expected = try XCTUnwrap(entry.v11?.bonusReferenceActions)
            let run = CatalogInterpreter.execute(source, program: program)
            XCTAssertEqual(run.result, .victory, "\(entry.id) bonus \(run)")
            XCTAssertEqual(run.actions, expected, entry.id)

            var engine = SimulationEngine(
                level: CatalogCampaign.playableLevel(source),
                program: Program(instructions: program.compactMap(mapInstruction))
            )
            let final = engine.runUntilTerminal()
            XCTAssertEqual(final.status, .succeeded, "\(entry.id) bonus engine")
            XCTAssertEqual(final.game.metrics.executedInstructions, expected, entry.id)
        }
    }

    // MARK: - Helpers

    private enum Sought {
        case si, repete
    }

    private func contains(_ program: [CatalogInstruction], _ sought: Sought) -> Bool {
        for instruction in program {
            switch (instruction, sought) {
            case (.repete, .repete), (.si, .si):
                return true
            case (.repete(let body), _):
                if contains(body, sought) { return true }
            case (.si(_, let body), _):
                if contains(body, sought) { return true }
            default:
                break
            }
        }
        return false
    }

    private func mapInstruction(_ instruction: CatalogInstruction) -> Instruction? {
        switch instruction {
        case .avance: return Instruction(command: .moveForward)
        case .recule: return Instruction(command: .moveBackward)
        case .tourneGauche: return Instruction(command: .turnLeft)
        case .tourneDroite: return Instruction(command: .turnRight)
        case .ramasse: return Instruction(command: .pickUp)
        case .utilise: return Instruction(command: .use)
        case .pousse: return Instruction(command: .push)
        case .active: return Instruction(command: .activate)
        case .repete(let body):
            return Instruction(command: .forever, children: body.compactMap(mapInstruction))
        case .si(let condition, let body):
            let mapped = CatalogCampaign.mapCondition(condition) ?? .obstacleAhead
            return Instruction(
                command: .ifBlock,
                condition: mapped,
                children: body.compactMap(mapInstruction)
            )
        }
    }
}

private struct V11PackFile: Decodable {
    var levels: [V11LevelEntry]
}

private struct V11LevelEntry: Decodable {
    var id: String
    var v11: V11Meta?
}

private struct V11Meta: Decodable {
    var bonusReferenceProgram: [CatalogInstruction]?
    var bonusReferenceActions: Int?
}
