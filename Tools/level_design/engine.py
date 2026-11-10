"""Simulateur et solveur des niveaux Robot Idiot (pack 7.0).

Reproduit les règles de `CatalogInterpreter` et de `WorldRules` :
- la victoire est testée avant chaque instruction ;
- SI et REPETE ne coûtent aucune action, chaque primitive réussie coûte 1 ;
- une primitive impossible arrête l'exécution ;
- REPETE est infini : il ne s'arrête que par victoire, erreur ou cycle détecté.
"""

from __future__ import annotations

from collections import deque
from dataclasses import dataclass, field, replace
from typing import Iterable

HEADINGS = [(0, -1), (1, 0), (0, 1), (-1, 0)]  # N E S W, y vers le bas
ARROWS = {"^": 0, ">": 1, "v": 2, "<": 3}
DIR_NAMES = "NESW"
SOLID = set("BRTO#")
LETHAL = set("WLP")
PRIMITIVES = [
    "AVANCE", "TOURNE_GAUCHE", "TOURNE_DROITE", "RECULE",
    "RAMASSE", "UTILISE", "POUSSE", "ACTIVE",
]
CONDITIONS = {
    "SI_OBSTACLE_DEVANT", "SI_CLE_DEVANT", "SI_CAISSE_DEVANT", "SI_CADENAS_DEVANT",
    "SI_SUR_CERCLE", "SI_SUR_LOSANGE", "OBSTACLE_DEVANT", "CASE_DEVANT_LIBRE",
}


@dataclass(frozen=True)
class State:
    x: int
    y: int
    d: int
    keys: int
    remaining_keys: frozenset
    open_locks: frozenset
    active_links: frozenset
    crates: frozenset
    bolt: bool = False


@dataclass
class Board:
    grid: list[str]
    links: dict  # (x, y) -> linkId for plates and doors
    bolt: tuple | None = None
    requires_key: bool = False
    start: tuple = field(init=False)
    finish: tuple = field(init=False)
    locks: frozenset = field(init=False)
    plates: dict = field(init=False)
    doors: dict = field(init=False)

    def __post_init__(self):
        keys, locks, crates = set(), set(), set()
        self.plates, self.doors = {}, {}
        for y, row in enumerate(self.grid):
            assert len(row) == 7, (y, row)
            for x, c in enumerate(row):
                if c in ARROWS:
                    self.start = (x, y, ARROWS[c])
                elif c == "F":
                    self.finish = (x, y)
                elif c == "K":
                    keys.add((x, y))
                elif c == "U":
                    locks.add((x, y))
                elif c == "C":
                    crates.add((x, y))
                elif c == "A":
                    self.plates[(x, y)] = self.links[(x, y)]
                elif c == "D":
                    self.doors[(x, y)] = self.links[(x, y)]
        assert len(self.grid) == 7
        self.locks = frozenset(locks)
        self._keys = frozenset(keys)
        self._crates = frozenset(crates)

    def tile(self, x, y):
        if not (0 <= x < 7 and 0 <= y < 7):
            return "#"
        return self.grid[y][x]

    def initial(self) -> State:
        x, y, d = self.start
        return State(x, y, d, 0, self._keys, frozenset(), frozenset(), self._crates, False)

    # --- règles -------------------------------------------------------------
    def free(self, s: State, x, y):
        t = self.tile(x, y)
        if t in SOLID or t.isdigit():
            return False
        if (x, y) in self.locks and (x, y) not in s.open_locks:
            return False
        if (x, y) in self.doors and self.doors[(x, y)] not in s.active_links:
            return False
        if (x, y) in s.crates:
            return False
        return True

    def safe(self, s, x, y):
        return self.free(s, x, y) and self.tile(x, y) not in LETHAL

    def won(self, s: State):
        if (s.x, s.y) != self.finish:
            return False
        return s.keys > 0 if self.requires_key else True

    def front(self, s):
        dx, dy = HEADINGS[s.d]
        return s.x + dx, s.y + dy

    def condition(self, name, s: State) -> bool:
        fx, fy = self.front(s)
        if name in ("SI_OBSTACLE_DEVANT", "OBSTACLE_DEVANT"):
            return not self.safe(s, fx, fy)
        if name == "CASE_DEVANT_LIBRE":
            return self.safe(s, fx, fy)
        if name == "SI_CLE_DEVANT":
            return (fx, fy) in s.remaining_keys
        if name == "SI_CAISSE_DEVANT":
            return (fx, fy) in s.crates
        if name == "SI_CADENAS_DEVANT":
            return (fx, fy) in self.locks and (fx, fy) not in s.open_locks
        if name == "SI_SUR_CERCLE":
            return self.tile(s.x, s.y) == "c"
        if name == "SI_SUR_LOSANGE":
            return self.tile(s.x, s.y) == "l"
        raise ValueError(name)

    def step(self, s: State, cmd: str):
        """Retourne l'état suivant, ou None si la primitive est impossible ou mortelle."""
        dx, dy = HEADINGS[s.d]
        fx, fy = s.x + dx, s.y + dy
        if cmd == "TOURNE_GAUCHE":
            return replace(s, d=(s.d + 3) % 4)
        if cmd == "TOURNE_DROITE":
            return replace(s, d=(s.d + 1) % 4)
        if cmd in ("AVANCE", "RECULE"):
            tx, ty = (fx, fy) if cmd == "AVANCE" else (s.x - dx, s.y - dy)
            if not self.free(s, tx, ty) or self.tile(tx, ty) in LETHAL:
                return None
            return self._arrive(replace(s, x=tx, y=ty))
        if cmd == "RAMASSE":
            if (s.x, s.y) not in s.remaining_keys:
                return None
            return replace(s, keys=s.keys + 1, remaining_keys=s.remaining_keys - {(s.x, s.y)})
        if cmd == "UTILISE":
            if (fx, fy) not in self.locks or (fx, fy) in s.open_locks or s.keys == 0:
                return None
            return replace(s, keys=s.keys - 1, open_locks=s.open_locks | {(fx, fy)})
        if cmd == "ACTIVE":
            link = self.plates.get((s.x, s.y))
            if link is None or link in s.active_links:
                return None
            return replace(s, active_links=s.active_links | {link})
        if cmd == "POUSSE":
            if (fx, fy) not in s.crates:
                return None
            bx, by = fx + dx, fy + dy
            if not self.free(s, bx, by) or self.tile(bx, by) in LETHAL:
                return None
            crates = (s.crates - {(fx, fy)}) | {(bx, by)}
            return self._arrive(replace(s, x=fx, y=fy, crates=crates))
        raise ValueError(cmd)

    def _arrive(self, s: State):
        if self.bolt is not None and (s.x, s.y) == self.bolt and not s.bolt:
            return replace(s, bolt=True)
        return s


# --- programmes ---------------------------------------------------------------
# Un programme est une liste de nœuds : "AVANCE", ("REPETE", [...]), ("SI", "COND", [...]).

def blocks(program) -> int:
    total = 0
    for node in program:
        if isinstance(node, str):
            total += 1
        elif node[0] == "REPETE":
            total += 1 + blocks(node[1])
        else:
            total += 1 + blocks(node[2])
    return total


def uses(program, kind) -> bool:
    for node in program:
        if isinstance(node, str):
            continue
        if node[0] == kind:
            return True
        body = node[1] if node[0] == "REPETE" else node[2]
        if uses(body, kind):
            return True
    return False


def conditions_used(program, acc=None):
    acc = set() if acc is None else acc
    for node in program:
        if isinstance(node, str):
            continue
        if node[0] == "SI":
            acc.add(node[1])
            conditions_used(node[2], acc)
        else:
            conditions_used(node[1], acc)
    return acc


def commands_used(program, acc=None):
    acc = set() if acc is None else acc
    for node in program:
        if isinstance(node, str):
            acc.add(node)
        else:
            acc.add(node[0])
            conditions_used  # noqa
            commands_used(node[1] if node[0] == "REPETE" else node[2], acc)
    return acc


def to_json(program):
    out = []
    for node in program:
        if isinstance(node, str):
            out.append({"command": node})
        elif node[0] == "REPETE":
            out.append({"command": "REPETE", "body": to_json(node[1])})
        else:
            out.append({"command": "SI", "condition": node[1], "body": to_json(node[2])})
    return out


def from_json(nodes):
    out = []
    for n in nodes:
        if n["command"] == "REPETE":
            out.append(("REPETE", from_json(n.get("body", []))))
        elif n["command"] == "SI":
            out.append(("SI", n["condition"], from_json(n.get("body", []))))
        else:
            out.append(n["command"])
    return out


@dataclass
class Run:
    result: str  # victory | failure | cycle | end | safety
    actions: int
    state: State
    trace: list
    condition_hits: dict  # condition -> [true count, false count]
    loop_iterations: int  # tours du REPETE le plus externe commencés
    steps: int


def execute(board: Board, program, allowed: Iterable[str] | None = None, max_steps=20_000) -> Run:
    allowed = set(allowed) if allowed is not None else None
    s = board.initial()
    frames = [[program, 0, False, None]]  # instructions, position, is_loop, loop_id
    trace, hits, seen = [], {}, set()
    actions, steps, iterations = 0, 0, 0
    outer_loop = None

    def signature():
        return (s, tuple((f[1], f[2]) for f in frames))

    while frames:
        if board.won(s):
            return Run("victory", actions, s, trace, hits, iterations, steps)
        steps += 1
        if steps > max_steps:
            return Run("safety", actions, s, trace, hits, iterations, steps)
        top = frames[-1]
        if top[1] == len(top[0]):
            if top[2]:
                top[1] = 0
                if top[3] == outer_loop:
                    iterations += 1
            else:
                frames.pop()
            continue
        sig = signature()
        if sig in seen:
            return Run("cycle", actions, s, trace, hits, iterations, steps)
        seen.add(sig)
        node = top[0][top[1]]
        top[1] += 1
        if isinstance(node, str):
            if allowed is not None and node not in allowed:
                return Run("failure", actions, s, trace + [("locked", node)], hits, iterations, steps)
            nxt = board.step(s, node)
            if nxt is None:
                return Run("failure", actions, s, trace + [("invalid", node)], hits, iterations, steps)
            s = nxt
            actions += 1
            trace.append(node)
        elif node[0] == "REPETE":
            if allowed is not None and "REPETE" not in allowed:
                return Run("failure", actions, s, trace + [("locked", "REPETE")], hits, iterations, steps)
            if not node[1]:
                return Run("failure", actions, s, trace + [("empty", "REPETE")], hits, iterations, steps)
            loop_id = id(node)
            if outer_loop is None:
                outer_loop = loop_id
                iterations = 1
            frames.append([node[1], 0, True, loop_id])
        else:
            if allowed is not None and "SI" not in allowed:
                return Run("failure", actions, s, trace + [("locked", "SI")], hits, iterations, steps)
            ok = board.condition(node[1], s)
            counter = hits.setdefault(node[1], [0, 0])
            counter[0 if ok else 1] += 1
            if ok:
                frames.append([node[2], 0, False, None])
    if board.won(s):
        return Run("victory", actions, s, trace, hits, iterations, steps)
    return Run("end", actions, s, trace, hits, iterations, steps)


# --- recherche exhaustive ------------------------------------------------------

def shortest(board: Board, allowed, need_bolt=False, limit=80):
    """BFS exact sur (position, orientation, clés, cadenas, plaques, caisses, écrou)."""
    commands = [c for c in PRIMITIVES if c in allowed]
    start = board.initial()
    if board.won(start) and (start.bolt or not need_bolt):
        return [], 1
    queue = deque([start])
    parent = {start: None}
    while queue:
        cur = queue.popleft()
        for cmd in commands:
            nxt = board.step(cur, cmd)
            if nxt is None or nxt in parent:
                continue
            parent[nxt] = (cur, cmd)
            if board.won(nxt):
                if nxt.bolt or not need_bolt:
                    path = []
                    node = nxt
                    while parent[node] is not None:
                        prev, c = parent[node]
                        path.append(c)
                        node = prev
                    return path[::-1], len(parent)
                continue  # la partie s'arrête au drapeau : état terminal
            queue.append(nxt)
    return None, len(parent)


def natural_shortest(board: Board, allowed, need_bolt=False):
    """Plus court chemin exact ; à égalité, celui qui recule le moins (lecture plus naturelle)."""
    import heapq
    commands = [c for c in PRIMITIVES if c in allowed]
    start = board.initial()
    best = {start: (0, 0)}
    parent = {start: None}
    heap = [(0, 0, 0, start)]
    counter = 1
    while heap:
        a, r, _, cur = heapq.heappop(heap)
        if best.get(cur) != (a, r):
            continue
        if board.won(cur) and (cur.bolt or not need_bolt):
            path, node = [], cur
            while parent[node] is not None:
                prev, c = parent[node]
                path.append(c)
                node = prev
            return path[::-1]
        if board.won(cur):
            continue
        for cmd in commands:
            nxt = board.step(cur, cmd)
            if nxt is None:
                continue
            cost = (a + 1, r + (1 if cmd == "RECULE" else 0))
            if nxt not in best or cost < best[nxt]:
                best[nxt] = cost
                parent[nxt] = (cur, cmd)
                heapq.heappush(heap, (cost[0], cost[1], counter, nxt))
                counter += 1
    return None


ABBREV = {"AVANCE": "A", "TOURNE_GAUCHE": "G", "TOURNE_DROITE": "D", "RECULE": "R",
          "RAMASSE": "K", "UTILISE": "U", "POUSSE": "P", "ACTIVE": "X"}


def reachable_cells(board: Board, allowed):
    commands = [c for c in PRIMITIVES if c in allowed]
    start = board.initial()
    seen = {start}
    queue = deque([start])
    cells = {(start.x, start.y)}
    while queue:
        cur = queue.popleft()
        for cmd in commands:
            nxt = board.step(cur, cmd)
            if nxt is None or nxt in seen:
                continue
            seen.add(nxt)
            cells.add((nxt.x, nxt.y))
            if not board.won(nxt):
                queue.append(nxt)
    return cells


def loop_free_equivalent_exists(board: Board, allowed, max_blocks, max_nodes=3_000_000):
    """Cherche un programme sans SI d'au plus `max_blocks` blocs qui gagne.

    Sans SI, tout programme équivaut à « préfixe P puis REPETE { B } » (un REPETE ne se
    termine jamais, donc la suite est morte ; un REPETE imbriqué revient à allonger P).
    Coût : |P| + 1 + |B| blocs, ou |P| blocs sans boucle.
    Retourne (trouvé, programme, exhaustif).
    """
    prims = [c for c in PRIMITIVES if c in allowed]
    budget = [max_nodes]

    def run_loop(state, body):
        s = state
        seen = set()
        for _ in range(400):
            for i, cmd in enumerate(body):
                if board.won(s):
                    return True
                key = (s, i)
                if key in seen:
                    return False
                seen.add(key)
                s = board.step(s, cmd)
                if s is None:
                    return False
            if board.won(s):
                return True
        return False

    def bodies(state, length):
        # Corps de longueur exacte `length` dont le premier passage reste valide.
        def rec(s, prefix):
            budget[0] -= 1
            if budget[0] < 0:
                raise TimeoutError
            if len(prefix) == length:
                yield list(prefix)
                return
            for cmd in prims:
                if board.won(s):
                    return
                nxt = board.step(s, cmd)
                if nxt is None:
                    continue
                prefix.append(cmd)
                yield from rec(nxt, prefix)
                prefix.pop()
        yield from rec(state, [])

    try:
        def prefixes(s, p, depth):
            budget[0] -= 1
            if budget[0] < 0:
                raise TimeoutError
            if board.won(s):
                return list(p)
            remaining = max_blocks - len(p) - 1
            for blen in range(1, remaining + 1):
                for body in bodies(s, blen):
                    if run_loop(s, body):
                        return list(p) + [("REPETE", body)]
            if len(p) >= max_blocks:
                return None
            for cmd in prims:
                nxt = board.step(s, cmd)
                if nxt is None:
                    continue
                p.append(cmd)
                found = prefixes(nxt, p, depth + 1)
                p.pop()
                if found is not None:
                    return found
            return None

        found = prefixes(board.initial(), [], 0)
        return (found is not None, found, True)
    except TimeoutError:
        return (False, None, False)


def describe_state(board, s):
    return f"({s.x},{s.y}) {DIR_NAMES[s.d]} keys={s.keys}"
