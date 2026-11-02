import UIKit
import RobotIdiotCore

/// Dessins du jeu : robot, tuiles, blocs, étoiles et icônes. Rien de cela ne vient des symboles système.
enum GameArt {
    private static let cache = NSCache<NSString, UIImage>()

    static func mascot(cheering: Bool) -> UIImage {
        canvas(cheering ? "mascot-cheer" : "mascot-idle", side: 320) { ctx, s in
            let ink = AppTheme.line
            ctx.setFillColor(UIColor.black.withAlphaComponent(0.18).cgColor)
            ctx.fillEllipse(in: CGRect(x: s * 0.18, y: s * 0.74, width: s * 0.64, height: s * 0.14))

            ink.setStroke()
            let stem = UIBezierPath()
            stem.move(to: CGPoint(x: s * 0.5, y: s * 0.24))
            stem.addLine(to: CGPoint(x: s * 0.5, y: s * 0.1))
            stem.lineWidth = s * 0.03
            stem.lineCapStyle = .round
            stem.stroke()
            let bulb = UIBezierPath(ovalIn: CGRect(x: s * 0.44, y: s * 0.02, width: s * 0.12, height: s * 0.12))
            AppTheme.coral.setFill()
            bulb.lineWidth = s * 0.02
            bulb.fill()
            ink.setStroke()
            bulb.stroke()

            AppTheme.robotBody.setFill()
            let body = UIBezierPath(roundedRect: CGRect(x: s * 0.2, y: s * 0.24, width: s * 0.6, height: s * 0.52), cornerRadius: s * 0.18)
            body.lineWidth = s * 0.035
            body.fill()
            ink.setStroke()
            body.stroke()

            let face = UIBezierPath(roundedRect: CGRect(x: s * 0.3, y: s * 0.32, width: s * 0.4, height: s * 0.28), cornerRadius: s * 0.1)
            UIColor(hex: 0x24315F).setFill()
            face.fill()

            func eye(_ x: CGFloat) {
                UIColor.white.setFill()
                UIBezierPath(ovalIn: CGRect(x: x, y: s * 0.38, width: s * 0.09, height: s * 0.1)).fill()
                ink.setFill()
                ctx.fillEllipse(in: CGRect(x: x + s * 0.03, y: s * 0.41, width: s * 0.035, height: s * 0.045))
            }
            eye(s * 0.37)
            eye(s * 0.54)

            let smile = UIBezierPath()
            smile.move(to: CGPoint(x: s * 0.4, y: s * 0.52))
            smile.addQuadCurve(to: CGPoint(x: s * 0.6, y: s * 0.52), controlPoint: CGPoint(x: s * 0.5, y: s * 0.58))
            smile.lineWidth = s * 0.018
            smile.lineCapStyle = .round
            UIColor.white.setStroke()
            smile.stroke()

            func arm(from: CGPoint, to: CGPoint) {
                let path = UIBezierPath()
                path.move(to: from)
                path.addLine(to: to)
                path.lineWidth = s * 0.045
                path.lineCapStyle = .round
                ink.setStroke()
                path.stroke()
                AppTheme.robotBody.setFill()
                let hand = UIBezierPath(ovalIn: CGRect(x: to.x - s * 0.045, y: to.y - s * 0.045, width: s * 0.09, height: s * 0.09))
                hand.fill()
                ink.setStroke()
                hand.lineWidth = s * 0.015
                hand.stroke()
            }
            if cheering {
                arm(from: CGPoint(x: s * 0.22, y: s * 0.4), to: CGPoint(x: s * 0.06, y: s * 0.18))
                arm(from: CGPoint(x: s * 0.78, y: s * 0.4), to: CGPoint(x: s * 0.94, y: s * 0.18))
            } else {
                arm(from: CGPoint(x: s * 0.22, y: s * 0.46), to: CGPoint(x: s * 0.08, y: s * 0.62))
                arm(from: CGPoint(x: s * 0.78, y: s * 0.46), to: CGPoint(x: s * 0.92, y: s * 0.62))
            }
        }
    }

    /// Robot de l'accueil, de face, un bras levé. Deux poses pour le salut.
    static func homeHero(wavingHigh: Bool) -> UIImage {
        canvas(wavingHigh ? "home-hero-high" : "home-hero-low", side: 360) { ctx, s in
            let ink = AppTheme.line
            ctx.setFillColor(UIColor.black.withAlphaComponent(0.16).cgColor)
            ctx.fillEllipse(in: CGRect(x: s * 0.22, y: s * 0.82, width: s * 0.56, height: s * 0.1))

            AppTheme.coral.setFill()
            ctx.fillEllipse(in: CGRect(x: s * 0.34, y: s * 0.74, width: s * 0.12, height: s * 0.09))
            ctx.fillEllipse(in: CGRect(x: s * 0.54, y: s * 0.74, width: s * 0.12, height: s * 0.09))

            let body = UIBezierPath(roundedRect: CGRect(x: s * 0.28, y: s * 0.4, width: s * 0.44, height: s * 0.38), cornerRadius: s * 0.14)
            AppTheme.robotBody.setFill()
            body.fill()
            ink.setStroke()
            body.lineWidth = s * 0.035
            body.stroke()

            let head = UIBezierPath(ovalIn: CGRect(x: s * 0.22, y: s * 0.16, width: s * 0.56, height: s * 0.42))
            AppTheme.robotBody.setFill()
            head.fill()
            ink.setStroke()
            head.lineWidth = s * 0.04
            head.stroke()

            let visor = UIBezierPath(roundedRect: CGRect(x: s * 0.32, y: s * 0.26, width: s * 0.36, height: s * 0.22), cornerRadius: s * 0.08)
            UIColor(hex: 0x2F6BFF).setFill()
            visor.fill()

            func happyEye(_ x: CGFloat) {
                let eye = UIBezierPath()
                eye.move(to: CGPoint(x: x, y: s * 0.36))
                eye.addQuadCurve(to: CGPoint(x: x + s * 0.08, y: s * 0.36), controlPoint: CGPoint(x: x + s * 0.04, y: s * 0.31))
                eye.lineWidth = s * 0.018
                eye.lineCapStyle = .round
                UIColor.white.setStroke()
                eye.stroke()
            }
            happyEye(s * 0.38)
            happyEye(s * 0.52)
            let smile = UIBezierPath()
            smile.move(to: CGPoint(x: s * 0.42, y: s * 0.4))
            smile.addQuadCurve(to: CGPoint(x: s * 0.58, y: s * 0.4), controlPoint: CGPoint(x: s * 0.5, y: s * 0.45))
            smile.lineWidth = s * 0.016
            smile.lineCapStyle = .round
            UIColor.white.setStroke()
            smile.stroke()

            ink.setStroke()
            let stem = UIBezierPath()
            stem.move(to: CGPoint(x: s * 0.5, y: s * 0.18))
            stem.addLine(to: CGPoint(x: s * 0.5, y: s * 0.07))
            stem.lineWidth = s * 0.028
            stem.lineCapStyle = .round
            stem.stroke()
            let bulb = UIBezierPath(ovalIn: CGRect(x: s * 0.44, y: s * 0.015, width: s * 0.12, height: s * 0.12))
            AppTheme.gold.setFill()
            bulb.fill()
            ink.setStroke()
            bulb.lineWidth = s * 0.02
            bulb.stroke()

            func limb(from: CGPoint, to: CGPoint) {
                let path = UIBezierPath()
                path.move(to: from)
                path.addLine(to: to)
                path.lineWidth = s * 0.06
                path.lineCapStyle = .round
                ink.setStroke()
                path.stroke()
                AppTheme.robotBody.setFill()
                let hand = UIBezierPath(ovalIn: CGRect(x: to.x - s * 0.055, y: to.y - s * 0.055, width: s * 0.11, height: s * 0.11))
                hand.fill()
                ink.setStroke()
                hand.lineWidth = s * 0.02
                hand.stroke()
            }
            limb(from: CGPoint(x: s * 0.3, y: s * 0.5), to: CGPoint(x: s * 0.14, y: s * 0.74))
            if wavingHigh {
                limb(from: CGPoint(x: s * 0.7, y: s * 0.46), to: CGPoint(x: s * 0.88, y: s * 0.14))
            } else {
                limb(from: CGPoint(x: s * 0.7, y: s * 0.46), to: CGPoint(x: s * 0.9, y: s * 0.3))
            }
        }
    }

    static func star(filled: Bool) -> UIImage {
        canvas(filled ? "star-on" : "star-off", side: 96) { _, s in
            let path = starPath(in: CGRect(x: s * 0.08, y: s * 0.08, width: s * 0.84, height: s * 0.84))
            if filled {
                AppTheme.gold.setFill()
                path.fill()
            } else {
                AppTheme.inkSoft.withAlphaComponent(0.35).setFill()
                path.fill()
            }
            AppTheme.line.setStroke()
            path.lineWidth = s * 0.06
            path.lineJoinStyle = .round
            path.stroke()
        }
    }

    static func commandIcon(_ command: CommandType) -> UIImage {
        let name: String
        switch command {
        case .moveForward: name = "CommandForward"
        case .moveBackward: name = "CommandBackward"
        case .turnLeft: name = "CommandLeft"
        case .turnRight: name = "CommandRight"
        case .pickUp: name = "CommandPickUp"
        case .use: name = "CommandUse"
        case .push: name = "CommandPush"
        case .activate: name = "CommandActivate"
        case .forever: name = "CommandLoop"
        case .ifBlock: name = "CommandIf"
        }
        if let image = UIImage(named: name) {
            return image.withRenderingMode(.alwaysTemplate)
        }
        return drawnCommandIcon(command)
    }

    private static func drawnCommandIcon(_ command: CommandType) -> UIImage {
        canvas("cmd-\(command.rawValue)", side: 64) { _, s in
            UIColor.white.setStroke()
            UIColor.white.setFill()
            let weight = s * 0.09
            switch command {
            case .moveForward:
                arrow(in: CGRect(x: s * 0.22, y: s * 0.16, width: s * 0.56, height: s * 0.68), weight: weight, up: true)
            case .moveBackward:
                arrow(in: CGRect(x: s * 0.22, y: s * 0.16, width: s * 0.56, height: s * 0.68), weight: weight, up: false)
            case .turnLeft:
                turn(in: CGRect(x: s * 0.14, y: s * 0.16, width: s * 0.7, height: s * 0.68), weight: weight, left: true)
            case .turnRight:
                turn(in: CGRect(x: s * 0.16, y: s * 0.16, width: s * 0.7, height: s * 0.68), weight: weight, left: false)
            case .forever:
                infinity(in: CGRect(x: s * 0.1, y: s * 0.28, width: s * 0.8, height: s * 0.44), weight: weight)
            case .ifBlock:
                let diamond = UIBezierPath()
                diamond.move(to: CGPoint(x: s * 0.5, y: s * 0.84))
                diamond.addLine(to: CGPoint(x: s * 0.82, y: s * 0.5))
                diamond.addLine(to: CGPoint(x: s * 0.5, y: s * 0.16))
                diamond.addLine(to: CGPoint(x: s * 0.18, y: s * 0.5))
                diamond.close()
                diamond.lineWidth = weight
                diamond.stroke()
            case .pickUp:
                key(in: CGRect(x: s * 0.16, y: s * 0.16, width: s * 0.68, height: s * 0.68), weight: weight)
            case .use:
                lock(in: CGRect(x: s * 0.22, y: s * 0.14, width: s * 0.56, height: s * 0.7), weight: weight, open: true)
            case .push:
                crate(in: CGRect(x: s * 0.18, y: s * 0.18, width: s * 0.64, height: s * 0.64), weight: weight)
            case .activate:
                lever(in: CGRect(x: s * 0.18, y: s * 0.18, width: s * 0.64, height: s * 0.64), weight: weight)
            }
        }.withRenderingMode(.alwaysTemplate)
    }

    static func mark(_ name: String) -> UIImage {
        canvas("mark-\(name)", side: 64) { _, s in
            UIColor.white.setStroke()
            UIColor.white.setFill()
            let weight = s * 0.09
            switch name {
            case "play":
                let path = UIBezierPath()
                path.move(to: CGPoint(x: s * 0.28, y: s * 0.2))
                path.addLine(to: CGPoint(x: s * 0.78, y: s * 0.5))
                path.addLine(to: CGPoint(x: s * 0.28, y: s * 0.8))
                path.close()
                path.fill()
            case "map":
                let sheet = UIBezierPath(roundedRect: CGRect(x: s * 0.12, y: s * 0.2, width: s * 0.76, height: s * 0.58), cornerRadius: s * 0.1)
                sheet.lineWidth = weight
                sheet.stroke()
                let road = UIBezierPath()
                road.move(to: CGPoint(x: s * 0.24, y: s * 0.62))
                road.addQuadCurve(to: CGPoint(x: s * 0.74, y: s * 0.36), controlPoint: CGPoint(x: s * 0.42, y: s * 0.28))
                road.lineWidth = weight * 0.7
                road.lineCapStyle = .round
                road.stroke()
                let pin = UIBezierPath(ovalIn: CGRect(x: s * 0.58, y: s * 0.3, width: s * 0.14, height: s * 0.14))
                pin.fill()
            case "spark":
                starPath(in: CGRect(x: s * 0.16, y: s * 0.16, width: s * 0.68, height: s * 0.68)).fill()
            case "list":
                for offset in [0.28, 0.5, 0.72] as [CGFloat] {
                    UIBezierPath(ovalIn: CGRect(x: s * 0.16, y: s * offset - s * 0.045, width: s * 0.09, height: s * 0.09)).fill()
                    let line = UIBezierPath()
                    line.move(to: CGPoint(x: s * 0.36, y: s * offset))
                    line.addLine(to: CGPoint(x: s * 0.84, y: s * offset))
                    line.lineWidth = weight * 0.85
                    line.lineCapStyle = .round
                    line.stroke()
                }
            case "book":
                let pages = UIBezierPath()
                pages.move(to: CGPoint(x: s * 0.5, y: s * 0.28))
                pages.addLine(to: CGPoint(x: s * 0.16, y: s * 0.22))
                pages.addLine(to: CGPoint(x: s * 0.18, y: s * 0.74))
                pages.addLine(to: CGPoint(x: s * 0.5, y: s * 0.64))
                pages.addLine(to: CGPoint(x: s * 0.82, y: s * 0.74))
                pages.addLine(to: CGPoint(x: s * 0.84, y: s * 0.22))
                pages.close()
                pages.fill()
                let spine = UIBezierPath()
                spine.move(to: CGPoint(x: s * 0.5, y: s * 0.28))
                spine.addLine(to: CGPoint(x: s * 0.5, y: s * 0.64))
                spine.lineWidth = weight * 0.7
                spine.stroke()
            case "trophy":
                let bowl = UIBezierPath()
                bowl.move(to: CGPoint(x: s * 0.28, y: s * 0.16))
                bowl.addLine(to: CGPoint(x: s * 0.72, y: s * 0.16))
                bowl.addLine(to: CGPoint(x: s * 0.64, y: s * 0.46))
                bowl.addQuadCurve(to: CGPoint(x: s * 0.36, y: s * 0.46), controlPoint: CGPoint(x: s * 0.5, y: s * 0.58))
                bowl.close()
                bowl.fill()
                let leftHandle = UIBezierPath()
                leftHandle.move(to: CGPoint(x: s * 0.3, y: s * 0.22))
                leftHandle.addQuadCurve(to: CGPoint(x: s * 0.3, y: s * 0.4), controlPoint: CGPoint(x: s * 0.08, y: s * 0.3))
                leftHandle.lineWidth = weight
                leftHandle.lineCapStyle = .round
                leftHandle.stroke()
                let rightHandle = UIBezierPath()
                rightHandle.move(to: CGPoint(x: s * 0.7, y: s * 0.22))
                rightHandle.addQuadCurve(to: CGPoint(x: s * 0.7, y: s * 0.4), controlPoint: CGPoint(x: s * 0.92, y: s * 0.3))
                rightHandle.lineWidth = weight
                rightHandle.lineCapStyle = .round
                rightHandle.stroke()
                UIBezierPath(roundedRect: CGRect(x: s * 0.46, y: s * 0.5, width: s * 0.08, height: s * 0.14), cornerRadius: 2).fill()
                UIBezierPath(roundedRect: CGRect(x: s * 0.32, y: s * 0.64, width: s * 0.36, height: s * 0.1), cornerRadius: s * 0.04).fill()
            case "chart":
                let bars = [
                    CGRect(x: s * 0.18, y: s * 0.48, width: s * 0.16, height: s * 0.32),
                    CGRect(x: s * 0.42, y: s * 0.28, width: s * 0.16, height: s * 0.52),
                    CGRect(x: s * 0.66, y: s * 0.38, width: s * 0.16, height: s * 0.42)
                ]
                for bar in bars {
                    UIBezierPath(roundedRect: bar, cornerRadius: s * 0.04).fill()
                }
            case "flag":
                let pole = UIBezierPath()
                pole.move(to: CGPoint(x: s * 0.28, y: s * 0.14))
                pole.addLine(to: CGPoint(x: s * 0.28, y: s * 0.86))
                pole.lineWidth = weight
                pole.lineCapStyle = .round
                pole.stroke()
                let cloth = UIBezierPath()
                cloth.move(to: CGPoint(x: s * 0.28, y: s * 0.16))
                cloth.addLine(to: CGPoint(x: s * 0.82, y: s * 0.34))
                cloth.addLine(to: CGPoint(x: s * 0.28, y: s * 0.52))
                cloth.close()
                cloth.fill()
            default:
                gear(in: CGRect(x: s * 0.14, y: s * 0.14, width: s * 0.72, height: s * 0.72), weight: weight)
            }
        }.withRenderingMode(.alwaysTemplate)
    }

    static func worldBadge(_ theme: ThemeIdentifier) -> UIImage {
        canvas("world-\(theme.rawValue)", side: 128) { _, s in
            let card = UIBezierPath(roundedRect: CGRect(x: s * 0.06, y: s * 0.06, width: s * 0.88, height: s * 0.88), cornerRadius: s * 0.22)
            let fill: UIColor
            switch theme {
            case .orchard: fill = UIColor(hex: 0x3DDC84)
            case .night: fill = UIColor(hex: 0x3A4C96)
            case .foundry: fill = UIColor(hex: 0xE36A4A)
            default: fill = AppTheme.teal
            }
            fill.setFill()
            card.fill()
            AppTheme.line.setStroke()
            card.lineWidth = s * 0.04
            card.stroke()
            UIColor.white.setFill()
            switch theme {
            case .orchard:
                bush(at: CGPoint(x: s * 0.36, y: s * 0.58), radius: s * 0.16)
                bush(at: CGPoint(x: s * 0.62, y: s * 0.5), radius: s * 0.2)
            case .night:
                let moon = UIBezierPath(ovalIn: CGRect(x: s * 0.3, y: s * 0.28, width: s * 0.4, height: s * 0.4))
                moon.fill()
                fill.setFill()
                UIBezierPath(ovalIn: CGRect(x: s * 0.42, y: s * 0.32, width: s * 0.32, height: s * 0.32)).fill()
            case .foundry:
                let roof = UIBezierPath()
                roof.move(to: CGPoint(x: s * 0.24, y: s * 0.62))
                roof.addLine(to: CGPoint(x: s * 0.5, y: s * 0.32))
                roof.addLine(to: CGPoint(x: s * 0.76, y: s * 0.62))
                roof.close()
                roof.fill()
                UIBezierPath(rect: CGRect(x: s * 0.46, y: s * 0.18, width: s * 0.08, height: s * 0.16)).fill()
            default:
                let flask = UIBezierPath()
                flask.move(to: CGPoint(x: s * 0.42, y: s * 0.22))
                flask.addLine(to: CGPoint(x: s * 0.42, y: s * 0.42))
                flask.addLine(to: CGPoint(x: s * 0.28, y: s * 0.72))
                flask.addLine(to: CGPoint(x: s * 0.72, y: s * 0.72))
                flask.addLine(to: CGPoint(x: s * 0.58, y: s * 0.42))
                flask.addLine(to: CGPoint(x: s * 0.58, y: s * 0.22))
                flask.close()
                flask.fill()
            }
        }
    }

    enum BoardPiece: String {
        case grassA, grassB, stone, goal, bush, shutter, cracked
        case hero, flag, crate, key, door, doorOpen, lock, plate, plateOn
        case water, lava, spikes, portal
    }

    static func piece(_ piece: BoardPiece) -> UIImage {
        if let image = UIImage(named: assetName(piece)) {
            return image
        }
        return drawnPiece(piece)
    }

    private static func assetName(_ piece: BoardPiece) -> String {
        switch piece {
        case .grassA, .grassB, .goal:
            return "BoardGrass"
        case .stone:
            return "BoardStone"
        case .bush:
            return "BoardBush"
        case .shutter:
            return "BoardShutter"
        case .cracked:
            return "BoardCracked"
        case .water:
            return "BoardWater"
        case .lava:
            return "BoardLava"
        case .spikes:
            return "BoardSpikes"
        case .portal:
            return "BoardPortal"
        case .crate:
            return "BoardCrate"
        case .key:
            return "BoardKey"
        case .door:
            return "BoardDoor"
        case .lock:
            return "BoardLock"
        case .plate, .plateOn:
            return "BoardPlate"
        case .flag:
            return "BoardFlag"
        case .hero, .doorOpen:
            return ""
        }
    }

    private static func drawnPiece(_ piece: BoardPiece) -> UIImage {
        canvas("piece-\(piece.rawValue)", side: 128) { ctx, s in
            switch piece {
            case .grassA, .grassB:
                roundedTile(CGRect(x: 4, y: 4, width: s - 8, height: s - 8), fill: piece == .grassA ? UIColor(hex: 0x7DDE63) : UIColor(hex: 0x69D254), radius: s * 0.18)
                AppTheme.success.setFill()
                let shift: CGFloat = piece == .grassA ? 0 : 18
                ctx.fillEllipse(in: CGRect(x: 28 + shift, y: 36, width: 10, height: 16))
                ctx.fillEllipse(in: CGRect(x: 70 - shift, y: 72, width: 8, height: 14))
            case .stone, .bush, .shutter, .cracked, .water, .lava, .spikes, .portal:
                roundedTile(CGRect(x: 4, y: 4, width: s - 8, height: s - 8), fill: UIColor(hex: 0x8E97A8), radius: s * 0.16)
                UIColor.white.withAlphaComponent(0.45).setFill()
                ctx.fillEllipse(in: CGRect(x: s * 0.22, y: s * 0.28, width: s * 0.16, height: s * 0.12))
                UIColor(hex: 0x5C6578).setFill()
                ctx.fillEllipse(in: CGRect(x: s * 0.58, y: s * 0.58, width: s * 0.18, height: s * 0.14))
            case .goal:
                roundedTile(CGRect(x: 4, y: 4, width: s - 8, height: s - 8), fill: AppTheme.gold, radius: s * 0.18)
            case .hero:
                AppTheme.line.withAlphaComponent(0.25).setFill()
                ctx.fillEllipse(in: CGRect(x: s * 0.2, y: s * 0.78, width: s * 0.6, height: s * 0.12))
                let body = UIBezierPath(ovalIn: CGRect(x: s * 0.18, y: s * 0.2, width: s * 0.64, height: s * 0.64))
                AppTheme.robotBody.setFill()
                body.fill()
                AppTheme.line.setStroke()
                body.lineWidth = s * 0.05
                body.stroke()
                let face = UIBezierPath(roundedRect: CGRect(x: s * 0.28, y: s * 0.3, width: s * 0.44, height: s * 0.34), cornerRadius: s * 0.1)
                UIColor(hex: 0x24315F).setFill()
                face.fill()
                func heroEye(_ x: CGFloat) {
                    UIColor.white.setFill()
                    ctx.fillEllipse(in: CGRect(x: x, y: s * 0.34, width: s * 0.13, height: s * 0.15))
                    AppTheme.line.setFill()
                    ctx.fillEllipse(in: CGRect(x: x + s * 0.035, y: s * 0.36, width: s * 0.055, height: s * 0.065))
                }
                heroEye(s * 0.33)
                heroEye(s * 0.54)
                let smile = UIBezierPath()
                smile.move(to: CGPoint(x: s * 0.4, y: s * 0.52))
                smile.addQuadCurve(to: CGPoint(x: s * 0.6, y: s * 0.52), controlPoint: CGPoint(x: s * 0.5, y: s * 0.58))
                smile.lineWidth = s * 0.025
                smile.lineCapStyle = .round
                UIColor.white.setStroke()
                smile.stroke()
                AppTheme.line.setStroke()
                let stem = UIBezierPath()
                stem.move(to: CGPoint(x: s * 0.5, y: s * 0.22))
                stem.addLine(to: CGPoint(x: s * 0.5, y: s * 0.08))
                stem.lineWidth = s * 0.045
                stem.lineCapStyle = .round
                stem.stroke()
                AppTheme.coral.setFill()
                let bulb = UIBezierPath(ovalIn: CGRect(x: s * 0.42, y: s * 0.02, width: s * 0.16, height: s * 0.16))
                bulb.fill()
                AppTheme.line.setStroke()
                bulb.lineWidth = s * 0.035
                bulb.stroke()
            case .flag:
                AppTheme.line.setFill()
                UIBezierPath(roundedRect: CGRect(x: s * 0.22, y: s * 0.1, width: s * 0.1, height: s * 0.78), cornerRadius: 4).fill()
                AppTheme.coral.setFill()
                let cloth = UIBezierPath()
                cloth.move(to: CGPoint(x: s * 0.32, y: s * 0.12))
                cloth.addLine(to: CGPoint(x: s * 0.92, y: s * 0.34))
                cloth.addLine(to: CGPoint(x: s * 0.32, y: s * 0.56))
                cloth.close()
                cloth.fill()
                AppTheme.line.setStroke()
                cloth.lineWidth = s * 0.045
                cloth.stroke()
            case .crate:
                crate(in: CGRect(x: s * 0.12, y: s * 0.12, width: s * 0.76, height: s * 0.76), weight: s * 0.05, fill: UIColor(hex: 0xE08A3C))
            case .key:
                key(in: CGRect(x: s * 0.14, y: s * 0.14, width: s * 0.72, height: s * 0.72), weight: s * 0.06, fill: AppTheme.gold)
            case .door, .doorOpen, .lock:
                let open = piece == .doorOpen
                let rect = CGRect(x: s * 0.28, y: s * 0.12, width: open ? s * 0.22 : s * 0.44, height: s * 0.76)
                let gate = UIBezierPath(roundedRect: rect, cornerRadius: s * 0.08)
                (open ? AppTheme.teal.withAlphaComponent(0.35) : AppTheme.line).setFill()
                gate.fill()
                AppTheme.line.setStroke()
                gate.lineWidth = s * 0.045
                gate.stroke()
            case .plate, .plateOn:
                let on = piece == .plateOn
                let base = UIBezierPath(ovalIn: CGRect(x: s * 0.18, y: s * 0.28, width: s * 0.64, height: s * 0.4))
                (on ? AppTheme.gold : UIColor(hex: 0x8E97A8)).setFill()
                base.fill()
                AppTheme.line.setStroke()
                base.lineWidth = s * 0.045
                base.stroke()
                (on ? AppTheme.coral : AppTheme.line).setFill()
                ctx.fillEllipse(in: CGRect(x: s * 0.4, y: s * 0.4, width: s * 0.2, height: s * 0.16))
            }
        }
    }

    static func fitted(_ image: UIImage, side: CGFloat) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.opaque = false
        format.scale = max(image.scale, UITraitCollection.current.displayScale, 3)
        let rendered = UIGraphicsImageRenderer(size: CGSize(width: side, height: side), format: format).image { renderer in
            renderer.cgContext.interpolationQuality = .high
            image.draw(in: CGRect(x: 0, y: 0, width: side, height: side))
        }
        return rendered.withRenderingMode(image.renderingMode)
    }

    private static func canvas(_ key: String, side: CGFloat, draw: (CGContext, CGFloat) -> Void) -> UIImage {
        let name = "\(key)-\(Int(side))" as NSString
        if let cached = cache.object(forKey: name) { return cached }
        let format = UIGraphicsImageRendererFormat()
        format.opaque = false
        let image = UIGraphicsImageRenderer(size: CGSize(width: side, height: side), format: format).image { renderer in
            draw(renderer.cgContext, side)
        }
        cache.setObject(image, forKey: name)
        return image
    }

    private static func roundedTile(_ rect: CGRect, fill: UIColor, radius: CGFloat) {
        let path = UIBezierPath(roundedRect: rect, cornerRadius: radius)
        fill.setFill()
        path.fill()
        AppTheme.line.setStroke()
        path.lineWidth = rect.width * 0.045
        path.stroke()
    }

    private static func starPath(in rect: CGRect) -> UIBezierPath {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let outer = min(rect.width, rect.height) / 2
        let inner = outer * 0.46
        let path = UIBezierPath()
        for index in 0..<10 {
            let angle = -CGFloat.pi / 2 + CGFloat(index) * .pi / 5
            let radius = index.isMultiple(of: 2) ? outer : inner
            let point = CGPoint(x: center.x + cos(angle) * radius, y: center.y + sin(angle) * radius)
            if index == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        path.close()
        return path
    }

    private static func arrow(in rect: CGRect, weight: CGFloat, up: Bool) {
        let path = UIBezierPath()
        let tip = up ? rect.minY : rect.maxY
        let tail = up ? rect.maxY : rect.minY
        let head = up ? tip + rect.height * 0.38 : tip - rect.height * 0.38
        path.move(to: CGPoint(x: rect.midX, y: tail))
        path.addLine(to: CGPoint(x: rect.midX, y: tip))
        path.move(to: CGPoint(x: rect.minX, y: head))
        path.addLine(to: CGPoint(x: rect.midX, y: tip))
        path.addLine(to: CGPoint(x: rect.maxX, y: head))
        path.lineWidth = weight
        path.lineCapStyle = .round
        path.lineJoinStyle = .round
        path.stroke()
    }

    private static func turn(in rect: CGRect, weight: CGFloat, left: Bool) {
        let path = UIBezierPath()
        let corner = CGPoint(x: rect.midX, y: rect.minY + rect.height * 0.34)
        path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: corner)
        let tip = CGPoint(x: left ? rect.minX : rect.maxX, y: corner.y)
        path.addLine(to: tip)
        path.lineWidth = weight
        path.lineCapStyle = .round
        path.lineJoinStyle = .round
        path.stroke()
        let head = UIBezierPath()
        let back = left ? tip.x + rect.width * 0.28 : tip.x - rect.width * 0.28
        head.move(to: CGPoint(x: back, y: tip.y - rect.height * 0.18))
        head.addLine(to: tip)
        head.addLine(to: CGPoint(x: back, y: tip.y + rect.height * 0.18))
        head.lineWidth = weight
        head.lineCapStyle = .round
        head.lineJoinStyle = .round
        head.stroke()
    }

    private static func infinity(in rect: CGRect, weight: CGFloat) {
        let left = UIBezierPath(ovalIn: CGRect(x: rect.minX, y: rect.minY, width: rect.width * 0.52, height: rect.height))
        let right = UIBezierPath(ovalIn: CGRect(x: rect.midX - rect.width * 0.04, y: rect.minY, width: rect.width * 0.52, height: rect.height))
        left.lineWidth = weight
        right.lineWidth = weight
        left.stroke()
        right.stroke()
    }

    private static func key(in rect: CGRect, weight: CGFloat, fill: UIColor = .white) {
        fill.setFill()
        UIColor.white.setStroke()
        let head = UIBezierPath(ovalIn: CGRect(x: rect.minX, y: rect.maxY - rect.height * 0.48, width: rect.width * 0.46, height: rect.height * 0.46))
        head.lineWidth = weight
        head.fill()
        head.stroke()
        let shaft = UIBezierPath()
        shaft.move(to: CGPoint(x: rect.minX + rect.width * 0.4, y: rect.midY))
        shaft.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        shaft.move(to: CGPoint(x: rect.maxX - rect.width * 0.12, y: rect.midY))
        shaft.addLine(to: CGPoint(x: rect.maxX - rect.width * 0.12, y: rect.midY - rect.height * 0.16))
        shaft.lineWidth = weight
        shaft.lineCapStyle = .round
        shaft.stroke()
    }

    private static func lock(in rect: CGRect, weight: CGFloat, open: Bool) {
        let body = UIBezierPath(roundedRect: CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: rect.height * 0.58), cornerRadius: rect.width * 0.12)
        body.lineWidth = weight
        body.stroke()
        let shackle = UIBezierPath()
        shackle.addArc(withCenter: CGPoint(x: rect.midX, y: rect.minY + rect.height * 0.62), radius: rect.width * 0.28, startAngle: .pi, endAngle: 0, clockwise: open)
        shackle.lineWidth = weight
        shackle.lineCapStyle = .round
        shackle.stroke()
    }

    private static func crate(in rect: CGRect, weight: CGFloat, fill: UIColor = .white) {
        let box = UIBezierPath(roundedRect: rect, cornerRadius: rect.width * 0.12)
        fill.setFill()
        box.fill()
        UIColor.white.setStroke()
        box.lineWidth = weight
        box.stroke()
        let band = UIBezierPath()
        band.move(to: CGPoint(x: rect.minX, y: rect.midY))
        band.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        band.move(to: CGPoint(x: rect.midX, y: rect.minY))
        band.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        band.lineWidth = weight
        band.stroke()
    }

    private static func lever(in rect: CGRect, weight: CGFloat) {
        let base = UIBezierPath(roundedRect: CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: rect.height * 0.28), cornerRadius: 6)
        base.lineWidth = weight
        base.stroke()
        let stick = UIBezierPath()
        stick.move(to: CGPoint(x: rect.midX, y: rect.minY + rect.height * 0.28))
        stick.addLine(to: CGPoint(x: rect.midX + rect.width * 0.22, y: rect.maxY))
        stick.lineWidth = weight
        stick.lineCapStyle = .round
        stick.stroke()
        UIBezierPath(ovalIn: CGRect(x: rect.midX + rect.width * 0.1, y: rect.maxY - rect.height * 0.16, width: rect.width * 0.22, height: rect.height * 0.22)).stroke()
    }

    private static func gear(in rect: CGRect, weight: CGFloat) {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let outer = min(rect.width, rect.height) / 2
        let valley = outer * 0.72
        let hole = outer * 0.3
        let teeth = 8
        let path = UIBezierPath()
        for index in 0..<teeth {
            let start = CGFloat(index) / CGFloat(teeth) * .pi * 2 - .pi / 2
            let span = .pi * 2 / CGFloat(teeth)
            func point(_ angle: CGFloat, _ radius: CGFloat) -> CGPoint {
                CGPoint(x: center.x + cos(angle) * radius, y: center.y + sin(angle) * radius)
            }
            let valleyStart = point(start, valley)
            if index == 0 { path.move(to: valleyStart) } else { path.addLine(to: valleyStart) }
            path.addLine(to: point(start + span * 0.28, outer))
            path.addLine(to: point(start + span * 0.72, outer))
            path.addLine(to: point(start + span, valley))
        }
        path.close()
        path.append(UIBezierPath(ovalIn: CGRect(x: center.x - hole, y: center.y - hole, width: hole * 2, height: hole * 2)))
        path.usesEvenOddFillRule = true
        path.fill()
        _ = weight
    }

    private static func bush(at center: CGPoint, radius: CGFloat) {
        UIBezierPath(ovalIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)).fill()
    }
}
