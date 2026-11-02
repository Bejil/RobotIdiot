import Foundation

/// Campagne jouable : les 100 grilles du pack, dix mondes de dix niveaux.
/// Les coordonnées du fichier augmentent vers le bas. Le `Level` en mémoire
/// les retourne pour le moteur, dont Y augmente vers le haut, sans déplacer
/// une case par rapport aux autres.
public enum CatalogCampaign {
    public static let worldCount = 10
    public static let levelsPerWorld = 10
    public static let formulaVersion = 4
    public static let layout = CampaignLayout(standardLevelCount: 10, includesFinale: false)

    public static let pack: LevelPack = {
        do {
            return try LevelPackLoader.loadBundled()
        } catch {
            fatalError("Le pack de niveaux est illisible : \(error)")
        }
    }()

    public static func catalogLevel(at address: LevelAddress) -> CatalogLevel? {
        pack.levels.first { $0.world == address.world && $0.worldLevel == address.level }
    }

    public static func level(at address: LevelAddress) -> Level? {
        catalogLevel(at: address).map(playableLevel)
    }

    public static func mechanicTitle(for world: Int) -> String {
        var seen: [String] = []
        for level in pack.levels where level.world == world {
            if !seen.contains(level.family) {
                seen.append(level.family)
            }
        }
        var names = seen.map(familyTitle)
        if pack.levels.contains(where: { $0.world == world && $0.objective.requiresItemHeld }),
           !names.contains("Clé à garder") {
            names.append("Clé à garder")
        }
        return names.isEmpty ? "Déplacements" : names.joined(separator: " · ")
    }

    public static func theme(for world: Int) -> ThemeIdentifier {
        let families = pack.levels.filter { $0.world == world }.map(\.family)
        if families.contains("key_door") { return .orchard }
        if families.contains("switch_gate") { return .night }
        if families.contains("push_crate") { return .foundry }
        return .laboratory
    }

    public static func playableLevel(_ source: CatalogLevel) -> Level {
        let height = source.height
        func flipped(_ x: Int, _ y: Int) -> GridCoordinate {
            GridCoordinate(x: x, y: height - 1 - y)
        }

        let rows = source.cells
        var grid = Grid(width: source.width, height: height)
        if rows.count == height {
            for y in 0..<height {
                for x in 0..<rows[y].count {
                    let surface = terrain(for: rows[y][x])
                    grid.updateCell(at: flipped(x, y)) { cell in
                        cell.terrain = surface
                    }
                }
            }
        }

        if let key = source.mechanics.first(where: { $0.type == "BoardKey" }) {
            grid.updateCell(at: flipped(key.x, key.y)) { cell in
                cell.objects.append(PlacedObject(id: "\(source.id)-key", kind: ObjectKind.key))
            }
        }
        if let crate = source.mechanics.first(where: { $0.type == "BoardCrate" }) {
            grid.updateCell(at: flipped(crate.x, crate.y)) { cell in
                cell.objects.append(PlacedObject(id: "\(source.id)-crate", kind: ObjectKind.crate))
            }
        }
        let gateID = "\(source.id)-gate"
        if let gate = source.mechanics.first(where: { $0.type == "BoardDoor" }) {
            grid.updateCell(at: flipped(gate.x, gate.y)) { cell in
                cell.mechanisms.append(PlacedMechanism(id: gateID, kind: MechanismKind.door, isActive: false, link: "\(source.id)-switch"))
            }
        }
        if let door = source.mechanics.first(where: { $0.type == "BoardLock" }) {
            grid.updateCell(at: flipped(door.x, door.y)) { cell in
                cell.mechanisms.append(PlacedMechanism(id: "\(source.id)-door", kind: MechanismKind.door, isActive: false))
            }
        }
        if let plate = source.mechanics.first(where: { $0.type == "BoardPlate" }) {
            let link = source.mechanics.contains(where: { $0.type == "BoardDoor" }) ? gateID : nil
            grid.updateCell(at: flipped(plate.x, plate.y)) { cell in
                cell.mechanisms.append(PlacedMechanism(id: "\(source.id)-switch", kind: MechanismKind.plate, isActive: false, link: link))
            }
        }

        let allowed = source.unlockedCommands.compactMap(commandType)
        let nesting = allowed.contains(.forever) || allowed.contains(.ifBlock) ? 4 : 1
        var notes = [source.family]
        if source.objective.requiresItemHeld {
            notes.append("hold_key")
        }
        var level = Level(
            id: source.id,
            version: 1,
            seed: UInt64(max(0, source.generation.seed)),
            generatorVersion: 0,
            worldNumber: source.world,
            levelNumber: source.worldLevel,
            difficulty: Double(source.difficulty.worldTier) / 10,
            theme: theme(for: source.world),
            grid: grid,
            initialRobot: RobotState(
                position: flipped(source.start.x, source.start.y),
                orientation: direction(source.start.orientation)
            ),
            objectives: [
                Objective(
                    id: "\(source.id)-flag",
                    kind: .reachFlag,
                    position: flipped(source.finish.x, source.finish.y),
                    requiresItemHeld: source.objective.requiresItemHeld
                )
            ],
            allowedCommands: allowed,
            programConstraints: ProgramConstraints(maxBlocks: nil, maxNestingDepth: nesting),
            scoringRules: ScoringRules(
                compactProgramMaxBlocks: nil,
                efficientExecutionMaxSteps: nil,
                referenceNote: ""
            ),
            validation: ValidationMetadata(status: .handcrafted, notes: notes)
        )
        let minimum = ActionSearch.shortest(level: level)?.actionCount ?? source.solution.actionCount
        let word = minimum > 1 ? "commandes" : "commande"
        level.scoringRules = ScoringRules(
            compactProgramMaxBlocks: nil,
            efficientExecutionMaxSteps: minimum,
            referenceNote: "La solution optimale compte \(minimum) \(word)."
        )
        return level
    }

    public static func referenceProgram(for source: CatalogLevel) -> Program {
        Program(instructions: source.solution.program.map(instruction))
    }

    private static func familyTitle(_ family: String) -> String {
        switch family {
        case "key_door": return "Clés et portes"
        case "switch_gate": return "Interrupteurs"
        case "push_crate": return "Caisses"
        case "infinite_loop_navigation": return "Boucles"
        case "infinite_loop_with_condition": return "Conditions"
        default: return "Déplacements"
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
        default: return .floor
        }
    }

    private static func direction(_ orientation: String) -> Direction {
        switch orientation {
        case "E": return .east
        case "S": return .south
        case "W": return .west
        default: return .north
        }
    }

    private static func commandType(_ name: String) -> CommandType? {
        switch name {
        case "AVANCE": return .moveForward
        case "RECULE": return .moveBackward
        case "TOURNE_GAUCHE": return .turnLeft
        case "TOURNE_DROITE": return .turnRight
        case "RAMASSE": return .pickUp
        case "UTILISE": return .use
        case "POUSSE": return .push
        case "ACTIVE": return .activate
        case "REPETE": return .forever
        case "SI": return .ifBlock
        default: return nil
        }
    }

    private static func instruction(_ node: CatalogInstruction) -> Instruction {
        switch node {
        case .avance: return Instruction(command: .moveForward)
        case .recule: return Instruction(command: .moveBackward)
        case .tourneGauche: return Instruction(command: .turnLeft)
        case .tourneDroite: return Instruction(command: .turnRight)
        case .ramasse: return Instruction(command: .pickUp)
        case .utilise: return Instruction(command: .use)
        case .pousse: return Instruction(command: .push)
        case .active: return Instruction(command: .activate)
        case .repete(let body):
            return Instruction(command: .forever, children: body.map(instruction))
        case .si(let condition, let body):
            return Instruction(
                command: .ifBlock,
                condition: ConditionType(rawValue: condition) ?? .cellAheadFree,
                children: body.map(instruction)
            )
        }
    }
}
