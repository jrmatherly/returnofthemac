# jstack model configuration. One line per role, `<model> <effort>`. Delete a line to fall back to the skill default.
# `inherit`: the role runs on the parent's model and effort (omit both). `codex`: a read-only seat run by `codex exec`.
# budget: small (medium)
# Changed by hand from the skill table: fable for judgment, prose and the lead seat on each panel; opus for code; no codex seats.
feature, refactoring: opus medium
bug-fix: opus medium
perf-issue: opus medium
hillclimb: opus medium
judgment and prose: fable medium
arena runners: fable medium, opus medium, opus medium
arena cross-judge pool: fable medium, opus medium
swarm workers: opus medium
interrogate reviewers: fable medium, opus medium, sonnet medium
