# OpenCode — Système multi-agents dev

Système d'agents spécialisés pour OpenCode, conçu pour le développement fullstack (front, back, devops).
Chaque agent a un rôle précis, des permissions adaptées, et des règles globales garantissent que `main` n'est jamais touché et que tous les checks qualité passent avant de déclarer une tâche terminée.

---

## Table des matières

1. [Vue d'ensemble](#1-vue-densemble)
2. [Prérequis](#2-prérequis)
3. [Installation](#3-installation)
4. [Structure des fichiers](#4-structure-des-fichiers)
5. [Agents](#5-agents)
   - [Orchestrateur](#51-orchestrateur--primary)
   - [Build](#52-build--primary-built-in)
   - [Plan](#53-plan--primary-built-in)
   - [Reviewer](#54-reviewer--subagent)
   - [Debugger](#55-debugger--subagent)
   - [Tester](#56-tester--subagent)
   - [Refactorer](#57-refactorer--subagent)
   - [Docs-writer](#58-docs-writer--subagent)
   - [Performance](#59-performance--subagent)
   - [Security](#510-security--subagent)
6. [Règles globales](#6-règles-globales)
   - [git-safety](#61-git-safety)
   - [code-quality](#62-code-quality)
7. [Commandes personnalisées](#7-commandes-personnalisées)
   - [/ticket](#71-ticket)
8. [Configuration par projet](#8-configuration-par-projet)
9. [Exemples de flux complets](#9-exemples-de-flux-complets)
10. [Personnalisation](#10-personnalisation)
11. [Travail en parallèle — Worktrees](#11-travail-en-parallèle--worktrees)
12. [Référence rapide](#12-référence-rapide)

---

## 1. Vue d'ensemble

### Problème résolu

Le mode `build` par défaut d'OpenCode est un agent généraliste : il fait tout, mais sans guardrails. Il peut travailler sur `main`, oublier de lancer les tests, et mélanger investigation et implémentation dans le même contexte.

Ce système apporte :

- **Protection de `main`** — aucun agent ne touche `main` directement. La branche de travail est toujours décidée en amont, avec confirmation si le contexte est ambigu.
- **Spécialisation** — chaque type de tâche (review, debug, tests, refactoring, docs, perf, sécu) a un agent dédié avec un process et des permissions adaptés.
- **Quality gate automatique** — après tout changement de code, les checks définis dans `AGENTS.md` (lint, typecheck, tests, build) doivent passer. Un agent ne déclare jamais une tâche terminée si un check échoue.
- **Délégation parallèle** — l'orchestrateur peut lancer plusieurs agents spécialisés en parallèle et synthétiser les résultats.

### Philosophie

```
Un agent = un rôle = des permissions adaptées à ce rôle
```

Un agent de review n'a pas besoin d'écrire des fichiers. Un agent de debug n'a pas besoin de modifier du code. Ces restrictions ne sont pas des limitations artificielles : elles garantissent que chaque agent fait exactement ce pour quoi il est conçu, sans risque d'effets de bord.

---

## 2. Prérequis

- [OpenCode](https://opencode.ai) installé (`curl -fsSL https://opencode.ai/install | bash`)
- Un provider Claude configuré dans OpenCode (`/connect` dans le TUI)
- Le répertoire template situé à `~/dev/agents/` (ce repo)
- `git` disponible dans le PATH

---

## 3. Installation

### Setup unique (une seule fois)

Lance le script d'installation des helpers shell :

```bash
bash ~/dev/agents/install-shell-helpers.sh
```

Ce script met à jour `.bashrc` et `.zshrc` automatiquement :
- Ajoute `agents-setup` (alias vers `setup.sh`)
- Remplace les anciens alias `wt-new` / `wt-done` par un `source` vers `shell-functions.sh`
- Conserve l'alias `wt-list`

> **Pourquoi `source` et pas des alias ?**
> `wt-new` et `wt-done` doivent changer le répertoire courant du terminal (`cd`). Un alias ou un script s'exécute dans un sous-shell — le `cd` n'affecte pas le shell parent. Seule une fonction shell sourcée dans le shell courant le permet.

Recharge le shell :

```bash
source ~/.zshrc   # ou source ~/.bashrc
```

### Par projet (dans chaque nouveau repo)

```bash
cd mon-projet/
agents-setup
```

Sortie attendue :

```
OpenCode multi-agent setup → /chemin/vers/mon-projet
──────────────────────────────────────────
  ✓ .opencode/agents/ → /home/<user>/dev/agents/.opencode/agents
  ✓ .opencode/rules/  → /home/<user>/dev/agents/.opencode/rules
  ✓ opencode.json copied (customize for this project)
  ✓ AGENTS.md created from template

  → Fill in AGENTS.md with your project's quality check commands.

Done. Run 'opencode' to start.
```

### Ce que fait `setup.sh` en détail

| Étape | Action | Comportement si déjà présent |
|---|---|---|
| 1 | Crée `.opencode/` | Ignoré si existe |
| 2 | Symlink `.opencode/agents/` → template | Skip + avertissement si dossier réel existant |
| 3 | Symlink `.opencode/rules/` → template | Skip + avertissement si dossier réel existant |
| 4 | Symlink `.opencode/commands/` → template | Skip + avertissement si dossier réel existant |
| 5 | Copie `opencode.json` | Skip si déjà présent |
| 6 | Copie `AGENTS.md.template` → `AGENTS.md` | Skip si déjà présent |

**Idempotent** : relancer `agents-setup` dans un projet déjà configuré est sans danger.

### Stratégie symlink vs copie

| Fichier | Stratégie | Raison |
|---|---|---|
| `.opencode/agents/` | **Symlink** | Mettre à jour le template = mettre à jour tous les projets automatiquement |
| `.opencode/rules/` | **Symlink** | Idem — les règles git et qualité sont globales |
| `.opencode/commands/` | **Symlink** | Idem — les commandes personnalisées sont partagées entre tous les projets |
| `opencode.json` | **Copie** | Chaque projet peut avoir des permissions et modèles différents |
| `AGENTS.md` | **Copie** | Contenu entièrement spécifique au projet |

> Pour customiser un agent sur un projet spécifique, supprimer le symlink `.opencode/agents/` et le remplacer par un vrai dossier contenant tes overrides. Voir [Personnalisation](#9-personnalisation).

---

## 4. Structure des fichiers

```
~/dev/agents/
│
├── README.md                        ← cette documentation
├── setup.sh                         ← script d'installation (agents-setup)
├── opencode.json                    ← template de config (copié dans chaque projet)
├── AGENTS.md.template               ← starter AGENTS.md (copié dans chaque projet)
│
└── .opencode/
    ├── rules/                       ← symlinkée dans chaque projet
    │   ├── git-safety.md            ← règle branchement (alwaysApply: true)
    │   └── code-quality.md          ← règle quality gate (alwaysApply: true)
    │
    ├── agents/                      ← symlinkée dans chaque projet
    │   ├── orchestrator.md          ← agent PRIMARY
    │   ├── reviewer.md              ← subagent
    │   ├── debugger.md              ← subagent
    │   ├── tester.md                ← subagent
    │   ├── refactorer.md            ← subagent
    │   ├── docs-writer.md           ← subagent
    │   ├── performance.md           ← subagent
    │   ├── security.md              ← subagent
    │   └── git-publisher.md         ← subagent
    │
    └── commands/                    ← symlinkée dans chaque projet
        └── ticket.md                ← /ticket <id> [contexte]
```

Après `agents-setup` dans un projet, la structure locale est :

```
mon-projet/
├── opencode.json                    ← copié, customisable
├── AGENTS.md                        ← copié, à remplir
└── .opencode/
    ├── agents/    →  ~/dev/agents/.opencode/agents/    (symlink)
    ├── rules/     →  ~/dev/agents/.opencode/rules/     (symlink)
    └── commands/  →  ~/dev/agents/.opencode/commands/  (symlink)
```

---

## 5. Agents

OpenCode propose deux types d'agents :
- **Primary** : agents interactifs, accessibles via la touche **Tab** dans le TUI
- **Subagent** : agents spécialisés, invocables via `@nom` dans un message ou automatiquement via le Task tool

### 5.1 Orchestrateur — primary

| Propriété | Valeur |
|---|---|
| Mode | `primary` |
| Couleur | Violet `#7c3aed` |
| Accès fichiers | Read/write complet |
| Bash | Git read `allow` · git write `ask` · reste `ask` |
| Task tool | Tous les subagents `allow` |

**Rôle** : point d'entrée pour les tâches complexes. Analyse la demande, gère la stratégie de branchement, délègue aux bons spécialistes, et valide le tout avec le quality gate final.

**Quand l'utiliser** : dès qu'une tâche dépasse une simple implémentation — revue + sécu, debug + fix, refactoring + tests, etc.

**Workflow interne** :

```
1. Branch Decision
   └─ git branch --show-current
   └─ Appliquer git-safety (voir §6.1)
   └─ Demander si doute sur la branche cible

2. Task Analysis
   └─ Lire AGENTS.md (stack, conventions, quality checks)
   └─ Identifier le(s) type(s) de tâche
   └─ Sélectionner les spécialistes

3. Délégation
   └─ Tâches indépendantes → lancement en parallèle
   └─ Tâches dépendantes  → lancement séquentiel

4. Quality Gate final
   └─ Lire ## Quality Checks dans AGENTS.md
   └─ Exécuter : format → lint → typecheck → test → build
   └─ Corriger si échec, retry jusqu'à passage complet

5. Synthèse
   └─ Branche utilisée / créée
   └─ Résultats des spécialistes
   └─ Statut quality gate
```

---

### 5.2 Build — primary (built-in)

| Propriété | Valeur |
|---|---|
| Mode | `primary` (agent built-in OpenCode, customisé) |
| Accès fichiers | Read/write complet |
| Bash | Git read `allow` · reste `ask` |

**Rôle** : implémentation directe. Agent par défaut pour écrire du code, créer des fichiers, corriger des bugs simples.

**Différence avec l'orchestrateur** : le `build` travaille directement sans déléguer. À utiliser pour les tâches simples et ciblées. Pour les tâches composites, préférer l'orchestrateur.

**Customisation dans `opencode.json`** :
- Git read (status, diff, log, branch, fetch) : `allow` automatique
- Tout le reste bash : `ask` — l'agent demande confirmation avant d'exécuter

---

### 5.3 Plan — primary (built-in)

| Propriété | Valeur |
|---|---|
| Mode | `primary` (agent built-in OpenCode, customisé) |
| Accès fichiers | **Aucun** — `edit: deny` |
| Bash | **Aucun** — `deny` complet |

**Rôle** : réflexion et planification sans modifier quoi que ce soit. Idéal pour explorer une architecture, concevoir une feature, ou comprendre une base de code avant d'agir.

**Utilisation** : appuyer sur **Tab** dans le TUI pour basculer entre Build, Plan et Orchestrateur.

---

### 5.4 Reviewer — subagent

| Propriété | Valeur |
|---|---|
| Mode | `subagent` |
| Couleur | Bleu `#0891b2` |
| Accès fichiers | **Aucun** — `edit: deny` |
| Bash | `git diff/log/show`, `grep`, `ls` uniquement |

**Rôle** : revue de code structurée. Analyse le code sur 8 dimensions et retourne un rapport hiérarchisé.

**Dimensions analysées** :
- Correctness (logique, edge cases, null handling)
- Quality (nommage, taille des fonctions, responsabilité unique)
- Duplication (logique répétée à extraire)
- Complexity (code imbriqué, cyclomatic complexity)
- Patterns (anti-patterns, incohérences avec le reste du projet)
- Error handling (try/catch manquants, promise rejections silencieuses)
- Types (usage de `any`, types manquants — projets TS)
- Tests (chemins critiques non testés)

**Format de sortie** :

```
## Code Review — <scope>

### Critical
- [fichier:ligne] Description + Suggestion

### Warning
- [fichier:ligne] Description + Suggestion

### Info
- [fichier:ligne] Note mineure + Suggestion

### Positive
- Ce qui est bien fait (1-3 items max)

### Summary
Évaluation globale en 2-3 phrases.
```

**Invocation** : `@reviewer revue le module auth` ou automatiquement par l'orchestrateur.

---

### 5.5 Debugger — subagent

| Propriété | Valeur |
|---|---|
| Mode | `subagent` |
| Couleur | Rouge `#dc2626` |
| Accès fichiers | **Aucun** — `edit: deny` |
| Bash | `git log/diff/show/blame`, `grep`, `ls`, `cat` uniquement |

**Rôle** : investigation de bugs par hypothèses et preuves. Ne corrige jamais — identifie et localise.

**Process en 4 phases** :

```
Phase 1 — Comprendre le symptôme
  → Comportement observé vs attendu, conditions de reproduction

Phase 2 — Formuler des hypothèses
  → 2-4 causes racines plausibles, classées par vraisemblance

Phase 3 — Investiguer
  → Tracer le flux de données, git log, grep, éliminer les hypothèses

Phase 4 — Rapport
  → Root cause confirmée + localisation précise + direction de fix
```

**Format de sortie** :

```
## Debug Report — <description>

### Symptom
### Root Cause
Location: fichier:ligne
### Evidence
### Eliminated hypotheses
### Fix direction
Estimated complexity: XS / S / M / L
```

**Important** : le debugger ne code pas le fix. Il passe le relais à `build` ou à l'orchestrateur.

---

### 5.6 Tester — subagent

| Propriété | Valeur |
|---|---|
| Mode | `subagent` |
| Couleur | Vert `#16a34a` |
| Accès fichiers | **Complet** — `edit: allow` |
| Bash | `git diff/branch`, `grep`, `ls` · reste `ask` |

**Rôle** : analyse la couverture existante et génère les tests manquants. Respecte les conventions de test du projet. Lance les tests à la fin — ils doivent passer.

**Priorités** :
1. Chemins critiques (happy path)
2. Cas d'erreur (input invalide, données manquantes)
3. Edge cases (valeurs limites, null/undefined, appels concurrents)
4. Points d'intégration (interactions entre modules)

**Quality gate** : exécute la commande `test` de `AGENTS.md` après avoir écrit les tests. Tous doivent passer avant de rendre la main.

**Format de sortie** :

```
## Tests written — <scope>

### Coverage added
- <fichier> — N tests (liste des scénarios)

### Edge cases covered
### Not covered (out of scope / needs more context)

### Quality gate
test: ✓ (N passing)
```

---

### 5.7 Refactorer — subagent

| Propriété | Valeur |
|---|---|
| Mode | `subagent` |
| Couleur | Orange `#ea580c` |
| Accès fichiers | **Complet** — `edit: allow` |
| Bash | `git diff/branch`, `grep`, `ls` · reste `ask` |

**Rôle** : améliore la structure interne du code sans changer son comportement observable. Propose un plan avant d'agir.

**Règle absolue** : si les tests échouent après un refactoring, c'est une régression — le refactoring a changé le comportement. Stopper et corriger.

**Process** :

```
1. Lire le code en entier
2. Proposer un plan (problèmes identifiés, changements proposés, risques)
3. Attendre approbation (implicite si invoqué par orchestrateur avec tâche claire)
4. Refactorer de façon incrémentale
5. Quality gate complet : format → lint → typecheck → test → build
```

**Opérations autorisées** :
- Extraction de fonctions/constantes/types
- Renommage pour plus d'expressivité
- Simplification (aplatir les conditions imbriquées)
- Consolidation (supprimer le code mort, merger la logique dupliquée)
- Séparation (découper les fichiers/modules trop larges)

**Opérations interdites** :
- Changer la logique métier
- Introduire de nouvelles dépendances
- Modifier des APIs publiques sans le signaler explicitement

---

### 5.8 Docs-writer — subagent

| Propriété | Valeur |
|---|---|
| Mode | `subagent` |
| Couleur | Bleu foncé `#0369a1` |
| Accès fichiers | **Complet** — `edit: allow` |
| Bash | `ls`, `git log`, `grep` uniquement — pas d'exécution |

**Rôle** : rédige et maintient la documentation technique. S'adapte au style existant dans le projet.

**Types de documentation produits** :

| Type | Détail |
|---|---|
| JSDoc / TSDoc | `@param`, `@returns`, `@throws`, `@example` |
| Commentaires inline | Uniquement le *pourquoi*, jamais le *quoi* |
| README | Sections structurées, exemples de code fonctionnels |
| ADR | Architecture Decision Records au format standard |
| API docs | Endpoints, request/response, exemples curl |

**Principe fondamental** : l'exactitude prime sur l'exhaustivité. Une documentation fausse est pire qu'une documentation absente.

---

### 5.9 Performance — subagent

| Propriété | Valeur |
|---|---|
| Mode | `subagent` |
| Couleur | Ambre `#b45309` |
| Accès fichiers | **Aucun** — `edit: deny` |
| Bash | `ls`, `grep`, `git diff` · commandes d'audit `ask` |

**Rôle** : audit de performance. Identifie les bottlenecks, retourne un rapport priorisé par impact utilisateur.

**Domaines couverts** :

*Backend / API* : requêtes N+1, indexes manquants, fetch excessif, opérations bloquantes, cache absent, payload surdimensionné.

*Frontend* : re-renders inutiles, memoization manquante, bundle size, requêtes en cascade au lieu de parallèles, fuites mémoire.

*Algorithmes* : complexité O(n²) ou pire, mauvaise structure de données, passes multiples inutiles sur les mêmes données.

**Format de sortie** :

```
## Performance Audit — <scope>

### Critical  (impact utilisateur significatif)
- [fichier:ligne] Problème + Impact + Fix

### High      (impact notable à l'échelle)
### Medium    (gains mineurs)
### Out of scope (nécessite des données de profiling réelles)

### Summary
```

---

### 5.10 Security — subagent

| Propriété | Valeur |
|---|---|
| Mode | `subagent` |
| Couleur | Rouge sombre `#991b1b` |
| Accès fichiers | **Aucun** — `edit: deny` |
| Bash | `grep`, `ls`, `cat`, `find` uniquement (read-only) |

**Rôle** : audit de sécurité basé sur l'OWASP Top 10. Retourne un rapport avec niveau de sévérité.

**Catégories analysées** :

| Catégorie | OWASP | Exemples |
|---|---|---|
| Injection | A03 | SQL injection, command injection, NoSQL |
| Auth & Authz | A01, A07 | Auth manquante, RBAC cassé, JWT faible |
| Data Exposure | A02 | Secrets hardcodés, PII dans les logs, pas de chiffrement |
| Misconfiguration | A05 | CORS wildcard, headers permissifs, debug en prod |
| Dépendances | A06 | Packages avec CVE connus, versions critiques obsolètes |
| Patterns dangereux | — | `eval()`, `innerHTML`, path traversal, ReDoS, race conditions |

**Niveaux de sévérité** : Critical → High → Medium → Low → Info

**Important** : rapporte uniquement ce qui est constaté dans le code. Ne construit pas de chaînes d'attaque hypothétiques.

---

### 5.11 Git-publisher — subagent

| Propriété | Valeur |
|---|---|
| Mode | `subagent` |
| Couleur | Indigo `#4f46e5` |
| Accès fichiers | **Aucun** — `edit: deny` |
| Bash | Git read + `git add/commit/push`, `glab mr`, `gh pr` |

**Rôle** : rédige les messages de commit (conventional commits) et les descriptions de MR/PR, puis exécute le flow complet de publication.

**Workflow** :

```
1. git status + git diff --staged (ou main...HEAD)
2. Détection de la plateforme via git remote get-url origin
   → github.com → gh
   → autre       → glab
3. Rédaction du message de commit (conventional commits)
4. Commit direct si le diff est clair — sinon demande confirmation
5. git push (avec -u origin <branch> si pas d'upstream)
6. Propose de créer la MR/PR — si oui, rédige et crée
```

**Invocation** : `@git-publisher` ou automatiquement par l'orchestrateur après une tâche.

---

## 6. Règles globales

Les règles sont des fichiers markdown avec `alwaysApply: true` dans leur frontmatter. Elles sont injectées dans le contexte de **tous** les agents via le champ `instructions` de `opencode.json`. Elles s'appliquent donc au `build`, à l'orchestrateur, et à chaque subagent.

### 6.1 git-safety

**Fichier** : `.opencode/rules/git-safety.md`

#### Règle fondamentale

> Ne JAMAIS commiter, pusher, ni effectuer de changements de code directement sur `main`.

#### Arbre de décision (exécuté avant tout changement de code)

```
git branch --show-current
        │
        ▼
  Branche = main ?
  ┌─ OUI ──────────────────────────────────────────────────────┐
  │  STOP. Avertir l'utilisateur.                              │
  │  "Je ne travaille pas directement sur main."               │
  │  Proposer de créer une branche avant de continuer.         │
  │  Ne rien modifier tant qu'on est sur main.                 │
  └────────────────────────────────────────────────────────────┘
        │
  Branche ≠ main
        │
        ├─ Fix / amélioration liée à la branche actuelle ?
        │   └─ Rester sur la branche actuelle.
        │
        ├─ Nouvelle feature dépendant de la branche actuelle ?
        │   └─ git checkout -b <nom>
        │       (fork depuis la branche actuelle)
        │
        └─ Nouvelle feature indépendante ?
            └─ git fetch origin
               git checkout main && git pull
               git checkout -b <nom>
               (fork depuis main à jour)
```

#### Cas de doute

Si l'intention est ambiguë (tâche liée **ou** indépendante), l'agent demande **avant** de créer quoi que ce soit :

> "Cette tâche est-elle liée à `feat/auth` ou indépendante de cette branche ?
> Je propose `feature/notifications` — ça te convient ?"

#### Nommage des branches

| Préfixe | Usage |
|---|---|
| `feature/` | Nouvelle fonctionnalité |
| `fix/` | Correction de bug |
| `refactor/` | Refactoring |
| `docs/` | Documentation |
| `test/` | Ajout de tests |
| `perf/` | Optimisation de performance |

Noms en **kebab-case**, courts et descriptifs.

#### Commits

- Format **Conventional Commits** : `feat:`, `fix:`, `refactor:`, `test:`, `docs:`, `chore:`
- Jamais de `git push --force` sur une branche partagée sans confirmation explicite
- Préférer le rebase au merge pour intégrer `main` dans une feature branch

---

### 6.2 code-quality

**Fichier** : `.opencode/rules/code-quality.md`

#### Règle fondamentale

> Après TOUT changement de code, tous les checks qualité définis dans `AGENTS.md` doivent passer avant de déclarer la tâche terminée.

#### Procédure

```
1. Lire ## Quality Checks dans AGENTS.md
   └─ Si section absente → signaler à l'utilisateur et demander les commandes

2. Exécuter dans l'ordre :
   format    → formatter le code (peut modifier des fichiers)
   lint      → vérifier les règles statiques
   typecheck → vérifier les types
   test      → exécuter les tests
   build     → vérifier la compilation / le bundle

3. En cas d'échec :
   └─ Analyser l'erreur
   └─ Corriger
   └─ Re-exécuter la commande concernée
   └─ Recommencer jusqu'à passage complet

4. Si l'échec préexistait avant les changements :
   └─ Signaler : "Ce check échouait déjà avant mes changements : <erreur>"
   └─ Proposer de corriger ou d'ignorer selon le contexte

5. Confirmer une fois tout passé :
   "Tous les checks qualité passent : format ✓ lint ✓ typecheck ✓ test ✓ build ✓"
```

#### Agents soumis au quality gate

| Agent | Gate qualité | Raison |
|---|---|---|
| `build` | Oui | Après chaque changement de code |
| `tester` | Oui | Les tests générés doivent eux-mêmes passer |
| `refactorer` | Oui | Critique — toute régression est un bug |
| `orchestrator` | Oui | Gate final après tous les subagents |
| `reviewer` | Non | Read-only, aucun changement de code |
| `debugger` | Non | Read-only, aucun changement de code |
| `docs-writer` | Non | Documentation uniquement |
| `performance` | Non | Audit uniquement |
| `security` | Non | Audit uniquement |

---

## 7. Commandes personnalisées

Les commandes sont des fichiers markdown dans `.opencode/commands/`. Elles s'invoquent avec `/` dans le TUI et acceptent des arguments positionnels (`$1`, `$2`, …) ou `$ARGUMENTS` pour tout récupérer.

Le répertoire `commands/` est **symlinkée** depuis le template — ajouter une commande ici la déploie automatiquement dans tous les projets installés.

---

### 7.1 /ticket

**Fichier :** `.opencode/commands/ticket.md`

**Usage :**
```
/ticket <id> [contexte additionnel]
```

**Exemples :**
```
/ticket 42
/ticket 87 focus sur le module de paiement
/ticket PROJ-123 ne pas toucher à l'API publique
```

**Rôle :** analyse un ticket (GitLab, GitHub ou Jira) et l'ensemble de ses sous-tickets pour produire un plan d'implémentation structuré. Ne crée pas de branche, ne modifie aucun fichier.

**Trackers supportés :**

| Format de l'ID | Tracker détecté | Commande utilisée |
|---|---|---|
| Entier (`42`) + remote `gitlab.com` | GitLab | `glab issue view` + GraphQL |
| Entier (`42`) + remote `github.com` | GitHub | `gh issue view` |
| `PROJ-42` | Jira | `acli jira issue view` |

**Livrable produit :**

```
## Plan d'implémentation — Ticket #<id> : <titre>

### Contexte additionnel
### Arbre des sous-tickets      — ID, titre, état, taille estimée
### Analyse technique           — fichiers impactés, dépendances, risques
### Ordre d'implémentation      — séquence recommandée avec approche par sous-ticket
### Prochaines étapes concrètes — branche à créer, par où commencer
```

**Agent à utiliser :** choisir avant de lancer la commande.
- `plan` — analyse pure, aucun accès bash (recommandé si `glab` est déjà configuré)
- `build` / `orchestrator` — peut explorer le codebase dynamiquement en complément

---

## 8. Configuration par projet

### `opencode.json`

Copié dans chaque projet par `agents-setup`. À customiser selon le projet.

```jsonc
{
  "$schema": "https://opencode.ai/config.json",

  // Règles globales injectées dans tous les agents
  "instructions": [
    ".opencode/rules/git-safety.md",
    ".opencode/rules/code-quality.md"
  ],

  "agent": {
    "build": {
      "permission": {
        "bash": {
          "*": "ask",                // toutes les commandes bash → confirmation
          "git status*": "allow",   // lecture git → silencieux
          "git diff*": "allow",
          "git log*": "allow",
          "git branch*": "allow",
          "git fetch*": "allow",
          "ls*": "allow",
          "pwd": "allow"
        }
      }
    },
    "plan": {
      "permission": {
        "edit": "deny",   // aucune modification de fichier
        "bash": "deny"    // aucune commande shell
      }
    }
  }
}
```

**Customisations utiles** :

```jsonc
// Utiliser un modèle spécifique pour un agent
"agent": {
  "orchestrator": {
    "model": "anthropic/claude-opus-4-5"
  }
}

// Autoriser automatiquement les commandes de test pour ce projet
"agent": {
  "build": {
    "permission": {
      "bash": {
        "npm test": "allow",
        "npm run lint": "allow"
      }
    }
  }
}

// Désactiver un agent non pertinent pour ce projet
"agent": {
  "security": {
    "disable": true
  }
}
```

---

### `AGENTS.md`

Copié depuis `AGENTS.md.template`. C'est le fichier le plus important à remplir — les agents le lisent systématiquement pour comprendre le projet et récupérer les commandes qualité.

**Structure** :

```markdown
# Nom du projet

## Stack
NestJS + TypeScript / Nuxt 3 + Vue / etc.

## Structure
- src/modules/  — modules fonctionnels
- src/common/   — utilitaires partagés
- tests/        — tests (miroir de src/)

## Commands
- dev: npm run dev
- install: npm install

## Quality Checks
<!-- OBLIGATOIRE — tous les agents qui modifient du code exécutent ces commandes -->
- test: npm test
- lint: npm run lint
- format: npm run format
- typecheck: npm run typecheck
- build: npm run build

## Conventions
- Named exports uniquement, pas de default export
- DTOs validés avec class-validator
- Conventional commits : feat/fix/chore/refactor/test/docs
- ...

## Notes
- La migration DB se lance avec : npm run migrate
- ...
```

> La section `## Quality Checks` est **obligatoire**. Si elle est absente, les agents le signalent et demandent de la remplir avant de continuer.

---

## 9. Exemples de flux complets

### Exemple 1 — Nouvelle feature indépendante

**Contexte** : tu es sur `feat/auth`, tu veux ajouter un système de notifications.

```
Toi → @orchestrateur "Implémente un système de notifications push"

Orchestrateur :
  1. git branch --show-current → feat/auth
  2. "Notifications est-il lié à feat/auth ou indépendant ?"
     → Tu réponds : "Indépendant"
  3. git fetch origin && git checkout main && git pull
     git checkout -b feature/push-notifications
  4. Tâche = implémentation → délègue à build directement
     (ou gère en direct selon la complexité)
  5. Quality gate : format ✓ lint ✓ typecheck ✓ test ✓ build ✓
  6. Synthèse : "Feature implémentée sur feature/push-notifications"
```

---

### Exemple 2 — Bug + investigation + correction

**Contexte** : les emails de confirmation ne partent pas.

```
Toi → @orchestrateur "Les emails de confirmation ne sont pas envoyés"

Orchestrateur :
  1. git branch --show-current → feature/user-onboarding  ✓
  2. Tâche = bug → invoquer @debugger en premier

  @debugger :
    Phase 1 : symptôme documenté
    Phase 2 : 3 hypothèses (queue bloquée, config SMTP, template manquant)
    Phase 3 : git log → grep du service mail → traçage du flux
    Phase 4 : Root cause = variable d'env SMTP_HOST absente en staging
    → Rapport remis à l'orchestrateur

  Orchestrateur :
    → Correction ciblée via build (ajout de la config + guard au démarrage)
    → Quality gate complet
    → Synthèse : root cause + fix appliqué + checks ✓
```

---

### Exemple 3 — Revue de code + audit sécurité en parallèle

**Contexte** : tu viens de finir un module de paiement.

```
Toi → @orchestrateur "Revue complète du module payment avant merge"

Orchestrateur :
  1. git branch --show-current → feature/payment  ✓
  2. Tâches = review + sécu → indépendantes → lancement en parallèle

  En parallèle :
    @reviewer  → analyse src/modules/payment/
    @security  → audit src/modules/payment/

  Résultats :
    reviewer  → 2 Critical, 4 Warning (ex: montant non validé côté serveur)
    security  → 1 High (secret Stripe dans le code), 2 Medium

  Orchestrateur :
    → Synthèse consolidée des deux rapports
    → Priorisé : Critical et High d'abord
    → Pas de quality gate (aucun fichier modifié par ces agents)
```

---

### Exemple 4 — Refactoring d'un module

**Contexte** : le service `UserService` fait 600 lignes.

```
Toi → @orchestrateur "Refactore UserService, il est trop gros"

Orchestrateur :
  1. git branch --show-current → feat/user-improvements  ✓
  2. Tâche liée à la branche → rester dessus
  3. Invoquer @refactorer

  @refactorer :
    Step 1 : Lire UserService en entier
    Step 2 : Plan proposé
      - Extraire AuthUserService (logique d'auth)
      - Extraire UserQueryService (logique de lecture)
      - Renommer des méthodes ambiguës
      - Risque : Medium (interfaces publiques changent)
    → Attente approbation

  Toi → "Go"

  @refactorer :
    Step 3 : Refactoring incrémental
    Step 4 : format ✓ lint ✓ typecheck ✓ test ✓ build ✓

  Orchestrateur :
    → Quality gate final (déjà passé par refactorer, vérifie quand même)
    → Synthèse : 3 fichiers créés, 1 fichier supprimé, tous les checks ✓
```

---

### Exemple 5 — Tentative de travail sur `main`

```
Toi → (sur la branche main) @build "Ajoute un champ email à User"

Build :
  1. git branch --show-current → main
  2. STOP.
     "Je ne travaille pas directement sur main.
     Crée une branche d'abord. Je propose : feature/user-email-field
     Tu peux faire : git checkout -b feature/user-email-field"

→ Aucun fichier modifié.
```

---

## 10. Personnalisation

### Ajouter un agent spécifique à un projet

Créer un fichier dans `.opencode/agents/` du projet (pas dans le symlink — il faut d'abord le remplacer par un vrai dossier) :

```bash
# Remplacer le symlink par un vrai dossier en conservant les agents globaux
cp -r ~/dev/agents/.opencode/agents mon-projet/.opencode/agents-backup
rm mon-projet/.opencode/agents
cp -r ~/dev/agents/.opencode/agents mon-projet/.opencode/agents
```

Puis créer l'agent spécifique :

```bash
# Exemple : agent spécialisé pour les migrations de BDD
cat > mon-projet/.opencode/agents/db-migrator.md << 'EOF'
---
description: Database migration specialist — creates, reviews and runs database migrations safely.
mode: subagent
permission:
  edit: allow
  bash:
    "*": ask
    "npm run migrate:status": allow
    "npm run migrate:dry-run": allow
---

Tu es spécialisé dans les migrations de base de données pour ce projet.
...
EOF
```

### Surcharger les permissions d'un agent built-in

Dans le `opencode.json` du projet :

```jsonc
"agent": {
  // Autoriser automatiquement les tests pour ce projet
  "build": {
    "permission": {
      "bash": {
        "*": "ask",
        "npm test": "allow",
        "npm run test:watch": "allow",
        "git *": "allow"
      }
    }
  }
}
```

### Désactiver un agent

```jsonc
"agent": {
  "performance": { "disable": true },
  "docs-writer": { "disable": true }
}
```

### Mettre à jour tous les projets

Modifier un fichier dans `~/dev/agents/.opencode/agents/` ou `~/dev/agents/.opencode/rules/` : la mise à jour est **immédiate** dans tous les projets utilisant les symlinks. Pas besoin de réinstaller.

---

## 11. Travail en parallèle — Worktrees

OpenCode ne gère pas nativement le parallélisme de sessions. La solution est **git worktrees** : chaque feature travaille dans son propre dossier sur le disque, avec sa propre branche, et peut avoir son propre `opencode` ouvert en parallèle sans aucun conflit de fichiers.

### Concept

```
~/dev/
├── mon-projet/                       ← repo principal (main)
├── mon-projet-feature-auth/          ← worktree feature/auth
└── mon-projet-feature-notifications/ ← worktree feature/notifications
```

Chaque dossier est indépendant sur le disque mais partage le même historique git.

### `wt-new <branch>` — créer un worktree

```bash
# Depuis n'importe où dans le repo principal
wt-new feature/auth
```

Ce que ça fait :
1. Refuse de travailler sur `main`/`master`
2. Fetch origin et crée la branche depuis `main` à jour (si elle n'existe pas)
3. `git worktree add ../mon-projet-feature-auth feature/auth`
4. Lance `agents-setup` dans le nouveau worktree (symlinks + opencode.json + AGENTS.md)
5. `cd` dans le worktree (le terminal se déplace automatiquement)
6. Lance opencode (bloquant — Ctrl-C pour quitter)
7. Après fermeture d'opencode, le terminal est toujours dans le worktree → prêt pour `wt-done`

Sortie attendue :

```
Creating worktree for branch: feature/auth
Path: /home/<user>/dev/mon-projet-feature-auth
──────────────────────────────────────────
  ✓ Branch 'feature/auth' created from main
  ✓ Worktree created at /home/<user>/dev/mon-projet-feature-auth
  ✓ .opencode/agents/ → ~/dev/agents/.opencode/agents
  ✓ .opencode/rules/  → ~/dev/agents/.opencode/rules
  ✓ opencode.json copied
  ✓ AGENTS.md created from template

  Worktree ready.
  When done, run wt-done from inside the worktree to clean up.

  → Launching opencode... (Ctrl-C to exit, then run wt-done)
```

### `wt-done` — nettoyer un worktree terminé

```bash
# Depuis l'intérieur du worktree, après que la PR est mergée
wt-done
```

Ce que ça fait :
1. Refuse de s'exécuter depuis le repo principal
2. Vérifie les changements non commités → demande confirmation si présents
3. Fetch origin et vérifie si la branche est mergée dans `origin/main`
   - **Mergée** → suppression directe sans confirmation
   - **Pas mergée** → avertissement + confirmation explicite requise
4. `git worktree remove` + `git branch -d` + `git worktree prune`
5. `cd` dans le repo principal (le terminal revient automatiquement)

### `wt-list` — voir les worktrees actifs

```bash
wt-list
# alias de : git worktree list

/home/user/dev/mon-projet                        abc1234 [main]
/home/user/dev/mon-projet-feature-auth           def5678 [feature/auth]
/home/user/dev/mon-projet-feature-notifications  ghi9012 [feature/notifications]
```

### Flux complet — deux features en parallèle

```bash
# ── Feature A : auth ──────────────────────────────────────────
cd ~/dev/mon-projet
wt-new feature/auth
# → cd automatique dans le worktree + opencode lancé
# → Ctrl-C pour quitter opencode
# → terminal dans ~/dev/mon-projet-feature-auth

# ── Feature B : notifications (depuis un autre terminal) ──────
cd ~/dev/mon-projet
wt-new feature/notifications
# → idem, terminal dans ~/dev/mon-projet-feature-notifications

# ── Nettoyage après merge ──────────────────────────────────────
# (depuis le worktree feature/auth, PR mergée)
wt-done   # → supprime worktree + branche + cd dans ~/dev/mon-projet

# (depuis le worktree feature/notifications)
wt-done   # idem
```

### Cas particulier — fork depuis une feature en cours

Si `feature/notifications` dépend de `feature/auth` (pas encore mergée dans main) :

```bash
# Se placer dans le worktree de feature/auth
cd ~/dev/mon-projet-feature-auth

# Créer le worktree depuis la branche actuelle
wt-new feature/notifications
# → fork depuis feature/auth (puisqu'on est dans ce worktree)
```

> `wt-new` crée la branche depuis `main` par défaut. Pour forker depuis une autre branche, lance `wt-new` depuis le worktree de cette branche.

---

## 12. Référence rapide

### Tableau des agents

| Agent | Mode | Couleur | Écrit du code | Bash | Cas d'usage |
|---|---|---|---|---|---|
| `orchestrator` | primary | Violet | Oui | Git read/write · utilitaires · uv/npm/… | Tâches composites, délégation |
| `build` | primary | — | Oui | Git read (auto) · reste (ask) | Implémentation directe |
| `plan` | primary | — | Non | Non | Planification, exploration |
| `reviewer` | subagent | Bleu | Non | Git read · grep · cat · find | Revue de code |
| `debugger` | subagent | Rouge | Non | Git read · grep · cat · find | Investigation de bugs |
| `tester` | subagent | Vert | Oui | Git read · utilitaires · uv/npm/… | Génération de tests |
| `refactorer` | subagent | Orange | Oui | Git read · utilitaires · uv/npm/… | Refactoring |
| `docs-writer` | subagent | Bleu foncé | Oui (docs) | Git log/diff · ls · grep · cat · find | Documentation |
| `performance` | subagent | Ambre | Non | ls · grep · cat · find | Audit de performances |
| `security` | subagent | Rouge sombre | Non | grep · ls · cat · find (read-only) | Audit de sécurité |
| `git-publisher` | subagent | Indigo | Non | Git read/add/commit/push · glab · gh | Commit + MR/PR |

### Commandes OpenCode utiles

| Action | Commande |
|---|---|
| Cycler entre agents primaires | **Tab** |
| Invoquer un subagent | `@nom-agent message` |
| Basculer en mode Plan | **Tab** jusqu'à "Plan" |
| Annuler les derniers changements | `/undo` |
| Rétablir | `/redo` |
| Initialiser AGENTS.md | `/init` |
| Partager une session | `/share` |
| Lister les modèles disponibles | `opencode models` (CLI) |

### Commandes personnalisées

| Commande | Description |
|---|---|
| `/ticket <id> [contexte]` | Analyse un ticket et ses sous-tickets, produit un plan d'implémentation |

### Helpers shell disponibles

| Commande | Type | Source | Description |
|---|---|---|---|
| `agents-setup` | alias | `setup.sh` | Installe les agents dans le projet courant |
| `wt-new <branch>` | **fonction** | `shell-functions.sh` | Crée un worktree + cd + opencode |
| `wt-done` | **fonction** | `shell-functions.sh` | Nettoie le worktree + cd vers le repo principal |
| `wt-list` | alias | `git worktree list` | Liste tous les worktrees actifs |

> `wt-new` et `wt-done` sont des **fonctions shell** (pas des alias) car ils doivent modifier le répertoire courant du terminal. Ils sont chargés via `source "$HOME/dev/agents/shell-functions.sh"` dans `.bashrc` et `.zshrc`.

### Fichiers clés à modifier après `agents-setup`

| Priorité | Fichier | Action requise |
|---|---|---|
| **Obligatoire** | `AGENTS.md` | Remplir `## Quality Checks` avec les commandes du projet |
| Recommandé | `AGENTS.md` | Remplir Stack, Structure, Conventions |
| Optionnel | `opencode.json` | Ajuster permissions bash, ajouter modèles spécifiques |
