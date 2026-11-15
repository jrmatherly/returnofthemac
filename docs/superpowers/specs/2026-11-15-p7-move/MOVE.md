# Moving a clone install to an installed copy: runbook (2026-11-15)

This moves one Mac, by hand and once, from a clone install to a copy that follows `stable`. Before it, every link in `$HOME` points into the clone at `~/dev/dotfiles`. After it, they point into mise's checkout at `~/.local/share/mise/bootstrap-repo`, and the clone is for editing only. It is P7 plan Tasks 3 to 5 (`docs/superpowers/plans/2026-11-15-p7-stable-and-the-owners-mac.md`). It is not a path users get: nothing in the product does this (decision 15 of `docs/superpowers/specs/2026-11-11-installable-setup-profiles-and-sync.md`).

How it works:

- You type every line, in order, in **one Terminal window**. Step 3 removes `~/.zshrc`, so open no other shell until step 7 says to.
- A step's block ran as written in a scratch home shaped like this Mac on 2026-11-15, in `zsh`, with only the home folder changed, and ended in the state the step names. The lines that could not run there say **Not run on the host**. The guest rehearsal (Task 4) is their first run.
- When a line prints something this page does not expect, stop. [Roll back](#8-roll-back) works from any step.

## Before

- `main` is clean and pushed, and `stable` is promoted.
- VS Code, Obsidian and every Claude Code session are quit. One Terminal window is open and no other shell.
- A backup of `~/dev/dotfiles` exists. It holds 4.7 GB of VS Code state that step 5 moves.

Type this block first. Step 7's new window needs it again:

```shell
CLONE=~/dev/dotfiles COPY=~/.local/share/mise/bootstrap-repo KEEP=~/rotm-move-keep A="$HOME/Library/Application Support"
P7=~/vm-proof/p7/mac   # in the guest: "/Volumes/My Shared Files/vm-proof/p7"
r() { local row=$1; shift; { "$@"; echo "exit $?"; } > "$P7/$row.txt" 2>&1; tail -3 "$P7/$row.txt"; }
# every link in the folders setup links into whose resolved target is inside the clone
inclone() { find ~ ~/.config ~/.claude ~/.claude/rules ~/.claude/skills ~/.codex ~/.ssh ~/.gnupg ~/.config/mole ~/.local/share/mise/plugins "$A/Code" "$A/lazydocker" "$A/rtk" -maxdepth 1 -type l 2> /dev/null | sort -u | while IFS= read -r l; do case "$(realpath "$l" 2> /dev/null)" in "$CLONE" | "$CLONE"/*) echo "$l" ;; esac; done; }
```

`inclone` resolves each link, so it finds a link through `~/dotfiles` as well as an absolute one. Its folders are the ones `40-dotfiles.toml` and the module fragments name a target in, plus mise's plugin folder. A new entry in another folder adds its folder here.

Then check the start:

```shell
git -C "$CLONE" status --short
"$CLONE/bin/lib/rotm-mode"
```

The first line prints nothing and the second prints `clone`.

## 1. Record the start

The rollback needs the list.

```shell
mkdir -m 700 "$KEEP" && mkdir -p "$P7" && inclone > "$KEEP/links.txt"
wc -l < "$KEEP/links.txt"
```

It prints the number of links. On the owner's Mac it was 46 on 2026-11-15, measured read-only.

## 2. Move what git ignores out of the clone

A fresh copy has none of these files. Each is moved, not copied, so the clone keeps no stale copy for the rollback to trip on, and the modes are kept.

```shell
mkdir -p -m 700 ~/.config/rotm
[ -L "$CLONE/tilde/.config/mise/config.override.toml" ] || mv "$CLONE/tilde/.config/mise/config.override.toml" ~/.config/rotm/config.override.toml
mv "$CLONE/tilde/.config/mise/config.local.toml" "$KEEP/config.local.toml"
sed -i '' 's|~/dotfiles/mole/whitelist.local|~/.config/mole/whitelist.local|' "$KEEP/config.local.toml"
grep -n 'mole/whitelist' "$KEEP/config.local.toml"
mv "$CLONE/mole/whitelist.local" ~/.config/mole/whitelist.local
mv "$CLONE/tilde/.config/gh/hosts.yml" "$KEEP/hosts.yml"
mv "$CLONE/tilde/.config/hunk/state.json" "$KEEP/state.json"
stat -f '%Sp %N' ~/.config/rotm/config.override.toml ~/.config/mole/whitelist.local "$KEEP"/*
```

The `grep` prints the Mole entry with `source = "~/.config/mole/whitelist.local"`. The `stat` lists six files, and `hosts.yml`, your GitHub sign-in, reads `-rw-------`. The second line moves nothing when the clone's override file is already a link into `~/.config/rotm`, as on a clone set up after P3.

From here until step 6 ends, `gh`, mise's own settings and the Mole list are not where their tools look. That is why nothing else runs during the move.

## 3. Remove the links the installed copy replaces

Each is a link, so `rm` removes no file. The block checks that first and stops at one that is not a link.

```shell
links=(~/dotfiles ~/.config/mise ~/.zshrc ~/.gitconfig ~/.config/gh ~/.config/fastfetch ~/.config/mole/whitelist ~/.claude/rules/jstack-models.md "$A/Code/User")
n=0; for l in "${links[@]}"; do [ -L "$l" ] || { echo "STOP, not a link: $l"; n=1; }; done; [ $n = 0 ] && rm "${links[@]}" && echo "removed ${#links[@]} links"
```

It prints `removed 9 links`. A `STOP` line means nothing was removed: tell the session which path it named. `~/.config/fastfetch` is one folder link on this Mac, and it is on the list because the installed copy seeds a file inside it.

## 4. Fetch the copy

**Not run on the host.** It is the by-hand line of `docs/installation.md`, without its `setup.sh` half. `install.sh` is not used: it would start setup before step 5.

```shell
~/.local/bin/mise -E rotm-installed bootstrap --from 'https://github.com/jrmatherly/returnofthemac.git?ref=stable' --config-dir tilde/.config/mise --save-env --only final-hook
```

It prints `linked ~/.config/mise to ~/.local/share/mise/bootstrap-repo/tilde/.config/mise` and `saved env = ["rotm-installed"]`. Then put this Mac's own mise file into the copy's config dir, where git ignores it:

```shell
mv "$KEEP/config.local.toml" ~/.config/mise/config.local.toml
git -C "$COPY" status --short
```

The second line prints nothing.

## 5. Make the real folders and put the state back

An installed copy has real folders where the clone had folder links, so the state goes into them before setup seeds the rest.

```shell
mkdir -m 700 ~/.config/gh && mv "$KEEP/hosts.yml" ~/.config/gh/
mkdir -p -m 700 "$A/Code/User"
for n in History globalStorage profiles sync workspaceStorage agent-sessions.code-workspace; do mv "$CLONE/vscode/User/$n" "$A/Code/User/"; done
ls -A "$A/Code/User" "$CLONE/vscode/User"
```

The first folder lists the six names. The clone's keeps its tracked files, `settings.json` and `.settings.rendered`: setup renders those two again.

## 6. Run setup from the copy

**Not run on the host.**

```shell
~/.local/share/mise/bootstrap-repo/setup.sh
```

| Setup asks | Answer |
| --- | --- |
| `Press Enter key to continue…` | Enter |
| `Load your saved settings from jrmatherly/rotm-settings before installing? [Y/n]` | **`n`**. The repository holds the P5 guests' test values, and Enter would load them. It appears only if the repository still exists |
| The password, once | The login password |
| The VS Code font preset | Enter, which keeps the saved one |
| Git identity and signing | Not asked: `~/.gitconfig.local` exists |

It links `~/dotfiles` to the copy, seeds `~/.zshrc`, `~/.gitconfig` and the other files that are yours on an installed copy, repoints every other link, installs the one missing package (the menu bar app) and opens it. It must end with `All done!`.

It also warns that the REA server "is registered differently" and prints the line that fixes it. Run that line in the form the warning prints, which should be:

```shell
claude mcp remove rea -s user && claude mcp add --scope user rea -- ~/.local/share/mise/bootstrap-repo/bin/rea-mcp
```

Then put the last carried file back. It is git-ignored in the copy:

```shell
mv "$KEEP/state.json" ~/.config/hunk/state.json
ls -A "$KEEP"
```

`$KEEP` now holds `links.txt` only.

## 7. Check, in a new Terminal window

Open a new Terminal window and type the [opening block](#before) again. Then:

```shell
r m1 ~/dotfiles/bin/lib/rotm-mode
r m2 eval 'echo $DOTFILES'
r m3 inclone
r m4 eval 'git -C "$COPY" status --short; git -C "$CLONE" status --short'
r m5 mise dotfiles status --missing
r m6 eval 'cmp ~/.zshrc "$COPY/tilde/.zshrc.installed" && [ ! -L ~/.gitconfig ]'
r m7 gh auth status
r m8 rotm settings status
r m9 readlink ~/.config/mole/whitelist
r m10 git -C "$CLONE" config --get user.email
r m11 claude mcp list
r m12 rotm settings get updates.mac_password_op
```

| Row | Passes when |
| --- | --- |
| `m1` | `installed` |
| `m2` | The copy's path |
| `m3` | Nothing but `exit 0` |
| `m4` | Nothing but `exit 0` |
| `m5` | `exit 0` |
| `m6` | Nothing but `exit 0` |
| `m7` | Signed in |
| `m8` | Mode `installed`, branch `stable`, sync not connected |
| `m9` | `~/.config/mole/whitelist.local`, expanded |
| `m10` | Your email, read through the seeded `~/.gitconfig` and `~/.gitconfig.local` |
| `m11` | No server's command names the clone |
| `m12` | The value this Mac had, read from `~/.config/rotm` |

Rows `m1`, `m3` to `m6` and `m9` ran in the scratch home, and `m2` there as a new `zsh` reading `~/.zshenv`. **Not run on the host:** `m7`, `m8`, `m10`, `m11` and `m12`, which need setup, a sign-in or Claude Code.

Then open VS Code and see the recent folders, and see "Setup: up to date" in the menu bar app. Check your own files, which the session may not read:

```shell
grep -l dev/dotfiles ~/.zsh.local ~/.gitconfig.local ~/.ssh/config.local
```

It should print nothing, or each file it names holds a path you mean to keep.

## 8. Roll back

From any step, with VS Code quit, in this order. Each line skips what its step had not yet done. A rollback from the end ran in the scratch home. A rollback from a step part way did not.

1. Take out what the move made. A seeded file that you have changed since is kept aside in `$KEEP`:

   ```shell
   [ ! -f "$COPY/tilde/.config/mise/config.local.toml" ] || mv "$COPY/tilde/.config/mise/config.local.toml" "$KEEP/config.local.toml"
   for l in ~/dotfiles ~/.config/mise; do [ ! -L "$l" ] || rm "$l"; done
   for p in .zshrc:tilde/.zshrc.installed .gitconfig:tilde/.gitconfig.installed .claude/rules/jstack-models.md:tilde/.claude/rules/jstack-models.md .config/fastfetch/config.jsonc:tilde/.config/fastfetch/config.jsonc; do f="$HOME/${p%%:*}" s="$COPY/${p#*:}"; [ -f "$f" ] && [ ! -L "$f" ] || continue; if cmp -s "$f" "$s"; then rm "$f" && echo "removed $f"; else mv "$f" "$KEEP/" && echo "kept aside $f"; fi; done
   ```

2. Move the state back into the clone. Everything VS Code wrote since step 7 goes with it, except the files setup seeded or rendered. The two real folders are kept in `$KEEP`, not deleted:

   ```shell
   if [ -d "$A/Code/User" ] && [ ! -L "$A/Code/User" ]; then ls -A "$A/Code/User" | while IFS= read -r n; do case "$n" in keybindings.json | tasks.json | chatLanguageModels.json | snippets | settings.json | .settings.rendered) ;; *) mv "$A/Code/User/$n" "$CLONE/vscode/User/" ;; esac; done; mv "$A/Code/User" "$KEEP/Code-User.installed"; fi
   if [ -d ~/.config/gh ] && [ ! -L ~/.config/gh ]; then mv ~/.config/gh/hosts.yml "$CLONE/tilde/.config/gh/" && mv ~/.config/gh "$KEEP/gh.installed"; fi
   [ ! -f "$KEEP/hosts.yml" ] || mv "$KEEP/hosts.yml" "$CLONE/tilde/.config/gh/"
   for s in "$COPY/tilde/.config/hunk/state.json" "$KEEP/state.json"; do [ ! -f "$s" ] || mv "$s" "$CLONE/tilde/.config/hunk/"; done
   mv "$KEEP/config.local.toml" "$CLONE/tilde/.config/mise/config.local.toml"
   [ ! -f ~/.config/mole/whitelist.local ] || mv ~/.config/mole/whitelist.local "$CLONE/mole/whitelist.local"
   sed -i '' 's|~/.config/mole/whitelist.local|~/dotfiles/mole/whitelist.local|' "$CLONE/tilde/.config/mise/config.local.toml"
   ```

   A file or folder that VS Code created at the top of `Code/User` after the move shows as untracked in the clone afterwards. Move it aside if you do not want it there.

3. Restore the two links, and mise's vscode plugin, which the next step would skip:

   ```shell
   ln -s "$CLONE" ~/dotfiles
   ln -s "$CLONE/tilde/.config/mise" ~/.config/mise
   mise plugins link --force vscode "$CLONE/mise-plugins/vscode"
   ```

4. Point the REA server back at the clone, and run setup from the clone, answering `n` to the saved-settings question. **Not run on the host.** Setup links `config.override.toml` from `~/.config/rotm`, which stays, and relinks the rest:

   ```shell
   claude mcp remove rea -s user && claude mcp add --scope user rea -- ~/dev/dotfiles/bin/rea-mcp
   "$CLONE/setup.sh" -- --skip packages
   ```

5. Check:

   ```shell
   "$CLONE/bin/lib/rotm-mode"
   inclone | wc -l; wc -l < "$KEEP/links.txt"
   mise dotfiles status --missing; echo "exit $?"
   git -C "$CLONE" status --short; git -C "$COPY" status --short
   while IFS= read -r l; do case "$(realpath "$l" 2> /dev/null)" in "$CLONE" | "$CLONE"/*) ;; *) echo "not in the clone: $l" ;; esac; done < "$KEEP/links.txt"
   ```

   It prints `clone`, then two counts, `exit 0`, nothing from git, and one line: `not in the clone: ~/.config/fastfetch`. The first count is one less than the second for the same reason. A clone set up today links fastfetch's files one by one, so that path is a real folder of links into the clone and no longer one link. Any other `not in the clone` line is a link the rollback missed. The links now read `~/dotfiles/…`, which is why the check resolves them.

The copy is left in place: a clone ignores it. The override file stays in `~/.config/rotm`, the layout a clone has had since P3.

## 9. Living with both

`$DOTFILES` is the copy in every shell after the move, so a clone script that reads it must be told otherwise.

| To | Run |
| --- | --- |
| Edit, check and commit | In `~/dev/dotfiles`, as before. `pnpm check` checks the clone's tree whatever `$DOTFILES` says |
| Read a changed script's help | `DOTFILES=~/dev/dotfiles help <name>`. A bare `help` renders the copy's header |
| Try a changed script before promoting | `DOTFILES=~/dev/dotfiles ~/dev/dotfiles/bin/<name>`. With it set, `rotm-mode` reads `clone`, so `set-defaults` and `dotfiles-settings` would write the clone's tracked files while mise still reads the copy's config: use those two from the copy only |
| Record this Mac's Claude Code setup | `~/dev/dotfiles/bin/claude-config save`, which resolves its own path. `sysup` no longer saves on this Mac. `claude-catalog`, `claude-stack` and `vscode-settings` by path act on the clone the same way |
| Bring Obsidian settings back to the repository | `DOTFILES=~/dev/dotfiles ~/dev/dotfiles/bin/obsidian-vault capture`. Without the variable it writes into the copy and `rotm update` then stops |
| Make a change live | Push to `main`, promote (`setup/README.md`, "Releasing to `stable`"), then `rotm update` |

Three things changed:

- Never edit through `~/.claude/rules/*`, `~/.config/<app>` or `~/.config/mole/whitelist_optimize`. They are links into the copy.
- `~/.claude/rules/jstack-models.md` is this Mac's own file now, so `/jstack:setup-jstack` no longer changes the tracked one.
- `sysup`'s and setup's logs land in the copy's git-ignored `logs/` and `private/`.

Checked on 2026-11-15 with `DOTFILES` naming a second checkout: `DOTFILES=~/dev/dotfiles help rotm` rendered the clone's header, and `~/dev/dotfiles/bin/claude-config restore --dry-run` named the clone's `agents/` in a scratch home and never the second checkout. On this Mac the same dry run prints nothing, because nothing the clone tracks is missing here.

## What the scratch run changed from the plan

The plan's Task 3 text was the specification. Running it found these, each fixed above:

| Found | Change |
| --- | --- |
| The rollback left the Mole list in `~/.config/mole`, so its link resolved outside the clone | Rollback step 2 moves the list back and reverts the `sed` |
| `~/.config/fastfetch` cannot return to one folder link: a clone-mode apply makes a real folder of links | Rollback step 1 removes only the seeded `config.jsonc`, and step 5 expects that one line and a count one lower |
| After `rm ~/dotfiles` the installed links are dead, so a path through them names nothing | Rollback steps 1 and 2 name `$COPY/tilde/…` directly |
| Deleting the real `Code/User` and `~/.config/gh` needed `rm -r` on folders holding state | Rollback step 2 moves both into `$KEEP` |
| `r` takes one command, and rows `m2`, `m4` and `m6` are two commands or need the shell | They run through `eval` |
| One apply under `rotm-installed` was enough for `mise dotfiles status --missing` to exit 0, where the plan expected two | Nothing to change: setup runs the apply |
