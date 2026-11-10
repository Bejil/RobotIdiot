# Robot Idiot — V8 : audit portes/boutons

Script : `repair_v8_doors.py`  
Pack source du repo : `Packages/RobotIdiotCore/.../robot_idiot_100_levels_v7.json`

## Règle

Chaque tuile `D` (`BoardDoor`) doit être reliée à une tuile `A` (`BoardPlate`) via :
- un objet `BoardDoor` dans `mechanics` avec un `linkId`
- un `interactionLinks` portant ce `linkId` et listant la porte
- un `BoardPlate` au même `linkId` sur la case plaque

Sinon la porte est remplacée par `O` (`BoardStone`) et sa mécanique est retirée.  
Les marqueurs `c` / `l` et le reste du niveau ne sont pas touchés.

## Commande

```bash
# Audit + rapport (sans écraser le pack)
python3 Tools/level_design/repair_v8_doors.py

# Audit + écriture dans les deux copies embarquées du pack v7
python3 Tools/level_design/repair_v8_doors.py --apply
```

## Dernier contrôle (pack jeu actuel)

- 100 niveaux, 68 portes, 68 plaques
- 68 associations valides
- 0 porte remplacée, 0 plaque orpheline
- Marqueurs conservés (87)
- `requiresSolutionRevalidation: false`
