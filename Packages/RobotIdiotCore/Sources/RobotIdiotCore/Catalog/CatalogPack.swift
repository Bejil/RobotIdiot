import Foundation

/// Pack officiel `schemaVersion` 7.0.
/// L'axe Y du fichier augmente vers le bas. Cette orientation n'est pas inversée ici.
public struct LevelPack: Codable, Equatable, Sendable {
    public var schemaVersion: String
    public var game: String
    public var gridLegend: [String: String]
    public var coordinateSystem: String
    public var commandRules: [String: String]
    public var levels: [CatalogLevel]

    public static let supportedSchemaVersion = "7.0"
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
    public var rewards: CatalogRewards?
    public var starTargets: CatalogStarTargets?

    private enum CodingKeys: String, CodingKey {
        case id, world, worldLevel, globalLevel, name, width, height, grid
        case start, finish, objective, family, unlockedCommands, mechanics
        case obstacles, solution, generation, difficulty, rewards, starTargets
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        world = try container.decode(Int.self, forKey: .world)
        worldLevel = try container.decode(Int.self, forKey: .worldLevel)
        globalLevel = try container.decode(Int.self, forKey: .globalLevel)
        name = try container.decode(String.self, forKey: .name)
        width = try container.decode(Int.self, forKey: .width)
        height = try container.decode(Int.self, forKey: .height)
        grid = try container.decode([String].self, forKey: .grid)
        start = try container.decode(Start.self, forKey: .start)
        finish = try container.decode(Finish.self, forKey: .finish)
        objective = try container.decode(Objective.self, forKey: .objective)
        family = try container.decode(String.self, forKey: .family)
        unlockedCommands = try container.decode([String].self, forKey: .unlockedCommands)
        mechanics = try container.decode([Mechanic].self, forKey: .mechanics)
        obstacles = try container.decode(Obstacles.self, forKey: .obstacles)
        solution = try container.decode(CatalogSolution.self, forKey: .solution)
        generation = try container.decode(Generation.self, forKey: .generation)
        difficulty = try container.decode(Difficulty.self, forKey: .difficulty)
        rewards = try container.decodeIfPresent(CatalogRewards.self, forKey: .rewards)
        starTargets = try container.decodeIfPresent(CatalogStarTargets.self, forKey: .starTargets)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(world, forKey: .world)
        try container.encode(worldLevel, forKey: .worldLevel)
        try container.encode(globalLevel, forKey: .globalLevel)
        try container.encode(name, forKey: .name)
        try container.encode(width, forKey: .width)
        try container.encode(height, forKey: .height)
        try container.encode(grid, forKey: .grid)
        try container.encode(start, forKey: .start)
        try container.encode(finish, forKey: .finish)
        try container.encode(objective, forKey: .objective)
        try container.encode(family, forKey: .family)
        try container.encode(unlockedCommands, forKey: .unlockedCommands)
        try container.encode(mechanics, forKey: .mechanics)
        try container.encode(obstacles, forKey: .obstacles)
        try container.encode(solution, forKey: .solution)
        try container.encode(generation, forKey: .generation)
        try container.encode(difficulty, forKey: .difficulty)
        try container.encodeIfPresent(rewards, forKey: .rewards)
        try container.encodeIfPresent(starTargets, forKey: .starTargets)
    }

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
        public var linkId: String?

        private enum CodingKeys: String, CodingKey {
            case type
            case x
            case y
            case linkId
        }

        public init(type: String, x: Int, y: Int, linkId: String? = nil) {
            self.type = type
            self.x = x
            self.y = y
            self.linkId = linkId
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            type = try container.decode(String.self, forKey: .type)
            x = try container.decode(Int.self, forKey: .x)
            y = try container.decode(Int.self, forKey: .y)
            linkId = try container.decodeIfPresent(String.self, forKey: .linkId)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(type, forKey: .type)
            try container.encode(x, forKey: .x)
            try container.encode(y, forKey: .y)
            try container.encodeIfPresent(linkId, forKey: .linkId)
        }
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
        public var solutionActionCount: Int
        public var walkablePathLength: Int
        public var turnsOnIntendedPath: Int
        public var maximumStraightRun: Int
        public var detourCount: Int
        public var deadEnds: Int
        public var wallCount: Int
        public var turns: Int
        public var moveActions: Int
        public var maxConsecutiveMovesSameDirection: Int
        public var optimalActionCount: Int?
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
            return "robot_idiot_100_levels_v7.json est absent du bundle."
        case .unreadable:
            return "robot_idiot_100_levels_v7.json est illisible."
        case .invalid(let issues):
            return issues.map(\.description).joined(separator: "\n")
        }
    }
}

public enum LevelPackLoader {
    public static func loadBundled() throws -> LevelPack {
        guard let url = bundledPackURL() else {
            throw LevelPackError.missingResource
        }
        let pack = try load(from: url)
        let issues = LevelPackChecker.issues(in: pack)
        if !issues.isEmpty {
            throw LevelPackError.invalid(issues)
        }
        return pack
    }

    /// Cherche le pack dans le bundle SPM, puis dans l'app et les bundles embarqués (device).
    private static func bundledPackURL() -> URL? {
        let name = "robot_idiot_100_levels_v7"
        if let url = Bundle.module.url(forResource: name, withExtension: "json") {
            return url
        }
        if let url = Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Resources") {
            return url
        }
        let bundles = [Bundle.main] + Bundle.allBundles + Bundle.allFrameworks
        for bundle in bundles {
            if let url = bundle.url(forResource: name, withExtension: "json") {
                return url
            }
            if let url = bundle.url(forResource: name, withExtension: "json", subdirectory: "Resources") {
                return url
            }
            if let root = bundle.resourceURL {
                let candidates = [
                    root.appendingPathComponent("\(name).json"),
                    root.appendingPathComponent("Resources/\(name).json"),
                    root.appendingPathComponent("RobotIdiotCore_RobotIdiotCore.bundle/\(name).json"),
                    root.appendingPathComponent("RobotIdiotCore_RobotIdiotCore.bundle/Resources/\(name).json")
                ]
                for candidate in candidates where FileManager.default.fileExists(atPath: candidate.path) {
                    return candidate
                }
            }
        }
        return nil
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
            if mechanic.type == "BoardPlate" || mechanic.type == "BoardDoor" {
                if mechanic.linkId?.isEmpty != false {
                    report("mécanisme", "\(mechanic.type) sans linkId en \(mechanic.x),\(mechanic.y)")
                }
            }
        }
        let plateLinks = Set(level.mechanics.compactMap { $0.type == "BoardPlate" ? $0.linkId : nil })
        let doorLinks = Set(level.mechanics.compactMap { $0.type == "BoardDoor" ? $0.linkId : nil })
        if plateLinks != doorLinks {
            report("liaison", "plaques \(plateLinks.sorted()) / portes \(doorLinks.sorted())")
        }
        let unknown = level.unlockedCommands.filter { !knownCommands.contains($0) }
        if !unknown.isEmpty {
            report("commandes débloquées", unknown.joined(separator: ", "))
        }
        reportProgram(level.solution.program, into: &issues, levelID: level.id)
        if level.objective.type != "reach_flag" {
            report("objectif", level.objective.type)
        }
        let collectibles = level.rewards?.collectibles ?? []
        if collectibles.count > 1 {
            report("récompense", "\(collectibles.count) collectibles au lieu d'au plus 1")
        }
        for item in collectibles {
            if item.type != "BoardBolt" {
                report("récompense", "type \(item.type)")
            }
            if !inBounds(item.x, item.y) {
                report("récompense", "\(item.id) hors grille")
            } else if level.grid.count == 7, level.grid[item.y].count == 7 {
                let tile = level.grid[item.y][level.grid[item.y].index(level.grid[item.y].startIndex, offsetBy: item.x)]
                if tile != "g" && !"KUCAD".contains(tile) {
                    // Overlay sur herbe : g, ou mécanique posée sur herbe.
                    if !"^>v<F".contains(tile) && LevelPackChecker.blockingSymbols.contains(tile) {
                        report("récompense", "\(item.id) sur case bloquante \(tile)")
                    }
                }
            }
            if item.amount < 1 {
                report("récompense", "\(item.id) amount \(item.amount)")
            }
        }
        if let stars = level.starTargets {
            if stars.withoutBonus.threeStarsMax < 1 {
                report("étoiles", "withoutBonus.threeStarsMax invalide")
            }
            if collectibles.isEmpty, stars.withBonus != nil {
                report("étoiles", "withBonus présent sans collectible")
            }
            if !collectibles.isEmpty, stars.withBonus == nil {
                report("étoiles", "withBonus absent malgré un collectible")
            }
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
                if condition != "CASE_DEVANT_LIBRE", condition != "OBSTACLE_DEVANT" {
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
