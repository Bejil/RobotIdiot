"""Écrit les niveaux RI-061 … RI-080 de design.py dans les deux copies du pack.

Chaque niveau est rejoué, comparé à l'optimum exact (BFS) et vérifié avant écriture.
Usage : python3 build_pack.py [--dry-run]
"""

import json
import sys
from collections import Counter
from pathlib import Path

from design import LEVELS
from analyze import board_of
from engine import (Board, execute, shortest, natural_shortest, blocks, uses, conditions_used,
                    commands_used, to_json, reachable_cells)
from helpers import wrap_flat

ROOT = Path(__file__).resolve().parents[2]
PACKS = [
    ROOT / "Packages/RobotIdiotCore/Sources/RobotIdiotCore/Resources/robot_idiot_100_levels_v7.json",
    ROOT / "RobotIdiot/Resources/robot_idiot_100_levels_v7.json",
]
VALIDATION = ROOT / "Packages/RobotIdiotCore/Sources/RobotIdiotCore/Resources/robot_idiot_v7_validation.json"
DEEP = Path(__file__).with_name("deep_results.json")
REPORT = Path(__file__).with_name("report_w7_w8.json")

ORIENT = {"^": "N", ">": "E", "v": "S", "<": "W"}
TILE_NAMES = {"B": "BoardBush", "R": "BoardCracked", "L": "BoardLava", "T": "BoardShutter",
              "P": "BoardSpikes", "O": "BoardStone", "W": "BoardWater"}
MECHANICS = {"K": "BoardKey", "U": "BoardLock", "C": "BoardCrate", "A": "BoardPlate", "D": "BoardDoor"}


def family(spec, world, index):
    if world == 7:
        return "conditions_intro" if index <= 7 else "conditions_mastery"
    return "loop_patterns" if index <= 3 else "loop_conditions"


def new_command(world, index):
    if world == 7:
        return "SI"
    return "REPETE"


def difficulty(grid, trace, world, optimum, block_count):
    moves = sum(1 for c in trace if c in ("AVANCE", "RECULE", "POUSSE"))
    turns = sum(1 for c in trace if c in ("TOURNE_GAUCHE", "TOURNE_DROITE"))
    longest = run = 0
    for c in trace:
        run = run + 1 if c == "AVANCE" else 0
        longest = max(longest, run)
    walls = sum(1 for r in grid for c in r if c in TILE_NAMES)
    open_cells = {(x, y) for y, r in enumerate(grid) for x, c in enumerate(r) if c not in TILE_NAMES}
    dead_ends = sum(1 for (x, y) in open_cells
                    if sum((x + dx, y + dy) in open_cells for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))) == 1)
    return {"worldTier": world, "solutionActionCount": len(trace), "walkablePathLength": moves,
            "turnsOnIntendedPath": turns, "maximumStraightRun": longest, "detourCount": 0,
            "deadEnds": dead_ends, "wallCount": walls, "turns": turns, "moveActions": moves,
            "maxConsecutiveMovesSameDirection": longest, "optimalActionCount": optimum,
            "blockCount": block_count}


def door_is_mandatory(spec, door):
    """La porte scellée pour toujours, le drapeau doit devenir inaccessible."""
    sealed = [list(r) for r in spec["grid"]]
    sealed[door[1]][door[0]] = "O"
    links = {k: v for k, v in (((x, y), l) for (x, y, l) in spec.get("links", [])) if k != door}
    rows = ["".join(r) for r in sealed]
    # La plaque reste en place mais n'ouvre plus rien.
    board = Board(rows, links, None, False)
    path, _ = shortest(board, spec["allowed"])
    return path is None


def build(spec):
    board = board_of(spec)
    allowed = spec["allowed"]
    if spec.get("program") == "auto":
        spec["program"] = wrap_flat(board, natural_shortest(board, allowed), spec["rules"])
    if spec.get("bonusProgram") == "auto":
        spec["bonusProgram"] = wrap_flat(board, natural_shortest(board, allowed, need_bolt=True), spec["rules"])

    number = int(spec["id"][3:])
    world, index = (number - 1) // 10 + 1, (number - 1) % 10 + 1
    program = spec["program"]
    run = execute(board, program, allowed)
    assert run.result == "victory", (spec["id"], run.result, run.trace[-5:])
    direct, direct_states = shortest(board, allowed)
    assert direct is not None and run.actions == len(direct), (spec["id"], run.actions, len(direct))
    assert commands_used(program) <= set(allowed), spec["id"]
    if spec.get("maxBlocks"):
        assert blocks(program) <= spec["maxBlocks"], (spec["id"], blocks(program))
        assert spec["maxBlocks"] < len(direct), "sans boucle, il faut un bloc par action"
    if spec.get("requiresLoop"):
        assert uses(program, "REPETE"), spec["id"]
    if spec.get("requiresCondition"):
        assert uses(program, "SI"), spec["id"]

    grid = spec["grid"]
    for (x, y) in [(x, y) for y, r in enumerate(grid) for x, c in enumerate(r) if c in "cl"]:
        assert (x, y) in reachable_cells(board, allowed), (spec["id"], "balise inaccessible", x, y)
    assert not any(c.isdigit() for r in grid for c in r), "pas de portail"

    links = {(x, y): l for (x, y, l) in spec.get("links", [])}
    start = next((x, y, c) for y, r in enumerate(grid) for x, c in enumerate(r) if c in ORIENT)
    finish = next((x, y) for y, r in enumerate(grid) for x, c in enumerate(r) if c == "F")
    mechanics = []
    for y, row in enumerate(grid):
        for x, c in enumerate(row):
            if c in MECHANICS:
                entry = {"type": MECHANICS[c], "x": x, "y": y}
                if c in "AD":
                    entry["linkId"] = links[(x, y)]
                mechanics.append(entry)
    for door in [(m["x"], m["y"]) for m in mechanics if m["type"] == "BoardDoor"]:
        assert door_is_mandatory(spec, door), (spec["id"], "porte contournable", door)
    interaction_links = []
    for link in sorted(set(links.values())):
        plate = next(k for k, v in links.items() if v == link and grid[k[1]][k[0]] == "A")
        doors = [k for k, v in links.items() if v == link and grid[k[1]][k[0]] == "D"]
        interaction_links.append({"linkId": link, "plate": {"x": plate[0], "y": plate[1]},
                                  "doors": [{"x": d[0], "y": d[1]} for d in doors]})

    blocking = Counter(TILE_NAMES[c] for r in grid for c in r if c in TILE_NAMES)
    keys_used = run.trace.count("RAMASSE")
    level = {
        "id": spec["id"], "world": world, "worldLevel": index, "globalLevel": number,
        "name": f"Monde {world} · Niveau {index}",
        "title": spec["name"],
        "concept": spec["concept"],
        "width": 7, "height": 7, "grid": grid,
        "start": {"x": start[0], "y": start[1], "orientation": ORIENT[start[2]]},
        "finish": {"x": finish[0], "y": finish[1]},
        "objective": {"type": "reach_flag", "requiresItemHeld": False},
        "family": family(spec, world, index),
        "unlockedCommands": allowed,
        "mechanics": mechanics,
        "obstacles": {"blockingTiles": dict(sorted(blocking.items()))},
        "solution": {
            "program": to_json(program),
            "expandedOptimalCommands": run.trace,
            "expandedCommands": run.trace,
            "actionCount": run.actions,
            "optimality": "EXACT_BFS_PROVEN",
            "validated": True,
            "requiredCommandUsage": sorted(c for c in commands_used(program) if c not in
                                           ("AVANCE", "TOURNE_GAUCHE", "TOURNE_DROITE", "RECULE")),
            "loopIterationsBeforeVictory": run.loop_iterations if uses(program, "REPETE") else None,
            "conditionBranches": {k: {"true": v[0], "false": v[1]} for k, v in sorted(run.condition_hits.items())} or None,
            "blockCount": blocks(program),
            "observedInteractions": {
                "keysCollected": keys_used,
                "locksOpened": run.trace.count("UTILISE"),
                "cratesPushedActions": run.trace.count("POUSSE"),
                "platesActivated": run.trace.count("ACTIVE"),
                "markers": {"circle": sum(r.count("c") for r in grid), "diamond": sum(r.count("l") for r in grid)},
            },
        },
        "generation": {"seed": spec.get("seed", number * 1000 + 7), "attempt": 1, "generatorVersion": "7.1-design",
                       "source": "Tools/level_design/design.py"},
        "difficulty": difficulty(grid, run.trace, world, len(direct), blocks(program)),
        "newCommand": new_command(world, index),
        "rendering": {"ground": "BoardGrass", "orientation": "topDown", "gridSize": [7, 7]},
        "validationNote": "V7.1: reference program replayed; action count equals exact BFS optimum.",
        "interactionLinks": interaction_links,
    }
    constraints = {}
    if spec.get("maxBlocks"):
        constraints["maxBlocks"] = spec["maxBlocks"]
    if spec.get("requiresLoop"):
        constraints["requiresLoop"] = True
    if spec.get("requiresCondition"):
        constraints["requiresCondition"] = True
    if constraints:
        level["programConstraints"] = constraints

    stars = {"metric": "executedPrimitiveActions", "selectionRule": "useWithBonusIfCollectedThisAttempt",
             "withoutBonus": {"optimal": len(direct), "threeStarsMax": len(direct)}}
    validation = None
    if spec.get("bolt"):
        bx, by = spec["bolt"]
        assert grid[by][bx] == "g", (spec["id"], "écrou hors herbe")
        with_bonus, bonus_states = shortest(board, allowed, need_bolt=True)
        assert with_bonus is not None and len(with_bonus) > len(direct), spec["id"]
        assert not run.state.bolt, (spec["id"], "la référence directe ramasse l'écrou")
        bonus_run = execute(board, spec["bonusProgram"], allowed)
        assert bonus_run.result == "victory" and bonus_run.state.bolt, spec["id"]
        assert bonus_run.actions == len(with_bonus), (spec["id"], bonus_run.actions, len(with_bonus))
        if spec.get("maxBlocks"):
            assert blocks(spec["bonusProgram"]) <= spec["maxBlocks"], spec["id"]
        stars["withBonus"] = {"optimal": len(with_bonus), "threeStarsMax": len(with_bonus)}
        level["rewards"] = {"currency": "bolt", "completionOnly": True, "repeatable": False, "collectibles": [{
            "id": f"{spec['id']}-bolt-1", "type": "BoardBolt", "x": bx, "y": by, "amount": 1,
            "optional": True, "pickup": "auto_on_enter", "layer": "overlay_on_BoardGrass",
            "grantCondition": "level_won_and_bonus_collected", "repeatable": False}]}
        level["rewardPolicy"] = {"maxCollectibles": 1, "bonusRequiredToFinish": False,
                                 "bonusRequiresCommand": False, "creditOnlyOnVictory": True, "noReplayFarming": True}
        level["rewardValidation"] = {
            "offUncollectedOptimalRoute": True,
            "extraActionsRequired": len(with_bonus) - len(direct),
            "optionalRouteBacktracks": True,
            "noBonusOptimality": "EXACT_BFS_PROVEN", "withBonusOptimality": "EXACT_BFS_PROVEN",
            "optimalDirectProgram": run.trace, "optimalWithBonusProgram": bonus_run.trace,
            "referenceBonusProgram": to_json(spec["bonusProgram"]),
            "directStatesVisited": direct_states, "bonusStatesVisited": bonus_states,
        }
        validation = ("bonus", {"id": spec["id"], "world": world, "worldLevel": index, "bonus": [bx, by],
                                "directOptimal": len(direct), "withBonusOptimal": len(with_bonus),
                                "extra": len(with_bonus) - len(direct), "degree": 2, "backtrack": True})
    else:
        validation = ("plain", {"id": spec["id"], "optimal": len(direct), "searchedStates": direct_states})
    level["starTargets"] = stars

    loop_body = next((n[1] for n in program if not isinstance(n, str) and n[0] == "REPETE"), None)
    report = {
        "id": spec["id"], "title": spec["name"], "world": world, "worldLevel": index,
        "concept": spec["concept"],
        "optimalActions": len(direct),
        "withBonusOptimal": stars.get("withBonus", {}).get("optimal"),
        "referenceBlocks": blocks(program),
        "maxBlocks": spec.get("maxBlocks"),
        "minBlocksWithoutLoop": len(direct),
        "loopIterations": run.loop_iterations if loop_body else 0,
        "distinctCommandsInLoop": sorted(commands_used(loop_body) - {"SI", "REPETE"}) if loop_body else [],
        "conditionsInLoop": sorted(conditions_used(loop_body)) if loop_body else [],
        "conditionsUsed": sorted(conditions_used(program)),
        "conditionBranches": level["solution"]["conditionBranches"],
        "conditionsAlwaysTrue": sorted(k for k, v in run.condition_hits.items() if v[1] == 0),
    }
    return level, validation, report


def main():
    dry = "--dry-run" in sys.argv
    deep = json.loads(DEEP.read_text()) if DEEP.exists() else {}
    built, validations, reports = {}, [], []
    for spec in LEVELS:
        level, validation, report = build(spec)
        proof = deep.get(spec["id"])
        if proof:
            report["siFreeSolutionWithinMaxBlocks"] = proof["siFreeSolutionFound"]
            report["siFreeSearchExhaustive"] = proof["exhaustive"]
        built[spec["id"]] = level
        validations.append(validation)
        reports.append(report)
        print(f"{spec['id']} {spec['name']}: {report['optimalActions']} actions, "
              f"{report['referenceBlocks']} blocs, max {report['maxBlocks']}, bonus {report['withBonusOptimal']}")
    if dry:
        return
    for path in PACKS:
        pack = json.loads(path.read_text())
        pack["levels"] = [built.get(l["id"], l) for l in pack["levels"]]
        path.write_text(json.dumps(pack, ensure_ascii=False, indent=2) + "\n")

    data = json.loads(VALIDATION.read_text())
    ids = set(built)
    data["levelResults"] = sorted([r for r in data["levelResults"] if r["id"] not in ids]
                                  + [v for k, v in validations if k == "bonus"], key=lambda r: r["id"])
    data["noBonusResults"] = sorted([r for r in data["noBonusResults"] if r["id"] not in ids]
                                    + [v for k, v in validations if k == "plain"], key=lambda r: r["id"])
    data["bonusLevels"] = len(data["levelResults"])
    data["noBonusLevels"] = len(data["noBonusResults"])
    VALIDATION.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n")
    REPORT.write_text(json.dumps(reports, ensure_ascii=False, indent=1) + "\n")


if __name__ == "__main__":
    main()
