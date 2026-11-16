# Claude Code Context Trim, Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A Claude Code session in this repository stops loading 14 plugins and 14 skills that nothing here uses, and nothing else on the Mac changes.

**Architecture:** Every switch goes into this project's git-ignored `.claude/settings.local.json`, one through `claude-stack` and the rest by a `jq` merge, because Claude Code reads that file for this project only. One tracked project file gets a one-line fix. Each task ends by reading what a new session starts with, from the session's own start-up list and from `claude plugin list`. No model is asked.

**Tech Stack:** `jq`, `bin/claude-stack`, the `claude` CLI, Ruby's YAML for one parse check.

**Spec:** `docs/superpowers/specs/2026-11-15-claude-code-context-audit.md`. Read its Goal and "Decisions the owner made" in full before Task 1. Findings F2, F3, F4 and F6 are this plan. F1, F5 and F7 are out of scope by decision.

## Global Constraints

- Decision 1: a change affects this project only. Do not edit `agents/claude-plugins.txt`, `agents/claude-skills.txt`, `agents/catalog/curated.toml`, anything under `setup/` or `tilde/`, `~/.claude/settings.json`, `~/.claude/rules/` or `~/.claude/skills/`.
- Decision 2: do not remove, wrap or silence the CodeGraph prompt hook.
- Do not run `claude plugin disable`, `claude plugin uninstall` or `npx skills remove`. Each changes user scope.
- Read settings files by key only (`jq '.enabledPlugins'`). They can hold secrets in `env`.
- Write a settings file through a temp file made by `mktemp` and `jq`, then `cp` over it. Never `sed` it.
- Claude Code itself writes `.claude/settings.local.json`: an "always allow" answer to a permission prompt adds a line under `permissions.allow`. So never restore the whole file from a copy, and treat a new `allow` entry as expected.
- This Mac is an installed copy. Run the clone's scripts by path: `~/dev/dotfiles/bin/claude-stack`. On 2026-11-15 the clone's `bin/claude-stack`, `agents/catalog/stack.py` and `curated.toml` were byte-identical to the copy's.
- Tasks 1 to 3 and 5 commit nothing: their files are git-ignored. Tasks 4 and 6 commit Markdown only.
- A session that is already open keeps its old list. Every check starts a new one.
- `$L` in the steps is `docs/superpowers/specs/2026-11-15-claude-code-context-audit/listed.sh`. It starts an unsaved session and prints `name=present` or `name=absent` from that session's agents, skills and slash commands. `$NAMES` is the 16 names Task 1 Step 2 sets.

## Measured for this plan (2026-11-15)

- `.claude/settings.local.json` has two keys, `enabledPlugins` and `permissions`. 21 plugins are `false` there, all written by `claude-stack`, and `.owned` in `.claude/skill-stack.json` has 21 entries.
- `.claude/settings.local.json`, `.claude/skill-stack.json`, `.claude/rules/skill-stack.md` and `private/` are git-ignored.
- `claude-stack scan` here prints `keep voltagent-lang@voltagent-subagents  path: agents/catalog/build_catalog.py`. Of the 14 plugins, only that one is in `[stack.signals]`.
- Simulated with `stack.py`'s own functions on a copy, by the reviewer: `apply --off voltagent-lang@voltagent-subagents` is accepted and gives 22 `false` and 22 owned. A later plain `apply` keeps it off and keeps hand-written entries and `skillOverrides`. `reset` removes only the owned entries.
- A `skillOverrides` entry in `.claude/settings.local.json` hides a skill from `~/.claude/skills`: with `theme-factory` set to `"off"`, `$L theme-factory archify` printed `theme-factory=absent` and `archify=present`.
- `claude plugin list --json`, run from this directory, reports the project's state: `azure@claude-plugins-official` reads `enabled: false` here and `true` from `/tmp`.
- A new session's start-up list holds 89 agents, 226 skills, 279 slash commands and 44 plugins here. A name can be in any of the first three: `voltagent-lang:python-pro` is an agent, `commit-commands:commit` a slash command, `theme-factory` a skill. `$L` checks all three.
- Asking a model which names it can see does not work. Haiku answered the 16-name question with `name=present` sixteen times.

## Review Focus

1. **A later `claude-stack apply` or `reset` drops the hand-written entries.** They must survive both. Task 2 Step 5 runs `apply` again and counts them.
2. **The `jq` merge loses or changes another key.** `permissions` may gain an `allow` entry from a prompt, and must lose nothing. Tasks 2 and 3 list what was removed, which must be nothing.
3. **A plugin turned off here is one this repository's own workflow calls.** `superpowers`, `pr-review-toolkit`, `jstack`, `remember` and `claude-docs` must stay listed. Task 2 Step 6 checks one name from each.
4. **A skill that jstack or a rule reads by path is turned off.** `coding-standards` and `hindsight-coding-agent` stay on. Task 3 Step 3 checks both.
5. **The catalog still recommends what is now off here.** `voltagent-qa-sec:ui-ux-tester`, `commit-commands:commit` and `claude-md-management:revise-claude-md` are picks in the global task guide, and `.claude/rules/skill-stack.md` lists only the plugins `claude-stack` owns. A session here gets no hint that the other 13 plugins and 14 skills are off. Task 6 puts the list and the Undo in the audit's "Result".
6. **The quoted description changes what Claude Code shows.** The parsed text must equal the old text. Task 4 Step 3 compares them.

---

### Task 1: Record the starting state

**Files:**
- Create: `private/context-trim/` (git-ignored)

**Interfaces:**
- Produces: `private/context-trim/before/` holding the three stack files as they were, and `permissions.before`, `plugins-off.before` and `listed.before` beside it. Later tasks compare with these.

- [ ] **Step 1: Copy the three files aside.**

```shell
mkdir -p private/context-trim/before
cp -p .claude/settings.local.json .claude/skill-stack.json .claude/rules/skill-stack.md private/context-trim/before/
jq -S '.permissions' .claude/settings.local.json > private/context-trim/permissions.before
```

- [ ] **Step 2: Record what Claude Code reports.**

```shell
L=docs/superpowers/specs/2026-11-15-claude-code-context-audit/listed.sh
NAMES="voltagent-lang:python-pro voltagent-qa-sec:debugger commit-commands:commit coderabbit:code-review modern-web-guidance:modern-web-guidance theme-factory mcp-builder find-skills superpowers:writing-plans pr-review-toolkit:code-reviewer jstack:j-mode remember:remember claude-docs:claude-docs coding-standards hindsight-coding-agent archify"
claude plugin list --json | jq '[.[] | select(.enabled == false)] | length' | tee private/context-trim/plugins-off.before
$L $NAMES | tee private/context-trim/listed.before
```

Run it in `bash`, or in `zsh` as `$L ${=NAMES}`, since zsh does not split an unquoted variable. Expected: a number, then 16 lines that all end in `=present`. A line that reads `absent` names something already off: note it and leave it out of the later checks.

- [ ] **Step 3: The owner runs `/context` in a new session here** and gives the session the total and the "Skills" and "Custom agents" lines. Write them to `private/context-trim/context.before`.

### Task 2: Turn the 14 plugins off for this project

**Files:**
- Modify: `.claude/settings.local.json` (git-ignored)
- Modify, through `claude-stack`: `.claude/skill-stack.json`, `.claude/rules/skill-stack.md` (git-ignored)

**Interfaces:**
- Consumes: Task 1's `private/context-trim/` files, `$L` and `$NAMES`.
- Produces: 35 `false` entries under `enabledPlugins` (21 before, 14 added).

- [ ] **Step 1: Turn off the one `claude-stack` owns.**

```shell
~/dev/dotfiles/bin/claude-stack apply --off voltagent-lang@voltagent-subagents
```

Expected: `.claude/rules/skill-stack.md` gains the line ``- `voltagent-lang@voltagent-subagents` ``, and `jq '[.enabledPlugins[] | select(. == false)] | length' .claude/settings.local.json` prints `22`.

- [ ] **Step 2: Write the other thirteen.**

```shell
t=$(mktemp) && jq '.enabledPlugins += {
  "voltagent-qa-sec@voltagent-subagents": false,
  "agent-sdk-dev@claude-plugins-official": false,
  "mcp-server-dev@claude-plugins-official": false,
  "modern-web-guidance@claude-plugins-official": false,
  "coderabbit@claude-plugins-official": false,
  "superdesign@claude-plugins-official": false,
  "commit-commands@claude-plugins-official": false,
  "claude-md-management@claude-plugins-official": false,
  "code-simplifier@claude-plugins-official": false,
  "session-report@claude-plugins-official": false,
  "browser-use@claude-plugins-official": false,
  "rust-analyzer-lsp@claude-plugins-official": false,
  "lua-lsp@claude-plugins-official": false
}' .claude/settings.local.json > "$t" && cp "$t" .claude/settings.local.json && rm "$t"
```

- [ ] **Step 3: Check the count, and that nothing was removed from `permissions`.**

```shell
jq '[.enabledPlugins[] | select(. == false)] | length' .claude/settings.local.json
jq -n --slurpfile b private/context-trim/permissions.before --slurpfile a <(jq '.permissions' .claude/settings.local.json) '($b[0].allow // []) - ($a[0].allow // [])'
```

Expected: `35`, then `[]`. An entry that is new since Task 1 is a prompt's "always allow" and is fine. An entry that is gone is a fault: stop.

- [ ] **Step 4: Check that `claude-stack` does not own the thirteen.** `jq '.owned | length' .claude/skill-stack.json` prints `22`.

- [ ] **Step 5: Run `apply` again and count again.**

```shell
~/dev/dotfiles/bin/claude-stack apply
jq '[.enabledPlugins[] | select(. == false)] | length' .claude/settings.local.json
```

Expected: `35`. If it prints `22`, `apply` rewrote the whole key: run the Undo, stop, and report it. The fix would be a change to `agents/catalog/stack.py`, which decision 1 keeps out of this plan.

- [ ] **Step 6: Read the result from Claude Code.**

```shell
claude plugin list --json | jq '[.[] | select(.enabled == false)] | length'
$L $NAMES | tee private/context-trim/listed.after-plugins
```

Expected: the number in `plugins-off.before` plus 14. The first five names read `absent`, and the other eleven `present`.

### Task 3: Turn the 14 skills off for this project

**Files:**
- Modify: `.claude/settings.local.json` (git-ignored)

**Interfaces:**
- Consumes: Task 2's file, `$L` and `$NAMES`.
- Produces: a `skillOverrides` key with 14 entries.

- [ ] **Step 1: Write the key.**

```shell
t=$(mktemp) && jq '.skillOverrides = ((.skillOverrides // {}) + ([
  "doc-coauthoring", "email-and-password-best-practices", "find-skills", "hindsight-architect",
  "hindsight-docs", "internal-comms", "mcp-builder", "organization-best-practices",
  "scrapling-official", "sentry-cli", "supabase-prompts", "theme-factory",
  "two-factor-authentication-best-practices", "web-artifacts-builder"
] | map({(.): "off"}) | add))' .claude/settings.local.json > "$t" && cp "$t" .claude/settings.local.json && rm "$t"
```

- [ ] **Step 2: Check the counts, and `permissions` with Task 2 Step 3's second line.**

```shell
jq '.skillOverrides | length' .claude/settings.local.json
jq '[.enabledPlugins[] | select(. == false)] | length' .claude/settings.local.json
```

Expected: `14`, `35`, and `[]` from the `permissions` line.

- [ ] **Step 3: Read the result from Claude Code.** `$L $NAMES | tee private/context-trim/listed.after-skills`.

Expected: `theme-factory`, `mcp-builder` and `find-skills` now read `absent` too. `coding-standards`, `hindsight-coding-agent` and `archify` read `present`, and the plugin lines read as in Task 2 Step 6.

- [ ] **Step 4: Run `claude-stack apply` once more.** `jq '.skillOverrides | length' .claude/settings.local.json` still prints `14`.

### Task 4: Quote the add-tool skill's description

**Files:**
- Modify: `.claude/skills/add-tool/SKILL.md:3`

**Interfaces:**
- Produces: frontmatter that a strict YAML parser reads. The file is a project skill: `40-dotfiles.toml` links only `tilde/.claude/skills/project-stack` into `$HOME`.

- [ ] **Step 1: See it fail, and keep the old text.**

```shell
ruby -ryaml -e 't = File.read(ARGV[0], encoding: "UTF-8"); y = YAML.safe_load(t.split(/^---\s*$/, 3)[1]); puts y["description"]' .claude/skills/add-tool/SKILL.md
sed -n 3p .claude/skills/add-tool/SKILL.md | sed 's/^description: //' > private/context-trim/add-tool.description
```

Expected: the first line prints an error naming `line 3 column 105`.

- [ ] **Step 2: Quote the line.** Wrap the value on line 3 in single quotes and double its one apostrophe, in `one's`. Change nothing else on the line.

- [ ] **Step 3: See it pass, with the same text.**

```shell
ruby -ryaml -e 't = File.read(ARGV[0], encoding: "UTF-8"); y = YAML.safe_load(t.split(/^---\s*$/, 3)[1]); puts y["description"]' .claude/skills/add-tool/SKILL.md | cmp - private/context-trim/add-tool.description && echo same
```

Expected: `same`.

- [ ] **Step 4: `pnpm check`, then commit.**

```shell
git add .claude/skills/add-tool/SKILL.md
git commit -m "Quote the add-tool skill's description"
```

### Task 5: The owner turns three MCP servers off here

**Files:**
- Modified by Claude Code: the project's entry in `~/.claude.json`

- [ ] **Step 1: The owner runs these in a session in this repository.** `/mcp disable agent-browser`, `/mcp disable jean`, `/mcp disable astro-docs`. `mise`, `scrapling` and `snippetslab` stay on: setup registers them, and a session here is where a fault in them is seen. If a Claude Desktop session has no `/mcp disable`, run it from `claude` in a terminal in this directory.

- [ ] **Step 2: Check by key.**

```shell
jq -c --arg p "$PWD" '.projects[$p].disabledMcpServers' ~/.claude.json
```

Expected: an array holding the three names. Today the project's entry has no such key, and where Claude Code writes it was not tried. If this prints `null` after Step 1, find the key with `jq -c 'paths | select(.[-1] == "disabledMcpServers")' ~/.claude.json` and record the real path in the spec. The entry is keyed by this folder's path, so a session in a worktree under `.claude/worktrees/` is not covered.

### Task 6: Measure, record and file

**Files:**
- Modify: `docs/superpowers/specs/2026-11-15-claude-code-context-audit.md` (a "Result" section, and "Plans")
- Modify: `docs/superpowers/plans/README.md`
- Move: this file to `docs/superpowers/plans/completed/`, and the spec with its folder to `docs/superpowers/specs/completed/`

- [ ] **Step 1: The owner runs `/context` in a new session here** and gives the session the same three lines as Task 1 Step 3.
- [ ] **Step 2: Write "Result" in the spec.** It holds the before and after `/context` lines, the differences between the three `listed.*` files, the 14 plugin keys and 14 skill names that are off in this project, and the Undo block below, so a session that finds a catalog pick missing here can bring it back. A number that did not move as predicted is recorded with the measured value.
- [ ] **Step 3: Add an Outcome table to the top of this plan,** move it and the spec, and update the index and the paths that name them. `pnpm check`, commit: "File the finished context-trim plan and its audit".

## Undo

By key, so that nothing Claude Code wrote since Task 1 is lost:

```shell
t=$(mktemp) && jq 'del(.skillOverrides) | .enabledPlugins |= with_entries(select(.key as $k | [
  "voltagent-qa-sec@voltagent-subagents", "agent-sdk-dev@claude-plugins-official", "mcp-server-dev@claude-plugins-official",
  "modern-web-guidance@claude-plugins-official", "coderabbit@claude-plugins-official", "superdesign@claude-plugins-official",
  "commit-commands@claude-plugins-official", "claude-md-management@claude-plugins-official", "code-simplifier@claude-plugins-official",
  "session-report@claude-plugins-official", "browser-use@claude-plugins-official", "rust-analyzer-lsp@claude-plugins-official",
  "lua-lsp@claude-plugins-official"] | index($k) | not))' .claude/settings.local.json > "$t" && cp "$t" .claude/settings.local.json && rm "$t"
~/dev/dotfiles/bin/claude-stack apply --keep voltagent-lang@voltagent-subagents
```

That leaves `.claude/skill-stack.json` recording `voltagent-lang` as kept by hand, where it began as kept by a path signal. The two behave the same. For the exact start state, copy `skill-stack.json` and `skill-stack.md` back from `private/context-trim/before/` as well.

To bring back one plugin or skill, delete its key from `enabledPlugins` or `skillOverrides`. For an MCP server, `/mcp enable <name>`. Task 4 is a `git revert`.

## Not in this plan

- **The CodeGraph prompt hook** (F1), by decision 2. It is the largest cost found, about 3,000 tokens a prompt in every project.
- **The retries auto mode costs when a hook rewrites a call** (F5) and **jstack's `swarm workers` model** (F7). Both live in global files.
- **`~/dev/career-ops/AGENTS.md`, jstack in other projects, and `ccd_turn`** (F7). None is in this repository.
- **A gate check for skill frontmatter.** `bin/lib/test-conventions` could parse it, but one fault in 29 files does not earn a change to the gate.
- **A note in the session that these are off.** `.claude/rules/skill-stack.md` is generated, and a tracked rule would be false on another Mac. The audit's "Result" carries the list.
- **The same trim in another project.** `/project-stack` there, from that project.

## Review of this plan (2026-11-15)

One independent reviewer read the first version (`91b2f45`) against the code, read-only, and simulated the `claude-stack` and `jq` steps on copies. Each finding was checked before the plan changed.

| Finding | Change |
| --- | --- |
| Asking Haiku which names it sees returned `name=present` sixteen times, and each run fired the session hooks and saved a transcript | The checks read the session's start-up list through `listed.sh`, unsaved, and `claude plugin list --json`. Reproduced: an overridden skill reads `absent` there |
| Claude Code writes `permissions.allow` in the same file, so a byte compare fails for a harmless reason and a whole-file restore loses a grant | The check lists removed entries only, and Undo works by key |
| Undo left `skill-stack.json` recording `voltagent-lang` as kept by hand | Task 1 copies all three stack files, and Undo says how to restore them |
| Three of the plugins own picks in the catalog's task guide, and nothing tells a session here they are off | Review Focus 5, and Task 6 writes the list and the Undo into the audit |
| `usage.py` scanned top-level transcripts only | It is recursive now: 2,316 files in 14 days. The 14 plugins, 14 skills and three MCP servers still have no call. `scrapling` had 16, in subagent files |
| Task 5's key path and `/mcp disable` in Claude Desktop were not tried | Task 5 says so and gives the fallback |
| Task 4 did not say how to save the old text | It has the command |

Found correct: no step writes outside this project, `claude-stack apply` writes only its three git-ignored files, `pnpm check` and `claude-config save` do not read the local file, the three `jq` blocks give 22, 35 and 14, and nothing in this repository's instructions, skills, hooks or docs names any of the 28.
