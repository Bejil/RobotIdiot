import Foundation

public enum TerrainType: String, Codable, Hashable, Sendable {
    case floor
    case wall
    case bush
    case cracked
    case lava
    case shutter
    case spikes
    case stone
    case water

    /// Mur, buisson et autres obstacles solides : le robot reste sur sa case.
    public var blocksMovement: Bool {
        switch self {
        case .floor, .spikes, .lava, .water:
            return false
        case .wall, .bush, .cracked, .shutter, .stone:
            return true
        }
    }

    /// Pics, lave et eau : le robot peut y entrer, puis meurt.
    public var isLethal: Bool {
        switch self {
        case .spikes, .lava, .water:
            return true
        default:
            return false
        }
    }
}

/// Occupation dynamique d'une case. Le robot n'y est pas stocké :
/// sa position vit dans `RobotState`, ce qui sépare le niveau de la partie.
public enum Occupancy: String, Codable, Hashable, Sendable {
    case empty
}

public enum ObjectKind {
    public static let key = "key"
    public static let crate = "crate"
}

public enum MechanismKind {
    public static let door = "door"
    public static let plate = "switch"
}

public struct PlacedObject: Codable, Hashable, Sendable, Identifiable {
    public var id: String
    public var kind: String

    public init(id: String, kind: String) {
        self.id = id
        self.kind = kind
    }
}

public struct PlacedMechanism: Codable, Hashable, Sendable, Identifiable {
    public var id: String
    public var kind: String
    /// Pour un interrupteur, `true` signifie activé.
    /// Pour une porte, `true` signifie ouverte. Une porte inactive est fermée.
    public var isActive: Bool
    /// Porte ouverte ou fermée par cet interrupteur. `nil` si le mécanisme est autonome.
    public var link: String?

    public init(id: String, kind: String, isActive: Bool = false, link: String? = nil) {
        self.id = id
        self.kind = kind
        self.isActive = isActive
        self.link = link
    }
}

public struct Cell: Codable, Hashable, Sendable {
    public var coordinate: GridCoordinate
    public var terrain: TerrainType
    public var occupancy: Occupancy
    public var objects: [PlacedObject]
    public var mechanisms: [PlacedMechanism]

    public init(
        coordinate: GridCoordinate,
        terrain: TerrainType,
        occupancy: Occupancy = .empty,
        objects: [PlacedObject] = [],
        mechanisms: [PlacedMechanism] = []
    ) {
        self.coordinate = coordinate
        self.terrain = terrain
        self.occupancy = occupancy
        self.objects = objects
        self.mechanisms = mechanisms
    }

    /// Une clé se traverse : la ramasser est une commande.
    /// Une caisse et une porte fermée bloquent le passage.
    /// L'eau, la lave et les pics restent accessibles (puis mortels).
    public var allowsRobotEntry: Bool {
        !terrain.blocksMovement && occupancy == .empty && !containsCrate && !containsClosedDoor
    }

    /// Entrée sans danger : pas d'obstacle solide ni de terrain mortel.
    public var allowsSafeRobotEntry: Bool {
        allowsRobotEntry && !terrain.isLethal
    }

    /// La case d'arrivée d'une caisse est un sol sans autre caisse ni porte fermée.
    /// Une clé ne bloque pas la caisse. Les terrains mortels non plus.
    public var allowsCrate: Bool {
        !terrain.blocksMovement && !terrain.isLethal && occupancy == .empty && !containsCrate && !containsClosedDoor
    }

    public var containsCrate: Bool {
        objects.contains { $0.kind == ObjectKind.crate }
    }

    public var containsClosedDoor: Bool {
        mechanisms.contains { $0.kind == MechanismKind.door && !$0.isActive }
    }
}

public struct Grid: Codable, Hashable, Sendable {
    public var width: Int
    public var height: Int
    public var cells: [Cell]

    public init(width: Int, height: Int, walls: Set<GridCoordinate> = []) {
        self.width = width
        self.height = height
        var built: [Cell] = []
        built.reserveCapacity(max(0, width * height))
        guard width > 0, height > 0 else {
            self.cells = []
            return
        }
        for y in 0..<height {
            for x in 0..<width {
                let coordinate = GridCoordinate(x: x, y: y)
                let terrain: TerrainType = walls.contains(coordinate) ? .wall : .floor
                built.append(Cell(coordinate: coordinate, terrain: terrain))
            }
        }
        self.cells = built
    }

    public init(width: Int, height: Int, cells: [Cell]) {
        self.width = width
        self.height = height
        self.cells = cells
    }

    public func contains(_ coordinate: GridCoordinate) -> Bool {
        coordinate.x >= 0 && coordinate.y >= 0 && coordinate.x < width && coordinate.y < height
    }

    public func index(of coordinate: GridCoordinate) -> Int? {
        guard contains(coordinate), cells.count == width * height else { return nil }
        return coordinate.y * width + coordinate.x
    }

    public func cell(at coordinate: GridCoordinate) -> Cell? {
        guard let index = index(of: coordinate) else { return nil }
        return cells[index]
    }

    public mutating func updateCell(at coordinate: GridCoordinate, _ body: (inout Cell) -> Void) {
        guard let index = index(of: coordinate) else { return }
        body(&cells[index])
    }

    public static func bordered(width: Int, height: Int, interiorWalls: Set<GridCoordinate> = []) -> Grid {
        var walls = interiorWalls
        guard width > 0, height > 0 else {
            return Grid(width: width, height: height, walls: walls)
        }
        for x in 0..<width {
            walls.insert(GridCoordinate(x: x, y: 0))
            walls.insert(GridCoordinate(x: x, y: height - 1))
        }
        for y in 0..<height {
            walls.insert(GridCoordinate(x: 0, y: y))
            walls.insert(GridCoordinate(x: width - 1, y: y))
        }
        return Grid(width: width, height: height, walls: walls)
    }
}
