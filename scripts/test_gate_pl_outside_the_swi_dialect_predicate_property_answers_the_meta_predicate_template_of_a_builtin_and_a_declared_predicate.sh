#!/usr/bin/env bash
# test_gate_pl_outside_the_swi_dialect_predicate_property_answers_the_meta_predicate_template_of_a_builtin_and_a_declared_predicate.sh -- OUTSIDE THE SWI DIALECT predicate_property/2 ALSO ANSWERS meta_predicate(Template) FOR A BUILT-IN AND FOR A :- meta_predicate PREDICATE,
# IN BOTH MODES (hq_prolog 2026-10-15; the coo's Logtalk red at 52f822b69: 8eb42d21d sent every non-SWI predicate_property through the runtime road, which
# has no meta_predicate answer, and 16 Logtalk ISO cases went red in both modes).
# THE CURE: the static road in lower_prolog.c keeps the runtime road's properties and ADDS meta_predicate(Template) -- the built-in's pl_meta_template
# (findall(?,0,?), (0,0), (0;0), (0->0) ...) or the user's own declaration -- as one more alternative, so the answer is the union.
# THE CRITERION IS NOT AN ORACLE DIFF but the Logtalk ISO suite's own cases, each carrying its expectation from the standard
# (corpus/packages/prolog/logtalk_iso): predicate_property_2 (29 cases: the control constructs' templates among them) and meta_predicate_1 (3 cases:
# mp1(0), mp2(1,_), mp2(1,Indicator)), graded by util_logtalk_grade.py --group in mode 3 and mode 4.  RED BEFORE (the parent, 8eb42d21d on):
# predicate_property_2 16/29 and meta_predicate_1 0/3 in both modes.
# RE-CUT 29 -> 28 (the cto's ARCH-PROLOG-DATABASE.md 4c ADDENDUM, 2026-10-25): lgt_predicate_property_2_23 runs only under
# predicate_property(if(_,_,_), built_in); if/3 is no builtin in either oracle, the meta-spec tables are cut from the oracles alone, so SCRIP
# skips that case as swipl does and predicate_property_2 passes 28 of its 29.
# rc=0 every case passes in both modes - rc=1 a case fails - rc=2 REFUSAL (no build, no suite).  ~40 s.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
B="$HERE/../../SCRIP"
GATE=test_gate_pl_outside_the_swi_dialect_predicate_property_answers_the_meta_predicate_template_of_a_builtin_and_a_declared_predicate
refuse() { echo "REFUSED(2) [$GATE]: $*"; exit 2; }
ROOT="${S4E_HOME:-$(cd "$HERE/../.." && pwd)}"
SUITE="${S4E_CORPUS:-$ROOT/corpus}/packages/prolog/logtalk_iso"
[ -f "$SUITE/ALL.csv" ] || refuse "no Logtalk suite at $SUITE"
[ -x "$B/scrip" ] || refuse "$B/scrip is not built"
[ -f "$B/out/libscrip_rt.so" ] || refuse "out/libscrip_rt.so is not built -- mode 4 cannot link"
"$HERE/util_require_fresh.sh" --gate $GATE || exit $?
. "$HERE/lib_declared_arena.sh" || refuse "lib_declared_arena.sh unloadable"
D="$(mktemp "${TMPDIR:-/tmp}/lgt_decl.XXXXXX")" || refuse "no scratch file"
trap 'rm -f "$D"' EXIT
declared_memory_begin "$SUITE/ALL.csv" "$D" > /dev/null 2>&1 || refuse "a declared-memory cell in $SUITE/ALL.csv is refused"
red=0
for g in predicate_property_2 meta_predicate_1; do
    line=$(timeout -k 5 400 python3 "$HERE/util_logtalk_grade.py" --suite "$SUITE" --scrip "$B/scrip" --modes m3,m4 --jobs 2 --decl "$D" --group $g 2>&1 | grep -m1 '^LOGTALK_ISO_BOARD')
    [ -n "$line" ] || refuse "the grader printed no board line for $g"
    pop=$(printf '%s\n' "$line" | sed -E 's/.*population=([0-9]+).*/\1/')
    want=$pop
    [ "$g" = predicate_property_2 ] && want=$((pop - 1))
    for m in m3 m4; do
        pass=$(printf '%s\n' "$line" | sed -E "s/.*${m}_pass=([0-9]+).*/\1/")
        if [ "$pass" = "$want" ]; then echo "  $g $m GREEN: $pass of $pop (want $want)"; else echo "  $g $m RED: $pass of $pop (want $want)"; red=1; fi
    done
done
[ "$red" = 0 ] && echo "PASS $GATE"
exit "$red"
