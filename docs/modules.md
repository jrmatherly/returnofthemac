# Modules: leaving parts out

Everything outside the base is grouped into seventeen modules, and each one can be switched off. All of them are on by default, and a module added in a later update is on too. The base is what the dotfiles themselves run: Git, Zsh, mise, uv, jq, the shell tools, the terminals and VS Code.

| Module | What it holds | Leans on |
| --- | --- | --- |
| `fonts` | The seven Nerd Font casks, and the Iosevka Code font that setup and `sysup` install for VS Code |  |
| `apps` | The GUI apps, 1Password among them, and the language servers for Terax's editor |  |
| `vscode` | Every VS Code extension, and the CodeQL CLI its CodeQL extension runs. VS Code itself is in the base |  |
| `claude` | Claude Code: its installer, its saved config and skills, the plugin catalog, `bun`, and the `catalog.md` Claude rule. A rule already linked stays when the module is switched off later |  |
| `agents` | `rtk`, CodeRabbit, CodeGraph, REA, Serena, Scrapling, Browser Use, Hindsight memory, the MCP server registrations, and the `rtk.md` and `hindsight.md` Claude rules. A rule already linked stays when the module is switched off later | `claude` for the registrations. Hindsight's daemon needs `cargo`, from `rustup` in `devops`. REA also uses Ghidra (`security`) and Hopper (`apps`) when they are there |
| `cloud` | The Azure, AWS and Google Cloud CLIs, `azd`, Azure Functions Core Tools, Aspire and Serverless |  |
| `kubernetes` | Kubernetes, container and infra CLIs, OrbStack and Docker, `flux2`, `talosctl`, `mirrord` and `lazydocker` |  |
| `devops` | CI, linting and DevOps formulae, `rustup`, and the Sentry CLI |  |
| `security` | Security and pentesting formulae, such as `nmap`, `hydra` and `ghidra` |  |
| `network` | Networking and system utilities |  |
| `languages` | Language runtimes and build tools from Homebrew, `pnpm` among them, and `ni` |  |
| `media` | File, text and image processing formulae, Mole among them |  |
| `menubar` | Return of the Mac, the menu bar app over `rotm settings`, which setup opens once it is installed |  |
| `multipass` | Claude Multipass, the owner's tool that switches Claude Desktop between accounts, and its menu bar app |  |
| `itsaplan` | A registration, not a package: the MCP server of It's a Plan, the owner's tracker at `plan.matherly.net`, which answers only on his network. Off leaves the registration in place | `claude` |
| `touchid` | A system change, not a package: `/etc/pam.d/sudo_local`, which lets `sudo` accept Touch ID. Off leaves the file as it is |  |
| `loginshell` | A system change, not a package: Homebrew's zsh as the login shell. Off leaves the account's shell as it is |  |

Each module is one file, `tilde/.config/mise/conf.d/60-rotm-<name>.toml`, and its first lines say what turning it off leaves behind.

## Switching a module off or on

After the first install:

```shell
rotm settings set modules.security off
rotm settings set modules.security on
```

The same switches are in the Modules section of `rotm settings tui`. To leave modules out from the first install, add `--without` to the install line, as in `| bash -s -- --without security,cloud` ([installation](installation.md)).

What off does:

- Nothing more is installed or updated for that module, and setup and `sysup` skip its steps.
- Its formulae, casks and VS Code extensions stay installed. `mise bootstrap packages prune` removes them, but it removes every package no config declares, not only this module's, so read `mise bootstrap packages prune --dry-run` first.
- Its mise tools go at the next `sysup`, whose `mise prune` step deletes tool versions no config uses.

Until you prune, `sysup` keeps mentioning the packages no config declares, and its notice names the modules that are off. A module switched back on is installed by the next `rotm update` or `setup.sh`.

The choice is stored in `~/.config/rotm/modules-off.local`, a file of your own that mise's config dir links to, and in the `ignored_config_paths` line of the git-ignored `miserc.local.toml` in that config dir. No tracked file changes, so an installed copy still updates. [Settings sync](settings-sync.md) carries `modules-off.local` to your next Mac. A shell with `MISE_IGNORED_CONFIG_PATHS` set uses that list instead, and an off module loads there.

## Skipping one package or tool

To skip a single package from a module that stays on, declare it absent in `~/.config/rotm/config.override.toml`, and turn a mise tool off with `disable_tools`:

```toml
# ~/.config/rotm/config.override.toml
[bootstrap.packages]
"brew-cask:warp" = { state = "absent" }

[settings]
disable_tools = ["npm:serverless"]
```

`rotm settings` keeps its own changes in the same file, under `[env]` and `[bootstrap.settings.macos.defaults]`, and leaves these tables alone. [Settings sync](settings-sync.md) saves the file, so both opt-outs reach your next Mac. An opt-out left in `~/.config/mise/config.local.toml` still works and stays on that Mac, because mise never syncs a `*.local.toml` file.

An absent package that is already installed is left in place, and neither setup nor `sysup` reports it as a problem. This works for a `vscode:` key too: mise reports the extension as absent and never installs or removes it. With such an extension installed, `mise bootstrap packages apply --manager vscode` exits 1, which setup treats as no problem, while a plain `apply` and `upgrade` exit 0.

## Sources outside Homebrew's own lists

These taps are declared by a fragment, so their formulae and casks install with the module that uses them:

| Tap | Serves | Module |
| --- | --- | --- |
| `jrmatherly/tap` | `claude-multipass`, `claude-multipass-app`, `returnofthemac-app` | `multipass`, `menubar` |
| `kubestellar/tap` | `kubestellar-deploy`, `kubestellar-ops` | `kubernetes` |
| `skyhook-io/tap` | `radar` | `kubernetes` |
| `bramstein/webfonttools` | `sfnt2woff` | `media` |

A tap's formula is whatever its owner last pushed, and mise's release-age hold does not cover `brew:` packages.

Three mise tools install with no checksum or attestation that mise can verify: `azd` and `azure-functions-core-tools` (`cloud`) and `github:getsentry/toolkit` (`devops`). To skip them and keep their module:

```toml
# ~/.config/rotm/config.override.toml
[settings]
disable_tools = ["azd", "azure-functions-core-tools", "github:getsentry/toolkit"]
```

## Working on the repo

`pnpm check` and the commit hook run `pnpm` (`languages`) and `shellcheck` (`devops`), and stop without them. They skip the `actionlint` (`devops`) and `rtk` (`agents`) checks when those are missing.
