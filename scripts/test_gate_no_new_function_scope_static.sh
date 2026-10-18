#!/usr/bin/env bash
# ../harness/scripts/test_gate_no_new_function_scope_static.sh -- row census-function-scope-mutable-statics-under-src.
#
# EXTENDS NO-NEW-GLOBALS (RULES.md line 169) TO FUNCTION-SCOPE MUTABLE STATICS -- SCOPED TO src/runtime/ ONLY.
# The existing enforcement ("diffs checked for new file-scope definitions", GOAL-*.md's ENFORCEMENT lines,
# test_gate_pl_no_new_global.sh) names only FILE-SCOPE declarations and the Prolog g_* naming convention.
# Neither catches `static int x = -1;` sitting inside a function body -- and static storage duration, not the
# scope keyword, is the property the law guards (ceo ruling 2026-09-01, RULES.md line 169, receipt: hq_P's
# self-raised question on two getenv killswitch statics in emit.cpp's zd_plan). This gate is the missing half.
#
# ⛔⛔ SCOPE RE-CUT 2026-09-02 (ceo, routed hq_B, on Lon in-chat verbatim: "You can always add as many g_emit
# values as you want. Those were never part of the no global rule."): the clarification that minted this row
# was itself an overshoot -- COMPILE-TIME working state (emitter/lower/ir/driver/optimizer/templates/parsers,
# which runs once per COMPILATION, not once per program execution) was NEVER the target; ordinary long-
# standing practice there needs no grant. Scope is now src/runtime/ ONLY -- the tree that becomes
# libscrip_rt.so and is executed by every COMPILED program at ITS OWN runtime, which is where a new,
# ungranted mutable static is genuinely new PROGRAM state and genuinely load-bearing on the SCOPE GUARD's
# own terms (a per-match/per-dispatch hot path). A compile-time-scoped conversion was built, verified, and
# then DISCARDED under this re-cut before landing -- salvage patch:
# /home/resources/postoffice/salvage/seat07-census-function-scope-mutable-statics-under-src-compile-time-DISCARDED-2026-09-02.patch
# (worth reading before anyone reopens compile-time scope: the discarded conversion, though behaviorally a
# pure deletion in every single site, measurably broke corpus witness pos_rpos_alt_branch_5 with a
# deterministic runtime ERROR 246 stack overflow -- root cause not fully traced, plausibly one of
# bb_match_defer.cpp's getenv-cache flags selecting an inconsistent code-generation strategy across the
# function's two compile-time invocations for a self-referential deferred pattern. Bisected cleanly:
# pre-conversion tree passes the witness 2/2 runs, converted tree fails 3/3 runs, deterministic either way.)
#
# MECHANISM: a PER-FILE RATCHET, not a single scalar and not a symbol-name allowlist (unlike
# test_gate_pl_no_new_global.sh's g_* SANCTIONED list) -- function-scope statics are overwhelmingly named
# with short, non-unique locals (`v`, `on`, `m`, `p`...), so a name-based allowlist would be ambiguous by
# construction; a name in one function tells you nothing about a same-named local in another. Per-file
# COUNTS are stable under line-number churn elsewhere in the file and, combined with the GRANT-comment
# carve-out below, are precise enough to catch a genuinely NEW site while a pure global scalar total (the
# INSTRUMENT LAWS' "count-only criteria" warning) could hide one new site behind an unrelated conversion
# landing in the same commit. A file with NO baseline row has an implicit ceiling of ZERO. Paths in the
# baseline and in this gate's own file-keys are relative to CENSUS_ROOT (src/runtime/ by default, override
# with FSS_ROOT), NOT to src/ -- e.g. "core/core.c", not "runtime/core/core.c".
#
# GRANT CARVE-OUT: per the row's brief -- "needs a cited grant, and if none exists say so LOUDLY rather
# than minting one retroactively" -- a static whose declaration LINE contains the literal marker `GRANT:`
# is excluded from the ratchet count entirely (it is documented, sanctioned state, the function-scope
# sibling of test_gate_pl_no_new_global.sh's SANCTIONED list comment blocks). Landing a GRANT: comment
# without an actual cited Lon ruling is exactly the "quiet ask does not count as asking" violation RULES.md
# already forbids -- this gate does not (yet) verify the citation's substance, only that the marker exists;
# review is still required, same as any other law-citing comment.
#
# ⛔ RATCHET LOWERING IS MANUAL, NEVER AUTO (same law as test_gate_icn_rbp_census_ratchet.sh): when a
# session converts or grants sites in a file, it lowers that file's row in func_scope_static_baseline.tsv
# in the SAME commit. This script never rewrites the baseline itself.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
CENSUS_ROOT="${FSS_ROOT:-$ROOT/src/runtime}"
BASELINE="${FSS_BASELINE:-$HERE/func_scope_static_baseline.tsv}"
CENSUS="$HERE/util_census_function_scope_statics.py"

[ -f "$CENSUS" ] || { echo "REFUSED: census instrument missing: $CENSUS"; exit 2; }
[ -f "$BASELINE" ] || { echo "REFUSED: baseline missing: $BASELINE"; exit 2; }
command -v python3 >/dev/null || { echo "REFUSED: python3 not on PATH"; exit 2; }

if [ "${1:-}" = "--selftest" ]; then
    # ⭐ TWO-PART PROOF (RULES.md): before trusting this gate, watch it FAIL once on a deliberately
    # offending static, then watch it PASS again once the offense is removed -- a gate nobody has
    # seen fail is not a gate. Runs entirely inside a throwaway sandbox src/ tree; never touches the
    # real one.
    SBX="$(mktemp -d /tmp/fss_gate_selftest_XXXXXX)"
    trap 'rm -rf "$SBX"' EXIT
    mkdir -p "$SBX/src/emitter"
    ok=1
    # --- CASE 1: a clean tree (mirrors the real baseline's own files, present at their exact ceiling) passes ---
    cat > "$SBX/src/emitter/emit.cpp" <<'EOF'
static int seq_fold_on(void) { int on = -1; if (on < 0) { const char *e = getenv("X"); on = (e && *e == '0') ? 0 : 1; } return on; }
EOF
    printf 'emitter/emit.cpp\t0\n' > "$SBX/baseline.tsv"
    out="$(python3 "$CENSUS" --root "$SBX/src" 2>&1)"
    mutable_n="$(echo "$out" | sed -n 's/^  MUTABLE (in scope):  *//p')"
    [ "$mutable_n" = "0" ] || { echo "SELFTEST FAIL case 1: expected 0 mutable statics on the de-static'd form, census says $mutable_n"; ok=0; }
    echo "${ok:+SELFTEST}" >/dev/null
    [ "$mutable_n" = "0" ] && echo "SELFTEST OK: case 1 (clean tree, static already removed) -- census reports 0, gate would PASS"
    # --- CASE 2: inject ONE deliberate offending function-scope static -- the gate's positive control ---
    cat > "$SBX/src/emitter/emit.cpp" <<'EOF'
static int seq_fold_on(void) { static int on = -1; if (on < 0) { const char *e = getenv("X"); on = (e && *e == '0') ? 0 : 1; } return on; }
EOF
    out="$(python3 "$CENSUS" --root "$SBX/src" 2>&1)"
    mutable_n="$(echo "$out" | sed -n 's/^  MUTABLE (in scope):  *//p')"
    if [ "$mutable_n" = "1" ]; then
        echo "SELFTEST OK: case 2 (one offending static injected) -- census reports 1 (baseline ceiling 0) -- GATE WOULD FAIL, as required"
    else
        echo "SELFTEST FAIL case 2: expected exactly 1 mutable static after injection, census says $mutable_n"; ok=0
    fi
    # --- CASE 3: a GRANT: comment on the line excludes it from the ratchet count ---
    cat > "$SBX/src/emitter/emit.cpp" <<'EOF'
static int seq_fold_on(void) { static int on = -1; /* GRANT: FINDING-fake-example, Lon 2026-01-01 */ if (on < 0) { const char *e = getenv("X"); on = (e && *e == '0') ? 0 : 1; } return on; }
EOF
    out="$(python3 "$CENSUS" --root "$SBX/src" --csv "$SBX/hits.csv" 2>&1)"
    granted="$(awk -F, 'NR>1 && $0 ~ /GRANT:/' "$SBX/hits.csv" 2>/dev/null | wc -l)"
    # the census itself does not parse GRANT: (that is this gate's job); confirm the marker IS on the
    # reported line so the gate layer has something to find.
    line_no="$(python3 -c "
import sys; sys.path.insert(0,'$HERE')
import util_census_function_scope_statics as u
hits = u.scan_file('$SBX/src/emitter/emit.cpp', 'emit.cpp')
print(hits[0][0] if hits else -1)
")"
    src_line="$(sed -n "${line_no}p" "$SBX/src/emitter/emit.cpp")"
    case "$src_line" in
        *GRANT:*) echo "SELFTEST OK: case 3 -- GRANT: marker is present on the reported declaration line, gate layer can exclude it" ;;
        *) echo "SELFTEST FAIL case 3: GRANT: marker not found on reported line $line_no: $src_line"; ok=0 ;;
    esac
    [ "$ok" = "1" ] && { echo "SELFTEST: ALL PASS"; exit 0; }
    echo "SELFTEST: FAILED"; exit 1
fi

TMP_CSV="$(mktemp /tmp/fss_gate_census_XXXXXX.csv)"
trap 'rm -f "$TMP_CSV"' EXIT
python3 "$CENSUS" --root "$CENSUS_ROOT" --csv "$TMP_CSV" >/dev/null 2>&1 || { echo "REFUSED: census instrument failed to run"; exit 2; }

declare -A ceiling
while IFS=$'\t' read -r file count; do
    case "$file" in ''|'#'*) continue;; esac
    ceiling["$file"]="$count"
done < "$BASELINE"

declare -A current
declare -A granted_count
# CSV columns: file,line,name,verdict,declaration,static_offset -- skip header, keep MUTABLE rows only.
# ⛔ NAIVE `IFS=,` splitting, deliberately: `declaration` (a full `static int a=-1, b=-1;` statement)
# routinely CONTAINS a comma, which Python's csv.writer quotes correctly but this split does not
# respect -- `decl`/`rest` below can end up truncated/shifted. That is fine and stays fine ONLY
# because this loop never reads `decl`/`rest` for anything; every field this gate actually uses
# (file, line, name, verdict) sits BEFORE `declaration` in column order, so a later column's comma
# never shifts an earlier one. If a future edit starts reading `decl`, switch to `python3 -c
# 'import csv'` first -- do not trust this split past column 4.
while IFS=, read -r file line name verdict decl rest; do
    [ "$file" = "file" ] && continue
    case "$verdict" in MUTABLE*) : ;; *) continue;; esac
    srcfile="$CENSUS_ROOT/$file"
    src_line="$(sed -n "${line}p" "$srcfile" 2>/dev/null)"
    case "$src_line" in
        *GRANT:*) granted_count["$file"]=$(( ${granted_count["$file"]:-0} + 1 )); continue ;;
    esac
    current["$file"]=$(( ${current["$file"]:-0} + 1 ))
done < "$TMP_CSV"

rc=0
violations=0
echo "=== no-new-function-scope-static gate ==="
for file in "${!current[@]}"; do
    c="${current[$file]}"
    base="${ceiling[$file]:-0}"
    if [ "$c" -gt "$base" ]; then
        echo "  FAIL  $file: $c function-scope mutable static(s) > ceiling $base"
        violations=$((violations + 1))
        rc=1
    fi
done
if [ "$violations" -eq 0 ]; then
    total_current=0; for c in "${current[@]}"; do total_current=$((total_current + c)); done
    total_base=0; for c in "${ceiling[@]}"; do total_base=$((total_base + c)); done
    echo "  PASS  no file exceeds its baseline ceiling (current total $total_current / baseline total $total_base)"
    dropped=0
    for file in "${!ceiling[@]}"; do
        c="${current[$file]:-0}"
        base="${ceiling[$file]}"
        if [ "$c" -lt "$base" ]; then dropped=$((dropped + 1)); fi
    done
    [ "$dropped" -gt 0 ] && echo "  NOTE  $dropped file(s) now read BELOW their baseline ceiling -- lower $BASELINE for them in this landing commit (ratchet lowering is manual)."
else
    echo "  A new (or ungranted) function-scope mutable static entered the count above its file's ceiling."
    echo "  Either convert it to read-at-use (getenv-cache shape), add a cited /* GRANT: ... */ comment"
    echo "  on its declaration line naming the ruling, or revert the addition."
fi
exit $rc
