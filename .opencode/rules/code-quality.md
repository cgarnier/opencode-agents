---
alwaysApply: true
---

# Code Quality Gate

Après TOUT changement de code, les checks définis dans `AGENTS.md > ## Quality Checks`
doivent passer avant de déclarer la tâche terminée.

## Procédure

1. Lire `## Quality Checks` dans `AGENTS.md` à la racine du projet.
2. Exécuter les commandes dans l'ordre : `format` → `lint` → `typecheck` → `test` → `build`.
3. En cas d'échec : corriger, re-exécuter. Si l'échec est préexistant, le signaler explicitement.
4. Rapport final : `"Tous les checks passent : format ✓ lint ✓ typecheck ✓ test ✓ build ✓"`.

Ne JAMAIS déclarer la tâche terminée si un check échoue sans l'avoir signalé.

## Fallback — AGENTS.md ou Quality Checks manquants

Si `AGENTS.md` est absent, ou si `## Quality Checks` est manquante/vide/placeholders :
avertir l'utilisateur de lancer `bash ~/dev/agents/setup.sh` puis `/check-agents`,
et ne pas deviner silencieusement des commandes. Si l'utilisateur refuse de configurer,
marquer la tâche `completed without quality gate` avec un warning explicite.
