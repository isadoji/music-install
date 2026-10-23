#!/bin/bash
# install_skills.sh -- enlaza cada Skill de este repo (skills/<nombre>/SKILL.md)
# en ~/.claude/skills/<nombre> para que Claude Code la encuentre. Idempotente:
# si el symlink ya apunta aqui no hace nada; si existe algo distinto con ese
# nombre, no lo toca y avisa. Ver README.md §10.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
DEST="${CLAUDE_SKILLS_DIR:-$HOME/.claude/skills}"
mkdir -p "$DEST"
for d in "$HERE"/*/; do
    [ -f "$d/SKILL.md" ] || continue
    name=$(basename "$d"); src="${d%/}"; link="$DEST/$name"
    if [ -L "$link" ] && [ "$(readlink -f "$link")" = "$(readlink -f "$src")" ]; then
        echo "ok      $link -> $src (ya existia)"
    elif [ -e "$link" ] || [ -L "$link" ]; then
        echo "AVISO   $link ya existe y no apunta a $src; no se toca"
    else
        ln -s "$src" "$link"; echo "creado  $link -> $src"
    fi
done
