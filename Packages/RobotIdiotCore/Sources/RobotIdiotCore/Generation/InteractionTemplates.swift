import Foundation

/// Couloirs courts où le drapeau est derrière une clé, un interrupteur ou une caisse.
enum InteractionTemplates {
    static func make(_ family: PuzzleFamily, rng: inout SeededGenerator, span: Int) -> TemplateProduct {
        switch family {
        case .switchDoor:
            return switchDoor(rng: &rng, span: span)
        case .cratePush:
            return cratePush(rng: &rng, span: span)
        case .keyDoor, .openWalk, .obstacleWalk, .infiniteCorridor, .wallFollow:
            return keyDoor(rng: &rng, span: span)
        }
    }

    static func keyDoor(rng: inout SeededGenerator, span: Int) -> TemplateProduct {
        let gap = rng.int(0..<(max(1, min(max(span, 6), 8) - 5)))
        let doorX = 3 + gap
        let flagX = doorX + 1
        let width = flagX + 2
        var grid = seal(width: width, height: 5, path: path(fromX: 1, toX: flagX, y: 1))
        let key = GridCoordinate(x: 2, y: 1)
        grid.updateCell(at: key) { cell in
            cell.objects = [PlacedObject(id: "key", kind: ObjectKind.key)]
        }
        grid.updateCell(at: GridCoordinate(x: doorX, y: 1)) { cell in
            cell.mechanisms = [PlacedMechanism(id: "door", kind: MechanismKind.door)]
        }
        var commands: [CommandType] = [.moveForward, .pickUp]
        commands.append(contentsOf: Array(repeating: .moveForward, count: gap))
        commands.append(contentsOf: [.use, .moveForward, .moveForward])
        return product(
            grid: grid,
            flagX: flagX,
            allowed: CommandType.movement + [.pickUp, .use],
            commands: commands
        )
    }

    static func switchDoor(rng: inout SeededGenerator, span: Int) -> TemplateProduct {
        if span >= 7, rng.bool() {
            return sideSwitch()
        }
        let gap = rng.int(0..<(max(1, min(max(span, 6), 8) - 5)))
        let doorX = 3 + gap
        let flagX = doorX + 1
        var grid = seal(width: flagX + 2, height: 5, path: path(fromX: 1, toX: flagX, y: 1))
        grid.updateCell(at: GridCoordinate(x: 2, y: 1)) { cell in
            cell.mechanisms = [PlacedMechanism(id: "plate", kind: MechanismKind.plate, link: "door")]
        }
        grid.updateCell(at: GridCoordinate(x: doorX, y: 1)) { cell in
            cell.mechanisms = [PlacedMechanism(id: "door", kind: MechanismKind.door)]
        }
        var commands: [CommandType] = [.moveForward, .activate]
        commands.append(contentsOf: Array(repeating: .moveForward, count: gap + 2))
        return product(
            grid: grid,
            flagX: flagX,
            allowed: CommandType.movement + [.activate],
            commands: commands
        )
    }

    static func cratePush(rng: inout SeededGenerator, span: Int) -> TemplateProduct {
        let flagX = 3
        let emptyX = 4
        var grid = seal(width: emptyX + 2, height: 5, path: path(fromX: 1, toX: emptyX, y: 1))
        grid.updateCell(at: GridCoordinate(x: 2, y: 1)) { cell in
            cell.objects = [PlacedObject(id: "crate", kind: ObjectKind.crate)]
        }
        let turnsFirst = span >= 7 && rng.bool()
        let commands: [CommandType] = turnsFirst ? [.turnRight, .push, .push] : [.push, .push]
        return product(
            grid: grid,
            robot: RobotState(position: GridCoordinate(x: 1, y: 1), orientation: turnsFirst ? .north : .east),
            flagX: flagX,
            allowed: CommandType.movement + [.push],
            commands: commands
        )
    }

    private static func sideSwitch() -> TemplateProduct {
        let flagX = 4
        var cells = path(fromX: 1, toX: flagX, y: 1)
        cells.insert(GridCoordinate(x: 2, y: 2))
        var grid = seal(width: flagX + 2, height: 6, path: cells)
        grid.updateCell(at: GridCoordinate(x: 2, y: 2)) { cell in
            cell.mechanisms = [PlacedMechanism(id: "plate", kind: MechanismKind.plate, link: "door")]
        }
        grid.updateCell(at: GridCoordinate(x: 3, y: 1)) { cell in
            cell.mechanisms = [PlacedMechanism(id: "door", kind: MechanismKind.door)]
        }
        return product(
            grid: grid,
            flagX: flagX,
            allowed: CommandType.movement + [.activate],
            commands: [.moveForward, .turnLeft, .moveForward, .activate, .moveBackward, .turnRight, .moveForward, .moveForward]
        )
    }

    private static func path(fromX start: Int, toX end: Int, y: Int) -> Set<GridCoordinate> {
        Set((start...end).map { GridCoordinate(x: $0, y: y) })
    }

    private static func seal(width: Int, height: Int, path: Set<GridCoordinate>) -> Grid {
        var walls = Set<GridCoordinate>()
        for x in 1..<(width - 1) {
            for y in 1..<(height - 1) where !path.contains(GridCoordinate(x: x, y: y)) {
                walls.insert(GridCoordinate(x: x, y: y))
            }
        }
        return Grid.bordered(width: width, height: height, interiorWalls: walls)
    }

    private static func product(
        grid: Grid,
        robot: RobotState = RobotState(position: GridCoordinate(x: 1, y: 1), orientation: .east),
        flagX: Int,
        allowed: [CommandType],
        commands: [CommandType]
    ) -> TemplateProduct {
        let reference = Program(instructions: commands.map { Instruction(command: $0) })
        return TemplateProduct(
            grid: grid,
            robot: robot,
            flag: GridCoordinate(x: flagX, y: 1),
            allowed: allowed,
            constraints: ProgramConstraints(maxBlocks: reference.blockCount, maxNestingDepth: 1),
            reference: reference
        )
    }
}
