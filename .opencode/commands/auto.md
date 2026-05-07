---
description: Mode autonome — infère la tâche depuis le contexte du repo (branche, ticket, diff, checks, MR) et exécute le pipeline complet sans interaction
---

# /auto — Exécution autonome par inférence

**Arguments :** $ARGUMENTS

**Règle absolue : zéro question.** Toutes les décisions ambiguës sont prises de façon
opinionée et documentées dans le rapport final. Ne jamais s'arrêter pour demander.

---

## Step 0 — Détecter le mode d'entrée

Analyser `$ARGUMENTS` :

| Pattern | Mode | Action |
|---|---|---|
| vide | **infer** | Inférer depuis le repo (Step 1B) |
| `/ticket <ID>` | **ticket** | Extraire l'ID, aller Step 1A |
| `[A-Z]+-\d+` seul (ex: `TILT-001`) | **ticket** | ID direct, aller Step 1A |
| entier seul (ex: `42`) | **ticket** | ID numérique, aller Step 1A |
| texte libre | **hint** | Hint d'intent, aller Step 1B avec le hint |

---

## Step 1A — Mode ticket : collecter le contexte du ticket

Suivre exactement les **Étapes 1 à 4** décrites dans `.opencode/commands/ticket.md`
en utilisant l'ID détecté au Step 0.

Puis continuer vers **Step 2 — Filtrage cross-projet** (ne pas produire le plan de ticket.md Step 5).

---

## Step 1B — Mode inférence : collecter le contexte du repo

Lancer toutes ces commandes **en parallèle** :

```bash
# Branche courante
git branch --show-current

# Statut et diff (travail en cours)
git status --short
git diff HEAD

# Historique récent
git log --oneline -10

# Vérifier si une MR/PR est ouverte sur cette branche
REMOTE=$(git remote get-url origin 2>/dev/null)
BRANCH=$(git branch --show-current)
```

Si le nom de branche contient un ticket ID (pattern `[A-Z]+-\d+` ou entier après `/`) :

```bash
# Extraire l'ID depuis le nom de branche
# Ex: feature/TILT-001-auth → TILT-001
# Ex: feature/42-fix-login  → 42
```

→ Si ID détecté : exécuter aussi **Step 1A** avec cet ID.

Vérifier aussi les MR/PR ouvertes :

```bash
# GitLab
glab mr list --source-branch "$BRANCH" --output json 2>/dev/null \
  | jq '[.[] | {iid, title, state, has_conflicts, web_url}]'

# GitHub
gh pr list --head "$BRANCH" --json number,title,state,url 2>/dev/null
```

Si une MR/PR ouverte existe et que `glab` ou `gh` est disponible, lire les threads non résolus via `@mr-reviewer`. Si la CLI n'est pas disponible, ignorer cette étape silencieusement.

Lancer le quality gate depuis `AGENTS.md` pour détecter les échecs préexistants.

---

## Step 2 — Filtrage cross-projet (mode ticket uniquement)

Après récupération des sous-tickets, identifier ceux qui appartiennent au repo courant.

**Détecter le type du repo courant :**

```bash
# Stack indicators
ls package.json go.mod pom.xml Cargo.toml requirements.txt composer.json 2>/dev/null || true
grep -A5 "## Stack" AGENTS.md 2>/dev/null
```

**Signaux dans le titre/labels d'un sous-ticket indiquant qu'il appartient à un autre projet :**
- Labels : `front`, `frontend`, `web`, `ui`, `back`, `backend`, `api`, `mobile`, `ios`, `android`
- Mots-clés dans le titre : noms de repos, stacks spécifiques opposées (ex: "React component" dans un repo Go)
- Préfixes explicites dans le titre : `[FRONT]`, `[API]`, `[APP]`

**Partitionner :**
- ✓ **À implémenter** : appartient à ce repo
- ⊘ **À ignorer** : autre projet (noter la raison)

Si **aucun sous-ticket ne correspond** à ce repo → reporter clairement et s'arrêter proprement.

---

## Step 3 — Synthèse de la tâche

Consolider toutes les informations collectées en une **décision de tâche unique** :

```
TÂCHE INFÉRÉE :
  Source        : <ticket TILT-001 / branche / diff / checks en échec / MR threads>
  Objectif      : <description en une phrase>
  Sous-tâches   : <liste ordonnée des sous-tickets à implémenter, ou tâches inférées>
  Ignorés       : <sous-tickets d'autres projets, avec raison>
  Décisions     : <toute décision ambiguë prise de façon opinionée>
```

Logger ce bloc dans la session (visible dans l'output), puis continuer sans attendre.

---

## Step 4 — Branch strategy (opinionée, sans demander)

Règles appliquées dans l'ordre :

| Situation | Décision |
|---|---|
| Déjà sur une branche feature/ ou fix/ non-main | Rester sur la branche courante |
| Sur `main` + ticket ID connu | Créer `feature/<ID>-<slug-du-titre>` |
| Sur `main` + hint libre | Créer `feature/<slug-du-hint>` |
| Sur `main` + inférence pure | Créer `fix/auto-<date-YYYYMMDD>` |
| Branche existante avec même ticket | Checkout cette branche |

Ne jamais travailler directement sur `main`.

---

## Step 5 — Implémentation

Pour chaque sous-ticket à implémenter (ou tâche inférée), dans l'ordre défini au Step 3 :

1. Lire la **description complète** du sous-ticket si pas encore chargée :
   - GitLab : `glab issue view <iid> --output json | jq '{title, description}'`
   - GitHub  : `gh issue view <number> --json title,body`
   - Jira    : `acli jira workitem view <key> --json | jq '{summary, description: .fields.description}'`

2. Implémenter les changements de code nécessaires.

3. Après chaque sous-ticket : noter ce qui a été fait, continuer au suivant.

Déléguer aux spécialistes selon la nature du travail :
- Bug à investiguer d'abord → `@debugger` puis fix
- Tests manquants → `@tester`
- Refactoring → `@refactorer`
- Documentation → `@docs-writer`

---

## Step 6 — Quality gate

Lire `## Quality Checks` dans `AGENTS.md` et exécuter toutes les commandes dans l'ordre :
`format → lint → typecheck → test → build`

Si un check échoue : corriger, re-exécuter. Ne pas passer à l'étape suivante tant que tout n'est pas vert.

---

## Step 7 — Code review

Collecter le diff complet :

```bash
git diff main...HEAD --stat
git diff main...HEAD
```

Choisir le mode :
- Diff < 100 lignes ET < 5 fichiers → `Mode: quick`
- Sinon → `Mode: full`

Passer le diff à `@reviewer` avec le contexte de la tâche.

Si des issues **Critical** sont remontées → corriger et relancer la review.

---

## Step 8 — Publication

Déléguer à `@git-publisher` pour :
- Commit conventionnel (feat/fix/refactor selon la nature des changements)
- Push sur la branche courante
- Création de la MR/PR avec :
  - Titre : `<type>(<ticket-ID>): <titre du ticket ou tâche inférée>`
  - Corps : liste des sous-tickets traités, décisions prises, quality gate status

---

## Step 9 — Rapport final

Produire un résumé structuré :

```
## Rapport /auto — <date>

### Tâche exécutée
<objectif inféré ou fourni>

### Source d'inférence
<ticket / branche / diff / checks / hint>

### Branche
<nom de la branche utilisée ou créée>

### Sous-tickets traités
| ID | Titre | Statut |
|----|-------|--------|
| #x | ...   | ✓ implémenté |
| #y | ...   | ⊘ ignoré (autre projet : frontend) |

### Décisions opinionées
- <décision 1 et raison>
- <décision 2 et raison>

### Code review
<Critical fixés / Warnings / Infos>

### Quality gate
format ✓ · lint ✓ · typecheck ✓ · test ✓ · build ✓

### MR/PR
<URL>
```

---

## Cas d'arrêt propre

S'arrêter avec un message clair (sans erreur fatale) si :

- `$ARGUMENTS` contient un ticket ID mais le ticket est introuvable (mauvais tracker, accès refusé)
- Aucun sous-ticket ne correspond au repo courant ET aucun diff/check en échec détecté
- La branche courante est `main` ET impossible de déterminer un nom de branche (pas d'ID, pas de hint, pas de diff)

Dans ces cas, afficher :

```
⚠ /auto — contexte insuffisant pour démarrer
Raison : <raison précise>
Suggestion : opencode run "/auto <hint>" ou opencode run "/auto <TICKET-ID>"
```
