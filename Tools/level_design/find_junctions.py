import sys
from gen import maze, dead_ends, bfs_path, turns_along, neighbours
need = int(sys.argv[1]); mode = sys.argv[2]
out=[]
for seed in range(1, 20000):
    rows, cells = maze(seed)
    de = dead_ends(cells)
    for a in de:
        for b in de:
            if a == b: continue
            p = bfs_path(cells, a, b)
            if not (17 <= len(p) <= 23): continue
            t = turns_along(p)
            jt = []   # virages dont la case droit devant est ouverte (carrefour)
            rt_blocked_ok = True
            for (cell, turn) in t:
                i = p.index(cell)
                d = (cell[0]-p[i-1][0], cell[1]-p[i-1][1])
                ahead = (cell[0]+d[0], cell[1]+d[1])
                if ahead in cells:
                    jt.append((cell, turn, ahead))
                    if turn == 'D': rt_blocked_ok = False
            if mode == 'junction' and len(jt) >= need:
                out.append((len(jt), len(t), seed, a, b, len(p), jt))
            if mode == 'wallfollow' and rt_blocked_ok and len(t) >= need:
                lefts = sum(1 for _,x in t if x=='G')
                out.append((len(t), -lefts, seed, a, b, len(p), t))
out.sort(key=lambda r: (r[0], r[1]), reverse=True)
seen=set()
for r in out:
    if r[2] in seen: continue
    seen.add(r[2])
    print(r[:6]); print('   ', r[6])
    if len(seen) >= 6: break
