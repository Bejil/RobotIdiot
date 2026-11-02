import Foundation

/// Case de la grille logique.
///
/// `x` augmente vers la droite, `y` augmente vers le haut.
/// Cette convention coïncide avec SpriteKit et reste indépendante des pixels.
public struct GridCoordinate: Codable, Hashable, Sendable {
    public var x: Int
    public var y: Int

    public init(x: Int, y: Int) {
        self.x = x
        self.y = y
    }

    public func translated(by direction: Direction, distance: Int = 1) -> GridCoordinate {
        GridCoordinate(
            x: x + direction.dx * distance,
            y: y + direction.dy * distance
        )
    }

    /// Direction d'un pas unitaire vers `other`. `nil` si les cases ne sont pas voisines.
    public func step(toward other: GridCoordinate) -> Direction? {
        let dx = other.x - x
        let dy = other.y - y
        if dx == 1 && dy == 0 { return .east }
        if dx == -1 && dy == 0 { return .west }
        if dx == 0 && dy == 1 { return .north }
        if dx == 0 && dy == -1 { return .south }
        return nil
    }
}

/// Orientation du robot, par quarts de tour.
public enum Direction: String, Codable, Hashable, Sendable, CaseIterable {
    case north
    case east
    case south
    case west

    public var left: Direction {
        switch self {
        case .north: return .west
        case .west: return .south
        case .south: return .east
        case .east: return .north
        }
    }

    public var right: Direction {
        switch self {
        case .north: return .east
        case .east: return .south
        case .south: return .west
        case .west: return .north
        }
    }

    public var opposite: Direction {
        left.left
    }

    public var dx: Int {
        switch self {
        case .east: return 1
        case .west: return -1
        case .north, .south: return 0
        }
    }

    public var dy: Int {
        switch self {
        case .north: return 1
        case .south: return -1
        case .east, .west: return 0
        }
    }

    /// Rotation SpriteKit : 0 pointe vers +y, donc vers le nord.
    public var spriteRotation: Double {
        switch self {
        case .north: return 0
        case .west: return .pi / 2
        case .south: return .pi
        case .east: return -.pi / 2
        }
    }
}
