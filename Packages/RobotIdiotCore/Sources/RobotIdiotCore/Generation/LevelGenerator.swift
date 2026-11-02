import Foundation

public enum LevelGenerator {
    public static let version = 1

    /// Alterne des niveaux accessibles et des niveaux plus exigeants.
    public static func difficulty(forSeed seed: UInt64) -> Double {
        let bands: [Double] = [0.15, 0.42, 0.58, 0.74, 0.9]
        return bands[Int(seed % UInt64(bands.count))]
    }

    public static func generate(
        _ request: GenerationRequest,
        budget: GenerationBudget = .interactive,
        cancellation: GenerationCancellation? = nil
    ) -> GeneratedLevel {
        guard request.generatorVersion == version else {
            return fallback(request, reasons: ["Version de générateur inconnue."], explored: 0)
        }

        var reasons: [String] = []
        var explored = 0
        let attempts = max(0, budget.maxAttempts)
        for attempt in 0..<attempts {
            if cancellation?.isCancelled == true {
                reasons.append("Génération annulée.")
                break
            }
            var rng = SeededGenerator(seed: mix(request, attempt: attempt))
            let profile = DifficultyModel.profile(target: request.targetDifficulty, rng: &rng)
            let family = request.family ?? profile.family
            guard let product = NavigationTemplates.make(family, rng: &rng, span: profile.maximumSpan) else {
                reasons.append("Gabarit impossible.")
                continue
            }
            let drafted = assemble(request, product: product, family: family, difficulty: profile.target)
            let verdict = validate(drafted, family: family, budget: budget.solver)
            explored += verdict.explored
            if let accepted = verdict.level {
                return GeneratedLevel(
                    level: accepted.level,
                    referenceProgram: accepted.reference,
                    validation: ValidationResult(
                        status: .accepted,
                        estimatedDifficulty: profile.target,
                        qualityScore: verdict.quality,
                        solverConclusion: verdict.conclusion,
                        exploredPrograms: explored,
                        rejectionReasons: []
                    ),
                    usedFallback: false
                )
            }
            reasons.append(contentsOf: verdict.reasons)
        }
        return fallback(request, reasons: reasons, explored: explored)
    }

    private struct Draft {
        var level: Level
        var reference: Program
    }

    private struct Verdict {
        var level: Draft?
        var reasons: [String]
        var explored: Int
        var conclusion: SolverConclusion
        var quality: Double
    }

    private static func validate(_ draft: Draft, family: PuzzleFamily, budget: SolverBudget) -> Verdict {
        let integrity = LevelIntegrity.issues(in: draft.level)
        if !integrity.isEmpty {
            return Verdict(level: nil, reasons: ["Le plateau est incohérent."], explored: 0, conclusion: .interrupted, quality: 0)
        }
        if !ProgramValidator.issues(in: draft.reference, level: draft.level).isEmpty {
            return Verdict(level: nil, reasons: ["La solution de référence est refusée."], explored: 0, conclusion: .interrupted, quality: 0)
        }

        let played = ProgramSolver.simulate(draft.reference, level: draft.level)
        guard played.status == .succeeded else {
            return Verdict(level: nil, reasons: ["La solution de référence n'atteint pas le drapeau."], explored: 1, conclusion: .interrupted, quality: 0)
        }

        var level = draft.level
        level.scoringRules = ScoringRules(
            compactProgramMaxBlocks: draft.reference.blockCount,
            efficientExecutionMaxSteps: played.metrics.executedInstructions,
            referenceNote: note(blocks: draft.reference.blockCount, actions: played.metrics.executedInstructions)
        )
        let scored = Draft(level: level, reference: draft.reference)

        if family.requiresInteraction {
            if ProgramSolver.movementReachesFlag(level) {
                return Verdict(
                    level: nil,
                    reasons: ["Le drapeau s'atteint sans interaction."],
                    explored: 1,
                    conclusion: .found,
                    quality: 0
                )
            }
            return Verdict(level: scored, reasons: [], explored: 1, conclusion: .found, quality: 1)
        }

        if family.requiresLoop {
            let limit = level.programConstraints.maxBlocks ?? 4
            let sequential = ProgramSolver.search(
                level: level,
                sequentialLimit: limit,
                includeLoops: false,
                budget: budget
            )
            if sequential.conclusion == .interrupted {
                return Verdict(level: nil, reasons: ["Le solveur n'a pas fini de vérifier la boucle."], explored: sequential.exploredPrograms + 1, conclusion: .interrupted, quality: 0)
            }
            if sequential.conclusion == .found {
                return Verdict(level: nil, reasons: ["Une suite de déplacements tient dans la limite de blocs."], explored: sequential.exploredPrograms + 1, conclusion: .found, quality: 0)
            }
            if family.requiresCondition && conditionIsOptional(level) {
                return Verdict(level: nil, reasons: ["Le drapeau s'atteint sans tester le monde."], explored: sequential.exploredPrograms + 6, conclusion: .found, quality: 0)
            }
            return Verdict(
                level: scored,
                reasons: [],
                explored: sequential.exploredPrograms + 1,
                conclusion: .absent,
                quality: 1
            )
        }

        return Verdict(level: scored, reasons: [], explored: 1, conclusion: .found, quality: 0.85)
    }

    private static func conditionIsOptional(_ level: Level) -> Bool {
        let blind: [[CommandType]] = [
            [.moveForward],
            [.turnLeft, .moveForward],
            [.moveForward, .turnLeft],
            [.turnRight, .moveForward],
            [.moveForward, .turnRight]
        ]
        return blind.contains { body in
            ProgramSolver.simulate(ProgramSolver.forever(body), level: level).status == .succeeded
        }
    }

    private static func assemble(
        _ request: GenerationRequest,
        product: TemplateProduct,
        family: PuzzleFamily,
        difficulty: Double
    ) -> Draft {
        let level = Level(
            id: identifier(request),
            version: 1,
            seed: request.seed,
            generatorVersion: version,
            worldNumber: request.worldNumber,
            levelNumber: request.levelNumber,
            difficulty: difficulty,
            theme: request.theme,
            grid: product.grid,
            initialRobot: product.robot,
            objectives: [
                Objective(id: "flag", kind: .reachFlag, position: product.flag)
            ],
            allowedCommands: product.allowed,
            programConstraints: product.constraints,
            scoringRules: ScoringRules(
                compactProgramMaxBlocks: product.reference.blockCount,
                efficientExecutionMaxSteps: nil,
                referenceNote: "Solution de référence en cours de vérification."
            ),
            validation: ValidationMetadata(
                status: .accepted,
                notes: [family.rawValue]
            )
        )
        return Draft(level: level, reference: product.reference)
    }

    private static func fallback(_ request: GenerationRequest, reasons: [String], explored: Int) -> GeneratedLevel {
        let source = fallbackSource(for: request)
        var level = source.level
        level.id = identifier(request)
        level.seed = request.seed
        level.generatorVersion = version
        level.worldNumber = request.worldNumber
        level.levelNumber = request.levelNumber
        level.difficulty = request.targetDifficulty
        level.theme = request.theme
        level.validation.notes.append("Secours déjà validé.")
        return GeneratedLevel(
            level: level,
            referenceProgram: source.program,
            validation: ValidationResult(
                status: .handcrafted,
                estimatedDifficulty: request.targetDifficulty,
                qualityScore: 0.35,
                solverConclusion: .found,
                exploredPrograms: explored,
                rejectionReasons: reasons
            ),
            usedFallback: true
        )
    }

    private static func fallbackSource(for request: GenerationRequest) -> (level: Level, program: Program) {
        switch request.family {
        case .openWalk, .obstacleWalk:
            return (PrototypeLevel.firstSteps, PrototypeLevel.referenceProgram())
        case .infiniteCorridor:
            return (PrototypeLevel.corridor, PrototypeLevel.corridorReferenceProgram())
        case .wallFollow:
            return (PrototypeLevel.corner, PrototypeLevel.cornerReferenceProgram())
        case .keyDoor, .switchDoor, .cratePush:
            return interactionFallback(request)
        case nil:
            if request.targetDifficulty < 0.34 {
                return (PrototypeLevel.firstSteps, PrototypeLevel.referenceProgram())
            }
            if request.targetDifficulty < 0.67 {
                return (PrototypeLevel.corridor, PrototypeLevel.corridorReferenceProgram())
            }
            return (PrototypeLevel.corner, PrototypeLevel.cornerReferenceProgram())
        }
    }

    private static func interactionFallback(_ request: GenerationRequest) -> (level: Level, program: Program) {
        let family = request.family ?? .keyDoor
        var rng = SeededGenerator(seed: 1)
        let product = InteractionTemplates.make(family, rng: &rng, span: 6)
        var level = Level(
            id: identifier(request),
            version: 1,
            seed: request.seed,
            generatorVersion: version,
            worldNumber: request.worldNumber,
            levelNumber: request.levelNumber,
            difficulty: request.targetDifficulty,
            theme: request.theme,
            grid: product.grid,
            initialRobot: product.robot,
            objectives: [Objective(id: "flag", kind: .reachFlag, position: product.flag)],
            allowedCommands: product.allowed,
            programConstraints: product.constraints,
            scoringRules: ScoringRules(
                compactProgramMaxBlocks: product.reference.blockCount,
                efficientExecutionMaxSteps: nil,
                referenceNote: "Solution de référence en cours de vérification."
            ),
            validation: ValidationMetadata(status: .handcrafted, notes: [family.rawValue])
        )
        let played = ProgramSolver.simulate(product.reference, level: level)
        level.scoringRules = ScoringRules(
            compactProgramMaxBlocks: product.reference.blockCount,
            efficientExecutionMaxSteps: played.metrics.executedInstructions,
            referenceNote: note(blocks: product.reference.blockCount, actions: played.metrics.executedInstructions)
        )
        return (level, product.reference)
    }

    private static func identifier(_ request: GenerationRequest) -> String {
        "gen-v\(version)-s\(request.seed)-w\(request.worldNumber)-l\(request.levelNumber)"
    }

    private static func note(blocks: Int, actions: Int) -> String {
        let blockText = blocks <= 1 ? "\(blocks) bloc" : "\(blocks) blocs"
        let actionText = actions <= 1 ? "\(actions) action" : "\(actions) actions"
        return "Solution de référence vérifiée : \(blockText) et \(actionText)."
    }

    private static func mix(_ request: GenerationRequest, attempt: Int) -> UInt64 {
        var mixed = request.seed &+ 0x9E3779B97F4A7C15
        mixed ^= UInt64(request.generatorVersion) &* 0xBF58476D1CE4E5B9
        mixed &+= UInt64(bitPattern: Int64(request.worldNumber)) &* 0x94D049BB133111EB
        mixed &+= UInt64(bitPattern: Int64(request.levelNumber)) &* 0xD1B54A32D192ED03
        mixed &+= UInt64(attempt) &* 0x9E3779B97F4A7C15
        return mixed == 0 ? 1 : mixed
    }
}
