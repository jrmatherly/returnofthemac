#!/bin/bash
#
# The `bootstrap` task of tilde/.config/mise/conf.d/50-bootstrap.toml: every
# setup step no declarative mise section covers. It runs on every
# `mise bootstrap`, so each step checks state first and warns instead of
# failing. It never uses sudo: the parts that need root run before it.

set -euo pipefail

# For a run that skipped the tools part, whose hook drops the credential
sudo -k 2> /dev/null || true

DOTFILES_DIR="${DOTFILES_DIR:-${DOTFILES:-$(cd "$(dirname "$0")/.." && pwd -P)}}"
cd "$DOTFILES_DIR"

# HOMEBREW_PREFIX so a self-check can point the script away from this Mac's tools.
# rustup is keg-only, and Hindsight's installer checks `cargo --version`: without
# its keg dir a fresh install warns that macOS needs a Rust toolchain (tilde/.zprofile adds it for shells)
prefix="${HOMEBREW_PREFIX:-/opt/homebrew}"
export PATH="$HOME/.local/bin:$prefix/bin:$prefix/sbin:$prefix/opt/rustup/bin:$PATH"

# tput fails with TERM unset (CI, a launchd job), which would abort this set -e script
tput() { command tput "$@" 2> /dev/null || true; }
c_ok="" c_changed="" c_notice="" c_fail="" c_prompt="" c_reset="" progress=""
if [ -t 1 ]; then
  progress=1
  if [ -z "${NO_COLOR:-}" ]; then
    c_ok=$(tput setaf 2) c_changed=$(tput setaf 6) c_notice=$(tput setaf 3)
    c_fail=$(tput setaf 1) c_prompt=$(tput setaf 5) c_reset=$(tput sgr0)
  fi
fi

# setup.sh names the run's log. Only an existing file is appended to: the value
# may be a placeholder, and a path that outlived its run must not be recreated
log="${DOTFILES_SETUP_LOG:-}"
{ [ -f "$log" ] && [ -w "$log" ]; } || log=/dev/null

# The "… <step>" line a terminal shows while a step runs; clear_line erases it
# before anything else prints
working() {
  [ -z "$progress" ] || printf '\r\033[2K  … %s' "$1"
}
clear_line() {
  [ -z "$progress" ] || printf '\r\033[2K'
}

# Without colour codes or cursor moves (tput's sgr0 is ESC ( B ESC [ m)
log_clean() {
  sed $'s/\033\\[[0-9;?]*[A-Za-z]//g; s/\033(B//g; s/\r//g'
}

# step <name>: the step every line and capture below belongs to
step_name="" out=""
step() {
  step_name=$1 out=""
  printf '\n== %s ==\n' "$1" >> "$log"
  working "$1"
}

# capture <cmd…>: the output lands in $out and the log, and on the terminal only
# under setup.sh --verbose; returns the command's status. Its stdin is closed: a
# prompt nobody can see would hang the run
capture() {
  local rc=0
  out=$("$@" 2>&1 < /dev/null) || rc=$?
  [ -z "$out" ] || printf '%s\n' "$out" | log_clean >> "$log"
  if [ -n "${DOTFILES_SETUP_VERBOSE:-}" ] && [ -n "$out" ]; then
    clear_line
    printf '%s\n' "$out"
  fi
  return "$rc"
}

# line <ok|changed|notice|fail|wait> <message>: "<mark> <step, padded> <message>", on the terminal and in the log
line() {
  local glyph color
  case $1 in
    ok) glyph=✔ color=$c_ok ;;
    changed) glyph=↻ color=$c_changed ;;
    notice) glyph=● color=$c_notice ;;
    fail) glyph=✖ color=$c_fail ;;
    *) glyph=› color=$c_prompt ;;
  esac
  clear_line
  printf '%s%s%s %-18s %s\n' "$color" "$glyph" "$c_reset" "$step_name" "$2"
  printf '%s %-18s %s\n' "$glyph" "$step_name" "$2" >> "$log"
}
ok() { line ok "$1"; }
changed() { line changed "$1"; }

# record_change <type> <name> <detail>: setup.sh groups ROTM_CHANGES_FILE's
# lines by type in its end summary. Types: package tool extension link mcp
# plugin skill setting file other
record_change() {
  [ ! -e "${ROTM_CHANGES_FILE:-}" ] || { printf '%s\t%s\t%s\n' "$1" "$2" "$3" >> "$ROTM_CHANGES_FILE"; } 2> /dev/null || true
}

# setup.sh lists ROTM_WARNINGS_FILE's lines at the end of its run
record_warning() {
  # An app that setup opened inherits the path after setup removed the file, and >> would make a new one
  [ ! -e "${ROTM_WARNINGS_FILE:-}" ] || { echo "$1" >> "$ROTM_WARNINGS_FILE"; } 2> /dev/null || true
}
# notice <message>: a ● line, listed again at the end under its step's name,
# which a short message ("6 lint notes") needs to make sense there
notice() {
  line notice "$1"
  record_warning "$step_name: $1"
}
warning() {
  line notice "$1"
  record_warning "$1"
}

# output_tail: the end of what the step printed ($out) and where the rest is,
# since that output is otherwise only in the log; all of it when there is no log
output_tail() {
  if [ "$log" = /dev/null ]; then
    [ -z "$out" ] || sed 's/^/    /' <<< "$out"
  else
    [ -z "$out" ] || tail -n 10 <<< "$out" | sed 's/^/    /'
    echo "    full output: ${log/#$HOME/~}"
  fi
}
# failed <message>: a warning whose step failed
failed() {
  line fail "$1"
  output_tail
  record_warning "$1"
}

command_exists() {
  command -v "$@" &> /dev/null
}

# module_on <name> <step>: false, with the step's line saying why, when that module is switched off (bin/lib/rotm-modules)
module_on() {
  "$DOTFILES_DIR/bin/lib/rotm-modules" is-on "$1" && return 0
  step_name=$2
  ok "skipped: the $1 module is off"
  return 1
}

# Make custom binary scripts executable
step 'bin scripts'
# tr: macOS wc pads the count
ok "$(find "$DOTFILES_DIR/bin" -type f -not -name '.DS_Store' -not -name '*.md' -exec chmod +x {} \; -print | wc -l | tr -d ' ') executable"

# Iosevka Code Nerd Font — VS Code's editor and terminal font (companion of the
# SpaceBox theme; no Homebrew cask). Installs it when missing and reinstalls it
# when the upstream release zip changed; unchanged costs one conditional request.
if module_on fonts 'Iosevka font'; then
  step 'Iosevka font'
  if ! capture "$DOTFILES_DIR/bin/install-iosevka-code"; then
    failed "Iosevka Code font not installed — run it later: install-iosevka-code"
  elif grep -q '^Installed Iosevka Code' <<< "$out"; then
    changed "installed into ~/Library/Fonts (restart apps to pick it up)"
    record_change file "Iosevka Code font" "installed into ~/Library/Fonts"
  else
    ok "up to date"
  fi
fi

# A prompt needs a terminal, and `./setup.sh -y` takes each default instead
asks() { [ -t 0 ] && [ -z "${DOTFILES_YES:-}" ]; }

# VS Code settings.json is rendered from vscode/User/settings.json.j2 with a
# font preset (vscode/presets.toml); a terminal gets the preset menu. It never
# overwrites edits VS Code made since the last render (drift is a warning).
if command_exists minijinja-cli; then
  step 'VS Code settings'
  # Where bin/vscode-settings writes: an installed copy renders outside the checkout
  vscode_dir="${VSCODE_SETTINGS_DIR:-$DOTFILES_DIR/vscode/User}"
  if [ -z "${VSCODE_SETTINGS_DIR:-}" ] && [ "$("$DOTFILES_DIR/bin/lib/rotm-mode" "$DOTFILES_DIR" 2> /dev/null)" = installed ]; then
    vscode_dir="$HOME/Library/Application Support/Code/User"
  fi
  vscode_before=$(cksum "$vscode_dir/settings.json" 2> /dev/null || true)
  vscode_rc=0
  # Only while no preset is saved: the menu's answer writes that file, so it
  # shows once, and `vscode-settings --choose` changes it later
  if asks && [ ! -f "${VSCODE_SETTINGS_ENV:-$HOME/.config/dotfiles/vscode.env}" ]; then
    # The menu runs uncaptured: it reads its answer from the terminal
    line wait "choose a font preset"
    "$DOTFILES_DIR/bin/vscode-settings" --choose || vscode_rc=$?
  else
    capture "$DOTFILES_DIR/bin/vscode-settings" || vscode_rc=$?
  fi
  vscode_preset=$(sed -n 's/^rendered settings.json \((preset .*)\)$/ \1/p' <<< "$out")
  # The menu ran uncaptured, so the preset is read from the file its answer wrote
  [ -n "$vscode_preset" ] || vscode_preset=$(sed -n 's/^VSCODE_FONT_PRESET=\(.*\)$/ (preset \1)/p' "${VSCODE_SETTINGS_ENV:-$HOME/.config/dotfiles/vscode.env}" 2> /dev/null || true)
  if [ "$vscode_rc" -ne 0 ]; then
    failed "VS Code settings not rendered — fix what's shown, then run: vscode-settings"
  elif [ "$vscode_before" != "$(cksum "$vscode_dir/settings.json" 2> /dev/null || true)" ]; then
    changed "rendered$vscode_preset"
    record_change setting "VS Code settings.json" "rendered$vscode_preset"
  else
    ok "unchanged$vscode_preset"
  fi
  # A preset font that is not installed
  while IFS= read -r vscode_note; do
    [ -z "$vscode_note" ] || notice "$vscode_note"
  done < <(sed -n 's/^warning: //p' <<< "$out")
else
  step_name='VS Code settings'
  warning "minijinja-cli not found, so VS Code settings weren't rendered — mise bootstrap packages apply brew:minijinja-cli, then run: vscode-settings"
fi

# GitHub CLI: setup.sh offers `gh auth login` before the packages, so a bare
# `mise bootstrap` only gets the hint.
if command_exists gh && ! gh auth status &> /dev/null; then
  step_name='GitHub CLI'
  notice "not signed in to GitHub — run: gh auth login"
fi

# setup.sh (or the tools part of a bare `mise bootstrap`) installed the
# runtimes and CLIs before this task
if command_exists mise; then
  # setup.sh --skip-codegraph sets MISE_DISABLE_TOOLS for the tool install. A
  # reshim while it is set deletes an installed CodeGraph's shim, so reshim
  # once more without it.
  if [ "${DOTFILES_SKIP_CODEGRAPH:-false}" = true ]; then
    step_name='mise shims'
    capture env -u MISE_DISABLE_TOOLS mise reshim || {
      rc=$?
      failed "mise reshim failed"
      exit "$rc"
    }
  fi
  # typescript-language-server (a Terax preset, an `npm:` tool in the config)
  # finds TypeScript in a project's node_modules or by Node resolution from its
  # own install dir, which walks up to mise's data dir. mise gives every npm
  # tool its own prefix, so link the global `npm:typescript` where that walk
  # finds it. The target path carries the exact version: sysup relinks after
  # `mise upgrade`.
  step_name='TypeScript link'
  if ! module_on apps 'TypeScript link'; then
    :
  elif ts_dir="$(mise where npm:typescript 2> /dev/null)"; then
    mkdir -p "${MISE_DATA_DIR:-$HOME/.local/share/mise}/node_modules"
    ln -sfn "$ts_dir/node_modules/typescript" "${MISE_DATA_DIR:-$HOME/.local/share/mise}/node_modules/typescript"
    ok "linked to npm:typescript"
  else
    warning "npm:typescript is not installed — typescript-language-server will only see a project's own TypeScript"
  fi
  # Make node/npm available to the rest of this script. `activate --shims` is
  # just a PATH prepend, so fall back to the shim dir if it can't be evaluated.
  if shims_env="$(mise activate bash --shims 2> /dev/null)"; then
    eval "$shims_env"
  else
    export PATH="${MISE_DATA_DIR:-$HOME/.local/share/mise}/shims:$PATH"
  fi
fi

# Rust — the rustup formula (conf.d/60-rotm-devops.toml) is the system toolchain manager. Make
# stable the default when it isn't: a proxy with no default toolchain downloads
# one on first use, which Hindsight's daemon start runs inside a 10 s
# `cargo --version` check. `rustup default` alone is a local read.
# Hindsight (agents module) needs it too, so either module keeps the step.
rustup="$prefix/opt/rustup/bin/rustup"
if [ -x "$rustup" ] && { "$DOTFILES_DIR/bin/lib/rotm-modules" is-on agents || module_on devops Rust; }; then
  step Rust
  if "$rustup" default 2> /dev/null | grep -q '^stable-'; then
    ok "stable is the default toolchain"
  elif capture "$rustup" default stable; then
    changed "stable set as the default toolchain"
    record_change tool rust "stable set as the default toolchain"
  else
    failed "rustup default stable failed — run it later"
  fi
fi

# Claude Code — Anthropic's native installer, into ~/.local/bin (zsh/path.zsh
# puts it on PATH). Only when missing: it auto-updates itself afterwards.
# https://docs.claude.com/en/docs/claude-code/setup
install_claude() { curl -fsSL https://claude.ai/install.sh | bash; }
step 'Claude Code'
if [ -x "$HOME/.local/bin/claude" ] || command_exists claude; then
  ok "already installed, it updates itself"
elif ! module_on claude 'Claude Code'; then
  :
elif capture install_claude; then
  changed "installed"
  record_change tool "Claude Code" "installed into ~/.local/bin"
else
  failed "Claude Code install failed — run it later: curl -fsSL https://claude.ai/install.sh | bash"
fi

# CodeGraph (installed by the tools part) — wire its MCP server into Claude Code:
# user-scope entry in ~/.claude.json, auto-allow permission + UserPromptSubmit
# hook in ~/.claude/settings.json, marker-fenced block in ~/.claude/CLAUDE.md.
# Idempotent. Claude Code only: the installer writes via tmp file + rename,
# which would replace the ~/.codex/AGENTS.md symlink with a regular file.
# https://github.com/colbymchenry/codegraph#2-connect-your-agents
# The agents module gates every step from here to rtk; its one "skipped" line is printed here
if module_on agents 'agent tools'; then agents_on=true; else agents_on=false; fi
step_name=CodeGraph
if ! $agents_on; then
  :
elif [ "${DOTFILES_SKIP_CODEGRAPH:-false}" = true ]; then
  ok "skipped (--skip-codegraph)"
elif command_exists codegraph; then
  step CodeGraph
  if ! capture codegraph install --yes --target claude --location global --no-color; then
    failed "codegraph install failed — run it later: codegraph install --target claude"
  # Every file it reports unchanged
  elif grep -q 'Claude Code:' <<< "$out" && ! grep 'Claude Code:' <<< "$out" | grep -qv 'Unchanged'; then
    ok "already connected"
  else
    changed "connected to Claude Code (restart it to load the server)"
    record_change setting CodeGraph "connected to Claude Code"
  fi
  # Persisted opt-out: the MCP server Claude Code spawns may not inherit
  # CODEGRAPH_TELEMETRY=0 from zsh/env.zsh (e.g. GUI-launched)
  capture codegraph telemetry off || true
else
  ok "skipped: codegraph not found"
fi

claude_bin="$(command -v claude || echo "$HOME/.local/bin/claude")"

# The registrations below sit beside the tool each belongs to, for their order;
# they report into this tally, and mcp_summary prints the one "MCP servers" line
mcp_same=0 mcp_added=0 mcp_differ=0 mcp_failed=0 mcp_fail_out=""
mcp_notes=()
# mcp_warning <message>: recorded now, printed with the summary
mcp_warning() {
  record_warning "$1"
  mcp_notes+=("$1")
}
# mcp_adding <name>: the log's heading for a registration, which runs inside another step
mcp_adding() {
  printf '\n== MCP servers: %s ==\n' "$1" >> "$log"
}
mcp_summary() {
  local total=$((mcp_same + mcp_added + mcp_differ + mcp_failed)) message note
  # Without the blank line a registration that printed nothing leaves
  step_name='MCP servers' out=$(sed '/^$/d' <<< "$mcp_fail_out")
  [ "$total" -gt 0 ] || return 0
  message="$((mcp_same + mcp_differ)) registered"
  [ "$mcp_added" -eq 0 ] || message+=", $mcp_added added"
  [ "$mcp_differ" -eq 0 ] || message+=", $mcp_differ registered differently"
  [ "$mcp_failed" -eq 0 ] || message+=", $mcp_failed failed"
  if [ "$mcp_failed" -gt 0 ]; then
    line fail "$message"
    output_tail
  elif [ "$mcp_added" -gt 0 ]; then
    changed "$message"
  elif [ "$mcp_differ" -gt 0 ]; then
    # Not notice: mcp_warning recorded each server that differs
    line notice "$message"
  else
    ok "$message"
  fi
  for note in ${mcp_notes[@]+"${mcp_notes[@]}"}; do
    line notice "$note"
  done
}

# Registers a stdio MCP server with Claude Code at user scope, once. A server
# of that name registered with the same command, args and environment is left
# alone; one that differs (a `rea setup` registration, a moved binary, a
# changed env path) gets a warning with the command to re-register, since
# `claude mcp add` refuses to overwrite and a silent keep would hide the drift.
# `claude mcp get` prints indented "Command: …", "Args: …" (bare "Args:" when
# none) and "KEY=value" lines; each is matched as a whole line.
# Usage: register_mcp <name> <label> [-e KEY=VALUE]... -- <command> [args...]
register_mcp() {
  local name="$1" label="$2" existing line i
  shift 2
  local -a env_args=()
  while [ "$1" != "--" ]; do
    env_args+=("$1" "$2")
    shift 2
  done
  shift
  working "MCP servers: $name"
  if existing=$("$claude_bin" mcp get "$name" 2> /dev/null); then
    local args="${*:2}"
    local -a expect=("Command: $1" "Args:${args:+ $args}")
    for ((i = 1; i < ${#env_args[@]}; i += 2)); do
      expect+=("${env_args[i]}")
    done
    for line in "${expect[@]}"; do
      if ! sed 's/^ *//' <<< "$existing" | grep -qxF -- "$line"; then
        mcp_warning "$label MCP server is registered differently (expected '$line') — re-register: claude mcp remove $name -s user && claude mcp add --scope user $name ${env_args[*]+"${env_args[*]}"} -- $*"
        mcp_differ=$((mcp_differ + 1))
        return 0
      fi
    done
    mcp_same=$((mcp_same + 1))
  elif mcp_adding "$name" && capture "$claude_bin" mcp add --scope user "$name" ${env_args[@]+"${env_args[@]}"} -- "$@"; then
    mcp_added=$((mcp_added + 1))
    record_change mcp "$name" "registered with Claude Code"
  else
    mcp_failed=$((mcp_failed + 1)) mcp_fail_out+="$out"$'\n'
    mcp_warning "Registering $label failed — run: claude mcp add --scope user $name ${env_args[*]+"${env_args[*]}"} -- $*"
  fi
}

# Registers a remote (HTTP) MCP server with Claude Code at user scope, once,
# and returns 0 only when this call registered it.
# Usage: register_http_mcp <name> <url>
register_http_mcp() {
  local name="$1" url="$2" existing
  working "MCP servers: $name"
  if existing=$("$claude_bin" mcp get "$name" 2> /dev/null); then
    # The whole "URL:" line, so the same URL with a query string added is drift
    if sed 's/^ *//' <<< "$existing" | grep -qxF "URL: $url"; then
      mcp_same=$((mcp_same + 1))
    else
      mcp_differ=$((mcp_differ + 1))
      mcp_warning "$name MCP server is registered with a different URL — expected $url"
    fi
    return 1
  fi
  mcp_adding "$name"
  if capture "$claude_bin" mcp add --scope user --transport http "$name" "$url"; then
    mcp_added=$((mcp_added + 1))
    record_change mcp "$name" "registered with Claude Code ($url)"
    return 0
  fi
  mcp_failed=$((mcp_failed + 1)) mcp_fail_out+="$out"$'\n'
  mcp_warning "Registering $name failed — run: claude mcp add --scope user --transport http $name $url"
  return 1
}

# mise's MCP server for Claude Code (user scope — serves whichever project
# Claude runs in): exposes tools, tasks, env and config, and can run tasks.
# Note `mise://env` shows real environment values, secrets included, to the
# agent. https://mise.jdx.dev/mcp.html
if $agents_on && command_exists mise && [ -x "$claude_bin" ]; then
  register_mcp mise mise -- "$(command -v mise)" mcp
fi

# Serena — symbol-level code tools over language servers, as an MCP server for
# Claude Code. Installed as a uv tool (its only documented install method);
# `bin/sysup` upgrades it. Launch invariants (claude-code context, one
# user-scope registration, --project-from-cwd): ~/.claude/rules/serena.md
# https://github.com/oraios/serena
serena_bin="$HOME/.local/bin/serena"
if $agents_on && command_exists uv && [ ! -x "$serena_bin" ]; then
  step Serena
  if capture uv tool install --exclude-newer "48 hours" -p 3.13 serena-agent; then
    changed "installed"
    record_change tool serena-agent "installed with uv"
  else
    failed "Serena install failed — run it later: uv tool install --exclude-newer '48 hours' -p 3.13 serena-agent"
  fi
elif $agents_on && [ -x "$serena_bin" ]; then
  step_name=Serena
  ok "already installed"
fi
if $agents_on && [ -x "$serena_bin" ] && [ -x "$claude_bin" ]; then
  register_mcp serena Serena -- serena start-mcp-server --context claude-code --project-from-cwd
fi

# Scrapling — web scraping library with an MCP server (plain, Chromium and
# stealth fetches, sessions, screenshots) and a CLI that the scrapling-official
# skill (agents/claude-skills.txt) drives. A uv tool with the `ai` extra (the
# server plus the browser fetchers; `all` only adds IPython); `bin/sysup`
# upgrades it. `scrapling install` downloads Playwright's Chromium once and is
# a no-op after. Registered by absolute path so app-launched Claude Code finds
# it without the shell's PATH. https://scrapling.readthedocs.io/en/latest/ai/mcp-server/
scrapling_bin="$HOME/.local/bin/scrapling"
scrapling_mcp_bin="$HOME/.local/bin/scrapling-mcp"
scrapling_new=false
if $agents_on && command_exists uv && [ ! -x "$scrapling_bin" ]; then
  step Scrapling
  if capture uv tool install --exclude-newer "48 hours" -p 3.13 "scrapling[ai]"; then
    scrapling_new=true
    record_change tool scrapling "installed with uv"
  else
    failed "Scrapling install failed — run it later: uv tool install --exclude-newer '48 hours' -p 3.13 'scrapling[ai]'"
  fi
fi
if $agents_on && [ -x "$scrapling_bin" ]; then
  step Scrapling
  # Playwright's browsers, to tell a download from the no-op
  scrapling_browsers() { ls "$HOME/Library/Caches/ms-playwright" 2> /dev/null || true; }
  scrapling_before=$(scrapling_browsers)
  if ! capture "$scrapling_bin" install; then
    failed "Scrapling's browser download failed — run it later: scrapling install"
  elif $scrapling_new; then
    changed "installed, with its browser"
  elif [ "$scrapling_before" != "$(scrapling_browsers)" ]; then
    changed "browser downloaded"
    record_change tool scrapling "browser downloaded"
  else
    ok "already installed, browser ready"
  fi
fi
# The entry point exists even for an install without the `ai` extra, and
# `scrapling-mcp --help` passes there (the server module is imported lazily),
# so import it from the tool's venv before registering a server that would
# die on launch
if $agents_on && [ -x "$scrapling_mcp_bin" ] && [ -x "$claude_bin" ] && command_exists uv; then
  if "$(uv tool dir)/scrapling/bin/python" -c 'import scrapling.core.ai' 2> /dev/null; then
    register_mcp scrapling Scrapling -- "$scrapling_mcp_bin"
  else
    step_name=Scrapling
    warning "scrapling-mcp can't start (installed without the ai extra?) — reinstall: uv tool install --force --exclude-newer '48 hours' -p 3.13 'scrapling[ai]'"
  fi
fi

# Browser Use — MCP server that drives Chrome over CDP (your logged-in session
# or a cloud browser). A uv tool and not the browser-use plugin: the plugin runs
# `uvx browser-use@latest`, which takes each release the hour it ships and holds
# the uv cache lock for as long as the session is open, so `sysup` cannot prune.
# Python 3.12 is the plugin's own pin. https://github.com/browser-use/browser-use
browser_use_bin="$HOME/.local/bin/browser-use"
browser_use_new=false
if $agents_on && command_exists uv && [ ! -x "$browser_use_bin" ]; then
  step 'Browser Use'
  if capture uv tool install --exclude-newer "48 hours" -p 3.12 browser-use; then
    browser_use_new=true
    record_change tool browser-use "installed with uv"
  else
    failed "Browser Use install failed — run it later: uv tool install --exclude-newer '48 hours' -p 3.12 browser-use"
  fi
fi
if $agents_on && [ -x "$browser_use_bin" ]; then
  step 'Browser Use'
  # Persisted, so a server Claude Code starts outside a shell stays opted out
  if ! capture "$browser_use_bin" telemetry disable; then
    failed "browser-use telemetry disable failed — run it later"
  elif $browser_use_new; then
    changed "installed, telemetry off"
  else
    ok "already installed, telemetry off"
  fi
fi
if $agents_on && [ -x "$browser_use_bin" ] && [ -x "$claude_bin" ]; then
  # No update check: after a failed call it tells the agent to install the newest release
  register_mcp browser-use "Browser Use" -e BROWSER_USE_NO_UPDATE_CHECK=1 -- "$browser_use_bin" --cli-mcp
fi

# Hindsight — per-repo long-term memory for Claude Code and Codex via the vendor
# installer (what it writes: setup/README.md and the spec,
# docs/superpowers/specs/completed/2026-10-24-hindsight-memory.md). Tracked snapshots stay
# clean: `claude-config save` drops `hooks`, and the [mcp_servers] block lands in
# the seeded copy ~/.codex/config.toml. It registers its MCP server with
# `claude mcp add`, hence the PATH prefix. `bin/sysup` upgrades it.
if ! $agents_on; then
  :
elif command_exists npx && command_exists uvx && command_exists jq && [ -x "$claude_bin" ]; then
  step 'Hindsight memory'
  # What init writes (bin/hindsight-memory): the config on a first install, and
  # the stamp of the lock the daemon environment was last built from. Its
  # "daemon environment updated" line is printed only when a daemon had to stop
  hindsight_cfg="${HINDSIGHT_CONFIG:-$HOME/.hindsight/coding-agent.json}"
  hindsight_stamp="${HINDSIGHT_DAEMON_ENV:-$HOME/.hindsight/daemon-env}/.synced"
  hindsight_new=true
  [ ! -f "$hindsight_cfg" ] || hindsight_new=false
  hindsight_env=$(cat "$hindsight_stamp" 2> /dev/null || true)
  if ! PATH="$(dirname "$claude_bin"):$PATH" capture "$DOTFILES_DIR/bin/hindsight-memory" init; then
    failed "Hindsight memory setup failed — run it later: hindsight-memory init"
  elif $hindsight_new && [ -f "$hindsight_cfg" ]; then
    changed "installed for Claude Code and Codex"
    record_change setting "Hindsight memory" "installed for Claude Code and Codex"
  elif [ "$hindsight_env" != "$(cat "$hindsight_stamp" 2> /dev/null || true)" ]; then
    changed "set up, daemon environment updated"
    record_change setting "Hindsight memory" "daemon environment updated"
  else
    ok "already set up"
  fi
else
  step_name='Hindsight memory'
  ok "skipped: npx, uvx, jq or claude not found"
fi

# REA — reverse-engineering MCP server (`rea-agents`, a mise npm tool) for
# Claude Code, driving the Ghidra formula and Hopper cask (conf.d/30-packages.toml). The
# registered command is bin/rea-mcp, which resolves GHIDRA_INSTALL_DIR and
# JAVA_HOME from the installed keg at every launch (the ghidra formula's openjdk@N, the
# JDK the formula's own ghidraRun wrapper uses) and execs the mise shim. The
# registration therefore holds no versioned path: a JAVA_HOME pinned here
# dangled when Ghidra 12.2 moved from openjdk@21 to @25 (2026-10-22). Hopper's
# cask path is REA's default launcher. The reverse-engineer-anything skill is
# REA's own bundled copy, installed by `rea setup --skill` into ~/.agents/skills
# and ~/.claude/skills (not the skills CLI's copy from the repo's main branch,
# which drifts from the installed server and makes `rea doctor` call it stale).
# https://github.com/morluto/rea
rea_shim="${MISE_DATA_DIR:-$HOME/.local/share/mise}/shims/rea"
if $agents_on && [ -x "$rea_shim" ]; then
  # The skills CLI linked ~/.claude/skills/<name> into ~/.agents/skills; rea setup
  # refuses to replace a link, so an older install's link goes first
  rea_link="$HOME/.claude/skills/reverse-engineer-anything"
  [ -L "$rea_link" ] && rm "$rea_link"
  mkdir -p "$HOME/.agents/skills" "$HOME/.claude/skills"
  step REA
  # The two copies rea setup writes, to tell a write from the no-op
  rea_skill() { find "$HOME/.agents/skills/reverse-engineer-anything/SKILL.md" "$HOME/.claude/skills/reverse-engineer-anything/SKILL.md" -exec cksum {} + 2> /dev/null || true; }
  rea_before=$(rea_skill)
  if ! capture "$rea_shim" setup --skill-client shared --skill-client claude_code --skill --yes --format json; then
    failed "REA skill install failed — run it later: rea setup --skill-client shared --skill-client claude_code --skill --yes"
  elif [ "$rea_before" != "$(rea_skill)" ]; then
    changed "skill written"
    record_change skill reverse-engineer-anything "written by rea setup"
  else
    ok "skill in place"
  fi
fi
if ! $agents_on; then
  :
elif [ -x "$rea_shim" ] && [ -x "$claude_bin" ] && [ -d "$prefix/opt/ghidra/libexec" ]; then
  register_mcp rea REA -- "$DOTFILES_DIR/bin/rea-mcp"
else
  step_name=REA
  ok "MCP server skipped: rea shim or the ghidra formula not found"
fi

# SnippetsLab (Mac App Store, so not a mise package): its `lab` helper gives an
# agent skill (a static copy, so sysup refreshes it; no git source, so not in
# agents/claude-skills.txt) and a stdio MCP server, registered with Claude
# Code and Codex. The server launches the app on the first tool call, not at
# the handshake (measured), so no --no-launch. Write access for create_snippet
# is the app's own setting (Settings > Integrations).
# https://www.renfei.org/snippets-lab/manual/mac/agentic-tools.html
snippetslab_lab="/Applications/SnippetsLab.app/Contents/Helpers/lab"
if $agents_on && [ -x "$snippetslab_lab" ]; then
  step SnippetsLab
  if ! capture "$DOTFILES_DIR/bin/install-snippetslab-skill"; then
    failed "SnippetsLab skill not written — run it later: install-snippetslab-skill"
  elif grep -q '^SnippetsLab skill unchanged' <<< "$out"; then
    ok "skill unchanged"
  else
    # "SnippetsLab skill written", "… updated"
    snippetslab_result=$(sed -n 's/^SnippetsLab skill //p' <<< "$out" | tail -n 1)
    changed "skill ${snippetslab_result:-written}"
    record_change skill snippetslab "${snippetslab_result:-written}"
  fi
  if [ -x "$claude_bin" ]; then
    register_mcp snippetslab SnippetsLab -- "$snippetslab_lab" mcp
  fi
  # `codex mcp get` prints "command: …" and "args: …" lines; compare them the
  # way register_mcp does for Claude Code, so a registration pasted from the
  # app's own setup (another path or args) is reported, not silently kept.
  if command_exists codex; then
    if codex_existing="$(codex mcp get snippetslab 2> /dev/null)"; then
      if grep -qF "command: $snippetslab_lab" <<< "$codex_existing" && grep -qF "args: mcp" <<< "$codex_existing"; then
        mcp_same=$((mcp_same + 1))
      else
        mcp_differ=$((mcp_differ + 1))
        mcp_warning "SnippetsLab MCP server is registered differently with Codex — re-register: codex mcp remove snippetslab && codex mcp add snippetslab -- $snippetslab_lab mcp"
      fi
    elif mcp_adding "snippetslab (Codex)" && capture codex mcp add snippetslab -- "$snippetslab_lab" mcp; then
      mcp_added=$((mcp_added + 1))
      record_change mcp snippetslab "registered with Codex"
    else
      mcp_failed=$((mcp_failed + 1)) mcp_fail_out+="$out"$'\n'
      mcp_warning "Registering SnippetsLab with Codex failed — run: codex mcp add snippetslab -- $snippetslab_lab mcp"
    fi
  fi
fi

# Remote documentation MCP servers (HTTP, nothing to install): Astro, Better
# Auth, and Sidero Labs (Talos Linux, Omni; its `siderolabs` skill comes from
# agents/claude-skills.txt via `claude-config restore` below).
# https://docs.siderolabs.com/talos/v1.14/learn-more/ai-agent-integration
if $agents_on && [ -x "$claude_bin" ]; then
  while read -r name url; do
    register_http_mcp "$name" "$url" || true
  done << 'EOF'
astro-docs https://mcp.docs.astro.build/mcp
better-auth https://mcp.better-auth.com/mcp
siderolabs-docs https://docs.siderolabs.com/mcp
EOF
fi

# rtk (a brew: package) — a Claude Code PreToolUse hook that rewrites Bash calls to
# their compact rtk form (`git status` → `rtk git status`). --hook-only: no
# RTK.md or @RTK.md line in ~/.claude/CLAUDE.md (codegraph rewrites that file).
# tilde/.claude/rules/rtk.md carries the guidance, so rtk's "No RTK.md created"
# note is false here and is filtered out; pipefail still reports rtk's own failure.
# Re-run every time because
# `claude-config` doesn't track hooks; rtk skips it when already present.
# Claude Code only: --codex would write through the ~/.codex/AGENTS.md symlink
# into agents/instructions.md. https://github.com/rtk-ai/rtk#auto-rewrite-hook
if $agents_on && command_exists rtk; then
  step rtk
  rtk_init() { rtk init -g --hook-only --auto-patch 2>&1 | { grep -v 'No RTK.md created' || true; }; }
  if ! capture rtk_init; then
    failed "rtk init failed — run it later: rtk init -g --hook-only"
  elif grep -q 'hook already present' <<< "$out"; then
    ok "hook already present"
  else
    changed "hook installed in Claude Code (restart it to load the hook)"
    record_change setting rtk "Claude Code hook installed"
  fi
fi

# It's a Plan, the owner's own tracker, on a private host that resolves only on
# his network, so it is a module of its own. Sign-in is OAuth through /mcp, so
# no secret lives here. The default URL, not ?tools=catalog: Claude Code loads
# tool definitions on demand.
if [ -x "$claude_bin" ] && module_on itsaplan 'itsaplan'; then
  if register_http_mcp itsaplan https://plan.matherly.net/api/mcp; then
    mcp_warning "Sign in once on this Mac: run /mcp in Claude Code and pick itsaplan"
  fi
fi
mcp_summary

# Supabase CLI (a brew: package) — persisted telemetry opt-out, for runs that don't
# inherit DO_NOT_TRACK from zsh/env.zsh (GUI-launched tools, scripts). The
# variable here keeps this call itself from reporting.
if command_exists supabase && module_on devops Supabase; then
  step Supabase
  if DO_NOT_TRACK=1 capture supabase telemetry disable; then
    ok "telemetry off"
  else
    failed "supabase telemetry disable failed — run it later"
  fi
fi

# PowerShell as a .NET global tool — Microsoft-supported, and uses the official
# dotnet-sdk cask. (The Homebrew `powershell` formula would pull in the
# `dotnet` formula, which takes over /opt/homebrew/bin/dotnet.) Lands in
# ~/.dotnet/tools, which tilde/.zprofile puts on PATH.
# https://learn.microsoft.com/powershell/scripting/install/install-powershell-on-macos
# Pinned to 7.6: 7.7 is built on .NET 11 and the dotnet-sdk cask is still
# .NET 10. (7.7.0 also shipped to NuGet on 2026-11-10 without its per-platform
# packages, so it could not install at all.) Lift the pin once the cask
# reaches .NET 11.
POWERSHELL_VERSION='7.6.*'
step_name=PowerShell
if ! command_exists dotnet; then
  ok "skipped: dotnet not found (install the dotnet-sdk cask first)"
elif module_on cloud PowerShell; then
  step PowerShell
  if dotnet tool list --global | grep -qi '^powershell[[:space:]]'; then
    powershell_verb=update powershell_done=updated
  else
    powershell_verb=install powershell_done=installed
  fi
  if ! capture dotnet tool "$powershell_verb" --global PowerShell --version "$POWERSHELL_VERSION"; then
    failed "PowerShell install failed; re-run: dotnet tool install --global PowerShell --version '$POWERSHELL_VERSION'"
  # "Tool 'powershell' (version '7.6.10') is already installed."
  elif grep -q 'already installed' <<< "$out"; then
    ok "$(sed -n "s/.*(version '\([^']*\)').*/\1 /p" <<< "$out" | head -n 1)already installed"
  else
    # "Tool 'powershell' (version '7.6.10') was successfully installed." or
    # "… was successfully updated from version '7.6.9' to version '7.6.10'."
    powershell_result="$powershell_done$(sed -n "s/.*(version '\([^']*\)').*/ \1/p; s/.* to version '\([^']*\)'.*/ \1/p" <<< "$out" | head -n 1)"
    changed "$powershell_result"
    record_change tool PowerShell "$powershell_result"
  fi
fi

# Aspire HTTPS dev certificate: `aspire run` in a non-interactive session
# creates it without trusting it (macOS can't show the Keychain prompt), so the
# dashboard shows TLS warnings. `aspire certs trust` creates it if missing and
# asks for the login password. The check greps the message rather than trusting
# the exit code (unverified for the untrusted case); a wording change only
# costs a redundant (idempotent) trust run.
if command_exists aspire && command_exists dotnet && module_on cloud 'Aspire certificate'; then
  step 'Aspire certificate'
  if [[ "$(dotnet dev-certs https --check --trust 2>&1)" == *'A trusted certificate was found'* ]]; then
    ok "HTTPS dev certificate already trusted"
  elif asks; then
    # Uncaptured: macOS asks for the password
    line wait "trusting the HTTPS dev certificate (macOS may ask for your password)"
    if aspire certs trust --nologo; then
      changed "HTTPS dev certificate trusted"
      record_change setting "Aspire HTTPS dev certificate" "trusted"
    else
      warning "aspire certs trust failed — run it later: aspire certs trust"
    fi
  else
    notice "HTTPS dev certificate not trusted — run: aspire certs trust"
  fi
fi

# Without npm only the npm config and the repo's dependencies are skipped;
# the Claude Code restore below still runs
if command_exists npm; then
  # Node.js global config
  step npm
  # Less verbose output
  npm config set loglevel warn
  # Disable funding messages
  npm config set fund false
  # Install exact version of packages ("1.2.3" instead of "^1.2.3" or "~1.2.3"). Keeps pinning durable
  npm config set save-exact true
  # Do not allow installing packages from Git
  npm config set allow-git none
  # Do not allow installing packages from a file
  # npm config set allow-file none
  # Do not allow installing packages from remote dependencies (URLs instead of npm registry)
  # npm config set allow-remote none
  # Only install package versions published at least 48 hours ago (npm counts whole days)
  npm config set min-release-age 2
  # (Bun: the same rules live in tilde/.bunfig.toml)

  # Global npm CLIs (serverless, @antfu/ni) are `npm:` tools in the mise config,
  # installed by the tools part. aws-cdk is a brew: package.

  # This repo's own dependencies: `prettier` (+ prettier-plugin-sh) for `pnpm
  # format`, and `avif`, which bin/optimize-image expects at node_modules/.bin
  ok "config in place"
  if command_exists pnpm; then
    step 'repo dependencies'
    if ! capture pnpm install --dir "$DOTFILES_DIR"; then
      failed "pnpm install failed; re-run: pnpm install"
    elif grep -q 'Already up to date' <<< "$out"; then
      ok "up to date"
    else
      changed "installed"
      record_change package "repo dependencies" "pnpm install changed node_modules"
    fi
  else
    step_name='repo dependencies'
    ok "skipped: pnpm not found (run 'pnpm install' later)"
  fi
else
  step_name=npm
  ok "skipped: npm not found, so no npm config and no repo dependencies"
fi

# Last, after the npm settings above (min-release-age, allow-git none) so the
# skills restore's npx runs with them: Claude Code's plugins, base settings and
# user skills from agents/claude-*
# (`claude-config save` refreshes them; restore adds what's missing, drops
# retired allow rules and never overwrites other settings), then the catalog of everything
# installed (~/.claude/catalog). claude may not be on PATH yet on a fresh Mac,
# so put its directory first for both.
# claude_state: what `claude-config restore` can add, one line each, to compare before and after
claude_state() {
  local config="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
  { jq -r '.plugins | keys[]' "$config/plugins/installed_plugins.json" 2> /dev/null || true; } | awk '{ print "plugin\t" $0 }'
  # shellcheck disable=SC2012 # skill names are plain folder names
  { ls "$config/skills" 2> /dev/null || true; } | awk '{ print "skill\t" $0 }'
  printf 'setting\t%s\n' "$(cksum "$config/settings.json" 2> /dev/null || true)"
}
if [ -x "$claude_bin" ] && module_on claude 'Claude Code config'; then
  step 'Claude Code config'
  claude_before=$(claude_state)
  restore_rc=0
  PATH="$(dirname "$claude_bin"):$PATH" capture "$DOTFILES_DIR/bin/claude-config" restore || restore_rc=$?
  restored=0
  while IFS=$'\t' read -r kind name; do
    case $kind in
      plugin | skill) record_change "$kind" "$name" "restored" ;;
      setting) record_change setting "Claude Code settings.json" "changed by the restore" ;;
      *) continue ;;
    esac
    restored=$((restored + 1))
  done < <(claude_state | grep -vxFf <(printf '%s\n' "$claude_before") || true)
  while IFS= read -r name; do
    record_change plugin "$name" "retired"
    restored=$((restored + 1))
  done < <(sed -n 's/^retired plugin //p' <<< "$out")
  if [ "$restore_rc" -ne 0 ]; then
    failed "Some of it didn't restore — re-run: claude-config restore"
  elif [ "$restored" -gt 0 ]; then
    changed "$restored restored or retired (plugins, settings, skills)"
  else
    ok "nothing to restore"
  fi
  step catalog
  catalog_rc=0
  PATH="$(dirname "$claude_bin"):$PATH" capture "$DOTFILES_DIR/bin/claude-catalog" || catalog_rc=$?
  # "wrote <paths>: 411 skills, 45 commands, 216 agents, 43 MCP servers, 74 plugins, <tokens and flags>"
  catalog_counts=$(sed -n 's/^wrote [^:]*: \(.* plugins\),.*/\1/p' <<< "$out" | head -n 1)
  # Its lint lines say what's wrong when curated.toml is out of date
  # Two kinds describe this Mac, not curated.toml, and an installed copy has no curated.toml to edit
  catalog_lint=$(grep '^ *lint:' <<< "$out" | grep -vc -e 'mcp server not registered on this machine' -e 'claude.ai skills not synced' || true)
  [ "$("$DOTFILES_DIR/bin/lib/rotm-mode" "$DOTFILES_DIR" 2> /dev/null)" != installed ] || catalog_lint=0
  if [ "$catalog_rc" -ne 0 ]; then
    failed "Catalog built with problems — fix agents/catalog/curated.toml, then run: claude-catalog"
  else
    ok "${catalog_counts:-built}"
    if [ "$catalog_lint" -gt 0 ] && [ "$log" = /dev/null ]; then
      notice "$catalog_lint lint notes (run claude-catalog to list them)"
    elif [ "$catalog_lint" -gt 0 ]; then
      notice "$catalog_lint lint notes (listed in the log)"
    fi
  fi
fi

# The menu bar app, once the packages have put it in /Applications
if module_on menubar 'menu bar app'; then
  step 'menu bar app'
  if ! capture "$DOTFILES_DIR/setup/menubar-open.sh"; then
    notice "${out:-could not open the app; open it from Applications}"
  elif [ -z "$out" ]; then
    changed "opened"
    record_change other "menu bar app" "opened"
  else
    case $out in
      # "skipped: setup opened the app before (delete <marker> to open it on the next run)"
      skipped:*) ok "${out%% (*}" ;;
      *) notice "$out" ;;
    esac
  fi
fi
