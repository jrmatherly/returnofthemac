# Quiet, summarised output for setup, `rotm update` and `sysup`

Date: 2026-11-25. Status: decided, not built.

## Goal

A run of `./setup.sh` (which `rotm update` runs) or `sysup` shows the owner only what is useful to read or act on. Everything else goes to the run's log file. The owner raised this after a `rotm update` on a Mac where nothing changed printed 176 lines.

## Decisions the owner made (2026-11-25)

1. **Quiet by default everywhere.** A first install and a re-run print the same way. No separate "update" mode.
2. **An unchanged step gets one summary line**, such as "33 tools already installed". It is not silent.
3. **Changes are listed at the end of the run, grouped by type** (additions, removals and so on), in a finished summary. They are not scattered through the run.
4. **The verbose output is kept in the log file.** The terminal is for what is actionable or useful.
5. **Result lines carry a status mark** (a green check, a red cross and so on).
6. **The free-space line gets clear separation and a colour that depends on how much space is free.**
7. **Each line sits under the step that owns it.** No line may appear under an unrelated heading.

## Measured on 2026-11-25

One `rotm update` with nothing to change, read from `private/setup-logs/20261125-161813.log`: 176 lines.

| Kind of line | Count |
| --- | --- |
| `already installed`, one per mise tool | 40 |
| "already registered", "already connected", "unchanged", "up to date" | about 20 |
| Raw tool output (a JSON blob, `Checked 206 packages`, pnpm timings) | about 12 |
| Catalog lint, one per connector | 13 |
| `bin/nyan` art after "All done!" | 18 |

## What the owner marked up

`rotm update` / `setup.sh`:

- A1. Add status marks to result lines: "Sudo activated!", "mise files: all files are applied", "mise brew: 147 package(s) already installed", the `mise bootstrap` part lines, "Sudo released".
- A2. "81Gi free on /" needs separation from the lines around it and a colour by free space. It also runs straight into the next `==>` title with no blank line.
- A3. The mise tool list: one line per already-installed tool serves no purpose.
- A4. "Overly verbose": the CodeGraph step (it carries a telemetry confirmation, a `DO_NOT_TRACK` warning, three "MCP server already registered" lines, "The dependencies are already installed" and a JSON blob) and the SnippetsLab step.
- A5. Wrong owner: the astro-docs, better-auth and siderolabs-docs MCP lines print under the SnippetsLab heading. The itsaplan MCP line and "Telemetry is disabled." print under the rtk heading.
- A6. "Telemetry is disabled." does not say whose telemetry.
- A7. The catalog's "wrote … 411 skills, 45 commands, …" line is hard to read as one wrapped line.
- A8. The catalog lint lines: remove.

`sysup`:

- S1. "packages cleanup: 1 old version removed, 3 links fixed" does not say what was removed or which links. The final summary must say.
- S2. "Hindsight memory: newer release 0.8.8 on npm; bump CODING_AGENTS_VERSION" asks for a manual step. See "Hindsight pin" below.
- S3. Thirteen catalog lint notices, each on its own line and each repeated under Notices: remove.

## Other things found while reading the same runs

- B1. `rotm update` prints git's raw fetch and pull output (about 14 lines: "remote: Enumerating objects…", "Your branch is behind…", the diffstat). One line is enough: the branch, the old and new commit, and the number of files.
- B2. `mise bootstrap` prints eight lines for four parts that all say "already applied".
- B3. The task echo `[bootstrap] $ "${DOTFILES:-$HOME/dotfiles}/setup/misc.sh"` and "mise bootstrap: running `bootstrap` task" are mise's own plumbing.
- B4. `[skipped] ~/.gitconfig.local` and `[skipped] Firefox styles` use a third style of marker.
- B5. `sysup` prints four `mise hold` lines. They are useful, so they stay, but a count line plus the detail in the summary would match decision 3.
- B6. `bin/nyan` prints 18 lines of art after "All done!". It is the owner's flourish, so it stays unless the owner says otherwise. It must be the last thing printed.
- B7. A step that fails must print the end of its captured output and the log path, because the raw output is no longer on screen.

## Design

### One vocabulary

`sysup` already has the model: `step`, `capture`, `status`, `rows`, an end summary and a log. Setup adopts the same marks and line shape:

| Mark | Meaning |
| --- | --- |
| `✔` green | nothing to do, or done with nothing worth listing |
| `↻` | changed |
| `●` amber | notice: the owner may want to act |
| `✖` red | failed |
| `›` | waiting on the owner (a prompt, sudo) |

A line is `<mark> <step name, padded> <message>`. The repo has no shared shell library (`CLAUDE.md`, "Output helpers are defined inline per script"), so each script defines its own small helpers. Keep them identical in behaviour.

### The data shape

Every step produces one **result**: a status (`ok`, `changed`, `notice`, `fail`), a step name, a one-line message, and zero or more **change records**. A change record is `type<TAB>name<TAB>detail`. Types are a closed list: `package`, `tool`, `extension`, `link`, `mcp`, `plugin`, `skill`, `setting`, `file`, `other`.

`setup/misc.sh` runs as a separate mise task, so it cannot share shell variables with `setup.sh`. It already passes warnings through the file `$ROTM_WARNINGS_FILE`. Change records travel the same way, through a file whose path `setup.sh` exports (name it `ROTM_CHANGES_FILE`). `setup/dotfiles-extras.sh` uses it too.

### The log

Today `setup.sh` re-executes itself under `script -q`, which records only what reaches the terminal. Once steps are quiet, that log would lose the detail. So setup writes its own log, the way `sysup` does: every step's captured output is appended to `private/setup-logs/<timestamp>.log`, and every line shown on the terminal is written there too. Drop the `script` re-exec only if prompts, `sudo` and colour still work without it; check each. `/validate-setup after` reads this log, so it must still hold the whole run.

### What the terminal shows

- A section title per phase (links, formulae, casks, bootstrap, tools, the misc task, extensions), as now.
- Under it, one line per step.
- While a step runs, a transient "working" line that is erased when the step ends, as `sysup` does. A fresh install can spend minutes in one step, and a silent terminal reads as a hang.
- Prompts, `sudo` and anything that needs an answer stay on the terminal.
- Free space: its own line with a blank line before the next title. Green at 20 GiB or more, amber under 20 GiB, red under 10 GiB. The full install measured about 32 GB, which is why the line exists.
- MCP registrations become one step, "MCP servers", with one line: "14 registered" or "13 registered, 1 added". This fixes A5.
- A telemetry opt-out is part of the step for the tool it belongs to. Its confirmation goes to the log. This fixes A6.
- The end summary, in this order: the totals line, **Changed** grouped by type, **Notices**, **Failed**, then the log path. With nothing changed it says so in one line.
- `--verbose` restores live output for debugging.

### `sysup`

- A step that produces several notices of one kind prints one line with a count, and the summary lists them once. The catalog step is the case in hand.
- `packages cleanup` records what it removed and which links it fixed, and the summary's Changed section lists them (S1).

### `rotm update`

Capture git's output to the log. Print one line: `✔ returnofthemac  stable 2df15c2 → b3111ca, 2 files`, or `✔ returnofthemac  stable up to date`.

### Hindsight pin (S2)

It is already automated as far as the repo allows. `renovate.json` watches `CODING_AGENTS_VERSION` in `bin/hindsight-memory` and opens a pull request, which is PR 24 today. The rule's own description says why it never merges by itself: "0.8.7 renamed three tools and a rule file changed with it". So the manual step is merging that PR, not editing the file. The `sysup` notice should say that: "newer release 0.8.8; merge the Renovate PR". Auto-merging patch releases would reverse a recorded choice, so it is the owner's call and is not part of this work.

## Order of work

Each unit ends in a check that passes before the next starts.

1. `sysup`: collapse repeated notices, detail for `packages cleanup`, the Hindsight wording. Check: `LC_ALL=en_US.UTF-8 bash bin/lib/test-sysup`.
2. `setup/misc.sh` and `setup/dotfiles-extras.sh`: one line per step, the "MCP servers" step, change records, the catalog line. Check: `bash bin/lib/test-bootstrap` and a dry run.
3. `setup.sh`: the phases, the log, the free-space line, the end summary, `--verbose`. Check: `bash bin/lib/test-bootstrap`, then a real run by the owner.
4. `rotm update`: the one-line git summary. Check: `bash bin/lib/test-bin` or the test that covers `bin/rotm`.

Docs that describe the output change with it: `setup/README.md`, `docs/updating.md`, `.claude/rules/setup.md`, `.claude/rules/sysup.md`.

## Not in scope

- Changing what any step does. Only what it prints.
- mise's own output format. Where mise prints, setup captures it and prints its own line.
- Auto-merging the Hindsight pin.

## What is not verified

- Whether `sudo` and the `gh auth login` prompt behave without the `script` re-exec.
- How a first install reads. Only an unchanged re-run was measured. The disposable VM is the place to look.
