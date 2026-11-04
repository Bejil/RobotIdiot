import SpriteKit
import RobotIdiotCore
import UIKit

/// Le bord du plateau est la seule limite invisible. Les cases ajoutées pour remplir le 7×7 sont du sol.
enum LevelFraming {
    static func playfield(_ level: Level) -> Level {
        let grid = level.grid
        guard grid.width > 1, grid.height > 1 else { return level }
        var minX = 0
        var maxX = grid.width - 1
        var minY = 0
        var maxY = grid.height - 1
        func columnIsWall(_ x: Int) -> Bool {
            (0..<grid.height).allSatisfy { grid.cell(at: GridCoordinate(x: x, y: $0))?.terrain == .wall }
        }
        func rowIsWall(_ y: Int) -> Bool {
            (0..<grid.width).allSatisfy { grid.cell(at: GridCoordinate(x: $0, y: y))?.terrain == .wall }
        }
        if columnIsWall(minX) { minX += 1 }
        if maxX > minX, columnIsWall(maxX) { maxX -= 1 }
        if rowIsWall(minY) { minY += 1 }
        if maxY > minY, rowIsWall(maxY) { maxY -= 1 }
        let fieldWidth = maxX - minX + 1
        let fieldHeight = maxY - minY + 1
        let span = max(7, fieldWidth, fieldHeight)
        let shiftX = (span - fieldWidth) / 2 - minX
        let shiftY = (span - fieldHeight) / 2 - minY

        var cells: [Cell] = []
        cells.reserveCapacity(span * span)
        for y in 0..<span {
            for x in 0..<span {
                let source = GridCoordinate(x: x - shiftX, y: y - shiftY)
                let inside = source.x >= minX && source.x <= maxX && source.y >= minY && source.y <= maxY
                if inside, var cell = grid.cell(at: source) {
                    cell.coordinate = GridCoordinate(x: x, y: y)
                    cells.append(cell)
                } else {
                    cells.append(Cell(coordinate: GridCoordinate(x: x, y: y), terrain: .floor))
                }
            }
        }

        var framed = level
        framed.grid = Grid(width: span, height: span, cells: cells)
        framed.initialRobot.position = GridCoordinate(
            x: level.initialRobot.position.x + shiftX,
            y: level.initialRobot.position.y + shiftY
        )
        framed.objectives = level.objectives.map { objective in
            var moved = objective
            moved.position = GridCoordinate(x: objective.position.x + shiftX, y: objective.position.y + shiftY)
            return moved
        }
        return framed
    }
}

/// Plateau strictement vu du dessus. Les animations ne modifient jamais la simulation :
/// elles illustrent un état déjà calculé.
final class BoardScene: SKScene {
    private let level: Level
    private var presented: GameState
    private var cellSize: CGFloat = 32
    private var origin: CGPoint = .zero
    private var columnShift = 0
    private var rowShift = 0
    private var displaySpan = 7
    private var robotNode = SKNode()
    private var robotSprite = SKSpriteNode()
    private var robotShadow = SKSpriteNode()
    private var goalTileNode: SKSpriteNode?
    private var didPrepare = false
    private var playbackCompletion: (() -> Void)?

    private var artTextures: [String: SKTexture] = [:]

    private func textured(_ piece: GameArt.BoardPiece, side: CGFloat) -> SKSpriteNode {
        let key = "\(level.worldNumber)-\(piece.rawValue)"
        let texture: SKTexture
        if let cached = artTextures[key] {
            texture = cached
        } else {
            let made = SKTexture(image: GameArt.piece(piece, world: level.worldNumber))
            artTextures[key] = made
            texture = made
        }
        let sprite = SKSpriteNode(texture: texture)
        sprite.size = CGSize(width: side, height: side)
        return sprite
    }

    /// La bordure de murs n'est pas une tuile : le bord du 7×7 est la seule limite.
    /// Les niveaux du pack gardent chaque mur dessiné à sa place.
    private func playfield() -> (minX: Int, maxX: Int, minY: Int, maxY: Int) {
        let grid = level.grid
        if level.id.hasPrefix("RI-") {
            return (0, max(grid.width - 1, 0), 0, max(grid.height - 1, 0))
        }
        var minX = 0
        var maxX = max(grid.width - 1, 0)
        var minY = 0
        var maxY = max(grid.height - 1, 0)
        func columnIsWall(_ x: Int) -> Bool {
            (0..<grid.height).allSatisfy { grid.cell(at: GridCoordinate(x: x, y: $0))?.terrain == .wall }
        }
        func rowIsWall(_ y: Int) -> Bool {
            (0..<grid.width).allSatisfy { grid.cell(at: GridCoordinate(x: $0, y: y))?.terrain == .wall }
        }
        if maxX > minX, columnIsWall(minX) { minX += 1 }
        if maxX > minX, columnIsWall(maxX) { maxX -= 1 }
        if maxY > minY, rowIsWall(minY) { minY += 1 }
        if maxY > minY, rowIsWall(maxY) { maxY -= 1 }
        return (minX, maxX, minY, maxY)
    }

    private var tileSpan: CGFloat { cellSize * 0.96 }

    private func paintCornerBushes() {
        let last = displaySpan - 1
        guard last > 0 else { return }
        for (x, y) in [(0, 0), (last, 0), (0, last), (last, last)] {
            let logical = GridCoordinate(x: x - columnShift, y: y - rowShift)
            guard presented.grid.cell(at: logical)?.terrain == .floor else { continue }
            let spot = displayCenter(x: x, y: y)
            let bush = textured(.bush, side: tileSpan)
            bush.position = spot
            bush.zPosition = 0.35
            addChild(bush)
            attachLifeParticles(for: .bush, at: spot)
        }
    }
    private let palette: BoardPalette
    private let contrast: Bool

    init(level: Level, contrast: Bool = false) {
        self.level = level
        self.contrast = contrast
        self.presented = GameState.initial(from: level)
        let prepared = BoardPalette.make(level.theme)
        self.palette = contrast ? prepared.contrasted() : prepared
        super.init(size: CGSize(width: 320, height: 320))
        backgroundColor = UIColor(hex: 0x3EAE4C)
        scaleMode = .resizeFill
        anchorPoint = .zero
        didPrepare = true
    }

    required init?(coder: NSCoder) {
        nil
    }

    func show(_ game: GameState) {
        let boardReady = children.contains(where: {
            $0.name?.hasPrefix("ground-") == true || $0.name == "goal-ground"
        })
        let sameRobot = presented.robot.position == game.robot.position
            && presented.robot.orientation == game.robot.orientation
        let idleRunning = robotSprite.action(forKey: "idle") != nil
        // Mise à jour au repos sans bouger le robot : garder l'idle en cours.
        if boardReady, playbackCompletion == nil, sameRobot, idleRunning {
            presented = game
            syncProps(to: presented)
            return
        }

        cancelPlayback()
        presented = game
        // Ne pas reconstruire le plateau à chaque édition de programme :
        // ça réinitialiserait les particules d'ambiance.
        if boardReady {
            restoreGoalAppearance()
            placeRobot(presented.robot)
            syncProps(to: presented)
            if playbackCompletion == nil {
                startIdle()
            }
            return
        }
        rebuild()
    }

    func play(
        event: SimulationEvent?,
        resulting: GameState,
        tempo: PlaybackTempo,
        reduceMotion: Bool,
        completion: @escaping () -> Void
    ) {
        cancelPlayback()
        presented = resulting
        playbackCompletion = completion

        let victory = resulting.isVictory
        switch event {
        case .moved(_, let destination, _, _):
            let collected = collectBonusNodes(missingFrom: resulting)
            slideRobot(to: destination, tempo: tempo, reduceMotion: reduceMotion, victory: victory)
            animateBonusCollection(collected, tempo: tempo, reduceMotion: reduceMotion)
        case .enteredHazard(_, let destination, let terrain, _, _):
            fallIntoHazard(at: destination, terrain: terrain, tempo: tempo, reduceMotion: reduceMotion)
        case .turned:
            applyFacing(presented.robot.orientation)
            let duration = tempo.turnDuration(reduceMotion: reduceMotion)
            let hop = SKAction.sequence([
                .moveBy(x: 0, y: cellSize * 0.12, duration: duration * 0.45),
                .moveBy(x: 0, y: -cellSize * 0.12, duration: duration * 0.55)
            ])
            let nod = SKAction.sequence([
                .scale(to: 1.08, duration: duration * 0.45),
                .scale(to: 1, duration: duration * 0.55)
            ])
            let motion: SKAction = reduceMotion ? .wait(forDuration: duration) : .group([hop, nod])
            robotNode.run(motion) { [weak self] in
                self?.endStep(victory: victory, reduceMotion: reduceMotion)
            }
        case .pickedUp(let item, _):
            fadeProp(named: "prop-\(item.id)", tempo: tempo, reduceMotion: reduceMotion, victory: victory)
        case .collectedBonus:
            let collected = collectBonusNodes(missingFrom: resulting)
            animateBonusCollection(collected, tempo: tempo, reduceMotion: reduceMotion)
            dwell(reduceMotion: reduceMotion, tempo: tempo, victory: victory)
        case .used(_, let coordinate):
            syncProps(to: presented)
            pulseMechanisms(at: coordinate)
            dwell(reduceMotion: reduceMotion, tempo: tempo, victory: victory)
        case .activated(let mechanismID, _, _):
            syncProps(to: presented)
            pulseNode(named: "mech-\(mechanismID)")
            dwell(reduceMotion: reduceMotion, tempo: tempo, victory: victory)
        case .pushed(let objectID, let from, let to):
            if let crate = childNode(withName: "prop-\(objectID)") {
                crate.run(SKAction.move(to: center(of: to), duration: tempo.moveDuration(reduceMotion: reduceMotion)))
            }
            slideRobot(to: from, tempo: tempo, reduceMotion: reduceMotion, victory: victory)
        case .enteredLoop, .testedCondition:
            dwell(reduceMotion: reduceMotion, tempo: tempo, victory: victory)
        case .blocked(let fault):
            shake(fault: fault, reduceMotion: reduceMotion)
        case .succeeded:
            endStep(victory: true, reduceMotion: reduceMotion)
        case .finishedWithoutGoal, .safetyStopped, nil:
            finishPlayback()
        }
    }

    func cancelPlayback() {
        robotNode.removeAllActions()
        robotSprite.removeAllActions()
        robotShadow.removeAllActions()
        resetRobotPose()
        goalTileNode?.removeAllActions()
        childNode(withName: "effect")?.removeFromParent()
        enumerateChildNodes(withName: "effect") { node, _ in
            node.removeFromParent()
        }
        playbackCompletion = nil
        if didPrepare {
            placeRobot(presented.robot)
            syncProps(to: presented)
        }
    }

    private func resetRobotPose() {
        robotNode.setScale(1)
        robotNode.alpha = 1
        robotNode.zRotation = 0
        robotSprite.setScale(1)
        robotSprite.alpha = 1
        robotSprite.zRotation = 0
        robotSprite.position = .zero
        robotShadow.removeAction(forKey: "idle")
        robotShadow.setScale(1)
        robotShadow.alpha = 1
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        guard didPrepare, size.width > 2, size.height > 2 else { return }
        let wasPlaying = playbackCompletion != nil
        rebuild()
        if wasPlaying {
            finishPlayback()
        }
    }

    private func rebuild() {
        removeAllChildren()
        artTextures.removeAll()
        goalTileNode = nil
        guard size.width > 2, size.height > 2, level.grid.width > 0, level.grid.height > 0 else { return }

        let field = playfield()
        let fieldWidth = field.maxX - field.minX + 1
        let fieldHeight = field.maxY - field.minY + 1
        displaySpan = max(7, fieldWidth, fieldHeight)
        columnShift = (displaySpan - fieldWidth) / 2 - field.minX
        rowShift = (displaySpan - fieldHeight) / 2 - field.minY
        let margin: CGFloat = 10
        cellSize = floor(min(size.width - margin * 2, size.height - margin * 2) / CGFloat(displaySpan))
        guard cellSize > 4 else { return }
        let boardSide = cellSize * CGFloat(displaySpan)
        origin = CGPoint(x: (size.width - boardSide) / 2, y: (size.height - boardSide) / 2)

        for y in 0..<displaySpan {
            for x in 0..<displaySpan {
                let logical = GridCoordinate(x: x - columnShift, y: y - rowShift)
                let inside = logical.x >= field.minX && logical.x <= field.maxX
                    && logical.y >= field.minY && logical.y <= field.maxY
                let terrain = inside ? presented.grid.cell(at: logical)?.terrain : nil
                let isGoal = inside && level.objectives.contains {
                    $0.kind == .reachFlag && $0.position == logical
                }
                let piece: GameArt.BoardPiece = isGoal ? .goal : groundPiece(terrain)
                let tile = textured(piece, side: tileSpan)
                let spot = displayCenter(x: x, y: y)
                tile.name = isGoal ? "goal-ground" : "ground-\(x)-\(y)"
                tile.position = spot
                tile.zPosition = terrain?.blocksMovement == true ? 0.4 : 0
                addChild(tile)
                if isGoal {
                    goalTileNode = tile
                    attachGoalShine(at: spot)
                } else if let terrain {
                    attachLifeParticles(for: terrain, at: spot)
                }
            }
        }
        if !level.id.hasPrefix("RI-") {
            paintCornerBushes()
        }

        for cell in presented.grid.cells {
            for object in cell.objects {
                addChild(makeObject(object, at: cell.coordinate))
            }
            for mechanism in cell.mechanisms {
                addChild(makeMechanism(mechanism, at: cell.coordinate))
            }
        }
        for bonus in presented.remainingCollectibles {
            addChild(makeBonus(bonus))
        }

        robotNode = makeRobot()
        robotNode.zPosition = 3
        addChild(robotNode)
        placeRobot(presented.robot)
        if playbackCompletion == nil {
            startIdle()
        }
    }

    private func groundPiece(_ terrain: TerrainType?) -> GameArt.BoardPiece {
        switch terrain {
        case .floor, .none:
            return .grassA
        case .bush:
            return .bush
        case .cracked:
            return .cracked
        case .lava:
            return .lava
        case .shutter:
            return .shutter
        case .spikes:
            return .spikes
        case .water:
            return .water
        case .wall:
            return .stone
        case .stone:
            return .slab
        }
    }

    private func fill(for cell: Cell) -> UIColor {
        if cell.terrain == .wall { return palette.wall }
        let isGoal = level.objectives.contains { $0.kind == .reachFlag && $0.position == cell.coordinate }
        if isGoal { return palette.goal }
        return (cell.coordinate.x + cell.coordinate.y).isMultiple(of: 2) ? palette.floorA : palette.floorB
    }

    private func tilePath() -> CGPath {
        let inset = cellSize * 0.07
        let side = cellSize - inset * 2
        let rect = CGRect(x: -side / 2, y: -side / 2, width: side, height: side)
        return UIBezierPath(roundedRect: rect, cornerRadius: cellSize * 0.18).cgPath
    }

    private func displayCenter(x: Int, y: Int) -> CGPoint {
        CGPoint(
            x: origin.x + (CGFloat(x) + 0.5) * cellSize,
            y: origin.y + (CGFloat(y) + 0.5) * cellSize
        )
    }

    private func center(of coordinate: GridCoordinate) -> CGPoint {
        displayCenter(x: coordinate.x + columnShift, y: coordinate.y + rowShift)
    }

    private func robotAnchor(of coordinate: GridCoordinate) -> CGPoint {
        let point = center(of: coordinate)
        // Pied du sprite (anchor bas) posé sur la case.
        return CGPoint(x: point.x, y: point.y - cellSize * 0.22)
    }

    private func facingImage(for direction: Direction) -> UIImage {
        let name: String
        switch direction {
        case .east: name = "RobotRight"
        case .west: name = "RobotLeft"
        case .north: name = "RobotBack"
        case .south: name = "BoardMascot"
        }
        return UIImage(named: name) ?? UIImage(named: "BoardMascot") ?? GameArt.piece(.hero)
    }

    private func applyFacing(_ direction: Direction) {
        robotSprite.texture = SKTexture(image: facingImage(for: direction))
        robotNode.zRotation = 0
        robotSprite.zRotation = 0
    }

    private func makeRobot() -> SKNode {
        let node = SKNode()
        robotShadow = SKSpriteNode(texture: Self.robotShadowTexture)
        robotShadow.size = CGSize(width: cellSize * 0.92, height: cellSize * 0.4)
        robotShadow.position = CGPoint(x: 0, y: cellSize * 0.05)
        robotShadow.zPosition = 0
        robotShadow.alpha = 1
        robotShadow.name = "robot-shadow"
        node.addChild(robotShadow)

        robotSprite = SKSpriteNode(texture: SKTexture(image: facingImage(for: presented.robot.orientation)))
        let side = cellSize * 0.92
        robotSprite.size = CGSize(width: side, height: side)
        robotSprite.anchorPoint = CGPoint(x: 0.5, y: 0)
        robotSprite.position = .zero
        robotSprite.zPosition = 1
        node.addChild(robotSprite)
        return node
    }

    private func placeRobot(_ robot: RobotState) {
        robotNode.position = robotAnchor(of: robot.position)
        applyFacing(robot.orientation)
    }

    private func dwell(reduceMotion: Bool, tempo: PlaybackTempo, victory: Bool = false) {
        let duration: TimeInterval = reduceMotion ? 0.01 : (tempo == .fast ? 0.05 : 0.12)
        robotNode.run(SKAction.wait(forDuration: duration)) { [weak self] in
            self?.endStep(victory: victory, reduceMotion: reduceMotion)
        }
    }

    private func endStep(victory: Bool, reduceMotion: Bool) {
        if victory {
            celebrate(reduceMotion: reduceMotion)
        } else {
            finishPlayback()
        }
    }

    private func restoreGoalAppearance() {
        goalTileNode?.removeAllActions()
        goalTileNode?.alpha = 1
        goalTileNode?.setScale(1)
        if goalTileNode == nil || goalTileNode?.parent == nil {
            goalTileNode = childNode(withName: "goal-ground") as? SKSpriteNode
            goalTileNode?.alpha = 1
            goalTileNode?.setScale(1)
        }
    }

    private func shake(fault: ExecutionFault, reduceMotion: Bool) {
        if case .pathBlocked(_, _, _, let attempted) = fault {
            flash(at: attempted)
            Soundscape.shared.playObstacleHit()
        }
        if case .pushBlocked(_, let attempted) = fault {
            flash(at: attempted)
            Soundscape.shared.playObstacleHit()
        }
        // Reste sur la case d'origine : le mur / buisson bloque sans y entrer.
        let home = robotAnchor(of: presented.robot.position)
        robotNode.position = home
        let wash = SKSpriteNode(color: AppTheme.coral.withAlphaComponent(0.28), size: size)
        wash.position = CGPoint(x: size.width / 2, y: size.height / 2)
        wash.zPosition = 8
        wash.name = "effect"
        addChild(wash)
        wash.run(.sequence([.fadeOut(withDuration: 0.28), .removeFromParent()]))
        guard !reduceMotion else {
            finishPlayback()
            return
        }
        let shake = SKAction.sequence([
            .moveBy(x: 7, y: 0, duration: 0.05),
            .moveBy(x: -14, y: 0, duration: 0.06),
            .moveBy(x: 12, y: 0, duration: 0.06),
            .moveBy(x: -8, y: 0, duration: 0.05),
            .move(to: home, duration: 0.05)
        ])
        robotNode.run(shake) { [weak self] in
            self?.finishPlayback()
        }
    }

    private func fallIntoHazard(
        at destination: GridCoordinate,
        terrain: TerrainType,
        tempo: PlaybackTempo,
        reduceMotion: Bool
    ) {
        let target = robotAnchor(of: destination)
        let moveDuration = tempo.moveDuration(reduceMotion: reduceMotion)
        flash(at: destination)
        let arrive = SKAction.move(to: target, duration: moveDuration)
        let impact = SKAction.run {
            Soundscape.shared.playHazardHit(terrain)
        }
        let sink: SKAction
        if reduceMotion {
            sink = .group([.fadeOut(withDuration: 0.01), .scale(to: 0.01, duration: 0.01)])
        } else if terrain == .spikes {
            sink = .sequence([
                .group([
                    .scale(to: 1.12, duration: 0.08),
                    .rotate(byAngle: 0.18, duration: 0.08)
                ]),
                .group([
                    .scale(to: 0.2, duration: 0.22),
                    .fadeOut(withDuration: 0.22),
                    .moveBy(x: 0, y: -cellSize * 0.08, duration: 0.22)
                ])
            ])
        } else if terrain == .water || terrain == .lava {
            // Face vers le bas, puis tourne en diminuant jusqu'à disparaître.
            sink = .sequence([
                .run { [weak self] in
                    self?.applyFacing(.south)
                },
                .wait(forDuration: 0.04),
                .group([
                    .rotate(byAngle: .pi * 2.4, duration: 0.55),
                    .scale(to: 0.08, duration: 0.55),
                    .fadeOut(withDuration: 0.55),
                    .moveBy(x: 0, y: -cellSize * 0.22, duration: 0.55)
                ])
            ])
        } else {
            sink = .group([
                .scale(to: 0.15, duration: 0.35),
                .fadeOut(withDuration: 0.35)
            ])
        }
        robotNode.run(.sequence([arrive, impact, sink])) { [weak self] in
            self?.resetRobotPose()
            self?.finishPlayback()
        }
    }

    private func flash(at coordinate: GridCoordinate) {
        let marker = SKShapeNode(path: tilePath())
        marker.fillColor = AppTheme.coral.withAlphaComponent(0.45)
        marker.strokeColor = AppTheme.coral
        marker.lineWidth = 3
        marker.position = center(of: coordinate)
        marker.zPosition = 1
        marker.name = "effect"
        addChild(marker)
        marker.run(SKAction.sequence([
            .fadeOut(withDuration: 0.45),
            .removeFromParent()
        ]))
    }

    private func celebrate(reduceMotion: Bool) {
        // De face (sud) sur la borne de recharge.
        applyFacing(.south)
        goalTileNode?.removeAllActions()
        robotNode.removeAction(forKey: "idle")
        robotSprite.removeAction(forKey: "idle")
        robotShadow.removeAction(forKey: "idle")
        resetRobotPose()
        Soundscape.shared.play("success")

        guard !reduceMotion else {
            finishPlayback()
            return
        }

        goalTileNode?.run(.sequence([
            .group([
                .scale(to: 1.1, duration: 0.14),
                .fadeAlpha(to: 0.88, duration: 0.14)
            ]),
            .group([
                .scale(to: 1.0, duration: 0.2),
                .fadeAlpha(to: 1.0, duration: 0.2)
            ])
        ]))

        let hop = SKAction.sequence([
            .moveBy(x: 0, y: cellSize * 0.24, duration: 0.13),
            .moveBy(x: 0, y: -cellSize * 0.24, duration: 0.13)
        ])
        let squash = SKAction.sequence([
            .scaleX(to: 1.18, y: 0.86, duration: 0.1),
            .scaleX(to: 0.9, y: 1.14, duration: 0.1),
            .scaleX(to: 1.08, y: 0.96, duration: 0.08),
            .scaleX(to: 1, y: 1, duration: 0.1)
        ])
        let wiggle = SKAction.sequence([
            .rotate(byAngle: 0.12, duration: 0.08),
            .rotate(byAngle: -0.24, duration: 0.1),
            .rotate(byAngle: 0.12, duration: 0.08)
        ])

        let radius = cellSize * 1.2
        let burstOrigin = CGPoint(
            x: robotNode.position.x,
            y: robotNode.position.y + cellSize * 0.42
        )
        for index in 0..<18 {
            let dot = SKShapeNode(circleOfRadius: cellSize * (index.isMultiple(of: 2) ? 0.075 : 0.05))
            let colors = [AppTheme.gold, AppTheme.coral, AppTheme.teal, AppTheme.success, AppTheme.move]
            dot.fillColor = colors[index % colors.count]
            dot.strokeColor = .clear
            dot.position = burstOrigin
            dot.zPosition = 5
            dot.name = "effect"
            addChild(dot)
            let angle = CGFloat(index) / 18 * .pi * 2
            let distance = radius * (index.isMultiple(of: 2) ? 1 : 0.7)
            let destination = CGPoint(
                x: burstOrigin.x + cos(angle) * distance,
                y: burstOrigin.y + sin(angle) * distance
            )
            dot.run(SKAction.sequence([
                .group([
                    .move(to: destination, duration: 0.55),
                    .rotate(byAngle: .pi, duration: 0.55),
                    .fadeOut(withDuration: 0.55),
                    .scale(to: 0.2, duration: 0.55)
                ]),
                .removeFromParent()
            ]))
        }

        robotNode.run(.sequence([
            .group([.repeat(hop, count: 2), squash, wiggle]),
            .wait(forDuration: 0.28)
        ])) { [weak self] in
            self?.resetRobotPose()
            self?.finishPlayback()
        }
    }

    private func slideRobot(to destination: GridCoordinate, tempo: PlaybackTempo, reduceMotion: Bool, victory: Bool) {
        let duration = tempo.moveDuration(reduceMotion: reduceMotion)
        let move = SKAction.move(to: robotAnchor(of: destination), duration: duration)
        move.timingMode = .easeInEaseOut
        let squash = SKAction.sequence([
            .scaleX(to: 1.12, y: 0.9, duration: duration * 0.22),
            .scaleX(to: 0.94, y: 1.08, duration: duration * 0.28),
            .scaleX(to: 1, y: 1, duration: duration * 0.3)
        ])
        let motion: SKAction = reduceMotion ? move : .group([move, squash])
        robotNode.run(motion) { [weak self] in
            self?.endStep(victory: victory, reduceMotion: reduceMotion)
        }
    }

    private func fadeProp(named name: String, tempo: PlaybackTempo, reduceMotion: Bool, victory: Bool = false) {
        let duration = reduceMotion ? 0.01 : tempo.moveDuration(reduceMotion: false) * 0.7
        if let node = childNode(withName: name) {
            node.run(SKAction.sequence([
                .fadeOut(withDuration: duration),
                .removeFromParent()
            ]))
        }
        let hop = SKAction.sequence([
            .scale(to: 1.08, duration: duration * 0.45),
            .scale(to: 1, duration: duration * 0.55)
        ])
        robotNode.run(hop) { [weak self] in
            self?.endStep(victory: victory, reduceMotion: reduceMotion)
        }
    }

    private func syncProps(to game: GameState) {
        var seen = Set<String>()
        for cell in game.grid.cells {
            for object in cell.objects {
                let name = "prop-\(object.id)"
                seen.insert(name)
                if let node = childNode(withName: name) {
                    node.position = center(of: cell.coordinate)
                    node.alpha = 1
                } else {
                    addChild(makeObject(object, at: cell.coordinate))
                }
            }
            for mechanism in cell.mechanisms {
                let name = "mech-\(mechanism.id)"
                seen.insert(name)
                childNode(withName: name)?.removeFromParent()
                addChild(makeMechanism(mechanism, at: cell.coordinate))
            }
        }
        for bonus in game.remainingCollectibles {
            let name = "bonus-\(bonus.id)"
            seen.insert(name)
            if childNode(withName: name) == nil {
                addChild(makeBonus(bonus))
            }
        }
        var stale: [SKNode] = []
        enumerateChildNodes(withName: "*") { node, _ in
            guard let name = node.name else { return }
            if (name.hasPrefix("prop-") || name.hasPrefix("mech-") || name.hasPrefix("bonus-")),
               !seen.contains(name) {
                stale.append(node)
            }
        }
        stale.forEach { $0.removeFromParent() }
    }

    private func makeBonus(_ bonus: LevelCollectible) -> SKNode {
        let node = SKNode()
        node.name = "bonus-\(bonus.id)"
        node.position = center(of: bonus.position)
        node.zPosition = 1.55
        let sprite = textured(.bolt, side: tileSpan * 0.78)
        sprite.name = "bolt-sprite"
        sprite.zPosition = 1
        if !PlaySettings.prefersReducedMotion {
            let sparkles = makeBonusShineEmitter()
            sparkles.name = "bonus-shine"
            sparkles.zPosition = -0.1
            node.addChild(sparkles)
            let bob = SKAction.sequence([
                .moveBy(x: 0, y: cellSize * 0.06, duration: 0.55),
                .moveBy(x: 0, y: -cellSize * 0.06, duration: 0.55)
            ])
            sprite.run(.repeatForever(bob), withKey: "bob")
            let glow = SKAction.sequence([
                .fadeAlpha(to: 0.88, duration: 0.7),
                .fadeAlpha(to: 1, duration: 0.7)
            ])
            sprite.run(.repeatForever(glow), withKey: "shine")
        }
        node.addChild(sprite)
        return node
    }

    private func makeBonusShineEmitter() -> SKEmitterNode {
        let factor = particleSizeFactor
        let emitter = SKEmitterNode()
        emitter.particleTexture = Self.haloTexture
        emitter.particleBlendMode = .add
        emitter.particleBirthRate = 4.5
        emitter.particleLifetime = 1.15
        emitter.particleLifetimeRange = 0.2
        emitter.particleSpeed = cellSize * 0.015
        emitter.particleSpeedRange = cellSize * 0.01
        emitter.emissionAngle = 0
        emitter.emissionAngleRange = .pi * 2
        emitter.particlePositionRange = CGVector(dx: tileSpan * 0.06, dy: tileSpan * 0.06)
        emitter.yAcceleration = 0
        emitter.particleScale = 1.15 * factor
        emitter.particleScaleRange = emitter.particleScale * 0.2
        emitter.particleScaleSequence = particleScaleSequence([0.55, 1.15, 1.55], times: [0, 0.45, 1])
        emitter.particleColorBlendFactor = 1
        let gold = UIColor(red: 1, green: 0.88, blue: 0.4, alpha: 1)
        let soft = UIColor(red: 1, green: 0.72, blue: 0.22, alpha: 1)
        emitter.particleColorSequence = SKKeyframeSequence(
            keyframeValues: [gold, soft],
            times: [0, 1]
        )
        emitter.particleAlphaSequence = SKKeyframeSequence(
            keyframeValues: [0, 0.55, 0.28, 0],
            times: [0, 0.2, 0.65, 1]
        )
        emitter.userData = NSMutableDictionary(dictionary: ["birthRate": emitter.particleBirthRate])
        return emitter
    }

    private func collectBonusNodes(missingFrom game: GameState) -> [SKNode] {
        let remaining = Set(game.remainingCollectibles.map(\.id))
        var collected: [SKNode] = []
        enumerateChildNodes(withName: "bonus-*") { node, _ in
            guard let name = node.name, name.hasPrefix("bonus-") else { return }
            let id = String(name.dropFirst("bonus-".count))
            if !remaining.contains(id) {
                collected.append(node)
            }
        }
        return collected
    }

    private func animateBonusCollection(_ nodes: [SKNode], tempo: PlaybackTempo, reduceMotion: Bool) {
        guard !nodes.isEmpty else { return }
        let duration = reduceMotion ? 0.05 : max(0.28, tempo.moveDuration(reduceMotion: false) * 0.85)
        for node in nodes {
            node.zPosition = 4
            node.removeAllActions()
            node.enumerateChildNodes(withName: "bonus-shine") { child, _ in
                if let emitter = child as? SKEmitterNode {
                    emitter.particleBirthRate = 28
                    emitter.particleLifetime = 0.45
                }
            }
            if reduceMotion {
                node.removeFromParent()
                continue
            }
            let pop = SKAction.group([
                .sequence([
                    .scale(to: 1.35, duration: duration * 0.35),
                    .scale(to: 0.1, duration: duration * 0.65)
                ]),
                .moveBy(x: 0, y: cellSize * 0.55, duration: duration),
                .fadeOut(withDuration: duration)
            ])
            node.run(.sequence([pop, .removeFromParent()]))
        }
        Soundscape.shared.play("success")
    }

    private func makeObject(_ object: PlacedObject, at coordinate: GridCoordinate) -> SKNode {
        let node = SKNode()
        node.name = "prop-\(object.id)"
        node.position = center(of: coordinate)
        node.zPosition = 1.4
        if object.kind == ObjectKind.crate {
            node.addChild(textured(.crate, side: tileSpan))
        } else {
            node.addChild(textured(.key, side: tileSpan))
        }
        return node
    }

    private func makeMechanism(_ mechanism: PlacedMechanism, at coordinate: GridCoordinate) -> SKNode {
        let node = SKNode()
        node.name = "mech-\(mechanism.id)"
        node.position = center(of: coordinate)
        node.zPosition = mechanism.kind == MechanismKind.door ? 1.2 : 1.3
        if mechanism.kind == MechanismKind.door {
            if !mechanism.isActive {
                let closed: GameArt.BoardPiece = mechanism.link == nil ? .lock : .door
                node.addChild(textured(closed, side: tileSpan))
            }
        } else {
            node.addChild(textured(.plate, side: tileSpan))
        }
        return node
    }

    private func finishPlayback() {
        let completion = playbackCompletion
        playbackCompletion = nil
        startIdle()
        completion?()
    }

    func applyMotionPreference() {
        guard playbackCompletion == nil else { return }
        robotNode.removeAction(forKey: "idle")
        robotSprite.removeAction(forKey: "idle")
        robotShadow.removeAction(forKey: "idle")
        resetRobotPose()
        startIdle()
        refreshLifeParticlesMotion()
    }

    private func startIdle() {
        // Ne pas redémarrer une idle déjà en cours (évite le hic à chaque édition).
        if robotSprite.action(forKey: "idle") != nil { return }
        robotNode.removeAction(forKey: "idle")
        robotShadow.removeAction(forKey: "idle")
        resetRobotPose()
        guard !PlaySettings.prefersReducedMotion else { return }
        // Respiration très légère depuis les pieds.
        let lift = cellSize * 0.02
        let up = SKAction.group([
            .moveBy(x: 0, y: lift, duration: 0.95),
            .scaleX(to: 0.985, y: 1.02, duration: 0.95)
        ])
        up.timingMode = .easeInEaseOut
        let down = SKAction.group([
            .moveBy(x: 0, y: -lift, duration: 0.95),
            .scaleX(to: 1.015, y: 0.985, duration: 0.95)
        ])
        down.timingMode = .easeInEaseOut
        let sway = SKAction.sequence([
            .rotate(toAngle: 0.015, duration: 1.4),
            .rotate(toAngle: -0.015, duration: 1.4)
        ])
        sway.timingMode = .easeInEaseOut
        robotSprite.run(
            .group([
                .repeatForever(.sequence([up, down])),
                .repeatForever(sway)
            ]),
            withKey: "idle"
        )
        // L'ombre se contracte un peu quand le robot se relève.
        let shrink = SKAction.group([
            .scaleX(to: 0.9, y: 0.88, duration: 0.95),
            .fadeAlpha(to: 0.88, duration: 0.95)
        ])
        shrink.timingMode = .easeInEaseOut
        let grow = SKAction.group([
            .scaleX(to: 1.0, y: 1.0, duration: 0.95),
            .fadeAlpha(to: 1.0, duration: 0.95)
        ])
        grow.timingMode = .easeInEaseOut
        robotShadow.run(.repeatForever(.sequence([shrink, grow])), withKey: "idle")
    }

    private static let robotShadowTexture: SKTexture = {
        // Carré large : le dégradé radial s'éteint avant le bord, puis on l'aplatit en ovale.
        let side: CGFloat = 128
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: side, height: side))
        let image = renderer.image { context in
            let cg = context.cgContext
            let colors = [
                UIColor.black.withAlphaComponent(0.78).cgColor,
                UIColor.black.withAlphaComponent(0.48).cgColor,
                UIColor.black.withAlphaComponent(0.2).cgColor,
                UIColor.black.withAlphaComponent(0).cgColor
            ] as CFArray
            let spaces = CGColorSpaceCreateDeviceRGB()
            guard let gradient = CGGradient(
                colorsSpace: spaces,
                colors: colors,
                locations: [0, 0.32, 0.68, 1]
            ) else { return }
            let center = CGPoint(x: side * 0.5, y: side * 0.5)
            cg.drawRadialGradient(
                gradient,
                startCenter: center,
                startRadius: 0,
                endCenter: center,
                endRadius: side * 0.48,
                options: []
            )
        }
        return SKTexture(image: image)
    }()

    private static let sparkTexture: SKTexture = {
        let side: CGFloat = 10
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: side, height: side))
        let image = renderer.image { context in
            UIColor.white.setFill()
            context.cgContext.fillEllipse(in: CGRect(x: 0, y: 0, width: side, height: side))
        }
        return SKTexture(image: image)
    }()

    /// Halo doux (dégradé radial), pas un disque opaque de poussière.
    private static let haloTexture: SKTexture = {
        let side: CGFloat = 64
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: side, height: side))
        let image = renderer.image { context in
            let cg = context.cgContext
            let colors = [
                UIColor.white.withAlphaComponent(0.85).cgColor,
                UIColor.white.withAlphaComponent(0.28).cgColor,
                UIColor.white.withAlphaComponent(0).cgColor
            ] as CFArray
            let locations: [CGFloat] = [0, 0.4, 1]
            guard let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: colors,
                locations: locations
            ) else { return }
            let center = CGPoint(x: side / 2, y: side / 2)
            cg.drawRadialGradient(
                gradient,
                startCenter: center,
                startRadius: 0,
                endCenter: center,
                endRadius: side / 2,
                options: []
            )
        }
        return SKTexture(image: image)
    }()

    private static let leafTexture: SKTexture = {
        let size = CGSize(width: 16, height: 22)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            let cg = context.cgContext
            cg.setFillColor(UIColor.white.cgColor)
            cg.beginPath()
            cg.move(to: CGPoint(x: size.width * 0.5, y: 1))
            cg.addQuadCurve(
                to: CGPoint(x: size.width * 0.5, y: size.height - 1),
                control: CGPoint(x: size.width * 1.05, y: size.height * 0.45)
            )
            cg.addQuadCurve(
                to: CGPoint(x: size.width * 0.5, y: 1),
                control: CGPoint(x: -size.width * 0.05, y: size.height * 0.45)
            )
            cg.closePath()
            cg.fillPath()
        }
        return SKTexture(image: image)
    }()

    private func attachGoalShine(at position: CGPoint) {
        // Halo diffus + respiration : pas d'étincelles nettes.
        let bloom = makeGoalHaloEmitter(scale: 2.2, birthRate: 2.0, alphaPeak: 0.12, z: 0.42)
        bloom.name = "life-goal-halo-outer"
        bloom.position = position
        if PlaySettings.prefersReducedMotion {
            bloom.particleBirthRate = 0
        }
        addChild(bloom)

        let core = makeGoalHaloEmitter(scale: 1.45, birthRate: 2.6, alphaPeak: 0.18, z: 0.46)
        core.name = "life-goal-halo-core"
        core.position = position
        if PlaySettings.prefersReducedMotion {
            core.particleBirthRate = 0
        }
        addChild(core)

        addChild(makeGoalPulseHalo(
            at: position,
            sizeFactor: 1.55,
            alphaLow: 0.14,
            alphaHigh: 0.34,
            duration: 1.05,
            z: 0.52,
            name: "life-goal-pulse-a"
        ))
        addChild(makeGoalPulseHalo(
            at: position,
            sizeFactor: 2.15,
            alphaLow: 0.08,
            alphaHigh: 0.22,
            duration: 1.35,
            z: 0.5,
            name: "life-goal-pulse-b"
        ))
    }

    private func makeGoalPulseHalo(
        at position: CGPoint,
        sizeFactor: CGFloat,
        alphaLow: CGFloat,
        alphaHigh: CGFloat,
        duration: TimeInterval,
        z: CGFloat,
        name: String
    ) -> SKSpriteNode {
        let colors = goalShineColors()
        let glow = SKSpriteNode(texture: Self.haloTexture)
        glow.name = name
        glow.position = position
        glow.zPosition = z
        glow.blendMode = .add
        glow.color = colors.primary
        glow.colorBlendFactor = 1
        let side = tileSpan * sizeFactor
        glow.size = CGSize(width: side, height: side)
        glow.setScale(1)
        glow.alpha = PlaySettings.prefersReducedMotion ? (alphaLow + alphaHigh) * 0.5 : alphaLow
        guard !PlaySettings.prefersReducedMotion else { return glow }

        let breatheIn = SKAction.group([
            .fadeAlpha(to: alphaHigh, duration: duration),
            .scale(to: 1.14, duration: duration)
        ])
        breatheIn.timingMode = .easeInEaseOut
        let breatheOut = SKAction.group([
            .fadeAlpha(to: alphaLow, duration: duration),
            .scale(to: 1.0, duration: duration)
        ])
        breatheOut.timingMode = .easeInEaseOut
        glow.run(.repeatForever(.sequence([breatheIn, breatheOut])), withKey: "pulse")
        return glow
    }

    private func goalShineColors() -> (primary: UIColor, secondary: UIColor) {
        switch level.worldNumber {
        case 2:
            return (UIColor(hex: 0xFFB020), UIColor(hex: 0xFF7A18))
        case 3:
            return (UIColor(hex: 0x7CFF9A), UIColor(hex: 0x3EC6FF))
        case 4:
            return (UIColor(hex: 0xC56BFF), UIColor(hex: 0x7B3FF2))
        case 5:
            return (UIColor(hex: 0x3EC6FF), UIColor(hex: 0x7FE9FF))
        case 6:
            return (UIColor(hex: 0x7FE9FF), UIColor(hex: 0x3EC6FF))
        case 7:
            return (UIColor(hex: 0xFFD24A), UIColor(hex: 0xE08A3C))
        case 8:
            return (UIColor(hex: 0x7DDE63), UIColor(hex: 0x3ECF7A))
        case 9:
            return (UIColor(hex: 0xFF7A18), UIColor(hex: 0xFF3B2F))
        case 10:
            return (UIColor(hex: 0x6B7BFF), UIColor(hex: 0xC56BFF))
        default:
            return (UIColor(hex: 0x7DDE63), UIColor(hex: 0x3ECF7A))
        }
    }

    private func makeGoalHaloEmitter(
        scale: CGFloat,
        birthRate: CGFloat,
        alphaPeak: CGFloat,
        z: CGFloat
    ) -> SKEmitterNode {
        let factor = particleSizeFactor
        let colors = goalShineColors()
        let emitter = SKEmitterNode()
        emitter.particleTexture = Self.haloTexture
        emitter.particleBlendMode = .add
        emitter.particleBirthRate = birthRate
        emitter.particleLifetime = 2.4
        emitter.particleLifetimeRange = 0.5
        emitter.particleSpeed = cellSize * 0.004
        emitter.particleSpeedRange = cellSize * 0.003
        emitter.emissionAngle = 0
        emitter.emissionAngleRange = .pi * 2
        emitter.particlePositionRange = CGVector(dx: tileSpan * 0.08, dy: tileSpan * 0.08)
        emitter.yAcceleration = 0
        emitter.particleScale = scale * factor
        emitter.particleScaleRange = emitter.particleScale * 0.12
        emitter.particleScaleSequence = particleScaleSequence(
            [scale * 0.82, scale, scale * 1.12],
            times: [0, 0.45, 1]
        )
        emitter.particleColorBlendFactor = 1
        emitter.particleColorSequence = SKKeyframeSequence(
            keyframeValues: [colors.primary, colors.secondary, colors.primary],
            times: [0, 0.55, 1]
        )
        emitter.particleAlphaSequence = SKKeyframeSequence(
            keyframeValues: [0, alphaPeak, alphaPeak * 0.55, 0],
            times: [0, 0.25, 0.7, 1]
        )
        emitter.zPosition = z
        emitter.userData = NSMutableDictionary(dictionary: ["birthRate": emitter.particleBirthRate])
        return emitter
    }

    private func attachLifeParticles(for terrain: TerrainType, at position: CGPoint) {
        guard let emitter = makeLifeEmitter(for: terrain) else { return }
        emitter.name = "life-\(terrain.rawValue)"
        emitter.position = position
        emitter.zPosition = 1.05
        if PlaySettings.prefersReducedMotion {
            emitter.particleBirthRate = 0
        }
        addChild(emitter)
        if terrain == .lava {
            let smoke = makeLavaSmokeEmitter()
            smoke.name = "life-lava-smoke"
            smoke.position = CGPoint(x: position.x, y: position.y + tileSpan * 0.22)
            smoke.zPosition = 1.08
            if PlaySettings.prefersReducedMotion {
                smoke.particleBirthRate = 0
            }
            addChild(smoke)
        }
    }

    private func refreshLifeParticlesMotion() {
        let calm = PlaySettings.prefersReducedMotion
        enumerateChildNodes(withName: "life-*") { node, _ in
            if let emitter = node as? SKEmitterNode {
                let rate = (emitter.userData?["birthRate"] as? NSNumber)?.doubleValue ?? 0
                emitter.particleBirthRate = calm ? 0 : CGFloat(rate)
                if calm {
                    emitter.resetSimulation()
                }
                return
            }
            guard node.name?.hasPrefix("life-goal-pulse") == true else { return }
            if calm {
                node.removeAction(forKey: "pulse")
                node.setScale(1)
                node.alpha = 0.2
            } else if node.action(forKey: "pulse") == nil, let sprite = node as? SKSpriteNode {
                let high: CGFloat = sprite.name == "life-goal-pulse-a" ? 0.34 : 0.22
                let low: CGFloat = sprite.name == "life-goal-pulse-a" ? 0.14 : 0.08
                let duration: TimeInterval = sprite.name == "life-goal-pulse-a" ? 1.05 : 1.35
                let breatheIn = SKAction.group([
                    .fadeAlpha(to: high, duration: duration),
                    .scale(to: 1.14, duration: duration)
                ])
                breatheIn.timingMode = .easeInEaseOut
                let breatheOut = SKAction.group([
                    .fadeAlpha(to: low, duration: duration),
                    .scale(to: 1.0, duration: duration)
                ])
                breatheOut.timingMode = .easeInEaseOut
                sprite.alpha = low
                sprite.run(.repeatForever(.sequence([breatheIn, breatheOut])), withKey: "pulse")
            }
        }
    }

    /// Taille de case de référence : à cette taille, l'échelle visuelle reste celle d'origine.
    private var particleSizeFactor: CGFloat {
        max(0.45, cellSize / 44)
    }

    /// Les séquences SpriteKit sont absolues : on les multiplie par le facteur de case.
    private func particleScaleSequence(_ values: [CGFloat], times: [NSNumber]) -> SKKeyframeSequence {
        let factor = particleSizeFactor
        return SKKeyframeSequence(keyframeValues: values.map { $0 * factor }, times: times)
    }

    private func makeLifeEmitter(for terrain: TerrainType) -> SKEmitterNode? {
        let emitter = SKEmitterNode()
        let factor = particleSizeFactor
        emitter.particleTexture = Self.sparkTexture
        emitter.particleBlendMode = .alpha
        emitter.particlePositionRange = CGVector(dx: tileSpan * 0.42, dy: tileSpan * 0.28)
        emitter.emissionAngleRange = .pi * 2
        emitter.particleAlphaSequence = SKKeyframeSequence(keyframeValues: [0, 0.7, 0], times: [0, 0.35, 1])
        emitter.particleColorBlendFactor = 1

        switch terrain {
        case .water:
            emitter.particleBirthRate = 4.4
            emitter.particleLifetime = 1.9
            emitter.particleLifetimeRange = 0.4
            emitter.particleSpeed = cellSize * 0.09
            emitter.particleSpeedRange = cellSize * 0.06
            emitter.emissionAngle = .pi / 2
            emitter.emissionAngleRange = .pi / 2.4
            emitter.particlePositionRange = CGVector(dx: tileSpan * 0.92, dy: tileSpan * 0.55)
            emitter.yAcceleration = cellSize * 0.045
            emitter.particleScale = 0.55 * factor
            emitter.particleScaleRange = emitter.particleScale * 0.4
            emitter.particleScaleSequence = particleScaleSequence([0.35, 0.7, 0.15], times: [0, 0.4, 1])
            emitter.particleColor = UIColor(red: 0.55, green: 0.88, blue: 1, alpha: 1)
            emitter.particleColorBlendFactorSequence = SKKeyframeSequence(
                keyframeValues: [1, 1],
                times: [0, 1]
            )
            let cyan = UIColor(red: 0.45, green: 0.82, blue: 1, alpha: 1)
            let white = UIColor(white: 1, alpha: 1)
            emitter.particleColorSequence = SKKeyframeSequence(keyframeValues: [cyan, white, cyan], times: [0, 0.5, 1])
            emitter.particleAlphaSequence = SKKeyframeSequence(keyframeValues: [0.25, 0.95, 0.55, 0], times: [0, 0.25, 0.7, 1])
        case .lava:
            emitter.particleBirthRate = 5.0
            emitter.particleLifetime = 1.4
            emitter.particleLifetimeRange = 0.35
            emitter.particleSpeed = cellSize * 0.13
            emitter.particleSpeedRange = cellSize * 0.09
            emitter.emissionAngle = .pi / 2
            emitter.emissionAngleRange = .pi / 3
            emitter.particlePositionRange = CGVector(dx: tileSpan * 0.92, dy: tileSpan * 0.55)
            emitter.yAcceleration = cellSize * 0.07
            emitter.particleScale = 0.6 * factor
            emitter.particleScaleRange = emitter.particleScale * 0.45
            emitter.particleScaleSequence = particleScaleSequence([0.35, 0.7, 0.15], times: [0, 0.4, 1])
            let orange = UIColor(red: 1, green: 0.55, blue: 0.12, alpha: 1)
            let yellow = UIColor(red: 1, green: 0.86, blue: 0.28, alpha: 1)
            let red = UIColor(red: 1, green: 0.28, blue: 0.08, alpha: 1)
            emitter.particleColorSequence = SKKeyframeSequence(keyframeValues: [orange, yellow, red], times: [0, 0.45, 1])
            emitter.particleAlphaSequence = SKKeyframeSequence(keyframeValues: [0.3, 1, 0.55, 0], times: [0, 0.18, 0.68, 1])
        case .bush:
            emitter.particleTexture = Self.leafTexture
            emitter.particleBirthRate = 3.2
            emitter.particleLifetime = 2.4
            emitter.particleLifetimeRange = 0.5
            emitter.particleSpeed = cellSize * 0.03
            emitter.particleSpeedRange = cellSize * 0.02
            emitter.emissionAngle = 0
            emitter.emissionAngleRange = .pi * 2
            emitter.particlePositionRange = CGVector(dx: tileSpan * 0.55, dy: tileSpan * 0.42)
            emitter.xAcceleration = 0
            emitter.yAcceleration = 0
            emitter.particleScale = 0.75 * factor
            emitter.particleScaleRange = emitter.particleScale * 0.25
            emitter.particleScaleSequence = particleScaleSequence([0.55, 0.95, 0.55], times: [0, 0.4, 1])
            emitter.particleRotation = -.pi / 6
            emitter.particleRotationRange = .pi * 0.6
            emitter.particleRotationSpeed = 0.55
            let lime = UIColor(red: 0.78, green: 0.98, blue: 0.32, alpha: 1)
            let mint = UIColor(red: 0.55, green: 0.92, blue: 0.42, alpha: 1)
            let pale = UIColor(red: 0.94, green: 1, blue: 0.62, alpha: 1)
            emitter.particleColorSequence = SKKeyframeSequence(keyframeValues: [mint, lime, pale], times: [0, 0.4, 1])
            emitter.particleAlphaSequence = SKKeyframeSequence(keyframeValues: [0.15, 0.72, 0.58, 0], times: [0, 0.12, 0.7, 1])
        default:
            return nil
        }

        emitter.numParticlesToEmit = 0
        emitter.userData = NSMutableDictionary(dictionary: ["birthRate": emitter.particleBirthRate])
        return emitter
    }

    private func makeLavaSmokeEmitter() -> SKEmitterNode {
        let factor = particleSizeFactor
        let smoke = SKEmitterNode()
        smoke.particleTexture = Self.sparkTexture
        smoke.particleBlendMode = .alpha
        smoke.particleBirthRate = 2.8
        smoke.particleLifetime = 2.8
        smoke.particleLifetimeRange = 0.7
        smoke.particleSpeed = cellSize * 0.16
        smoke.particleSpeedRange = cellSize * 0.06
        smoke.emissionAngle = .pi / 2
        smoke.emissionAngleRange = .pi / 6
        smoke.particlePositionRange = CGVector(dx: tileSpan * 0.55, dy: tileSpan * 0.1)
        smoke.yAcceleration = cellSize * 0.08
        smoke.xAcceleration = cellSize * 0.012
        smoke.particleScale = 0.85 * factor
        smoke.particleScaleRange = smoke.particleScale * 0.45
        smoke.particleScaleSequence = particleScaleSequence([0.45, 1.25, 1.7], times: [0, 0.4, 1])
        smoke.particleColorBlendFactor = 1
        let peach = UIColor(red: 1, green: 0.78, blue: 0.58, alpha: 1)
        let cream = UIColor(red: 1, green: 0.92, blue: 0.82, alpha: 1)
        let mist = UIColor(red: 0.96, green: 0.88, blue: 0.8, alpha: 1)
        smoke.particleColorSequence = SKKeyframeSequence(keyframeValues: [peach, cream, mist], times: [0, 0.45, 1])
        smoke.particleAlphaSequence = SKKeyframeSequence(keyframeValues: [0.12, 0.38, 0.2, 0], times: [0, 0.18, 0.62, 1])
        smoke.numParticlesToEmit = 0
        smoke.userData = NSMutableDictionary(dictionary: ["birthRate": smoke.particleBirthRate])
        return smoke
    }

    private func pulseMechanisms(at coordinate: GridCoordinate) {
        let point = center(of: coordinate)
        enumerateChildNodes(withName: "mech-*") { node, _ in
            let distance = hypot(node.position.x - point.x, node.position.y - point.y)
            if distance < 2 {
                self.pulseNode(node)
            }
        }
    }

    private func pulseNode(named name: String) {
        guard let node = childNode(withName: name) else { return }
        pulseNode(node)
    }

    private func pulseNode(_ node: SKNode) {
        guard !PlaySettings.prefersReducedMotion else { return }
        node.removeAction(forKey: "pulse")
        node.setScale(1)
        node.run(.sequence([
            .scale(to: 1.16, duration: 0.08),
            .scale(to: 1, duration: 0.14)
        ]), withKey: "pulse")
    }
}
