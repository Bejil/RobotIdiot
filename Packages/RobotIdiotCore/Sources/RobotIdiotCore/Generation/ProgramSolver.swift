import Foundation

/// Recherche bornée de programmes. Elle utilise le même moteur que le joueur.
///
/// L'espace séquentiel est exhaustif jusqu'à `sequentialLimit` (borné à 6).
/// Les boucles ne sont pas énumérées : un catalogue de squelettes couvre
/// REPETE et SI pour les commandes de déplacement. Au-delà, la conclusion
/// est `interrupted`, jamais une absence inventée.
public enum ProgramSolver {
    public static let maximumSequentialDepth = 6

    public static func search(
        level: Level,
        sequentialLimit: Int,
        includeLoops: Bool,
        budget: SolverBudget
    ) -> SolverResult {
        var spentPrograms = 0
        var spentSteps = 0
        let movement = level.allowedCommands.filter { CommandType.movement.contains($0) }
        let depth = min(max(0, sequentialLimit), maximumSequentialDepth)
        let capped = sequentialLimit > maximumSequentialDepth

        switch walk(
            prefix: [],
            limit: depth,
            commands: movement,
            level: level,
            spentPrograms: &spentPrograms,
            spentSteps: &spentSteps,
            budget: budget
        ) {
        case .found(let program, let metrics):
            return SolverResult(
                conclusion: .found,
                program: program,
                metrics: metrics,
                exploredPrograms: spentPrograms,
                exploredSteps: spentSteps
            )
        case .interrupted:
            return SolverResult(
                conclusion: .interrupted,
                exploredPrograms: spentPrograms,
                exploredSteps: spentSteps
            )
        case .exhausted:
            break
        }

        if includeLoops {
            for candidate in loopPrograms(level: level, movement: movement, maxBlocks: max(sequentialLimit, level.programConstraints.maxBlocks ?? sequentialLimit)) {
                if spentPrograms >= budget.maxPrograms || spentSteps >= budget.maxSteps {
                    return SolverResult(
                        conclusion: .interrupted,
                        exploredPrograms: spentPrograms,
                        exploredSteps: spentSteps
                    )
                }
                let outcome = simulate(candidate, level: level)
                spentPrograms += 1
                spentSteps += outcome.steps
                if outcome.status == .succeeded {
                    return SolverResult(
                        conclusion: .found,
                        program: candidate,
                        metrics: outcome.metrics,
                        exploredPrograms: spentPrograms,
                        exploredSteps: spentSteps
                    )
                }
            }
        }

        if capped {
            return SolverResult(
                conclusion: .interrupted,
                exploredPrograms: spentPrograms,
                exploredSteps: spentSteps
            )
        }
        return SolverResult(
            conclusion: .absent,
            exploredPrograms: spentPrograms,
            exploredSteps: spentSteps
        )
    }

    /// Vrai si une suite de déplacements peut atteindre le drapeau sans toucher aux objets.
    /// Une caisse ou une porte fermée compte comme un mur.
    public static func movementReachesFlag(_ level: Level) -> Bool {
        guard let flag = level.objectives.first(where: { $0.kind == .reachFlag })?.position else { return false }
        var seen: Set<GridCoordinate> = [level.initialRobot.position]
        var queue = [level.initialRobot.position]
        while !queue.isEmpty {
            let current = queue.removeFirst()
            if current == flag { return true }
            for direction in Direction.allCases {
                let next = current.translated(by: direction)
                guard !seen.contains(next), level.grid.cell(at: next)?.allowsSafeRobotEntry == true else { continue }
                seen.insert(next)
                queue.append(next)
            }
        }
        return false
    }

    private enum Walk {
        case found(Program, ExecutionMetrics)
        case exhausted
        case interrupted
    }

    private static func walk(
        prefix: [CommandType],
        limit: Int,
        commands: [CommandType],
        level: Level,
        spentPrograms: inout Int,
        spentSteps: inout Int,
        budget: SolverBudget
    ) -> Walk {
        if spentPrograms >= budget.maxPrograms || spentSteps >= budget.maxSteps {
            return .interrupted
        }
        let outcome = simulate(Program(instructions: prefix.map { Instruction(command: $0) }), level: level)
        spentPrograms += 1
        spentSteps += outcome.steps
        switch outcome.status {
        case .succeeded:
            return .found(
                Program(instructions: prefix.map { Instruction(command: $0) }),
                outcome.metrics
            )
        case .exhausted, .ready:
            break
        case .failed, .safetyStopped, .inProgress:
            return .exhausted
        }
        guard prefix.count < limit else { return .exhausted }
        for command in commands {
            switch walk(
                prefix: prefix + [command],
                limit: limit,
                commands: commands,
                level: level,
                spentPrograms: &spentPrograms,
                spentSteps: &spentSteps,
                budget: budget
            ) {
            case .found(let program, let metrics):
                return .found(program, metrics)
            case .interrupted:
                return .interrupted
            case .exhausted:
                continue
            }
        }
        return .exhausted
    }

    static func simulate(_ program: Program, level: Level) -> (status: ExecutionStatus, metrics: ExecutionMetrics, steps: Int) {
        var engine = SimulationEngine(
            level: level,
            program: program,
            safetyLimits: SafetyLimits(maxInstructionSteps: 400)
        )
        let final = engine.runUntilTerminal()
        return (final.status, final.game.metrics, final.safetyStepCount)
    }

    /// Squelettes REPETE / SI. L'ordre va des programmes les plus courts aux plus longs.
    static func loopPrograms(level: Level, movement: [CommandType], maxBlocks: Int) -> [Program] {
        guard level.allowedCommands.contains(.forever), level.programConstraints.maxNestingDepth >= 2 else {
            return []
        }
        var programs: [Program] = []
        var bodies: [[CommandType]] = movement.map { [$0] }
        if maxBlocks >= 3 {
            for first in movement {
                for second in movement {
                    bodies.append([first, second])
                }
            }
        }
        for body in bodies where 1 + body.count <= maxBlocks {
            programs.append(forever(body))
        }

        if level.allowedCommands.contains(.ifBlock), level.programConstraints.maxNestingDepth >= 3, maxBlocks >= 4 {
            let turns = [CommandType.turnLeft, .turnRight].filter { movement.contains($0) }
            let moves = [CommandType.moveForward, .moveBackward].filter { movement.contains($0) }
            for condition in [ConditionType.obstacleAhead, .cellAheadFree] {
                for turn in turns {
                    for move in moves where 4 <= maxBlocks {
                        programs.append(foreverIf(condition: condition, turn: turn, move: move))
                    }
                }
            }
            if level.allowedCommands.contains(.activate), maxBlocks >= 4 {
                programs.append(foreverIf(condition: .doorClosed, turn: .activate, move: .moveForward))
            }
        }
        if level.allowedCommands.contains(.push), maxBlocks >= 2 {
            programs.append(forever([.push]))
        }
        if level.allowedCommands.contains(.pickUp),
           level.allowedCommands.contains(.use),
           level.allowedCommands.contains(.ifBlock),
           level.programConstraints.maxNestingDepth >= 3,
           maxBlocks >= 6 {
            programs.append(keyLoop())
        }

        let base = programs
        let turns = [CommandType.turnLeft, .turnRight].filter { movement.contains($0) }
        for program in base {
            for turn in turns {
                for count in 1...2 where program.blockCount + count <= maxBlocks {
                    var instructions: [Instruction] = []
                    for _ in 0..<count {
                        instructions.append(Instruction(command: turn))
                    }
                    instructions.append(contentsOf: program.instructions)
                    programs.append(Program(instructions: instructions))
                }
            }
        }
        return programs.sorted { $0.blockCount < $1.blockCount }
    }

    static func forever(_ body: [CommandType]) -> Program {
        Program(instructions: [
            Instruction(command: .forever, children: body.map { Instruction(command: $0) })
        ])
    }

    static func foreverIf(condition: ConditionType, turn: CommandType, move: CommandType) -> Program {
        let check = Instruction(command: .ifBlock, condition: condition, children: [Instruction(command: turn)])
        let loop = Instruction(command: .forever, children: [check, Instruction(command: move)])
        return Program(instructions: [loop])
    }

    static func keyLoop() -> Program {
        let pick = Instruction(command: .ifBlock, condition: .objectPresent, children: [Instruction(command: .pickUp)])
        let open = Instruction(command: .ifBlock, condition: .doorClosed, children: [Instruction(command: .use)])
        let loop = Instruction(command: .forever, children: [pick, open, Instruction(command: .moveForward)])
        return Program(instructions: [loop])
    }
}
