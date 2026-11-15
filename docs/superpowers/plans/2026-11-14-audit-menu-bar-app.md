# Audit fixes for the menu bar app, Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix the nine menu bar app findings of the 2026-11-14 audit (M1 to M9) and put the app's one window-focus test into the gate (G8), so the app never runs two commands at once, never offers an update it cannot install, and says what an Apply will change.

**Architecture:** Every fix stays inside the Swift package in `app/`. `RotmCore` (`AppState`, `SettingsModel`, `AppUpdate`, `AnsiParser`) takes the logic and its tests. The AppKit and SwiftUI shell (`StatusItemController`, `SettingsView`, `SettingRowView`, `ReviewSheet`) only calls it. No Python, bash or JSON contract changes.

**Tech Stack:** Swift 5.9 tools, macOS 14+, AppKit, SwiftUI, Observation, Swift Testing, `FakeRunner` and its `hold` from `app/Tests/RotmTestSupport`. mise 2026.11.8 for the one read-only `status --json` call Task 2 adds.

**Spec:** `docs/superpowers/specs/2026-11-14-project-audit.md`, section "M. Menu bar app" and row G8. Read its Goal first. The app's design is the P5 plan, `docs/superpowers/plans/2026-11-13-p5-menu-bar-app.md`.

The fixes ship with the next app release (the `app/VERSION` bump, the tag and the cask), which is the owner's call and is not part of this plan.

## Global Constraints

- The gate is `pnpm check`. Every task ends with it passing, and it runs before every commit.
- Commit subjects are short, imperative, sentence case, with no conventional-commit prefix. One commit per task, with the subject the task names.
- A change to setup behaviour, the package list or mise tools carries its doc edit in the same commit (CLAUDE.md, "Docs mirror behavior"). Here that means `docs/menu-bar.md` whenever a task changes what that page states.
- Never run on this Mac: `sysup`, `./setup.sh`, `set-defaults`, `rotm install`, `rotm update`, `hindsight-memory init`, `hindsight-memory upgrade`, `hindsight-memory uninstall`, `rotm settings sync …`, or the built app. Swift tests use `FakeRunner` or a temp script.
- Never touch github.com/jrmatherly/rotm-settings.
- Pushing a tag, closing a PR and running a GitHub workflow are the owner's and need their word.
- The app adds no logic (P5 plan). A value the app needs comes from a command's output and is never computed in Swift.
- Do not edit `CLAUDE.md`. It is 11,995 bytes against a cap of 12,000.
- Swift style: two-space indent, no comment that restates the code.
- Run one suite with the lines below. `bin/lib/check:96-100` exports the same variable, and only when `xcode-select -p` is the Command Line Tools:

```bash
xcode=/Applications/Xcode.app/Contents/Developer
developer=${DEVELOPER_DIR:-$(xcode-select -p 2> /dev/null || true)}
if [[ -z $developer || $developer == */CommandLineTools ]] && [ -d "$xcode" ]; then
  export DEVELOPER_DIR=$xcode
  developer=$xcode
fi
```

  Every "Run" line in this plan assumes `export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer` in the same shell.

- `bin/lib/app-shots` writes 12 PNGs to `.shots/` (git-ignored). A task that names an image regenerates it and reads it with the Read tool before the commit.

## Decided while writing this plan

Each is a default the owner can change before the task starts.

- **M1. An action waits for the refresh in flight.** The other design was a `refreshing` flag folded into `blocked`. The menu asks for a refresh every time it opens (`StatusItemController.swift:51-54`), so that flag would grey every action for about a second on each open and for the length of a `git fetch` once an hour. Under the chosen design the menu looks as it does today. An action chosen while a refresh runs marks itself busy at once, and its command starts when the refresh ends. The confirmation alert usually outlasts the status read, so the wait is seldom seen. The console window for Update opens after the wait, not before.
- **M2. The signal is `mise bootstrap packages status --json`.** No new CLI field. The app asks mise only when the tap holds a newer version, at most once a day. The app offers its update only when the row for its cask has `"state": "installed"`. A copy from the DMG, or any copy with the `menubar` module off, is then offered no update and shows no dot. It is also told nothing about a new release. A line that sends such a user to the releases page would be a new feature and is not planned.
- **M3. Ask before the update, not after it.** The update's confirmation names the staged edits it will discard, and the relaunch then quits without a second question. Edits staged while mise runs are discarded with no question.
- **M5. No Python change.** With "Write to shared settings" ticked, the app stops comparing an edit with the shown value and offers Reset on every writable row. It leaves three things imperfect. An edit equal to the shared layer's own value is staged and runs a command that changes nothing. Changing a control back does not drop the edit, so the user chooses Undo. Reset on a row whose shared layer holds no value runs a command that changes nothing (not checked for every adapter, and `settings/tests/test_cli.py` has no case for it).
- **M8. `applyStaged()` stops reloading.** The window already reloads when `blocked` clears. Apply ends about one `list --json` (3.5 s measured by the audit) sooner, and the rows refresh about one status read later than before. The reload on window focus stays. It is how the window sees a change made in a terminal, and the P5 plan's Review Focus 2 depends on it.

## Measured for this plan (2026-11-14, this Mac, mise 2026.11.8)

| Fact | How |
| --- | --- |
| An action starts while `update --check` is held | The test in Task 1 Step 1, run in a scratch copy of the package, failed at its `!runner.calls.contains(sync)` line after about 15 s |
| The Task 1 change passes the whole suite but one test | Scratch copy with the Task 1 and Task 6 changes: 89 tests, one failure, `applyRunsEveryEditPastAFailureThenReloads` at `SettingsModelTests.swift:89` |
| After the Task 6 change one Apply is `set`, `status`, `list` | Scratch copy, the window test in Task 6 Step 1 |
| A cask mise installed has `"state":"installed","managed_by":"mise"` | `mise bootstrap packages status --json`, the `jrmatherly/tap/claude-multipass-app` row under `"brew-cask"` → `"packages"` |
| A declared cask with nothing in the Caskroom has `"state":"missing","installed_version":""` | Same output, the `jrmatherly/tap/returnofthemac-app` row. This Mac has no Caskroom entry for it, which is what a DMG copy looks like to mise |
| A cask no config declares has no row | `MISE_CONFIG_DIR` pointed at an empty config: the output is `{}` |
| `status --json` takes about 1.9 s | `time`, one sample |
| The focus test fails without the line it guards | Scratch copy with `SettingsWindow.swift:34` removed: `Expectation failed: !(controller.window.firstResponder is NSText)` |
| Opening the settings window in a test does not take focus | `lsappinfo front` sampled every 0.15 s through `Shots/settings` and `Shots/noFieldTakesFocusOnOpen`: the front app never changed |
| The new escape patterns strip the four shapes and keep the old cases | A scratch script over `NSRegularExpression` with the patterns in Task 4 |

## Review Focus

1. **The refresh in flight fails.** `update --check` exits non-zero while an action waits on it. The action must still run. Test in Task 1.
2. **Quit while an action waits on a refresh.** The user must be asked, as for any running command. Test in Task 1.
3. **mise is missing or prints something that is not JSON.** The app offers no update and says nothing. Test in Task 2.
4. **Two different failures in a row.** Dropping repeats must not hide a second failure with other words. Test in Task 3.
5. **A new-shape escape sequence split across two writes.** It must be held back and dropped whole, as the old shapes are. Test in Task 4.

---

### Task 1: An action waits for the refresh in flight

**Finding:** M1

**Files:**
- Modify: `app/Sources/RotmCore/AppState.swift:45-48` (`refresh`), `:90-93` (`upgradeApp`), `:138-144` (`exclusive`), `:146-160` (`perform`)
- Modify: `app/Sources/ReturnOfTheMac/StatusItemController.swift:144-159` (`runConsole`)
- Test: `app/Tests/RotmCoreTests/AppStateTests.swift`

**Interfaces:**
- Produces: `public func settled() async` on `AppState`. It returns when no refresh is in flight. `blocked` keeps its meaning.

- [ ] **Step 1: Write the failing tests** in `AppStateTests`, in the style of `useProfileRunsOneCommandThenRefreshes` (`:83`).

```swift
@Test func anActionWaitsForTheRefreshInFlight() async {
  let runner = FakeRunner()
  stubClean(runner)
  let sync = ["settings", "sync", "now"]
  runner.stub(sync, .success(CommandOutput(stdout: "", stderr: "")))
  let release = runner.hold(checkArgs)
  let state = makeState(runner)
  let refresh = Task { await state.refresh() }
  await waitUntil { runner.calls.contains(checkArgs) }
  #expect(!state.blocked)
  let action = Task { await state.syncNow() }
  await waitUntil { state.busy != nil }
  try? await Task.sleep(nanoseconds: 50_000_000)
  #expect(!runner.calls.contains(sync))
  #expect(state.quitDecision(sessionTitle: nil, stagedEdits: 0) == .ask(message: "Quit while a command is running?", detail: "Syncing…"))
  release()
  await refresh.value
  await action.value
  #expect(runner.calls == [statusArgs, checkArgs, sync, statusArgs])
}
```

  `aFailedRefreshInFlightStillLetsTheActionRun`: the same shape with `checkArgs` stubbed `.failure(.failed(1, "no network"))` before the hold. After `release()` the calls are the same four and `state.lastError == nil`.

  `exclusiveWorkWaitsForTheRefreshInFlight`: open as the first test does (hold `checkArgs`, start the refresh, wait for the call), start `state.exclusive("Applying settings…") { ran = true }` in a `Task`, wait for `state.busy != nil`, sleep 50 ms, expect `ran == false`, release, await, expect `ran == true`.

  `aSecondRefreshJoinsTheOneInFlight`: hold `statusArgs`, start two `refresh()` tasks, wait for one `statusArgs` call, sleep 50 ms, release, await both. `runner.calls.filter { $0 == statusArgs }.count == 1`.

- [ ] **Step 2: Run them.** `swift test --package-path app --filter AppStateTests`. Expected: the first three fail at the line after the sleep (the first takes about 15 s to fail, because `busy` has already cleared), and the fourth fails with a count of 2.

- [ ] **Step 3: Implement.** `AppState` gains `private var reading: Task<Void, Never>?`. `perform` and `exclusive` call `await settled()` on the line after `busy = label`. `upgradeApp` calls it on the line after `upgrading = true`. `refresh` and `settled` are:

```swift
public func refresh(recheckUpdates: Bool = false) async {
  guard !blocked else { return }
  if let inFlight = reading {
    await inFlight.value
    guard recheckUpdates, !blocked else { return }
  }
  let task = Task { await self.read(recheckUpdates: recheckUpdates) }
  reading = task
  await task.value
  if reading == task { reading = nil }
}

public func settled() async { await reading?.value }
```

  In `runConsole`, keep both `!state.blocked` guards and the alert. After them set `state.sessionRunning = true`, then build the session and call `console.run` inside `Task { await state.settled(); … }`.

- [ ] **Step 4: Run.** `swift test --package-path app --filter AppStateTests`. Expected: every test passes. Then `swift test --package-path app` passes.

- [ ] **Step 5: Commit.** No image shows the menu, and the menu's entries do not change (`MenuBuilderTests` is untouched and passes).

```bash
git add app/Sources/RotmCore/AppState.swift app/Sources/ReturnOfTheMac/StatusItemController.swift app/Tests/RotmCoreTests/AppStateTests.swift
git commit -m "Hold an action until the refresh in flight ends"
```

---

### Task 2: Offer the app's update only for a cask mise installed

**Finding:** M2

**Files:**
- Modify: `app/Sources/RotmCore/AppUpdate.swift`
- Modify: `app/Sources/RotmCore/AppState.swift:81-87` (`checkAppUpdate`)
- Modify: `app/Sources/ReturnOfTheMac/StatusItemController.swift:56-61` (`refresh`)
- Modify: `docs/menu-bar.md:80` and `:106`
- Test: `app/Tests/RotmCoreTests/AppUpdateTests.swift`, `app/Tests/ReturnOfTheMacTests/MenuBuilderTests.swift:141`

**Interfaces:**
- Produces: `AppUpdate.statusArguments = ["bootstrap", "packages", "status", "--json"]`.
- Produces: `AppUpdate.caskInstalled(inStatus json: String) -> Bool`. True when `json["brew-cask"]["packages"]` holds a row whose `package` is `jrmatherly/tap/returnofthemac-app` and whose `state` is `installed`. False for anything else, text that is not JSON included.
- Changes: `AppState.checkAppUpdate(fetch:current:installed:)`, where `installed: () async -> Bool` is required and is called only when the tap's version is newer than `current`. When it returns false, `appUpdate` is nil.

- [ ] **Step 1: Write the failing tests** in `AppUpdateTests`. `caskInstalledReadsMisesStatus` with four inputs, the first two cut from the measured output:

```swift
private let caskRow = #"{"brew-cask":{"available":true,"packages":[{"package":"jrmatherly/tap/returnofthemac-app","requested_version":"latest","desired_state":"present","state":"STATE","installed_version":"0.1.2","managed_by":"mise"}]}}"#

#expect(AppUpdate.caskInstalled(inStatus: caskRow.replacingOccurrences(of: "STATE", with: "installed")))
#expect(!AppUpdate.caskInstalled(inStatus: caskRow.replacingOccurrences(of: "STATE", with: "missing")))
#expect(!AppUpdate.caskInstalled(inStatus: "{}"))
#expect(!AppUpdate.caskInstalled(inStatus: "mise ERROR no config"))
```

  `aCopyMiseDidNotInstallIsOfferedNothing`: `checkAppUpdate(fetch: { _ in "  version \"0.2.0\"\n" }, current: "0.1.0", installed: { false })` leaves `state.appUpdate == nil` and `state.needsAttention == false` (stub the clean status and a `behind: 0` check first, as `needsAttention` at `AppStateTests.swift:220` does).

  `theSameVersionDoesNotAskMise`: with the cask at `0.1.0` and `current: "0.1.0"`, an `installed` closure that records its call is never called.

  Give every existing `checkAppUpdate` call `installed: { true }` (eight in `AppUpdateTests.swift`, one at `MenuBuilderTests.swift:141`).

- [ ] **Step 2: Run.** `swift test --package-path app --filter AppUpdateTests`. Expected: a compile error, `extra argument 'installed' in call`.

- [ ] **Step 3: Implement** the three interfaces. `caskInstalled` uses `JSONSerialization`, since the shape belongs to mise and only one field is read. In `StatusItemController.refresh`, `installed` runs `CLI(tool: home.appendingPathComponent(".local/bin/mise"), home: home).run(AppUpdate.statusArguments)` and returns `AppUpdate.caskInstalled(inStatus:)` of its stdout, or false when the call throws.

- [ ] **Step 4: Run.** `swift test --package-path app --filter "AppUpdateTests|MenuBuilderTests"`. Expected: pass.

- [ ] **Step 5: Edit `docs/menu-bar.md`.** At `:80`, after "compares the version there with its own", say that when the tap has a newer one the app asks mise (`mise bootstrap packages status --json`) whether mise installed its cask, and offers the update only then, so a copy opened from the DMG is offered none. At `:106`, replace "by `sysup` or by its own menu line" with wording that says the menu line no longer appears.

- [ ] **Step 6: Not run on the host.** The proof that the menu line and the dot are absent needs an installed guest. It is one step for the "Update the setup and the app" section of `docs/superpowers/specs/2026-11-14-p5-vm-proof/RUNBOOK.md`, written by the session that runs the next app release: set `modules.menubar` off, wait for the tap to hold a newer version, open the menu, and record that it has no "Update Return of the Mac" line.

- [ ] **Step 7: Commit.** No image shows the menu.

```bash
git add app/Sources/RotmCore/AppUpdate.swift app/Sources/RotmCore/AppState.swift app/Sources/ReturnOfTheMac/StatusItemController.swift app/Tests/RotmCoreTests/AppUpdateTests.swift app/Tests/ReturnOfTheMacTests/MenuBuilderTests.swift docs/menu-bar.md
git commit -m "Offer the app's update only for a cask mise installed"
```

---

### Task 3: Show each note and failure once

**Finding:** M4

**Files:**
- Modify: `app/Sources/RotmCore/SettingsModel.swift:72`, `:102`, `:104`
- Test: `app/Tests/RotmCoreTests/SettingsModelTests.swift`

- [ ] **Step 1: Write the failing tests.** In `aFailedLoadKeepsTheRowsAndSaysWhy` (`:127`), call `await model.load()` three times in place of once. The expectations stay. Then stub `listArgs` with `.failure(.timedOut)`, load once more, and expect `model.failures == ["settings list: uv: not found", "settings list: rotm did not finish in time."]`.

  New, `theSameNoteIsShownOnce`: stage `jstack.feature_refactoring` to `sonnet high` and `jstack.arena_runners` to `opus high, opus high`, stub both `set` commands with `ok("", note)` where `note` is `"Edited tilde/.claude/rules/jstack-models.md, a tracked file. Commit it to keep the change."`, apply, and expect `model.notes == [note]`.

- [ ] **Step 2: Run.** `swift test --package-path app --filter SettingsModelTests`. Expected: the first fails with three equal failures, the second with two equal notes.

- [ ] **Step 3: Implement.** The three `append` calls add a text only when the list does not already hold it. That also makes the `ForEach(…, id: \.self)` ids at `SettingsView.swift:59-60` unique.

- [ ] **Step 4: Run** the same filter. Expected: pass.

- [ ] **Step 5: Commit.** No image shows the result list. The model tests are the proof.

```bash
git add app/Sources/RotmCore/SettingsModel.swift app/Tests/RotmCoreTests/SettingsModelTests.swift
git commit -m "Show a repeated note or failure once"
```

---

### Task 4: Strip the escape sequences the console let through

**Finding:** M7

**Files:**
- Modify: `app/Sources/RotmCore/Ansi.swift:50-51` (`escape`), `:70` (the SGR test)
- Modify: `app/Sources/RotmCore/ConsoleSession.swift:62` (`partialEscape`)
- Test: `app/Tests/RotmCoreTests/AnsiTests.swift`, `app/Tests/RotmCoreTests/ConsoleSessionTests.swift`

- [ ] **Step 1: Write the failing tests.** In `AnsiParserTests`:

```swift
@Test func colonPrivateAndIntermediateSequencesAreStrippedUnstyled() {
  var parser = AnsiParser()
  #expect(parser.parse("a\(esc)[38:2:255:0:0mb\(esc)7c\(esc)8d\(esc)[ qe") == [run("abcde")])
  // Read as SGR, >4;2 would reset the style.
  #expect(parser.parse("\(esc)[1mf\(esc)[>4;2mg") == [run("fg", bold: true)])
}
```

  In `ConsoleSessionTests`, after `aCharacterOrAnEscapeSplitAcrossWritesArrivesWhole` (`:148`), `aColonSequenceSplitAcrossWritesIsDropped`: the script is `printf '\033[38:2:255'; sleep 0.3; printf ':0:0mred\n'` and `s.text == "red\n"`.

- [ ] **Step 2: Run.** `swift test --package-path app --filter "AnsiParserTests|ConsoleSessionTests"`. Expected: both new tests fail with the escape bytes in the text.

- [ ] **Step 3: Implement.** The CSI branch of `escape` becomes `\\[[0-?]*[ -/]*[@-~]` (ECMA-48 parameter, intermediate and final bytes) and its last branch becomes `[78=>]`. `partialEscape`'s CSI branch becomes `\\[[0-?]*[ -/]*`. At `Ansi.swift:70`, call `apply` only when every parameter character is a digit or `;`. A colon colour is dropped, not read.

- [ ] **Step 4: Run** the same filter. Expected: pass, `otherSequencesAreStripped` included.

- [ ] **Step 5: Regenerate and read** `.shots/console-running-light.png` and `.shots/console-running-dark.png` with `bin/lib/app-shots`. The ticks, the warning and the five rows of art keep their colours.

- [ ] **Step 6: Commit.**

```bash
git add app/Sources/RotmCore/Ansi.swift app/Sources/RotmCore/ConsoleSession.swift app/Tests/RotmCoreTests/AnsiTests.swift app/Tests/RotmCoreTests/ConsoleSessionTests.swift
git commit -m "Strip colon, private and intermediate escape sequences from the console"
```

---

### Task 5: Run the window-focus test in the gate

**Finding:** G8

**Files:**
- Create: `app/Tests/ReturnOfTheMacTests/SettingsWindowTests.swift`
- Modify: `app/Tests/ReturnOfTheMacTests/ShotsTests.swift:16`, `:28`, `:107-110`, `:159-166`

**Interfaces:**
- Produces: the suite `SettingsWindowTests` (`@Suite(.serialized) @MainActor`, with `init() { _ = NSApplication.shared }`), which runs with no environment variable. `bin/lib/app-shots` filters on `Shots`, which does not match it.
- Produces: `fixtureState()` and `settingsWindow(section:)` in `ShotsTests.swift` without `private`, for this suite and Task 6.

- [ ] **Step 1: See the gap.** `swift test --package-path app --filter noFieldTakesFocusOnOpen`. Expected: `➜ Test noFieldTakesFocusOnOpen() skipped.`

- [ ] **Step 2: Move the test.** `noFieldTakesFocusOnOpen` and `editableFields(in:)` move to the new file unchanged. Drop `private` from the two helpers.

- [ ] **Step 3: Run.** The same command. Expected: `✔ Test noFieldTakesFocusOnOpen() passed`.

- [ ] **Step 4: Prove it can fail.** Comment out `window.makeFirstResponder(nil)` at `app/Sources/ReturnOfTheMac/SettingsWindow.swift:34` and run again. Expected: `Expectation failed: !(controller.window.firstResponder is NSText)`. Restore the line.

- [ ] **Step 5: Run `bin/lib/app-shots`.** Expected: `app-shots: wrote 12 images`. Read `.shots/settings-setup-light.png` to confirm the helpers still build the window.

- [ ] **Step 6: Commit.** The `check` workflow runs on `macos-26` and will run this test for the first time. After the push, read the run with `gh run list --workflow check.yml --limit 1`. If the runner cannot open a window, tell the owner and do not add a skip.

```bash
git add app/Tests/ReturnOfTheMacTests/SettingsWindowTests.swift app/Tests/ReturnOfTheMacTests/ShotsTests.swift
git commit -m "Run the settings window's focus test in the gate"
```

---

### Task 6: List the settings once per Apply, and test an edit staged during it

**Finding:** M8, M9

**Files:**
- Modify: `app/Sources/RotmCore/SettingsModel.swift:105-109` (`applyStaged`)
- Modify: `docs/menu-bar.md:66` only if its sentence stops being true (it says the window reads the settings "after every command the app runs", which holds)
- Test: `app/Tests/RotmCoreTests/SettingsModelTests.swift:77-93`, `app/Tests/ReturnOfTheMacTests/SettingsWindowTests.swift`

**Interfaces:**
- Consumes: `SettingsWindowTests` and `fixtureState()` from Task 5.
- Changes: `SettingsModel.applyStaged()` no longer calls `load()`. `SettingsWindowController.watchActions` (`SettingsWindow.swift:45-55`) is the one reload after an Apply.

- [ ] **Step 1: Write the tests.** In `SettingsWindowTests`:

```swift
@Test func applyListsTheSettingsOnce() async throws {
  let (state, runner) = await fixtureState()
  let controller = SettingsWindowController(state: state, runner: runner)
  await controller.model.load()
  controller.show()
  try await Task.sleep(nanoseconds: 500_000_000)
  let set = ["settings", "set", "updates.slow_step_seconds", "--", "20"]
  runner.stub(set, .success(CommandOutput(stdout: "", stderr: "")))
  controller.model.stage("updates.slow_step_seconds", value: "20", shared: false)
  let before = runner.calls.count
  await state.exclusive("Applying settings…") { await controller.model.applyStaged() }
  try await Task.sleep(nanoseconds: 500_000_000)
  #expect(Array(runner.calls.dropFirst(before)) == [set, ["settings", "status", "--json"], ["settings", "list", "--json"]])
  controller.window.close()
}
```

  In `SettingsModelTests`, rename `applyRunsEveryEditPastAFailureThenReloads` (`:77`) to `applyRunsEveryEditPastAFailure` and change `:89` to `#expect(runner.calls == [listArgs, first, second, third])`. Lines `:90-92` stay.

  New, for M9, `anEditStagedDuringApplyWinsOverTheFailedOne`: stage `updates.slow_step_seconds` to `20`, stub its `set` with `.failure(.failed(1, "disk full"))`, `hold` it, start `applyStaged()` in a `Task`, `waitUntil` the `set` call is recorded, stage the same setting to `30`, release, await. Expect `model.staged == [Edit(settingId: "updates.slow_step_seconds", change: .set("30"), shared: false)]` and `model.failures == ["updates.slow_step_seconds: disk full"]`.

- [ ] **Step 2: Run.** `swift test --package-path app --filter "SettingsModelTests|SettingsWindowTests"`. Expected: `applyListsTheSettingsOnce` fails with a `list` call between the `set` and the `status` (read from the code, not run), `applyRunsEveryEditPastAFailure` fails with a trailing `listArgs`, and the M9 test passes, since it covers code that already works.

- [ ] **Step 3: Prove the M9 test can fail.** Replace the condition at `SettingsModel.swift:106` with `true` and run it. Expected: `staged` holds both the `30` and the `20` edit. Restore the line.

- [ ] **Step 4: Implement.** Delete `await load()` at `SettingsModel.swift:109`. The comment at `:105` now says the window's reload drops the edit if it took after all.

- [ ] **Step 5: Run** the same filter, then `swift test --package-path app`. Expected: pass.

- [ ] **Step 6: Commit.** Nothing the user sees changes but the timing, so no image is regenerated.

```bash
git add app/Sources/RotmCore/SettingsModel.swift app/Tests/RotmCoreTests/SettingsModelTests.swift app/Tests/ReturnOfTheMacTests/SettingsWindowTests.swift
git commit -m "List the settings once after an Apply"
```

---

### Task 7: Keep a shared edit that equals the shown value

**Finding:** M5

**Files:**
- Modify: `app/Sources/RotmCore/SettingsModel.swift:123-131` (`differs`)
- Modify: `app/Sources/ReturnOfTheMac/SettingRowView.swift:72`
- Modify: `docs/menu-bar.md:64`
- Test: `app/Tests/RotmCoreTests/SettingsModelTests.swift`

**Interfaces:**
- Produces: `public static func canReset(_ row: SettingRow, shared: Bool) -> Bool` on `SettingsModel`. True for a writable row when `shared` is true or `row.source == "override"`.
- Changes: `differs` returns true for any edit with `shared == true` on a writable row that exists.

- [ ] **Step 1: Write the failing test.** The fixture's `updates.slow_step_seconds` is `10` from `default`, `apps.obsidian_vault` is from `seed`, and `hindsight.llm_model` is `ro`.

```swift
@Test func aSharedEditIsStagedWhateverTheProfileShows() async throws {
  let (model, _) = await loaded()
  model.stage("updates.slow_step_seconds", value: "10", shared: true)
  model.stageReset("apps.obsidian_vault", shared: true)
  #expect(model.staged.map(\.settingId) == ["updates.slow_step_seconds", "apps.obsidian_vault"])
  await model.load()
  #expect(model.staged.count == 2)
  model.stage("updates.slow_step_seconds", value: "10", shared: false)
  model.stageReset("apps.obsidian_vault", shared: false)
  #expect(model.staged.isEmpty)
  model.stage("hindsight.llm_model", value: "x", shared: true)
  #expect(model.staged.isEmpty)
  let vault = try #require(model.rows.first { $0.settingId == "apps.obsidian_vault" })
  let locked = try #require(model.rows.first { $0.settingId == "hindsight.llm_model" })
  #expect(SettingsModel.canReset(vault, shared: true))
  #expect(!SettingsModel.canReset(vault, shared: false))
  #expect(!SettingsModel.canReset(locked, shared: true))
}
```

- [ ] **Step 2: Run.** `swift test --package-path app --filter SettingsModelTests`. Expected: a compile error for `canReset`. With that line stubbed out, the first `#expect` fails with an empty list.

- [ ] **Step 3: Implement** both interfaces. `SettingRowView.swift:72` becomes `else if SettingsModel.canReset(row, shared: shared)`.

- [ ] **Step 4: Run** the same filter. Expected: pass.

- [ ] **Step 5: Edit `docs/menu-bar.md:64`.** Add that with the box ticked every change is staged, even one equal to the value shown, because the window shows the profile's value and not the shared one, and that Reset is offered on every row.

- [ ] **Step 6: Regenerate and read** `.shots/settings-setup-light.png`. No profile is active in the fixture, so the Reset buttons must be where they were, on the `override` rows only. No image shows a profile with the box ticked.

- [ ] **Step 7: Commit.**

```bash
git add app/Sources/RotmCore/SettingsModel.swift app/Sources/ReturnOfTheMac/SettingRowView.swift app/Tests/RotmCoreTests/SettingsModelTests.swift docs/menu-bar.md
git commit -m "Keep a shared edit that equals the profile's value"
```

---

### Task 8: Name what an Apply will change

**Finding:** M6

**Files:**
- Modify: `app/Sources/RotmCore/SettingsModel.swift`
- Modify: `app/Sources/ReturnOfTheMac/ReviewSheet.swift:6-14`
- Modify: `app/Sources/ReturnOfTheMac/SettingsView.swift:33`
- Modify: `docs/menu-bar.md:59`
- Test: `app/Tests/RotmCoreTests/SettingsModelTests.swift`, `app/Tests/ReturnOfTheMacTests/ShotsTests.swift:136`

**Interfaces:**
- Produces: `public static func targetNote(profile: String, shared: Bool) -> String` on `SettingsModel`, with exactly these three results:
  - `profile == "default"`: `No profile is in use, so these change your shared settings.`
  - a profile, `shared == false`: `The profile work is in use, so these change that profile.`
  - a profile, `shared == true`: `These change your shared settings, not the profile work.`
- Changes: `ReviewSheet` gains `let target: String`, shown as a line under "Apply runs these commands in order:".

Staged edits still follow a profile switch. The sheet is where the user agrees to the commands, so it is where the target is named.

- [ ] **Step 1: Write the failing test** `theReviewNamesWhatTheCommandsChange` with the three calls and the three strings above (`work` as the profile).

- [ ] **Step 2: Run.** `swift test --package-path app --filter SettingsModelTests`. Expected: a compile error for `targetNote`.

- [ ] **Step 3: Implement.** `SettingsView.swift:33` passes `target: SettingsModel.targetNote(profile: state.status?.profile.active ?? "default", shared: writeShared)`. `ShotsTests.swift:136` passes `target: SettingsModel.targetNote(profile: "work", shared: false)`.

- [ ] **Step 4: Run** the same filter. Expected: pass.

- [ ] **Step 5: Regenerate and read** `.shots/settings-review-light.png` and `.shots/settings-review-dark.png`. The new line reads "The profile work is in use, so these change that profile." and nothing is clipped.

- [ ] **Step 6: Edit `docs/menu-bar.md:59`.** Add that the sheet says whether the commands change the profile in use or your shared settings.

- [ ] **Step 7: Commit.**

```bash
git add app/Sources/RotmCore/SettingsModel.swift app/Sources/ReturnOfTheMac/ReviewSheet.swift app/Sources/ReturnOfTheMac/SettingsView.swift app/Tests/RotmCoreTests/SettingsModelTests.swift app/Tests/ReturnOfTheMacTests/ShotsTests.swift docs/menu-bar.md
git commit -m "Name the profile or shared settings in the review sheet"
```

---

### Task 9: Ask about staged edits before the app's update, not during the relaunch

**Finding:** M3

**Files:**
- Modify: `app/Sources/RotmCore/AppState.swift:163-175` (`quitDecision`)
- Modify: `app/Sources/ReturnOfTheMac/StatusItemController.swift:162-181` (`upgradeApp`)
- Modify: `docs/menu-bar.md:82` and `:88`
- Test: `app/Tests/RotmCoreTests/AppStateTests.swift`

**Interfaces:**
- Produces: `public var relaunching = false` on `AppState`. While it is true, `quitDecision` returns `.allow` whatever else holds.
- Produces: `public static func upgradeQuestion(version: String, stagedEdits: Int) -> String` on `AppState`:
  - 0 edits: `Update Return of the Mac to 0.2.0?`
  - 1 edit: `Update Return of the Mac to 0.2.0 and discard 1 change?`
  - 3 edits: `Update Return of the Mac to 0.2.0 and discard 3 changes?`

- [ ] **Step 1: Write the failing tests** in `AppStateTests`. `theRelaunchQuitsWithoutAsking`: with `state.relaunching = true`, `state.quitDecision(sessionTitle: nil, stagedEdits: 2) == .allow`, and with it false the same call is the "Quit and discard 2 changes?" ask. `theUpdateQuestionNamesTheStagedEdits`: the three strings above.

- [ ] **Step 2: Run.** `swift test --package-path app --filter AppStateTests`. Expected: a compile error for `relaunching`.

- [ ] **Step 3: Implement.** In `StatusItemController.upgradeApp`, the alert's message is `AppState.upgradeQuestion(version: version, stagedEdits: settingsWindow?.model.staged.count ?? 0)`, and the `.relaunch` case sets `state.relaunching = true` before `Self.relaunch(app)`. `relaunch` itself is unchanged: `applicationShouldTerminate` (`App.swift:29-43`) now always gets `.allow`, so the waiter never outlives a cancelled quit.

- [ ] **Step 4: Run** the same filter. Expected: pass.

- [ ] **Step 5: Edit `docs/menu-bar.md`.** At `:82`, say the question names any changes staged in the settings window, which the update discards. At `:88`, say the app quits and opens again without asking a second time.

- [ ] **Step 6: Not run on the host.** The relaunch itself is proved in the guest by the app-update step of `docs/superpowers/specs/2026-11-14-p5-vm-proof/RUNBOOK.md` ("Update the setup and the app") at the next app release, with one change staged in the settings window before the update is chosen. Record that the question named the change and that the new version opened with no second question. No image shows the alert.

- [ ] **Step 7: Commit.**

```bash
git add app/Sources/RotmCore/AppState.swift app/Sources/ReturnOfTheMac/StatusItemController.swift app/Tests/RotmCoreTests/AppStateTests.swift docs/menu-bar.md
git commit -m "Ask about staged edits before the app's update"
```

---

## Left as they are

- A `settings list --json` read started by the window is not counted by `settled()`. An Apply can start while one runs. The read changes nothing, and `SettingsModel.load`'s generation counter drops a stale answer.
- The window lists the settings on every focus (the second half of M8). See "Decided while writing this plan".
- A copy mise did not install learns of no new release from the app (M2).
- Edits staged while mise replaces the app are discarded without a question (M3).
- A colon-form colour (`38:2:…`) is dropped, not shown. No command the app runs prints one.

## Findings the code contradicts

None. Each of M1 to M9 and G8 matches the cited lines at `1b5fa26`.
