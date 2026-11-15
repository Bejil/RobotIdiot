import Foundation

public enum ExpertCatalogError: Error, Equatable, CustomStringConvertible {
    case missingResource(String)
    case unreadable(String)
    case invalid(String)

    public var description: String {
        switch self {
        case .missingResource(let name): return "\(name) est absent du bundle."
        case .unreadable(let name): return "\(name) est illisible."
        case .invalid(let detail): return detail
        }
    }
}

public enum ExpertCatalog {
    public static let pack: ExpertSimulationPack = {
        do { return try loadSimulationsBundled() }
        catch { fatalError("Pack Expert illisible : \(error)") }
    }()

    public static let tutorial: ExpertTutorialPack = {
        do { return try loadTutorialBundled() }
        catch { fatalError("Tutoriel Expert illisible : \(error)") }
    }()

    public static let config: ExpertConfig = {
        do { return try loadConfigBundled() }
        catch {
            return ExpertConfig(schemaVersion: "expert-config/1.0", mode: "expert", pack: nil)
        }
    }()

    public static let totalSimulations = 40

    public static func loadSimulationsBundled() throws -> ExpertSimulationPack {
        try load(name: "robot_idiot_expert_simulations_40", as: ExpertSimulationPack.self) { pack in
            guard pack.simulations.count == 40 else {
                throw ExpertCatalogError.invalid("Attendu 40 simulations, trouvé \(pack.simulations.count)")
            }
            let ids = pack.simulations.map(\.id)
            guard Set(ids).count == ids.count else {
                throw ExpertCatalogError.invalid("IDs Expert non uniques")
            }
        }
    }

    public static func loadTutorialBundled() throws -> ExpertTutorialPack {
        try load(name: "robot_idiot_expert_tutorial_fr", as: ExpertTutorialPack.self) { pack in
            guard pack.pages.count == 5 else {
                throw ExpertCatalogError.invalid("Attendu 5 pages de tutoriel, trouvé \(pack.pages.count)")
            }
        }
    }

    public static func loadConfigBundled() throws -> ExpertConfig {
        try load(name: "robot_idiot_expert_config", as: ExpertConfig.self) { _ in }
    }

    public static func simulation(id: String) -> ExpertSimulation? {
        pack.simulations.first { $0.id == id }
    }

    public static func simulation(sequence: Int) -> ExpertSimulation? {
        pack.simulations.first { $0.sequence == sequence }
    }

    public static var orderedSimulations: [ExpertSimulation] {
        pack.simulations.sorted { $0.sequence < $1.sequence }
    }

    public static func referenceProgram(for simulation: ExpertSimulation) -> Program {
        CatalogCampaign.program(from: simulation.reference.program)
    }

    public static func playableLevel(for simulation: ExpertSimulation) -> Level {
        let height = simulation.height
        func flipped(_ x: Int, _ y: Int) -> GridCoordinate {
            GridCoordinate(x: x, y: height - 1 - y)
        }

        var grid = Grid(width: simulation.width, height: height)
        for y in 0..<height {
            let row = Array(simulation.grid[y])
            for x in 0..<min(row.count, simulation.width) {
                let symbol = row[x]
                // `F` (objectif) et marqueurs de départ restent du sol praticable ;
                // la case Goal est posée via `objectives` (reachFlag à `finish`).
                let surface = terrain(for: symbol)
                grid.updateCell(at: flipped(x, y)) { cell in
                    cell.terrain = surface
                }
            }
        }

        for mechanic in simulation.mechanics {
            let at = flipped(mechanic.x, mechanic.y)
            switch mechanic.type {
            case "BoardKey":
                grid.updateCell(at: at) { cell in
                    cell.objects.append(PlacedObject(
                        id: "\(simulation.id)-key-\(mechanic.x)-\(mechanic.y)",
                        kind: ObjectKind.key
                    ))
                }
            case "BoardCrate":
                grid.updateCell(at: at) { cell in
                    cell.objects.append(PlacedObject(
                        id: "\(simulation.id)-crate-\(mechanic.x)-\(mechanic.y)",
                        kind: ObjectKind.crate
                    ))
                }
            case "BoardLock":
                grid.updateCell(at: at) { cell in
                    cell.mechanisms.append(PlacedMechanism(
                        id: "\(simulation.id)-lock-\(mechanic.x)-\(mechanic.y)",
                        kind: MechanismKind.door,
                        isActive: false
                    ))
                }
            case "BoardDoor":
                let link = mechanic.linkId ?? "\(simulation.id)-gate-\(mechanic.x)-\(mechanic.y)"
                grid.updateCell(at: at) { cell in
                    cell.mechanisms.append(PlacedMechanism(
                        id: link,
                        kind: MechanismKind.door,
                        isActive: false,
                        link: link
                    ))
                }
            case "BoardPlate":
                let link = mechanic.linkId ?? "\(simulation.id)-gate-\(mechanic.x)-\(mechanic.y)"
                grid.updateCell(at: at) { cell in
                    cell.mechanisms.append(PlacedMechanism(
                        id: "\(simulation.id)-plate-\(link)",
                        kind: MechanismKind.plate,
                        isActive: false,
                        link: link
                    ))
                }
            default:
                break
            }
        }

        let portals = portalLinks(from: simulation.mechanics, id: simulation.id, flip: flipped)
        let primitives = simulation.initiallyAvailableCommands.compactMap(CatalogCampaign.commandType(named:))
        let controls = simulation.unlockedControlCommands.compactMap(CatalogCampaign.commandType(named:))
        var allowed = primitives
        for command in controls where !allowed.contains(command) {
            allowed.append(command)
        }
        // SI peut être visible verrouillée : ne pas l'ajouter à allowed tant qu'elle n'est pas dans unlockedControlCommands.

        return Level(
            id: simulation.id,
            version: 1,
            seed: UInt64(simulation.sequence),
            generatorVersion: 0,
            worldNumber: simulation.visualThemeWorld,
            levelNumber: simulation.sequence,
            difficulty: Double(simulation.sequence) / 40,
            theme: CatalogCampaign.theme(for: simulation.visualThemeWorld),
            grid: grid,
            initialRobot: RobotState(
                position: flipped(simulation.start.x, simulation.start.y),
                orientation: direction(simulation.start.orientation)
            ),
            objectives: [
                Objective(
                    id: "\(simulation.id)-flag",
                    kind: .reachFlag,
                    position: flipped(simulation.finish.x, simulation.finish.y),
                    requiresItemHeld: simulation.objective.requiresItemHeld
                )
            ],
            allowedCommands: allowed,
            programConstraints: ProgramConstraints(maxBlocks: nil, maxNestingDepth: 6),
            scoringRules: ScoringRules(
                compactProgramMaxBlocks: simulation.starTargets.threeStarsMax,
                efficientExecutionMaxSteps: simulation.starTargets.twoStarsMax,
                referenceNote: "Étoiles Expert : blocs écrits (référence non prouvée minimale)."
            ),
            validation: ValidationMetadata(status: .handcrafted, notes: ["expert", simulation.id]),
            collectibles: [],
            portalLinks: portals
        )
    }

    public static func lockedControls(for simulation: ExpertSimulation) -> [CommandType] {
        var locked: [CommandType] = []
        if !simulation.unlockedControlCommands.contains("SI") {
            locked.append(.ifBlock)
        }
        return locked
    }

    public static func unlockedConditions(for simulation: ExpertSimulation) -> [ConditionType] {
        simulation.unlockedConditions.compactMap(CatalogCampaign.mapCondition)
    }

    private static func portalLinks(
        from mechanics: [CatalogLevel.Mechanic],
        id: String,
        flip: (Int, Int) -> GridCoordinate
    ) -> [LevelPortalLink] {
        let portals = mechanics.filter { $0.type == "BoardPortal" }
        var byLink: [String: [CatalogLevel.Mechanic]] = [:]
        for portal in portals {
            let link = portal.linkId ?? "\(id)-portal"
            byLink[link, default: []].append(portal)
        }
        return byLink.compactMap { linkId, group in
            guard group.count == 2 else { return nil }
            return LevelPortalLink(
                linkId: linkId,
                endpoints: group.map { flip($0.x, $0.y) },
                visualVariant: group.first?.visualVariant ?? "A"
            )
        }
    }

    private static func terrain(for symbol: Character) -> TerrainType {
        switch symbol {
        case "B": return .bush
        case "R": return .cracked
        case "L": return .lava
        case "T": return .shutter
        case "P": return .spikes
        case "O": return .stone
        case "W": return .water
        // Objectif `F` + robot ASCII + herbe : sol libre (l’objectif n’est pas un obstacle).
        case "F", "g", "^", ">", "v", "<":
            return .floor
        default: return .floor
        }
    }

    /// Position moteur (Y retourné) de l’objectif Goal (`F` / `finish`).
    public static func goalPosition(for simulation: ExpertSimulation) -> GridCoordinate {
        GridCoordinate(x: simulation.finish.x, y: simulation.height - 1 - simulation.finish.y)
    }

    private static func direction(_ orientation: String) -> Direction {
        switch orientation {
        case "E": return .east
        case "S": return .south
        case "W": return .west
        default: return .north
        }
    }

    private static func load<T: Decodable>(
        name: String,
        as type: T.Type,
        validate: (T) throws -> Void
    ) throws -> T {
        guard let url = resourceURL(name: name) else {
            throw ExpertCatalogError.missingResource("\(name).json")
        }
        do {
            let data = try Data(contentsOf: url)
            let decoded = try JSONDecoder().decode(T.self, from: data)
            try validate(decoded)
            return decoded
        } catch let error as ExpertCatalogError {
            throw error
        } catch {
            throw ExpertCatalogError.unreadable("\(name).json")
        }
    }

    private static func resourceURL(name: String) -> URL? {
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
        }
        return nil
    }
}
