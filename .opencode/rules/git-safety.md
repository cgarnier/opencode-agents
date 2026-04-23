---
alwaysApply: true
---

# Git Branch Safety

Ne JAMAIS commiter, pusher, ni modifier du code directement sur `main`.
Règle non-négociable, applicable à tous les agents.

## Décision de branche (avant tout changement de code)

1. Détecter la branche : `git branch --show-current`
2. Appliquer la table ci-dessous.

| Situation | Action |
|---|---|
| Sur `main` | STOP. Avertir l'utilisateur, proposer une branche `feature/` ou `fix/`, ne rien modifier. |
| Fix/amélioration liée au travail en cours | Rester sur la branche actuelle. |
| Nouvelle tâche dépendante de la branche actuelle | Fork depuis la branche actuelle : `git checkout -b <nom>` |
| Nouvelle tâche indépendante | `git fetch origin && git checkout main && git pull && git checkout -b <nom>` |
| Intention ambiguë | **Demander** à l'utilisateur avant de créer la branche. Ne jamais deviner. |

## Nommage et commits

- Conventions de nommage de branches : voir `AGENTS.md > ## Branch Naming` (kebab-case, préfixes `feature/`, `fix/`, `refactor/`, `docs/`, `test/`, `perf/`).
- Messages en conventional commits : `feat:`, `fix:`, `refactor:`, `test:`, `docs:`, `chore:`.
- Jamais de `git push --force` sur une branche partagée sans confirmation explicite.
- Jamais de `git merge main` dans une feature branch sans demander (préférer rebase).
