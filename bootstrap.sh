#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="$HOME/.dotfiles-backup-$(date +%Y%m%d-%H%M%S)"

# Plugin pins. These are the commits this configuration is known to work with;
# lazy-lock.json plays the same role for the Neovim side.
TPM_COMMIT="e261deb1b47614eed3400089ce7197dc68acc4eb"
CATPPUCCIN_TMUX_COMMIT="d2d25bd3393fe43f19eb4fff6cdd2bdf5578e622"  # v2.3.0

log() {
  printf '\n==> %s\n' "$*"
}

if [[ ! -f /etc/arch-release ]]; then
  printf 'This bootstrap script is intended for Arch Linux.\n' >&2
  exit 1
fi

if grep -qiE '(microsoft|wsl)' /proc/version 2>/dev/null; then
  log "Arch on WSL detected"
else
  log "Arch detected (WSL was not detected, continuing anyway)"
fi

# ── Preflight ─────────────────────────────────────────────────────────
# Everything below links into the *default* config locations. If one of
# these variables redirects an app somewhere else, the symlinks would be
# created where nothing reads them -- fail loudly instead.
check_default_locations() {
  local problem=0

  if [[ -n "${XDG_CONFIG_HOME:-}" ]] && [[ "$XDG_CONFIG_HOME" != "$HOME/.config" ]]; then
    printf 'XDG_CONFIG_HOME is set to a non-default path: %s\n' "$XDG_CONFIG_HOME" >&2
    printf '  Expected %s. Unset it, or adjust this script deliberately.\n' "$HOME/.config" >&2
    problem=1
  fi

  if [[ -n "${STARSHIP_CONFIG:-}" ]] && [[ "$STARSHIP_CONFIG" != "$HOME/.config/starship.toml" ]]; then
    printf 'STARSHIP_CONFIG is set to a non-default path: %s\n' "$STARSHIP_CONFIG" >&2
    printf '  Starship would ignore the linked ~/.config/starship.toml.\n' >&2
    problem=1
  fi

  if [[ -n "${NVIM_APPNAME:-}" ]] && [[ "$NVIM_APPNAME" != "nvim" ]]; then
    printf 'NVIM_APPNAME is set to: %s\n' "$NVIM_APPNAME" >&2
    printf '  Neovim would read ~/.config/%s, not the linked ~/.config/nvim.\n' "$NVIM_APPNAME" >&2
    problem=1
  fi

  if (( problem )); then
    printf '\nRefusing to link into locations that are being overridden.\n' >&2
    exit 1
  fi

  # Report what Neovim itself resolves, so a mismatch is visible rather than
  # something you discover later when the config silently does not load.
  if command -v nvim >/dev/null 2>&1; then
    local resolved
    resolved="$(nvim --headless -c 'lua io.write(vim.fn.stdpath("config"))' -c 'qa' 2>/dev/null || true)"
    if [[ -n "$resolved" ]]; then
      printf 'Neovim config path resolves to: %s\n' "$resolved"
      if [[ "$resolved" != "$HOME/.config/nvim" ]]; then
        printf '  WARNING: expected %s\n' "$HOME/.config/nvim" >&2
      fi
    fi
  fi
}

log "Checking that config locations are the defaults"
check_default_locations

# ── Packages ──────────────────────────────────────────────────────────
mapfile -t PACKAGES < <(grep -Ev '^\s*(#|$)' "$DOTFILES_DIR/packages.txt")

log "Installing required packages"
sudo pacman -Syu --needed --noconfirm "${PACKAGES[@]}"

# ── Linking ───────────────────────────────────────────────────────────
backup_target() {
  local target="$1"

  if [[ -L "$target" ]]; then
    # Surface where the old link pointed. A leftover link into a custom path
    # is exactly the kind of thing that should not disappear silently.
    printf 'Replacing existing symlink: %s -> %s\n' "$target" "$(readlink "$target")"
    rm -f "$target"
    return
  fi

  if [[ -e "$target" ]]; then
    mkdir -p "$BACKUP_DIR"
    mv "$target" "$BACKUP_DIR/"
    printf 'Backed up: %s -> %s/\n' "$target" "$BACKUP_DIR"
  fi
}

link_dotfile() {
  local source="$1"
  local target="$2"

  if [[ -L "$target" ]] && [[ "$(readlink -f "$target")" == "$(readlink -f "$source")" ]]; then
    printf 'Already linked: %s\n' "$target"
    return
  fi

  backup_target "$target"
  mkdir -p "$(dirname "$target")"
  ln -s "$source" "$target"
  printf 'Linked: %s -> %s\n' "$target" "$source"
}

log "Linking dotfiles"
link_dotfile "$DOTFILES_DIR/.config/nvim"          "$HOME/.config/nvim"
link_dotfile "$DOTFILES_DIR/.config/starship.toml" "$HOME/.config/starship.toml"
link_dotfile "$DOTFILES_DIR/.tmux.conf"            "$HOME/.tmux.conf"
link_dotfile "$DOTFILES_DIR/.bashrc"               "$HOME/.bashrc"
link_dotfile "$DOTFILES_DIR/.bash_profile"         "$HOME/.bash_profile"

# ── tmux plugins ──────────────────────────────────────────────────────
# Cloned at pinned commits rather than at HEAD, so a fresh machine gets the
# same versions this configuration was written against.
clone_pinned() {
  local repo="$1" dest="$2" commit="$3" name="$4"

  if [[ -d "$dest/.git" ]]; then
    printf '%s is already installed (%s)\n' "$name" "$(git -C "$dest" rev-parse --short HEAD)"
    return
  fi

  mkdir -p "$(dirname "$dest")"
  git clone "$repo" "$dest"
  git -C "$dest" checkout --quiet "$commit"
  printf 'Installed %s at %s\n' "$name" "$commit"
}

log "Installing tmux plugins"
clone_pinned https://github.com/tmux-plugins/tpm "$HOME/.tmux/plugins/tpm" \
  "$TPM_COMMIT" "TPM"
clone_pinned https://github.com/catppuccin/tmux "$HOME/.tmux/plugins/tmux" \
  "$CATPPUCCIN_TMUX_COMMIT" "catppuccin/tmux"

# Non-interactive equivalent of `prefix + I`; picks up anything else declared
# in .tmux.conf that is not pinned above.
if [[ -x "$HOME/.tmux/plugins/tpm/bin/install_plugins" ]]; then
  "$HOME/.tmux/plugins/tpm/bin/install_plugins" || \
    printf 'TPM install_plugins reported an error; run prefix + I inside tmux.\n' >&2
fi

# ── Neovim plugins ────────────────────────────────────────────────────
# `restore` installs exactly the commits in lazy-lock.json. `sync` would
# pull newer upstream commits and defeat the point of committing the lockfile.
log "Restoring Neovim plugins from lazy-lock.json"
nvim --headless '+Lazy! restore' +qa

cat <<'MSG'

Bootstrap complete.

Next steps:
  1. Open a new shell (or `exec bash -l`) to pick up .bashrc.
  2. Start tmux; the Catppuccin status bar should appear at the top.
  3. Open Neovim and run :checkhealth.

Not handled automatically (see README.md):
  - /etc/wsl.conf   (systemd + automount metadata)
  - .gitconfig      (gh credential helper -- run `gh auth login`)
  - Windows Terminal profile and Nerd Font (see windows/)

If existing dotfiles had to be replaced, they were moved to a timestamped
~/.dotfiles-backup-* directory.
MSG
