import Foundation

public struct StepOutcome: Equatable, Sendable {
    public var event: SimulationEvent?
    public var state: ExecutionState

    public init(event: SimulationEvent?, state: ExecutionState) {
        self.event = event
        self.state = state
    }
}

/// Interpréteur déterministe. La vitesse d'animation n'existe pas ici :
/// un pas logique produit toujours le même état.
public struct SimulationEngine: Sendable {
    public let level: Level
    public private(set) var program: Program
    public private(set) var state: ExecutionState
    public let safetyLimits: SafetyLimits
    /// Empreintes déjà rencontrées. Elles ne font pas partie de l'état comparé :
    /// les compter rendrait chaque pas unique et masquerait le cycle.
    private var seenFingerprints: Set<SimulationFingerprint> = []

    public init(level: Level, program: Program, safetyLimits: SafetyLimits = .standard) {
        self.level = level
        self.program = program
        self.safetyLimits = safetyLimits
        self.state = .ready(level: level)
    }

    /// Remplace le programme seulement au repos, pour ne jamais modifier une exécution en cours.
    @discardableResult
    public mutating func updateProgram(_ program: Program) -> Bool {
        guard state.status == .ready else { return false }
        self.program = program
        return true
    }

    public mutating func reset(program: Program? = nil) {
        if let program {
            self.program = program
        }
        state = .ready(level: level)
        seenFingerprints.removeAll()
    }

    @discardableResult
    public mutating func step() -> StepOutcome {
        guard !state.status.isTerminal else {
            return StepOutcome(event: nil, state: state)
        }

        if state.cursor.frames.isEmpty {
            state.status = .inProgress
            state.cursor.frames = [
                ExecutionCursor.Frame(containerPath: [], childIndex: 0, policy: .sequence)
            ]
        }

        switch closeFinishedFrames() {
        case .ready:
            break
        case .programFinished:
            return finishWithoutGoal()
        case .halted(let outcome):
            return outcome
        }

        guard let frame = state.cursor.frames.last else {
            return finishWithoutGoal()
        }
        let siblings = children(at: frame.containerPath)
        guard siblings.indices.contains(frame.childIndex) else {
            return finishWithoutGoal()
        }

        let instruction = siblings[frame.childIndex]
        state.activeInstructionID = instruction.id

        state.safetyStepCount += 1
        if state.safetyStepCount > safetyLimits.maxInstructionSteps {
            state.status = .safetyStopped
            state.fault = .safetyStop
            return StepOutcome(event: .safetyStopped, state: state)
        }

        if !level.allowedCommands.contains(instruction.command) {
            return fail(.commandUnavailable(command: instruction.command, instructionID: instruction.id))
        }

        let fingerprint = state.fingerprint
        if seenFingerprints.contains(fingerprint) {
            return fail(.cycle(instructionID: instruction.id))
        }
        seenFingerprints.insert(fingerprint)

        switch instruction.command {
        case .forever:
            let path = frame.containerPath + [frame.childIndex]
            state.cursor.frames.append(
                ExecutionCursor.Frame(containerPath: path, childIndex: 0, policy: .forever)
            )
            return StepOutcome(event: .enteredLoop(instruction.id), state: state)
        case .ifBlock:
            guard let condition = instruction.condition else {
                return fail(.missingCondition(instructionID: instruction.id))
            }
            state.game.metrics.tests += 1
            let passed = ConditionEvaluator.evaluate(condition, game: state.game)
            if passed {
                let path = frame.containerPath + [frame.childIndex]
                state.cursor.frames.append(
                    ExecutionCursor.Frame(containerPath: path, childIndex: 0, policy: .sequence)
                )
            } else {
                state.cursor.frames[state.cursor.frames.count - 1].childIndex += 1
                if isDrained() {
                    state.status = .exhausted
                }
            }
            return StepOutcome(
                event: .testedCondition(instructionID: instruction.id, condition: condition, passed: passed),
                state: state
            )
        case .moveForward, .moveBackward, .turnLeft, .turnRight, .pickUp, .use, .push, .activate:
            switch WorldRules.apply(command: instruction.command, to: state.game, level: level) {
            case .failure(let violation):
                return fail(fault(violation, instruction: instruction))
            case .success(let applied):
                state.game = applied.game
                state.cursor.frames[state.cursor.frames.count - 1].childIndex += 1
                if state.game.isVictory {
                    state.history.append(ExecutionRecord(
                        instructionID: instruction.id,
                        command: instruction.command,
                        event: applied.event
                    ))
                    state.status = .succeeded
                    return StepOutcome(event: applied.event, state: state)
                }
                if case .moved(let from, let to, let forward, let command) = applied.event,
                   let terrain = state.game.grid.cell(at: to)?.terrain,
                   terrain.isLethal {
                    let fault = ExecutionFault.hazard(
                        command: command,
                        instructionID: instruction.id,
                        terrain: terrain,
                        at: to
                    )
                    state.status = .failed
                    state.fault = fault
                    let event = SimulationEvent.enteredHazard(
                        from: from,
                        to: to,
                        terrain: terrain,
                        forward: forward,
                        command: command
                    )
                    state.history.append(ExecutionRecord(
                        instructionID: instruction.id,
                        command: instruction.command,
                        event: event
                    ))
                    return StepOutcome(event: event, state: state)
                }
                state.history.append(ExecutionRecord(
                    instructionID: instruction.id,
                    command: instruction.command,
                    event: applied.event
                ))
                if isDrained() {
                    state.status = .exhausted
                }
                return StepOutcome(event: applied.event, state: state)
            }
        }
    }

    private func fault(_ violation: RuleViolation, instruction: Instruction) -> ExecutionFault {
        switch violation {
        case .pathBlocked(let forward, let attempted):
            return .pathBlocked(
                command: instruction.command,
                instructionID: instruction.id,
                forward: forward,
                attempted: attempted
            )
        case .commandUnavailable(let command):
            return .commandUnavailable(command: command, instructionID: instruction.id)
        case .nothingToPickUp:
            return .nothingToPickUp(instructionID: instruction.id)
        case .nothingToUse:
            return .nothingToUse(instructionID: instruction.id)
        case .incompatibleUse:
            return .incompatibleUse(instructionID: instruction.id)
        case .nothingToPush:
            return .nothingToPush(instructionID: instruction.id)
        case .pushBlocked(let attempted):
            return .pushBlocked(instructionID: instruction.id, attempted: attempted)
        case .nothingToActivate:
            return .nothingToActivate(instructionID: instruction.id)
        }
    }

    private enum FrameClose {
        case ready
        case programFinished
        case halted(StepOutcome)
    }

    /// Ferme les blocs terminés. REPETE recommence à zéro, sans compteur.
    /// Une boucle vide est un cycle, pas une attente indéfinie.
    private mutating func closeFinishedFrames() -> FrameClose {
        var hops = 0
        while hops < 64 {
            hops += 1
            guard let frame = state.cursor.frames.last else { return .programFinished }
            let siblings = children(at: frame.containerPath)
            guard frame.childIndex >= siblings.count else { return .ready }
            if frame.policy == .forever {
                if siblings.isEmpty {
                    let identifier = instruction(at: frame.containerPath)?.id ?? frameIdentifierFallback()
                    return .halted(fail(.cycle(instructionID: identifier)))
                }
                state.cursor.frames[state.cursor.frames.count - 1].childIndex = 0
                continue
            }
            state.cursor.frames.removeLast()
            guard !state.cursor.frames.isEmpty else { return .programFinished }
            state.cursor.frames[state.cursor.frames.count - 1].childIndex += 1
        }
        state.status = .safetyStopped
        state.fault = .safetyStop
        return .halted(StepOutcome(event: .safetyStopped, state: state))
    }

    private func isDrained() -> Bool {
        var frames = state.cursor.frames
        while let frame = frames.last {
            let siblings = children(at: frame.containerPath)
            if frame.childIndex < siblings.count { return false }
            if frame.policy == .forever { return false }
            frames.removeLast()
            if frames.isEmpty { return true }
            frames[frames.count - 1].childIndex += 1
        }
        return true
    }

    private func frameIdentifierFallback() -> UUID {
        state.activeInstructionID ?? UUID()
    }

    @discardableResult
    public mutating func runUntilTerminal() -> ExecutionState {
        let ceiling = safetyLimits.maxInstructionSteps + 2
        var spins = 0
        while !state.status.isTerminal {
            _ = step()
            spins += 1
            if spins > ceiling {
                state.status = .safetyStopped
                state.fault = .safetyStop
                break
            }
        }
        return state
    }

    private func instruction(at path: [Int]) -> Instruction? {
        guard !path.isEmpty else { return nil }
        var nodes = program.instructions
        var current: Instruction?
        for index in path {
            guard nodes.indices.contains(index) else { return nil }
            current = nodes[index]
            nodes = nodes[index].children
        }
        return current
    }

    private func children(at containerPath: [Int]) -> [Instruction] {
        var nodes = program.instructions
        for index in containerPath {
            guard nodes.indices.contains(index) else { return [] }
            nodes = nodes[index].children
        }
        return nodes
    }

    private mutating func fail(_ fault: ExecutionFault) -> StepOutcome {
        state.status = .failed
        state.fault = fault
        let event = SimulationEvent.blocked(fault)
        return StepOutcome(event: event, state: state)
    }

    private mutating func finishWithoutGoal() -> StepOutcome {
        state.status = .exhausted
        state.cursor.frames.removeAll()
        return StepOutcome(event: .finishedWithoutGoal, state: state)
    }
}
