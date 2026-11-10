#!/usr/bin/env python3
"""Audit BoardDoor->BoardPlate links and replace unlinked doors by BoardStone.

Does not modify any doors that have a valid consistent linkId relationship
between the grid, mechanics, and interactionLinks. On a replacement, any
existing stored solutions/star thresholds must be recomputed before release.
"""
import argparse
import copy
import json
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DEFAULT_INPUT = ROOT / 'Packages/RobotIdiotCore/Sources/RobotIdiotCore/Resources/robot_idiot_100_levels_v7.json'
DEFAULT_OUTPUT = Path(__file__).resolve().parent / 'robot_idiot_100_levels_v8_doors.json'
DEFAULT_REPORT = Path(__file__).resolve().parent / 'Robot_Idiot_V8_Rapport_Portes.json'


def pos(obj):
    if isinstance(obj, dict) and isinstance(obj.get('x'), int) and isinstance(obj.get('y'), int):
        return obj['x'], obj['y']
    return None


def all_positions(grid, character):
    return {(x, y) for y, row in enumerate(grid) for x, cell in enumerate(row) if cell == character}


def audit_and_repair(src, source_name='robot_idiot_100_levels_v7.json', output_name='robot_idiot_100_levels_v8_doors.json'):
    data = copy.deepcopy(src)
    report = {'source': source_name,
              'output': output_name,
              'replacementTile': {'char': 'O', 'type': 'BoardStone'},
              'levelsAudited': len(data['levels']),
              'doorsFound': 0, 'platesFound': 0, 'linkedDoors': 0,
              'replacedDoors': [], 'levelsModified': [],
              'orphanPlates': [], 'staleLinksRemoved': [],
              'requiresSolutionRevalidation': False}
    for level in data['levels']:
        lid = level['id']
        grid = level['grid']
        ds, plates = all_positions(grid, 'D'), all_positions(grid, 'A')
        report['doorsFound'] += len(ds)
        report['platesFound'] += len(plates)
        door_mechs = [m for m in level.get('mechanics', []) if m.get('type') == 'BoardDoor']
        plate_mechs = [m for m in level.get('mechanics', []) if m.get('type') == 'BoardPlate']
        links = level.get('interactionLinks', [])
        bad = []
        for xy in sorted(ds):
            matching_mechs = [m for m in door_mechs if pos(m) == xy]
            valid = False
            if len(matching_mechs) == 1:
                link_id = matching_mechs[0].get('linkId')
                matches = [l for l in links if link_id and l.get('linkId') == link_id
                           and xy in [pos(p) for p in l.get('doors', [])]]
                if len(matches) == 1:
                    pl = pos(matches[0].get('plate'))
                    valid = (pl in plates and
                             len([m for m in plate_mechs if pos(m) == pl and m.get('linkId') == link_id]) == 1)
            if valid:
                report['linkedDoors'] += 1
            else:
                bad.append(xy)
        if bad:
            report['levelsModified'].append(lid)
            replacements = set(bad)
            rows = [list(row) for row in grid]
            for x, y in bad:
                rows[y][x] = 'O'
                report['replacedDoors'].append({'level': lid, 'x': x, 'y': y,
                    'reason': 'No valid matching BoardPlate + linkId + interactionLinks'})
            level['grid'] = [''.join(row) for row in rows]
            level['mechanics'] = [m for m in level.get('mechanics', [])
                if not (m.get('type') == 'BoardDoor' and pos(m) in replacements)]
            updated_links = []
            for link in links:
                remaining = [p for p in link.get('doors', []) if pos(p) not in replacements]
                if remaining:
                    link['doors'] = remaining
                    updated_links.append(link)
                else:
                    report['staleLinksRemoved'].append({'level': lid, 'linkId': link.get('linkId')})
            level['interactionLinks'] = updated_links
            if 'obstacles' in level and 'blockingTiles' in level['obstacles']:
                blocking = level['obstacles']['blockingTiles']
                blocking['BoardStone'] = blocking.get('BoardStone', 0) + len(bad)
            # Existing solutions may have crossed a now blocked passage. Never claim validation.
            level.setdefault('solution', {})['validated'] = False
            level['solution']['requiresRecalculation'] = True
            if 'rewardValidation' in level:
                level['rewardValidation']['requiresRecalculation'] = True
            if 'starTargets' in level:
                level['starTargets']['requiresRecalculation'] = True
            report['requiresSolutionRevalidation'] = True
        # Note inactive/orphan plate tiles for diagnostics, never silently change them.
        assigned_plates = {pos(l.get('plate')) for l in level.get('interactionLinks', [])}
        for xy in sorted(plates - assigned_plates):
            report['orphanPlates'].append({'level': lid, 'x': xy[0], 'y': xy[1]})
    data['contentRevision'] = 'V8 — audit portes/boutons'
    data['migrationFromV7'] = {
        'source': source_name,
        'rule': 'A BoardDoor is kept only if its position and linkId resolve to a BoardPlate '
                'present in the grid, mechanics and interactionLinks.',
        'replaceUnlinkedDoorsWith': 'BoardStone (O)',
        'doorsReplaced': len(report['replacedDoors']),
        'levelsModified': len(report['levelsModified']),
        'originalLevelDataUnchanged': not report['replacedDoors'],
        'needsRevalidationIfReplacements': True,
    }
    return data, report


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--input', type=Path, default=DEFAULT_INPUT)
    p.add_argument('--output', type=Path, default=DEFAULT_OUTPUT)
    p.add_argument('--report', type=Path, default=DEFAULT_REPORT)
    p.add_argument('--apply', action='store_true',
                   help='Écrit aussi le résultat dans les deux copies embarquées du pack v7.')
    args = p.parse_args()
    with args.input.open(encoding='utf-8') as f: data = json.load(f)
    output, report = audit_and_repair(data, source_name=args.input.name, output_name=args.output.name)
    text = json.dumps(output, indent=2, ensure_ascii=False) + '\n'
    args.output.write_text(text, encoding='utf-8')
    args.report.write_text(json.dumps(report, indent=2, ensure_ascii=False) + '\n', encoding='utf-8')
    if args.apply:
        targets = [
            ROOT / 'Packages/RobotIdiotCore/Sources/RobotIdiotCore/Resources/robot_idiot_100_levels_v7.json',
            ROOT / 'RobotIdiot/Resources/robot_idiot_100_levels_v7.json',
        ]
        for target in targets:
            target.write_text(text, encoding='utf-8')
            print(f'applied → {target.relative_to(ROOT)}')
    print(f"{report['levelsAudited']} levels | {report['doorsFound']} doors | "
          f"{report['linkedDoors']} valid linked | {len(report['replacedDoors'])} replaced")
    if report['requiresSolutionRevalidation']:
        print('WARNING: Changed levels MUST be re-solved and their star thresholds recalculated.')


if __name__ == '__main__':
    main()
