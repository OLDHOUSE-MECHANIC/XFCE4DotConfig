#!/usr/bin/env bash
# setup.sh — restore XFCE config + dotfiles on a fresh install
# Usage: ./setup.sh [path/to/xfce-backup.tar.gz]
#        If no archive is passed, it picks the latest from ~/xfce-backups/
set -euo pipefail

BACKUP_DIR="$HOME/xfce-backups"
DOTFILES_DIR="$HOME/dotfiles"
BACKUP="${1:-}"

# ── Find backup archive ───────────────────────────────────────────────────────
if [[ -z "$BACKUP" ]]; then
  BACKUP=$(ls -t "$BACKUP_DIR"/xfce-backup-*.tar.gz 2>/dev/null | head -1 || true)
fi

if [[ -z "$BACKUP" || ! -f "$BACKUP" ]]; then
  echo "ERROR: No backup archive found."
  echo "Usage: ./setup.sh /path/to/xfce-backup.tar.gz"
  exit 1
fi

echo "==> Restoring from: $BACKUP"
echo ""

# ── Kill XFCE daemons BEFORE touching any files ───────────────────────────────
# This is critical — xfconfd will overwrite restored files from memory if left running
echo "==> Stopping XFCE daemons..."
pkill -9 xfce4-panel  2>/dev/null || true
pkill -9 xfconfd      2>/dev/null || true
pkill -9 xfce4-session 2>/dev/null || true
sleep 1

# ── Wipe stale destination state ─────────────────────────────────────────────
echo "==> Clearing stale XFCE config..."
rm -rf "$HOME/.config/xfce4/panel"
rm -rf "$HOME/.config/xfconf/xfce-perchannel-xml"
rm -rf "$HOME/.config/xfce4/xfconf"

# ── Extract to temp, then copy into place (no mv) ────────────────────────────
echo "==> Extracting archive..."
TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT   # always clean up temp on exit

tar -xzf "$BACKUP" -C "$TMPDIR"

echo "==> Copying config files into place..."

copy_if_exists() {
  local src="$1"
  local dst="$2"
  if [[ -e "$TMPDIR/$src" ]]; then
    mkdir -p "$(dirname "$HOME/$dst")"
    cp -r "$TMPDIR/$src" "$HOME/$dst"
    echo "    Copied: $src"
  fi
}

copy_if_exists ".config/xfce4"                       ".config/xfce4"
copy_if_exists ".config/xfconf/xfce-perchannel-xml"  ".config/xfconf/xfce-perchannel-xml"
copy_if_exists ".config/Thunar"                      ".config/Thunar"
copy_if_exists ".config/gtk-3.0"                     ".config/gtk-3.0"
copy_if_exists ".config/gtk-4.0"                     ".config/gtk-4.0"
copy_if_exists ".local/share/xfce4"                  ".local/share/xfce4"
copy_if_exists ".gtkrc-2.0"                          ".gtkrc-2.0"

# ── Restore dotfiles ──────────────────────────────────────────────────────────
if [[ -d "$DOTFILES_DIR" ]]; then
  echo ""
  echo "==> Restoring dotfiles from $DOTFILES_DIR ..."

  DOTFILES=(
    ".bashrc"
    ".bash_profile"
    ".bash_aliases"
    ".zshrc"
    ".zprofile"
    ".profile"
    ".inputrc"
    ".vimrc"
    ".tmux.conf"
    ".gitconfig"
    ".gitignore_global"
    ".gtkrc-2.0"
    ".Xresources"
    ".xinitrc"
  )

  for f in "${DOTFILES[@]}"; do
    if [[ -f "$DOTFILES_DIR/$f" ]]; then
      cp "$DOTFILES_DIR/$f" "$HOME/$f"
      echo "    Copied: $f"
    fi
  done
else
  echo ""
  echo "  Tip: no ~/dotfiles directory found, skipping dotfile restore."
  echo "  Run backup-xfce.sh first to populate it."
fi

# ── Reload Xresources if present ─────────────────────────────────────────────
if [[ -f "$HOME/.Xresources" ]] && command -v xrdb &>/dev/null; then
  xrdb -merge "$HOME/.Xresources"
  echo "==> Xresources merged."
fi

# ── Restart XFCE daemons ─────────────────────────────────────────────────────
echo ""
echo "==> Restarting XFCE..."
xfconfd &
sleep 1
xfce4-panel &
sleep 1

echo ""
echo "==> Restore complete!"
echo "    Log out and back in if anything still looks off."
