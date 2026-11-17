# Quieter updates and a keg cleanup, Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A `sysup` or `rotm update` run that changed nothing says so in a few lines and raises no false alarm, and `sysup` removes the Homebrew kegs that an earlier upgrade replaced.

**Architecture:** `sysup` keeps its one status line per step and gains one quiet level for a release mise is holding, a real check behind the installed copy's `dotfiles` line, and a `packages cleanup` step that calls a new helper, `bin/lib/brew-keg-cleanup`. `rotm update` tells `setup.sh` it is an update through one environment variable, and `setup/misc.sh` prints one line where a step found nothing to do. No output format is redesigned: each change is local to the line it fixes.

**Tech Stack:** bash 3.2 (`/bin/bash` on macOS), jq, git, Python 3 for `agents/catalog/build_catalog.py`, the self-checks under `bin/lib/test-*` that `pnpm check` runs.

**Spec:** None of its own. The section below records the evidence and the owner's decisions this plan argues from. It comes from the audit of one `rotm update` run and one `sysup` run on the owner's Mac on 2026-11-16 (logs `private/setup-logs/20261116-210223.log` and `logs/sysup-20261116-210319.log` in the installed copy).

## Evidence and the owner's decisions

Measured on 2026-11-16, mise 2026.11.8, on the owner's Mac (an installed copy on `stable`).

1. **The `dotfiles` notice is unconditional.** `bin/sysup:222` prints `installed copy: run rotm update` for every installed copy. `rotm update --check --json` printed `{"mode":"installed","branch":"stable","behind":0}` at the same moment.
2. **A held release is a notice.** `bin/sysup:444` prints `mirrord 3.288.0 held until … by minimum_release_age` at the `notice` level, so it is yellow and counts in the headline. The run said "4 notices" and two of them were holds. Owner's decision: a hold is not a warning and gets its own indicator.
3. **The plugins step fetches over SSH.** 10 of the 12 clones under `~/.claude/plugins/marketplaces/` have a `git@github.com:` remote. The owner saw a 1Password prompt during that step with no line announcing it. That the SSH fetch is what prompted is inferred. A fetch of three of those remotes with `url.https://github.com/.insteadOf=git@github.com:` and `GIT_SSH_COMMAND=false` succeeded, the owner's own marketplace included.
4. **mise leaves the previous keg.** After the 15 November upgrade, 62 kegs of 54 formulae sat beside their current version, 2.7 GiB. mise's `pour.rs` links the new keg and does not touch the rack's other versions, and its docs ([Homebrew formulae](https://mise.jdx.dev/bootstrap/packages/brew.html)) list no command that removes one: `prune` removes only a linked formula that no config declares. mise never runs `brew`, and this repo has no `brew`.
5. **mise leaves stale links.** 159 links outside the Cellar pointed into those kegs. 45 had the same file in the current version, among them 13 alias links such as `opt/node@26` and `opt/awscli@2`. 114 named a file the current version no longer ships.
6. **The cleanup is safe when done in that order.** A script repointed the 45, removed the 114 and moved the kegs aside. Before it, 8,386 Mach-O files in live locations loaded nothing from a superseded keg and no process had one open. After it, the same scan found no new missing library, 20 tools printed the versions they printed before, and `mise bootstrap packages status` listed every package as installed.
   An independent review of that script then found three defects, each reproduced in a fake prefix. None fired on the real run: all 114 removed links were checked afterwards and none has a file in the current version. Task 4's rules and cases p to s close them.
   - A link with an absolute target was removed where it should be repointed. This Mac has five, all rustup's (`bin/rustup -> /opt/homebrew/Cellar/rustup/1.29.3/bin/rustup`), so the next rustup upgrade would have taken `rustup` off `PATH`.
   - An `opt` target ending in `/` made the current keg count as superseded.
   - A link name holding a newline made the script act on a path relative to the working directory.
7. **One dead link has no keg.** `/opt/homebrew/share/man/man1/README.md` points at `../../../manpages/README.md`, a file of the Homebrew checkout that this Mac no longer has. Owner's decision: the plan removes it too. `brew cleanup` prunes dead links in the prefix the same way.
8. **`rotm update` printed 276 lines and changed nothing.** 82 are `set for <script>` (`setup/misc.sh:60`). The first-install warning and its "Press Enter" wait ran (`setup.sh:239`). The font preset menu ran (`setup/misc.sh:83`). `claude-config restore` printed nothing under its heading. The catalog line printed two Python dicts (`agents/catalog/build_catalog.py:630`).
9. **A same-version bottle rebuild is invisible to mise.** `socat` 1.8.1.3 kept loading `openssl@3` after its formula moved to `openssl@4`. This is documented in `setup/README.md` since `588985c` and is not part of this plan.

Owner's decisions:

- A held release gets its own quiet indicator (item 2).
- The dead `README.md` link is fixed by this plan (item 7).
- The keg cleanup uses a script, because mise has no native way (item 4). It goes into `sysup`.

Decisions this plan makes, for the owner to overrule at review:

- **`sysup` deletes superseded kegs, it does not move them aside.** The step runs before the package upgrade, so it removes what an earlier run replaced and keeps what this run replaces. That is the rule `mise prune` already follows in `sysup`, and it leaves one run in which an upgrade can be rolled back.
- **The held line reads `◷ mise hold  <tool> <version> until <time> (minimum_release_age)`**, dim, outside the Notices block and the headline count.
- **`rotm update` skips the first-install warning.** The warning asks for consent to replace config files with links. An installed copy gave it at install, and setup still stops when a file is in the way.

Left out on purpose:

- The free-space line after each package manager stays. `bin/lib/test-bootstrap:235` asserts it, and it exists for a fresh install, where a full disk is the likeliest failure.
- One output style for `setup.sh` and `sysup`. It is a redesign of `setup.sh` and `setup/misc.sh` and needs its own spec.
- "Open a new terminal" only after a change. `setup.sh` does not track whether a step changed anything.
- The sudo prompt on a run that needs no root. `setup.sh` cannot know that before mise runs.
- Updating plugins in parallel. The step took 1m 35s of 2m 39s for 67 plugins, one at a time. Whether two `claude plugin update` processes can write `installed_plugins.json` at once is not known. A probe that runs two updates at once against a copy of the config folder would settle it.
- Reporting items 4 and 5 to mise. That is a public post, so it is the owner's call.

## Global Constraints

- bash 3.2: no associative arrays, no `mapfile`, no `${var,,}`.
- Every script starts with `#!/bin/bash` and a header comment. `shellcheck --severity=warning` and `prettier --check` pass on each changed file. `pnpm check` passes before each commit.
- `sysup`'s report contract (`.claude/rules/sysup.md`): every step ends in exactly one `ok`, `changed`, `notice` or `fail` line, and a `changed` line appears only when the step changed something.
- Never run on this Mac: `sysup`, `./setup.sh`, `rotm update`, `claude-config restore` or `save` outside a test's fake `HOME`. The owner runs them (Task 9).
- A self-check that fakes `HOME` or `MISE_DATA_DIR` takes mise's shims off `PATH` first.
- A setup behavior change updates `setup/README.md` in the same commit. A `sysup` change updates `docs/updating.md` and, where a constraint changes, `.claude/rules/sysup.md`.
- `bin/lib/test-conventions` caps the instruction files: a file under `.claude/rules/` holds at most 6,000 bytes and no line over 1,000. `.claude/rules/sysup.md` is 4,749 bytes, and its Claude Code bullet (line 18) is 754, so Task 3's sentence goes in a bullet of its own. `CLAUDE.md` is 11,951 of 12,000 bytes: add nothing to it.
- The menu bar app runs `rotm update -y` and reads no line of the output (`app/Sources/RotmCore/ConsoleSession.swift:16`), so no task touches `app/`. `app/Tests/RotmTestSupport/Fixtures/update-console.raw` is a recorded sample for the color renderer and stays as it is.
- `sysup` calls a `bin/` script by name and a `bin/lib/` helper by path, resolved before its `cd "$HOME"` (`bin/sysup:21-23`).
- Commit subjects are short, imperative, sentence case, no prefix. On `main`, commit and push once `pnpm check` passes.
- Comments say only a non-obvious why. Prose in docs and messages uses no long dash.

## Review Focus

1. A link with an absolute target into a superseded keg (rustup's five on this Mac). It must be repointed, not removed. Pinned in Task 4, case p. With it, a formula whose name or version is a prefix of another's (`node` and `node@26`, `1.2` and `1.2.1`): cases b and c.
2. A downgrade or a hand-repointed `opt` link, where `opt/<name>` names the older keg. The newer keg must stay. Pinned in Task 4, case h.
3. `sysup` with no Homebrew prefix (the CI runner's layout, `HOMEBREW_PREFIX` pointing nowhere). The step must not appear and nothing may fail. Pinned in Task 5.
4. `rotm update --check` failing offline. The `dotfiles` line must say it could not check, never "up to date". Pinned in Task 2.
5. A first install, where `ROTM_UPDATE` is unset and no font preset is saved. The warning, the Enter wait and the menu must all still appear. Pinned in Tasks 6 and 7.

---

### Task 1: A quiet level for a held release

**Files:**

- Modify: `bin/sysup:45-52` (`style`), `bin/sysup:72-90` (`status`), `bin/sysup:443-445`
- Modify: `.claude/rules/sysup.md` (Report contract bullet), `docs/updating.md`
- Test: `bin/lib/test-sysup:304`

**Interfaces:**

- Produces: `status held <step> <detail>`, a fifth level. It prints a line and logs it, and is not collected for the summary or the headline.

- [ ] **Step 1: Change the assertion at `bin/lib/test-sysup:304` and add two**

```bash
check_true "changes: a held release has its own quiet line" has '^◷ mise hold +aspire 13\.6\.3 until 2026-10-24 14:17 EDT \(minimum_release_age\)$'
check_true "changes: … and is not a notice" lacks '● mise +aspire'
check_true "changes: … and is not in the summary" lacks '^ +◷'
```

- [ ] **Step 2: Run `bash bin/lib/test-sysup`. Expected: FAIL naming "a held release has its own quiet line".**

- [ ] **Step 3: Add the level**

In `style`, add `held) glyph=◷ color=$c_dim ;;`. In `status`, dim the detail for `held` as for `ok`, and leave `held` out of both `case` statements, so it gets no elapsed time and joins no summary array. At line 444 call `status held "mise hold" "${tool##*[:/]} $version until $until (minimum_release_age)"`.

- [ ] **Step 4: Run `bash bin/lib/test-sysup`. Expected: PASS.**

- [ ] **Step 5: Docs**

In `.claude/rules/sysup.md`, add to the Report contract bullet: "A `held` line (a release mise holds back by `minimum_release_age`) is extra to a step's status line and counts as none of the four." In `docs/updating.md`, name the `◷` line where the page lists what `sysup` prints.

- [ ] **Step 6: `pnpm check`, then commit: "Show a held mise release as its own quiet line"**

### Task 2: The dotfiles line checks an installed copy

**Files:**

- Modify: `bin/sysup:221-222`, and the two `ok` details at the "Claude config" and catalog steps
- Modify: `setup/README.md:73`, `docs/updating.md`
- Test: `bin/lib/test-sysup:474-484`

**Interfaces:**

- Consumes: `rotm update --check --json`, which prints `{"mode":"installed","branch":"<b>","behind":<n>}` and exits 0, or prints one line on stderr and exits 1 when the fetch fails (`bin/lib/test-rotm:83-98`).

- [ ] **Step 1: Add a `rotm` stub beside the others in `bin/lib/test-sysup`**

```bash
stub rotm '[ ! -e "$STATE/rotm-fails" ] || { echo "rotm: could not fetch stable from origin" >&2; exit 1; }
echo "{\"mode\":\"installed\",\"branch\":\"stable\",\"behind\":$(cat "$STATE/behind" 2> /dev/null || echo 0)}"'
```

- [ ] **Step 2: Replace the two dotfiles assertions in the installed-copy case (lines 483-484) and add two runs after them**

```bash
check_true "installed: a level copy is up to date" has '^✔ dotfiles +installed copy up to date$'
check_true "installed: … with no advice to update" lacks 'dotfiles.*rotm update'
echo 2 > "$STATE/behind"
rm -rf "$DOTFILES/logs"
run
check_true "installed, behind: the count and the command" has '^● dotfiles +2 updates waiting; run: rotm update$'
rm -f "$STATE/behind"
touch "$STATE/rotm-fails"
rm -rf "$DOTFILES/logs"
run
check_true "installed, offline: says it could not check" has "^● dotfiles +couldn't check the installed copy; run: rotm update --check\$"
check_true "installed, offline: … and never up to date" lacks 'dotfiles.*up to date'
rm -f "$STATE/rotm-fails"
```

- [ ] **Step 3: Run `bash bin/lib/test-sysup`. Expected: FAIL naming "a level copy is up to date".**

- [ ] **Step 4: Replace `bin/sysup:222`**

`capture rotm update --check --json`, then read `.behind` with `jq -er '.behind | numbers'`. Zero is `status ok dotfiles "installed copy up to date"`. Any other number is `status notice dotfiles "$(plural "$behind" update) waiting; run: rotm update"`. A failed command or a value jq rejects is `status notice dotfiles "couldn't check the installed copy; run: rotm update --check"`.

- [ ] **Step 5: Two details that read like problems**

Change `"installed copy: not saved into it"` to `"installed copy, nothing to save"`, and the catalog `ok` detail `"catalog rebuilt"` to `"rebuilt, no change"`. `grep -n 'catalog rebuilt' bin/lib/test-sysup` names the assertions to update. The `changed` detail keeps its text.

- [ ] **Step 6: Run `bash bin/lib/test-sysup`. Expected: PASS.**

- [ ] **Step 7: Docs**

`setup/README.md:73` becomes: "`sysup` does not pull. It asks `rotm update --check` whether the copy is behind its branch and reports how many updates are waiting. It does not run `claude-config save`, which writes `agents/` inside the copy." Say the same under "On an installed copy" in `docs/updating.md`.

- [ ] **Step 8: `pnpm check`, then commit: "Have sysup check whether the installed copy is behind"**

### Task 3: The plugins step fetches over HTTPS

**Files:**

- Modify: `bin/sysup` plugins step (`claude plugin marketplace update` and `claude plugin update -y "$id"`)
- Modify: `.claude/rules/sysup.md` (Claude Code bullet)
- Test: `bin/lib/test-sysup:142-155` (the `claude` stub) and the plugin assertions near line 447

**Interfaces:**

- Produces: `https_git <cmd…>` in `bin/sysup`, which runs the command with `GIT_CONFIG_COUNT=1`, `GIT_CONFIG_KEY_0=url.https://github.com/.insteadOf` and `GIT_CONFIG_VALUE_0=git@github.com:` in its environment.

- [ ] **Step 1: Make the `claude` stub record that environment for both plugin commands**

At the top of the stub: `case "$1 $2" in "plugin update" | "plugin marketplace") echo "${GIT_CONFIG_COUNT:-}|${GIT_CONFIG_KEY_0:-}|${GIT_CONFIG_VALUE_0:-}" >> "$STATE/plugin-git.log" ;; esac`.

- [ ] **Step 2: Assert it after the default run**

```bash
check_true "plugins: every fetch is told to use HTTPS for github.com" [ "$(sort -u "$STATE/plugin-git.log")" = '1|url.https://github.com/.insteadOf|git@github.com:' ]
```

- [ ] **Step 3: Run `bash bin/lib/test-sysup`. Expected: FAIL naming that check.**

- [ ] **Step 4: Add `https_git` above the plugins step and put it in front of both `claude plugin` commands inside `capture`**

- [ ] **Step 5: Run `bash bin/lib/test-sysup`. Expected: PASS.**

- [ ] **Step 6: Add a bullet of its own to `.claude/rules/sysup.md`, after the Claude Code one**

"**Plugin fetches**: the marketplace clones have `git@github.com:` remotes, and a fetch through the 1Password SSH agent asks for approval with no line to announce it, so both plugin commands run with a `url.https://github.com/.insteadOf` rewrite in their environment."

Then `bash bin/lib/test-conventions`. Expected: PASS (the size caps).

- [ ] **Step 7: `pnpm check`, then commit: "Fetch plugin marketplaces over HTTPS in sysup"**

### Task 4: `brew-keg-cleanup`

**Files:**

- Create: `bin/lib/brew-keg-cleanup`
- Create: `bin/lib/test-keg-cleanup`
- Modify: `bin/lib/check` (a `job quiet bash bin/lib/test-keg-cleanup` line beside `test-packages`), `bin/CLAUDE.md` (the `bin/lib/` list)
- Delete: `private/keg-cleanup.sh` (git-ignored, the prototype this replaces)

**Interfaces:**

- Produces: `brew-keg-cleanup [--apply]`. Prefix is `${HOMEBREW_PREFIX:-/opt/homebrew}`. Without `--apply` it changes nothing. Exit 0 on success, 1 on a failure, 2 on an unknown argument.
- Output, one line per action, paths relative to the prefix:
  - `repoint <link> -> <new target>`
  - `unlink  <link>`
  - `remove  Cellar/<name>/<version>`
  - last line `<K> kegs, <R> links repointed, <U> links removed`, or the single line `nothing superseded` when all three are zero or the prefix has no `Cellar`.

**Rules the script follows:**

- A keg `Cellar/<name>/<v>` is superseded when `opt/<name>` is a link to another version `<cur>` of the same rack, `Cellar/<name>/<cur>` exists, `var/homebrew/linked/<name>` is absent or names `<cur>`, and `Cellar/<name>/<cur>` is newer than the keg by mtime. A rack that fails any of these is skipped whole.
- `<cur>` is the `basename` of the `opt` link's target, so a trailing `/` does not empty it. An empty `<cur>`, `.` or `..` skips the rack. A keg that is the same directory as `opt/<name>` (`-ef`) is never removed, whatever the rest says.
- Links are found with `find -H "$P"`, so a prefix that is itself a symlink is still scanned. A trailing slash would do that too, but it prints `$P//…` paths that the `-prune` patterns no longer match.
- A link outside `Cellar` belongs to a superseded keg when its target, split on `/`, holds the three consecutive components `Cellar`, `<name>`, `<v>`. Compare components, never substrings. An absolute target must also start with `$P/`, so another prefix's Cellar is left alone.
- Before a link is repointed or removed, its path must start with `$P/` and be a symlink (`-L`). A name with a newline or a tab that the list splits wrongly is then skipped, never acted on.
- For each such link: when the same path exists under `<cur>`, repoint it there, else remove it. The existence test uses the new target as it is when it is absolute, and joins it to the link's directory when it is relative. All links of a keg are handled before the keg is removed.
- A temp file is removed by a `trap … EXIT`.
- The record of what a run removed is its own output, which `sysup` writes to its log.
- Then remove every symlink under `bin etc include lib opt sbin share var/homebrew/linked` whose target does not exist. It prints as `unlink` and counts in `<U>`.
- `--apply` removes a keg with `rm -rf`. The path it removes is built from the rack listing, never from a link target.
- A second run after a complete or an interrupted one finishes the work and then prints `nothing superseded`.

- [ ] **Step 1: Write `bin/lib/test-keg-cleanup`**

Model it on `bin/lib/test-packages` (header, `set -euo pipefail`, a `mktemp -d` fixture, `fail` naming the first failed assertion). Each case builds a fake prefix with a helper `keg <name> <version> [file…]` that creates `Cellar/<name>/<version>/<file>` and `link <path> <target>`, sets `HOMEBREW_PREFIX`, and runs the script. Give kegs distinct mtimes with `touch -t`. The cases and what each asserts:

| Case | Fixture | Assert after `--apply` |
| --- | --- | --- |
| a | `foo` 1.0 and 2.0, `opt/foo` to 2.0 | dry run prints `remove  Cellar/foo/1.0` and both kegs still exist. Then `--apply`: 1.0 is gone, 2.0 exists |
| b | `foo` 1.2 old and 1.2.1 current, `lib/libfoo.dylib` into 1.2.1 | the link target is unchanged |
| c | racks `node` (1 old, 2 current) and `node@26` (one keg), `bin/n26` into `node@26` | the `node@26` keg and `bin/n26` are unchanged |
| d | alias `opt/foo@1` to `../Cellar/foo/1.0` | it reads `../Cellar/foo/2.0` |
| e | `lib/a` and `lib/b` into 1.0, 2.0 ships only `lib/a` | `lib/a` points into 2.0, `lib/b` is gone |
| f | keg-only: no `var/homebrew/linked/foo` | 1.0 is gone |
| g | `var/homebrew/linked/foo` names 1.0 while `opt/foo` names 2.0 | both kegs exist, output has no `Cellar/foo` line |
| h | downgrade: `opt/foo` to 1.0, and 2.0 has the newer mtime | both kegs exist |
| i | `opt/foo` points at a version that does not exist | both kegs exist |
| j | `share/man/man1/README.md` to `../../../manpages/README.md` (missing), and a live link beside it | the dead link is gone, the live one stays, and the dry run printed `unlink  share/man/man1/README.md` |
| k | a prefix with no `Cellar` | stdout is exactly `nothing superseded`, exit 0 |
| l | case a, run twice | the second run prints exactly `nothing superseded` |
| m | a link whose path has a space | handled as in case e |
| n | case e | the last line matches `^1 kegs, 1 links repointed, 1 links removed$` |
| o | `--bogus` | exit 2, nothing changed |
| p | `bin/tool` with the absolute target `$P/Cellar/foo/1.0/bin/tool`, and 2.0 ships `bin/tool` | it reads `$P/Cellar/foo/2.0/bin/tool` and still resolves |
| q | `opt/foo` reads `../Cellar/foo/2.0/` with the trailing slash | 2.0 exists, 1.0 is gone, `opt/foo` still resolves |
| r | a link under `bin/` whose name is `a`, a newline, `decoy`, pointing into 1.0, and the script run from a directory holding a file `decoy` | `./decoy` still exists |
| s | `HOMEBREW_PREFIX` is a symlink to the fake prefix, case e's links | `lib/a` points into 2.0, `lib/b` is gone |
| t | an absolute link into `/elsewhere/Cellar/foo/1.0/x` | the link is unchanged |

- [ ] **Step 2: Run `bash bin/lib/test-keg-cleanup`. Expected: FAIL, the script does not exist.**

- [ ] **Step 3: Write `bin/lib/brew-keg-cleanup` to the rules above**

Start from `private/keg-cleanup.sh`, which already has the rack loop and the link pass and ran clean on 62 kegs. The review's three defects are already fixed in it and proven on a fake prefix (cases a to e, h, m, p, q and r pass). It still differs from the rules in two ways: it moves kegs into a holding folder where the rules want `rm -rf`, and it has no dead-link pass. Read the links once into a `link<TAB>target` list: a `readlink` per link per keg took minutes on the real prefix.

- [ ] **Step 4: Run `bash bin/lib/test-keg-cleanup`. Expected: PASS.**

- [ ] **Step 5: Run the dry run on this Mac: `brew-keg-cleanup`**

Expected: one `unlink  share/man/man1/README.md` line and `0 kegs, 0 links repointed, 1 links removed`. Any `remove` or `repoint` line means a keg was upgraded since 2026-11-16: read each one before going on. Do not pass `--apply` here: Task 9 does that through `sysup`.

- [ ] **Step 6: Register the self-check in `bin/lib/check`, add the helper to the `bin/lib/` list in `bin/CLAUDE.md`, delete `private/keg-cleanup.sh`**

- [ ] **Step 7: `pnpm check`, then commit: "Add a cleanup for Homebrew kegs an upgrade replaced"**

### Task 5: `sysup` runs the cleanup before the package upgrade

**Files:**

- Modify: `bin/sysup`, a new step directly above `step packages` (line 322)
- Modify: `docs/updating.md`, `setup/README.md:108`, `.claude/rules/sysup.md` (Packages bullet), `README.md` where it lists what `sysup` does
- Test: `bin/lib/test-sysup`

**Interfaces:**

- Consumes: `brew-keg-cleanup --apply` and its last line from Task 4. `sysup` finds it by path, as it finds `rotm-modules`, so the self-check runs the real helper against a fake prefix. No stub.

- [ ] **Step 1: Add the cases to `bin/lib/test-sysup`**

The default runs keep `HOMEBREW_PREFIX="$tmp/nobrew"`, which does not exist, so add first:

```bash
check_true "no Homebrew prefix: the cleanup step does not appear" lacks 'packages cleanup'
```

Then a block that builds a prefix under `$HOMEBREW_PREFIX` and runs `sysup` three times, with `rm -rf "$DOTFILES/logs"` before each run:

```bash
# an empty Cellar
mkdir -p "$HOMEBREW_PREFIX/Cellar" "$HOMEBREW_PREFIX/opt" "$HOMEBREW_PREFIX/lib"
run
check_true "kegs: nothing superseded is an ok line" has '^✔ packages cleanup +nothing superseded$'
check_true "kegs: it runs before the upgrade" grep -q 'packages cleanup.*packages ' <<< "$(grep -oE '^== packages( cleanup)? ==' "$DOTFILES"/logs/sysup-*.log | tr '\n' ' ')"
# foo 1.0 replaced by 2.0, one link to repoint and one to drop
mkdir -p "$HOMEBREW_PREFIX/Cellar/foo/1.0/lib" "$HOMEBREW_PREFIX/Cellar/foo/2.0/lib"
touch "$HOMEBREW_PREFIX/Cellar/foo/1.0/lib/a" "$HOMEBREW_PREFIX/Cellar/foo/1.0/lib/b" "$HOMEBREW_PREFIX/Cellar/foo/2.0/lib/a"
touch -t 202601010000 "$HOMEBREW_PREFIX/Cellar/foo/1.0"
ln -s ../Cellar/foo/2.0 "$HOMEBREW_PREFIX/opt/foo"
ln -s ../Cellar/foo/1.0/lib/a "$HOMEBREW_PREFIX/lib/a"
ln -s ../Cellar/foo/1.0/lib/b "$HOMEBREW_PREFIX/lib/b"
run
check_true "kegs: a removal is a changed line with both counts" has '^↻ packages cleanup +1 old version removed, 2 links fixed$'
check_true "kegs: the old version is gone and the current one stays" [ ! -e "$HOMEBREW_PREFIX/Cellar/foo/1.0" ] && check_true "…" [ -d "$HOMEBREW_PREFIX/Cellar/foo/2.0" ]
# a keg that cannot be removed
mkdir -p "$HOMEBREW_PREFIX/Cellar/foo/1.5"
touch -t 202601010000 "$HOMEBREW_PREFIX/Cellar/foo/1.5"
chmod 555 "$HOMEBREW_PREFIX/Cellar/foo"
run
# before the check: a failed check exits, and the trap cannot delete a read-only rack
chmod 755 "$HOMEBREW_PREFIX/Cellar/foo"
rm -rf "$HOMEBREW_PREFIX"
check_true "kegs: a failure names the command" has '^✖ packages cleanup +run: brew-keg-cleanup$'
```

`sysup` uses the rustup stub only while `$HOMEBREW_PREFIX/opt/rustup/bin/rustup` is missing, which this block keeps true. If another step's assertion changes once the prefix exists, that step reads the prefix too: fix the fixture, not the step.

- [ ] **Step 2: Run `bash bin/lib/test-sysup`. Expected: FAIL naming "nothing superseded is an ok line".**

- [ ] **Step 3: Add the step**

Beside the `modules=` line at `bin/sysup:23`, resolve `keg_cleanup="$(cd "$(dirname "$0")/lib" && pwd -P)/brew-keg-cleanup"`. Only when `${HOMEBREW_PREFIX:-/opt/homebrew}/Cellar` is a directory: `step "packages cleanup"`, then `capture "$keg_cleanup" --apply`. Parse the last line of `$out` with one `sed -nE 's/^([0-9]+) kegs, ([0-9]+) links repointed, ([0-9]+) links removed$/\1 \2 \3/p'`. No match, or three zeros, is `status ok "packages cleanup" "nothing superseded"`. Otherwise `status changed "packages cleanup" "$(plural "$kegs" "old version") removed, $((repointed + removed)) links fixed"`. A non-zero exit is `status fail "packages cleanup" "run: brew-keg-cleanup"` followed by `show`.

- [ ] **Step 4: Run `bash bin/lib/test-sysup`. Expected: PASS.**

- [ ] **Step 5: Docs**

- `docs/updating.md`: one bullet beside the `packages prune` one. `sysup` removes the Homebrew versions an earlier upgrade replaced, and repoints or removes the links that still named them. It runs before the upgrade, so the version this run replaces stays until the next run.
- `.claude/rules/sysup.md`, Packages bullet: mise leaves the previous keg and does not repoint alias links (`opt/node@26`) on upgrade, and has no command for either, so `brew-keg-cleanup` does both. It runs before the upgrade for the same reason `mise prune` does.
- `setup/README.md:108`: keep the paragraph, and add that `sysup` removes replaced versions by itself.
- `README.md`: `grep -n 'packages prune\|sysup' README.md` shows whether it lists `sysup`'s steps. If it does, add this one.

- [ ] **Step 6: `pnpm check`, then commit: "Remove replaced Homebrew versions in sysup"**

### Task 6: `rotm update` skips the first-install warning

**Files:**

- Modify: `bin/rotm:117`, `setup.sh:239-250`
- Modify: `setup/README.md`, `docs/updating.md:12`
- Test: `bin/lib/test-rotm:48`, `bin/lib/test-bootstrap` (the `unset` list at line 38 and a new case)

**Interfaces:**

- Produces: `ROTM_UPDATE=1` in `setup.sh`'s environment when `rotm update` started it. `rotm install` leaves it unset.

- [ ] **Step 1: In `bin/lib/test-rotm`, make the fixture's `setup.sh` log the variable on a line before its `setup` line**

The line is `env ROTM_UPDATE=${ROTM_UPDATE:-}`. The existing check that the last log line is `setup ` stays true. Add:

```bash
check "update tells setup.sh it is an update" "rotm update && grep -qx 'env ROTM_UPDATE=1' '$tmp/log'"
check "install does not" ": > '$tmp/log'; rotm install && grep -qx 'env ROTM_UPDATE=' '$tmp/log'"
```

- [ ] **Step 2: In `bin/lib/test-bootstrap`, add `ROTM_UPDATE` to the `unset` list and a case beside case a**

```bash
ROTM_UPDATE=1 run
check_true "update: no first-install warning" lacks 'WARNING'
check_true "update: … and no wait or its stand-in" lacks 'Press Enter|Non-interactive shell'
check_true "update: one line names the copy" has '^Updating /' 
run
check_true "install: the warning still shows" has 'WARNING'
```

The self-check has no terminal, so `setup.sh` prints "Non-interactive shell — continuing without confirmation." where a terminal would get "Press Enter". The second check covers both.

- [ ] **Step 3: Run both self-checks. Expected: FAIL naming the first new check in each.**

- [ ] **Step 4: Implement**

`bin/rotm`: `export ROTM_UPDATE=1` on the line before `exec "$DOTFILES/setup.sh" "$@"` in `update`. `setup.sh`: when `ROTM_UPDATE` is set, print `Updating $DOTFILES_DIR` and skip the four warning lines, the Enter wait and its non-interactive stand-in. Nothing else in `setup.sh` reads the variable.

- [ ] **Step 5: Run both self-checks. Expected: PASS.**

- [ ] **Step 6: Docs**

`setup/README.md` and `docs/updating.md:12`: `rotm update` runs setup without the first-install warning and its wait.

- [ ] **Step 7: `pnpm check`, then commit: "Skip the first-install warning on rotm update"**

### Task 7: `misc.sh` says one line when a step had nothing to do

**Files:**

- Modify: `setup/misc.sh:58-62` (permissions), `:83` (font menu), `:170-172` (CodeGraph), `:385-387` (rtk), `:411` (PowerShell heading), `:480-482` (restore)
- Modify: `setup/README.md:32` and `:128`
- Test: `bin/lib/test-bootstrap`, the `misc` cases from line 719

- [ ] **Step 1: Add the assertions to the "all on" `misc` case**

```bash
check_true "permissions: one line, not one per script" has '^  [0-9]+ scripts executable$' && check_true "… and no per-script line" lacks 'set for '
check_true "restore with nothing to do says so" has '^  nothing to restore$'
check_true "PowerShell: the heading does not claim an install" has 'Checking PowerShell' && check_true "…" lacks 'Installing PowerShell'
```

The harness facts these rest on (`bin/lib/test-bootstrap:715-750`): `misc` runs with `DOTFILES_YES=1`, no terminal and `PATH="$tmp/mbin:/usr/bin:/bin"`; the `claude-config` stub prints nothing; `fresh` stubs no `codegraph`, so the CodeGraph step runs only in a case that adds one.

And three cases with their own stub output (`mstub` writes a stub, as at line 807):

```bash
mstub "$tmp/mbin/codegraph" "echo '◆  Claude Code: Unchanged ~/.claude.json'; echo '◇  Next: index a project'; echo '└  Done! Restart your agent to use CodeGraph.'"
# run misc
check_true "CodeGraph unchanged: one line" has '^  CodeGraph already connected$' && check_true "… and no restart advice" lacks 'Restart your agent'
mstub "$tmp/mbin/codegraph" "echo '◆  Claude Code: Updated ~/.claude.json'; echo '└  Done! Restart your agent to use CodeGraph.'"
# run misc
check_true "CodeGraph changed: its output is kept" has 'Restart your agent'
mstub "$tmp/mbin/rtk" "echo 'RTK hook registered (hook-only mode).'; echo '  settings.json: hook already present'; echo '  Restart Claude Code. Test with: git status'"
# run misc
check_true "rtk already wired: one line" has '^  rtk hook already present$' && check_true "… and no restart advice" lacks 'Restart Claude Code'
```

The existing rtk checks at lines 807-815 (`Hook installed` kept, `rtk init failed` on a failure) must still pass.

For the font menu, the `misc` cases run without a terminal, so `asks` is false in all of them. Add a static check in the style of line 233:

```bash
want='if asks && [ ! -f "${VSCODE_SETTINGS_ENV:-$HOME/.config/dotfiles/vscode.env}" ]; then'
check_true "the font menu is only for a Mac with no saved preset" grep -qF -- "$want" "$repo/setup/misc.sh"
```

- [ ] **Step 2: Run `bash bin/lib/test-bootstrap`. Expected: FAIL naming "permissions: one line".**

- [ ] **Step 3: Implement, one edit per site**

- Permissions: keep the `find … -exec chmod +x {} \;`, add `-print`, count the lines (`wc -l | tr -d ' '`, since macOS pads the count), print `<n> scripts executable` through `indent`. Drop the per-file `printf` and the `Done!` line.
- Font menu: the condition becomes `asks && [ ! -f "${VSCODE_SETTINGS_ENV:-$HOME/.config/dotfiles/vscode.env}" ]`. That is the file `bin/vscode-settings:47` saves a choice to, and `--choose` with Enter writes it, so the menu shows once.
- CodeGraph: capture the installer's output. When it has at least one `Claude Code:` line and every such line says `Unchanged`, print `CodeGraph already connected`. Otherwise print the output as now. The failure warning stays on a non-zero exit.
- rtk: capture as now, with the `No RTK.md` filter. When the output contains `hook already present`, print `rtk hook already present`. Otherwise print it as now.
- PowerShell: the heading reads `💠 Checking PowerShell (.NET global tool)…`.
- Restore: capture `claude-config restore`'s output. Print it through `indent` when it is not empty, else print `nothing to restore`. The warning on a non-zero exit stays.

- [ ] **Step 4: Run `bash bin/lib/test-bootstrap`. Expected: PASS.**

- [ ] **Step 5: Docs**

`setup/README.md:32` says `DOTFILES_YES` makes `misc.sh` skip the font menu, and `:128` describes the render. Add that the menu shows only while no preset is saved, and that `vscode-settings --choose` changes it later.

- [ ] **Step 6: `pnpm check`, then commit: "Print one line where setup found nothing to do"**

### Task 8: Three helpers report what happened

**Files:**

- Modify: `bin/install-snippetslab-skill:33-43`
- Modify: `agents/catalog/build_catalog.py:628-632`, `agents/catalog/test_build_catalog.py`
- Modify: `setup/dotfiles-extras.sh:223`
- Test: `agents/catalog/test_build_catalog.py`

**Interfaces:**

- Produces: `summary_line(out, kinds, n_plugins, total_cost, flags, since=None, added=0, removed=0) -> str` in `build_catalog.py`. `kinds` maps `skill`, `command`, `agent`, `mcp` to counts, and `flags` maps `review`, `watch`, `retire` to counts.
- `bin/sysup:786-787` reads the line with `^wrote (.*)/CATALOG\.md,.*` and `^wrote .*, since (.*): \+([0-9]+) -([0-9]+)$`. Both must still match.

- [ ] **Step 1: Add to `agents/catalog/test_build_catalog.py`, above the `importlib.reload` block near the end**

The file is a script of top-level asserts that imports the module as `b` and ends with `print("ok")`. It has no test functions, so add plain asserts, and `import re` at the top:

```python
# the line sysup parses: a sentence, with both of sysup's patterns still matching
line = b.summary_line("/c", {"skill": 362, "command": 42, "agent": 202, "mcp": 28}, 67, 57570,
                      {"review": 16, "watch": 10, "retire": 0}, "2026-11-16", 0, 0)
assert line == ("wrote /c/CATALOG.md, CATALOG-lite.md, catalog.html: 362 skills, 42 commands, 202 agents, "
                "28 MCP servers, 67 plugins, 57,570 always-on tokens, 16 to review, 10 to watch, 0 to retire, "
                "since 2026-11-16: +0 -0"), line
assert re.match(r"^wrote (.*)/CATALOG\.md,.*", line).group(1) == "/c"
assert re.match(r"^wrote .*, since (.*): \+([0-9]+) -([0-9]+)$", line).groups() == ("2026-11-16", "0", "0")
first = b.summary_line("/c", {"skill": 1, "command": 1, "agent": 1, "mcp": 1}, 1, 0, {"review": 0, "watch": 0, "retire": 0})
assert first.endswith("0 to review, 0 to watch, 0 to retire"), first
```

- [ ] **Step 2: Run `python3 agents/catalog/test_build_catalog.py`. Expected: FAIL with `AttributeError: module 'build_catalog' has no attribute 'summary_line'`.**

- [ ] **Step 3: Add `summary_line` and call it from the `print` at line 630**

Counts are not singularized: "1 skills" is accepted, because the line is a log line and a plural rule per noun is not worth the code.

- [ ] **Step 4: Run `python3 agents/catalog/test_build_catalog.py`. Expected: `ok`. `bin/lib/test-sysup:174-175` stubs the line without its middle part and needs no change.**

- [ ] **Step 5: `bin/install-snippetslab-skill`**

Before the `mv`, when `$skill_dir/SKILL.md` exists and `cmp -s "$tmp" "$skill_dir/SKILL.md"` is true, skip the `mv`. The link check and `ln -sfn` still run. The last line is then `SnippetsLab skill unchanged`, else the current `written to` line. `sysup` compares checksums and does not read this line.

Check by hand, since SnippetsLab is installed here: run `install-snippetslab-skill` twice. Expected: the second run prints `SnippetsLab skill unchanged`.

- [ ] **Step 6: `setup/dotfiles-extras.sh:223`**

`warn "No Firefox Developer Edition profile found — skipping Firefox styles"` becomes `skipped "Firefox styles (no Firefox Developer Edition profile)"`. A Mac without that browser is not a warning.

- [ ] **Step 7: `pnpm check`, then commit: "Report unchanged results plainly in three setup helpers"**

### Task 9: The owner's proof

Tasks 1 to 8 are built and pushed (2026-11-16, `3a124a9` to `941c99c`). Differences from the plan as written:

- Task 2: a third assertion needed the new wording (`bin/lib/test-sysup`, "installed, with a macOS update").
- Task 4: the prototype did not parse under `/bin/bash` 3.2 (a bare `)` case pattern inside `$(…)`, and a quoted `${t/"a/b"/…}` pattern), so both are written the 3.2 way. An absolute link that names the prefix by its physical path is matched too.
- Task 5: the changed line counts links with a singular ("1 link fixed").
- Task 7: the CodeGraph stubs answer only `install`, because `misc.sh` also calls `codegraph telemetry off`. Two cases were added: a restore that prints something, and a failed CodeGraph install.
- Task 8: `setup/tests/dotfiles-extras.sh` asserted the Firefox warning and now asserts the skipped line.
- Review: an independent reviewer reproduced four defects in `brew-keg-cleanup` on fake prefixes, none of which this Mac's prefix triggers. A `HOMEBREW_PREFIX` ending in `/` unlinked links it should have repointed. An `opt` link into another rack's keg of the same version counted as this rack's current one. A link name holding a newline and the path of a real link got that link removed. An empty current keg still replaced the old one. Cases u to x pin them. In `sysup`, the plugin commands also get `GIT_TERMINAL_PROMPT=0`, a last line the step cannot read is a notice, and the failure hint is `brew-keg-cleanup --apply`.

`sysup` and `rotm update` are never run by an agent on this Mac. This task is the owner's.

- [x] **Step 1: Promote `main` to `stable` the way the last plan did (`docs/superpowers/plans/completed/2026-11-16-trusted-skill-sources-and-hook-pin.md`, Task 6), after `check` and a `fresh-install` run pass on the commit.**

Done 2026-11-17: `fresh-install` run 44020041126 passed on the `clone` and the `installed` path on `f02ffbb`, with `check` green on the same commit (run 44020031224). `stable` moved from `2cbdee8` to `f02ffbb` by a fast-forward push.

- [ ] **Step 2: The owner runs `rotm update`. Expected:**

- no `WARNING` block and no "Press Enter", one `Updating …` line
- no font preset menu
- one `<n> scripts executable` line, no `set for` lines
- `CodeGraph already connected`, `rtk hook already present`, `nothing to restore`, `SnippetsLab skill unchanged`
- a catalog line with no braces

- [ ] **Step 3: The owner runs `sysup`. Expected:**

- `✔ dotfiles  installed copy up to date`
- `↻ packages cleanup  0 old versions removed, 1 link fixed` on the first run (the dead `README.md` link), unless an upgrade since 2026-11-16 left kegs, in which case the count is theirs
- any held release as a dim `◷ mise hold` line, and a headline that does not count it
- no 1Password prompt during the plugins step. If one appears, Task 3's premise is wrong: say so in the outcome section and reopen it.

- [ ] **Step 4: The owner runs `sysup` again. Expected: `✔ packages cleanup  nothing superseded`.**

- [ ] **Step 5: Write the outcome table at the top of this plan (task, commit, difference from the plan), move the plan to `completed/`, and update `docs/superpowers/plans/README.md`.**
