#!/usr/bin/env python3
#
# Check the docs' links: every relative link in a tracked Markdown page points at a file that exists, and every #anchor at a heading that exists.
#
# - Run its own cases, then check the repository:
#
# `python3 setup/tests/doc-links.py`
import re
import subprocess
import sys
import tempfile
from pathlib import Path
from urllib.parse import unquote

ROOT = Path(__file__).resolve().parents[2]
# Written by agents or vendored, and not pages a reader follows
SKIPPED = ("docs/superpowers/", ".claude/", ".serena/", "icons/", "private/")
# `help <name>` reads docs/<name>.md before the script's header, so a page named
# after a script hides its help. These two are their script's manual on purpose
PAGES_NAMED_AFTER_A_SCRIPT = ("claude-config", "claude-catalog")

LINK = re.compile(r"\[[^\]]*\]\(([^)\s]+)\)")
SCHEME = re.compile(r"[a-z][a-z0-9+.-]*:", re.I)
FENCE = re.compile(r"\s*(```|~~~)")


def slug(heading):
    """GitHub's anchor for a heading line."""
    text = re.sub(r"\[([^\]]*)\]\([^)]*\)", r"\1", heading.strip().lstrip("#").strip())
    return "".join(c for c in text.lower() if c.isalnum() or c in " -_").replace(" ", "-")


def prose(path):
    """(line number, line) for each line of a page outside its fenced blocks."""
    fenced = False
    for number, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        if FENCE.match(line):
            fenced = not fenced
        elif not fenced:
            yield number, line


def anchors(path):
    seen = {}
    found = set()
    for _, line in prose(path):
        if re.match(r"#{1,6} ", line):
            base = slug(line)
            count = seen.get(base, 0)
            seen[base] = count + 1
            found.add(f"{base}-{count}" if count else base)
    return found


def problems(root, pages):
    cache = {}
    for page in pages:
        for number, line in prose(root / page):
            for target in LINK.findall(re.sub(r"`[^`]*`", "", line)):
                if SCHEME.match(target):
                    continue
                path, _, fragment = unquote(target).partition("#")
                if path.startswith("/"):
                    file = root / path.lstrip("/")
                elif path:
                    file = (root / page).parent / path
                else:
                    file = root / page
                if not file.exists():
                    yield f"{page}:{number}: no such file: {target}"
                elif fragment and file.suffix == ".md":
                    if file not in cache:
                        cache[file] = anchors(file)
                    if fragment not in cache[file]:
                        yield f"{page}:{number}: no such heading: {target}"


def self_test():
    assert slug("### `~/.ssh/github_personal.pub`") == "sshgithub_personalpub"
    assert slug("## What must not be in the way") == "what-must-not-be-in-the-way"
    assert slug("macOS tips & tricks") == "macos-tips--tricks"
    with tempfile.TemporaryDirectory() as tmp:
        root = Path(tmp)
        (root / "a.md").write_text("[gone](b.md#gone) [there](b.md#here-1) [code](`x.md`)\n```\n[fenced](x.md)\n```\n")
        (root / "b.md").write_text("# Here\n\n## Here\n")
        found = list(problems(root, ["a.md", "b.md"]))
        assert found == ["a.md:1: no such heading: b.md#gone"], found


def main():
    self_test()
    tracked = subprocess.run(
        ["git", "ls-files", "*.md"], cwd=ROOT, check=True, capture_output=True, text=True
    ).stdout.splitlines()
    pages = [p for p in tracked if not p.startswith(SKIPPED)]
    found = list(problems(ROOT, pages))
    scripts = {p.name for p in (ROOT / "bin").iterdir() if p.is_file()}
    for page in sorted((ROOT / "docs").glob("*.md")):
        if page.stem in scripts and page.stem not in PAGES_NAMED_AFTER_A_SCRIPT:
            found.append(f"docs/{page.name}:1: named after bin/{page.stem}, so `help {page.stem}` shows this page")
    if found:
        print("\n".join(found), file=sys.stderr)
        sys.exit(1)
    links = sum(
        1
        for page in pages
        for _, line in prose(ROOT / page)
        for target in LINK.findall(re.sub(r"`[^`]*`", "", line))
        if not SCHEME.match(target)
    )
    print(f"ok: {links} relative links in {len(pages)} pages")


if __name__ == "__main__":
    main()
