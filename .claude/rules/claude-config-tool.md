---
paths:
  - 'bin/claude-config'
  - 'bin/lib/test-claude-config'
  - 'agents/claude-*'
---

# claude-config

`docs/claude-config.md` is the user guide and `bin/claude-config` the source. These are the constraints the code doesn't show.

- `save` never shrinks a tracked file: a missing or unparsable source warns and keeps it, and writes go through `.tmp` + `mv`.
- `save` drops the keys other tools own and the credential helpers, and of `env` keeps only the allowlist in `settings_filter`, because `env` is where API keys go and the saved file is committed. `MAX_THINKING_TOKENS` is kept and `CLAUDE_CODE_OAUTH_TOKEN` is not.
- Two `CLAUDE_CODE_*` switches stay out: the LLM Router strips them when its profile is switched off (read at 9.0.0), but a `save` made while one is on would track them, and `restore` never deletes a key, so tracking them would hand a gateway profile to a Mac with no router.
- `$HOME` becomes `~` only where it starts a path, and `//$HOME/` (Claude's absolute-path rule syntax) becomes `~/`.
- A `well-known` skill source is written as the URL the CLI stored (`sourceBaseUrl`), since its bare-host `source` fails as a git clone.
- `restore` merges with existing values winning and permission lists unioned, so it never deletes a local rule. To remove a rule from every Mac, add it to `agents/claude-permissions-retired.txt` in the same commit that removes it from `agents/claude-settings.json`. `save`, `restore` and `retire` drop those from `permissions.allow`. A plugin is retired the same way through `agents/claude-plugins-retired.txt`: `save` leaves it out, `restore` and `retire` uninstall it at user scope. `sysup` runs only `retire`, so a pull can't add a grant, and skips `save` while the tracked files hold something this Mac lacks.
- A marketplace already on the machine may predate a plugin, so `restore` refreshes it once before the first install from it.
- `restore skills --update` reinstalls a skill from a source in `claude-skills-trusted.txt` when upstream moved past the installed copy. It compares with the lock, not a reviewed value, because an installed copy cannot record a review (`save` refuses there), and the row has no fifth field so an update changes no tracked file. For a source outside the list it installs a skill whose reviewed value in the repository is ahead of the lock (a merged review; the row's sixth field, the folder, is tracked because the review workflow has no lock), and reports a skill past its reviewed value (the fifth field `save` writes) and never installs it, not even for an agent that lacks it (`skill held <name>`, also for an `unknown` one), because a skill is third-party code that runs unreviewed otherwise.
- `save` keeps a six-field row's reviewed value (a merged review can be ahead of this Mac's lock, and `sysup` runs `save` in a clone), so `--accept` records the value it installed itself, in that one row. `--accept <name>` is the only reinstall of an untrusted skill past its review, for exactly the agents on the row, because the CLI's own `skills update` reinstalls with no agent list, so a skill tracked for one agent would spread to all.
- `setup/misc.sh` runs `restore` last, so `npx skills` runs with the npm settings. The `jrmatherly/skills` marketplace is public, so no credential is needed.
