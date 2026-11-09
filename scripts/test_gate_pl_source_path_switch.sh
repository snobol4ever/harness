#!/usr/bin/env bash
# test_gate_pl_source_path_switch.sh -- scrip --source-path=PATH names the MAIN source for the Prolog side (CIO-20; row
# scrip-source-path-switch-names-the-file-a-prolog-program-reports-for-its-own-source). The name a program reports for its
# main source (predicate_property file/1, source_file/2) is PATH; the text is still read from the file given; the name is
# baked at lower time, so mode 3 (--run) and mode 4 (--compile, then the binary) agree; a consulted file keeps its own name;
# and nothing else changes: the whole output of a switched run equals the plain run with the path substituted.
# rc 0 green · 1 red (the failing arm named) · 2 could not measure.
set -uo pipefail
GATE_NAME=test_gate_pl_source_path_switch
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP -- this gate measures SCRIP and cannot from here"; exit 2; }; cd "$ROOT"
SCRIP="${SCRIP_BIN:-$ROOT/scrip}"
RT="${RT_DIR:-$ROOT/out}"
[ -x "$SCRIP" ] || { echo "⛔ REFUSE(2) [$GATE_NAME]: no scrip at $SCRIP -- a missing binary prints a plausible all-FAIL board"; exit 2; }
"$HERE/util_require_fresh.sh" --gate "$GATE_NAME" "$SCRIP" "$RT/libscrip_rt.so" || exit 2
[ -f "$RT/libscrip_rt.so" ] || { echo "⛔ REFUSE(2) [$GATE_NAME]: no $RT/libscrip_rt.so -- mode 4 cannot link"; exit 2; }
D=$(mktemp -d) || { echo "⛔ REFUSE(2) [$GATE_NAME]: no tmpdir"; exit 2; }
trap 'rm -rf "$D"' EXIT
PASS=0; FAIL=0; N=0
want() { N=$((N+1)); if [ "$2" = "$3" ]; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); echo "  RED $1"; echo "      got:  [$2]"; echo "      want: [$3]"; fi; }
cat > "$D/p.pl" <<'PLEOF'
foo.
main :- predicate_property(foo, file(F)), write(pred(F)), nl, source_file(foo, S), write(source(S)), nl, ( predicate_property(last(_,_), file(_)) -> write(lib_has_file) ; write(lib_no_file) ), nl.
:- initialization(main).
PLEOF
printf 'hp.\n' > "$D/h.pl"
cat > "$D/m.pl" <<PLEOF
:- consult('$D/h.pl').
main :- predicate_property(hp, file(H)), write(helper(H)), nl, predicate_property(foo, file(F)), write(main(F)), nl.
foo.
:- initialization(main).
PLEOF
m4() { local stem="$1"; shift; timeout -k 5 120 "$SCRIP" --compile --out="$D/$stem.s" "$@" </dev/null >"$D/$stem.cout" 2>&1 || return 1; gcc -m64 -no-pie "$D/$stem.s" -o "$D/$stem.bin" -L"$RT" -lscrip_rt -Wl,-rpath,"$RT" -lm >"$D/$stem.gcc" 2>&1 || return 1; timeout -k 5 60 "$D/$stem.bin" </dev/null 2>&1; }
P3=$(timeout -k 5 60 "$SCRIP" --run "$D/p.pl" </dev/null 2>&1)
S3=$(timeout -k 5 60 "$SCRIP" --run --source-path=/x/y/z.pl "$D/p.pl" </dev/null 2>&1)
C3=$(timeout -k 5 60 "$SCRIP" --run --source-path=/x/y/z.pl "$D/m.pl" </dev/null 2>&1)
P4=$(m4 plain "$D/p.pl") || { echo "⛔ REFUSE(2) [$GATE_NAME]: the plain program did not compile in mode 4 -- see $D/plain.cout (the count does not cover the population)"; exit 2; }
S4=$(m4 sw --source-path=/x/y/z.pl "$D/p.pl") || S4="(mode 4 with the switch did not compile or link)"
EXP_P=$(printf 'pred(%s)\nsource(%s)\nlib_no_file' "$D/p.pl" "$D/p.pl")
EXP_S=$(printf 'pred(%s)\nsource(%s)\nlib_no_file' /x/y/z.pl /x/y/z.pl)
EXP_C=$(printf 'helper(%s)\nmain(/x/y/z.pl)' "$D/h.pl")
want "mode 3, no switch: the name is the path given" "$P3" "$EXP_P"
want "mode 3, --source-path: the main source reports the switch path and nothing else changes" "$S3" "$EXP_S"
want "mode 3, --source-path with a consult: the consulted file keeps its own name" "$C3" "$EXP_C"
want "mode 4, no switch: the name is the path given" "$P4" "$EXP_P"
want "mode 4, --source-path: the baked name is the switch path" "$S4" "$EXP_S"
if [ "$FAIL" = 0 ]; then echo "$GATE_NAME" | tr 'a-z' 'A-Z' | sed 's/$/_BOARD/' | tr -d '\n'; echo " arms=$N red=0 (tree $(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null || echo unknown))"; echo "GATE OK [$GATE_NAME]: $PASS of $N arms green"; exit 0; fi
echo "$GATE_NAME" | tr 'a-z' 'A-Z' | sed 's/$/_BOARD/' | tr -d '\n'; echo " arms=$N red=$FAIL (tree $(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null || echo unknown))"
echo "GATE FAIL [$GATE_NAME]: $FAIL of $N arm(s) red"; exit 1
