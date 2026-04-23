---
alwaysApply: true
---

# Code Quality Gate — Règle absolue

## Principe fondamental

Après TOUT changement de code (fichiers créés, modifiés ou supprimés),
tous les checks qualité définis dans `AGENTS.md` doivent passer
avant de déclarer la tâche terminée.

## Procédure (OBLIGATOIRE pour tout agent qui modifie du code)

### Étape 1 — Lire les commandes qualité du projet
Lire la section `## Quality Checks` dans `AGENTS.md` à la racine du projet.
Elle liste les commandes à exécuter (tests, lint, format, typecheck, build).

#### Fallback — `AGENTS.md` absent

Si `AGENTS.md` n'existe pas à la racine du projet :
1. **STOP**. Ne pas deviner les commandes à exécuter.
2. Avertir l'utilisateur :
   > "AGENTS.md est absent à la racine du projet. Lance `bash ~/dev/agents/setup.sh`
   > pour initialiser le fichier, puis `/check-agents` pour qu'il soit rempli
   > automatiquement à partir du code. Je ne peux pas valider mes changements
   > sans cette configuration."
3. Ne **jamais** déclarer la tâche terminée. La laisser en état `blocked`.

#### Fallback — section `## Quality Checks` absente ou vide

Si `AGENTS.md` existe mais que `## Quality Checks` est absente, vide, ou ne contient
que des placeholders (`<command>`, commentaires HTML) :
1. Avertir **une seule fois** :
   > "`## Quality Checks` est manquante/vide dans AGENTS.md.
   > Je peux lancer `/check-agents` pour l'inférer automatiquement — veux-tu ?"
2. Si l'utilisateur accepte → attendre qu'il exécute la commande, puis reprendre.
3. Si l'utilisateur refuse → marquer la tâche comme **`completed without quality gate`**
   avec un warning explicite dans la synthèse :
   > "⚠ Tâche terminée sans quality gate — `## Quality Checks` n'était pas défini.
   > Les changements n'ont pas été validés par des checks automatiques."
4. Ne jamais inventer silencieusement des commandes (pas de `npm test` deviné).

### Étape 2 — Exécuter toutes les commandes

Exécuter chaque commande définie. Ordre recommandé :
1. `format` — formatter le code (peut modifier des fichiers)
2. `lint` — vérifier le style et les règles statiques
3. `typecheck` — vérifier les types
4. `test` — exécuter les tests
5. `build` — vérifier que le projet compile/bundle

### Étape 3 — En cas d'échec

Si une commande échoue :
1. Analyser l'erreur
2. Corriger le problème
3. Re-exécuter la commande concernée
4. Recommencer jusqu'à passage complet

Si l'échec n'est pas lié aux changements effectués (erreur préexistante) :
- Signaler à l'utilisateur : "Ce check échouait déjà avant mes changements : <erreur>"
- Proposer de corriger ou d'ignorer selon le contexte

### Étape 4 — Rapport final

Une fois tous les checks passés, confirmer :
> "Tous les checks qualité passent : format ✓ lint ✓ typecheck ✓ test ✓ build ✓"

Ne JAMAIS déclarer une tâche terminée si un check échoue sans l'avoir signalé explicitement.

## Agents concernés

| Agent | Gate qualité |
|---|---|
| `build` (built-in) | Oui — après chaque changement |
| `tester` | Oui — les tests générés doivent passer |
| `refactorer` | Oui — critique, rien ne doit régresser |
| `orchestrator` | Oui — gate final après tous les sous-agents |
| `reviewer` | Non — read-only |
| `debugger` | Non — read-only |
| `docs-writer` | Non — uniquement de la documentation |
| `performance` | Non — audit uniquement |
| `security` | Non — audit uniquement |
