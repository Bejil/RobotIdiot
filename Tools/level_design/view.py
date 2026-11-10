import sys
from gen import maze, bfs_path, turns_along, dead_ends
seed=int(sys.argv[1]); a=tuple(map(int,sys.argv[2].split(','))); b=tuple(map(int,sys.argv[3].split(',')))
rows,cells=maze(seed)
p=bfs_path(cells,a,b)
print('path',len(p),'turns',turns_along(p))
print('dead ends',dead_ends(cells))
for y,r in enumerate(rows):
    print(y, ''.join('*' if (x,y) in p else c for x,c in enumerate(r)), '  ', r)
