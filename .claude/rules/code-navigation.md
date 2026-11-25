# Which code tool to use here

- **Understand / locate** (what calls what, where is X): CodeGraph first (`codegraph_explore`), per the global instructions.
- **Read or edit a symbol in a `*.sh` file**: Serena's symbol tools (`get_symbols_overview`, `find_symbol`, `replace_symbol_body`, `find_referencing_symbols`).
- **Everything else**: `bin/` scripts (no extension, so Serena's language server doesn't see them), `zsh/*.zsh`, `tilde/**`, Markdown, JSON/TOML/YAML: native Read and Edit (or Serena's `replace_content`). Serena's "Edit is forbidden for code files" applies only to files its language server serves.
- **Before an edit through Serena or after a CodeGraph read**: Read the file natively once. Path-scoped rules and nested `CLAUDE.md` files load on a native Read, Edit or Write, and on a Bash `cat` or `head` only when rtk leaves it alone (measured 2026-11-25 on Claude Code 2.1.332: a Serena read, a CodeGraph read and a Bash `head` that rtk rewrote loaded none).
