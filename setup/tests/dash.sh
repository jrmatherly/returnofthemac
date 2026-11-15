#!/bin/bash
#
# Tests setup/dash.sh against a fixture checkout with a stubbed rotm-mode and
# HOME in a temp dir, so the tracked Dash file is never written. Run by bin/lib/check.

set -u

repo="$(cd "$(dirname "$0")/../.." && pwd -P)"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
fx="$tmp/checkout"
plist="$fx/dash/Dash.dashsync/Preferences.plist"
mkdir -p "$fx/dash/Dash.dashsync" "$fx/bin/lib" "$tmp/docs"
printf '#!/bin/bash\ncat "%s"\n' "$tmp/mode" > "$fx/bin/lib/rotm-mode"
chmod +x "$fx/bin/lib/rotm-mode"
fails=0

# reset <mode>: the fixture checkout holds the tracked file again, and HOME is new
reset() {
  echo "$1" > "$tmp/mode"
  cp "$repo/dash/Dash.dashsync/Preferences.plist" "$plist"
  cp "$plist" "$tmp/plist.before"
  rm -rf "${tmp:?}/home"
  mkdir -p "$tmp/home"
}

run() {
  env -i HOME="$tmp/home" PATH=/usr/bin:/bin DOTFILES_DIR="$fx" \
    bash "$repo/setup/dash.sh" add "$tmp/docs" Notes notes > "$tmp/out" 2>&1
}

check() {
  if eval "$2"; then echo "ok   $1"; else
    echo "FAIL $1"
    cat "$tmp/out"
    fails=$((fails + 1))
  fi
}

reset clone
run
check "a clone: the docset is written to the checkout's file" "grep -q '<string>notes</string>' '$plist'"

reset installed
run
check "an installed copy: the checkout's file is unchanged" "cmp -s '$plist' '$tmp/plist.before'"
check "an installed copy: the docset is in the user's folder" "grep -q '<string>notes</string>' '$tmp/home/.local/share/rotm/dash/Dash.dashsync/Preferences.plist'"
check "an installed copy: the run names that folder as the sync folder" "grep -qF '$tmp/home/.local/share/rotm/dash' '$tmp/out'"

[ "$fails" = 0 ] || {
  echo "$fails failed" >&2
  exit 1
}
