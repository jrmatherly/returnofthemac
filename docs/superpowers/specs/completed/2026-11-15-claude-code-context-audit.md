# Claude Code context audit, 2026-11-15

Date: 2026-11-15. Status: closed the same day. The one plan built on it is finished ([Result](#result-2026-11-15)) and listed in [Plans](#plans). Findings F1, F5 and F7 stay open as out of scope, by the owner's decisions.

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

## Result (2026-11-15)

Tasks 1 to 4 of the plan ran that evening. Task 5, the three MCP servers, was skipped on the owner's word: `agent-browser`, `jean` and `astro-docs` stay on in this repository.

Read with `claude -p '/context' --model haiku --no-session-persistence` in this repository, before and after:

| Category | Before | After |
| --- | --- | --- |
| Total | 66.7k | 60.2k |
| Custom agents | 9.7k | 5.1k |
| MCP server instructions | 6.7k | 5.2k |
| MCP tools (deferred) | 249.1k | 248.1k |
| Skills | 9.9k | 9.9k |
| Memory files | 9.7k | 9.7k |

The total fell by 6,500. About 6,100 of that is the change: the agents fell by 4,600, which is the two voltagent packs and the smaller plugins' agents, and the 1,500 off the server instructions is `browser-use`, which the audit had not counted. The rest is the Messages line, which moves by a few hundred between two readings of the same state. The prediction was 5,900. **The Skills line did not move.** The session's skill count fell from 226 to 203 with no change in tokens, which fits a capped listing: turning off 14 skills and the plugins' skills freed room in it for other descriptions and saved no tokens. The cap was not tested by itself. The audit's 1,200 for the skills was wrong as a saving.

`claude plugin list --json` reported 27 plugins off before and 41 after. `listed.sh` reported all 16 names present before (the session's own Task 1 output: the file was later emptied). After, the five plugin names and three skill names read `absent`, and the eight that must stay read `present`.

### What is off in this repository, and how to bring it back

All of it is in the git-ignored `.claude/settings.local.json`, on this Mac only. A session here that looks for one of these and does not find it should read this section.

- **Plugins, under `enabledPlugins`:** `voltagent-lang@voltagent-subagents` (through `claude-stack`), and by hand `voltagent-qa-sec@voltagent-subagents`, `agent-sdk-dev`, `mcp-server-dev`, `modern-web-guidance`, `coderabbit`, `superdesign`, `commit-commands`, `claude-md-management`, `code-simplifier`, `session-report`, `browser-use`, `rust-analyzer-lsp` and `lua-lsp`, each `@claude-plugins-official`.
- **Skills, under `skillOverrides`:** `doc-coauthoring`, `email-and-password-best-practices`, `find-skills`, `hindsight-architect`, `hindsight-docs`, `internal-comms`, `mcp-builder`, `organization-best-practices`, `scrapling-official`, `sentry-cli`, `supabase-prompts`, `theme-factory`, `two-factor-authentication-best-practices`, `web-artifacts-builder`.

To bring one back, delete its key from that file and start a new session. `voltagent-lang` comes back with `~/dev/dotfiles/bin/claude-stack apply --keep voltagent-lang@voltagent-subagents`. The plan's "Undo" removes all of it by key.

### What went wrong while it ran

The first `listed.sh` started its session with the prompt `ok` and every tool, and read only the first line the session printed. The session kept running. Its start hooks gave it the handoff note, which said to execute this plan on the owner's go, and it took `ok` as that go. Six such sessions took part between 21:06 and 21:12: two that the script started, and four more that those started by running the same script again. Four ended by themselves and the last two were killed. It was noticed because Task 4's "see it fail" step did not fail.

What they did, none of it by the executing session:

- Wrote Task 3's `skillOverrides` key and made Task 4's edit.
- Ran `claude-stack apply`.
- Overwrote the saved "before" evidence in `private/context-trim/`: the three copied stack files were copied again after Task 2, `plugins-off.before` was rewritten with 41, and `listed.before` was emptied. They also wrote `listed.after-plugins` and `listed.after-skills`.
- Left five one-turn sessions in Hindsight's memory of this repository (`retain_ok` in `~/.hindsight/coding-agents-logs/diag.jsonl`, ids beginning `0c859e4f`, `09f90111`, `a87aad01`, `f84787ca`, `91a5f36e`). They held 17 extracted facts. One said the agent ran the plan "following the user's ok", which was false, and the rest were status snapshots that were stale within minutes.

  A "Correction" document was ingested first. Hindsight's documentation says a correction outranks the older fact and rewrites the belief, and that "the raw facts are always preserved" (`developer/observations.md`), so the 17 facts would have stayed for a deep query or the next page refresh to find. A correction is meant for knowledge that was once believed. These were records of sessions the owner never ran, and the main session's own transcript already held the account. So on the owner's word the five documents were deleted at about 22:04 through the documents API, which "removes a document and all its associated memories" (`developer/api/documents.md`). Checked before: all nine knowledge pages had last refreshed before the sessions ran, and none of the five had a transcript on disk, so the background import cannot bring them back. Checked after: the bank went from 102 documents to 97, no fact or belief cites any of the five ids, and no belief says the owner approved with `ok`. The correction was saved again under the same title as the lasting lesson. The one other short session retained in that window, `ac53e07f`, is a real session in another repository.

The executing session first recorded this as two sessions and two writes. An independent review found the rest from Hindsight's log and the files' change times.

What holds, checked by that review and again afterwards: `.claude/settings.local.json` differs from a true copy made before the plan by exactly the 14 plugin keys and the 14 skill names, with `permissions` identical. Nothing was committed or pushed, and there is no stash, branch, worktree, memory file or scheduled task from them. The global settings, the bootstrap lists and the installed copy are unchanged. The one true "before" copy of the settings file was a test copy the session had made at 20:36, and it is now in `private/context-trim/before/`. There is no true copy of `skill-stack.json` from before. `private/context-trim/NOTES.txt` says which files there can be trusted.

`listed.sh` now starts its session with no built-in tools (`--tools ""`), no MCP servers (`--strict-mcp-config`), plan mode and a prompt that asks for one word, and kills it as soon as the start-up list is read or the script is interrupted. Its start-up event then lists 0 tools and 0 servers, and the 16 answers are the same. `--tools ""` alone was not enough: the session still had 480 MCP tools, some of them allowed to write files by the global settings. The session's start hooks still run.

The lesson for this repository: **a headless `claude -p` here is a full agent that has read the handoff note, and can start more of itself.** Start one only through `listed.sh`.

## Plans

- `docs/superpowers/plans/completed/2026-11-15-claude-code-context-trim.md` (done 2026-11-15): findings F2, F3 and F4, in this project only. F6 was skipped.
