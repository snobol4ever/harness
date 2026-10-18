#!/usr/bin/env bash
# test_gate_stage2_isolation.sh — stage2 handoff firewall.
#
# Invariant: the old shim-macro names — `g_registry`, `label_table`,
# `label_count`, `g_pl_pred_table`, `proc_table`, `proc_count` — must
# appear in source ONLY as qualified field references of stage2_t, never
# as bare/unqualified identifiers.
#
# ST2-1 introduced stage2_t with those six fields and a corresponding set
# of reader shim macros (`#define proc_table (g_stage2.proc_table)` etc.).
# ST2-1b deleted all six macros across four sub-steps (g_registry,
# label_table/label_count, g_pl_pred_table, proc_table/proc_count).  Today
# every reader of those tables resolves to either:
#
#     g_stage2.<field>     (deep-dispatch sites with no s2 in scope)
#     s2-><field>          (producer sites threading stage2_t *s2)
#
# A bare `proc_table[i]` or `proc_count++` in a future commit would mean
# someone reintroduced a shim macro (or relied on one that's been deleted).
# Both are regressions of the ST2-1b decision.  This gate catches that
# regression at grep time, before the slower compile/link/test cycle.
#
# Honest scope: this is a TOKEN firewall (same shape as the parse/runtime
# include firewalls — fast, lexical, false-positive-prone).  It does NOT
# prove that reads of g_stage2 fields are reachable only from the proper
# producer/reader sites.  A link-time isolation analogous to ISO-7 would
# close that gap; see ST2-2's followup in the goal file.
#
# Run: bash ../harness/scripts/test_gate_stage2_isolation.sh
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
cd "$ROOT"
. "$HERE/lib_gate.sh"
gate_parse_args "$@"

# A missing src/ must REFUSE, not silently score zero violations. The scan below
# runs grep with `|| true` (required so `set -euo pipefail` tolerates a legitimate
# zero-matches result), which also swallows grep's "No such file or directory" when
# src/ itself is absent -- indistinguishable from a clean scan without this check.
[ -d src ] || { echo "UNPROVEN: src missing"; exit 2; }

# The six field names that used to be shim macros.  Each must appear in
# source only as a qualified field reference (preceded by `.` or `->`).
FIELDS=(
    g_registry
    label_table
    label_count
    g_pl_pred_table
    proc_table
    proc_count
)

# Allowlist: file:identifier pairs where a bare reference is expected.
# Format: one entry per line, "<file>:<identifier>".
# Each entry must carry a comment above it explaining why.
ALLOW=(
    # stage2.h defines the struct itself — the field names appear bare
    # there as struct member declarations.  This is the source of truth.
    # PATH UPDATED 2026-08-28 (stage2-isolation-missing-src-false-ok): the
    # srcreorg MOVE 2 of 3 (SCRIP d4312e86, 2026-08-26) merged src/contracts
    # into src/ir; these six entries still named the pre-move path, which
    # made this gate FAIL on the four fields still bare in the struct today
    # (label_table/label_count/proc_table/proc_count) — a false RED, not a
    # real ST2-1b regression. Re-verified at src/ir/stage2.h before fixing.
    "src/ir/stage2.h:g_registry"
    "src/ir/stage2.h:label_table"
    "src/ir/stage2.h:label_count"
    "src/ir/stage2.h:g_pl_pred_table"
    "src/ir/stage2.h:proc_table"
    "src/ir/stage2.h:proc_count"
    # ScripModule (the per-language module-registry entry) has its own
    # `nprocs` field — renamed from `proc_count` in ST2-1 specifically to
    # avoid colliding with the (now-gone) shim macro.  The struct comment
    # in stage2.h still mentions the old name as documentation history.
    # No code change here; this is doc text only.

    # KNOWN STALE, LEFT AS-IS 2026-08-28: src/driver/interp_private.h no
    # longer exists post-srcreorg (confirmed: `ls` fails; the "ST2-1b"/"shim
    # macro" doc text these three entries described is not findable anywhere
    # under src/ by grep either — deleted, not moved). Currently inert: zero
    # live violations depend on these three entries either way, so left
    # untouched rather than guessing a replacement path — flagged for
    # whoever next sweeps this gate's allowlist for post-srcreorg staleness.
    "src/driver/interp_private.h:g_registry"
    "src/driver/interp_private.h:label_table"
    "src/driver/interp_private.h:label_count"

    # scrip_sm.c's sm_resolve_proc_entry_pcs prints a [CH-17a] diagnostic
    # banner that names 'proc_table' as a literal label inside the printf
    # format string.  The format string is human-facing text; the actual
    # code reads s2->proc_count and s2->proc_table[i] (both qualified).
    "src/driver/scrip_sm.c:proc_table"

    # ADDED 2026-08-28 (stage2-isolation-missing-src-false-ok): unification.c
    # declares its own file-static `pl_pred_row_t *g_pl_pred_table = 0;` for
    # the UNRELATED Prolog predicate-table meta-call substrate (PT-0/PT-1a/
    # PT-2a, SCRIP 01dbd8fe/62426a60) -- not a stage2_t field reference.
    # Verified: `static` (internal linkage, cannot be extern'd elsewhere) and
    # this is its ONLY occurrence in the file (grep), so it is also unread —
    # dead within its own translation unit, not just misnamed. stage2_t has
    # no field named g_pl_pred_table today (renamed to resolve_pred_table);
    # this identifier cannot resolve to or be confused with that field.
    "src/runtime/unification.c:g_pl_pred_table"

    # ADDED 2026-08-28 (stage2-isolation-missing-src-false-ok): scrip.c:57 is
    # the closing line of a multi-line /* ... */ block comment (opens line 47,
    # "N-2 item 2 step 1 (hq_P): HOST-DETECTION PREDICATE...") whose
    # continuation lines carry no leading '*', so this gate's line-starts-
    # with-comment-marker heuristic (see the loop below) does not catch it.
    # The word is plain prose ("...therefore proc_count for main..."), not
    # code; the actual code four lines later correctly reads s2->proc_count.
    "src/driver/scrip.c:proc_count"
)

violations=0
new_violations=()

# Negative-lookbehind regex: a field-name word NOT preceded by '.' or '>'.
# Perl-compatible regex; grep -P is required.
#
# We also skip:
#   - comments (lines starting with optional whitespace then '*' or '//' or '/*')
#   - string literals containing the names (rare; would be a false positive)
#   - the stage2.h struct definition (already on the allowlist)
#
# The grep is deliberately permissive on false positives — the allowlist
# is the proper escape hatch for any legitimate bare appearance.

# ⛔ THE POPULATION IS COUNTED BEFORE THE FIELD SWEEP (coo 2026-09-18, the cto's finding, seat10's 2026-08-23
# list).  Every field below is checked with a grep -r over src/ that must find NO bare reference, so an EMPTY
# src/ satisfies every field at once and the gate printed that all references are qualified having opened no
# file.  For a gate whose whole verdict is an absence, the denominator IS the verdict.
census_files=$(find src/ -name '*.c' -o -name '*.h' 2>/dev/null | wc -l)
gate_floor "$census_files" 1 "src/ C source file(s) over which every field's absence is asserted"

for field in "${FIELDS[@]}"; do
    # Match the field as a whole word not preceded by '.' or '>'.
    # Then filter out comment lines (very rough, but catches the
    # historical-doc references in stage2.h).
    while IFS= read -r line; do
        [ -z "$line" ] && continue
        file="${line%%:*}"
        rest="${line#*:}"
        lineno="${rest%%:*}"
        # Skip pure comment lines (line begins with * or // or /* after
        # leading whitespace, or contains the field only inside a /* */
        # block — we approximate by skipping any line whose pre-field
        # text contains '/*' without a matching '*/' before the field).
        # Simpler: skip lines that look like comments.
        text="${rest#*:}"
        # Trim leading whitespace.
        trimmed="$(echo "$text" | sed -E 's/^[[:space:]]+//')"
        case "$trimmed" in
            \**|"//"*|"/*"*) continue ;;
        esac
        # Check allowlist.
        key="$file:$field"
        ok=0
        for allowed in "${ALLOW[@]}"; do
            if [ "$key" = "$allowed" ]; then
                ok=1
                break
            fi
        done
        if [ $ok -eq 0 ]; then
            new_violations+=("$file:$lineno: bare reference to '$field'")
            violations=$((violations + 1))
        fi
    done < <(grep -rPn "(?<![\.\>_a-zA-Z0-9])${field}\b" src/ --include="*.c" --include="*.h" 2>/dev/null | grep -v "^Binary file" || true)
done

if [ $violations -gt 0 ]; then
    echo "FAIL stage2 isolation firewall: $violations bare reference(s) to former shim-macro field name(s):"
    for v in "${new_violations[@]}"; do echo "  $v"; done
    echo ""
    echo "These field names must always be qualified with 'g_stage2.' or 's2->'."
    echo "If the bare reference is legitimate (e.g. struct member declaration,"
    echo "historical-doc comment), add a 'file:field' entry to the ALLOW list"
    echo "in this script with a comment explaining why."
    exit 1
fi

echo "OK  stage2 isolation firewall: all references to {${FIELDS[*]}} are qualified"
echo "    (allowlist size: ${#ALLOW[@]} entries — see top of script)"
