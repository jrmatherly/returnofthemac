# Fixes from the 2026-11-16 audit, Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix findings A1 to D8 of the 2026-11-16 audit, so a folder name cannot run a command in the shell, a failed sync write cannot lose a later reset, and no documented command dirties an installed copy.

**Architecture:** Every fix is at the line where the fault is, and none adds a module. Each task writes its failing check into the self-check file that already covers the script, sees it fail, then makes the smallest change that passes. The tasks do not depend on each other except where a task says so, and the four stages run in order of what a fault costs.

**Tech Stack:** bash 3.2 and zsh (`bin/`, `setup/`, `tilde/.zshrc`), Python 3.11+ standard library (`settings/src/dotfiles_settings`), Swift 6 with Swift Testing (`app/`), mise 2026.11.8, pnpm, Renovate, GitHub Actions.

**Spec:** [`docs/superpowers/specs/2026-11-16-project-audit.md`](../specs/2026-11-16-project-audit.md). Finding ids (A1, C3) are its ids. Read its "Owner's decisions" before starting. Task 5 needs the owner's word, and Task 8 assumes a yes to decision 6.

## Global Constraints

- The gate is `pnpm check`. Every task ends with it passing. Edit and commit in separate Bash calls.
- One commit per task on `main`, with the subject the task names. Subjects are short, imperative, sentence case, with no conventional-commit prefix. `CLAUDE.md`'s standing approval covers the commit and the push.
- A change to a command's behaviour carries its doc edit in the same commit (`CLAUDE.md`, "Docs mirror behavior").
- Never run on this Mac: `sysup`, `./setup.sh`, `set-defaults`, `rotm install`, `rotm update`, `rotm settings sync …`, `claude -p` or the built app. Tests use scratch homes and stubs, as the files they join already do.
- No new test file. Every case joins an existing file, so the lists in `bin/lib/check` do not change.
- A failing check must never write into this repository. Tasks 6 and 7 point the script at a fixture folder for that reason. Keep it.
- The standard-library tests run as `mise exec python -- python3 settings/tests/<file>` and print `ok` last. The shell self-checks run as `bash bin/lib/<name>` or `bash setup/tests/<name>.sh`.
- Line numbers are those of `main` at `f56b558`.
- `CLAUDE.md` is capped at 12,000 bytes and each `.claude/rules/*.md` at 6,000 (`bin/lib/test-conventions:210-212`). `CLAUDE.md` has 2 bytes left and `.claude/rules/setup.md` has 4. Only Task 24 edits `CLAUDE.md`. No task edits `setup.md`.
- Tasks 1 to 4 are the audit's "fix first" group. Do them before anything else.

## Decided while writing this plan

Each is a default the owner can change before the task starts.

- **A3 deletes the `git prune` line.** Git's own `gc` already prunes unreachable objects after two weeks. The other option was `git gc --prune=2.weeks.ago`, which adds a slow step for the same result.
- **B4 is a docs fix.** `mise use --path ~/.config/mise/config.local.toml <tool>` writes the gitignored local file (ran as a dry run on 2026-11-16). `mise use -g -e local` was tried and writes `~/mise.local.toml`, which is the wrong file. `MISE_GLOBAL_CONFIG_FILE` is ruled out by the spec.
- **C1 uses `main` as the compare base.** That is what `push` already falls back to on every run, since `get_parent` never existed. Working out a branch's real parent is not attempted.
- **C6 changes the seed only.** `~/.gitconfig` on an installed copy is written once and is then the user's file, so a Mac that already has it keeps the double include. Task 13 gives the one-line hand fix.
- **C9 flips the default, and keeps the question.** When the folder already holds settings the prompt says so and defaults to no. Skipping the question was the other option. It was not chosen because nobody has checked whether setup leaves a file in that folder before the question on a new Mac.
- **Not planned.** The spec's section G lists six items with the reason each waits. Section E's decisions 1 to 5 get a plan of their own once answered.

## Measured for this plan (2026-11-16, this Mac)

| Fact | How |
| --- | --- |
| A folder named `$(touch PWNED)` runs the command from the title hook | `zsh -i -c 'setopt \| grep promptsubst; _set_terminal_title'` in that folder printed `promptsubst` and created `PWNED` |
| `mise use --path` targets the gitignored local file | `mise use -n --path ~/.config/mise/config.local.toml hunk@latest` printed "would update ~/.config/mise/config.local.toml", and `git check-ignore` matches that path |
| `pnpm audit` reports one high advisory | `sharp <0.35.5`, path `.>avif>sharp` |
| `stable` has no rules | `gh api repos/jrmatherly/returnofthemac/rules/branches/stable` printed `[]` |
| uv 0.13.8 takes a relative `--exclude-newer` | `echo six \| uv pip compile - --exclude-newer "7 days"` resolved |

## Review Focus

Each line is a case the spec implies and a reader would hit. Its check is in the task named.

1. **A folder name holding `%` or a backtick.** `print -P` also expands `%n` and friends. The title must show the name as typed. Task 1.
2. **A Mac that already has the old link or the old wrapper.** A seeded file is written once, so a fix to the seed does not reach it. Task 8 tests the move from a link, and Task 13 gives a hand fix.
3. **`push` to a host that is not GitHub.** It must still print no URL and exit 0. Task 10.
4. **`pull` hitting a conflict with nothing stashed.** The rollback must abort the rebase and must not try to pop a stash. Task 11.
5. **`setup.sh -y` in a real terminal.** Task 15's change cannot be tested without a pty. It is checked by reading, and the task says so.

---

## Stage A. Fix first

### Task 1: Print the window title as text (A1, C5)

**Files:**
- Modify: `tilde/.zshrc:17-23`
- Test: `bin/lib/test-shell` (append before the last line)

**Interfaces:** None.

- [ ] **Step 1: Write the failing checks**

```bash
# The window title prints the folder name as text: $(...), a backtick or a % in it is never expanded
for name in '$(touch pwned)' '`touch pwned`' '%n'; do
  mkdir "$tmp/$name"
  title=$(cd "$tmp/$name" && user_zsh 'setopt promptsubst; _set_terminal_title')
  [ ! -e "$tmp/$name/pwned" ] || fail "window title: the folder name $name ran as a command"
  [[ $title == *"$name"* ]] || fail "window title: $name is not printed as it is"
done
# Over SSH the title names the host (zsh sets HOST, not HOSTNAME)
title=$(run_zsh SSH_CONNECTION='1 2 3 4' zsh -i -c '_set_terminal_title; print -rn -- "|$HOST"')
[[ $title == *" — ${title##*|}"* && -n ${title##*|} ]] || fail "window title: no host over SSH"
```

- [ ] **Step 2: Run it and see it fail**

Run: `bash bin/lib/test-shell`
Expected: `FAIL: window title: the folder name $(touch pwned) ran as a command`

- [ ] **Step 3: Change `_set_terminal_title` in `tilde/.zshrc`**

Print with `print -rn --` and no `-P`. Build the escape bytes with `$'\e]2;'` and `$'\a'`, write the dash as the literal character, and use `$HOST`.

- [ ] **Step 4: Run it and see it pass**

Run: `bash bin/lib/test-shell`
Expected: exit 0, no `FAIL` line.

- [ ] **Step 5: Commit**

Subject: `Print the window title as text, never as a prompt`

### Task 2: Keep the applied record when a replay write fails (A2)

**Files:**
- Modify: `settings/src/dotfiles_settings/sync.py:129-130`
- Test: `settings/tests/test_sync.py` (after `test_replay_retries_a_failed_reset`)

**Interfaces:** None.

- [ ] **Step 1: Write the failing test**

```python
def test_replay_keeps_the_applied_value_when_a_write_fails():
    clean()
    sync.record(setting("a.one"), "old")
    sync.tools_path().write_text('[tools]\n"a.one" = "new"\n')
    fake = Fake({"a.one": "old"}, fail={"a.one"})
    sync.replay([setting("a.one")], {"fake": fake})
    assert tools(sync.applied_path()) == {"a.one": "old"}
    sync.tools_path().write_text("[tools]\n")          # another Mac reset it
    fake.fail.clear(); fake.calls.clear()
    sync.replay([setting("a.one")], {"fake": fake})
    assert fake.calls == [("reset", "a.one")]
    assert tools(sync.applied_path()) == {}
```

- [ ] **Step 2: Run it and see it fail**

Run: `mise exec python -- python3 settings/tests/test_sync.py`
Expected: `AssertionError: test_replay_keeps_the_applied_value_when_a_write_fails`

- [ ] **Step 3: In `_replay`'s first `except SettingsError`, keep `applied[id]` in `done` when `id` is in `applied`**

Comment it as line 139 is commented: the tool still holds the old value.

- [ ] **Step 4: Run it and see it pass**

Run: `mise exec python -- python3 settings/tests/test_sync.py`
Expected: `ok`

- [ ] **Step 5: Commit**

Subject: `Keep a setting's applied record when its replay write fails`

### Task 3: Stop `git tidy` deleting dropped stashes (A3)

**Files:**
- Modify: `bin/git-tidy:23-25` (delete the three lines)
- Test: `bin/lib/test-bin:68`

**Interfaces:** None.

- [ ] **Step 1: Write the failing check**

Before the `git-tidy` call at line 68:

```bash
dropped=$(cd "$tmp/repo" && echo e >> top.txt && git stash -q && git rev-parse 'stash@{0}' && git stash drop -q)
```

After the three existing `git-tidy` checks:

```bash
check "a dropped stash is still recoverable" "git -C '$tmp/repo' cat-file -e '$dropped'"
```

- [ ] **Step 2: Run it and see it fail**

Run: `bash bin/lib/test-bin`
Expected: `FAIL a dropped stash is still recoverable`

- [ ] **Step 3: Delete the "Deleting unreachable objects" header and `git prune` from `bin/git-tidy`**

- [ ] **Step 4: Run it and see it pass**

Run: `bash bin/lib/test-bin`
Expected: every line starts `ok`.

- [ ] **Step 5: Commit**

Subject: `Leave unreachable objects to git's own gc in git tidy`

### Task 4: Move `sharp` past its advisory (A4)

**Files:**
- Modify: `pnpm-lock.yaml`, `renovate.json`

**Interfaces:** None.

- [ ] **Step 1: See the advisory**

Run: `pnpm audit`
Expected: `1 vulnerabilities found`, `Severity: 1 high`, package `sharp`.

- [ ] **Step 2: Update the transitive package**

Run: `pnpm update sharp --depth Infinity`
Then: `pnpm why sharp`
Expected: `sharp 0.35.5` or later, and `git diff --stat` names only `pnpm-lock.yaml`.

- [ ] **Step 3: Let Renovate refresh the lockfile from now on**

Add `"lockFileMaintenance": { "enabled": true }` to `renovate.json`, after `minimumReleaseAge`.

- [ ] **Step 4: Verify**

Run: `pnpm audit`
Expected: `No known vulnerabilities found`
Run: `pnpm install --frozen-lockfile`
Expected: exit 0, so the lockfile still matches `package.json`.

- [ ] **Step 5: Commit**

Subject: `Update sharp past GHSA-wq5f-xc86-pv6w and refresh the lockfile weekly`

### Task 5: Protect `stable` and tighten the repository settings (A5, D3, D8)

Every step changes GitHub, not the repository. **Do none of them without the owner's word for that step.** State the command and wait.

**Files:** None.

**Interfaces:** None.

- [ ] **Step 1: Add a ruleset on `stable`**

```bash
gh api repos/jrmatherly/returnofthemac/rulesets -X POST --input - <<'JSON'
{"name":"stable: no force-push or delete","target":"branch","enforcement":"active",
 "conditions":{"ref_name":{"include":["refs/heads/stable"],"exclude":[]}},
 "rules":[{"type":"deletion"},{"type":"non_fast_forward"}]}
JSON
```

Verify: `gh api repos/jrmatherly/returnofthemac/rules/branches/stable --jq '.[].type'` prints `deletion` and `non_fast_forward`. A promotion is a plain fast-forward push (`setup/README.md:88`), so it still works.

- [ ] **Step 2: Require SHA-pinned actions**

Run: `gh api -X PUT repos/jrmatherly/returnofthemac/actions/permissions -F enabled=true -f allowed_actions=all -F sha_pinning_required=true`
Verify: `gh api repos/jrmatherly/returnofthemac/actions/permissions` shows `"sha_pinning_required":true`.

- [ ] **Step 3: Turn vulnerability alerts on**

Run: `gh api -X PUT repos/jrmatherly/returnofthemac/vulnerability-alerts`
Verify: `gh api -i repos/jrmatherly/returnofthemac/vulnerability-alerts` answers `204`.

- [ ] **Step 4: Run the fresh-install workflow once**

Run: `gh workflow run fresh-install.yml --ref main`
Verify: `gh run list --workflow fresh-install --limit 1` shows `success` on the current `main` commit. Record the run id in the spec's D3 row.

---

## Stage B. Keep writes out of an installed copy

### Task 6: Refuse `obsidian-vault capture` on an installed copy (B1)

**Files:**
- Modify: `bin/obsidian-vault:72` (top of `capture()`), and its header comment
- Modify: `docs/README.md` (the `obsidian-vault` row)
- Test: `bin/lib/test-bin`

**Interfaces:** None.

- [ ] **Step 1: Write the failing checks**

The fixture stands in for the repository, so a missing guard writes into `$tmp` and never here.

```bash
fix="$tmp/fix"
mkdir -p "$fix/obsidian" "$tmp/data" "$tmp/vault/.obsidian"
git init -q "$fix"
echo '{}' > "$tmp/vault/.obsidian/app.json"
ln -s "$fix" "$tmp/data/bootstrap-repo"
DOTFILES="$fix" MISE_DATA_DIR="$tmp/data" OBSIDIAN_VAULT="$tmp/vault" "$root/bin/obsidian-vault" capture > "$tmp/cap.out" 2>&1
check "capture refuses an installed copy" "[ $? -ne 0 ] && grep -q 'installed copy' '$tmp/cap.out'"
check "capture wrote nothing into it" "[ ! -e '$fix/obsidian/.obsidian' ]"
DOTFILES="$fix" MISE_DATA_DIR="$tmp/none" OBSIDIAN_VAULT="$tmp/vault" "$root/bin/obsidian-vault" capture > /dev/null 2>&1
check "capture still writes into a clone" "[ -f '$fix/obsidian/.obsidian/app.json' ]"
```

- [ ] **Step 2: Run it and see it fail**

Run: `bash bin/lib/test-bin`
Expected: `FAIL capture refuses an installed copy`

- [ ] **Step 3: Add the guard at the top of `capture()`**

When `"$(dirname "$0")/lib/rotm-mode" "$DOTFILES"` prints `installed`, write this to stderr and exit 1: `obsidian-vault: capture writes into the repository, and this is an installed copy. Run it from a clone (docs/forking.md).` Add one sentence to the header and to the docs row saying capture needs a clone.

- [ ] **Step 4: Run it and see it pass**

Run: `bash bin/lib/test-bin && help obsidian-vault`
Expected: every line `ok`, and the rendered header shows the new sentence.

- [ ] **Step 5: Commit**

Subject: `Refuse obsidian-vault capture on an installed copy`

### Task 7: Refuse `claude-config save` on an installed copy (B2)

**Files:**
- Modify: `bin/claude-config:380` (the `save)` case), and its header comment
- Modify: `docs/claude-config.md:16`
- Test: `bin/lib/test-claude-config`

**Interfaces:** None.

- [ ] **Step 1: Write the failing checks**

```bash
fix="$tmp/fix"
mkdir -p "$fix" "$tmp/data"
ln -s "$fix" "$tmp/data/bootstrap-repo"
env -u CLAUDE_CONFIG_SAVE_DIR DOTFILES_DIR="$fix" MISE_DATA_DIR="$tmp/data" "$script" save > "$tmp/save.out" 2>&1
check "save refuses an installed copy" "[ $? -ne 0 ] && grep -q 'installed copy' '$tmp/save.out'"
check "save wrote nothing into it" "[ ! -e '$fix/agents' ]"
```

The file's other `save` cases all set `CLAUDE_CONFIG_SAVE_DIR`, and they are the proof that a named folder is still written.

- [ ] **Step 2: Run it and see it fail**

Run: `bash bin/lib/test-claude-config`
Expected: `FAIL save refuses an installed copy`, under both bash versions.

- [ ] **Step 3: Add the guard as the first line of the `save)` case**

Refuse only when `CLAUDE_CONFIG_SAVE_DIR` is unset and `"$(dirname "$0")/lib/rotm-mode" "$DOTFILES_DIR"` prints `installed`. Message, to stderr, exit 1: `claude-config: save writes agents/ in the repository, and this is an installed copy. Run it from a clone, or set CLAUDE_CONFIG_SAVE_DIR.` Say the same in the header and in `docs/claude-config.md`.

- [ ] **Step 4: Run it and see it pass**

Run: `bash bin/lib/test-claude-config && bash bin/lib/test-sysup`
Expected: no `FAIL` line in either.

- [ ] **Step 5: Commit**

Subject: `Refuse claude-config save on an installed copy`

### Task 8: Seed the Mole whitelists on an installed copy (B3)

Assumes a yes to the spec's decision 6. If the owner says no, skip this task and record that in the spec.

**Files:**
- Modify: `tilde/.config/mise/config.rotm-installed.toml` (two entries)
- Modify: `docs/mole.md:113-115`
- Test: `bin/lib/test-dotfiles:260`

**Interfaces:** None.

- [ ] **Step 1: Write the failing checks**

After the `~/.config/gh` check in the installed block:

```bash
for f in whitelist whitelist_optimize; do
  [ ! -L "$home/.config/mole/$f" ] && cmp -s "$home/.config/mole/$f" "$repo/mole/$f" || fail "installed: ~/.config/mole/$f is not a seeded copy"
done
```

Then one migration case, in the style of the file's existing one for `~/.claude/rules`. Apply the base config to a fresh scratch home so both whitelists are links, apply again with `MISE_ENV=rotm-installed`, and fail unless each is a regular file with the tracked content.

- [ ] **Step 2: Run it and see it fail**

Run: `bash bin/lib/test-dotfiles`
Expected: `FAIL: installed: ~/.config/mole/whitelist is not a seeded copy`

- [ ] **Step 3: Add the two entries to `config.rotm-installed.toml`**

```toml
# Mole's own editors (mo clean --whitelist) rewrite these files
"~/.config/mole/whitelist" = { source = "~/dotfiles/mole/whitelist", mode = "copy", create_if_missing = true }
"~/.config/mole/whitelist_optimize" = { source = "~/dotfiles/mole/whitelist_optimize", mode = "copy", create_if_missing = true }
```

- [ ] **Step 4: Run it and see both cases pass**

Run: `bash bin/lib/test-dotfiles`
Expected: exit 0. If the migration case fails because mise will not replace a link with a copy, stop and tell the owner. Do not add `--force`.

- [ ] **Step 5: Rewrite `docs/mole.md:115`**

Say that on an installed copy the two files are the user's own copies, seeded once, that Mole's editors are safe there, and that a later change to the shared list does not reach them.

- [ ] **Step 6: Commit**

Subject: `Seed Mole's whitelists on an installed copy`

### Task 9: Say where a global mise tool goes on an installed copy (B4)

**Files:**
- Modify: `docs/README.md:105`

**Interfaces:** None.

- [ ] **Step 1: Rewrite the row**

Keep the project sentence. Replace the global sentence with two. In a clone, reorder the version list in `tilde/.config/mise/config.toml`. On an installed copy, never edit that file or run `mise use -g`, both of which stop `rotm update`, and run `mise use --path ~/.config/mise/config.local.toml {{tool}}@{{version}}`.

- [ ] **Step 2: Verify the command the row names**

Run: `cd ~ && mise use -n --path ~/.config/mise/config.local.toml node@24`
Expected: `mise would update ~/.config/mise/config.local.toml`

- [ ] **Step 3: Commit**

Subject: `Document where a global mise tool goes on an installed copy`

---

## Stage C. Small broken behaviours

Tasks 10 to 12 all add to `bin/lib/test-bin`, after the `git-tidy` checks. Run them in order so each finds the fixture the one before left.

### Task 10: Fix `push`'s missing function and its compare URL (C1, C2)

**Files:**
- Modify: `bin/push:66-87`
- Test: `bin/lib/test-bin`

**Interfaces:**
- Produces: `$tmp/origin.git`, a bare remote named `origin` on `$tmp/repo`, which Task 11 uses.

- [ ] **Step 1: Write the failing checks**

A `git` stub answers only `remote get-url --push`, so the push itself goes to a local bare repository. A `gh` stub keeps the network out.

```bash
mkdir "$tmp/stub"
printf '#!/bin/bash\nif [ "$1 $2 $3" = "remote get-url --push" ]; then echo "$PUSH_URL"; exit 0; fi\nexec %q "$@"\n' "$(command -v git)" > "$tmp/stub/git"
printf '#!/bin/sh\nexit 1\n' > "$tmp/stub/gh"
chmod +x "$tmp/stub/git" "$tmp/stub/gh"
git init -q --bare -b main "$tmp/origin.git"
git -C "$tmp/repo" remote add origin "$tmp/origin.git"
n=0
for u in git@github.com:o/r.git git@github.com:o/r ssh://git@github.com/o/r.git https://github.com/o/r.git; do
  n=$((n + 1))
  git -C "$tmp/repo" checkout -qb "feat$n" main
  (cd "$tmp/repo" && PATH="$tmp/stub:$PATH" PUSH_URL=$u "$root/bin/push") > "$tmp/push.out" 2>&1
  check "push $u: compare URL" "[ \"\$(tail -1 '$tmp/push.out')\" = https://github.com/o/r/compare/main...feat$n ]"
  check "push $u: no missing command" "! grep -q 'command not found' '$tmp/push.out'"
done
git -C "$tmp/repo" checkout -qb feat-lab main
(cd "$tmp/repo" && PATH="$tmp/stub:$PATH" PUSH_URL=https://gitlab.com/o/r.git "$root/bin/push") > "$tmp/push.out" 2>&1
check "push to another host: exits 0 and prints no URL" "[ $? -eq 0 ] && ! grep -q '^https://' '$tmp/push.out'"
git -C "$tmp/repo" checkout -q main
```

- [ ] **Step 2: Run it and see it fail**

Run: `bash bin/lib/test-bin`
Expected: `FAIL push git@github.com:o/r.git: no missing command`, and `FAIL` on the compare URL of the second and third remotes.

- [ ] **Step 3: Change `bin/push`**

Replace the `get_parent` call with `refs="main...$branch"`. Replace the two `regEx` branches with one `sed -E` that strips a leading `git@github.com:`, `ssh://git@github.com/` or `https://github.com/` and a trailing `.git`, and set `url='https://github.com/'` for every GitHub remote.

- [ ] **Step 4: Run it and see it pass**

Run: `bash bin/lib/test-bin`
Expected: every line `ok`.

- [ ] **Step 5: Commit**

Subject: `Build push's compare URL for every GitHub remote form`

### Task 11: Abort the rebase when `pull` rolls back (C3)

**Files:**
- Modify: `bin/pull:35-40`
- Test: `bin/lib/test-bin`

**Interfaces:**
- Consumes: `$tmp/origin.git` and the `origin` remote from Task 10.

- [ ] **Step 1: Write the failing checks**

```bash
git -C "$tmp/repo" push -q origin main
git clone -q "$tmp/origin.git" "$tmp/other"
(cd "$tmp/other" && echo theirs > top.txt && git commit -qam theirs && git push -q origin main)
(cd "$tmp/repo" && echo ours > top.txt && git commit -qam ours && echo dirty > untracked.txt)
(cd "$tmp/repo" && "$root/bin/pull") > "$tmp/pull.out" 2>&1
check "pull on a conflict: exits non-zero" "[ $? -ne 0 ]"
check "pull on a conflict: no rebase left behind" "[ ! -d '$tmp/repo/.git/rebase-merge' ]"
check "pull on a conflict: the stash is restored" "[ -z \"\$(git -C '$tmp/repo' stash list)\" ] && [ -f '$tmp/repo/untracked.txt' ]"
rm "$tmp/repo/untracked.txt"
(cd "$tmp/repo" && "$root/bin/pull") > "$tmp/pull.out" 2>&1
check "pull on a conflict with nothing stashed: no rebase, no stash pop" "[ ! -d '$tmp/repo/.git/rebase-merge' ] && ! grep -q 'Restoring tree' '$tmp/pull.out'"
```

- [ ] **Step 2: Run it and see it fail**

Run: `bash bin/lib/test-bin`
Expected: `FAIL pull on a conflict: no rebase left behind`

- [ ] **Step 3: In `rollback()`, run `git rebase --abort 2> /dev/null` before `unstash`**

- [ ] **Step 4: Run it and see it pass**

Run: `bash bin/lib/test-bin`
Expected: every line `ok`.

- [ ] **Step 5: Commit**

Subject: `Abort the rebase when pull rolls back`

### Task 12: Delete only folders in `node-modules-clean` (C4)

**Files:**
- Modify: `bin/node-modules-clean:14`
- Test: `bin/lib/test-bin`

**Interfaces:** None.

- [ ] **Step 1: Write the failing checks**

```bash
mkdir -p "$tmp/nm/a/node_modules/x/node_modules" "$tmp/nm/b"
: > "$tmp/nm/b/node_modules"
(cd "$tmp/nm" && "$root/bin/node-modules-clean")
check "node-modules-clean removes the folder" "[ ! -e '$tmp/nm/a/node_modules' ]"
check "node-modules-clean keeps a plain file of that name" "[ -f '$tmp/nm/b/node_modules' ]"
```

- [ ] **Step 2: Run it and see it fail**

Run: `bash bin/lib/test-bin`
Expected: `FAIL node-modules-clean keeps a plain file of that name`

- [ ] **Step 3: Change the line to `find . -type d -name node_modules -prune -exec rm -rf '{}' +`**

- [ ] **Step 4: Run it and see it pass**

Run: `bash bin/lib/test-bin`
Expected: every line `ok`.

- [ ] **Step 5: Commit**

Subject: `Delete only folders in node-modules-clean`

### Task 13: Read `~/.gitconfig.local` once on an installed copy (C6)

**Files:**
- Modify: `tilde/.gitconfig.installed:5-6` (delete the second include)
- Test: `bin/lib/test-dotfiles:260`

**Interfaces:** None.

- [ ] **Step 1: Write the failing check**

After the `core.excludesfile` check in the installed block:

```bash
printf '[x]\n  y = 1\n' > "$home/.gitconfig.local"
[ "$(HOME="$home" git config --file "$home/.gitconfig" --includes --get-all x.y | wc -l | tr -d ' ')" = 1 ] \
  || fail "installed: ~/.gitconfig.local is read more than once"
```

- [ ] **Step 2: Run it and see it fail**

Run: `bash bin/lib/test-dotfiles`
Expected: `FAIL: installed: ~/.gitconfig.local is read more than once`

- [ ] **Step 3: Delete the second `[include]` from `tilde/.gitconfig.installed`**

`tilde/.gitconfig:269-270` already includes the file.

- [ ] **Step 4: Run it and see it pass**

Run: `bash bin/lib/test-dotfiles`
Expected: exit 0.

- [ ] **Step 5: Commit, then tell the owner the hand fix**

Subject: `Read ~/.gitconfig.local once on an installed copy`

A Mac that already has the wrapper keeps the old one. Tell the owner to delete the last two lines of `~/.gitconfig` on this Mac. Do not edit it yourself.

### Task 14: Let git verify SSH-signed commits (C7)

**Files:**
- Modify: `setup/dotfiles-extras.sh:118-148`
- Modify: `setup/README.md` (the git identity step)
- Test: `setup/tests/dotfiles-extras.sh:99`

**Interfaces:** None.

- [ ] **Step 1: Write the failing checks**

After the "ssh signing written" check:

```bash
check "ssh signing: git is told where the allowed signers are" "grep -qx '  allowedSignersFile = ~/.config/git/allowed_signers' '$h/.gitconfig.local'"
check "ssh signing: the key is an allowed signer" "grep -qx 'a@b.c ssh-ed25519 AAAA' '$h/.config/git/allowed_signers'"
```

After the "no signing lines" check at line 91:

```bash
check "ssh signing without 1Password: no allowed signers file" "[ ! -e '$h0/.config/git/allowed_signers' ]"
```

- [ ] **Step 2: Run it and see it fail**

Run: `bash setup/tests/dotfiles-extras.sh`
Expected: `FAIL ssh signing: git is told where the allowed signers are`

- [ ] **Step 3: In the `ssh)` branch, write the file and name it**

Write `$email $signing_key` as one line to `$HOME/.config/git/allowed_signers`, creating the folder, and add `  allowedSignersFile = ~/.config/git/allowed_signers` under `[gpg "ssh"]`. An existing `~/.gitconfig.local` is still kept as it is.

- [ ] **Step 4: Run it and see it pass**

Run: `bash setup/tests/dotfiles-extras.sh`
Expected: every line `ok`.

- [ ] **Step 5: Commit, then tell the owner the hand fix**

Subject: `Write an allowed signers file with SSH commit signing`

This Mac's `~/.gitconfig.local` exists, so setup will not rewrite it. Give the owner these two lines to run, and the check:

```bash
mkdir -p ~/.config/git && printf '%s %s\n' "$(git config user.email)" "$(git config user.signingkey)" > ~/.config/git/allowed_signers
```

```bash
git config --file ~/.gitconfig.local gpg.ssh.allowedSignersFile '~/.config/git/allowed_signers'
```

Check: `git log -1 --format=%G?` prints `G`.

### Task 15: Skip the Aspire certificate prompt under `-y` (C8)

**Files:**
- Modify: `setup/misc.sh:428`
- Modify: `docs/installation.md` (the row near line 120 that lists what `-y` still asks)

**Interfaces:**
- Consumes: `asks()` at `setup/misc.sh:75`, which is true only in a terminal with `DOTFILES_YES` unset.

- [ ] **Step 1: Change `elif [ -t 0 ]; then` to `elif asks; then`**

The `else` branch already prints the command to run later.

- [ ] **Step 2: Verify**

Run: `bash bin/lib/test-bootstrap`
Expected: exit 0. No check can tell the two forms apart without a pty, since both are false there. Confirm the change by reading the line, and say in the commit body that it is untested.

- [ ] **Step 3: Commit**

Subject: `Skip the Aspire certificate prompt under setup -y`

### Task 16: Default "Load your saved settings" to no when settings are already here (C9)

**Files:**
- Modify: `setup.sh:526-528`
- Modify: `docs/settings-sync.md` (the paragraph on a new Mac's first setup)
- Test: `bin/lib/test-bootstrap` (after the `saved:` cases that start near line 586)

**Interfaces:** None.

- [ ] **Step 1: Write the failing checks**

One case in the file's own style. Its `prepare` stubs `gh` with `$saved` and puts one file, `tools.toml`, in the folder that `rotm-user-layer dir` prints for the fixture. Run with `answers='\n'`.

```bash
check_true "saved, settings already here: says so" has 'already holds settings'
check_true "saved, settings already here: Return does not restore" restores 0
```

A second run with `answers='y\n'` and `check_true "saved, settings already here: yes still restores" restores 1`.

- [ ] **Step 2: Run it and see it fail**

Run: `bash bin/lib/test-bootstrap`
Expected: `saved, settings already here: says so` fails.

- [ ] **Step 3: Change the question in `load_saved_settings`**

Read `folder` before the question. When it holds a regular file other than `modules-off.local` and `.DS_Store`, ask `This Mac already holds settings in $folder, so loading can conflict. Load your saved settings from $repo anyway? [y/N] ` and treat anything but `y` or `Y` as no. Otherwise ask the present question unchanged.

- [ ] **Step 4: Run it and see it pass**

Run: `bash bin/lib/test-bootstrap`
Expected: exit 0. The existing `saved:` cases still pass, which is the proof that a new Mac is asked as before.

- [ ] **Step 5: Commit**

Subject: `Default to no when loading saved settings over existing ones`

### Task 17: Refuse wrong-shape settings files in one line (C10, C11)

**Files:**
- Modify: `settings/src/dotfiles_settings/sync.py:26-30`
- Modify: `settings/src/dotfiles_settings/adapters/tool.py:89, 98, 127`
- Test: `settings/tests/test_sync.py`, `settings/tests/test_tool.py`

**Interfaces:**
- Produces: `_opt_in_paths(config: dict) -> list[str]` in `adapters/tool.py`. It returns `config["optInPaths"]` when that is a list of `str`, and `[]` otherwise.

- [ ] **Step 1: Write the failing tests**

In `test_sync.py`, after `test_a_broken_tools_file_is_a_settings_error`:

```python
def test_a_wrong_shape_tools_file_is_a_settings_error():
    for text in ('tools = "x"\n', '[tools]\n"a.one" = 1\n'):
        clean()
        sync.user_dir().mkdir(parents=True, exist_ok=True)
        sync.tools_path().write_text(text)
        try:
            sync.replay([setting("a.one")], {"fake": Fake({})})
        except SettingsError as e:
            assert str(sync.tools_path()) in str(e)
        else:
            raise AssertionError(f"no error for {text!r}")
```

In `test_tool.py`, after `test_claude_model_seed_and_drift` and `test_hindsight_paths_add_then_remove`:

```python
def test_claude_model_ignores_a_value_that_is_not_text():
    live.write_text('{"model": 3}'); tracked_settings.write_text('{"model": "opus"}')
    v = A.read(by_id("claude.model"))
    assert (v.value, v.source, v.seed) == (None, Source.UNSET, "opus")


def test_hindsight_paths_ignore_a_wrong_shape():
    for bad in ('"~/dev"', "[1]"):
        cfg.write_text('{"optInPaths": %s}' % bad)
        assert A.read(by_id("hindsight.paths")).value == ""
```

- [ ] **Step 2: Run them and see them fail**

Run: `mise exec python -- python3 settings/tests/test_sync.py; mise exec python -- python3 settings/tests/test_tool.py`
Expected: a `TypeError` or `AttributeError` traceback from the first, an `AssertionError` from the second.

- [ ] **Step 3: Implement**

`_parse` raises `SettingsError(f"{path}: [tools] must be a table of text values")` unless `tools` is a `dict` whose keys and values are all `str`. `_json_model` returns the model only when it is a `str`. Both readers of `optInPaths` go through `_opt_in_paths`.

- [ ] **Step 4: Run them and see them pass**

Run: the two commands of Step 2, then `mise exec python -- python3 settings/tests/test_cli.py`
Expected: `ok` three times.

- [ ] **Step 5: Commit**

Subject: `Report a wrong-shape settings file in one line`

### Task 18: Correct three messages (C12)

Copy only, so no test.

**Files:**
- Modify: `setup/dash.sh:158`, `bin/optimize-image:42`, `bin/wg` (header comment)

**Interfaces:** None.

- [ ] **Step 1: Edit the three lines**

- `setup/dash.sh:158`: keep `restore it with git checkout` when `dash_dir` is the repository's `dash` folder. Otherwise print `delete it and run this again to start from the shipped one`. Lines 27 to 30 already copy the shipped file when it is missing.
- `bin/optimize-image:42`: `avif is not installed: run pnpm install in $DOTFILES`.
- `bin/wg`: one header sentence saying a file that lacked a final newline gains one.

- [ ] **Step 2: Verify**

Run: `bash setup/tests/dash.sh && help wg`
Expected: exit 0, and the new sentence in the rendered page.

- [ ] **Step 3: Commit**

Subject: `Correct three hints that named the wrong command`

---

## Stage D. CI, the app and the docs

### Task 19: Stop Renovate raising mise in `check.yml` alone (D1)

**Files:**
- Modify: `renovate.json` (one `packageRules` entry)

**Interfaces:** None.

- [ ] **Step 1: Add the rule**

```json
{
  "description": "check.yml pins mise to the floor in setup/mise-floor.sh, and bin/lib/test-override-env fails when they differ. Raise both by hand in one commit",
  "matchManagers": ["github-actions"],
  "matchDepNames": ["jdx/mise"],
  "enabled": false
}
```

- [ ] **Step 2: Verify**

Run: `pnpm check`
Expected: exit 0. After the push, the Dependency Dashboard (`gh issue view 4`) stops listing an update for `jdx/mise`. Renovate refreshes it within a few hours, so record the check in the commit body as pending if it has not refreshed.

- [ ] **Step 3: Commit**

Subject: `Leave the mise floor in check.yml to a hand edit`

### Task 20: Cut the Python download and the second app build from CI (D4, D5)

**Files:**
- Modify: `.github/workflows/check.yml:36, 83-84`

**Interfaces:** None.

- [ ] **Step 1: Find a cached Python**

Read the `macos-26` image's Readme in `actions/runner-images`, section "Cached Tools", and take the newest Python listed that is 3.11 or later. If none is listed, leave line 36 alone and say so.

- [ ] **Step 2: Edit the workflow**

Set `python-version` to that version. Delete the `bash app/scripts/build-app.sh` step and its comment at lines 83 and 84, since `pnpm check` runs `bin/lib/test-app-build`.

- [ ] **Step 3: Verify**

Run: `pnpm check`, commit, push, then `gh run watch`.
Expected: the run passes, the `setup-python` step's log has no "was not found in the local cache" line, and that step takes under 10 seconds (`gh run view <id> --json jobs`).

- [ ] **Step 4: Commit**

Subject: `Use a cached Python in CI and build the app once`

### Task 21: Run one app-update check at a time (D7)

**Files:**
- Modify: `app/Sources/RotmCore/AppState.swift:99-106`
- Test: `app/Tests/RotmCoreTests/AppUpdateTests.swift`

**Interfaces:** None. `checkAppUpdate`'s signature does not change.

- [ ] **Step 1: Write the failing test**

Build `state` as the neighbouring tests do.

```swift
@Test func twoChecksAtOnceFetchOnce() async {
  let fetched = FetchCount()
  let fetch: (URL) async throws -> String = { _ in
    fetched.count += 1
    await Task.yield()
    return "  version \"0.2.0\"\n"
  }
  async let a: Void = state.checkAppUpdate(fetch: fetch, current: "0.1.0", installed: { true })
  async let b: Void = state.checkAppUpdate(fetch: fetch, current: "0.1.0", installed: { true })
  _ = await (a, b)
  #expect(fetched.count == 1)
  #expect(state.appUpdate == "0.2.0")
}
```

- [ ] **Step 2: Run it and see it fail**

Run: `swift test --package-path app --filter AppUpdateTests`
Expected: `fetched.count == 1` fails with 2.

- [ ] **Step 3: Add `private var checkingApp = false` to `AppState` and return early while it is set**

Set it before the fetch and clear it with `defer`. Do not move `appCheckedAt` before the fetch, or a failed fetch would block the next try for a day.

- [ ] **Step 4: Run it and see it pass**

Run: `swift test --package-path app --filter AppUpdateTests`
Expected: all pass.

- [ ] **Step 5: Commit**

Subject: `Run one app update check at a time`

### Task 22: Write `miserc.local.toml` atomically (spec section G)

**Files:**
- Modify: `settings/src/dotfiles_settings/profile.py:129`

**Interfaces:**
- Consumes: `edit_file(path: Path, change: Callable[[str], str]) -> None` from `adapters/tool.py`, which writes a temp file and replaces.

- [ ] **Step 1: Replace `path.write_text(left)` with `edit_file(path, lambda _: left)`**

Import it inside the function if a top-level import makes a cycle, as `sync._save` does. Line 95 writes a modules-off file, not the miserc, and stays as it is.

- [ ] **Step 2: Verify**

Run: `mise exec python -- python3 settings/tests/test_profile.py && bash bin/lib/test-profiles`
Expected: `ok`, then exit 0. A crash mid-write is not tested. The existing cases prove the text written is unchanged.

- [ ] **Step 3: Commit**

Subject: `Write the profile's miserc file atomically`

### Task 23: Find why the console stop test is flaky (D2)

A diagnosis, not a fix. The deliverable is a paragraph in the spec's D2 row.

**Files:**
- Modify: `docs/superpowers/specs/2026-11-16-project-audit.md` (row D2)

**Interfaces:** None.

- [ ] **Step 1: Measure**

Run the full suite ten times and keep each result: `for i in $(seq 10); do swift test --package-path app 2>&1 | grep -E 'stopEndsACommand|Test run' ; done`
Record how many of the ten fail and each run's time for that test.

- [ ] **Step 2: Run the test alone ten times**

Run: `swift test --package-path app --filter stopEndsACommandThatIgnoresTheInterrupt`, ten times.
Record the same two numbers.

- [ ] **Step 3: Write the finding**

If it fails only in full runs, the cause to name is the `DispatchQueue.main.asyncAfter` at `ConsoleSession.swift:144`, which waits behind other main-queue work. Say whether the measurements support that. If it never fails in twenty runs, say so and close the row as not reproduced. Do not change the 10 second bound in this task.

- [ ] **Step 4: Commit**

Subject: `Record the console stop test's flake measurements`

### Task 24: Bring `CLAUDE.md` and the plans index up to date (D6)

Run last, since it records the other tasks.

**Files:**
- Modify: `CLAUDE.md:26, 47, 77`
- Modify: `docs/superpowers/plans/README.md`

**Interfaces:** None.

- [ ] **Step 1: Edit `CLAUDE.md`, three replacements**

- Line 26: replace ``Flags: `-y`, `--skip-codegraph`, `--dash`, `-h`, `-- <mise args>`.`` with ``Flags: `./setup.sh --help`.``
- Line 47: append ``; app-release.yml = the signed app build on `app-v*` tags``
- Line 77: replace the bullet with `- Output helpers are defined inline per script. No shared shell library is sourced.`

- [ ] **Step 2: Verify the cap**

Run: `wc -c CLAUDE.md && bash bin/lib/test-conventions`
Expected: 12,000 bytes or fewer, and exit 0.

- [ ] **Step 3: Update `docs/superpowers/plans/README.md`**

In "Found while running them", strike the `obsidian-vault capture`, Mole, "Load your saved settings" and `dash.sh` bullets, naming each fixing commit. Close the `MISE_ENV=rotm-installed` bullet with the measurement from the spec's section F. Leave the `sync on` and `--accept` bullets open.

- [ ] **Step 4: Commit**

Subject: `Name every setup flag and workflow in CLAUDE.md and close five open items`

- [ ] **Step 5: File the plan**

Add an "Outcome" table to this plan with each task's commit and any difference from the plan. Move this file to `plans/completed/`. Move the spec to `specs/completed/` only once section E's decisions are answered or have a plan of their own. Remove this plan's row from the README's "Open plans" table.
