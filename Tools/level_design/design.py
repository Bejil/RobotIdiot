"""Conception des mondes 7 (conditions) et 8 (boucles) — source unique des 20 niveaux.

Chaque niveau part d'un labyrinthe parfait 7×7 (graine) ou d'une grille dessinée.
Les programmes de référence sont rejoués et comparés à l'optimum exact (BFS).
"""

from gen import maze, bfs_path, turns_along, put

BASE = ["AVANCE", "TOURNE_GAUCHE", "TOURNE_DROITE", "RECULE", "RAMASSE", "UTILISE", "POUSSE", "ACTIVE"]
W7 = BASE + ["SI"]
W8 = BASE + ["REPETE", "SI"]

A, G, D, R = "AVANCE", "TOURNE_GAUCHE", "TOURNE_DROITE", "RECULE"
K, U, P, X = "RAMASSE", "UTILISE", "POUSSE", "ACTIVE"


def SI(cond, *body):
    return ("SI", cond, list(body))


def REPETE(*body):
    return ("REPETE", list(body))


OBST, CLE, CAISSE, CADENAS = "SI_OBSTACLE_DEVANT", "SI_CLE_DEVANT", "SI_CAISSE_DEVANT", "SI_CADENAS_DEVANT"
CERCLE, LOSANGE, LIBRE = "SI_SUR_CERCLE", "SI_SUR_LOSANGE", "CASE_DEVANT_LIBRE"

MARKER_FOLLOW = [SI(CERCLE, G), SI(LOSANGE, D), A]


def from_maze(seed, start, finish, arrow, edits=(), mark_from=None, mark=True, lethal=()):
    """Grille issue d'un labyrinthe. Balises : cercle = virage à gauche, losange = à droite."""
    rows, cells = maze(seed)
    if mark:
        origin = mark_from or start
        path = bfs_path(cells, origin, finish)
        for (cell, turn) in turns_along(path):
            put(rows, cell[0], cell[1], "c" if turn == "G" else "l")
    for (x, y, ch) in lethal:
        put(rows, x, y, ch)
    put(rows, start[0], start[1], arrow)
    put(rows, finish[0], finish[1], "F")
    for (x, y, ch) in edits:
        put(rows, x, y, ch)
    return rows


def flat_markers(rows):
    return [r.replace("c", "g").replace("l", "g") for r in rows]


LEVELS = []


def level(**spec):
    LEVELS.append(spec)
    return spec


# ----------------------------------------------------------------------------- Monde 7
# 7-1 · Première condition : tourner seulement quand un obstacle bloque.
level(
    id="RI-061", name="Le mur qui parle",
    concept="SI_OBSTACLE_DEVANT : tourner quand un obstacle bloque la case devant",
    allowed=W7, requiresCondition=True,
    grid=flat_markers(from_maze(5035, (0, 6), (6, 6), "^", lethal=[(3, 3, "W"), (5, 5, "W")])),
    program="auto", rules=[(OBST, [D]), (OBST, [G])],
)

# 7-2 · Balise cercle.
level(
    id="RI-062", name="Sur le cercle",
    concept="SI_SUR_CERCLE : le robot lit la case sous ses roues et tourne à gauche",
    allowed=W7, requiresCondition=True,
    grid=[r.replace("l", "g") for r in from_maze(6904, (6, 0), (6, 6), "<")],
    program="auto", rules=[(CERCLE, [G]), (OBST, [D]), (OBST, [G])],
)

# 7-3 · Balise losange.
level(
    id="RI-063", name="Sur le losange",
    concept="SI_SUR_LOSANGE : tourner à droite sur la balise losange",
    allowed=W7, requiresCondition=True,
    grid=[r.replace("c", "g") for r in from_maze(5928, (6, 0), (6, 6), "<")],
    program="auto", rules=[(LOSANGE, [D]), (OBST, [D]), (OBST, [G])],
)

# 7-4 · Les deux balises ensemble.
level(
    id="RI-064", name="Cercles et losanges",
    concept="SI_SUR_CERCLE / SI_SUR_LOSANGE : le robot lit la case sous ses roues",
    allowed=W7, requiresCondition=True,
    grid=from_maze(6435, (0, 0), (0, 6), ">"),
    bolt=(6, 4),
    program="auto", rules=[(CERCLE, [G]), (LOSANGE, [D])],
    bonusProgram="auto",
)

# 7-5 · Détecter une caisse.
level(
    id="RI-065", name="Caisses en travers",
    concept="SI_CAISSE_DEVANT { POUSSE } : dégager le couloir dans une impasse",
    allowed=W7, requiresCondition=True,
    grid=flat_markers(from_maze(7571, (0, 0), (6, 0), "v", edits=[(4, 3, "C"), (2, 3, "C")])),
    program="auto", rules=[(CAISSE, [P]), (OBST, [D]), (OBST, [G])],
)

# 7-6 · Clés, cadenas et conditions.
level(
    id="RI-066", name="Clé en vue",
    concept="SI_CLE_DEVANT { AVANCE, RAMASSE } puis SI_CADENAS_DEVANT { UTILISE }",
    allowed=W7, requiresCondition=True,
    grid=flat_markers(from_maze(5631, (6, 2), (0, 6), "v", edits=[(3, 4, "K"), (1, 4, "U")])),
    program="auto", rules=[(CLE, [A, K]), (CADENAS, [U]), (OBST, [D]), (OBST, [G])],
)

# 7-7 · Réagir à différents obstacles (plaque + porte + balises).
level(
    id="RI-067", name="La plaque au fond",
    concept="Un SI qui contient plusieurs instructions ; plaque et porte liées",
    allowed=W7, requiresCondition=True,
    grid=from_maze(5631, (6, 2), (0, 6), "v", mark_from=(6, 4),
                   edits=[(6, 6, "A"), (3, 2, "D"), (6, 4, "g")]),
    links=[(6, 6, "g67-1"), (3, 2, "g67-1")],
    bolt=(6, 0),
    program="auto", rules=[(CERCLE, [G, A, A]), (LOSANGE, [D, A, A]), (CERCLE, [G]), (LOSANGE, [D])],
    bonusProgram="auto",
)

# 7-8 · Plusieurs conditions successives (imbriquées).
level(
    id="RI-068", name="Conditions gigognes",
    concept="SI imbriqués : SI_SUR_CERCLE { TOURNE_GAUCHE ; SI_CLE_DEVANT { … } }",
    allowed=W7, requiresCondition=True,
    grid=from_maze(2752, (0, 0), (2, 6), "v", edits=[(5, 2, "K"), (5, 4, "U")]),
    program="auto",
    rules=[("nest", CERCLE, G, CLE, [A, K]), ("nest", LOSANGE, D, CADENAS, [U]), (CERCLE, [G]), (LOSANGE, [D])],
)

# 7-9 · Labyrinthe avec balises et interactions.
level(
    id="RI-069", name="Labyrinthe annoté",
    concept="Balises, clés et cadenas : enchaîner les bonnes conditions",
    allowed=W7, requiresCondition=True,
    grid=from_maze(3855, (2, 2), (0, 4), "^", edits=[(5, 2, "K"), (3, 6, "U")]),
    program="auto",
    rules=[(CLE, [A, K]), (CADENAS, [U]), (CERCLE, [G]), (LOSANGE, [D]), (OBST, [D]), (OBST, [G])],
)

# 7-10 · Synthèse de toutes les conditions (plaque + balises + objets).
level(
    id="RI-070", name="Grand final conditionnel",
    concept="Synthèse : plaque, balises, clé, cadenas — sans boucle",
    allowed=W7, requiresCondition=True,
    grid=from_maze(866, (0, 6), (6, 0), "^", mark_from=(0, 4),
                   edits=[(0, 2, "A"), (5, 2, "D"), (0, 4, "l"), (3, 4, "K"), (4, 0, "U")]),
    links=[(0, 2, "g70-1"), (5, 2, "g70-1")],
    bolt=(0, 1),
    program="auto",
    rules=[(CLE, [A, K]), (CADENAS, [U]), (CERCLE, [G]), (LOSANGE, [D]), (OBST, [D]), (OBST, [G])],
    bonusProgram="auto",
)

# ----------------------------------------------------------------------------- Monde 8
# 8-1 · Un motif qui se répète : l'escalier.
level(
    id="RI-071", name="L'escalier",
    concept="REPETE { AVANCE, TOURNE_DROITE, AVANCE, TOURNE_GAUCHE } : un motif, douze marches",
    allowed=W8, maxBlocks=8, requiresLoop=True,
    grid=[
        "TBOWBgF",
        "BOWWggB",
        "OWWggWO",
        "WWggWWT",
        "WggWWOB",
        "ggWWBOT",
        "^gggBTR",
    ],
    program=[REPETE(A, D, A, G)],
)

# 8-2 · Motif plus long ; un écrou caché à côté du départ.
level(
    id="RI-072", name="Grandes marches",
    concept="Boucle de six commandes ; l'écrou se prend avant d'entrer dans la boucle",
    allowed=W8, maxBlocks=12, requiresLoop=True,
    grid=[
        "OBTWgg F".replace(" ", ""),
        "BOWTgRB",
        "TRgggBO",
        "WBgOggg",
        "gggOBOB",
        "gBTWROT",
        "^gOBTWR",
    ],
    bolt=(1, 6),
    program=[REPETE(A, A, D, A, A, G)],
    bonusProgram=[D, A, R, G, REPETE(A, A, D, A, A, G)],
)

# 8-3 · Clés et cadenas en escalier ; la victoire arrête la boucle au milieu d'un tour.
level(
    id="RI-073", name="Escalier verrouillé",
    concept="Motif avec RAMASSE et UTILISE ; REPETE s'arrête en plein tour sur le drapeau",
    allowed=W8, maxBlocks=10, requiresLoop=True,
    grid=[
        "BTOgWBR",
        "OBWBFBg",
        "TWBKUgg",
        "WBKUBOg",
        "OKUBWTB",
        "KUBWOgR",
        "^OTBRgg",
    ],
    program=[REPETE(A, K, D, U, A, G)],
)

# 8-4 · Spirale : tourner à droite dès qu'un obstacle bloque.
level(
    id="RI-074", name="La spirale",
    concept="REPETE { SI_OBSTACLE_DEVANT { TOURNE_DROITE } ; AVANCE } : 4 blocs pour 36 actions",
    allowed=W8, maxBlocks=6, requiresLoop=True, requiresCondition=True,
    grid=[
        ">gggggg",
        "RBOWTBg",
        "gggggOg",
        "gOWBgTg",
        "gTFggBg",
        "gBROWOg",
        "ggggggg",
    ],
    program=[REPETE(SI(OBST, D), A)],
)

# 8-5 · Balises et caisses : pousser les caisses dans les impasses sans s'arrêter.
level(
    id="RI-075", name="Déménagement",
    concept="Boucle : balises, SI_CAISSE_DEVANT { POUSSE }, sinon avancer si la case est libre",
    allowed=W8, maxBlocks=11, requiresLoop=True, requiresCondition=True,
    grid=from_maze(7618, (2, 0), (2, 2), ">", edits=[(6, 3, "C"), (3, 6, "C"), (0, 3, "C")],
                   lethal=[(1, 3, "W"), (5, 5, "L")]),
    program=[REPETE(SI(CERCLE, G), SI(LOSANGE, D), SI(CAISSE, P), SI(LIBRE, A))],
)

# 8-6 · Clés au fond des alcôves, cadenas sur le chemin.
level(
    id="RI-076", name="Alcôves",
    concept="SI_CLE_DEVANT { AVANCE, RAMASSE, RECULE } dans la boucle, puis cadenas",
    allowed=W8, maxBlocks=14, requiresLoop=True, requiresCondition=True,
    grid=from_maze(2211, (4, 6), (6, 6), "<",
                   edits=[(1, 6, "K"), (0, 1, "K"), (5, 0, "K"), (4, 3, "K"),
                          (1, 4, "U"), (1, 2, "U"), (5, 2, "U"), (6, 4, "U")]),
    program=[REPETE(SI(CLE, A, K, R), SI(CERCLE, G), SI(LOSANGE, D), SI(CADENAS, U), A)],
)

# 8-7 · Peu de balises : les virages à droite se lisent sur les obstacles.
level(
    id="RI-077", name="Main droite",
    concept="Cercles pour la gauche, SI_OBSTACLE_DEVANT pour la droite ; l'écrou est derrière le départ",
    allowed=W8, maxBlocks=10, requiresLoop=True, requiresCondition=True,
    grid=[r.replace("l", "g") for r in from_maze(2325, (1, 4), (6, 6), "<", mark_from=(2, 4),
                                                  lethal=[(1, 3, "P"), (3, 3, "W"), (5, 5, "L")])],
    bolt=(2, 4),
    program=[REPETE(SI(CERCLE, G), SI(OBST, D), A)],
    bonusProgram=[R, A, REPETE(SI(CERCLE, G), SI(OBST, D), A)],
)

# 8-8 · Ouvrir la porte avant la boucle, puis clés et cadenas en route.
level(
    id="RI-078", name="Porte de service",
    concept="Préfixe (plaque) puis boucle à balises qui ramasse et déverrouille",
    allowed=W8, maxBlocks=23, requiresLoop=True, requiresCondition=True,
    grid=from_maze(14761, (6, 0), (4, 0), "v", mark_from=(6, 0),
                   edits=[(6, 6, "A"), (1, 4, "D"), (1, 6, "K"), (0, 1, "K"), (0, 3, "U"), (3, 0, "U")]),
    links=[(6, 6, "g78-1"), (1, 4, "g78-1")],
    program=[A, A, A, A, A, A, X, R, R,
             REPETE(SI(CLE, A, K, R), SI(CERCLE, G), SI(LOSANGE, D), SI(CADENAS, U), A)],
)

# 8-9 · Conditions imbriquées : un obstacle peut être un cadenas.
level(
    id="RI-079", name="Obstacle ou cadenas ?",
    concept="SI_OBSTACLE_DEVANT { SI_CADENAS_DEVANT { UTILISE } ; SI_OBSTACLE_DEVANT { TOURNE_DROITE } }",
    allowed=W8, maxBlocks=14, requiresLoop=True, requiresCondition=True,
    grid=[r.replace("l", "g") for r in from_maze(9305, (2, 2), (0, 6), "^",
                                                  edits=[(4, 0, "K"), (6, 4, "K"), (2, 6, "K"),
                                                         (5, 2, "U"), (4, 5, "U"), (1, 4, "U")])],
    program=[REPETE(SI(CLE, A, K), SI(CERCLE, G), SI(OBST, SI(CADENAS, U), SI(OBST, D)), A)],
)

# 8-10 · Synthèse : plaque, caisse, clés en alcôve, cadenas, porte et écrou.
level(
    id="RI-080", name="Le grand circuit",
    concept="Préfixe court puis une boucle qui combine balises, clés, cadenas et caisse",
    allowed=W8, maxBlocks=26, requiresLoop=True, requiresCondition=True,
    grid=from_maze(10477, (1, 6), (0, 2), ">", mark_from=(1, 6),
                   edits=[(0, 6, "A"), (3, 0, "D"), (3, 6, "C"), (6, 1, "K"), (5, 2, "U"),
                          (1, 0, "K"), (2, 1, "U")]),
    links=[(0, 6, "g80-1"), (3, 0, "g80-1")],
    bolt=(0, 4),
    program=[R, X, A,
             REPETE(SI(CLE, A, K, R), SI(CERCLE, G), SI(LOSANGE, D), SI(CADENAS, U), SI(CAISSE, P), SI(LIBRE, A))],
    bonusProgram=[R, X, G, A, A, R, R, D, A,
                  REPETE(SI(CLE, A, K, R), SI(CERCLE, G), SI(LOSANGE, D), SI(CADENAS, U), SI(CAISSE, P), SI(LIBRE, A))],
)
