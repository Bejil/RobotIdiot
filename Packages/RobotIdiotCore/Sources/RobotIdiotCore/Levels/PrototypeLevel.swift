import Foundation

public enum PrototypeLevel {
    /// Niveau fabriqué à la main.
    ///
    /// y augmente vers le haut. Le robot part vers l'est et doit contourner les murs.
    ///
    /// ```
    /// y5 ######
    /// y4 #F...#
    /// y3 ###..#
    /// y2 #...##
    /// y1 #R...#
    /// y0 ######
    /// ```
    public static let firstSteps: Level = {
        let grid = Grid.bordered(
            width: 6,
            height: 6,
            interiorWalls: [
                GridCoordinate(x: 1, y: 3),
                GridCoordinate(x: 2, y: 3),
                GridCoordinate(x: 4, y: 2)
            ]
        )
        return Level(
            id: "world-1-level-1",
            version: 1,
            seed: 1,
            generatorVersion: 0,
            worldNumber: 1,
            levelNumber: 1,
            difficulty: 0.15,
            theme: .laboratory,
            grid: grid,
            initialRobot: RobotState(
                position: GridCoordinate(x: 1, y: 1),
                orientation: .east
            ),
            objectives: [
                Objective(id: "flag", kind: .reachFlag, position: GridCoordinate(x: 1, y: 4))
            ],
            allowedCommands: CommandType.movement,
            programConstraints: .flat,
            scoringRules: ScoringRules(
                compactProgramMaxBlocks: 9,
                efficientExecutionMaxSteps: 9,
                referenceNote: "Solution de référence séquentielle : 9 blocs et 9 actions."
            ),
            validation: ValidationMetadata(
                status: .handcrafted,
                notes: ["Niveau d'introduction écrit à la main, vérifié par le moteur."]
            )
        )
    }()

    /// Couloir droit. Cinq cases séparent le robot du drapeau, deux blocs sont autorisés.
    ///
    /// ```
    /// y7 ###
    /// y6 #F#
    /// y5 #.#
    /// y4 #.#
    /// y3 #.#
    /// y2 #.#
    /// y1 #R#
    /// y0 ###
    /// ```
    public static let corridor: Level = {
        Level(
            id: "world-1-level-2",
            version: 1,
            seed: 2,
            generatorVersion: 0,
            worldNumber: 1,
            levelNumber: 2,
            difficulty: 0.3,
            theme: .laboratory,
            grid: Grid.bordered(width: 3, height: 8, interiorWalls: []),
            initialRobot: RobotState(
                position: GridCoordinate(x: 1, y: 1),
                orientation: .north
            ),
            objectives: [
                Objective(id: "flag", kind: .reachFlag, position: GridCoordinate(x: 1, y: 6))
            ],
            allowedCommands: CommandType.movement + [.forever],
            programConstraints: ProgramConstraints(maxBlocks: 2, maxNestingDepth: 2),
            scoringRules: ScoringRules(
                compactProgramMaxBlocks: 2,
                efficientExecutionMaxSteps: 5,
                referenceNote: "REPETE { AVANCE } : 2 blocs, 5 avances."
            ),
            validation: ValidationMetadata(
                status: .handcrafted,
                notes: ["Le plafond de 2 blocs rend la boucle nécessaire."]
            )
        )
    }()

    /// Le chemin tourne deux fois. Une boucle qui teste l'obstacle devant tient en 4 blocs.
    ///
    /// ```
    /// y5 ######
    /// y4 #F...#
    /// y3 ####.#
    /// y2 ####.#
    /// y1 #R...#
    /// y0 ######
    /// ```
    public static let corner: Level = {
        let open: Set<GridCoordinate> = [
            GridCoordinate(x: 1, y: 1), GridCoordinate(x: 2, y: 1),
            GridCoordinate(x: 3, y: 1), GridCoordinate(x: 4, y: 1),
            GridCoordinate(x: 4, y: 2), GridCoordinate(x: 4, y: 3), GridCoordinate(x: 4, y: 4),
            GridCoordinate(x: 3, y: 4), GridCoordinate(x: 2, y: 4), GridCoordinate(x: 1, y: 4)
        ]
        var walls: [GridCoordinate] = []
        for x in 1...4 {
            for y in 1...4 where !open.contains(GridCoordinate(x: x, y: y)) {
                walls.append(GridCoordinate(x: x, y: y))
            }
        }
        return Level(
            id: "world-1-level-3",
            version: 1,
            seed: 3,
            generatorVersion: 0,
            worldNumber: 1,
            levelNumber: 3,
            difficulty: 0.45,
            theme: .laboratory,
            grid: Grid.bordered(width: 6, height: 6, interiorWalls: Set(walls)),
            initialRobot: RobotState(
                position: GridCoordinate(x: 1, y: 1),
                orientation: .east
            ),
            objectives: [
                Objective(id: "flag", kind: .reachFlag, position: GridCoordinate(x: 1, y: 4))
            ],
            allowedCommands: CommandType.movement + [.forever, .ifBlock],
            programConstraints: ProgramConstraints(maxBlocks: 4, maxNestingDepth: 3),
            scoringRules: ScoringRules(
                compactProgramMaxBlocks: 4,
                efficientExecutionMaxSteps: 11,
                referenceNote: "REPETE { SI obstacle devant { TOURNE_GAUCHE } AVANCE } : 4 blocs, 11 actions."
            ),
            validation: ValidationMetadata(
                status: .handcrafted,
                notes: ["Le plafond de 4 blocs rend la boucle et le test nécessaires."]
            )
        )
    }()

    public static let playable: [Level] = [firstSteps, corridor, corner]

    public static func level(after id: String) -> Level? {
        guard let index = playable.firstIndex(where: { $0.id == id }) else { return nil }
        let next = playable.index(after: index)
        return playable.indices.contains(next) ? playable[next] : nil
    }

    public static func referenceProgram() -> Program {
        let commands: [CommandType] = [
            .moveForward, .moveForward, .turnLeft,
            .moveForward, .moveForward, .moveForward,
            .turnLeft, .moveForward, .moveForward
        ]
        return Program(instructions: commands.map { Instruction(command: $0) })
    }

    public static func corridorReferenceProgram() -> Program {
        let move = Instruction(command: .moveForward)
        let loop = Instruction(command: .forever, children: [move])
        return Program(instructions: [loop])
    }

    public static func cornerReferenceProgram() -> Program {
        let turn = Instruction(command: .turnLeft)
        let check = Instruction(command: .ifBlock, condition: .obstacleAhead, children: [turn])
        let move = Instruction(command: .moveForward)
        let loop = Instruction(command: .forever, children: [check, move])
        return Program(instructions: [loop])
    }
}
