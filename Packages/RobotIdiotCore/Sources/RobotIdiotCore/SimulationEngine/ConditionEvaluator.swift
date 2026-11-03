import Foundation

/// Évalue une condition sur l'état courant. Une condition fausse n'est jamais une erreur.
public enum ConditionEvaluator {
    public static func evaluate(_ condition: ConditionType, game: GameState) -> Bool {
        switch condition {
        case .obstacleAhead:
            return !isFreeAhead(game)
        case .cellAheadFree:
            return isFreeAhead(game)
        case .objectPresent:
            return game.grid.cell(at: game.robot.position)?.objects.isEmpty == false
        case .doorClosed:
            return mechanismAhead(game, kind: MechanismKind.door)?.isActive == false
        case .switchActivated:
            let here = game.grid.cell(at: game.robot.position)?.mechanisms ?? []
            let ahead = cellAhead(game)?.mechanisms ?? []
            return (here + ahead).contains { $0.kind == MechanismKind.plate && $0.isActive }
        case .carryingItem:
            return !game.robot.inventory.isEmpty
        }
    }

    /// La case devant le robot existe et le robot peut y entrer sans mourir.
    public static func isFreeAhead(_ game: GameState) -> Bool {
        guard let cell = cellAhead(game) else { return false }
        return cell.allowsSafeRobotEntry
    }

    private static func cellAhead(_ game: GameState) -> Cell? {
        let destination = game.robot.position.translated(by: game.robot.orientation)
        return game.grid.cell(at: destination)
    }

    private static func mechanismAhead(_ game: GameState, kind: String) -> PlacedMechanism? {
        cellAhead(game)?.mechanisms.first { $0.kind == kind }
    }
}
