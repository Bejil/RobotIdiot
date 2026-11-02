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

        var crateX = -1
        var crateY = -1
        for y in 0..<7 {
            for x in 0..<7 where grid[y][x] == "C" {
                crateX = x
                crateY = y
                break
            }
            if crateX >= 0 { break }
        }

        var machine = Machine(
            x: level.start.x,
            y: level.start.y,
            direction: direction,
            holding: false,
            taken: false,
            doorOpen: false,
            switchOn: false,
            crateX: crateX,
            crateY: crateY
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
            if LevelPackChecker.blockingSymbols.contains(symbol) || symbol == "#" || symbol.isNumber { return false }
            if symbol == "U", !machine.doorOpen { return false }
            if symbol == "D", !machine.switchOn { return false }
            if x == machine.crateX, y == machine.crateY { return false }
            return true
        }
        func reachedFlag() -> Bool {
            guard machine.x == level.finish.x, machine.y == level.finish.y else { return false }
            if level.objective.requiresItemHeld { return machine.holding }
            return true
        }
        func step(_ command: String) -> Machine? {
            let (dx, dy) = headings[machine.direction]
            let frontX = machine.x + dx
            let frontY = machine.y + dy
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
                guard tile(machine.x, machine.y) == "K", !machine.holding, !machine.taken else { return nil }
                var next = machine
                next.holding = true
                next.taken = true
                return next
            case "UTILISE":
                guard tile(frontX, frontY) == "U", machine.holding, !machine.doorOpen else { return nil }
                var next = machine
                next.holding = false
                next.doorOpen = true
                return next
            case "ACTIVE":
                guard tile(machine.x, machine.y) == "A", !machine.switchOn else { return nil }
                var next = machine
                next.switchOn = true
                return next
            case "POUSSE":
                guard frontX == machine.crateX, frontY == machine.crateY else { return nil }
                let beyondX = frontX + dx
                let beyondY = frontY + dy
                guard free(beyondX, beyondY) else { return nil }
                var next = machine
                next.x = frontX
                next.y = frontY
                next.crateX = beyondX
                next.crateY = beyondY
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
                guard condition == "CASE_DEVANT_LIBRE" else {
                    return CatalogRun(actions: actions, result: .unsupportedCondition(condition))
                }
                if step("AVANCE") != nil {
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

private struct Machine: Hashable {
    var x: Int
    var y: Int
    var direction: Int
    var holding: Bool
    var taken: Bool
    var doorOpen: Bool
    var switchOn: Bool
    var crateX: Int
    var crateY: Int
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
