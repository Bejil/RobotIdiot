"""Outils de conception : grilles depuis un labyrinthe, programmes plats annotés de SI."""

from gen import maze, put
from engine import Board


def grid_from(seed, start, finish, edits=(), lethal_ratio=0.0):
    rows, _ = maze(seed, lethal_ratio=lethal_ratio)
    x, y, arrow = start
    put(rows, x, y, arrow)
    put(rows, finish[0], finish[1], "F")
    for (ex, ey, ch) in edits:
        put(rows, ex, ey, ch)
    return rows


def wrap_flat(board: Board, path, rules):
    """Rejoue `path` et regroupe des actions dans des SI quand la condition est vraie.

    `rules` : liste de (condition, motif) où motif est une liste de commandes. À chaque
    position, si la condition est vraie et que le chemin continue par le motif, on émet
    ("SI", condition, motif).
    """
    out = []
    s = board.initial()
    i = 0
    while i < len(path):
        emitted = False
        for rule in rules:
            if rule[0] == "nest":
                # ("nest", cond, turn, inner_cond, inner_motif) → SI cond { turn ; SI inner { motif } }
                _, cond, turn, inner, motif = rule
                if path[i:i + 1 + len(motif)] == [turn] + motif and board.condition(cond, s):
                    after_turn = board.step(s, turn)
                    if board.condition(inner, after_turn):
                        out.append(("SI", cond, [turn, ("SI", inner, list(motif))]))
                        s = after_turn
                        for c in motif:
                            s = board.step(s, c)
                        i += 1 + len(motif)
                        emitted = True
                        break
                continue
            cond, motif = rule
            if path[i:i + len(motif)] == motif and board.condition(cond, s):
                out.append(("SI", cond, list(motif)))
                for c in motif:
                    s = board.step(s, c)
                i += len(motif)
                emitted = True
                break
        if not emitted:
            out.append(path[i])
            s = board.step(s, path[i])
            i += 1
    return out
