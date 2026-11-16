#!/bin/bash
#
# Print present or absent for each name given, read from the agents, skills and slash commands
# that a new Claude Code session in the current directory starts with. No model is asked.
#
# `listed.sh name…`
#
# The session is a real agent in this repository, and its start hooks hand it the handoff note.
# The first version sent it the prompt "ok" with every tool, and it took that as a go-ahead and
# ran parts of the plan it was checking, and started more sessions like itself. So it gets no
# built-in tools, no MCP servers, plan mode and an inert prompt, and is killed as soon as its
# start-up list is read, also when this script is interrupted. It is not saved. Its start hooks
# still run, so Hindsight and the handoff hook see a session start.

set -euo pipefail

[ $# -gt 0 ] || {
  echo "usage: listed.sh name…" >&2
  exit 2
}
out=$(mktemp)
pid=""
trap '[ -z "$pid" ] || kill "$pid" 2> /dev/null; rm -f "$out"' EXIT
claude -p 'Reply with the one word: listed. Do nothing else.' --model haiku --no-session-persistence \
  --tools "" --strict-mcp-config --permission-mode plan --output-format stream-json --verbose > "$out" 2> /dev/null &
pid=$!
init=""
for _ in $(seq 240); do
  init=$(grep -m1 '"subtype":"init"' "$out" || true)
  [ -z "$init" ] || break
  kill -0 "$pid" 2> /dev/null || break
  sleep 0.5
done
kill "$pid" 2> /dev/null || true
wait "$pid" 2> /dev/null || true
[ -n "$init" ] || {
  echo "listed.sh: claude printed no init event" >&2
  exit 1
}
jq -r '$ARGS.positional as $want | (.agents + .skills + .slash_commands) as $all
  | $want[] | . + "=" + (if . as $n | $all | index($n) then "present" else "absent" end)' --args "$@" <<< "$init"
