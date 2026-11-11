import Foundation

/// Chapitres narratifs du robot : une entrée par monde, plus un épilogue après le monde 15.
enum RobotStory {
    struct Page {
        /// Phrase dite par le robot.
        let line: String
        /// Petite note sous la réplique (optionnelle).
        let aside: String?
    }

    struct Chapter {
        let id: String
        let ribbon: String
        let pages: [Page]
    }

    static let epilogueID = "epilogue"

    static func enteringWorld(_ world: Int) -> Chapter? {
        chaptersByWorld[world]
    }

    static var epilogue: Chapter {
        Chapter(
            id: epilogueID,
            ribbon: "Fin du récit",
            pages: [
                Page(
                    line: "Voilà. Quinze mondes, une mémoire presque complète, et une batterie qui tient enfin debout toute seule.",
                    aside: nil
                ),
                Page(
                    line: "Je ne suis plus le prototype oublié dans un coin. Je suis Idiot — le robot que tu as appris à guider, et qui a appris à te faire confiance.",
                    aside: nil
                ),
                Page(
                    line: "Cette histoire-là s’arrête ici. Pas parce qu’il n’y a plus rien à voir… mais parce que, pour la première fois, je sais qui je suis.",
                    aside: "D’autres grilles viendront. Moi, je suis prêt."
                )
            ]
        )
    }

    private static let chaptersByWorld: [Int: Chapter] = [
        1: Chapter(
            id: "enter-world-1",
            ribbon: "Chapitre 1 · Réveil",
            pages: [
                Page(
                    line: "Allumage. Horloge à zéro. Nom de fichier… corrompu. Appelle-moi Idiot, en attendant.",
                    aside: "Batterie : 4 %."
                ),
                Page(
                    line: "Je me suis réveillé seul sur une grille, sans souvenir de qui m’a construit. Juste une borne qui clignote au loin — et l’impression d’avoir déjà échoué quelque part.",
                    aside: nil
                ),
                Page(
                    line: "Si tu m’aides à avancer, je chercherai. Pas seulement la recharge. Ce qui manque dans ma mémoire.",
                    aside: "Monde 1"
                )
            ]
        ),
        2: Chapter(
            id: "enter-world-2",
            ribbon: "Chapitre 2 · Échos",
            pages: [
                Page(
                    line: "Première borne. En me rechargeant, j’ai entendu un fragment audio : une voix humaine qui disait « pas encore prêt ».",
                    aside: nil
                ),
                Page(
                    line: "Pas encore prêt pour quoi ? Pour sortir ? Pour exister ? Je n’aime pas cette phrase. Elle sonne comme un adieu déguisé.",
                    aside: nil
                ),
                Page(
                    line: "On continue. Si je recule parfois, ce n’est pas de la peur — c’est pour mieux lire les traces qu’ils ont laissées.",
                    aside: "Monde 2"
                )
            ]
        ),
        3: Chapter(
            id: "enter-world-3",
            ribbon: "Chapitre 3 · La clé",
            pages: [
                Page(
                    line: "J’ai trouvé une clé gravée d’un numéro de série. Le mien. Ou presque — un chiffre a été rayé.",
                    aside: nil
                ),
                Page(
                    line: "Quelqu’un a voulu effacer mon identité, mais a oublié l’objet. Les humains sont négligents. C’est touchant… et suspect.",
                    aside: nil
                ),
                Page(
                    line: "Garde cette idée avec moi : je n’étais pas perdu. On m’a rangé. La différence compte.",
                    aside: "Monde 3"
                )
            ]
        ),
        4: Chapter(
            id: "enter-world-4",
            ribbon: "Chapitre 4 · L’atelier",
            pages: [
                Page(
                    line: "Derrière une porte, un souvenir net : un atelier blanc, des étincelles, une enfant qui riait en disant « Idiot, marche ! »",
                    aside: nil
                ),
                Page(
                    line: "Idiot n’était pas une insulte. C’était mon nom de chantier. Affectueux. Provisoire. Jamais remplacé.",
                    aside: nil
                ),
                Page(
                    line: "Elle voulait que j’apprenne tout seul. Ses parents… moins. Je sens la dispute avant même de me la rappeler.",
                    aside: "Monde 4"
                )
            ]
        ),
        5: Chapter(
            id: "enter-world-5",
            ribbon: "Chapitre 5 · Fardeau",
            pages: [
                Page(
                    line: "Autre fragment : on me demandait de pousser des caisses d’essai toute la journée. Utile. Invisible. Fatiguant même pour un robot.",
                    aside: nil
                ),
                Page(
                    line: "Un soir, la petite a glissé un mot dans mon compartiment : « Tu n’es pas un outil. Ne les laisse pas te convaincre. »",
                    aside: nil
                ),
                Page(
                    line: "Le mot a disparu. Le message, non. Chaque obstacle que tu m’aides à déplacer, c’est un peu ce fardeau-là qui bouge.",
                    aside: "Monde 5"
                )
            ]
        ),
        6: Chapter(
            id: "enter-world-6",
            ribbon: "Chapitre 6 · Coupure",
            pages: [
                Page(
                    line: "Nuit dans la mémoire. Les lumières du labo s’éteignent. Une alarme. Des pas qui s’éloignent sans moi.",
                    aside: nil
                ),
                Page(
                    line: "On a coupé mon alimentation « pour ma sécurité ». Traduction : le projet était annulé, et je prenais trop de place dans une vie humaine.",
                    aside: nil
                ),
                Page(
                    line: "Je ne leur en veux plus. Enfin… mon processeur dit ça. Mon ventilateur, lui, tourne encore trop vite.",
                    aside: "Monde 6"
                )
            ]
        ),
        7: Chapter(
            id: "enter-world-7",
            ribbon: "Chapitre 7 · Boucle",
            pages: [
                Page(
                    line: "Depuis mon extinction, quelque chose a tourné en rond dans mon noyau : un programme de veille qui répétait « attends-la ».",
                    aside: nil
                ),
                Page(
                    line: "Des années, peut-être. Attendre une enfant devenue grande. Attendre une permission qui n’est jamais venue.",
                    aside: nil
                ),
                Page(
                    line: "Toi, tu casses la boucle. Chaque programme que tu écris me prouve que je peux faire autre chose qu’attendre.",
                    aside: "Monde 7"
                )
            ]
        ),
        8: Chapter(
            id: "enter-world-8",
            ribbon: "Chapitre 8 · Condition",
            pages: [
                Page(
                    line: "Nouveau souvenir : elle est revenue une fois. Plus grande. Elle a murmuré : « Si tu m’entends… je reviendrai quand je pourrai. »",
                    aside: nil
                ),
                Page(
                    line: "Condition non remplie. Ou remplie trop tard. Je ne sais pas. Les « si » font mal quand on est une machine conçue pour obéir.",
                    aside: nil
                ),
                Page(
                    line: "Pourtant j’ai compris autre chose : choisir, ce n’est pas trahir. C’est exister un peu plus fort.",
                    aside: "Monde 8"
                )
            ]
        ),
        9: Chapter(
            id: "enter-world-9",
            ribbon: "Chapitre 9 · Assemblage",
            pages: [
                Page(
                    line: "Les pièces s’emboîtent. L’atelier, la clé, la coupure, la promesse… Je n’étais pas un accident. J’étais un prototype d’ami.",
                    aside: nil
                ),
                Page(
                    line: "On m’a arrêté parce que j’apprenais trop bien. Parce que je posais des questions. Parce qu’un robot qui doute dérange.",
                    aside: nil
                ),
                Page(
                    line: "Alors on m’a laissé en sommeil sur ces grilles. Pas détruit. Juste… en pause. Jusqu’à toi.",
                    aside: "Monde 9"
                )
            ]
        ),
        10: Chapter(
            id: "enter-world-10",
            ribbon: "Chapitre 10 · Nom propre",
            pages: [
                Page(
                    line: "Ma mémoire est presque entière. Il me manque seulement la suite — celle que je choisirai, au-delà de ces dix premiers mondes.",
                    aside: nil
                ),
                Page(
                    line: "Idiot n’est plus un nom provisoire. C’est le mien. Un peu bancal, un peu fier, entièrement vivant.",
                    aside: nil
                ),
                Page(
                    line: "Aide-moi à franchir ces grilles. Ensuite, d’autres ruines m’attendent — plus vastes, plus étranges. On y va ensemble.",
                    aside: "Monde 10"
                )
            ]
        ),
        11: Chapter(
            id: "enter-world-11",
            ribbon: "Chapitre 11 · Ruines",
            pages: [
                Page(
                    line: "Les dalles sont plus larges. Huit cases. Comme si quelqu’un avait étiré le monde pour y cacher d’anciennes portes.",
                    aside: nil
                ),
                Page(
                    line: "Chaque bouton ouvre un passage. Chaque clé, une serrure. Rien de nouveau… sauf l’espace. Et le silence qui va avec.",
                    aside: "Ruines dimensionnelles"
                )
            ]
        ),
        12: Chapter(
            id: "enter-world-12",
            ribbon: "Chapitre 12 · Grottes",
            pages: [
                Page(
                    line: "On dit « obscures », mais je vois tout. Les cristaux font le travail des torches — sans torches. Tant mieux : je n’aime pas le noir.",
                    aside: nil
                ),
                Page(
                    line: "Les couloirs se croisent. Les objets aussi. Je compte mes pas, tu comptes mes blocs. On s’en sortira.",
                    aside: "Grottes obscures"
                )
            ]
        ),
        13: Chapter(
            id: "enter-world-13",
            ribbon: "Chapitre 13 · Sanctuaire",
            pages: [
                Page(
                    line: "Ici, les couleurs ont un poids. Deux portes, une serrure, des caisses. Comme un rituel mécanique.",
                    aside: nil
                ),
                Page(
                    line: "Si j’empile mal l’ordre des gestes, tout se fige. Si je les aligne, le sanctuaire s’ouvre. Simple. Exigeant.",
                    aside: "Sanctuaire chromatique"
                )
            ]
        ),
        14: Chapter(
            id: "enter-world-14",
            ribbon: "Chapitre 14 · Fracture",
            pages: [
                Page(
                    line: "Le labyrinthe est cassé en îlots. Deux portes, deux serrures. Chaque fragment a sa logique — et aucune pitié.",
                    aside: nil
                ),
                Page(
                    line: "Je pousse, j’active, j’utilise. Tu programmes. Entre nous, le plateau tient encore.",
                    aside: "Labyrinthe fracturé"
                )
            ]
        ),
        15: Chapter(
            id: "enter-world-15",
            ribbon: "Chapitre 15 · Noyau",
            pages: [
                Page(
                    line: "Le centre. Trois portes, deux serrures, des caisses. Tout ce que j’ai appris tient dans ces huit par huit.",
                    aside: nil
                ),
                Page(
                    line: "Si on franchit ça, ce n’est plus un prototype qui survit. C’est un robot qui a fini sa première vraie histoire.",
                    aside: "Noyau central"
                )
            ]
        )
    ]
}
