import XCTest
@testable import RobotIdiotCore

/// Mondes 9–15 (V14) : labyrinthes à portails, ≤ 3 paires A/B/C.
final class V13PortalCampaignTests: XCTestCase {
    private var portalLevels: [CatalogLevel] {
        CatalogCampaign.pack.levels.filter { $0.world >= 9 }
    }

    func testSeventyPortalLevelsWithExpectedGrids() {
        XCTAssertEqual(portalLevels.count, 70)
        XCTAssertEqual(CatalogCampaign.pack.schemaVersion, "14.1")
        XCTAssertEqual(CatalogCampaign.pack.levels.count, 150)
        for level in portalLevels {
            let expected = level.world <= 10 ? 7 : 8
            XCTAssertEqual(level.width, expected, level.id)
            XCTAssertEqual(level.height, expected, level.id)
            XCTAssertFalse(level.portalLinks.isEmpty, level.id)
            XCTAssertLessThanOrEqual(level.portalLinks.count, LevelPackChecker.maxPortalPairsPerLevel, level.id)
            XCTAssertTrue(level.grid.joined().contains("Q"), level.id)
            XCTAssertFalse(level.grid.joined().contains(where: \.isNumber), level.id)
            XCTAssertFalse(level.grid.joined().contains("c"), level.id)
            XCTAssertFalse(level.grid.joined().contains("l"), level.id)
            for link in level.portalLinks {
                XCTAssertTrue(LevelPackChecker.portalVariants.contains(link.visualVariant), "\(level.id) \(link.visualVariant)")
            }
        }
    }

    func testWorldsOneToEightUnchangedHaveNoPortals() {
        for level in CatalogCampaign.pack.levels where level.world <= 8 {
            XCTAssertTrue(level.portalLinks.isEmpty, level.id)
            XCTAssertFalse(level.grid.joined().contains("Q"), level.id)
        }
    }

    func testEveryPortalSolutionReplaysOnInterpreterAndEngine() {
        for source in portalLevels {
            let run = CatalogInterpreter.execute(source)
            XCTAssertEqual(run.result, .victory, "\(source.id) interpreter \(run)")
            XCTAssertEqual(run.actions, source.solution.actionCount, source.id)

            let level = CatalogCampaign.playableLevel(source)
            XCTAssertEqual(LevelIntegrity.issues(in: level), [], source.id)
            XCTAssertFalse(level.portalLinks.isEmpty, source.id)
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

    func testBonusProgramsFromRawJSON() throws {
        let url = try XCTUnwrap(
            Bundle.module.url(forResource: "robot_idiot_100_levels_v7", withExtension: "json")
        )
        let file = try JSONDecoder().decode(V14PackFile.self, from: Data(contentsOf: url))
        let bonusLevels = file.levels.filter { $0.v14?.bonusReferenceProgram?.isEmpty == false }
        XCTAssertEqual(bonusLevels.count, 21)

        let pack = try LevelPackLoader.loadBundled()
        for entry in bonusLevels {
            let source = try XCTUnwrap(pack.levels.first { $0.id == entry.id })
            let program = try XCTUnwrap(entry.v14?.bonusReferenceProgram)
            let expected = entry.v14?.bonusReferenceCommands?.count
                ?? entry.v14?.bonusReferenceActions
            let run = CatalogInterpreter.execute(source, program: program)
            XCTAssertEqual(run.result, .victory, "\(entry.id) bonus \(run)")
            if let expected {
                XCTAssertEqual(run.actions, expected, entry.id)
            }

            var engine = SimulationEngine(
                level: CatalogCampaign.playableLevel(source),
                program: Program(instructions: program.compactMap(mapInstruction))
            )
            let final = engine.runUntilTerminal()
            XCTAssertEqual(final.status, .succeeded, "\(entry.id) bonus engine")
            if let expected {
                XCTAssertEqual(final.game.metrics.executedInstructions, expected, entry.id)
            }
            XCTAssertTrue(final.game.collectedBonusThisAttempt, entry.id)
        }
    }

    func testSpotlightPortalLevelsDecodeAndWin() throws {
        // 9-1, 9-2, 9-3, 10-10, 11-1, 13-10, 14-10, 15-10
        let ids = ["RI-081", "RI-082", "RI-083", "RI-100", "RI-101", "RI-130", "RI-140", "RI-150"]
        for id in ids {
            let source = try XCTUnwrap(CatalogCampaign.pack.levels.first { $0.id == id })
            XCTAssertLessThanOrEqual(source.portalLinks.count, 3, id)
            XCTAssertEqual(CatalogInterpreter.execute(source).result, .victory, id)
            var engine = SimulationEngine(
                level: CatalogCampaign.playableLevel(source),
                program: CatalogCampaign.referenceProgram(for: source)
            )
            XCTAssertEqual(engine.runUntilTerminal().status, .succeeded, id)
        }
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

private struct V14PackFile: Decodable {
    var levels: [V14LevelEntry]
}

private struct V14LevelEntry: Decodable {
    var id: String
    var v14: V14Meta?
}

private struct V14Meta: Decodable {
    var bonusReferenceProgram: [CatalogInstruction]?
    var bonusReferenceCommands: [String]?
    var bonusReferenceActions: Int?
}
