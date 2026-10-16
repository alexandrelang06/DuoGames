# LICENSES.md

Inventaire fichier par fichier des ressources tierces embarquées (PRD §8.6).
Aucune ressource n'entre dans le dépôt sans sa ligne ici.

## Polices

| Fichier | Origine | Licence | Texte de licence |
|---|---|---|---|
| `Resources/Fonts/ZillaSlab-Regular.ttf` | Google Fonts — The Mozilla Foundation | SIL OFL 1.1 | `Fonts/OFL-ZillaSlab.txt` |
| `Resources/Fonts/ZillaSlab-SemiBold.ttf` | Google Fonts — The Mozilla Foundation | SIL OFL 1.1 | `Fonts/OFL-ZillaSlab.txt` |
| `Resources/Fonts/ZillaSlab-Bold.ttf` | Google Fonts — The Mozilla Foundation | SIL OFL 1.1 | `Fonts/OFL-ZillaSlab.txt` |
| `Resources/Fonts/Orbitron.ttf` | Google Fonts — The Orbitron Project Authors | SIL OFL 1.1 | `Fonts/OFL-Orbitron.txt` |

La SIL OFL autorise l'embarquement dans une application commerciale et interdit la vente des
fontes seules. Les textes de licence sont conservés.

## Sons

Tous issus des packs **Kenney** (kenney.nl), licence **CC0 1.0** — domaine public, aucune
attribution requise, redistribution et modification libres. Texte : `Sounds/LICENSE-Kenney.txt`.
Conversion Ogg Vorbis → CAF PCM mono 44,1 kHz par ffmpeg, sans autre traitement.

| Fichier embarqué | Clé d'événement | Source Kenney | Pack |
|---|---|---|---|
| `game_select.caf` | `game.select` | `select_001.ogg` | Interface Sounds |
| `game_move.caf` | `game.move` | `impactWood_light_000.ogg` | Impact Sounds |
| `game_place.caf` | `game.place` | `impactWood_medium_000.ogg` | Impact Sounds |
| `game_capture.caf` | `game.capture` | `impactWood_heavy_000.ogg` | Impact Sounds |
| `game_rejected.caf` | `game.rejected` | `error_004.ogg` | Interface Sounds |
| `game_victory.caf` | `game.victory` | `confirmation_002.ogg` | Interface Sounds |
| `airhockey_bounce.caf` | `airhockey.bounce` | `impactGeneric_light_000.ogg` | Impact Sounds |
| `airhockey_goal.caf` | `airhockey.goal` | `maximize_006.ogg` | Interface Sounds |
| `airhockey_relaunch.caf` | `airhockey.relaunch` | `tick_001.ogg` | Interface Sounds |
| `airhockey_victory.caf` | `airhockey.victory` | `confirmation_003.ogg` | Interface Sounds |
| `tron_turn.caf` | `tron.turn` | `tick_002.ogg` | Interface Sounds |
| `tron_crash.caf` | `tron.crash` | `impactGlass_heavy_000.ogg` | Impact Sounds |
| `tron_victory.caf` | `tron.victory` | `confirmation_003.ogg` | Interface Sounds |

Packs téléchargés le 11 septembre 2026 : Interface Sounds, Impact Sounds, UI Audio.
Le pack UI Audio n'a finalement fourni aucun fichier retenu.

## Code

Aucune dépendance tierce (PRD §6.1). `Packages/GameEngines` est du code du projet.
