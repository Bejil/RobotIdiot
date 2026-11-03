import Foundation

public enum RuleViolation: Error, Equatable, Sendable, Codable {
    case pathBlocked(forward: Bool, attempted: GridCoordinate)
    case commandUnavailable(CommandType)
    case nothingToPickUp
    case nothingToUse
    case incompatibleUse
    case nothingToPush
    case pushBlocked(attempted: GridCoordinate)
    case nothingToActivate
}

public struct RuleApplication: Equatable, Sendable {
    public var game: GameState
    public var event: SimulationEvent

    public init(game: GameState, event: SimulationEvent) {
        self.game = game
        self.event = event
    }
}

/// Règles du monde, sans aucune connaissance de l'éditeur ni du rendu.
public enum WorldRules {
    public static func apply(
        command: CommandType,
        to game: GameState,
        level: Level
    ) -> Result<RuleApplication, RuleViolation> {
        switch command {
        case .moveForward:
            return move(game, level: level, forward: true, command: command)
        case .moveBackward:
            return move(game, level: level, forward: false, command: command)
        case .turnLeft:
            return turn(game, level: level, command: command, towards: game.robot.orientation.left)
        case .turnRight:
            return turn(game, level: level, command: command, towards: game.robot.orientation.right)
        case .pickUp:
            return pickUp(game, level: level)
        case .use:
            return use(game, level: level)
        case .push:
            return push(game, level: level)
        case .activate:
            return activate(game, level: level)
        case .forever, .ifBlock:
            return .failure(.commandUnavailable(command))
        }
    }

    public static func isSatisfied(_ game: GameState, level: Level) -> Bool {
        guard !level.objectives.isEmpty else { return false }
        return level.objectives.allSatisfy { objective in
            isMet(objective, by: game)
        }
    }

    private static func move(
        _ game: GameState,
        level: Level,
        forward: Bool,
        command: CommandType
    ) -> Result<RuleApplication, RuleViolation> {
        let heading = forward ? game.robot.orientation : game.robot.orientation.opposite
        let destination = game.robot.position.translated(by: heading)
        guard let cell = game.grid.cell(at: destination), cell.allowsRobotEntry else {
            return .failure(.pathBlocked(forward: forward, attempted: destination))
        }

        var updated = game
        let origin = updated.robot.position
        updated.robot.position = destination
        updated.metrics.moves += 1
        updated.metrics.executedInstructions += 1
        _ = collectBonusIfNeeded(at: destination, game: &updated)
        refreshObjectives(&updated, level: level)
        return .success(RuleApplication(
            game: updated,
            event: .moved(from: origin, to: destination, forward: forward, command: command)
        ))
    }

    /// Ramasse automatiquement un BoardBolt sur la case, sans commande RAMASSE ni coût d'action.
    @discardableResult
    private static func collectBonusIfNeeded(at position: GridCoordinate, game: inout GameState) -> LevelCollectible? {
        guard let index = game.remainingCollectibles.firstIndex(where: { $0.position == position }) else {
            return nil
        }
        let bonus = game.remainingCollectibles.remove(at: index)
        game.collectedThisAttempt.append(bonus)
        return bonus
    }

    private static func turn(
        _ game: GameState,
        level: Level,
        command: CommandType,
        towards orientation: Direction
    ) -> Result<RuleApplication, RuleViolation> {
        var updated = game
        let origin = updated.robot.orientation
        updated.robot.orientation = orientation
        updated.metrics.turns += 1
        updated.metrics.executedInstructions += 1
        refreshObjectives(&updated, level: level)
        return .success(RuleApplication(
            game: updated,
            event: .turned(from: origin, to: orientation, command: command)
        ))
    }

    /// Ramasse la première clé posée sur la case du robot.
    private static func pickUp(_ game: GameState, level: Level) -> Result<RuleApplication, RuleViolation> {
        let position = game.robot.position
        guard let object = game.grid.cell(at: position)?.objects.first(where: { $0.kind == ObjectKind.key }) else {
            return .failure(.nothingToPickUp)
        }
        var updated = game
        updated.grid.updateCell(at: position) { cell in
            cell.objects.removeAll { $0.id == object.id }
        }
        let item = CarriedItem(id: object.id, kind: object.kind)
        updated.robot.inventory.append(item)
        countInteraction(&updated)
        refreshObjectives(&updated, level: level)
        return .success(RuleApplication(game: updated, event: .pickedUp(item, at: position)))
    }

    /// Utilise le premier objet transporté sur la case devant le robot.
    /// Une clé ouvre une porte fermée et quitte l'inventaire.
    private static func use(_ game: GameState, level: Level) -> Result<RuleApplication, RuleViolation> {
        guard let item = game.robot.inventory.first else {
            return .failure(.nothingToUse)
        }
        let ahead = game.robot.position.translated(by: game.robot.orientation)
        guard item.kind == ObjectKind.key,
              game.grid.cell(at: ahead)?.mechanisms.contains(where: { $0.kind == MechanismKind.door && !$0.isActive }) == true else {
            return .failure(.incompatibleUse)
        }
        var updated = game
        updated.robot.inventory.removeFirst()
        updated.grid.updateCell(at: ahead) { cell in
            guard let index = cell.mechanisms.firstIndex(where: { $0.kind == MechanismKind.door && !$0.isActive }) else { return }
            cell.mechanisms[index].isActive = true
        }
        countInteraction(&updated)
        refreshObjectives(&updated, level: level)
        return .success(RuleApplication(game: updated, event: .used(item, on: ahead)))
    }

    /// Pousse la caisse devant le robot d'une case, puis avance sur la case libérée.
    private static func push(_ game: GameState, level: Level) -> Result<RuleApplication, RuleViolation> {
        let ahead = game.robot.position.translated(by: game.robot.orientation)
        guard let crate = game.grid.cell(at: ahead)?.objects.first(where: { $0.kind == ObjectKind.crate }) else {
            return .failure(.nothingToPush)
        }
        let beyond = ahead.translated(by: game.robot.orientation)
        guard game.grid.cell(at: beyond)?.allowsCrate == true else {
            return .failure(.pushBlocked(attempted: beyond))
        }
        var updated = game
        updated.grid.updateCell(at: ahead) { cell in
            cell.objects.removeAll { $0.id == crate.id }
        }
        updated.grid.updateCell(at: beyond) { cell in
            cell.objects.append(PlacedObject(id: crate.id, kind: crate.kind))
        }
        updated.robot.position = ahead
        updated.metrics.moves += 1
        countInteraction(&updated)
        refreshObjectives(&updated, level: level)
        return .success(RuleApplication(
            game: updated,
            event: .pushed(objectID: crate.id, from: ahead, to: beyond)
        ))
    }

    /// ACTIVE ne vaut que sur la case de l'interrupteur, et une seule fois.
    /// La grille liée s'ouvre et reste ouverte. L'interrupteur devant le robot ne compte pas.
    private static func activate(_ game: GameState, level: Level) -> Result<RuleApplication, RuleViolation> {
        guard let located = plate(at: game.robot.position, in: game), !located.mechanism.isActive else {
            return .failure(.nothingToActivate)
        }
        var updated = game
        updated.grid.updateCell(at: located.coordinate) { cell in
            guard let index = cell.mechanisms.firstIndex(where: { $0.id == located.mechanism.id }) else { return }
            cell.mechanisms[index].isActive = true
        }
        if let doorID = located.mechanism.link {
            for cell in updated.grid.cells where cell.mechanisms.contains(where: { $0.id == doorID }) {
                updated.grid.updateCell(at: cell.coordinate) { doorCell in
                    guard let index = doorCell.mechanisms.firstIndex(where: { $0.id == doorID && $0.kind == MechanismKind.door }) else { return }
                    doorCell.mechanisms[index].isActive = true
                }
            }
        }
        countInteraction(&updated)
        refreshObjectives(&updated, level: level)
        return .success(RuleApplication(
            game: updated,
            event: .activated(mechanismID: located.mechanism.id, at: located.coordinate, isActive: true)
        ))
    }

    private struct LocatedPlate {
        var coordinate: GridCoordinate
        var mechanism: PlacedMechanism
    }

    private static func plate(at coordinate: GridCoordinate, in game: GameState) -> LocatedPlate? {
        guard let mechanism = game.grid.cell(at: coordinate)?.mechanisms.first(where: { $0.kind == MechanismKind.plate }) else {
            return nil
        }
        return LocatedPlate(coordinate: coordinate, mechanism: mechanism)
    }

    private static func countInteraction(_ game: inout GameState) {
        game.metrics.interactions += 1
        game.metrics.executedInstructions += 1
    }

    private static func refreshObjectives(_ game: inout GameState, level: Level) {
        for index in game.objectives.indices {
            let identifier = game.objectives[index].id
            guard let objective = level.objectives.first(where: { $0.id == identifier }) else { continue }
            if isMet(objective, by: game) {
                game.objectives[index].isCompleted = true
            }
        }
    }

    private static func isMet(_ objective: Objective, by game: GameState) -> Bool {
        switch objective.kind {
        case .reachFlag:
            guard game.robot.position == objective.position else { return false }
            if objective.requiresItemHeld {
                return !game.robot.inventory.isEmpty
            }
            return true
        }
    }
}

/// Nom historique utilisé par l'intégrité du niveau, pour garder la règle de victoire au même endroit.
enum LevelRules {
    static func isSatisfied(_ game: GameState, level: Level) -> Bool {
        WorldRules.isSatisfied(game, level: level)
    }
}
