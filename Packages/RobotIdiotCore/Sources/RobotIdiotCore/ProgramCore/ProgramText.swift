import Foundation

public enum TextCompletion: Equatable, Sendable {
    case command(CommandType)
    case condition(ConditionType)

    public var token: String {
        switch self {
        case .command(let command):
            return command.rawValue
        case .condition(let condition):
            return condition.rawValue
        }
    }
}

public struct TextCompletionSet: Equatable, Sendable {
    /// Zone UTF-16 du mot en cours, à remplacer par le jeton choisi.
    public var replacementUTF16: NSRange
    public var items: [TextCompletion]

    public init(replacementUTF16: NSRange, items: [TextCompletion]) {
        self.replacementUTF16 = replacementUTF16
        self.items = items
    }
}

public struct ProgramDiagnostic: Equatable, Sendable {
    public var line: Int
    public var message: String

    public init(line: Int, message: String) {
        self.line = line
        self.message = message
    }
}

public struct ProgramParse: Equatable, Sendable {
    public var program: Program?
    public var diagnostics: [ProgramDiagnostic]
    /// Un identifiant par ligne du texte, `nil` pour une ligne vide.
    public var lineIDs: [UUID?]

    public init(program: Program?, diagnostics: [ProgramDiagnostic], lineIDs: [UUID?]) {
        self.program = program
        self.diagnostics = diagnostics
        self.lineIDs = lineIDs
    }
}

/// Pseudo-langage du mode texte. L'indentation de deux espaces porte la structure.
/// `REPETE` n'accepte aucun compteur.
public enum ProgramText {
    public static func render(_ program: Program) -> (source: String, lineIDs: [UUID?]) {
        var lines: [String] = []
        var identifiers: [UUID?] = []
        func walk(_ nodes: [Instruction], depth: Int) {
            for node in nodes {
                let indent = String(repeating: " ", count: depth * 2)
                let words = node.command == .ifBlock
                    ? "\(node.command.rawValue) \(node.condition?.rawValue ?? "")".trimmingCharacters(in: .whitespaces)
                    : node.command.rawValue
                lines.append(indent + words)
                identifiers.append(node.id)
                walk(node.children, depth: depth + 1)
            }
        }
        walk(program.instructions, depth: 0)
        let source = lines.isEmpty ? "" : lines.joined(separator: "\n") + "\n"
        return (source, identifiers)
    }

    public static func parse(_ source: String, allowed: [CommandType]) -> ProgramParse {
        let normalized = source.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
        var pieces = normalized.components(separatedBy: "\n")
        if pieces.last?.isEmpty == true {
            pieces.removeLast()
        }
        let allowedSet = Set(allowed)
        var diagnostics: [ProgramDiagnostic] = []
        var lineIDs = Array<UUID?>(repeating: nil, count: pieces.count)
        var roots: [Instruction] = []
        var stack: [OpenBlock] = []

        for (offset, raw) in pieces.enumerated() {
            let lineNumber = offset + 1
            let expanded = raw.replacingOccurrences(of: "\t", with: "  ")
            if expanded.trimmingCharacters(in: .whitespaces).isEmpty {
                continue
            }
            let indent = expanded.prefix { $0 == " " }.count
            guard indent.isMultiple(of: 2) else {
                diagnostics.append(ProgramDiagnostic(line: lineNumber, message: "L'indentation doit aller de deux en deux."))
                continue
            }
            let depth = indent / 2
            while let top = stack.last, top.depth >= depth {
                let closed = stack.removeLast()
                attach(closed.instruction, to: &roots, stack: &stack)
            }
            let expected = (stack.last?.depth ?? -1) + 1
            guard depth == expected else {
                diagnostics.append(ProgramDiagnostic(line: lineNumber, message: "Cette ligne est trop enfoncée."))
                continue
            }
            switch read(line: String(expanded.drop { $0 == " " }), number: lineNumber, allowed: allowedSet) {
            case .failure(let diagnostic):
                diagnostics.append(diagnostic)
            case .success(let instruction):
                lineIDs[offset] = instruction.id
                if instruction.command.isContainer {
                    stack.append(OpenBlock(depth: depth, instruction: instruction))
                } else {
                    attach(instruction, to: &roots, stack: &stack)
                }
            }
        }
        while let closed = stack.popLast() {
            attach(closed.instruction, to: &roots, stack: &stack)
        }
        guard diagnostics.isEmpty else {
            return ProgramParse(program: nil, diagnostics: diagnostics, lineIDs: lineIDs)
        }
        return ProgramParse(program: Program(instructions: roots), diagnostics: [], lineIDs: lineIDs)
    }

    public static func completions(in source: String, cursorUTF16: Int, allowed: [CommandType]) -> TextCompletionSet {
        let utf16 = Array(source.utf16)
        let clamped = min(max(0, cursorUTF16), utf16.count)
        let cursor = String.Index(utf16Offset: clamped, in: source) ?? source.endIndex
        let lineStart = source[..<cursor].lastIndex(of: "\n").map { source.index(after: $0) } ?? source.startIndex
        let lineEnd = source[cursor...].firstIndex(of: "\n") ?? source.endIndex
        let line = source[lineStart..<lineEnd]
        let cursorInLine = source.distance(from: lineStart, to: cursor)
        let tokens = tokens(in: String(line))
        let active = tokens.last { $0.range.contains(cursorInLine) || $0.range.upperBound == cursorInLine }
        let lineLocation = source.utf16.distance(from: source.utf16.startIndex, to: lineUTF16(lineStart, in: source))
        let prefix: String
        let replacement: NSRange
        if let active {
            replacement = NSRange(location: lineLocation + active.range.lowerBound, length: active.range.count)
            let prefixEnd = min(cursorInLine, active.range.upperBound)
            let start = line.index(line.startIndex, offsetBy: active.range.lowerBound)
            let end = line.index(line.startIndex, offsetBy: prefixEnd)
            prefix = String(line[start..<end])
        } else {
            replacement = NSRange(location: clamped, length: 0)
            prefix = ""
        }
        let first = tokens.first?.text.uppercased()
        let writingCondition = first == "SI" && (active.map { tokens.first?.range != $0.range } ?? true) && !tokens.isEmpty
        let items: [TextCompletion]
        if writingCondition {
            items = ConditionType.allCases
                .filter { prefix.isEmpty || $0.rawValue.hasPrefix(prefix.uppercased()) }
                .map { .condition($0) }
        } else {
            items = allowed.filter { prefix.isEmpty || $0.rawValue.hasPrefix(prefix.uppercased()) }.map { .command($0) }
        }
        return TextCompletionSet(replacementUTF16: replacement, items: items)
    }

    /// Aligne les identifiants d'un programme déjà adopté sur les lignes d'une analyse de même forme.
    public static func adoptedLineIDs(_ lines: [UUID?], program: Program) -> [UUID?] {
        var identifiers = preorder(program)
        return lines.map { marker in
            guard marker != nil, !identifiers.isEmpty else { return nil }
            return identifiers.removeFirst()
        }
    }

    private struct OpenBlock {
        var depth: Int
        var instruction: Instruction
    }

    private struct Token {
        var text: String
        var range: Range<Int>
    }

    private enum Read {
        case success(Instruction)
        case failure(ProgramDiagnostic)
    }

    private static func attach(_ instruction: Instruction, to roots: inout [Instruction], stack: inout [OpenBlock]) {
        if stack.isEmpty {
            roots.append(instruction)
        } else {
            stack[stack.count - 1].instruction.children.append(instruction)
        }
    }

    private static func read(line: String, number: Int, allowed: Set<CommandType>) -> Read {
        let parts = line.split(whereSeparator: { $0 == " " || $0 == "\t" }).map(String.init)
        guard let first = parts.first else {
            return .failure(ProgramDiagnostic(line: number, message: "Commande inconnue."))
        }
        let word = first.uppercased()
        if word.hasPrefix("REPETE") && word != "REPETE" {
            return .failure(ProgramDiagnostic(line: number, message: "Répète n'a pas de nombre de tours."))
        }
        if word.hasPrefix("SI") && word != "SI" {
            return .failure(ProgramDiagnostic(line: number, message: "Écris SI, puis la condition."))
        }
        guard let command = CommandType.allCases.first(where: { $0.rawValue == word }) else {
            return .failure(ProgramDiagnostic(line: number, message: "Commande inconnue."))
        }
        guard allowed.contains(command) else {
            return .failure(ProgramDiagnostic(line: number, message: "Cette commande n'est pas disponible dans ce niveau."))
        }
        if command == .forever {
            guard parts.count == 1 else {
                return .failure(ProgramDiagnostic(line: number, message: "Répète n'a pas de nombre de tours."))
            }
            return .success(Instruction(command: .forever))
        }
        if command == .ifBlock {
            guard parts.count >= 2 else {
                return .failure(ProgramDiagnostic(line: number, message: "Ce Si n'a pas de condition."))
            }
            guard parts.count == 2 else {
                return .failure(ProgramDiagnostic(line: number, message: "Ce Si a trop de mots."))
            }
            let conditionWord = parts[1].uppercased()
            guard let condition = ConditionType.allCases.first(where: { $0.rawValue == conditionWord }) else {
                return .failure(ProgramDiagnostic(line: number, message: "Condition inconnue."))
            }
            return .success(Instruction(command: .ifBlock, condition: condition))
        }
        guard parts.count == 1 else {
            return .failure(ProgramDiagnostic(line: number, message: "Seule la commande Si a une condition."))
        }
        return .success(Instruction(command: command))
    }

    private static func tokens(in line: String) -> [Token] {
        var found: [Token] = []
        var index = line.startIndex
        var offset = 0
        while index < line.endIndex {
            if line[index] == " " || line[index] == "\t" {
                offset += 1
                index = line.index(after: index)
                continue
            }
            let start = index
            let startOffset = offset
            while index < line.endIndex && line[index] != " " && line[index] != "\t" {
                offset += 1
                index = line.index(after: index)
            }
            found.append(Token(text: String(line[start..<index]), range: startOffset..<offset))
        }
        return found
    }

    private static func lineUTF16(_ index: String.Index, in source: String) -> String.UTF16View.Index {
        source.utf16.index(source.utf16.startIndex, offsetBy: source.utf16.distance(from: source.startIndex, to: index))
    }

    private static func preorder(_ program: Program) -> [UUID] {
        var identifiers: [UUID] = []
        func walk(_ nodes: [Instruction]) {
            for node in nodes {
                identifiers.append(node.id)
                walk(node.children)
            }
        }
        walk(program.instructions)
        return identifiers
    }
}

private extension String.Index {
    init?(utf16Offset: Int, in string: String) {
        guard utf16Offset >= 0 else { return nil }
        let utf16 = string.utf16
        guard utf16Offset <= utf16.count else { return nil }
        let target = utf16.index(utf16.startIndex, offsetBy: utf16Offset)
        guard let index = String.Index(target, within: string) else { return nil }
        self = index
    }
}
