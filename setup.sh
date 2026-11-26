#!/bin/bash
#
# Set up computer environment: a wrapper around `mise bootstrap`
#
# Usage:
#   ./setup.sh [-y|--yes] [--without <modules>] [--skip-codegraph] [--dash] [--verbose] [-h|--help] [-- <mise bootstrap args>]
#
#   -y, --yes         Don't wait for confirmation, and pass --yes to mise;
#                     the VS Code font menu and the gh login question are skipped
#   --without <a,b>   Turn these modules off before installing (docs/modules.md).
#                     It is remembered: a later run leaves them off
#   --skip-codegraph  Don't install CodeGraph or wire it into Claude Code
#   --dash            Also run the optional Dash docset configuration
#   --verbose         Also show mise's own output while it runs. Without it each
#                     step prints one line and the rest goes to the run's log,
#                     private/setup-logs/<timestamp>.log. A --dry-run shows it too
#   -h, --help        Print this help and exit
#   -- <args>         Passed to `mise bootstrap`. `--skip <parts>` is added to
#                     the parts setup always skips, `--upgrade` also upgrades
#                     the packages, `--dry-run` previews and `--only` is refused
#
# Exits 0 when everything installed, and 2 when setup ran to the end but some
# packages or tools failed (listed last). Any other status means a step stopped it.
#
# License: MIT

set -euo pipefail

# Where this repo actually lives — the scripts never assume `~/dotfiles`.
# DOTFILES is what the hooks and the task in conf.d/50-bootstrap.toml read.
DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd -P)"
export DOTFILES_DIR DOTFILES="$DOTFILES_DIR"
# An installed copy is mise's own checkout: its hints name rotm, and nothing may write into it
self=./setup.sh installed=false
if [ "$("$DOTFILES_DIR/bin/lib/rotm-mode" "$DOTFILES_DIR")" = installed ]; then
  self='rotm install' installed=true
fi

# Telemetry opt-outs for the tools this run installs and invokes (dotnet tool
# install, func, pwsh, az, aspire, codegraph, rtk, claude) — zsh/env.zsh sets the same for
# everyday shells, but it isn't sourced yet on a fresh Mac. Keep the two lists
# in sync.
export FUNCTIONS_CORE_TOOLS_TELEMETRY_OPTOUT=1
export DOTNET_CLI_TELEMETRY_OPTOUT=1
export POWERSHELL_TELEMETRY_OPTOUT=1
export AZURE_CORE_COLLECT_TELEMETRY=false
export AZURE_MCP_COLLECT_TELEMETRY=false
export ASPIRE_CLI_TELEMETRY_OPTOUT=true
export ASPIRE_DASHBOARD_TELEMETRY_OPTOUT=true
export CODEGRAPH_TELEMETRY=0
export RTK_TELEMETRY_DISABLED=1
export DISABLE_ERROR_REPORTING=1

# rotm update hands over what its fetch printed, which came before this run's
# log existed. Read before any exit, a bad flag included, so the file never outlives the run
update_output=""
if [ -f "${ROTM_UPDATE_OUTPUT:-}" ]; then
  update_output=$(cat "$ROTM_UPDATE_OUTPUT") || update_output=""
  rm -f "$ROTM_UPDATE_OUTPUT"
fi

yes=""
# Also settable in the environment
skip_codegraph="${DOTFILES_SKIP_CODEGRAPH:-false}"
RUN_DASH=false
without=""
verbose=false

while [ $# -gt 0 ]; do
  case "$1" in
    -y | --yes)
      yes=true
      # Read by setup/misc.sh, which then takes each prompt's default
      export DOTFILES_YES=true
      ;;
    --skip-codegraph) skip_codegraph=true ;;
    --dash) RUN_DASH=true ;;
    --verbose) verbose=true ;;
    --without)
      [ $# -ge 2 ] || {
        echo "--without needs a list of modules" >&2
        exit 1
      }
      without="${without:+$without,}$2"
      shift
      ;;
    --without=*) without="${without:+$without,}${1#--without=}" ;;
    --skip-brew)
      echo "--skip-brew is gone: use $self -- --skip packages" >&2
      exit 1
      ;;
    -h | --help)
      # Print the header comment block (everything after the shebang)
      awk 'NR > 1 && /^#/ { sub(/^# ?/, ""); if ($0 ~ /^License:/) next; print; next } NR > 1 { exit }' "$0"
      exit 0
      ;;
    --)
      shift
      break
      ;;
    *)
      echo "Unknown option: $1 (try --help)" >&2
      exit 1
      ;;
  esac
  shift
done

# A typo stops here, before the banner, the password prompt and the mise install
modules="$DOTFILES_DIR/bin/lib/rotm-modules"
if [ -n "$without" ]; then
  IFS=, read -ra without_names <<< "$without"
  for name in "${without_names[@]}"; do
    rc=0
    "$modules" is-on "$name" || rc=$?
    [ "$rc" -ne 2 ] || exit 2
  done
fi

user_skip="" dry_run_flag="" upgrade=false
mise_args=()
while [ $# -gt 0 ]; do
  case "$1" in
    --skip)
      [ $# -ge 2 ] || {
        echo "--skip needs a list of parts" >&2
        exit 1
      }
      user_skip="${user_skip:+$user_skip,}$2"
      shift
      ;;
    --skip=*) user_skip="${user_skip:+$user_skip,}${1#--skip=}" ;;
    --only | --only=*)
      echo "--only cannot be combined with the --skip macos-defaults that setup always passes. Run it yourself: cd ~ && mise bootstrap --only <parts>" >&2
      exit 1
      ;;
    --dry-run | -n)
      dry_run_flag=--dry-run
      mise_args+=("$1")
      ;;
    --upgrade)
      upgrade=true
      mise_args+=("$1")
      ;;
    *) mise_args+=("$1") ;;
  esac
  shift
done

# macOS preferences are never part of setup (set-defaults owns them), and
# --only cannot be combined with --skip, so there is one merged list.
skip="macos-defaults${user_skip:+,$user_skip}"
run_packages=true run_dotfiles=true
case ",$user_skip," in *,packages,*) run_packages=false ;; *) skip="$skip,packages" ;; esac
case ",$user_skip," in *,dotfiles,*) run_dotfiles=false ;; esac
# setup installs the tools itself, between two bootstrap calls (below)
run_tools=true run_task=true
case ",$user_skip," in *,tools,*) run_tools=false ;; *) skip="$skip,tools" ;; esac
case ",$user_skip," in *,task,*) run_task=false ;; *) skip="$skip,task" ;; esac
run_extras=$run_dotfiles
[ -z "$dry_run_flag" ] || run_extras=false

# A dry run is a preview, so mise's plan is the output
[ -z "$dry_run_flag" ] || verbose=true
# Read by setup/misc.sh once it honours it
[ "$verbose" = false ] || export DOTFILES_SETUP_VERBOSE=1

# The run's log, private/setup-logs/<timestamp>.log (git-ignored), which
# /validate-setup reads. setup writes it itself: under macOS `script` the lines
# setup/misc.sh appends to the file were overwritten. A value already set is a
# file to append to, or a placeholder that turns the log off.
if [ -z "${DOTFILES_SETUP_LOG:-}" ]; then
  DOTFILES_SETUP_LOG="$DOTFILES_DIR/private/setup-logs/$(date +%Y%m%d-%H%M%S).log"
  { mkdir -p "${DOTFILES_SETUP_LOG%/*}" && : > "$DOTFILES_SETUP_LOG"; } 2> /dev/null || true
fi
export DOTFILES_SETUP_LOG
log=$DOTFILES_SETUP_LOG
{ [ -f "$log" ] && [ -w "$log" ]; } || log=/dev/null

# The same marks, colours and line shape as setup/misc.sh and bin/sysup
c_ok="" c_changed="" c_notice="" c_fail="" c_prompt="" c_alert="" bold="" c_reset="" progress=""
if [ -t 1 ]; then
  progress=1
  if [ -z "${NO_COLOR:-}" ] && [ "${TERM:-dumb}" != dumb ]; then
    c_ok=$'\033[32m' c_changed=$'\033[36m' c_notice=$'\033[33m' c_fail=$'\033[31m'
    c_prompt=$'\033[35m' c_alert=$'\033[91m' bold=$'\033[1m' c_reset=$'\033[0m'
  fi
fi

# The "… <step>" line a terminal shows while a step runs; clear_line erases it
working_shown=""
working() {
  [ -z "$progress" ] || {
    printf '\r\033[2K  … %s' "$1"
    working_shown=1
  }
}
clear_line() {
  [ -z "$working_shown" ] || printf '\r\033[2K'
  working_shown=""
}
log_clean() {
  sed $'s/\033\\[[0-9;?]*[A-Za-z]//g; s/\033(B//g; s/\r//g'
}
# say <text>: on the terminal and in the log
say() {
  clear_line
  printf '%s\n' "$1"
  printf '%s\n' "$1" | log_clean >> "$log"
}
title() {
  say "${bold}==> $1${c_reset}"
  say ""
}
# line <ok|changed|notice|fail|wait> <step> <message> [<mark colour>]: "<mark> <step, padded> <message>"
line() {
  local glyph color
  case $1 in
    ok) glyph=✔ color=$c_ok ;;
    changed) glyph=↻ color=$c_changed ;;
    notice) glyph=● color=$c_notice ;;
    fail) glyph=✖ color=$c_fail ;;
    *) glyph=› color=$c_prompt ;;
  esac
  say "$(printf '%s%s%s %-18s %s' "${4:-$color}" "$glyph" "$c_reset" "$2" "$3")"
}
# elapsed <seconds>: "45s", "3m 54s"
elapsed() {
  if [ "$1" -lt 60 ]; then echo "${1}s"; else echo "$(($1 / 60))m $(($1 % 60))s"; fi
}

# record_change <type> <name> <detail>: a line of the end summary's Changed
# section, which setup/misc.sh and setup/dotfiles-extras.sh (separate
# processes) append to as well. Types: package tool extension link mcp plugin
# skill setting file other
record_change() {
  { printf '%s\t%s\t%s\n' "$1" "$2" "$3" >> "$ROTM_CHANGES_FILE"; } 2> /dev/null || true
}
record_warning() {
  { echo "$1" >> "$ROTM_WARNINGS_FILE"; } 2> /dev/null || true
}
# warning <step> <message>: a notice line, listed again under Notices at the
# end, with setup/misc.sh's, so it does not scroll away
warning() {
  line notice "$1" "$2"
  record_warning "$2"
}
# failed <step> <message>: a ✖ line with the end of the step's captured output
# ($out), which is otherwise only in the log, or all of it when there is no log.
# show_log prints the log's path, once, when the run ends
failed() {
  line fail "$1" "$2"
  [ -z "${out:-}" ] || say "$(if [ "$log" = /dev/null ]; then cat; else tail -n 10; fi <<< "$out" | sed 's/^/    /')"
}
# stop <message>: a check that ends the run before it starts, on stderr and in
# the log, which /validate-setup after reads
stop() {
  clear_line
  printf '%s\n' "$1" >&2
  printf '%s\n' "$1" | log_clean >> "$log"
  exit 1
}
# show_warnings: the run's notices, each once in the order they came, in the
# end summary or, from the EXIT trap, when the run stops early. Once a run
show_warnings() {
  local warnings
  [ -z "${warnings_shown:-}" ] || return 0
  warnings_shown=true
  warnings=$(awk 'NF && !seen[$0]++' "$ROTM_WARNINGS_FILE" 2> /dev/null) || warnings=""
  [ -n "$warnings" ] || return 0
  say "${bold}Notices${c_reset}"
  say "$(awk -v x="${c_notice}●${c_reset}" '{ print "  " x " " $0 }' <<< "$warnings")"
  say ""
}
show_log() {
  [ "$log" = /dev/null ] || [ -n "${log_shown:-}" ] || say "Log: ${log/#$HOME/~}"
  log_shown=true
}
# The EXIT trap. Any exit but 0 stops the run early, Ctrl-C's 130 included
finish() {
  local rc=$?
  clear_line
  [ -z "${sudo_kept_alive:-}" ] || sudo_keepalive_stop
  if [ "$rc" != 0 ]; then
    show_warnings
    show_log
  fi
  rm -f "$ROTM_WARNINGS_FILE" "$ROTM_CHANGES_FILE"
}
ROTM_WARNINGS_FILE=$(mktemp -t rotm-warnings)
ROTM_CHANGES_FILE=$(mktemp -t rotm-changes)
export ROTM_WARNINGS_FILE ROTM_CHANGES_FILE
trap finish EXIT
# A signal bash takes with no trap of its own runs the EXIT trap with status 0, and a trap that
# returns would let the run carry on past a guarded step
trap 'exit 130' INT
trap 'exit 143' TERM

[ -z "$update_output" ] || printf '$ rotm update\n%s\n' "$update_output" | log_clean >> "$log"

# Until 2026-11-12 the config environment was named `installed`, a name a
# project's own mise.installed.toml also answers to. A copy from then still has
# it saved, and without the new name config.rotm-installed.toml is not read.
# Before every check that can stop the run: a copy left with the old name has
# its app-written targets linked into the checkout by the next mise dotfiles apply.
rc_local="$DOTFILES_DIR/tilde/.config/mise/miserc.local.toml"
if [ "$installed" = true ] && [ -z "$dry_run_flag" ] && grep -qE '^env[[:space:]]*=.*"installed"' "$rc_local" 2> /dev/null; then
  sed -i '' -E '/^env[[:space:]]*=/s/"installed"/"rotm-installed"/' "$rc_local"
  say "Renamed the saved config environment from installed to rotm-installed"
fi

# The clone itself needed git, so on a new Mac the tools are usually there
if ! xcode-select -p > /dev/null 2>&1; then
  stop "Command Line Tools missing; run: xcode-select --install, then rerun $self"
fi

# rotm update sets ROTM_UPDATE: an installed copy agreed to the links at install,
# and setup still stops when a file is in the way of one
if [ -n "${ROTM_UPDATE:-}" ]; then
  say "Updating $DOTFILES_DIR"
else
  say "${c_notice}!!! ${c_fail}WARNING${c_notice} !!!"
  say "${c_alert}This script replaces your configuration files with symlinks to this repo."
  say "${c_alert}It stops when a file is in the way of a link. Nothing is overwritten.${c_reset}"
  say "${c_notice}Repo: ${c_reset}$DOTFILES_DIR"

  if [ -z "$yes" ]; then
    if [ -t 0 ]; then
      say "${c_notice}Press Enter key to continue…${c_reset}"
      say ""
      read -r _ || true
    else
      say "${c_notice}Non-interactive shell — continuing without confirmation.${c_reset}"
      say ""
    fi
  fi
fi

# link_into_repo <link> <target>: creates the link when nothing is there.
# Returns 1 when something else is, and leaves it alone.
link_into_repo() {
  [ -e "$1" ] || [ -L "$1" ] || ln -s "$2" "$1"
  [ "$1" -ef "$2" ]
}

# Every [dotfiles] source is written ~/dotfiles/… (mise does not expand
# variables in a source, and neither does lazygit's `shellFunctionsFile`), and
# the hooks and the task fall back to it, so it must be this clone before mise runs
if ! link_into_repo "$HOME/dotfiles" "$DOTFILES_DIR"; then
  # shellcheck disable=SC2088 # display text
  stop "~/dotfiles is not a link to $DOTFILES_DIR. Move it aside and rerun $self"
fi
# mise reads the whole setup through this link. With another config there it
# would find no packages, no dotfiles and no task, and exit 0.
mkdir -p "$HOME/.config"
if ! link_into_repo "$HOME/.config/mise" "$DOTFILES_DIR/tilde/.config/mise"; then
  # shellcheck disable=SC2088 # display text
  stop "~/.config/mise is not a link to $DOTFILES_DIR/tilde/.config/mise. Move it aside (mv ~/.config/mise ~/.config/mise.backup) and rerun $self"
fi

# mise skips a module (conf.d/60-rotm-<name>.toml) only while ignored_config_paths
# in miserc.local.toml names it, so the list is written before any mise call
if [ -n "$dry_run_flag" ]; then
  say "dry run: the module list is not written"
else
  # The user's settings live in their own folder, linked from the config dir
  "$DOTFILES_DIR/bin/lib/rotm-user-layer" ensure || exit $?
  "$modules" sync ${without:+--without "$without"} 2>&1 | tee -a "$log" || exit $?
fi

# On an installed copy ~/.zshrc and ~/.gitconfig are seeded once and then the
# user's, so mise keeps a file that is already there without a word, and ours
# would never load. Stop instead, as a clone does at a file in the way of a link,
# and before the password prompt.
if [ "$installed" = true ] && [ "$run_dotfiles" = true ]; then
  for ours in tilde/.zshrc tilde/.gitconfig; do
    theirs="$HOME/${ours#tilde/}"
    if [ -f "$theirs" ] && [ ! -L "$theirs" ] && ! grep -qF "$ours" "$theirs"; then
      stop "$theirs is your own and does not load returnofthemac's. Move it aside (mv $theirs $theirs.backup) or add the lines of $DOTFILES_DIR/$ours.installed to it, then rerun $self"
    fi
  done
fi

# mise's installer puts it in ~/.local/bin, and a fresh Mac's PATH lacks both.
# The prefix is here so a code or gh installed earlier in this run is found.
prefix="${HOMEBREW_PREFIX:-/opt/homebrew}"
export PATH="$HOME/.local/bin:$prefix/bin:$prefix/sbin:$PATH"
if ! command -v mise > /dev/null; then
  title "Installing mise…"
  # Installs to ~/.local/bin/mise and checks the archive against checksums in the script
  # It asks nothing, so its output can go through tee into the log
  curl -fsSL https://mise.run | sh 2>&1 | tee -a "$log"
fi
floor=$(bash "$DOTFILES_DIR/setup/mise-floor.sh" 2>&1) || stop "$floor"

# Again now that mise exists: with a module off, sync has mise trust the module
# files, without which mise dotfiles and mise bootstrap stop at an ignored one
[ -n "$dry_run_flag" ] || "$modules" sync > /dev/null || exit $?

# Read by setup/misc.sh, which reshims without the second one
disable_codegraph() { export DOTFILES_SKIP_CODEGRAPH=true MISE_DISABLE_TOOLS="${MISE_DISABLE_TOOLS:+$MISE_DISABLE_TOOLS,}npm:@colbymchenry/codegraph"; }
[ "$skip_codegraph" != true ] || disable_codegraph

# Keep the sudo timestamp alive so app installers don't re-prompt halfway.
# `sudo -n -v` extends the credential without prompting (`sudo -n true` only
# checks it); `|| true` keeps one failure from killing the loop under `set -e`.
sudo_keepalive_start() {
  while true; do
    sudo -n -v 2> /dev/null || true
    sleep 60
    kill -0 "$$" 2> /dev/null || exit
  done &
  SUDO_KEEPALIVE_PID=$!
  sudo_kept_alive=true
}

# Stop the keep-alive and drop the cached credential (`sudo -k`), so the steps
# that follow can't use sudo without asking. Without a keep-alive mise's own
# sudo prompts may have cached one, so it is dropped either way.
sudo_keepalive_stop() {
  if [ -n "${SUDO_KEEPALIVE_PID:-}" ]; then
    kill "$SUDO_KEEPALIVE_PID" 2> /dev/null || true
    SUDO_KEEPALIVE_PID=""
    line ok sudo released
  fi
  sudo -k 2> /dev/null || true
}

# Ask for the administrator password once, for the packages, sudo_local and
# the login shell. It is dropped before the tools install.
# Without a terminal mise asks per step, and a dry run needs none.
if [ -t 0 ] && [ -z "$dry_run_flag" ]; then
  line wait sudo "the administrator password, for the packages, sudo_local and the login shell"
  sudo -v
  sudo_keepalive_start
  line ok sudo "active until the tools install"
  say ""
fi

# Every mise call below runs from here: started in the clone, mise would take
# node from the repo's .nvmrc instead of the configured versions
cd "$HOME"

# mise_run <mise args>: runs mise with its output in the log, and on the
# terminal too with --verbose, and sets out to that output without colour
# codes, for the greps below. Captured, mise sees no terminal and drops its
# colours unless forced. tee shows the output on stderr, so that is the stream
# that must be a terminal. stdin stays the caller's
[ -t 2 ] && [ -z "${NO_COLOR:-}" ] && mise_color=1 || mise_color=""
mise_run() {
  local rc=0
  printf '\n$ mise %s\n' "$*" >> "$log"
  if [ "$verbose" = true ]; then
    clear_line
    out=$(env ${mise_color:+CLICOLOR_FORCE=1} mise "$@" 2>&1 | tee /dev/stderr) || rc=$?
  else
    out=$(mise "$@" 2>&1) || rc=$?
  fi
  out=$(printf '%s' "$out" | log_clean)
  [ -z "$out" ] || printf '%s\n' "$out" >> "$log"
  return "$rc"
}

# Linked before any package: packages write into $HOME (the git-credential-manager
# pkg writes ~/.gitconfig, `code` creates Code/User), and a real file where a
# link belongs stops the apply. mise bootstrap's own dotfiles part then finds
# nothing left to do.
if [ "$run_dotfiles" = true ]; then
  title "🔗 Linking the dotfiles…"
  # A folder that config.rotm-installed.toml makes real may still be a link from before
  # that entry arrived. mise keeps such a link and writes the folder's entries
  # through it, into the checkout (probe 14), so the link goes first.
  if [ "$installed" = true ] && [ -z "$dry_run_flag" ]; then
    while IFS= read -r key; do
      path="$HOME/${key#\~/}"
      [ -L "$path" ] || continue
      case "$(cd "$path" 2> /dev/null && pwd -P)" in
        "$DOTFILES_DIR"/*)
          rm "$path"
          line changed links "Unlinked $path: it is a real folder on an installed copy"
          record_change link "$path" "unlinked: a real folder on an installed copy"
          ;;
      esac
    done < <(sed -n 's/^"\([^"]*\)" = { permissions = .*/\1/p' "$DOTFILES_DIR/tilde/.config/mise/config.rotm-installed.toml" 2> /dev/null)
  fi
  # What the apply is about to write, for the summary: mise's own lines go to the log
  pending=""
  [ -n "$dry_run_flag" ] || pending=$(mise dotfiles status --json 2> /dev/null \
    | jq -r '(.files // [])[], (.edits // [])[] | select(.state == "missing" or .state == "differs") | .target // .path' 2> /dev/null) || pending=""
  working links
  # --yes: the Enter prompt above was the confirmation, and mise asks per file otherwise
  if ! mise_run dotfiles apply --yes ${dry_run_flag:+"$dry_run_flag"}; then
    failed links "mise dotfiles apply stopped. Move aside what it reported, then rerun $self"
    exit 1
  fi
  if [ -n "$dry_run_flag" ]; then
    line ok links "dry run: nothing linked"
  elif [ -n "$pending" ]; then
    line changed links "$(grep -c . <<< "$pending") applied"
    while IFS= read -r target; do record_change link "$target" applied; done <<< "$pending"
  elif grep -qvE '^(mise )?(files|edits): all (files|edits) are applied$|^$' <<< "$out"; then
    line changed links "$(tail -n 1 <<< "$out" | sed 's/^mise //')"
    record_change link dotfiles "$(tail -n 1 <<< "$out" | sed 's/^mise //')"
  else
    line ok links "all files applied"
  fi
  say ""
fi

# What the run carried on past, listed at the end: one "kind<TAB>name<TAB>reason"
# line each (bash 3.2 has no associative arrays)
problems=""
# problem <kind> <name> [<mise output>]: the reason is mise's own `failed:` or
# ERROR text, and stays empty when mise printed none
problem() {
  local reason
  reason=$(grep -E 'failed: |ERROR ' <<< "${3:-}" | grep -vE 'ERROR +(Version:|Run with)' | tail -1 | sed -E 's/.*(failed: |ERROR +)//' | cut -c1-100) || reason=""
  problems+="$1"$'\t'"$2"$'\t'"$reason"$'\n'
}

# pkg_lines <manager>: "state<TAB>package<TAB>version" per package, from
# `mise bootstrap packages status --json` on stdin
pkg_lines() {
  jq -r --arg m "$1" '.[$m].packages[]? | "\(.state)\t\(.package)\t\(.installed_version // "")"' 2> /dev/null || true
}
pkg_status() {
  mise bootstrap packages status --json 2>> "$log" || true
}
# tool_lines: the same shape for every installed version of a mise tool
tool_lines() {
  mise ls --installed --json 2> /dev/null | jq -r 'to_entries[] | .key as $k | .value[] | "installed\t\($k)@\(.version)\t"' 2> /dev/null || true
}
# changes_between <before> <after>: "installed<TAB>name<TAB>version" for a name
# installed only after, "upgraded<TAB>name<TAB>old → new" for one at another version
changes_between() {
  awk -F'\t' '
    NR == FNR { if ($1 == "installed") was[$2] = $3; next }
    $1 != "installed" { next }
    !($2 in was) { print "installed\t" $2 "\t" $3; next }
    was[$2] != $3 { print "upgraded\t" $2 "\t" was[$2] " → " $3 }
  ' <(printf '%s\n' "$1") <(printf '%s\n' "$2")
}
# report_changes <step> <type> <changes> [<installed now>]: the step's one
# line, with its counts, and a change record per line of changes_between
report_changes() {
  local n_new n_up rest msg="" verb name detail
  n_new=$(grep -c '^installed' <<< "$3" || true)
  n_up=$(grep -c '^upgraded' <<< "$3" || true)
  [ "$n_new" -eq 0 ] || msg="$n_new installed"
  [ "$n_up" -eq 0 ] || msg="${msg:+$msg, }$n_up upgraded"
  rest=$((${4:-0} - n_new - n_up))
  [ "$rest" -le 0 ] || msg="${msg:+$msg, }$rest already installed"
  if [ $((n_new + n_up)) -gt 0 ]; then line changed "$1" "$msg"; else line ok "$1" "${msg:-applied}"; fi
  while IFS=$'\t' read -r verb name detail; do
    [ -z "$verb" ] || record_change "$2" "$name" "$verb${detail:+ $detail}"
  done <<< "$3"
}

# The full install measured about 32 GB; a full disk is the likeliest mid-run
# failure. A green ✔ at 20 GiB or more; under 20 a notice, amber, and red under 10
free_space() {
  local kb gib color=$c_notice
  kb=$(df -k / 2> /dev/null | awk 'NR == 2 { print $4 }') || kb=""
  case $kb in '' | *[!0-9]*) return 0 ;; esac
  gib=$((kb / 1048576))
  say ""
  if [ "$gib" -ge 20 ]; then
    line ok "free space" "$c_ok$gib GiB$c_reset free on /"
  else
    [ "$gib" -ge 10 ] || color=$c_fail
    line notice "free space" "$color$gib GiB$c_reset free on /" "$color"
    record_warning "Only $gib GiB free on /: the full install measured about 32 GB"
  fi
  say ""
}

# packages_for <manager> <noun> <kind> <type>: setup applies the packages itself, because
# mise bootstrap stops at the first part that fails and one failed cask would
# skip the dotfiles, the login shell and the tools. A failed package warns and
# the run goes on, but "no packages requested" means mise read no package list.
# What it installed or upgraded is the difference between mise's package status
# before and after, since the status names each package and mise's lines do not
# have to be parsed: before is pkg_json, read once for every manager (it takes
# about 3 seconds), and after is read only when something could have changed.
packages_for() {
  local out before after changes="" reread=false bad=false
  title "🫖 Installing $2 with mise…"
  before=$(pkg_lines "$1" <<< "$pkg_json")
  working "$2"
  if ! mise_run bootstrap packages apply --yes --manager "$1" ${dry_run_flag:+"$dry_run_flag"}; then
    reread=true
    if grep -q 'no packages requested' <<< "$out"; then
      failed "$2" "mise read no package list from $HOME/.config/mise"
      exit 1
    fi
    # mise stops at the first package that fails, so each one after it gets its own apply
    local states missing pkg
    states=$(pkg_status | pkg_lines "$1")
    missing=$(awk -F'\t' '$1 == "missing" { print $2 }' <<< "$states")
    if [ -n "$missing" ]; then
      :
    elif grep -q '^unexpectedly_installed' <<< "$states"; then
      # With --manager mise fails an installed package that a local config declares { state = "absent" }.
      # Nothing is missing, so that choice is not a problem
      line ok "$2" "Nothing is missing: mise stopped at $2 that are installed and declared absent, and they stay as they are"
    else
      bad=true
      failed "$2" "Some $2 failed to install. See the output below, then rerun $self"
      problem "$3" "some $2" "$out"
    fi
    for pkg in $missing; do
      working "$2: $pkg"
      if ! mise_run bootstrap packages apply --yes ${dry_run_flag:+"$dry_run_flag"} "$1:$pkg"; then
        bad=true
        failed "$2" "$1:$pkg failed to install. See the output below, then rerun $self"
        problem "$3" "$pkg" "$out"
      fi
    done
  fi
  # mise's own --upgrade upgrades packages only in the part setup skips
  if [ "$upgrade" = true ]; then
    reread=true
    working "$2: upgrading"
    if ! mise_run bootstrap packages upgrade --yes --manager "$1" ${dry_run_flag:+"$dry_run_flag"}; then
      bad=true
      failed "$2" "Some $2 failed to upgrade. See the output below, then rerun $self -- --upgrade"
      problem upgrade "$2" "$out"
    fi
  fi
  if [ -n "$dry_run_flag" ]; then
    line ok "$2" "dry run: nothing installed"
  else
    after=$before
    if [ "$reread" = true ] || grep -qv '^installed' <<< "$before"; then
      working "$2"
      after=$(pkg_status | pkg_lines "$1")
    fi
    # Without the status read before the first manager there is nothing to compare with
    [ -z "$pkg_json" ] || changes=$(changes_between "$before" "$after")
    # After a ✖ line, a line only for what did install
    [ "$bad" = true ] && [ -z "$changes" ] || report_changes "$2" "$4" "$changes" "$(grep -c '^installed' <<< "$after" || true)"
  fi
  free_space
}

# The git-credential-manager pkg registers itself with `git config --global`,
# and ~/.gitconfig is a link to the tracked file, so its sections move to the
# local include. A value the local file already has is not added twice.
move_credential_config() {
  local tracked="$DOTFILES_DIR/tilde/.gitconfig" local_file="$HOME/.gitconfig.local" entry key value
  git config --file "$tracked" --get-regexp '^credential\.' > /dev/null 2>&1 || return 0
  # --null prints key, newline, value, NUL: the first helper value is empty
  while IFS= read -r -d '' entry; do
    key=${entry%%$'\n'*} value=${entry#*$'\n'}
    git config --file "$local_file" --get-all "$key" 2> /dev/null | grep -qxF -- "$value" \
      || git config --file "$local_file" --add "$key" "$value" || return 1
  done < <(git config --file "$tracked" --null --get-regexp '^credential\.')
  git config --file "$tracked" --name-only --get-regexp '^credential\.' | sed 's/\.[^.]*$//' | sort -u \
    | while IFS= read -r key; do git config --file "$tracked" --remove-section "$key"; done
  line changed "git credentials" "moved the [credential] sections a package wrote into ~/.gitconfig to ~/.gitconfig.local"
  record_change setting "git credentials" "moved from ~/.gitconfig to ~/.gitconfig.local"
}

# mise asks gh for a token itself ([settings.github] in config.toml), so none is
# exported here for every build and hook to inherit
github_token() { [ -n "${MISE_GITHUB_TOKEN:-}" ] || gh auth token > /dev/null 2>&1; }

# The login comes before the package lists and the tools, which are what spend
# the anonymous limit: a rerun in the same hour as the install ran out of it.
# gh is installed alone for that. A run that cannot ask keeps the warning.
github_login() {
  github_token && return 0
  if [ "$run_packages" = true ] && [ -t 0 ] && [ -z "$yes" ] && [ -z "$dry_run_flag" ]; then
    title "🔑 GitHub login…"
    if ! command -v gh > /dev/null; then
      working "GitHub login"
      mise_run bootstrap packages apply --yes brew:gh || true
      if command -v gh > /dev/null; then
        line changed "GitHub login" "installed gh"
        record_change package gh "installed for the GitHub login"
      fi
    fi
    if command -v gh > /dev/null; then
      line notice "GitHub login" "Without a GitHub login, GitHub allows 60 API calls an hour, and this install uses them"
      # A failed read (end of input) skips, as Ctrl-C at the login would end the whole run
      read -rp "Sign in to GitHub now (gh auth login)? [Y/n] " gh_login || gh_login=n
      case "$gh_login" in
        n* | N*) ;;
        *) gh auth login || line notice "GitHub login" "gh auth login failed or was cancelled. Run it later." ;;
      esac
    fi
    say ""
  fi
  if ! github_token; then
    warning "GitHub login" "No GitHub token: tap formulae use the anonymous API limit (60 calls an hour). If packages fail to resolve, run gh auth login and rerun $self"
    say ""
  fi
}

# The pre-packages hook does this for a bare `mise bootstrap`. Before the login,
# whose apply of gh reads a config that declares vscode: keys
if [ "$run_packages" = true ] && [ -z "$dry_run_flag" ]; then
  mise_run plugins link --force vscode "$DOTFILES_DIR/mise-plugins/vscode" || {
    rc=$?
    failed "mise plugins" "could not link the vscode plugin"
    exit "$rc"
  }
fi
github_login

# The settings a user saved with `rotm settings sync on` load before the package lists. This is
# `sync on`'s lookup in bash, because bin/dotfiles-settings needs uv, which the package lists install
restored=false
load_saved_settings() {
  local origin login repo answer folder aside=""
  [ -z "$dry_run_flag" ] && github_token || return 0
  origin=$(mise dot origin 2>&1) || true
  case "$origin" in
    *"no setup repository is connected"*) ;;
    *)
      # A run that stopped between the restore and the apply leaves the origin connected and nothing applied
      [ -e "${XDG_STATE_HOME:-$HOME/.local/state}/rotm/effective.applied.json" ] || restored=true
      return 0
      ;;
  esac
  login=$(gh api user --jq .login 2> /dev/null) && [ -n "$login" ] || return 0
  repo="$login/rotm-settings"
  [ "$(gh repo view "$repo" --json isEmpty --jq .isEmpty 2> /dev/null)" = false ] \
    && [ "$(gh repo view "$repo" --json visibility --jq .visibility 2> /dev/null)" = PRIVATE ] \
    && gh api "repos/$repo/contents/.mise-history/format.toml" > /dev/null 2>&1 || return 0
  if [ ! -t 0 ] || [ -n "$yes" ]; then
    line notice "saved settings" "Your saved settings are in $repo. Run \`rotm settings sync on\` after setup to load them."
    return 0
  fi
  folder=$("$DOTFILES_DIR/bin/lib/rotm-user-layer" dir)
  # Settings already in the folder make the load conflict, so there the default is no
  if [ -n "$(find "$folder" -maxdepth 1 -type f ! -name modules-off.local ! -name .DS_Store 2> /dev/null | head -1)" ]; then
    read -rp "This Mac already holds settings in $folder, so loading can conflict. Load your saved settings from $repo anyway? [y/N] " answer || answer=n
    case "$answer" in y* | Y*) ;; *) return 0 ;; esac
  else
    read -rp "Load your saved settings from $repo before installing? [Y/n] " answer || answer=n
    case "$answer" in n* | N*) return 0 ;; esac
  fi
  # This run's --without wrote the list already: set aside, it would conflict with the saved one
  if [ -n "$without" ] && [ -e "$folder/modules-off.local" ]; then
    aside=$(mktemp)
    mv "$folder/modules-off.local" "$aside"
  fi
  if "$DOTFILES_DIR/bin/lib/rotm-user-layer" restore "https://github.com/$repo.git"; then
    restored=true
    line changed "saved settings" "Loaded your saved settings from $repo."
    record_change setting "saved settings" "loaded from $repo"
  else
    warning "saved settings" "Your saved settings did not load, and setup carries on without them. Run rotm settings sync status to see why"
    [ -z "$aside" ] || [ -e "$folder/modules-off.local" ] || mv "$aside" "$folder/modules-off.local"
  fi
  [ -z "$aside" ] || rm -f "$aside"
  # The flag wins over the saved list, and a module switched off there is off before the packages
  "$modules" sync ${without:+--without "$without"} || exit $?
  # skip_codegraph was read before the restore
  if [ "$restored" = true ] && [ "$skip_codegraph" != true ] \
    && [ "$(mise env --json | /usr/bin/jq -r '.DOTFILES_SKIP_CODEGRAPH // empty')" = true ]; then
    disable_codegraph
  fi
  say ""
}
load_saved_settings

pkg_json=""
if [ "$run_packages" = true ]; then
  [ -n "$dry_run_flag" ] || pkg_json=$(pkg_status)
  # Formulae first: reading the claude-multipass-app tap cask needs the Ruby 3 that brew:ruby installs
  packages_for brew formulae formula package
  packages_for brew-cask casks cask package
fi

# What mise 2026.11.12 prints for a part with nothing to apply, in a dry run and
# in a real one (bin/lib/test-bootstrap holds both as it printed them). A part
# with something to apply prints its commands bare in a dry run ("ln -sf …",
# "chsh -s …") and its own words in a real one, so every other line counts as pending
settled='^mise (system files: already converged|files: all files are applied|edits: all edits are applied|login_shell: already set to .*)$'
# bootstrap_settled <mise bootstrap output>: true only when there is output and
# every line is a part's heading or one of those. A line it does not know is not "nothing to do"
bootstrap_settled() {
  [ -n "$1" ] && ! grep -qvE "^mise bootstrap: |$settled" <<< "$1"
}
# bootstrap_parts: "part<TAB>pending|same<TAB>last message" per part, from
# `mise bootstrap` output on stdin ("mise bootstrap: <part>", then the part's lines)
bootstrap_parts() {
  awk -v settled="$settled" '
    /^mise bootstrap: / {
      part = substr($0, 17)
      if (!(part in state)) { order[++n] = part; state[part] = "same" }
      next
    }
    # "bootstrap: follow-up if applied" closes the last part
    /^bootstrap: / { part = "" }
    # A warning says nothing about the part
    part == "" || /^mise +WARN / { next }
    {
      msg = $0; sub(/^mise [^:]*: /, "", msg); sub(/^ +/, "", msg); last[part] = msg
      if ($0 !~ settled) state[part] = "pending"
    }
    END { for (i = 1; i <= n; i++) if (last[order[i]] != "") print order[i] "\t" state[order[i]] "\t" last[order[i]] }'
}
# part_type <part>: the change record's type
part_type() {
  case $1 in dotfiles) echo link ;; 'login shell') echo setting ;; *) echo file ;; esac
}
# report_bootstrap <parts>: one line when every part was already applied, or a line per part
report_bootstrap() {
  local part state msg n
  if ! grep -q $'\tpending\t' <<< "$1"; then
    n=$(grep -c . <<< "$1" || true)
    if [ "$n" -gt 0 ]; then line ok "mise bootstrap" "$n parts already applied"; else line ok "mise bootstrap" "nothing to apply"; fi
    return 0
  fi
  while IFS=$'\t' read -r part state msg; do
    if [ "$state" = pending ]; then
      line changed "$part" "$msg"
      record_change "$(part_type "$part")" "$part" "$msg"
    else
      line ok "$part" "$msg"
    fi
  done <<< "$1"
}
# report_applied <parts before> <parts after>: for a run mise made on the
# terminal, where the owner may have said no. A part is reported as changed only
# when it was pending before and mise now finds nothing to do in it
report_applied() {
  local part state msg now rows
  rows=$(awk -F'\t' 'NF && !seen[$1]++' <<< "$1"$'\n'"$2")
  if [ -z "$rows" ]; then
    line ok "mise bootstrap" "ran on the terminal"
    return 0
  fi
  if ! grep -q $'\tpending\t' <<< "$rows"$'\n'"$2"; then
    report_bootstrap "$rows"
    return 0
  fi
  while IFS=$'\t' read -r part state msg; do
    now=$(awk -F'\t' -v p="$part" '$1 == p { print $2 }' <<< "$2")
    if [ "$now" = pending ]; then
      line notice "$part" "not applied: mise still has it to do. Rerun $self to apply it"
      record_warning "mise bootstrap did not apply the $part part (declined or skipped). Rerun $self to apply it"
    elif [ "$state" = same ]; then
      line ok "$part" "$msg"
    elif [ "$now" = same ]; then
      line changed "$part" applied
      record_change "$(part_type "$part")" "$part" applied
    else
      line notice "$part" "could not check whether it applied: see mise's lines above"
      record_warning "mise bootstrap: could not check whether the $part part applied"
    fi
  done <<< "$rows"
}
bootstrap_stopped() {
  failed "mise bootstrap" "mise bootstrap stopped. Earlier steps stay applied. Fix what it reported, then rerun $self"
  exit "$1"
}

title "🚀 Running mise bootstrap…"
boot_args=(${yes:+--yes} --skip "$skip" ${mise_args[@]+"${mise_args[@]}"})
# boot_plan: what mise would apply, read with a dry run; fails when mise does (pipefail)
boot_plan() {
  mise bootstrap "${boot_args[@]}" --dry-run 2>&1 < /dev/null | log_clean
}
# mise asks before it applies a change only while its stderr is a terminal, and
# applies it unasked when captured (measured on 2026.11.12 for a system file
# and a dotfile). So where mise can ask, its output is captured
# only when a dry run shows nothing to apply. Anything else (a line the test
# above does not know, a dry run that failed or printed nothing) leaves mise on
# the terminal, with nothing between the two, --verbose included
plan="" boot_on_terminal=false
if [ -z "$yes" ] && [ -z "$dry_run_flag" ] && [ -t 2 ]; then
  working "mise bootstrap"
  plan=$(boot_plan) && bootstrap_settled "$plan" || boot_on_terminal=true
fi
if [ "$boot_on_terminal" = true ]; then
  clear_line
  printf '\n$ mise bootstrap %s\n(on the terminal, where mise asks before it applies. Its dry run first:)\n%s\n' "${boot_args[*]}" "$plan" >> "$log"
  out=""
  mise bootstrap "${boot_args[@]}" || bootstrap_stopped $?
  # mise exits 0 when the owner says no, so what it applied is read, not assumed
  after=$(boot_plan) || true
  printf '(its dry run afterwards:)\n%s\n' "$after" >> "$log"
  report_applied "$(bootstrap_parts <<< "$plan")" "$(bootstrap_parts <<< "$after")"
else
  working "mise bootstrap"
  mise_run bootstrap "${boot_args[@]}" || bootstrap_stopped $?
  if [ -n "$dry_run_flag" ]; then
    line ok "mise bootstrap" "dry run: nothing applied"
  else
    report_bootstrap "$(bootstrap_parts <<< "$out")"
  fi
fi
sudo_keepalive_stop
say ""

# Not mise's tools part, which stops the whole bootstrap at a failed tool.
# mise install carries on past one and exits 1, and the task needs the rest.
if [ "$run_tools" = true ]; then
  title "🧰 Installing the mise tools…"
  before=$(tool_lines) bad=false
  working tools
  if ! mise_run install --yes ${dry_run_flag:+"$dry_run_flag"}; then
    missing=$(mise ls --missing --json | jq -r 'keys[]') || missing=""
    [ -n "$missing" ] || problem tool "mise install" "$out"
    for tool in $missing; do
      problem tool "$tool" "$(grep -F " $tool@" <<< "$out")"
    done
    bad=true
    failed tools "Not installed: $(echo ${missing:-some tools}). See the output below, then rerun $self"
  fi
  already=$(grep -oE '[0-9]+ already installed' <<< "$out" | tail -n 1 | cut -d' ' -f1) || already=""
  # What mise's --upgrade did in the tools part
  if [ "$upgrade" = true ]; then
    working "tools: upgrading"
    if ! mise_run upgrade --yes ${dry_run_flag:+"$dry_run_flag"}; then
      bad=true
      failed tools "mise upgrade failed. See the output below, then rerun $self -- --upgrade"
      problem upgrade tools "$out"
    fi
  fi
  if [ -n "$dry_run_flag" ]; then
    line ok tools "dry run: nothing installed"
  else
    changes=$(changes_between "$before" "$(tool_lines)")
    [ "$bad" = true ] && [ -z "$changes" ] || report_changes tools tool "$changes" "${already:+$((already + $(grep -c . <<< "$changes" || true)))}"
  fi
  say ""
fi

if [ "$run_task" = true ]; then
  title "🧩 Running the setup steps…"
  # The task prints its own lines and may ask, so it keeps the terminal. -q
  # drops mise's two lines about running it, and is not passed on to the task
  task_args=(${yes:+--yes} --only task ${mise_args[@]+"${mise_args[@]}"})
  [ "$verbose" = true ] || task_args+=(-q)
  printf '\n$ mise bootstrap %s\n' "${task_args[*]}" >> "$log"
  out=""
  mise bootstrap "${task_args[@]}" || bootstrap_stopped $?
  say ""
fi

if [ "$run_packages" = true ]; then
  # The VS Code cask may have arrived in this run, without code on PATH yet
  # The cask is in the base and every extension in the module, so with it off
  # mise has no vscode package and --manager vscode is its fatal "no packages requested"
  if ! "$modules" is-on vscode; then
    title "🫖 Installing extensions with mise…"
    line ok extensions "skipped: the vscode module is off"
    say ""
  elif command -v code > /dev/null; then
    packages_for vscode extensions extension extension
  else
    title "🫖 Installing extensions with mise…"
    warning extensions "VS Code is not installed yet: extensions are skipped. Rerun $self once it is"
    say ""
  fi
fi

# Never a mise hook: a post-dotfiles hook also runs on every plain
# `mise dotfiles apply`, where nobody can answer its prompts. It asks for sudo
# itself, and only to link cot or code.
if [ "$run_extras" = true ]; then
  title "🧷 Finishing the dotfiles…"
  "$DOTFILES_DIR/setup/dotfiles-extras.sh"
  # After the extras script, which writes the identity only while ~/.gitconfig.local is missing
  [ "$run_packages" = false ] || move_credential_config || warning "git credentials" "Could not move the [credential] sections out of tilde/.gitconfig. Move them to ~/.gitconfig.local by hand"
  sudo -k 2> /dev/null || true
  say ""
fi

# After the task's claude-config restore, so the saved tool settings are the last write.
# ROTM_JUST_INSTALLED: this run installed with the restored files, so apply's "run rotm install" would be false
if [ "$restored" = true ] && ! ROTM_JUST_INSTALLED=1 "$DOTFILES_DIR/bin/dotfiles-settings" sync apply; then
  warning "saved settings" "Your saved tool settings did not apply. Run rotm settings sync apply once setup is done"
  say ""
fi

# Optional: Dash docsets built from local folders
if [ "$RUN_DASH" = true ]; then
  title "🔍 Configuring Dash docsets…"
  "$DOTFILES_DIR/setup/dash.sh"
  say ""
fi

# The end summary: the totals, what changed by type, the notices, what failed, the log
changes=$(awk 'NF && !seen[$0]++' "$ROTM_CHANGES_FILE" 2> /dev/null) || changes=""
n_changed=$(grep -c . <<< "$changes" || true)
n_notices=$(awk 'NF && !seen[$0]++' "$ROTM_WARNINGS_FILE" 2> /dev/null | grep -c . || true)
n_failed=$(grep -c . <<< "$problems" || true)
tally="nothing changed"
[ "$n_changed" -eq 0 ] || tally="$n_changed changed"
[ "$n_notices" -eq 0 ] || tally+=" · $n_notices notice$([ "$n_notices" -eq 1 ] || echo s)"
[ "$n_failed" -eq 0 ] || tally+=" · $n_failed failed"
say "${bold}Done in $(elapsed "$SECONDS")${c_reset} · $tally"
say ""
if [ -n "$changes" ]; then
  say "${bold}Changed${c_reset}"
  for type in package tool extension link mcp plugin skill setting file other; do
    case $type in
      package) heading=Packages ;; tool) heading=Tools ;; extension) heading=Extensions ;; link) heading=Links ;;
      mcp) heading='MCP servers' ;; plugin) heading=Plugins ;; skill) heading=Skills ;; setting) heading=Settings ;;
      file) heading=Files ;; *) heading=Other ;;
    esac
    # A type outside the list is listed under Other, not dropped
    rows=$(awk -F'\t' -v t="$type" -v x="${c_changed}↻${c_reset}" '
      $1 == t || (t == "other" && $1 !~ /^(package|tool|extension|link|mcp|plugin|skill|setting|file)$/) {
        name[++n] = $2; detail[n] = $3
        if (length($2) > w) w = length($2)
      }
      END { for (i = 1; i <= n; i++) { l = sprintf("    %s %-*s  %s", x, w, name[i], detail[i]); sub(/ +$/, "", l); print l } }' <<< "$changes")
    [ -n "$rows" ] || continue
    say "  $heading"
    say "$rows"
  done
  say ""
fi
show_warnings
if [ -z "$problems" ]; then
  show_log
  say "🦏 ${c_ok}All done! Open a new terminal for the changes to take effect or run: source ~/.zshrc.${c_reset}"
  "$DOTFILES_DIR/bin/nyan"
  exit 0
fi

# In place of the art, so the list and the log are the last things on screen
say "${bold}Failed${c_reset}"
say "$(awk -F '\t' -v x="${c_fail}✖${c_reset}" 'NF {
    k[++n] = $1; p[n] = $2; r[n] = $3
    if (length($1) > kw) kw = length($1)
    if (length($2) > pw) pw = length($2)
  }
  END { for (i = 1; i <= n; i++) { l = sprintf("  %s %-*s   %-*s   %s", x, kw, k[i], pw, p[i], r[i]); sub(/ +$/, "", l); print l } }' <<< "$problems")"
say ""
say "  Everything else is installed. To retry: $self$([ "$upgrade" = false ] || echo ' -- --upgrade')"
case "$problems" in tool$'\t'* | *$'\n'tool$'\t'*) say "  To see why a tool failed: mise install <tool>" ;; esac
say ""
show_log
exit 2
