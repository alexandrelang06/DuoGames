# PRD — Duo Games (nom de travail)

> Ce document sert à la fois de PRD et de prompt initial pour Claude Code.
> À placer à la racine du repo. Lis-le intégralement avant d'écrire la moindre ligne de code.
> Les fichiers `DESIGN.md` et `FOLDABLE.md` décrits en annexe sont à générer dès la première session, puis à respecter strictement.

---

## 1. Contexte et opportunité

Apple a lancé l'iPhone Duo (premier iPhone pliable, format livre) le 23 octobre 2026, sous iOS 27.1. Écran interne 7,6 pouces, écran externe 5,4 pouces, à partir de 1 999 $. Base installée estimée à 6-8 millions d'unités fin 2026.

La fenêtre de marché est celle des apps exploitant réellement le form factor pliable. Cette catégorie est quasi vide (aucun succès commercial documenté sur Samsung Fold/Pixel Fold). Apple met historiquement en avant les apps qui exploitent le nouveau matériel dès le lancement (featuring éditorial App Store).

Contrainte majeure côté validation. La Guideline 4.2 (Minimum Functionality) élimine les apps gadget sans utilité. La Guideline 2.5.2 durcit la revue des apps générées par IA sans supervision. L'app doit donc offrir une vraie valeur de jeu, pas un gag.

## 2. Vision produit

**Une collection de jeux à deux joueurs en face à face, impossibles sur un iPhone classique, exploitant les deux postures physiques de l'iPhone Duo.**

Deux modes physiques structurent tout le produit.

- **Mode tente** (appareil plié en toit, posé debout sur la table, un joueur de chaque côté). Chaque joueur voit uniquement son demi-écran. Le pli devient un mur physique qui cache l'information. Cas d'usage pour les jeux à information cachée
- **Mode à plat** (appareil ouvert à 180°, posé sur la table, un joueur de chaque côté). Plateau partagé affiché tête-bêche, chaque moitié orientée vers son joueur. Cas d'usage pour les jeux de plateau classiques

Positionnement. Le jeu d'apéro et de table premium du lancement de l'iPhone Duo. Deux personnes, un appareil, zéro compte, zéro réseau, on pose le téléphone et on joue en 10 secondes.

## 3. Modèle économique

- Achat unique à 1,99 €, aucun abonnement, aucune pub, aucun achat intégré en v1
- Compte Apple Developer individuel (99 $/an), Small Business Program (commission 15 %)
- Localisation français + anglais dès la v1

## 4. Périmètre

### v1.0 (objectif de sortie le 23 octobre 2026, jour du lancement du Duo)

1. **Bataille navale** (mode tente)
2. **Air hockey** (mode à plat)
3. Hub de sélection des jeux avec détection de posture et guidage de placement de l'appareil
4. Tutoriel de mise en place par jeu (comment poser l'appareil, où s'asseoir)
5. Écran de score de session (parties gagnées par joueur)

### v1.x (post-lancement, ne rien coder maintenant mais architecturer pour)

- Morpion et Puissance 4 (mode à plat)
- Devine-le-mot avec packs thématiques (mode tente)
- Packs de thèmes visuels additionnels

### Hors périmètre définitif

- Multijoueur en ligne, comptes, classements distants
- Jeux de cartes à main cachée (le format à un seul appareil ne le permet pas)
- Toute forme de collecte de données au-delà du strict minimum Apple

## 5. Spécifications des jeux

### 5.1 Bataille navale (mode tente)

**Setup.** L'appareil est plié entre 60° et 120°, posé debout. Chaque joueur fait face à un écran (écran interne côté A, écran externe côté B, selon ce que permet l'API. Si l'affichage simultané interne + externe n'est pas possible, basculer sur le plan B décrit en 7.4).

**Déroulé.**
1. Phase de placement. Chaque joueur place sa flotte sur sa grille 10×10 par drag and drop (5 navires classiques, tailles 5/4/3/3/2). Rotation par tap. Validation par bouton
2. Phase de tir au tour par tour. Le joueur actif tape une case de la grille de tir. L'app affiche à l'eau, touché ou coulé des deux côtés avec animations et sons distincts
3. Victoire quand une flotte est intégralement coulée. Écran de victoire avec proposition de revanche

**Règles d'interface.**
- Chaque demi-écran affiche deux grilles (sa flotte en bas, sa grille de tir en haut) orientées vers son joueur
- Indicateur clair de qui doit jouer, visible des deux côtés
- Aucun élément interactif dans la reserved region du pli
- Anti-triche léger. Un voile s'affiche si l'angle de la charnière sort de la plage tente (l'appareil a été soulevé ou ouvert)

### 5.2 Air hockey (mode à plat)

**Setup.** Appareil ouvert à plat (angle > 170°), posé sur la table. Le terrain occupe tout l'écran interne, affiché tête-bêche. La ligne médiane du terrain coïncide avec l'axe du pli mais aucun élément de jeu critique ne s'arrête exactement dessus (gouttière visuelle de sécurité de 24 pt de part et d'autre).

**Déroulé.**
1. Chaque joueur contrôle son maillet au doigt, limité à sa moitié de terrain
2. Physique du palet (rebonds sur les bords, accélération au contact, friction légère)
3. Match en 7 buts, engagement alterné, pause par double tap à deux doigts
4. Score affiché en miroir aux deux extrémités, lisible par chaque joueur

**Règles d'interface.**
- Multi-touch obligatoire (deux doigts simultanés minimum, tester 4 points de contact)
- Le palet ne doit jamais devenir invisible dans la zone du pli (le faire passer vite ou compenser visuellement)
- Haptique à chaque rebond et à chaque but

## 6. Architecture technique

### 6.1 Stack

- **Langage** Swift 6, **UI** SwiftUI, cible minimale iOS 27.1, compilation avec le SDK iOS 27.1 / Xcode 27.1 (obligatoire pour l'expérience Duo bord à bord)
- **Air hockey** en SpriteKit (physique, particules) hébergé dans une vue SwiftUI via `SpriteView`
- **Bataille navale, hub, menus** en SwiftUI pur
- Aucune dépendance tierce. Zéro package externe en v1
- Persistance minimale (scores de session en mémoire, préférences en `UserDefaults`)

### 6.2 Structure du projet

```
DuoGames/
  App/                  point d'entrée, cycle de vie UIScene
  Core/
    Posture/            détection de pose (tente, à plat, autre) et angle charnière
    Haptics/            patterns Core Haptics centralisés
    Audio/              lecteur de sons centralisé
    DesignSystem/       tokens issus de DESIGN.md (couleurs, typo, espacements, radius)
  Features/
    Hub/                sélection des jeux, guidage de posture
    Battleship/         modèle, moteur de règles, vues tente
    AirHockey/          scène SpriteKit, physique, vues
  Resources/            assets, sons, localisations fr/en
  Docs/                 PRD.md (ce fichier), DESIGN.md, FOLDABLE.md, LICENSES.md
```

### 6.3 Règles d'ingénierie

- Layouts exclusivement en size classes, safe areas et géométrie locale. Jamais de dimension d'écran codée en dur, jamais de `UIScreen.main`, jamais de verrou d'orientation
- Le moteur de règles de chaque jeu est une cible Swift pure testable sans UI (tests unitaires sur placement, tirs, détection de victoire, physique simplifiée)
- Tout code lié à la charnière gère le cas `nil` (appareil non pliable). L'app doit se lancer proprement sur un iPhone classique avec un écran expliquant que les jeux nécessitent un iPhone Duo, plus un mode dégradé pass and play pour la bataille navale (on se passe l'appareil, écran de transition qui masque la grille)
- Accessibilité. Contraste AA minimum, VoiceOver sur le hub et les menus, Dynamic Type sur tout le texte hors plateau de jeu

## 7. Intégration iPhone Duo

### 7.1 APIs à utiliser

- `onHingeChange` (SwiftUI) pour l'angle de charnière et l'état de pliage. Usage limité aux effets et à la détection de posture, jamais pour piloter le layout
- `ArrangementView` en mode `.split` pour les dispositions deux zones
- `reservedRegion` via `GeometryProxy` pour éviter le pli et les caméras
- Poses système (Closed, Portrait, Landscape, Seated, Standing) pour le guidage de placement dans le hub

### 7.2 Règles pliable non négociables

- Aucun élément interactif dans la division region du pli
- En pose posée à plat ou tente, contenu vers le haut et contrôles vers le bas de chaque zone
- Le layout réagit aux size classes, pas au nom de la pose
- Tester chaque écran dans le simulateur iPhone Duo aux angles 60°, 90°, 120° et 180°, plus iPhone classique 6,1 pouces

### 7.3 Vérification préalable obligatoire (première tâche du projet)

Avant tout développement, vérifier dans la doc Apple et le simulateur les hypothèses suivantes, et consigner les réponses dans `FOLDABLE.md`.

1. L'affichage simultané écran interne + écran externe est-il permis à une app tierce en mode tente
2. La plage d'angles réellement exposée par `onHingeChange` et sa granularité
3. Le comportement tactile réel près du pli en mode partiellement plié
4. Les poses disponibles et leurs seuils exacts

### 7.4 Plan B si l'affichage double écran en tente est impossible

La bataille navale bascule en mode à plat tête-bêche avec masquage. Chaque joueur voit sa moitié, les grilles adverses sont floutées, et un carton de confidentialité s'affiche pendant la phase de placement (chacun place sa flotte à tour de rôle, l'autre détourne le regard, transition sonore). Moins élégant mais fonctionnel. Décision à prendre à l'issue de 7.3 et à documenter.

## 8. Design (résumé, détail dans DESIGN.md)

### 8.1 Principe

Une identité parapluie éditoriale pour le hub et les menus, une matière distincte par jeu. Interdiction absolue du rendu IA générique.

### 8.2 Identité parapluie (hub, menus, réglages)

- Style éditorial type NYT Games. Fond crème `#FAF8F3`, encre `#1A1A1A`, un accent par jeu
- Typographie display **Zilla Slab** (SIL, embarquée), texte courant en **SF Pro** système
- Navigation et chrome en composants natifs Liquid Glass (barres, feuilles), jamais de verre sur le contenu

### 8.3 Bataille navale, matière bois et papier

- Palette bois miel `#C8A063`, feutre marine `#1E3A5F`, crème `#F2E8D5`, laiton `#B08D57`, rouge touché `#C0392B`
- Textures discrètes et nettes, tactilité drag and drop physique, navires stylisés (5 à 8 illustrations à commander en freelance, budget 500 à 1 200 €, placeholders vectoriels sobres en attendant)
- Sons bois, splash, corne de brume. Haptique `.rigid` au placement, pattern victoire au coulage

### 8.4 Air hockey, matière néon rétro-arcade

- Palette noir bleuté `#0D0221`, magenta `#FF2A6D`, cyan `#05D9E8`, jaune `#F9F002`
- Glow parcimonieux et structuré (grille perspective, chrome du terrain), typographie de score **Orbitron**
- Le duo cyan/magenta n'est acceptable que porté par cette direction arcade complète, jamais en simple accent
- Sons chiptune, thock du palet. Haptique nette à chaque rebond, double impulsion au but

### 8.5 Liste noire anti-slop (à recopier en tête de DESIGN.md)

Interdits partout. Dégradés violet vers cyan hors contexte arcade, glassmorphism sur les surfaces de jeu, police Inter, séries de cards identiques, emojis en guise d'icônes, blobs 3D, easing bounce systématique, dark mode par défaut hors air hockey, halos néon non structurés.

### 8.6 Son et haptique

Traités comme la moitié de la direction artistique. Un son et un pattern haptique nommés par événement de jeu, centralisés dans `Core/Haptics` et `Core/Audio`. Sources CC0 uniquement (Kenney Audio, Sonniss GDC, Freesound filtré CC0), licences consignées fichier par fichier dans `LICENSES.md`.

## 9. App Store

- Nom provisoire Duo Games (vérifier la disponibilité, proposer 5 alternatives)
- Catégorie Jeux > Plateau. Prix 1,99 € (tier équivalent)
- La fiche App Store doit montrer l'usage physique (photos de deux personnes autour de l'appareil en tente et à plat). Prévoir une vidéo preview de 20 secondes
- Argumentaire 4.2 préparé. Moteurs de jeu complets, deux modes physiques inédits, mode dégradé iPhone classique, aucune coquille vide
- Soumission visée au plus tard le 18 octobre 2026 pour une sortie le 23

## 10. Critères d'acceptation v1.0

1. Une partie complète de bataille navale et d'air hockey jouable de bout en bout dans le simulateur Duo sans crash ni état bloquant
2. Aucun élément interactif ne chevauche jamais une reserved region, vérifié aux 4 angles de test
3. Moteurs de règles couverts par des tests unitaires (placement invalide, victoire, rebonds) qui passent en CI locale
4. Lancement propre sur iPhone classique avec le mode dégradé fonctionnel
5. Zéro texte en dur, tout passe par les fichiers de localisation fr/en
6. DESIGN.md respecté, vérifiable écran par écran contre la liste noire
7. Temps entre le lancement de l'app et le premier coup joué inférieur à 30 secondes pour deux nouveaux joueurs

## 11. Méthode de travail attendue de Claude Code

1. **Session 1.** Lire ce PRD. Exécuter la vérification 7.3 et produire `FOLDABLE.md`. Générer `DESIGN.md` complet (tokens détaillés à partir de la section 8). Créer le squelette du projet et la cible de tests. Ne rien coder d'autre
2. **Session 2.** Moteur de règles bataille navale avec tests, puis UI tente (ou plan B selon 7.3)
3. **Session 3.** Scène SpriteKit air hockey, physique, puis habillage néon
4. **Session 4.** Hub, guidage de posture, tutoriels, localisation, mode dégradé
5. **Session 5.** Polish (son, haptique, animations), passe accessibilité, passe anti-slop écran par écran, assets App Store
6. À chaque session, terminer par un état des lieux dans `Docs/JOURNAL.md` (fait, reste à faire, décisions prises, questions ouvertes)
7. Ne jamais inventer une API Duo. En cas de doute sur une signature, le signaler dans le journal et proposer une abstraction isolée dans `Core/Posture` pour limiter la surface à corriger
8. Toute dérogation au PRD ou au DESIGN.md doit être proposée explicitement, jamais appliquée silencieusement
