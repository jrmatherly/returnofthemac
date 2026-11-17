# claude-config

`bin/claude-config` keeps this machine's Claude Code setup in the repo: which plugins are installed, the base `settings.json`, and which user skills are installed for which agents. `save` records the machine into three tracked files under `agents/`; `restore` brings a new Mac up to that state. `setup/misc.sh` runs `restore` last, and `sysup` runs `restore skills --update`, `retire` and then `save`, skipping `save` when `restore --dry-run` finds plugins or settings this Mac lacks, since it would erase them from the tracked files. On an installed copy (see [setup](../setup/README.md#installed-copies)) `sysup` never runs `save`, which would write into mise's checkout.

## Summary

- In a clone, run `claude-config save` after installing or removing a plugin or skill, or changing a setting, then review `git diff agents/` and commit. `save` records what this machine has now.
- `save` never shrinks a tracked file whose source is missing on this machine (a Mac that is not set up yet). It warns and keeps the tracked file. Writes go through a temp file and `mv`.
- `restore` adds. Settings already on the machine win, permission lists are unioned, and nothing is rewritten when nothing is missing. The one removal: allow rules listed in `agents/claude-permissions-retired.txt` are dropped by `restore`, `save` and `retire`. Add a rule there when you remove it from `agents/claude-settings.json`, or another Mac keeps it and its next `save` brings it back. The same goes for a plugin: list it in `agents/claude-plugins-retired.txt` when you remove its line from `agents/claude-plugins.txt`, and `restore` and `retire` uninstall it while `save` leaves it out. `sysup` runs `retire`, which only removes, so a pull can't grant anything: new rules wait for a `restore` you run yourself.
- Secrets never land in the tracked settings: credential helpers are dropped, and of `env` only Claude Code's own switches and the variables plugin hooks read (`AZURE_MCP_COLLECT_TELEMETRY`, `HINDSIGHT_API_LLM_PROVIDER` and the `HINDSIGHT_API_*LLM_MODEL` pins) survive.

## Commands

| Command | What it does |
| --- | --- |
| `claude-config save` | Write `agents/claude-plugins.txt`, `agents/claude-settings.json` and `agents/claude-skills.txt` from this machine. It needs a clone: an installed copy refuses unless `CLAUDE_CONFIG_SAVE_DIR` names another folder |
| `claude-config restore` | Add missing marketplaces and plugins, merge the base settings, install missing skills |
| `claude-config restore plugins` / `settings` / `skills` | One part only |
| `claude-config retire` | Drop retired allow rules from this Mac's settings and change nothing else |
| `claude-config restore ... --dry-run` | Print what that part would do |
| `claude-config restore skills --update` | For a source listed in `agents/claude-skills-trusted.txt`: reinstall a skill whose upstream moved past the installed copy, for every agent on its row, and print `skill updated <name>`; such a skill is never held, and one an agent lacks is installed even when the source can't be checked. For any other source: install a skill whose reviewed value moved in the repository past the installed copy (a merged review, `skill updated <name>`), and otherwise compare each tracked skill's source with its reviewed value, the row's fifth field (on GitHub its folder's git tree SHA, one `gh api` call per repository; for a well-known source such as `siderolabs`, the `digest` in the site's `/.well-known/agent-skills/index.json`), or with the lock's `skillFolderHash` or `wellKnownDigest` for a row without one; prints `skill same\|changed\|unknown <name>` per skill and installs a `same` one for agents that lack it; a `changed` or `unknown` one is never installed, and when an agent lacks it the next line is `skill held <name>` (`sysup` does this) |
| `claude-config restore skills --accept <name>` | For a source that is not on the trusted list: reinstall that one skill for every agent on its row, after you reviewed its upstream change. In a clone it records the new value in `agents/claude-skills.txt`, the only way a GitHub row's reviewed value moves on a Mac: plain `save` keeps it, because a merged review may be ahead of this Mac's copy. Exits 2 for a name the list doesn't track |

## The tracked files

| File | Contents | On restore |
| --- | --- | --- |
| `agents/claude-plugins.txt` | `marketplace <name> <source>` lines and `plugin <id>[ disabled]` lines for user-scope plugins | Missing marketplaces are added; missing plugins installed (after a `claude plugin marketplace update <name>` for a marketplace already on the machine, which may predate the plugin); recorded-disabled plugins are disabled only on a fresh install |
| `agents/claude-settings.json` | `~/.claude/settings.json` minus the keys tools own (`enabledPlugins`, `extraKnownMarketplaces`, `hooks`), with `$HOME` written as `~` where it starts a path and permission lists sorted, with gitignore negations such as `Read(!.env.example)` moved last because a negation only carves out of the rules before it. Never saved: `apiKeyHelper`, `awsCredentialExport`, `awsAuthRefresh`, `otelHeadersHelper`, and any `env` entry other than `CLAUDE_CODE_*` (minus the LLM Router's `CLAUDE_CODE_ENABLE_GATEWAY_MODEL_DISCOVERY` and `CLAUDE_CODE_DISABLE_UNKNOWN_MODEL_WINDOW_ENFORCEMENT`), `DISABLE_*`, `MAX_*`, `AZURE_MCP_COLLECT_TELEMETRY`, `HINDSIGHT_API_LLM_PROVIDER` and the `HINDSIGHT_API_*LLM_MODEL` pins. `model` is not recorded: `save` keeps the tracked value, so change the standard by editing the file | Merged into the live file: existing values win, permission lists are unioned, no rewrite when nothing is missing. An invalid merge warns instead of aborting |
| `agents/claude-skills.txt` | `skill <name> <source> <agents> [<reviewed> [<folder>]]` from `~/.agents/.skill-lock.json`, where `<reviewed>` is the lock's `skillFolderHash` or `wellKnownDigest`, and is absent for a trusted source. `<folder>`, the sixth field, is the directory that holds `SKILL.md` in a GitHub source that is not trusted (`.` at the repository root). A `well-known` source is saved as the URL the CLI stored, since its bare host fails as a git clone | `npx skills add <source> -g -s <name> -a <agents> -y` for the agents that lack it (under `--update`, only for a skill that matches its reviewed value), with telemetry off and stdin from `/dev/null` |
| `agents/claude-skills-trusted.txt` | One skill source per line, spelled as the source field of `claude-skills.txt`. Kept by hand: `save` never writes it. Removing a trusted source's last skill fails `pnpm check` until its line leaves the list | Read by `restore skills --update` and by `save` |

Agents map to folders: `claude-code` is `~/.claude/skills`, `codex` is `~/.agents/skills`.

## A skill from a source that is not trusted

Add it with `npx skills add`, then run `claude-config save` in a clone and record the result in git: the row holds the reviewed value and the skill's folder. From then on the `skill-review` workflow checks the source daily, and a change upstream arrives as a pull request named "Review skill <name>" that moves the row's reviewed value and lists the files added, removed and changed. Merging it is the review. `check` does not start on it by itself, because the workflow's token opened it, so close and reopen the pull request first. The next `sysup` after the merge is promoted installs the skill. A well-known source is not covered: `sysup` reports its change and `claude-config restore skills --accept <name>` takes it.

## On a fresh Mac

`setup/misc.sh` runs `claude-config restore` after Claude Code, npm config and PowerShell are in place, then `claude-catalog`. Both steps warn on failure and never abort setup.

## Why not the CLI's own update

`npx skills update` reinstalls every skill with no agent list, so a skill tracked for one agent spreads to all of them. `restore skills --accept <name>` reinstalls one skill for exactly the agents the tracked file lists.

## Dependencies

`jq` (a `brew:` package); `npx` with Node from mise for skills. Reads `~/.claude` (or `$CLAUDE_CONFIG_DIR`) and `~/.agents`.

See also `help claude-catalog` and [`agents/README.md`](../agents/README.md).
