import Foundation

struct TemplateProduct {
    var grid: Grid
    var robot: RobotState
    var flag: GridCoordinate
    var allowed: [CommandType]
    var constraints: ProgramConstraints
    var reference: Program
}

enum NavigationTemplates {
    static func make(_ family: PuzzleFamily, rng: inout SeededGenerator, span: Int) -> TemplateProduct? {
        switch family {
        case .openWalk:
            return openWalk(rng: &rng)
        case .obstacleWalk:
            return obstacleWalk(rng: &rng, span: span)
        case .infiniteCorridor:
            return infiniteCorridor(rng: &rng)
        case .wallFollow:
            return wallFollow(rng: &rng)
        case .keyDoor:
            return InteractionTemplates.keyDoor(rng: &rng, span: span)
        case .switchDoor:
            return InteractionTemplates.switchDoor(rng: &rng, span: span)
        case .cratePush:
            return InteractionTemplates.cratePush(rng: &rng, span: span)
        }
    }

    private static func openWalk(rng: inout SeededGenerator) -> TemplateProduct? {
        if rng.bool() {
            let moves = 3 + rng.int(0..<3)
            let grid = Grid.bordered(width: moves + 3, height: 5)
            let commands = Array(repeating: CommandType.moveForward, count: moves)
            return TemplateProduct(
                grid: grid,
                robot: RobotState(position: GridCoordinate(x: 1, y: 1), orientation: .east),
                flag: GridCoordinate(x: 1 + moves, y: 1),
                allowed: CommandType.movement,
                constraints: ProgramConstraints(maxBlocks: nil, maxNestingDepth: 1),
                reference: Program(instructions: commands.map { Instruction(command: $0) })
            )
        }
        let east = 2 + rng.int(0..<2)
        let north = 2 + rng.int(0..<2)
        var commands = Array(repeating: CommandType.moveForward, count: east)
        commands.append(.turnLeft)
        commands.append(contentsOf: Array(repeating: CommandType.moveForward, count: north))
        return TemplateProduct(
            grid: Grid.bordered(width: east + 3, height: north + 3),
            robot: RobotState(position: GridCoordinate(x: 1, y: 1), orientation: .east),
            flag: GridCoordinate(x: 1 + east, y: 1 + north),
            allowed: CommandType.movement,
            constraints: ProgramConstraints(maxBlocks: nil, maxNestingDepth: 1),
            reference: Program(instructions: commands.map { Instruction(command: $0) })
        )
    }

    private static func obstacleWalk(rng: inout SeededGenerator, span: Int) -> TemplateProduct? {
        let size = min(max(span, 6), 8)
        var path = [GridCoordinate(x: 1, y: 1)]
        var facing = Direction.east
        let target = 5 + rng.int(0..<3)
        var turns = 0
        var steps = 0
        while path.count <= target && steps < 48 {
            steps += 1
            let current = path[path.count - 1]
            let ordered = [facing, facing.left, facing.right, facing.opposite]
            let open = ordered.filter { direction in
                let next = current.translated(by: direction)
                return next.x >= 1 && next.y >= 1 && next.x < size - 1 && next.y < size - 1 && !path.contains(next)
            }
            let pool = open.filter { $0 != facing.opposite }
            let choices = pool.isEmpty ? open : pool
            guard let direction = choices.randomElement(using: &rng) else { break }
            if direction != facing { turns += 1 }
            facing = direction
            path.append(current.translated(by: facing))
        }
        guard path.count >= 5, turns >= 1, let commands = commands(along: path) else { return nil }
        var walls = Set<GridCoordinate>()
        for x in 1..<(size - 1) {
            for y in 1..<(size - 1) where !path.contains(GridCoordinate(x: x, y: y)) {
                walls.insert(GridCoordinate(x: x, y: y))
            }
        }
        guard let startFacing = path[0].step(toward: path[1]) else { return nil }
        return TemplateProduct(
            grid: Grid.bordered(width: size, height: size, interiorWalls: walls),
            robot: RobotState(position: path[0], orientation: startFacing),
            flag: path[path.count - 1],
            allowed: CommandType.movement,
            constraints: ProgramConstraints(maxBlocks: commands.count, maxNestingDepth: 1),
            reference: Program(instructions: commands.map { Instruction(command: $0) })
        )
    }

    private static func infiniteCorridor(rng: inout SeededGenerator) -> TemplateProduct? {
        let moves = 4 + rng.int(0..<4)
        let span = moves + 3
        let horizontal = rng.bool()
        let grid = Grid.bordered(width: horizontal ? span : 3, height: horizontal ? 3 : span)
        let robot = RobotState(
            position: GridCoordinate(x: 1, y: 1),
            orientation: horizontal ? .east : .north
        )
        let flag = horizontal
            ? GridCoordinate(x: 1 + moves, y: 1)
            : GridCoordinate(x: 1, y: 1 + moves)
        return TemplateProduct(
            grid: grid,
            robot: robot,
            flag: flag,
            allowed: CommandType.movement + [.forever],
            constraints: ProgramConstraints(maxBlocks: 2, maxNestingDepth: 2),
            reference: ProgramSolver.forever([.moveForward])
        )
    }

    private static func wallFollow(rng: inout SeededGenerator) -> TemplateProduct? {
        let segmentCount = 2 + rng.int(0..<2)
        var segments: [Int] = []
        for _ in 0..<segmentCount {
            segments.append(2 + rng.int(0..<3))
        }
        if segments.reduce(0, +) < 5 {
            segments[segments.count - 1] += 5 - segments.reduce(0, +)
        }
        guard let carved = carveLeftHook(segments) else { return nil }
        return TemplateProduct(
            grid: carved.grid,
            robot: carved.robot,
            flag: carved.flag,
            allowed: CommandType.movement + [.forever, .ifBlock],
            constraints: ProgramConstraints(maxBlocks: 4, maxNestingDepth: 3),
            reference: ProgramSolver.foreverIf(condition: .obstacleAhead, turn: .turnLeft, move: .moveForward)
        )
    }

    private static func carveLeftHook(_ segments: [Int]) -> (grid: Grid, robot: RobotState, flag: GridCoordinate)? {
        var position = GridCoordinate(x: 0, y: 0)
        var direction = Direction.east
        var path = [position]
        var corners: [(at: GridCoordinate, ahead: GridCoordinate)] = []
        for (index, length) in segments.enumerated() {
            for _ in 0..<length {
                position = position.translated(by: direction)
                if path.contains(position) { return nil }
                path.append(position)
            }
            if index < segments.count - 1 {
                let ahead = position.translated(by: direction)
                corners.append((position, ahead))
                direction = direction.left
            }
        }
        guard path.count >= 2, let startFacing = path[0].step(toward: path[1]) else { return nil }
        if corners.contains(where: { path.contains($0.ahead) }) { return nil }

        let minX = path.map(\.x).min() ?? 0
        let maxX = path.map(\.x).max() ?? 0
        let minY = path.map(\.y).min() ?? 0
        let maxY = path.map(\.y).max() ?? 0
        let shiftX = 1 - minX
        let shiftY = 1 - minY
        let shifted = path.map { GridCoordinate(x: $0.x + shiftX, y: $0.y + shiftY) }
        let width = maxX - minX + 3
        let height = maxY - minY + 3
        var walls = Set<GridCoordinate>()
        let pathSet = Set(shifted)
        for x in 1..<(width - 1) {
            for y in 1..<(height - 1) where !pathSet.contains(GridCoordinate(x: x, y: y)) {
                walls.insert(GridCoordinate(x: x, y: y))
            }
        }
        return (
            grid: Grid.bordered(width: width, height: height, interiorWalls: walls),
            robot: RobotState(position: shifted[0], orientation: startFacing),
            flag: shifted[shifted.count - 1]
        )
    }

    private static func commands(along path: [GridCoordinate]) -> [CommandType]? {
        guard path.count >= 2, var facing = path[0].step(toward: path[1]) else { return nil }
        var commands: [CommandType] = []
        for index in 1..<path.count {
            guard let needed = path[index - 1].step(toward: path[index]) else { return nil }
            if facing.opposite == needed {
                commands.append(.turnLeft)
                commands.append(.turnLeft)
                facing = facing.opposite
            } else if facing.left == needed {
                commands.append(.turnLeft)
                facing = facing.left
            } else if facing.right == needed {
                commands.append(.turnRight)
                facing = facing.right
            }
            commands.append(.moveForward)
        }
        return commands
    }
}
