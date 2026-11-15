# Make it yours

This setup ships with its owner's choices in it. Nothing was taken out for being his, so a few values point at him or at his own projects. This page lists each one and how you change it. Setup already asks for your git identity and commit signing.

## On an installed copy

You change these from your own settings and your own files. None of them needs an edit to the copy, which `rotm update` replaces.

| What points at the owner | What you do |
| --- | --- |
| Time Machine is turned off, the firewall is on, and the locale (US English), power and Spotlight shortcut preferences are his | Switch a group off with `rotm settings set macos.<name> off` before you run `set-defaults`. The names are `disable_time_machine`, `firewall`, `locale`, `power` and `spotlight_hotkeys`. **If you use Time Machine, run `rotm settings set macos.disable_time_machine off` before `set-defaults`, which otherwise stops all backups.** |
| The formulae, apps and VS Code extensions are the ones he uses | Turn a [module](modules.md) off with `rotm settings set modules.<name> off`, or [skip one package](modules.md#skipping-one-package-or-tool) |
| Claude Multipass, his own project, is in the base and in no module | Declare `"brew:jrmatherly/tap/claude-multipass"` and `"brew-cask:jrmatherly/tap/claude-multipass-app"` as `{ state = "absent" }` in `~/.config/rotm/config.override.toml`, the form under [Skipping one package or tool](modules.md#skipping-one-package-or-tool) |
| fastfetch prints his name, site and city | Edit `~/.config/fastfetch/config.jsonc`. It is your own file after the install. It stays on this Mac, because settings sync does not carry it |
| lazygit colors his name in the commit list | Write your own `gui.authorColors` in `~/Library/Application Support/lazygit/config.yml`, which lazygit reads after the tracked file from your next new shell. It stays on this Mac |
| The Claude Code plugins, settings and skills are his | Setup adds his on every run and removes none of yours. A plugin of his that you uninstall is installed again, and one you disable stays disabled. To stop setup adding them, turn the `claude` module off. The catalog's notes on his own MCP servers print a `lint:` line and nothing else |
| The menu bar app updates from his releases | Nothing to change. Turn the `menubar` module off to leave the app out |
| `github.com` uses the key at `~/.ssh/github_personal.pub` when that file exists | Export your own key to that path, or leave the file out and ssh uses its defaults. See [`~/.ssh/github_personal.pub`](local-customizations.md#sshgithub_personalpub) |

A value that points at the owner, has no row here and cannot be changed without editing the copy is a bug. Please report it.

## In a fork

These are edits to tracked files. The values are hard-coded to me, so change them in your fork:

| File | What to change |
| --- | --- |
| [`README.md`](../README.md), [`docs/installation.md`](installation.md), [`docs/macos tips & tricks.md`](macos%20tips%20%26%20tricks.md) | Title, intro and the `jrmatherly/returnofthemac` clone URL and link |
| [`agents/README.md`](../agents/README.md) | The `jrmatherly/skills` links point to my skills repo. Use it, your own, or the [skills CLI](https://github.com/vercel-labs/skills) alone |
| [`tilde/.config/fastfetch/config.jsonc`](../tilde/.config/fastfetch/config.jsonc) | Name, URL and weather `location` |
| [`lazygit/config.yml`](../lazygit/config.yml) | The author name under `authorColors` |
| [`agents/claude-*`](../agents/) | My Claude Code plugins, settings and skills, including the `jrmatherly-skills` marketplace (`jstack`, `resume`) and the `coding-standards` and `supabase-prompts` skills from my public skills repo. Keep them or drop those lines. Run `claude-config save` once yours are installed and commit the result |
| [`agents/catalog/curated.toml`](../agents/catalog/curated.toml) | Notes on my tools. `claude-catalog` still builds but exits 1 (a warning in setup) for each skill, command or agent you don't have installed. Delete those. An `[mcp.*]` entry you lack, like my `coolify` and `reactive-resume` servers (both on my own domain, so point them at your own hosts or delete them), only prints a `lint:` note, because MCP registration is per machine |
| [`30-packages.toml`](../tilde/.config/mise/conf.d/30-packages.toml), the [modules](modules.md) (`conf.d/60-rotm-*.toml`), and the tools in [`config.toml`](../tilde/.config/mise/config.toml) | My formulae, apps and VS Code extensions. Trim the modules or turn them off before the first run. The `jrmatherly/tap` entries (`claude-multipass` and its app, and the `menubar` module's `returnofthemac-app`) are my own projects |
| [`settings/registry.toml`](../settings/registry.toml) | `macos.disable_time_machine` and `macos.firewall` default to on, my choice, as do `macos.locale` (US English), `macos.power` and `macos.spotlight_hotkeys`. **If you use Time Machine, run `dotfiles-settings set macos.disable_time_machine off` before `set-defaults`, which otherwise stops all backups.** |
| [`package.json`](../package.json) | The `author` field |
| [`settings/README.md`](../settings/README.md) | The `uv tool install` line names `jrmatherly/returnofthemac` |
| [`setup/README.md`](../setup/README.md) | The `misc` section links my `jrmatherly/skills` repo and names its `jrmatherly-skills` marketplace |
| [`setup/bootstrap-runtime.archify.json`](../setup/bootstrap-runtime.archify.json) | The `meta.repository.url` clone URL (Archify's source for the setup diagram; the exported SVG doesn't show it) |
| [`app/scripts/build-app.sh`](../app/scripts/build-app.sh) | The menu bar app's bundle id, `net.matherly.returnofthemac` (the `APP_BUNDLE_ID` default). Use a reverse-DNS id of your own |
| [`.github/workflows/app-release.yml`](../.github/workflows/app-release.yml) | A pushed `app-v<version>` tag signs the app with my Developer ID (team `7BSA2L4Z5L`) and notarizes it through five repository secrets: `MACOS_CERT_P12`, `MACOS_CERT_PASSWORD`, `APPLE_API_KEY_ID`, `APPLE_API_ISSUER_ID` and `APPLE_API_KEY_P8`. Set your own, or push no `app-v` tags. The DMG goes to the release of that tag on the repository the workflow runs in (`https://github.com/<owner>/<repo>/releases/tag/app-v<version>`), so a fork publishes to its own |
| [`app/Sources/RotmCore/AppUpdate.swift`](../app/Sources/RotmCore/AppUpdate.swift) | Where the menu bar app looks for its own update: the cask `brew-cask:jrmatherly/tap/returnofthemac-app`, that cask's file in my tap (`caskURL`) and my releases page (`releasesURL`). Point all three at your tap and repository, or the app tells your users about my releases |
| [`install.sh`](../install.sh) | The `repo` URL it has mise fetch, and the `raw.githubusercontent.com/jrmatherly/returnofthemac` URL in its header and in the install line of the README and `docs/installation.md`. Point them at your fork, or the line installs my repository. [`setup/tests/install.sh`](../setup/tests/install.sh) reads the `repo` line, so the gate follows it |
| [`.github/workflows/fresh-install.yml`](../.github/workflows/fresh-install.yml) | The install line's `raw.githubusercontent.com/jrmatherly/returnofthemac` URL. Point it at your fork, or the `installed` run tests my repository |
| [`docs/menu-bar.md`](menu-bar.md) | The `jrmatherly/tap/returnofthemac-app` cask and the `jrmatherly/homebrew-tap` file the app reads. Keep them in step with the `AppUpdate.swift` row |
| [`tilde/.ssh/config`](../tilde/.ssh/config) | `github.com` uses `~/.ssh/github_personal.pub` with `IdentitiesOnly yes` when that file exists, and every host uses the 1Password SSH agent when its socket exists. Without either, ssh uses its defaults. Export your GitHub key to that path, or change the path |
| [`LICENSE`](../LICENSE) | Add your copyright line; keep the existing ones (MIT requires it) |

[`docs/jstack.md`](jstack.md) and [`docs/gui/raycast.md`](gui/raycast.md) also link my own projects (`jrmatherly/skills`, `jrmatherly/claude-multipass`); they describe tools this setup installs, so keep them unless you drop those tools.
