# Project audit, 2026-11-16

A read-only audit of this repository at `f56b558`, run on 2026-11-16. It records what was found, how each finding was checked, and what to do about it. The plan built on it is [2026-11-16-audit-fixes](../plans/completed/2026-11-16-audit-fixes.md).

## Goal

Give the owner a checked list of real problems, gaps and opportunities, so the owner can choose which to fix. Nothing was changed during the audit.

## How it was run

Six read-only workers each took one area: the recorded open items, `bin/` and `zsh/`, the install path, the Python code, the Swift app with CI, and the docs. The session that started them then re-ran or re-read the top claims from each.

The evidence column uses three words.

- **Reproduced.** The lead session ran it and saw the result.
- **Confirmed.** The lead session read the cited lines, or re-ran the worker's read-only command.
- **Worker ran.** The worker reproduced it in a scratch folder. The lead session did not repeat it.

State at the start: `pnpm check` exits 0 in 1 minute 58 seconds on this Mac, CI is green, no plan is open, and the settings registry's 113 entries all resolve.

## Owner's decisions

The section "E. Decisions the owner must make" lists six. All six are answered. Decisions 1, 4 and 5 have no task yet and wait for a plan. A plan task that waits on one names it.

- **2026-11-16, decision 6: yes.** Seed Mole's two whitelists on an installed copy. Task 8 of the plan ran. On the owner's Mac `whitelist` already links to its own `whitelist.local`, so only `whitelist_optimize` needs the hand step.
- **2026-11-16, Task 5: yes to all four steps.** The ruleset on `stable`, required SHA pins, vulnerability alerts and one `fresh-install` run. Rows A5, D3 and D8 record each result.
- **2026-11-16, promotion without the VM pass.** The owner skipped Guest A for this promotion. `stable` moved from `f56b558` to `d68d3ac` by a fast-forward push, with `check` green on `d68d3ac`. `fresh-install` had passed on `1a9bb95` only, so the owner's own `rotm update` is the first install of the later commits.
- **2026-11-16, decision 1: a 48 hour hold everywhere.** A tracked global `~/.config/uv/uv.toml` with `exclude-newer = "48 hours"`, and pnpm (`pnpm-workspace.yaml`), bun (`tilde/.bunfig.toml`), npm (`setup/misc.sh`, in whole days, so 2) and Renovate (`renovate.json`) all move from 7 days to 48 hours, matching mise. Tested the same day: uv 0.13.8 reads `exclude-newer = "7 days"` from a config file named by `UV_CONFIG_FILE`. Settled the same day: uv's configuration page says `tool` commands ignore local files and read only the user-level and system-level ones, and its settings reference accepts a duration such as `24 hours` for the top-level `exclude-newer`. A scratch `uv tool install ruff` under a user-level `uv.toml` with a 2023 cutoff installed 0.0.205 where no config installed 0.17.5, and with `48 hours` the receipt recorded `exclude-newer-span = "PT48H"`.
- **2026-11-16, decision 2: leave as is.** Skills are not pinned to a commit. The reviewed folder hash in `agents/claude-skills.txt` stays the only check.
- **2026-11-16, decision 3: leave as is.** No mise lockfile. Thirteen tools are `latest` (counted the same day), held 48 hours by `minimum_release_age`.
- **2026-11-16, decision 4: a module for Claude Multipass only.** The tap, `claude-multipass` and `claude-multipass-app` move from `30-packages.toml` to a module that is on by default. `brew:ruby` stays in the base, since the `menubar` module's cask needs it too. `gnupg` and `pinentry-mac` stay in the base. The whole base list was read: nothing else in it is the owner's alone.
- **2026-11-16, decision 5: the hook stays on by default and is switched off per project.** Measured the same day over every project's transcripts: 3,841 firings in 24 projects injected about 5.7 million tokens (about 2,300 a prompt in the full-source form), and a file the hook named was read, edited or cited later in the same turn in 13% of them (career-ops 13%, this repository 11%, serviceradar 4%, focused code worktrees 30 to 43%). The measure counts later file use, not an answer given straight from the injected context. CodeGraph 1.6.2 is the latest release and its README does not describe the hook. Its code has a kill switch, `CODEGRAPH_NO_PROMPT_HOOK=1` (or `CODEGRAPH_PROMPT_HOOK=0`), tested: the same prompt gave 9,251 characters without it and none with it. Nothing limits the size, and the hook is already silent on a prompt with no structural keyword or indexed symbol. Settled the same day from the Claude Code docs: the `env` setting sets variables "for every session and for the subprocesses Claude Code starts from it" (settings reference), a hook process inherits that environment (hooks reference), and project and local `env` values apply once the folder is trusted. In this session a user-settings `env` value was present in a Bash subprocess. Not tested: the variable in a project file silencing the hook in a live session, which the first project switched will show. First projects: this repository, serviceradar and llm-router's main checkout.

## A. Fix first

| Id | Finding | Where | Evidence |
| --- | --- | --- | --- |
| A1 | A directory name runs as a command at every prompt. The title hook calls `print -P`, and starship turns on `promptsubst`, so `print -P` expands `$(...)` in the folder name. | `tilde/.zshrc:17-23` | Reproduced. In a folder named `$(touch PWNED)`, an interactive zsh with this config created `PWNED` |
| A2 | A failed write during replay erases the applied record. `_replay` saves only the ids it wrote, so a later reset from another Mac never reaches this one. A failed reset keeps its record (line 139). A failed write does not. | `settings/src/dotfiles_settings/sync.py:124-141` | Worker ran a repro with a stub adapter. Confirmed by reading |
| A3 | `git tidy` runs a bare `git prune`, which deletes a dropped stash's commit at once. | `bin/git-tidy:25` | Worker ran. Confirmed the line |
| A4 | `sharp@0.35.4` has a high advisory, GHSA-wq5f-xc86-pv6w. It arrives through `avif`, so Renovate does not see it, and the repository's vulnerability alerts are off. | `pnpm-lock.yaml` | Reproduced with `pnpm audit` |
| A5 | `stable` has no protection. Installed Macs pull it, and nothing blocks a force-push or a deletion. | GitHub settings | Reproduced. The protection API returns 404 and the branch rules list is empty. **Done 2026-11-16:** ruleset 27382636 blocks deletion and force-push of `stable`, and `rules/branches/stable` lists `deletion` and `non_fast_forward` |

## B. Commands that write into an installed copy

Each one changes a tracked file in mise's checkout, and `rotm update` then refuses.

| Id | Finding | Where | Evidence |
| --- | --- | --- | --- |
| B1 | `obsidian-vault capture` has no installed-copy check. Already recorded in the plans README. | `bin/obsidian-vault:72-88` | Confirmed |
| B2 | `claude-config save` has no installed-copy check. `sysup` skips it there, but the docs list it as a command to run. | `bin/claude-config:380-386` | Confirmed. The script never calls `rotm-mode` |
| B3 | The two Mole whitelists are links into the checkout, so Mole's own editors write there. Already recorded, and `docs/mole.md:115` warns about it. | `40-dotfiles.toml:88-89` | Confirmed |
| B4 | `mise use -g` edits the tracked `config.toml`, and `docs/README.md:105` tells the reader to edit that file by hand. | `~/.config/mise` | Reproduced with a dry run |

One worker claim under this heading was wrong and is dropped. `bin/vscode-settings:44-46` does keep its render out of the checkout, because `config.rotm-installed.toml` makes `Code/User` a real folder.

## C. Small broken behaviours

| Id | Finding | Where | Evidence |
| --- | --- | --- | --- |
| C1 | `push` calls `get_parent`, which is defined nowhere. Every push from a feature branch prints "command not found". | `bin/push:71` | Confirmed with `git grep` |
| C2 | `push` builds a wrong compare URL for an `ssh://` remote and for a `git@` remote without `.git`. | `bin/push:80-87` | Worker ran |
| C3 | `pull` prints "rolling back" on a rebase conflict, then only pops the stash. The rebase stays half-done and the pop fails. | `bin/pull:35-40` | Worker ran. Confirmed the code |
| C4 | `node-modules-clean` deletes a plain file named `node_modules`, and walks into folders it is about to delete. | `bin/node-modules-clean:14` | Worker ran. Confirmed the line |
| C5 | The SSH window title names no host. zsh sets `$HOST`, not `$HOSTNAME`. | `tilde/.zshrc:20` | Confirmed |
| C6 | `~/.gitconfig.local` is read twice on an installed copy. The wrapper includes it, and so does the tracked file the wrapper includes. | `tilde/.gitconfig.installed:5-6` | Reproduced. `credential.helper` lists each value twice |
| C7 | SSH-signed commits cannot be checked on this Mac. Setup turns signing on and never sets `gpg.ssh.allowedSignersFile`. | `setup/dotfiles-extras.sh:118-148` | Reproduced. `git log --format=%G?` prints an error, then `N` |
| C8 | `setup.sh -y` in a terminal still runs `aspire certs trust`, which can ask for the login password. | `setup/misc.sh:428` | Confirmed |
| C9 | Setup's "Load your saved settings" question defaults to yes on a Mac whose folder already holds settings, where the load cannot succeed. Already recorded. | `setup.sh:526` | Confirmed |
| C10 | A wrong-type `tools.toml` gives a traceback, not a one-line error. The file arrives from another Mac by sync. | `sync.py:26-30` | Worker ran. Confirmed `_parse` |
| C11 | A non-string `model` in Claude's `settings.json` reaches the app as a number and fails its whole decode. A non-list `optInPaths` is read one character a line. | `adapters/tool.py:89, 122-127` | Worker ran |
| C12 | Three messages are wrong. The Dash hint says `git checkout` on an installed copy, where the file is not in git. `optimize-image` says `npm install avif` in a pnpm repository. `wg` adds a final newline and its header does not say so. | `setup/dash.sh:158`, `bin/optimize-image:42`, `bin/wg:66` | Confirmed the first two. Worker ran the third |

## D. CI and process

| Id | Finding | Where | Evidence |
| --- | --- | --- | --- |
| D1 | The next Renovate bump of mise will fail the gate. `test-override-env:37` requires `check.yml` to match `setup/mise-floor.sh`, Renovate tracks only `check.yml`, and mise 2026.11.9 is out. | `renovate.json`, `check.yml:41` | Confirmed |
| D2 | One Swift test is flaky. `stopEndsACommandThatIgnoresTheInterrupt` took 11.47 seconds against a 10 second bound in 1 of 3 full runs. | `ConsoleSessionTests.swift:102-110` | Worker ran. Not reproduced by the lead session. **Measured 2026-11-16:** 0 failures in 20 runs. Alone, ten runs took 2.06 to 2.10 seconds, the 2 second timer and nothing else. In the full suite, ten runs took 2.62 to 9.50 seconds (median 3.6, with one at 7.02 and one at 9.50). The delay appears only beside the other tests, which supports the cause as the `DispatchQueue.main.asyncAfter` in `ConsoleSession.stop()` waiting behind other main-queue work. The row stays open: no run failed, but one came within 0.5 seconds of the 10 second bound, so a slower machine can cross it. The bound was not changed |
| D3 | `fresh-install.yml` last ran on `cbd63b0`, before `install.sh` existed. Eight commits have touched the install path since. | `.github/workflows/fresh-install.yml` | Worker ran. Confirmed the dates. **Done 2026-11-16:** run 43892315785 passed on `1a9bb95`, both the `clone` and the `installed` path |
| D4 | CI spends 33 to 61 seconds installing Python 3.15 in 9 of 10 runs, because the runner does not cache that version. | `check.yml:34-36` | Worker ran |
| D5 | CI builds the app twice. `pnpm check` already runs `test-app-build`. | `check.yml:83-84` | Confirmed |
| D6 | `CLAUDE.md` is 11,998 bytes against a 12,000 byte cap, and `.claude/rules/setup.md` is 5,996 against 6,000. `CLAUDE.md` also omits `--without` and `app-release.yml`. | `bin/lib/test-conventions:210-212` | Reproduced with `wc -c` |
| D7 | The app's update check can run twice at once, because `appCheckedAt` is set only after the fetch returns. | `app/Sources/RotmCore/AppState.swift:99-106` | Confirmed by reading |
| D8 | Every action is pinned by SHA, but the repository does not require it. | GitHub settings | Reproduced. **Done 2026-11-16:** `actions/permissions` shows `sha_pinning_required: true`. Vulnerability alerts (A4) are on too: the endpoint answers 204 |

## E. Decisions the owner must make

Each has a recommendation. None has a task until it is answered.

1. **Hold uv tools back as npm and bun are held.** `serena-agent` and `scrapling[ai]` install with no version and no release-age wait (`setup/misc.sh:235, 253`). Recommended: a tracked `~/.config/uv/uv.toml` with `exclude-newer = "7 days"`. uv 0.13.8 accepts that value on the command line (ran). The config file form is not yet tested, and it would apply to every uv project on the Mac.
2. **Pin skills to a commit.** `claude-config restore skills --accept` installs whatever the source holds that day (`bin/claude-config:367`). Recommended: record a commit in `claude-config save` and install `owner/repo#<sha>`. About 30 lines in two files.
3. **Record what `latest` resolved to.** About twelve mise tools are `latest`, and `mise settings get lockfile` is unset. Recommended: probe `lockfile = true` in a scratch `MISE_CONFIG_DIR` first, since nobody has measured what it records for a global config.
4. **Move the owner's tap out of the base list.** Every install gets `jrmatherly/tap`, `claude-multipass` and its app (`30-packages.toml:20, 39-40`). Recommended: move them into a module, so a fork can switch them off.
5. **The CodeGraph prompt hook.** It costs about 3,000 tokens a prompt, and `setup/misc.sh:171` reinstalls it on every run. Recommended: remove the hook from `settings.json` after the install step.
6. **Seed the Mole whitelists on an installed copy (B3).** A seeded copy lets Mole's editors work, and it stops receiving later changes to the shared list. The plan's Task 8 assumes yes. Say no and the task is dropped, since the docs already warn. A yes reaches new installs only: mise 2026.11.8 leaves an existing link alone (ran in a scratch clone on 2026-11-16), so a Mac installed earlier needs the two links deleted by hand.

## F. Closed without a fix

- **`MISE_ENV=rotm-installed` does not hide a saved profile.** A worker ran mise 2026.11.8 with both environments set, and `MISE_ENV` read `rotm-installed,rotm-p-work`. `profile.active()` takes the last `rotm-p-` entry, so the profile is found. The line in the plans README can be closed.
- **`zsh/env.zsh` does set `OBSIDIAN_VAULT`** (line 17). A worker said otherwise.
- **The worker's fix for B4 is rejected.** `MISE_GLOBAL_CONFIG_FILE` turns mise's override files off (`bin/lib/test-dotfiles:105`).

## G. Not planned

| Item | Why it waits |
| --- | --- |
| No subprocess timeouts in the settings CLI (`mise.py:15`, `sync.py:169`) | The app already kills a hung command after 120 seconds (`CLI.swift:97`). Only a terminal user waits |
| `sync on` after the settings repository was deleted and made again | Rare, and the hand fix is in the installable-setup spec |
| Non-atomic writes of `effective.applied.json`, the macOS fragment and `miserc.local.toml` (`profile.py:129`) | The first two recover: a JSON read failure is tolerated, and git restores the fragment. A truncated `miserc.local.toml` needs a hand edit, but the repository's atomic writer, `edit_file`, refuses a path inside an installed copy, where that file lives. A second writer needs an installed-copy test, for a crash nobody has seen |
| `helmfile` 1.8.3 is installed on this Mac and no config declares it | Machine state. `mise uninstall --all helmfile` clears it |
| The Software Update and trackpad defaults may write to a domain macOS no longer reads | Unproven. It needs a fresh Mac |
| Amp or cmux may rewrite a tracked file on an installed copy | Unproven. Amp is not installed here |

## What was not checked

- No setup step, `sysup` or `rotm update` ran.
- `sysup`, `claude-config restore`, `rotm-modules` and most doc bodies were not read line by line.
- D2 and the "worker ran" rows were not repeated by the lead session.
- Which job inside `pnpm check` takes the 176 to 302 seconds on CI.
