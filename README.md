# Robot Idiot

Jeu iOS de programmation visuelle : tu construis un programme, un petit robot l’exécute sur une grille vue de dessus, et tu dois atteindre le drapeau.

**Robot Idiot** mêle puzzle, logique et progression. Les commandes se débloquent monde après monde : d’abord avancer et tourner, puis les boucles, les conditions, les clés, les interrupteurs et les caisses. En parallèle de la campagne, deux missions quotidiennes figées proposent un **niveau du jour** et un **bug du jour**.

| | |
| --- | --- |
| Plateforme | iPhone, iPad, iPhone Duo (UIKit + SpriteKit) |
| Bundle ID | `com.michaelblin.RobotIdiot` |
| Version | 1.0 |
| Cœur de jeu | package Swift local `RobotIdiotCore` |
| Contenu | 100 niveaux campagne · 100 défis · 100 bugs · catalogue V7 |

---

## Concept

Le joueur assemble un programme (blocs ou pseudo-texte) à partir des commandes autorisées par le niveau. Le moteur simule chaque pas de façon déterministe ; l’écran anime ensuite le résultat.

Objectif principal : **amener le robot jusqu’au drapeau**.  
Objectifs secondaires : ramasser des **écrous** (bonus optionnels), viser les **étoiles** selon une solution de référence, et dépenser les écrous pour des **aides**.

L’app reste jouable hors ligne pour la campagne et les défis du jour. La publicité AdMob et le consentement UMP s’activent lorsque le réseau et le consentement le permettent.

---

## Jouer

1. Lancer **Continuer** depuis l’accueil, ou ouvrir la carte des mondes.
2. Composer un programme avec les commandes débloquées.
3. Lancer l’exécution, observer le robot, corriger, recommencer.
4. Atteindre le drapeau pour valider le niveau, collecter les écrous et progresser.
5. Ouvrir **Défis du jour** pour le niveau et le bug figés de la journée.

### Commandes

| Commande | Rôle |
| --- | --- |
| `AVANCE` / tours | Déplacements de base |
| `REPETE` | Boucle infinie (corps répété tant que le programme tourne) |
| `SI` + condition | Branche conditionnelle sur l’état courant |
| `RAMASSE` | Prend la clé sur la case du robot |
| `UTILISE` | Ouvre une porte avec la clé tenue |
| `POUSSE` | Pousse une caisse d’une case |
| `ACTIVE` | Bascule un interrupteur (et la porte liée) |

Les commandes proposées viennent du niveau (`allowedCommands`) : l’éditeur n’affiche que ce qui est débloqué.

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
- Sélection et statut de victoire persistés localement (`DailyStore`) : rouvrir l’app le même jour ne change pas les missions.
- Accès depuis l’accueil → hub **Défis du jour**.

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
├── UI/                         Accueil, campagne, défis, éditeur, réglages, pubs
├── Board/                      Rendu SpriteKit (BoardScene)
├── Resources/                  Pack campagne V7 + packs quotidiens (JSON)
└── Assets.xcassets             Thèmes par monde, commandes, UI

Packages/RobotIdiotCore/        Cœur pur (pas d’UIKit / SpriteKit)
├── GameCore/                   Level, GameState, grille, règles
├── SimulationEngine/           Interpréteur pas à pas
├── Catalog/                    Pack V7, campagne, défis du jour, récompenses
├── Generation/                 Générateur / solveur (outils)
└── Tests/                      Tests unitaires Mac (dont DailyCatalog)

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

Détails et historique des phases : voir [`ARCHITECTURE.md`](ARCHITECTURE.md).

---

## Contenu

### Campagne (V7)

- **10 mondes × 10 niveaux** (100 grilles)
- Introduction progressive des mécaniques (navigation → boucles → conditions → clés → interrupteurs → caisses, puis mélanges)
- Thèmes visuels par familles de mécaniques (`laboratory`, `orchard`, `night`, `foundry`)
- Assets dédiés par monde (sols, obstacles, drapeaux, écrous…)
- Fichier source : `RobotIdiot/Resources/robot_idiot_100_levels_v7.json` (aussi embarqué dans le package core)

Chaque niveau du pack a été validé par simulation : le programme de référence atteint le drapeau.

### Packs quotidiens

| Fichier | Contenu |
| --- | --- |
| `robot_idiot_daily_challenges_100.json` | 100 niveaux du jour |
| `robot_idiot_daily_bugs_100.json` | 100 bugs (référence plateau + programme bugué + commandes dispo) |
| `robot_idiot_daily_config.json` | Fuseau, époque, paliers, montants de récompense |

---

## Stack technique

| Couche | Techno |
| --- | --- |
| App | Swift, UIKit, SpriteKit |
| Cœur | Swift Package `RobotIdiotCore` (iOS 17+ / macOS 14+) |
| Pubs | [Google Mobile Ads](https://github.com/googleads/swift-package-manager-google-mobile-ads) |
| Consentement | [Google User Messaging Platform](https://github.com/googleads/swift-package-manager-google-user-messaging-platform) |
| Persistance | `UserDefaults` (progression, réglages, écrous, aides, défis du jour) |

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

Couverture typique : simulation, programmes, boucles / conditions, interactions, campagne, pack V7, récompenses, **sélection et catalogues quotidiens**.

---

## Confidentialité

- Politique : [`PrivacyPolicies.html`](PrivacyPolicies.html)
- Contact : `michou855@hotmail.com`
- Données de jeu locales (progression, réglages, écrous, défis du jour)
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
| Pack de niveaux campagne | `Catalog/` + JSON V7 |
| Défis / bugs du jour | `DailyCatalog.swift`, `DailySelection.swift`, `DailyStore.swift`, `DailyHubViewController.swift` |
| Layout iPad / Duo | `GameViewController` (`shouldUseSideBySideLayout`, `verticalFold`) |
| Plateau et animations | `RobotIdiot/Board/BoardScene.swift` |
| Éditeur / partie | `RobotIdiot/UI/GameViewController.swift` |
| Campagne / déblocages | `CampaignStore.swift`, `WorldMapViewController.swift` |
| Écrous & aides | `BoltWallet.swift`, `HelpUnlockStore.swift` |
| Pubs & consentement | `AdsService.swift`, `AdsConsentManager.swift` |
| Thème UI | `AppTheme.swift` |

---

## Licence / statut

Projet applicatif privé en développement actif (version marketing 1.0).  
Les SDK Google Mobile Ads et User Messaging Platform restent soumis à leurs licences respectives.
