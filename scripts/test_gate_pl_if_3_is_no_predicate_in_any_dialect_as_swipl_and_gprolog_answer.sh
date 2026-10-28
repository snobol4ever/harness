#!/usr/bin/env bash
# test_gate_pl_if_3_is_no_predicate_in_any_dialect_as_swipl_and_gprolog_answer.sh -- if/3 IS NOT A PREDICATE OF THE LANGUAGE (cto CEO-1888/1996, ARCH-PROLOG-DATABASE.md 4c addendum).
# swipl 9.0.4, swipl 10.1.5 and the gprolog oracle (gprolog_bin) all answer a call of if(C,T,E) with existence_error(procedure, if/3), as a body goal and through call/1, and
# predicate_property(if(_,_,_), _) has no answer in any of them. SCRIP defined it as a soft cut in every dialect but the SWI one (added by abd2fb800 for a
# Logtalk unit that runs only where predicate_property(if(_,_,_), built_in) holds, which neither oracle satisfies); the three sites are deleted, so SCRIP
# ships no control construct its dialect's oracle lacks. A program that defines its OWN if/3 keeps it (arm own). The expected text below is cut from the
# oracles and RE-CHECKED against live swipl and gprolog on every run: an oracle that cannot answer REFUSES rc 2, an oracle that disagrees reds the gate.
# RED BEFORE: on c33d10f89 the plain program ran if/3 as a soft cut in the default dialect and printed called, called, no_property in m3 and m4 (2 arms red).
# The retired witness test_gate_pl_iso_rung6_the_soft_cut_if_3_predicate.sh asserted the opposite baseline (CEO-1996 ruling).
set -u
GATE_NAME=test_gate_pl_if_3_is_no_predicate_in_any_dialect_as_swipl_and_gprolog_answer
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${S4E_HOME:-$(cd "$HERE/../.." && pwd)}"
SCRIP="$HERE/../../SCRIP/scrip"
RT="${RT_DIR:-$HERE/../../SCRIP/out}"
SWIPL=/usr/bin/swipl
refuse() { echo "⛔ REFUSED(2) [$GATE_NAME]: $*" >&2; exit 2; }
. "$HERE/lib_oracle_flags.sh" || refuse "lib_oracle_flags.sh is missing"
GPROLOG="$(gprolog_bin)" || refuse "the gprolog oracle accessor refused"
[ -x "$SCRIP" ] || refuse "no scrip binary at $SCRIP -- run make first"
[ -x "$SWIPL" ] || refuse "no swipl oracle at $SWIPL"
[ -x "$GPROLOG" ] || refuse "no gprolog oracle at $GPROLOG"
"$HERE/util_require_fresh.sh" --gate "$GATE_NAME" "$SCRIP" "$RT/libscrip_rt.so" || exit 2
MODES="${PL_RUNG_MODES:-m3,m4}"
TMPD="$(mktemp -d)"; trap 'rm -rf "$TMPD"' EXIT
red=0; total=0
run_m3() { timeout -k 5 20 "$SCRIP" "$1" </dev/null 2>"$TMPD/err"; }
run_m4() {
    local src="$1" s="$TMPD/w.s" b="$TMPD/w.bin"
    timeout -k 5 60 "$SCRIP" --compile -o "$s" "$src" </dev/null 2>"$TMPD/err" || { echo "  (m4: compile failed: $(head -c 160 "$TMPD/err"))"; return 97; }
    gcc -m64 -no-pie "$s" -o "$b" -L"$RT" -lscrip_rt -Wl,-rpath,"$RT" -lm 2>"$TMPD/err" || { echo "  (m4: link failed: $(head -c 160 "$TMPD/err"))"; return 98; }
    timeout -k 5 20 "$b" </dev/null 2>"$TMPD/err"
}
run_swipl() { timeout -k 5 30 "$SWIPL" -q "$1" </dev/null 2>/dev/null; }
run_gprolog() { timeout -k 5 30 "$GPROLOG" --consult-file "$1" --query-goal halt </dev/null 2>/dev/null | grep -v -e '^compiling ' -e 'compiled, ' -e '^$' -e 'GNU Prolog' -e 'Copyright' -e '^Compiled ' -e '^By Daniel' -e 'Prolog top-Level' -e '^| ?-'; }
arm() {
    local name="$1" src="$2" want_out="$3" mode got
    for mode in m3 m4; do
        case "$MODES" in *"$mode"*) : ;; *) continue ;; esac
        total=$((total+1))
        got="$("run_$mode" "$src")"; rc=$?
        if [ "$got" = "$want_out" ]; then echo "  ok  $name $mode"
        else echo "  RED $name $mode: out=[$got] want [$want_out] $(head -c 200 "$TMPD/err" 2>/dev/null)"; red=$((red+1)); fi
    done
}
oracle() {
    local name="$1" src="$2" want_out="$3" o got
    for o in swipl gprolog; do
        total=$((total+1))
        got="$("run_$o" "$src")"
        if [ "$got" = "$want_out" ]; then echo "  ok  $name oracle $o"
        else echo "  RED $name oracle $o disagrees with the expected text: out=[$got] want [$want_out]"; red=$((red+1)); fi
    done
}
cat > "$TMPD/plain.pl" <<'EOP'
:- initialization(main).
main :-
    catch(( if(true, true, true), write(called) ), error(E1, _), write(raised(E1))), nl,
    G = if(fail, true, true),
    catch(( call(G), write(called) ), error(E2, _), write(raised(E2))), nl,
    ( predicate_property(if(_, _, _), _) -> write(has_property) ; write(no_property) ), nl,
    halt.
EOP
{ printf ':- use_module(library(lists)).\n'; cat "$TMPD/plain.pl"; } > "$TMPD/swi.pl"
cat > "$TMPD/own.pl" <<'EOP'
:- initialization(main).
if(a, b, c).
main :-
    ( if(a, b, c) -> write(ok(u)) ; write(bad(u)) ), nl,
    ( if(x, y, z) -> write(bad(v)) ; write(ok(v)) ), nl,
    G = if(a, b, c), ( call(G) -> write(ok(w)) ; write(bad(w)) ), nl,
    halt.
EOP
WANT_PLAIN="$(printf '%s\n' 'raised(existence_error(procedure,if/3))' 'raised(existence_error(procedure,if/3))' 'no_property')"
WANT_OWN="$(printf '%s\n' 'ok(u)' 'ok(v)' 'ok(w)')"
oracle plain "$TMPD/plain.pl" "$WANT_PLAIN"
oracle own "$TMPD/own.pl" "$WANT_OWN"
total=$((total+1)); got="$(run_swipl "$TMPD/swi.pl")"
if [ "$got" = "$WANT_PLAIN" ]; then echo "  ok  swi oracle swipl"; else echo "  RED swi oracle swipl disagrees: out=[$got]"; red=$((red+1)); fi
arm if_3_is_an_existence_error_in_the_default_dialect "$TMPD/plain.pl" "$WANT_PLAIN"
arm if_3_is_an_existence_error_in_the_swi_dialect "$TMPD/swi.pl" "$WANT_PLAIN"
arm a_program_that_defines_its_own_if_3_keeps_it "$TMPD/own.pl" "$WANT_OWN"
echo "$GATE_NAME: arms=$total red=$red modes=$MODES"
[ "$red" -eq 0 ] || { echo "⛔ $GATE_NAME RED"; exit 1; }
echo "✅ $GATE_NAME GREEN"
