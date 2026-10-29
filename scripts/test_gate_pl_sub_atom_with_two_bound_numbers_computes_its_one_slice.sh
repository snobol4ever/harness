#!/usr/bin/env bash
# test_gate_pl_sub_atom_with_two_bound_numbers_computes_its_one_slice.sh -- sub_atom/5 ANSWERS IN TIME LINEAR IN THE ATOM: two bound numbers compute ONE slice, a bound Sub walks its occurrences, and only the unbound cases
# enumerate -- through a closed-form index, never a re-walk per candidate. hq_prolog 2026-10-04, row prolog-sub-atom-5-with-before-and-length-bound-computes-its-
# one-slice-not-an-enumeration-of-every-before-length-pair (the cfo's measurement). ARM 1 (both modes): a 200000-character atom, sub_atom(B, 100000, 1, A, C)
# answers a/99999 inside 10 s (RED on origin 29d5b67fd: no answer within 10 s -- the lowering enumerated all (n+1)(n+2)/2 Before/Length pairs and each candidate
# re-walked the string and built its atom; measured n=2000 5.2 s, n=4000 47.8 s, n=8000 over 120 s). ARM 2 (both modes): 22 patterns -- every bound/unbound
# combination of Before, Length, After and Sub, an empty Sub, overlapping occurrences, out-of-range numbers, the empty atom, a UTF-8 atom -- byte-equal to
# swipl -q -t halt, cut at gate-writing time (origin answers them too; they are the behaviour the plan must keep).
set -u
GATE_NAME=test_gate_pl_sub_atom_with_two_bound_numbers_computes_its_one_slice
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIP="${SCRIP_BIN:-$HERE/../../SCRIP/scrip}"
RT="${RT_DIR:-$(dirname "$SCRIP")/out}"
refuse() { echo "⛔ REFUSED(2) [$GATE_NAME]: $*" >&2; exit 2; }
[ -x "$SCRIP" ] || refuse "no scrip binary at $SCRIP -- run make first"
[ -n "${SCRIP_BIN:-}" ] || "$HERE/util_require_fresh.sh" --gate "$GATE_NAME" "$SCRIP" "$RT/libscrip_rt.so" || exit 2
TMPD="$(mktemp -d)"; trap 'rm -rf "$TMPD"' EXIT
red=0
printf ':- initialization(main).\nmain :- length(L, 200000), maplist(=(0\x27a), L), atom_codes(B, L), sub_atom(B, 100000, 1, A, C), write(C/A), nl.\n' > "$TMPD/big.pl"
cat > "$TMPD/pat.pl" <<'EOP'
:- initialization(main).
e(G) :- findall(G, G, R), write(R), nl.
main :- e(sub_atom(abc, B, L, A, S)), e(sub_atom(abc, 1, L, A, S)), e(sub_atom(abc, B, 2, A, S)), e(sub_atom(abc, B, L, 1, S)),
        e(sub_atom(abc, 1, 1, A, S)), e(sub_atom(abc, 0, L, 1, S)), e(sub_atom(abc, B, 1, 0, S)), e(sub_atom(abc, 1, 1, 1, S)),
        e(sub_atom(aaa, B, L, A, aa)), e(sub_atom(abcab, B, L, A, ab)), e(sub_atom(abc, B, L, A, '')), e(sub_atom(abc, 2, L, A, c)),
        e(sub_atom(abc, 1, L, A, c)), e(sub_atom(abc, 4, L, A, S)), e(sub_atom(abc, B, 4, A, S)), e(sub_atom(abc, B, L, 7, S)),
        e(sub_atom('', B, L, A, S)), e(sub_atom('héllo', 1, 3, A, S)), e(sub_atom('héllo', B, L, A, 'll')), e(sub_atom('héllo', B, 2, 0, S)),
        e(sub_atom(abc, 0, 3, 0, abc)), e(sub_atom(abc, 0, 3, 0, abd)).
EOP
want_pat='[sub_atom(abc,0,0,3,),sub_atom(abc,0,1,2,a),sub_atom(abc,0,2,1,ab),sub_atom(abc,0,3,0,abc),sub_atom(abc,1,0,2,),sub_atom(abc,1,1,1,b),sub_atom(abc,1,2,0,bc),sub_atom(abc,2,0,1,),sub_atom(abc,2,1,0,c),sub_atom(abc,3,0,0,)]
[sub_atom(abc,1,0,2,),sub_atom(abc,1,1,1,b),sub_atom(abc,1,2,0,bc)]
[sub_atom(abc,0,2,1,ab),sub_atom(abc,1,2,0,bc)]
[sub_atom(abc,0,2,1,ab),sub_atom(abc,1,1,1,b),sub_atom(abc,2,0,1,)]
[sub_atom(abc,1,1,1,b)]
[sub_atom(abc,0,2,1,ab)]
[sub_atom(abc,2,1,0,c)]
[sub_atom(abc,1,1,1,b)]
[sub_atom(aaa,0,2,1,aa),sub_atom(aaa,1,2,0,aa)]
[sub_atom(abcab,0,2,3,ab),sub_atom(abcab,3,2,0,ab)]
[sub_atom(abc,0,0,3,),sub_atom(abc,1,0,2,),sub_atom(abc,2,0,1,),sub_atom(abc,3,0,0,)]
[sub_atom(abc,2,1,0,c)]
[]
[]
[]
[]
[sub_atom(,0,0,0,)]
[sub_atom(héllo,1,3,1,éll)]
[sub_atom(héllo,2,2,1,ll)]
[sub_atom(héllo,3,2,0,lo)]
[sub_atom(abc,0,3,0,abc)]
[]'
run() { local f="$1" mode="$2" t="$3"
    if [ "$mode" = m3 ]; then (cd "$TMPD" && timeout -k 5 "$t" "$SCRIP" "$f.pl" </dev/null 2>/dev/null)
    else (cd "$TMPD" && timeout -k 5 120 "$SCRIP" --compile --out="$f.s" "$f.pl" </dev/null >/dev/null 2>&1) && gcc -m64 -no-pie "$TMPD/$f.s" -o "$TMPD/$f.bin" -L"$RT" -lscrip_rt -Wl,-rpath,"$RT" -lm 2>/dev/null \
         && (cd "$TMPD" && timeout -k 5 "$t" "./$f.bin" </dev/null 2>/dev/null); fi; }
for mode in m3 m4; do
    got=$(run big $mode 10); if [ "$got" = "a/99999" ]; then echo "  ok  arm 1 $mode: the 200000-character atom answers its one slice inside 10 s"
    else echo "  RED arm 1 $mode: got [$got] want [a/99999] within 10 s"; red=$((red+1)); fi
    got=$(run pat $mode 60); if [ "$got" = "$want_pat" ]; then echo "  ok  arm 2 $mode: 22 patterns match swipl"
    else echo "  RED arm 2 $mode: the patterns differ from swipl: $(diff <(printf '%s\n' "$want_pat") <(printf '%s\n' "$got") | head -4 | tr '\n' '|' | cut -c1-200)"; red=$((red+1)); fi
done
[ "$red" = 0 ] || { echo "GATE FAIL [$GATE_NAME]: $red arm(s) red"; exit 1; }
echo "GATE PASS [$GATE_NAME]: sub_atom/5 computes a bound slice of a 200000-character atom inside 10 s and 22 patterns match swipl, in both modes"
exit 0
