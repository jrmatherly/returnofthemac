# Updating

Two commands keep a Mac current. `rotm update` brings this project's changes to an installed copy, and [`sysup`](../bin/sysup) upgrades everything the setup installed.

## On an installed copy

```shell
rotm update
sysup
```

Run both, in that order. `rotm update` fetches the newest `stable` into the copy, prints one line such as `↻ returnofthemac  stable 2df15c2 → b3111ca, 2 files` or `✔ returnofthemac  stable up to date` in place of git's output, and runs setup again, without the first-install warning and its wait, which links what is new and installs what is missing. It does not upgrade what is already installed, except PowerShell and the Iosevka Code font. `sysup` does that: macOS, mise, the packages, the runtimes and the agent tooling. On an installed copy `sysup` skips the pull. It asks `rotm update --check` whether the copy is behind `stable` and prints `installed copy up to date`, or how many updates are waiting with the command to run. Its other steps are the ones listed under [In a clone](#in-a-clone).

To see whether an update is waiting without installing anything, run `rotm update --check`: it fetches the copy's branch and prints `Up to date.` or `2 updates are waiting. Run rotm update.`, leaving the copy as it was. Add `--json` for `{"mode":"installed","branch":"stable","behind":2}`. In a development clone it prints `This is a development clone. Pull it yourself.` (`"behind":null` in JSON) and exits 0. A failed fetch, or a copy that is not on a branch, exits 1 with one line on stderr. The [menu bar app](menu-bar.md) shows the same count in its menu, runs `rotm update -y` from its **Update…** line, and upgrades itself through mise when you choose to.

## In a clone

```shell
sysup
```

[`sysup`](../bin/sysup) is the routine update command, and it works from any directory. It prints one status line per step (green ✔ up to date, cyan ↻ changed with what changed, yellow ● a notice, red ✖ a failed step with the command to rerun, and a dim `◷ mise hold` line for each release mise holds back by `minimum_release_age`, which is not a notice and is not counted in the summary) and ends with a summary: a `Done in <time> · <n> changed · …` headline, then what changed, notices and failures in aligned columns, the actions you still have to take (restart Claude Code after plugin updates, review the tracked config, open a new terminal) under a highlighted `▶ ACTION NEEDED` banner, and clickable links to the rebuilt catalog and the log (shown as `~/…` paths). A list such as the upgraded packages or mise tools, the versions `mise prune` removed or the plugins updated prints as a two-column table under its step, and long lines wrap under the detail column. A step with several items of one kind, such as the catalog's lint notes or the Homebrew versions and links `packages cleanup` removed or fixed, prints one line with a count, and the summary lists the items under that line. Each run's full tool output goes to `logs/sysup-<timestamp>.log` (git-ignored); only a step that changed something or failed shows its output on screen. A failed step never stops the run, and `sysup` exits 1 at the end when any step failed. On a terminal, the step in progress shows as a `…` line, and a step that took 10 seconds or more names its time. It:

- pulls the latest dotfiles (`git pull` in the clone)
- installs macOS software updates (a macOS update asks for your login password: see [below](#macos-update-password-from-1password-optional)); one that needs a restart, such as a new macOS version, is only downloaded, and the summary tells you to install it from System Settings → General → Software Update → Restart Now or with `sudo softwareupdate -ia --restart`, since a plain restart doesn't install it
- updates mise itself (`mise self-update`). A mise that a package manager installed refuses, and the step fails with a pointer to [A Mac set up before the mise-first setup](#a-mac-set-up-before-the-mise-first-setup)
- removes the Homebrew versions an earlier upgrade replaced, and repoints or removes the links that still named them (`brew-keg-cleanup`, since mise leaves both behind). It runs before the upgrade, so the version this run replaces stays until the next run. It also removes dead links in the Homebrew prefix
- upgrades the formulae and casks in [`30-packages.toml`](../tilde/.config/mise/conf.d/30-packages.toml) and the [modules](modules.md) that are on, VS Code included, without asking for confirmation (`mise bootstrap packages upgrade --yes`; the pairs whose installed version moved go to the screen). VS Code updates its own extensions
- lists any declared package that is still not installed
- reports, as one notice, the formulae and casks installed on this Mac that no mise config declares (`mise bootstrap packages prune --dry-run`, and again with `-m brew-cask`). It never removes them; review the list and run `mise bootstrap packages prune` yourself to remove every one
- runs `mise prune`, which deletes the tool versions the previous run replaced that no project's mise config still uses, and reports how much it freed. The versions this run replaces stay until the next run, so you can go back to one. The prune is skipped, with a notice, while a leftover mise rust install would make it hang
- upgrades mise tools (Node/Python patch releases, CodeGraph, the npm CLIs, the Aspire CLI and flate); a tool mise could not reinstall is a notice
- updates the stable Rust toolchain (`rustup update`). rustup is the `brew:rustup` package, called by path because it keeps its proxies in `/opt/homebrew/opt/rustup/bin`. A notice follows when `cargo --version` fails in that shell, or when a mise rust toolchain that no config pins shadows it
- upgrades the uv tools (Serena, Scrapling and Browser Use) under the same 48 hour release hold as their install, which also gives the hold to a tool installed before it existed, then re-runs `scrapling install` so its Chromium matches
- prunes the uv cache (`uv cache prune`, waiting at most 10 s for the lock) and reports how many cached environments are waiting when open Claude Code sessions keep it busy
- updates the Google Cloud CLI with its own updater (`gcloud components update --quiet`), because mise never upgrades that cask: it is an installer, not one app
- reinstalls the Iosevka Code font if its upstream zip changed
- updates Claude Code itself (`claude update`) and reports its version, before the steps below so they run on the new binary
- reads when the stored claude.ai sign-in ends (`claude auth status`, Claude Code 2.1.318 or later) and gives a notice to run `claude auth login` when that is under 10 days away or past, or when Claude Code is not signed in (a sign-in that already ended reads the same), since using Claude Code doesn't extend it and unattended `claude` runs such as Hindsight's extraction fail once it ends; an API key or another credential is an ok line
- reinstalls an agent skill from a trusted source (`agents/claude-skills-trusted.txt`) when it moved upstream and shows it as a change, and for any other source checks each tracked agent skill against its reviewed value in `agents/claude-skills.txt` (a GitHub folder's git SHA or a well-known site's digest) and installs what an agent lacks only for a skill that matches it (`claude-config restore skills --update`); a skill that moved upstream, or one it can't check that an agent lacks, is a notice and is not installed, so review the change, then run `claude-config restore skills --accept <name>`, which in a clone also records the new value; a skill it can't check is named on the ok line
- reinstalls REA's bundled `reverse-engineer-anything` skill when it differs from the installed `rea-agents` (`rea setup --skill`), so the skill matches the server
- re-runs the pinned Hindsight memory installer (`hindsight-memory upgrade`, only when `~/.hindsight/coding-agent.json` exists) and reports a newer release as a notice once npm's `min-release-age` lets it install, telling you to merge the Renovate pull request that bumps the version pin in `bin/hindsight-memory` (Renovate never merges it itself); the installer's own `▲` warnings (no `uv`, no `cargo`, no model) become a notice too, because each means the memory daemon can't cold-start from that shell. It also syncs the daemon's locked environment and stops the daemon when the lock changed, so the next prompt starts it from the new one; an environment that did not build is a notice
- refreshes the SnippetsLab skill from the app when SnippetsLab is installed (`install-snippetslab-skill`)
- refreshes the Claude Code marketplaces and updates every installed plugin (`claude plugin marketplace update`, then `claude plugin update` per plugin; Claude Code applies them on its next start; `-y` accepts a marketplace-declared install command without showing it, since the tracked marketplaces are vetted ones)
- drops retired Claude Code permission rules from this Mac and uninstalls retired plugins (`claude-config retire`, which only removes), then records the plugins, base settings and user skills in the repo (`claude-config save`, review with `git diff`; skipped with an action when the repo has plugins or settings this Mac lacks) and rebuilds the catalog (`claude-catalog`), then checks mise's MCP server: if its user-scope entry isn't `✔ Connected` and runs a different command from what setup writes (a moved binary, an old wrapper), it's re-registered; otherwise it warns, naming anthropics/claude-code#88128 when the server lists no tools. A missing registration is left alone
- asks Raycast to check for app and extension updates
- updates Amp, if it's installed

A step that belongs to a [module](modules.md) you switched off (`rotm settings set modules.<module> off`) prints `the <module> module is off` and does nothing: the font with `fonts`, Raycast with `apps`, the Google Cloud CLI with `cloud`, the Claude Code steps with `claude`, and the REA, Hindsight, SnippetsLab, Scrapling and mise MCP steps with `agents`. Browser Use has no step of its own: the uv tools step upgrades it. The package steps need no switch, because mise no longer reads that module's file. The packages it installed stay, so the notice that counts packages no config declares names the modules that are off. A package you declared `{ state = "absent" }` in `config.local.toml` is not reported as missing.

It doesn't re-apply the dotfiles. When a pull brings new symlinks, tools or config, run setup again:

```shell
"$DOTFILES/setup.sh" # add `-- --skip packages` to leave the packages alone
```

`setup.sh` installs what's missing but doesn't upgrade what's already there, except PowerShell (`dotnet tool update`) and the Iosevka Code font. There are two ways to upgrade. `./setup.sh -- --upgrade` upgrades what the mise config declares: the packages, one manager at a time with a warning on failure, and the tools. `sysup` upgrades everything: macOS, mise itself, the packages, the tools, Rust, the uv tools and the agent tooling.

## A Mac set up before the mise-first setup

A Mac set up from this repository before 2026-11-11 installed its packages with Homebrew itself, and `git pull` alone does not bring it across. You have one when `command -v mise` prints `/opt/homebrew/bin/mise`, or `sysup` fails at `mise self-update` with "installed via a package manager". On such a Mac nothing upgrades mise or the casks Homebrew installed.

The script that moves it across, `migrate/legacy-to-mise`, was removed from `main` on 2026-11-11. Its last version is in the history at `498f513`, and its self-check passed against `main` at `e7e8eac` on 2026-11-18. That day it moved one Mac across with the steps below. In the clone:

```shell
git checkout 498f513 -- migrate
migrate/legacy-to-mise --dry-run
migrate/legacy-to-mise --step env
migrate/legacy-to-mise --step packages
```

Open a new terminal after the `packages` step moves mise, then:

```shell
migrate/legacy-to-mise --step setup
git reset -q HEAD migrate && rm -rf migrate && git status --short
```

Run the steps one at a time, because a step that exits non-zero stops the ones after it. Every change asks first and is backed up to `~/.dotfiles-migration-backup/<timestamp>/`, which holds a `RESTORE.txt`. `git show 498f513:migrate/README.md` describes each step. The `macos` step only reports. Run `--step dotfiles` before `--step setup` on a Mac that stays a clone, and leave it out on one that becomes an installed copy, because the move below expects the old folder links.

What the 2026-11-18 run found:

- **Answer no to every "Keep `<formula>`".** Nothing is removed either way. Never clear the notice that follows with `mise bootstrap packages prune`, which removes every formula no config declares.
- **Declare a cask only when mise can read it.** A tap cask whose file uses a keyword mise does not support (`azure-cli-preview`, `aspire`) breaks `mise bootstrap packages status` for every package once declared. After declaring one, run `mise bootstrap packages status --json > /dev/null`, and delete its line from `tilde/.config/mise/config.local.toml` if that fails.
- **Reinstall the casks that do not update themselves, and decline the ones that do.** The first list gets upgrades again. The second gains nothing and a replaced app can lose its privacy permissions. Homebrew then stays installed, which is harmless.
- **A cask another cask depends on stops the step.** `brew uninstall` refuses it. Run `HOMEBREW_NO_ANALYTICS=1 brew uninstall --cask --ignore-dependencies <token>` and `mise bootstrap packages apply --yes brew-cask:<token>` yourself, then run the step again.
- **The git-credential-manager installer writes to `~/.gitconfig`,** which is a link into the clone, so the last line above prints `M tilde/.gitconfig`. Add the same `credential` lines to `~/.gitconfig.local` with `git config --file ~/.gitconfig.local`, then `git checkout -- tilde/.gitconfig`.

Then either run `./setup.sh` to stay a clone, or move to an installed copy by hand with [the move runbook](superpowers/specs/completed/2026-11-15-p7-move/MOVE.md). The runbook was written for one Mac, so on another:

- Paste its opening block one line at a time. zsh expands aliases when it reads a pasted block, so in a block pasted whole `inclone` is defined with `find` still meaning `fd`, and it counts 0 links.
- Skip a line of step 2 or step 5 whose file does not exist. Not every Mac has a Mole `.local` list, a `hosts.yml`, hunk's `state.json` or every VS Code folder.
- Start setup from `~`, not from inside the clone, and add `--without <modules>` to that line to leave modules out.
- Afterwards look for links that still resolve into the clone. `~/.config/mole/whitelist_optimize` stayed one: remove the link and run `mise dotfiles apply --yes` from `~`.

Nothing in the product does the move, and no test covers this section: it records one run.

## The repository's own updates

The repo's own pins get update PRs from [Renovate](https://docs.renovatebot.com/) (config in [`renovate.json`](../renovate.json)): `package.json` and its `packageManager` pnpm, the single-version tools in the global mise config, the Hindsight hook package pin in `bin/hindsight-memory`, and the action pins and `setup-python` version in `.github/workflows/`. It waits 48 hours after a release, like `pnpm-workspace.yaml`'s `minimumReleaseAge`, opens or refreshes the daily `@ampcode/plugin` snapshots only early on Monday (New York time), and keeps mise's `npm:typescript` below 7 and `azure-functions-core-tools` below 5. It skips mise's `node` and `python`: its mise manager reads only the first entry of a version list, so it would rewrite the default and leave the rest. Those, like `.nvmrc`'s `lts/*`, stay manual. The `check` workflow ([`.github/workflows/check.yml`](../.github/workflows/check.yml)) runs `pnpm check` on macOS for every PR, its PRs included, and every push to `main`. Its Dependency Dashboard issue lists held and pending updates; tick a PR's rebase box there to re-run the check on a PR opened before a workflow change. The packages in `30-packages.toml` and mise's `latest` entries stay with `sysup`; VS Code updates its own extensions.

A tracked agent skill from a source that is not in `agents/claude-skills-trusted.txt` gets a pull request too, named "Review skill <name>", from the `skill-review` workflow ([claude-config](claude-config.md#a-skill-from-a-source-that-is-not-trusted)).

## After a VS Code update

An update of VS Code replaces the files the SpaceBox UI Enhancer patched, so run **SpaceBox Enable UI Enhancer** again afterwards (see [vscode](../vscode/README.md#spacebox-ui-enhancer)).

## macOS update password from 1Password (optional)

`sysup` starts with a fingerprint for `sudo`, but a macOS update still stops at `Password:`. That prompt comes from `softwareupdate` itself: on Apple Silicon only the account password authorizes an OS update, and neither `sudo` nor Touch ID counts. If you keep that password in 1Password, `sysup` can fetch it with a fingerprint instead. Without this setup nothing changes and you type the password as before.

1. In 1Password, save your Mac login password as an item (a Login or Password item; any vault).
1. Turn on **Settings → Developer → Integrate with 1Password CLI**. The `op` command is the `brew-cask:1password-cli` package.
1. Copy the field's secret reference: open the item, click the arrow next to the password field → **Copy Secret Reference**. It looks like `op://Private/Mac login/password`.
1. Store it with [`dotfiles-settings`](../settings/README.md), which keeps it in `~/.config/rotm/config.override.toml`, a file of your own outside the repository:

   ```shell
   dotfiles-settings set updates.mac_password_op 'op://Private/Mac login/password'
   ```

   An `export DOTFILES_MAC_PASSWORD_OP=…` in [`~/.zsh.local`](local-customizations.md#zshlocal) still works. It is the seed that the setting beats.

1. Open a new terminal and check that it resolves (this prints nothing but `ok`):

   ```shell
   op read "$DOTFILES_MAC_PASSWORD_OP" > /dev/null && echo ok
   ```

`sysup` only asks 1Password when a macOS update is actually pending. If `op` is missing or the variable is unset, it asks for the password at its own `Password:` prompt, which hides what you type, and passes it to `softwareupdate` the same way. A password `softwareupdate` rejects fails the macOS step; there is no retry. Update the 1Password item when you change your login password.
