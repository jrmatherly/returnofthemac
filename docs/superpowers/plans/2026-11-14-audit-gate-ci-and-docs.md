# Audit fixes: the gate, CI and docs, Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Close findings G1 to G14 of the 2026-11-14 audit, so the gate catches what it missed, CI runs what it skipped, and the docs and the VM runbook say what the code and the record say.

**Architecture:** No new file and no new tool. Each fix is a line or two in a file that already owns the behaviour: `bin/lib/check`, `bin/lib/test-conventions`, `renovate.json`, `.github/actionlint.yaml`, `.github/workflows/check.yml`, one Python test, and the docs. G8's Swift test moved to the menu bar app plan (Task 8). Three findings are the owner's to act on and appear as checklist items. Two wait for the Guest 2 rows of the P5 VM proof.

**Tech Stack:** bash 3.2, uv 0.13.7, actionlint 1.7.12, Renovate (Mend app), Python 3.11+ standard library, GitHub Actions on `macos-26`.

**Spec:** `docs/superpowers/specs/2026-11-14-project-audit.md`, section "G. Gate, CI and docs". Read it before Task 1. Tasks 2 and 11 also read `docs/superpowers/specs/2026-11-14-p5-vm-proof/RUNBOOK.md` and Task 11 of `docs/superpowers/plans/completed/2026-11-13-p5-menu-bar-app.md`.

## Global Constraints

- The gate is `pnpm check` (`bin/lib/check`). Every task ends with it passing. Edit and commit in separate Bash calls.
- Commit subjects are short, imperative, sentence case, with no conventional-commit prefix. One commit per task, with the subject the task names.
- A change to setup behaviour, the package list or mise tools carries its doc edit in the same commit (CLAUDE.md, "Docs mirror behavior").
- Never run on this Mac: `sysup`, `./setup.sh`, `set-defaults`, `rotm install`, `rotm update`, `hindsight-memory init`, `hindsight-memory upgrade`, `hindsight-memory uninstall`, `rotm settings sync …` or the built app.
- Never touch github.com/jrmatherly/rotm-settings.
- Pushing a tag, closing a PR and running a GitHub workflow are the owner's and need their word. Standing approval covers a push to `main` once `pnpm check` passes.
- `docs/superpowers/` is in `.prettierignore`. Do not hand-format files there.
- `CLAUDE.md` is capped at 12,000 bytes and each `.claude/rules/*.md` at 6,000, with no line over 1,000 bytes (`bin/lib/test-conventions:192-204`). No task here edits `CLAUDE.md`.
- No task here has an owner decision in the spec's list. Tasks 4 and 11 wait on the owner for other reasons, stated in each.

## Measured for this plan (2026-11-14, this Mac)

| Fact | How |
| --- | --- |
| `uv lock --check --quiet --directory <copy of hindsight/>` exits 0 and prints nothing | Ran it on a scratch copy, online, with `--offline`, and with `--offline` on an empty `UV_CACHE_DIR`. It wrote no `.venv` |
| The same call on a copy with PR 20's line (`requires-python = ">=3.15,<3.16"`) exits 1 | Ran it. uv re-resolves ("fork markers being disjoint with `requires-python`") and fails building `psycopg2-binary`. With `--offline` it fails with "No solution found" |
| The check needs a Python 3.13 | With only 3.15 and 3.9 on PATH, `UV_PYTHON_PREFERENCE=only-system` and `UV_PYTHON_DOWNLOADS=never`, it exits 2: "No interpreter found for Python ==3.13.\*". This Mac has 3.13.15 |
| The check needs no network when a 3.13 is present | The `--offline` run on an empty cache, above |
| Not measured. uv fetching 3.13 by itself on the CI runner | `check.yml` sets up Python 3.15 only. uv's default is to download a managed Python, and `setup-uv` does not turn that off. Nothing was downloaded here. Task 1 Step 6 settles it |
| The gate already calls uv behind `command -v uv`, with `--locked` for `settings/` | `bin/lib/check:85-91` |
| actionlint 1.7.12 rejects `ubuntu-26.04` and accepts it once listed under `self-hosted-runner.labels` | Ran `actionlint -config-file` on a scratch copy of `app-release.yml`, with each config |
| Every self-check file is wired into `bin/lib/check` today | A loop over the six globs of Task 6 found none missing |
| The latest `check` run on `main` (43652103969) skipped four parts | Its log holds `skip: zoxide not installed`, `skip: rg not installed`, `skip: fzf not installed` and `test-conventions: tldr not found, skipping the help render check` |
| A type-aware fixture comparison passes on today's fixtures and catches a changed type | Ran `test_cli.py` with the Task 7 functions swapped in. `"drift": "false"` in one row and `"connected": "no"` both failed it |
| `proof.sh` needs a new row for Task 2 | `rows` at `proof.sh:140` is a fixed list, and line 318 refuses any other name with the usage text |
| The record holds `haiku high` at 1c1 to 1c3 and `sonnet xhigh` from 1d1 on | `~/vm-proof/p5/g1/*/state.json`, field `list.jstack.bug_fix`. `g1/1d1/vs-1c1.txt` shows the change |
| Guest 1 installed app 0.1.1, saw 2 commits waiting and updated the app to 0.1.2 | Fields `mac.app_version`, `update.behind` and `tap.version` in 1f1 to 1f3 |
| This Mac has no `lidwake` key | `pmset -g custom \| grep -c lidwake` printed 0 |
| `docs/forking.md` has 16 rows | Lines 7 to 22 |
| PR 16, 19 and 20 are open. PR 20's `check` is green and its `renovate/artifacts` fails. PR 19's `check` fails | `gh pr view` |

## Review Focus

1. **A Mac or runner with no Python 3.13 and no network.** The new lock check then fails the gate for a reason that is not the lock. A person expects the message to name the cause. uv's own text does ("No interpreter found for Python ==3.13.\*"), and `check: failed: uv lock …` names the step. Task 1 Step 6 watches the first CI run for it.
2. **A self-check whose name is outside the six globs.** `app/scripts/test-x.sh` would not be seen by Task 6's check. The globs are the places self-checks live today. Task 6 Step 3 puts them in one loop, so a new place is one word.
3. **A fixture field that is null on one side, or a list.** Task 7 lets null match any type, because `seed`, `origin`, `missing` and `conflicts` are nullable, and does not compare list elements, because the fixture's lists are empty. A string that becomes a list is caught. A list of strings that becomes a list of numbers is not.
4. **The Guest 2 row offers no Reset.** The fix in `e7db2f3` may not hold on a real install. Task 2's runbook step tells the owner to say so and go on, and the record then shows the row unchanged.
5. **A runner bottle that is missing for one of the four new formulae.** `mise bootstrap packages apply` fails that step by name before `pnpm check` starts. Task 5 Step 4 reads the run.

---

### Task 1: Check the Hindsight lock in the gate and keep Renovate out of it

**Finding:** G1

**Files:**
- Modify: `bin/lib/check:85-91` (one job inside the `command -v uv` block)
- Modify: `renovate.json:30-34` (the existing Hindsight rule)

**Interfaces:**
- Produces: a gate step named `uv lock --check --quiet --directory hindsight`. A failure prints `check: failed: uv lock --check --quiet --directory hindsight` and uv's error.

- [ ] **Step 1: Reproduce the gap.** PR 20 changes one line and its `check` passed, so nothing in the gate reads `hindsight/`.

```bash
d=$(mktemp -d) && cp hindsight/pyproject.toml hindsight/uv.lock "$d/"
uv lock --check --quiet --directory "$d"; echo "exit $?"
sed -i '' 's/>=3.13,<3.14/>=3.15,<3.16/' "$d/pyproject.toml"
uv lock --check --quiet --directory "$d"; echo "exit $?"
```

Expected: `exit 0` with no output, then an error from uv and `exit 1`.

- [ ] **Step 2: Add the job.** In `bin/lib/check`, inside `if command -v uv`, after the three `uv run` lines, add `job uv lock --check --quiet --directory hindsight`. It takes no `quiet` wrapper, since `--quiet` already prints nothing on success. It takes no `--offline` either. With a 3.13 present the check uses no network, and without one `--offline` would stop uv fetching it. The comment above it says in one line that the lock must still match `pyproject.toml` and that uv needs a Python 3.13 for it.

- [ ] **Step 3: See the gate fail on PR 20's change.**

```bash
sed -i '' 's/>=3.13,<3.14/>=3.15,<3.16/' hindsight/pyproject.toml
pnpm check; echo "exit $?"
git checkout hindsight/pyproject.toml
```

Expected: `check: failed: uv lock --check --quiet --directory hindsight`, `exit 1`. After the checkout, `git status --short hindsight/` prints nothing.

- [ ] **Step 4: Change the Renovate rule.** In the rule at `renovate.json:30-34`, replace `"matchPackageNames": ["hindsight-embed", "hindsight-api"]` with `"matchFileNames": ["hindsight/pyproject.toml"]`, and keep `"enabled": false`. The rule then covers the two packages and the `requires-python` range. Extend its `description` with one clause, that the Python range is the lock's, so a bump is `uv lock --directory hindsight` in a reviewed commit. Checked on 2026-11-14 in Renovate's `docs/usage/configuration-options.md` (`packageRules.matchFileNames`): the option takes a glob or an exact file name and is compared against the dependency's package file, and its lock file when there is one. After the push, PR 20 should close or stop updating on Renovate's next run. That effect is not measured here, and the Dependency Dashboard issue shows it.

- [ ] **Step 5:** `pnpm check`. Expected: pass. Commit: "Check the Hindsight lock in the gate and keep Renovate out of it".

- [ ] **Step 6: Watch the push's `check` run.** `gh run watch "$(gh run list --workflow check.yml --branch main --limit 1 --json databaseId --jq '.[0].databaseId')"`. Expected: green, which shows uv found or fetched a 3.13 on the runner. If the step fails with "No interpreter found for Python ==3.13.\*", stop and tell the owner with that line. The fix is then a second `python-version` in `check.yml`'s `setup-python` step, and which version becomes the default `python3` must be read in that action's README first.

- [ ] **Step 7: The owner closes PR 20**, unless Renovate has closed it by itself on its next run. Not done by the session.

---

### Task 2: Prove the jstack Reset in Guest 2

**Finding:** G10

This task is time-bound, so run it before Task 1 while Guest 2 is still up. Guest 2 is running (`utmctl list` says `started`). The step must be in the runbook, and the row in the shared copy of the script, before the owner records 2b and shuts the guest down.

**Files:**
- Modify: `docs/superpowers/specs/2026-11-14-p5-vm-proof/RUNBOOK.md` (a new step 36 after line 262; today's step 36 becomes 37)
- Modify: `docs/superpowers/specs/2026-11-14-p5-vm-proof/proof.sh:140` (`rows`) and `:179-182` (the `case`)

**Interfaces:**
- Produces: row `2c`, recorded into `~/vm-proof/p5/g2/2c/` and compared with `2b`. Task 11 reads it.

- [ ] **Step 1: See the script refuse the row.** `/bin/bash docs/superpowers/specs/2026-11-14-p5-vm-proof/proof.sh 2c`. Expected: `proof: usage: proof.sh <row> | diff <record> <record>. Rows: …` and exit 1.

- [ ] **Step 2: Add the row.** Append `2c` to `rows`. Add `2c) against=2b ;;` after the `2a | 2b)` branch. Nothing else changes, because `record` already captures `list.json` and `~/.config/rotm/tools.toml`.

- [ ] **Step 3: See it accepted.** The same command as Step 1. Expected on this Mac: `proof: this is not an installed copy (rotm-mode says: clone). Never run this on a development clone`, exit 1. The preflight stops it before anything is written. Then `bash -n` and `shellcheck --severity=warning` on the file, which the gate does not lint.

- [ ] **Step 4: Add runbook step 36**, with this text, and renumber the shut-down step to 37:

```markdown
36. From the menu, choose **Settings…**, then **Agents**. The **jstack: bug-fix** row reads `sonnet xhigh`, loaded from guest 1, and should offer **Reset**. Choose **Reset**, then **Review…** (one `reset` line) and **Apply**. If the row offers no **Reset**, **tell the session** and record the row anyway. Then:

    ```shell
    p 2c
    ```

    Expected, compared with 2b: `list.jstack.bug_fix` goes from `"sonnet xhigh" [override]` to `null [unset]`, and `file.tools.toml` loses its `jstack.bug_fix` line. `status.sync.waiting` may gain an entry, because the reset is a local change that sync has not sent. Row 1c3 could not show this: the app offered no Reset for a role then (fixed in `e7db2f3`).
```

- [ ] **Step 5:** `pnpm check`, commit: "Add a jstack Reset row to the Guest 2 proof".

- [ ] **Step 6: Copy the script to the shared folder**, as the runbook's step 1 does, and tell the owner the new step exists. The command is `cp docs/superpowers/specs/2026-11-14-p5-vm-proof/proof.sh ~/vm-proof/p5/proof.sh`. The two files are identical today (`diff -q`). **Not run on the host:** the row itself. Guest 2's `p 2c` proves it.

---

### Task 3: Let actionlint accept the `ubuntu-26.04` label

**Finding:** G3

**Files:**
- Modify: `.github/actionlint.yaml`

- [ ] **Step 1: See it fail.**

```bash
d=$(mktemp -d) && sed 's/ubuntu-24.04/ubuntu-26.04/' .github/workflows/app-release.yml > "$d/app-release.yml"
actionlint -config-file .github/actionlint.yaml "$d/app-release.yml"; echo "exit $?"
```

Expected: `label "ubuntu-26.04" is unknown`, `exit 1`.

- [ ] **Step 2: Add the label.** One entry under `labels`, `- ubuntu-26.04`, with a comment in the style of the `xcode-27` one. It says the label is hosted, not self-hosted, that actionlint 1.7.12 does not list it yet, that Renovate PR 19 wants it for `app-release.yml`'s `release` job, and that the entry goes once actionlint lists it. Move the existing comment so each label has its own comment directly above it.

- [ ] **Step 3: See it pass.** The Step 1 command. Expected: no output, `exit 0`.

- [ ] **Step 4:** `pnpm check`, commit: "Let actionlint accept the ubuntu-26.04 runner label".

This task does not prove that GitHub serves a hosted `ubuntu-26.04` image. Renovate's proposal is the only evidence, and the `release` job runs only on an `app-v*` tag. The owner checks the label in the `actions/runner-images` README before merging PR 19.

---

### Task 4: The owner's steps

**Finding:** G2, G4, and the PRs of G1 and G3

Nothing here is run by the session. Each line is one action and its expected result.

Outcome, 2026-11-15, on the owner's word to the session: PR 16 is closed and PR 19 is merged as `ef4d530`. Its `check` passed after `gh pr update-branch 19 --rebase`. The `actions/runner-images` README lists `ubuntu-26.04` as a hosted label with no beta mark, and the image holds GitHub CLI 2.103.3. Not proven: the `release` job running on it, which needs an `app-v*` tag. `fresh-install` is still owed.

- [ ] **G2. Run `fresh-install`.** `gh workflow run fresh-install.yml`, then `gh run watch` on it. Expected: both legs of the matrix (`clone`, `installed`) green, in about 27 minutes as on 2026-11-12. It last ran at `7f837d6`. Run it again after the install plan (`completed/2026-11-14-audit-install-and-opt-outs.md`) lands, since that plan changes the setup path.
- [ ] **G4. Close PR 16.** Its change is on `main` in `e7fb36f` (`package.json:22` holds `0.0.0-20261102001236-gf10f41a`).
- [ ] **G1. Close PR 20** after Task 1 is pushed.
- [ ] **G3. Merge or close PR 19** after Task 3 is pushed and Renovate has rebased it. Expected: its `check` turns green.

---

### Task 5: Run the skipped self-check parts in CI

**Finding:** G6

**Files:**
- Modify: `.github/workflows/check.yml:47-49`
- Modify: `bin/lib/check:116-119`

- [ ] **Step 1: See the skips.** `gh run view 43652103969 --log | grep -E 'skip: (zoxide|rg|fzf) not installed|tldr not found'`. Expected: four lines.

- [ ] **Step 2: Install the four tools on the runner.** Append `brew:zoxide brew:ripgrep brew:fzf brew:tlrc` to the `mise bootstrap packages apply --yes` line (the names `30-packages.toml` uses), and name them in the comment above it as what `test-shell` and `test-conventions` need.

- [ ] **Step 3: Say when actionlint is missing.** Give the `if command -v actionlint` block in `bin/lib/check` an `else` that prints `check: actionlint not found, skipping the workflow lint` to stderr, as the `uv` and Xcode blocks do. This branch is not exercised on this Mac or in CI, since both have actionlint.

- [ ] **Step 4:** `pnpm check`, commit: "Run the zoxide, rg, fzf and tldr self-check parts in CI". After the push, repeat Step 1's `grep` on the new run. Expected: no line, and the run green. If a newly run part fails on the runner, read the failure before changing anything. A case that fails there for a reason in `zsh/` is a finding, not a reason to weaken the case.

---

### Task 6: Fail when a self-check is not wired into the gate

**Finding:** G5

**Files:**
- Modify: `bin/lib/test-conventions` (a new block before the `size_limit` block at line 189, and one phrase in the header comment at lines 10-23)

- [ ] **Step 1: See the gap.**

```bash
touch bin/lib/test-zz-unwired && bash bin/lib/test-conventions; echo "exit $?"; rm bin/lib/test-zz-unwired
```

Expected today: `conventions: all checks passed`, `exit 0`.

- [ ] **Step 2: Add the check.** One loop over `bin/lib/test-* setup/tests/* .claude/hooks/test-*.sh settings/tests/test_*.py agents/catalog/test_*.py vscode/test-*.sh`. Skip anything that is not a regular file (`[ -f "$f" ] || continue`), so a `__pycache__` folder or an unmatched glob is not reported. For each file, `grep -qF "$f" bin/lib/check`, else `fail "self-check not run by bin/lib/check: $f"`. Add "that bin/lib/check runs every self-check" to the header's list.

- [ ] **Step 3: See it fail, then pass.** The Step 1 command. Expected: `FAIL: self-check not run by bin/lib/check: bin/lib/test-zz-unwired`, `exit 1`. Then `bash bin/lib/test-conventions` alone. Expected: `conventions: all checks passed`.

- [ ] **Step 4:** `pnpm check`, commit: "Fail the gate when a self-check is not wired into it".

---

### Task 7: Compare types in the JSON fixture contract

**Finding:** G7

**Files:**
- Modify: `settings/tests/test_cli.py:224-234`

- [ ] **Step 1: See the gap.** In `app/Tests/RotmTestSupport/Fixtures/list.json`, change the first row's `"drift": false` to `"drift": "false"`. Run `python3 settings/tests/test_cli.py`. Expected today: `ok`. Leave the edit in place for Step 3.

- [ ] **Step 2: Compare shapes with types.** Replace `shape` and the two assertions:

```python
def shape(value):
    return {k: shape(v) for k, v in value.items()} if isinstance(value, dict) else type(value).__name__


def same(a, b):
    """Null matches any type: seed, origin, missing and conflicts are nullable."""
    if isinstance(a, dict) and isinstance(b, dict):
        return a.keys() == b.keys() and all(same(a[k], b[k]) for k in a)
    return a == b or "NoneType" in (a, b)


assert all(same(shape(row), shape(live)) for row in json.loads((fixtures / "list.json").read_text())), shape(live)
```

and, after the `DOTFILES_SETTINGS_MISE` line, `assert same(shape(<status.json>), shape(<status --json>))`. `live` stays the first row of `list --json`. Update the comment above to say a renamed field or a changed type fails one side's gate.

- [ ] **Step 3: See it fail, then pass.** Run the test. Expected: `AssertionError`. Then `git checkout app/Tests/RotmTestSupport/Fixtures/list.json` and run it again. Expected: `ok`.

- [ ] **Step 4:** `pnpm check`, commit: "Compare field types in the app's JSON fixture contract".

---

### Task 8: The focus-on-open test moves to the app plan

**Finding:** G8

This fix lives in `docs/superpowers/plans/2026-11-14-audit-menu-bar-app.md`, Task 5, which moves `noFieldTakesFocusOnOpen` into an always-on suite. That plan's writer ran the moved test in a scratch copy of the package and saw it take no focus from the front app, so it does not need a CI-only gate. Nothing to do here.

---

### Task 9: Correct `ci.md`, the forking table and the spec's count

**Finding:** G12, G13

**Files:**
- Modify: `.claude/rules/ci.md:13,17`
- Modify: `docs/forking.md` (four rows before the `LICENSE` row at line 22)
- Modify: `docs/superpowers/specs/2026-11-11-installable-setup-profiles-and-sync.md:41`

These edits have no test, because they are statements about files. Each step names the line that proves the new text.

- [ ] **Step 1: `ci.md:13`.** "15-minute timeout" becomes "20-minute timeout" (`check.yml:21`).

- [ ] **Step 2: `ci.md:17`.** Say that `fresh-install` is a matrix of two paths on a runner whose Homebrew is deleted (`fresh-install.yml:25-28`). `clone` runs `./setup.sh -y --skip-codegraph -- --skip user`. `installed` installs mise, runs the README's install line against the branch under test and the copy's `setup.sh` with the same flags, then `rotm update`, and fails when the copy has a tracked change (`:73-86`, `:148-163`). Keep the rest of the bullet. The line is 780 bytes today, so split it into two bullets, each under 1,000 bytes.

- [ ] **Step 3: `docs/forking.md`.** Add four rows, in the table's link style:

| File | What to change |
| --- | --- |
| `.github/workflows/fresh-install.yml` | The install line's `https://github.com/jrmatherly/returnofthemac.git` URL (line 84). Point it at your fork, or the `installed` run tests my repository |
| `docs/menu-bar.md` | The `jrmatherly/tap` cask name and the `jrmatherly/homebrew-tap` file the app reads. Keep them in step with the `AppUpdate.swift` row |
| `tilde/.ssh/config` | `github.com` is pinned to `~/.ssh/github_personal.pub` with `IdentitiesOnly yes`, and every host uses the 1Password SSH agent. Without that key file and agent, `git@github.com` is denied. Create the key in 1Password, or remove the `Host github.com` block and the `IdentityAgent` line |
| `tilde/.config/mise/conf.d/20-macos.toml` | `AppleLanguages`, `AppleLocale`, `AppleMeasurementUnits`, `AppleTemperatureUnit` and `AppleMetricUnits` set US English, dollars, inches and Fahrenheit. Change or delete them before `set-defaults` |

If the install plan's I1 or I9 task has landed first, write the last two rows to match what it shipped (a switch, a guard) and not the text above.

- [ ] **Step 4: The spec's line 41.** "lists 13 places" becomes "lists 20 places" (16 rows today plus the four). Leave line 366, which is history.

- [ ] **Step 5:** `pnpm check`, commit: "Correct ci.md and list four more owner values in forking.md".

---

### Task 10: Correct the lid wake and Software Update claims

**Finding:** G14

**Files:**
- Modify: `docs/macos settings.md:56,178`
- Modify: `setup/README.md:207`

- [ ] **Step 1: Line 56.** Keep "turn on every option" as the by-hand instruction and correct the parenthesis: set-defaults turns on three of them (the automatic check, the download, and critical and security installs; switch `macos.software_update`), and the rest are set by hand. Evidence: `setup/macos-extras.sh:143-152` writes `AutomaticCheckEnabled`, `AutomaticDownload` and `CriticalUpdateInstall`, plus the daily `ScheduleFrequency`, which is not an option in Settings.

- [ ] **Step 2: Line 178 and `setup/README.md:207`.** Lid wake is set only on a Mac whose `pmset -g custom` lists `lidwake`. In `docs/macos settings.md` add "(this Mac has no `lidwake` key, so it is skipped)", in the page's "this Mac" style. In `setup/README.md` write "lid wake on where the Mac has the key". Evidence: `setup/macos-extras.sh:170-180`, and `pmset -g custom | grep -c lidwake` prints 0 here.

- [ ] **Step 3:** `pnpm check`, commit: "Say which update options and pmset keys set-defaults writes".

---

### Task 11: Fold the Guest 1 record and the runbook's drift into the P5 write-up

**Finding:** G9, G11

Do not start this task until `~/vm-proof/p5/g2/2a/state.json` and `~/vm-proof/p5/g2/2b/state.json` exist. It is part of Task 11 Step 3 of `docs/superpowers/plans/completed/2026-11-13-p5-menu-bar-app.md`, which writes the run's results into the spec once. Splitting the spec edit in two would leave the sync row half-rewritten.

**Files:**
- Modify: `docs/superpowers/specs/2026-11-11-installable-setup-profiles-and-sync.md:211-321` ("Verified facts" and "Still not verified")
- Modify: `docs/superpowers/specs/2026-11-14-p5-vm-proof/RUNBOOK.md:158,189-218,246`
- Modify: `docs/superpowers/specs/2026-11-14-p5-vm-proof/proof.sh:42-43` (the comment only)

**Interfaces:**
- Consumes: rows `2a`, `2b` and Task 2's `2c` in `~/vm-proof/p5/g2/`.

- [ ] **Step 1: Read the record.** For each pair below, `/bin/bash ~/vm-proof/p5/proof.sh diff <a> <b>`, ignoring `list.packages.*` and `cask`. `diff` only reads.

| "Still not verified" row (spec line) | Record that answers it | Expected |
| --- | --- | --- |
| A real install and a real `rotm update` (313) | `1a`; `1f1` and `1f2` | The app installed and opened by setup; `update.behind` 2 to 0 and a new `status.commit` |
| `gh auth login` writes a Git credential helper (317) | `1d2` and `1d3` | No `git.credential` line in the diff. The field is the same in `1a`, `1d2`, `1d3`, `1d4` and `1f4` |
| A profile switch on a real install (318) | `1b1` and `1b2`; `1b5` and `1b6` | `no field differs` |
| The menu bar app on a real install (320) | `1c1` and `1c2`; `1d1` to `1d4`; `1f3` and `1f4` for Launch at Login | `no field differs` for the settings; `mac.booted` and `mac.app_started` later with the app running |
| The app's own update on its real cask (321) | `1f2` and `1f3` | `mac.app_version` 0.1.1 to 0.1.2, not the 0.1.0 to 0.1.1 the row predicts |
| Sync against a real private repository (316) | `1d3`, `1d4` for the first half; `2a`, `2b` for the second | `status.sync.connected` true on guest 1; on guest 2 the four `list.*` rows match `1d4` |

- [ ] **Step 2: Move each answered row** from "Still not verified" to "Verified facts", in that table's style, which is the claim, then what the record shows, with the record's path and the date 2026-11-14. Where a diff is not what the table above expects, write what it shows and keep the row in "Still not verified" with what is still owed. Add the Reset result from `2c`.

- [ ] **Step 3: Correct the runbook's expectations in place**, so the file matches the record it produced:
  - Line 158: compared with 1c1, `list.jstack.bug_fix` reads `sonnet xhigh` and `file.tools.toml` differs by that line. The record shows 1c3 still holding `haiku high` (the app offered no Reset for a role, fixed in `e7db2f3`) and 1d1 holding `sonnet xhigh`. It does not show why the value changed between them, so write what the record holds and no cause.
  - Lines 189 to 218: guest 1 installed app 0.1.1, and the release cut during the run was 0.1.2. Every `0.1.1` on lines 189, 190, 191, 196, 212 and 218 becomes `0.1.2`. Line 196's setup line reads **Setup: 2 updates waiting**.
  - Line 246: bug-fix `sonnet xhigh`, and "the tap now gives 0.1.2".

- [ ] **Step 4: `proof.sh:42-43`.** The comment says rows 1c and 1d use `values`. Say that 1c does, and that from row 1d1 on the 2026-11-14 record holds `sonnet xhigh` for `jstack.bug_fix`. Leave `values` as it is: row 1c2 set `haiku high`, and records 1c1 and 1c2 hold it. Copy the file to `~/vm-proof/p5/proof.sh` again.

- [ ] **Step 5:** `pnpm check`, commit with the P5 write-up, under that plan's subject for the step.

## Findings the code contradicts

None in full. One in part:

- **G11, the `proof.sh` half.** The finding lists `haiku high` in `proof.sh` as stale. `proof.sh:45` is used only by row 1c2's `set_all`, and records `g1/1c1` and `g1/1c2` hold `"haiku high"`, so the value is right for the row that uses it. Only the comment above it over-claims. Task 11 Step 4 changes the comment and keeps the value.
