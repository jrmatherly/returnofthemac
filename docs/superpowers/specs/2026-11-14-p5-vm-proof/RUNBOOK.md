# P5 VM proof: runbook (2026-11-14)

This run proves, in the disposable UTM guest, that the menu bar app does what its commands do on a real install. In the same run it settles the two VM proofs still owed: the profile switch on a real install (P4 plan, Task 11 Step 3) and sync against a real private repository between two Macs (P3 plan, Task 9 Step 6). It ends the P5 plan's Task 11 Step 3.

How it works:

- You click in the app and type short lines in the guest's Terminal. Each `p <row>` line runs one row of `proof.sh`, which records the state into `~/vm-proof/p5/g1/<row>/` (guest 1) or `g2/<row>/` (guest 2) on the host. Rows 1b2, 1b6 and 1c2 also run the terminal side of a comparison themselves, so you type nothing longer than `p 1c2`.
- The session reads every result on the host. You do not need to read the output. Tell the session when you reach a step marked **Tell the session**, and whenever something on screen looks wrong.
- A row that compares prints `compared with <row>:` and the fields that differ, or `no field differs`. Some differences are expected, and each step says which. The `list.packages.*` rows and the `cask` field change whenever packages install or GitHub's API is slow, so ignore them in every comparison.
- Every line you type was run on the host first through the same shell, with only the shared folder's path and the home folder changed, except where a step says **Not run on the host**.

## Before the run

1. **The session** copies the script to the shared folder, from the repository's root, when the run starts, so the guest runs the reviewed copy. **Not run yet.**

   ```shell
   mkdir -p ~/vm-proof/p5 && cp docs/superpowers/specs/2026-11-14-p5-vm-proof/proof.sh ~/vm-proof/p5/proof.sh
   ```

2. **You decide** what happens to `jrmatherly/rotm-settings`. P5's probe row 5 created it on 2026-11-14 and it holds saved settings. If guest 1 signs in to that account, Turn On Sync loads those settings instead of creating the repository, and the settings changed in steps 16 and 19 then stop it with a conflict. Delete the repository on GitHub (its Settings, then Danger Zone), or use another account at every sign-in (steps 5, 21 and 32). **Not run on the host:** the deletion.

## Guest 1

### Install

3. In UTM, start the macOS guest with **Run without saving changes**.
4. In the guest's Terminal, check the two tools the install needs:

   ```shell
   xcode-select -p
   ```

   It prints a folder. When it says the tools are missing, run `xcode-select --install` and wait for it to finish. Then:

   ```shell
   ls ~/.local/bin/mise
   ```

   When that file is missing, run `curl https://mise.run | sh`. **Not run on the host:** the two installers.

5. Run the install line, from `main` because nothing is promoted to `stable` yet:

   ```shell
   ~/.local/bin/mise -E rotm-installed bootstrap --from 'https://github.com/jrmatherly/returnofthemac.git?ref=main' --config-dir tilde/.config/mise --save-env --only final-hook && ~/.local/share/mise/bootstrap-repo/setup.sh
   ```

   Answer setup's questions: `y` to the GitHub login and sign in with the account you chose, taking gh's defaults except one: answer `n` to "Authenticate Git with your GitHub credentials" (the wording probe row 5 recorded). Then the console's sign-in in step 21 is the only one that can add gh's Git credential helper, which the spec's "Still not verified" table asks about. For the rest: your name and email for git, no commit signing, Enter for the other questions, and your password when asked. It takes a while. **Not run on the host:** `setup.sh`. The mise half ran with `--dry-run` in a scratch home and printed the clone of `main`.

6. Quit Terminal and open it again, so the new window has the installed `PATH`. Then define `p`, which you type again in every new Terminal window:

   ```shell
   p() { /bin/bash "/Volumes/My Shared Files/vm-proof/p5/proof.sh" "$@"; }
   ```

7. Record the state after the install:

   ```shell
   p 1a
   ```

   This shows whether the app is in `/Applications`, runs, and has the `opened-by-setup` file.

   Then check GitHub over SSH with a plain key and no 1Password (audit plan `docs/superpowers/plans/completed/2026-11-14-audit-install-and-opt-outs.md`, Task 4):

   ```shell
   ssh-keygen -t ed25519 -N '' -f ~/.ssh/id_ed25519 && pbcopy < ~/.ssh/id_ed25519.pub
   ```

   Add the copied key at github.com/settings/keys for the account you signed in with, then run `ssh -T -o StrictHostKeyChecking=accept-new git@github.com`. It should greet the account by name. **Tell the session** what it printed. **Not run on the host.**

8. In Finder, open **Applications**, then **Return of the Mac**. The settings window should open. **Tell the session** what you saw, and whether the menu bar shows the app's icon.

### P4: a profile, through the app

9. Click the app's icon in the menu bar. Choose **Profile: default**, then **New Profile…**. Type `work` and choose **Create**. Open the menu again, choose **Profile: default**, then **work**, and confirm the alert. Then:

   ```shell
   p 1b1
   ```

10. The terminal side of the switch: the row switches back to `default` and then to `work` with `rotm settings profile use`, and compares.

    ```shell
    p 1b2
    ```

    Expected: the first comparison (with 1a) lists only the new profile's two files and `status.profile.names`. The last one, with 1b1, says `no field differs`.

11. From the menu, choose **Settings…**. Make three changes, pressing Return after typing a value:
    - **Shell**, **Editor**: `nano`
    - **macOS (tracked in git)**, **Dock icon size**: `30`
    - **Modules**, **File, text and image processing**: off

    Choose **Review…**, check that it lists three `rotm settings set` lines, and choose **Apply**. Then:

    ```shell
    p 1b3
    ```

    Expected: the Dock shrinks at once. A `set` of a macOS preference writes that one preference and restarts the Dock; the other preferences wait for `set-defaults`.

12. From the menu, choose **More**, then **Run Setup Again…**, and confirm. In the console, type your password when asked. When the console says the command finished, close it. Then choose **More**, then **Apply macOS Preferences…**, confirm, and answer its question and the password the same way. Then:

    ```shell
    p 1b4
    ```

13. From the menu, choose **Profile: work**, then **default**, and confirm. Then:

    ```shell
    p 1b5
    ```

14. The terminal side of the switch back:

    ```shell
    p 1b6
    ```

    Expected: the last comparison, with 1b5, says `no field differs`.

15. From the menu, choose **More**, then **Apply macOS Preferences…**, and confirm and answer as before. A switch writes no macOS preference, so this run puts the Dock back. Then:

    ```shell
    p 1b7
    ```

    Expected, compared with 1a: the Dock size is the shared value, 38 (1a may show `(not set)`: the install never runs `set-defaults`); the `work` profile's files and `status.profile.names` exist; `miserc.local.toml` may gain an `ignored_config_paths` line. The Editor and the module are as in 1a. The row also leaves `~/vm-proof/p4/p5-run.txt`, which points at these records.

### The app against the terminal, one setting of each kind

16. From the menu, choose **Settings…**. Make four changes:
    - **Shell**, **Editor**: `vim`
    - **macOS (tracked in git)**, **Dock icon size**: `64`
    - **Modules**, **Kubernetes and containers**: off
    - **Agents**, **jstack: bug-fix**: model `haiku`, effort `high`

    Choose **Review…** (four `set` lines), then **Apply**. Then:

    ```shell
    p 1c1
    ```

17. The terminal side: the row resets the four settings with `rotm settings reset` and records that into `1c2/undone`, then sets them again with `rotm settings set` and compares with 1c1.

    ```shell
    p 1c2
    ```

    Expected: the last comparison, with 1c1, says `no field differs`. The first one, with 1b7, may show what a reset leaves behind: empty tables in `config.override.toml` and `tools.toml`, an empty `modules-off.local`, and `list.jstack.bug_fix` going from the shipped value to unset, because a reset deletes the role's line.

18. From the menu, choose **Settings…**. Choose **Reset** on each of the four rows, then **Review…** (four `reset` lines) and **Apply**. Then:

    ```shell
    p 1c3
    ```

    Expected: compared with `1c2/undone`, the terminal's reset, `no field differs`.

19. In **Settings…**, make the same four changes as in step 16 again and apply them. Then:

    ```shell
    p 1d1
    ```

    Expected: compared with 1c1, `list.jstack.bug_fix` reads `sonnet xhigh` where 1c1 holds `haiku high`, and `file.tools.toml` differs by that line. Nothing else differs. Row 1c3 still holds `haiku high`, because the app offered no Reset for a role then (fixed in `e7db2f3`). These four changes are what sync carries to guest 2.

### P3, first half: sync from guest 1

20. From the menu, choose **More**, then **Apply macOS Preferences…**, and answer as before. Guest 2 runs the same command from Terminal in step 34, so the two Macs' preferences compare an app run with a terminal run. Then:

    ```shell
    p 1d2
    ```

    The row records first, then signs `gh` out, so that the app's console does the GitHub sign-in in the next step.

21. From the menu, choose **Turn On Sync…** and confirm. In the console, answer `y` to "Authenticate Git with your GitHub credentials", press Return when it shows the one-time code, and finish the sign-in in the browser with the account you chose. When the console says the command finished:

    ```shell
    p 1d3
    ```

    Expected, compared with 1d2: `status.sync.connected` turns true with the repository as its origin. `git.credential` shows whether the console's sign-in changed the Git credential helpers. 1d2 recorded `gh` signed in, before the row signed it out (`1d2/gh-after.txt.err` shows the signed-out state), so `gh.signed_in` reads true in both.

22. From the menu, choose **Sync Now** and confirm. Then:

    ```shell
    p 1d4
    ```

    The row also leaves `~/vm-proof/p3/p5-run.txt`.

### Stop and tell the session: the 0.1.2 release

23. **Stop and tell the session.** Leave the guest running. From here:
    1. The session sets `app/VERSION` to `0.1.2`, runs `pnpm check`, commits and pushes to `main`. That commit is also the update guest 1 sees waiting.
    1. You push the tag on that commit, from the clone on the host: `git tag -m "Return of the Mac 0.1.2" app-v0.1.2 <commit> && git push origin app-v0.1.2`. The message is needed because `tag.gpgsign` is on in `~/.gitconfig.local`: without one, git stops with "no tag message?" and makes no tag (seen on 2026-11-15 for 0.1.3).
    1. The session waits for the release workflow to publish `returnofthemac-app_0.1.2_arm64.dmg`, then changes the cask in `~/dev/homebrew-tap/Casks/returnofthemac-app.rb` to `version "0.1.2"` and the release's `sha256`, and pushes it when you say so.
    1. The session tells you when the tap is pushed. Wait five minutes after that: the app reads the cask through `raw.githubusercontent.com`, which caches it for up to five minutes.

### Update the setup and the app

24. The app checks for its own update when it starts and then once a day, so restart it. From the menu, choose **Quit**. In Finder, open **Applications**, then **Return of the Mac**. Open the menu: the first line should read **Update Return of the Mac to 0.1.2…**, and the setup line **Setup: 2 updates waiting**. Then:

    ```shell
    p 1f1
    ```

    **Tell the session** what the menu's first lines say.

25. From the menu, choose **Update…** and confirm. In the console, type your password when asked. When it finishes:

    ```shell
    p 1f2
    ```

    Expected, compared with 1f1: `update.behind` drops to 0 and `status.commit` is the new commit.

26. From the menu, choose **Update Return of the Mac to 0.1.2…** and confirm. The app runs mise while it keeps running, then quits and opens again by itself, which takes up to a minute. If it shows "Return of the Mac was not updated" instead, **tell the session** what it says. Then:

    ```shell
    p 1f3
    ```

    Expected, compared with 1f2: `mac.app_version` is 0.1.2, `mac.app_running` is still yes with a new `mac.app_started`, and `cask` shows 0.1.2 installed.

### Launch at Login across a restart

27. From the menu, choose **More**, then **Launch at Login**, so it has a tick.
28. Restart the guest with the **Restart** button in the UTM window's toolbar, not with the guest's Apple menu. Read in UTM 5.0.8's source, not run: when the guest restarts itself, UTM treats it as a stop and discards a disposable run's changes, while the toolbar's Restart stops and starts the same machine and keeps them. If the guest comes back without the app installed, the changes were lost: **tell the session**. Everything recorded so far is on the host and is safe.
29. Log in to the guest. Wait half a minute. Open Terminal, define `p` again (step 6), then:

    ```shell
    p 1f4
    ```

    Expected, compared with 1f3: `mac.booted` and `mac.app_started` are later, and `mac.app_running` is yes.

30. Shut the guest down, which discards it. **Tell the session.**

## Guest 2

### P3, second half: a fresh Mac loads the settings

31. In UTM, start the guest again with **Run without saving changes**. It starts from the clean state, without anything from guest 1.
32. Do steps 4 and 5 again: check the tools, then run the install line. At setup's GitHub login, answer `y`, sign in with the same account as in step 21, and again answer `n` to "Authenticate Git with your GitHub credentials", so that the restore reads the private repository with the credential helpers setup itself leaves (2a records them). When setup asks whether to load your saved settings, press Enter. **Not run on the host:** `setup.sh` and its restore prompt.
33. Quit Terminal, open it again, define `p` (step 6), then:

    ```shell
    p 2a
    ```

    Expected, compared with 1d4: the four `list.*` rows of step 16 match (Editor `vim`, Dock size 64, Kubernetes off, bug-fix `sonnet xhigh`), as do the files from `~/.config/rotm`. Expected to differ: the Dock's `defaults` value (this Mac has not run `set-defaults`), `mac.app_version` (the tap now gives 0.1.2), `status.commit`, and the machine-scoped rows. If setup warned that your saved settings did not load, or `status.sync.connected` is false, **tell the session** before going on.

34. Apply the macOS preferences from the terminal, answering its question and the password:

    ```shell
    set-defaults
    ```

    **Not run on the host:** `set-defaults` writes the Mac's preferences.

35. Record it:

    ```shell
    p 2b
    ```

    Expected, compared with 1d4: `defaults.com.apple.dock.tilesize` is 64 on both. The row also rewrites `~/vm-proof/p3/p5-run.txt` to point at both guests.

36. From the menu, choose **Settings…**, then **Agents**. The **jstack: bug-fix** row reads `sonnet xhigh`, loaded from guest 1, and should offer **Reset**. Choose **Reset**, then **Review…** (one `reset` line) and **Apply**. If the row offers no **Reset**, **tell the session** and record the row anyway. Then:

    ```shell
    p 2c
    ```

    Expected, compared with 2b: `list.jstack.bug_fix` goes from `"sonnet xhigh" [override]` to `null [unset]`, and `file.tools.toml` loses its `jstack.bug_fix` line. `status.sync.waiting` may gain an entry, because the reset is a local change that sync has not sent. Row 1c3 could not show this: the app offered no Reset for a role then (fixed in `e7db2f3`).

37. Shut the guest down. **Tell the session.** The run is complete.

## The 0.1.3 and 0.1.4 releases (2026-11-15)

Two fixes in 0.1.3 can only be seen while the app that runs is 0.1.3 and the tap holds something newer (audit app plan, Tasks 2 and 9). So this run takes two releases: 0.1.3 carries the fixes, and 0.1.4 is a version bump that gives 0.1.3 an update to offer. Rows `3a` to `3d` record into `~/vm-proof/p5/g3/`.

38. Use the guest from step 36 if it is still running. Otherwise start the guest with **Run without saving changes** and do steps 4 to 6. No GitHub sign-in is needed, so answer `n` to setup's GitHub login. Do this before step 41, so the guest never installs 0.1.4 directly.
39. **Stop and tell the session.** The 0.1.3 release follows step 23, with `0.1.3` in place of `0.1.2`: the session pushes the version commit, you push the tag `app-v0.1.3` on it with its message, the session changes the cask and pushes the tap on your word, and you wait five minutes.
40. From the menu, choose **Quit**. In Finder, open **Applications**, then **Return of the Mac**. The menu's first line should read **Update Return of the Mac to 0.1.3…**. Choose it and confirm. When the app has opened again:

    ```shell
    p 3a
    ```

    Expected, compared with 2c: `mac.app_version` is 0.1.3 and `mac.app_started` is later. A guest installed after the tap moved already runs 0.1.3 and shows no update line: run `p 3a` and go on.

41. **Stop and tell the session.** The 0.1.4 release is the same four steps with `0.1.4`. Wait five minutes after the session says the tap is pushed.
42. Turn the module off, then restart the app so it checks for its update again:

    ```shell
    rotm settings set modules.menubar off
    ```

    From the menu, choose **Quit**, then open the app from **Applications**. Open the menu. Expected: no **Update Return of the Mac** line and no dot on the icon, because mise no longer manages the cask. Then:

    ```shell
    p 3b
    ```

    **Tell the session** what the menu's first lines say. **Not run on the host.**

43. Turn the module on again and restart the app the same way:

    ```shell
    rotm settings set modules.menubar on
    ```

    Expected: the menu's first line reads **Update Return of the Mac to 0.1.4…**. Then:

    ```shell
    p 3c
    ```

44. From the menu, choose **Settings…** and change one setting, such as **Editor**. Do not choose **Review…**, so the change stays staged. From the menu, choose **Update Return of the Mac to 0.1.4…**. Expected: the question reads **Update Return of the Mac to 0.1.4 and discard 1 change?**. Confirm. The app quits and opens again by itself, and asks nothing a second time. Then:

    ```shell
    p 3d
    ```

    Expected, compared with 3c: `mac.app_version` is 0.1.4, and the setting you changed has its old value. **Tell the session** the question's words and whether a second question appeared.

45. Shut the guest down. **Tell the session.**

## Compare any two records

To compare two records yourself, in either guest or on the host (with the host's path):

```shell
p diff 1c1 1d1
```

A record is a row name, or `1b2/undone`, `1b6/undone` or `1c2/undone` for the state a terminal row restored before it repeated the app's action.
