# Project audit, 2026-11-14

Date: 2026-11-14. Status: findings for the owner's review. Nothing here is fixed yet. Plans built on this spec are listed in [Plans](#plans).

## Goal

The owner asked for the project's issues, gaps and opportunities, each backed by evidence, so they can decide what to fix before the P5 VM proof resumes (Guest 2, rows 2a and 2b). The product goal the findings are judged against is the one in `2026-11-11-installable-setup-profiles-and-sync.md`: a stranger installs with one command, updates with one more, keeps their own changes outside the repository, opts out of what they do not want, and a menu bar app fronts it.

## How the audit ran

Ten read-only reviewers on `main` at `1b5fa26`, one slice each: setup, settings, the app, the gate and CI, docs, shell and agent config, then a second pass over the app's views, the terminal UI, the macOS preferences path, and the package lists with Firefox. The session then read every cited line. Each finding carries one label:

- **run**: a reviewer reproduced it with a command or a scratch test. The session read the code but did not rerun the repro.
- **read**: read in the code by the reviewer and by the session.
- **guess**: not checked. The finding says what would settle it.

`bin/lib/test-bootstrap`, `bin/lib/test-rotm` and `bin/lib/test-user-layer` were run by the session and pass (exit 0).

No data-loss or credential-leak defect was found. Checked and clean: token handling in `rotm-user-layer` and `setup.sh` (environment only, never in arguments, none in `private/setup-logs`), atomic writes in `edit_file`, the public-repository refusal in sync, `serve`'s bind and token checks, the console's password handling and log mode, the release workflow's signing and asset rules, CI action pinning and permissions, shell startup guards and startup time (0.07 to 0.11 s over 10 samples), and the package counts in the docs.

## Findings

Severity is high, medium, low or opportunity. "Stranger" means a user who is not the owner.

### G. Gate, CI and docs

| ID | Sev | Finding | Where | Evidence |
| --- | --- | --- | --- | --- |
| G1 | high | Renovate PR 20 raises `requires-python` to `>=3.15,<3.16` while `uv.lock` stays `==3.13.*`. Its `check` passed. Merged, `hindsight-memory init` and `upgrade` cannot sync. | `hindsight/pyproject.toml:10`, `hindsight/uv.lock:3`, `bin/hindsight-memory:84,147`, `renovate.json` | run (`uv sync --frozen` refused in scratch); the PR's `renovate/artifacts` check fails |
| G2 | medium | `fresh-install` last ran 2026-11-12 at `7f837d6`. 46 commits have touched the setup path since, including the mise floor raise and the gh token changes. | `.claude/rules/ci.md`, `gh run list --workflow fresh-install.yml` | run |
| G3 | medium | Renovate PR 19 fails only because actionlint 1.7.12 does not list the `ubuntu-26.04` label. | `.github/workflows/app-release.yml:95`, `.github/actionlint.yaml` | run (run 43549964161) |
| G4 | low | Renovate PR 16 is already on `main` (`e7fb36f`). | `package.json:22` | run |
| G5 | opportunity | Nothing fails when a new self-check is not wired into `bin/lib/check`. | `bin/lib/check:57`, `bin/lib/test-conventions` | read |
| G6 | low | CI skips the zoxide, rg, fzf and tldr parts of two self-checks and reports green. `bin/lib/check` skips actionlint silently when it is missing. | `.github/workflows/check.yml:49`, `bin/lib/check` | run (CI log) |
| G7 | opportunity | The JSON fixture contract compares key names only, so a field that changes type passes both gates. | `settings/tests/test_cli.py:224-234` | read |
| G8 | low | The app's `noFieldTakesFocusOnOpen` test only runs when `UI_SHOTS_DIR` is set, so the gate never runs it. | `app/Tests/ReturnOfTheMacTests/ShotsTests.swift:112,159-166` | read |
| G9 | medium | The spec's "Still not verified" table has five rows the Guest 1 record now answers (a real install and update, the profile switch, the app's own update, Launch at Login, no Git helper written by `gh auth login`), and half of the sync row. | installable-setup spec `:313-321` | run (`proof.sh diff` on `~/vm-proof/p5/g1/`) |
| G10 | medium | The jstack Reset fix (`e7db2f3`) has no VM proof. Row 1c3 recorded the failure and no later row resets a role through the app. | `RUNBOOK.md:150` | run |
| G11 | low | The runbook's expectations are stale: app versions 0.1.0 to 0.1.1 (the run used 0.1.1 to 0.1.2), "1 update waiting" (it was 2), and `haiku high` in steps 19 and 33 (the record holds `sonnet xhigh`). `proof.sh:45` is right for row 1c2, and only its comment is stale. | `RUNBOOK.md:158,189-218,246`, `proof.sh:45` | run |
| G12 | low | `ci.md` says a 15-minute timeout (the workflow sets 20) and describes `fresh-install` as the `setup.sh` path only (it is a `clone` and `installed` matrix). The spec says forking lists 13 places (the table has 16). | `.claude/rules/ci.md:13`, spec `:41` | read |
| G13 | low | `docs/forking.md` has no row for the hard-coded install URL in `fresh-install.yml:84`, the tap names in `docs/menu-bar.md`, `tilde/.ssh/config` (I1) or the locale keys (I9). | `docs/forking.md` | read |
| G14 | low | `docs/macos settings.md` claims lid wake is set (this Mac has no `lidwake` key, so it is skipped) and that every update option is switched on (three are). | `docs/macos settings.md:56,178` | run and read |

### I. Install, shell, macOS preferences and packages

| ID | Sev | Finding | Where | Evidence |
| --- | --- | --- | --- | --- |
| I1 | medium | The tracked SSH config pins `github.com` to `~/.ssh/github_personal.pub` with `IdentitiesOnly yes` and sends every host to the 1Password agent. Without that layout `git@github.com` is denied. | `tilde/.ssh/config:13-15,23-24` | run (two reviewers; `ssh -v` repro) |
| I2 | medium | A failure in `dotfiles-extras.sh` stops `setup.sh` before the restored tool settings apply. A rerun skips the apply because the origin is already connected. | `setup.sh:602,509,611`, `setup/dotfiles-extras.sh:84-101,173` and its last line | read |
| I3 | medium | A failed or cancelled `sudo` stops `set-defaults` halfway with no message of its own. Only the `tmutil` call guards itself. | `setup/macos-extras.sh:176,193,214-217,223,233,236` | run (stubbed `sudo`) |
| I4 | medium | `sysup` reinstalls any third-party skill whose upstream tree changed, with no pinned ref and no age gate. | `bin/claude-config:345-355`, `agents/claude-skills.txt` | read |
| I5 | medium | Third-party taps ship unreviewed builds. `kubestellar/tap` currently serves `0.9.23-nightly.20261112`. No doc names the kubestellar, skyhook-io or bramstein taps, and the release-age delay does not cover `brew:` packages. | `60-rotm-kubernetes.toml:8-9,27-29`, `60-rotm-media.toml:8,31` | run |
| I6 | medium | Firefox's `user.js` is hard-linked into the first Developer Edition profile with no prompt or switch. It turns off Firefox Sync and password saving. `setup/README.md:183` calls the files "styles". | `setup/dotfiles-extras.sh:201-210`, `firefox/user.js:155,282` | read |
| I7 | medium | `user.js` enables remote debugging with the connection prompt off. | `firefox/user.js:109-111` | read |
| I8 | medium | Tracked allow rules run code with no prompt: `bun install`, `bun add`, `bun update`, `bun run`, `bun test`, `npx tsc`, `npx license-checker`, and the Chrome DevTools `evaluate_script`, `navigate_page` and `fill_form` tools. That bare `npx tsc` fetches a deprecated stand-in package is a guess (`npm view tsc` settles it). | `agents/claude-settings.json:14-55` | read |
| I9 | medium | Language, locale, units and temperature are forced to US values with no switch. | `tilde/.config/mise/conf.d/20-macos.toml:87-91` | read |
| I10 | low | Four `misc.sh` blocks run with their module off (rustup, supabase telemetry, PowerShell, Aspire certs). | `setup/misc.sh:136-143,392-395,407-416,424-433` | read |
| I11 | low | Global Claude rules link in the base, so `rtk.md`, `hindsight.md`, `catalog.md` and `jstack-models.md` load with the `agents` module off. | `40-dotfiles.toml:41` | read |
| I12 | low | `/etc/pam.d/sudo_local` and the login shell are rewritten on every run with no opt-out. | `50-bootstrap.toml:12-20` | read |
| I13 | low | `set-defaults` kills Terminal.app unless it runs inside it, so the app's console and Ghostty runs always kill it. | `setup/macos-extras.sh:263-269` | read |
| I14 | low | Spotlight's ⌘Space is disabled even when Raycast (the `apps` module) is off. | `20-macos.toml:272-285` | read |
| I15 | low | The `pmset` group (wake on network off, hibernate mode, disk sleep) has no switch. | `setup/macos-extras.sh:180-189` | read |
| I16 | low | `dash.sh` writes the user's Dash settings into the copy `rotm update` replaces. | `setup/dash.sh:22-23,76` | read |
| I17 | low | Three mise tools install with no integrity check (`azd`, `azure-functions-core-tools`, `github:getsentry/toolkit`). | `60-rotm-cloud.toml:32-33`, `60-rotm-devops.toml:48` | run (`mise tool`) |
| I18 | opportunity | mise's release-age delay is its 24 h default while npm and Renovate wait 7 days. | `tilde/.config/mise/config.toml` | run |
| I19 | low | The DoH comment says "Enable" over `network.trr.mode` 5 (off), and several prefs are probably dead (Pocket, Fakespot). The dead-pref list is a guess (Mozilla's `StaticPrefList.yaml` settles it). | `firefox/user.js:201-205` | read and guess |
| I20 | low | The `sysup` plugins step can print no status line, and `sysup` exits 0 when steps failed. | `bin/sysup:696-726,903` | read |
| I21 | low | `setup.sh` calls `/usr/bin/jq` by absolute path. Whether macOS 14 ships it is a guess (a macOS 14 guest settles it). The path is deliberate: the packages, `jq` among them, install after this line (`:544`), so PATH has none yet. Not planned. | `setup.sh:539` | guess |
| I22 | medium | An installed user cannot change owner values in linked files (fastfetch, lazygit) without editing the checkout, which blocks `rotm update`. No plan covers it. | `40-dotfiles.toml:51`, `zsh/env.zsh:185`, spec `:367` | read (reviewer only) |

### S. Settings tool and terminal UI

| ID | Sev | Finding | Where | Evidence |
| --- | --- | --- | --- | --- |
| S1 | medium | A Finder `.DS_Store` in `~/.config/rotm` blocks `sync on` and `sync now`. | `sync.py:203-207` | run |
| S2 | medium | `updates.mac_password_op` accepts any text and syncs it, so a pasted password reaches the settings repository's history. | `settings/registry.toml:1-12`, `sync.py:150` | run |
| S3 | medium | A trailing space or an unknown effort on a `jstack-models.md` line crashes the terminal UI (`InvalidSelectValueError`). | `tui_agents.py:94`, `adapters/tool.py:214` | run |
| S4 | medium | Any error other than `SettingsError` (a permission error, a missing helper, a non-UTF-8 override file) kills the terminal UI, and the CLI prints a traceback for the same causes. | `tui.py:111-114,173-179,190-193`, `cli.py:190`, `adapters/env.py:34-39` | run |
| S5 | medium | A read failure while a lines box has focus saves the half-typed text. | `tui.py:131`, `tui_agents.py:45-47` | run |
| S6 | low | A bool stored as a non-canonical value (`0`) shows Off, the redraw writes the empty string by itself, and `macos-extras.sh` treats any non-empty value as on. | `tui.py:41,140,204-205`, `setup/macos-extras.sh:62,243` | run |
| S7 | low | `profile use` can exit 1 after the switch happened, and "Open a new shell" never prints. | `profile.py:119,130` | run |
| S8 | low | `apps.obsidian_vault` syncs as an absolute path under one Mac's home. | `cli.py:33-37`, registry `apps.obsidian_vault` | run |
| S9 | low | An invalid `--repo` name exits 1 where the contract says 2. | `sync.py:285-287` | read |
| S10 | low | A focused text box is overwritten when its setting changes on disk. A single-line field keeps an unsaved edit on screen after Tab. Ctrl+R does nothing inside a seat picker. A refused value's only explanation is a 5-second toast. | `tui.py:147,200-201,212,178-180` | run |
| S11 | low | macOS preference rows do not refresh when another front end changes them (`macos_default.py` has no `watch_paths`). | `adapters/macos_default.py` | read |

### M. Menu bar app

| ID | Sev | Finding | Where | Evidence |
| --- | --- | --- | --- | --- |
| M1 | medium | A running refresh does not count as busy, so Update or Apply can start while the hourly `git fetch` runs. The fetch collision itself is a guess. | `AppState.swift:15,45-48`, `StatusItemController.swift:51-53,145` | run (scratch test) |
| M2 | medium | With the `menubar` module off, or after a DMG install, the app still offers its own update and the attention dot never clears. | `AppState.swift:28,81-87` | read, plus a mise dry run |
| M3 | low | Cancelling the staged-edits prompt during the post-update relaunch leaves the old binary running and a waiter that reopens the app later. | `StatusItemController.swift:185-194`, `App.swift:29-43` | read |
| M4 | low | Notes and failures repeat in the result list. `load()` appends the same failure on every focus, and the `ForEach` uses the text as its id. | `SettingsModel.swift:72,102`, `SettingsView.swift:59-60` | run |
| M5 | low | "Write to shared settings" compares an edit against the profile's merged value, so a shared edit equal to the shown value is dropped, and Reset is offered for a shared value that may not exist. | `SettingsModel.swift:123-131`, `SettingRowView.swift:72` | run and read |
| M6 | low | Staged edits follow a profile switch and are written to the newly active profile. The review sheet does not name the target. | `SettingsModel.swift:59-70`, `ReviewSheet.swift:13-18` | read |
| M7 | low | `AnsiParser` lets colon SGR, DECSC and DECRC, and two other sequence shapes through. | `Ansi.swift:50-51`, `ConsoleSession.swift:62` | run |
| M8 | opportunity | Each Apply lists every setting twice (about 3.5 s each), and every window focus lists them again. | `SettingsModel.swift:109`, `SettingsWindow.swift:23-25,45-55` | run (timing) and read |
| M9 | low | The branch where an edit staged during Apply wins over a failed one has no test. | `SettingsModel.swift:105-106` | read |

## Decisions the owner must make

Each has a recommended default. A plan task that depends on one says so and waits for the owner's word.

1. **Allow rules (I8).** Recommended: remove `npx tsc`, `npx license-checker`, `bun install`, `bun add`, `bun update` and `evaluate_script`; keep `bun run`, `bun test`, `navigate_page` and `fill_form`. Decision 12 lets the owner's values ship, so this is a preference.
2. **Third-party skills (I4).** Recommended: record a reviewed tree SHA per skill and report an upstream change as a notice, as Hindsight's pin does, in place of reinstalling.
3. **Third-party taps (I5).** Recommended: name the three taps in `docs/modules.md` and drop the `kubestellar` pair from the default set.
4. **Locale (I9), `pmset` (I15), Spotlight hotkeys (I14).** Recommended: one switch each, on by default, so the owner's Mac is unchanged and a stranger can turn it off.
5. **`sudo_local` and the login shell (I12).** Recommended: one switch each, on by default.
6. **Firefox (I6, I7).** Recommended: skip the link when the profile already has a `user.js` that is not ours, and drop `devtools.debugger.prompt-connection`.
7. **Release age (I18).** Recommended: `minimum_release_age = "7d"` in `config.toml`.
8. **Owner values in linked files (I22).** Not planned here. It belongs in the P6 plan, as `create_if_missing` copies in `config.rotm-installed.toml`.

## Not covered

The 184 VS Code extension ids, `firefox/chrome/*.css`, VoiceOver in the running app, `agents/catalog/*.py`, and anything that needs a clean Mac. Nothing was installed and the built app was never launched.

## Plans

- `docs/superpowers/plans/2026-11-14-audit-gate-ci-and-docs.md` covers G1 to G14, except G8.
- `docs/superpowers/plans/2026-11-14-audit-install-and-opt-outs.md` covers I1 to I21.
- `docs/superpowers/plans/2026-11-14-audit-settings-tool.md` covers S1 to S11.
- `docs/superpowers/plans/2026-11-14-audit-menu-bar-app.md` covers M1 to M9 and G8.
