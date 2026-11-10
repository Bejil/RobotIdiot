import sys
from gen import maze, dead_ends, bfs_path, turns_along
lo, hi, mint = int(sys.argv[1]), int(sys.argv[2]), int(sys.argv[3])
start_seed = int(sys.argv[4]) if len(sys.argv)>4 else 1
res=[]; used=set()
for seed in range(start_seed, start_seed+4000):
    rows, cells = maze(seed)
    de = dead_ends(cells)
    best=None
    for a in de:
        for b in de:
            if a==b: continue
            p = bfs_path(cells, a, b)
            t = turns_along(p)
            if lo <= len(p) <= hi and len(t)>=mint:
                sc=(len(t), len(de))
                if best is None or sc>best[0]: best=(sc,a,b,len(p))
    if best: res.append((best[0], seed, best[1], best[2], best[3]))
res.sort(key=lambda r:r[0], reverse=True)
for r in res[:8]:
    print(r)
    rows,_=maze(r[1])
    for row in rows: print('   ',row)
