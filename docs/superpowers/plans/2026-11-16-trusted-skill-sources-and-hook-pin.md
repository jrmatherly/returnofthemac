# Trusted skill sources and a watched hook pin, Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `sysup` installs an upstream change to an agent skill by itself when the skill's source is one the owner trusts, a change from any other source arrives as a pull request whose merge is the review, and Renovate opens a pull request when the Hindsight hook package has a new release, so none of the three needs a hand-run command.

**Architecture:** Trust is a property of a source, kept as one tracked list beside the skill list. `claude-config restore skills --update` reinstalls a trusted skill whose upstream moved past the installed copy and says so on one line, which `sysup` turns into a changed step. A trusted row carries no reviewed value, so an update never changes a tracked file and needs no promotion. For a source that is not trusted, a scheduled workflow runs one script that compares each reviewed value with upstream and opens a pull request moving it, and `restore` then installs a skill whose merged review is ahead of the installed copy. The hook pin gets a Renovate regex manager and nothing else.

**Tech Stack:** bash 3.2, jq, `gh api`, the `skills` CLI through `npx`, GitHub Actions, Renovate (Mend app).

**Spec:** None of its own. This plan changes decision 2 of [`docs/superpowers/specs/completed/2026-11-16-project-audit.md`](../specs/completed/2026-11-16-project-audit.md) ("the reviewed folder hash stays the only check"), and the section below is the record of that change. Read it and the audit's "Owner's decisions" before starting.

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
- Line numbers are those of `main` at `2f99ba0`.

## Decided while writing this plan

Each is a default the owner can change before the task starts.

- **No row uses the pull request review today.** Every tracked source is trusted, so Tasks 3 and 4 are proved by their self-checks and by one manual workflow run that must open nothing. Their first real use is the first skill added from a source that is not on the list.
- **An untrusted GitHub row gains a sixth field, the skill's folder in its repository.** The workflow has no `skills` CLI lock to read the folder from, and a name is not enough: `microsoft/azure-skills` holds two folders named `microsoft-foundry`. `save` writes it from the lock's `skillPath`. A well-known row needs none, since its digest is looked up by name.
- **One script does the comparison, `bin/lib/skill-review`.** The workflow only runs it and opens the pull request, so the logic has a self-check and the workflow file stays short.
- **One pull request per skill, on the branch `skill-review/<name>`.** A second upstream change while one is open moves the same branch.
- **The pull request is opened with the workflow's own token.** GitHub starts no workflow for an event made with that token, so `check` will not run on it, and `main`'s ruleset expects `check`. The owner merges with the bypass the ruleset already gives them: the change is one field of one text file. A token of the owner's as a repository secret would make `check` run and is the alternative.
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
| Renovate's regex manager takes these field names | Its documentation page for the regex manager names `customType`, `managerFilePatterns`, `matchStrings`, `depNameTemplate` and `datasourceTemplate`, and requires a `currentValue` group |

### Not verified

- No task was run before this plan was written. The earlier plans in this folder were run red then green in a scratch clone; this one was not.
- The Renovate rule against Renovate itself. Running `renovate-config-validator` here was refused by the session's permission check, so Task 5 reads the result from Renovate's own Dependency Dashboard.
- The workflow on GitHub, beyond `actionlint`. Task 4 runs it once by hand, where it must open nothing. Its pull request path runs for the first time when an untrusted source exists.
- That the `skills` CLI updates the lock's `skillFolderHash` on a reinstall. If it did not, a trusted skill would reinstall on every `sysup`. Task 6's second `sysup` is the check.
- Whether Renovate's `minimumReleaseAge` applies to a dependency found by a regex manager. Its documentation page does not say.

## Review Focus

1. **A trusted skill whose reinstall fails.** It must not be reported as updated, and the `sysup` step must fail with the command to rerun. Task 1's Step 1 has the case.
2. **No `gh`, or GitHub's API refusing the call.** An installed trusted skill is left alone and named as "could not check", as today. Task 1's Step 1 has the case.
3. **A source spelled differently in the two files.** It would silently fall back to the review gate. Task 1 adds a `test-conventions` line that fails for a listed source no row uses.
4. **`sysup` in a clone.** It runs `claude-config save` after the update, and the tracked skill list must not change. Task 1's Step 1 has the case.
5. **A skill from a source that is not on the list.** Every existing check in `bin/lib/test-claude-config:126-147` must still pass unchanged.
6. **A merged review on a Mac that holds the older copy.** `restore` must install it, and must not install when upstream has moved again past the merged value. Task 3's Step 1 has both cases.
7. **The workflow when every source is trusted, which is today.** It must exit 0, change nothing and open nothing. Task 4's Step 1 has the case, and its Step 7 runs it for real.

---

### Task 1: Reinstall a trusted skill that moved upstream

**Files:**
- Create: `agents/claude-skills-trusted.txt`
- Modify: `bin/claude-config:36` (the header's file list), `:55-56` (the path), `:276-296` (`save_skills`), `:338-372` (`restore_skills`)
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
| `m` | none | `mmm` | no | `-s m -a claude-code` in the log, no `skill held m` |
| `n` | `nold` | absent from the tree | yes | `skill unknown n`, no `-s n ` in the log |

Two more checks in the same block:

```bash
check "a trusted skill whose reinstall failed is not reported as updated" "! grep -qx 'skill updated k' '$tmp/out'"
check "save writes a trusted source's row with no reviewed value" "grep -qx 'skill k t/r claude-code' '$CLAUDE_CONFIG_SAVE_DIR/claude-skills.txt'"
```

The first runs `restore skills --update` again with an `npx` stub that exits 1. Skill `g` (untrusted, installed past its review) must still print `skill changed g` in every run of this block.

In `bin/lib/test-conventions`, before the `# tlrc rejects a page` comment:

```bash
# A trusted source no row uses is a misspelling: the skill would fall back to the review gate
while read -r source; do
  awk -v s="$source" '$1 == "skill" && $3 == s { f = 1 } END { exit !f }' agents/claude-skills.txt || fail "trusted skill source with no skill: $source"
done < <(grep -Ev '^[[:space:]]*(#|$)' agents/claude-skills-trusted.txt)
```

- [ ] **Step 2: Run them and see them fail**

Run: `bash bin/lib/test-claude-config; bash bin/lib/test-conventions`
Expected: the `skill updated k` check fails, and `test-conventions` fails on the missing list file.

- [ ] **Step 3: Add the list and `trusted <source>`**

`agents/claude-skills-trusted.txt` holds a two-line header comment and the ten sources of "Owner's decisions", one per line. In `bin/claude-config`, `trusted_list="$save_dir/claude-skills-trusted.txt"` beside `retired_list`, and `trusted <source>`, which exits 0 when the list holds that exact line and 1 otherwise, also when the file is missing.

- [ ] **Step 4: Change `restore_skills` for a trusted row under `--update`**

For a trusted source, and only when `$update` is true and `$accept` is empty: `state=$(upstream "$name")`, with no reviewed value. `same` prints `skill same <name>`. `changed` sets the agent list to every agent on the row and prints `skill updated <name>` after the install, only when that install did not fail. `unknown` prints `skill unknown <name>`. In no state is a trusted skill held: an agent that lacks it gets it. An untrusted row takes today's path with no change.

- [ ] **Step 5: Make `save_skills` leave the reviewed value off a trusted row**

One condition where the row is written. Then remove the fifth field from the 21 rows of `agents/claude-skills.txt` that have one, by hand, not with `claude-config save`.

- [ ] **Step 6: Run the checks and see them pass**

Run: `bash bin/lib/test-claude-config && bash bin/lib/test-conventions`
Expected: both exit 0, with the checks of lines 126 to 147 unchanged and passing.

- [ ] **Step 7: Update the docs**

- `docs/claude-config.md:21`: `--update` reinstalls a skill from a trusted source when upstream moved past the installed copy, and reports the rest. `:22`: `--accept` is for a source not on the list. `:30`: the fifth field is absent for a trusted source. A new row in the same table for `agents/claude-skills-trusted.txt`.
- `agents/README.md:38`: the list, in one sentence.
- `.claude/rules/claude-config-tool.md`: the bullet says a skill from a source outside `claude-skills-trusted.txt` is never installed past its review, and why a trusted one compares with the installed copy (an installed copy cannot record a review).
- `docs/forking.md`: a fork-table row. The list is the owner's judgment of ten sources; empty it to review every change.
- The audit spec, decision 2: one sentence that this plan lets a listed source update with no review, dated 2026-11-16.

- [ ] **Step 8: Commit**

Run: `pnpm check`
Subject: `Let skills from trusted sources update without a review`

### Task 2: Report an updated skill in `sysup`

**Files:**
- Modify: `bin/sysup:601-622`
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
- Modify: `bin/claude-config:276-296` (`save_skills`), `:338-372` (`restore_skills`)
- Modify: `docs/claude-config.md:21, 30`, `.claude/rules/claude-config-tool.md` (the same bullet as Task 1)
- Test: `bin/lib/test-claude-config` (after Task 1's block)

**Interfaces:**
- Consumes: `trusted <source>` and the line `skill updated <name>` from Task 1.
- Produces: the row shape `skill <name> <source> <agents> <reviewed> <folder>` for an untrusted GitHub source. `<folder>` is the directory that holds `SKILL.md`, relative to the repository root, and `.` for a skill at the root. Task 4 reads it.

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

- [ ] **Step 2: Run them and see them fail**

Run: `bash bin/lib/test-claude-config`
Expected: the `skill updated p` check and both `save` checks fail.

- [ ] **Step 3: Reinstall when the merged review is ahead of the installed copy**

In `restore_skills`, for an untrusted row under `--update` with no `--accept`: when `upstream "$name" "$reviewed"` prints `same` and the lock's hash for the skill (`skillFolderHash` or `wellKnownDigest`) is not `$reviewed`, set the agent list to every agent on the row and print `skill updated <name>` after an install that did not fail, in place of `skill same`. A row with no reviewed value never takes this path. `read` gains the sixth field so the folder is not read into `reviewed`.

- [ ] **Step 4: Write the folder in `save_skills`**

For a GitHub source that is not trusted, the directory of the lock's `skillPath` follows the reviewed value. A trusted row and a well-known row are unchanged.

- [ ] **Step 5: Run the checks, update the docs and commit**

Run: `bash bin/lib/test-claude-config && pnpm check`
`docs/claude-config.md:21`: a skill whose reviewed value moved in the repository is installed on the next `--update`. `:30`: the sixth field. The rule's bullet gains one sentence: the folder is tracked because the review workflow has no lock.
Subject: `Install a skill once its review is merged`

### Task 4: Open a pull request when an untrusted skill changes upstream

**Files:**
- Create: `bin/lib/skill-review`, `bin/lib/test-skill-review`, `.github/workflows/skill-review.yml`
- Modify: `bin/CLAUDE.md` (the `bin/lib/` helper list), `.claude/rules/ci.md` (a line for the workflow), `docs/updating.md` (after line 58), `docs/claude-config.md` (a short section), `CLAUDE.md`'s architecture block is not edited (its cap)
- Test: `bin/lib/test-skill-review`. `bin/lib/check:16` runs every `bin/lib/test-*`, so it needs no registration

**Interfaces:**
- Consumes: the six-field row from Task 3 and `agents/claude-skills-trusted.txt` from Task 1.
- Produces: `skill-review [--list | <name>]`. `--list` prints the name of each untrusted skill whose upstream value differs from its reviewed value, one per line, and exits 0 also when it prints nothing. `<name>` rewrites that row's reviewed value in `agents/claude-skills.txt` and prints a Markdown body on stdout: the source, the old and new values, the files added, removed and changed between the two folder trees, and a link to the folder's history on GitHub. Exit 1 when a source cannot be read, naming it on stderr.

- [ ] **Step 1: Write the failing self-check**

`bin/lib/test-skill-review`, in the shape of `bin/lib/test-claude-config`: a temp repo copy holding a skill list and a trusted list, with `gh` and `curl` stubbed on `PATH`.

| Case | Expected |
| --- | --- |
| Every source trusted | `--list` prints nothing, exit 0, the list file unchanged |
| Untrusted `u/r` skill `x`, reviewed `xold`, folder `skills/x`, stub tree SHA `xnew` | `--list` prints `x` |
| `skill-review x` | the row reads `skill x u/r claude-code xnew skills/x`, every other row byte-identical, and the body names one changed file and one added file from the stubbed trees |
| Untrusted skill `y`, reviewed value equal to the stub's | not printed by `--list` |
| Two folders named `x` in the stub tree | the row's folder decides, the other is ignored |
| Untrusted well-known skill `w`, digest moved in the stubbed `index.json` | `--list` prints `w`, and `skill-review w` rewrites the digest with no file list in the body |
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

`.github/workflows/skill-review.yml`: `on` is `schedule` (`cron: '17 9 * * *'`) and `workflow_dispatch`. `permissions` is `contents: write` and `pull-requests: write`. One job on `ubuntu-24.04` with a 10 minute timeout, `actions/checkout` at the SHA `check.yml:23` pins, and `GH_TOKEN: ${{ github.token }}`. For each name `bin/lib/skill-review --list` prints: create or reset the branch `skill-review/<name>` from `main`, run `bin/lib/skill-review <name> > body.md`, commit `agents/claude-skills.txt` with the subject `Review <name>: its source changed upstream`, force-push that branch, and `gh pr create --title "Review skill <name>" --body-file body.md`, or `gh pr edit` when the branch already has an open pull request. No `uses:` step other than the checkout.

- [ ] **Step 6: Update the docs**

`docs/claude-config.md`: adding a skill from a source that is not trusted is `npx skills add`, then `claude-config save` in a clone, and from then on a change upstream arrives as a pull request named "Review skill <name>"; merging it is the review, and the next `sysup` after promotion installs it. `docs/updating.md`: one sentence beside Renovate's. `.claude/rules/ci.md`: the workflow, and that `check` does not run on its pull requests because of the token. `bin/CLAUDE.md`: `skill-review` in the helper list.

- [ ] **Step 7: Lint it, commit, and run it once**

Run: `pnpm check` (it runs `actionlint` and the new self-check).
Subject: `Open a pull request when an untrusted skill changes upstream`
After the push: `gh workflow run skill-review.yml --ref main`, then `gh run list --workflow skill-review.yml --limit 1`.
Expected: `success`, and `gh pr list` shows no new pull request, because every source is trusted.

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
jq -e '.customManagers[] | select(.depNameTemplate == "@vectorize-io/hindsight-coding-agents") | .managerFilePatterns == ["/^bin/hindsight-memory$/"] and (.matchStrings[0] | contains("CODING_AGENTS_VERSION=(?<currentValue>"))' renovate.json > /dev/null || fail "renovate: no regex manager for the hook pin"
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
    "managerFilePatterns": ["/^bin/hindsight-memory$/"],
    "matchStrings": ["CODING_AGENTS_VERSION=(?<currentValue>\\S+)"],
    "depNameTemplate": "@vectorize-io/hindsight-coding-agents",
    "datasourceTemplate": "npm"
  }
]
```

No `automerge` key anywhere. The `sysup` notice for a newer release stays: it covers a Mac whose Renovate PR is not merged yet.

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
