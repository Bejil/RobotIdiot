# Architecture — Phase 8

Robot Idiot sépare la simulation, le programme et le rendu. Les phases 1 à 8 sont en place. La phase 9 (debug UX, glitchs, bugs) et la phase 10 (design system et UX finale) ne sont pas commencées.

## Décisions

- **Cœur dans un package local** `Packages/RobotIdiotCore`. Il ne connaît ni UIKit ni SpriteKit. Les tests tournent avec `swift test` sur le Mac, sans simulateur.
- **L'application** (`RobotIdiot/`) est UIKit. Le plateau est une `SKScene` en vue de dessus : `y` logique augmente vers le haut, comme SpriteKit. Aucune projection isométrique.
- **Un niveau n'est pas une partie.** `Level` est immuable. `GameState` est la copie jouée. Réinitialiser reconstruit l'état depuis le niveau et conserve le programme.
- **Le robot n'occupe pas une case.** Sa position vit dans `RobotState`. Les cases portent le terrain, l'occupation, les objets et les mécanismes.
- **Un seul arbre de programme.** `Instruction` est un nœud. `REPETE` et `SI` sont des conteneurs, sans compteur de répétition. Les blocs et le texte lisent le même arbre.
- **L'interpréteur ignore la vitesse d'animation.** `SimulationEngine.step()` produit un événement. L'interface joue ensuite l'animation. Exécuter, Stop et pas à pas ne font que décider quand appeler `step()`.
- **REPETE est une boucle infinie.** Le moteur pousse une `ExecutionCursor.Frame` de politique `forever` et ne la dépile jamais. Il n'existe pas de compteur. Une commande absente du niveau reste refusée avec `commandUnavailable`.
- **SI évalue une condition sur l'état courant.** Une condition fausse saute le corps et n'est pas une erreur. Une condition absente est une erreur. `ConditionEvaluator` porte les six conditions.
- **Un cycle compare l'empreinte complète** avant d'exécuter l'instruction : robot, grille, objectifs et curseur. Les métriques et l'historique des empreintes n'en font pas partie. Le message joueur est « Le robot recommence exactement les mêmes gestes. »
- **Le plafond de sécurité n'est pas une commande.** `SafetyLimits` est interne au moteur. Le joueur ne le voit pas et ne le règle pas. Les sauts de structure (recommencer REPETE, fermer un SI) ne le consomment pas.
- **La victoire interrompt le programme.** Les commandes placées après l'atteinte du drapeau ne s'exécutent pas.
- **Les étoiles comparent à une solution de référence vérifiée** par le moteur. Elles ne sont pas présentées comme une preuve d'optimalité.
- **Les commandes proposées viennent du niveau** (`allowedCommands`). Le déblocage progressif branchera cette liste, pas l'éditeur.
- **Le thème est un identifiant.** `laboratory` ne change aucune règle. Les couleurs vivent dans `AppTheme`.
- **Un niveau généré se reconstruit depuis sa graine et la version du générateur.** `LevelGenerator` mélange la graine, le monde et le numéro de niveau. La version 1 construit des parcours : marche libre, parcours muré, couloir en boucle, suivi de mur avec `SI`.
- **La solution est simulée par le moteur du joueur.** Un niveau n'est accepté que si la référence gagne. Si la famille exige une boucle, le solveur séquentiel doit conclure à l'absence dans la limite de blocs. Si elle exige une condition, une boucle aveugle ne doit pas suffire. Sinon le générateur réessaie, puis sert un niveau de secours déjà validé.
- **Le solveur est borné.** `absent` signifie que l'espace annoncé a été épuisé. `interrupted` signifie que le budget a coupé la recherche. Les boucles viennent d'un catalogue de squelettes, pas d'une énumération de tous les arbres.
- **La génération est synchrone et pure.** L'application l'appelle hors du thread principal. La taille des plateaux reste petite : la difficulté change de famille plus que de dimensions.
- **La campagne est une suite de mondes, sans nombre plafond.** Chaque monde a 10 niveaux et un final. Sa graine dérive de la graine de campagne. Le monde 1 n'a que les déplacements, le monde 2 introduit `Répète`, le monde 3 introduit `Si`, puis les familles se mélangent. La courbe de difficulté monte puis se stabilise.
- **Un niveau visité est recopié en entier.** `CampaignStore` le garde dans `campaign.json`. Y revenir ne relance pas le générateur. Le niveau suivant est préparé en arrière-plan.
- **Le thème colore le plateau.** `laboratory`, `orchard`, `night` et `foundry` ne changent aucune règle.
- **Les interactions sont des commandes, pas des automatismes.** `RAMASSE` prend la clé sur la case du robot. `UTILISE` dépense cette clé sur une porte fermée devant lui. `POUSSE` avance une caisse d'une case si l'arrivée est libre, puis le robot occupe la case libérée. `ACTIVE` bascule l'interrupteur sous le robot, sinon celui juste devant, et la porte liée suit cet état. Une caisse et une porte fermée bloquent le passage. Une clé se traverse.
- **La campagne introduit une mécanique à la fois.** Le monde 4 pose les clés, le monde 5 les interrupteurs, le monde 6 les caisses. Ensuite les parcours et les mécanismes se mélangent. Un niveau d'interaction n'est accepté que si sa référence gagne et si le drapeau est inaccessible par les seuls déplacements.
- **Le texte et les blocs sont le même arbre.** `ProgramText` imprime et relit un pseudo-langage indenté, sans compteur de `REPETE`. Un brouillon illisible reste à l'écran et ne remplace pas le dernier programme valide. L'exécution ne lit que cet arbre.
- **Un défi libre est une recette, puis une copie figée.** `ChallengeRecipe` choisit une famille selon la graine, ou laisse le modèle de difficulté choisir un parcours si aucune mécanique n'est cochée. Le niveau généré est recopié dans `challenges.json`. Le rejouer ne relance pas le générateur. « Autre défi » avance la graine et garde les mêmes mécaniques.
- **Les réglages ne changent pas les règles.** Son, musique, vibrations, vitesse, contraste, taille du texte et réduction des animations vivent dans `PlaySettings`. La vitesse d'animation ne change pas le résultat de la simulation. Le contraste ne change que le trait du plateau, au prochain niveau.
- **Les sons sont synthétisés.** `Soundscape` joue des tampons PCM. Il n'y a pas de fichier audio. La musique reste sur l'écran de jeu, et seulement si elle est activée.
- **L'application reste hors ligne.** Pas de compte, pas de suivi. `PrivacyInfo.xcprivacy` déclare l'accès à `UserDefaults` (CA92.1). `ITSAppUsesNonExemptEncryption` est faux.

## Où ajouter la suite

| Phase | Point d'extension |
| --- | --- |
| Boucles et conditions | En place : `REPETE`, `SI`, les six conditions, l'imbrication dans l'éditeur et les niveaux 2 et 3. |
| Générateur | En place pour la navigation et les interactions : gabarits, graine, solveur borné, validation et niveau de secours. |
| Campagne | En place : mondes numérotés, déblocages, thèmes, sauvegarde des niveaux visités et préparation du suivant. |
| Interactions | En place : clés, portes, interrupteurs, caisses, et les familles de campagne qui les introduisent. |
| Texte | En place : pseudo-langage indenté, couleurs, numéros de ligne, suggestions, et le même arbre que les blocs. |
| Défis libres | En place : configuration, génération à la demande, favoris, historique et rejeu du niveau figé. |
| Finition | En place : réglages, sons synthétisés, vibrations, tutoriel, contraste, taille du texte, réduction des animations, manifeste de confidentialité et icône. |
| Debug UX | Phase 9, pas commencée : glitchs, bugs, parcours à la main. |
| Design system | Phase 10, pas commencée : couche visuelle et UX finale. |

## Parcours de relecture

Cinq tâches suffisent pour une passe manuelle, avant la phase 9 :

1. Ouvrir la première leçon, écrire Avance, et atteindre le drapeau.
2. Ouvrir « La boucle », lancer un `REPETE` vide, et lire le message de cycle.
3. Depuis Défis, cocher Clés, générer, puis retrouver le niveau dans Gardés.
4. Depuis Réglages, couper le son, passer en animation rapide, puis revenir à une partie.
5. Marquer un défi en favori, filtrer, puis effacer la progression après confirmation.

## Lancer les tests

```sh
swift test --package-path Packages/RobotIdiotCore
```
