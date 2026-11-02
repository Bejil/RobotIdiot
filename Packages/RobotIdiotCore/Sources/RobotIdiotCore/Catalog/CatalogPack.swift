import Foundation

/// Pack officiel `schemaVersion` 3.0.
/// L'axe Y du fichier augmente vers le bas. Cette orientation n'est pas inversée ici.
public struct LevelPack: Codable, Equatable, Sendable {
    public var schemaVersion: String
    public var game: String
    public var gridLegend: [String: String]
    public var coordinateSystem: String
    public var commandRules: [String: String]
    public var levels: [CatalogLevel]

    public static let supportedSchemaVersion = "3.0"
    public static let documentedCoordinateSystem = "x increases right, y increases down, zero indexed"
}

public struct CatalogLevel: Codable, Equatable, Sendable {
    public var id: String
    public var world: Int
    public var worldLevel: Int
    public var globalLevel: Int
    public var name: String
    public var width: Int
    public var height: Int
    public var grid: [String]
    public var start: Start
    public var finish: Finish
    public var objective: Objective
    public var family: String
    public var unlockedCommands: [String]
    public var mechanics: [Mechanic]
    public var obstacles: Obstacles
    public var solution: CatalogSolution
    public var generation: Generation
    public var difficulty: Difficulty

    public struct Start: Codable, Equatable, Sendable {
        public var x: Int
        public var y: Int
        public var orientation: String
    }

    public struct Finish: Codable, Equatable, Sendable {
        public var x: Int
        public var y: Int
    }

    public struct Objective: Codable, Equatable, Sendable {
        public var type: String
        public var requiresItemHeld: Bool

        private enum CodingKeys: String, CodingKey {
            case type
            case requiresItemHeld
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            type = try container.decode(String.self, forKey: .type)
            requiresItemHeld = try container.decodeIfPresent(Bool.self, forKey: .requiresItemHeld) ?? false
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(type, forKey: .type)
            try container.encode(requiresItemHeld, forKey: .requiresItemHeld)
        }
    }

    public struct Mechanic: Codable, Equatable, Sendable {
        public var type: String
        public var x: Int
        public var y: Int
    }

    public struct Obstacles: Codable, Equatable, Sendable {
        public var blockingTiles: [String: Int]
    }

    public struct Generation: Codable, Equatable, Sendable {
        public var seed: Int
        public var attempt: Int
        public var generatorVersion: String
    }

    public struct Difficulty: Codable, Equatable, Sendable {
        public var worldTier: Int
        public var optimalActionCount: Int
        public var wallCount: Int
    }

    var cells: [[Character]] {
        grid.map(Array.init)
    }
}

public struct CatalogSolution: Codable, Equatable, Sendable {
    public var program: [CatalogInstruction]
    public var expandedOptimalCommands: [String]
    public var actionCount: Int
    public var optimality: String
    public var validated: Bool
}

/// Instruction du pack. `REPETE` et `SI` portent leurs enfants ; ils ne sont pas des primitives.
public enum CatalogInstruction: Equatable, Sendable, Codable {
    case avance
    case recule
    case tourneGauche
    case tourneDroite
    case ramasse
    case utilise
    case pousse
    case active
    case repete([CatalogInstruction])
    case si(condition: String, body: [CatalogInstruction])

    public var commandName: String {
        switch self {
        case .avance: return "AVANCE"
        case .recule: return "RECULE"
        case .tourneGauche: return "TOURNE_GAUCHE"
        case .tourneDroite: return "TOURNE_DROITE"
        case .ramasse: return "RAMASSE"
        case .utilise: return "UTILISE"
        case .pousse: return "POUSSE"
        case .active: return "ACTIVE"
        case .repete: return "REPETE"
        case .si: return "SI"
        }
    }

    private enum CodingKeys: String, CodingKey {
        case command
        case condition
        case body
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let command = try container.decode(String.self, forKey: .command)
        switch command {
        case "AVANCE": self = .avance
        case "RECULE": self = .recule
        case "TOURNE_GAUCHE": self = .tourneGauche
        case "TOURNE_DROITE": self = .tourneDroite
        case "RAMASSE": self = .ramasse
        case "UTILISE": self = .utilise
        case "POUSSE": self = .pousse
        case "ACTIVE": self = .active
        case "REPETE":
            self = .repete(try container.decodeIfPresent([CatalogInstruction].self, forKey: .body) ?? [])
        case "SI":
            let condition = try container.decodeIfPresent(String.self, forKey: .condition) ?? ""
            let body = try container.decodeIfPresent([CatalogInstruction].self, forKey: .body) ?? []
            self = .si(condition: condition, body: body)
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .command,
                in: container,
                debugDescription: "Commande inconnue \(command)"
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(commandName, forKey: .command)
        switch self {
        case .repete(let body):
            try container.encode(body, forKey: .body)
        case .si(let condition, let body):
            try container.encode(condition, forKey: .condition)
            try container.encode(body, forKey: .body)
        default:
            break
        }
    }
}

public struct LevelPackIssue: Equatable, Sendable, CustomStringConvertible {
    public var levelID: String?
    public var rule: String
    public var observed: String

    public var description: String {
        let where_ = levelID.map { "\($0) — " } ?? ""
        return "\(where_)\(rule) : \(observed)"
    }
}

public enum LevelPackError: Error, Equatable, CustomStringConvertible {
    case missingResource
    case unreadable
    case invalid([LevelPackIssue])

    public var description: String {
        switch self {
        case .missingResource:
            return "robot_idiot_100_levels_v3.json est absent du bundle."
        case .unreadable:
            return "robot_idiot_100_levels_v3.json est illisible."
        case .invalid(let issues):
            return issues.map(\.description).joined(separator: "\n")
        }
    }
}

public enum LevelPackLoader {
    public static func loadBundled() throws -> LevelPack {
        guard let url = Bundle.module.url(forResource: "robot_idiot_100_levels_v3", withExtension: "json") else {
            throw LevelPackError.missingResource
        }
        let pack = try load(from: url)
        let issues = LevelPackChecker.issues(in: pack)
        if !issues.isEmpty {
            throw LevelPackError.invalid(issues)
        }
        return pack
    }

    public static func load(from url: URL) throws -> LevelPack {
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            throw LevelPackError.unreadable
        }
        return try decode(data)
    }

    public static func decode(_ data: Data) throws -> LevelPack {
        let decoder = JSONDecoder()
        do {
            return try decoder.decode(LevelPack.self, from: data)
        } catch {
            throw LevelPackError.invalid([
                LevelPackIssue(levelID: nil, rule: "décodage JSON", observed: String(describing: error))
            ])
        }
    }
}

public enum LevelPackChecker {
    public static let symbols: Set<Character> = Set("gBRLTPOWF^>v<KUADC0123456789")
    public static let orientations = ["N": "^", "E": ">", "S": "v", "W": "<"]
    public static let knownCommands: Set<String> = [
        "AVANCE", "RECULE", "TOURNE_GAUCHE", "TOURNE_DROITE",
        "RAMASSE", "UTILISE", "POUSSE", "ACTIVE", "REPETE", "SI"
    ]
    public static let mechanicSymbols = [
        "BoardKey": "K",
        "BoardLock": "U",
        "BoardPlate": "A",
        "BoardDoor": "D",
        "BoardCrate": "C"
    ]
    public static let blockingSymbols: Set<Character> = Set("BRLTPOW")

    public static func issues(in pack: LevelPack) -> [LevelPackIssue] {
        var issues: [LevelPackIssue] = []
        func report(_ id: String?, _ rule: String, _ observed: String) {
            issues.append(LevelPackIssue(levelID: id, rule: rule, observed: observed))
        }

        if pack.schemaVersion != LevelPack.supportedSchemaVersion {
            report(nil, "schemaVersion", "\(pack.schemaVersion) au lieu de \(LevelPack.supportedSchemaVersion)")
        }
        if pack.coordinateSystem != LevelPack.documentedCoordinateSystem {
            report(nil, "coordinateSystem", pack.coordinateSystem)
        }
        if pack.levels.count != 100 {
            report(nil, "nombre de niveaux", "\(pack.levels.count) au lieu de 100")
        }

        let identifiers = pack.levels.map(\.id)
        if Set(identifiers).count != identifiers.count {
            report(nil, "identifiants", "des identifiants sont répétés")
        }
        let expectedIDs = (1...100).map { String(format: "RI-%03d", $0) }
        if identifiers != expectedIDs, pack.levels.count == 100 {
            report(nil, "identifiants", "la suite n'est pas RI-001 … RI-100 dans l'ordre")
        }

        var seenGrids = Set<[String]>()
        for level in pack.levels {
            if !seenGrids.insert(level.grid).inserted {
                report(level.id, "grille unique", "cette grille est déjà utilisée")
            }
            issues.append(contentsOf: LevelPackChecker.issues(in: level))
        }
        return issues
    }

    public static func issues(in level: CatalogLevel) -> [LevelPackIssue] {
        var issues: [LevelPackIssue] = []
        func report(_ rule: String, _ observed: String) {
            issues.append(LevelPackIssue(levelID: level.id, rule: rule, observed: observed))
        }

        let expectedWorld = (level.globalLevel - 1) / 10 + 1
        let expectedWorldLevel = (level.globalLevel - 1) % 10 + 1
        if level.world != expectedWorld || level.worldLevel != expectedWorldLevel {
            report(
                "campagne",
                "monde \(level.world) niveau \(level.worldLevel) pour le rang \(level.globalLevel)"
            )
        }
        if level.width != 7 || level.height != 7 || level.grid.count != 7 || level.grid.contains(where: { $0.count != 7 }) {
            report("grille 7×7", "\(level.width)×\(level.height), \(level.grid.count) lignes")
        }

        let foreign = level.grid.joined().filter { !symbols.contains($0) }
        if !foreign.isEmpty {
            report("symboles", "caractères inconnus \(String(foreign))")
        }

        var arrows: [(Int, Int, Character)] = []
        var flags: [(Int, Int)] = []
        var counts: [Character: Int] = [:]
        if level.grid.count == 7, level.grid.allSatisfy({ $0.count == 7 }) {
            for (y, row) in level.grid.enumerated() {
                for (x, symbol) in row.enumerated() {
                    counts[symbol, default: 0] += 1
                    if "^>v<".contains(symbol) {
                        arrows.append((x, y, symbol))
                    }
                    if symbol == "F" {
                        flags.append((x, y))
                    }
                }
            }
        }
        if arrows.count != 1 {
            report("départ", "\(arrows.count) flèches au lieu d'une")
        }
        if flags.count != 1 {
            report("drapeau", "\(flags.count) drapeaux au lieu d'un")
        }
        if LevelPackChecker.orientations[level.start.orientation] == nil {
            report("orientation", level.start.orientation)
        }
        if !inBounds(level.start.x, level.start.y) {
            report("départ", "coordonnées \(level.start.x),\(level.start.y) hors grille")
        } else if arrows.count == 1 {
            let arrow = arrows[0]
            let expected = LevelPackChecker.orientations[level.start.orientation].map(Character.init)
            if arrow.0 != level.start.x || arrow.1 != level.start.y || arrow.2 != expected {
                report(
                    "départ",
                    "la flèche \(arrow) ne correspond pas à \(level.start.x),\(level.start.y) \(level.start.orientation)"
                )
            }
        }
        if !inBounds(level.finish.x, level.finish.y) {
            report("drapeau", "coordonnées \(level.finish.x),\(level.finish.y) hors grille")
        } else if flags.count == 1, flags[0] != (level.finish.x, level.finish.y) {
            report("drapeau", "F est en \(flags[0]) et finish en \(level.finish.x),\(level.finish.y)")
        }

        let portals = level.grid.joined().filter(\.isNumber)
        if !portals.isEmpty {
            report("portail", "le pack validé n'en place aucun, trouvé \(portals)")
        }
        let singular: [(Character, String)] = [("K", "clé"), ("U", "cadenas"), ("C", "caisse"), ("A", "plaque"), ("D", "porte")]
        for (symbol, name) in singular {
            if counts[symbol, default: 0] > 1 {
                report(name, "\(counts[symbol, default: 0]) occurrences")
            }
        }
        for mechanic in level.mechanics {
            guard let symbol = mechanicSymbols[mechanic.type] else {
                report("mécanisme", "type \(mechanic.type)")
                continue
            }
            guard inBounds(mechanic.x, mechanic.y), level.grid.count == 7, level.grid[mechanic.y].count == 7 else {
                report("mécanisme", "\(mechanic.type) en \(mechanic.x),\(mechanic.y) hors grille")
                continue
            }
            let placed = level.grid[mechanic.y][level.grid[mechanic.y].index(level.grid[mechanic.y].startIndex, offsetBy: mechanic.x)]
            if String(placed) != symbol {
                report("mécanisme", "\(mechanic.type) en \(mechanic.x),\(mechanic.y) vaut \(placed) au lieu de \(symbol)")
            }
        }
        let unknown = level.unlockedCommands.filter { !knownCommands.contains($0) }
        if !unknown.isEmpty {
            report("commandes débloquées", unknown.joined(separator: ", "))
        }
        reportProgram(level.solution.program, into: &issues, levelID: level.id)
        if level.objective.type != "reach_flag" {
            report("objectif", level.objective.type)
        }
        return issues
    }

    private static func inBounds(_ x: Int, _ y: Int) -> Bool {
        (0..<7).contains(x) && (0..<7).contains(y)
    }

    private static func reportProgram(_ program: [CatalogInstruction], into issues: inout [LevelPackIssue], levelID: String) {
        for instruction in program {
            switch instruction {
            case .si(let condition, let body):
                if condition != "CASE_DEVANT_LIBRE" {
                    issues.append(LevelPackIssue(
                        levelID: levelID,
                        rule: "condition SI",
                        observed: condition.isEmpty ? "condition absente" : condition
                    ))
                }
                reportProgram(body, into: &issues, levelID: levelID)
            case .repete(let body):
                reportProgram(body, into: &issues, levelID: levelID)
            default:
                break
            }
        }
    }
}
