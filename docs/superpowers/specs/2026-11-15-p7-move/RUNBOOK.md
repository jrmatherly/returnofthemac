# P7 guest runs: runbook (2026-11-15)

Candidate: the commit on `main` that adds `install.sh`, once its `check.yml` run has passed. The session gives you its full hash when it hands this runbook over, and row `a1` must print it. mise for this run: 2026.11.8, the newest release on 2026-11-15 (`gh api repos/jdx/mise/releases/latest`).

This run proves a fresh install from `main` at the candidate in the disposable UTM guest. It is the gate for moving `stable` (decision 9 of `docs/superpowers/specs/2026-11-11-installable-setup-profiles-and-sync.md`), run on the mise release current that day (decision 10). It is P7 plan Task 1 (`docs/superpowers/plans/2026-11-15-p7-stable-and-the-owners-mac.md`).

How it works:

- You type each line in the guest's Terminal. Each `r <row> …` line runs one command and records what it printed, and its exit code, into `~/vm-proof/p7/<row>.txt` on the host. It shows you the last three lines.
- The session reads every record on the host and compares it with the row's "Passes when". Tell the session when you reach a step marked **Tell the session**, and whenever something on screen looks wrong.
- Every line was run on the host first, in a scratch home through the same shell, with only the record folder and the home folder changed, except where a step says **Not run on the host**.
- Push nothing to `main` from the first step to the last: the guest follows `main`, and row `a7` reads it.

## Guest A

1. In UTM, start the macOS guest with **Run without saving changes**.
2. In the guest's Terminal, see which of the two tools the install needs are there. Install neither by hand:

   ```shell
   xcode-select -p
   ```

   It prints a folder, or says the tools are missing. Then:

   ```shell
   ls ~/.local/bin/mise
   ```

   The baseline guest has the tools and no mise (the owner, 2026-11-15). So that `install.sh` has to install the tools too, remove them when the first line printed `/Library/Developer/CommandLineTools`. Nothing is kept from this guest:

   ```shell
   sudo rm -rf /Library/Developer/CommandLineTools
   xcode-select -p; echo "exit $?"
   ```

   The second line must now end with an exit code that is not 0. When it still prints `exit 0`, or the first line printed a path inside `Xcode.app`, leave the tools as they are: the run then proves the mise install only. **Not run on the host.**

   **Tell the session** what each line printed. `install.sh` installs what is missing, and this run is its first on a real Mac. When the tools are missing it asks for the guest's password and installs them with no window; if a window opens instead, finish it and **tell the session**. **Not run on the host:** its two installers.

3. Make the record folder:

   ```shell
   mkdir -p "/Volumes/My Shared Files/vm-proof/p7"
   ```

4. Run the README's install line with `main` for `stable`, and `--ref main` so the copy follows `main` too, where the candidate is:

   ```shell
   curl -fsSL https://raw.githubusercontent.com/jrmatherly/returnofthemac/main/install.sh | bash -s -- --ref main
   ```

   Setup's questions, and the answers:

   | Setup asks | Answer |
   | --- | --- |
   | `Press Enter key to continue…` | Enter |
   | `Sign in to GitHub now (gh auth login)? [Y/n]` | `y`, then gh's defaults |
   | `Load your saved settings from <login>/rotm-settings before installing? [Y/n]` | **`n`**. It appears only when that repository exists, and it holds the P5 guests' test values |
   | Your name and email for git | Yours |
   | Commit signing | No |
   | The password | The guest's login password |
   | Anything else | Enter |

   It takes a while. Setup must end with `All done!`. If it lists failed packages instead, **Tell the session** their names: the session decides with you whether each is accepted. **Not run on the host:** `setup.sh`, and `install.sh` installing the Command Line Tools or mise. `install.sh` ran in a scratch home on 2026-11-15 with mise present and `setup.sh` stubbed, piped into `bash` under a terminal: setup's flags reached it and its stdin was the terminal. The mise half cloned `main`, printed `linked ~/.config/mise to ~/.local/share/mise/bootstrap-repo/tilde/.config/mise` and `saved env = ["rotm-installed"]`.

5. Quit Terminal and open it again, so the new window has the installed `PATH`. Then type these two lines, which every new Terminal window needs:

   ```shell
   P7="/Volumes/My Shared Files/vm-proof/p7"
   r() { local row=$1; shift; { "$@"; echo "exit $?"; } > "$P7/$row.txt" 2>&1; tail -3 "$P7/$row.txt"; }
   ```

6. Record the install:

   ```shell
   r a1 git -C ~/.local/share/mise/bootstrap-repo rev-parse HEAD
   r a2 ~/dotfiles/bin/lib/rotm-mode
   r a3 rotm settings status --json
   r a4 mise --version
   ```

   | Row | Passes when |
   | --- | --- |
   | `a1` | It prints the candidate's full hash |
   | `a2` | `installed` |
   | `a3` | `"mode": "installed"`, `"branch": "main"` and the candidate's short hash as `"commit"` |
   | `a4` | The mise release named above |

7. Use the apps that write into their config once, so row `a5` shows whether any of them writes into the copy. Open VS Code from the Dock or Applications, wait for its window, and quit it (⌘Q). Then:

   ```shell
   lazygit -p ~/.local/share/mise/bootstrap-repo
   ```

   Press Enter at its welcome, then `q` to leave it. It needs a repository: a bare `lazygit` in the home folder only offers to create one. Then:

   ```shell
   fastfetch
   gh config set editor vim
   r a5 git -C ~/.local/share/mise/bootstrap-repo status --short
   ```

   `a5` passes when the record holds nothing but `exit 0`. **Not run on the host:** the apps, which need setup's install. The row itself printed `exit 0` on the scratch copy.

8. Check fastfetch's own config, the first real install of P6 Task 2:

   ```shell
   r a6 fastfetch --version
   r a6b ls -lR ~/.config/fastfetch
   ```

   `a6b` passes when `config.jsonc` is a regular file (its line starts with `-`) and the files under `ascii` are links (their lines start with `l`). **Not run on the host:** setup seeds `config.jsonc`.

9. Check for updates:

   ```shell
   r a7 rotm update --check
   ```

   It passes when it prints `Up to date.`

10. **Tell the session** that the rows are recorded. When it says they passed, or asks for nothing more, shut the guest down from the Apple menu. Nothing it did is kept.

The rows' commands were checked before the candidate existed. On a scratch copy of `9e79b81`, the candidate's grandparent, on 2026-11-15, rows `a1` to `a5` and `a7` passed through the same `r`, with `DOTFILES` set to the copy because no setup had run: `a1` printed the hash, `a2` `installed`, `a3` `"mode": "installed"`, `"branch": "main"`, `"commit": "9e79b81"`, `a4` `2026.11.8 macos-arm64 (2026-11-13)`, `a5` only `exit 0`, and `a7` `Up to date.`

### Result (2026-11-15)

Passed on candidate `2e0dbe990461727e82e0958f1c75c3ee063eb005` with mise 2026.11.8. The guest had the Command Line Tools and no mise, the tools were removed in step 2, and `install.sh` installed both with one password prompt and no installer window. Setup ended with `All done!`. Every row met its "Passes when". The run corrected step 7, which first ran a bare `lazygit`. The rows are in the spec's "Verified facts".

## Guest B

This run rehearses [`MOVE.md`](MOVE.md) on a guest shaped like the owner's Mac, before it is run there. It is P7 plan Task 4. It is the first run of the fetch, of `setup.sh` on a moved home, and of the rollback's setup. It also proves an update across a promotion and that the clone is inert afterwards.

- Records go to `~/vm-proof/p7/` on the host, as in guest A. `MOVE.md`'s rows land beside this section's.
- The guest follows `stable` after the move, so the session may push to `main` during this run. It pushes nothing to `stable` without your word.
- The blocks of steps 4 and 5 ran in a scratch home on 2026-11-15, in `zsh`, with only the home folder changed, and `MOVE.md`'s steps 1 to 3 and 5 then ran on that home as written. What did not run says **Not run on the host**.

### Set up a clone install

1. In UTM, start the macOS guest with **Run without saving changes**. Check the two tools, as every guest run does: `xcode-select -p` prints a folder, and `ls ~/.local/bin/mise` finds no file, which is right, since setup installs mise. Leave the Command Line Tools in place this time: the clone needs `git`.
2. Clone and run setup, as the README's "Install from a clone" does. **Not run on the host.**

   ```shell
   git clone https://github.com/jrmatherly/returnofthemac.git ~/dev/dotfiles
   ~/dev/dotfiles/setup.sh
   ```

   Answer as in guest A: Enter to continue, `y` to the GitHub sign-in with gh's defaults, **`n`** to "Load your saved settings", your name and email for git, no commit signing, the guest's password, Enter for the rest. It must end with `All done!`.

3. Quit Terminal and open it again. Open VS Code, wait for its window and quit it (⌘Q). Then type `MOVE.md`'s opening block with the guest's record folder:

   ```shell
   CLONE=~/dev/dotfiles COPY=~/.local/share/mise/bootstrap-repo KEEP=~/rotm-move-keep A="$HOME/Library/Application Support"
   P7="/Volumes/My Shared Files/vm-proof/p7"
   r() { local row=$1; shift; { "$@"; echo "exit $?"; } > "$P7/$row.txt" 2>&1; tail -3 "$P7/$row.txt"; }
   inclone() { find ~ ~/.config ~/.claude ~/.claude/rules ~/.claude/skills ~/.codex ~/.ssh ~/.gnupg ~/.config/mole ~/.local/share/mise/plugins "$A/Code" "$A/lazydocker" "$A/rtk" -maxdepth 1 -type l 2> /dev/null | sort -u | while IFS= read -r l; do case "$(realpath "$l" 2> /dev/null)" in "$CLONE" | "$CLONE"/*) echo "$l" ;; esac; done; }
   ```

   Every new Terminal window in this run needs this block again, with this `P7` line and not `MOVE.md`'s.

### Give it the state a used Mac has

4. A setting, a Mole list of its own, and the files VS Code and hunk leave behind:

   ```shell
   dotfiles-settings set updates.mac_password_op 'op://x/y/z'
   echo 'guest-b' > "$CLONE/mole/whitelist.local"
   printf '[dotfiles]\n"~/.config/mole/whitelist" = { source = "~/dotfiles/mole/whitelist.local", mode = "symlink" }\n' >> ~/.config/mise/config.local.toml
   [ -e ~/.config/hunk/state.json ] || echo '{}' > ~/.config/hunk/state.json
   for n in History globalStorage profiles sync workspaceStorage; do mkdir -p "$A/Code/User/$n"; done
   [ -e "$A/Code/User/agent-sessions.code-workspace" ] || echo '{}' > "$A/Code/User/agent-sessions.code-workspace"
   mise dotfiles apply --yes
   git -C "$CLONE" status --short
   ```

   The apply prints `created symlink ~/.config/mole/whitelist -> ~/dotfiles/mole/whitelist.local`, and the last line prints nothing. Type the `printf` line once only: a second `[dotfiles]` header in that file is a TOML error. **Not run on the host:** the first line. In the scratch home the override file was written directly.

### Reshape it to the owner's Mac

A clone set up today links through `~/dotfiles`, has a real `~/.config/fastfetch` and keeps the override file in `~/.config/rotm`. The owner's Mac, set up long ago, has absolute links, one folder link for fastfetch and the override file in the clone. `MOVE.md` is written for that shape.

5. Reshape, then record it:

   ```shell
   inclone | while IFS= read -r l; do [ "$l" = ~/dotfiles ] || ln -sfn "$(realpath "$l")" "$l"; done
   rm -r ~/.config/fastfetch && ln -s "$CLONE/tilde/.config/fastfetch" ~/.config/fastfetch
   rm "$CLONE/tilde/.config/mise/config.override.toml" && mv ~/.config/rotm/config.override.toml "$CLONE/tilde/.config/mise/config.override.toml"
   rm -f "$CLONE/tilde/.config/mise/modules-off.local" && rmdir ~/.config/rotm
   r b0 ~/dotfiles/bin/lib/rotm-mode
   r b0b sh -c 'find ~ ~/.config -maxdepth 1 -type l -lname "$HOME/dev/dotfiles/*" | wc -l'
   ```

   | Row | Passes when |
   | --- | --- |
   | `b0` | `clone` |
   | `b0b` | 20 or more, which shows the links are absolute. The scratch home printed 24 |

   The `rm -r` removes a folder that holds links only. The third line removes a link and puts the real file in its place.

### Run the move

6. Quit VS Code if it is open. Run `MOVE.md` from "Then check the start" through step 7, in this one Terminal window, with these differences:

   - **Step 1** printed 46 in the scratch home. **Tell the session** the number.
   - **Step 6** asks for the guest's password, and must not ask about GitHub or git identity. It installs no package here: the clone setup already installed the menu bar app, which `MOVE.md` names as the one missing on the owner's Mac. Run the REA line its warning prints. If it prints no such warning, tell the session.
   - **Step 7** needs the opening block of step 3 above in its new window. Row `m11` is judged like the others: setup itself runs `claude mcp` on this signed-out guest. Add one row after it, `r b8 claude mcp get rea`, which passes when its `Command:` line names `bootstrap-repo`. Row `m12` passes when it prints `op://x/y/z`. Skip the closing `grep` of your own files.

   **Tell the session** when the rows are recorded, and wait for its word before the next step.

### Prove an update across a promotion

7. The session promotes `stable` to `main`'s head on your word. It first checks that `git diff --name-only origin/stable origin/main` lists Markdown files only, which decision 9 requires of a commit no guest installed. On 2026-11-15 it listed four `.md` files. If a fix made during this run touched another file, this step waits for a new guest A. Then:

   ```shell
   r b1 rotm update --check
   rotm update
   r b2 git -C ~/.local/share/mise/bootstrap-repo rev-parse HEAD
   r b3 rotm update --check
   ```

   | Row | Passes when |
   | --- | --- |
   | `b1` | `1 update is waiting. Run rotm update.`, or `N updates are waiting. Run rotm update.` for the count the session names |
   | `b2` | The new `stable`, which the session names |
   | `b3` | `Up to date.` |

   `rotm update` runs setup again: answer as in step 6 of `MOVE.md`. **Not run on the host:** all four lines.

### Prove the clone is inert

8. An edit in the clone must change nothing live:

   ```shell
   echo '# x' >> ~/dev/dotfiles/tilde/.zshenv
   ```

   Open a new Terminal window, type the opening block, then:

   ```shell
   r b4 grep -c '^# x$' ~/.zshenv
   git -C ~/dev/dotfiles checkout tilde/.zshenv
   ```

   `b4` passes when it prints `0`. Its exit code is 1, which is `grep` finding no line. **Not run on the host.**

### Roll back

9. Change one setting first, so the rollback meets an override file newer than the one it moved:

   ```shell
   rotm settings set updates.mac_password_op 'op://x/y/changed'
   ```

   Then run `MOVE.md` section 8, steps 1 to 5. If step 6 printed no REA warning, the `claude mcp remove` line of its step 4 fails and skips the add, which is harmless: run the `setup.sh` line after it all the same. Record the end:

   ```shell
   r b5 ~/dotfiles/bin/lib/rotm-mode
   r b6 eval 'inclone | wc -l; wc -l < "$KEEP/links.txt"; git -C "$CLONE" status --short; git -C "$COPY" status --short'
   r b7 rotm settings get updates.mac_password_op
   ```

   | Row | Passes when |
   | --- | --- |
   | `b5` | `clone` |
   | `b6` | Two counts, the first one less than the second, and nothing from git |
   | `b7` | `op://x/y/changed`: the setting changed after the move survived the rollback |

   **Not run on the host:** `rotm settings set` and `get`, and section 8's step 4.

10. **Tell the session** the rows are recorded. Shut the guest down when it says so.
