"""Analyse rapide d'un niveau en cours de conception (usage : import + show())."""

from engine import (Board, execute, shortest, natural_shortest, blocks, reachable_cells,
                    loop_free_equivalent_exists, ABBREV)

BASE = ["AVANCE", "TOURNE_GAUCHE", "TOURNE_DROITE", "RECULE", "RAMASSE", "UTILISE", "POUSSE", "ACTIVE"]


def board_of(spec):
    links = {}
    for (x, y, link) in spec.get("links", []):
        links[(x, y)] = link
    bolt = tuple(spec["bolt"]) if spec.get("bolt") else None
    return Board(spec["grid"], links, bolt, spec.get("requiresKey", False))


def cells_of(board, path):
    s = board.initial()
    cells = [(s.x, s.y)]
    for c in path:
        s = board.step(s, c)
        cells.append((s.x, s.y))
    return cells


def overlay(board, cells):
    rows = [list(r) for r in board.grid]
    for (x, y) in cells:
        if rows[y][x] == "g":
            rows[y][x] = "·"
    return ["".join(r) for r in rows]


def short(path):
    return " ".join(ABBREV[c] for c in path)


def show(spec, deep=False):
    b = board_of(spec)
    allowed = spec["allowed"]
    path = natural_shortest(b, allowed)
    print(f"== {spec['id']} ==")
    print("optimum sans bonus:", len(path) if path is not None else None)
    if path:
        print("   chemin:", short(path))
        for raw, r in zip(b.grid, overlay(b, cells_of(b, path))):
            print("   ", raw, "  ", r)
    if b.bolt:
        bpath = natural_shortest(b, allowed, need_bolt=True)
        print("optimum avec bonus:", len(bpath) if bpath is not None else None)
        if bpath:
            print("   chemin:", short(bpath))
    for key in ("program", "bonusProgram"):
        if key not in spec:
            continue
        run = execute(b, spec[key], allowed)
        print(f"{key}: {run.result} actions={run.actions} blocs={blocks(spec[key])} tours={run.loop_iterations} "
              f"bolt={run.state.bolt} conds={run.condition_hits}")
        if run.result != "victory":
            print("   trace:", run.trace[-6:], "état", run.state)
    reach = reachable_cells(b, allowed)
    markers = [(x, y) for y, r in enumerate(b.grid) for x, c in enumerate(r) if c in "cl"]
    unreachable = [m for m in markers if m not in reach]
    if unreachable:
        print("balises inaccessibles:", unreachable)
    if deep and spec.get("maxBlocks"):
        found, prog, exhaustive = loop_free_equivalent_exists(b, allowed, spec["maxBlocks"])
        print("programme sans SI ≤ maxBlocks:", found, prog, "exhaustif" if exhaustive else "budget dépassé")
    return b
