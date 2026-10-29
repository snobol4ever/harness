#!/usr/bin/env bash
# test_gate_sno_io_assoc_channel_and_filespec.sh -- INPUT/OUTPUT's association form must validate the
# (channel, filespec) pair like SPITBOL, not silently create a stray file or accept a null channel
# (row snobol4-output-third-argument-is-a-format-not-a-file-name, hq_P 2026-09-05).
#
# TWO INDEPENDENT DEFECTS, ONE CURE. Measured LIVE against /home/resources/x64/bin/sbl -bf, 2026-09-05:
#   (1) a non-integer/empty channel with a filename argument present (testpgms test4/test5's shape,
#       `INPUT(.INPUT,,72)`) raises ERROR 116 regardless of the filename's own validity.
#   (2) a valid channel whose filename argument contains a raw space (testpgms test8's FORTRAN-format-
#       as-filename shape, `OUTPUT('TITLE',6,'(14H1THIS IS HAND ,110A1)')`; also snoflake_suite's
#       output-format-ignored.sno, whose own @expect was never checked against the oracle and is wrong)
#       raises ERROR 160/116 too, independent of (1).
# SCRIP raises exactly as SPITBOL does (the one oracle, Lon 2026-09-07; the --compat dialect switch is retired):
# each error face is live-diffed against the oracle, and regression faces protect the corpus's 8 real
# bracketed-options-only sites
# (`INPUT(.INPUT, 9, '[-f0 -r...]')`) which must NEVER be touched by this cure.
#
# EXIT: 0 every face passes · 1 a face is red · 2 REFUSED (unbuilt/stale tree, oracle unreachable)
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
S="$ROOT/scrip"; RT="$ROOT/out/libscrip_rt.so"
[ -x "$S" ] || { echo "⛔ GATE REFUSES: no $S -- make first. A missing binary proves NOTHING about this defect."; exit 2; }
if ! . "$HERE/lib_gate.sh" 2>/dev/null || ! command -v gate_require_fresh >/dev/null 2>&1; then
    echo "⛔ GATE REFUSES: lib_gate.sh unavailable or missing gate_require_fresh -- cannot verify binary freshness" >&2; exit 2
fi
GATE_NAME=sno_io_assoc gate_require_fresh "$ROOT" src "$S" "$RT"
. "$HERE/lib_oracle_flags.sh" 2>/dev/null || { echo "⛔ GATE REFUSES: cannot load lib_oracle_flags.sh -- the ONE oracle-flag authority"; exit 2; }
SBL="$(sbl_correctness_bin)" || exit 2
FLAGS="$(sbl_lang_flags)"
W="$(mktemp -d)" || { echo "⛔ GATE REFUSES: mktemp failed"; exit 2; }
trap 'rm -rf "$W"' EXIT
rc=0
mk() { printf '%b' "$2" > "$W/$1.sno"; }
snapshot() { (cd "$W" && ls -1 | sort); }

# ── faces that must hit a specific ERROR under SPITBOL default, matching the LIVE oracle, and must
#    leave the scratch dir untouched (no stray file, the original bug report's own symptom) ──
oracle_error_face() {
    local name="$1" errno="$2" before after new_files want got
    before="$(snapshot)"
    want="$(cd "$W" && timeout -k 5 10 "$SBL" $FLAGS "$name.sno" </dev/null 2>/dev/null | grep -m1 -E "ERROR [0-9]+ --")"
    got="$(cd "$W" && timeout -k 5 10 "$S" "$name.sno" </dev/null 2>&1)"
    after="$(snapshot)"; new_files="$(comm -13 <(printf '%s\n' "$before") <(printf '%s\n' "$after") | grep -v "^$name\.")"
    case "$want" in
        *"ERROR $errno "*) : ;;
        *) echo "  FAIL $name (witness stale: oracle did not hit ERROR $errno -- oracle said: ${want:-<nothing>})"; rc=1; return ;;
    esac
    case "$got" in
        *"ERROR $errno "*|*"error $((10#$errno)):"*) echo "  PASS $name  spitbol-default matches oracle ($want)" ;;
        *) echo "  FAIL $name  spitbol-default: got [$got] want ERROR $errno (oracle: $want)"; rc=1 ;;
    esac
    if [ -n "$new_files" ]; then echo "  FAIL $name  left stray file(s) in cwd: $new_files"; rc=1; fi
}

# ── m4 (--compile) must agree with m3 -- BOTH-MEDIUM MANDATORY ──
m4_error_face() {
    local name="$1" errno="$2" got
    ( cd "$W" && timeout -k 5 10 "$S" --compile --out="$name.s" "$name.sno" </dev/null >/dev/null 2>&1
      gcc -no-pie "$name.s" -L"$ROOT/out" -lscrip_rt -Wl,-rpath,"$ROOT/out" -o "$name.bin" 2>/dev/null )
    got="$(cd "$W" && timeout -k 5 10 "./$name.bin" </dev/null 2>&1)"
    case "$got" in
        *"ERROR $errno "*|*"error $((10#$errno)):"*) echo "  PASS $name  m4 matches m3 (ERROR $errno)" ;;
        *) echo "  FAIL $name  m4: got [$got] want ERROR $errno"; rc=1 ;;
    esac
}

# ── regression controls: legitimate/pre-existing shapes this row must NOT touch ──
regress_face() {
    local name="$1" want="$2" gotS
    gotS="$(cd "$W" && timeout -k 5 10 "$S" "$name.sno" </dev/null 2>&1)"
    if [ "$gotS" = "$want" ]; then
        echo "  PASS $name  unaffected ($want)"
    else
        echo "  FAIL $name  got=[$gotS] want=[$want]"; rc=1
    fi
}

mk empty_channel_input      "\tINPUT(.X,,'nonexistent_xyz_1.tmp')\t\t:F(ERR)\n\tOUTPUT = 'ok-assoc'\t\t:(END)\nERR\tOUTPUT = 'ok-soft-fail'\nEND\n"
mk space_filename_output    "\tOUTPUT('X',6,'has a space 1.tmp')\t\t:F(ERR)\n\tOUTPUT = 'ok-assoc'\t\t:(END)\nERR\tOUTPUT = 'FAIL'\nEND\n"
mk valid_plain_output       "\tOUTPUT('W',7,'io_assoc_gate_plain.tmp')\t\t:F(ERR)\n\tW = 'roundtrip-ok'\n\tOUTPUT = 'ok-write'\t\t:(END)\nERR\tOUTPUT = 'FAIL'\nEND\n"
mk empty_channel_empty_slot "\tINPUT(.X,,)\t\t:F(ERR)\n\tOUTPUT = 'ok-degenerate'\t\t:(END)\nERR\tOUTPUT = 'FAIL'\nEND\n"
mk bracketed_options_only   "\tINPUT(.INPUT, 9, '[-f0 -r4194304]')\t\t:F(ERR)\n\tOUTPUT = 'ok-options-only'\t\t:(END)\nERR\tOUTPUT = 'FAIL'\nEND\n"

echo "SNOBOL4 INPUT/OUTPUT association: channel + file-spec validity (SPITBOL, the one oracle):"
oracle_error_face empty_channel_input   116
oracle_error_face space_filename_output 160
m4_error_face      empty_channel_input   116
m4_error_face      space_filename_output 160
regress_face valid_plain_output       "ok-write"
regress_face empty_channel_empty_slot "ok-degenerate"
regress_face bracketed_options_only   "ok-options-only"
if [ "$(cat "$W/io_assoc_gate_plain.tmp" 2>/dev/null)" = "roundtrip-ok" ]; then
    echo "  PASS valid_plain_output  file content correct (channel association truly wrote through)"
else
    echo "  FAIL valid_plain_output  file content wrong: $(cat "$W/io_assoc_gate_plain.tmp" 2>/dev/null)"; rc=1
fi
rm -f "$W"/*.tmp "$W"/io_assoc_gate_plain.tmp 2>/dev/null

[ "$rc" = 0 ] && echo "GATE OK" || echo "GATE RED"
exit "$rc"
