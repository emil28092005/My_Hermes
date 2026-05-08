---
name: skill-sync-workflow
description: "Sync updated skills from ~/.hermes/skills/ to the My_Hermes repo and push to GitHub."
version: 1.0.0
author: Hermes Agent
metadata:
  hermes:
    tags: [skills, git, sync, github, hermes-agent, workflow]
---

# Skill Sync Workflow

Синхронизация обновлённых скиллов из `~/.hermes/skills/` в репозиторий `My_Hermes` и пуш на GitHub.

## Архитектура

| Источник правды | `~/.hermes/skills/` — актуальные скиллы |
| Цель | `~/My_Hermes/skills/` → GitHub `main` |
| Транспорт | Git + SSH |
| Conflict resolution | `force-with-lease` (source of truth = local .hermes) |

## Pipeline

### Step 1: Определить что синхронизировать

1. Пользователь говорит: «обнови скилл X» или «скилл X актуальный»
2. Находим скилл в `~/.hermes/skills/`:
   ```bash
   find ~/.hermes/skills -name "SKILL.md" | grep <skill-name>
   ```
3. Проверяем репозиторий:
   ```bash
   find ~/My_Hermes/skills -name "SKILL.md" | grep <skill-name>
   ```
4. Сравниваем: `wc -l`, `diff` или `md5sum` — определяем что новее.

### Step 2: Копировать файлы

Копируем **всю директорию скилла** рекурсивно, включая `linked_files`:
```bash
rsync -av --delete \
  ~/.hermes/skills/<category>/<skill-name>/ \
  ~/My_Hermes/skills/<category>/<skill-name>/
```

### Step 3: Git commit

```bash
cd ~/My_Hermes

git -c user.name="<name>" -c user.email="<email>" add skills/<category>/<skill-name>/

git -c user.name="<name>" -c user.email="<email>" commit -m "feat(skills): update <skill-name> to v<version>

- <changelog line 1>
- <changelog line 2>"
```

### Step 4: Push

```bash
cd ~/My_Hermes
git push origin main
```

**Если rejected (divergent branches):**
```bash
# Force-push — локальный .hermes = source of truth
git push --force-with-lease origin main
```

## Pitfalls

### 1. `failed to push some refs` (divergent branches)

Причина: на GitHub есть коммиты, которых нет локально. Локальный .hermes/skills/ = source of truth.

**Fix:**
```bash
git push --force-with-lease origin main
```

**НЕ делать `git pull` перед пушем** — это зальёт старые версии скиллов поверх актуальных.

### 2. `fatal: Need to specify how to reconcile divergent branches`

Причина: git pull без настроенной стратегии merge/rebase.

**Fix:** Не pull-ить. Использовать `force-with-lease`.

### 3. `Author identity unknown`

Причина: git identity не настроена в свежем окружении.

**Fix:**
```bash
git -c user.name="Emil Shanaty" -c user.email="emil28092005@gmail.com" commit ...
```

Никогда не конфигурить глобально без просьбы пользователя.

### 4. `Host key verification failed`

Причина: новая VM не доверяет GitHub SSH key.

**Fix перед первым пушем:**
```bash
ssh-keyscan -t ed25519 github.com >> ~/.ssh/known_hosts
```

### 5. Скилл не найден в .hermes/skills/

Причина: скилл в другой категории или ещё не создан.

**Fix:**
```bash
find ~/.hermes/skills -type d -name "*<name>*"
```

### 6. Забыли скопировать linked_files

Причина: копировали только SKILL.md.

**Fix:** Использовать `rsync -av --delete` на директорию целиком.

## Файловая структура скилла

```
~/.hermes/skills/
└── <category>/
    └── <skill-name>/
        ├── SKILL.md              (обязательно)
        ├── references/           (опционально)
        ├── templates/            (опционально)
        └── scripts/              (опционально)
```

## Скрипт-автоматизация

```bash
#!/bin/bash
# sync_skill.sh <skill-name>

SKILL_NAME="$1"
SRC_BASE="$HOME/.hermes/skills"
DST_BASE="$HOME/My_Hermes/skills"

# Find skill category
SRC_DIR=$(find "$SRC_BASE" -type d -name "$SKILL_NAME" | head -1)
[ -z "$SRC_DIR" ] && { echo "Skill not found in $SRC_BASE"; exit 1; }

# Extract category from path
CATEGORY=$(basename "$(dirname "$SRC_DIR")")
DST_DIR="$DST_BASE/$CATEGORY/$SKILL_NAME"

# Sync
mkdir -p "$DST_DIR"
rsync -av --delete "$SRC_DIR/" "$DST_DIR/"

# Git push
cd "$HOME/My_Hermes" || exit 1
git add "skills/$CATEGORY/$SKILL_NAME/"
git -c user.name="Emil Shanaty" -c user.email="emil28092005@gmail.com" \
  commit -m "feat(skills): sync $SKILL_NAME from .hermes"
git push --force-with-lease origin main
```
