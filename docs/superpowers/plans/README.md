# Open plans and the order to run them

Written 2026-11-14. This page lists the plans in this folder that are not finished and the order their tasks should run. Each plan moves to `completed/` once every task in it is done, and its row leaves this page.

## Open plans

| Plan | Spec | Tasks | State |
| --- | --- | --- | --- |
| [P5 menu bar app](2026-11-13-p5-menu-bar-app.md) | [installable setup](../specs/2026-11-11-installable-setup-profiles-and-sync.md) | 12 | Through Task 10, with Task 9 and Task 11's docs done. Task 11's VM proof waits on Guest 2. Task 12 waits on the owner's word. |
| [Audit: gate, CI and docs](2026-11-14-audit-gate-ci-and-docs.md) | [project audit](../specs/2026-11-14-project-audit.md), G1 to G14 | 11 | Tasks 1, 2, 3, 5, 6 and 7 are on `main` (`9bc4017` to `97d4766`). Task 8 is the app plan's Task 5, done. Task 4 is the owner's. Tasks 9 and 10 are Stage 7. Task 11 waits on Guest 2. |
| [Audit: install and opt-outs](2026-11-14-audit-install-and-opt-outs.md) | project audit, I1 to I20 | 15 | Tasks 4, 5, 6, 11, 12, 14 and 15 are on `main` (`03df250` to `ac43eb6`). Tasks 1, 2, 3, 7, 8, 9, 10 and 13 wait on an owner decision. |
| [Audit: settings tool](2026-11-14-audit-settings-tool.md) | project audit, S1 to S11 | 12 | Every task but 9 is on `main` (`aa06a68` to `7e94c04`). Task 9 needs the owner told first. |
| [Audit: menu bar app](2026-11-14-audit-menu-bar-app.md) | project audit, M1 to M9 and G8 | 9 | All nine tasks are on `main` (`0cb1667` to `c448cb3`), with `c597959` added from review. Unreleased: the `app/VERSION` bump, tag and cask are the owner's. The plan moves to `completed/` after the guest steps Tasks 2 and 9 add have run. |

The four audit plans were each checked line by line against the code on 2026-11-14 and corrected. Stages 2 to 5 below ran on 2026-11-14, one commit per task, each with its failing check seen first. Stage 1's step 1 is done and step 2 is the owner's.

Found while running them, and not in any plan:

- Install 12 as planned removed `rtk.md`, `hindsight.md` and `catalog.md` from `~/.claude/rules` on the first apply of an existing install. The landed commit gives the three module entries `depends = ["~/.claude/rules"]`, and `bin/lib/test-dotfiles` holds the migration case.
- App 1 as planned let two rechecks waiting on one refresh each start a read. `c597959` fixes it with a test.
- The "restore it with git checkout" hint at `setup/dash.sh:158` is wrong on an installed copy. Not fixed.

## Recommended order

Task numbers are the plan's own. "Gate 2" means Task 2 of the gate plan. Run the stages in order. Inside a stage, run the tasks in the order listed.

### Stage 1. Finish the P5 VM proof (time-bound)

Guest 2 is running in UTM and is disposable, so this stage comes first.

1. **Gate 2.** Add row `2c` (the jstack Reset proof) to `proof.sh` and the runbook, then copy `proof.sh` to `~/vm-proof/p5/`.
2. **The owner runs the Guest 2 retry** in the guest: `rotm update`, `p 2a`, `set-defaults`, `p 2b`, `p 2c`, then shuts the guest down. The exact lines are in the session handoff and in the runbook's Guest 2 section.
3. **P5 Task 11 Step 3 with Gate 11.** Write the VM results into the installable-setup spec once, with the runbook corrections. Both wait on rows `2a`, `2b` and `2c`.

### Stage 2. Protect the gate

No owner decision is needed. Each task is small and independent of the others.

1. **Gate 1.** Check the Hindsight lock in the gate and keep Renovate out of it. This is the one high-severity finding.
2. **Gate 3.** Let actionlint accept the `ubuntu-26.04` label.
3. **Gate 6.** Fail when a self-check is not wired into the gate.
4. **Gate 7.** Compare types in the JSON fixture contract.
5. **Gate 5.** Run the skipped self-check parts in CI.
6. **Gate 4, the owner's steps.** Close PR 20 after Gate 1, close PR 16, decide PR 19 after Gate 3, and run `fresh-install`.

### Stage 3. Fixes a stranger hits, with no decision needed

1. **Settings 1, 2, 5.** The `.DS_Store` sync block, the password where the 1Password reference goes, and the terminal UI crash on a jstack line.
2. **Settings 3, then 4.** One-line errors for unreadable files, then no write while a read error shows.
3. **Install 4.** The 1Password SSH layout only where it exists.
4. **Install 5.** Restored tool settings applied on the rerun after a failed run.
5. **Install 6.** Carry on after a refused sudo in `set-defaults`, and leave Terminal open.
6. **Install 11, 12.** Gate four `misc.sh` steps on their module, and link the agent rules from their modules.
7. **Install 14, 15.** Dash docsets outside an installed copy, and the `sysup` status line and exit code.
8. **Settings 6, 7, 8.** The `--repo` exit code, the profile-switch message, and the vault path scoped to one Mac.

### Stage 4. Terminal UI polish

1. **Settings 10.** Keep a typed edit and save a field on Tab. It needs Settings 4.
2. **Settings 11.** Reset from inside a seat picker, and a longer refusal notice.
3. **Settings 12.** Watch the macOS preference files. It needs Settings 3.

### Stage 5. The menu bar app

Run App 1 to 9 in the plan's order. App 5 must come before App 6. The fixes reach users with the next app release (the `app/VERSION` bump, the tag and the cask), which is the owner's call. App 2 and App 9 each add one step to the next guest run.

### Stage 6. Tasks that wait on the owner

Start each only after the owner confirms the decision named in the [audit spec](../specs/2026-11-14-project-audit.md), section "Decisions the owner must make".

| Task | Decision | What it does |
| --- | --- | --- |
| Install 1 | 1 | Remove the allow rules that run fetched code |
| Install 9 | 2 | Report a changed third-party skill and stop reinstalling it |
| Install 10 | 3 | Name the third-party taps and drop the KubeStellar pair |
| Settings 9, then Install 7 | 4, and the owner told first for Settings 9 | One meaning for a macOS switch, then switches for locale, power and the Spotlight shortcuts |
| Install 13 | 5 | Switches for Touch ID for sudo and the login shell |
| Install 2, then Install 8 | 6 | Firefox's debugger prompt and DoH comment, then leave a profile's own `user.js` alone |
| Install 3 | 7 | Hold mise tools for seven days |

Decision 8 (owner values in linked files, finding I22) is not planned here. It belongs to the P6 plan.

### Stage 7. Close out

1. **Gate 9, then Gate 10.** The `ci.md`, forking table and macOS doc corrections. Gate 9 comes after Install 4 and Install 7, because two of its forking rows describe what those tasks ship.
2. **The owner runs `fresh-install` again**, since the install plan changes the setup path.
3. **P5 Task 12** (retire `rotm settings serve`), only on the owner's word.
4. Move each finished plan to `completed/`, and each spec to `specs/completed/` when every plan built on it is there.

## Tasks that touch the same files

Run these one after another, never in parallel, and rerun the earlier task's self-check after the later one.

| Files | Tasks |
| --- | --- |
| `setup/macos-extras.sh`, `setup/tests/macos-extras.sh` | Install 6, Settings 9, Install 7 |
| `setup/tests/dotfiles-extras.sh` | Install 4, Install 2, Install 8 |
| `bin/lib/test-bootstrap` | Install 5, Install 11, Install 3, Install 13 |
| `settings/tests/test_tui.py`, `test_tui_agents.py`, `tui.py` | Settings 3, 4, 5, 9, 10, 11, 12 |
| `settings/tests/test_sync.py`, `sync.py` | Settings 1, 2, 6, 8 |
| `app/Sources/RotmCore/AppState.swift`, `AppStateTests.swift` | App 1, App 2, App 9 |
| `app/Sources/RotmCore/SettingsModel.swift`, `SettingsModelTests.swift` | App 3, App 6, App 7, App 8 |
| `docs/forking.md` | Gate 9, Install 7 |
| `bin/lib/check` | Gate 1, Gate 5, Install 14 |

## What one task needs from another

- **Gate 8** is only a pointer. The work is **App 5**.
- **Gate 11** needs the Guest 2 rows, and Gate 2's row `2c`.
- **Settings 10** needs Settings 4. **Settings 12** needs Settings 3. **App 6** needs App 5.
- **Settings 9 and Install 7** change how `setup/macos-extras.sh` reads a switch. Whichever runs second follows the form the first left, and each plan says so.
- **Gate 9**'s rows for the SSH config and the locale keys depend on whether Install 4 and Install 7 have shipped.

## Rules that hold for every task

- The gate is `pnpm check`, and every task ends with it passing.
- Never run on this Mac without the owner's word: `sysup`, `./setup.sh`, `set-defaults`, `rotm install`, `rotm update`, `hindsight-memory init`, `upgrade` or `uninstall`, `rotm settings sync …`, or the built app. Never touch github.com/jrmatherly/rotm-settings.
- Pushing a tag, closing a PR and running a GitHub workflow are the owner's.
