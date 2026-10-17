#!/usr/bin/env bash
# ../harness/scripts/test_icon_x64_all_rungs.sh — Icon rung ladder runner under scrip --compile (MODE 4).
# Self-contained. Run from anywhere with no env vars.
# Usage: bash ../harness/scripts/test_icon_x64_all_rungs.sh [--rung RUNG] [--scrip PATH] [--corpus PATH] [CORPUS_DIR]
#
# THE M4 TWIN OF test_icon_all_rungs.sh (Z-0(a), s230). Same corpus selection, same .ref /
# .stdin / .xfail law, SAME 293 DENOMINATOR — the only difference is the pipeline: --compile emits
# standalone x86-64 asm, gcc -no-pie links it against out/libscrip_rt.so, and the binary runs with
# cwd = the corpus dir (so relative data-file reads resolve exactly as they do under --run).
#
# REPLACES the deleted-era runner (s230 forensics: it shelled a `-icn` flag, assembled with nasm and
# invoked /home/scrip — none of which have existed for many sessions; its 0/293 measured the harness,
# not the compiler, while smoke m4 was 12/14 the whole time).
#
# CRASH-AWARE CLEAN/DIRTY GRADING (stricter than the m3 runner by design): PASS requires BOTH a
# byte-equal stdout AND a clean exit. A program whose stdout matches but which dies on a signal or
# hits the timeout is graded DIRTY-PASS and counted FAIL, because a latent SEGV after the last
# write() is exactly the defect class the m3 stdout-only comparison hides. The dirt breakdown line
# (EMIT/LINK/CRASH/TIMEOUT/OUTPUT/DIRTYPASS) is the discriminator for m3-vs-m4 deltas.
#
# SUITE-FORMAT DELEGATION (tests-consolidate-icon, 2026-08-28): a family converted by
# corpus_suite_harness.py loses its loose rungNN_*.icn files and becomes one <family>.icn+.ref
# pair (discriminator: a .ref sibling AND section banners in the source). run_one()'s own `[ -f "$exp" ]
# || return 0` guard means a suite file landing here would just vanish from the board silently
# (no FAIL, but no PASS either -- the family's coverage disappears with no error printed). Converted
# families are routed into SUITE_FILES instead and folded into PASS/FAIL via
# `corpus_suite_harness.py run --modes m4` (this runner is compile/m4-only throughout).
#
# Authors: LCherryholmes · Claude Sonnet 4.6 · Claude Fable 5 · Claude Sonnet 5
S4E="${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"   # D-17 PORTABLE-HOME: the sibling root (all repos + oracles are siblings under ONE root; /home/claude2-style seat roots work with zero env; S4E_HOME overrides)

set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/lib_icn_rundir.sh" || { echo "⛔ REFUSES rc=2: cannot load lib_icn_rundir.sh -- THE ONE run-directory contract reader" >&2; exit 2; }
SCRIP="${SCRIP:-$HERE/../../SCRIP/scrip}"
RT_DIR="$(cd "$HERE/../../SCRIP" && pwd)/out"
RT_SO="$RT_DIR/libscrip_rt.so"
CORPUS="${CORPUS:-$S4E/corpus/tests/icon}"
RUNG=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --rung)   RUNG="$2";   shift 2 ;;
        --scrip)  SCRIP="$2";  shift 2 ;;
        --corpus) CORPUS="$2"; shift 2 ;;
        -*) echo "Usage: $0 [--rung RUNG] [--scrip PATH] [--corpus PATH] [CORPUS_DIR]" >&2; exit 1 ;;
        *)  CORPUS="$1"; shift ;;
    esac
done

# ⛔ A RUNNER THAT CANNOT MEASURE REFUSES rc=2 -- these three exited 0 as "SKIP", which a caller reads as a green board
if [ ! -x "$SCRIP" ]; then
    echo "⛔ REFUSES rc=2: scrip binary not found at $SCRIP -- nothing was examined" >&2
    exit 2
fi
if [ ! -f "$RT_SO" ]; then
    echo "⛔ REFUSES rc=2: libscrip_rt.so not found at $RT_SO (run: make) -- nothing was examined" >&2
    exit 2
fi
if [ ! -d "$CORPUS" ]; then
    echo "⛔ REFUSES rc=2: corpus not found at $CORPUS -- nothing was examined" >&2
    exit 2
fi

PASS=0; FAIL=0; XFAIL=0; MISSING=0; INVALID=0
D_EMIT=0; D_LINK=0; D_CRASH=0; D_TIMEOUT=0; D_OUTPUT=0; D_DIRTYPASS=0
declare -a SUITE_FILES=()
# converted-family discriminator (see header note): a .ref sibling AND corpus_suite_harness.py's section banners
# (`#---- <seq> <name>`) in the source. The sibling alone decided while loose programs carried a .expected; since
# CEO-1222 every loose expected output is a .ref as well, so the source's own shape is what tells a container.
is_suite_file() { [ -f "${1%.icn}.ref" ] && grep -qE '^#-{3,} [0-9]+ [^[:space:]]' "$1"; }

WORK="$(mktemp -d /tmp/icon_m4_rungs.XXXXXX)"
trap 'rm -rf "$WORK"' EXIT

# rung36 per-category tally (sidecar map at corpus/rung36_categories.txt)
declare -A R36_CAT_P R36_CAT_F R36_CAT_X
R36_MAP_FILE="$CORPUS/rung36_categories.txt"
declare -A R36_NAME_TO_CAT
if [ -f "$R36_MAP_FILE" ]; then
    while IFS=$'\t' read -r r36_name r36_cat; do
        case "$r36_name" in ''|'#'*) continue ;; esac
        R36_NAME_TO_CAT["$r36_name"]="$r36_cat"
        R36_CAT_P["$r36_cat"]=${R36_CAT_P["$r36_cat"]:-0}
        R36_CAT_F["$r36_cat"]=${R36_CAT_F["$r36_cat"]:-0}
        R36_CAT_X["$r36_cat"]=${R36_CAT_X["$r36_cat"]:-0}
    done < "$R36_MAP_FILE"
fi

r36_tally() {
    local name="$1" status="$2"
    case "$name" in
        rung36_jcon_*)
            local stem="${name#rung36_jcon_}"
            local cat="${R36_NAME_TO_CAT[$stem]:-uncategorized}"
            case "$status" in
                PASS)  R36_CAT_P["$cat"]=$((${R36_CAT_P["$cat"]:-0}+1)) ;;
                FAIL)  R36_CAT_F["$cat"]=$((${R36_CAT_F["$cat"]:-0}+1)) ;;
                XFAIL) R36_CAT_X["$cat"]=$((${R36_CAT_X["$cat"]:-0}+1)) ;;
            esac
            ;;
    esac
}

fail_one() {
    local name="$1" why="$2"
    echo "FAIL $name  [$why]"
    FAIL=$((FAIL+1))
    r36_tally "$name" FAIL
}

run_one() {
    local icn="$1"
    local tmo="${2:-8}"
    local exp="${icn%.icn}.ref"
    local base="${icn%.icn}"
    local name
    name=$(basename "$icn" .icn)
    # the m3 twin's MISSING/INVALID law: a pairless file icont refuses is not a board member, one it compiles owes a ref
    if [ ! -f "$exp" ]; then
        if icn_oracle_refuses "$icn"; then echo "INVALID $name (no .ref, and icont refuses the source: not a board member)"; INVALID=$((INVALID+1)); return 0; fi
        echo "MISSING $name (no .ref oracle)"; MISSING=$((MISSING+1)); return 0
    fi
    if [ -f "${base}.xfail" ]; then
        echo "XFAIL $name"
        XFAIL=$((XFAIL+1))
        r36_tally "$name" XFAIL
        return 0
    fi
    # ⛔ THE RUN-DIRECTORY CONTRACT, THE M3 TWIN'S OWN (lib_icn_rundir.sh): stdin from NAME.stdin or config/NAME.stdin, argv,
    # fixtures and env as declared, run from a scratch cwd. This twin read only NAME.stdin beside the source, so every tests/icon
    # stdin witness (all of them live in config/) ran starved -- seven loose rung36 programs red in m4 and green in m3 on one
    # binary -- and it ran from the corpus directory, so what a program wrote landed in the source tree.
    local stdin_file; stdin_file="$(icn_rundir_stdin "$icn")"
    local -a rd_argv=() rd_env=(); local rd_rc
    # ⭐ THE DECLARED HEAP AND STACK (CEO-1353): icn_rundir_sizes fills rd_sw with -d<kb>k -s<kb>k for the binary's head, before a --.
    local -a rd_sw=(); rd_rc=0; if icn_rundir_sizes "$icn" rd_sw; then :; else rd_rc=$?; fi
    if [ "$rd_rc" -eq 2 ]; then echo "⛔ REFUSE(2) $name: malformed NAME.heap or NAME.stack declaration (the reader said why above)" >&2; exit 2; fi
    if [ "$rd_rc" -eq 1 ]; then echo "    $name: declares no heap and stack beside it -- runs at the shipped default, NAMED (CEO-1353)" >&2; fi
    local sdir tdir="$WORK/cwd"; sdir=$(dirname "$icn"); mkdir -p "$tdir"
    if icn_rundir_declares "$icn"; then
        rd_rc=0; icn_rundir_argv "$icn" rd_argv || rd_rc=$?
        if [ "$rd_rc" -eq 2 ]; then echo "⛔ REFUSE(2) $name: malformed argv declaration" >&2; exit 2; fi
        rd_rc=0; icn_rundir_env "$icn" rd_env || rd_rc=$?
        if [ "$rd_rc" -eq 2 ]; then echo "⛔ REFUSE(2) $name: malformed env declaration" >&2; exit 2; fi
        tdir="$(icn_rundir_make "$icn" "$WORK")" || { echo "⛔ REFUSE(2) $name: could not stage the declared fixtures" >&2; exit 2; }
    fi
    local asm="$WORK/$name.s" bin="$WORK/bin/$name"; mkdir -p "$WORK/bin"
    if ! (cd "$sdir" && timeout -k 5 "$tmo" "$SCRIP" --compile "$(basename "$icn")" < /dev/null) > "$asm" 2>"$WORK/$name.emit_err" || [ ! -s "$asm" ]; then
        D_EMIT=$((D_EMIT+1)); fail_one "$name" "emit"; return 0
    fi
    if ! timeout -k 5 30 gcc -no-pie "$asm" -L"$RT_DIR" -lscrip_rt -Wl,-rpath,"$RT_DIR" -o "$bin" 2>"$WORK/$name.link_err"; then
        D_LINK=$((D_LINK+1)); fail_one "$name" "link"; return 0
    fi
    local got rc
    # the binary runs under its BARE STEM found on PATH (CEO-624: &progname is the stem in both modes), argv after it
    got=$( (cd "$tdir" && PATH="$WORK/bin:$PATH" timeout -k 5 "$tmo" env ${rd_env[@]+"${rd_env[@]}"} "$name" ${rd_sw[@]+"${rd_sw[@]}"} ${rd_sw[@]+--} ${rd_argv[@]+"${rd_argv[@]}"}) < "$stdin_file" 2>/dev/null); rc=$?
    local want
    want=$(cat "$exp")
    local dirty="" 
    if [ "$rc" -eq 124 ]; then dirty="timeout"; elif [ "$rc" -ge 128 ]; then dirty="crash rc=$rc"; fi
    if [ "$got" = "$want" ] && [ -z "$dirty" ]; then
        echo "PASS $name"
        PASS=$((PASS+1))
        r36_tally "$name" PASS
    elif [ "$got" = "$want" ]; then
        D_DIRTYPASS=$((D_DIRTYPASS+1))
        case "$dirty" in timeout) D_TIMEOUT=$((D_TIMEOUT+1)) ;; *) D_CRASH=$((D_CRASH+1)) ;; esac
        fail_one "$name" "DIRTY-PASS $dirty (stdout byte-equal, unclean exit)"
    else
        if [ -n "$dirty" ]; then
            case "$dirty" in timeout) D_TIMEOUT=$((D_TIMEOUT+1)) ;; *) D_CRASH=$((D_CRASH+1)) ;; esac
            fail_one "$name" "$dirty"
        else
            D_OUTPUT=$((D_OUTPUT+1)); fail_one "$name" "output"
        fi
        echo "  want: $(echo "$want" | tr '\n' '|')"
        echo "  got:  $(echo "$got"  | tr '\n' '|')"
    fi
}

if [ -n "$RUNG" ]; then
    for icn in "$CORPUS"/${RUNG}_*.icn "$CORPUS"/${RUNG}.icn; do
        [ -f "$icn" ] || continue
        if is_suite_file "$icn"; then SUITE_FILES+=("$icn"); continue; fi
        run_one "$icn"
    done
else
    for icn in "$CORPUS"/rung0[1-9]_*.icn \
               "$CORPUS"/rung1[0-9]_*.icn \
               "$CORPUS"/rung2[0-9]_*.icn \
               "$CORPUS"/rung3[0-5]_*.icn; do
        [ -f "$icn" ] || continue
        if is_suite_file "$icn"; then SUITE_FILES+=("$icn"); continue; fi
        run_one "$icn" 8
    done
    for icn in "$CORPUS"/rung36_*.icn; do
        [ -f "$icn" ] || continue
        if is_suite_file "$icn"; then SUITE_FILES+=("$icn"); continue; fi
        run_one "$icn" 8
    done
    for icn in "$CORPUS"/rung37_*.icn; do
        [ -f "$icn" ] || continue
        if is_suite_file "$icn"; then SUITE_FILES+=("$icn"); continue; fi
        run_one "$icn" 8
    done
fi

# suite-format families (see header note): fold each converted family's m4 board into the same
# PASS/FAIL totals a loose-file run_one would have contributed.
for icn in "${SUITE_FILES[@]}"; do
    sfname=$(basename "$icn" .icn)
    board=$(python3 "$HERE/corpus_suite_harness.py" run "$icn" "${icn%.icn}.ref" --lang icon --modes m4 2>&1 | grep '^SUITE_BOARD')
    spass=$(echo "$board" | grep -oP 'm4_pass=\K[0-9]+')
    if [ -z "$spass" ]; then
        echo "SUITE-RUN-ERROR $sfname (harness produced no SUITE_BOARD line)"
        FAIL=$((FAIL+1))
        continue
    fi
    sfail=$(echo "$board" | grep -oP 'm4_fail=\K[0-9]+')
    scrash=$(echo "$board" | grep -oP 'm4_crash=\K[0-9]+')
    shang=$(echo "$board" | grep -oP 'm4_hang=\K[0-9]+')
    sunproven=$(echo "$board" | grep -oP 'm4_unproven=\K[0-9]+')
    sxfail=$(echo "$board" | grep -oP 'm4_xfail=\K[0-9]+')
    sxpass=$(echo "$board" | grep -oP 'm4_xpass=\K[0-9]+')
    # XPASS (a witness marked XFAIL that actually passed -- stale marker) is surfaced as loudly as
    # FAIL, same rationale as the harness's own docstring: exactly as actionable, opposite sign.
    sbad=$((sfail+scrash+shang+sunproven+sxpass))
    echo "SUITE $sfname: pass=$spass xfail=$sxfail bad=$sbad"
    PASS=$((PASS+spass)); FAIL=$((FAIL+sbad)); XFAIL=$((XFAIL+sxfail))
done

echo "--- rung36 by category ---"
{
    for cat in "${!R36_CAT_P[@]}" "${!R36_CAT_F[@]}" "${!R36_CAT_X[@]}"; do echo "$cat"; done
} | sort -u | while read -r cat; do
    [ -z "$cat" ] && continue
    p=${R36_CAT_P[$cat]:-0}
    f=${R36_CAT_F[$cat]:-0}
    x=${R36_CAT_X[$cat]:-0}
    total=$((p+f+x))
    printf "  rung36_%-12s  total=%2d  PASS=%2d  FAIL=%2d  XFAIL=%2d\n" "$cat" "$total" "$p" "$f" "$x"
done

echo "--- m4 dirt: EMIT=$D_EMIT LINK=$D_LINK CRASH=$D_CRASH TIMEOUT=$D_TIMEOUT OUTPUT=$D_OUTPUT DIRTYPASS=$D_DIRTYPASS ---"
echo "--- Icon --compile: PASS=$PASS FAIL=$FAIL XFAIL=$XFAIL MISSING=$MISSING INVALID=$INVALID TOTAL=$((PASS+FAIL+XFAIL)) ---"
[ "$FAIL" -eq 0 ] && [ "$MISSING" -eq 0 ]
