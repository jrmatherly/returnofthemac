# Claude Code context audit, 2026-11-15

Date: 2026-11-15. Status: findings recorded, one plan written and not started. The plan is listed in [Plans](#plans).

## Goal

Cut what Claude Code loads into a session in this repository, without touching what the repository ships to a Mac or what other projects on the Mac get. The audit is a `/doctor` run in the dotfiles session of 2026-11-15.

## Decisions the owner made (2026-11-15)

1. **A change affects this project only.** This repository bootstraps a Mac with the owner's preferred settings, agents, skills, tools, plugins and MCP servers. Much of that is unused here and used in other projects. So nothing in the bootstrap configuration changes (`agents/claude-plugins.txt`, `agents/claude-skills.txt`, `agents/catalog/curated.toml`, `setup/`, `tilde/`), and nothing in the global configuration (`~/.claude/settings.json`, `~/.claude/rules/`, `~/.claude/skills/`).
2. **The CodeGraph prompt hook is left alone.** It is installed globally and has no per-project switch (finding F1). The finding is recorded here, for a separate decision about the bootstrap.

## What a project-only change can use

| Lever | File | Reach |
| --- | --- | --- |
| `enabledPlugins: {"<plugin>@<marketplace>": false}` | `.claude/settings.local.json` | This project. Git-ignored |
| `claude-stack apply --off <key>` | The same file, plus `.claude/skill-stack.json` and `.claude/rules/skill-stack.md` | This project. All three git-ignored. Only for a plugin in `curated.toml`'s `[stack.signals]` |
| `skillOverrides: {"<skill>": "off"}` | `.claude/settings.local.json` | This project, and it does hide a skill from `~/.claude/skills` (tried, below) |
| `/mcp disable <server>` | The project's entry in `~/.claude.json` | This project |
| An edit to a file under `.claude/` that the repository tracks | `.claude/skills/add-tool/SKILL.md` | Sessions in this repository, on any Mac that clones it |

Tried on 2026-11-15, Claude Code 2.1.325: with `"skillOverrides": {"theme-factory": "off"}` added to `.claude/settings.local.json`, a `claude -p` session in this repository reported `theme-factory=absent` and `archify=present`. Both are skills in `~/.claude/skills`. The file was then restored.

## Findings

Measured on the owner's Mac. Token figures are estimates, characters divided by four. Two windows were scanned: the session transcripts of the last 14 days, across every project, for usage and hook output, and the 50 most recent sessions (10 hours, 38 projects) for hook timing and denials. `usage.py` and `hooks-and-denials.py` in [`2026-11-15-claude-code-context-audit/`](2026-11-15-claude-code-context-audit/) print both, as counts and names only, and `listed.sh` beside them prints what a new session starts with.

The first run of `usage.py` read 601 top-level transcripts. A review found that subagent transcripts are nested and were missed, so it is recursive now and reads 2,316 files for the same 14 days. The hook and prompt figures below are from the first run. The zero-use findings were checked again on the full set and hold. The 50-session window moves with each run, so its counts are of that evening and will not reproduce.

The usage counters in `~/.claude.json` are per Mac, not per project. A plugin with a count of zero is unused in every project so far, which is stronger than this audit needs: a plugin another project starts using stays on there.

### What is healthy

- One install, native, at 2.1.325. No npm leftovers, and `~/.local/bin` is on `PATH`.
- The three settings files and `~/.claude.json` parse.
- Auto mode is the default at user scope, and the project does not override it.
- `~/.claude/CLAUDE.md` does not repeat a checked-in file.
- The checked-in instruction files are lean. `bin/lib/test-conventions` caps them, and 12 of the 14 project rules load only for matching paths.

### F1. The CodeGraph prompt hook is the largest recurring cost (out of scope, decision 2)

`codegraph install` adds a `UserPromptSubmit` hook, `codegraph prompt-hook`, to `~/.claude/settings.json`. It ran on 3,425 prompts in 14 days and added 41.7 million characters, 12,172 per prompt on average, which is about 3,000 tokens a prompt. In the 10-hour window its median was 0.6 s, its 90th percentile 3.3 s, and one run hit 30 s and timed out. In the session that ran this audit, the injected source was often unrelated to the prompt.

Tried in a scratch home (CodeGraph 1.6.2): `codegraph install --yes --target claude --location global` writes the hook, and writes it back after the hook is deleted from the file. `codegraph install --refresh` does not. Its help text and README name no option, config key or variable that leaves the hook out or silences it in one project. `setup/misc.sh` runs the install on every setup run.

### F2. Fourteen plugins are unused here

Enabled at user scope, a lifetime count of 0 or 1 in `pluginUsage`, and no skill, command, agent or tool call from them in 14 days of transcripts.

| Plugin | Uses since install | Listing cost | `claude-stack` can turn it off |
| --- | --- | --- | --- |
| `voltagent-lang@voltagent-subagents` | 0 | about 1,800 (30 agents) | Yes |
| `voltagent-qa-sec@voltagent-subagents` | 1, on 2026-10-19 | about 1,100 (19 agents) | No |
| `agent-sdk-dev@claude-plugins-official` | 0 | about 360 | No |
| `mcp-server-dev@claude-plugins-official` | 0 | about 360 | No |
| `modern-web-guidance@claude-plugins-official` | 0 | about 290 | No |
| `coderabbit@claude-plugins-official` | 0, installed 6 days ago | about 240 | No |
| `superdesign@claude-plugins-official` | 0 | about 160 | No |
| `commit-commands@claude-plugins-official` | 0 | about 140 | No |
| `claude-md-management@claude-plugins-official` | 0 | about 130 | No |
| `code-simplifier@claude-plugins-official` | 0 | about 100 | No |
| `session-report@claude-plugins-official` | 0 | about 50 | No |
| `browser-use@claude-plugins-official` | 0 | not counted: its tools are deferred, but its server adds a long instructions block to every session | No |
| `rust-analyzer-lsp@claude-plugins-official` | 0 | none | No |
| `lua-lsp@claude-plugins-official` | 0 | none | No |

About 4,700 tokens a session, not counting `browser-use`'s instructions. The two voltagent figures are read off the session's agent list, because their install folders did not match the script's layout. `lua-lsp` was installed on 2026-10-25 and the repository holds four `.lua` files, in the mise vscode plugin, so turning it off costs Lua diagnostics on those four.

`claude-stack` turns off only a plugin named in `[stack.signals]` of `agents/catalog/curated.toml`, and calls the rest core. Its scan keeps `voltagent-lang` here because the repository holds Python. The other thirteen need the `enabledPlugins` entry written by hand. `merge_settings` in `agents/catalog/stack.py` removes and rewrites only the keys the manifest lists as owned.

### F3. Fourteen user skills are unused here

In `~/.claude/skills`, with no entry in `skillUsage` and no call in 14 days: `doc-coauthoring`, `email-and-password-best-practices`, `find-skills`, `hindsight-architect`, `hindsight-docs`, `internal-comms`, `mcp-builder`, `organization-best-practices`, `scrapling-official`, `sentry-cli`, `supabase-prompts`, `theme-factory`, `two-factor-authentication-best-practices`, `web-artifacts-builder`. About 1,200 tokens of listing.

The skill listing is over its budget: the session's listing shows many skills by name with no description, which is what Claude Code does when the descriptions do not fit.

Kept, though their counter is zero: `coding-standards` (jstack reads it, which is not a call), `hindsight-coding-agent` (the Hindsight rule points at it), `reverse-engineer-anything` and `snippetslab` (installed for their MCP servers).

### F4. One skill file fails a strict YAML parse

`.claude/skills/add-tool/SKILL.md`, line 3: the `description:` value holds an unquoted `: ` ("…these dotfiles: mise package vs…"). Ruby's YAML rejects it. Claude Code loaded the skill with its description in this session, so nothing is broken today. Of the 29 agent and skill files checked, it is the only one.

### F5. A hook that rewrites a call costs a retry in auto mode (out of scope, global)

Of 31 denied tool calls in the 10-hour window, 21 were `automode-unavailable`. Claude Code's message for them says a hook changed the call's input after auto mode reviewed it. For a Bash call the hook that rewrites the command is rtk's. About a third of them are `Edit`, `Write` and `Agent` calls (10 in a later run of the script), which rtk does not rewrite. The audit session saw why: when one response holds a Bash call and other calls, the rewrite of the Bash call voids the review of the others too, and Claude Code says so ("another call in this response was changed after auto mode reviewed it"). Each costs a second call. None was the owner saying no. The commands differ each time, so no allow rule would match them.

### F6. Three MCP servers this project never calls

`agent-browser`, `jean` and `astro-docs` had no call in 14 days, in any project, and nothing here names them. `mise` and `snippetslab` had none either, and `scrapling` had 16, all from subagents. `setup/misc.sh` registers those three and `sysup` checks the first, so a session in this repository is where a fault in them would be seen, and they stay on. The tools of all six are deferred. `agent-browser` adds a short instructions block to every session.

### F7. What `/usage` flagged, last 7 days (out of scope)

| Share | Finding | Where it would be fixed |
| --- | --- | --- |
| 86% | Long sessions carried across tasks | The owner: `/clear` between tasks |
| 26% | `~/dev/career-ops/AGENTS.md` is 103,465 characters, about 26,000 tokens a request | The career-ops repository |
| 24% | The jstack plugin, on in every project | Other projects, through `/project-stack` there |
| 12% | `jstack:j-agent` subagents: 936 spawns in 14 days | `~/.claude/rules/jstack-models.md`, a global file |
| 12% | `ccd_turn` | Nowhere: it is Claude Desktop's own task list |

The j-agent file sets no model. Each spawn takes its model from `jstack-models.md`, where `swarm workers` and the four code roles read `opus medium` by the owner's hand, and the skill's own default is `sonnet medium`.

### Context that loads at session start, estimated

| Component | Tokens |
| --- | --- |
| Skill, command and agent listings of every installed plugin | about 31,000 |
| `CLAUDE.md` | 3,000 |
| `~/.claude/rules`, the 8 without `paths:` | 2,300 |
| `~/.claude/skills` listing | 2,200 |
| `bin/CLAUDE.md`, when working under `bin/` | 1,400 |
| Project rules without `paths:` | 400 |

`claude-catalog` printed 56,530 always-on tokens the same evening, by its own method. `/context` gives the live figure.

## Plans

- `docs/superpowers/plans/2026-11-15-claude-code-context-trim.md` (written 2026-11-15, not started): findings F2, F3, F4 and F6, in this project only.
