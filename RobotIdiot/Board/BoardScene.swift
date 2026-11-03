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
    private var flagNode = SKNode()
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
        cancelPlayback()
        presented = game
        // Ne pas reconstruire le plateau à chaque édition de programme :
        // ça réinitialiserait les particules d'ambiance.
        if children.contains(where: { $0.name?.hasPrefix("ground-") == true }) {
            restoreFlagAppearance()
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
            slideRobot(to: destination, tempo: tempo, reduceMotion: reduceMotion, victory: victory)
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
        robotNode.setScale(1)
        flagNode.removeAllActions()
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
                let piece = groundPiece(terrain)
                let tile = textured(piece, side: tileSpan)
                let spot = displayCenter(x: x, y: y)
                tile.name = "ground-\(x)-\(y)"
                tile.position = spot
                tile.zPosition = terrain?.blocksMovement == true ? 0.4 : 0
                addChild(tile)
                if let terrain {
                    attachLifeParticles(for: terrain, at: spot)
                }
            }
        }
        if !level.id.hasPrefix("RI-") {
            paintCornerBushes()
        }

        for objective in level.objectives where objective.kind == .reachFlag {
            flagNode = makeFlag()
            flagNode.position = center(of: objective.position)
            flagNode.zPosition = 2
            addChild(flagNode)
        }

        for cell in presented.grid.cells {
            for object in cell.objects {
                addChild(makeObject(object, at: cell.coordinate))
            }
            for mechanism in cell.mechanisms {
                addChild(makeMechanism(mechanism, at: cell.coordinate))
            }
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
        return CGPoint(x: point.x, y: point.y + cellSize * 0.16)
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
    }

    private func makeRobot() -> SKNode {
        let node = SKNode()
        robotSprite = SKSpriteNode(texture: SKTexture(image: facingImage(for: presented.robot.orientation)))
        let side = cellSize * 0.92
        robotSprite.size = CGSize(width: side, height: side)
        robotSprite.zPosition = 1
        node.addChild(robotSprite)
        return node
    }

    private func makeFlag() -> SKNode {
        let node = SKNode()
        let sprite = textured(.flag, side: tileSpan)
        node.addChild(sprite)
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

    private func restoreFlagAppearance() {
        flagNode.removeAllActions()
        flagNode.alpha = 1
        flagNode.setScale(1)
        if flagNode.parent == nil {
            for objective in level.objectives where objective.kind == .reachFlag {
                flagNode = makeFlag()
                flagNode.position = center(of: objective.position)
                flagNode.zPosition = 2
                addChild(flagNode)
            }
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
            self?.robotNode.alpha = 1
            self?.robotNode.setScale(1)
            self?.robotNode.zRotation = 0
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
        // De face (sud) : le sol sous le drapeau apparaît quand le drapeau disparaît.
        applyFacing(.south)
        flagNode.removeAllActions()
        robotNode.removeAction(forKey: "idle")
        robotNode.setScale(1)
        robotNode.alpha = 1
        robotNode.zRotation = 0
        Soundscape.shared.play("success")

        guard !reduceMotion else {
            flagNode.alpha = 0
            finishPlayback()
            return
        }

        flagNode.run(.fadeOut(withDuration: 0.2))

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
        for index in 0..<18 {
            let dot = SKShapeNode(circleOfRadius: cellSize * (index.isMultiple(of: 2) ? 0.075 : 0.05))
            let colors = [AppTheme.gold, AppTheme.coral, AppTheme.teal, AppTheme.success, AppTheme.move]
            dot.fillColor = colors[index % colors.count]
            dot.strokeColor = .clear
            dot.position = robotNode.position
            dot.zPosition = 5
            dot.name = "effect"
            addChild(dot)
            let angle = CGFloat(index) / 18 * .pi * 2
            let distance = radius * (index.isMultiple(of: 2) ? 1 : 0.7)
            let destination = CGPoint(
                x: robotNode.position.x + cos(angle) * distance,
                y: robotNode.position.y + sin(angle) * distance
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
            self?.robotNode.zRotation = 0
            self?.robotNode.setScale(1)
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
        var stale: [SKNode] = []
        enumerateChildNodes(withName: "*") { node, _ in
            guard let name = node.name else { return }
            if (name.hasPrefix("prop-") || name.hasPrefix("mech-")), !seen.contains(name) {
                stale.append(node)
            }
        }
        stale.forEach { $0.removeFromParent() }
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
        robotNode.setScale(1)
        startIdle()
        refreshLifeParticlesMotion()
    }

    private func startIdle() {
        robotNode.removeAction(forKey: "idle")
        guard !PlaySettings.prefersReducedMotion else { return }
        let bob = SKAction.sequence([
            .scale(to: 1.035, duration: 0.85),
            .scale(to: 1, duration: 0.85)
        ])
        robotNode.run(.repeatForever(bob), withKey: "idle")
    }

    private static let sparkTexture: SKTexture = {
        let side: CGFloat = 10
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: side, height: side))
        let image = renderer.image { context in
            UIColor.white.setFill()
            context.cgContext.fillEllipse(in: CGRect(x: 0, y: 0, width: side, height: side))
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
            guard let emitter = node as? SKEmitterNode else { return }
            let rate = (emitter.userData?["birthRate"] as? NSNumber)?.doubleValue ?? 0
            emitter.particleBirthRate = calm ? 0 : CGFloat(rate)
            if calm {
                emitter.resetSimulation()
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
