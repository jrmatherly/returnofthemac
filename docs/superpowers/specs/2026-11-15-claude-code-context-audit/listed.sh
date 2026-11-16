#!/bin/bash
#
# Print present or absent for each name given, read from the agents, skills and slash commands
# that a new Claude Code session in the current directory starts with. No model is asked.
#
# `listed.sh name…`
#
# The session is not saved, so it leaves no transcript for a later usage scan to count.

set -euo pipefail

[ $# -gt 0 ] || {
  echo "usage: listed.sh name…" >&2
  exit 2
}
init=$(claude -p ok --model haiku --no-session-persistence --output-format stream-json --verbose 2> /dev/null \
  | jq -c 'select(.subtype == "init")' | head -1)
[ -n "$init" ] || {
  echo "listed.sh: claude printed no init event" >&2
  exit 1
}
jq -r '$ARGS.positional as $want | (.agents + .skills + .slash_commands) as $all
  | $want[] | . + "=" + (if . as $n | $all | index($n) then "present" else "absent" end)' --args "$@" <<< "$init"
