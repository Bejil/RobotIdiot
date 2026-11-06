import XCTest
@testable import RobotIdiotCore

final class DailyCatalogTests: XCTestCase {
    func testBundledDailyPacksDecodeWithUniqueIDs() throws {
        let challenges = try DailyCatalog.loadChallengesBundled()
        let bugs = try DailyCatalog.loadBugsBundled()
        XCTAssertEqual(challenges.levels.count, 100)
        XCTAssertEqual(bugs.bugs.count, 100)
        XCTAssertEqual(Set(challenges.levels.map(\.id)).count, 100)
        XCTAssertEqual(Set(bugs.bugs.map(\.id)).count, 100)
        for world in 1...10 {
            XCTAssertEqual(DailyCatalog.challenges(forTier: world).count, 10, "défi palier \(world)")
            XCTAssertEqual(DailyCatalog.bugs(forTier: world).count, 10, "bug palier \(world)")
        }
    }

    func testEveryDailyChallengeSolutionWins() throws {
        let pack = try DailyCatalog.loadChallengesBundled()
        for source in pack.levels {
            let run = CatalogInterpreter.execute(source)
            XCTAssertEqual(run.result, .victory, "\(source.id) \(run)")

            let level = CatalogCampaign.playableLevel(source)
            XCTAssertTrue(level.collectibles.isEmpty, source.id)
            var engine = SimulationEngine(level: level, program: CatalogCampaign.referenceProgram(for: source))
            let final = engine.runUntilTerminal()
            XCTAssertEqual(final.status, .succeeded, "\(source.id) \(String(describing: final.fault))")
            XCTAssertTrue(final.game.isVictory, source.id)
            XCTAssertEqual(
                final.game.metrics.executedInstructions,
                run.actions,
                "\(source.id) moteur vs interpréteur"
            )
        }
    }

    func testEveryBugFailsAndIntendedFixWins() throws {
        let challenges = try DailyCatalog.loadChallengesBundled()
        let bugs = try DailyCatalog.loadBugsBundled()
        let byID = Dictionary(uniqueKeysWithValues: challenges.levels.map { ($0.id, $0) })
        for bug in bugs.bugs {
            let board = try XCTUnwrap(byID[bug.boardRef], bug.id)
            let bad = CatalogInterpreter.execute(board, program: bug.bugProgram)
            XCTAssertNotEqual(bad.result, .victory, bug.id)

            let fixedProgram = try XCTUnwrap(
                DailySelection.replacePrimitive(
                    in: bug.bugProgram,
                    at: bug.intendedBugLineForQA,
                    with: bug.validation.winningReplacement
                ),
                bug.id
            )
            let original = try XCTUnwrap(
                DailySelection.primitive(at: bug.intendedBugLineForQA, in: bug.bugProgram),
                bug.id
            )
            if let expected = bug.validation.originalIncorrectCommand {
                XCTAssertEqual(original.commandName, expected, bug.id)
            }
            let good = CatalogInterpreter.execute(board, program: fixedProgram)
            XCTAssertEqual(good.result, .victory, "\(bug.id) \(good)")
        }
    }

    func testSampleTiersHaveNoLockedCommandsInPrograms() throws {
        let challenges = try DailyCatalog.loadChallengesBundled()
        let bugs = try DailyCatalog.loadBugsBundled()
        for tier in [1, 3, 5, 6, 7, 8, 10] {
            for level in challenges.levels.filter({ $0.world == tier }) {
                assertUnlocked(level.solution.program, allowed: Set(level.unlockedCommands), id: level.id)
            }
            for bug in bugs.bugs.filter({ $0.tier == tier }) {
                assertUnlocked(bug.bugProgram, allowed: Set(bug.availableCommands), id: bug.id)
                assertUnlocked(bug.referenceProgram, allowed: Set(bug.availableCommands), id: bug.id)
            }
        }
    }

    func testDailySelectionIsDeterministicAndFreezesTier() throws {
        let calendar = DailySelection.calendar()
        let epoch = try XCTUnwrap(DailySelection.parseCivilDate("2026-11-04", calendar: calendar))
        let dayA = try XCTUnwrap(calendar.date(byAdding: .day, value: 2, to: epoch))
        let dayB = try XCTUnwrap(calendar.date(byAdding: .day, value: 3, to: epoch))

        let challenges = DailyCatalog.challenges(forTier: 2)
        let bugs = DailyCatalog.bugs(forTier: 2)
        let first = DailySelection.select(tier: 2, on: dayA, challenges: challenges, bugs: bugs)
        let again = DailySelection.select(tier: 2, on: dayA, challenges: challenges, bugs: bugs)
        XCTAssertEqual(first, again)
        XCTAssertNotEqual(first.challengeBoardRef, first.bugBoardRef)

        let nextDay = DailySelection.select(tier: 2, on: dayB, challenges: challenges, bugs: bugs)
        XCTAssertNotEqual(first.civilDate, nextDay.civilDate)

        let higher = DailySelection.select(tier: 5, on: dayA, challenges: DailyCatalog.challenges(forTier: 5), bugs: DailyCatalog.bugs(forTier: 5))
        XCTAssertEqual(higher.civilDate, first.civilDate)
        XCTAssertNotEqual(higher.tier, first.tier)

        // Transition d'heure : minuit Paris + changement d'heure été/hiver.
        let summer = try XCTUnwrap(civilNoon(year: 2026, month: 3, day: 29, calendar: calendar))
        let winter = try XCTUnwrap(civilNoon(year: 2026, month: 10, day: 25, calendar: calendar))
        let summerIndex = DailySelection.dayIndex(on: summer, calendar: calendar)
        let winterIndex = DailySelection.dayIndex(on: winter, calendar: calendar)
        XCTAssertEqual(
            DailySelection.civilDateString(on: summer, calendar: calendar),
            "2026-03-29"
        )
        XCTAssertEqual(
            DailySelection.civilDateString(on: winter, calendar: calendar),
            "2026-10-25"
        )
        XCTAssertGreaterThan(winterIndex, summerIndex)

        let justBefore = try XCTUnwrap(calendar.date(bySettingHour: 23, minute: 30, second: 0, of: dayA))
        let justAfter = try XCTUnwrap(calendar.date(byAdding: .hour, value: 1, to: justBefore))
        XCTAssertEqual(
            DailySelection.civilDateString(on: justBefore, calendar: calendar),
            DailySelection.civilDateString(on: dayA, calendar: calendar)
        )
        XCTAssertEqual(
            DailySelection.civilDateString(on: justAfter, calendar: calendar),
            DailySelection.civilDateString(on: dayB, calendar: calendar)
        )
        XCTAssertEqual(
            DailySelection.dayIndex(on: justAfter, calendar: calendar),
            DailySelection.dayIndex(on: dayA, calendar: calendar) + 1
        )
    }

    func testBoardDoorsRequireLinkedPlate() throws {
        let pack = try DailyCatalog.loadChallengesBundled()
        let withDoors = pack.levels.filter { level in
            level.mechanics.contains { $0.type == "BoardDoor" }
                && level.mechanics.contains { $0.type == "BoardPlate" }
        }
        XCTAssertFalse(withDoors.isEmpty)
        for source in withDoors.prefix(12) {
            let doors = source.mechanics.filter { $0.type == "BoardDoor" }
            for door in doors {
                let link = try XCTUnwrap(door.linkId, source.id)
                XCTAssertTrue(
                    source.mechanics.contains { $0.type == "BoardPlate" && $0.linkId == link },
                    "\(source.id) porte \(link)"
                )
            }
            let run = CatalogInterpreter.execute(source)
            XCTAssertEqual(run.result, .victory, source.id)
        }
    }

    private func assertUnlocked(_ program: [CatalogInstruction], allowed: Set<String>, id: String) {
        func walk(_ nodes: [CatalogInstruction]) {
            for node in nodes {
                XCTAssertTrue(allowed.contains(node.commandName), "\(id) \(node.commandName)")
                switch node {
                case .repete(let body):
                    walk(body)
                case .si(_, let body):
                    walk(body)
                default:
                    break
                }
            }
        }
        walk(program)
    }

    private func civilNoon(year: Int, month: Int, day: Int, calendar: Calendar) -> Date? {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = 12
        return calendar.date(from: components)
    }
}
