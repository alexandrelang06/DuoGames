# MONITORING.md — Suivi des bugs et alertes

> Ajout de Session 1, hors PRD initial. Demande utilisateur du 10 septembre 2026.

## Principe directeur

L'app affiche à ses joueurs : **« Aucun compte. Aucun réseau. Rien ne quitte l'appareil. »**
Tout dispositif de monitoring doit donc être vrai avec cette phrase. Un SDK tiers la rendrait
mensongère.

**Aucun SDK tiers n'est utilisé.** Ni Sentry, ni Crashlytics, ni Bugsnag. Trois raisons cumulées :
le PRD §6.1 interdit les dépendances tierces ; ces SDK transmettent des données hors de l'appareil,
ce qui contredit la promesse affichée et alourdit l'étiquette de confidentialité App Store ; et
Apple fournit l'équivalent en première partie, gratuitement.

---

## Les trois couches

### 1. MetricKit — crashs, blocages, performance

Framework système. L'OS collecte et livre à l'app, **au plus une fois par jour**, des rapports de
crash, de blocage (hang), de lancement lent, ainsi que des métriques d'énergie et de disque.
Aucun code d'envoi, aucun compte, aucun réseau.

Implémenté dans `Packages/GameEngines/Sources/Diagnostics/DiagnosticsCenter.swift`.
Appeler `DiagnosticsCenter.shared.start()` une fois au démarrage.

Surveillance dédiée du **temps au premier rendu**, parce que le PRD §10.7 impose moins de
30 secondes entre le lancement et le premier coup joué. C'est un critère d'acceptation, donc il
se mesure en production, pas seulement en test.

### 2. `os.Logger` — journalisation unifiée

Journalisation système, catégorisée, lisible dans Console.app et incluse dans les sysdiagnose.
Sous-système `com.duogames.app`. Coût quasi nul quand personne n'écoute.

**Règle de confidentialité :** aucun message ne contient de donnée personnelle. Les prénoms des
joueurs, saisis dans l'espace joueur local, ne sont **jamais** journalisés. Les messages sont
marqués `privacy: .public` précisément parce qu'ils sont conçus pour ne rien contenir de sensible.

### 3. `DiagnosticLog` — tampon local consultable

Tampon circulaire borné (50 entrées par défaut), en mémoire, pour les incidents applicatifs :
échec de restauration d'achat, posture incohérente, état de jeu inattendu. Consultable depuis un
écran de diagnostic caché (à construire en Session 5). Rien n'est persisté ni transmis.

Couvert par 8 tests unitaires : bornage du tampon, éviction des plus anciens, filtrage par
sévérité, tri par priorité, détection d'incident bloquant.

---

## Comment les rapports te remontent

**Xcode → Window → Organizer → Crashes.** Apple agrège les rapports des utilisateurs ayant accepté
de partager leurs analyses avec les développeurs, les symbolise et les regroupe par signature.
Zéro ligne de code, zéro coût, zéro collecte supplémentaire.

Complété par **App Store Connect** : avis et notes, statistiques de téléchargement et de conversion.

## Alertes actives

Xcode Organizer ne notifie pas. Pour être alerté d'un pic de crashs sans rien ajouter dans l'app,
la voie propre est l'**API App Store Connect**, interrogée depuis ta machine ou un CI :
elle expose les métriques de crash et les avis. Le script vit **hors de l'app**, ne touche pas au
binaire, et ne change rien à l'étiquette de confidentialité.

À construire après le lancement. Inutile avant d'avoir des utilisateurs.

## Étiquette de confidentialité App Store

Côté diagnostic — MetricKit, `os.Logger`, tampon local, aucun SDK, aucun réseau — rien n'est
collecté par l'app : les diagnostics MetricKit relèvent du partage de l'utilisateur avec Apple.

**Mais l'ajout de Game Center change la donne** (décision du 10 septembre 2026). Les classements
transmettent un score et un identifiant de joueur à Apple. La déclaration ne peut donc plus être
« Aucune donnée collectée » : il faudra déclarer les identifiants et données de jeu liés au compte,
conformément à la documentation Game Center.

C'est pourquoi la mention « Rien ne quitte l'appareil » a été retirée de l'espace joueur. Une app
qui promet cela puis publie un classement en ligne ment à ses utilisateurs, et la contradiction
serait visible dans la fiche App Store.
