#!/usr/bin/env bash
# backup-xfce.sh — snapshot your XFCE config + dotfiles
# Usage: ./backup-xfce.sh [destination_folder]
set -euo pipefail

DEST="${1:-$HOME/xfce-backups}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
ARCHIVE="$DEST/xfce-backup-$TIMESTAMP.tar.gz"
DOTFILES_DIR="$HOME/dotfiles"
DESKTOP_XML="$HOME/.config/xfconf/xfce-perchannel-xml/xfce4-desktop.xml"

mkdir -p "$DEST"
mkdir -p "$DOTFILES_DIR"

echo "==> Flushing xfconfd to disk..."
pkill -HUP xconfd 2>/dev/null || true
sleep 0.5

# ── XFCE + GTK config archive ────────────────────────────────────────────────
echo "==> Creating archive: $ARCHIVE"
tar -czf "$ARCHIVE" \
  --exclude='*.log' \
  --exclude='*.lock' \
  -C "$HOME" \
  .config/xfce4 \
  .config/xfconf/xfce-perchannel-xml \
  .config/Thunar \
  .config/gtk-3.0 \
  .config/gtk-4.0 \
  .local/share/xfce4 \
  $([ -f "$HOME/.gtkrc-2.0" ] && echo ".gtkrc-2.0" || true) \
  2>/dev/null

echo "    Saved: $ARCHIVE"

# ── Wallpaper ─────────────────────────────────────────────────────────────────
if [[ -f "$DESKTOP_XML" ]]; then
  WPPATH=$(grep -oP '(?<=value=")[^"]+\.(jpg|jpeg|png|webp)' "$DESKTOP_XML" 2>/dev/null | head -1 || true)
  if [[ -n "$WPPATH" && -f "$WPPATH" ]]; then
    EXT="${WPPATH##*.}"
    cp "$WPPATH" "$DEST/wallpaper-$TIMESTAMP.$EXT"
    echo "    Wallpaper copied: $WPPATH"
  fi
fi

# ── Dotfiles ──────────────────────────────────────────────────────────────────
echo "==> Syncing dotfiles to $DOTFILES_DIR ..."

# List of dotfiles to track — add your own here
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
  if [[ -f "$HOME/$f" ]]; then
    cp "$HOME/$f" "$DOTFILES_DIR/$f"
    echo "    Copied: $f"
  fi
done

# Copy the backup archive into dotfiles too so it's all in one place
cp "$ARCHIVE" "$DOTFILES_DIR/"

# ── Git commit (if dotfiles is a repo) ───────────────────────────────────────
if [[ -d "$DOTFILES_DIR/.git" ]]; then
  echo "==> Committing to git..."
  cd "$DOTFILES_DIR"
  git add -A
  git commit -m "xfce snapshot $TIMESTAMP" 2>/dev/null && echo "    Git commit done." || echo "    Nothing new to commit."
  cd - > /dev/null
else
  echo ""
  echo "  Tip: turn ~/dotfiles into a git repo for version history:"
  echo "    cd ~/dotfiles && git init && git add -A && git commit -m 'initial'"
fi

echo ""
echo "==> Backup complete!"
echo "    Archive : $ARCHIVE"
echo "    Dotfiles: $DOTFILES_DIR"
