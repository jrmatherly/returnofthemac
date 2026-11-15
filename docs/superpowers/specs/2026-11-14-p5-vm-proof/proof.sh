#!/bin/bash
#
# Record, in the UTM guest, what the menu bar app and its commands leave behind, and compare two records.
#
# - Run one row of RUNBOOK.md (some rows run a command first, then each records):
#
# `/bin/bash "/Volumes/My Shared Files/vm-proof/p5/proof.sh" {{1a}}`
#
# - Compare two records, printing only the fields that differ:
#
# `/bin/bash "/Volumes/My Shared Files/vm-proof/p5/proof.sh" diff {{1c1}} {{1c2}}`
#
# ---
# Evidence for ../../plans/completed/2026-11-13-p5-menu-bar-app.md (Task 11 Step 3), and the
# VM proofs the P3 plan (Task 9 Step 6) and the P4 plan (Task 11 Step 3) still owe.
# Not part of the product. RUNBOOK.md beside it says what to click before each row.
# The guest runs the copy at ~/vm-proof/p5/proof.sh on the host. Run it under
# /bin/bash, only in the disposable guest, on an installed copy.
#
# A record is a folder, g<guest>/<row>/ next to this file: the raw output of
# each command, and state.json, the fields `diff` compares. Every record runs in
# the environment the app gives a command (a bare environment, the app's PATH,
# TERM=dumb). The rows that run a rotm command first (1b2, 1b6, 1c2) run it as a
# terminal user does, in the caller's environment, so a row compares the app
# with the terminal. Those rows and 1d2 (which signs gh out, so the app's console
# does the sign-in) change the guest; the rest only read. 1b7, 1d4 and 2b also
# leave a pointer in ../p4 or ../p3, the folders those plans name.
#
# P5_DOCK_SIZE (default 64) is the Dock size 1c2 sets. It exists for the test on
# a Mac, where the set must match the Mac's own value: mise reads the
# preference back, and the test's stub for `defaults write` writes nothing.
#
# License: MIT

set -u
here=$(cd "$(dirname "$0")" && pwd -P)
rotm="$HOME/dotfiles/bin/rotm"
app_path="$HOME/.local/bin:$HOME/.local/share/mise/shims:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin"
bundle="${APPLICATIONS_DIR:-/Applications}/Return of the Mac.app"
cask_url=https://raw.githubusercontent.com/jrmatherly/homebrew-tap/HEAD/Casks/returnofthemac-app.rb

# The four settings rows 1c and 1d change, one of each kind. Row 1c2 sets these
# values. From row 1d1 on, the 2026-11-14 record holds "sonnet xhigh" for
# jstack.bug_fix, the value chosen in the settings window
ids=(shell.editor macos.dock.tilesize modules.kubernetes jstack.bug_fix)
values=(vim "${P5_DOCK_SIZE:-64}" off "haiku high")

say() { printf '\nproof: %s\n' "$*"; }
die() {
  say "$*" >&2
  exit 1
}

appenv() {
  env -i HOME="$HOME" USER="${USER:-$(id -un)}" LOGNAME="${LOGNAME:-$(id -un)}" SHELL="${SHELL:-/bin/zsh}" \
    TMPDIR="${TMPDIR:-/tmp}" PATH="$app_path" TERM=dumb "$@"
}

# grab <dir> <file> <command...>: run it as the app would, from $HOME; keep stdout, stderr and the exit code
grab() {
  local d=$1 f=$2
  shift 2
  (cd "$HOME" && appenv "$@" > "$d/$f" 2> "$d/$f.err")
  echo $? > "$d/$f.exit"
}

record() {
  local d=$1 pid f
  mkdir -p "$d/files"
  date '+%Y-%m-%d %H:%M:%S %Z' > "$d/taken.txt"
  grab "$d" status.json "$rotm" settings status --json
  grab "$d" list.json "$rotm" settings list --json
  grab "$d" update.json "$rotm" update --check --json
  grab "$d" packages.json mise bootstrap packages status --json
  grab "$d" defaults.txt defaults read com.apple.dock tilesize
  grab "$d" gitcred.txt git config --global --show-origin --get-regexp '^credential'
  grab "$d" gh.txt gh auth status
  grab "$d" cask.rb curl -fsS --max-time 10 "$cask_url"
  for f in "$HOME/.config/rotm/"* "$HOME/.config/mise/miserc.local.toml"; do
    [ -f "$f" ] && cp "$f" "$d/files/"
  done
  pid=$(pgrep -x ReturnOfTheMac | head -1)
  {
    if [ -f "$bundle/Contents/Info.plist" ]; then
      echo "app_version=$(plutil -extract CFBundleShortVersionString raw "$bundle/Contents/Info.plist" 2>&1)"
    else
      echo "app_version=not installed"
    fi
    echo "app_running=$([ -n "$pid" ] && echo yes || echo no)"
    echo "app_started=$([ -n "$pid" ] && ps -o lstart= -p "$pid" | sed 's/^ *//')"
    echo "opened_by_setup=$([ -e "$HOME/Library/Logs/returnofthemac/opened-by-setup" ] && echo yes || echo no)"
    echo "booted=$(sysctl -n kern.boottime | sed 's/^{ sec = \([0-9]*\).*/\1/')"
  } > "$d/mac.txt"
  py state "$d" || die "could not build $d/state.json"
}

# Run one rotm command as a terminal user does, in this shell's environment, into the row's log
terminal() {
  printf '$ rotm %s\n' "$*" | tee -a "$log"
  (cd "$HOME" && "$rotm" "$@" < /dev/null) 2>&1 | tee -a "$log"
  echo "exit ${PIPESTATUS[0]}" | tee -a "$log"
}

set_all() {
  local i
  for i in 0 1 2 3; do terminal settings set "${ids[$i]}" -- "${values[$i]}"; done
}

reset_all() {
  local i
  for i in 0 1 2 3; do terminal settings reset "${ids[$i]}"; done
}

# compare <record> <row or row/undone>: print and keep what differs
compare() {
  local d=$1 other=$2 there
  there=$(where "$other") || return 0
  say "compared with $other:"
  py diff "$there" "$d" | tee "$d/vs-$(echo "$other" | tr / -).txt"
}

# The undo half of a terminal row: run it, record into undone/, compare with the row it should restore
undo() {
  local back=$1
  shift
  say "undoing the app's change in the terminal"
  "$@"
  record "$d/undone"
  compare "$d/undone" "$back"
}

pointer() {
  mkdir -p "$here/../$1" && printf '%s\n' "$2" > "$here/../$1/p5-run.txt"
}

where() {
  [ -f "$here/g${1:0:1}/$1/state.json" ] || die "no record $1 (expected $here/g${1:0:1}/$1/state.json)"
  echo "$here/g${1:0:1}/$1"
}

rows="1a 1b1 1b2 1b3 1b4 1b5 1b6 1b7 1c1 1c2 1c3 1d1 1d2 1d3 1d4 1f1 1f2 1f3 1f4 2a 2b 2c 3a 3b 3c 3d"

run_row() {
  local row=$1 against="" sign_out=""
  d="$here/g${row:0:1}/$row"
  log="$d/terminal.txt"
  rm -rf "$d"
  mkdir -p "$d" || die "cannot write $d"
  case "$row" in
    1b2)
      undo 1a terminal settings profile use default
      terminal settings profile use work
      against=1b1
      ;;
    1b6)
      undo 1b4 terminal settings profile use work
      terminal settings profile use default
      against=1b5
      ;;
    1b7)
      against=1a
      pointer p4 "The P4 proof ran inside the P5 run: ../p5/g1/1b1 to 1b7, RUNBOOK.md steps 9 to 15 in docs/superpowers/specs/2026-11-14-p5-vm-proof/."
      ;;
    1c2)
      undo 1b7 reset_all
      set_all
      against=1c1
      ;;
    1c3) against=1c2/undone ;;
    1d1) against=1c1 ;;
    1d2) sign_out=1 ;;
    1d3) against=1d2 ;;
    1d4)
      against=1d3
      pointer p3 "The first half of the P3 proof ran inside the P5 run: ../p5/g1/1c1 to 1d4. The second half is ../p5/g2/2a and 2b. Steps 16 to 22 and 31 to 35 of RUNBOOK.md in docs/superpowers/specs/2026-11-14-p5-vm-proof/."
      ;;
    1f2) against=1f1 ;;
    1f3) against=1f2 ;;
    1f4) against=1f3 ;;
    2a | 2b)
      against=1d4
      [ "$row" = 2a ] || pointer p3 "The P3 proof ran inside the P5 run: guest 1 is ../p5/g1/1c1 to 1d4, guest 2 is ../p5/g2/2a and 2b. Steps 16 to 22 and 31 to 35 of RUNBOOK.md in docs/superpowers/specs/2026-11-14-p5-vm-proof/."
      ;;
    2c) against=2b ;;
    3b) against=3a ;;
    3c) against=3b ;;
    3d) against=3c ;;
  esac
  say "recording $row (about 15 seconds)"
  record "$d"
  [ -z "$against" ] || compare "$d" "$against"
  # After the record, which signed out would spend the anonymous GitHub API limit
  if [ -n "$sign_out" ] && [ "$(cat "$d/gh.txt.exit")" = 0 ]; then
    say "gh is signed in. Signing it out of github.com, so Turn On Sync signs in from the app's console."
    (cd "$HOME" && appenv gh auth logout --hostname github.com) 2>&1 | tee -a "$log"
    grab "$d" gh-after.txt gh auth status
  fi
  say "$row saved in $d"
}

preflight() {
  [ -x "$rotm" ] || die "$rotm is missing: install first (RUNBOOK.md)"
  local mode
  mode=$("$HOME/dotfiles/bin/lib/rotm-mode" "$(cd "$HOME/dotfiles" && pwd -P)" 2>&1)
  [ "$mode" = installed ] || die "this is not an installed copy (rotm-mode says: $mode). Never run this on a development clone"
}

py() {
  /usr/bin/python3 -I - "$@" << 'PY'
# Python 3.9 (the guest's): no tomllib, no match, no X | Y types
import difflib, json, os, re, sys


def read(path):
    try:
        with open(path) as f:
            return f.read()
    except OSError:
        return None


def ran(d, name):
    """The command's stdout, or None with a reason when it failed."""
    code = (read(os.path.join(d, name + ".exit")) or "").strip()
    if code == "0":
        return read(os.path.join(d, name)), None
    err = (read(os.path.join(d, name + ".err")) or "").strip().splitlines()
    return None, "exit %s: %s" % (code or "?", err[-1] if err else "")


def flat(prefix, value, out):
    if isinstance(value, dict):
        for k, v in value.items():
            flat(prefix + "." + k, v, out)
    else:
        out[prefix] = json.dumps(value) if isinstance(value, list) else value


def state(d):
    fields, kinds = {}, {}
    for name in ("status", "update"):
        text, why = ran(d, name + ".json")
        if why:
            fields[name] = why
        else:
            flat(name, json.loads(text), fields)
    text, why = ran(d, "list.json")
    if why:
        fields["list"] = why
    else:
        for row in json.loads(text):
            key = "list." + row["setting_id"]
            fields[key] = "%s [%s%s]" % (json.dumps(row["value"]), row["source"], ", drift" if row["drift"] else "")
            kinds[key] = row["kind"] + (", " + row["scope"] if row.get("scope") else "")
    text, why = ran(d, "packages.json")
    if why:
        fields["cask"] = why
    else:
        casks = json.loads(text).get("brew-cask", {}).get("packages", [])
        row = next((p for p in casks if p.get("package", "").endswith("/returnofthemac-app")), None)
        fields["cask"] = ("state=%s installed=%s managed_by=%s" % (row.get("state"), row.get("installed_version"),
                          row.get("managed_by")) if row else "not declared")
    text, why = ran(d, "defaults.txt")
    fields["defaults.com.apple.dock.tilesize"] = text.strip() if text is not None else "(not set)"
    text, why = ran(d, "gitcred.txt")
    # git config exits 1 when nothing matches
    fields["git.credential"] = text.strip() if text is not None else ("" if why.startswith("exit 1:") else why)
    text, why = ran(d, "gh.txt")
    out = (text or "") + (read(os.path.join(d, "gh.txt.err")) or "")
    fields["gh.signed_in"] = why is None
    m = re.search(r"account (\S+)", out)
    fields["gh.account"] = m.group(1) if m else None
    text, why = ran(d, "cask.rb")
    m = re.search(r'version "([^"]+)"', text or "")
    fields["tap.version"] = m.group(1) if m else why or "no version line"
    for name in sorted(os.listdir(os.path.join(d, "files"))):
        fields["file." + name] = read(os.path.join(d, "files", name))
    for line in (read(os.path.join(d, "mac.txt")) or "").splitlines():
        k, _, v = line.partition("=")
        fields["mac." + k] = v
    with open(os.path.join(d, "state.json"), "w") as f:
        json.dump({"fields": fields, "kinds": kinds}, f, indent=1, sort_keys=True)


def show(v):
    return "(absent)" if v is None else v if isinstance(v, str) else json.dumps(v)


def diff(a_dir, b_dir):
    a, b = (json.load(open(os.path.join(x, "state.json"))) for x in (a_dir, b_dir))
    kinds = dict(a["kinds"], **b["kinds"])
    fa, fb = a["fields"], b["fields"]
    differ = [k for k in sorted(set(fa) | set(fb)) if fa.get(k) != fb.get(k)]
    for k in differ:
        label = k + (" (%s)" % kinds[k] if k in kinds else "")
        va, vb = fa.get(k), fb.get(k)
        if all(isinstance(v, str) or v is None for v in (va, vb)) and "\n" in (va or "") + (vb or ""):
            print(label + ":")
            for line in difflib.unified_diff((va or "").splitlines(), (vb or "").splitlines(), lineterm="", n=0):
                if not line.startswith(("---", "+++", "@@")):
                    print("    " + line)
        else:
            print("%s: %s -> %s" % (label, show(va), show(vb)))
    if not differ:
        print("no field differs")
    return 1 if differ else 0


if sys.argv[1] == "state":
    state(sys.argv[2])
else:
    sys.exit(diff(sys.argv[2], sys.argv[3]))
PY
}

case "${1:-}" in
  diff)
    [ $# = 3 ] || die "usage: proof.sh diff <record> <record>, such as: diff 1c1 1c2/undone"
    a=$(where "$2") && b=$(where "$3") || exit 1
    py diff "$a" "$b"
    ;;
  *)
    case " $rows " in
      *" ${1:-none} "*) ;;
      *) die "usage: proof.sh <row> | diff <record> <record>. Rows: $rows" ;;
    esac
    preflight
    run_row "$1"
    ;;
esac
