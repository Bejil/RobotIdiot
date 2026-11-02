import Foundation

public struct CampaignLayout: Equatable, Sendable {
    public var standardLevelCount: Int
    public var includesFinale: Bool

    public init(standardLevelCount: Int, includesFinale: Bool) {
        self.standardLevelCount = max(1, standardLevelCount)
        self.includesFinale = includesFinale
    }

    public static let standard = CampaignLayout(standardLevelCount: 10, includesFinale: true)

    public var levelCount: Int {
        standardLevelCount + (includesFinale ? 1 : 0)
    }

    public func isFinale(_ level: Int) -> Bool {
        includesFinale && level == levelCount
    }
}

public enum LevelPace: String, Codable, Hashable, Sendable {
    case accessible
    case intermediate
    case demanding
}

public struct LevelSlot: Equatable, Sendable {
    public var levelNumber: Int
    public var isFinale: Bool
    public var pace: LevelPace
    public var request: GenerationRequest

    public init(levelNumber: Int, isFinale: Bool, pace: LevelPace, request: GenerationRequest) {
        self.levelNumber = levelNumber
        self.isFinale = isFinale
        self.pace = pace
        self.request = request
    }
}

public struct WorldBlueprint: Equatable, Sendable {
    public var worldNumber: Int
    public var seed: UInt64
    public var theme: ThemeIdentifier
    public var targetDifficulty: Double
    public var families: [PuzzleFamily]
    public var slots: [LevelSlot]

    public init(
        worldNumber: Int,
        seed: UInt64,
        theme: ThemeIdentifier,
        targetDifficulty: Double,
        families: [PuzzleFamily],
        slots: [LevelSlot]
    ) {
        self.worldNumber = worldNumber
        self.seed = seed
        self.theme = theme
        self.targetDifficulty = targetDifficulty
        self.families = families
        self.slots = slots
    }
}

public enum WorldGenerator {
    public static let formulaVersion = 2

    public static func blueprint(
        campaignSeed: UInt64,
        world: Int,
        layout: CampaignLayout = .standard,
        generatorVersion: Int = LevelGenerator.version
    ) -> WorldBlueprint {
        let number = max(1, world)
        let families = families(forWorld: number)
        let seed = worldSeed(campaign: campaignSeed, world: number)
        let theme = theme(forWorld: number)
        let curve = curve(forWorld: number)
        var slots: [LevelSlot] = []
        for level in 1...layout.levelCount {
            let finale = layout.isFinale(level)
            let pace = pace(forLevel: level, finale: finale)
            let difficulty = targetDifficulty(world: number, pace: pace, finale: finale)
            let request = GenerationRequest(
                seed: seed,
                generatorVersion: generatorVersion,
                worldNumber: number,
                levelNumber: level,
                targetDifficulty: difficulty,
                family: family(in: families, pace: pace, finale: finale),
                theme: theme
            )
            slots.append(LevelSlot(levelNumber: level, isFinale: finale, pace: pace, request: request))
        }
        return WorldBlueprint(
            worldNumber: number,
            seed: seed,
            theme: theme,
            targetDifficulty: curve,
            families: families,
            slots: slots
        )
    }

    /// Monte avec le numéro de monde, puis se stabilise. La taille des plateaux reste bornée.
    public static func curve(forWorld world: Int) -> Double {
        let steps = Double(max(world, 1) - 1)
        return min(0.9, 0.18 + 0.70 * (steps / (steps + 7)))
    }

    public static func families(forWorld world: Int) -> [PuzzleFamily] {
        switch max(1, world) {
        case 1:
            return [.openWalk, .obstacleWalk]
        case 2:
            return [.obstacleWalk, .infiniteCorridor]
        case 3:
            return [.infiniteCorridor, .wallFollow]
        case 4:
            return [.keyDoor]
        case 5:
            return [.keyDoor, .switchDoor]
        case 6:
            return [.switchDoor, .cratePush]
        default:
            return [.openWalk, .keyDoor, .cratePush, .wallFollow]
        }
    }

    public static func theme(forWorld world: Int) -> ThemeIdentifier {
        let themes = ThemeIdentifier.campaign
        let index = (max(world, 1) - 1) % themes.count
        return themes[index]
    }

    public static func worldSeed(campaign: UInt64, world: Int) -> UInt64 {
        var mixed = campaign &+ 0x9E3779B97F4A7C15
        mixed ^= UInt64(max(world, 1)) &* 0xBF58476D1CE4E5B9
        return mixed == 0 ? 1 : mixed
    }

    public static func pace(forLevel level: Int, finale: Bool) -> LevelPace {
        if finale { return .demanding }
        switch (max(level, 1) - 1) % 4 {
        case 0: return .accessible
        case 1: return .intermediate
        case 2: return .accessible
        default: return .demanding
        }
    }

    public static func targetDifficulty(world: Int, pace: LevelPace, finale: Bool) -> Double {
        let shift: Double
        switch pace {
        case .accessible: shift = -0.06
        case .intermediate: shift = 0
        case .demanding: shift = 0.07
        }
        let boost = finale ? 0.08 : 0
        return min(1, max(0.05, curve(forWorld: world) + shift + boost))
    }

    private static func family(in families: [PuzzleFamily], pace: LevelPace, finale: Bool) -> PuzzleFamily {
        guard let first = families.first, let last = families.last else { return .openWalk }
        if finale { return last }
        switch pace {
        case .accessible:
            return first
        case .intermediate:
            return families[families.count / 2]
        case .demanding:
            return last
        }
    }
}
