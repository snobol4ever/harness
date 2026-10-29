#!/usr/bin/env bash
# test_gate_pas_a_subrange_variable_is_given_only_values_of_its_subrange.sh -- ISO 7185 6.8.2.2 and 6.9.1: assigning or reading a value
# outside a subrange variable's type is an error, detected by default; fpc's {$R+} and {$R-} keep their fpc meaning
#
# MEASURED 2026-09-26 by hq_pascal, both modes, row pascal-every-suite-to-100-under-nonet-ceo-1266. The subrange check existed
# (pas_subvar_get + __pas_range_check) but ran only under an explicit {$R+} -- fpc's default of range checks off -- and never on read: b := 10
# into 1..5 printed 10, and PAT iso7185prt1755 (read 10 into 1..5) ran to rc 0. ISO makes both an error and PAT expects them detected. NO
# BRACKET: an absent error sends no event. The cure: g_pas_range_check_on is three-state -- 2 by default (ISO: checked, and a failure
# stops with the ISO 7185 clause, rc 1, which the PAT verdict reads as a refusal), 1 under {$R+} or {$r+} (fpc's own runtime error 201 and
# rc 201, which FPC test_trstr7 and webtbs_tw2690 expect), 0 under {$R-} (unchecked, like fpc) -- and read into a subrange variable is
# wrapped as assignment already was. MEASURED before landing: default-on checking moved no FPC, rungs or bench program.
#
# ⭐ A SET VARIABLE REGISTERS ITS BASE RANGE LIKE A SUBRANGE VARIABLE, so the old {$R+} check compared the SET'S VALUE with 1..20 and
# refused s := [1, 3, 13] (measured: default-on checking turned test_gate_pas_calls_carry_more_than_six_operands red, and PAT 1750 read
# green for the wrong reason). A set assignment now takes the set form of the check: every member must lie in the base-type (6.8.2.2).
#
# ARMS, both modes: (1) an assignment, (2) a read of a value outside 1..5, and (6) a set with a member outside 1..10 must print fpc -Miso's
# stdout up to the fault, exit 1 and name 6.8.2.2 / 6.9.1 (fpc -Miso checks none of them by default, so its 'after' line is cut); (3) the
# assignment under {$R+} must exit 201 like fpc -Miso does; (4) the assignment under {$R-}, (5) in-range assignments and reads, and (7) an
# in-range set assignment must run byte-identical to fpc -Miso. It FAILS on the parent (arms 1, 2 and 6 run to rc 0). FAIL_ONCE=1
# corrupts arm 5's ref to prove it can fail. ⭐ THE CHECK IS SCOPED (found after landing, SCRIP ab47ea88d): the subrange table was flat, so a
# program's x: integer was checked against a procedure's local x: 1..5 and x := 10 was refused where fpc runs it; each entry now carries
# the unique id of its defining point (g_pas_scope's PasDef.uid) and a lookup matches only the declaration visible where it is asked.
# Arm 8 (a local x: 1..5 given 9 beside the program's x: integer) must still fault, and arm 9 (the shadowing program) must run.
# ⭐ A FORMAL IS A VARIABLE OF ITS TYPE TOO (found 2026-09-26, PAT iso7185prt1708, 6.6.3.2 / 6.8.2.2): a formal section registered set-ness
# but never its subrange or set base, so c := [3,6] into a value formal c of type set of 1..5 ran to rc 0. The routine's scope now reads each
# value and var formal's type from the routine's signature when it opens and registers the bounds against the formal's own defining point.
# Arms 10 and 11 (a value set formal given [3,6], a var formal of 1..5 given 9) must fault; arm 12 (in-range formals, and a program x:
# integer given 10 after a routine whose formal x is 1..5) must run.
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -uo pipefail
G="$(basename "${BASH_SOURCE[0]}" .sh)"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
SCRIP="${SCRIP_BIN:-$ROOT/scrip}"; [ -x "$SCRIP" ] || { echo "⛔ GATE REFUSE(2) [$G]: no scrip at $SCRIP"; exit 2; }
RT_DIR="${RT_DIR:-$ROOT/out}"; [ -f "$RT_DIR/libscrip_rt.so" ] || { echo "⛔ GATE REFUSE(2) [$G]: no runtime at $RT_DIR/libscrip_rt.so"; exit 2; }
FPC="${FPC_BIN:-/usr/bin/fpc}"; [ -x "$FPC" ] || { echo "⛔ GATE REFUSE(2) [$G]: no fpc at $FPC -- every arm's expectation is CUT FROM THE ORACLE"; exit 2; }
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
RC=0
run() { local m="$1" p="$2"
  if [ "$m" = m3 ]; then ( cd "$T" && timeout -k 5 20s "$SCRIP" --run "$p.pas" <"$T/in" >"$T/o" 2>"$T/e" ); return $?; fi
  ( cd "$T" && timeout -k 5 20s "$SCRIP" --compile --out="$T/$p.s" "$p.pas" </dev/null >/dev/null 2>&1 && cc -m64 -no-pie "$p.s" -o "$p.m4" -L"$RT_DIR" -lscrip_rt -lm -Wl,-rpath,"$RT_DIR" >/dev/null 2>&1 ) || { echo "  ⛔ $p m4: did not compile or link"; return 99; }
  ( cd "$T" && timeout -k 5 20s "./$p.m4" <"$T/in" >"$T/o" 2>"$T/e" ); return $?; }
fpcrun() { ( cd "$T" && "$FPC" -Miso -v0 -o"$1.fpc" $1.pas >/dev/null 2>&1 ) || { echo "⛔ GATE REFUSE(2) [$G]: fpc -Miso would not compile $1"; exit 2; }; ( cd "$T" && timeout -k 5 20s ./$1.fpc <"$T/in" >"$T/$1.want" 2>/dev/null ); echo $?; }
printf ' 10\n' > "$T/in"
printf 'program asg(output);\nvar b: 1..5; i: integer;\nbegin\n  i := 3; b := i; writeln(%s, b); i := 10; b := i; writeln(%s, b)\nend.\n' "'in '" "'after '" > "$T/asg.pas"
printf 'program sbad(output);\nvar s: set of 1..10; i: integer;\nbegin\n  s := [2, 4]; writeln(%s); s := [1, 2, 11]; writeln(%s)\nend.\n' "'before'" "'after'" > "$T/sbad.pas"
printf 'program sok(output);\nvar s: set of 1..20; i: integer;\nbegin\n  s := [1, 3, 5, 7, 9, 11, 13, 20]; for i := 0 to 21 do if i in s then write(i:3); writeln\nend.\n' > "$T/sok.pas"
printf 'program shf(output);\nvar x: integer;\nprocedure p;\nvar x: 1..5;\nbegin\n  x := 9\nend;\nbegin\n  x := 10; writeln(%s, x); p; writeln(%s)\nend.\n' "'main '" "'after'" > "$T/shf.pas"
printf 'program sho(output);\nvar x: integer;\nprocedure p;\nvar x: 1..5;\nbegin\n  x := 3; writeln(%s, x)\nend;\nprocedure q(x: integer);\nbegin\n  x := x * 10; writeln(%s, x)\nend;\nbegin\n  x := 10; writeln(%s, x); p; q(7)\nend.\n' "'p '" "'q '" "'main '" > "$T/sho.pas"
printf 'program fset(output);\ntype a = set of 1..5;\nprocedure b(c: a);\nbegin\n  c := [3, 6]; writeln(%s)\nend;\nbegin\n  writeln(%s); b([1, 2])\nend.\n' "'after'" "'before'" > "$T/fset.pas"
printf 'program fvar(output);\ntype s = 1..5;\nvar g: s;\nprocedure b(var c: s);\nvar i: integer;\nbegin\n  i := 9; c := i; writeln(%s)\nend;\nbegin\n  writeln(%s); b(g)\nend.\n' "'after'" "'before'" > "$T/fvar.pas"
printf 'program fok(output);\ntype a = set of 1..5; s = 1..5;\nvar g: s; x: integer;\nprocedure b(c: a; var d: s; e: s);\nbegin\n  c := c + [5]; d := e; if 5 in c then writeln(%s, d)\nend;\nprocedure q(x: s);\nbegin\n  x := 5; writeln(%s, x)\nend;\nbegin\n  b([1, 2], g, 4); writeln(g); q(2); x := 10; writeln(x)\nend.\n' "'five '" "'q '" > "$T/fok.pas"
printf 'program rdg(input, output);\nvar b: 1..5;\nbegin\n  writeln(%s); read(b); writeln(%s, b)\nend.\n' "'before'" "'after '" > "$T/rdg.pas"
printf '{$R+}\nprogram rplus(output);\nvar b: 1..5; i: integer;\nbegin\n  i := 10; writeln(%s); b := i; writeln(%s, b)\nend.\n' "'before'" "'after '" > "$T/rplus.pas"
printf '{$R-}\nprogram rminus(output);\nvar b: 1..5; i: integer;\nbegin\n  i := 10; b := i; writeln(%s, b)\nend.\n' "'unchecked '" > "$T/rminus.pas"
printf 'program ok(input, output);\nvar b: 1..5; c: %s..%s; i: integer;\nbegin\n  for i := 1 to 5 do begin b := i; write(b:2) end; writeln;\n  read(b); writeln(b); c := %s; writeln(c)\nend.\n' "'a'" "'z'" "'q'" > "$T/ok.pas"
for p in asg rdg sbad shf fset fvar; do
  frc=$(fpcrun $p); [ "$frc" = 0 ] && grep -q '^after' "$T/$p.want" || { echo "⛔ GATE REFUSE(2) [$G]: fpc -Miso now checks arm $p by default -- re-cut it"; exit 2; }
  grep -v '^after' "$T/$p.want" > "$T/$p.cut"; cl='6\.8\.2\.2'; [ $p = rdg ] && cl='6\.9\.1'
  for m in m3 m4; do run $m $p; rc=$?
    if [ "$rc" = 1 ] && cmp -s "$T/$p.cut" "$T/o" && grep -q "ISO 7185 $cl" "$T/e"; then echo "  arm $p $m: rc=1, stdout = fpc up to the fault, stderr names ${cl//\\/}"
    else echo "  ⛔ arm $p $m FAILED: rc=$rc"; echo "      want: $(tr '\n' '|' < "$T/$p.cut")"; echo "      got : $(tr '\n' '|' < "$T/o")"; echo "      err : $(head -1 "$T/e" | cut -c1-140)"; RC=1; fi; done
done
frc=$(fpcrun rplus); [ "$frc" = 201 ] || { echo "⛔ GATE REFUSE(2) [$G]: fpc -Miso {\$R+} exited $frc, not 201"; exit 2; }
for m in m3 m4; do run $m rplus; rc=$?
  if [ "$rc" = 201 ] && cmp -s "$T/rplus.want" "$T/o"; then echo "  arm {\$R+} $m: rc=201 and stdout, as fpc -Miso"
  else echo "  ⛔ arm {\$R+} $m FAILED: rc=$rc (want 201)"; RC=1; fi; done
for p in rminus ok sok sho fok; do
  [ $p = ok ] && printf ' 4\n' > "$T/in"
  frc=$(fpcrun $p); [ "$frc" = 0 ] || { echo "⛔ GATE REFUSE(2) [$G]: fpc -Miso ran $p to rc $frc"; exit 2; }
  if [ -n "${FAIL_ONCE:-}" ] && [ $p = ok ]; then echo "corrupted by FAIL_ONCE" >> "$T/ok.want"; fi
  for m in m3 m4; do run $m $p; rc=$?
    if [ "$rc" = 0 ] && cmp -s "$T/$p.want" "$T/o"; then echo "  arm $p $m: byte-identical to fpc -Miso"
    else echo "  ⛔ arm $p $m FAILED: rc=$rc"; echo "      want: $(tr '\n' '|' < "$T/$p.want")"; echo "      got : $(tr '\n' '|' < "$T/o")"; RC=1; fi; done
done
if [ "$RC" = 0 ]; then echo "GATE PASS [$G]: a subrange variable is given only values of its subrange by default, {\$R+}/{\$R-} keep fpc's meaning, both modes"
else echo "GATE FAIL(1) [$G]: examined 12 arms in 2 modes"; fi
echo "    tree: SCRIP=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY)" \
     " oracle: $FPC $($FPC -iV 2>/dev/null)  measured $(date -u +%Y-%m-%dT%H:%MZ)"
exit $RC
