#!/usr/bin/env bash
#
# SessionStart hook: make the Morrison-Lab ai-config skill set available in
# Claude Code *web/cloud* sessions.
#
# Why this exists
# ---------------
# `.claude/settings.json` declares ai-config via `extraKnownMarketplaces` /
# `enabledPlugins`. That works locally, but a cloud session never installs it:
# measured 2026-09-14 in a fresh claude.ai/code session on this repo, with the
# plugin config checked in and pointing at a correctly-named marketplace, the
# plugin listing came back empty and none of ai-config's ~205 skills were
# present beyond a stale ~45-skill subset synced separately to the account.
#
# That settles a question ai-config's own notes left open (Morrison-Lab/ai-config
# memories/claude-code-settings.md, "Two docs pages disagree on whether a
# project-declared plugin auto-installs in a cloud session"): the settings
# reference governs. A plugin whose source is a GitHub repository, enabled in a
# project's `.claude/settings.json`, is *not* installed for cloud sessions.
#
# So we fetch the skills ourselves and drop them in `~/.claude/skills/`, which
# Claude Code discovers directly with no plugin, no marketplace, no install step.
#
# Timing
# ------
# SessionStart runs after checkout, so in principle it could land after the
# session's first skill scan. Measured 2026-09-14: it does not -- running this
# script mid-session made all 204 skills available to the running session
# immediately, with no `/reload-plugins` and no resume. The container is reused,
# so every later session in it also starts with the skills already on disk.
#
# Everything here is idempotent and non-fatal: a blocked network or a missing
# git degrades to "no ai-config skills" rather than failing session startup.

set -uo pipefail

# Local machines install ai-config once as a native plugin (see that repo's
# README), so this is remote-only.
if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

AI_CONFIG_REPO="${AI_CONFIG_REPO:-https://github.com/Morrison-Lab/ai-config}"
AI_CONFIG_DIR="${AI_CONFIG_DIR:-$HOME/.cache/ai-config}"
SKILLS_DEST="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/skills"
MARKER=".ai-config-managed"

warn() { printf 'session-start: %s\n' "$*" >&2; }

command -v git >/dev/null 2>&1 || {
  warn "git unavailable; skipping ai-config skills"
  exit 0
}

# --- 1. Fetch (or refresh) the ai-config checkout -------------------------
sync_checkout() {
  if [ -d "$AI_CONFIG_DIR/.git" ]; then
    GIT_LFS_SKIP_SMUDGE=1 git -C "$AI_CONFIG_DIR" fetch --depth 1 origin HEAD >/dev/null 2>&1 || return 1
    git -C "$AI_CONFIG_DIR" reset --hard FETCH_HEAD >/dev/null 2>&1 || return 1
  else
    rm -rf "$AI_CONFIG_DIR"
    mkdir -p "$(dirname "$AI_CONFIG_DIR")"
    GIT_LFS_SKIP_SMUDGE=1 git clone --depth 1 "$AI_CONFIG_REPO" "$AI_CONFIG_DIR" >/dev/null 2>&1 || return 1
  fi
}

if ! sync_checkout; then
  if [ -d "$AI_CONFIG_DIR/skills" ]; then
    warn "could not refresh ai-config; using the existing checkout"
  else
    warn "could not fetch ai-config (network policy?); skipping skill install"
    exit 0
  fi
fi

[ -d "$AI_CONFIG_DIR/skills" ] || {
  warn "no skills/ in ai-config checkout"
  exit 0
}

# --- 2. Drop skills this hook previously installed ------------------------
# The marker means we only ever remove our own copies, never a hand-written or
# repo-local skill, and that a skill deleted upstream disappears here too.
mkdir -p "$SKILLS_DEST"
pruned=0
for d in "$SKILLS_DEST"/*/; do
  [ -e "$d$MARKER" ] || continue
  rm -rf "$d" && pruned=$((pruned + 1))
done

# --- 3. Install the current set -------------------------------------------
installed=0
skipped=0
for src in "$AI_CONFIG_DIR"/skills/*/; do
  [ -f "$src/SKILL.md" ] || continue
  name="$(basename "$src")"
  dest="$SKILLS_DEST/$name"

  # An unmanaged directory of the same name is someone else's skill: leave it.
  if [ -e "$dest" ]; then
    skipped=$((skipped + 1))
    continue
  fi

  if cp -R "$src" "$dest" 2>/dev/null; then
    : >"$dest/$MARKER"
    installed=$((installed + 1))
  else
    warn "failed to install skill: $name"
  fi
done

printf 'ai-config skills: %d installed in %s (%d refreshed, %d left to existing definitions)\n' \
  "$installed" "$SKILLS_DEST" "$pruned" "$skipped"
