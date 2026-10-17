#!/usr/bin/env bash
# ⛔⭐ GATE: no baton's real DONE-WHEN sits hidden behind an unreachable column-0 placeholder.
# Row fifty-seven-batons-are-unclosable-because-their-criterion-is-not-at-column-zero (seat13, 2026-09-05).
# Sources the SHIPPED s4e_donewhen_is_placeholder / s4e_donewhen_hidden_elsewhere functions straight out of
# s4e_msg.sh (never a hand-copied duplicate -- two copies of one rule drift, per that file's own warning at
# its s4e_donewhen_needs_compiler comment) so this gate tests the real mechanism, not a model of it.
set -u
S4E_HOME="${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
MSG_SH="$S4E_HOME/harness/scripts/s4e_msg.sh"
PO="${S4E_POST:-/home/resources/postoffice}"

[ -f "$MSG_SH" ] || { echo "REFUSE(2): $MSG_SH not found -- cannot load the real placeholder/hidden-elsewhere logic" >&2; exit 2; }
[ -d "$PO/tasks" ] || { echo "REFUSE(2): $PO/tasks not found -- cannot measure" >&2; exit 2; }

HELPERS="$(awk '
  /^s4e_donewhen_is_placeholder\(\)/ { grab=1 }
  /^s4e_donewhen_hidden_elsewhere\(\)/ { grab=1 }
  /^# READ-ONLY probe:/ { grab=0 }
  grab { print }
' "$MSG_SH")"
[ -n "$HELPERS" ] || { echo "REFUSE(2): could not extract s4e_donewhen_is_placeholder/s4e_donewhen_hidden_elsewhere from $MSG_SH -- names may have changed" >&2; exit 2; }
eval "$HELPERS"
type s4e_donewhen_is_placeholder >/dev/null 2>&1 || { echo "REFUSE(2): extraction ran but s4e_donewhen_is_placeholder is not a function -- extraction is broken" >&2; exit 2; }
type s4e_donewhen_hidden_elsewhere >/dev/null 2>&1 || { echo "REFUSE(2): extraction ran but s4e_donewhen_hidden_elsewhere is not a function -- extraction is broken" >&2; exit 2; }

n=0
cd "$PO/tasks" || exit 2
for f in *.task.md; do
    dw="$(sed -n 's/^DONE-WHEN:[[:space:]]*//p' "$f" | head -1)"
    case "$dw" in '`'*'`') dw="${dw#\`}"; dw="${dw%\`}";; esac
    if s4e_donewhen_is_placeholder "$dw" && s4e_donewhen_hidden_elsewhere "$f"; then
        n=$((n+1))
        printf 'RED: %s -- column 0 is a placeholder AND another DONE-WHEN: line sits elsewhere:\n' "$f" >&2
        printf '%s\n' "$_dhe_lines" | sed 's/^/  /' >&2
    fi
done

if [ "$n" -eq 0 ]; then
    echo "GREEN: no baton hides its criterion from the tool that must run it"
    exit 0
else
    echo "RED: $n baton(s) carry a placeholder at column 0 with a real DONE-WHEN: line hidden elsewhere -- unclosable at any tree state"
    exit 1
fi
