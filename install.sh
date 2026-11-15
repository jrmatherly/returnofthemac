#!/bin/bash
#
# Install Return of the Mac on a new Mac, with no clone.
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/jrmatherly/returnofthemac/stable/install.sh | bash
#   curl -fsSL <the same URL> | bash -s -- [--ref <branch>] [--dry-run] [-h|--help] [setup.sh flags]
#
#   --ref <branch>  Follow this branch instead of stable
#   --dry-run       Show what mise would fetch and link. Installs nothing and does not run setup.sh
#   -h, --help      Show this help
#
# Every other flag goes to setup.sh (-y, --without <modules>, --dash, …).
#
# It installs the Command Line Tools and mise when they are missing, has mise
# fetch the copy and link ~/.config/mise into it, then runs setup.sh from the
# copy. docs/installation.md has the same steps by hand.
#
# License: MIT

set -euo pipefail

repo=https://github.com/jrmatherly/returnofthemac.git

# Homebrew's installer does the same: the placeholder makes softwareupdate
# list the tools, so no dialog is needed
install_clt() {
  local placeholder=/tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress label
  echo "Installing the Command Line Tools (for git). This asks for your password."
  # A subshell, so its trap removes the placeholder on Ctrl-C too
  (
    trap 'sudo rm -f "$placeholder"' EXIT
    sudo touch "$placeholder"
    label=$(softwareupdate -l 2> /dev/null | sed -n 's/^.*Label: \(Command Line Tools.*\)$/\1/p' | sort -V | tail -1)
    [ -n "$label" ] && sudo softwareupdate -i "$label" && sudo xcode-select --switch /Library/Developer/CommandLineTools
  ) || true
  xcode-select -p > /dev/null 2>&1 && return
  echo "Finish the installer window that opens. This waits for it: Ctrl-C stops the wait, and the line can be run again."
  xcode-select --install > /dev/null 2>&1 || true
  until xcode-select -p > /dev/null 2>&1; do sleep 5; done
}

# A function, so a download cut short runs nothing
main() {
  local ref=stable dry="" setup_args=()
  while [ $# -gt 0 ]; do
    case "$1" in
      --ref)
        ref=${2:?--ref needs a branch}
        shift
        ;;
      --dry-run) dry=1 ;;
      -h | --help)
        # Not read from the header: under curl | bash there is no file to read
        echo "usage: install.sh [--ref <branch>] [--dry-run] [-h|--help] [setup.sh flags]"
        echo "  --ref <branch>  Follow this branch instead of stable"
        echo "  --dry-run       Show what mise would fetch and link, and install nothing"
        echo "Every other flag goes to setup.sh: -y, --without <modules>, --dash, --skip-codegraph"
        exit 0
        ;;
      # What follows -- is setup.sh's, even a flag this script also has
      --)
        setup_args+=("$@")
        break
        ;;
      *) setup_args+=("$1") ;;
    esac
    shift
  done

  if [ "$(uname -s)" != Darwin ] || [ "$(uname -m)" != arm64 ]; then
    echo "install: this needs macOS on Apple Silicon" >&2
    exit 1
  fi

  if ! xcode-select -p > /dev/null 2>&1; then
    if [ -n "$dry" ]; then
      echo "Would install the Command Line Tools"
    else
      install_clt
    fi
  fi

  local mise="${MISE_INSTALL_PATH:-$HOME/.local/bin/mise}" had_mise=1
  if [ ! -x "$mise" ]; then
    had_mise=""
    if [ -n "$dry" ]; then
      echo "Would install mise from https://mise.run, then fetch $repo ($ref)"
      exit 0
    fi
    echo "Installing mise…"
    curl -fsSL https://mise.run | sh
  fi

  local copy="${MISE_DATA_DIR:-$HOME/.local/share/mise}/bootstrap-repo"
  # --only final-hook: fetch and link, apply nothing. setup.sh does the installing
  if ! "$mise" -E rotm-installed bootstrap ${dry:+--dry-run} --from "$repo?ref=$ref" --config-dir tilde/.config/mise --save-env --only final-hook; then
    [ -z "$had_mise" ] || echo "install: if mise did not know a flag above, it is too old: run $mise self-update, then this again" >&2
    exit 1
  fi
  [ -z "$dry" ] || exit 0

  # curl | bash leaves this script on stdin: give setup's questions the terminal
  if [ ! -t 0 ] && (: < /dev/tty) 2> /dev/null; then exec < /dev/tty; fi
  exec "$copy/setup.sh" ${setup_args[@]+"${setup_args[@]}"}
}

main "$@"
