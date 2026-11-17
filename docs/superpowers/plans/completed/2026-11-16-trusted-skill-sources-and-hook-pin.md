# Trusted skill sources and a watched hook pin, Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `sysup` installs an upstream change to an agent skill by itself when the skill's source is one the owner trusts, a change from any other source arrives as a pull request whose merge is the review, and Renovate opens a pull request when the Hindsight hook package has a new release, so none of the three needs a hand-run command.

**Architecture:** Trust is a property of a source, kept as one tracked list beside the skill list. `claude-config restore skills --update` reinstalls a trusted skill whose upstream moved past the installed copy and says so on one line, which `sysup` turns into a changed step. A trusted row carries no reviewed value, so an update never changes a tracked file and needs no promotion. For a source that is not trusted, a scheduled workflow runs one script that compares each reviewed value with upstream and opens a pull request moving it, and `restore` then installs a skill whose merged review is ahead of the installed copy. The hook pin gets a Renovate regex manager and nothing else.

**Tech Stack:** bash 3.2, jq, `gh api`, the `skills` CLI through `npx`, GitHub Actions, Renovate (Mend app).

**Spec:** None of its own. This plan changes decision 2 of [`docs/superpowers/specs/completed/2026-11-16-project-audit.md`](../../specs/completed/2026-11-16-project-audit.md) ("the reviewed folder hash stays the only check"), and the section below is the record of that change. Read it and the audit's "Owner's decisions" before starting.

## Outcome (2026-11-16)

All six tasks are done. Tasks 1 to 5 ran natively on `main`, each red then green, and the owner's own `rotm update` and two `sysup` runs were the proof of Task 6.

| Task | Commit | Difference from the plan |
| --- | --- | --- |
| 1 | `c16801a` | None. A failed reinstall prints no `skill updated` line and `restore` exits 1, which `sysup` shows as its fail line |
| 2 | `56be265` | None |
| 3 | `7a38d2c` | None |
| 4 | `b7542ee` | The runner is `ubuntu-26.04`, the image `app-release.yml` already pins, not `ubuntu-24.04`. Step 7's run (43983853396) passed and opened nothing. Step 8: the owner said yes, and the setting now reads `"can_approve_pull_request_reviews":true` |
| 4, added | `aa571b6` | A file name from the untrusted repository could write Markdown into the pull request body. Characters outside a plain path become `?` and each list has a count |
| 5 | `667cde9` | None. Step 5: Renovate's Dependency Dashboard lists `regex (1)` with `@vectorize-io/hindsight-coding-agents 0.8.7` under `bin/hindsight-memory`, and no config error issue is open |
| Review | `2cbdee8` | An independent reviewer found that `save` took an untrusted row's reviewed value from the lock, so `sysup`'s `save` in a clone wrote an older value over a merged review that had not installed. `save` now keeps a six-field row's value and `--accept` records the value it installed, in its own row, so "then run `claude-config save`" is gone from the docs. A dry run no longer prints `skill updated`, and whitespace on a trusted source line fails `pnpm check` |
| 6, Step 1 | none | The owner took a `fresh-install` run as the proof: run 43986835873 passed on the `clone` and the `installed` path on `2cbdee8`, with `check` green on the same commit. `stable` moved from `2fb0d53` to `2cbdee8` by a fast-forward push |
| 6, Step 2 | none | The owner's first `sysup` after `rotm update` printed `↻ agent skills  2 skills updated: hindsight-docs, microsoft-foundry; 20 unchanged`. Each lock hash then equalled its upstream folder SHA, so the `skills` CLI moves the lock on a reinstall, which "Not verified" had left open |
| 6, Step 3 | none | The owner's second `sysup` printed `✔ agent skills  22 unchanged` |

Still not run for real, because every source is trusted: the workflow's pull request path, `check` on a reopened pull request, `bin/lib/skill-review` on Ubuntu beyond an empty `--list`, and an untrusted skill installing after a merged review. An automated review also noted that the pull request body compares file contents only, so a file-mode change is not listed and a truncated tree listing is not flagged. Look at both before the first untrusted source is added.

Left as it is, on purpose: a review pull request that no longer applies (the change was taken with `--accept`, or upstream went back) stays open until someone closes it, and one untrusted source that cannot be read fails the whole workflow run before any branch moves.

## Owner's decisions (2026-11-16)

Asked and answered in the session that wrote this plan. Do not raise them again.

- **Every source tracked today is trusted.** `jrmatherly/skills`, `anthropics/skills`, `microsoft/azure-skills`, `vectorize-io/hindsight`, `vercel-labs/skills`, `supabase/agent-skills`, `better-auth/skills`, `tt-a1i/archify`, `D4Vinci/Scrapling` and `https://docs.siderolabs.com`. That is all 22 skills.
- **A trusted skill installs at once.** No 48 hour wait. The owner was offered the hold that every package manager has and declined it for skills.
- **Renovate watches the hook pin and opens a pull request.** A person merges it. It is never merged automatically: 0.8.7 renamed three tools and a rule file had to change with it (`2f99ba0`).
- **Plan first.** No code changes before the owner has read this plan.
- **The pull request review is built too.** Asked after the first draft of this plan left it out: the owner wants it for sources added later, so a new source never brings back the hand-run steps.

## Global Constraints

- The gate is `pnpm check`. Every task's last step runs it before the commit. Edit and commit in separate Bash calls.
- One commit per task on `main`, with the subject the task names. `CLAUDE.md`'s standing approval covers the commit and the push.
- A change to behaviour carries its doc edit in the same commit (`CLAUDE.md`, "Docs mirror behavior").
- Never run on this Mac: `sysup`, `./setup.sh`, `rotm update`, `claude-config restore` in any form, `claude-config save` outside a test's fake `HOME`, `npx skills`. The self-checks stub `npx`, `gh` and `curl` and run under a fake `HOME`.
- `CLAUDE.md` is capped at 12,000 bytes. No task edits it. `.claude/rules/claude-config-tool.md` is at 2,357 bytes and `.claude/rules/sysup.md` at 4,749, each under a 6,000 cap.
- Line numbers are those of `main` at `2f99ba0`. An independent reviewer checked every one against the code on 2026-11-16, and the three it found wrong are corrected.

## Decided while writing this plan

Each is a default the owner can change before the task starts.

- **No row uses the pull request review today.** Every tracked source is trusted, so Tasks 3 and 4 are proved by their self-checks and by one manual workflow run that must open nothing. Their first real use is the first skill added from a source that is not on the list.
- **An untrusted GitHub row gains a sixth field, the skill's folder in its repository.** The workflow has no `skills` CLI lock to read the folder from, and a name is not enough: `microsoft/azure-skills` holds two folders named `microsoft-foundry`. `save` writes it from the lock's `skillPath`, and only when the lock holds both a folder hash and a path.
- **The pull request review covers GitHub sources only.** The one well-known source, `https://docs.siderolabs.com`, is trusted, and its lock entry has an empty `skillFolderHash` beside its digest, which is why its row has no reviewed value today (`bin/claude-config:285`: jq's `//` keeps an empty string). An untrusted well-known source keeps today's gate, `sysup`'s notice and `--accept`. `skill-review` skips such a row.
- **One script does the comparison, `bin/lib/skill-review`.** The workflow only runs it and opens the pull request, so the logic has a self-check and the workflow file stays short.
- **One pull request per skill, on the branch `skill-review/<name>`.** A second upstream change while one is open moves the same branch.
- **The pull request is opened with the workflow's own token.** GitHub starts no workflow for an event made with that token, so `check` will not run on it, and `main`'s ruleset requires `check`. The owner closes and reopens the pull request, which starts `check` as an event of their own, or merges with the admin bypass the ruleset already gives: the change is one field of one text file. A token of the owner's as a repository secret would make `check` run unprompted and is the alternative.
- **The repository must let Actions open pull requests, and today it does not.** `gh api repos/jrmatherly/returnofthemac/actions/permissions/workflow` printed `"can_approve_pull_request_reviews":false` on 2026-11-16. Turning on "Allow GitHub Actions to create and approve pull requests" is a repository setting, so it is the owner's step, in Task 4.
- **`--accept` stays.** It is the way to take a change on one Mac before its pull request is merged.
- **Trust is matched on the row's source field, exactly.** The list holds `owner/repo` for a GitHub source and the stored URL for a well-known one, the same text `save` writes.
- **The list is its own file, `agents/claude-skills-trusted.txt`.** `save` rewrites `agents/claude-skills.txt` whole from the CLI's lock, so a line kept there would be lost. `agents/claude-permissions-retired.txt` is the precedent for a hand-kept list beside a generated one.
- **A trusted skill is compared with the installed copy, not a reviewed value.** `upstream <name>` with no second argument already does that (`bin/claude-config:305`). `save` then writes a trusted row without its fifth field, so the tracked file does not change when a skill updates.
- **A trusted skill an agent lacks is installed even when the source cannot be checked.** The hold on an unchecked skill exists because its content is unreviewed, which no longer applies.

## Measured for this plan (2026-11-16)

| Fact | How |
| --- | --- |
| The reviewed value and the folder's tree SHA agree right after an install | The owner's `sysup` reported "20 unchanged" for the 20 skills whose upstream had not moved |
| `--accept` reinstalls over an installed skill for the row's agents | `bin/claude-config:353` sets the agent list, and `bin/lib/test-claude-config:141` asserts the `npx` call |
| `restore` installs nothing over an older installed copy without `--accept` | `bin/claude-config:345-351` builds the agent list only from agents that lack the folder |
| An installed copy cannot record a review | `bin/claude-config:382-383` refuses `save` there |
| Two skills are waiting now | `hindsight-docs`: ten reference files changed, one added, `SKILL.md` unchanged. `microsoft-foundry`: `SKILL.md` and about fourteen references changed, two added. Compared through `gh api` tree listings |
| Actions cannot open a pull request in this repository today | `gh api repos/jrmatherly/returnofthemac/actions/permissions/workflow` printed `{"default_workflow_permissions":"read","can_approve_pull_request_reviews":false}` |
| A self-check must be named in `bin/lib/check` | `bin/lib/check:16` is only the shellcheck glob. Each check has its own `job quiet bash bin/lib/test-…` line (119 to 173), and `bin/lib/test-conventions:212` fails with "self-check not run by bin/lib/check" for one that has none |
| A missing list file does not fail a `while read … < <(grep … file)` loop | Run as a script under `set -euo pipefail`: grep printed its error, the loop ran zero times and the script exited 0 |
| The well-known lock entry has an empty folder hash | `jq '.skills.siderolabs'` on the lock: `"skillFolderHash":""`, a `wellKnownDigest`, and `"skillPath":null` |
| Renovate's regex manager takes these field names | Its documentation page for the regex manager names `customType`, `managerFilePatterns`, `matchStrings`, `depNameTemplate` and `datasourceTemplate`, and requires a `currentValue` group |

### Not verified

- No task was run before this plan was written. The earlier plans in this folder were run red then green in a scratch clone; this one was not.
- The Renovate rule against Renovate itself. Running `renovate-config-validator` here was refused by the session's permission check, so Task 5 reads the result from Renovate's own Dependency Dashboard.
- The workflow on GitHub, beyond `actionlint`. Task 4 runs it once by hand, where it must open nothing. Its pull request path, the repository setting it needs, and `check` starting on a reopened pull request all run for the first time when an untrusted source exists.
- `bin/lib/skill-review` on Ubuntu. Its self-check runs under macOS bash 3.2 and BSD tools, and the workflow runs it under bash 5 and GNU tools. Task 4's manual run covers only `--list` with nothing to list.
- An untrusted skill reinstalling on every `sysup`. Task 3's rule has the same dependence on the CLI moving the lock's hash as the trusted path, and no untrusted row exists to show it.
- Plain `claude-config restore`, which `setup/misc.sh:481` runs on a new Mac, installs each missing skill at its source's newest version with no comparison, for a trusted and an untrusted source alike. That is today's behaviour and this plan leaves it: a merged review governs updates, not a first install.
- That the `skills` CLI updates the lock's `skillFolderHash` on a reinstall. If it did not, a trusted skill would reinstall on every `sysup`. Task 6's second `sysup` is the check.
- Whether Renovate's `minimumReleaseAge` applies to a dependency found by a regex manager. Its documentation page does not say.

## Review Focus

1. **A trusted skill whose reinstall fails.** It must not be reported as updated, and the `sysup` step must fail with the command to rerun. Task 1's Step 1 has the case.
2. **No `gh`, or GitHub's API refusing the call.** An installed trusted skill is left alone and named as "could not check", as today. Task 1's Step 1 has the case.
3. **A source spelled differently in the two files.** It would silently fall back to the review gate. Task 1 adds a `test-conventions` line that fails for a listed source no row uses.
4. **`sysup` in a clone.** It runs `claude-config save` after the update, and the tracked skill list must not change. Task 1's Step 1 has the case.
5. **A skill from a source that is not on the list.** Every existing check in `bin/lib/test-claude-config:126-147` must still pass unchanged.
6. **A merged review on a Mac that holds the older copy.** `restore` must install it, and must not install when upstream has moved again past the merged value. Task 3's Step 1 has both cases.
7. **The list file deleted or renamed.** Every source would silently go back behind the review gate. Task 1's `test-conventions` lines fail on a missing file before the loop.
8. **The workflow when every source is trusted, which is today.** It must exit 0, change nothing and open nothing. Task 4's Step 1 has the case, and its Step 7 runs it for real.

---

### Task 1: Reinstall a trusted skill that moved upstream

**Files:**
- Create: `agents/claude-skills-trusted.txt`
- Modify: `bin/claude-config:21-27` (the header's `--update` and `--accept` bullets, which `help claude-config` renders), `:39-42` (the header's file list), `:55-56` (the path), `:276-297` (`save_skills`), `:335-373` (`restore_skills`)
- Modify: `agents/claude-skills.txt` (the fifth field leaves every row of a trusted source)
- Modify: `docs/claude-config.md:21, 22, 30`, `agents/README.md:38`, `.claude/rules/claude-config-tool.md` (the `restore skills --update` bullet), `docs/forking.md` (a fork-table row for the list)
- Modify: `docs/superpowers/specs/completed/2026-11-16-project-audit.md` (one sentence under decision 2 that points here)
- Test: `bin/lib/test-claude-config` (after line 147), `bin/lib/test-conventions`

**Interfaces:**
- Produces: the output line `skill updated <name>`, printed by `claude-config restore skills --update` once per trusted skill it reinstalled. Task 2 reads it.
- Produces: `agents/claude-skills-trusted.txt`, one source per line, `#` comments and blank lines ignored.
- Produces: `trusted <source>` in `bin/claude-config`. Task 3 uses it.

- [ ] **Step 1: Write the failing checks**

In `bin/lib/test-claude-config`, a block after the `save records the lock's folder SHA` check. It writes `$CLAUDE_CONFIG_SAVE_DIR/claude-skills-trusted.txt` holding `t/r`, adds four skills from `t/r` to the lock, the list and the `gh` stub's tree, and runs `cc restore skills --update`:

| Skill | Lock hash | Stub tree SHA | Installed for `claude-code` | Expected |
| --- | --- | --- | --- | --- |
| `k` | `kold` | `knew` | yes | `skill updated k`, and `-s k -a claude-code` in the `npx` log |
| `l` | `lll` | `lll` | yes | `skill same l`, no `-s l ` in the log |
| `m` | none (no lock entry) | `mmm` | no | `skill updated m`, `-s m -a claude-code` in the log, no `skill held m` and no `skill unknown m` |
| `n` | `nold` | absent from the tree | yes | `skill unknown n`, no `-s n ` in the log |

Two more checks in the same block:

```bash
check "a trusted skill whose reinstall failed is not reported as updated" "! grep -qx 'skill updated k' '$tmp/out'"
check "save writes a trusted source's row with no reviewed value" "grep -qx 'skill k t/r claude-code' '$CLAUDE_CONFIG_SAVE_DIR/claude-skills.txt'"
```

The first runs `restore skills --update` again with an `npx` stub that exits 1. The block comes after line 146's `cc save`, which has rewritten every row from the lock, so it writes its own skill list first, with `skill g o/r claude-code old` among the rows: skill `g` (untrusted, installed past its review) must still print `skill changed g` in every run of this block.

In `bin/lib/test-conventions`, before the `# tlrc rejects a page` comment:

```bash
# A trusted source no row uses is a misspelling: the skill would fall back to the review gate.
# The file test is its own line: a missing file ends the loop below with no error
[ -f agents/claude-skills-trusted.txt ] || fail "agents/claude-skills-trusted.txt is missing"
while read -r source; do
  awk -v s="$source" '$1 == "skill" && $3 == s { f = 1 } END { exit !f }' agents/claude-skills.txt || fail "trusted skill source with no skill: $source"
done < <(grep -Ev '^[[:space:]]*(#|$)' agents/claude-skills-trusted.txt)
```

- [ ] **Step 2: Run them and see them fail**

Run: `bash bin/lib/test-claude-config; bash bin/lib/test-conventions`
Expected: the `skill updated k` check fails, and `test-conventions` prints `FAIL: agents/claude-skills-trusted.txt is missing`.

- [ ] **Step 3: Add the list and `trusted <source>`**

`agents/claude-skills-trusted.txt` holds a two-line header comment and the ten sources of "Owner's decisions", one per line. In `bin/claude-config`, `trusted_list="$save_dir/claude-skills-trusted.txt"` beside `retired_list`, and `trusted <source>`, which exits 0 when the list holds that exact line and 1 otherwise, also when the file is missing.

- [ ] **Step 4: Change `restore_skills` for a trusted row under `--update`**

For a trusted source, and only when `$update` is true and `$accept` is empty: `state=$(upstream "$name")`, with no reviewed value. `same` prints `skill same <name>`. `changed` sets the agent list to every agent on the row and prints `skill updated <name>` after the install, only when that install did not fail. `unknown` prints `skill unknown <name>` when every agent on the row has the skill, and when one lacks it (a skill with no lock entry is always `unknown`, `bin/claude-config:316-322`) it installs for that agent and prints `skill updated <name>` in place of `unknown`, so `sysup` does not report "could not check" for a skill it just installed. In no state is a trusted skill held. An untrusted row takes today's path with no change, and so does `--accept` for any row.

- [ ] **Step 5: Make `save_skills` leave the reviewed value off a trusted row**

One condition where the row is written. Then remove the fifth field from the 21 rows of `agents/claude-skills.txt` that have one, by hand, not with `claude-config save`.

- [ ] **Step 6: Run the checks and see them pass**

Run: `bash bin/lib/test-claude-config && bash bin/lib/test-conventions`
Expected: both exit 0, with the checks of lines 126 to 147 unchanged and passing.

- [ ] **Step 7: Update the docs**

- `bin/claude-config:21-27`, the header: the `--update` bullet says it reinstalls a skill from a trusted source and reports the rest, and the `--accept` bullet says it is for a source not on the list. Each bullet stays one sentence on one line, or `help claude-config` fails to render. `docs/README.md:158` is the alias row for the same commands: change it only if a command spelling changes, which this plan does not do.
- `docs/claude-config.md:21`: `--update` reinstalls a skill from a trusted source when upstream moved past the installed copy, and reports the rest. `:22`: `--accept` is for a source not on the list. `:30`: the fifth field is absent for a trusted source. A new row in the same table for `agents/claude-skills-trusted.txt`, which also says that removing a trusted source's last skill fails `pnpm check` until its line leaves the list.
- `agents/README.md:38`: the list, in one sentence.
- `.claude/rules/claude-config-tool.md`: the bullet says a skill from a source outside `claude-skills-trusted.txt` is never installed past its review, and why a trusted one compares with the installed copy (an installed copy cannot record a review).
- `docs/forking.md`: a fork-table row. The list is the owner's judgment of ten sources; empty it to review every change.
- The audit spec, decision 2: one sentence that this plan lets a listed source update with no review, dated 2026-11-16.

- [ ] **Step 8: Commit**

Run: `pnpm check`
Subject: `Let skills from trusted sources update without a review`

### Task 2: Report an updated skill in `sysup`

**Files:**
- Modify: `bin/sysup:573-576` and `:596-600` (two comments that say a changed skill is never installed), `:601-622`
- Modify: `docs/updating.md:37`, `.claude/rules/sysup.md` (only if it describes this step: `grep -n skill` printed nothing at `2f99ba0`)
- Test: `bin/lib/test-sysup:162` (the `claude-config` stub), `:234, 277` (the neighbouring assertions)

**Interfaces:**
- Consumes: `skill updated <name>` from Task 1.

- [ ] **Step 1: Write the failing checks**

A stub state that prints `skill updated one`, `skill updated two` and `skill same three`, and a second that adds `skill changed four`:

```bash
check_true "changes: updated skills named" has '^↻ agent skills +2 skills updated: one, two; 1 unchanged$'
check_true "changes: an update beside a skill to review is a notice naming both" has '^● agent skills +2 skills updated: one, two; 1 skill changed upstream: four; 1 unchanged; review, then run: claude-config restore skills --accept four$'
```

- [ ] **Step 2: Run them and see them fail**

Run: `LC_ALL=en_US.UTF-8 bash bin/lib/test-sysup`
Expected: both new checks fail, every other check passes.

- [ ] **Step 3: Read `skill updated` and choose the status**

`skills_updated` from `sed -n 's/^skill updated //p'`. With updates and nothing to review the step is `status changed`. With both, it stays a notice and the updated names lead the line. With neither, today's lines are unchanged, which `test-sysup:234` and `:277` already pin.

- [ ] **Step 4: Run the checks, update the doc and commit**

Run: `LC_ALL=en_US.UTF-8 bash bin/lib/test-sysup && pnpm check`
`docs/updating.md:37`: a skill from a trusted source is updated and shown as a change, and one from any other source is reported for review.
Subject: `Show the skills sysup updated`

### Task 3: Install a skill whose review was merged

**Files:**
- Modify: `bin/claude-config:21-27` (the header bullets again), `:276-297` (`save_skills`), `:335-373` (`restore_skills`)
- Modify: `docs/claude-config.md:21, 30`, `.claude/rules/claude-config-tool.md` (the same bullet as Task 1)
- Test: `bin/lib/test-claude-config` (after Task 1's block)

**Interfaces:**
- Consumes: `trusted <source>` and the line `skill updated <name>` from Task 1.
- Produces: the row shape `skill <name> <source> <agents> <reviewed> <folder>` for an untrusted GitHub source whose lock entry holds a folder hash and a `skillPath`. `<folder>` is the directory that holds `SKILL.md`, relative to the repository root, and `.` for a skill at the root. Any other row keeps today's four or five fields. Task 4 reads it.

- [ ] **Step 1: Write the failing checks**

Three skills from the untrusted source `o/r`, each installed for `claude-code`, run through `cc restore skills --update`:

| Skill | Row's reviewed value | Lock hash | Stub tree SHA | Expected |
| --- | --- | --- | --- | --- |
| `p` | `pnew` | `pold` | `pnew` | `skill updated p`, and `-s p -a claude-code` in the `npx` log |
| `q` | `qrev` | `qold` | `qnewer` | `skill changed q`, no `-s q ` in the log |
| `a` (existing) | `aaa` | `aaa` | `aaa` | `skill same a`, no `-s a ` in the log |

```bash
check "save writes an untrusted GitHub row with its folder" "grep -qx 'skill a o/r claude-code aaa skills/a' '$CLAUDE_CONFIG_SAVE_DIR/claude-skills.txt'"
check "save writes a root skill's folder as a dot" "grep -qx 'skill d o/r claude-code rootsha .' '$CLAUDE_CONFIG_SAVE_DIR/claude-skills.txt'"
```

The existing check at line 147 expects `skill a o/r claude-code aaa`: it changes to the first line above.

One more, for the shape the real lock has: a fixture entry with `"sourceType":"well-known"`, `"skillFolderHash":""`, a `wellKnownDigest` and no `skillPath` must be saved as a row of four fields, with no reviewed value and no folder.

- [ ] **Step 2: Run them and see them fail**

Run: `bash bin/lib/test-claude-config`
Expected: the `skill updated p` check and both `save` checks fail.

- [ ] **Step 3: Reinstall when the merged review is ahead of the installed copy**

In `restore_skills`, for an untrusted row under `--update` with no `--accept`: when the row has a folder (so it is a GitHub row), `upstream "$name" "$reviewed"` prints `same`, and the lock's `skillFolderHash` for the skill is a non-empty string other than `$reviewed`, set the agent list to every agent on the row and print `skill updated <name>` after an install that did not fail, in place of `skill same`. A row with no reviewed value or no folder never takes this path, which keeps a well-known row out of it. `read` gains the sixth field so the folder is not read into `reviewed`.

- [ ] **Step 4: Write the folder in `save_skills`**

For a GitHub source that is not trusted, the directory of the lock's `skillPath` follows the reviewed value, and only when the lock's `skillFolderHash` and `skillPath` are both non-empty strings. The jq line emits its columns separated by tabs and the loop reads with `IFS=$'\t'`: with spaces, an empty hash lets the path land in `reviewed`. A trusted row and a well-known row are unchanged.

- [ ] **Step 5: Run the checks, update the docs and commit**

Run: `bash bin/lib/test-claude-config && pnpm check`
`docs/claude-config.md:21`: a skill whose reviewed value moved in the repository is installed on the next `--update`. `:30`: the sixth field. The rule's bullet gains one sentence: the folder is tracked because the review workflow has no lock.
Subject: `Install a skill once its review is merged`

### Task 4: Open a pull request when an untrusted skill changes upstream

**Files:**
- Create: `bin/lib/skill-review`, `bin/lib/test-skill-review`, `.github/workflows/skill-review.yml`
- Modify: `bin/lib/check` (a `job quiet bash bin/lib/test-skill-review` line beside line 143), `bin/CLAUDE.md` (the `bin/lib/` helper list), `.claude/rules/ci.md` (a line for the workflow), `docs/updating.md` (after line 58), `docs/claude-config.md` (a short section), `CLAUDE.md`'s architecture block is not edited (its cap)
- Test: `bin/lib/test-skill-review`

**Interfaces:**
- Consumes: the six-field row from Task 3 and `agents/claude-skills-trusted.txt` from Task 1.
- Produces: `skill-review [--list | <name>]`. `--list` prints the name of each untrusted skill whose upstream value differs from its reviewed value, one per line, and exits 0 also when it prints nothing. `<name>` rewrites that row's reviewed value in `agents/claude-skills.txt` and prints a Markdown body on stdout: the source, the old and new values, the files added, removed and changed between the two folder trees, and a link to the folder's history on GitHub. Exit 1 when a source cannot be read, naming it on stderr. Only a row with six fields is considered, so a well-known row and a trusted row are skipped. On an installed copy `<name>` refuses to write, with the guard `claude-config save` has (`bin/claude-config:382`): `bin/lib` is on `PATH` there.

- [ ] **Step 1: Write the failing self-check**

`bin/lib/test-skill-review`, in the shape of `bin/lib/test-claude-config`: a temp repo copy holding a skill list and a trusted list, with `gh` and `curl` stubbed on `PATH`.

| Case | Expected |
| --- | --- |
| Every source trusted | `--list` prints nothing, exit 0, the list file unchanged |
| Untrusted `u/r` skill `x`, reviewed `xold`, folder `skills/x`, stub tree SHA `xnew` | `--list` prints `x` |
| `skill-review x` | the row reads `skill x u/r claude-code xnew skills/x`, every other row byte-identical, and the body names one changed file and one added file from the stubbed trees |
| Untrusted skill `y`, reviewed value equal to the stub's | not printed by `--list` |
| Two folders named `x` in the stub tree | the row's folder decides, the other is ignored |
| Untrusted well-known skill `w`, a row of five fields | not printed by `--list`, and `skill-review w` exits 1 with `skill-review: w has no folder to compare` |
| `skill-review x` on an installed copy (a stubbed `rotm-mode` printing `installed`) | exit 1, the list file unchanged |
| `gh` exits 1 | exit 1 and `skill-review: cannot read u/r` on stderr, the list file unchanged |

- [ ] **Step 2: Run it and see it fail**

Run: `bash bin/lib/test-skill-review`
Expected: fails at the first case, since the script does not exist.

- [ ] **Step 3: Write `bin/lib/skill-review`**

Bash, `set -euo pipefail`, a header comment in the shape `bin/CLAUDE.md` gives. It resolves the repository from its own path. One `gh api repos/<repo>/git/trees/HEAD?recursive=1` per repository, and one `gh api repos/<repo>/git/trees/<reviewed>?recursive=1` for the old folder when it writes a body. The row is rewritten through a `.tmp` file and `mv`, as `claude-config` writes.

- [ ] **Step 4: Run the self-check and see it pass**

Run: `bash bin/lib/test-skill-review && shellcheck --severity=warning bin/lib/skill-review`
Expected: both exit 0.

- [ ] **Step 5: Write the workflow**

`.github/workflows/skill-review.yml`: `on` is `schedule` (`cron: '17 9 * * *'`) and `workflow_dispatch`. `permissions` is `contents: write` and `pull-requests: write`. One job on `ubuntu-24.04` with a 10 minute timeout, `actions/checkout` at the SHA `check.yml:23` pins, and `GH_TOKEN: ${{ github.token }}`. The checkout keeps its credentials, unlike `check.yml:23-25`, which sets `persist-credentials: false`: this job pushes. A step sets `git config user.name` and `user.email` to the `github-actions[bot]` identity. For each name `bin/lib/skill-review --list` prints: create the branch `skill-review/<name>` from `main`, run `bin/lib/skill-review <name> > body.md`, and compare the rewritten row with the same row on `origin/skill-review/<name>` when that branch exists. Equal means upstream has not moved since the open pull request, so do nothing for that name. Otherwise commit `agents/claude-skills.txt` with the subject `Review <name>: its source changed upstream`, force-push the branch, and `gh pr create --title "Review skill <name>" --body-file body.md`, or `gh pr edit --body-file body.md` when the branch already has an open pull request. No `uses:` step other than the checkout.

- [ ] **Step 6: Update the docs**

`docs/claude-config.md`: adding a skill from a source that is not trusted is `npx skills add`, then `claude-config save` in a clone, and from then on a change upstream arrives as a pull request named "Review skill <name>"; merging it is the review (close and reopen it first to start `check`), and the next `sysup` after promotion installs it; a well-known source is not covered and keeps `--accept`. `docs/updating.md`: one sentence beside Renovate's. `.claude/rules/ci.md`: the workflow, and that `check` does not run on its pull requests because of the token. `bin/CLAUDE.md`: `skill-review` in the helper list.

- [ ] **Step 7: Lint it, commit, and run it once**

Run: `pnpm check` (it runs `actionlint` and the new self-check).
Subject: `Open a pull request when an untrusted skill changes upstream`
After the push: `gh workflow run skill-review.yml --ref main`, then `gh run list --workflow skill-review.yml --limit 1`.
Expected: `success`, and `gh pr list` shows no new pull request, because every source is trusted.

- [ ] **Step 8: Let Actions open pull requests (owner's word)**

A repository setting, so the owner turns it on or says to: Settings, Actions, General, "Allow GitHub Actions to create and approve pull requests". With the owner's word it is `gh api -X PUT repos/jrmatherly/returnofthemac/actions/permissions/workflow -f default_workflow_permissions=read -F can_approve_pull_request_reviews=true`.
Verify: `gh api repos/jrmatherly/returnofthemac/actions/permissions/workflow` prints `"can_approve_pull_request_reviews":true`. Without it the first real pull request is refused, and Step 7's run cannot show that, since it opens nothing.

### Task 5: Let Renovate watch the hook pin

**Files:**
- Modify: `renovate.json` (a top-level `customManagers` array)
- Modify: `.claude/rules/ci.md:14` (the list of what Renovate updates), `docs/updating.md:58` (the same list for readers)
- Test: `bin/lib/test-conventions` (two lines in the release-hold block's neighbourhood)

**Interfaces:** None.

- [ ] **Step 1: Write the failing checks**

```bash
# Renovate's regex manager reads the hook pin: a pin line it cannot match gets no update PR
grep -Eqx 'CODING_AGENTS_VERSION=[0-9]+\.[0-9]+\.[0-9]+' bin/hindsight-memory || fail "renovate: the hook pin is not one bare version on its own line"
jq -e '.customManagers[] | select(.depNameTemplate == "@vectorize-io/hindsight-coding-agents") | .managerFilePatterns == ["bin/hindsight-memory"] and (.matchStrings[0] | contains("CODING_AGENTS_VERSION=(?<currentValue>"))' renovate.json > /dev/null 2>&1 || fail "renovate: no regex manager for the hook pin"
```

- [ ] **Step 2: Run it and see it fail**

Run: `bash bin/lib/test-conventions`
Expected: `FAIL: renovate: no regex manager for the hook pin`

- [ ] **Step 3: Add the manager**

```json
"customManagers": [
  {
    "customType": "regex",
    "description": "The Hindsight hook package pin. A PR, never an automatic merge: 0.8.7 renamed three tools and a rule file changed with it",
    "managerFilePatterns": ["bin/hindsight-memory"],
    "matchStrings": ["CODING_AGENTS_VERSION=(?<currentValue>\\S+)"],
    "depNameTemplate": "@vectorize-io/hindsight-coding-agents",
    "datasourceTemplate": "npm"
  }
]
```

The pattern is a plain path, the style `renovate.json` already uses for mise (`tilde/.config/mise/conf.d/60-rotm-*.toml`). The reviewer ran the jq check on a scratch copy: exit 0 with the manager, non-zero without the key and with an empty array. No existing `packageRules` entry matches this dependency. No `automerge` key anywhere. The `sysup` notice for a newer release stays: it covers a Mac whose Renovate PR is not merged yet.

- [ ] **Step 4: Run the checks, update the two lists and commit**

Run: `bash bin/lib/test-conventions && pnpm check`
Subject: `Have Renovate watch the Hindsight hook pin`

- [ ] **Step 5: Read Renovate's verdict (after its next run)**

Run: `gh issue list --search "Dependency Dashboard in:title" --json number,body -q '.[0].body' | grep -c hindsight-coding-agents`
Expected: 1 or more, and no "config error" issue (`gh issue list --search "Action Required"` prints nothing). Renovate runs on its own schedule, so this may be hours after the push. A config error is fixed in a follow-up commit, not by removing the manager.

### Task 6: Promote, take the two waiting skills, and file the plan

Run last. Step 1 moves `stable`: it needs the owner's word.

**Files:**
- Modify: `docs/superpowers/plans/README.md`
- Move: this plan to `plans/completed/`

**Interfaces:** None.

- [ ] **Step 1: Promote (owner's word)**

`main` also holds the Hindsight daemon-stop fix, the dependency updates and the 0.8.7 hook pin, none of them promoted. Put the choice to the owner as `setup/README.md:80-88` asks: Guest A first, or a `fresh-install` run on the tip of `main` as the proof. Then, on the owner's word only: `git push origin <sha>:refs/heads/stable`. The owner runs `rotm update`, then `sysup`.

- [ ] **Step 2: Read the owner's `sysup` output**

Expected: `↻ agent skills  2 skills updated: hindsight-docs, microsoft-foundry; 20 unchanged`. This is the first real run of the path, and it takes the two skills that were waiting.

- [ ] **Step 3: Check that the update is not repeated**

After the owner's next `sysup`, or from its log: `✔ agent skills  22 unchanged`. A skill updated twice in a row means the CLI did not move the lock's hash ("Not verified"), and that is a bug to fix before filing.

- [ ] **Step 4: Record the outcome and file the plan**

Add an "Outcome" table to this plan with each task's commit and any difference from it. Move it to `plans/completed/` and remove its row from the README's "Open plans" table.

Subject: `File the trusted skill sources plan as completed`
