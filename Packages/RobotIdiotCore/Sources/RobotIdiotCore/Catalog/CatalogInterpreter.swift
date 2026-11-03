import Foundation

public enum CatalogResult: Equatable, Sendable {
    case victory
    case emptyLoop
    case unsupportedCondition(String)
    case lockedCommand(String)
    case invalidCommand(String)
    case infiniteCycle
    case endWithoutVictory
}

public struct CatalogRun: Equatable, Sendable {
    public var actions: Int
    public var result: CatalogResult
}

/// Interpréteur du pack. Même ordre que le validateur : la victoire est testée
/// avant l'instruction suivante, donc un `REPETE` s'arrête dès l'entrée sur F.
/// `SI` et `REPETE` ne comptent pas ; chaque primitive réussie compte pour un.
/// Plusieurs clés, cadenas, caisses et portes liées (`linkId`) sont supportés.
public enum CatalogInterpreter {
    private static let headings = [(0, -1), (1, 0), (0, 1), (-1, 0)]
    private static let primitives: Set<String> = [
        "AVANCE", "RECULE", "TOURNE_GAUCHE", "TOURNE_DROITE",
        "RAMASSE", "UTILISE", "POUSSE", "ACTIVE"
    ]

    public static func execute(
        _ level: CatalogLevel,
        program: [CatalogInstruction]? = nil,
        maxSteps: Int = 10_000
    ) -> CatalogRun {
        let source = program ?? level.solution.program
        let grid = level.cells
        guard grid.count == 7, grid.allSatisfy({ $0.count == 7 }) else {
            return CatalogRun(actions: 0, result: .invalidCommand("grille"))
        }
        guard let direction = ["N": 0, "E": 1, "S": 2, "W": 3][level.start.orientation] else {
            return CatalogRun(actions: 0, result: .invalidCommand(level.start.orientation))
        }

        var keys = Set<CellPoint>()
        var locks = Set<CellPoint>()
        var crates = Set<CellPoint>()
        var plates: [CellPoint: String] = [:]
        var doors: [CellPoint: String] = [:]
        for mechanic in level.mechanics {
            let point = CellPoint(x: mechanic.x, y: mechanic.y)
            switch mechanic.type {
            case "BoardKey":
                keys.insert(point)
            case "BoardLock":
                locks.insert(point)
            case "BoardCrate":
                crates.insert(point)
            case "BoardPlate":
                if let link = mechanic.linkId {
                    plates[point] = link
                }
            case "BoardDoor":
                if let link = mechanic.linkId {
                    doors[point] = link
                }
            default:
                break
            }
        }

        var machine = Machine(
            x: level.start.x,
            y: level.start.y,
            direction: direction,
            keyCount: 0,
            remainingKeys: keys,
            openLocks: [],
            openLinks: [],
            activePlates: [],
            crates: crates
        )
        var frames = [Frame(instructions: source, position: 0, loop: false)]
        var seen = Set<Signature>()
        var actions = 0
        let allowed = Set(level.unlockedCommands)

        func tile(_ x: Int, _ y: Int) -> Character {
            guard (0..<7).contains(x), (0..<7).contains(y) else { return "#" }
            return grid[y][x]
        }
        func free(_ x: Int, _ y: Int) -> Bool {
            let symbol = tile(x, y)
            let point = CellPoint(x: x, y: y)
            if LevelPackChecker.blockingSymbols.contains(symbol) || symbol == "#" || symbol.isNumber { return false }
            if locks.contains(point), !machine.openLocks.contains(point) { return false }
            if let link = doors[point], !machine.openLinks.contains(link) { return false }
            if machine.crates.contains(point) { return false }
            return true
        }
        func reachedFlag() -> Bool {
            guard machine.x == level.finish.x, machine.y == level.finish.y else { return false }
            if level.objective.requiresItemHeld { return machine.keyCount > 0 }
            return true
        }
        func step(_ command: String) -> Machine? {
            let (dx, dy) = headings[machine.direction]
            let frontX = machine.x + dx
            let frontY = machine.y + dy
            let here = CellPoint(x: machine.x, y: machine.y)
            let front = CellPoint(x: frontX, y: frontY)
            switch command {
            case "TOURNE_GAUCHE":
                var next = machine
                next.direction = (machine.direction + 3) % 4
                return next
            case "TOURNE_DROITE":
                var next = machine
                next.direction = (machine.direction + 1) % 4
                return next
            case "AVANCE", "RECULE":
                let destination = command == "AVANCE"
                    ? (frontX, frontY)
                    : (machine.x - dx, machine.y - dy)
                guard free(destination.0, destination.1) else { return nil }
                var next = machine
                next.x = destination.0
                next.y = destination.1
                return next
            case "RAMASSE":
                guard machine.remainingKeys.contains(here) else { return nil }
                var next = machine
                next.remainingKeys.remove(here)
                next.keyCount += 1
                return next
            case "UTILISE":
                guard locks.contains(front),
                      !machine.openLocks.contains(front),
                      machine.keyCount > 0 else { return nil }
                var next = machine
                next.keyCount -= 1
                next.openLocks.insert(front)
                return next
            case "ACTIVE":
                guard let link = plates[here], !machine.activePlates.contains(link) else { return nil }
                var next = machine
                next.activePlates.insert(link)
                next.openLinks.insert(link)
                return next
            case "POUSSE":
                guard machine.crates.contains(front) else { return nil }
                let beyond = CellPoint(x: frontX + dx, y: frontY + dy)
                guard free(beyond.x, beyond.y) else { return nil }
                var next = machine
                next.crates.remove(front)
                next.crates.insert(beyond)
                next.x = front.x
                next.y = front.y
                return next
            default:
                return nil
            }
        }

        while !frames.isEmpty, actions <= maxSteps {
            if reachedFlag() {
                return CatalogRun(actions: actions, result: .victory)
            }
            if frames[frames.count - 1].position == frames[frames.count - 1].instructions.count {
                if frames[frames.count - 1].loop {
                    frames[frames.count - 1].position = 0
                } else {
                    frames.removeLast()
                }
                continue
            }

            let instruction = frames[frames.count - 1].instructions[frames[frames.count - 1].position]
            frames[frames.count - 1].position += 1
            switch instruction {
            case .repete(let body):
                if body.isEmpty {
                    return CatalogRun(actions: actions, result: .emptyLoop)
                }
                frames.append(Frame(instructions: body, position: 0, loop: true))
            case .si(let condition, let body):
                let aheadFree = step("AVANCE") != nil
                let passes: Bool
                switch condition {
                case "CASE_DEVANT_LIBRE":
                    passes = aheadFree
                case "OBSTACLE_DEVANT":
                    passes = !aheadFree
                default:
                    return CatalogRun(actions: actions, result: .unsupportedCondition(condition))
                }
                if passes {
                    frames.append(Frame(instructions: body, position: 0, loop: false))
                }
            default:
                let name = instruction.commandName
                if !allowed.contains(name) || !primitives.contains(name) {
                    return CatalogRun(actions: actions, result: .lockedCommand(name))
                }
                guard let next = step(name) else {
                    return CatalogRun(actions: actions, result: .invalidCommand(name))
                }
                machine = next
                actions += 1
                let signature = Signature(
                    machine: machine,
                    frames: frames.map {
                        FrameMark(position: $0.position, loop: $0.loop, length: $0.instructions.count)
                    }
                )
                if seen.contains(signature) {
                    return CatalogRun(actions: actions, result: .infiniteCycle)
                }
                seen.insert(signature)
            }
        }

        if reachedFlag() {
            return CatalogRun(actions: actions, result: .victory)
        }
        return CatalogRun(actions: actions, result: .endWithoutVictory)
    }
}

private struct CellPoint: Hashable {
    var x: Int
    var y: Int
}

private struct Machine: Hashable {
    var x: Int
    var y: Int
    var direction: Int
    var keyCount: Int
    var remainingKeys: Set<CellPoint>
    var openLocks: Set<CellPoint>
    var openLinks: Set<String>
    var activePlates: Set<String>
    var crates: Set<CellPoint>
}

private struct Frame {
    var instructions: [CatalogInstruction]
    var position: Int
    var loop: Bool
}

private struct FrameMark: Hashable {
    var position: Int
    var loop: Bool
    var length: Int
}

private struct Signature: Hashable {
    var machine: Machine
    var frames: [FrameMark]
}
