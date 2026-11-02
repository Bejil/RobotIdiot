import UIKit
import RobotIdiotCore

enum SeedCursor {
    private static let key = "robotidiot.nextGeneratedSeed"

    static func advance() -> UInt64 {
        let stored = UInt64(UserDefaults.standard.string(forKey: key) ?? "") ?? 1
        let current = stored == 0 ? 1 : stored
        UserDefaults.standard.set(String(current &+ 1), forKey: key)
        return current
    }
}

enum GeneratedLevelFlow {
    static func request(seed: UInt64, world: Int = 1, level: Int? = nil) -> GenerationRequest {
        GenerationRequest(
            seed: seed,
            generatorVersion: LevelGenerator.version,
            worldNumber: world,
            levelNumber: level ?? Int(seed % 10_000),
            targetDifficulty: LevelGenerator.difficulty(forSeed: seed)
        )
    }

    static func produce(_ request: GenerationRequest, completion: @escaping (GeneratedLevel) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let generated = LevelGenerator.generate(request, budget: .interactive)
            DispatchQueue.main.async {
                completion(generated)
            }
        }
    }
}
