# Audit fixes for the settings tool and terminal UI, Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix findings S1 to S11 of the 2026-11-14 audit, so `rotm settings` never syncs a password, never dies on a file it cannot read, and its terminal UI never writes or discards a value the user did not choose.

**Architecture:** Every fix sits at the boundary where the bad input arrives. Sync's folder check (`sync._guard`) and the value check (`cli.normalize`) refuse or clean what must not reach the settings repository. One tuple of expected failures (`model.FAILURES`) is caught where a front end already catches `SettingsError`. The terminal UI's writes all pass through `SettingsApp.commit`, which is where a write during a read error stops. No new module and no new test file.

**Tech Stack:** Python 3.11+ standard library (`settings/src/dotfiles_settings`), Textual 8.2.8 (`settings/uv.lock`), bash 3.2 (`setup/macos-extras.sh`, `bin/lib/test-sync`), mise 2026.11.8.

**Spec:** `docs/superpowers/specs/2026-11-14-project-audit.md`, section "S. Settings tool and terminal UI". No entry in its "Decisions the owner must make" covers an S finding, so no task waits on one. Task 9 changes a documented rule and says so at its top: tell the owner before starting it.

## Global Constraints

- The gate is `pnpm check`. Every task ends with it passing. Edit and commit in separate Bash calls.
- Commit subjects are short, imperative, sentence case, with no conventional-commit prefix. One commit per task, with the subject the task names. `CLAUDE.md`'s standing approval covers the commit and the push on `main`.
- A change to setup behaviour, the package list or mise tools carries its doc edit in the same commit (`CLAUDE.md`, "Docs mirror behavior"). The same holds here for `settings/README.md` when a command's behaviour or exit code changes.
- Never run on this Mac: `sysup`, `./setup.sh`, `set-defaults`, `rotm install`, `rotm update`, `hindsight-memory init|upgrade|uninstall`, `rotm settings sync …` or the built app. Tests use scratch homes and stubs, as the files they join already do.
- Never touch github.com/jrmatherly/rotm-settings. Pushing a tag, closing a PR and running a GitHub workflow are the owner's and need their word.
- No new test file. Every case joins an existing file, so the list in `bin/lib/check:71` and the three `uv run` lines at `:86-88` do not change.
- The standard-library tests run as `mise exec python -- python3 settings/tests/<file>` (macOS's own `python3` is 3.9 and has no `tomllib`). The UI tests run as `uv run --quiet --locked --project settings python settings/tests/<file>`. Each prints `ok` as its last line.
- Line numbers are those of `main` at `1b5fa26`.
- `.claude/rules/*.md` files are capped at 6000 bytes and 1000 bytes a line (`bin/lib/test-conventions:202-204`). Task 9 replaces a sentence there and adds none.

## Decided while writing this plan

Each is a default the owner can change before the task starts. None was asked.

- **S1 deletes the file.** mise saves a `.DS_Store` from a tracked folder (measured below), so ignoring it in the check would publish it. `_guard` removes it. Finder rebuilds it on demand.
- **S2 is a keyed check, not a registry field.** The registry has no per-row validation field (`registry.py:11`). One dict in `sync.py` names the env key and its prefix, and both boundaries read it.
- **S6 is fixed in two places.** The UI stops writing on a redraw (`on_switch_changed`), and `setup/macos-extras.sh` reads a switch as on only when it is `1`, which is the registry's `true_value` and what the UI shows. `normalize` is not changed, since it already stores only `1` or the empty string.
- **S7 keeps exit 1.** A step did fail. The message now says the switch happened and what to run.
- **S8 scopes the row to the machine.** Storing `~` would need both consumers to expand it (`bin/obsidian-vault:23`, `bin/install-color-themes:63` use the value as a path as it is), and the env adapter refuses `$`.
- **S10 saves a single-line field on Tab,** as a lines box already saves on blur. Reverting on Tab was the other option.
- **S10 keeps a refused value's message for 20 seconds.** The value still returns to the stored one.

## Measured for this plan (2026-11-14, this Mac)

| Fact | How |
| --- | --- |
| mise 2026.11.8 saves `.DS_Store` from a folder tracked with `mode = "track"` | In a scratch home `mise dot save` printed "2 files" and `mise dot files` listed `.DS_Store` as tracked |
| Every terminal UI finding reproduces | Each case of the reviewer's `probe.py` was rerun: S3 and S4 crash, S5 writes `~/dev\n~/ha`, S6 writes `('t.flag', '')` |
| The planned UI fixes behave as the tasks state | A scratch subclass with the `commit` guard, `on_input_blurred`, the ancestor walk in `setting_of` and the `on_switch_changed` test. It wrote nothing under the banner, Tab saved `oldX`, Ctrl+R reached `reset`, and a stored `0` wrote nothing |
| A subclass handler does not replace the base one | Textual ran both `on_switch_changed` methods. Edit the method in `tui.py`, never shadow it |
| `Input.Blurred(input, value)` and `Widget.ancestors_with_self` exist | Textual 8.2.8 in `settings/.venv` |
| The app never passes `--repo` | No match for `repo` in `app/Sources` |
| This Mac's override file holds no `OBSIDIAN_VAULT` and no switch stored as `0` | `grep` on `tilde/.config/mise/config.override.toml` |

## Review Focus

1. **A password stored before the fix.** A value that is not an `op://` reference is already in `config.override.toml`, put there by an older version or by `mise set`. `sync on` and `sync now` must stop before the first save and must not print the value. Test in Task 2.
2. **A file that is not UTF-8 other than the env override.** `miserc.local.toml`, `tools.toml` or `jstack-models.md` holds bad bytes. The command line prints one line and exits 1. Test in Task 3.
3. **A role line with no space after the comma** (`fable medium,opus medium`). The row opens unchanged, and a save from it is refused by `parse_seats`. Tests in Task 5.
4. **Text typed right before the error banner appears.** The half-typed lines are not saved, are still in the box when the file reads again, and save on the next blur. Test in Task 4.
5. **A vault path already in the shared override file.** After Task 8, `sync now` stops and names `rotm settings set apps.obsidian_vault`, which moves the value. Test in Task 8.

---

### Task 1: Remove a Finder `.DS_Store` before sync checks the folder

**Finding:** S1

**Files:**
- Modify: `settings/src/dotfiles_settings/sync.py:201-207` (`_guard`)
- Test: `settings/tests/test_sync.py` (after `test_a_secret_or_a_stray_file_stops_before_the_first_save`, `:315`), `bin/lib/test-sync:222-223`
- Modify: `settings/README.md:162`

- [ ] **Step 1: Write the failing tests.** In `test_sync.py`:

```python
def test_a_finder_ds_store_is_removed_and_stops_nothing():
    for fn, args in ((sync.on, ("rotm-settings",)), (sync.now, ())):
        fresh()
        (sync.user_dir() / ".DS_Store").write_bytes(b"\0\0\0\1Bud1")
        fn(*args)
        assert not (sync.user_dir() / ".DS_Store").exists() and "mise dot save" in calls(), (fn.__name__, calls())
```

In `bin/lib/test-sync`, add `touch "$(folder a)/.DS_Store"` on the line before `settings a sync now` (`:222`), and after the existing exit-0 row add `check_true "A: a Finder .DS_Store is removed before the save" [ ! -e "$(folder a)/.DS_Store" ]`.

- [ ] **Step 2: Run them.** `mise exec python -- python3 settings/tests/test_sync.py` fails with `SettingsError: … holds .DS_Store`. `bash bin/lib/test-sync` fails at "A: sync now after a change exits 0".
- [ ] **Step 3: Change `_guard`.** Before the folder is listed, `(folder / ".DS_Store").unlink(missing_ok=True)`. One comment line gives the reason, that mise saves every file in a tracked folder and Finder writes this one. No other name is exempt.
- [ ] **Step 4: Run both again.** Each ends with `ok`.
- [ ] **Step 5: Edit `settings/README.md:162`.** After "when the folder holds any file but those three" add that a Finder `.DS_Store` is deleted, not refused.
- [ ] **Step 6: `pnpm check`, then commit** "Remove a Finder .DS_Store before sync saves the folder".

### Task 2: Refuse a Mac password where the 1Password reference goes

**Finding:** S2

**Files:**
- Modify: `settings/src/dotfiles_settings/sync.py:150` (new constant beside `SECRET`), `:210-220` (`_guard`'s loop)
- Modify: `settings/src/dotfiles_settings/cli.py:38` (`normalize`, before the final `return raw`)
- Test: `settings/tests/test_cli.py` (after the exit-code loop, `:138`), `settings/tests/test_sync.py` (after `test_the_secret_rule_reads_every_env_table_in_any_case`, `:326`)
- Modify: `settings/README.md` ("Values that are refused", `:182-190`, and `:162`)

**Interfaces:**
- Produces: `sync.REFERENCE: dict[str, str] = {"DOTFILES_MAC_PASSWORD_OP": "op://"}`, an env key mapped to the prefix its value must start with. An empty value stays allowed.

- [ ] **Step 1: Write the failing tests.** In `test_cli.py` (import `InvalidValue` and `Setting` from `dotfiles_settings.model`):

```python
ref = Setting(id="t.ref", section="T", label="", help="", kind="env", key="DOTFILES_MAC_PASSWORD_OP", type="string",
              access="rw")
assert cli.normalize(ref, "op://Private/Mac login/password") == "op://Private/Mac login/password"
assert cli.normalize(ref, "") == ""
try:
    cli.normalize(ref, "hunter2")
    raise AssertionError("a password was accepted")
except InvalidValue as e:
    assert "op://" in str(e) and "hunter2" not in str(e), e
```

In `test_sync.py`:

```python
def test_a_password_in_place_of_the_reference_stops_before_the_first_save():
    fresh()
    (sync.user_dir() / "config.override.toml").write_text('[env]\nDOTFILES_MAC_PASSWORD_OP = "hunter2"\n')
    message = raises(sync.now)
    assert "DOTFILES_MAC_PASSWORD_OP" in message and "hunter2" not in message, message
    assert "mise dot save" not in calls(), calls()
    fresh()
    (sync.user_dir() / "config.override.toml").write_text('[env]\nDOTFILES_MAC_PASSWORD_OP = "op://Private/Mac/password"\n')
    sync.now()
    assert "mise dot save" in calls()
```

- [ ] **Step 2: Run them.** `test_cli.py` fails with "a password was accepted". `test_sync.py` fails with "now did not raise".
- [ ] **Step 3: Add `REFERENCE` and the check in `normalize`.** For an `env` setting whose key is in `sync.REFERENCE`, a non-empty value that does not start with the prefix raises `InvalidValue(f"{s.id}: expected a 1Password secret reference that starts with op://. Nothing was stored.")`. The message never contains the value, because it is printed to the terminal and shown by the app.
- [ ] **Step 4: Add the check in `_guard`.** In the loop over override files, a string value under a `REFERENCE` key that is non-empty and lacks the prefix raises a `SettingsError` that names the key and the file, says sync would keep it in the repository's history for good, and gives the `unset` command the loop already builds. It never contains the value. It runs for every env table, as the secret rule does.
- [ ] **Step 5: Run both again.** Each ends with `ok`.
- [ ] **Step 6: Edit `settings/README.md`.** Add one bullet to "Values that are refused" for `updates.mac_password_op`, and add the same case to the list of what stops `on` and `now` at `:162`. Say that a value an earlier sync already saved stays in that repository's history, and removing it is the owner's call.
- [ ] **Step 7: `pnpm check`, then commit** "Refuse a password where the 1Password reference goes".

### Task 3: Report unreadable and undecodable files in one line

**Finding:** S4

**Files:**
- Modify: `settings/src/dotfiles_settings/model.py` (new constant after `InvalidValue`)
- Modify: `settings/src/dotfiles_settings/adapters/env.py:34-39` (`read_env`)
- Modify: `settings/src/dotfiles_settings/tui.py:113`, `:178`, `:192`; `settings/src/dotfiles_settings/tui_agents.py:165`; `settings/src/dotfiles_settings/cli.py:190`
- Test: `settings/tests/test_env.py:132-136`, `settings/tests/test_cli.py:142-146`, `settings/tests/test_tui.py`, `settings/tests/test_tui_agents.py` (`test_stack_screen_keep_and_off`)
- Modify: `settings/README.md:71`

**Interfaces:**
- Produces: `model.FAILURES = (SettingsError, OSError, UnicodeDecodeError)`, what a front end reports in one line. It is not `Exception`, so a bug still shows its traceback.
- Produces: in `test_tui.py`, `FakeAdapter.fail` and `FakeAdapter.refuse` accept a message or an exception instance, `reset` honours `refuse`, and `FakeAdapter.reads` counts `read` calls (Task 12 uses it).

- [ ] **Step 1: Write the failing tests.**
  - In `test_env.py`, after the invalid-TOML case, add `env.override_path().write_bytes(b'[env]\nT = "\xff"\n')`, then `raises(lambda: a.read(S("T_VAL")), SettingsError, "config.override.toml")`, then unlink.
  - In `test_cli.py`, after the invalid-TOML case, write the same bytes to `env.override_path()`. `run("list", "--json")` gives code 1, `config.override.toml` in stderr, no `Traceback`, one line. Then, for Review Focus 2, `(conf / "miserc.local.toml").write_bytes(b'env = ["\xff"]\n')` and `run("profile", "list")` gives code 1, stderr starts with `dotfiles-settings: `, has one line and no `Traceback`. Unlink both.
  - In `test_tui.py`, change `FakeAdapter` as Interfaces says, and add this after the refused-value block (`:108`):

```python
        fake.refuse = FileNotFoundError(2, "No such file or directory", "bin/hindsight-memory")
        app.query_one("#w-t-name", Input).focus()
        await pilot.press("end", "?", "enter"); await pilot.pause()
        assert app.is_running and any("hindsight-memory" in str(n.message) for n in app._notifications)
        fake.overrides["T_NAME"] = "set"; app.refresh_values(); await pilot.pause()
        app.query_one("#w-t-name", Input).focus(); await pilot.press("ctrl+r"); await pilot.pause()
        assert app.is_running and fake.overrides["T_NAME"] == "set", "a reset that cannot run is a notice"
        fake.refuse = None; fake.overrides.pop("T_NAME")
        fake.fail = PermissionError(13, "Permission denied", "config.override.toml")
        app.refresh_values(); await pilot.pause()
        assert "Permission denied" in str(app.query_one("#error", Static).content)
        fake.fail = None; app.refresh_values(); await pilot.pause()
```

    Add a second app beside the `empty` one (`:122`). A `FakeAdapter` whose `fail` is that `PermissionError` before mount opens with the `#error` banner holding "Permission denied".
  - In `test_tui_agents.py` (import `Static`), at the end of `test_stack_screen_keep_and_off`, set `tool.stack_scan` to a function that raises `FileNotFoundError(2, "No such file", "bin/claude-stack")`, press `p`, pause 0.2, and assert the `#stack-state` text is "Scan failed" and the app is running.
- [ ] **Step 2: Run the four files.** `test_env.py` and `test_cli.py` fail with `UnicodeDecodeError`. The two UI files fail with `FileNotFoundError` or `PermissionError` raised out of `run_test`.
- [ ] **Step 3: Add `FAILURES` and use it.** `read_env` keeps `FileNotFoundError` as empty and turns `OSError`, `UnicodeDecodeError` and `TOMLDecodeError` into `SettingsError(f"{path}: {e}")`. The four UI sites and `cli.main` catch `FAILURES` in place of `SettingsError`. `cli.main`'s exit mapping is unchanged, so an `OSError` exits 1. A decode error in a file other than the env override prints Python's message, which does not name the file.
- [ ] **Step 4: Run the four files again.** Each ends with `ok`.
- [ ] **Step 5: Edit `settings/README.md:71`.** Add "a file that cannot be read or is not UTF-8" to the list of exit 1 causes.
- [ ] **Step 6: `pnpm check`, then commit** "Report a file the settings tool cannot read in one line".

### Task 4: Write nothing while the read error shows

**Finding:** S5

**Files:**
- Modify: `settings/src/dotfiles_settings/tui.py:171-172` (`commit`)
- Test: `settings/tests/test_tui_agents.py`

**Interfaces:**
- Produces: in `test_tui_agents.py`, `FakeAdapter.fail: Exception | None`, raised by `read` when set. Task 10 saves a single-line field on blur and relies on this guard.

- [ ] **Step 1: Write the failing test** (import `SettingsError`, and add the test to the tuple in `main`, `:118`):

```python
async def test_a_read_failure_saves_nothing_from_a_focused_box():
    fake = FakeAdapter({"hindsight.paths": "~/dev"})
    app = SettingsApp(settings=[paths_setting], adapters={"tool": fake})
    async with app.run_test() as pilot:
        ed = app.query_one("#w-hindsight-paths", LinesEditor)
        ed.focus(); await pilot.press("end", "enter", "~", "/", "h", "a"); await pilot.pause()
        fake.fail = SettingsError("file broke"); app.refresh_values(); await pilot.pause()
        assert app.query("#error") and ed.disabled and fake.writes == [], fake.writes
        fake.fail = None; app.refresh_values(); await pilot.pause()
        assert ed.text == "~/dev\n~/ha" and not ed.disabled, "the typed lines are still there"
        ed.focus(); await pilot.press("tab"); await pilot.pause()
        assert fake.writes == [("hindsight.paths", "~/dev\n~/ha")]
```

- [ ] **Step 2: Run it.** `uv run --quiet --locked --project settings python settings/tests/test_tui_agents.py` fails on `fake.writes == []`, because disabling the focused box blurs it and the blur saves.
- [ ] **Step 3: Guard `commit`.** It returns at once when `self.error` is set. Every widget's write passes through `commit`, and `read_all` sets `self.error` before `show_state` disables anything, so the order of Textual's events does not matter.
- [ ] **Step 4: Run it again.** It ends with `ok`.
- [ ] **Step 5: `pnpm check`, then commit** "Write nothing from the terminal UI while a read error shows".

### Task 5: Open a jstack role whose line has a trailing space or an unknown effort

**Finding:** S3

**Files:**
- Modify: `settings/src/dotfiles_settings/adapters/tool.py:214` (`_read_jstack`)
- Modify: `settings/src/dotfiles_settings/tui_agents.py:86-96` (`SeatsEditor.seat_row`)
- Test: `settings/tests/test_tool.py` (`test_jstack_read`, `:273`; `test_parse_seats`, `:322`), `settings/tests/test_tui_agents.py`

- [ ] **Step 1: Write the failing tests.**
  - In `test_tool.py`, at the end of `test_jstack_read`, add `tracked.write_text(RULE.replace("bug-fix: opus", "bug-fix: opus medium \t"))` and `assert A.read(by_id("jstack.bug_fix")).value == "opus medium"`.
  - In `test_tool.py`, `test_parse_seats`, add `("arena runners", "fable medium,opus medium")` to the tuple of refused values (Review Focus 3).
  - In `test_tui_agents.py` (add it to the tuple in `main`):

```python
async def test_seats_editor_opens_what_it_cannot_parse():
    for role, value, effort in (("bug-fix", "opus fast", "fast"),
                                ("arena runners", "fable medium,opus medium", "medium,opus medium")):
        async with host(SeatsEditor(role, value, id="e")).run_test() as pilot:
            e = pilot.app.query_one("#e", SeatsEditor)
            assert e.value == value and e.query_one("#effort-0", Select).value == effort, "opening changes nothing"
```

- [ ] **Step 2: Run them.** `test_tool.py` fails on the read (`'opus medium \t'`). `test_tui_agents.py` fails with `InvalidSelectValueError: Illegal select value 'fast'`.
- [ ] **Step 3: Make both changes.** `_read_jstack` strips the value it returns. `seat_row` adds the seat's own effort to the effort options when it is not in `tool.EFFORTS`, as lines 88-90 already do for a model. A save from such a row still goes through `parse_seats`, which refuses it.
- [ ] **Step 4: Run them again.** Each ends with `ok`.
- [ ] **Step 5: `pnpm check`, then commit** "Open a jstack role whose line the seat editor cannot parse".

### Task 6: Exit 2 for a `--repo` that is not a repository name

**Finding:** S9

**Files:**
- Modify: `settings/src/dotfiles_settings/sync.py:9` (import), `:286` (`on`)
- Test: `settings/tests/test_sync.py:262-264`, `settings/tests/test_cli.py` (after `:160`)
- Modify: `settings/README.md:65`

The app maps exit 2 to `CommandError.invalid` at `app/Sources/RotmCore/CLI.swift:129`, pinned by `exitTwoIsInvalid` in `app/Tests/RotmCoreTests/CLITests.swift:53`. The app never passes `--repo`, and `AppState.swift:183` shows `.invalid` and `.readOnly` messages alike, so no Swift file changes.

- [ ] **Step 1: Write the failing tests.** In `test_cli.py`, with the fake mise of `:158` in place: `code, out, err = run("sync", "on", "--repo", "someone/else")` and `assert (code, out) == (2, "") and "--repo" in err`. In `test_sync.py` (import `InvalidValue`), the body of `test_on_refuses_a_name_that_is_not_a_repository_name` becomes:

```python
    fresh()
    try:
        sync.on("someone/else")
        raise AssertionError("no error")
    except InvalidValue as e:
        assert "--repo" in str(e) and calls() == []
```

- [ ] **Step 2: Run them.** `test_cli.py` fails with code 1. `test_sync.py` fails with an uncaught `SettingsError`.
- [ ] **Step 3: Raise `InvalidValue`** at `sync.py:286`, with the message unchanged.
- [ ] **Step 4: Run them again.** Each ends with `ok`.
- [ ] **Step 5: Edit `settings/README.md:65`.** The exit column reads "0, 1 when a step stops it, 2 for an unknown action or a `--repo` that is not a repository name".
- [ ] **Step 6: `pnpm check`, then commit** "Exit 2 for a sync repository name that is not one".

### Task 7: Say that the profile switched when its apply fails

**Finding:** S7

**Files:**
- Modify: `settings/src/dotfiles_settings/profile.py:130-131` (`use`)
- Test: `settings/tests/test_profile.py` (after `:95`)
- Modify: `settings/README.md:177`

- [ ] **Step 1: Write the failing test:**

```python
# an apply that fails after the switch says the switch happened, and what is left to run
def broken_apply():
    raise SettingsError("rotm-modules: broke")


sync.apply = broken_apply
rc.write_text('env = ["rotm-installed"]\n')
for needle in ("Now using the profile work.", "rotm-modules: broke", "rotm settings sync apply", "new shell"):
    raises(profile.use, SettingsError, needle, "work")
assert calls()[-1] == "mise -E rotm-installed,rotm-p-work bootstrap --save-env --only final-hook"
sync.apply = lambda: ["APPLIED"]
```

- [ ] **Step 2: Run it.** `mise exec python -- python3 settings/tests/test_profile.py` fails on the first needle, because the error is only "rotm-modules: broke".
- [ ] **Step 3: Catch the apply's `SettingsError` in `use`** and raise `SettingsError(f"{first line} Its settings were not applied: {e}. Run `rotm settings sync apply`, then open a new shell.")`, where the first line is the "Now using …" sentence `use` already builds. Exit stays 1. A failure before the switch (`_ensure`, the mise call, the env line) is unchanged.
- [ ] **Step 4: Run it again.** It ends with `ok`.
- [ ] **Step 5: Edit `settings/README.md:177`.** Add one sentence saying that when the apply fails after the switch, `profile use` exits 1 and its message says the profile is in use and names `sync apply`.
- [ ] **Step 6: `pnpm check`, then commit** "Say the profile switched when its apply fails".

### Task 8: Keep the Obsidian vault path on one Mac

**Finding:** S8

**Files:**
- Modify: `settings/registry.toml:66-77` (`apps.obsidian_vault`)
- Test: `settings/tests/test_registry.py:57`, `settings/tests/test_sync.py` (after `test_the_guards_cover_a_profiles_files`, `:547`)
- Modify: `docs/settings-sync.md:19`

`OBSIDIAN_VAULT` is read as a path with no expansion by `bin/obsidian-vault:23` and `bin/install-color-themes:63`, and `zsh/env.zsh:17` seeds it from `$HOME`. The seed already suits every Mac. Only a value the user set is an absolute path under one home, so that value stays in `config.local.toml`. The app's fixture row (`app/Tests/RotmTestSupport/Fixtures/list.json:79`) is hand-written and stays as it is.

- [ ] **Step 1: Write the failing tests.** In `test_registry.py`, add `"apps.obsidian_vault"` to the `machine` set. In `test_sync.py` (Review Focus 5):

```python
def test_a_vault_path_left_in_the_shared_file_names_the_set_that_moves_it():
    fresh()
    (sync.user_dir() / "config.override.toml").write_text('[env]\nOBSIDIAN_VAULT = "/Users/a/Notes"\n')
    assert "rotm settings set apps.obsidian_vault" in raises(sync.now) and "mise dot save" not in calls()
```

- [ ] **Step 2: Run them.** `test_registry.py` fails on the `machine` set. `test_sync.py` fails with "now did not raise".
- [ ] **Step 3: Add `scope = "machine"`** to the row, and end its `help` with "Kept on this Mac." The env adapter and `_guard` already handle a machine key (`env.py:110-113`, `sync.py:209-229`).
- [ ] **Step 4: Run them again.** Each ends with `ok`.
- [ ] **Step 5: Edit `docs/settings-sync.md:19`.** "The three settings" becomes four, with the Obsidian vault folder (`apps.obsidian_vault`) added.
- [ ] **Step 6: `pnpm check`, then commit** "Keep the Obsidian vault path out of sync".

### Task 9: Give a switch one meaning in the UI and in `macos-extras.sh`

**Finding:** S6

**Files:**
- Modify: `settings/src/dotfiles_settings/tui.py:203-205` (`on_switch_changed`)
- Modify: `setup/macos-extras.sh:38-40`, `:61-62`, `:115`, `:117`, `:130`, `:135`, `:143`, `:222`, `:229`, `:243`
- Test: `settings/tests/test_tui.py`, `setup/tests/macos-extras.sh` (after `:120`)
- Modify: `.claude/rules/macos-defaults.md:10-11`, `settings/README.md:194`, `setup/README.md:197` (says "empty means off for a group" for an export in `~/.zsh.local`)

**Tell the owner before starting this task.** It is not in the spec's decision list, but it changes a documented rule. Today any non-empty value turns a switch on, so `export DOTFILES_MACOS_FIREWALL=yes` in `~/.zsh.local` is on and `=0` is on too. After this task only `1` is on, so `yes` becomes off and `0` becomes off. The owner's Mac and the guests hold only `1` or the empty string (measured above), so nothing changes for them.

The install plan's Task 7 (`2026-11-14-audit-install-and-opt-outs.md`) adds three switches to the same script (`DOTFILES_MACOS_LOCALE`, `_POWER`, `_SPOTLIGHT_HOTKEYS`). If it has landed, they change here the same way, the count below is ten, not seven, and they join the test in Step 1. If it has not, that plan follows the form this task leaves.

A bool is on when its value equals `true_value` and off when empty (`registry.py:68`, `cli.py:19-24`, `settings/README.md:194`). `normalize` stores nothing else, so a `0` or `true` only arrives from `mise set` or `~/.zsh.local`. The UI shows such a value as off. The script must agree, most of all for `DOTFILES_MACOS_DISABLE_TIME_MACHINE`, where "on" stops backups.

- [ ] **Step 1: Write the failing tests.** In `test_tui.py`, after the Ctrl+R block (`:91`):

```python
        fake.overrides["T_FLAG"] = "1"; app.refresh_values(); await pilot.pause()
        fake.overrides["T_FLAG"] = "0"; app.refresh_values(); await pilot.pause()
        assert app.query_one("#w-t-flag", Switch).value is False and fake.writes == [("T_FLAG", "1")], \
            "a value stored elsewhere is shown, never rewritten"
        fake.overrides.pop("T_FLAG"); app.refresh_values(); await pilot.pause()
```

In `setup/tests/macos-extras.sh`:

```bash
DOTFILES_MACOS_FIREWALL=0 DOTFILES_MACOS_DISABLE_TIME_MACHINE=0 DOTFILES_MACOS_HIDPI=true DOTFILES_MACOS_SCREENSHOTS=0 run
check "a switch that is not 1 is off, as the settings UI shows it" "! grep -q 'socketfilterfw --set\|tmutil\|windowserver\|com.apple.screencapture' '$log'"
```

- [ ] **Step 2: Run them.** `test_tui.py` fails on the writes, which gain `("T_FLAG", "")`. `bash setup/tests/macos-extras.sh` prints `FAIL a switch that is not 1 is off, as the settings UI shows it`.
- [ ] **Step 3: Change `on_switch_changed`.** It commits only when `event.value` differs from `self.values[s.id].value == s.true_value`, which is what the stored value shows as. A redraw never differs, and a user's flip always does.
- [ ] **Step 4: Change the script.** Each of the seven switches is on when its value is exactly `1`. The four group tests become `[ "${VAR-1}" = 1 ]`, and the `hidpi`, `firewall` and `disable_tm` tests become `[ "$x" = 1 ]`. The flags still set `1`. Unset still means on for the six default-on switches. Update the header (`:38-40`) and the comment at `:115` to say "on when unset or `1`".
- [ ] **Step 5: Run them again.** `test_tui.py` ends with `ok`, and the script's self-check prints no `FAIL`.
- [ ] **Step 6: Edit the docs.** In `.claude/rules/macos-defaults.md:10-11`, replace "on unless set to the empty string" with "on when unset or `1`" in both sentences, keeping the note that the settings UI writes `""` for off. In `settings/README.md:194`, add that `setup/macos-extras.sh` reads its switches the same way, so any other value is off in both. In `setup/README.md:197`, "empty means off for a group" becomes "`1` or unset is on, and anything else is off".
- [ ] **Step 7: `pnpm check`, then commit** "Read a switch as on only when it holds its on value". Not run on the host, where `set-defaults` is never run. The stubbed self-check is the proof, and no VM row is needed because this Mac and the guests store only `1` or the empty string.

### Task 10: Keep a typed edit, and save a field on Tab

**Finding:** S10 (the focused box that is overwritten, and the single-line field that keeps an unsaved edit)

**Files:**
- Modify: `settings/src/dotfiles_settings/tui.py:133-163` (`redraw`, `refresh_values`), `:212-215`
- Test: `settings/tests/test_tui.py`, `settings/tests/test_tui_agents.py:78-81`
- Modify: `settings/README.md:9`

**Interfaces:**
- Consumes: Task 4's guard in `commit`, so a blur caused by the error banner saves nothing.
- Produces: `redraw(self, s: Setting, was: Value | None = None)`. `was` is the value held before this refresh. `refresh_values` passes it for every changed row except `force`.

- [ ] **Step 1: Write the failing tests.** In `test_tui.py`, after the block Task 3 added:

```python
        app.query_one("#w-t-name", Input).focus()
        await pilot.press("end", "X", "tab"); await pilot.pause()
        assert fake.overrides["T_NAME"] == "seededX", "Tab saves a single-line field, as it saves a lines box"
        app.query_one("#w-t-name", Input).focus()
        await pilot.press("end", "Y"); await pilot.pause()
        fake.overrides["T_NAME"] = "elsewhere"; app.refresh_values(); await pilot.pause()
        assert app.query_one("#w-t-name", Input).value == "seededXY", "a change on disk does not replace a typed edit"
        assert any("changed elsewhere" in str(n.message) for n in app._notifications)
        await pilot.press("enter"); await pilot.pause()
        assert fake.overrides["T_NAME"] == "seededXY"
        fake.overrides.pop("T_NAME"); app.refresh_values(); await pilot.pause()
        assert app.query_one("#w-t-name", Input).value == "seeded", "a box with no edit follows the disk"
```

In `test_tui_agents.py`, `test_lines_editor_saves_on_blur` asserts today that a focused box holding a typed `p` is overwritten (`:80-81`). Replace those two lines. First, with focus away from the box, a disk change to `~/work` redraws it and writes nothing. Then focus it, type `p`, change the disk to `~/other` and call `app.refresh_values()`. The text still ends in `p` and `len(fake.writes) == 1`. Then Tab writes `("hindsight.paths", "~/workp")`.

- [ ] **Step 2: Run them.** `test_tui.py` fails on `fake.overrides["T_NAME"]` (a `KeyError`, since Tab saved nothing). `test_tui_agents.py` fails on the kept `p`.
- [ ] **Step 3: Change `redraw` and `refresh_values`.** When `was` is given and the widget is the focused `Input` or `LinesEditor` and its `value` differs from `was.value or ""`, the text is left alone and one notice says `f"{s.label} changed elsewhere. Your edit is kept, and saving it replaces that change."` The marker and the Reset button update either way. A forced redraw (after a refused write or a reset) passes no `was` and replaces the text, as today.
- [ ] **Step 4: Add `on_input_blurred(self, event: Input.Blurred)`,** which does what `on_input_submitted` does.
- [ ] **Step 5: Run them again.** Each ends with `ok`.
- [ ] **Step 6: Edit `settings/README.md:9`.** Add that Enter or Tab saves a field, and that a field being edited keeps its text when the setting changes elsewhere.
- [ ] **Step 7: `pnpm check`, then commit** "Keep a typed edit in the terminal UI and save a field on Tab".

### Task 11: Reset from inside a seat picker and keep a refusal on screen

**Finding:** S10 (Ctrl+R inside a seat picker, and the 5-second explanation)

**Files:**
- Modify: `settings/src/dotfiles_settings/tui.py:179`, `:193` (the two error notices), `:200-201` (`setting_of`)
- Test: `settings/tests/test_tui.py:107`, `settings/tests/test_tui_agents.py`

**Interfaces:**
- Produces: `tui.ERROR_SECONDS = 20`. In `test_tui_agents.py`, `FakeAdapter.source` (default `Source.SEED`, used by `read`) and `FakeAdapter.resets: list[str]`, appended to by `reset`.

- [ ] **Step 1: Write the failing tests.** In `test_tui.py:107`, the refused-value assertion also requires `n.timeout == 20`. In `test_tui_agents.py` (add to the tuple in `main`):

```python
async def test_ctrl_r_resets_from_inside_a_seat_picker():
    fake = FakeAdapter({"jstack.bug_fix": "opus high"}); fake.source = Source.OVERRIDE
    app = SettingsApp(settings=[bug_fix_setting], adapters={"tool": fake})
    async with app.run_test() as pilot:
        app.query_one("#w-jstack-bug_fix #model-0").focus(); await pilot.pause()
        await pilot.press("ctrl+r"); await pilot.pause()
        assert fake.resets == ["jstack.bug_fix"]
```

- [ ] **Step 2: Run them.** `test_tui.py` fails on the timeout (5). `test_tui_agents.py` fails with `fake.resets == []`.
- [ ] **Step 3: Make both changes.** `setting_of` returns the setting of the widget or of its nearest ancestor that has one (`w.ancestors_with_self`). The nested selects and buttons of a `SeatsEditor` stop their own events, so only `action_reset` gains a new path. The two `self.notify(str(e), severity="error")` calls pass `timeout=ERROR_SECONDS`.
- [ ] **Step 4: Run them again.** Each ends with `ok`.
- [ ] **Step 5: `pnpm check`, then commit** "Reset a jstack role from inside its seat picker".

### Task 12: Watch the macOS preference files

**Finding:** S11

**Files:**
- Modify: `settings/src/dotfiles_settings/adapters/macos_default.py:242` (`MacosDefaultAdapter`)
- Modify: `settings/src/dotfiles_settings/tui.py:158-169` (`refresh_values`, `poll`)
- Test: `settings/tests/test_macos_default.py` (profile section, after `:308`, and before the last line), `settings/tests/test_tui.py`

**Interfaces:**
- Consumes: `FakeAdapter.reads` from Task 3.
- Produces: `MacosDefaultAdapter.watch_paths(self) -> list[Path]`, returning `[fragment_path(), override_path(), profile.miserc()]` plus the active profile's override file, in that order.

The env adapter already watches the override files, so a change there redraws the macOS rows today. The tracked fragment is the file nothing watches, and it is where a clone's writes go. Each macOS row's read runs `mise bootstrap macos defaults status`, so a refresh is slow, and a watched file that the UI itself wrote would be read twice. The second step stops that.

- [ ] **Step 1: Write the failing tests.** In `test_macos_default.py`, once the work profile is active, add `assert adapter.watch_paths() == [fragment_path(), override, profile.miserc(), work]`. After the final `profile.miserc().unlink()`, add `assert adapter.watch_paths() == [fragment_path(), override, profile.miserc()]`. In `test_tui.py`, make `FakeAdapter.write` call `self.touch()`, as a real write changes a watched file, and after the first write (`:84`):

```python
        seen = fake.reads; app.poll()
        assert fake.reads == seen, "the UI's own write is read once"
```

- [ ] **Step 2: Run them.** `test_macos_default.py` fails with `AttributeError: … no attribute 'watch_paths'`. `test_tui.py` fails on the read count.
- [ ] **Step 3: Add `watch_paths`** as Interfaces says.
- [ ] **Step 4: Move the snapshot.** `refresh_values` sets `self.mtimes = self.watched()` before it reads, and `poll` only compares and calls it. Taken before the read, a change that lands during the read is still seen by the next poll.
- [ ] **Step 5: Run them again.** Each ends with `ok`.
- [ ] **Step 6: `pnpm check`, then commit** "Refresh macOS rows when another front end changes them".

## Findings the code contradicts

None. S11 is narrower than written, because the override files were already watched through the env adapter, and only the tracked fragment was not.
