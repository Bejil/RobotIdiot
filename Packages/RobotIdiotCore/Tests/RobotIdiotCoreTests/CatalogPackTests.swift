import XCTest
@testable import RobotIdiotCore

final class CatalogPackTests: XCTestCase {
    func testBundledPackPassesStructuralRules() throws {
        let pack = try LevelPackLoader.loadBundled()
        XCTAssertEqual(pack.schemaVersion, LevelPack.supportedSchemaVersion)
        XCTAssertEqual(pack.coordinateSystem, LevelPack.documentedCoordinateSystem)
        XCTAssertEqual(pack.levels.count, 150)
        XCTAssertEqual(LevelPackChecker.issues(in: pack), [])
        XCTAssertEqual(Set(pack.levels.map(\.world)), Set(1...15))
        for world in 1...15 {
            let slice = pack.levels.filter { $0.world == world }
            XCTAssertEqual(slice.map(\.worldLevel), Array(1...10), "monde \(world)")
            let expectedSide = world <= 10 ? 7 : 8
            for level in slice {
                XCTAssertEqual(level.width, expectedSide, level.id)
                XCTAssertEqual(level.height, expectedSide, level.id)
            }
        }
    }

    func testEveryOfficialSolutionMatchesItsActionCount() throws {
        let pack = try LevelPackLoader.loadBundled()
        for level in pack.levels {
            let run = CatalogInterpreter.execute(level)
            XCTAssertEqual(run.result, .victory, "\(level.id) \(run)")
            XCTAssertEqual(run.actions, level.solution.actionCount, level.id)
        }
    }

    func testPlayableLevelsReplayOnTheGameEngine() throws {
        for source in CatalogCampaign.pack.levels {
            let level = CatalogCampaign.playableLevel(source)
            XCTAssertEqual(LevelIntegrity.issues(in: level), [], source.id)
            XCTAssertEqual(level.allowedCommands.map(\.rawValue), source.unlockedCommands, source.id)
            var engine = SimulationEngine(level: level, program: CatalogCampaign.referenceProgram(for: source))
            let final = engine.runUntilTerminal()
            XCTAssertEqual(final.status, .succeeded, "\(source.id) \(String(describing: final.fault))")
            XCTAssertEqual(final.game.metrics.executedInstructions, source.solution.actionCount, source.id)
            XCTAssertTrue(final.game.isVictory, source.id)
        }
    }

    func testVictoryStopsBeforeAnyCommandAfterTheFlag() throws {
        let pack = try LevelPackLoader.loadBundled()
        let level = try XCTUnwrap(pack.levels.first { $0.id == "RI-001" })
        let continued = level.solution.program + [.avance, .avance, .avance]
        let run = CatalogInterpreter.execute(level, program: continued)
        XCTAssertEqual(run.result, .victory)
        XCTAssertEqual(run.actions, level.solution.actionCount)
    }

    func testAdventureLevelSeventyOneUsesOnlyPrimitives() throws {
        let pack = try LevelPackLoader.loadBundled()
        let level = try XCTUnwrap(pack.levels.first { $0.id == "RI-071" })
        XCTAssertFalse(level.solution.program.contains {
            if case .repete = $0 { return true }
            if case .si = $0 { return true }
            return false
        })
        let run = CatalogInterpreter.execute(level)
        XCTAssertEqual(run.result, .victory, "\(run)")
        XCTAssertEqual(run.actions, level.solution.actionCount)
    }

    func testControlNodesStayFreeWhileTheirChildrenStillCount() throws {
        let pack = try LevelPackLoader.loadBundled()
        let campaign = pack.levels.filter { $0.world <= 10 }
        let repeats = campaign.filter { contains($0.solution.program, .repete) }
        let conditions = campaign.filter { contains($0.solution.program, .si) }
        // V14.1 Aventure : aucune solution de référence n'utilise SI/REPETE.
        XCTAssertEqual(repeats.count, 0)
        XCTAssertEqual(conditions.count, 0)
        for level in pack.levels where level.world <= 10 {
            let run = CatalogInterpreter.execute(level)
            XCTAssertEqual(run.result, .victory, level.id)
            XCTAssertEqual(run.actions, level.solution.actionCount, level.id)
        }
    }

    func testWorld3FlagRequiresTheKey() throws {
        let pack = try LevelPackLoader.loadBundled()
        let source = try XCTUnwrap(pack.levels.first { $0.id == "RI-021" })
        XCTAssertTrue(source.objective.requiresItemHeld)
        var withoutKey = source
        withoutKey.solution.program = [.avance]
        var grid = source.grid
        grid[source.start.y] = replace(grid[source.start.y], at: source.start.x, with: "g")
        grid[source.finish.y] = replace(grid[source.finish.y], at: source.finish.x, with: "g")
        let ahead = aheadCell(of: source)
        grid[ahead.y] = replace(grid[ahead.y], at: ahead.x, with: "F")
        withoutKey.grid = grid
        withoutKey.finish = CatalogLevel.Finish(x: ahead.x, y: ahead.y)
        let missed = CatalogInterpreter.execute(withoutKey)
        XCTAssertEqual(missed.result, .endWithoutVictory)

        var holding = withoutKey
        grid[source.start.y] = replace(grid[source.start.y], at: source.start.x, with: "K")
        holding.grid = grid
        holding.mechanics = [CatalogLevel.Mechanic(type: "BoardKey", x: source.start.x, y: source.start.y)]
        holding.solution.program = [.ramasse, .avance]
        let reached = CatalogInterpreter.execute(holding)
        XCTAssertEqual(reached.result, .victory)
        XCTAssertEqual(reached.actions, 2)
    }

    private enum Sought {
        case repete
        case si
    }

    private func contains(_ program: [CatalogInstruction], _ sought: Sought) -> Bool {
        for instruction in program {
            switch (instruction, sought) {
            case (.repete(let body), .repete):
                return true
            case (.si(_, let body), .si):
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

    private func aheadCell(of level: CatalogLevel) -> (x: Int, y: Int) {
        let delta: (Int, Int)
        switch level.start.orientation {
        case "E": delta = (1, 0)
        case "S": delta = (0, 1)
        case "W": delta = (-1, 0)
        default: delta = (0, -1)
        }
        return (level.start.x + delta.0, level.start.y + delta.1)
    }

    func testDisplayedMinimumFollowsStarTargets() {
        for source in CatalogCampaign.pack.levels {
            let level = CatalogCampaign.playableLevel(source)
            if let stars = source.starTargets {
                XCTAssertEqual(
                    level.scoringRules.efficientExecutionMaxSteps,
                    stars.withoutBonus.threeStarsMax,
                    source.id
                )
                XCTAssertEqual(
                    level.scoringRules.efficientExecutionMaxStepsWithBonus,
                    stars.withBonus?.threeStarsMax,
                    source.id
                )
            } else {
                let shortest = ActionSearch.shortest(level: level)?.actionCount
                XCTAssertEqual(level.scoringRules.efficientExecutionMaxSteps, shortest, source.id)
                XCTAssertNotNil(shortest, source.id)
                XCTAssertLessThanOrEqual(shortest!, source.solution.actionCount, source.id)
            }
        }
    }

    private func replace(_ row: String, at index: Int, with symbol: Character) -> String {
        var characters = Array(row)
        characters[index] = symbol
        return String(characters)
    }
}
