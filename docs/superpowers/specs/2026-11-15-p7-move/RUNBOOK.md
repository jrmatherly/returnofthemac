# P7 guest runs: runbook (2026-11-15)

Candidate: the commit on `main` that adds this file. It changes Markdown only and its parent is `9e79b810172bf03bd094fb9069664ed6ce40d15e`, whose `check.yml` run passed (43743597226). The session gives you its full hash when it hands this runbook over, and row `a1` must print it. mise for this run: 2026.11.8, the newest release on 2026-11-15 (`gh api repos/jdx/mise/releases/latest`).

This run proves a fresh install from `main` at the candidate in the disposable UTM guest. It is the gate for moving `stable` (decision 9 of `docs/superpowers/specs/2026-11-11-installable-setup-profiles-and-sync.md`), run on the mise release current that day (decision 10). It is P7 plan Task 1 (`docs/superpowers/plans/2026-11-15-p7-stable-and-the-owners-mac.md`).

How it works:

- You type each line in the guest's Terminal. Each `r <row> …` line runs one command and records what it printed, and its exit code, into `~/vm-proof/p7/<row>.txt` on the host. It shows you the last three lines.
- The session reads every record on the host and compares it with the row's "Passes when". Tell the session when you reach a step marked **Tell the session**, and whenever something on screen looks wrong.
- Every line was run on the host first, in a scratch home through the same shell, with only the record folder and the home folder changed, except where a step says **Not run on the host**.
- Push nothing to `main` from the first step to the last: the guest follows `main`, and row `a7` reads it.

## Guest A

1. In UTM, start the macOS guest with **Run without saving changes**.
2. In the guest's Terminal, check the two tools the install needs:

   ```shell
   xcode-select -p
   ```

   It prints a folder. When it says the tools are missing, run `xcode-select --install` and wait for it to finish. Then:

   ```shell
   ls ~/.local/bin/mise
   ```

   When that file is missing, run `curl https://mise.run | sh`. Then `~/.local/bin/mise --version` should print 2026.11.8 or the newer release the session named at handoff. **Not run on the host:** the two installers.

3. Make the record folder:

   ```shell
   mkdir -p "/Volumes/My Shared Files/vm-proof/p7"
   ```

4. Run the install line, from `main`, where the candidate is:

   ```shell
   ~/.local/bin/mise -E rotm-installed bootstrap --from 'https://github.com/jrmatherly/returnofthemac.git?ref=main' --config-dir tilde/.config/mise --save-env --only final-hook && ~/.local/share/mise/bootstrap-repo/setup.sh
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

   It takes a while. Setup must end with `All done!`. If it lists failed packages instead, **Tell the session** their names: the session decides with you whether each is accepted. **Not run on the host:** `setup.sh`. The mise half ran in a scratch home on 2026-11-15: it cloned `main`, printed `linked ~/.config/mise to ~/.local/share/mise/bootstrap-repo/tilde/.config/mise` and `saved env = ["rotm-installed"]`.

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
   lazygit
   ```

   Press `q` to leave it. Then:

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

On the scratch copy of `9e79b81` on 2026-11-15, rows `a1` to `a5` and `a7` passed through the same `r`, with `DOTFILES` set to the copy because no setup had run: `a1` printed the hash, `a2` `installed`, `a3` `"mode": "installed"`, `"branch": "main"`, `"commit": "9e79b81"`, `a4` `2026.11.8 macos-arm64 (2026-11-13)`, `a5` only `exit 0`, and `a7` `Up to date.`

## Guest B

Written in Task 4, after `stable` is promoted.
