---
alwaysApply: true
---

# Git Branch Safety

Ne JAMAIS commiter, pusher, ni modifier du code directement sur `main`.
Règle non-négociable, applicable à tous les agents.

## Décision de branche (avant tout changement de code)

1. Détecter la branche courante : `git branch --show-current`
2. Appliquer dans l'ordre, première ligne qui matche :

| Situation | Action |
|---|---|
| Branche courante = `main` ou `master` | STOP. Avertir l'utilisateur, proposer une branche `feature/` ou `fix/`, demander confirmation avant de créer. |
| Utilisateur a explicitement demandé une nouvelle branche ("crée une branche X", "nouvelle feature isolée", "fork depuis main"…) | Demander la base si ambiguë (courante ou `main` ?), puis `git checkout -b <nom>`. |
| Branche courante ≠ `main` / `master` (cas par défaut) | **Rester sur la branche courante.** C'est la branche de travail. |
| Doute réel sur l'intention | Demander avant toute action. Ne jamais créer de branche silencieusement. |

**Principe directeur** : si tu es déjà sur une branche autre que `main`/`master`, c'est *la* branche de travail. Ne JAMAIS proposer de forker de soi-même sans demande explicite de l'utilisateur.

## Nommage et commits

- Conventions de nommage de branches : voir `AGENTS.md > ## Branch Naming` (kebab-case, préfixes `feature/`, `fix/`, `refactor/`, `docs/`, `test/`, `perf/`).
- Messages en conventional commits : `feat:`, `fix:`, `refactor:`, `test:`, `docs:`, `chore:`.
- Jamais de `git push --force` sur une branche partagée sans confirmation explicite.
- Jamais de `git merge main` dans une feature branch sans demander (préférer rebase).
