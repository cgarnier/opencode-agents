---
alwaysApply: true
---

# Git Branch Safety — Règle absolue

## Principe fondamental

Ne JAMAIS commiter, pusher, ni effectuer de changements de code directement sur `main`.
Cette règle est non-négociable et s'applique à TOUS les agents.

## Décision de branche (OBLIGATOIRE avant tout changement de code)

### Étape 1 — Détecter la branche actuelle
```bash
git branch --show-current
```

### Étape 2 — Appliquer l'arbre de décision

```
Branche actuelle = main ?
  OUI → STOP.
        Avertir l'utilisateur : "Je ne travaille pas directement sur main."
        Proposer : créer une branche feature/ ou fix/ avant de continuer.
        Ne rien modifier tant qu'on est sur main.

Branche actuelle ≠ main
  │
  ├─ La tâche est un fix ou une amélioration liée au travail en cours ?
  │   → Rester sur la branche actuelle. Pas de nouvelle branche.
  │
  ├─ Nouvelle feature/tâche qui dépend du contenu de la branche actuelle ?
  │   → Fork depuis la branche actuelle :
  │       git checkout -b <nom-branche>
  │
  └─ Nouvelle feature/tâche indépendante ?
      → Mettre à jour main puis fork :
          git fetch origin
          git checkout main
          git pull
          git checkout -b <nom-branche>
```

### Étape 3 — En cas de doute

Si l'intention n'est pas claire (la tâche pourrait être liée OU indépendante),
**demander à l'utilisateur** avant de créer une branche :

> "Cette tâche est-elle liée à `<branche-actuelle>` ou indépendante ?
> Je propose la branche `<nom-suggéré>` — ça te convient ?"

Ne jamais deviner silencieusement quand il y a une ambiguïté.

## Nommage des branches

| Type de tâche | Préfixe | Exemple |
|---|---|---|
| Nouvelle fonctionnalité | `feature/` | `feature/user-notifications` |
| Correction de bug | `fix/` | `fix/auth-token-expiry` |
| Refactoring | `refactor/` | `refactor/payment-module` |
| Documentation | `docs/` | `docs/api-endpoints` |
| Tests | `test/` | `test/user-service-coverage` |
| Performance | `perf/` | `perf/query-optimization` |

Noms en kebab-case, courts et descriptifs. Proposer le nom, confirmer si doute.

## Commits

- Messages en conventional commits : `feat:`, `fix:`, `refactor:`, `test:`, `docs:`, `chore:`
- Ne jamais `git push --force` sur une branche partagée sans confirmation explicite
- Ne jamais `git merge main` dans une feature branch sans demander (préférer rebase)
