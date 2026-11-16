# Claude Code Context Trim, Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A Claude Code session in this repository stops loading 14 plugins and 14 skills that nothing here uses, and nothing else on the Mac changes.

**Architecture:** Every switch goes into this project's git-ignored `.claude/settings.local.json`, one through `claude-stack` and the rest by a `jq` merge, because Claude Code reads that file for this project only. One tracked project file gets a one-line fix. Each task ends with a `claude -p` session that reports what it can and cannot see.

**Tech Stack:** `jq`, `bin/claude-stack`, the `claude` CLI, Ruby's YAML for one parse check.

**Spec:** `docs/superpowers/specs/2026-11-15-claude-code-context-audit.md`. Read its Goal and "Decisions the owner made" in full before Task 1. Findings F2, F3, F4 and F6 are this plan. F1, F5 and F7 are out of scope by decision.

## Global Constraints

- Decision 1: a change affects this project only. Do not edit `agents/claude-plugins.txt`, `agents/claude-skills.txt`, `agents/catalog/curated.toml`, anything under `setup/` or `tilde/`, `~/.claude/settings.json`, `~/.claude/rules/` or `~/.claude/skills/`.
- Decision 2: do not remove, wrap or silence the CodeGraph prompt hook.
- Do not run `claude plugin disable`, `claude plugin uninstall` or `npx skills remove`. Each changes user scope.
- Read settings files by key only (`jq '.enabledPlugins'`). They can hold secrets in `env`.
- Write a settings file through a temp file made by `mktemp` and `jq`, then `cp` over it. Never `sed` it.
- `.claude/settings.local.json` keeps its `permissions` key exactly as it was.
- This Mac is an installed copy. Run the clone's script by path: `~/dev/dotfiles/bin/claude-stack`.
- Tasks 1 to 3 and 5 commit nothing: their files are git-ignored. Only Tasks 4 and 6 commit, and both are Markdown-only, so `main` gains no reason for a guest A (decision 9 of the installable-setup spec).
- A session that is already open keeps its old list. Every check starts a new one.

## Measured for this plan (2026-11-15)

- `.claude/settings.local.json` has two keys, `enabledPlugins` and `permissions`. 21 plugins are `false` there, all written by `claude-stack`.
- `.claude/settings.local.json`, `.claude/skill-stack.json` and `.claude/rules/skill-stack.md` are git-ignored (`.gitignore` lines 3, 56, 57).
- `claude-stack scan` here prints `keep voltagent-lang@voltagent-subagents  path: agents/catalog/build_catalog.py`. Of the 14 plugins, only that one is in `[stack.signals]`.
- A `skillOverrides` entry in `.claude/settings.local.json` hides a skill from `~/.claude/skills`: `theme-factory=absent`, `archify=present`.
- `claude -p '<question>' --model haiku` answers from this directory in under a minute.

## Review Focus

1. **A later `claude-stack apply` or `reset` drops the hand-written entries.** They must survive both. Task 2 Step 5 runs `apply` again and counts them.
2. **The `jq` merge loses the `permissions` key.** It must be byte-identical afterwards. Tasks 2 and 3 compare it before and after.
3. **A plugin turned off here is one this repository's own workflow calls.** `superpowers`, `pr-review-toolkit`, `jstack`, `remember` and `claude-docs` must stay listed. Task 2 Step 6 asks for one name from each.
4. **A skill that jstack or a rule reads by path is turned off.** `coding-standards` and `hindsight-coding-agent` stay on. Task 3 Step 3 asks for both.
5. **The quoted description changes what Claude Code shows.** The text between the quotes must equal the old text, with the one apostrophe doubled. Task 4 Step 3 compares the parsed value with the old line.

---

### Task 1: Record the starting state

**Files:**
- Create: `private/context-trim/before.txt` (git-ignored folder)

**Interfaces:**
- Produces: `private/context-trim/settings.local.json.before`, the file every later task can restore from, and `before.txt`, the answers Task 6 compares with.

- [ ] **Step 1: Copy the settings file aside.**

```shell
mkdir -p private/context-trim && cp -p .claude/settings.local.json private/context-trim/settings.local.json.before
jq -S '.permissions' .claude/settings.local.json > private/context-trim/permissions.before
```

- [ ] **Step 2: Ask a new session what it can see.**

```shell
claude -p 'Look only at the skills and agent types available to you in this session. For each name say present or absent, in the form name=present or name=absent, one per line, and nothing else: voltagent-lang:python-pro, voltagent-qa-sec:debugger, commit-commands:commit, coderabbit:code-review, modern-web-guidance:modern-web-guidance, theme-factory, mcp-builder, find-skills, superpowers:writing-plans, pr-review-toolkit:code-reviewer, jstack:j-mode, remember:remember, claude-docs:claude-docs, coding-standards, hindsight-coding-agent, archify' --model haiku | tee private/context-trim/before.txt
```

Expected: all 16 lines end in `=present`. A line that reads `absent` here names something already off: note it and leave it out of the later checks.

- [ ] **Step 3: The owner runs `/context` in a new session here** and gives the session the total and the "Skills" and "Custom agents" lines. Write them at the end of `before.txt`.

### Task 2: Turn the 14 plugins off for this project

**Files:**
- Modify: `.claude/settings.local.json` (git-ignored)
- Modify, through `claude-stack`: `.claude/skill-stack.json`, `.claude/rules/skill-stack.md` (git-ignored)

**Interfaces:**
- Consumes: Task 1's two `.before` files.
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

With Step 1's, fourteen entries are added.

- [ ] **Step 3: Check the count and the untouched key.**

```shell
jq '[.enabledPlugins[] | select(. == false)] | length' .claude/settings.local.json
jq -S '.permissions' .claude/settings.local.json | cmp - private/context-trim/permissions.before && echo same
```

Expected: `35`, then `same`.

- [ ] **Step 4: Check that `claude-stack` does not own them.** `jq '.owned | length' .claude/skill-stack.json` prints `22`.

- [ ] **Step 5: Run `apply` again and count again.**

```shell
~/dev/dotfiles/bin/claude-stack apply
jq '[.enabledPlugins[] | select(. == false)] | length' .claude/settings.local.json
```

Expected: `35`. If it prints `22`, `apply` rewrote the whole key: restore from `settings.local.json.before`, stop, and report it. The fix is then a change to `agents/catalog/stack.py`, which decision 1 does not allow in this plan.

- [ ] **Step 6: Ask a new session.** Run Task 1 Step 2's command, writing to `private/context-trim/after-plugins.txt`.

Expected: `voltagent-lang:python-pro`, `voltagent-qa-sec:debugger`, `commit-commands:commit`, `coderabbit:code-review` and `modern-web-guidance:modern-web-guidance` read `absent`. The other eleven read `present`.

### Task 3: Turn the 14 skills off for this project

**Files:**
- Modify: `.claude/settings.local.json` (git-ignored)

**Interfaces:**
- Consumes: Task 2's file.
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

- [ ] **Step 2: Check the count, the plugins and the untouched key.**

```shell
jq '.skillOverrides | length' .claude/settings.local.json
jq '[.enabledPlugins[] | select(. == false)] | length' .claude/settings.local.json
jq -S '.permissions' .claude/settings.local.json | cmp - private/context-trim/permissions.before && echo same
```

Expected: `14`, `35`, `same`.

- [ ] **Step 3: Ask a new session.** Run Task 1 Step 2's command, writing to `private/context-trim/after-skills.txt`.

Expected: `theme-factory`, `mcp-builder` and `find-skills` read `absent`. `coding-standards`, `hindsight-coding-agent` and `archify` read `present`, and the plugin lines read as in Task 2 Step 6.

- [ ] **Step 4: Run `claude-stack apply` once more.** `jq '.skillOverrides | length' .claude/settings.local.json` still prints `14`.

### Task 4: Quote the add-tool skill's description

**Files:**
- Modify: `.claude/skills/add-tool/SKILL.md:3`

**Interfaces:**
- Produces: frontmatter that a strict YAML parser reads.

- [ ] **Step 1: See it fail.**

```shell
ruby -ryaml -e 't = File.read(ARGV[0], encoding: "UTF-8"); y = YAML.safe_load(t.split(/^---\s*$/, 3)[1]); puts y["description"]' .claude/skills/add-tool/SKILL.md
```

Expected: an error naming `line 3 column 105`.

- [ ] **Step 2: Keep the old value, then quote the line.** Save the text after `description: ` to `private/context-trim/add-tool.description`. Wrap the value on line 3 in single quotes and double its one apostrophe, in `one's`. Change nothing else on the line.

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

- [ ] **Step 1: The owner runs these in a session in this repository.** `/mcp disable agent-browser`, `/mcp disable jean`, `/mcp disable astro-docs`. Each applies to this project only. `mise`, `scrapling` and `snippetslab` stay on: setup registers them, and a session here is where a fault in them is seen.

- [ ] **Step 2: Check by key.**

```shell
jq -c --arg p "$PWD" '.projects[$p].disabledMcpServers' ~/.claude.json
```

Expected: an array holding the three names.

### Task 6: Measure, record and file

**Files:**
- Modify: `docs/superpowers/specs/2026-11-15-claude-code-context-audit.md` (a "Result" section, and "Plans")
- Modify: `docs/superpowers/plans/README.md`
- Move: this file to `docs/superpowers/plans/completed/`

- [ ] **Step 1: The owner runs `/context` in a new session here** and gives the session the same three lines as Task 1 Step 3.
- [ ] **Step 2: Write "Result" in the spec:** the before and after `/context` lines, the three `claude -p` answer files' differences, and what each task changed. A number that did not move as predicted is recorded with the measured value, not explained away.
- [ ] **Step 3: Add an Outcome table to the top of this plan,** move it to `completed/`, update the index, and move the spec to `specs/completed/`, since its one plan is then finished. `pnpm check`, commit: "File the finished context-trim plan and its audit".

## Undo

Everything but Task 4 is one file. To undo all of it:

```shell
cp -p private/context-trim/settings.local.json.before .claude/settings.local.json
~/dev/dotfiles/bin/claude-stack apply --keep voltagent-lang@voltagent-subagents
```

To bring back one plugin or skill, delete its key from `enabledPlugins` or `skillOverrides` in `.claude/settings.local.json`. For an MCP server, `/mcp enable <name>`. Task 4 is a `git revert`.

## Not in this plan

- **The CodeGraph prompt hook** (F1), by decision 2. It is the largest cost found, about 3,000 tokens a prompt in every project.
- **The rtk hook's retries in auto mode** (F5) and **jstack's `swarm workers` model** (F7). Both live in global files.
- **`~/dev/career-ops/AGENTS.md`, jstack in other projects, and `ccd_turn`** (F7). None is in this repository.
- **A gate check for skill frontmatter.** `bin/lib/test-conventions` could parse it, but that file is not Markdown and one fault in 29 files does not earn a guest A.
- **The same trim in another project.** `/project-stack` there, from that project.
