#!/bin/bash
# Companion to 1Password agent-hooks: blocks non-Bash tool calls
# (Read, Edit, MultiEdit, Write, NotebookEdit) from operating on a
# named-pipe FIFO — the file type 1Password uses for local .env mounts.
#
# Why this exists: upstream agent-hooks (1Password/agent-hooks) only
# registers a `matcher: "Bash"` entry. Tool-using LLM agents like
# Claude Code default to Read/Edit for file inspection, bypassing the
# upstream validator entirely. Without this companion, "what's in .env"
# (which routes through the Read tool) leaks the FIFO contents into
# the conversation transcript.
#
# This is a workaround. Track upstream support at:
#   https://github.com/1Password/agent-hooks/issues/28
#
# Decision rule: any tool call whose target path is a FIFO is denied.
# Regular files, directories, and missing paths are allowed.

set -euo pipefail

input=$(cat)

# Extract the path argument. CC tools that touch files use either
# tool_input.file_path (Read, Edit, MultiEdit, Write) or
# tool_input.notebook_path (NotebookEdit, NotebookRead).
path=$(printf '%s' "$input" | python3 -c "
import json, sys
try:
    d = json.load(sys.stdin)
    ti = d.get('tool_input', {}) if isinstance(d, dict) else {}
    print(ti.get('file_path') or ti.get('notebook_path') or '')
except Exception:
    pass
" 2>/dev/null || true)

# No path → not a file tool → allow.
[ -z "$path" ] && exit 0

# Resolve to absolute path.
case "$path" in
    /*) abs="$path" ;;
    *) abs="$(pwd)/$path" ;;
esac

# Not a FIFO → regular file/dir/missing → allow.
[ -p "$abs" ] || exit 0

# It's a FIFO → almost certainly a 1Password local-.env mount.
cat >&2 <<MSG
Refusing tool call: "$abs" is a named pipe (FIFO).

This is almost certainly a 1Password local-.env mount. Reading or
editing it via this tool would stream real secrets into the
conversation transcript and any cache/log touching it.

If you need to inspect values, run \`op read 'op://...'\` in your
own shell (not via this agent), or check the 1Password desktop app's
Variables tab for the relevant Environment.
MSG
exit 2
