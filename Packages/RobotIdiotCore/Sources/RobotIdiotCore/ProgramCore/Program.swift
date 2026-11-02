import Foundation

public enum CommandCategory: String, Codable, Hashable, Sendable {
    case movement
    case interaction
    case control
}

/// Les dix commandes du langage.
///
/// `forever` est REPETE. Il n'a pas de compteur, pas de paramètre et n'en aura jamais.
/// Il tourne jusqu'à la victoire, une erreur, l'arrêt du joueur ou une limite interne du moteur.
public enum CommandType: String, Codable, Hashable, Sendable, CaseIterable {
    case moveForward = "AVANCE"
    case moveBackward = "RECULE"
    case turnLeft = "TOURNE_GAUCHE"
    case turnRight = "TOURNE_DROITE"
    case pickUp = "RAMASSE"
    case use = "UTILISE"
    case push = "POUSSE"
    case activate = "ACTIVE"
    case forever = "REPETE"
    case ifBlock = "SI"

    public var category: CommandCategory {
        switch self {
        case .moveForward, .moveBackward, .turnLeft, .turnRight:
            return .movement
        case .pickUp, .use, .push, .activate:
            return .interaction
        case .forever, .ifBlock:
            return .control
        }
    }

    public var isContainer: Bool {
        switch self {
        case .forever, .ifBlock:
            return true
        case .moveForward, .moveBackward, .turnLeft, .turnRight, .pickUp, .use, .push, .activate:
            return false
        }
    }

    public static let movement: [CommandType] = [
        .moveForward, .moveBackward, .turnLeft, .turnRight
    ]
}

public enum ConditionType: String, Codable, Hashable, Sendable, CaseIterable {
    case obstacleAhead = "OBSTACLE_DEVANT"
    case cellAheadFree = "CASE_DEVANT_LIBRE"
    case objectPresent = "OBJET_PRESENT"
    case doorClosed = "PORTE_FERMEE"
    case switchActivated = "INTERRUPTEUR_ACTIVE"
    case carryingItem = "TRANSPORTE_OBJET"
}

public struct Instruction: Codable, Hashable, Sendable, Identifiable {
    public var id: UUID
    public var command: CommandType
    public var condition: ConditionType?
    public var children: [Instruction]

    public init(
        id: UUID = UUID(),
        command: CommandType,
        condition: ConditionType? = nil,
        children: [Instruction] = []
    ) {
        self.id = id
        self.command = command
        self.condition = condition
        self.children = children
    }

    public var nodeCount: Int {
        1 + children.reduce(0) { $0 + $1.nodeCount }
    }

    public func duplicated() -> Instruction {
        Instruction(
            command: command,
            condition: condition,
            children: children.map { $0.duplicated() }
        )
    }

    public mutating func removeChild(id: UUID) -> Bool {
        if let index = children.firstIndex(where: { $0.id == id }) {
            children.remove(at: index)
            return true
        }
        for index in children.indices where children[index].removeChild(id: id) {
            return true
        }
        return false
    }
}

extension Instruction {
    fileprivate func contains(_ id: UUID) -> Bool {
        if self.id == id { return true }
        return children.contains { $0.contains(id) }
    }
}

/// Arbre syntaxique unique, partagé plus tard par l'éditeur de blocs et l'éditeur de texte.
public struct Program: Codable, Hashable, Sendable, Identifiable {
    public var id: UUID
    public var version: Int
    public var instructions: [Instruction]

    public init(id: UUID = UUID(), version: Int = 1, instructions: [Instruction] = []) {
        self.id = id
        self.version = version
        self.instructions = instructions
    }

    public var blockCount: Int {
        instructions.reduce(0) { $0 + $1.nodeCount }
    }

    public var nestingDepth: Int {
        func depth(of nodes: [Instruction]) -> Int {
            nodes.map { 1 + depth(of: $0.children) }.max() ?? 0
        }
        return depth(of: instructions)
    }

    public mutating func appendRoot(_ command: CommandType) {
        instructions.append(Self.make(command))
    }

    /// Ajoute une commande à la racine, ou dans le conteneur `parentID`.
    /// Un nouveau SI reçoit la condition case devant libre.
    @discardableResult
    public mutating func append(_ command: CommandType, toParent parentID: UUID?) -> UUID? {
        let instruction = Self.make(command)
        guard let parentID else {
            instructions.append(instruction)
            return instruction.id
        }
        return insert(instruction, parent: parentID, into: &instructions) ? instruction.id : nil
    }

    @discardableResult
    public mutating func setCondition(_ condition: ConditionType, on id: UUID) -> Bool {
        func walk(_ nodes: inout [Instruction]) -> Bool {
            for index in nodes.indices {
                if nodes[index].id == id {
                    guard nodes[index].command == .ifBlock else { return false }
                    nodes[index].condition = condition
                    return true
                }
                if walk(&nodes[index].children) { return true }
            }
            return false
        }
        return walk(&instructions)
    }

    /// Déplace une instruction parmi ses frères. `offset` vaut -1 ou 1.
    @discardableResult
    public mutating func moveSibling(_ id: UUID, offset: Int) -> Bool {
        func walk(_ nodes: inout [Instruction]) -> Bool {
            if let index = nodes.firstIndex(where: { $0.id == id }) {
                let destination = index + offset
                guard nodes.indices.contains(destination) else { return false }
                nodes.swapAt(index, destination)
                return true
            }
            for index in nodes.indices where walk(&nodes[index].children) {
                return true
            }
            return false
        }
        return walk(&instructions)
    }

    public func ancestorIDs(of id: UUID) -> [UUID] {
        var found: [UUID] = []
        func walk(_ nodes: [Instruction], ancestors: [UUID]) -> Bool {
            for node in nodes {
                if node.id == id {
                    found = ancestors
                    return true
                }
                if walk(node.children, ancestors: ancestors + [node.id]) { return true }
            }
            return false
        }
        _ = walk(instructions, ancestors: [])
        return found
    }

    public var rows: [ProgramRow] {
        var built: [ProgramRow] = []
        func walk(_ nodes: [Instruction], depth: Int) {
            for node in nodes {
                built.append(ProgramRow(id: node.id, depth: depth, instruction: node))
                walk(node.children, depth: depth + 1)
            }
        }
        walk(instructions, depth: 0)
        return built
    }

    private static func make(_ command: CommandType) -> Instruction {
        Instruction(
            command: command,
            condition: command == .ifBlock ? .cellAheadFree : nil
        )
    }

    private func insert(_ instruction: Instruction, parent: UUID, into nodes: inout [Instruction]) -> Bool {
        for index in nodes.indices {
            if nodes[index].id == parent {
                guard nodes[index].command.isContainer else { return false }
                nodes[index].children.append(instruction)
                return true
            }
            if insert(instruction, parent: parent, into: &nodes[index].children) { return true }
        }
        return false
    }

    @discardableResult
    public mutating func remove(id: UUID) -> Bool {
        if let index = instructions.firstIndex(where: { $0.id == id }) {
            instructions.remove(at: index)
            return true
        }
        for index in instructions.indices where instructions[index].removeChild(id: id) {
            return true
        }
        return false
    }

    /// `destination` est l'index après retrait, comme `UITableView` le fournit.
    public mutating func relocateRoot(from source: Int, to destination: Int) {
        guard instructions.indices.contains(source) else { return }
        let item = instructions.remove(at: source)
        let clamped = min(max(destination, 0), instructions.count)
        instructions.insert(item, at: clamped)
    }

    /// Déplace une instruction devant une autre, dans un conteneur, ou à la fin du programme.
    /// Refuse de poser un bloc dans sa propre descendance.
    @discardableResult
    public mutating func relocate(_ id: UUID, to placement: ProgramPlacement) -> Bool {
        guard let moving = instruction(id: id) else { return false }
        switch placement {
        case .atRootEnd:
            break
        case .before(let anchor):
            if anchor == id || moving.contains(anchor) { return false }
            guard instruction(id: anchor) != nil else { return false }
        case .into(let parent):
            guard let parentNode = instruction(id: parent), parentNode.command.isContainer else { return false }
            if parent == id || moving.contains(parent) { return false }
        }
        guard remove(id: id) else { return false }
        switch placement {
        case .atRootEnd:
            instructions.append(moving)
            return true
        case .before(let anchor):
            return insert(moving, before: anchor)
        case .into(let parent):
            return insert(moving, parent: parent, into: &instructions)
        }
    }

    private mutating func insert(_ node: Instruction, before anchor: UUID) -> Bool {
        func walk(_ nodes: inout [Instruction]) -> Bool {
            if let index = nodes.firstIndex(where: { $0.id == anchor }) {
                nodes.insert(node, at: index)
                return true
            }
            for index in nodes.indices where walk(&nodes[index].children) {
                return true
            }
            return false
        }
        return walk(&instructions)
    }

    @discardableResult
    public mutating func duplicate(id: UUID) -> Bool {
        func walk(_ nodes: inout [Instruction]) -> Bool {
            for index in nodes.indices {
                if nodes[index].id == id {
                    nodes.insert(nodes[index].duplicated(), at: index + 1)
                    return true
                }
                if walk(&nodes[index].children) {
                    return true
                }
            }
            return false
        }
        return walk(&instructions)
    }

    public func instruction(id: UUID) -> Instruction? {
        func walk(_ nodes: [Instruction]) -> Instruction? {
            for node in nodes {
                if node.id == id { return node }
                if let found = walk(node.children) { return found }
            }
            return nil
        }
        return walk(instructions)
    }
}

public enum ProgramPlacement: Equatable, Sendable {
    case atRootEnd
    case before(UUID)
    case into(UUID)
}

public struct ProgramRow: Equatable, Sendable {
    public var id: UUID
    public var depth: Int
    public var instruction: Instruction

    public init(id: UUID, depth: Int, instruction: Instruction) {
        self.id = id
        self.depth = depth
        self.instruction = instruction
    }
}

public enum ProgramIssue: Equatable, Sendable {
    case commandNotAllowed(CommandType)
    case leafHasChildren(CommandType)
    case missingCondition
    case unexpectedCondition(CommandType)
    case emptyForever
    case nestingTooDeep(limit: Int)
    case tooManyBlocks(limit: Int)
}

public enum ProgramValidator {
    public static func issues(in program: Program, level: Level) -> [ProgramIssue] {
        var found: [ProgramIssue] = []
        let allowed = Set(level.allowedCommands)
        walk(program.instructions, allowed: allowed, issues: &found)
        if program.nestingDepth > level.programConstraints.maxNestingDepth {
            found.append(.nestingTooDeep(limit: level.programConstraints.maxNestingDepth))
        }
        if let limit = level.programConstraints.maxBlocks, program.blockCount > limit {
            found.append(.tooManyBlocks(limit: limit))
        }
        return found
    }

    private static func walk(_ nodes: [Instruction], allowed: Set<CommandType>, issues: inout [ProgramIssue]) {
        for node in nodes {
            if !allowed.contains(node.command) {
                issues.append(.commandNotAllowed(node.command))
            }
            if node.command.isContainer {
                if node.command == .ifBlock && node.condition == nil {
                    issues.append(.missingCondition)
                }
                if node.command == .forever && node.children.isEmpty {
                    issues.append(.emptyForever)
                }
            } else if !node.children.isEmpty {
                issues.append(.leafHasChildren(node.command))
            }
            if node.command != .ifBlock && node.condition != nil {
                issues.append(.unexpectedCondition(node.command))
            }
            walk(node.children, allowed: allowed, issues: &issues)
        }
    }
}
