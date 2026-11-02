import XCTest
@testable import RobotIdiotCore

final class WorldRulesTests: XCTestCase {
    func testForwardMovesOneCellWithoutChangingOrientation() {
        let level = TestLevels.openRoom(robot: RobotState(position: GridCoordinate(x: 1, y: 1), orientation: .north))
        let result = WorldRules.apply(command: .moveForward, to: .initial(from: level), level: level)
        guard case .success(let applied) = result else {
            return XCTFail("Le déplacement aurait dû réussir")
        }
        let game = applied.game
        let event = applied.event
        XCTAssertEqual(game.robot.position, GridCoordinate(x: 1, y: 2))
        XCTAssertEqual(game.robot.orientation, .north)
        XCTAssertEqual(game.metrics.moves, 1)
        XCTAssertEqual(game.metrics.turns, 0)
        XCTAssertEqual(event, .moved(
            from: GridCoordinate(x: 1, y: 1),
            to: GridCoordinate(x: 1, y: 2),
            forward: true,
            command: .moveForward
        ))
    }

    func testAllFourDirections() {
        let expectations: [(Direction, GridCoordinate)] = [
            (.north, GridCoordinate(x: 2, y: 3)),
            (.east, GridCoordinate(x: 3, y: 2)),
            (.south, GridCoordinate(x: 2, y: 1)),
            (.west, GridCoordinate(x: 1, y: 2))
        ]
        for (direction, destination) in expectations {
            let level = TestLevels.openRoom(robot: RobotState(position: GridCoordinate(x: 2, y: 2), orientation: direction))
            let result = WorldRules.apply(command: .moveForward, to: .initial(from: level), level: level)
            guard case .success(let applied) = result else {
                return XCTFail("Échec vers \(direction)")
            }
            let game = applied.game
            XCTAssertEqual(game.robot.position, destination)
            XCTAssertEqual(game.robot.orientation, direction)
        }
    }

    func testBackwardDoesNotChangeOrientation() {
        let level = TestLevels.openRoom(robot: RobotState(position: GridCoordinate(x: 2, y: 2), orientation: .east))
        let result = WorldRules.apply(command: .moveBackward, to: .initial(from: level), level: level)
        guard case .success(let applied) = result else {
            return XCTFail("Le recul aurait dû réussir")
        }
        let game = applied.game
        XCTAssertEqual(game.robot.position, GridCoordinate(x: 1, y: 2))
        XCTAssertEqual(game.robot.orientation, .east)
    }

    func testTurnsAreExactQuarterTurns() {
        var orientation = Direction.north
        for expected in [Direction.west, .south, .east, .north] {
            orientation = orientation.left
            XCTAssertEqual(orientation, expected)
        }
        orientation = .north
        for expected in [Direction.east, .south, .west, .north] {
            orientation = orientation.right
            XCTAssertEqual(orientation, expected)
        }
        XCTAssertEqual(Direction.east.opposite, .west)
    }

    func testWallBlocksForwardAndLeavesStateUntouched() {
        var walls = Set<GridCoordinate>()
        walls.insert(GridCoordinate(x: 2, y: 1))
        let robot = RobotState(position: GridCoordinate(x: 1, y: 1), orientation: .east)
        let level = TestLevels.openRoom(robot: robot, walls: walls)
        let before = GameState.initial(from: level)
        let result = WorldRules.apply(command: .moveForward, to: before, level: level)
        guard case .failure(.pathBlocked(true, let attempted)) = result else {
            return XCTFail("Le mur aurait dû bloquer")
        }
        XCTAssertEqual(attempted, GridCoordinate(x: 2, y: 1))
        XCTAssertEqual(before.robot, robot)
        XCTAssertEqual(before.metrics, ExecutionMetrics())
    }

    func testOutOfBoundsBlocksLikeAWall() {
        let level = TestLevels.openRoom(robot: RobotState(position: GridCoordinate(x: 0, y: 0), orientation: .south))
        let result = WorldRules.apply(command: .moveForward, to: .initial(from: level), level: level)
        guard case .failure(.pathBlocked(true, let attempted)) = result else {
            return XCTFail("Sortir de la grille aurait dû échouer")
        }
        XCTAssertEqual(attempted, GridCoordinate(x: 0, y: -1))
    }

    func testBackwardIntoWallFailsWithoutTurning() {
        var walls = Set<GridCoordinate>()
        walls.insert(GridCoordinate(x: 0, y: 1))
        let level = TestLevels.openRoom(robot: RobotState(position: GridCoordinate(x: 1, y: 1), orientation: .east), walls: walls)
        let result = WorldRules.apply(command: .moveBackward, to: .initial(from: level), level: level)
        guard case .failure(.pathBlocked(false, _)) = result else {
            return XCTFail("Le recul dans le mur aurait dû échouer")
        }
    }

    func testUnavailableCommandDoesNotMoveTheRobot() {
        let level = TestLevels.openRoom(robot: RobotState(position: GridCoordinate(x: 1, y: 1), orientation: .north))
        let before = GameState.initial(from: level)
        let result = WorldRules.apply(command: .forever, to: before, level: level)
        guard case .failure(.commandUnavailable(.forever)) = result else {
            return XCTFail("REPETE ne doit pas être simulé comme un déplacement")
        }
        XCTAssertEqual(before.robot.position, GridCoordinate(x: 1, y: 1))
    }
}
