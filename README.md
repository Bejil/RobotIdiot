# Robot Idiot

Jeu iOS de programmation visuelle : tu construis un programme, un petit robot l’exécute sur une grille vue de dessus, et tu dois atteindre le drapeau.

**Robot Idiot** mêle puzzle, logique et progression. Les commandes se débloquent monde après monde : d’abord avancer et tourner, puis les boucles, les conditions, les clés, les interrupteurs et les caisses.

| | |
| --- | --- |
| Plateforme | iOS (UIKit + SpriteKit) |
| Bundle ID | `com.michaelblin.RobotIdiot` |
| Version | 1.0 |
| Cœur de jeu | package Swift local `RobotIdiotCore` |
| Contenu | 100 niveaux · 10 mondes · catalogue V7 |

---

## Concept

Le joueur assemble un programme (blocs ou pseudo-texte) à partir des commandes autorisées par le niveau. Le moteur simule chaque pas de façon déterministe ; l’interface anime ensuite le résultat.

Objectif principal : **amener le robot jusqu’au drapeau**.  
Objectifs secondaires : ramasser des **écrous** (bonus optionnels), viser les **étoiles** selon une solution de référence, et dépenser les écrous pour des **aides**.

L’app reste jouable hors ligne pour la campagne. La publicité AdMob et le consentement UMP s’activent lorsque le réseau et le consentement le permettent.

---

## Jouer

1. Lancer **Continuer** depuis l’accueil, ou ouvrir la carte des mondes.
2. Composer un programme avec les commandes débloquées.
3. Lancer l’exécution, observer le robot, corriger, recommencer.
4. Atteindre le drapeau pour valider le niveau, collecter les écrous et progresser.

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
- Dépenses typiques : indice, solution, retry sans pub (voir `RewardEconomy` dans le cœur).

### Publicité

- Bannière sur l’accueil
- Interstitiel au lancement, après succès / erreur, et pubs récompensées pour l’aide
- Consentement via **Google UMP** avant toute requête AdMob
- En DEBUG : unités de test Google ; en Release : unités de production

---

## Architecture

Le projet sépare volontairement **règles** et **présentation**.

```
RobotIdiot/                     Application iOS (UIKit + SpriteKit)
├── UI/                         Accueil, campagne, éditeur, réglages, pubs
├── Board/                      Rendu SpriteKit (BoardScene)
├── Resources/                  Pack de niveaux (JSON V7)
└── Assets.xcassets             Thèmes par monde, commandes, UI

Packages/RobotIdiotCore/        Cœur pur (pas d’UIKit / SpriteKit)
├── GameCore/                   Level, GameState, grille, règles
├── SimulationEngine/           Interpréteur pas à pas
├── Catalog/                    Pack V7, campagne, récompenses
├── Generation/                 Générateur / solveur (défis & outils)
└── Tests/                      Tests unitaires Mac

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

Détails et historique des phases : voir [`ARCHITECTURE.md`](ARCHITECTURE.md).

---

## Contenu de campagne (V7)

- **10 mondes × 10 niveaux** (100 grilles)
- Introduction progressive des mécaniques (navigation → boucles → conditions → clés → interrupteurs → caisses, puis mélanges)
- Thèmes visuels par familles de mécaniques (`laboratory`, `orchard`, `night`, `foundry`)
- Assets dédiés par monde (sols, obstacles, drapeaux, écrous…)
- Fichier source : `RobotIdiot/Resources/robot_idiot_100_levels_v7.json` (aussi embarqué dans le package core)

Chaque niveau du pack a été validé par simulation : le programme de référence atteint le drapeau.

---

## Stack technique

| Couche | Techno |
| --- | --- |
| App | Swift, UIKit, SpriteKit |
| Cœur | Swift Package `RobotIdiotCore` (iOS 17+ / macOS 14+) |
| Pubs | [Google Mobile Ads](https://github.com/googleads/swift-package-manager-google-mobile-ads) |
| Consentement | [Google User Messaging Platform](https://github.com/googleads/swift-package-manager-google-user-messaging-platform) |
| Persistance | `UserDefaults` (progression, réglages, écrous, aides) |

Xcode ouvre `RobotIdiot.xcodeproj`. Le package local et les dépendances SPM sont résolus automatiquement.

---

## Prérequis

- macOS avec **Xcode** (projet configuré pour un déploiement iOS récent)
- Simulateur iPhone ou appareil physique
- Compte AdMob configuré (messages Privacy & messaging) pour le formulaire UMP en production

---

## Lancer l’app

1. Ouvrir `RobotIdiot.xcodeproj` dans Xcode.
2. Sélectionner le scheme **RobotIdiot**.
3. Choisir un simulateur iPhone (ou un device).
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

Couverture typique : simulation, programmes, boucles / conditions, interactions, campagne, pack V7, récompenses.

---

## Confidentialité

- Politique : [`PrivacyPolicies.html`](PrivacyPolicies.html)
- Contact : `michou855@hotmail.com`
- Données de jeu locales (progression, réglages, écrous)
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
| Pack de niveaux | `Catalog/` + JSON V7 |
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
