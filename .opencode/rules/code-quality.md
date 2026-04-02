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

Si la section est absente ou incomplète, signaler à l'utilisateur :
> "La section `## Quality Checks` est manquante dans AGENTS.md.
> Ajoute les commandes pour que je puisse valider mes changements."

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
