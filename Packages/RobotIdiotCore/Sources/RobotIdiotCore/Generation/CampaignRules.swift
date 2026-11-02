import Foundation

public struct LevelAddress: Codable, Hashable, Sendable {
    public var world: Int
    public var level: Int

    public init(world: Int, level: Int) {
        self.world = world
        self.level = level
    }
}

public struct LevelScore: Codable, Hashable, Sendable {
    public var stars: Int
    public var blockCount: Int
    public var executedInstructions: Int

    public init(stars: Int, blockCount: Int, executedInstructions: Int) {
        self.stars = stars
        self.blockCount = blockCount
        self.executedInstructions = executedInstructions
    }

    public func isBetter(than other: LevelScore) -> Bool {
        if stars != other.stars { return stars > other.stars }
        if blockCount != other.blockCount { return blockCount < other.blockCount }
        return executedInstructions < other.executedInstructions
    }
}

public struct ScoreRecord: Codable, Hashable, Sendable {
    public var address: LevelAddress
    public var score: LevelScore

    public init(address: LevelAddress, score: LevelScore) {
        self.address = address
        self.score = score
    }
}

public struct CampaignProgress: Codable, Equatable, Sendable {
    public var campaignSeed: UInt64
    public var generatorVersion: Int
    public var formulaVersion: Int
    public var records: [ScoreRecord]

    public init(
        campaignSeed: UInt64,
        generatorVersion: Int = LevelGenerator.version,
        formulaVersion: Int = WorldGenerator.formulaVersion,
        records: [ScoreRecord] = []
    ) {
        self.campaignSeed = campaignSeed
        self.generatorVersion = generatorVersion
        self.formulaVersion = formulaVersion
        self.records = records
    }

    public func score(at address: LevelAddress) -> LevelScore? {
        records.first { $0.address == address }?.score
    }
}

public enum CampaignRules {
    public static func unlockedWorld(in progress: CampaignProgress, layout: CampaignLayout = .standard) -> Int {
        var world = 1
        while isCompleted(LevelAddress(world: world, level: layout.levelCount), progress: progress), layout.isFinale(layout.levelCount) {
            world += 1
        }
        return world
    }

    public static func isLevelUnlocked(
        _ address: LevelAddress,
        progress: CampaignProgress,
        layout: CampaignLayout = .standard
    ) -> Bool {
        guard address.world >= 1, address.level >= 1, address.level <= layout.levelCount else { return false }
        guard address.world <= unlockedWorld(in: progress, layout: layout) else { return false }
        if address.level == 1 { return true }
        return isCompleted(LevelAddress(world: address.world, level: address.level - 1), progress: progress)
    }

    public static func isCompleted(_ address: LevelAddress, progress: CampaignProgress) -> Bool {
        progress.score(at: address) != nil
    }

    public static func record(
        _ incoming: LevelScore,
        at address: LevelAddress,
        in progress: inout CampaignProgress
    ) {
        if let index = progress.records.firstIndex(where: { $0.address == address }) {
            if incoming.isBetter(than: progress.records[index].score) {
                progress.records[index].score = incoming
            }
        } else {
            progress.records.append(ScoreRecord(address: address, score: incoming))
        }
    }

    public static func continueAddress(
        in progress: CampaignProgress,
        layout: CampaignLayout = .standard
    ) -> LevelAddress {
        let opened = unlockedWorld(in: progress, layout: layout)
        for world in 1...opened {
            for level in 1...layout.levelCount {
                let address = LevelAddress(world: world, level: level)
                if progress.score(at: address) == nil { return address }
            }
        }
        return LevelAddress(world: opened, level: 1)
    }

    public static func nextAddress(
        after address: LevelAddress,
        layout: CampaignLayout = .standard
    ) -> LevelAddress {
        if address.level < layout.levelCount {
            return LevelAddress(world: address.world, level: address.level + 1)
        }
        return LevelAddress(world: address.world + 1, level: 1)
    }

    public static func stars(inWorld world: Int, progress: CampaignProgress) -> Int {
        progress.records.reduce(0) { partial, record in
            record.address.world == world ? partial + record.score.stars : partial
        }
    }
}
