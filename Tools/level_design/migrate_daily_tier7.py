"""Palier 7 des défis et bugs du jour : REPETE n'est débloqué qu'en 7-8.

Le REPETE { AVANCE } final de chaque programme est déroulé en AVANCE successifs,
et SI remplace REPETE dans les commandes disponibles. Rejoue chaque programme.
"""

import json
from pathlib import Path

from engine import Board, execute, from_json, to_json

ROOT = Path(__file__).resolve().parents[2]
COPIES = [ROOT / "Packages/RobotIdiotCore/Sources/RobotIdiotCore/Resources", ROOT / "RobotIdiot/Resources"]
CHALLENGES = "robot_idiot_daily_challenges_100.json"
BUGS = "robot_idiot_daily_bugs_100.json"


def board(level):
    links = {(m["x"], m["y"]): m["linkId"] for m in level["mechanics"] if m.get("linkId")}
    return Board(level["grid"], links, None, level["objective"].get("requiresItemHeld", False))


def unroll(program, b, commands):
    """Remplace le REPETE final par les AVANCE qu'il exécute réellement avant la victoire."""
    nodes = from_json(program)
    if not nodes or isinstance(nodes[-1], str):
        return program
    assert nodes[-1] == ("REPETE", ["AVANCE"]), nodes[-1]
    prefix = nodes[:-1]
    full = execute(b, nodes, None)
    assert full.result == "victory", full.result
    head = execute(b, prefix, None)
    flat = prefix + ["AVANCE"] * (full.actions - head.actions)
    run = execute(b, flat, commands)
    assert run.result == "victory" and run.actions == full.actions
    return to_json(flat)


def swap(commands):
    return [c for c in commands if c != "REPETE"] + (["SI"] if "SI" not in commands else [])


def main():
    challenges = json.loads((COPIES[0] / CHALLENGES).read_text())
    bugs = json.loads((COPIES[0] / BUGS).read_text())
    boards = {}
    for level in challenges["levels"]:
        if level["world"] != 7:
            continue
        b = board(level)
        boards[level["id"]] = b
        level["unlockedCommands"] = swap(level["unlockedCommands"])
        solution = level["solution"]
        solution["program"] = unroll(solution["program"], b, level["unlockedCommands"])
        solution["requiredCommandUsage"] = [c for c in solution["requiredCommandUsage"] if c != "REPETE"]
        solution["loopIterationsBeforeVictory"] = None
        level["family"] = "conditions_intro"
        level["newCommand"] = "SI"
    for bug in bugs["bugs"]:
        if bug["tier"] != 7:
            continue
        b = boards[bug["boardRef"]]
        bug["availableCommands"] = swap(bug["availableCommands"])
        bug["referenceProgram"] = unroll(bug["referenceProgram"], b, bug["availableCommands"])
        # Le programme bogué échoue avant la boucle : seul le suffixe change, sans être exécuté.
        nodes = from_json(bug["bugProgram"])
        if nodes and nodes[-1] == ("REPETE", ["AVANCE"]):
            tail = len(from_json(bug["referenceProgram"])) - (len(nodes) - 1)
            nodes = nodes[:-1] + ["AVANCE"] * tail
            bug["bugProgram"] = to_json(nodes)
        run = execute(b, from_json(bug["bugProgram"]), bug["availableCommands"])
        assert run.result != "victory", bug["id"]
        assert run.actions == bug["validation"]["badProgramActionsUntilStop"], (bug["id"], run.actions)
    for folder in COPIES:
        (folder / CHALLENGES).write_text(json.dumps(challenges, ensure_ascii=False, indent=2) + "\n")
        (folder / BUGS).write_text(json.dumps(bugs, ensure_ascii=False, indent=2) + "\n")
    print("palier 7 migré")


if __name__ == "__main__":
    main()
