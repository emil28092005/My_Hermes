#!/bin/bash
# sync_skill.sh <skill-name>
# Синхронизация скилла из ~/.hermes/skills/ в ~/My_Hermes/skills/

set -euo pipefail

SKILL_NAME="${1:-}"
if [ -z "$SKILL_NAME" ]; then
    echo "Usage: $0 <skill-name>"
    echo "Example: $0 multi-site-localhost"
    exit 1
fi

SRC_BASE="$HOME/.hermes/skills"
DST_BASE="$HOME/My_Hermes/skills"
GIT_USER="${GIT_USER:-Emil Shanaty}"
GIT_EMAIL="${GIT_EMAIL:-emil28092005@gmail.com}"

# Find skill category
SRC_DIR=$(find "$SRC_BASE" -maxdepth 2 -type d -name "$SKILL_NAME" | head -1)
if [ -z "$SRC_DIR" ]; then
    echo "❌ Skill '$SKILL_NAME' not found in $SRC_BASE"
    echo "Available skills:"
    find "$SRC_BASE" -maxdepth 2 -type d | tail -n +2
    exit 1
fi

# Extract category from path
CATEGORY=$(basename "$(dirname "$SRC_DIR")")
DST_DIR="$DST_BASE/$CATEGORY/$SKILL_NAME"

# Sync files
echo "📁 Syncing: $SRC_DIR → $DST_DIR"
mkdir -p "$DST_DIR"
rsync -av --delete "$SRC_DIR/" "$DST_DIR/"

# Git push
cd "$HOME/My_Hermes" || { echo "❌ Repo not found"; exit 1; }

git add "skills/$CATEGORY/$SKILL_NAME/"

# Commit only if there are changes
if git diff --cached --quiet; then
    echo "⚠️ No changes to commit"
    exit 0
fi

git -c user.name="$GIT_USER" -c user.email="$GIT_EMAIL" \
  commit -m "feat(skills): sync $SKILL_NAME from .hermes"

# Push with force-with-lease (local .hermes = source of truth)
if git push --force-with-lease origin main; then
    echo "✅ Pushed: $SKILL_NAME"
else
    echo "❌ Push failed"
    exit 1
fi
