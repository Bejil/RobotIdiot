import XCTest
@testable import RobotIdiotCore

final class CampaignTests: XCTestCase {
    func testBlueprintIsStableAndHasElevenSlots() {
        let first = WorldGenerator.blueprint(campaignSeed: 99, world: 4)
        let second = WorldGenerator.blueprint(campaignSeed: 99, world: 4)
        XCTAssertEqual(first, second)
        XCTAssertEqual(first.slots.count, 11)
        XCTAssertEqual(first.slots.last?.isFinale, true)
        XCTAssertEqual(first.slots.last?.levelNumber, 11)
        XCTAssertNotEqual(
            WorldGenerator.worldSeed(campaign: 99, world: 4),
            WorldGenerator.worldSeed(campaign: 99, world: 5)
        )
    }

    func testDifficultyRisesAcrossWorldsAndBreathesInsideOne() {
        var previous = WorldGenerator.curve(forWorld: 1)
        for world in 2...40 {
            let curve = WorldGenerator.curve(forWorld: world)
            XCTAssertGreaterThanOrEqual(curve, previous)
            previous = curve
        }
        XCTAssertLessThanOrEqual(WorldGenerator.curve(forWorld: 10_000), 0.9)
        let world = WorldGenerator.blueprint(campaignSeed: 3, world: 6)
        let accessible = world.slots[0].request.targetDifficulty
        let laterAccessible = world.slots[2].request.targetDifficulty
        XCTAssertEqual(world.slots[0].pace, .accessible)
        XCTAssertEqual(world.slots[1].pace, .intermediate)
        XCTAssertEqual(world.slots[2].pace, .accessible)
        XCTAssertEqual(accessible, laterAccessible, accuracy: 0.0001)
        let finale = world.slots.last!.request.targetDifficulty
        let hardestStandard = world.slots.dropLast().map(\.request.targetDifficulty).max() ?? 0
        XCTAssertGreaterThan(finale, hardestStandard)
    }

    func testUnlocksFollowTheWorldNumber() {
        let first = WorldGenerator.families(forWorld: 1)
        XCTAssertFalse(first.contains(.infiniteCorridor))
        XCTAssertFalse(first.contains(.wallFollow))
        XCTAssertEqual(WorldGenerator.families(forWorld: 2).last, .infiniteCorridor)
        XCTAssertEqual(WorldGenerator.families(forWorld: 3).last, .wallFollow)
        XCTAssertEqual(WorldGenerator.theme(forWorld: 1), .laboratory)
        XCTAssertEqual(WorldGenerator.theme(forWorld: 2), .orchard)
        XCTAssertEqual(WorldGenerator.theme(forWorld: 5), .laboratory)
    }

    func testEarlyWorldsStayInsideTheirUnlockedCommands() {
        let campaign = WorldGenerator.blueprint(campaignSeed: 11, world: 1)
        for slot in [campaign.slots[0], campaign.slots[10]] {
            let generated = LevelGenerator.generate(slot.request)
            XCTAssertFalse(generated.level.allowedCommands.contains(.forever), slot.levelNumber.description)
            XCTAssertFalse(generated.level.allowedCommands.contains(.ifBlock))
            XCTAssertEqual(generated.level.theme, .laboratory)
            var engine = SimulationEngine(level: generated.level, program: generated.referenceProgram)
            XCTAssertEqual(engine.runUntilTerminal().status, .succeeded)
        }

        let loops = WorldGenerator.blueprint(campaignSeed: 11, world: 2).slots.last!
        let looped = LevelGenerator.generate(loops.request)
        XCTAssertTrue(looped.level.allowedCommands.contains(.forever))
        XCTAssertFalse(looped.level.allowedCommands.contains(.ifBlock))
        XCTAssertEqual(looped.level.theme, .orchard)

        let conditions = WorldGenerator.blueprint(campaignSeed: 11, world: 3).slots.last!
        let conditional = LevelGenerator.generate(conditions.request)
        XCTAssertTrue(conditional.level.allowedCommands.contains(.ifBlock))
        XCTAssertEqual(conditional.level.theme, .night)
    }

    func testProgressUnlocksTheNextLevelThenTheNextWorld() {
        var progress = CampaignProgress(campaignSeed: 5)
        let layout = CampaignLayout(standardLevelCount: 2, includesFinale: true)
        XCTAssertEqual(CampaignRules.unlockedWorld(in: progress, layout: layout), 1)
        XCTAssertEqual(CampaignRules.continueAddress(in: progress, layout: layout), LevelAddress(world: 1, level: 1))
        XCTAssertFalse(CampaignRules.isLevelUnlocked(LevelAddress(world: 1, level: 2), progress: progress, layout: layout))
        XCTAssertFalse(CampaignRules.isLevelUnlocked(LevelAddress(world: 2, level: 1), progress: progress, layout: layout))

        CampaignRules.record(LevelScore(stars: 1, blockCount: 4, executedInstructions: 6), at: LevelAddress(world: 1, level: 1), in: &progress)
        XCTAssertTrue(CampaignRules.isLevelUnlocked(LevelAddress(world: 1, level: 2), progress: progress, layout: layout))
        CampaignRules.record(LevelScore(stars: 3, blockCount: 4, executedInstructions: 9), at: LevelAddress(world: 1, level: 1), in: &progress)
        CampaignRules.record(LevelScore(stars: 1, blockCount: 9, executedInstructions: 9), at: LevelAddress(world: 1, level: 1), in: &progress)
        XCTAssertEqual(progress.score(at: LevelAddress(world: 1, level: 1))?.stars, 3)
        XCTAssertEqual(progress.score(at: LevelAddress(world: 1, level: 1))?.blockCount, 4)

        CampaignRules.record(LevelScore(stars: 2, blockCount: 3, executedInstructions: 4), at: LevelAddress(world: 1, level: 2), in: &progress)
        XCTAssertTrue(CampaignRules.isLevelUnlocked(LevelAddress(world: 1, level: 3), progress: progress, layout: layout))
        XCTAssertFalse(CampaignRules.isLevelUnlocked(LevelAddress(world: 2, level: 1), progress: progress, layout: layout))
        CampaignRules.record(LevelScore(stars: 1, blockCount: 2, executedInstructions: 5), at: LevelAddress(world: 1, level: 3), in: &progress)
        XCTAssertEqual(CampaignRules.unlockedWorld(in: progress, layout: layout), 2)
        XCTAssertEqual(CampaignRules.continueAddress(in: progress, layout: layout), LevelAddress(world: 2, level: 1))
        XCTAssertTrue(CampaignRules.isLevelUnlocked(LevelAddress(world: 2, level: 1), progress: progress, layout: layout))
        XCTAssertFalse(CampaignRules.isLevelUnlocked(LevelAddress(world: 2, level: 2), progress: progress, layout: layout))
        XCTAssertEqual(
            CampaignRules.nextAddress(after: LevelAddress(world: 1, level: 3), layout: layout),
            LevelAddress(world: 2, level: 1)
        )
        XCTAssertEqual(CampaignRules.stars(inWorld: 1, progress: progress), 6)
    }

    func testProgressRoundTripsThroughJSON() throws {
        var progress = CampaignProgress(campaignSeed: 80)
        CampaignRules.record(
            LevelScore(stars: 2, blockCount: 4, executedInstructions: 7),
            at: LevelAddress(world: 1, level: 1),
            in: &progress
        )
        let data = try JSONEncoder().encode(progress)
        let decoded = try JSONDecoder().decode(CampaignProgress.self, from: data)
        XCTAssertEqual(decoded, progress)
    }
}
