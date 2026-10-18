#!/usr/bin/env bash
# util_snobol4_oracle_census.sh -- THE THREE-ORACLE ACCEPTANCE CENSUS OF EVERY STANDALONE SNOBOL4 PROGRAM.
#
# Lon 2026-09-08, in-chat to the cto, verbatim: "So, did you regrade each SNOBOL4 program with CSNOBOL4,
# Snoflake, and SPITBOL to properly mark the database of test suite programs?"  Nobody had.  The 09-07
# one-oracle ruling (RULES.md, sbl -bf) re-cut the refs from SPITBOL and NAMED what SPITBOL refuses; it never
# recorded, per program, what CSNOBOL4 and Snoflake say.  This script does exactly that and nothing else:
# it runs every program through each implementation that is installed and writes ONE row per program.
#
# WHAT A ROW SAYS -- ACCEPTANCE, NOT CORRECTNESS.  Each oracle column is one of
#   OK        the implementation compiled and ran the program to rc=0 (its output is NOT compared to anything)
#   ERR       rc!=0 (a compile refusal, a run-time error, or a program that asks for input it was not given);
#             the note column carries the first error-shaped line so a reader can tell those apart
#   TIMEOUT   rc=124 from `timeout` -- says only that it did not finish in $TIMEOUT s
#   CRASH(n)  killed by signal n
#   NO_ORACLE the implementation is not installed on this box (Snoflake today: nothing under /home/resources)
# A program is IN the SPITBOL baseline when its sbl column reads OK; every other combination is a fact about
# the program's dialect that the suite inventories (UNGRADABLE.tsv / OUTSIDE_SPITBOL_BASELINE.tsv) can cite.
#
# OUTPUT: <package>/ORACLE_ACCEPTANCE.tsv  (name, sbl, csnobol4, snoflake, then one note per oracle), sorted,
# and one ORACLE_ACCEPTANCE summary line per package on stdout.  The TSV is corpus content: commit it.
#
# Usage: bash ../harness/scripts/util_snobol4_oracle_census.sh [package-dir ...]      (default: every SNOBOL4 package
#        under corpus/packages/snobol4 plus the standalone .sno files of corpus/tests/snobol4)
#        SNOFLAKE_BIN=<path> names a Snoflake executable; TIMEOUT (default 10); JOBS (default 8).
S4E="${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CORPUS="$S4E/corpus"
TIMEOUT="${TIMEOUT:-10}"
JOBS="${JOBS:-8}"
SBL="/home/resources/x64/bin/sbl"
CSN="/home/resources/csnobol4/snobol4"
SNOFLAKE="${SNOFLAKE_BIN:-}"
[ -x "$SBL" ] || { echo "⛔ REFUSE(2): the SPITBOL oracle is missing at $SBL (shared install, never a per-root clone)" >&2; exit 2; }
[ -x "$CSN" ] || { echo "⛔ REFUSE(2): the CSNOBOL4 oracle is missing at $CSN (build INTO /home/resources/csnobol4)" >&2; exit 2; }
if [ -n "$SNOFLAKE" ] && [ ! -x "$SNOFLAKE" ]; then echo "⛔ REFUSE(2): SNOFLAKE_BIN=$SNOFLAKE is not executable" >&2; exit 2; fi
export SBL CSN SNOFLAKE TIMEOUT

if [ $# -gt 0 ]; then PKGS="$*"; else
    PKGS="$(ls -d "$CORPUS"/packages/snobol4/*/ 2>/dev/null | sed 's|/$||' | tr '\n' ' ') $CORPUS/tests/snobol4"
fi

# one program, one oracle -> "<verdict>\t<note>"   (cwd = the program's own directory, stdin = NAME.in if shipped)
census_one() {
    local bin="$1" flags="$2" prog="$3" dir name inp out rc v note
    dir="$(dirname "$prog")"; name="$(basename "$prog")"
    inp=/dev/null; [ -f "$dir/${name%.*}.in" ] && inp="$dir/${name%.*}.in"
    out="$(cd "$dir" && timeout -k 5 "$TIMEOUT" "$bin" $flags "$name" < "$inp" 2>&1 | tr -d '\000'; exit "${PIPESTATUS[0]}")"; rc=$?
    if [ $rc -eq 0 ]; then v=OK; note=""
    elif [ $rc -eq 124 ]; then v=TIMEOUT; note=""
    elif [ $rc -gt 128 ] && [ $rc -le 160 ]; then v="CRASH($((rc-128)))"; note=""
    else v=ERR; note="$(printf '%s\n' "$out" | grep -m1 -iE 'error|fail|not found|cannot|no end|undefined' | tr '\t' ' ' | cut -c1-110)"
         [ -n "$note" ] || note="$(printf '%s\n' "$out" | grep -m1 -v '^[[:space:]]*$' | tr '\t' ' ' | cut -c1-110)"
         note="rc=$rc $note"
    fi
    printf '%s\t%s' "$v" "$note"
}
census_row() {
    local prog="$1" r_sbl r_csn r_snf
    r_sbl="$(census_one "$SBL" "-bf" "$prog")"
    r_csn="$(census_one "$CSN" "-b" "$prog")"
    if [ -n "$SNOFLAKE" ]; then r_snf="$(census_one "$SNOFLAKE" "" "$prog")"; else r_snf=$'NO_ORACLE\t'; fi
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$(basename "$prog")" "${r_sbl%%$'\t'*}" "${r_csn%%$'\t'*}" "${r_snf%%$'\t'*}" "${r_sbl#*$'\t'}" "${r_csn#*$'\t'}" "${r_snf#*$'\t'}"
}
export -f census_one census_row

SCRATCH="$(mktemp -d "${TMPDIR:-/tmp}/sno_census.XXXXXX")" || { echo "⛔ REFUSE(2): mktemp failed" >&2; exit 2; }
trap 'rm -rf "$SCRATCH"' EXIT
for pkg in $PKGS; do
    [ -d "$pkg" ] || { echo "⛔ REFUSE(2): no such package dir $pkg" >&2; exit 2; }
    tsv="$pkg/ORACLE_ACCEPTANCE.tsv"; tmp="$(mktemp)"
    # ⛔ NEVER RUN IN THE CORPUS TREE: the first run (2026-09-08) left spitlib.idx, openo.tst, test.bin, ASMTEMP and two
    # "(121A1)" files behind -- programs write beside themselves. Each package is copied whole into scratch (so -INCLUDE
    # siblings and .in files still resolve) and every program runs in the copy; the copy dies with the trap.
    # The copy keeps the package's corpus-relative path, with the trees a -INCLUDE reaches ('../../benchmarks/snobol4/
    # harness.inc', library/, include/) beside it -- the rungs' probes resolved in the tree and not in a flat copy.
    rel="${pkg#$CORPUS/}"; run="$SCRATCH/$rel"; rm -rf "$run"; mkdir -p "$(dirname "$run")"; cp -r "$pkg" "$run"; rm -f "$run/ORACLE_ACCEPTANCE.tsv"
    # ⛔ A PACKAGE WHOSE RUNNER STAGES ITS INCLUDES INTO THE PROGRAM'S CWD DECLARES THE DIRECTORY IN INCLUDE_STAGING.tsv (dir<TAB>why), and the census
    # stages it the same way (the coo 2026-10-18, ceo's ruling): SPITBOL's -INCLUDE search is cwd-relative, and snoflake's 51 gimpel-* programs read
    # ERR "include file cannot be opened" here while test_snoflake_suite.sh, which copies gimpel/*.INC and *.IN beside them, gets their answers.
    if [ -f "$pkg/INCLUDE_STAGING.tsv" ]; then
        while IFS=$'\t' read -r sd _why; do
            case "$sd" in ''|'#'*) continue;; esac
            [ -d "$run/$sd" ] || { echo "⛔ REFUSE(2): $pkg/INCLUDE_STAGING.tsv names $sd, which is not a directory of the package" >&2; exit 2; }
            cp -pn "$run/$sd"/*.INC "$run/$sd"/*.IN "$run"/ 2>/dev/null || true
        done < "$pkg/INCLUDE_STAGING.tsv"
    fi
    for side in benchmarks/snobol4 library include; do
        [ -d "$CORPUS/$side" ] && [ ! -e "$SCRATCH/$side" ] && { mkdir -p "$SCRATCH/$(dirname "$side")"; cp -r "$CORPUS/$side" "$SCRATCH/$side"; }
    done
    # standalone programs only: *.sno / *.spt / *.SPT at depth 1; ALL.* is our own generated container, never a program
    find "$run" -maxdepth 1 -type f \( -name '*.sno' -o -name '*.spt' -o -name '*.SPT' \) ! -name 'ALL.*' | sort \
        | xargs -P "$JOBS" -I{} bash -c 'census_row "$1"' _ {} > "$tmp"
    n=$(grep -c '' "$tmp"); [ "$n" -gt 0 ] || { rm -f "$tmp"; echo "ORACLE_ACCEPTANCE package=$(basename "$pkg") n=0 (no standalone programs)"; continue; }
    { printf 'name\tsbl\tcsnobol4\tsnoflake\tsbl_note\tcsnobol4_note\tsnoflake_note\n'; sort "$tmp"; } > "$tsv"; rm -f "$tmp"
    awk -F'\t' -v p="$(basename "$pkg")" -v n="$n" 'NR>1 { s=($2=="OK"); c=($3=="OK"); f=($4=="OK"); so+=s; co+=c; fo+=f; if(s&&c)b++; else if(s)sx++; else if(c)cx++; else nn++; if($4=="NO_ORACLE")no++ }
        END { printf "ORACLE_ACCEPTANCE package=%s n=%d sbl_ok=%d csnobol4_ok=%d both=%d sbl_only=%d csnobol4_only=%d neither=%d snoflake=%s\n", p, n, so, co, b, sx, cx, nn, (no==n ? "NO_ORACLE" : fo"_ok") }' "$tsv"
done
