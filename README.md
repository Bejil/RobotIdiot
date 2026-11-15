# Robot Idiot

Jeu iOS de programmation visuelle : tu construis un programme, un petit robot l’exécute sur une grille vue de dessus, et tu dois atteindre le drapeau.

**Robot Idiot** mêle puzzle, logique et progression. Les commandes se débloquent monde après monde : d’abord avancer et tourner, puis les clés, les interrupteurs, les caisses et les portails. En parallèle de la campagne, deux missions quotidiennes figées proposent un **niveau du jour** et un **bug du jour**. Le **Mode Expert** (Le Laboratoire) offre un entraînement séparé à `SI` / `REPETE`.

| | |
| --- | --- |
| Plateforme | iPhone, iPad, iPhone Duo (UIKit + SpriteKit) |
| Bundle ID | `com.michaelblin.RobotIdiot` |
| Version | 1.0 |
| Cœur de jeu | package Swift local `RobotIdiotCore` |
| Contenu | 150 niveaux campagne (V14.1) · 100 défis · 100 bugs · 40 simulations Expert |

---

## Concept

Le joueur assemble un programme (blocs ou pseudo-texte) à partir des commandes autorisées par le niveau. Le moteur simule chaque pas de façon déterministe ; l’écran anime ensuite le résultat.

Objectif principal : **amener le robot jusqu’au drapeau**.  
Objectifs secondaires : ramasser des **écrous** (bonus optionnels), viser les **étoiles** selon une solution de référence, et dépenser les écrous pour des **aides**.

L’app reste jouable hors ligne pour la campagne, les défis du jour et le Mode Expert. La publicité AdMob et le consentement UMP s’activent lorsque le réseau et le consentement le permettent.

---

## Jouer

1. Lancer **Continuer** depuis l’accueil, ou ouvrir la carte des mondes.
2. Composer un programme avec les commandes débloquées.
3. Lancer l’exécution, observer le robot, corriger, recommencer.
4. Atteindre le drapeau pour valider le niveau, collecter les écrous et progresser.
5. Ouvrir **Défis du jour** pour le niveau et le bug figés de la journée.
6. Ouvrir **Mode Expert** (Le Laboratoire) pour l’entraînement `SI` / `REPETE` (à partir du monde 7 ; libre en DEBUG).

### Commandes

| Commande | Rôle |
| --- | --- |
| `AVANCE` / `RECULE` / tours | Déplacements de base |
| `REPETE` | Boucle infinie (corps répété tant que le programme tourne) |
| `SI` + condition | Branche conditionnelle sur l’état courant |
| `RAMASSE` | Prend la clé sur la case du robot |
| `UTILISE` | Ouvre une porte avec la clé tenue |
| `POUSSE` | Pousse une caisse d’une case |
| `ACTIVE` | Bascule un interrupteur (et la porte liée) |

Les commandes proposées viennent du niveau (`allowedCommands`) : l’éditeur n’affiche que ce qui est débloqué.

En **Aventure V14.1**, `SI` et `REPETE` restent visibles mais **verrouillés** : les solutions de référence n’utilisent que des primitives. Ces blocs se pratiquent dans le Mode Expert.

L’éditeur de blocs permet de **réordonner** les commandes par drag-and-drop (avant / après / dans un `SI` ou `REPETE`, avec aperçu de l’emplacement).

### Économie d’écrous

- Collectibles optionnels sur le plateau (`BoardBolt`).
- Crédités **une fois** par collectible lors d’une victoire.
- Missions quotidiennes : **+2 écrous** pour le niveau du jour, **+1 écrou** pour le bug (une seule récompense par mission et par jour).
- Dépenses typiques : indice, solution, retry sans pub (voir `RewardEconomy` dans le cœur).

### Défis du jour

Deux missions figées chaque jour civil (**fuseau Europe/Paris**), choisies selon le palier de progression et un index journalier depuis l’époque `2026-11-04` :

| Mission | Principe | Récompense |
| --- | --- | --- |
| **Niveau du jour** | Plateau dédié à résoudre comme un niveau classique | +2 écrous |
| **Bug du jour** | Programme déjà posé : **une seule** substitution de commande primitive | +1 écrou |

- Catalogue fixe : **100 défis** + **100 bugs** (10 par palier), plateaux distincts.
- Pack **V14.1** : missions en **primitives seulement** (pas de `SI` / `REPETE` à écrire).
- Sélection et statut de victoire persistés localement (`DailyStore`) : rouvrir l’app le même jour ne change pas les missions.
- Accès depuis l’accueil → hub **Défis du jour**.

### Mode Expert — Le Laboratoire

Entraînement séparé de l’Aventure, sans carte des mondes : une séquence linéaire de **40 simulations** (`EX-001` … `EX-040`).

| | |
| --- | --- |
| Accès | Accueil → Mode Expert (débloqué à partir du **monde 7** ; sans restriction en DEBUG) |
| Progression | Victoire + au moins 1 étoile pour ouvrir la suivante |
| Contrôles | Primitives dès le début ; `REPETE` puis `SI` et conditions se débloquent au fil des simulations |
| Persistance | `ExpertStore` (indépendant de la campagne) |
| UI | Tutoriel charté, hub (continuer / historique / maîtrise %), étoiles et score Expert |

Fichiers : `robot_idiot_expert_simulations_40.json`, `robot_idiot_expert_tutorial_fr.json`, `robot_idiot_expert_config.json`.  
Outils / validation : `Tools/level_design/expert_v1/` (`verify_expert.py`, etc.).

### Publicité

- Bannière sur l’accueil
- Interstitiel au lancement, après succès / erreur, et pubs récompensées pour l’aide
- Consentement via **Google UMP** avant toute requête AdMob
- En DEBUG : unités de test Google ; en Release : unités de production

---

## Compatibilité appareils

Application **universelle** (iPhone + iPad). L’écran de partie s’adapte à la géométrie :

| Contexte | Disposition |
| --- | --- |
| iPhone / iPad en portrait | Plateau au-dessus, panneau de commandes en feuille en bas (hauteur réglable) |
| iPad / grand écran en paysage (largeur ≥ 600) | Côte à côte : plateau à gauche, commandes à droite |
| **iPhone Duo** (charnière verticale) | Un panneau par écran, calé sur le pli (`reservedRegions` / division) ; rien sur la charnière |

La transition d’orientation et l’ouverture / fermeture Duo recalculent le layout sans quitter la partie.

---

## Architecture

Le projet sépare volontairement **règles** et **présentation**.

```
RobotIdiot/                     Application iOS (UIKit + SpriteKit)
├── UI/                         Accueil, campagne, défis, Expert, éditeur, réglages, pubs
├── Board/                      Rendu SpriteKit (BoardScene)
├── Resources/                  Pack campagne + quotidiens + Expert (JSON)
└── Assets.xcassets             Thèmes par monde, commandes, UI

Packages/RobotIdiotCore/        Cœur pur (pas d’UIKit / SpriteKit)
├── GameCore/                   Level, GameState, grille, règles
├── SimulationEngine/           Interpréteur pas à pas
├── Catalog/                    Campagne, défis du jour, Expert, récompenses
├── Generation/                 Générateur / solveur (outils)
└── Tests/                      Tests unitaires Mac (campagne, Daily, Expert…)

Tools/level_design/             Pipelines de packs (quotidiens, Expert, etc.)
PrivacyPolicies.html            Politique de confidentialité
ARCHITECTURE.md                 Décisions techniques détaillées
```

### Principes clés

- **`Level` est immuable** ; `GameState` est la copie jouée. Reset = nouvel état + même programme.
- **Le robot n’occupe pas une case** : sa position vit dans `RobotState`. Les cases portent terrain, objets et mécanismes.
- **Un seul arbre de programme** : blocs et texte lisent / écrivent le même modèle.
- **L’interpréteur ignore la vitesse d’animation** : `SimulationEngine.step()` produit un événement ; l’UI anime ensuite.
- **Victoire = interruption** : les commandes après le drapeau ne s’exécutent pas.
- **Les étoiles** comparent à une solution de référence vérifiée, sans prétendre à l’optimalité absolue.
- **Défis figés** : la sélection du jour est déterministe (date Paris + palier) et ne change plus une fois mémorisée.
- **Expert isolé** : progression et programmes Expert ne mélangent pas la sauvegarde Aventure.

Détails et historique des phases : voir [`ARCHITECTURE.md`](ARCHITECTURE.md).

---

## Contenu

### Campagne (V14.1 Aventure)

- **15 mondes × 10 niveaux** (150 grilles)
- Mondes 1–10 en 7×7 ; mondes 11–15 en 8×8
- Introduction progressive des mécaniques (navigation → clés → interrupteurs → caisses → portails, etc.)
- `SI` / `REPETE` **verrouillés** dans l’éditeur Aventure (boutons visibles mais non utilisables)
- Thèmes visuels par familles de mécaniques
- Fichier source : `robot_idiot_100_levels_v7.json` (nom historique ; pack V14.1 à 150 niveaux, aussi embarqué dans le package core)

Chaque niveau du pack a été validé par simulation : le programme de référence atteint le drapeau.

### Packs quotidiens

| Fichier | Contenu |
| --- | --- |
| `robot_idiot_daily_challenges_100.json` | 100 niveaux du jour |
| `robot_idiot_daily_bugs_100.json` | 100 bugs (référence plateau + programme bugué + commandes dispo) |
| `robot_idiot_daily_config.json` | Fuseau, époque, paliers, montants de récompense |

### Pack Expert

| Fichier | Contenu |
| --- | --- |
| `robot_idiot_expert_simulations_40.json` | 40 simulations du Laboratoire |
| `robot_idiot_expert_tutorial_fr.json` | Tutoriel Expert (5 pages) |
| `robot_idiot_expert_config.json` | Navigation, déblocages, scoring |

---

## Stack technique

| Couche | Techno |
| --- | --- |
| App | Swift, UIKit, SpriteKit |
| Cœur | Swift Package `RobotIdiotCore` (iOS 17+ / macOS 14+) |
| Pubs | [Google Mobile Ads](https://github.com/googleads/swift-package-manager-google-mobile-ads) |
| Consentement | [Google User Messaging Platform](https://github.com/googleads/swift-package-manager-google-user-messaging-platform) |
| Persistance | `UserDefaults` (progression, réglages, écrous, aides, défis du jour, Expert) |

Xcode ouvre `RobotIdiot.xcodeproj`. Le package local et les dépendances SPM sont résolus automatiquement.

---

## Prérequis

- macOS avec **Xcode** (projet configuré pour un déploiement iOS récent)
- Simulateur ou appareil : iPhone, iPad, ou iPhone Duo
- Compte AdMob configuré (messages Privacy & messaging) pour le formulaire UMP en production

---

## Lancer l’app

1. Ouvrir `RobotIdiot.xcodeproj` dans Xcode.
2. Sélectionner le scheme **RobotIdiot**.
3. Choisir un simulateur (iPhone, iPad…) ou un device.
4. Build & Run (`⌘R`).

En ligne de commande (exemple) :

```sh
xcodebuild \
  -project RobotIdiot.xcodeproj \
  -scheme RobotIdiot \
  -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  build
```

---

## Tests du cœur

Les règles et le moteur se testent **sans simulateur** :

```sh
swift test --package-path Packages/RobotIdiotCore
```

Couverture typique : simulation, programmes, boucles / conditions, interactions, campagne V14.1, pack niveaux, récompenses, **sélection et catalogues quotidiens**, **catalogue Expert**.

Validation outils Expert :

```sh
python3 Tools/level_design/expert_v1/verify_expert.py
```

---

## Confidentialité

- Politique : [`PrivacyPolicies.html`](PrivacyPolicies.html)
- Contact : `michou855@hotmail.com`
- Données de jeu locales (progression, réglages, écrous, défis du jour, Mode Expert)
- Publicité Google AdMob + éventuelle collecte associée (identifiants pub, IP approximative, interactions)
- Formulaire de consentement UMP au lancement lorsque requis (EEE, etc.)
- Entrée **Options de confidentialité** dans les Réglages si UMP l’exige

Pour App Store Connect, héberger / prévisualiser la page HTML (par ex. via GitHub + htmlpreview) et coller l’URL publique.

---

## Structure utile pour contribuer

| Besoin | Où regarder |
| --- | --- |
| Règles de déplacement / objets | `Packages/.../GameCore/WorldRules.swift` |
| Exécution du programme | `Packages/.../SimulationEngine/` |
| Pack de niveaux campagne | `Catalog/` + `robot_idiot_100_levels_v7.json` (V14.1) |
| Défis / bugs du jour | `DailyCatalog.swift`, `DailySelection.swift`, `DailyStore.swift`, `DailyHubViewController.swift` |
| Mode Expert | `ExpertCatalog.swift`, `ExpertStore.swift`, `ExpertHubViewController.swift`, `Tools/level_design/expert_v1/` |
| Layout iPad / Duo | `GameViewController` (`shouldUseSideBySideLayout`, `verticalFold`) |
| Plateau et animations | `RobotIdiot/Board/BoardScene.swift` |
| Éditeur / partie | `BlockEditorView.swift`, `GameViewController.swift` |
| Campagne / déblocages | `CampaignStore.swift`, `WorldMapViewController.swift` |
| Écrous & aides | `BoltWallet.swift`, `HelpUnlockStore.swift` |
| Pubs & consentement | `AdsService.swift`, `AdsConsentManager.swift` |
| Thème UI | `AppTheme.swift` |

---

## Licence / statut

Projet applicatif privé en développement actif (version marketing 1.0).  
Les SDK Google Mobile Ads et User Messaging Platform restent soumis à leurs licences respectives.
