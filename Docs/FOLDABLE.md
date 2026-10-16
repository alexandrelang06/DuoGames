# FOLDABLE.md — Vérification préalable (PRD §7.3)

> Statut : **Session 1, 10 septembre 2026.**
> Établi par recherche documentaire Apple. **Aucun point n'a pu être vérifié dans le simulateur Duo**
> (voir « Limite de vérification » en fin de document). Chaque réponse porte un niveau de confiance.
> À rejouer intégralement dès l'accès à Xcode 27.1.

## Légende des niveaux de confiance

| Niveau | Signification |
|---|---|
| **Confirmé** | Documentation Apple explicite (Tech Talk ou doc officielle) |
| **Probable** | Source secondaire cohérente et recoupée, non contredite par Apple |
| **Hypothèse** | Déduction de ma part. À vérifier impérativement au simulateur |

---

## Q1 — L'affichage simultané interne + externe est-il permis à une app tierce ?

### Réponse : NON pour notre cas d'usage. **Confirmé.**

L'accès à l'écran externe passe exclusivement par les **scene accessories**. La documentation Apple
(Tech Talk 111464, « Leverage multiple displays and scenes on iPhone Duo ») pose deux limites :

1. **Les nouvelles fenêtres ne peuvent pas être créées sur l'écran externe.** Celui-ci est réservé
   aux scene accessories ; l'UI principale reste sur l'écran interne.
2. Le seul accessoire documenté est **`CameraCaptureAccessory`**, disponible uniquement si l'app est
   en plein écran sur l'écran interne **et** qu'une session caméra est active. Il se désactive
   automatiquement à la fermeture de l'appareil.

Un jeu de bataille navale n'a aucune session caméra légitime. Détourner `CameraCaptureAccessory`
pour afficher une grille de jeu exposerait l'app à un rejet en revue, et activerait l'indicateur
caméra du système sans raison — signal de défiance majeur pour l'utilisateur.

### Objection physique, indépendante de l'API

Le Duo est un pliable **format livre à pliage interne**. Dans toute posture debout, les deux moitiés
de l'écran interne font face à la **même** direction générale. Aucune posture ne place une moitié
face au joueur A et l'autre face au joueur B. La « tente » du PRD §5.1, avec un joueur de chaque côté
voyant chacun son demi-écran, n'est donc pas réalisable — ni par l'API, ni par la géométrie.

### DÉCISION : **le plan B du PRD §7.4 est adopté.**

La bataille navale se joue en **mode à plat, tête-bêche, avec masquage à tour de rôle**. Cette
décision est structurante et validée par la procédure que le PRD prévoyait précisément pour cela.
Détail d'implémentation en fin de document.

---

## Q2 — Plage et granularité de `onHingeChange`

### Réponse partielle. **Confirmé** sur la nature, **Hypothèse** sur les seuils chiffrés.

**Confirmé.** SwiftUI expose le modificateur `onHingeChange` ; UIKit expose `UIHingeInteraction`.
Les deux rapportent :
- un **statut de haut niveau** : fermé, partiellement ouvert, complètement ouvert ;
- l'**angle de charnière en continu**, mis à jour en temps réel.

**Confirmé.** La valeur est `nil` sur appareil non pliable. Tout accès exige donc un `guard`.

**Confirmé, et directement contraignant pour nous.** Apple restreint explicitement l'usage :
ces données servent aux **effets et interactions** (parallaxe, animation de couverture), **jamais à
piloter le layout**, qui reste du ressort des size classes et des régions réservées.

> Conséquence PRD : le §7.1 est déjà aligné, et le §5.1 « anti-triche par angle de charnière » reste
> légitime — c'est un effet de jeu, pas une décision de mise en page.

**Hypothèse.** Les bornes numériques exactes (0° fermé, ~180° à plat), la granularité en degrés et
la fréquence d'émission ne sont pas documentées publiquement. Les seuils du PRD (60–120° tente,
>170° à plat) sont donc **non vérifiés** et traités comme constantes configurables isolées dans
`PostureKit`, pas comme des valeurs en dur dans les vues.

---

## Q3 — Comportement tactile près du pli en position partiellement pliée

### Réponse : non documenté publiquement. **Hypothèse.**

Aucune source Apple consultable ne décrit le comportement tactile réel au voisinage du pli sur un
appareil partiellement plié. Ce qui est **confirmé** en revanche, c'est l'existence des
**régions réservées**, interrogeables via le `GeometryProxy`, en distinguant :
- la **division** (le pli lui-même) ;
- l'**occlusion** (les caméras).

En l'absence de données, on applique une règle défensive, plus stricte que le PRD :

> **Aucun élément interactif ne doit se trouver dans la région de division, ni dans une marge de
> sécurité de 24 pt de part et d'autre** (le PRD §5.2 fixait déjà 24 pt pour l'air hockey ; on
> généralise à toute l'app).

---

## Q4 — Poses disponibles et seuils

### Réponse : les cinq poses sont **confirmées**, leurs seuils sont **Hypothèse**.

| Pose | Description Apple | Exploitable par nous ? |
|---|---|---|
| **Closed** | Replié, écran externe. Contrôles latéraux, plus de hauteur | Non (un seul petit écran) |
| **Portrait** | Ouvert à plat, tenu verticalement | Non (jeu de table) |
| **Landscape** | Ouvert à plat, horizontal. Split View deux vues | **Oui — support de l'air hockey et de la bataille navale plan B** |
| **Seated** | Partiellement plié sur une table, contenu en haut / contrôles en bas | Oui, pour le guidage de placement du hub |
| **Standing** | Écran **externe** exploité, StandBy, angle réglable | Non (voir Q1) |

Aucun seuil angulaire chiffré n'est publié pour le passage d'une pose à l'autre.

**Règle d'ingénierie qui en découle, alignée sur Apple :** le layout réagit aux **size classes et aux
régions réservées**, jamais au nom de la pose. La pose ne sert qu'au **guidage utilisateur**
(« pose ton téléphone à plat ») et aux effets. Cette contrainte est ce qui rend l'app portable
quand les seuils exacts seront connus.

---

## Conséquences sur l'architecture

1. **`PostureKit` est une abstraction totale.** Aucune API Duo n'est appelée depuis les vues. Le
   protocole `PostureProviding` expose pose, angle et régions réservées ; deux implémentations
   existent : `SimulatedPostureProvider` (utilisable aujourd'hui, SDK 26.5) et, à terme,
   `DuoPostureProvider` (SDK 27.1). La surface à corriger le jour du portage est ainsi d'un seul fichier.
2. **Bataille navale = mode à plat tête-bêche avec masquage** (décision Q1).
3. **Marge de sécurité de 24 pt** autour de la division, partout.
4. **Tous les seuils angulaires sont des constantes nommées** dans `PostureKit`, jamais des littéraux.

## Spécification du plan B — Bataille navale à plat

- **Placement.** Tour par tour. Le joueur actif place sa flotte sur sa moitié ; la moitié adverse
  affiche un carton de confidentialité opaque (pas un flou : un flou reste devinable). Transition
  sonore et compte à rebours de 3 s à la bascule, le temps que les joueurs échangent leur regard.
- **Tir.** Les deux moitiés sont visibles simultanément, tête-bêche. Chaque joueur voit sa flotte et
  sa grille de tir. Aucune information cachée n'est nécessaire à ce stade : les tirs sont publics.
- **Anti-triche.** L'angle de charnière sert de garde-fou : si l'appareil quitte la plage « à plat »
  pendant la phase de placement, le carton de confidentialité se verrouille et un son d'alerte
  se déclenche.
- **Gain inattendu.** Ce plan B fonctionne **aussi sur un iPhone classique**, ce qui fait converger
  le mode dégradé du PRD §6.3 avec le mode principal. Une seule UI à écrire et à tester au lieu de deux.

---

## Limite de vérification

Ce document a été produit sur un **MacBook Pro 2019 Intel**, où **Xcode 27 refuse de s'installer**
(binaire Apple silicon exclusif). L'outillage disponible est Xcode 26.5 / SDK iOS 26.5, qui ne
contient ni le simulateur iPhone Duo, ni `onHingeChange`, ni `ArrangementView`, ni `reservedRegion`.

**Aucune des quatre questions n'a donc été validée par l'exécution.** Les réponses marquées
« Confirmé » le sont par la documentation Apple, pas par l'observation.

**À rejouer intégralement** dès accès à une machine Apple silicon avec Xcode 27.1, en priorité Q2
(seuils) et Q3 (tactile près du pli), les deux seuls points où une surprise casserait du code déjà écrit.
