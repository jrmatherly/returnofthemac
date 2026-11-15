# P6: Docs for the new path, Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A stranger reads the README, installs from mise with one line, and can follow every page after it without knowing that a clone exists.

**Architecture:** Most of the P6 brief shipped with the phases before it: the README already has the install line, `docs/installation.md` is already split, and `docs/settings-sync.md` already covers sync and profiles. This plan closes what is left. It adds one self-check for the links a restructure breaks, gives an installed user a way to change the two owner values they cannot change today (audit finding I22), and then reorders four pages so the installed copy is the default reader and the clone is the second.

**Tech Stack:** Markdown (Prettier, `proseWrap: never`), Python 3.11+ standard library for the self-check, bash 3.2 (`bin/lib/test-dotfiles`), zsh (`zsh/env.zsh`), mise 2026.11.8.

**Spec:** `docs/superpowers/specs/2026-11-11-installable-setup-profiles-and-sync.md`. Read its Goal and "Decisions the owner made" in full before Task 1. This plan implements the P6 brief, and finding I22 of `docs/superpowers/specs/completed/2026-11-14-project-audit.md` (its decision 8).

## Outcome (2026-11-15)

Run natively in one session, with the docs audit of Task 8 and one independent code review at the end. Every commit passed `pnpm check`.

| Task | Commit | Difference from the plan |
| --- | --- | --- |
| 1. Link and anchor check | `d190531` | The script is `setup/tests/doc-links.py`, not `bin/lib/test-doc-links`: the gate and the lint hook read every `bin/lib/test-*` file as bash. It has no `--self-test` flag and always runs its cases first. First run: 301 relative links in 60 pages, none broken |
| 2. fastfetch's seeded config | `405de82` | None. Removing `depends` failed the fourth case, as measured |
| 3. lazygit's second file | `5916f6d` | None. lazygit has no way to print its merged config, so the merge order still rests on its documentation |
| 4. README | `576820c` | Also corrected `rotm settings` to `rotm settings tui` in the README and `docs/installation.md`: a bare `rotm settings` prints usage and exits |
| 5. Installation page | `8127115` | The preview check's literal `bootstrap --from` does not match, because `--dry-run` sits between the two words. Measured in a scratch home: the dry run prints the `git clone` and checkout it would run, exits 0, and fetches and links nothing. The page says that |
| 6. Updating page | `36a4945` | The VS Code paragraph has its own heading, "After a VS Code update", since it is not about the repository |
| 7. Make it yours | `f3617df` | The Claude row was confirmed in `restore_plugins`: a tracked plugin you uninstall is installed again, and one you disable stays disabled |
| 8. Docs audit | `12c9d0d` | `docs-auditor` reported twelve mismatches in nine files. All twelve held when checked against the line cited, so there is no table of contradicted findings. None was in the install line, the `rotm` commands or the installed table |
| Review | `e0e4276` | Not a task of the plan. The review found the installed-migration case passed without a migration, and blind spots in the link check (titled and nested links, case-only mismatches, fence tracking). Both are fixed, and the reviewer's mutation now fails |

The title is "Return of the Mac" and the run was native, both taken from the record (decision 6, and the owner's word to continue) without asking again.

Not done, and not planned here: Mole's two whitelists are links into the copy on an installed copy, so Mole's own editors would change it. `docs/mole.md` says to keep a list outside the copy. It is in the plan index beside the `obsidian-vault capture` guard.

P6's "Done when" was met on `main` at `e0e4276`: the audit's findings are corrected, and it was not run a second time.

## Global Constraints

- The gate is `pnpm check`. Every task ends with it passing. Edit and commit in separate Bash calls.
- Commit subjects are short, imperative, sentence case, with no conventional-commit prefix. One commit per task, with the subject the task names.
- Decision 12: nothing leaves the base for being the owner's. A value that points at the owner ships as it is and has a row in `docs/forking.md` saying what a user changes.
- Decision 13: a user's own changes are the ones made through `rotm settings` and their opt-outs.
- The install line is the same text in `README.md` and `docs/installation.md`, with `ref=stable` (decision 9). It differs from the line `.github/workflows/fresh-install.yml:84` runs only in the ref and in the flags after `setup.sh`.
- No new docs page is named after a command, because `help <name>` reads `docs/<name>.md` before the script's header and before tldr. Two pages are named after their script on purpose, `docs/claude-config.md` and `docs/claude-catalog.md`. This plan adds no page.
- Never run on this Mac without the owner's word: `sysup`, `./setup.sh`, `set-defaults`, `rotm install`, `rotm update`, `mise dotfiles apply`, or the built app. Task 2's proof runs in a scratch home, as `bin/lib/test-dotfiles` already does.
- `CLAUDE.md` and the rules under `.claude/rules/` change only when a stated fact becomes false. `bin/lib/test-conventions` caps their size.
- Prose follows the `technical-writing` and `unslop` skills. Markdown is not hand-wrapped.

## Measured for this plan (2026-11-15, this Mac, `main` at `580fadb`)

| Fact | Evidence |
| --- | --- |
| The README already leads its Quick start with "Install without cloning" | `README.md:29-45` |
| The README's title, intro and warning still describe personal dotfiles | `README.md:1-8`: "~jason", "Jason's personal dotfiles", "personal, opinionated" |
| The README says thirteen modules. There are fifteen | `README.md:12`, `docs/modules.md:3`, fifteen `conf.d/60-rotm-*.toml` files |
| The README's Time Machine warning sits only in the clone section | `README.md:61-62`. The installed section says "see the warning below" (`:45`) |
| "Everyday commands" is written for a clone | `README.md:69-81`: `"$DOTFILES/setup.sh"`, `pnpm check`, "a symlink into the clone" |
| `docs/installation.md` is split, but its shared sections assume a clone | `:75-104` ("Run setup": `~/dev/dotfiles/setup.sh`, "configured by editing files in the clone"), `:125-133` ("Preview"), `:140` (switch the clone to SSH) |
| `docs/updating.md` opens with `sysup` and gives `rotm update` one paragraph | `docs/updating.md:1-9`, `:41` |
| On an installed copy `sysup` skips the pull and says to run `rotm update` | `bin/sysup:221-222` |
| `docs/forking.md` is one table for someone who forks | `docs/forking.md:3-25`, 19 rows |
| `docs/settings-sync.md` covers sync and profiles | Its headings, `:5` to `:146`, with "Profiles" at `:82` |
| fastfetch's folder is one symlink into the checkout, and its config names the owner's site and city | `40-dotfiles.toml:52`, `tilde/.config/fastfetch/config.jsonc:31`, `:54` |
| fastfetch's config finds its logo through `$HOME/.config/fastfetch/ascii/` | `config.jsonc:5` |
| lazygit reads one file, in the checkout | `zsh/env.zsh:185`: `LG_CONFIG_FILE="$DOTFILES/lazygit/config.yml"` |
| lazygit's own folder holds no `config.yml` on this Mac | `ls ~/Library/Application\ Support/lazygit/`: `state.yml` and a cache file |
| `~/.claude/rules` already uses the pattern Task 2 needs | `40-dotfiles.toml` (`symlink-each`), `config.rotm-installed.toml:34-35`. Its migration case in `bin/lib/test-dotfiles:212-229` is an exclude-list change, not a folder link becoming `symlink-each` |
| `symlink-each` recurses into a subfolder | Scratch home, mise 2026.11.8: `ascii` arrived as a real folder holding one link per file ("created 5 symlink(s)") |
| A home whose `~/.config/fastfetch` is the old folder link migrates in one apply | Same scratch home: the link became a real folder, `config.jsonc` and the four `ascii` files were links, and the source folder held no new link |
| On an installed home that migrates, the seeded copy needs `depends` | Same scratch home, old folder link plus the two installed entries: without `depends = ["~/.config/fastfetch"]` one apply left `ascii` only and the second apply seeded the file. With it, one apply gave both. A fresh installed home needs no second apply either way |
| lazygit takes a comma-separated `LG_CONFIG_FILE` | `docs/Config.md` at `v0.66.3`: "you can supply a list of comma-separated config file paths", with `LG_CONFIG_FILE="$HOME/.base_lg_conf,$HOME/.light_theme_lg_conf"`. It does not state which file wins: the order is implied by "merge a specific config file into a more general config file" |
| lazygit's default config on macOS | The same page: `~/Library/Application Support/lazygit/config.yml` |
| `zsh/env.zsh` sources alone in a scratch home | The reviewer ran `env -i HOME=<scratch> DOTFILES=<repo> PATH=/usr/bin:/bin /bin/zsh -fc 'source "$DOTFILES/zsh/env.zsh"'`: exit 0. `bin/lib/test-shell:176` already uses this form for `.zprofile` |
| No Markdown link in scope is broken today | The reviewer's prototype of Task 1's rule over 60 tracked pages and 404 inline links reported none. No page uses a reference-style link, an HTML anchor or a titled link |
| `help` does not render a `bin/lib/` header | `bin/CLAUDE.md:24`: it resolves `docs/<query>.md`, then the header of `bin/<query>` |
| `obsidian-vault capture` has no installed-copy guard | `rg rotm-mode bin/obsidian-vault` finds nothing. On an installed copy it would write into the checkout |
| The gate has no check for a Markdown link or anchor | `rg -i 'anchor' bin/lib/test-conventions bin/lib/check` finds one unrelated comment |
| `stable` is at `d09f025`, 194 commits behind `main` at `580fadb` | `git rev-list --count origin/stable..origin/main` |

Not measured: lazygit's merge order in practice (it is a full-screen program, so Task 3 does not test it), and whether `--dry-run` on the install line still fetches the repository.

## Decided while writing this plan

- **No new page.** The brief's "page on sync and profiles" is `docs/settings-sync.md`. The user layer gets a section in `docs/forking.md`, not a page of its own.
- **The README's title becomes "Return of the Mac"** (decision 6 names the product), and the intro says it began as the owner's dotfiles. The owner can keep "~jason" at review: it changes Task 4's Step 2 and nothing else.
- **The README stops counting modules.** The count drifted once already. `docs/modules.md` is the one place that states it.
- **I22 for fastfetch follows `~/.claude/rules`:** the base entry becomes `symlink-each`, and an installed copy seeds `config.jsonc` once. The owner's Mac migrates on its next apply, measured in a scratch home (see "Measured").
- **I22 for lazygit is a second file,** lazygit's own `config.yml`, read after ours when it exists. This departs from the audit's decision 8, which names `create_if_missing` copies: a seeded copy of `lazygit/config.yml` would freeze every later change to it for the sake of one key. Not a file in `~/.config/rotm` either: sync refuses a file there that it does not know (`sync._guard`).
- **Neither new file syncs.** fastfetch's `config.jsonc` and lazygit's own file live outside `~/.config/rotm`, so they stay on the Mac they were written on. Decision 13 scopes sync to what `rotm settings` changes. Task 7's two rows say "this Mac only".
- **The docs describe `main`.** `stable` is not promoted until P7 (decisions 9 and 15), so until then the install line fetches a copy older than these pages. This plan does not add a caveat to the README for it. P7 closes the gap.

## Review Focus

1. **A renamed heading breaks a link from another page.** A reader clicks "what must not be in the way" and lands at the top of the page. Task 1's check fails the gate on it.
2. **An installed user runs a clone command.** They edit a file in the copy or run `./setup.sh` from a path they do not have, and `rotm update` then refuses. Tasks 4 to 6 put the installed command first wherever both exist, and Task 8's audit asks the question by name.
3. **A user with Time Machine runs `set-defaults` from the installed path.** The warning must be in that path, not below it. Task 4, Step 1.
4. **A Mac that already has the old folder link, after Task 2.** The owner's Mac and every installed copy have one. One apply must turn it into a folder with nothing lost, and on an installed copy `config.jsonc` must be there after that same apply. Task 2's two migration cases.
5. **A new page named after a command.** `help <name>` would show the page in place of the script's help. Task 1's check fails when a `docs/*.md` name is also a `bin/` script, except the two that are on purpose.

---

### Task 1: Check the docs' links in the gate

**Files:**
- Create: `bin/lib/test-doc-links`
- Modify: `bin/lib/check` (one `job` line beside the other `"${python[@]}"` self-checks)
- Modify: whichever pages the first run reports

**Interfaces:**
- Produces: `bin/lib/test-doc-links`, a Python script with the `#!/usr/bin/env python3` header and the comment block `help` renders. It exits 0 and prints `ok`, or prints one line per problem as `<file>:<line>: <problem>` and exits 1.

It reads every tracked `*.md` outside `docs/superpowers/`, `.claude/`, `.serena/`, `icons/` and `private/` (`git ls-files '*.md'`). For each inline link `[text](target)` outside a fenced block:

- `http:`, `https:` and `mailto:` targets are skipped.
- A relative path must exist, resolved from the linking file's folder, after `%20`-style unquoting.
- A `#fragment`, alone or after a path to a `.md` file, must equal the slug of a heading in that file. The slug is GitHub's: lowercase the heading text, drop every character that is not a letter, digit, space, hyphen or underscore, turn each space into a hyphen. A repeated slug gets `-1`, `-2`.

It also fails when a `docs/*.md` basename, without `.md`, is the name of a file in `bin/`, except `claude-config` and `claude-catalog`: a two-name tuple with one comment saying those pages are their script's manual on purpose.

The slug function strips the leading `#`s and the surrounding spaces first, and "letter" means any Unicode letter (`str.isalnum`).

- [ ] **Step 1: Write the script's own cases first,** at the bottom of the file under `if "--self-test" in sys.argv`: `slug("### \`~/.ssh/github_personal.pub\`") == "sshgithub_personalpub"`, `slug("## What must not be in the way") == "what-must-not-be-in-the-way"`, `slug("macOS tips & tricks") == "macos-tips--tricks"`, and a temp folder where `a.md` links `b.md#gone` yields exactly one problem line naming `a.md:1`.
- [ ] **Step 2: Run** `python3 bin/lib/test-doc-links --self-test`. Expected: a `NameError` for `slug`.
- [ ] **Step 3: Implement.** `main()` runs the self-test cases, then the repository scan, so the gate needs one job line.
- [ ] **Step 4: Run** `python3 bin/lib/test-doc-links`. Expected: `ok`, since a prototype found no broken link on 2026-11-15. If it reports one, fix it in the page that holds the link. Do not rename a heading to satisfy a link.
- [ ] **Step 5: Wire it** into `bin/lib/check`. `bin/lib/test-conventions` fails while a `bin/lib/test-*` file is unwired, so run `pnpm check` before and after.
- [ ] **Step 6:** `pnpm check`, commit: "Check the docs' links and anchors in the gate". Name in the commit body how many links it checked and how many it found broken. `help` does not render a `bin/lib/` header, so there is nothing to render.

### Task 2: Seed fastfetch's config on an installed copy

**Files:**
- Modify: `tilde/.config/mise/conf.d/40-dotfiles.toml:52`, and its comment at `:45` ("One link per ~/.config child"), which the new entry makes false
- Modify: `.claude/rules/symlinks.md:13` ("`~/.claude/rules` is the one `symlink-each` entry")
- Modify: `tilde/.config/mise/config.rotm-installed.toml`
- Modify: `bin/lib/test-dotfiles`
- Modify: `docs/installation.md:38` (the list of files that "are yours")

**Interfaces:**
- Produces: on an installed copy `~/.config/fastfetch/config.jsonc` is a real file, written once. `~/.config/fastfetch/ascii` still resolves into the checkout. Task 7's fastfetch row relies on both.

- [ ] **Step 1: Write the failing cases** in `bin/lib/test-dotfiles`, beside the `~/.claude/rules` ones, with the harnesses already there (`mmig` for the base config, `mi` for `rotm-installed`):
  - Base config, fresh home: `~/.config/fastfetch` is a real folder, `config.jsonc` is a link into the repo, and `ascii/deadpool-katanas.ascii` is readable.
  - Base config, a home whose `~/.config/fastfetch` starts as the old folder link: after one apply it is not a link (`[ ! -L ]`), `config.jsonc` and `ascii/deadpool-katanas.ascii` are both readable, and `find "$repo/tilde/.config/fastfetch" -type l` prints nothing. The scratch home's `~/dotfiles` points at the real repo, so this last line is what proves the apply wrote no link into it.
  - `rotm-installed`, fresh home: `config.jsonc` is a regular file whose bytes equal the tracked file, and a second apply after the file is edited leaves the edit.
  - `rotm-installed`, a home that starts with the old folder link: after one apply, not two, `config.jsonc` is a regular file.
- [ ] **Step 2: Run** `bash bin/lib/test-dotfiles`. Expected: the first new case fails, because the folder is one link.
- [ ] **Step 3: Implement.** The base entry becomes `mode = "symlink-each", exclude = [".DS_Store"]`. The installed file redeclares it with `"config.jsonc"` added to the exclude list and adds the seeded copy with `depends = ["~/.config/fastfetch"]`, as the three module entries for `~/.claude/rules` carry, and a one-line comment saying the file names the owner's site and city. The existing rules at `test-dotfiles:42-57` must pass unchanged: the rule at `:56` matches `mode = "copy", create_if_missing = true` as a substring, so `depends` after it is accepted.
- [ ] **Step 4: Run** `bash bin/lib/test-dotfiles`. Expected: pass. Remove `depends` once to see the fourth case fail, then put it back.
- [ ] **Step 5: Correct the two lines the change makes false:** the comment at `40-dotfiles.toml:45` and the sentence at `.claude/rules/symlinks.md:13`, which now names two `symlink-each` entries.
- [ ] **Step 6: Add** `fastfetch's config.jsonc` to the sentence at `docs/installation.md:38`.
- [ ] **Step 7:** `pnpm check`, commit: "Give an installed copy its own fastfetch config". The body says this Mac's `mise dotfiles status` shows `~/.config/fastfetch` differing until the next apply, and that an installed copy picks the change up on its next `rotm update`.

### Task 3: Let lazygit read the user's own config after ours

**Files:**
- Modify: `zsh/env.zsh:183-185`
- Modify: `bin/lib/test-shell` (beside the `.zprofile` case at `:176`, which already sources a file under `env -i` with a scratch `HOME`)

**Interfaces:**
- Produces: `LG_CONFIG_FILE` is `"$DOTFILES/lazygit/config.yml"`, with `,$HOME/Library/Application Support/lazygit/config.yml` appended only when that file exists at shell start. Task 7's lazygit row relies on it.

- [ ] **Step 1: Write the failing check** in `bin/lib/test-shell`, in the form of its `.zprofile` case: `env -i HOME="$tmp/lg-home" DOTFILES="$repo" PATH=/usr/bin:/bin /bin/zsh -fc 'source "$DOTFILES/zsh/env.zsh"; print -r -- $LG_CONFIG_FILE'`. Without the user file the output equals `$repo/lazygit/config.yml`. With an empty `$tmp/lg-home/Library/Application Support/lazygit/config.yml` it equals the two paths joined by one comma, ours first.
- [ ] **Step 2: Run** `bash bin/lib/test-shell`. Expected: the second assertion fails.
- [ ] **Step 3: Implement** in `zsh/env.zsh`, keeping the existing comment and adding one line of why: the user's file is theirs to write, so an installed copy stays clean.
- [ ] **Step 4:** `pnpm check`, commit: "Read the user's own lazygit config after the tracked one". The body says the merge order rests on lazygit's documentation and was not run.

### Task 4: Rewrite the README around the installed copy

**Files:**
- Modify: `README.md`
- Modify: `docs/forking.md:7` (its row for the README's title and intro), only if the wording there turns false

- [ ] **Step 1: Write the checks** as a throwaway shell block in the task's notes, and run them. Each must fail now:
  - `! grep -n 'thirteen' README.md`
  - `! grep -n "Jason's personal dotfiles" README.md`
  - `sed -n '/^### Install without cloning/,/^### Install from a clone/p' README.md | grep -q 'Time Machine'`. Now the note is at `:62`, below the clone heading at `:47`.
  - `! grep -n 'Everything in `$HOME` is a symlink into the clone' README.md`
- [ ] **Step 2: Edit, in this order.**
  1. Title `# Return of the Mac`. Intro, two sentences: what it is (a macOS setup for Apple Silicon that installs with one line and updates with one command, through mise), and where it came from (the owner's dotfiles, a fork of nicksp/dotfiles). Keep the screenshot.
  2. Replace the "personal, opinionated" warning with one that tells a stranger what to read before the install line: the package lists and `20-macos.toml`, with the same three links.
  3. Move "Quick start" above "What you get". Keep both install blocks and their numbered steps as they are, except: the Time Machine note moves directly under the installed section's last paragraph, and the clone section points up to it. The `[!TIP]` about `./setup.sh -- --dry-run` (`:64`) is a clone's and stays in the clone section.
  4. In "What you get", the first bullet leads with the install line and `rotm`, and names `setup.sh` as what a clone runs. Drop the module count: "Everything outside the base is in [modules](docs/modules.md)".
  5. Split "Everyday commands" into two tables. "On an installed copy": `rotm update`, `rotm settings`, `sysup`, `set-defaults`, `help`. "In a clone", introduced as what a clone adds to those: `"$DOTFILES/setup.sh"` in place of `rotm update`, `mise dotfiles apply`, `dotfiles-settings tui`, `pnpm check`. `sysup`, `set-defaults` and `help` are listed once, in the first table. The closing sentence says a clone's `$HOME` is links into the clone, and an installed copy is not for editing: change it through `rotm settings`.
  6. In "Documentation", the "Make it yours" row reads: what points at the owner and how to change it, from your own settings on an installed copy or in a fork.
- [ ] **Step 3: Run** the four checks. Expected: all pass. Run `diff <(grep -o "mise -E rotm-installed.*setup.sh" README.md) <(grep -o "mise -E rotm-installed.*setup.sh" docs/installation.md)`. Expected: no output.
- [ ] **Step 4:** `pnpm check` (Task 1's check covers the moved anchors), commit: "Lead the README with the install line and the installed copy".

### Task 5: Say which mode each line of the installation page is for

**Files:**
- Modify: `docs/installation.md:75-186`

The two install sections stay. The shared sections below them change so an installed reader never meets a clone path without a label.

- [ ] **Step 1: Write the checks.** Each must fail now:
  - `! grep -n 'To automate the setup of your dotfiles' docs/installation.md`
  - `grep -c 'rotm install' docs/installation.md` prints at least 4. Now it prints 1.
  - `sed -n '/^## Preview/,/^## After setup/p' docs/installation.md | grep -q 'bootstrap --from'`
- [ ] **Step 2: Edit.**
  1. "Run setup" opens by saying both installs end in the same `setup.sh`, started by the install line or `rotm install` on an installed copy and by `~/dev/dotfiles/setup.sh` in a clone. Its command block shows both, labelled.
  2. Every "run `./setup.sh` again" in `:100-123` becomes "run setup again (`rotm install`, or `./setup.sh` in a clone)" on first use in each paragraph.
  3. `:104`, "Everything is then configured by editing files in the clone", becomes two sentences: a clone is configured by editing its files, and an installed copy through `rotm settings` and the files setup seeded (link to `forking.md`).
  4. "Preview" gains the installed form first: the install line with `--dry-run` after `bootstrap`. Say what `:26` already says, that this previews mise's part (the fetch and the link) and not what setup installs. The clone command stays second.
  5. "After setup", step 2: the `git remote set-url` half is labelled as a clone's.
  6. "Install color themes" (`:166`): "edit the file in the repo and commit it" is labelled as a clone's.
  7. "Set up the Obsidian vault" (`:172`): `obsidian-vault capture` is labelled as a clone's. On an installed copy it writes into the copy, and `rotm update` then refuses (see "Not in this plan").
  8. Keep every heading's text, so no anchor moves.
- [ ] **Step 3: Run** the checks. Expected: pass. `help installation` renders.
- [ ] **Step 4:** `pnpm check`, commit: "Name the mode each installation step is for".

### Task 6: Put `rotm update` first on the updating page

**Files:**
- Modify: `docs/updating.md:1-41`, and `:54`
- Modify: `README.md` "Documentation" table, the Updating row

- [ ] **Step 1: Write the checks.** Each must fail now:
  - The first fenced block of `docs/updating.md` contains `rotm update`: `awk '/^```/{n++} n==1' docs/updating.md | grep -q 'rotm update'`
  - `grep -q '^## On an installed copy' docs/updating.md && grep -q '^## In a clone' docs/updating.md`
- [ ] **Step 2: Edit.** Two sections under a two-sentence intro.
  - "On an installed copy": `rotm update` brings this project's changes and runs setup, and installs what is missing. `sysup` upgrades macOS, mise, the packages and the tools, and on an installed copy it skips the pull and says to run `rotm update` (`bin/sysup:221`). Say plainly that an installed user runs both, and in which order: `rotm update`, then `sysup`. Move the `rotm update --check` paragraph (`:41`) here unchanged.
  - "In a clone": the present `sysup` text, its step list and the "run setup again" block, unchanged.
  - The Renovate and VS Code paragraphs stay last, under a heading that says they are about the repository.
  - `:54`, in the 1Password section: "keeps it in a git-ignored file inside the clone" is false. `docs/local-customizations.md:9` names the real file, `~/.config/rotm/config.override.toml`. Say that.
- [ ] **Step 3: Run** the checks. Expected: pass. `help updating` renders.
- [ ] **Step 4:** `pnpm check`, commit: "Put rotm update first on the updating page".

### Task 7: Rewrite "Make it yours" around the user layer

**Files:**
- Modify: `docs/forking.md`
- Modify: `docs/local-customizations.md` (one new section, and `:35`)
- Modify: `CLAUDE.md`, the "Forking" bullet: "`docs/forking.md`'s table" becomes "`docs/forking.md`'s fork table", since the page now has two

**Interfaces:**
- Consumes: Task 2 (fastfetch's seeded file) and Task 3 (lazygit's second file).

- [ ] **Step 1: Write the checks.** Each must fail now:
  - `grep -q '^## On an installed copy' docs/forking.md && grep -q '^## In a fork' docs/forking.md`
  - `grep -q '^## .*config/rotm' docs/local-customizations.md` (the page names the folder once today, with no section)
- [ ] **Step 2: Edit `docs/forking.md`.** Keep the title "Make it yours" and the file name. A guard, which passes before and must pass after: every row of today's table is still under the fork heading, `sed -n '/^## In a fork/,$p' docs/forking.md | grep -c '^| \['` prints at least 19.
  - Intro: the setup ships with the owner's choices in it (decision 12), and this page lists each one and how you change it.
  - "On an installed copy": a table with the columns "What points at the owner", "What you do". One row per value a user meets, each ending in a command or a file of their own, never an edit to the copy:
    - Time Machine off, the firewall, locale, power and Spotlight shortcuts: `rotm settings set macos.<name> off`, before `set-defaults`. Keep the bold Time Machine sentence.
    - The packages, apps and extensions: turn a module off (`rotm settings set modules.<name> off`) or mark one package absent, linking `modules.md`.
    - Claude Multipass, the owner's own project, which is in the base and in no module: declare `"brew:jrmatherly/tap/claude-multipass"` and `"brew-cask:jrmatherly/tap/claude-multipass-app"` as `{ state = "absent" }` in `~/.config/rotm/config.override.toml`, the form `modules.md` documents under "Skipping one package or tool".
    - fastfetch's name, site and city: edit `~/.config/fastfetch/config.jsonc`, which is your own file after the install (Task 2). This Mac only: sync does not carry it.
    - lazygit's author colour: write `gui.authorColors` in `~/Library/Application Support/lazygit/config.yml` (Task 3). This Mac only.
    - The Claude Code plugins, settings and skills: setup adds the owner's on every run, so a plugin you remove comes back unless the `claude` module is off. Your own plugins are never removed. Confirm the first half in `bin/claude-config`'s `restore` before writing it: the spec's P2 brief says restore only adds. The catalog's notes on the owner's own MCP servers print a `lint:` line and nothing else.
    - The menu bar app's update source: nothing to change, it updates from the owner's releases. Turn the `menubar` module off to leave it out.
    - The GitHub SSH key path: `~/.ssh/github_personal.pub`, linking `local-customizations.md`.
    - A closing line: a value with no row here that you cannot change without editing the copy is a bug to report.
  - "In a fork": the present table, every row kept, under one sentence saying these are edits to tracked files. The closing paragraph at `:27` (the two pages that link the owner's projects) stays last, in this section.
- [ ] **Step 3: Edit `docs/local-customizations.md`.** Add a section `## ~/.config/rotm` after the intro: it holds what `rotm settings` writes, it is the folder settings sync saves, and a file sync does not know stops a save. Link `settings-sync.md#what-is-saved`. At `:35`, "`~/.gitconfig` is a symlink into the repo" is true of a clone only: on an installed copy it is a file setup wrote once (`config.rotm-installed.toml:17`). Say both.
- [ ] **Step 4: Run** the checks. Expected: pass. `help forking` renders the page.
- [ ] **Step 5:** `pnpm check`, commit: "Rewrite Make it yours around your own settings".

### Task 8: Audit the docs, then close P6

**Files:**
- Modify: whichever pages the audit reports
- Modify: `docs/superpowers/specs/2026-11-11-installable-setup-profiles-and-sync.md` ("Plans", the P6 brief's "Shipped" line, and the "Open points" paragraph that says P6 rewrites `forking.md`)
- Modify: `docs/superpowers/plans/README.md`
- Move: this file to `docs/superpowers/plans/completed/`

- [ ] **Step 1: Run the `docs-audit` skill** over `README.md` and `docs/` (every page under it, `docs/gui/` included, as the brief's "Done when" says), with these questions added to its brief:
  1. Does any step an installed reader follows name a path under `~/dev/dotfiles`, tell them to edit a tracked file, or run `./setup.sh` without the `rotm install` form beside it?
  2. Does every command the README and `docs/installation.md` give for an installed copy exist in `bin/rotm`'s header?
  3. Is every value in `docs/forking.md`'s installed table changeable the way its row says? Check each against `settings/registry.toml`, `config.rotm-installed.toml` and `zsh/env.zsh`.
  4. Does any page still name `rotm settings serve` or a browser UI?
  5. Clone wording a review of this plan found and no task fixes: `settings/README.md:19` and `:34` ("the clone's code", "inside the clone"), and `docs/mole.md:26` and `:113` ("`~/.zshrc` links to `tilde/.zshrc`", "Edit the files in the repo"). Is each true of an installed copy, and if not, label it.
- [ ] **Step 2: Re-check each finding** against the file it cites before changing anything. A finding the code contradicts goes in a short table at the end of this plan, as the audit plans did.
- [ ] **Step 3: Fix** what holds, one commit: "Correct what the docs audit found". If it found nothing, say so in the plan's Outcome and skip the commit.
- [ ] **Step 4: Write the Outcome table** at the top of this plan (task, commit, difference from the plan), update the spec and the index, and move the plan. `pnpm check`, commit: "File the finished P6 plan".

P6's "Done when" is Step 1 returning no claim the shipped code contradicts. It is judged against `main`. It does not cover the copy a stranger gets from `stable` today.

## Not in this plan

- **Promoting `stable`.** It is P7's, proven in the VM first (decisions 9, 10 and 15). Until then the install line fetches `d09f025`, which has none of P2 to P5.
- **Renaming `dotfiles-settings`, `$DOTFILES` and the other `dotfiles` names.** The P1 brief calls it a later step, and no brief owns it yet.
- **A guest run.** Nothing here changes what setup installs except Task 2's one entry, which `bin/lib/test-dotfiles` proves with real mise in a scratch home. The next guest run, P7's, sees it on a real install.
- **A guard in `bin/obsidian-vault capture`.** On an installed copy it writes into the checkout, which `rotm update` then refuses to fast-forward. Task 5 labels the command as a clone's. The guard is a code change, recorded in the plan index for whoever picks it up.
- **Automatic sync, Linux, and the menu bar app's "Not built" list.**

## Review of this plan (2026-11-15)

One independent reviewer read the first version (`28bf015`) against the spec, the audit and the code, read-only. Each finding below was checked against the source or re-measured before the plan changed.

| Finding | Change |
| --- | --- |
| The "page named after a script" rule failed on day one: `claude-config` and `claude-catalog` are pages and scripts on purpose | Task 1 allows those two by name, and the Global Constraint says "no new page" |
| On an installed home that already has the old folder link, one apply left no `config.jsonc` (re-measured: `ascii` only) | Task 2 adds `depends` to the seeded entry and a fourth test case for that home |
| `help test-doc-links` cannot render: `help` reads `bin/`, not `bin/lib/` | Dropped from Task 1 |
| Task 2 made `.claude/rules/symlinks.md:13` and the comment at `40-dotfiles.toml:45` false | Both are in Task 2's files, with a step |
| Task 7's row-count check passed today and could pass after rows were lost | It is a guard now, scoped to the fork section |
| The installed table had no row for Claude Multipass, which is in the base | A row, with the `state = "absent"` form |
| The Claude row said setup does not remove your plugins, and left out that it adds the owner's back | Reworded, with a step to confirm it in `restore` |
| "Migrates as it does for the rules folder" had no precedent | Replaced by the measurement, and the migration case checks the source folder |
| Task 3 named `test-conventions`, which only greps `env.zsh` | It names `bin/lib/test-shell:176` and that form |
| Two of Task 4's checks could pass for the wrong reason | Check 3 is scoped to the installed section, and check 4 names the exact sentence |
| Lines false for an installed copy that no task named | `installation.md:166` and `:172` in Task 5, `updating.md:54` in Task 6, `local-customizations.md:35` in Task 7, and four more in Task 8's brief |
| The audit covered `docs/*.md`, which skips `docs/gui/` | Task 8 audits `docs/` |
| Undecided steps: where the README's tip goes, which commands the clone table repeats, what the installed preview shows, where `forking.md:27` goes, what `CLAUDE.md` says | Each decided where it sat |
| The lazygit route departs from the audit's decision 8, and neither new file syncs | Both stated under "Decided", and the two rows say "this Mac only" |

Both facts the first version left unmeasured are measured now: `symlink-each` recurses into a subfolder, and lazygit 0.66.3 documents a comma-separated `LG_CONFIG_FILE`. The fallbacks they carried are gone.

Left as they are: Task 1's first run finds nothing to fix, so its Step 4 is a check and not work. lazygit's merge order is taken from its documentation, since the plan has no way to run a full-screen program in the gate.

Not reviewed: `settings/README.md`, `setup/README.md`, `docs/menu-bar.md` and `docs/modules.md` were searched for clone wording, not read in full. Task 8's audit reads them.
