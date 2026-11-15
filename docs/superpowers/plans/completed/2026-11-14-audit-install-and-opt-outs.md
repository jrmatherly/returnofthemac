# Audit fixes: install, shell, macOS preferences and packages, Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A stranger who installs returnofthemac gets a Mac that still reaches GitHub over SSH, keeps their Firefox, locale and login shell unless they say otherwise, and a failed step in setup or `set-defaults` says what failed and is finished by a rerun.

**Architecture:** Fifteen independent fixes to the setup path, each with its own self-check. A new opt-out copies an existing shape. A macOS preference group becomes an `env` switch read by `setup/macos-extras.sh`, as `macos.disable_time_machine` is. A system change or a link that mise applies becomes a table in a `conf.d/60-rotm-<name>.toml` fragment, which `rotm-modules` already switches off. Nothing here adds a new mechanism.

**Tech Stack:** bash 3.2 (`setup/`, `bin/`), mise 2026.11.8 TOML fragments, `jq`, OpenSSH client config, Python 3.11+ standard library for the settings self-checks (`settings/tests/`), Firefox `user.js`.

**Spec:** `docs/superpowers/specs/2026-11-14-project-audit.md`, section I (findings I1 to I21) and "Decisions the owner must make" (decisions 1 to 7). Read both before Task 1. I22 is out of scope here. It belongs to the P6 plan (decision 8).

## Outcome

Done on 2026-11-14. Every task but Task 1 is on `main`, from `03df250` to `0d72eb4`. The owner answered decisions 1 to 7 before the tasks that wait on them.

| Task | Commit | Difference from the plan |
| --- | --- | --- |
| 1 | None | Dropped. The owner declined decision 1 and keeps the six allow rules |
| 2 | `b13fd42` | None |
| 3 | `7219d58` | New tool releases are held for 48 hours, not seven days (decision 7) |
| 4 | `03df250` | None |
| 5 | `528f7ec` | None |
| 6 | `7b94cea` | None |
| 7 | `da1cc8a` | None |
| 8 | `0d72eb4` | None |
| 9 | `3585de0`, `5e75b83` | As planned it still installed a changed or unchecked skill for an agent that lacked it. `5e75b83` holds the skill for every agent until `claude-config restore skills --accept <name>` |
| 10 | `30e199e` | Only the docs half shipped (decision 3). The KubeStellar pair stays |
| 11 | `3ae0ab8` | None |
| 12 | `ac43eb6` | As planned it removed `rtk.md`, `hindsight.md` and `catalog.md` from `~/.claude/rules` on the first apply of an existing install. The three module entries gained `depends = ["~/.claude/rules"]`, and `bin/lib/test-dotfiles` holds the migration case |
| 13 | `db7f2db`, `f246807` | `f246807` pins the setup diagram's sources to the commit that split the two fragments, so Archify validates |
| 14 | `d1e1bdb` | None |
| 15 | `7af79ae` | None |

Still not fixed, and not in any task: `--accept` installs whatever the source holds at that moment, and a first install on a new Mac is unpinned.

## Global Constraints

- The gate is `pnpm check`. Every task ends with it passing. The commit-gate hook runs it on each commit, so edit and commit in separate Bash calls.
- One commit per task, with the subject the task names. Commit subjects are short, imperative, sentence case, with no conventional-commit prefix.
- A change to setup behaviour, the package list or mise tools carries its doc edit in the same commit (`CLAUDE.md`, "Docs mirror behavior"). Each task names the docs it touches.
- Never run on this Mac: `sysup`, `./setup.sh`, `set-defaults`, `rotm install`, `rotm update`, `hindsight-memory init`, `hindsight-memory upgrade`, `hindsight-memory uninstall`, `rotm settings sync …` or the built app. Self-checks use scratch homes and stubs, as the existing ones do.
- Never touch `github.com/jrmatherly/rotm-settings`.
- Pushing a tag, closing a PR and running a GitHub workflow are the owner's and need their word.
- A task that carries an `**Owner decision <n>:**` line waits for the owner to confirm that decision. The other tasks do not wait.
- `CLAUDE.md` is 11,995 bytes against a cap of 12,000 (`bin/lib/test-conventions:200`). An edit to it must cut at least as much as it adds. No task below needs one.
- A new switch that `setup/macos-extras.sh` reads copies `macos.disable_time_machine` end to end:
  - a `[[setting]]` row in `settings/registry.toml`, section `"macOS (this Mac)"`, `kind = "env"`, `type = "bool"`, `true_value = "1"`, `default = "1"`, `access = "rw"` (the model row is at `settings/registry.toml:815-824`);
  - a `${DOTFILES_MACOS_<NAME>-1}` read in `setup/macos-extras.sh` (no colon, because the settings UI writes `""` for off). The settings plan's Task 9 (`2026-11-14-audit-settings-tool.md`, finding S6) changes how the script reads a switch, to on only when the value is `1`. If that task has landed, a new switch here uses the form the script then holds, and the test cases for "off" stay as written;
  - the variable in the `unset` list at `setup/tests/macos-extras.sh:42-44` and a pair of cases there, written as `check "<name>" "<shell test>"` lines;
  - the key in `on_by_default` at `settings/tests/test_macos_default.py:253-254`, which also asserts that every `DOTFILES_MACOS_*` name in the script has a registry row;
  - the count in the script's header (`setup/macos-extras.sh:38-43`, "sets all nine") and the switch list in `setup/README.md` ("Four groups the old script asked about").
- `setup/misc.sh` never calls sudo (`bin/lib/test-bootstrap:813` asserts it).
- Prose in docs and comments: short sentences, no long-dash character, no filler.

## Measured for this plan (2026-11-14, this Mac, mise 2026.11.8)

| Fact | How |
| --- | --- |
| `Match host github.com exec "test -f %d/.ssh/github_personal.pub"` applies its block only when the file exists, and `Match exec "test -S %d/Library/Group\ Containers/…/agent.sock"` sets `IdentityAgent` on this Mac | `ssh -G -F <scratch config> github.com` in two scratch homes and against the real tokens. No connection was made |
| mise merges `[dotfiles]` tables across `conf.d` fragments, and a file excluded from a `symlink-each` entry can be linked by a second fragment | `mise dotfiles status` in a scratch home with two fragments listed both entries. With the second fragment removed, only the first was listed |
| `minimum_release_age` is a setting mise knows and it is unset here | `mise settings get minimum_release_age` printed "is not set". An unknown name prints "Unknown setting" |
| `npx tsc` outside a project resolves to a deprecated package | `npm view tsc` printed version 2.0.4 and "Package no longer supported" |
| `azd`, `azure-functions-core-tools` and `github:getsentry/toolkit` report `Security: [none]` | `mise tool <name>` for each |
| `jq` is a base package, installed after `setup.sh:539` runs | `tilde/.config/mise/conf.d/30-packages.toml:59`, and `load_saved_settings` is called at `setup.sh:544`, before `packages_for` at `:548` |

## Decided while writing this plan

Each is a default the owner can change before the task starts.

- **I1.** The tracked SSH config keeps both blocks and makes each conditional on the file it needs. The alternative, moving the blocks to `~/.ssh/config.local`, would break GitHub SSH on the owner's Mac until the lines were copied by hand.
- **I2.** A rerun applies the saved tool settings when an origin is connected and no apply has been recorded. Making only the extras script non-fatal would leave the same loss after a failed `mise bootstrap` or task.
- **I3, I13 and I15.** All three change `setup/macos-extras.sh`. I15 needs decision 4 and the other two need none, so I15 is in the switches task with I9 and I14.
- **I6.** "Ours" is a `user.js` whose first line is `/* global user_pref */`, the first line of every version this repository has shipped. A new marker line would make the owner's stale copy look foreign once.
- **I11.** `rtk.md` and `hindsight.md` move to the `agents` module and `catalog.md` to the `claude` module. `jstack-models.md` stays in the base, because the settings tool reads and writes it and an installed copy seeds it from `config.rotm-installed.toml`.
- **I12.** Each of the two system changes becomes a module, `touchid` and `loginshell`. mise cannot condition a table on a variable, and a module is the one opt-out it honours under a bare `mise bootstrap` too.
- **I13.** Terminal.app is never force-quit. A run started from Ghostty or the app's console cannot know what the open Terminal windows hold.
- **I16.** An installed copy keeps its Dash sync folder in `${XDG_DATA_HOME:-~/.local/share}/rotm/dash`, outside both the checkout and the synced `~/.config/rotm`.
- **I17.** Documented, not changed. The three tools publish nothing mise can verify.
- **I20.** `sysup` exits 1 when any step failed. No caller in `app/`, `bin/rotm` or `setup.sh` reads its status.

## Review Focus

1. **A switch stored as the empty string, and one never set.** Off is `""` and on is unset or `1`. A new switch must do nothing when empty and act when unset. Tests in Tasks 7 and 13.
2. **Half of the 1Password layout.** A Mac with the agent socket and no `github_personal.pub`, and one with the file and no socket. Each block must apply alone. Test in Task 4.
3. **A rerun on a Mac whose saved settings were already applied.** An origin connected and an apply recorded must not apply again or ask. Test in Task 5.
4. **A stale copy of our own `user.js`.** After a pull, the profile holds an older version of the tracked file. It must still be replaced, while a file that was never ours is left alone. Test in Task 8.
5. **A tool that is present while its module is off.** The user installed it themselves, or switched the module off after an install. Setup must leave it alone. Test in Task 11.

---

### Task 1: Remove the allow rules that run fetched code

**Finding:** I8
**Owner decision 1:** remove `Bash(npx tsc:*)`, `Bash(npx license-checker:*)`, `Bash(bun install:*)`, `Bash(bun add:*)`, `Bash(bun update:*)` and `mcp__plugin_chrome-devtools-mcp_chrome-devtools__evaluate_script`. Keep `bun run`, `bun test`, `navigate_page` and `fill_form`. Do not start this task until the owner confirms it.

**Files:**
- Modify: `agents/claude-settings.json:14-51` (`permissions.allow`)
- Modify: `agents/claude-permissions-retired.txt` (append six lines)
- Test: `bin/lib/test-conventions:118`
- Modify: `agents/README.md` if it lists any of the six

- [ ] **Step 1: Write the failing check.** After `bin/lib/test-conventions:118`, add one line in the same form:

```bash
rules agents/claude-settings.json allow absent 'Bash(npx tsc:*)' 'Bash(npx license-checker:*)' 'Bash(bun install:*)' 'Bash(bun add:*)' 'Bash(bun update:*)' 'mcp__plugin_chrome-devtools-mcp_chrome-devtools__evaluate_script'
```

- [ ] **Step 2: Run it.** `bash bin/lib/test-conventions`. Expected: exit 1, "agents/claude-settings.json allow: Bash(npx tsc:*) should be absent".
- [ ] **Step 3: Remove the six rules** from `permissions.allow`, and append the same six texts, one per line, to `agents/claude-permissions-retired.txt`. The retired list is what makes `claude-config retire` and `restore` drop them from a Mac that already has them (`bin/lib/test-conventions:125` fails when a rule is in both files).
- [ ] **Step 4: Run it.** `bash bin/lib/test-conventions`. Expected: exit 0.
- [ ] **Step 5: Commit** "Stop allowing package installs and page scripts without a prompt". The message body records that `npm view tsc` shows a deprecated stand-in package.

---

### Task 2: Stop Firefox accepting debugger connections unasked and correct the DoH comment

**Finding:** I7, I19
**Owner decision 6:** drop `devtools.debugger.prompt-connection`. Do not start this task until the owner confirms it.

**Files:**
- Modify: `firefox/user.js:108-111`, `firefox/user.js:193-200`
- Test: `setup/tests/dotfiles-extras.sh`
- Modify: `firefox/README.md`

- [ ] **Step 1: Write the failing case.** In `setup/tests/dotfiles-extras.sh`, before the final "untouched" check (`:126`), in the file's `check "<name>" "<test>"` form:

```bash
check "the tracked user.js leaves the debugger's connection prompt on" "! grep -q 'devtools.debugger.prompt-connection' '$repo/firefox/user.js'"
check "the DoH comment says the mode it sets" "grep -B1 -F '0=default, 2=increased' '$repo/firefox/user.js' | grep -q '^// DNS over HTTPS (DoH) is off'"
```

- [ ] **Step 2: Run it.** `bash setup/tests/dotfiles-extras.sh`. Expected: two FAIL lines, exit 1.
- [ ] **Step 3: Edit `firefox/user.js`.** Delete line 111. Replace line 193, `// Enable DNS over HTTPS (DoH)`, with `// DNS over HTTPS (DoH) is off: mode 5. Set 2 or 3 to use the resolver below`. Leave `network.trr.mode` at 5.
- [ ] **Step 4: Say what a removed line does not undo.** In `firefox/README.md`, add one sentence: a preference removed from `user.js` keeps its last value in the profile, so reset `devtools.debugger.prompt-connection` in `about:config` on a profile that already ran with the old file.
- [ ] **Step 5: Run it.** `bash setup/tests/dotfiles-extras.sh`. Expected: exit 0.
- [ ] **Step 6: Commit** "Keep Firefox's debugger connection prompt and fix the DoH comment".

The dead-preference half of I19 is under "Findings the code contradicts or that stay unverified".

---

### Task 3: Hold mise tools for seven days

**Finding:** I18
**Owner decision 7:** `minimum_release_age = "7d"` in `tilde/.config/mise/config.toml`. Do not start this task until the owner confirms it.

**Files:**
- Modify: `tilde/.config/mise/config.toml` (`[settings]`, after `idiomatic_version_file_enable_tools`)
- Test: `bin/lib/test-bootstrap` (the `if command -v mise` block, `:781-801`)
- Modify: `setup/README.md:125` (says the cutoff is "shortened from 24 h to 6 h"), `tilde/.config/mise/conf.d/60-rotm-agents.toml:26-30` (the comment names "mise's default 24 h"). `docs/rea.md:7` names only the 6 h floor, which stays true, so it needs no edit

- [ ] **Step 1: Write the failing check.** Inside that block, after the `mise bootstrap user status` line (`:796`):

```bash
[ "$(mise settings get minimum_release_age 2> /dev/null)" = 7d ] || fail "config.toml does not hold new tool releases for 7 days"
```

- [ ] **Step 2: Run it.** `bash bin/lib/test-bootstrap`. Expected: "config.toml does not hold new tool releases for 7 days".
- [ ] **Step 3: Add the setting** with a one-line comment that it matches npm's `min-release-age 7` (`setup/misc.sh:453`) and Renovate, and that `npm:rea-agents` keeps its own 6 h. Update the two places that say 24 h.
- [ ] **Step 4: Run it.** `bash bin/lib/test-bootstrap`. Expected: exit 0. Then `cd ~ && mise ls --missing` and confirm no installed tool is reported missing.
- [ ] **Step 5: Not run on the host.** That a fresh install resolves every `latest` tool to a release at least seven days old is proved by the next `fresh-install` run, which the owner starts.
- [ ] **Step 6: Commit** "Hold new mise tool releases for seven days".

---

### Task 4: Use the 1Password SSH layout only where it exists

**Finding:** I1

**Files:**
- Modify: `tilde/.ssh/config:6-24`
- Modify: `setup/dotfiles-extras.sh:194-196`
- Test: `bin/lib/test-dotfiles` (new block before its mise section), `setup/tests/dotfiles-extras.sh:75`
- Modify: `docs/local-customizations.md:15-20`, `docs/installation.md:53`

**Interfaces:**
- Produces: the tracked config, in this order. The `Include` lines and the `Match all` stay where they are.

```sshconfig
Match host github.com exec "test -f %d/.ssh/github_personal.pub"
  IdentitiesOnly yes
  IdentityFile ~/.ssh/github_personal.pub

Match all
Include ~/.ssh/config.local

Match exec "test -S %d/Library/Group\ Containers/2BUA8C4S2C.com.1password/t/agent.sock"
  IdentityAgent "~/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"
```

- [ ] **Step 1: Write the failing test.** In `bin/lib/test-dotfiles`, in its `fail`-on-first-miss style. ssh takes `%d` and `~` from the account, not from `$HOME`, so the test rewrites both to a scratch folder in a copy and drops the `Include` lines. Create the socket with `python3 -c 'import socket,sys; socket.socket(socket.AF_UNIX).bind(sys.argv[1])'` under a `mktemp -d /tmp/rotm.XXXXXX` folder, because a socket path is limited to 104 bytes. Four scratch homes and one assertion each, read from `ssh -G -F <copy> <host>`:

| Home holds | Host | Must print | Must not print |
| --- | --- | --- | --- |
| nothing | `github.com` | `identitiesonly no` | `identityagent` naming 1password |
| the `.pub` file only | `github.com` | `identitiesonly yes` and `identityfile <home>/.ssh/github_personal.pub` | `identityagent` naming 1password |
| the socket only | `github.com` | `identitiesonly no` and `identityagent <home>/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock` |  |
| both | `example.com` | `identitiesonly no` and the same `identityagent` |  |

  Failure message: `"tilde/.ssh/config: <case> resolved to <the three lines>"`.
- [ ] **Step 2: Run it.** `bash bin/lib/test-dotfiles`. Expected: the "nothing" case fails with `identitiesonly yes`.
- [ ] **Step 3: Rewrite the two blocks** as in Interfaces. Keep the comment above the first block and add one line: without the file or the socket ssh uses its defaults.
- [ ] **Step 4: Warn about the key only on a Mac that has the agent.** In `setup/dotfiles-extras.sh:194`, the warning also requires `[ -e "$HOME/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock" ]`. In `setup/tests/dotfiles-extras.sh`, replace the case at `:75` with two: `"no 1Password agent: no warning about the public key"` (`! grep -q github_personal.pub "$tmp/out"`) for `h1`, and `"1Password agent without the public key: warned"` for a home where that path exists as a plain file.
- [ ] **Step 5: Run both.** `bash bin/lib/test-dotfiles && bash setup/tests/dotfiles-extras.sh`. Expected: exit 0. Then `ssh -G github.com | grep -iE '^(identitiesonly|identityagent)'` on this Mac. Expected: `identitiesonly yes` and the 1Password socket, as before the change.
- [ ] **Step 6: Update the two docs.** Both say SSH works only once 1Password is set up. Say instead that the pin and the agent apply when their file exists, and that any other key setup works untouched.
- [ ] **Step 7: Not run on the host.** `ssh -T git@github.com` with a plain `~/.ssh/id_ed25519` and no 1Password is a clean-Mac check. Add it as a row to the next guest run of the P5 VM proof (`docs/superpowers/specs/2026-11-14-p5-vm-proof/RUNBOOK.md`).
- [ ] **Step 8: Commit** "Apply the 1Password SSH settings only when their files exist".

---

### Task 5: Apply restored tool settings on the rerun after a failed run

**Finding:** I2

**Files:**
- Modify: `setup.sh:506-509` (`load_saved_settings`)
- Test: `bin/lib/test-bootstrap:654-660`
- Modify: `setup/README.md` (the step that describes loading saved settings)

**Interfaces:**
- Consumes: `settings/src/dotfiles_settings/sync.py:399-400`. `sync apply` writes `${XDG_STATE_HOME:-$HOME/.local/state}/rotm/effective.applied.json`, and so do `sync on` and `profile use`. A restore that was never followed by an apply leaves no such file.
- Produces: in `load_saved_settings`, when `mise dot origin` reports a connected origin and that file is missing, `restored=true` and the function returns. The block at `setup.sh:611` then runs `sync apply` as it does after a restore.

- [ ] **Step 1: Write the failing cases.** The fixture's `mise dot origin` already answers from `$STATE/origin` (`bin/lib/test-bootstrap:93-95`). Replace the block at `:654-660` with two `prepare` blocks. The first is the existing one plus:

```bash
check_true "an origin connected and never applied: the tool settings apply" applies 1
check_true "… with no question and no second restore" eval '! asked && restores 0'
```

  The second also runs `mkdir -p "$HOME/.local/state/rotm" && echo '{}' > "$HOME/.local/state/rotm/effective.applied.json"` in `prepare` and asserts:

```bash
check_true "an origin connected and already applied: no question" eval '! asked'
check_true "an origin connected and already applied: no restore" restores 0
check_true "an origin connected and already applied: nothing is applied again" applies 0
```

  `prepare` runs in the fresh `$HOME` before `setup.sh` does (`bin/lib/test-bootstrap:164-178`), so the file is in place for the run.
- [ ] **Step 2: Run it.** `bash bin/lib/test-bootstrap`. Expected: FAIL "an origin connected and never applied: the tool settings apply".
- [ ] **Step 3: Change `setup.sh:509`.** The `*) return 0 ;;` arm first sets `restored=true` when the applied record is missing. One comment line says why: a run that stopped between the restore and the apply leaves the origin connected and nothing applied.
- [ ] **Step 4: Run it.** `bash bin/lib/test-bootstrap`. Expected: exit 0.
- [ ] **Step 5: Update `setup/README.md`** in the same paragraph that describes the restore: a rerun after a failed run applies the saved tool settings.
- [ ] **Step 6: Commit** "Apply saved tool settings on the rerun after a run that stopped".

---

### Task 6: Carry on after a refused sudo in set-defaults, and leave Terminal open

**Finding:** I3, I13

**Files:**
- Modify: `setup/macos-extras.sh` (`:176`, `:193`, `:214-217`, `:223`, `:233`, `:236`, `:247`, `:262-270`)
- Test: `setup/tests/macos-extras.sh` (`:22`, `:165-166`)
- Modify: `README.md` and `docs/installation.md:154` (the list of apps `set-defaults` restarts), `setup/README.md` (macos section), `.claude/rules/macos-defaults.md` (the line that lists Terminal among the force-quit apps)

**Interfaces:**
- Produces: `root <command> [args…]` in `setup/macos-extras.sh`. It runs `sudo "$@"`. On a non-zero status it sets `root_refused=1`, warns once, and returns 0. Once `root_refused` is set it runs nothing and returns 0. Every `sudo` call in the script goes through it except `tmutil`, which keeps its own status handling and is skipped when `root_refused` is set.
- Produces: the warning text, exactly `Some settings need your password and were not applied: sudo failed or was cancelled. Run set-defaults again.`

- [ ] **Step 1: Write the failing cases.** Extend the `sudo` stub at `:22` so that `SUDO_RC`, when set, is its exit status for every call. Then, after the pmset cases at `:131-135` (the fixture still holds `disksleep 0`):

```bash
: > "$log"
SUDO_RC=1 "$repo/setup/macos-extras.sh" --restart > "$tmp/sudo.out" 2>&1
# shellcheck disable=SC2034 # read inside the eval of check
rc=$?
check "a refused sudo warns and the run carries on" "[ \$rc -eq 0 ] && grep -q 'sudo failed or was cancelled' '$tmp/sudo.out'"
check "… and sudo is asked once, not once per setting" "[ \"\$(grep -c '^sudo ' '$log')\" = 1 ]"
check "… and the apps still restart" "grep -qx 'killall Finder' '$log'"
```

  Replace the case at `:165-166` with:

```bash
stub pgrep 'exit "${PGREP_RC:-1}"'
run --restart
check "Terminal.app is never force-quit" "! grep -qx 'killall Terminal' '$log' && grep -qx 'killall Finder' '$log'"
PGREP_RC=0 "$repo/setup/macos-extras.sh" --restart > "$tmp/term.out" 2>&1
check "an open Terminal.app is told to reopen" "grep -q 'Quit and reopen Terminal' '$tmp/term.out'"
```

- [ ] **Step 2: Run it.** `bash setup/tests/macos-extras.sh`. Expected: the first new case fails with exit status 1 and no warning, and the Terminal case fails.
- [ ] **Step 3: Add `root`** below `sys` and route the calls through it. `"$(sys pmset)"` and the like stay as the argument, so a missing system tool still stops the run with `sys`'s own message.
- [ ] **Step 4: Drop Terminal from the restart list** at `:263`. After the loop, when `pgrep -xq Terminal` succeeds, print `warn "Quit and reopen Terminal to apply its settings."`. Remove the `TERM_PROGRAM` branch.
- [ ] **Step 5: Run it.** `bash setup/tests/macos-extras.sh`. Expected: exit 0, and the existing "every command sudo runs is in a system folder" case still passes.
- [ ] **Step 6: Update the four docs** named above. Each lists the apps that are force-quit.
- [ ] **Step 7: Commit** "Carry on after a refused sudo in set-defaults and leave Terminal open".

---

### Task 7: Switches for locale, power settings and the Spotlight shortcuts

**Finding:** I9, I14, I15
**Owner decision 4:** one switch each, on by default, so the owner's Mac is unchanged. Do not start this task until the owner confirms it.

**Files:**
- Modify: `tilde/.config/mise/conf.d/20-macos.toml:86-91` (remove the five locale keys and their comment), `:272-285` (remove the two `defaults_entries` and their comments)
- Modify: `setup/macos-extras.sh` (header `:38-43`, a locale block and a hotkeys block beside the other groups at `:117-152`, the pmset calls at `:179-189`)
- Modify: `settings/registry.toml` (three rows after `macos.software_update`, `:780-790`)
- Test: `setup/tests/macos-extras.sh`, `settings/tests/test_macos_default.py:253-254`
- Modify: `setup/README.md:194-207`, `docs/macos settings.md` (Keyboard and Spotlight sections, `:101-103` and `:199`), `docs/forking.md` (the row that names the owner's defaults in `settings/registry.toml`)

**Interfaces:**
- Produces: three switches, each in the shape Global Constraints describes.

| Registry id | Env key | Default | Label |
| --- | --- | --- | --- |
| `macos.locale` | `DOTFILES_MACOS_LOCALE` | `"1"` | Set language and region to US English |
| `macos.power` | `DOTFILES_MACOS_POWER` | `"1"` | Apply the power settings |
| `macos.spotlight_hotkeys` | `DOTFILES_MACOS_SPOTLIGHT_HOTKEYS` | `"1"` | Free ⌘Space from Spotlight |

  Help texts: locale, "en-US, US dollars, inches and Fahrenheit. Off leaves your language and region as they are. Applied by the next set-defaults." Power, "Lid wake on, disk sleep after 10 minutes, no wake for network access, hibernation mode 3. set-defaults asks for your password when one differs. Off leaves them as they are." Hotkeys, "Turns off the two Spotlight shortcuts so a launcher such as Raycast can use ⌘Space. Off leaves them as they are."
- Produces: the writes the locale block makes, the values the fragment holds today:

```bash
defaults write NSGlobalDomain AppleLanguages -array en-US
defaults write NSGlobalDomain AppleLocale -string en_US@currency=usd
defaults write NSGlobalDomain AppleMeasurementUnits -string Inches
defaults write NSGlobalDomain AppleTemperatureUnit -string Fahrenheit
defaults write NSGlobalDomain AppleMetricUnits -bool false
```

- Produces: the writes the hotkeys block makes, the form the script used before commit `eab7fa8`:

```bash
defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add 64 "{ enabled = 0; value = { parameters = (65535, 49, 1048576); type = standard; }; }"
defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add 65 "{ enabled = 0; value = { parameters = (65535, 49, 1572864); type = standard; }; }"
```

- [ ] **Step 1: Write the failing cases.** Add the three variables to the `unset` list at `setup/tests/macos-extras.sh:42-44`. After the "switched off" cases at `:72-77`:

```bash
run
check "locale is written when unset" "grep -q 'defaults write NSGlobalDomain AppleLocale -string en_US@currency=usd' '$log' && grep -q 'defaults write NSGlobalDomain AppleMetricUnits -bool false' '$log'"
check "the Spotlight shortcuts are turned off when unset" "grep -q 'defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add 64 ' '$log' && grep -q 'AppleSymbolicHotKeys -dict-add 65 ' '$log'"
DOTFILES_MACOS_LOCALE='' DOTFILES_MACOS_SPOTLIGHT_HOTKEYS='' run
check "locale switched off" "! grep -q 'NSGlobalDomain Apple' '$log'"
check "Spotlight shortcuts switched off" "! grep -q 'symbolichotkeys' '$log'"
```

  After the pmset cases at `:131-135`, where the fixture holds `disksleep 0`:

```bash
DOTFILES_MACOS_POWER='' run
check "power settings switched off: no pmset write" "! grep -q '^sudo .*/pmset' '$log'"
DOTFILES_MACOS_POWER=1 run
check "power settings switched on: the differing value is set" "grep -qx 'sudo .*/pmset -a disksleep 10' '$log'"
```

  In `settings/tests/test_macos_default.py:253-254`, add the three keys to `on_by_default`.
- [ ] **Step 2: Run them.** `bash setup/tests/macos-extras.sh` and the settings self-check (the command `bin/lib/check` runs for `settings/tests/test_macos_default.py`; read it there). Expected: the four new write cases fail, and the Python check fails on the first key with no registry row.
- [ ] **Step 3: Move the two groups and gate the third.** Delete the keys from the fragment. Add the two blocks to the extras script, each under `if [ -n "${DOTFILES_MACOS_<NAME>-1}" ]`, with the comments that sat above the keys. Wrap the four `pmset_ensure` calls the same way. mise never deletes a preference, so a Mac that already ran `set-defaults` keeps its values.
- [ ] **Step 4: Add the three registry rows** and raise the header's count from nine to twelve.
- [ ] **Step 5: Run them.** Both commands from Step 2, then `python3 setup/tests/macos-defaults.py`. Expected: exit 0 and "ok". The fragment's entry count is computed, so it needs no edit.
- [ ] **Step 6: Update the docs.** In `setup/README.md`, move "Language and region", "Energy (`pmset`)" and "⌘Space freed from Spotlight" out of "Always applied" and into the list of switches, which becomes seven. In `docs/macos settings.md`, name each switch where the setting is described.
- [ ] **Step 7: Commit** "Add switches for locale, power settings and the Spotlight shortcuts".

---

### Task 8: Leave a Firefox profile's own user.js alone

**Finding:** I6
**Owner decision 6:** skip the link when the profile already has a `user.js` that is not ours. Do not start this task until the owner confirms it.

**Files:**
- Modify: `setup/dotfiles-extras.sh:201-210`
- Test: `setup/tests/dotfiles-extras.sh:51`, `:107-124`
- Modify: `setup/README.md:183`, `firefox/README.md:8-11`

**Interfaces:**
- Produces: `ours <file>` in `setup/dotfiles-extras.sh`, true when the file's first line is exactly `/* global user_pref */`.
- Produces: for `user.js` only, when the profile's file exists, is not the tracked file (`-ef`) and is not `ours`, no link and no backup, and the warning `<profile>/user.js is your own, so the tracked preferences were not linked. They turn off Firefox Sync and password saving. Move it aside and rerun to use them.` The two CSS files keep today's backup-and-link behaviour.

- [ ] **Step 1: Change the fixture and write the failing cases.** At `:51` and `:119-120` the fixture `user.js` becomes two lines, the header then `v1` or `v2` (`printf '/* global user_pref */\nv1\n'`). At `:107-115`, the profile's `user.js` stays `mine` and `chrome/userChrome.css` is created holding `mine` too. Replace the cases at `:113-115`:

```bash
check "a user.js that is not ours is left alone" "[ \"\$(cat '$prof/user.js')\" = mine ] && [ ! -e '$prof/user.js.backup' ]"
check "… and the run says why" "grep -q 'user.js is your own' '$tmp/out'"
check "the CSS files are still hard-linked" "[ '$prof/chrome/userChrome.css' -ef '$fx/firefox/chrome/userChrome.css' ]"
check "a different CSS file is backed up first" "[ \"\$(cat '$prof/chrome/userChrome.css.backup')\" = mine ]"
check "an identical file is relinked without a backup" "[ '$prof/chrome/userContent.css' -ef '$fx/firefox/chrome/userContent.css' ] && [ ! -e '$prof/chrome/userContent.css.backup' ]"
```

  Then remove the profile's `user.js`, run, and assert `"an absent user.js is linked"`. The pulled-change cases at `:118-124` follow and now prove Review Focus 4: the stale copy starts with the header, so it is replaced and gets a backup name. Rewrite `:123` to `"the stale copy is backed up"` (`[ "$(sed -n 2p "$prof/user.js.backup")" = v1 ]`). Add one guard on the real file:

```bash
check "the tracked user.js starts with the line that marks it as ours" "[ \"\$(head -n 1 '$repo/firefox/user.js')\" = '/* global user_pref */' ]"
```

- [ ] **Step 2: Run it.** `bash setup/tests/dotfiles-extras.sh`. Expected: "a user.js that is not ours is left alone" fails, because the file was moved to `.backup`.
- [ ] **Step 3: Add `ours` and the skip** inside the `for file in …` loop at `:205`.
- [ ] **Step 4: Run it.** Expected: exit 0, and the final "untouched" check still passes.
- [ ] **Step 5: Correct the docs.** `setup/README.md:183` calls the three files "styles". Say that `user.js` is preferences, name the two it turns off (Firefox Sync and password saving), and state the skip. Mirror it in `firefox/README.md`.
- [ ] **Step 6: Commit** "Leave a Firefox profile's own user.js alone".

---

### Task 9: Report a changed third-party skill and stop reinstalling it

**Finding:** I4
**Owner decision 2:** record a reviewed tree SHA per skill and report an upstream change as a notice in place of reinstalling. Do not start this task until the owner confirms it.

**Files:**
- Modify: `bin/claude-config` (`upstream`, `:296-327`; `restore_skills`, `:329-355`; `save_skills`, `:270-291`; the `restore` argument loop, `:377-387`; the header and usage line)
- Modify: `agents/claude-skills.txt` (regenerated by Step 5)
- Modify: `bin/sysup:595-612`
- Test: `bin/lib/test-claude-config:101-130`, `bin/lib/test-sysup:162`, `:233`, `:271`
- Modify: `.claude/rules/claude-config-tool.md:19`, `agents/README.md`, `docs/updating.md` (the agent skills line), `bin/sysup:3` (header)

**Interfaces:**
- Produces: a row in `agents/claude-skills.txt` is `skill <name> <source> <agents> [<reviewed>]`. `<reviewed>` is the lock's `skillFolderHash` for a GitHub source or its `wellKnownDigest` for a well-known one. `claude-config save` writes it. A row with four fields is still valid.
- Produces: `upstream <name> [<reviewed>]` compares the upstream value with `<reviewed>` when given, else with the lock's value as today. It prints `same`, `changed` or `unknown`.
- Produces: `claude-config restore skills --update` prints `skill <state> <name>` per row and installs only for agents that lack the skill. It no longer reinstalls a `changed` or `unknown` skill.
- Produces: `claude-config restore skills --accept <name>` reinstalls that one skill for every agent on its row. It exits 2 with `claude-config: no tracked skill named <name>` for a name not in the list. The owner then runs `claude-config save` to record the new SHA.
- Produces: `sysup`'s line. With a changed skill: `status notice "agent skills" "<n> skill(s) changed upstream: <names>; <m> unchanged; review, then run: claude-config restore skills --accept <name>"`. Otherwise `status ok "agent skills" "<m> unchanged[, could not check: <names>]"`.

- [ ] **Step 1: Write the failing cases.** In `bin/lib/test-claude-config`, the fixture list at `:121` gains a fifth field on two rows: `skill a o/r claude-code aaa` and a new row `skill g o/r claude-code old`, with `g` in the lock at `skillFolderHash` `ggg` and in the tree at `ggg`. Replace the cases at `:126`, `:128` and `:129` and add three:

```bash
check "a moved folder SHA is reported, not reinstalled" "grep -qx 'skill changed b' '$tmp/out' && ! grep -q -- '-s b ' '$TEST_LOG.npx'"
check "a moved well-known digest is reported, not reinstalled" "grep -qx 'skill changed e' '$tmp/out' && ! grep -q -- '-s e ' '$TEST_LOG.npx'"
check "a source it can't check is reported, not reinstalled" "grep -qx 'skill unknown f' '$tmp/out' && ! grep -q -- '-s f ' '$TEST_LOG.npx'"
check "a skill installed past its reviewed SHA is changed, whatever the lock says" "grep -qx 'skill changed g' '$tmp/out'"
PATH="$tmp/bin:$PATH" cc restore skills --accept b > "$tmp/out" 2>&1
check "--accept reinstalls the named skill only" "grep -q -- '-s b -a claude-code' '$TEST_LOG.npx' && ! grep -q -- '-s e ' '$TEST_LOG.npx'"
PATH="$tmp/bin:$PATH" cc restore skills --accept nope > "$tmp/out" 2>&1
check "--accept refuses a name that is not tracked" "[ \$? = 2 ] && grep -q 'no tracked skill named nope' '$tmp/out'"
```

  Add a `save` case in the file's existing save section: after `cc save`, the row for a skill whose lock entry has `skillFolderHash` `aaa` ends in ` aaa`. In `bin/lib/test-sysup`, change `:233` to expect `'^✔ agent skills +1 unchanged, could not check: two$'` and `:271` to expect `'^● agent skills +1 skill changed upstream: one; 1 unchanged; review, then run: claude-config restore skills --accept one$'`. Check how `:314`'s headline counts change, since one "changed" becomes a "notice".
- [ ] **Step 2: Run them.** `bash bin/lib/test-claude-config` and `bash bin/lib/test-sysup`. Expected: the first new case in each fails.
- [ ] **Step 3: Change `bin/claude-config`** to the Interfaces above. `restore_skills` reads the fifth field with `read -r kind name source agents reviewed`.
- [ ] **Step 4: Change `bin/sysup:595-612`** to the two lines above, and its comment at `:595-597`.
- [ ] **Step 5: Record the SHAs.** `claude-config save` reads this Mac's `~/.claude` and writes `agents/`. Run `claude-config save`, then `git diff agents/` and confirm that the only change to `claude-skills.txt` is a fifth field on rows the lock knows. Revert any other change `save` made to `agents/` before committing.
- [ ] **Step 6: Run them.** Both self-checks. Expected: exit 0.
- [ ] **Step 7: Update the docs** named in Files. Each says `sysup` reinstalls a changed skill.
- [ ] **Step 8: Commit** "Report a changed third-party skill for review and stop reinstalling it".

**What this task leaves open.** It stops `sysup` reinstalling a skill that moved. It does not pin a first install: `restore skills` on a new Mac still runs `npx -y skills add <source>` (`bin/claude-config:355`), which fetches whatever the source holds that day. A stranger whose install lands after an upstream change then sees that skill as `changed` at their first `sysup`, with advice (`--accept`) written for the reviewer. Whether the `skills` CLI can install a source at a given commit is not checked here, and `npx -y skills add --help` settles it. If it can, pin the install to `<reviewed>` in a follow-up. If it cannot, say so in `agents/README.md` beside the list. Tell the owner which it is when this task is reported.

---

### Task 10: Name the third-party taps and unverified tools, and drop the KubeStellar pair

**Finding:** I5, I17
**Owner decision 3:** name the three taps in `docs/modules.md` and drop the `kubestellar` pair from the default set. Do not start this task until the owner confirms it.

**Files:**
- Modify: `tilde/.config/mise/conf.d/60-rotm-kubernetes.toml:8`, `:27-28`
- Test: `bin/lib/test-packages:105`
- Modify: `docs/modules.md` (new section after "Skipping one package or tool", `:44`). No page outside `docs/superpowers/` holds the count of 144 formulae (`git grep -n '\b144\b' -- '*.md' ':!docs/superpowers'` prints nothing), so the count changes in `bin/lib/test-packages` only

This task takes two packages out of the default set. The installable-setup spec's decision 3 says the base and its modules include everything they do today, so the removal needs the owner's explicit word, which the decision line above already requires. If the owner keeps the pair, do Steps 1, 4 and 5 without the count change and without the "add KubeStellar back" part, and leave the fragment as it is.

- [ ] **Step 1: Write the failing checks.** In `bin/lib/test-packages`, change the counts at `:105` from `(144, 34, 184)` to `(142, 34, 184)`. After `:100`, in the same Python block:

```python
docs = (repo / "docs/modules.md").read_text()
missing = [t for t in all_taps if t not in docs]
assert not missing, f"docs/modules.md does not name these taps: {missing}"
```

  Use the name that file already gives the repository root. Read the top of the block for it.
- [ ] **Step 2: Run it.** `bash bin/lib/test-packages`. Expected: "counts changed".
- [ ] **Step 3: Remove** the `kubestellar/tap` line and the two `brew:kubestellar/tap/…` lines.
- [ ] **Step 4: Write the docs section,** "Sources outside Homebrew's own lists", with three short parts. First, a table of every tap a fragment declares (`jrmatherly/tap`, `skyhook-io/tap`, `bramstein/webfonttools`), the package each serves and its module, and one sentence that a tap's formula is whatever its owner last pushed and that mise's release-age hold does not cover `brew:` packages. Second, the three tools mise installs with no checksum or attestation (`azd`, `azure-functions-core-tools`, `github:getsentry/toolkit`), each with the `disable_tools` line that skips it, in the form the section above uses. Third, how to add KubeStellar back, as a block for `~/.config/rotm/config.override.toml`:

```toml
[bootstrap.brew.taps]
"kubestellar/tap" = "https://github.com/kubestellar/homebrew-tap.git"

[bootstrap.packages]
"brew:kubestellar/tap/kubestellar-deploy" = "latest"
"brew:kubestellar/tap/kubestellar-ops" = "latest"
```

- [ ] **Step 5: Run it.** `bash bin/lib/test-packages`. Expected: exit 0.
- [ ] **Step 6: Not run on the host.** That the override block installs the pair is a guess until it is applied. The owner's Mac keeps both formulae installed (removing a line uninstalls nothing), so the proof is `mise bootstrap packages status` in a guest with the block in place. Say so in the commit body.
- [ ] **Step 7: Commit** "Name the third-party taps and drop the KubeStellar formulae from the default set".

---

### Task 11: Gate four misc.sh steps on their module

**Finding:** I10

**Files:**
- Modify: `setup/misc.sh:135-143` (rustup), `:392-395` (supabase), `:406-416` (PowerShell), `:424-433` (Aspire)
- Test: `bin/lib/test-bootstrap:706-757`
- Modify: `setup/README.md` (the `misc.sh` list, the four steps)

**Interfaces:**
- Consumes: `module_on <name>` (`setup/misc.sh:52-56`), which prints `skipped: the <name> module is off`.
- Produces: the Supabase telemetry step requires `module_on devops`. The rustup step runs when `devops` or `agents` is on, because its own comment (`setup/misc.sh:130-133`) says it exists for Hindsight's daemon start, which the `agents` module runs (`:277-282`). Its shape is `if [ -x "$rustup" ] && { "$DOTFILES_DIR/bin/lib/rotm-modules" is-on agents || module_on devops; }; then`, so the skip line prints only when both are off. `$agents_on` cannot be used here: it is set at `:163`, after this block. PowerShell and the Aspire certificate require `module_on cloud`, the module that declares `dotnet-sdk` and Aspire. In each, the tool check comes first and the module check second, so a Mac without the tool prints what it prints today.

- [ ] **Step 1: Write the failing cases.** In `fresh` (`:707-718`), add logging stubs for `supabase`, `dotnet` and `aspire` to the `mstub` loop, and one at `$HOMEBREW_PREFIX/opt/rustup/bin/rustup` (create the folder under the test's prefix). Add to the "all on" block after `:736`:

```bash
check_true "all on: rustup's default toolchain is set" ran 'rustup default stable'
check_true "all on: Supabase telemetry is turned off" ran 'supabase telemetry disable'
check_true "all on: PowerShell is installed" ran 'dotnet tool install --global PowerShell'
check_true "all on: the Aspire certificate hint is printed" has '\[Aspire\] HTTPS dev certificate not trusted'
```

  And a new block after `:757`:

```bash
fresh
printf 'devops\ncloud\n' > "$HOME/.config/mise/modules-off.local"
misc
for call in 'supabase telemetry' 'dotnet tool' 'dev-certs'; do
  check_true "devops and cloud off, tools present: no $call" eval '! ran "$call"'
done
check_true "devops off, agents on: rustup's default is still set for Hindsight" ran 'rustup default stable'
check_true "devops and cloud off: no Aspire hint" lacks '\[Aspire\]'
check_true "devops and cloud off: each says why" eval 'has "skipped: the devops module is off" && has "skipped: the cloud module is off"'
fresh
printf 'devops\nagents\n' > "$HOME/.config/mise/modules-off.local"
misc
check_true "devops and agents off, rustup present: no rustup default stable" eval '! ran "rustup default stable"'
```

  Read `:719-723` first: `ran` greps `$STATE/misc.log`, so the rustup stub at `$HOMEBREW_PREFIX/opt/rustup/bin/rustup` must log there as the `mstub` tools do, and answer `default` with a line that does not start `stable-`, or the step takes its "already the default" branch and never calls `default stable`.

- [ ] **Step 2: Run it.** `bash bin/lib/test-bootstrap`. Expected: the "all on" cases pass and "devops and cloud off, tools present: no supabase telemetry" fails.
- [ ] **Step 3: Add the four gates.** For PowerShell the shape is `if ! command_exists dotnet; then <today's "not found" line>; elif module_on cloud; then <install or update>; fi`.
- [ ] **Step 4: Run it.** Expected: exit 0, and "all on: nothing is skipped" still passes.
- [ ] **Step 5: Update `setup/README.md`.** Each of the four steps names its module.
- [ ] **Step 6: Commit** "Skip the Rust, Supabase, PowerShell and Aspire steps when their module is off".

---

### Task 12: Link the agent and Claude rules from their modules

**Finding:** I11

**Files:**
- Modify: `tilde/.config/mise/conf.d/40-dotfiles.toml:41`
- Modify: `tilde/.config/mise/conf.d/60-rotm-agents.toml`, `tilde/.config/mise/conf.d/60-rotm-claude.toml` (a `[dotfiles]` table each)
- Modify: `tilde/.config/mise/config.rotm-installed.toml:34`
- Test: `bin/lib/test-dotfiles:92-94`, `:181-183`
- Modify: `.claude/rules/symlinks.md` (the `~/.claude/rules` bullet), `docs/modules.md` (the `agents` and `claude` rows)

**Interfaces:**
- Produces: the base entry excludes three files. In `40-dotfiles.toml` the list is `exclude = [".DS_Store", "rtk.md", "hindsight.md", "catalog.md"]`. In `config.rotm-installed.toml` it is the same list plus `"jstack-models.md"`.
- Produces: in `60-rotm-agents.toml`:

```toml
[dotfiles]
"~/.claude/rules/rtk.md" = { source = "~/dotfiles/tilde/.claude/rules/rtk.md", mode = "symlink" }
"~/.claude/rules/hindsight.md" = { source = "~/dotfiles/tilde/.claude/rules/hindsight.md", mode = "symlink" }
```

  and in `60-rotm-claude.toml` the same shape for `catalog.md`. `jstack-models.md` stays in the base (see "Decided while writing this plan").

- [ ] **Step 1: Write the failing checks.** `bin/lib/test-dotfiles` applies the tracked fragment in a scratch home. Read how it loads `conf.d` first: if it copies only `40-dotfiles.toml`, the scratch config dir must also get the two module fragments. After `:94`:

```bash
for rule in rtk hindsight catalog; do
  [ -L "$home/.claude/rules/$rule.md" ] || fail "modules on: $rule.md is not linked"
done
```

  Then a second scratch home whose `miserc.local.toml` holds `ignored_config_paths = ["conf.d/60-rotm-agents.toml", "conf.d/60-rotm-claude.toml"]`, applied the same way:

```bash
for rule in rtk hindsight catalog; do
  [ ! -e "$off_home/.claude/rules/$rule.md" ] || fail "agents and claude off: $rule.md is still linked"
done
[ -L "$off_home/.claude/rules/verify-first.md" ] || fail "agents and claude off: the base rules are not linked"
```

- [ ] **Step 2: Run it.** `bash bin/lib/test-dotfiles`. Expected: "agents and claude off: rtk.md is still linked".
- [ ] **Step 3: Make the three edits** in Interfaces. Keep each `[dotfiles]` table below the fragment's `[tools]` or `[bootstrap.packages]` table, with one comment line: the rule describes a tool this module installs.
- [ ] **Step 4: Run it.** `bash bin/lib/test-dotfiles`, then `bash bin/lib/test-packages` (it parses every fragment). Expected: exit 0. The checks at `:48-55` on `config.rotm-installed.toml` allow an exclude-only change.
- [ ] **Step 5: Check this Mac without applying.** `cd ~ && mise dotfiles status | grep -E 'rules/(rtk|hindsight|catalog)'`. Expected: three rows whose source column is a `60-rotm-` fragment, in the state the other links show.
- [ ] **Step 6: Update the two docs.** A link already made stays when its module is switched off later, as a module's packages do. Say so in the `docs/modules.md` rows.
- [ ] **Step 7: Commit** "Link the rtk, Hindsight and catalog rules from their modules".

---

### Task 13: Switches for Touch ID for sudo and the login shell

**Finding:** I12
**Owner decision 5:** one switch each, on by default. Do not start this task until the owner confirms it.

**Files:**
- Create: `tilde/.config/mise/conf.d/60-rotm-touchid.toml`, `tilde/.config/mise/conf.d/60-rotm-loginshell.toml`
- Modify: `tilde/.config/mise/conf.d/50-bootstrap.toml:8-20` (the two tables and their comments move out)
- Modify: `bin/lib/rotm-modules:46` (the `modules` array)
- Modify: `settings/registry.toml` (two rows after `modules.menubar`, `:1033-1043`)
- Test: `bin/lib/test-modules:38`, `bin/lib/test-bootstrap:795-796`, `settings/tests/test_registry.py:110-111`
- Modify: `docs/modules.md` ("thirteen modules" at `:3` and the table), `docs/installation.md:111` (the `--without` list) and `:119` (says mise declares `sudo_local`), `setup/README.md:45` and `:108` (each names `50-bootstrap.toml` as the file that declares it), `bin/lib/test-bootstrap:13` (the header comment), `setup/bootstrap-runtime.archify.json:184-190` (the diagram source names `50-bootstrap.toml` for `sudo_local`; change the path and regenerate the diagram the way `setup/README.md` says it is built)

**Interfaces:**
- Produces: two modules, appended to the array in this order.

| Module | Fragment holds | Registry id | Default | Label |
| --- | --- | --- | --- | --- |
| `touchid` | `[bootstrap.files."/etc/pam.d/sudo_local"]` with its four keys | `modules.touchid` | `"on"` | Touch ID for sudo |
| `loginshell` | `[bootstrap.user]` with `login_shell = "/opt/homebrew/bin/zsh"` | `modules.loginshell` | `"on"` | Zsh as the login shell |

  Registry rows copy `modules.menubar` (`kind = "module"`, `key = "<name>"`, `type = "bool"`, `true_value = "on"`, `access = "rw"`). Each fragment opens with the four header lines the other modules use, and says what off leaves behind: the file or the login shell stays as it is, and setup stops rewriting it.

- [ ] **Step 1: Write the failing checks.** `bin/lib/test-modules:38` expects the list to end `… media menubar touchid loginshell `. In `settings/tests/test_registry.py`, after `:111`, the same two-line assertion for each new id. In `bin/lib/test-bootstrap`, after `:796`, in the scratch home that block already uses (its config dir is the repository's, so write the off list to a copy: read how `MISE_CONFIG_DIR` is set at `:782` and point a second run at a temp copy of `tilde/.config/mise` whose `miserc.local.toml` ignores the two fragments):

```bash
! mise bootstrap files status | grep -q '/etc/pam.d/sudo_local' || fail "touchid off: sudo_local is still declared"
! mise bootstrap user status | grep -q '^/opt/homebrew/bin/zsh' || fail "loginshell off: the login shell is still declared"
```

- [ ] **Step 2: Run them.** `bash bin/lib/test-modules`, `bash bin/lib/test-bootstrap` and the settings self-check. Expected: `test-modules` fails with "list".
- [ ] **Step 3: Move the tables, extend the array, add the rows.** Then run `git grep -n menubar -- ':!docs/superpowers' ':!app'` and add the two names wherever that module is listed by name beside the others (the array, `docs/installation.md:111`, `docs/modules.md`).
- [ ] **Step 4: Run them.** All three, then `bash bin/lib/test-packages`. Expected: exit 0. The existing checks at `test-bootstrap:795-796` still pass with both modules on.
- [ ] **Step 5: Not run on the host.** That a run with `--without touchid,loginshell` leaves `/etc/pam.d/sudo_local` absent and the account's shell unchanged needs a clean Mac. It is one row for the next guest run of the P5 VM proof, or a `fresh-install` run with that flag, which the owner starts.
- [ ] **Step 6: Update the docs.** `docs/modules.md` says fifteen modules. The two new rows say that these are system changes, not packages.
- [ ] **Step 7: Commit** "Make Touch ID for sudo and the login shell switchable".

---

### Task 14: Keep Dash docsets out of an installed copy's checkout

**Finding:** I16

**Files:**
- Modify: `setup/dash.sh:22-23`, `:32-37`, `:47`, `:150-152`
- Create: `setup/tests/dash.sh`
- Modify: `bin/lib/check` (one `job quiet bash setup/tests/dash.sh` line with its comment, beside `setup/tests/menubar-open.sh` at `:129`)
- Modify: `setup/README.md:220-226`, `docs/installation.md:177-186`

**Interfaces:**
- Produces: `dash_dir` in `setup/dash.sh`. It is `$DOTFILES_DIR/dash` when `"$DOTFILES_DIR/bin/lib/rotm-mode" "$DOTFILES_DIR"` prints `clone` (called by path with the folder as its argument, as `setup.sh:32` does), and `${XDG_DATA_HOME:-$HOME/.local/share}/rotm/dash` when it prints `installed`. `PLIST` is `$dash_dir/Dash.dashsync/Preferences.plist`, and every message that names the sync folder prints `$dash_dir`.
- Produces: on an installed copy with no file there yet, the script copies the checkout's `dash/Dash.dashsync/Preferences.plist` to `$dash_dir` first, so the tracked Dash settings are the starting point.

- [ ] **Step 1: Write the failing test,** `setup/tests/dash.sh`, in the form of `setup/tests/menubar-open.sh` (a temp dir, a `check` helper, exit 1 with a count). The fixture is a folder with a copy of `dash/Dash.dashsync/Preferences.plist`, a `bin/lib/rotm-mode` stub that prints the content of `$tmp/mode`, and a docs folder. Each run is `env -i HOME="$tmp/home" PATH=/usr/bin:/bin DOTFILES_DIR="$fx" bash "$repo/setup/dash.sh" add "$tmp/docs" Notes notes`. Cases:

```bash
check "a clone: the docset is written to the checkout's file" "grep -q '<string>notes</string>' '$fx/dash/Dash.dashsync/Preferences.plist'"
check "an installed copy: the checkout's file is unchanged" "cmp -s '$fx/dash/Dash.dashsync/Preferences.plist' '$tmp/plist.before'"
check "an installed copy: the docset is in the user's folder" "grep -q '<string>notes</string>' '$tmp/home/.local/share/rotm/dash/Dash.dashsync/Preferences.plist'"
check "an installed copy: the run names that folder as the sync folder" "grep -qF '$tmp/home/.local/share/rotm/dash' '$tmp/out'"
```

  The fixture checkout is reset from the real file between the clone case and the installed cases.
- [ ] **Step 2: Run it.** `bash setup/tests/dash.sh`. Expected: "an installed copy: the checkout's file is unchanged" fails.
- [ ] **Step 3: Add `dash_dir`** and the first-run copy, and wire the test into `bin/lib/check`.
- [ ] **Step 4: Run it.** `bash setup/tests/dash.sh`. Expected: exit 0. `bin/lib/test-conventions` checks that every `setup/*.sh` is executable. The test file sits under `setup/tests/` and is run through `bash`, as its neighbours are.
- [ ] **Step 5: Update the two docs.** Both tell the reader to point Dash's sync folder at the repository's `dash/` folder. An installed copy points it at `~/.local/share/rotm/dash`.
- [ ] **Step 6: Commit** "Write Dash docsets outside an installed copy's checkout".

---

### Task 15: Give the sysup plugins step a line when nothing is installed, and exit 1 after a failed step

**Finding:** I20

**Files:**
- Modify: `bin/sysup:718-726`, `bin/sysup:903`, the header at `:3-10`
- Test: `bin/lib/test-sysup:206-211` (`run`), and a new case beside `:231`
- Modify: `.claude/rules/sysup.md` (the "Report contract" bullet), `docs/updating.md`

**Interfaces:**
- Produces: when no plugin was checked, none updated, none blocked and none failed, `status ok plugins "none installed"`.
- Produces: `sysup` exits 1 when its `failed` array is non-empty, after the summary and the sign-off. It still never stops at a failed step.

- [ ] **Step 1: Write the failing cases.** In `run` (`:206-211`), replace the status check with one that ties the status to the screen:

```bash
if has '^✖ '; then check_true "sysup exited 1 after a failed step" [ "$rc" -eq 1 ]
else check_true "sysup exited 0" [ "$rc" -eq 0 ]; fi
```

  Beside the "up to date" block (`:231`), a run with `printf '{"plugins":{}}' > "$CLAUDE_CONFIG_DIR/plugins/installed_plugins.json"`, then restore the two-plugin file:

```bash
check_true "no plugins installed: the step still reports" has '^✔ plugins +none installed$'
```

- [ ] **Step 2: Run it.** `bash bin/lib/test-sysup`. Expected: the first run that stages a failure (`:352`) fails with "sysup exited 1 after a failed step".
- [ ] **Step 3: Make the two changes.** The plugins step needs a per-step count of `status fail plugins` lines, or a flag set in that branch, so "none installed" is not printed after a failed update. The exit is `[ ${#failed[@]} -eq 0 ] || exit 1` as the last line.
- [ ] **Step 4: Run it.** Expected: exit 0.
- [ ] **Step 5: Update the docs.** The "Report contract" bullet and `docs/updating.md` gain one sentence each: `sysup` exits 1 when a step failed.
- [ ] **Step 6: Commit** "Report the sysup plugins step when none is installed and exit 1 after a failed step".

---

## Findings the code contradicts or that stay unverified

- **I21 (`/usr/bin/jq` at `setup.sh:539`).** Not planned. The spec offers `jq` from PATH, and the code rules that out: `load_saved_settings` runs at `setup.sh:544`, before the package lists at `:548` install `brew:jq` (`30-packages.toml:59`). On a new Mac no `jq` is on PATH at that point, and the absolute path is the only one that can exist. The other `jq` calls (`setup.sh:426`, `:570`) run after the packages. Whether macOS 14 ships `/usr/bin/jq` is still a guess, and `ls /usr/bin/jq` in a macOS 14 guest settles it. If it is missing, the test at `:539` is false and a restored `DOTFILES_SKIP_CODEGRAPH` is ignored for that one run with no error. The fix then is to read the value without `jq` (for example `mise env | grep -qx 'export DOTFILES_SKIP_CODEGRAPH=true'`), which needs its own measurement of `mise env`'s output first.
- **I19, the dead preferences.** Not planned. The spec labels the list (Pocket at `firefox/user.js:157` and `:228`, Fakespot at `:226`, the shopping experience at `:126`) a guess. Mozilla's `modules/libpref/init/StaticPrefList.yaml` and `browser/app/profile/firefox.js` for the current Developer Edition settle which names still exist. A dead preference in `user.js` does nothing, so nothing is removed on a guess. Task 2 fixes the DoH comment, which was read.
- **I10, as worded.** The four blocks do not run on a Mac that never had the tool: each is behind `[ -x "$rustup" ]` or `command_exists`. They run with the module off only when the tool is present anyway. Task 11 fixes that case and its test stages exactly it.
