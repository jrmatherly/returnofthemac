#!/bin/bash
#
# install.sh in a scratch HOME with mise, curl, uname, xcode-select and
# setup.sh stubbed: what it passes to mise and to setup.sh, and what it
# installs when mise is missing. Nothing is fetched or installed.

set -euo pipefail

root=$(cd "$(dirname "$0")/../.." && pwd -P)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
export HOME="$tmp/home"
log="$tmp/log"
copy="$HOME/.local/share/mise/bootstrap-repo"
mkdir -p "$tmp/bin" "$HOME/.local/bin" "$copy"

fail() {
  echo "FAIL: $1" >&2
  [ ! -f "$log" ] || cat "$log" >&2
  exit 1
}

stub() {
  printf '#!/bin/bash\n%s\n' "$2" > "$1"
  chmod +x "$1"
}
stub "$tmp/bin/uname" 'case "$1" in -s) echo "${FAKE_OS:-Darwin}" ;; -m) echo arm64 ;; esac'
# Fails until softwareupdate's stub has "installed" the tools
stub "$tmp/bin/xcode-select" "if [ \"\$1\" = -p ]; then [ ! -f '$tmp/no-clt' ]; exit; fi; echo xcode-select \"\$@\" >> '$log'; [ \"\$1\" != --install ] || { [ -z \"\${FAKE_NO_GUI:-}\" ] && rm '$tmp/no-clt'; }"
# touch and rm name the real placeholder in /tmp, so they are logged, not run
stub "$tmp/bin/sudo" "case \"\$1\" in touch | rm) echo sudo \"\$@\" >> '$log' ;; *) exec \"\$@\" ;; esac"
stub "$tmp/bin/softwareupdate" "if [ \"\$1\" = -l ]; then [ -z \"\${FAKE_NO_LABEL:-}\" ] && printf '* Label: Command Line Tools for Xcode-16.0\\n\\tTitle: x\\n* Label: Command Line Tools for Xcode-26.1\\n'; else echo softwareupdate \"\$@\" >> '$log'; rm '$tmp/no-clt'; fi"
# What https://mise.run would do: put a mise where the script looks for it
stub "$tmp/bin/curl" "echo \"echo curl \$* >> '$log'; cp '$tmp/mise' '$HOME/.local/bin/mise'\""
stub "$tmp/mise" "echo mise \"\$@\" >> '$log'; exit \${FAKE_MISE_RC:-0}"
stub "$copy/setup.sh" "echo setup \"\$@\" >> '$log'"
export PATH="$tmp/bin:/usr/bin:/bin"
unset MISE_INSTALL_PATH MISE_DATA_DIR

placeholder=/tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress
repo=$(sed -n 's/^repo=//p' "$root/install.sh")
fetch() { echo "--from $repo?ref=$1 --config-dir tilde/.config/mise --save-env --only final-hook"; }
expect() { # <name> <the log's lines>...
  local name=$1
  shift
  [ "$(cat "$log" 2> /dev/null)" = "$(printf '%s\n' "$@")" ] || fail "$name"
  rm -f "$log"
}

# The piped form, as the README has it: mise is missing, so it is installed first
bash -s -- -y --without 'security,cloud' < "$root/install.sh" > /dev/null
expect "the piped form installs mise, fetches stable and passes setup's flags" \
  "curl -fsSL https://mise.run" "mise -E rotm-installed bootstrap $(fetch stable)" "setup -y --without security,cloud"

bash "$root/install.sh" --ref main > /dev/null
expect "--ref names the branch, and an installed mise is not installed again" \
  "mise -E rotm-installed bootstrap $(fetch main)" "setup"

bash "$root/install.sh" --dry-run -y > /dev/null
expect "--dry-run reaches mise, and setup.sh does not run" \
  "mise -E rotm-installed bootstrap --dry-run $(fetch stable)"

rm "$HOME/.local/bin/mise"
bash "$root/install.sh" --dry-run | grep -q 'Would install mise' || fail "--dry-run without mise says what it would install"
[ ! -f "$log" ] || fail "--dry-run without mise ran something"
cp "$tmp/mise" "$HOME/.local/bin/mise"

bash "$root/install.sh" -y -- --dry-run --ref x > /dev/null
expect "what follows -- is setup.sh's, even this script's own flags" \
  "mise -E rotm-installed bootstrap $(fetch stable)" "setup -y -- --dry-run --ref x"

touch "$tmp/no-clt"
bash "$root/install.sh" > /dev/null
expect "missing Command Line Tools: the newest label is installed and selected, and the placeholder removed, before mise runs" \
  "sudo touch $placeholder" "softwareupdate -i Command Line Tools for Xcode-26.1" "xcode-select --switch /Library/Developer/CommandLineTools" \
  "sudo rm -f $placeholder" "mise -E rotm-installed bootstrap $(fetch stable)" "setup"

touch "$tmp/no-clt"
FAKE_NO_LABEL=1 bash "$root/install.sh" > /dev/null
expect "softwareupdate lists no tools: the installer window is opened and waited for" \
  "sudo touch $placeholder" "sudo rm -f $placeholder" "xcode-select --install" "mise -E rotm-installed bootstrap $(fetch stable)" "setup"

touch "$tmp/no-clt"
if FAKE_NO_LABEL=1 FAKE_NO_GUI=1 bash "$root/install.sh" > /dev/null 2> "$tmp/err"; then fail "no tools and no window must stop the run"; fi
grep 'Command Line Tools' "$tmp/err" > /dev/null || fail "the message when no window can open"
grep '^mise' "$log" > /dev/null && fail "mise ran without the Command Line Tools"
rm -f "$log" "$tmp/no-clt"

if bash "$root/install.sh" --ref -y > /dev/null 2>&1; then fail "--ref followed by a flag must stop"; fi
[ ! -f "$log" ] || fail "--ref followed by a flag ran something"

if FAKE_MISE_RC=1 bash "$root/install.sh" > /dev/null 2> "$tmp/err"; then fail "a failed fetch must stop the run"; fi
grep -q 'self-update' "$tmp/err" || fail "a failed fetch on an existing mise names self-update"
grep -q '^setup' "$log" && fail "setup.sh ran after a failed fetch"
rm -f "$log"

if FAKE_OS=Linux bash "$root/install.sh" > /dev/null 2> "$tmp/err"; then fail "Linux must stop"; fi
grep -q 'Apple Silicon' "$tmp/err" || fail "the platform message"
[ ! -f "$log" ] || fail "something ran on Linux"

bash "$root/install.sh" --help | grep -- '--ref <branch>' > /dev/null || fail "--help"
[ ! -f "$log" ] || fail "--help ran something"

echo "install.sh: ok"
