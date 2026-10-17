#!/usr/bin/env bash
# util_switch_census.sh -- CERTIFY the SET-today env-var switch list by real measurement.
#
# WHY THIS EXISTS (hq_C s269, brief CEO-11c "empirical-switch-rule"):
#   Lon's rule is THE KEEP-LIST IS EXACTLY THE SWITCHES SET TODAY, everything else dies.
#   That makes "is this switch set?" a load-bearing question, and the first census answered it
#   at SUBSTRING level and reported ~8.  The real number is 48.  A 6x error in the direction of
#   deleting live configuration is the kind this script exists to make un-repeatable.
#
# ⛔ THE TWO TRAPS, both hit on the first honest pass, both defended against here:
#   (1) PROSE IS NOT A SETTING.  131 of 181 "assigned" names are assigned only inside .github/
#       and corpus/ -- FINDINGs, READMEs and probe programs QUOTING a command line.  Grepping the
#       org brain for FOO= certifies documentation as configuration.  Assignments are therefore
#       ATTRIBUTED PER TREE and only the live harness (../harness/scripts/ + Makefile) certifies a keep.
#   (2) A COMMENT IS NOT A SETTING, AND ARGV IS.  Comment-only mentions are filtered out (3 of 50
#       were).  But a switch can also be set through a door no assignment regex can see: e.g.
#       test_gate_zdp_on_null.sh:27 takes VAR=1 AS ARGV (`ENVS=("$@")`), which is how SCRIP_ZONE
#       is really set today.  Such doors are listed in ARGV_DOORS below and must be read, not
#       grepped -- so this script REPORTS them for a human rather than pretending to resolve them.
#
# Usage: bash ../harness/scripts/util_switch_census.sh [--sites]     (--sites prints one assignment site per name)
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
SIBS="$(cd "$ROOT/.." && pwd)"
cd "$ROOT"
WANT_SITES=0; [ "$1" = "--sites" ] && WANT_SITES=1
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
ASSIGN_RE='(^|[[:space:];&|(`]|export[[:space:]]+|env[[:space:]]+)[A-Za-z_][A-Za-z0-9_]*[[:space:]]*[?:+]?='
names_assigned_in() { grep -rhoE "$ASSIGN_RE" "$@" 2>/dev/null | sed -E 's/.*[^A-Za-z0-9_]([A-Za-z_][A-Za-z0-9_]*)[[:space:]]*[?:+]?=$/\1/; s/^([A-Za-z_][A-Za-z0-9_]*)[[:space:]]*[?:+]?=$/\1/' | sort -u; }
# --- SET A: every switch the compiler actually READS ---
grep -rhoE 'getenv[[:space:]]*\([[:space:]]*"[A-Za-z_][A-Za-z0-9_]*"' src/ | sed -E 's/.*"([A-Za-z0-9_]+)"/\1/' | sort -u > "$TMP/read"
grep -rhoE '(setenv|putenv)[[:space:]]*\([[:space:]]*"[A-Za-z_][A-Za-z0-9_]*"' src/ | sed -E 's/.*"([A-Za-z0-9_]+)"/\1/' | sort -u > "$TMP/selfset"
# --- SET B: assignments, ATTRIBUTED PER TREE ---
names_assigned_in ../harness/scripts/ Makefile                      > "$TMP/b_harness"
names_assigned_in "$SIBS/.github"                        > "$TMP/b_github"
names_assigned_in "$SIBS/corpus"                         > "$TMP/b_corpus"
comm -12 "$TMP/read" "$TMP/b_harness" > "$TMP/harness"
# --- filter comment-only mentions: an assignment on a '#' line is not a setting ---
: > "$TMP/certified"; : > "$TMP/commentonly"
while read -r v; do
    if grep -rnE "(^|[[:space:];&|(\`]|export[[:space:]]+|env[[:space:]]+)$v[[:space:]]*[?:+]?=" ../harness/scripts/ Makefile 2>/dev/null | grep -vqE '^[^:]+:[0-9]+:[[:space:]]*#'; then echo "$v" >> "$TMP/certified"; else echo "$v" >> "$TMP/commentonly"; fi
done < "$TMP/harness"
# --- ARGV DOORS: harnesses that set switches from their own argv; grep cannot see these ---
ARGV_DOORS="../harness/scripts/test_gate_zdp_on_null.sh"
for d in $ARGV_DOORS; do grep -hoE '[A-Z][A-Z0-9_]*=' "$d" 2>/dev/null | tr -d '='; done | sort -u > "$TMP/argv"
comm -12 "$TMP/read" "$TMP/argv" > "$TMP/argv_set"
cat "$TMP/certified" "$TMP/argv_set" | sort -u > "$TMP/keep"
comm -23 "$TMP/read" "$TMP/keep" > "$TMP/unset"
printf 'SWITCH CENSUS -- tree %s @ %s\n' "$ROOT" "$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)"
printf '  read by src/ (getenv)              %5d\n' "$(wc -l < "$TMP/read")"
printf '  self-set by src/ (setenv/putenv)   %5d   [expect 0]\n' "$(wc -l < "$TMP/selfset")"
printf '  assigned in LIVE HARNESS           %5d\n' "$(wc -l < "$TMP/harness")"
printf '    of which comment-only (NOT set)  %5d   %s\n' "$(wc -l < "$TMP/commentonly")" "$(tr '\n' ' ' < "$TMP/commentonly")"
printf '  set via ARGV DOORS                 %5d   %s\n' "$(wc -l < "$TMP/argv_set")" "$(tr '\n' ' ' < "$TMP/argv_set")"
printf '  assigned ONLY in .github/corpus    %5d   [PROSE -- certifies nothing]\n' "$(comm -13 "$TMP/harness" "$(cat "$TMP/b_github" "$TMP/b_corpus" | sort -u > "$TMP/prose"; comm -12 "$TMP/read" "$TMP/prose" > "$TMP/prose_read"; echo "$TMP/prose_read")" | wc -l)"
printf '\n  ⭐ CERTIFIED SET-TODAY (keep)       %5d\n' "$(wc -l < "$TMP/keep")"
printf '  ⛔ UNSET (die, minus keep-classes)  %5d\n\n' "$(wc -l < "$TMP/unset")"
echo "--- CERTIFIED SET-TODAY ---"
if [ "$WANT_SITES" = 1 ]; then
    while read -r v; do
        s=$(grep -rnE "(^|[[:space:];&|(\`]|export[[:space:]]+|env[[:space:]]+)$v[[:space:]]*[?:+]?=" ../harness/scripts/ Makefile 2>/dev/null | grep -vE '^[^:]+:[0-9]+:[[:space:]]*#' | head -1 | cut -c1-100)
        [ -z "$s" ] && s="(argv door)"
        printf '  %-28s %s\n' "$v" "$s"
    done < "$TMP/keep"
else
    sed 's/^/  /' "$TMP/keep"
fi
echo
echo "--- UNSET (candidates; keep-classes are applied by the strip brief, not here) ---"
sed 's/^/  /' "$TMP/unset"
