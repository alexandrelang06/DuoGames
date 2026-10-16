# DESIGN.md — Duo Games

> Source d'autorité pour toute décision visuelle, sonore et haptique.
> Généré en Session 1 à partir du PRD §8. Toute dérogation se propose, jamais ne s'applique (PRD §11.8).

---

## 0. Liste noire anti-slop

**Interdits partout, sans exception ni discussion.**

| Interdit | Pourquoi |
|---|---|
| Dégradé violet → cyan | Signature visuelle de l'IA générative. Toléré **uniquement** dans la direction arcade complète de l'air hockey |
| Glassmorphism sur une surface de jeu | Le verre est réservé au chrome natif (barres, feuilles). Jamais sur le contenu |
| Police Inter | Marqueur de template. On a Zilla Slab et SF Pro |
| Séries de cards identiques | Rythme de page mort. Le hub est éditorial, pas une grille de produits |
| Emoji en guise d'icône | Rendu incohérent, non localisable, non accessible |
| Blob 3D, forme organique flottante | Décor sans fonction |
| Easing `bounce` systématique | Une seule courbe expressive par écran, choisie |
| Dark mode par défaut | Sauf air hockey, dont le noir est la matière |
| Halo néon non structuré | Le glow doit suivre une géométrie (grille, chrome), jamais nimber au hasard |

**Test d'acceptation.** Chaque écran est confronté à ce tableau ligne par ligne avant d'être déclaré fini (PRD §10.6).

---

## 1. Architecture visuelle

Une **identité parapluie éditoriale** pour le hub, les menus, l'espace joueur et l'écran de déblocage.
Une **matière distincte par jeu**, qui prend tout l'écran une fois la partie lancée.

La transition hub → jeu est le moment où la matière change. Elle doit être franche, jamais un fondu mou.

---

## 2. Identité parapluie

### 2.1 Couleurs

| Token | Valeur | Usage |
|---|---|---|
| `umbrella.paper` | `#FAF8F3` | Fond général |
| `umbrella.ink` | `#1A1A1A` | Texte principal |
| `umbrella.inkSecondary` | `#5C5A55` | Texte secondaire, légendes |
| `umbrella.rule` | `#E3DED3` | Filets, séparateurs |
| `accent.battleship` | `#1E3A5F` | Accent bataille navale dans le hub |
| `accent.airHockey` | `#FF2A6D` | Accent air hockey dans le hub |

Un seul accent visible à la fois par zone. Jamais les deux accents côte à côte à intensité égale.

### 2.2 Typographie

| Rôle | Police | Détail |
|---|---|---|
| Display | **Zilla Slab** (SIL OFL, embarquée) | Titres de jeux, titres d'écran |
| Texte courant | **SF Pro** (système) | Tout le reste, Dynamic Type intégral |
| Score arcade | **Orbitron** (SIL OFL, embarquée) | Air hockey **uniquement** |

Zilla Slab ne descend jamais sous 20 pt. En dessous, c'est SF Pro.

### 2.3 Espacement et formes

Échelle en multiples de 4 : `4, 8, 12, 16, 24, 32, 48, 64`.
Rayons : `8` (contrôles), `16` (surfaces), `28` (feuilles modales).
**Marge de sécurité du pli : 24 pt de part et d'autre**, non négociable (FOLDABLE.md Q3).

### 2.4 Chrome

Composants natifs Liquid Glass pour les barres et les feuilles. Jamais de verre sur le contenu de jeu.

---

## 3. Matière — Bataille navale

Bois et papier. Tactile, mat, sans brillance.

| Token | Valeur |
|---|---|
| `bs.wood` | `#C8A063` |
| `bs.felt` | `#1E3A5F` |
| `bs.paper` | `#F2E8D5` |
| `bs.brass` | `#B08D57` |
| `bs.hit` | `#C0392B` |

**Textures.** Discrètes et nettes. Grain de bois à faible contraste, papier à fibre visible de près uniquement. Aucune texture ne doit survivre au passage en Dynamic Type XXL : elle recule, le texte prime.

**Navires.** 5 à 8 illustrations à commander en freelance (budget 500 à 1 200 €). En attendant, placeholders vectoriels sobres : silhouette pleine en `bs.felt`, aucun détail inventé, aucune illustration générée.

**Carton de confidentialité** (plan B, FOLDABLE.md). Opaque, jamais flouté — un flou reste devinable. Pleine surface en `bs.felt`, une seule ligne en Zilla Slab, compte à rebours de 3 s.

---

## 4. Matière — Arcade (air hockey et Tron)

Néon rétro-arcade. C'est la seule zone de l'app où le noir et le glow sont légitimes.

> **Décision de Session 3.** Tron partage cette matière avec l'air hockey : même palette, même
> typographie Orbitron, même discipline du glow. Les deux sont les jeux temps réel de la collection,
> et Tron est par nature un jeu d'arcade. Les trois jeux au tour par tour restent sur la matière
> bois et papier. Aucun autre écran n'a le droit à cette palette.

| Token | Valeur |
|---|---|
| `ah.void` | `#0D0221` |
| `ah.magenta` | `#FF2A6D` |
| `ah.cyan` | `#05D9E8` |
| `ah.amber` | `#F9F002` |

**Règle de discipline.** Le duo cyan/magenta n'est acceptable que porté par la direction arcade complète : grille en perspective, chrome du terrain, typographie Orbitron. Sorti de ce contexte, c'est du slop.

**Glow.** Structuré uniquement : il suit le tracé du terrain, la ligne médiane, le contour des buts. Jamais de halo libre.

**Ligne médiane.** Elle coïncide avec l'axe du pli, mais la gouttière de 24 pt de part et d'autre reste vide de tout élément critique. Le palet la traverse toujours en vitesse ; s'il s'y immobilise, le moteur le relance (`TableGeometry.isInFoldGutter`).

---

## 5. Son et haptique

Traités comme la moitié de la direction artistique (PRD §8.6). Un son **et** un pattern haptique nommés par événement, centralisés dans `Core/Audio` et `Core/Haptics`. Le moteur émet une clé, jamais un fichier.

| Clé d'événement | Son | Haptique |
|---|---|---|
| `game.select` | clic doux | impulsion légère, intensité réduite |
| `game.move` | bois léger | légère |
| `game.place` | bois moyen | `.rigid` |
| `game.capture` | bois lourd | moyenne |
| `game.rejected` | erreur brève | avertissement |
| `game.victory` | confirmation | succès |
| `airhockey.bounce` | thock | moyenne, à chaque rebond |
| `airhockey.goal` | montée chiptune | **double impulsion** `.rigid` |
| `airhockey.relaunch` | tick | aucune |
| `airhockey.victory` | confirmation | succès |
| `tron.turn` | tick sec | légère |
| `tron.crash` | éclat de verre | erreur |
| `tron.victory` | confirmation | succès |

Les vues n'appellent que `Feedback.play(clé)`, qui déclenche le son **et** l'haptique.
Un événement absent de cette table n'a pas de retour sensoriel — c'est voulu.

**Licences.** Sources CC0 exclusivement (Kenney Audio, Sonniss GDC, Freesound filtré CC0). Chaque fichier est consigné dans `Docs/LICENSES.md` avec son origine et sa licence.

---

## 6. Onboarding et écran de déblocage

> Ajout de Session 1, hors PRD initial. Décision utilisateur du 10 septembre 2026,
> consignée dans `JOURNAL.md`. Modèle retenu : gratuit + déblocage unique.

### 6.1 Onboarding

Trois écrans maximum, passables à tout moment. Il ne raconte pas l'app : il **fait poser le téléphone**.

1. Poser l'appareil à plat sur la table, illustration en situation
2. S'asseoir face à face
3. C'est parti

Contrainte dure : le premier coup jouable en moins de 30 secondes (PRD §10.7). L'onboarding est donc chronométré en test, pas seulement relu.

### 6.2 Espace joueur

Local, sans compte, sans réseau (décision du 10 septembre 2026). Prénoms, avatars choisis dans un jeu fourni, historique des duels, statistiques de session. La mention **« Aucun compte. Aucun réseau. Rien ne quitte l'appareil. »** est affichée : c'est un argument de vente, pas une note de bas de page.

### 6.3 Écran de déblocage

Jamais avant la première partie terminée. Il apparaît sur un moment de joie — juste après une victoire — et propose l'air hockey à 2,99 €, achat unique non consommable. Identité parapluie, jamais la matière arcade : on vend depuis le hub, pas depuis le jeu.

Interdits sur cet écran : compte à rebours, faux prix barré, formulation culpabilisante, opposition « gratuit / premium » dévalorisante.
