import Foundation

/// Pack Mode Expert — Le Laboratoire (40 simulations fixes).
public struct ExpertSimulationPack: Codable, Equatable, Sendable {
    public var schemaVersion: String
    public var packId: String?
    public var mode: String?
    public var simulations: [ExpertSimulation]
}

public struct ExpertSimulation: Codable, Equatable, Sendable {
    public var id: String
    public var sequence: Int
    public var name: String
    public var width: Int
    public var height: Int
    public var grid: [String]
    public var start: Start
    public var finish: Finish
    public var mechanics: [CatalogLevel.Mechanic]
    public var objective: CatalogLevel.Objective
    public var initiallyAvailableCommands: [String]
    public var unlockedControlCommands: [String]
    public var unlockedConditions: [String]
    public var starTargets: StarTargets
    public var reference: Reference
    public var visualThemeWorld: Int
    public var microTutorialKey: String?

    public struct Start: Codable, Equatable, Sendable {
        public var x: Int
        public var y: Int
        public var orientation: String
    }

    public struct Finish: Codable, Equatable, Sendable {
        public var x: Int
        public var y: Int
    }

    public struct StarTargets: Codable, Equatable, Sendable {
        public var metric: String
        public var threeStarsMax: Int
        public var twoStarsMax: Int
    }

    public struct Reference: Codable, Equatable, Sendable {
        public var program: [CatalogInstruction]
        public var writtenBlocks: Int?
        public var executedActions: Int?
    }
}

public struct ExpertTutorialPack: Codable, Equatable, Sendable {
    public var schemaVersion: String
    public var id: String
    public var completionStorageKey: String
    public var skipAllowed: Bool
    public var pages: [Page]
    public var microTutorials: [MicroTutorial]

    public struct Page: Codable, Equatable, Sendable {
        public var id: String
        public var title: String
        public var body: String
        public var primaryCTA: String?
        public var secondaryCTA: String?
    }

    public struct MicroTutorial: Codable, Equatable, Sendable {
        public var onFirstStartSimulation: String
        public var title: String
        public var body: String
        public var shownOnceKey: String
    }
}

public struct ExpertConfig: Codable, Equatable, Sendable {
    public var schemaVersion: String
    public var mode: String?
    public var pack: String?
}
