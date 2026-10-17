#!/usr/bin/env bash
# stale-binary preflight (row test-gate-scripts-that-grade-scrip-refuse-on-a-stale-binary-census-widened, hq_T 2026-09-05)
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
# test_gate_icon_arguments_dereference_at_the_call.sh -- ICON ARGUMENT LISTS STAGE VARIABLES AND DEREFERENCE AT THE CALL.
# Row icon-arizona-traps-write-dereferences-its-arguments-eagerly-not-after-all-are-evaluated (coo, CEO-452, 2026-09-09);
# diagnosis hq_U, .github FINDING-2026-09-09-hq_U-icon-argument-lists-must-stage-variables-and-dereference-at-the-call-...
#
# THE RULE (iconx invoke.r:67-74, Jcon gen_bc.icn:1636-1641): an argument list is evaluated left to right into
# VARIABLES and every variable is dereferenced when the call is made, so `write(i, (i := 2, ""), i)` prints 22.
# SCRIP read each variable as it was evaluated and printed 12. The cure stages the variable (locals, parameters,
# declared globals, L[1], r.x) in lower_call/lower_make_list and chains one IR_DEREF per staged argument after
# the whole list -- on the CALLER's side, before the call node; bb_call_* templates still receive values.
#
# ⛔ THE FIVE GREEN CONTROLS (p09-p13) ARE LOAD-BEARING: operators, nested calls, L[i] and the no-mutation case were
# already right, and the likeliest way to break this class is to defer dereference too widely and move them.
# p15/p16 pin the generator-call chain tail (a staged argument to find() or to a user generator: IPL morse regressed
# on 2026-09-09 when the generator call's entry link was re-pointed to the last ARGUMENT instead of the last DEREF).
# p17-p20 pin the CALL THROUGH A VALUE (IR_CALL_VALUE, shared with Prolog): a variable argument reaches the runtime
# dispatcher as the VARIABLE and is dereferenced there unless the callee is name(), so name() through a value answers
# for a local, a subscript and a global, and deref timing through a value matches the direct call (CEO-464/468).
# p21-p25 (row icon-argument-staging-widening-..., coo, CEO-477): an ASSIGNMENT (and +:=) in argument position yields its
# left operand as a VARIABLE, a SECTION s[i:j] is a substring variable, and an element generator (!R) reaching a builtin
# through a value (name) arrives as the variable; every expected output pinned from iconx 9.5 on 2026-09-09.
# p14 is the ceo's CEO-456 R7 witness: arguments are passed by VALUE (a callee assigning its parameter does not
# write the caller's variable). Expected outputs are PINNED from icont/iconx 9.5 (2026-09-09); the gate is hermetic
# and never consults the oracle, so it cannot go green because an oracle install moved.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
. "$HERE/lib_gate.sh"
GATE_NAME="icon_arguments_dereference_at_the_call"
SCRIP="${SCRIP:-$ROOT/scrip}"; RT="$ROOT/out"
[ -x "$SCRIP" ] || { echo "⛔ REFUSE(rc=2) [$GATE_NAME]: scrip not built at $SCRIP"; exit 2; }
[ -f "$RT/libscrip_rt.so" ] || { echo "⛔ REFUSE(rc=2) [$GATE_NAME]: $RT/libscrip_rt.so missing -- mode 4 cannot link"; exit 2; }
command -v gcc >/dev/null || { echo "⛔ REFUSE(rc=2) [$GATE_NAME]: gcc not on PATH -- mode 4 cannot link"; exit 2; }
W="$(mktemp -d "${TMPDIR:-/tmp}/gate_argderef.XXXXXX")" || { echo "⛔ REFUSE(rc=2) [$GATE_NAME]: mktemp failed"; exit 2; }
trap 'rm -rf "$W"' EXIT
gate_bin_watch "$SCRIP" "$RT/libscrip_rt.so"

probe() { printf '%s\n' "$3" > "$W/$1.icn"; printf '%s' "$2" > "$W/$1.want"; }
probe p01_local      '22'  'procedure main(); local i; i := 1; write(i, (i := 2, ""), i); end'
probe p02_userproc   '22'  'procedure g(a, b, c); write(a, c); end
procedure main(); local i; i := 1; g(i, (i := 2, ""), i); end'
probe p03_global     '22'  'global i
procedure main(); i := 1; write(i, (i := 2, ""), i); end'
probe p04_listelem   '22'  'procedure main(); local L; L := [1]; write(L[1], (L[1] := 2, ""), L[1]); end'
probe p05_field      '22'  'record R(x)
procedure main(); local r; r := R(1); write(r.x, (r.x := 2, ""), r.x); end'
probe p06_three      '333' 'procedure main(); local i; i := 1; write(i, (i := 2, ""), i, (i := 3, ""), i); end'
probe p07_listlit    '22'  'procedure main(); local i, L; i := 1; L := [i, (i := 2, ""), i]; every writes(!L); write(); end'
probe p08_return     '2'   'procedure h(a, b); return a; end
procedure main(); local i; i := 1; write(h(i, (i := 2, ""))); end'
probe p09_binop      '10'  'procedure main(); local i; i := 0; write(i + (i := 10, 0)); end'
probe p10_concat     'b'   'procedure main(); local i; i := "a"; write(i || (i := "b", "")); end'
probe p11_nested     '12'  'procedure f(x); return x; end
procedure main(); local i; i := 1; write(f(i), (i := 2, ""), f(i)); end'
probe p12_subscript  '12'  'procedure main(); local i, L; L := [1, 2]; i := 1; write(L[i], (i := 2, ""), L[i]); end'
probe p13_nomut      '55'  'procedure main(); local i; i := 5; write(i, "", i); end'
probe p14_byvalue    '1'   'procedure f(a); a := 2; end
procedure main(); local y; y := 1; f(y); write(y); end'
probe p15_genbuiltin '2'   'procedure main(); local c, s; c := "M"; s := "TMOT09"; write(find(c, s)); end'
probe p16_usergen    '5|6' 'procedure g(n); suspend n to n + 1; end
procedure main(); local i; i := 5; every write(g(i)); end'
probe p17_valname_lcl 'x'   'procedure main(); local p, x; p := proc("name", 0); x := 5; write(p(x)); end'
probe p18_valname_sub 'L[2]' 'procedure main(); local p, L; p := proc("name", 0); L := [1, 2]; write(p(L[2])); end'
probe p19_valname_glb 'g'   'global g
procedure main(); local p; g := 1; p := proc("name", 0); write(p(g)); end'
probe p20_valcall_tim '22'  'procedure main(); local p, i; p := proc("write", 0); i := 1; p(i, (i := 2, ""), i); end'
probe p21_assign_arg  '33'  'procedure main(); local x; write(x := 2, x := 3); end'
probe p22_section_arg 'wqwerty' 'procedure main(); ev("abcdefghi"); end
procedure ev(b); write(b[2:3], b[1:4] := "qwerty"); end'
probe p23_valgen_name 'date2.m|date2.y|date2.f|date2.m|date2.y|date2.f' 'record date2(m, y, f)
procedure main(); local p, R; R := date2("jan", 1999, "x"); p := proc("name", 0); every write(p(!R)); every write(name(!R)); end'
probe p24_augop_arg   '77'  'procedure main(); local x; x := 5; write(x +:= 1, x +:= 1); end'
probe p25_valgen_str  'a|b|c' 'procedure main(); local p; p := proc("write", 0); every p(!"abc"); end'

red=0; n=0
for src in "$W"/p*.icn; do
    b="$(basename "$src" .icn)"; want="$(cat "$W/$b.want")"; n=$((n+1))
    m3="$(cd "$W" && timeout -k 5 20 "$SCRIP" "$b.icn" </dev/null 2>&1 | tr '\n' '|' | sed 's/|$//')"
    m4="(compile/link failed)"
    if (cd "$W" && "$SCRIP" --compile "$b.icn" </dev/null > "$b.s" 2>/dev/null && gcc -c "$b.s" -o "$b.o" 2>/dev/null \
        && gcc "$b.o" -L"$RT" -lscrip_rt -lm -Wl,-rpath,"$RT" -o "$b.m4" 2>/dev/null); then
        m4="$(cd "$W" && timeout -k 5 20 "./$b.m4" </dev/null 2>&1 | tr '\n' '|' | sed 's/|$//')"
    fi
    v=GREEN; { [ "$m3" = "$want" ] && [ "$m4" = "$want" ]; } || { v=RED; red=$((red+1)); }
    printf '  %-14s want=%-5s m3=%-5s m4=%-5s %s\n' "$b" "$want" "$m3" "$m4" "$v"
done
gate_bin_unmoved
GATE_EXAMINED="$n probes (m3+m4)"
gate_floor "$n" 20 "probes minted"
gate_verdict "$red" "probe(s) disagree with the pinned iconx output in at least one mode"
