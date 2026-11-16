# A 48 hour release hold and a Claude Multipass module, Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the two answered decisions of the 2026-11-16 audit that still need code: every package manager this repository drives holds a new release for 48 hours, and Claude Multipass leaves the base list for a module a fork can switch off.

**Architecture:** No new script and no new test file. One block in `bin/lib/test-conventions` pins the hold in every place it is written, and each task makes its own lines of that block pass. The module is one new `conf.d` fragment plus its name in the three places that list modules, and the existing package self-check proves nothing was lost in the move.

**Tech Stack:** bash 3.2, mise 2026.11.8, uv 0.13.8, pnpm 12, bun, npm, Renovate, Python 3.11+ standard library for the settings tests.

**Spec:** [`docs/superpowers/specs/2026-11-16-project-audit.md`](../specs/2026-11-16-project-audit.md), section "Owner's decisions", decisions 1 and 4. Read that section in full before starting. Decisions 2 and 3 are "leave as is" and decision 5 is done, so this plan is the last one the spec waits for.

## Global Constraints

- The gate is `pnpm check`. Every task ends with it passing. Edit and commit in separate Bash calls.
- One commit per task on `main`, with the subject the task names. `CLAUDE.md`'s standing approval covers the commit and the push.
- A change to setup behaviour carries its doc edit in the same commit (`CLAUDE.md`, "Docs mirror behavior").
- Never run on this Mac: `sysup`, `./setup.sh`, `set-defaults`, `rotm install`, `rotm update`, `uv tool install` or `uv tool upgrade` against the real tool folder, `mise bootstrap packages apply`, `upgrade` or `prune`. Probes use scratch folders (`XDG_CONFIG_HOME`, `UV_TOOL_DIR`, `UV_TOOL_BIN_DIR`, `MISE_CONFIG_DIR`).
- No global uv configuration. Nothing in this plan writes `~/.config/uv/uv.toml` or tracks one. The owner ruled it out on 2026-11-16, because it changes every other uv project on the Mac (measured below).
- The hold is 48 hours in each manager's own unit: mise `"48h"`, pnpm `2880` (minutes), bun `172800` (seconds), npm `2` (days), Renovate `"2 days"`, uv `"48 hours"`.
- `CLAUDE.md` is capped at 12,000 bytes and is at 11,951. No task edits it.
- Line numbers are those of `main` at `c0c47a9`.

## Decided while writing this plan

Each is a default the owner can change before the task starts.

- **The module is named `multipass`** and sits after `menubar` in the module list. Its label in the settings UI is "Claude Multipass".
- **`brew:ruby` stays in the base.** The `menubar` module's cask needs it too, and `bin/lib/test-packages:112` already requires it there.
- **uv gets its hold in two places, neither of them global.** The two `uv tool install` lines take `--exclude-newer "48 hours"`, and the repository's two uv projects (`settings/`, `hindsight/`) take `[tool.uv] exclude-newer = "48 hours"` in their own `pyproject.toml`. A project file cannot hold a uv tool, and a flag cannot hold a project, so both are needed.
- **The project hold goes in each `pyproject.toml`, not one `uv.toml` at the repository root.** A root file was seen from `--project settings` when uv ran from the root, but `dotfiles-settings` runs from any folder, and that case was not measured. The per-project table is certain.
- **`sysup`'s upgrade carries the hold too.** `setup/misc.sh` installs each tool only when its binary is missing, so on a Mac that already has both, the install flag never runs. `uv tool upgrade --all --exclude-newer "48 hours"` applies the hold and writes it into the receipt of a tool installed without one (measured below), so there is no hand step.

## Measured for this plan (2026-11-16, this Mac, scratch folders only)

| Fact | How |
| --- | --- |
| A user-level `exclude-newer` makes uv reject every project's lockfile | With a scratch `XDG_CONFIG_HOME` holding `exclude-newer = "48 hours"`, `uv run --locked --project settings` printed "The lockfile at `uv.lock` needs to be updated", and a plain `uv lock` rewrote the file |
| A lockfile rewritten under the user-level file fails without it | The same file under an empty `XDG_CONFIG_HOME`: `uv lock --check` failed. CI and a fork have no such file |
| A project-level hold passes with and without a user-level file | `[tool.uv] exclude-newer = "48 hours"` in `settings/pyproject.toml`, `uv lock`, then `uv lock --check` under both |
| The project-level re-lock changes four lines and no version | `git diff` on both `uv.lock` files in a scratch clone: one `[options]` table with `exclude-newer-span = "PT48H"`, nothing else |
| A project config does not reach `uv tool install` | Run from a folder whose `uv.toml` had a 2023 cutoff, it installed ruff 0.17.5 |
| The install flag holds, and upgrades keep it | `uv tool install --exclude-newer 2023-01-01T00:00:00Z ruff` installed 0.0.205, and `uv tool upgrade --all` then said "Nothing to upgrade" |
| The upgrade flag governs, and reaches a tool installed without a hold | A tool held at 2023-01, then `uv tool upgrade --all --exclude-newer 2023-06-01T00:00:00Z`: ruff 0.0.205 became 0.0.270, not the newest. A plain install, then `uv tool upgrade --all --exclude-newer "48 hours"`: the receipt gained `exclude-newer-span = "PT48H"` |
| Setup skips a uv tool that is installed | `setup/misc.sh:233, 251` guard each install with `[ ! -x "$serena_bin" ]` and `[ ! -x "$scrapling_bin" ]` |
| The setup diagram does not show the npm value | `grep -c min-release-age setup/bootstrap-runtime.svg` printed 0, so the JSON edit in Task 1 needs no re-export |
| The owner's two receipts hold nothing today | `grep -c exclude` on both `uv-receipt.toml` files printed 0 |
| With the module on, mise still declares both Multipass packages | `MISE_CONFIG_DIR=<scratch clone>/tilde/.config/mise mise bootstrap packages status` listed both as installed. With the module's file in `ignored_config_paths` it listed neither |

### Checks already run, red then green

Each was run in a scratch clone of `c0c47a9`. Nothing in this repository was edited.

| Task | Red | Green |
| --- | --- | --- |
| 1, 2, 3 | `FAIL: release hold: pnpm is not 2880 minutes` | `hold block: ok`, with every line of the block present except Task 2's `sysup` line, which was added to the plan afterwards |
| 3 | The `uv run --locked` failure in the table above | `uv run --locked --project settings` ran, and `uv lock --check --project hindsight` resolved 231 packages |
| 4 | `AssertionError: the base holds the owner's tap or a package from it`, `FAIL: list`, `KeyError: 'modules.multipass'` | `test-packages` and `test-modules` exit 0, `test_registry`, `test_cli` and `test_module` print `ok` |

The hold block was run by itself, cut out of the file, because `test-conventions` stops earlier in any fresh clone with `FAIL: zsh prettier-ignored: tilde/.zshenv`, with or without this plan's changes. It passes in the real checkout. Not run: the docs edits, Task 2's `sysup` change with its `test-sysup` lines, and Task 5.

## Review Focus

1. **A Mac that already has Serena and Scrapling.** Its receipts hold nothing, and setup skips an installed tool. The next `sysup` must give both the hold without a reinstall. Measured above, and Task 2's Step 4 repeats it.
2. **CI and a fork, which have no user-level uv file.** `uv run --locked --project settings` must still pass there. Task 3's Step 4 runs it under an empty `XDG_CONFIG_HOME`.
3. **A Mac that already has Claude Multipass, with the module on.** Nothing may be removed or reinstalled. Task 4's Step 5 reads mise's status against the edited config.
4. **A Mac whose saved module list predates the module.** A list that does not name `multipass` means on, which is the rule for every module added later (`docs/modules.md:3`). Task 4's Step 1 extends the existing `test-modules` case rather than adding one.
5. **One tap declared by two modules.** Switching `multipass` off must leave `menubar`'s tap in place. `test-packages:147-152` already fails when the two URLs differ, and Task 4 keeps both declarations identical.

---

### Task 1: Hold npm, pnpm, bun and Renovate for 48 hours

**Files:**
- Modify: `pnpm-workspace.yaml:2`, `tilde/.bunfig.toml:9-11`, `setup/misc.sh:453-454`, `renovate.json:5`
- Modify: `setup/README.md:158`, `setup/bootstrap-runtime.archify.json:459`, `docs/updating.md:58`
- Test: `bin/lib/test-conventions` (a new block before the `# tlrc rejects a page` comment, and one clause in the header at lines 10 to 23)

**Interfaces:**
- Produces: the block's first line, `# One release-age hold everywhere: 48 hours, as mise's minimum_release_age (the audit spec, decision 1)`. Tasks 2 and 3 append to this block.

- [ ] **Step 1: Write the failing checks**

```bash
# One release-age hold everywhere: 48 hours, as mise's minimum_release_age (the audit spec, decision 1)
grep -qx 'minimum_release_age = "48h"' tilde/.config/mise/config.toml || fail "release hold: mise is not 48h"
grep -qx 'minimumReleaseAge: 2880' pnpm-workspace.yaml || fail "release hold: pnpm is not 2880 minutes"
grep -qx 'minimumReleaseAge = 172800' tilde/.bunfig.toml || fail "release hold: bun is not 172800 seconds"
grep -q '^  npm config set min-release-age 2$' setup/misc.sh || fail "release hold: npm is not 2 days"
grep -q '"minimumReleaseAge": "2 days"' renovate.json || fail "release hold: Renovate is not 2 days"
```

- [ ] **Step 2: Run it and see it fail**

Run: `bash bin/lib/test-conventions`
Expected: `FAIL: release hold: pnpm is not 2880 minutes`

- [ ] **Step 3: Change the four values and their comments**

`10080` to `2880`, `604800` to `172800`, `min-release-age 7` to `2`, `"7 days"` to `"2 days"`. Each comment beside a value that says 7 days says 48 hours. `.claude/rules/ci.md:19` already says to keep Renovate in step with pnpm and needs no edit.

- [ ] **Step 4: Update the three docs**

`setup/README.md:158` and the archify JSON name `min-release-age 7`: make it `2`. The exported diagram does not show that text, so it is not re-exported. In `docs/updating.md:58` change the Renovate wait from 7 days to 48 hours.

- [ ] **Step 5: Run it and see it pass**

Run: `bash bin/lib/test-conventions && pnpm install --frozen-lockfile`
Expected: both exit 0. A shorter hold never invalidates the lockfile.

- [ ] **Step 6: Commit**

Subject: `Hold npm, pnpm, bun and Renovate releases for 48 hours`

### Task 2: Hold the two uv tools for 48 hours

**Files:**
- Modify: `setup/misc.sh:235, 253` (the two `uv tool install` lines and the command each warning prints)
- Modify: `bin/sysup:497-498` (the upgrade and the command its failure line prints)
- Modify: `setup/README.md:148-149` (the Serena and Scrapling steps), `docs/updating.md` (the uv tools line)
- Test: `bin/lib/test-conventions` (the block from Task 1), `bin/lib/test-sysup:306, 316`

**Interfaces:**
- Consumes: the block Task 1 added.

- [ ] **Step 1: Write the failing check**

```bash
[ "$(grep -c 'uv tool install --exclude-newer "48 hours" ' setup/misc.sh)" = 2 ] || fail "release hold: a uv tool install has no 48 hour hold"
grep -q 'capture uv tool upgrade --all --exclude-newer "48 hours"' bin/sysup || fail "release hold: sysup upgrades uv tools with no 48 hour hold"
```

In `bin/lib/test-sysup:306, 316`, the two expected failure lines end `run: uv tool upgrade --all --exclude-newer "48 hours"`.

- [ ] **Step 2: Run them and see them fail**

Run: `bash bin/lib/test-conventions; LC_ALL=en_US.UTF-8 bash bin/lib/test-sysup`
Expected: `FAIL: release hold: a uv tool install has no 48 hour hold`, and the two `uv failure` checks of `test-sysup` fail. `test-sysup` needs the UTF-8 locale that `pnpm check` exports.

- [ ] **Step 3: Add `--exclude-newer "48 hours"` to the three commands**

Right after `uv tool install` on both lines of `setup/misc.sh`, and after `--all` in `bin/sysup:497`. The "run it later" text in each warning and the `status fail` line in `sysup` name the same command, so each gains the flag too. `sysup`'s stub of `uv` in `test-sysup` must still match the longer command: read how it matches before editing.

- [ ] **Step 4: Verify that an upgrade gives an unheld tool the hold**

In a scratch `UV_TOOL_DIR`, `UV_TOOL_BIN_DIR` and empty `XDG_CONFIG_HOME`: install `ruff` plain, run `uv tool upgrade --all --exclude-newer "48 hours"`, and read the receipt.
Expected: `uv-receipt.toml` holds `exclude-newer-span = "PT48H"`. This is the owner's Mac's case.

- [ ] **Step 5: Say it in the docs**

`setup/README.md:148-149`: both commands as they now read, and one sentence that the hold is kept in the tool's receipt. `docs/updating.md`, the uv tools line: `sysup` upgrades them under the same 48 hour hold, which also gives it to a tool installed before the hold existed.

- [ ] **Step 6: Run the checks and commit**

Run: `bash bin/lib/test-conventions && bash bin/lib/test-bootstrap && LC_ALL=en_US.UTF-8 bash bin/lib/test-sysup`
Expected: all exit 0. `test-bootstrap:783` matches the text `uv tool install`, which the flag leaves intact.

Subject: `Hold Serena and Scrapling releases for 48 hours`

### Task 3: Hold this repository's two uv projects for 48 hours

**Files:**
- Modify: `settings/pyproject.toml`, `hindsight/pyproject.toml` (a `[tool.uv]` table at the end of each)
- Modify: `settings/uv.lock`, `hindsight/uv.lock` (re-locked, four lines each)
- Modify: `settings/README.md` (how to re-lock)
- Test: `bin/lib/test-conventions` (the block from Task 1)

**Interfaces:**
- Consumes: the block Task 1 added.

- [ ] **Step 1: Write the failing checks**

```bash
for p in settings hindsight; do
  grep -qx 'exclude-newer = "48 hours"' "$p/pyproject.toml" || fail "release hold: $p/pyproject.toml has no 48 hour hold"
  grep -qx 'exclude-newer-span = "PT48H"' "$p/uv.lock" || fail "release hold: $p/uv.lock was not locked under the hold"
done
```

- [ ] **Step 2: Run it and see it fail**

Run: `bash bin/lib/test-conventions`
Expected: `FAIL: release hold: settings/pyproject.toml has no 48 hour hold`

- [ ] **Step 3: Add the table to both files and re-lock**

```toml
[tool.uv]
exclude-newer = "48 hours"
```

Run: `uv lock --project settings && uv lock --project hindsight`
Expected: `git diff --stat` shows 4 insertions in each `uv.lock` and no deletion. If any package version moves, stop and report it: the re-lock must not be an upgrade.

- [ ] **Step 4: Verify the two ways the locks are used**

Run: `XDG_CONFIG_HOME=/nonexistent uv run --quiet --locked --project settings python -c 'print("ok")'`
Expected: `ok`. This is CI's and a fork's case, with no user-level uv file.
Run: `uv lock --check --quiet --directory hindsight && bash bin/lib/test-hindsight-memory`
Expected: exit 0. The first is the gate's own line (`bin/lib/check:92`). `bin/hindsight-memory` copies both hindsight files to `~/.hindsight/daemon-env` and syncs with `--frozen`, which reads the lock as it is.

- [ ] **Step 5: Document the re-lock and commit**

In `settings/README.md`, one sentence: a dependency change is `uv lock --project settings`, which holds a release for 48 hours. `hindsight/pyproject.toml:6` already names its re-lock command.

Run: `pnpm check`
Subject: `Hold the settings and Hindsight lockfiles' releases for 48 hours`

### Task 4: Move Claude Multipass into a module

**Files:**
- Create: `tilde/.config/mise/conf.d/60-rotm-multipass.toml`
- Modify: `tilde/.config/mise/conf.d/30-packages.toml:19-21, 39-40, 56`, `tilde/.config/mise/conf.d/60-rotm-menubar.toml:7-8`
- Modify: `bin/lib/rotm-modules:46`, `settings/registry.toml` (a new entry before `modules.touchid`)
- Modify: `docs/modules.md:3, 19, 69`, `docs/installation.md:121`, `docs/forking.md:13`, `docs/gui/raycast.md:48`
- Test: `bin/lib/test-packages:114`, `bin/lib/test-modules:38`, `settings/tests/test_registry.py:111`

**Interfaces:**
- Produces: the module name `multipass`, the setting id `modules.multipass`, and the file `60-rotm-multipass.toml`.

- [ ] **Step 1: Write the failing checks**

In `bin/lib/test-packages`, after the `assert set(base.tools) == …` line:

```python
# The owner's own project is a module a fork can switch off, never the base
assert not base.taps and not any("jrmatherly" in k for k in base.packages), "the base holds the owner's tap or a package from it"
assert set(mods["multipass"].packages) == {"brew:jrmatherly/tap/claude-multipass", "brew-cask:jrmatherly/tap/claude-multipass-app"}, set(mods["multipass"].packages)
```

In `bin/lib/test-modules:38`, the expected list gains `multipass` between `menubar` and `touchid`.

In `settings/tests/test_registry.py`, after the `menubar` assertion:

```python
multipass = by_id["modules.multipass"]
assert (multipass.kind, multipass.key, multipass.default) == ("module", "multipass", "on"), multipass
```

- [ ] **Step 2: Run them and see them fail**

Run: `bash bin/lib/test-packages; bash bin/lib/test-modules; mise exec python -- python3 settings/tests/test_registry.py`
Expected: `AssertionError: the base holds the owner's tap or a package from it`, `FAIL: list`, and `KeyError: 'modules.multipass'`.

- [ ] **Step 3: Create the module and empty the base of it**

`60-rotm-multipass.toml`, in the shape of `60-rotm-menubar.toml`:

```toml
# returnofthemac module `multipass`: Claude Multipass, the owner's own project.
#
# Switch it off with `rotm settings set modules.multipass off` (on again with `on`).
# The formula and the app stay installed.
# `mise bootstrap packages prune --dry-run` lists what no config declares any more.

# Also declared in 60-rotm-menubar.toml: one tap at one URL in two files, so
# switching either module off leaves the other's tap in place
[bootstrap.brew.taps]
"jrmatherly/tap" = "https://github.com/jrmatherly/homebrew-tap.git"

[bootstrap.packages]
"brew:jrmatherly/tap/claude-multipass" = "latest" # Switch Claude Desktop between claude.ai accounts (github.com/jrmatherly/claude-multipass; Raycast scripts in its share dir)
"brew-cask:jrmatherly/tap/claude-multipass-app" = "latest" # Claude Multipass menu bar app (arm64, macOS 14+)
```

In `30-packages.toml` delete the `[bootstrap.brew.taps]` table and the two package lines. Reword the `brew:ruby` comment to name both tap casks, and the `60-rotm-menubar.toml` comment to name `60-rotm-multipass.toml`. The header rule about third-party taps stays: it now describes the modules.

- [ ] **Step 4: Name the module in the list and the registry**

`bin/lib/rotm-modules:46`: `multipass` after `menubar`. `settings/registry.toml`: an entry with `id = "modules.multipass"`, `label = "Claude Multipass"`, `help = "Switches Claude Desktop between saved claude.ai accounts: the command line tool and its menu bar app."`, `key = "multipass"`, and the other seven fields as `modules.menubar` has them.

- [ ] **Step 5: Run the checks, and read mise's view of an existing install**

Run: the three commands of Step 2, then `mise exec python -- python3 settings/tests/test_cli.py`
Expected: exit 0, exit 0, `ok`, `ok`. `test-packages`' count line (`144, 34, 184`) passing is the proof that no package was lost.

Run: `repo=$PWD; (cd /tmp && MISE_CONFIG_DIR="$repo/tilde/.config/mise" mise bootstrap packages status | grep multipass)`
Expected: both packages, each `installed`. This reads only. It shows a Mac with the module on keeps both.

- [ ] **Step 6: Update the docs**

- `docs/modules.md`: "fifteen" becomes "sixteen", a `multipass` row follows `menubar` ("Claude Multipass, the owner's tool that switches Claude Desktop between accounts, and its menu bar app"), and the tap table's `jrmatherly/tap` row names `multipass`, `menubar` in place of `base`, `menubar`.
- `docs/installation.md:121`: `multipass` joins the `--without` list after `menubar`.
- `docs/forking.md:13`: the row says Claude Multipass is the `multipass` module, switched off with `rotm settings set modules.multipass off`. The `state = "absent"` advice goes.
- `docs/gui/raycast.md:48`: the package is in the `multipass` module.

- [ ] **Step 7: Commit**

Run: `pnpm check`
Subject: `Move Claude Multipass from the base into a module`

### Task 5: Close the spec and promote

Run last. Step 2 changes GitHub Actions usage and Step 3 moves `stable`: each needs the owner's word.

**Files:**
- Modify: `docs/superpowers/specs/2026-11-16-project-audit.md`, `docs/superpowers/plans/README.md`
- Move: this plan to `plans/completed/`, the spec to `specs/completed/`

**Interfaces:** None.

- [ ] **Step 1: Record the outcome**

Add an "Outcome" table to this plan with each task's commit and any difference from the plan. In the spec's "Owner's decisions", say under decisions 1 and 4 that each is built, with the commit.

- [ ] **Step 2: Run the install on both paths (owner's word)**

Run: `gh workflow run fresh-install.yml --ref main`
Verify: `gh run list --workflow fresh-install.yml --limit 1` shows `success` on the current `main` commit, for the `clone` and the `installed` path. This plan changes the package list and the setup task, which is when `.claude/rules/ci.md` says to run it.

- [ ] **Step 3: Promote (owner's word)**

`setup/README.md:80-88` asks for a pass in the disposable VM, Guest A, before a commit that changes more than Markdown goes to `stable`. Put the choice to the owner: Guest A first, or the fresh-install run of Step 2 as the proof. Then, on the owner's word only: `git push origin <sha>:refs/heads/stable`. The owner runs `rotm update`.

- [ ] **Step 4: Verify on the owner's Mac after the update (read-only)**

The owner runs `sysup` once, since setup skips an installed uv tool.
Run: `grep exclude-newer-span ~/.local/share/uv/tools/serena-agent/uv-receipt.toml ~/.local/share/uv/tools/scrapling/uv-receipt.toml`
Expected: `PT48H` in both.
Run: `npm config get min-release-age` and `rotm settings list | grep multipass`
Expected: `2`, and the module shown as on.

- [ ] **Step 5: File the plan and the spec**

Move this plan to `plans/completed/` and remove its row from the README's "Open plans" table. Every decision of the spec is then answered and built, so move the spec to `specs/completed/` and fix the links to it (`git grep -n '2026-11-16-project-audit'`).

Subject: `Close the 2026-11-16 audit: every decision is built`
