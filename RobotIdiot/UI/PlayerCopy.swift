import Foundation
import RobotIdiotCore

enum PlaybackTempo {
    case normal
    case fast

    var title: String {
        switch self {
        case .normal: return "Normale"
        case .fast: return "Rapide"
        }
    }

    func moveDuration(reduceMotion: Bool) -> TimeInterval {
        if reduceMotion { return 0.01 }
        switch self {
        case .normal: return 0.34
        case .fast: return 0.1
        }
    }

    func turnDuration(reduceMotion: Bool) -> TimeInterval {
        if reduceMotion { return 0.01 }
        switch self {
        case .normal: return 0.24
        case .fast: return 0.08
        }
    }

    var toggled: PlaybackTempo {
        switch self {
        case .normal: return .fast
        case .fast: return .normal
        }
    }
}

enum PlayerCopy {
    static func commandTitle(_ command: CommandType) -> String {
        switch command {
        case .moveForward: return "Avance"
        case .moveBackward: return "Recule"
        case .turnLeft: return "Tourne à gauche"
        case .turnRight: return "Tourne à droite"
        case .pickUp: return "Ramasse"
        case .use: return "Utilise"
        case .push: return "Pousse"
        case .activate: return "Active"
        case .forever: return "Répète"
        case .ifBlock: return "Si"
        }
    }

    static func commandShortTitle(_ command: CommandType) -> String {
        switch command {
        case .moveForward: return "Avance"
        case .moveBackward: return "Recule"
        case .turnLeft: return "Gauche"
        case .turnRight: return "Droite"
        case .pickUp: return "Ramasse"
        case .use: return "Utilise"
        case .push: return "Pousse"
        case .activate: return "Active"
        case .forever: return "Répète"
        case .ifBlock: return "Si"
        }
    }

    static func commandSymbol(_ command: CommandType) -> String {
        switch command {
        case .moveForward: return "arrow.up"
        case .moveBackward: return "arrow.down"
        case .turnLeft: return "arrow.counterclockwise"
        case .turnRight: return "arrow.clockwise"
        case .pickUp: return "key.fill"
        case .use: return "lock.open"
        case .push: return "shippingbox"
        case .activate: return "switch.2"
        case .forever: return "infinity"
        case .ifBlock: return "questionmark.diamond"
        }
    }

    static func directionPhrase(_ direction: Direction) -> String {
        switch direction {
        case .north: return "le haut"
        case .east: return "la droite"
        case .south: return "le bas"
        case .west: return "la gauche"
        }
    }

    static func conditionTitle(_ condition: ConditionType) -> String {
        switch condition {
        case .obstacleAhead: return "obstacle devant"
        case .cellAheadFree: return "case devant libre"
        case .objectPresent: return "objet ici"
        case .doorClosed: return "porte fermée"
        case .switchActivated: return "interrupteur activé"
        case .carryingItem: return "transporte un objet"
        }
    }

    static func executionAlert(for fault: ExecutionFault?, game: GameState) -> (headline: String, detail: String) {
        guard let fault else {
            return (
                "Presque…",
                "Programme fini, drapeau toujours au loin. « J'ai suivi le plan. Le plan, lui, m'a lâché. »"
            )
        }
        switch fault {
        case .pathBlocked(_, _, let forward, let attempted):
            let cell = game.grid.cell(at: attempted)
            let obstacle: String
            if cell?.containsCrate == true {
                obstacle = "une caisse"
            } else if cell?.containsClosedDoor == true {
                obstacle = "une porte"
            } else {
                switch cell?.terrain {
                case .bush:
                    obstacle = "un buisson"
                case .spikes:
                    obstacle = "des pics"
                case .water:
                    obstacle = "de l'eau"
                case .lava:
                    obstacle = "de la lave"
                default:
                    obstacle = "un mur"
                }
            }
            if forward {
                return (
                    "Aïe, mur !",
                    "Bloqué par \(obstacle). « Je suis solide… mais pas à ce point. »"
                )
            }
            return (
                "Reculons… ou pas",
                "Impossible de reculer : \(obstacle). « Marche arrière non garantie. »"
            )
        case .hazard(_, _, let terrain, _):
            switch terrain {
            case .spikes:
                return (
                    "Ouille les pics !",
                    "Tu as marché sur des pics. « Note pour plus tard : les pointes, c'est non. »"
                )
            case .water:
                return (
                    "Plouf !",
                    "Direction l'eau. « Je savais nager… en théorie. »"
                )
            case .lava:
                return (
                    "Trop chaud !",
                    "La lave a gagné ce round. « Je préfère les prises USB. »"
                )
            default:
                return (
                    "Zone interdite",
                    "Danger touché. « On dit que j'apprends vite. Prouvons-le. »"
                )
            }
        case .commandUnavailable:
            return (
                "Pas cette commande",
                "Elle n'est pas débloquée ici. « Même moi, j'ai des limites. »"
            )
        case .nothingToPickUp:
            return (
                "Les mains vides",
                "Rien à ramasser. « Je cueille du vent, maintenant ? »"
            )
        case .nothingToUse:
            return (
                "Rien en stock",
                "Pas d'objet à utiliser. « Les poches sont en mode minimaliste. »"
            )
        case .incompatibleUse:
            return (
                "Mauvais outil",
                "Ça ne marche pas ici. « Clé dans le trou… sauf que non. »"
            )
        case .nothingToPush:
            return (
                "Poussée dans le vide",
                "Rien devant à pousser. « Je pousse l'air. L'air résiste mal. »"
            )
        case .pushBlocked:
            return (
                "Caisse coincée",
                "Elle ne peut pas aller plus loin. « Même les caisses ont leurs limites. »"
            )
        case .nothingToActivate:
            return (
                "Rien à activer",
                "Pas d'interrupteur ici. « J'ai appuyé sur… l'imaginaire. »"
            )
        case .missingCondition:
            return (
                "Si… quoi ?",
                "Ce Si n'a pas de condition. « Même moi, j'ai besoin d'un pourquoi. »"
            )
        case .cycle:
            return (
                "Déjà-vu",
                "Les mêmes gestes en boucle. « On tourne en rond, littéralement. »"
            )
        case .safetyStop:
            return (
                "Pause sécurité",
                "Arrêt automatique. « Mieux vaut freiner que fondre. »"
            )
        }
    }

    /// Petite vanne du robot selon le score d'étoiles.
    static func victoryQuip(rating: StarRating) -> String {
        switch rating.count {
        case 3:
            return "Triple étoile ! « Je brille plus que ma batterie. »"
        case 2:
            return "Deux étoiles. « Presque parfait… et déjà trop fier. »"
        default:
            return "Drapeau capturé ! « La suite peut attendre une microseconde. »"
        }
    }

    static func explain(_ fault: ExecutionFault) -> String {
        switch fault {
        case .pathBlocked(_, _, let forward, _):
            if forward {
                return "Le robot ne peut pas avancer : la case devant lui est bloquée."
            }
            return "Le robot ne peut pas reculer : la case derrière lui est bloquée."
        case .hazard(_, _, let terrain, _):
            switch terrain {
            case .spikes:
                return "Le robot a marché sur des pics."
            case .water:
                return "Le robot a coulé dans l'eau."
            case .lava:
                return "Le robot a coulé dans la lave."
            default:
                return "Le robot a marché sur un danger."
            }
        case .commandUnavailable:
            return "Cette commande n'est pas disponible dans ce niveau."
        case .nothingToPickUp:
            return "Il n'y a rien à ramasser ici."
        case .nothingToUse:
            return "Le robot n'a rien dans les mains."
        case .incompatibleUse:
            return "Cet objet ne marche pas ici."
        case .nothingToPush:
            return "Il n'y a rien à pousser devant le robot."
        case .pushBlocked:
            return "La caisse ne peut pas aller plus loin."
        case .nothingToActivate:
            return "Il n'y a pas d'interrupteur à activer."
        case .missingCondition:
            return "Ce Si n'a pas de condition."
        case .cycle:
            return "Le robot recommence exactement les mêmes gestes."
        case .safetyStop:
            return "Le robot a été arrêté par sécurité."
        }
    }

    static func explain(_ issue: ProgramIssue) -> String {
        switch issue {
        case .commandNotAllowed:
            return "Cette commande n'est pas disponible dans ce niveau."
        case .leafHasChildren:
            return "Seuls Répète et Si peuvent contenir d'autres commandes."
        case .missingCondition:
            return "Ce Si n'a pas de condition."
        case .unexpectedCondition:
            return "Seule la commande Si a une condition."
        case .emptyForever:
            return "Répète doit contenir au moins une commande."
        case .nestingTooDeep:
            return "Ce bloc est déjà au plus profond autorisé."
        case .tooManyBlocks(let limit):
            return limit <= 1 ? "Ce niveau autorise \(limit) bloc." : "Ce niveau autorise \(limit) blocs."
        }
    }

    static func title(for level: Level) -> String {
        if level.id.hasPrefix("RI-") {
            return "Monde \(level.worldNumber) · Niveau \(level.levelNumber)"
        }
        if level.id.hasPrefix("gen-") {
            return "Graine \(level.seed)"
        }
        switch level.id {
        case PrototypeLevel.firstSteps.id: return "Premier pas"
        case PrototypeLevel.corridor.id: return "La boucle"
        case PrototypeLevel.corner.id: return "Le coin"
        default: return "Niveau \(level.levelNumber)"
        }
    }

    static func listTitle(for level: Level) -> String {
        "Niveau \(level.levelNumber) · \(title(for: level))"
    }

    static func limits(for level: Level) -> String {
        let blocks: String
        if let maxBlocks = level.programConstraints.maxBlocks {
            blocks = maxBlocks <= 1 ? "\(maxBlocks) commande max" : "\(maxBlocks) commandes max"
        } else {
            blocks = "Commandes libres"
        }
        let depth = level.programConstraints.maxNestingDepth
        let nesting = depth <= 1 ? "sans imbrication" : "imbrication \(depth)"
        return [blocks, nesting].joined(separator: " · ")
    }

    static func briefing(for level: Level) -> String {
        if level.id.hasPrefix("RI-") {
            if level.validation.notes.contains("hold_key") {
                return "Ramasse la clé, puis atteins le drapeau en la gardant."
            }
            switch level.validation.notes.first {
            case "key_door":
                return "Ramasse la clé sur sa case, puis utilise-la face à la porte verrouillée."
            case "crate_and_key_door":
                return "Pousse la caisse si besoin, ramasse la clé, puis ouvre la porte."
            case "switch_gate", "switch_plus_existing":
                return "Active l'interrupteur en te tenant dessus. La grille s'ouvre et reste ouverte."
            case "push_crate":
                return "Pousse la caisse : elle avance d'une case, et le robot prend sa place."
            case "loop_plus_existing", "infinite_loop_navigation":
                return "Atteins le drapeau. Tu peux utiliser une boucle infinie."
            case "condition_loop_plus_existing", "infinite_loop_with_condition":
                return "Atteins le drapeau. Combine boucle et condition si tu en as besoin."
            case "integrated_advanced", "integrated_mastery":
                return "Combine tout ce que tu as appris pour atteindre le drapeau."
            case "navigation_backwards":
                return "Atteins le drapeau. Tu peux aussi reculer sans changer de direction."
            case "collect_key":
                return "Ramasse la clé, puis atteins le drapeau en la gardant."
            default:
                return "Atteins le drapeau."
            }
        }
        if level.id.hasPrefix("gen-") {
            if level.allowedCommands.contains(.push) {
                return "Pousse la caisse pour dégager le chemin jusqu'au drapeau."
            }
            if level.allowedCommands.contains(.activate) {
                return "Active l'interrupteur pour ouvrir la porte."
            }
            if level.allowedCommands.contains(.pickUp) {
                return "Ramasse la clé, puis utilise-la devant la porte."
            }
            if level.allowedCommands.contains(.ifBlock) {
                return "Atteins le drapeau. Si ne s'exécute que lorsque sa condition est vraie."
            }
            if level.allowedCommands.contains(.forever) {
                return "Atteins le drapeau. Répète tourne sans fin."
            }
            return "Atteins le drapeau."
        }
        switch level.id {
        case PrototypeLevel.corridor.id:
            return "Cinq cases, deux blocs. Une boucle suffit."
        case PrototypeLevel.corner.id:
            return "Le chemin tourne. Teste l'obstacle devant."
        default:
            return "Atteins le drapeau."
        }
    }

    static func ready(direction: Direction) -> String {
        "Prêt. Le robot regarde vers \(directionPhrase(direction))."
    }

    static func blockCount(_ count: Int) -> String {
        count <= 1 ? "\(count) bloc" : "\(count) blocs"
    }

    static func actionCount(_ count: Int) -> String {
        count <= 1 ? "\(count) action exécutée" : "\(count) actions exécutées"
    }

    static func improvement(rating: StarRating, rules: ScoringRules, bonusCollected: Bool = false) -> String {
        let tip: String
        if let steps = rules.efficientLimit(bonusCollected: bonusCollected), rules.compactProgramMaxBlocks == nil {
            if rating.efficientExecution {
                tip = bonusCollected
                    ? "Minimum d'actions avec l'écrou."
                    : "Tu as atteint le minimum d'actions."
            } else {
                let word = steps > 1 ? "actions" : "action"
                tip = "Trois étoiles : au plus \(steps) \(word)."
            }
        } else if rating.count == 3 {
            tip = "Tu as atteint la solution de référence."
        } else {
            tip = rules.referenceNote + " Tu peux encore simplifier ton programme."
        }
        return "\(victoryQuip(rating: rating)) \(tip)"
    }

    /// Les premières commandes d'une solution optimale, sans donner toute la suite.
    static func openingHint(commands: [CommandType]) -> String {
        let count = commands.count <= 2 ? 1 : 3
        let names = commands.prefix(count).map(commandShortTitle)
        guard let first = names.first else {
            return "Atteins le drapeau."
        }
        if names.count == 1 {
            return "Commence par \(first)."
        }
        let lead = names.dropLast().joined(separator: ", ")
        return "Commence par \(lead), puis \(names[names.count - 1])."
    }

    static func boardSummary(robot: RobotState) -> String {
        var text = "Plateau vu du dessus. Le robot regarde vers \(directionPhrase(robot.orientation))."
        if robot.inventory.contains(where: { $0.kind == ObjectKind.key }) {
            text += " Il transporte une clé."
        }
        return text
    }

    static func worldTitle(_ world: Int) -> String {
        "Monde \(world)"
    }

    static func themeName(_ theme: ThemeIdentifier) -> String {
        switch theme {
        case .orchard: return "Verger"
        case .night: return "Nuit"
        case .foundry: return "Fonderie"
        default: return "Laboratoire"
        }
    }

    static func mechanicTitle(_ families: [PuzzleFamily]) -> String {
        let keys = families.contains(.keyDoor)
        let plates = families.contains(.switchDoor)
        let crates = families.contains(.cratePush)
        switch (keys, plates, crates) {
        case (true, false, false):
            return "Clés"
        case (true, true, false):
            return "Portes"
        case (false, true, false):
            return "Interrupteurs"
        case (false, false, true), (false, true, true):
            return "Caisses"
        case (true, _, true):
            return "Mécanismes"
        default:
            if families.contains(.wallFollow) { return "Conditions" }
            if families.contains(.infiniteCorridor) { return "Boucles" }
            return "Déplacements"
        }
    }

    static func levelSlotTitle(level: Int, finale: Bool) -> String {
        finale ? "Niveau final" : "Niveau \(level)"
    }

    static func paceTitle(_ pace: LevelPace) -> String {
        switch pace {
        case .accessible: return "Accessible"
        case .intermediate: return "Intermédiaire"
        case .demanding: return "Exigeant"
        }
    }

    static func starCount(_ stars: Int) -> String {
        stars <= 1 ? "\(stars) étoile" : "\(stars) étoiles"
    }

    static func campaignTitle(_ address: LevelAddress) -> String {
        let slot = levelSlotTitle(level: address.level, finale: CatalogCampaign.layout.isFinale(address.level))
        return "\(worldTitle(address.world)) · \(slot)"
    }

    static func continueTitle(hasProgress: Bool, address: LevelAddress) -> String {
        guard hasProgress else { return "Commencer" }
        return "Continuer · \(campaignTitle(address))"
    }

}
