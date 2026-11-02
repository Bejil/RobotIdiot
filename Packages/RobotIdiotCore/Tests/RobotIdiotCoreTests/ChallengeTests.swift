import XCTest
@testable import RobotIdiotCore

final class ChallengeTests: XCTestCase {
    func testFreeChallengeRequestStaysDeterministic() {
        let recipe = ChallengeRecipe(families: [.cratePush, .keyDoor], difficulty: 1.4, seed: 5)
        XCTAssertEqual(recipe.difficulty, 1)
        XCTAssertEqual(recipe.seed, 5)
        let request = recipe.request()
        XCTAssertEqual(request, recipe.request())
        XCTAssertEqual(request.family, .keyDoor)
        XCTAssertEqual(request.worldNumber, 0)
        XCTAssertEqual(request.levelNumber, 1)
        XCTAssertEqual(request.targetDifficulty, 1)
        XCTAssertEqual(request.theme, ThemeIdentifier.campaign[1])

        let surprise = ChallengeRecipe(families: [], difficulty: 0.2, seed: 0)
        XCTAssertEqual(surprise.seed, 1)
        XCTAssertNil(surprise.request().family)
        XCTAssertEqual(surprise.request(), surprise.request())

        let next = recipe.advanced()
        XCTAssertEqual(next.seed, 6)
        XCTAssertEqual(next.families, recipe.families)
        XCTAssertEqual(next.difficulty, recipe.difficulty)
        XCTAssertEqual(next.request().family, .cratePush)

        let generated = LevelGenerator.generate(
            surprise.request(),
            budget: GenerationBudget(maxAttempts: 1, solver: SolverBudget(maxPrograms: 20, maxSteps: 200))
        )
        XCTAssertEqual(generated.level.seed, surprise.seed)
        XCTAssertEqual(generated.level.worldNumber, 0)
        XCTAssertTrue(generated.level.id.hasPrefix("gen-v\(LevelGenerator.version)-s\(surprise.seed)-w0-"))
    }
}
