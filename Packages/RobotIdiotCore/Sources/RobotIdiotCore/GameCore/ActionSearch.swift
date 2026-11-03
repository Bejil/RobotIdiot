import Foundation

/// Plus court enchaînement de commandes primitives qui atteint le drapeau.
/// `REPETE` et `SI` ne raccourcissent pas ce nombre : ils répètent les mêmes actions.
public struct ActionSearch: Equatable, Sendable {
    public var commands: [CommandType]

    public var actionCount: Int { commands.count }

    public init(commands: [CommandType]) {
        self.commands = commands
    }

    public static func shortest(level: Level, limit: Int = 48) -> ActionSearch? {
        explore(level: level, limit: limit)
    }

    private static let order: [CommandType] = [
        .moveForward, .turnLeft, .turnRight, .moveBackward,
        .pickUp, .use, .push, .activate
    ]

    private static func explore(level: Level, limit: Int) -> ActionSearch? {
        let commands = order.filter { level.allowedCommands.contains($0) }
        var start = GameState.initial(from: level)
        start.metrics = ExecutionMetrics()
        if WorldRules.isSatisfied(start, level: level) {
            return ActionSearch(commands: [])
        }

        var queue: [(GameState, [CommandType])] = [(start, [])]
        var seen: Set<GameState> = [signature(start)]
        var head = 0
        while head < queue.count {
            let (current, path) = queue[head]
            head += 1
            if path.count >= limit { continue }
            for command in commands {
                guard case .success(let applied) = WorldRules.apply(command: command, to: current, level: level) else {
                    continue
                }
                if applied.game.grid.cell(at: applied.game.robot.position)?.terrain.isLethal == true {
                    continue
                }
                let next = signature(applied.game)
                let steps = path + [command]
                if WorldRules.isSatisfied(applied.game, level: level) {
                    return ActionSearch(commands: steps)
                }
                if seen.insert(next).inserted {
                    queue.append((next, steps))
                }
            }
        }
        return nil
    }

    /// Deux positions identiques restent la même, quel que soit le compteur d'actions.
    private static func signature(_ game: GameState) -> GameState {
        var copy = game
        copy.metrics = ExecutionMetrics()
        copy.objectives = copy.objectives.map { ObjectiveState(id: $0.id, isCompleted: false) }
        // Les écrous sont facultatifs : ils ne doivent pas élargir l'espace de recherche.
        copy.remainingCollectibles = []
        copy.collectedThisAttempt = []
        return copy
    }
}
