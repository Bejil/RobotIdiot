import json, sys
from engine import Board, execute, shortest, from_json
p = json.load(open('../../Packages/RobotIdiotCore/Sources/RobotIdiotCore/Resources/robot_idiot_100_levels_v7.json'))
bad = 0
for l in p['levels']:
    links = {(m['x'], m['y']): m['linkId'] for m in l['mechanics'] if m.get('linkId')}
    bolt = l['rewards']['collectibles'][0] if l['rewards']['collectibles'] else None
    b = Board(l['grid'], links, (bolt['x'], bolt['y']) if bolt else None, l['objective']['requiresItemHeld'])
    prog = from_json(l['solution']['program'])
    r = execute(b, prog, l['unlockedCommands'])
    ok = r.result == 'victory' and r.actions == l['solution']['actionCount']
    if '--bfs' in sys.argv and l['world'] in (6, 9, 10):
        path, _ = shortest(b, l['unlockedCommands'])
        st = l['starTargets']['withoutBonus']['threeStarsMax']
        if len(path) != st:
            print('BFS mismatch', l['id'], len(path), st); bad += 1
        if bolt:
            bp, _ = shortest(b, l['unlockedCommands'], need_bolt=True)
            if len(bp) != l['starTargets']['withBonus']['threeStarsMax']:
                print('BFS bonus mismatch', l['id'], len(bp), l['starTargets']['withBonus']['threeStarsMax']); bad += 1
    if not ok:
        bad += 1; print(l['id'], r.result, r.actions, l['solution']['actionCount'])
print('done, problems:', bad)
