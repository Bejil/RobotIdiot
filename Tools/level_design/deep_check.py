"""Preuve « aucune solution sans SI dans la limite de blocs » pour les niveaux à maxBlocks.

Sans SI, un programme vaut « préfixe P puis REPETE { B } » et coûte |P| + 1 + |B| blocs
(ou |P| blocs sans boucle, impossible puisque maxBlocks < optimum). Seul l'état atteint
après P compte : on parcourt donc les états par distance minimale d, puis tous les corps
de longueur ≤ maxBlocks − 1 − d. Les corps contenant une paire neutre (G·D, D·G, A·R, R·A),
DD (même effet que GG) ou GGG (même effet que D) sont écartés : un corps plus court au
moins aussi bon existe alors.

Usage : python3 -u deep_check.py [RI-0xx …]  → deep_results.json (écrit après chaque niveau)
"""

import json
import sys
import time
from collections import deque
from pathlib import Path

from design import LEVELS
from analyze import board_of
from engine import PRIMITIVES

OUT = Path(__file__).with_name("deep_results.json")
NEUTRAL = {("TOURNE_GAUCHE", "TOURNE_DROITE"), ("TOURNE_DROITE", "TOURNE_GAUCHE"),
           ("AVANCE", "RECULE"), ("RECULE", "AVANCE"), ("TOURNE_DROITE", "TOURNE_DROITE")}


def distances(board, prims, limit):
    start = board.initial()
    dist = {start: 0}
    queue = deque([start])
    while queue:
        s = queue.popleft()
        if dist[s] >= limit or board.won(s):
            continue
        for c in prims:
            n = board.step(s, c)
            if n is not None and n not in dist:
                dist[n] = dist[s] + 1
                queue.append(n)
    return dist


def loop_wins(board, start, body):
    s, seen = start, set()
    while True:
        for i, c in enumerate(body):
            if board.won(s):
                return True
            if (s, i) in seen:
                return False
            seen.add((s, i))
            s = board.step(s, c)
            if s is None:
                return False
        if board.won(s):
            return True


def search(board, allowed, max_blocks):
    prims = [c for c in PRIMITIVES if c in allowed]
    dist = distances(board, prims, max_blocks - 2)
    checked = 0

    def bodies(s, body, length):
        nonlocal checked
        if body:
            checked += 1
            if loop_wins(board, start, body):
                return list(body)
        if len(body) == length or board.won(s):
            return None
        for c in prims:
            if body and (body[-1], c) in NEUTRAL:
                continue
            if len(body) >= 2 and body[-1] == body[-2] == c == "TOURNE_GAUCHE":
                continue
            n = board.step(s, c)
            if n is None:
                continue
            body.append(c)
            found = bodies(n, body, length)
            body.pop()
            if found:
                return found
        return None

    for start, d in sorted(dist.items(), key=lambda item: item[1]):
        room = max_blocks - 1 - d
        if room < 1:
            continue
        found = bodies(start, [], room)
        if found:
            return True, {"prefixLength": d, "body": found}, checked
    return False, None, checked


def main():
    wanted = set(sys.argv[1:])
    results = json.loads(OUT.read_text()) if OUT.exists() else {}
    for spec in LEVELS:
        if not spec.get("maxBlocks") or (wanted and spec["id"] not in wanted):
            continue
        t = time.time()
        found, program, checked = search(board_of(spec), spec["allowed"], spec["maxBlocks"])
        results[spec["id"]] = {"maxBlocks": spec["maxBlocks"], "siFreeSolutionFound": found,
                               "exhaustive": True, "program": program, "bodiesChecked": checked,
                               "seconds": round(time.time() - t, 1)}
        print(spec["id"], results[spec["id"]], flush=True)
        OUT.write_text(json.dumps(results, indent=1) + "\n")


if __name__ == "__main__":
    main()
