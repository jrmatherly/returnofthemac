# P7: Promote `stable` and move the owner's Mac, Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `stable` holds everything P1 to P6 shipped, and the Mac this project is written on runs an install from it like any user's, with the clone at `~/dev/dotfiles` left for editing only.

**Architecture:** No product code changes. The plan is two runbooks and the runs that prove them. The first proves a fresh install on the candidate commit in the disposable guest, which is the gate for moving `stable`. The second is the hand move of a clone-based Mac to an installed copy, rehearsed in the guest before it is run once on the owner's Mac. The owner types every line in the guest and on the Mac. The session writes the runbooks, reads the records and updates the spec.

**Tech Stack:** mise 2026.11.8 or newer (the release current on the day of each guest run), UTM guest `macOS` (macOS 27.2.1, disposable runs), bash and zsh, Markdown.

**Spec:** `docs/superpowers/specs/2026-11-11-installable-setup-profiles-and-sync.md`. Read its Goal and "Decisions the owner made" in full before Task 1. Decisions 7, 9, 10 and 15 and the P7 brief bind this plan.

## Global Constraints

- Decision 15 and the P7 brief: the move is done once, by hand. No command, flag or `setup.sh` branch is added to the product for it, and it is not a path users get.
- Decision 9: a commit reaches `stable` only after the VM install passed on it, or it differs from such a commit in Markdown files only (`setup/README.md`, "Releasing to `stable`").
- Decision 10: each promotion is proven in the VM on the mise version current that day. The floor stays 2026.11.8 unless a guest run fails on a newer release.
- Never run on the owner's Mac without the owner's word: `sysup`, `./setup.sh`, `set-defaults`, `rotm install`, `rotm update`, `mise dotfiles apply`, the built app, `rotm settings sync …`. Task 5 is the owner's word for the lines of `MOVE.md` and nothing else. Never touch github.com/jrmatherly/rotm-settings.
- Moving `stable` is a push to a branch users follow. The owner runs it, or tells the session to. Tags and workflow runs are the owner's.
- The guest is always clean on start. Every guest run uses "Run without saving changes", begins with the tool check (`xcode-select -p`, `ls ~/.local/bin/mise`), answers `y` to setup's GitHub sign-in and `n` to loading saved settings.
- Push nothing to `main` while a guest run is in progress: the app's dot and `update.behind` read it.
- Every line a runbook gives the owner was run by the session first in a scratch home through the same shell, with only paths changed, or is marked **Not run on the host**.
- The gate is `pnpm check`. Edit and commit in separate Bash calls. Commit subjects are short, imperative, sentence case.

## Measured for this plan (2026-11-15, this Mac, `main` at `4bc6f8d`, mise 2026.11.8)

| Fact | Evidence |
| --- | --- |
| `stable` is at `d09f025`, an ancestor of `main`, 206 commits behind | `git merge-base --is-ancestor origin/stable origin/main`, `git rev-list --count origin/stable..origin/main` |
| mise's newest release is 2026.11.8 (2026-11-13) | `gh api repos/jdx/mise/releases/latest` |
| This Mac is a clone install | `bin/lib/rotm-mode` prints `clone`. `~/dotfiles` links to `~/dev/dotfiles`, `~/.config/mise` to its `tilde/.config/mise`, and `~/.local/share/mise/bootstrap-repo` does not exist |
| Every link in this Mac's home is an absolute path into the clone, not a path through `~/dotfiles` | `readlink ~/.zshrc` prints `/Users/jason/dev/dotfiles/tilde/.zshrc`, and the same for `~/.gitconfig`, `~/.zshenv`, `~/.config/gh`, `~/.config/fastfetch`, `~/.config/hunk`, `Code/User` and each rule |
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
| `claude-config` resolves the repository from its own path | `bin/claude-config:50`. Run as `~/dev/dotfiles/bin/claude-config save` it writes into the clone whatever `$DOTFILES` says |
| `$DOTFILES` follows `~/.zshenv`'s link | `tilde/.zshenv:5`: `${${(%):-%x}:A:h:h}`. Once the link points into the copy, a new shell exports the copy |

Not measured: a full `setup.sh` run on a clone-shaped home that was moved (Task 4 runs it in the guest), whether `sysup` and the menu bar app behave on this Mac after the move (Task 5's checks), and an update across the 206 commits from `d09f025` (no copy outside the guest ever followed `stable`, decision 15, so no run is planned).

## Decided while writing this plan

- **Two guest runs, not three.** Guest A is a fresh install from `main` at the candidate, which is decision 9's gate. Guest B rehearses the move and uses the README's own line with `ref=stable`, so the stable line and a `rotm update` across a promotion are proven there. The README's line from a fresh home on `stable` is not run as its own guest: it differs from guest A's in the ref only.
- **The Mole list moves out of the checkout.** `~/.config/mole/whitelist.local`, with the `config.local.toml` entry pointed at it, as `docs/mole.md` now tells an installed user. Not into `~/.config/rotm`, where sync refuses a file it does not know.
- **VS Code's state is moved, not copied.** It is 4.7 GB. `mv` within one volume is instant, and the rollback moves it back.
- **The two runbooks live beside the spec**, in `docs/superpowers/specs/2026-11-15-p7-move/`, as the P5 proof's do. Records go to `~/vm-proof/p7/` on the host through the shared folder.
- **No new proof script.** The rows are few, so each records plain command output with one shell function the runbook defines.
- **The standing cost is accepted, not designed around.** After the move, a change reaches this Mac's live config only through a promotion (decisions 9 and 15). The clone-only commands the owner still needs are run by path. `MOVE.md` lists them.

## Review Focus

1. **The install line fails half way.** mise clones the copy and then refuses at the `~/.config/mise` link, leaving a copy and no config. `MOVE.md` removes the link first, and its rollback covers a stop at any step.
2. **A link into the clone survives the move.** An app then writes into the clone and the owner's edits there go live without a promotion. The move ends with a search for such links that must print nothing.
3. **State the clone held is lost.** gh's sign-in, 4.7 GB of VS Code history and storage, this Mac's settings and its Mole list are git-ignored files in the clone. Each has a carry step and a check after setup.
4. **The shell breaks mid-move.** `~/.zshrc` is removed before setup seeds the wrapper. The runbook keeps one Terminal window open for the whole move and opens no new shell until the check step says to.
5. **A newer mise breaks the fresh install.** mise ships almost daily and the floor is two days old. Guest A runs on the release current that day, and a failure there stops the promotion.

---

### Task 1: Write the promotion runbook and prove the candidate (guest A)

**Files:**
- Create: `docs/superpowers/specs/2026-11-15-p7-move/RUNBOOK.md`
- Modify: `docs/superpowers/specs/2026-11-11-installable-setup-profiles-and-sync.md` ("Verified facts")

**Interfaces:**
- Produces: the candidate, a full commit hash on `main` that Task 2 promotes, written in the runbook's first line. The runbook's record function, which `MOVE.md` and guest B reuse:

  ```shell
  r() { local row=$1; shift; { "$@"; echo "exit $?"; } > "/Volumes/My Shared Files/vm-proof/p7/$row.txt" 2>&1; tail -3 "/Volumes/My Shared Files/vm-proof/p7/$row.txt"; }
  ```

- [ ] **Step 1: Fix the candidate.** `git rev-parse origin/main`, with `main` clean and `check.yml` green on it (`gh run list --workflow check.yml --limit 1`). Record the mise release current that day (`gh api repos/jdx/mise/releases/latest --jq .tag_name`).
- [ ] **Step 2: Write `RUNBOOK.md`, section "Guest A".** Numbered steps in the form of the P5 runbook (`docs/superpowers/specs/2026-11-14-p5-vm-proof/RUNBOOK.md`, steps 3 to 7): start the guest disposable, check the two tools, `mkdir -p` the record folder, run the install line with `?ref=main`, answer setup, reopen Terminal, define `r`. Then these rows:

  | Row | Command | Passes when |
  | --- | --- | --- |
  | `a1` | `r a1 git -C ~/.local/share/mise/bootstrap-repo rev-parse HEAD` | It prints the candidate |
  | `a2` | `r a2 ~/dotfiles/bin/lib/rotm-mode` | `installed` |
  | `a3` | `r a3 rotm settings status --json` | `"mode":"installed"` and the candidate's short hash |
  | `a4` | `r a4 mise --version` | The release recorded in Step 1 |
  | `a5` | `r a5 git -C ~/.local/share/mise/bootstrap-repo status --short` | Nothing but `exit 0`, after opening VS Code, lazygit and fastfetch once and running `gh config set editor vim` |
  | `a6` | `r a6 fastfetch --version` then `r a6b ls -l ~/.config/fastfetch` | `config.jsonc` is a regular file and `ascii` holds links (P6 Task 2, first real install) |
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

**Before.** `main` clean and pushed, `stable` promoted, VS Code, Obsidian and every Claude Code session quit, one Terminal window open and no other shell. `git -C "$CLONE" status --short` prints nothing.

**1. Record the start,** so the rollback has a list, after `mkdir "$KEEP"`:

  ```shell
  A="$HOME/Library/Application Support"
  find ~ ~/.config ~/.claude ~/.claude/rules ~/.claude/skills ~/.codex ~/.ssh ~/.gnupg ~/.config/mole "$A/Code" "$A/lazydocker" "$A/rtk" -maxdepth 1 -type l -lname "$CLONE/*" | sort -u > "$KEEP/links.txt"
  ```

  On the owner's Mac it lists 43 links today (measured read-only on 2026-11-15). `~/dotfiles` is not among them, because its target is the clone itself: `readlink ~/dotfiles` is recorded beside the list. The folders are the ones `40-dotfiles.toml` and the module fragments name a target in. A new entry in another folder adds its folder here.

**2. Carry what git ignores out of the clone.** Copies, except VS Code's state, which moves in step 5:

  | From the clone | To |
  | --- | --- |
  | `tilde/.config/mise/config.override.toml` | `~/.config/rotm/config.override.toml` (after `mkdir -p ~/.config/rotm`) |
  | `tilde/.config/mise/config.local.toml` | `$KEEP/config.local.toml`, with the Mole entry's source changed to `~/.config/mole/whitelist.local` |
  | `mole/whitelist.local` | `~/.config/mole/whitelist.local` |
  | `tilde/.config/gh/hosts.yml` | `$KEEP/hosts.yml` |
  | `tilde/.config/hunk/state.json` | `$KEEP/state.json` |

**3. Remove the links the installed copy replaces.** Each is a link, so `rm` removes no file: `~/dotfiles`, `~/.config/mise`, `~/.zshrc`, `~/.gitconfig`, `~/.config/gh`, `~/.config/fastfetch`, `~/.config/mole/whitelist`, `~/.claude/rules/jstack-models.md` and `~/Library/Application Support/Code/User`. The step first checks each with `[ -L ]` and stops at one that is not a link.

**4. Fetch the copy.** The mise half of the README's install line, with `ref=stable`. Expected: `linked ~/.config/mise to …/bootstrap-repo/tilde/.config/mise` and `saved env = ["rotm-installed"]`. Then `cp "$KEEP/config.local.toml" ~/.config/mise/config.local.toml`, which lands in the copy's config dir, where git ignores it.

**5. Make the real folders and put the state back.** `mkdir -m 700 ~/.config/gh && cp "$KEEP/hosts.yml" ~/.config/gh/`. `mkdir -p -m 700 "$HOME/Library/Application Support/Code/User"`, then `mv` each of `History`, `globalStorage`, `profiles`, `sync`, `workspaceStorage` and `agent-sessions.code-workspace` from `$CLONE/vscode/User` into it.

**6. Run setup from the copy:** `~/.local/share/mise/bootstrap-repo/setup.sh`. It links `~/dotfiles` to the copy, seeds the wrappers and the copies, and repoints every other link. Then `cp "$KEEP/state.json" ~/.config/hunk/state.json`, which is git-ignored in the copy.

**7. Check, in a new Terminal window.** Each line through `r`:

  | Row | Command | Passes when |
  | --- | --- | --- |
  | `m1` | `~/dotfiles/bin/lib/rotm-mode` | `installed` |
  | `m2` | `echo $DOTFILES` | The copy's path |
  | `m3` | The `find` of step 1 | No line |
  | `m4` | `git -C "$COPY" status --short` and `git -C "$CLONE" status --short` | Neither prints a line |
  | `m5` | `mise dotfiles status --missing` | Exit 0 |
  | `m6` | `cmp ~/.zshrc "$COPY/tilde/.zshrc.installed"` and `[ ! -L ~/.gitconfig ]` | Exit 0 for both |
  | `m7` | `gh auth status` | Signed in |
  | `m8` | `rotm settings status` | Mode `installed`, branch `stable` |
  | `m9` | `readlink ~/.config/mole/whitelist` | `~/.config/mole/whitelist.local`, expanded |
  | `m10` | `git config --get user.email` in the clone | The owner's, read through the wrapper and `~/.gitconfig.local` |

  | `m11` | `claude mcp list` | No server's command names the clone. `docs/rea.md` says a registration holds its launcher's absolute path, and setup registers again from the copy |

  Then open VS Code and see the recent folders, and open the menu bar app and see "Setup: up to date". The owner also checks their own files, which the session may not read: `grep -l dev/dotfiles ~/.zsh.local ~/.gitconfig.local ~/.ssh/config.local` should print nothing, or each hit is a path the owner means to keep.

**8. Roll back,** from any step. Remove what the move made (`~/dotfiles`, `~/.config/mise`, the seeded `~/.zshrc`, `~/.gitconfig`, `jstack-models.md` and `~/.config/fastfetch`, each only when it is not the owner's edited file), move VS Code's state back into `$CLONE/vscode/User` and remove the real `Code/User` and `~/.config/gh` after copying `hosts.yml` back, restore the two links by hand (`ln -s "$CLONE" ~/dotfiles`, `ln -s "$CLONE/tilde/.config/mise" ~/.config/mise`), and run `"$CLONE/setup.sh" -- --skip packages`, which relinks the rest. The copy and `~/.config/rotm` are left in place, since a clone ignores the first and reads the second.

**9. Living with both.** A table for the owner:

  | To | Run |
  | --- | --- |
  | Edit, check and commit | In `~/dev/dotfiles`, as before. `pnpm check` runs the clone's scripts by path |
  | Try a changed script before promoting | By path, `~/dev/dotfiles/bin/<name>`. `PATH` holds the copy's |
  | Record this Mac's Claude Code setup | `~/dev/dotfiles/bin/claude-config save`. `sysup` no longer saves on this Mac |
  | Bring Obsidian settings back to the repository | `~/dev/dotfiles/bin/obsidian-vault capture` |
  | Make a change live | Push to `main`, promote (`setup/README.md`), then `rotm update` |

- [ ] **Step 1: Write `MOVE.md`** from the content above, with every command spelled out and its expected output.
- [ ] **Step 2: Run steps 1 to 3 and 5 to 8 in a scratch home** shaped like this Mac, as this plan's measurement did (two local checkouts, absolute links, `mise dotfiles apply` under `MISE_ENV=rotm-installed` standing in for steps 4 and 6). Expected: rows `m3`, `m4` and `m6` pass, and after the rollback the scratch home's links point into the first checkout again with `git status` empty in both. Mark steps 4 and 6 **Not run on the host**.
- [ ] **Step 3: Check the two by-path commands of section 9** read-only: `~/dev/dotfiles/bin/claude-config restore --dry-run` runs from the clone, and `bin/obsidian-vault` resolves its repository from its own path (read the script; if it honors `$DOTFILES` first, the table's line gains `DOTFILES=~/dev/dotfiles`).
- [ ] **Step 4:** `pnpm check`, commit: "Write the runbook for moving a clone to an installed copy".

### Task 4: Rehearse the move in the guest (guest B)

**Files:**
- Modify: `docs/superpowers/specs/2026-11-15-p7-move/RUNBOOK.md` (section "Guest B")
- Modify: `docs/superpowers/specs/2026-11-15-p7-move/MOVE.md` (what the rehearsal corrects)
- Modify: the spec ("Verified facts")

**Interfaces:**
- Consumes: Task 2's `stable`, Task 3's `MOVE.md`.
- Produces: `MOVE.md` as run in the guest, and a second promotion that Task 5 does not repeat.

- [ ] **Step 1: Write section "Guest B".** A disposable guest set up the way the owner's Mac is: `git clone https://github.com/jrmatherly/returnofthemac.git ~/dev/dotfiles` and `~/dev/dotfiles/setup.sh`, the GitHub sign-in answered `y`. Then make the state a used Mac has: open and quit VS Code, `dotfiles-settings set updates.mac_password_op 'op://x/y/z'` (a value in `config.override.toml`), a `mole/whitelist.local` with one line and its `config.local.toml` entry. Row `b0`: `r b0 ~/dotfiles/bin/lib/rotm-mode` prints `clone`.
- [ ] **Step 2: The owner runs `MOVE.md` in the guest,** steps 1 to 7. The session reads `m1` to `m11`.
- [ ] **Step 3: Prove an update across a promotion.** With the guest still up, the session pushes one Markdown-only commit to `main` (the record of Task 1 if it is not yet promoted, or a line in the plan index), and the owner promotes it as in Task 2. In the guest: `r b1 rotm update --check` prints `1 update is waiting…` or the count, `rotm update`, then `r b2 git -C ~/.local/share/mise/bootstrap-repo rev-parse HEAD` prints the new `stable` and `r b3 rotm update --check` prints `Up to date.`
- [ ] **Step 4: Prove the clone is inert.** In the guest: `echo '# x' >> ~/dev/dotfiles/tilde/.zshenv`, open a new Terminal window, `r b4 grep -c '^# x$' ~/.zshenv` prints 0, then `git -C ~/dev/dotfiles checkout tilde/.zshenv`.
- [ ] **Step 5: Run the rollback** (section 8), then `r b5 ~/dotfiles/bin/lib/rotm-mode` prints `clone` and the `find` of step 1 prints the same lines as `links.txt`. Shut the guest down.
- [ ] **Step 6: Correct `MOVE.md`** for every step that did not go as written, and record the rehearsal in "Verified facts". A step that failed and has no fix stops the plan before Task 5. `pnpm check`, commit: "Record the move rehearsal and correct its runbook".

### Task 5: Move the owner's Mac

**Files:**
- Modify: `docs/superpowers/specs/2026-11-15-p7-move/MOVE.md` (the link count, and what the real run corrects)

**Interfaces:**
- Consumes: `MOVE.md` as corrected by Task 4, and `stable` at the commit Task 4 promoted.

- [ ] **Step 1: The owner gives the word,** names a time with nothing else running on the Mac, and confirms a Time Machine or other backup of `~/dev/dotfiles` exists (it holds 4.7 GB of VS Code state that the move relocates). The session does not start this task from a handoff alone.
- [ ] **Step 2: The owner runs `MOVE.md`,** steps 1 to 7, in one Terminal window. Records go to `~/vm-proof/p7/mac/`. The session reads them from a Claude Code session started after step 7, since step 3 removes the links the running one uses.
- [ ] **Step 3: After the checks, the owner runs `sysup` once** and the session reads its summary: the dotfiles step reads `installed copy: run rotm update`, the Claude config step reads `installed copy: not saved into it`, and no step fails that passed on the clone.
- [ ] **Step 4: Prove the brief's "Done when" on this Mac.** `rotm-mode` prints `installed` (`m1`). A new `stable` commit arrives with `rotm update`: promote the next Markdown-only commit, here Step 5's, and run it. An edit in `~/dev/dotfiles` changes nothing live: Task 4's Step 4, run here.
- [ ] **Step 5: Record the move** in the spec and correct `MOVE.md`. Commit from the clone: "Record the owner's Mac moving to stable".

### Task 6: Close P7 and the spec

**Files:**
- Modify: the spec ("Plans", the P7 brief's "Shipped" line, decision 7's last sentence stays as written)
- Modify: `docs/superpowers/plans/README.md`
- Modify: `CLAUDE.md` and `.claude/rules/*.md`, only the statements the move made false. Known today: "The repo is the source of truth. Everything is symlinked into `$HOME` and configured by editing files in the clone" (`CLAUDE.md`, Overview), `~/dotfiles` "must be a symlink to the clone or, on an installed copy, to mise's checkout" stays true, and the standing approval in "Custom Notes" stays true
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
