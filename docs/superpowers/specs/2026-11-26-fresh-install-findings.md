# Findings from the fresh-install run of 2026-11-26

Date: 2026-11-26. Status: findings for triage, nothing decided, nothing built.

## What this is

The `fresh-install` workflow ran on `main` at `0c10565` as run 45769485504 and passed on both paths (`clone` in 28 minutes, `installed` in 24). It was the first full install after the output changes of 2026-11-25 and 2026-11-26 (`9a9ead1`, `444182f`, `3752623`, `0c10565`). This file lists what that run confirmed and what it showed that is still wrong or undecided, so a later session can triage without the conversation that produced it.

Earlier work this builds on: `docs/superpowers/specs/completed/2026-11-25-quiet-setup-and-update-output.md`. Its "Decisions the owner made" list is binding.

## How to re-read the evidence

```bash
gh run view 45769485504 --job 139738417186 --log   # clone: ./setup.sh from a checkout
gh run view 45769485504 --job 139738416818 --log   # installed: the install line, then rotm update
```

Each log line is `job<TAB>step<TAB>timestamp text`. The `setup.sh`, `Install line` and `rotm update` steps hold what the terminal showed. The `Setup logs` step holds each run's full log. `Remove Homebrew` and `Disk after setup` hold the disk figures.

## Confirmed working

| Change | Evidence in the run |
| --- | --- |
| A first install is short on screen | `clone` printed 135 lines for the whole `setup.sh` step. The same step printed 681 lines on 2026-11-25. |
| Long change types are counts | `Packages  180, listed in the log`, and the same for Tools 38, Extensions 184, Links 39, Plugins 74, Skills 24. MCP servers (9), Settings, Files and Other are listed in full. |
| Every notice reaches the summary | `clone` printed five `●` lines and its summary says `5 notices` and lists all five. `installed` printed seven and lists seven. |
| The mise installer is one step | `↻ mise  installed 2026.11.14`, with no installer output on screen. |
| Failed rows name the program | `✖ cask  royal-tsx  hdiutil attach exited with code 1`. |
| PowerShell's line is its version | `↻ PowerShell  installed 7.6.10`. |
| The space warning before installing | `installed` started with 42 GiB and printed `42 GiB free on / with 178 packages to install: a full install needs about 39 GB`. `clone` started with 51 GiB and printed none, which is correct. |
| No update banner | The `rotm update` step has no `Updating <path>` line. |
| Catalog lint is quiet on a Mac that is not the owner's | Neither job printed a lint line. The run of 2026-11-25 printed `6 lint notes`. |

## Findings to triage

Ordered by how much they matter. Severity is the author's judgment.

### 1. The free-space line repeats while space is short (medium)

In the `rotm update` step the runner had 3 GiB free, and `● free space  3 GiB free on /` printed three times, once after each package phase. `packages_for` in `setup.sh` prints the line after any phase while under 20 GiB is free. That rule was written so a short disk is never hidden, but on an unchanged run it says the same thing three times.

Options: print it after a phase only when the figure dropped since it was last shown, or print it once per run when nothing was installed. The summary already lists it once.

### 2. Three space notices in one summary (low)

The `installed` summary lists `42 GiB free … with 178 packages to install`, then `Only 16 GiB free`, then `Only 3 GiB free`. Each was true when recorded, and together they read as noise. Keeping only the last, or the warning plus the last, would say the same.

### 3. The runner is close to full, and what to free is now measured (medium, CI only)

`installed` went from 43 GiB free to 3. `clone` went from 51 to 12. The two runners started with different amounts, so a third could start lower and fail. The measuring step added in `3752623` shows what the image holds:

| Path | Size |
| --- | --- |
| `~/Library/Android` | 13 GiB |
| `/Applications/Xcode_27.2.app` | 3.4 GiB |
| `/Applications/Xcode_27.1.app` | 3.3 GiB |
| `/Applications/Xcode_27.app` | 3.3 GiB |
| `~/Library/Developer/CoreSimulator` | 420 MiB |

`/Applications/Xcode.app` and the `Xcode_27.0*` entries are links (0 B). The Android SDK alone frees 13 GiB and nothing in this repo uses it. Which Xcode the links point at was not read (`xcode-select -p` would say), so do not delete an Xcode before checking: setup needs the Command Line Tools.

Option: `sudo rm -rf ~/Library/Android` in the workflow's "Remove Homebrew" step. A real Mac is not affected.

### 4. A failed step's output tail still carries mise's boilerplate (low)

Under `✖ casks  brew-cask:royal-tsx failed to install` the screen shows four lines: mise's `✗ failed`, the raw `mise ERROR command ["hdiutil", …` line cut at the terminal width, then `mise ERROR Version: …` and `mise ERROR Run with --verbose …`. The last two never help. `bin/rotm` already drops them for its own failure line (`awk 'NF && !/^mise ERROR +(Version:|Run with)/'`); `failed()` in `setup.sh` does not.

### 5. Summary notices are worded two ways (low)

Notices recorded through `notice` carry their step (`GitHub CLI: not signed in to GitHub`). Notices recorded through `warning` or `mcp_warning` do not (`Sign in once on this Mac: …`, `Only 12 GiB free on /: …`). Both read well enough alone. Side by side they look inconsistent. Either prefix all of them or none.

### 6. `MCP servers  0 registered, 9 added` (low)

On a first install the count line leads with `0 registered`. `9 added` alone says it. `mcp_summary` in `setup/misc.sh` builds the message.

### 7. royal-tsx fails on every run without a terminal (known, no action proposed)

Its disk image carries a licence agreement that mise can only accept from a terminal (`conf.d/60-rotm-apps.toml`). The workflow tolerates it. The consequence worth knowing: on such a machine every `rotm update` reports `1 failed` and exits 2. Not seen on a real Mac, where the terminal is present.

## Not covered by this run

- The terminal path on a first install: `sudo -v`, Touch ID, the `gh auth login` prompt, and mise asking before it applies a change. The runner has no terminal.
- The login shell part. The workflow passes `--skip user`.
- `sysup`. The workflow does not run it.
- A real Mac. The workflow's own comment says a hosted runner is not a clean one.
