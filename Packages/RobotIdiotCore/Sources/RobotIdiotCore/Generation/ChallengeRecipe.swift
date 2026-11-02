import Foundation

/// Recette d'un défi libre. La même recette produit toujours la même demande.
/// Une liste de familles vide laisse le modèle de difficulté choisir un parcours.
public struct ChallengeRecipe: Codable, Hashable, Sendable {
    public var families: [PuzzleFamily]
    public var difficulty: Double
    public var seed: UInt64

    public init(families: [PuzzleFamily], difficulty: Double, seed: UInt64) {
        self.families = families
        self.difficulty = min(1, max(0, difficulty))
        self.seed = seed == 0 ? 1 : seed
    }

    public func request(generatorVersion: Int = LevelGenerator.version) -> GenerationRequest {
        let family: PuzzleFamily?
        if families.isEmpty {
            family = nil
        } else {
            family = families[Int(seed % UInt64(families.count))]
        }
        let themes = ThemeIdentifier.campaign
        let theme = themes[Int(seed % UInt64(themes.count))]
        return GenerationRequest(
            seed: seed,
            generatorVersion: generatorVersion,
            worldNumber: 0,
            levelNumber: 1,
            targetDifficulty: difficulty,
            family: family,
            theme: theme
        )
    }

    public func advanced() -> ChallengeRecipe {
        var copy = self
        let next = seed &+ 1
        copy.seed = next == 0 ? 1 : next
        return copy
    }
}
