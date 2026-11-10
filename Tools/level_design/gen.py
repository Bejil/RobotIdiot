"""Labyrinthes parfaits 4×4 nœuds étendus en 7×7 (nœuds aux coordonnées paires)."""

import random
from collections import deque

WALLS = "BORT"


def maze(seed, wall_mix=WALLS, lethal_ratio=0.0, algorithm="kruskal"):
    rng = random.Random(seed)
    open_cells = set()
    if algorithm == "dfs":
        seen = {(0, 0)}
        stack = [(0, 0)]
        while stack:
            cx, cy = stack[-1]
            options = [(cx + dx, cy + dy) for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))
                       if 0 <= cx + dx < 4 and 0 <= cy + dy < 4 and (cx + dx, cy + dy) not in seen]
            if not options:
                stack.pop()
                continue
            nx, ny = rng.choice(options)
            seen.add((nx, ny))
            open_cells.add((cx * 2 + (nx - cx), cy * 2 + (ny - cy)))
            stack.append((nx, ny))
    else:
        parent = {(x, y): (x, y) for x in range(4) for y in range(4)}

        def find(a):
            while parent[a] != a:
                parent[a] = parent[parent[a]]
                a = parent[a]
            return a

        edges = [((x, y), (x + 1, y)) for x in range(3) for y in range(4)]
        edges += [((x, y), (x, y + 1)) for x in range(4) for y in range(3)]
        rng.shuffle(edges)
        for a, b in edges:
            ra, rb = find(a), find(b)
            if ra != rb:
                parent[ra] = rb
                open_cells.add((a[0] + b[0], a[1] + b[1]))
    for x in range(4):
        for y in range(4):
            open_cells.add((x * 2, y * 2))
    rows = []
    for y in range(7):
        row = ""
        for x in range(7):
            if (x, y) in open_cells:
                row += "g"
            elif rng.random() < lethal_ratio:
                row += rng.choice("WLP")
            else:
                row += rng.choice(wall_mix)
        rows.append(row)
    return rows, open_cells


def neighbours(cells, x, y):
    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
        if (x + dx, y + dy) in cells:
            yield (x + dx, y + dy)


def bfs_path(cells, a, b):
    prev = {a: None}
    q = deque([a])
    while q:
        c = q.popleft()
        if c == b:
            break
        for n in neighbours(cells, *c):
            if n not in prev:
                prev[n] = c
                q.append(n)
    path, c = [], b
    while c is not None:
        path.append(c)
        c = prev[c]
    return path[::-1]


def dead_ends(cells):
    return [c for c in cells if len(list(neighbours(cells, *c))) == 1]


def put(rows, x, y, ch):
    r = list(rows[y])
    r[x] = ch
    rows[y] = "".join(r)


def turns_along(path):
    """Cases où le chemin change de direction, avec le sens du virage (G ou D), y vers le bas."""
    out = []
    for i in range(1, len(path) - 1):
        d1 = (path[i][0] - path[i - 1][0], path[i][1] - path[i - 1][1])
        d2 = (path[i + 1][0] - path[i][0], path[i + 1][1] - path[i][1])
        if d1 != d2:
            cross = d1[0] * d2[1] - d1[1] * d2[0]
            out.append((path[i], "D" if cross > 0 else "G"))
    return out


def arrow_for(a, b):
    d = (b[0] - a[0], b[1] - a[1])
    return {(0, -1): "^", (1, 0): ">", (0, 1): "v", (-1, 0): "<"}[d]
