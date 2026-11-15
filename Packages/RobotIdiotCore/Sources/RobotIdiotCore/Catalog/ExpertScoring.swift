import Foundation

/// Score Mode Expert : nombre de blocs AST écrits (une fois), pas les actions exécutées.
public enum ExpertScoring {
    /// Compte chaque nœud du programme une seule fois (REPETE/SI + enfants inclus).
    public static func countWrittenBlocks(_ program: Program) -> Int {
        program.instructions.reduce(0) { $0 + $1.nodeCount }
    }

    /// 3★ si ≤ threeStarsMax, 2★ si ≤ twoStarsMax, sinon 1★ pour toute victoire.
    public static func rating(
        writtenBlocks: Int,
        threeStarsMax: Int,
        twoStarsMax: Int
    ) -> StarRating {
        if writtenBlocks <= threeStarsMax {
            return StarRating(completion: true, compactProgram: true, efficientExecution: true)
        }
        if writtenBlocks <= twoStarsMax {
            return StarRating(completion: true, compactProgram: true, efficientExecution: false)
        }
        return StarRating(completion: true, compactProgram: false, efficientExecution: false)
    }
}
