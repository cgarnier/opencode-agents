---
description: Analyser un ticket et ses sous-tickets pour préparer l'implémentation
---

# Analyse du ticket $1 pour préparation d'implémentation

**Arguments :** $ARGUMENTS
**ID du ticket :** $1
**Contexte additionnel :** tout ce qui suit `$1` dans les arguments (peut être vide)

**Règle absolue : lecture seule.** Ne pas créer de branche, ne pas modifier de fichier.

---

## Étape 1 — Détecter le tracker

Examine l'ID `$1` :
- Correspond à `[A-Z]+-\d+` (ex : `PROJ-42`) → **Jira**
- Entier simple → détecter via le remote origin :
  ```bash
  git remote get-url origin
  ```
  - Contient `github.com` → **GitHub**
  - Contient `gitlab.com` ou domaine GitLab → **GitLab**

---

## Étape 2 — Récupérer le ticket parent

Les sorties CLI sont ingérées dans le contexte. Toujours passer par `--output json` / `--json`
puis projeter avec `jq` pour ne garder que les champs utiles au planning.

**GitLab :**
```bash
# Métadonnées du ticket (filtrées)
glab issue view $1 --output json \
  | jq '{title, description, state, labels,
         milestone: .milestone.title,
         assignees: [.assignees[].username]}'

# Commentaires (chargés en entier — volontaire pour garder le contexte de discussion)
glab issue view $1 --comments
```

**GitHub :**
```bash
gh issue view $1 --json title,body,state,labels,assignees,milestone,comments
```

**Jira :**
```bash
acli jira workitem view $1 --json \
  | jq '{summary,
         status: .fields.status.name,
         labels: .fields.labels,
         assignee: .fields.assignee.displayName,
         sprint: (.fields.sprint.name // null),
         description: .fields.description}'

acli jira workitem comment list --key $1
```

Extraire et noter :
- Titre exact
- Description complète et critères d'acceptance
- Labels, assigné, statut, milestone/sprint
- Commentaires pertinents

---

## Étape 3 — Récupérer les sous-tickets

**Principe :** à cette étape on construit seulement l'arbre (titre + état + labels).
Les **descriptions des sous-tickets ne sont PAS chargées** ici — elles seront lues
à la demande lors de l'implémentation de chaque sous-ticket, pas au planning.

**GitLab — via GraphQL :**
```bash
# Extraire le chemin projet depuis le remote (adapter selon SSH ou HTTPS)
# SSH  : git@gitlab.com:namespace/project.git   → namespace/project
# HTTPS: https://gitlab.com/namespace/project   → namespace/project
PROJECT_PATH=$(git remote get-url origin \
  | sed 's/.*github\.com[:/]//;s/.*gitlab\.com[:/]//;s/\.git$//')

# NOTE: `description` est volontairement omise — chargée à la demande plus tard.
glab api graphql -f query='
query($path: ID!, $iid: String!) {
  project(fullPath: $path) {
    issue(iid: $iid) {
      childIssues(first: 20) {
        nodes {
          iid
          title
          state
          labels(first: 5) { nodes { title } }
        }
      }
    }
  }
}' -f path="$PROJECT_PATH" -f iid="$1"
```

Si GraphQL ne retourne pas de `childIssues` (GitLab < 15.x ou feature désactivée),
utiliser le fallback REST avec le path URL-encodé (évite un `glab repo view` coûteux) :
```bash
PROJECT_PATH_ENC=$(printf '%s' "$PROJECT_PATH" | jq -sRr @uri)
glab api "projects/$PROJECT_PATH_ENC/issues/$1/links" \
  | jq '[.[] | {iid, title, state, labels}]'
```

**GitHub :**
```bash
gh api "repos/{owner}/{repo}/issues/$1/sub_issues" \
  --jq '[.[] | {number, title, state, labels: [.labels[].name]}]' 2>/dev/null \
  || gh issue view $1 --json body,comments
```

**Jira :**
```bash
acli jira workitem search --jql "parent = $1" --json \
  | jq '[.[] | {key,
                summary: .fields.summary,
                status: .fields.status.name,
                labels: .fields.labels}]'
```

---

## Étape 4 — Lire le contexte du projet

Lire `AGENTS.md` : stack, structure des dossiers, conventions de code.

Explorer les fichiers/modules susceptibles d'être impactés en fonction des titres et descriptions des tickets récupérés.

---

## Étape 5 — Produire le plan d'implémentation

Produire un document structuré avec le format suivant :

```
## Plan d'implémentation — Ticket #$1 : <titre>

### Contexte additionnel
<infos supplémentaires fournies, ou "aucun">

### Arbre des sous-tickets
| ID  | Titre | État | Taille estimée |
|-----|-------|------|----------------|
| #x  | ...   | open | M              |

### Analyse technique
**Modules / fichiers impactés :**
- <chemin> — <raison>

**Dépendances entre sous-tickets :**
- #x doit précéder #y car <raison>

**Risques identifiés :**
- <risque éventuel>

### Ordre d'implémentation recommandé
1. **#x — <titre>** (fondation, pas de dépendances)
   - Approche : ...
   - Taille : XS / S / M / L / XL
   - Fichiers concernés : ...

2. **#y — <titre>** (dépend de #x)
   - ...

### Prochaines étapes concrètes
- [ ] Créer la branche `feature/$1-<slug-du-titre>`
- [ ] Commencer par #x
```

**Convention de taille :**
XS < 1h · S ≈ demi-journée · M ≈ 1 jour · L ≈ 2-3 jours · XL > 3 jours

Si un sous-ticket est estimé XL, signaler qu'il devrait être découpé avant implémentation.
