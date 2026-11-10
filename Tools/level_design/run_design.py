import sys
from design import LEVELS
from analyze import show, board_of
from engine import natural_shortest
from helpers import wrap_flat
ids = sys.argv[1:]
for spec in LEVELS:
    if ids and spec['id'] not in ids: continue
    b = board_of(spec)
    if spec.get('program') == 'auto':
        spec['program'] = wrap_flat(b, natural_shortest(b, spec['allowed']), spec['rules'])
    if spec.get('bonusProgram') == 'auto':
        spec['bonusProgram'] = wrap_flat(b, natural_shortest(b, spec['allowed'], need_bolt=True), spec['rules'])
    show(spec, deep='--deep' in sys.argv)
    print('   prog:', spec['program'])
