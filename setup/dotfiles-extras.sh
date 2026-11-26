#!/bin/bash
#
# Do what mise's [dotfiles] cannot: write ~/.gitconfig.local, warn about a
# missing GitHub public key, link the cot and code CLIs into /usr/local/bin,
# hard-link the Firefox Developer Edition files and rebuild bat's cache.
#
# - Run after `mise dotfiles apply` (setup.sh does):
#
# `setup/dotfiles-extras.sh`
#
# ---
# DOTFILES_GIT_NAME, _EMAIL, _SIGN_METHOD (ssh, gpg or none) and _SIGNINGKEY
# answer the identity prompts, read only while ~/.gitconfig.local is missing.
# Safe to repeat: sudo runs only when a link is missing and its folder is not writable.
#
# License: MIT

set -euo pipefail

DOTFILES_DIR="${DOTFILES_DIR:-$(cd "$(dirname "$0")/.." && pwd -P)}"
apps_dir="${DOTFILES_EXTRAS_APPS:-/Applications}"
bin_dir="${DOTFILES_EXTRAS_BIN:-/usr/local/bin}"

# A run outside a login shell needs mise's and the prefix's tools checked below
prefix="${HOMEBREW_PREFIX:-/opt/homebrew}"
export PATH="$HOME/.local/bin:$prefix/bin:$prefix/sbin:$PATH"

tildify() {
  printf '%s' "${1/#$HOME/~}"
}

c_ok="" c_changed="" c_notice="" c_prompt="" c_reset=""
if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
  c_ok=$'\033[32m' c_changed=$'\033[36m' c_notice=$'\033[33m' c_prompt=$'\033[35m' c_reset=$'\033[0m'
fi

# setup.sh names the run's log. Only an existing file is appended to: the value may be a placeholder
log="${DOTFILES_SETUP_LOG:-}"
{ [ -f "$log" ] && [ -w "$log" ]; } || log=/dev/null

# line <ok|changed|notice|wait> <step> <message>: the same line setup/misc.sh prints, on the terminal and in the log
line() {
  local glyph color
  case $1 in
    ok) glyph=✔ color=$c_ok ;;
    changed) glyph=↻ color=$c_changed ;;
    notice) glyph=● color=$c_notice ;;
    *) glyph=› color=$c_prompt ;;
  esac
  printf '%s%s%s %-18s %s\n' "$color" "$glyph" "$c_reset" "$2" "$3"
  printf '%s %-18s %s\n' "$glyph" "$2" "$3" >> "$log"
}

# record_change <type> <name> <detail>: for setup.sh's end summary. Types:
# package tool extension link mcp plugin skill setting file other
record_change() {
  [ ! -e "${ROTM_CHANGES_FILE:-}" ] || { printf '%s\t%s\t%s\n' "$1" "$2" "$3" >> "$ROTM_CHANGES_FILE"; } 2> /dev/null || true
}

# %b, not %s: callers wrap long prompts with \n
user() {
  printf '%s›%s %b ' "$c_prompt" "$c_reset" "$1"
}

# A free name for a backup of $1, so an earlier backup is never overwritten (or,
# for a directory, moved into)
backup_path() {
  local bak="$1.backup"
  [ -e "$bak" ] || [ -L "$bak" ] || {
    printf '%s' "$bak"
    return
  }
  bak="$bak.$(date +%Y%m%d-%H%M%S)"
  local candidate=$bak n=1
  while [ -e "$candidate" ] || [ -L "$candidate" ]; do
    candidate="$bak.$n"
    n=$((n + 1))
  done
  printf '%s' "$candidate"
}

configure_git_identity() {
  local gitconfig_local="$HOME/.gitconfig.local"

  if [ -f "$gitconfig_local" ]; then
    line ok "git identity" "$(tildify "$gitconfig_local") exists"
    return
  fi

  local name="${DOTFILES_GIT_NAME:-}"
  local email="${DOTFILES_GIT_EMAIL:-}"
  local sign_method="${DOTFILES_GIT_SIGN_METHOD:-}" # ssh | gpg | none
  local signing_key="${DOTFILES_GIT_SIGNINGKEY:-}"
  local op_sign="$apps_dir/1Password.app/Contents/MacOS/op-ssh-sign"

  if [ -t 0 ]; then
    # An earlier setup step can leave the terminal without echo or line mode
    # (seen on a new Mac: nothing typed showed and Return did nothing)
    stty sane 2> /dev/null || true
    [ -z "$name" ] && read -rp "Git user.name: " name
    [ -z "$email" ] && read -rp "Git user.email: " email

    if [ -z "$sign_method" ]; then
      user "Sign commits with [s]sh (e.g. 1Password), [g]pg, or [n]one?"
      read -rn 1 sign_choice
      echo
      case "$sign_choice" in
        s | S) sign_method="ssh" ;;
        g | G) sign_method="gpg" ;;
        *) sign_method="none" ;;
      esac
    fi

    if [ "$sign_method" = "ssh" ] && [ -z "$signing_key" ] && [ -x "$op_sign" ]; then
      read -rp "SSH public key for signing (e.g. from 1Password: 'ssh-ed25519 AAAA...'): " signing_key
    elif [ "$sign_method" = "gpg" ] && [ -z "$signing_key" ]; then
      read -rp "GPG signing key ID: " signing_key
    fi
  fi

  # Signing through a program that is not there would fail every commit and tag
  # (the 1password cask is in the apps module, which can be switched off)
  if [ "$sign_method" = "ssh" ] && [ ! -x "$op_sign" ]; then
    line notice "git identity" "1Password's op-ssh-sign is not installed, so commit signing is left off. Install 1Password, delete $(tildify "$gitconfig_local") and rerun to turn it on"
    sign_method="none"
    signing_key=""
  fi

  if [ -z "$name" ] || [ -z "$email" ]; then
    line notice "git identity" "$(tildify "$gitconfig_local") not written: no name or email — set DOTFILES_GIT_NAME/DOTFILES_GIT_EMAIL, or create it manually"
    return
  fi

  if [ "$sign_method" = ssh ]; then
    # Without this file git cannot check an SSH signature, its own included
    mkdir -p "$HOME/.config/git"
    echo "$email $signing_key" > "$HOME/.config/git/allowed_signers"
  fi

  {
    echo "[user]"
    echo "  name = $name"
    echo "  email = $email"
    [ -n "$signing_key" ] && echo "  signingKey = $signing_key"

    case "$sign_method" in
      ssh)
        echo
        echo "[gpg]"
        echo "  format = ssh"
        echo "[gpg \"ssh\"]"
        echo "  program = $op_sign"
        echo "  allowedSignersFile = ~/.config/git/allowed_signers"
        echo
        echo "[commit]"
        echo "  gpgSign = true"
        echo
        echo "[tag]"
        echo "  gpgSign = true"
        ;;
      gpg)
        echo
        echo "[commit]"
        echo "  gpgSign = true"
        echo
        echo "[tag]"
        echo "  gpgSign = true"
        ;;
      *) ;;
    esac
  } > "$gitconfig_local"

  line changed "git identity" "wrote $(tildify "$gitconfig_local")"
  record_change file "$(tildify "$gitconfig_local")" "git identity written"
}

# link_cli <name> <path under the apps dir>: a symlink, because VS Code's code
# script finds the app from its own location
link_cli() {
  local name=$1 src="$apps_dir/$2" dst="$bin_dir/$1" app=${2%%.app/*}
  local as_root=()
  if command -v "$name" > /dev/null; then
    line ok "$name CLI" "already on PATH"
    return
  fi
  if [ "$dst" -ef "$src" ]; then
    line ok "$name CLI" "already linked"
    return
  fi
  if [ ! -x "$src" ]; then
    line notice "$name CLI" "$app not installed, so no $name command"
    return
  fi
  if [ -e "$dst" ] || [ -L "$dst" ]; then
    line notice "$name CLI" "$(tildify "$dst") exists and is not the $name CLI, leaving it"
    return
  fi
  if [ ! -d "$bin_dir" ] || [ ! -w "$bin_dir" ]; then
    line wait "$name CLI" "administrator password required to link $dst"
    as_root=(sudo)
  fi
  [ -d "$bin_dir" ] || ${as_root[@]+"${as_root[@]}"} mkdir -p "$bin_dir"
  ${as_root[@]+"${as_root[@]}"} ln -s "$src" "$dst"
  line changed "$name CLI" "linked $dst"
  record_change link "$dst" "$name CLI"
}

# hard_link <src> <dst>: a pull writes a changed file as a new inode, which
# breaks the link and leaves the old text in dst, so a different dst is backed up
hard_link() {
  local src=$1 dst=$2 bak
  [ "$dst" -ef "$src" ] && return
  if [ -e "$dst" ] && ! cmp -s "$src" "$dst"; then
    bak=$(backup_path "$dst")
    mv "$dst" "$bak"
    line changed Firefox "moved $(tildify "$dst") to $(tildify "$bak")"
    record_change file "$(tildify "$dst")" "moved to $(tildify "$bak")"
  fi
  mkdir -p "$(dirname "$dst")"
  ln -f "$src" "$dst"
  line changed Firefox "linked $(tildify "$dst")"
  record_change link "$(tildify "$dst")" "Firefox Developer Edition"
  firefox_said=true
}

configure_git_identity

if [ -f "$HOME/.ssh/github_personal.pub" ]; then
  line ok "GitHub SSH key" "$(tildify "$HOME/.ssh")/github_personal.pub found"
elif [ -e "$HOME/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock" ]; then
  line notice "GitHub SSH key" "$(tildify "$HOME/.ssh")/github_personal.pub not found — GitHub SSH needs it to pick your 1Password key (see tilde/.ssh/config)"
else
  line ok "GitHub SSH key" "skipped: no 1Password SSH agent"
fi

link_cli cot CotEditor.app/Contents/SharedSupport/bin/cot
link_cli code "Visual Studio Code.app/Contents/Resources/app/bin/code"

# Only when a dev-edition profile exists (an empty path would resolve to `/`,
# which we must never write to)
ff_dev_profile_dir="$("$DOTFILES_DIR"/firefox/lib/get-firefox-dev-path)"
if [ -n "$ff_dev_profile_dir" ] && [ -d "$ff_dev_profile_dir" ]; then
  # Every user.js this repo has shipped starts with this line, so a stale copy still counts as ours
  ours() { [ "$(head -n 1 "$1")" = '/* global user_pref */' ]; }
  firefox_said=false
  for file in user.js chrome/userContent.css chrome/userChrome.css; do
    dst="$ff_dev_profile_dir/$file"
    if [ "$file" = user.js ] && [ -e "$dst" ] && [ ! "$dst" -ef "$DOTFILES_DIR/firefox/$file" ] && ! ours "$dst"; then
      line notice Firefox "$(tildify "$ff_dev_profile_dir")/user.js is your own, so the tracked preferences were not linked. They turn off Firefox Sync and password saving. Move it aside and rerun to use them."
      firefox_said=true
      continue
    fi
    hard_link "$DOTFILES_DIR/firefox/$file" "$dst"
  done
  $firefox_said || line ok Firefox "preferences and styles linked"
else
  line ok Firefox "skipped: no Firefox Developer Edition profile"
fi

# bat only sees custom themes (tilde/.config/bat/themes) after its cache is
# rebuilt, otherwise BAT_THEME (zsh/env.zsh) warns "Unknown theme"
if command -v bat &> /dev/null; then
  bat cache --build > /dev/null && line ok bat "theme cache rebuilt"
fi
