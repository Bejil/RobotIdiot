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
        let texture: SKTexture
        if let cached = artTextures[piece.rawValue] {
            texture = cached
        } else {
            let made = SKTexture(image: GameArt.piece(piece))
            artTextures[piece.rawValue] = made
            texture = made
        }
        let sprite = SKSpriteNode(texture: texture)
        sprite.size = CGSize(width: side, height: side)
        return sprite
    }

    /// La bordure de murs n'est pas une tuile : le bord du 7×7 est la seule limite.
    private func playfield() -> (minX: Int, maxX: Int, minY: Int, maxY: Int) {
        let grid = level.grid
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
            let bush = textured(.bush, side: tileSpan)
            bush.position = displayCenter(x: x, y: y)
            bush.zPosition = 0.35
            addChild(bush)
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

        switch event {
        case .moved(_, let destination, _, _):
            slideRobot(to: destination, tempo: tempo, reduceMotion: reduceMotion, victory: resulting.isVictory)
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
                self?.finishPlayback()
            }
        case .pickedUp(let item, _):
            fadeProp(named: "prop-\(item.id)", tempo: tempo, reduceMotion: reduceMotion)
        case .used(_, let coordinate):
            syncProps(to: presented)
            pulseMechanisms(at: coordinate)
            dwell(reduceMotion: reduceMotion, tempo: tempo)
        case .activated(let mechanismID, _, _):
            syncProps(to: presented)
            pulseNode(named: "mech-\(mechanismID)")
            dwell(reduceMotion: reduceMotion, tempo: tempo)
        case .pushed(let objectID, let from, let to):
            if let crate = childNode(withName: "prop-\(objectID)") {
                crate.run(SKAction.move(to: center(of: to), duration: tempo.moveDuration(reduceMotion: reduceMotion)))
            }
            slideRobot(to: from, tempo: tempo, reduceMotion: reduceMotion, victory: resulting.isVictory)
        case .enteredLoop, .testedCondition:
            dwell(reduceMotion: reduceMotion, tempo: tempo)
        case .blocked(let fault):
            shake(fault: fault, reduceMotion: reduceMotion)
        case .succeeded, .finishedWithoutGoal, .safetyStopped, nil:
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
                let floor = inside && presented.grid.cell(at: logical)?.terrain == .floor
                let piece: GameArt.BoardPiece = floor
                    ? .grassA
                    : ((x + y).isMultiple(of: 2) ? .shutter : .cracked)
                let tile = textured(piece, side: tileSpan)
                tile.position = displayCenter(x: x, y: y)
                tile.zPosition = floor ? 0 : 0.4
                addChild(tile)
            }
        }
        paintCornerBushes()

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

    private func dwell(reduceMotion: Bool, tempo: PlaybackTempo) {
        let duration: TimeInterval = reduceMotion ? 0.01 : (tempo == .fast ? 0.05 : 0.12)
        robotNode.run(SKAction.wait(forDuration: duration)) { [weak self] in
            self?.finishPlayback()
        }
    }

    private func shake(fault: ExecutionFault, reduceMotion: Bool) {
        if case .pathBlocked(_, _, _, let attempted) = fault {
            flash(at: attempted)
        }
        if case .pushBlocked(_, let attempted) = fault {
            flash(at: attempted)
        }
        let home = robotAnchor(of: presented.robot.position)
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
        guard !reduceMotion else {
            finishPlayback()
            return
        }
        let pulse = SKAction.sequence([
            .scale(to: 1.12, duration: 0.12),
            .scale(to: 1, duration: 0.12)
        ])
        robotNode.run(pulse)
        flagNode.run(.sequence([
            .scale(to: 1.28, duration: 0.12),
            .scale(to: 1, duration: 0.16)
        ]))
        let radius = cellSize * 1.15
        for index in 0..<16 {
            let dot = SKShapeNode(circleOfRadius: cellSize * (index.isMultiple(of: 2) ? 0.07 : 0.045))
            let colors = [AppTheme.gold, AppTheme.coral, AppTheme.teal, AppTheme.success, AppTheme.move]
            dot.fillColor = colors[index % colors.count]
            dot.strokeColor = .clear
            dot.position = robotNode.position
            dot.zPosition = 5
            dot.name = "effect"
            addChild(dot)
            let angle = CGFloat(index) / 16 * .pi * 2
            let distance = radius * (index.isMultiple(of: 2) ? 1 : 0.72)
            let destination = CGPoint(
                x: robotNode.position.x + cos(angle) * distance,
                y: robotNode.position.y + sin(angle) * distance
            )
            dot.run(SKAction.sequence([
                .group([
                    .move(to: destination, duration: 0.48),
                    .rotate(byAngle: .pi, duration: 0.48),
                    .fadeOut(withDuration: 0.48),
                    .scale(to: 0.2, duration: 0.48)
                ]),
                .removeFromParent()
            ]))
        }
        robotNode.run(SKAction.wait(forDuration: 0.5)) { [weak self] in
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
            if victory {
                self?.celebrate(reduceMotion: reduceMotion)
            } else {
                self?.finishPlayback()
            }
        }
    }

    private func fadeProp(named name: String, tempo: PlaybackTempo, reduceMotion: Bool) {
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
            self?.finishPlayback()
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
                let closed = level.allowedCommands.contains(.pickUp) || level.allowedCommands.contains(.use) ? GameArt.BoardPiece.lock : .door
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
