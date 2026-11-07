#!/usr/bin/env bash
# ⛔⭐ GATE: no baton's real DONE-WHEN sits hidden behind an unreachable column-0 placeholder.
# Row fifty-seven-batons-are-unclosable-because-their-criterion-is-not-at-column-zero (seat13, 2026-09-05).
# Sources the SHIPPED s4e_donewhen_is_placeholder / s4e_donewhen_hidden_elsewhere functions straight out of
# s4e_msg.sh (never a hand-copied duplicate -- two copies of one rule drift, per that file's own warning at
# its s4e_donewhen_needs_compiler comment) so this gate tests the real mechanism, not a model of it.
# CLASSES (cio ruling (c), 2026-11-07): HIDDEN = a column-0 placeholder AND an indented real `DONE-WHEN: <command>` line above ## LEDGER (always RED).
# UNEXPRESSED = a column-0 placeholder AND only prose naming DONE-WHEN: elsewhere (the GOAL line): RED only when the baton's row in QUEUE.tsv is live
# (FREE, QUEUED:*, ASSIGNED:*, CLAIMED:*); a parked row or a baton with no row is backlog debt, printed on one line, never relabelled, never red.
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

[ -f "$PO/QUEUE.tsv" ] || { echo "REFUSE(2): $PO/QUEUE.tsv not found -- cannot tell a live row from a parked one" >&2; exit 2; }
declare -A ST
while IFS=$'\t' read -r rank topic owner state rest; do
    case "$rank" in '#'*|'') continue;; esac
    ST["$topic"]="$state"
done < "$PO/QUEUE.tsv"

n=0; debt=0
cd "$PO/tasks" || exit 2
for f in *.task.md; do
    dw="$(sed -n 's/^DONE-WHEN:[[:space:]]*//p' "$f" | head -1)"
    case "$dw" in '`'*'`') dw="${dw#\`}"; dw="${dw%\`}";; esac
    s4e_donewhen_is_placeholder "$dw" || continue
    real="$(awk '/^## LEDGER/{exit} {print}' "$f" | sed -nE 's/^[[:space:]]+DONE-WHEN:[[:space:]]*//p' | head -1)"
    case "$real" in '`'*'`') real="${real#\`}"; real="${real%\`}";; esac
    if [ -n "$real" ] && ! s4e_donewhen_is_placeholder "$real"; then
        n=$((n+1))
        printf 'RED: %s -- HIDDEN: column 0 is a placeholder AND a real indented DONE-WHEN: line sits below it\n' "$f" >&2
    elif s4e_donewhen_hidden_elsewhere "$f"; then
        st="${ST[${f%.task.md}]:-}"
        case "$st" in
            FREE|QUEUED:*|ASSIGNED:*|CLAIMED:*)
                n=$((n+1))
                printf 'RED: %s -- UNEXPRESSED on a LIVE row (%s): a placeholder at column 0 and no criterion anywhere\n' "$f" "$st" >&2;;
            *) debt=$((debt+1));;
        esac
    fi
done

[ "$debt" -gt 0 ] && echo "UNEXPRESSED: $debt baton(s) carry a placeholder and only GOAL prose, none on a live row -- backlog debt, re-minted with a real criterion by its owner when unparked (not red)"
if [ "$n" -eq 0 ]; then
    echo "GREEN: no baton hides its criterion from the tool that must run it, and no live row is unexpressed"
    exit 0
else
    echo "RED: $n baton(s): a HIDDEN real criterion below a column-0 placeholder, or an UNEXPRESSED live row -- unclosable at any tree state"
    exit 1
fi
