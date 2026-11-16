# P7: Promote `stable` and move the owner's Mac, Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `stable` holds everything P1 to P6 shipped, and the Mac this project is written on runs an install from it like any user's, with the clone at `~/dev/dotfiles` left for editing only.

**Architecture:** No product code changes. The plan is two runbooks and the runs that prove them. The first proves a fresh install on the candidate commit in the disposable guest, which is the gate for moving `stable`. The second is the hand move of a clone-based Mac to an installed copy, rehearsed in the guest before it is run once on the owner's Mac. The owner types every line in the guest and on the Mac. The session writes the runbooks, reads the records and updates the spec.

**Tech Stack:** mise 2026.11.8 or newer (the release current on the day of each guest run), UTM guest `macOS` (macOS 27.2.1, disposable runs), bash and zsh, Markdown.

**Spec:** `docs/superpowers/specs/2026-11-11-installable-setup-profiles-and-sync.md`. Read its Goal and "Decisions the owner made" in full before Task 1. Decisions 7, 9, 10 and 15 and the P7 brief bind this plan.

## Progress (2026-11-15)

| Task | State | Record |
| --- | --- | --- |
| 1. Promotion runbook and guest A | Done | `b80ff2f`, `2e0dbe9`, `73300a5`. Guest A passed on candidate `2e0dbe9` with mise 2026.11.8 (rows `a1` to `a8` in `~/vm-proof/p7/`, the spec's "Verified facts") |
| 2. Promote `stable` | Done | `stable` moved from `d09f025` to `73300a5` (`f3f18f1` records it) |
| 3. Move runbook | Done | `5d76cfa`, corrected by a review in `2e16095`. `MOVE.md` ends with what the scratch run changed from this plan |
| 4. Guest B | Done | `9ed4da0`, `02be67d`. Guest B passed on 2026-11-15 (rows `b0` to `b8` and `m1` to `m13` in `~/vm-proof/p7/`, `RUNBOOK.md` "Result", the spec's "Verified facts"). `stable` moved from `73300a5` to `02be67d` in step 7 |
| 5. Move the owner's Mac | Done on 2026-11-15 (`c953c79`, promoted to `stable` and brought here by `rotm update`) | `~/vm-proof/p7/mac/` (`move.log`, `m1` to `m13`), `MOVE.md` "What the move on the owner's Mac changed", the spec's "Verified facts" |
| 6. Close P7 and the spec | Not started | |

Differences from the plan as written:

- **`install.sh` was added before guest A** (`0a403c6`, `7363c2c`), on the owner's request for a one-line installer. Guest A ran it, with the guest's Command Line Tools removed first, so the run proved the tools install, the mise install and setup's prompts after a piped start. The README's install line is now `curl … /stable/install.sh | bash`. `MOVE.md` step 4 keeps the by-hand mise line, since `install.sh` would start setup before step 5.
- **The candidate was not `9e79b81`.** Guest A installs `main`'s head, so the candidate was the head once the runbook and `install.sh` had landed: `2e0dbe9`.
- **Task 2 Step 4's commit** is `f3f18f1`. `main` was ahead of `stable` by Markdown-only commits until guest B's step 7 promoted them.
- **Guest B ran `MOVE.md` from scripts,** after its typed lines failed in the owner's shell (`find` is `fd` there). The scripts are beside the rows in `~/vm-proof/p7/` and hold the runbook's lines. They are not in the repository, so that `main` stays a Markdown-only step from `stable` (decision 9). The owner chose the scripts for Task 5 too (2026-11-15): `~/vm-proof/p7/mac/move.zsh`, `rows.zsh` and `rollback.zsh`, reviewed and run in scratch homes (`MOVE.md`, "What the guest rehearsal changed"). Decision 15's "by hand" stands: they add no command to the product.

## Global Constraints

- Decision 15 and the P7 brief: the move is done once, by hand. No command, flag or `setup.sh` branch is added to the product for it, and it is not a path users get.
- Decision 9: a commit reaches `stable` only after the VM install passed on it, or it differs from such a commit in Markdown files only (`setup/README.md`, "Releasing to `stable`").
- Decision 10: each promotion is proven in the VM on the mise version current that day. The floor stays 2026.11.8 unless a guest run fails on a newer release.
- Never run on the owner's Mac without the owner's word: `sysup`, `./setup.sh`, `set-defaults`, `rotm install`, `rotm update`, `mise dotfiles apply`, the built app, `rotm settings sync …`. Task 5 is the owner's word for the lines of `MOVE.md` and nothing else. Never touch github.com/jrmatherly/rotm-settings.
- Moving `stable` is a push to a branch users follow. The owner runs it, or tells the session to. Tags and workflow runs are the owner's.
- The guest is always clean on start. Every guest run uses "Run without saving changes", begins with the tool check (`xcode-select -p`, `ls ~/.local/bin/mise`), answers `y` to setup's GitHub sign-in and `n` to loading saved settings.
- Push nothing to `main` while a guest that follows `main` is running (guest A): the app's dot and `update.behind` read it. Guest B follows `stable`, so Task 4's one push to `main` during it is allowed.
- Every line a runbook gives the owner was run by the session first in a scratch home through the same shell, with only paths changed, or is marked **Not run on the host**.
- The gate is `pnpm check`. Edit and commit in separate Bash calls. Commit subjects are short, imperative, sentence case.

## Measured for this plan (2026-11-15, this Mac, `main` at `4bc6f8d`, mise 2026.11.8)

| Fact | Evidence |
| --- | --- |
| `stable` is at `d09f025`, an ancestor of `main`, 206 commits behind | `git merge-base --is-ancestor origin/stable origin/main`, `git rev-list --count origin/stable..origin/main` |
| mise's newest release is 2026.11.8 (2026-11-13) | `gh api repos/jdx/mise/releases/latest` |
| This Mac is a clone install | `bin/lib/rotm-mode` prints `clone`. `~/dotfiles` links to `~/dev/dotfiles`, `~/.config/mise` to its `tilde/.config/mise`, and `~/.local/share/mise/bootstrap-repo` does not exist |
| This Mac's links are absolute paths into the clone, and a fresh apply writes them through `~/dotfiles` | `readlink ~/.zshrc` prints `/Users/jason/dev/dotfiles/tilde/.zshrc`, and the same for `~/.gitconfig`, `~/.zshenv`, `~/.config/gh`, `~/.config/fastfetch`, `~/.config/hunk` and `Code/User`. An older setup made them, and mise leaves an equivalent link alone. The newest, `~/.claude/rules/rtk.md`, reads `/Users/jason/dotfiles/…`, and in a scratch home every link a fresh apply made read `$HOME/dotfiles/…`. So a guest set up from a clone today does not have this Mac's shape |
| 46 links on this Mac resolve into the clone | The search of `MOVE.md` step 1, run read-only: it resolves each link, so it counts `~/dotfiles`, `rtk.md` and `~/.local/share/mise/plugins/vscode`, which a match on the link's text missed |
| `~/.config/fastfetch` is still one folder link on this Mac | `readlink`. No apply has run here since P6 changed the entry |
| This Mac has no `~/.config/rotm` | `ls -ld ~/.config/rotm`. `config.override.toml` and `config.local.toml` are real, git-ignored files in the clone's `tilde/.config/mise/`, because `setup.sh` has not run here since P3 |
| What this Mac keeps in the clone that git ignores and a fresh copy lacks | `git status --short --ignored`: the two mise files, `mole/whitelist.local`, `tilde/.config/gh/hosts.yml`, `tilde/.config/hunk/state.json`, and VS Code's `History`, `globalStorage`, `profiles`, `sync`, `workspaceStorage`, `agent-sessions.code-workspace` and the rendered `settings.json` under `vscode/User` (4.7 GB) |
| This Mac's Mole list is linked through `config.local.toml` | Its `[dotfiles]` entry has `source = "~/dotfiles/mole/whitelist.local"`, a path that will not exist in an installed copy |
| The install line refuses while `~/.config/mise` is a link | Scratch home, link to a clone's config dir: `mise ERROR ~/.config/mise is already a link; remove it to use --config-dir …`, exit 1, after cloning the copy. With the link removed first: `linked ~/.config/mise to ~/.local/share/mise/bootstrap-repo/tilde/.config/mise`, `saved env = ["rotm-installed"]`, exit 0, and `rotm-mode` in that home prints `installed` |
| `setup.sh` stops when `~/dotfiles` links elsewhere | `setup.sh:263-266` |
| `setup.sh`'s unlink step does not see this Mac's folder links | `setup.sh:369-379` removes a folder link only when it resolves inside the installed copy. This Mac's resolve inside the clone |
| A bare apply under `rotm-installed` on a clone-shaped home is not enough | Scratch home, `~/dotfiles` repointed to a second checkout, one `mise dotfiles apply`: `~/.zshrc`, `~/.gitconfig`, `~/.config/gh` and `Code/User` stayed links, and `jstack-models.md` was missing |
| The hand steps of Task 3 end in the right state | Scratch home shaped like this Mac (absolute links into checkout A), state written through the folder links, the six links and `~/dotfiles` removed, `~/dotfiles` pointed at checkout B, two applies: `~/.zshrc` equals `tilde/.zshrc.installed`, `~/.gitconfig`, `~/.config/gh`, `Code/User` and `jstack-models.md` are real, the carried `hosts.yml` and VS Code state are there, and `git status` is empty in both checkouts |
| Nothing in `/usr/local/bin` points into the clone | `ls -l /usr/local/bin`: OrbStack's links and git-credential-manager only |
| A per-file link left behind still points into the clone | Same run: `~/.config/fastfetch/config.jsonc`, the one link not removed by hand, still pointed into checkout A. So `~/.config/fastfetch` is on the removal list, and the move ends with a search for links into the clone |
| Four scripts resolve the repository from their own path, and nine read `$DOTFILES` first | Own path (`DOTFILES_DIR`, which no shell exports): `claude-config:50`, `claude-catalog:25`, `claude-stack:42`, `vscode-settings:39`. `$DOTFILES` first: `obsidian-vault:21`, `rotm:45`, `sysup:18`, `set-defaults:36`, `dotfiles-settings:44`, `sync-all:16`, `dotfiles:17`, `nyan:15`, and `bin/lib/get-tldr-md:19` behind `help`. Run by path from the clone after the move, the second group acts on the copy |
| Setup offers to load saved settings on a Mac with gh signed in and no origin connected | `setup.sh:505-527`: when `<login>/rotm-settings` is private and holds `.mise-history/format.toml`, it asks `Load your saved settings from … before installing? [Y/n]`, and Enter loads them. The P5 guests left test values in that repository (spec, the sync row of "Verified facts") |
| Setup does not repair an MCP registration that names the clone | `setup/misc.sh:190-216`: `register_mcp` warns that a server "is registered differently", prints the `claude mcp remove` and `add` line, and returns. `claude mcp get rea` here prints `Command: /Users/jason/dev/dotfiles/bin/rea-mcp` (the reviewer's run) |
| mise's vscode plugin is a link into the clone | `readlink ~/.local/share/mise/plugins/vscode` prints `/Users/jason/dev/dotfiles/mise-plugins/vscode`. `setup.sh:499` links it again from the copy, but not under `-- --skip packages` |
| The gate followed the shell's `$DOTFILES` | `DOTFILES=<an empty folder> bash bin/lib/test-conventions` failed with `FAIL: help render: bin/check-port`. Fixed with this review: the self-check now exports its own tree as `DOTFILES`, and the same command passes |
| What setup will install on this Mac | The reviewer's read-only status calls: `jrmatherly/tap/returnofthemac-app` is the one missing package, and `mise ls --missing` is empty. So the move installs the menu bar app and opens it once |
| `$DOTFILES` follows `~/.zshenv`'s link | `tilde/.zshenv:5`: `${${(%):-%x}:A:h:h}`. Once the link points into the copy, a new shell exports the copy |

Not measured: a full `setup.sh` run on a clone-shaped home that was moved (Task 4 runs it in the guest), whether `sysup` and the menu bar app behave on this Mac after the move (Task 5's checks), and an update across the 206 commits from `d09f025` (no copy outside the guest ever followed `stable`, decision 15, so no run is planned).

## Decided while writing this plan

- **Two guest runs, not three.** Guest A is a fresh install from `main` at the candidate, which is decision 9's gate. Guest B rehearses the move and uses the README's own line with `ref=stable`, so the stable line and a `rotm update` across a promotion are proven there. The README's line from a fresh home on `stable` is not run as its own guest: it differs from guest A's in the ref only.
- **The Mole list moves out of the checkout.** `~/.config/mole/whitelist.local`, with the `config.local.toml` entry pointed at it, as `docs/mole.md` now tells an installed user. Not into `~/.config/rotm`, where sync refuses a file it does not know.
- **VS Code's state is moved, not copied.** It is 4.7 GB. `mv` within one volume is instant, and the rollback moves it back.
- **The two runbooks live beside the spec**, in `docs/superpowers/specs/2026-11-15-p7-move/`, as the P5 proof's do. Records go to `~/vm-proof/p7/` on the host through the shared folder.
- **No new proof script.** The rows are few, so each records plain command output with one shell function the runbook defines.
- **The carried files move, they are not copied.** A copy left behind in the clone made the rollback stop: `rotm-user-layer ensure` exits 1 when the clone's config dir and `~/.config/rotm` hold different copies of one file (the reviewer's scratch run). After a rollback the clone reads `~/.config/rotm` through a link, which is the layout a clone has had since P3.
- **Guest B is reshaped before the rehearsal,** to this Mac's shape, since a fresh clone install does not have it (see "Measured").
- **The standing cost is accepted, not designed around.** After the move, a change reaches this Mac's live config only through a promotion (decisions 9 and 15). The clone-only commands the owner still needs are run by path. `MOVE.md` lists them.

## Review Focus

1. **The install line fails half way.** mise clones the copy and then refuses at the `~/.config/mise` link, leaving a copy and no config. `MOVE.md` removes the link first, and its rollback covers a stop at any step.
2. **Something still points into the clone after the move.** A link, the REA registration or mise's vscode plugin. An edit in the clone is then live without a promotion, which breaks the brief's third "Done when". The move ends with a search that resolves every link and must print nothing, and with a registration check.
3. **State the clone held is lost.** gh's sign-in, 4.7 GB of VS Code history and storage, this Mac's settings and its Mole list are git-ignored files in the clone. Each has a carry step and a check after setup.
4. **The shell breaks mid-move.** `~/.zshrc` is removed before setup seeds the wrapper. The runbook keeps one Terminal window open for the whole move and opens no new shell until the check step says to.
5. **Setup's default answer loads the guests' test settings.** One Enter at "Load your saved settings" would switch the Kubernetes module off and change the Dock on the owner's Mac. `MOVE.md` step 6 names every question setup asks and its answer.
6. **A newer mise breaks the fresh install.** mise ships almost daily and the floor is two days old. Guest A runs on the release current that day, and a failure there stops the promotion.

---

### Task 1: Write the promotion runbook and prove the candidate (guest A)

**Files:**
- Create: `docs/superpowers/specs/2026-11-15-p7-move/RUNBOOK.md`
- Modify: `docs/superpowers/specs/2026-11-11-installable-setup-profiles-and-sync.md` ("Verified facts")

**Interfaces:**
- Produces: the candidate, a full commit hash on `main` that Task 2 promotes, written in the runbook's first line. The runbook's record function, which `MOVE.md` and guest B reuse. `P7` is the record folder: the shared folder in a guest, `~/vm-proof/p7/mac` on the owner's Mac. Both lines are typed again in every new Terminal window:

  ```shell
  P7="/Volumes/My Shared Files/vm-proof/p7"
  r() { local row=$1; shift; { "$@"; echo "exit $?"; } > "$P7/$row.txt" 2>&1; tail -3 "$P7/$row.txt"; }
  ```

- [ ] **Step 1: Fix the candidate.** `git rev-parse origin/main`, with `main` clean and `check.yml` green on it (`gh run list --workflow check.yml --limit 1`). Record the mise release current that day (`gh api repos/jdx/mise/releases/latest --jq .tag_name`).
- [ ] **Step 2: Write `RUNBOOK.md`, section "Guest A".** Numbered steps in the form of the P5 runbook (`docs/superpowers/specs/2026-11-14-p5-vm-proof/RUNBOOK.md`, steps 3 to 7): start the guest disposable, check the two tools, `mkdir -p` the record folder, run the install line with `?ref=main`, answer setup, reopen Terminal, define `r`. Then these rows:

  | Row | Command | Passes when |
  | --- | --- | --- |
  | `a1` | `r a1 git -C ~/.local/share/mise/bootstrap-repo rev-parse HEAD` | It prints the candidate |
  | `a2` | `r a2 ~/dotfiles/bin/lib/rotm-mode` | `installed` |
  | `a3` | `r a3 rotm settings status --json` | `"mode": "installed"` (the JSON is indented, `cli.py:129`) and the candidate's short hash |
  | `a4` | `r a4 mise --version` | The release recorded in Step 1 |
  | `a5` | `r a5 git -C ~/.local/share/mise/bootstrap-repo status --short` | Nothing but `exit 0`, after opening VS Code, lazygit and fastfetch once and running `gh config set editor vim` |
  | `a6` | `r a6 fastfetch --version` then `r a6b ls -lR ~/.config/fastfetch` | `config.jsonc` is a regular file and `ascii` holds links (P6 Task 2, first real install) |
  | `a7` | `r a7 rotm update --check` | `Up to date.` |

  Setup must end with "All done" (exit 0) or list only package failures the owner accepts by name. The run ends with shutting the guest down.
- [ ] **Step 3: Check the lines on the host.** Run each row's command in a scratch home or read-only on this Mac, and mark the install line and `setup.sh` **Not run on the host**.
- [ ] **Step 4:** `pnpm check`, commit: "Write the P7 promotion runbook". Push, then wait for `check.yml` before the owner starts, and fix the candidate at that commit if the runbook's commit is to be included (it changes Markdown only, so either is allowed).
- [ ] **Step 5: The owner runs guest A.** The session reads `~/vm-proof/p7/a*.txt` and compares each with its "Passes when".
- [ ] **Step 6: Record the result** as rows of "Verified facts" in the spec: the candidate, the mise version, and what `a5` and `a6` showed. A failed row stops here: fix it on `main`, take a new candidate and run guest A again. Commit: "Record the P7 fresh install on the candidate".

### Task 2: Promote `stable`

**Files:**
- Modify: `setup/README.md` ("Releasing to `stable`": the rows are in this plan's runbook, not the P1 plan)
- Modify: the spec ("Where we are" is unchanged; "Plans" and the P7 brief gain the promotion)

**Interfaces:**
- Consumes: Task 1's candidate, with every row passed.
- Produces: `origin/stable` at the candidate or at a later commit that differs from it in Markdown only. Task 4 and Task 5 install from it.

- [ ] **Step 1: Confirm the diff rule.** `git diff --name-only <candidate> origin/main | grep -v '\.md$'` prints nothing. If it prints a file, promote the candidate itself.
- [ ] **Step 2: The owner promotes,** or tells the session to:

  ```shell
  git push origin "<sha>:refs/heads/stable"
  ```

  It is a fast-forward: `stable` is an ancestor of `main`. No `--force`.
- [ ] **Step 3: Verify.** `git fetch origin && git rev-parse origin/stable` prints `<sha>`, and `git rev-list --count origin/stable..origin/main` prints the number of Markdown-only commits left, or 0.
- [ ] **Step 4: Correct `setup/README.md`'s pointer and the spec,** `pnpm check`, commit: "Promote stable to the P6 tree". The body names both hashes.

### Task 3: Write the move runbook

**Files:**
- Create: `docs/superpowers/specs/2026-11-15-p7-move/MOVE.md`

**Interfaces:**
- Consumes: `r` from Task 1.
- Produces: `MOVE.md`, with the sections below in this order. Task 4 runs it in the guest and Task 5 on the owner's Mac. `CLONE` is the clone's path (`~/dev/dotfiles` on both), `COPY` is `~/.local/share/mise/bootstrap-repo`, and `KEEP` is `~/rotm-move-keep`.

The runbook's content, decided here. Each numbered item is one step with its command and the output that means it worked.

**Before.** `main` clean and pushed, `stable` promoted, VS Code, Obsidian and every Claude Code session quit, one Terminal window open and no other shell. `git -C "$CLONE" status --short` prints nothing. The runbook opens with the block every Terminal window needs, typed again in step 7's new window:

  ```shell
  CLONE=~/dev/dotfiles COPY=~/.local/share/mise/bootstrap-repo KEEP=~/rotm-move-keep A="$HOME/Library/Application Support"
  P7=~/vm-proof/p7/mac   # in the guest: "/Volumes/My Shared Files/vm-proof/p7"
  r() { local row=$1; shift; { "$@"; echo "exit $?"; } > "$P7/$row.txt" 2>&1; tail -3 "$P7/$row.txt"; }
  # every link in the folders setup links into whose resolved target is inside the clone
  inclone() { find ~ ~/.config ~/.claude ~/.claude/rules ~/.claude/skills ~/.codex ~/.ssh ~/.gnupg ~/.config/mole ~/.local/share/mise/plugins "$A/Code" "$A/lazydocker" "$A/rtk" -maxdepth 1 -type l 2> /dev/null | sort -u | while IFS= read -r l; do case "$(realpath "$l" 2> /dev/null)" in "$CLONE" | "$CLONE"/*) echo "$l" ;; esac; done; }
  ```

  `inclone` resolves each link, so it finds a link through `~/dotfiles` as well as an absolute one. The folders are the ones `40-dotfiles.toml` and the module fragments name a target in, plus mise's plugin folder. A new entry in another folder adds its folder here.

**1. Record the start,** so the rollback has a list: `mkdir -m 700 "$KEEP" && mkdir -p "$P7" && inclone > "$KEEP/links.txt"`. On the owner's Mac it lists 46 links today (measured read-only on 2026-11-15).

**2. Move what git ignores out of the clone.** Each is `mv`, so the clone keeps no stale copy for the rollback to trip on, and modes are kept (`hosts.yml` is the owner's sign-in):

  | From the clone | To |
  | --- | --- |
  | `tilde/.config/mise/config.override.toml` | `~/.config/rotm/config.override.toml` (after `mkdir -p ~/.config/rotm`). Skipped when `~/.config/rotm` already holds it and the clone's is a link, as on a clone set up after P3 |
  | `tilde/.config/mise/config.local.toml` | `$KEEP/config.local.toml`, then its Mole entry's source edited to `~/.config/mole/whitelist.local` |
  | `mole/whitelist.local` | `~/.config/mole/whitelist.local` |
  | `tilde/.config/gh/hosts.yml` | `$KEEP/hosts.yml` |
  | `tilde/.config/hunk/state.json` | `$KEEP/state.json` |

  From here until step 6 ends, `gh`, mise's own settings and the Mole list are not where their tools look. That is why nothing else runs during the move.

**3. Remove the links the installed copy replaces.** Each is a link, so `rm` removes no file: `~/dotfiles`, `~/.config/mise`, `~/.zshrc`, `~/.gitconfig`, `~/.config/gh`, `~/.config/fastfetch`, `~/.config/mole/whitelist`, `~/.claude/rules/jstack-models.md` and `$A/Code/User`. The step checks each with `[ -L ]` first and stops at one that is not a link. `~/.config/fastfetch` is one folder link on this Mac. It is on the list because the installed copy seeds a file inside it.

**4. Fetch the copy.** The mise half of the README's install line, with `ref=stable`. Expected: `linked ~/.config/mise to …/bootstrap-repo/tilde/.config/mise` and `saved env = ["rotm-installed"]`. Then `mv "$KEEP/config.local.toml" ~/.config/mise/config.local.toml`, which lands in the copy's config dir, where git ignores it.

**5. Make the real folders and put the state back.** `mkdir -m 700 ~/.config/gh && mv "$KEEP/hosts.yml" ~/.config/gh/`. `mkdir -p -m 700 "$A/Code/User"`, then `mv` each of `History`, `globalStorage`, `profiles`, `sync`, `workspaceStorage` and `agent-sessions.code-workspace` from `$CLONE/vscode/User` into it. The rendered `settings.json` and `.settings.rendered` stay behind: setup renders both again.

**6. Run setup from the copy:** `~/.local/share/mise/bootstrap-repo/setup.sh`. Its questions on this Mac, and the answers:

  | Setup asks | Answer |
  | --- | --- |
  | `Press Enter key to continue…` | Enter |
  | `Load your saved settings from jrmatherly/rotm-settings before installing? [Y/n]` | **`n`**. The repository holds the P5 guests' test values. It appears only if the repository still exists |
  | The password, once | The login password |
  | The VS Code font preset | Enter, which keeps the saved one |
  | Git identity and signing | Not asked: `~/.gitconfig.local` exists |

  It links `~/dotfiles` to the copy, seeds the wrappers and the copies, repoints every other link, installs the one missing package (the menu bar app) and opens it. It also warns that the REA server "is registered differently" and prints the line that fixes it. Run that line: `claude mcp remove rea -s user && claude mcp add --scope user rea -- ~/.local/share/mise/bootstrap-repo/bin/rea-mcp`, in the exact form the warning prints. Then `mv "$KEEP/state.json" ~/.config/hunk/state.json`, which is git-ignored in the copy.

**7. Check, in a new Terminal window,** after typing the opening block again. Each line through `r`:

  | Row | Command | Passes when |
  | --- | --- | --- |
  | `m1` | `~/dotfiles/bin/lib/rotm-mode` | `installed` |
  | `m2` | `echo $DOTFILES` | The copy's path |
  | `m3` | `inclone` | No line |
  | `m4` | `git -C "$COPY" status --short` and `git -C "$CLONE" status --short` | Neither prints a line |
  | `m5` | `mise dotfiles status --missing` | Exit 0 |
  | `m6` | `cmp ~/.zshrc "$COPY/tilde/.zshrc.installed"` and `[ ! -L ~/.gitconfig ]` | Exit 0 for both |
  | `m7` | `gh auth status` | Signed in |
  | `m8` | `rotm settings status` | Mode `installed`, branch `stable`, sync not connected |
  | `m9` | `readlink ~/.config/mole/whitelist` | `~/.config/mole/whitelist.local`, expanded |
  | `m10` | `git config --get user.email` in the clone | The owner's, read through the wrapper and `~/.gitconfig.local` |
  | `m11` | `claude mcp list` | No server's command names the clone |
  | `m12` | `rotm settings get updates.mac_password_op` | The value this Mac had, read from `~/.config/rotm` |

  Then open VS Code and see the recent folders, and see "Setup: up to date" in the menu bar app. The owner also checks their own files, which the session may not read: `grep -l dev/dotfiles ~/.zsh.local ~/.gitconfig.local ~/.ssh/config.local` should print nothing, or each hit is a path the owner means to keep.

**8. Roll back,** from any step, with VS Code quit. In this order:

  1. Move `~/.config/mise/config.local.toml` to `$KEEP` if step 4 placed it, then remove what the move made: the links `~/dotfiles` and `~/.config/mise`, the seeded `~/.zshrc`, `~/.gitconfig` and `~/.claude/rules/jstack-models.md` (each only while it still equals the file the copy seeded, otherwise it is kept aside in `$KEEP`), and `~/.config/fastfetch`.
  2. Move back into `$CLONE/vscode/User` everything in the real `Code/User` except `keybindings.json`, `tasks.json`, `chatLanguageModels.json`, `snippets`, `settings.json` and `.settings.rendered`, so what VS Code wrote since step 7 is kept. Then remove the real folder. Move `hosts.yml` back to `$CLONE/tilde/.config/gh/` and remove the real `~/.config/gh`. Move `state.json` and `config.local.toml` back to their places in the clone.
  3. Restore the two links by hand: `ln -s "$CLONE" ~/dotfiles` and `ln -s "$CLONE/tilde/.config/mise" ~/.config/mise`.
  4. `mise plugins link --force vscode "$CLONE/mise-plugins/vscode"`, which `-- --skip packages` would skip, and the REA line with the clone's path.
  5. `"$CLONE/setup.sh" -- --skip packages`, answering `n` to the saved-settings question. It links `config.override.toml` from `~/.config/rotm`, which stays, and relinks the rest.
  6. Check: `"$CLONE/bin/lib/rotm-mode"` prints `clone`, `inclone | wc -l` prints the count of `links.txt` less the links a module switch removed, `mise dotfiles status --missing` exits 0, and `git status --short` is empty in the clone. The links now read `~/dotfiles/…`, so the check compares resolved targets, not text.

  The copy is left in place: a clone ignores it.

**9. Living with both.** A table for the owner. `$DOTFILES` is the copy in every shell, so a clone script that reads it must be told otherwise:

  | To | Run |
  | --- | --- |
  | Edit, check and commit | In `~/dev/dotfiles`, as before. `pnpm check` checks the clone's tree whatever `$DOTFILES` says (fixed with this plan's review) |
  | Read a changed script's help | `DOTFILES=~/dev/dotfiles help <name>`. A bare `help` renders the copy's header |
  | Try a changed script before promoting | `DOTFILES=~/dev/dotfiles ~/dev/dotfiles/bin/<name>`. With it set, `rotm-mode` reads `clone`, so `set-defaults` and `dotfiles-settings` would write the clone's tracked files while mise still reads the copy's config: use them from the copy only |
  | Record this Mac's Claude Code setup | `~/dev/dotfiles/bin/claude-config save`, which resolves its own path. `sysup` no longer saves on this Mac. `claude-catalog`, `claude-stack` and `vscode-settings` by path act on the clone the same way |
  | Bring Obsidian settings back to the repository | `DOTFILES=~/dev/dotfiles ~/dev/dotfiles/bin/obsidian-vault capture`. Without the variable it writes into the copy and `rotm update` then stops |
  | Make a change live | Push to `main`, promote (`setup/README.md`), then `rotm update` |

  And three things that changed: never edit through `~/.claude/rules/*`, `~/.config/<app>` or `~/.config/mole/whitelist_optimize`, which are links into the copy. `~/.claude/rules/jstack-models.md` is this Mac's own file now, so `/jstack:setup-jstack` no longer changes the tracked one. `sysup`'s and setup's logs land in the copy's git-ignored `logs/` and `private/`.

- [ ] **Step 1: Write `MOVE.md`** from the content above, with every command spelled out and its expected output.
- [ ] **Step 2: Run steps 1 to 3 and 5 to 8 in a scratch home** shaped like this Mac, as this plan's measurement did (two local checkouts, absolute links, a folder link for fastfetch, the override file in the first checkout's config dir, `mise dotfiles apply` under `MISE_ENV=rotm-installed` standing in for steps 4 and 6). Expected: rows `m3`, `m4` and `m6` pass. Then change one line of `~/.config/rotm/config.override.toml`, as a setting changed after the move would, and run the rollback: `rotm-user-layer ensure` from the first checkout exits 0, every path of `links.txt` resolves into the first checkout again, and `git status` is empty in both. Mark steps 4 and 6 **Not run on the host**.
- [ ] **Step 3: Check section 9's commands** read-only, from a shell whose `$DOTFILES` is a second checkout: `~/dev/dotfiles/bin/claude-config restore --dry-run` names the clone's `agents/`, and `DOTFILES=~/dev/dotfiles help rotm` renders the clone's header.
- [ ] **Step 4:** `pnpm check`, commit: "Write the runbook for moving a clone to an installed copy".

### Task 4: Rehearse the move in the guest (guest B)

**Files:**
- Modify: `docs/superpowers/specs/2026-11-15-p7-move/RUNBOOK.md` (section "Guest B")
- Modify: `docs/superpowers/specs/2026-11-15-p7-move/MOVE.md` (what the rehearsal corrects)
- Modify: the spec ("Verified facts")

**Interfaces:**
- Consumes: Task 2's `stable`, Task 3's `MOVE.md`.
- Produces: `MOVE.md` as run in the guest, and a second promotion that Task 5 does not repeat.

- [ ] **Step 1: Write section "Guest B".** A disposable guest set up from a clone: `git clone https://github.com/jrmatherly/returnofthemac.git ~/dev/dotfiles` and `~/dev/dotfiles/setup.sh`, the GitHub sign-in answered `y` and the saved-settings question `n`. Then make the state a used Mac has: open and quit VS Code, `dotfiles-settings set updates.mac_password_op 'op://x/y/z'`, a `mole/whitelist.local` with one line and its `config.local.toml` entry, then `mise dotfiles apply`.
- [ ] **Step 2: Add the reshaping step,** which gives the guest this Mac's shape. A fresh clone install links through `~/dotfiles`, has a real `~/.config/fastfetch` and keeps the override file in `~/.config/rotm`, and none of that is true here. The step, written out in the runbook and run first in a scratch home: rewrite every link `inclone` lists, except `~/dotfiles`, to its resolved absolute path (`ln -sfn "$(realpath "$l")" "$l"`); replace `~/.config/fastfetch` with one link to `$CLONE/tilde/.config/fastfetch`; move `~/.config/rotm/config.override.toml` over its link in the clone's config dir and remove `~/.config/rotm`. Rows: `r b0 ~/dotfiles/bin/lib/rotm-mode` prints `clone`, and `r b0b sh -c 'find ~ ~/.config -maxdepth 1 -type l -lname "$HOME/dev/dotfiles/*" | wc -l'` prints 20 or more, which is what shows the links are absolute.
- [ ] **Step 3: The owner runs `MOVE.md` in the guest,** steps 1 to 7. The session reads `m1` to `m12`. `m11` passes there only if the guest has Claude Code signed in, and is skipped otherwise, with the REA line read off setup's warning.
- [ ] **Step 4: Prove an update across a promotion.** With the guest still up (it follows `stable`, so this push to `main` is the one the Global Constraints allow), the session pushes one Markdown-only commit to `main` (the record of Task 1 if it is not yet promoted, or a line in the plan index), and the owner promotes it as in Task 2. In the guest: `r b1 rotm update --check` prints `1 update is waiting…` or the count, `rotm update`, then `r b2 git -C ~/.local/share/mise/bootstrap-repo rev-parse HEAD` prints the new `stable` and `r b3 rotm update --check` prints `Up to date.`
- [ ] **Step 5: Prove the clone is inert.** In the guest: `echo '# x' >> ~/dev/dotfiles/tilde/.zshenv`, open a new Terminal window, `r b4 grep -c '^# x$' ~/.zshenv` prints 0, then `git -C ~/dev/dotfiles checkout tilde/.zshenv`.
- [ ] **Step 6: Run the rollback** (section 8), after changing one setting with `rotm settings set`, so the rollback meets a newer override file. Then `r b5 ~/dotfiles/bin/lib/rotm-mode` prints `clone` and section 8's check passes. Shut the guest down.
- [ ] **Step 7: Correct `MOVE.md`** for every step that did not go as written, and record the rehearsal in "Verified facts". A step that failed and has no fix stops the plan before Task 5. `pnpm check`, commit: "Record the move rehearsal and correct its runbook".

### Task 5: Move the owner's Mac

**Files:**
- Modify: `docs/superpowers/specs/2026-11-15-p7-move/MOVE.md` (the link count, and what the real run corrects)

**Interfaces:**
- Consumes: `MOVE.md` as corrected by Task 4, and `stable` at the commit Task 4 promoted.

- [ ] **Step 1: The owner gives the word,** names a time with nothing else running on the Mac, and confirms a Time Machine or other backup of `~/dev/dotfiles` exists (it holds 4.7 GB of VS Code state that the move relocates). The session does not start this task from a handoff alone.
- [ ] **Step 2: The owner runs `MOVE.md`,** steps 1 to 7, in one Terminal window, from `~/vm-proof/p7/mac/move.zsh` and then `rows.zsh` in a new window, answering `n` at "Load your saved settings". Records go to `~/vm-proof/p7/mac/`. The session reads them from a Claude Code session started after step 7, since step 3 removes the links the running one uses.
- [ ] **Step 3: After the checks, the owner runs `sysup` once** and the session reads its summary: the dotfiles step reads `installed copy: run rotm update`, the Claude config step reads `installed copy: not saved into it`, and no step fails that passed on the clone.
- [ ] **Step 4: Prove the brief's "Done when" on this Mac.** `rotm-mode` prints `installed` (`m1`). A new `stable` commit arrives with `rotm update`: promote the next Markdown-only commit, here Step 5's, and run it. An edit in `~/dev/dotfiles` changes nothing live: Task 4's Step 5, run here, and `m3` and `m11` passed.
- [ ] **Step 5: Record the move** in the spec and correct `MOVE.md`. Commit from the clone: "Record the owner's Mac moving to stable".

### Task 6: Close P7 and the spec

**Files:**
- Modify: the spec ("Plans", the P7 brief's "Shipped" line, decision 7's last sentence stays as written)
- Modify: `docs/superpowers/plans/README.md`
- Modify: `CLAUDE.md` and `.claude/rules/*.md`, only the statements the move made false. Known today: "The repo is the source of truth. Everything is symlinked into `$HOME` and configured by editing files in the clone" (`CLAUDE.md`, Overview), "`help <bin-script>`: … Use it to verify new or edited `bin/` scripts" (it renders the copy's header unless `DOTFILES` names the clone), `~/dotfiles` "must be a symlink to the clone or, on an installed copy, to mise's checkout" stays true, and the standing approval in "Custom Notes" stays true
- Modify: `~/.claude/projects/-Users-jason-dev-dotfiles/memory/`, the memory that says which commands never run on this Mac, if the owner changes that list
- Move: this file to `docs/superpowers/plans/completed/`, and the spec with its probe folders to `docs/superpowers/specs/completed/`, since every plan built on it is then finished

- [ ] **Step 1: Run the `docs-audit` skill** over `CLAUDE.md`, `.claude/rules/` and `setup/README.md` with one question added: does any line describe this Mac as a clone install, or tell an agent that an edit in the clone is live?
- [ ] **Step 2: Re-check each finding** against the file it cites, and fix what holds.
- [ ] **Step 3: Write the Outcome table** at the top of this plan (task, commit or record, difference from the plan), update the spec and the index, and move the files. `pnpm check` (the link check follows the moved spec's links), commit: "File the finished P7 plan and the installable-setup spec".

## Not in this plan

- **Automatic promotion,** a `promote` command or a CI gate on `stable`. Decision 9 keeps it a hand step after a VM run.
- **A guard in `obsidian-vault capture` or Mole's whitelist editors** for an installed copy. Both are in the plan index. After the move the owner's Mac is the first Mac they can bite, and section 9 of `MOVE.md` is the answer until one is built.
- **Renaming `dotfiles-settings`, `$DOTFILES` and the clone's folder.** No brief owns it.
- **An update from `d09f025`.** No copy outside the guest followed `stable` before this promotion.
- **Automatic sync and Linux.**

## Review of this plan (2026-11-15)

One independent reviewer read the first version (`82c7a8b`) against the spec, the owner's decisions and the code, read-only, and rebuilt the move in scratch homes on mise 2026.11.8. Each finding below was checked against the source it cited before the plan changed.

| Finding | Change |
| --- | --- |
| Setup asks "Load your saved settings … [Y/n]" on the owner's Mac, Enter loads the P5 guests' test values, and the runbook did not say what to answer (`setup.sh:505-527`) | Step 6 lists every question setup asks here and its answer. It is the fifth Review Focus line |
| A guest set up from a clone does not have this Mac's shape: mise writes links through `~/dotfiles`, fastfetch's folder is real and the override file is in `~/.config/rotm`. The link search printed nothing there, and step 3 would have stopped at fastfetch | Task 4 gains a reshaping step with a row that shows the links are absolute |
| Row `m11` could not pass: `register_mcp` only warns about a registration that names the clone (`setup/misc.sh:190-216`) | Step 6 runs the line the warning prints, and the rollback runs its reverse |
| After the move `pnpm check` in the clone rendered the copy's headers, and a new `bin/` script could not pass the gate (`bin/lib/test-conventions`, `bin/lib/get-tldr-md:19`) | Fixed in the code with this review: the self-check exports its own tree as `DOTFILES`. Reproduced failing before and passing after |
| Section 9's by-path commands acted on the copy for the nine scripts that read `$DOTFILES` first | Each such line carries `DOTFILES=~/dev/dotfiles`, with a warning for the two that would then write tracked files |
| The rollback stopped at `rotm-user-layer ensure` once a setting changed after the move, because step 2 left a stale copy in the clone | Step 2 moves the files. Task 3 Step 2 and Task 4 Step 6 change a setting before rolling back |
| The rollback's check compared link text, which cannot match once mise recreates the links through `~/dotfiles` | `inclone` resolves every link, and steps 1, 7 and 8 use it |
| `~/.local/share/mise/plugins/vscode` links into the clone and was in no list, and a rollback under `-- --skip packages` left it on the copy | It is in `inclone`'s folders and has a line in the rollback |
| `r` wrote to the guest's shared folder, which the owner's Mac does not have, and a new window had none of the variables | `P7` names the folder, and the opening block is typed again in step 7 |
| The rollback removed the real `Code/User` with whatever VS Code wrote after step 7 | It moves back everything but the seeded and rendered files |
| Task 4 pushed to `main` during a guest run, against a Global Constraint | The constraint names guest A, and the step says why guest B is exempt |
| Smaller: `hosts.yml` copied at mode 644, `"mode":"installed"` without the JSON's space, `ls -l` not showing the logo links, "each rule" (one rule links through `~/dotfiles`), the reason fastfetch is on the removal list, the one package setup will install, and three things section 9 left out | Each corrected where it sat |

The reviewer re-measured the plan's central claim and it held: on a home shaped like this Mac the hand steps ended with the wrappers seeded, the folders real, the state carried and both checkouts clean, after one apply.

Not verified by the review or by me: whether `jrmatherly/rotm-settings` still exists (the plan forbids touching it, and step 6's answer is right either way), the owner's `~/.zsh.local`, `~/.gitconfig.local`, `~/.ssh` and `~/.claude.json`, which neither of us may read, the commands of MCP servers other than `rea`, and a real `setup.sh` run from the copy, which guest B is the first to make.

