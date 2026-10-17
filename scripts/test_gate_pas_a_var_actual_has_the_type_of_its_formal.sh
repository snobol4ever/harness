#!/usr/bin/env bash
# test_gate_pas_a_var_actual_has_the_type_of_its_formal.sh -- ISO 7185 6.6.3.3: the actual-parameter of a variable formal-parameter shall
# possess the same type as the formal; a variable of a subrange type is not of its host type
#
# MEASURED 2026-09-26 by hq_pascal, both modes, row pascal-every-suite-to-100-under-nonet-ceo-1266. PAT iso7185prt1823 passes c: 1..10 to
# procedure a(var b: integer) and scrip ran it to rc 0; fpc -Miso refuses it at compile time ("Call by var for arg no. 1 has to match
# exactly"). NO BRACKET: a static refusal sends no event. The cure: pas_value_actuals_check gains a var arm -- an actual that is a plain
# variable registered as a subrange variable (a set variable excluded: its base range rides the same table) given to a var formal whose
# signature type is not itself a subrange type is refused, naming 6.6.3.3.
#
# ⭐ NO WIDER THAN THE ORACLE (probed 2026-09-26): fpc -Miso refuses an integer or enumerated subrange variable given to a var formal of its
# host type, but ACCEPTS a char subrange to var char, a boolean one to var boolean, and one subrange type to a var formal of another
# subrange type of the same host -- all three ISO errors that fpc does not diagnose. The check refuses exactly what fpc refuses; the rest
# is the oracle's call and a later ruling's, never this gate's.
#
# ARMS, both modes: (1) 1..10 to var integer, (2) an enumerated subrange g..b to var e, (3) a subrange VALUE formal passed on to var integer
# -- each must be refused by scrip (rc non-zero, stderr names 6.6.3.3) AND by fpc -Miso (the oracle's own compile error); (4) a variable of
# a named subrange type to a var formal of that same type, an integer to var integer, a set variable to a var formal of its set type and
# (5) 'a'..'z' to var char must run byte-identical to fpc -Miso. It FAILS on the parent (arms 1-3 run to rc 0). FAIL_ONCE=1 corrupts arm
# 4's ref to prove it can fail.
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -uo pipefail
G="$(basename "${BASH_SOURCE[0]}" .sh)"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
SCRIP="${SCRIP_BIN:-$ROOT/scrip}"; [ -x "$SCRIP" ] || { echo "⛔ GATE REFUSE(2) [$G]: no scrip at $SCRIP"; exit 2; }
RT_DIR="${RT_DIR:-$ROOT/out}"; [ -f "$RT_DIR/libscrip_rt.so" ] || { echo "⛔ GATE REFUSE(2) [$G]: no runtime at $RT_DIR/libscrip_rt.so"; exit 2; }
FPC="${FPC_BIN:-/usr/bin/fpc}"; [ -x "$FPC" ] || { echo "⛔ GATE REFUSE(2) [$G]: no fpc at $FPC -- every arm's expectation is CUT FROM THE ORACLE"; exit 2; }
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
RC=0
run() { local m="$1" p="$2"
  if [ "$m" = m3 ]; then ( cd "$T" && timeout -k 5 20s "$SCRIP" --run "$p.pas" </dev/null >"$T/o" 2>"$T/e" ); return $?; fi
  ( cd "$T" && timeout -k 5 20s "$SCRIP" --compile -o "$T/$p.s" "$p.pas" </dev/null >"$T/o" 2>"$T/e" ) || return $?
  ( cd "$T" && cc -m64 -no-pie "$p.s" -o "$p.m4" -L"$RT_DIR" -lscrip_rt -lm -Wl,-rpath,"$RT_DIR" >/dev/null 2>&1 ) || { echo "  ⛔ $p m4: did not link"; return 99; }
  ( cd "$T" && timeout -k 5 20s "./$p.m4" </dev/null >"$T/o" 2>"$T/e" ); return $?; }
printf 'program vint(output);\nvar c: 1..10;\nprocedure a(var b: integer);\nbegin\n  b := 1\nend;\nbegin\n  a(c); writeln(c)\nend.\n' > "$T/vint.pas"
printf 'program vchr(output);\nvar c: %s..%s;\nprocedure a(var b: char);\nbegin\n  b := %s\nend;\nbegin\n  a(c); writeln(c)\nend.\n' "'a'" "'z'" "'q'" > "$T/vchr.pas"
printf 'program venm(output);\ntype e = (r, g, b, y);\nvar c: g..b;\nprocedure a(var d: e);\nbegin\n  d := g\nend;\nbegin\n  a(c); writeln(ord(c))\nend.\n' > "$T/venm.pas"
printf 'program vfml(output);\ntype s = 1..5;\nprocedure a(var b: integer);\nbegin\n  b := 1\nend;\nprocedure p(x: s);\nbegin\n  a(x); writeln(x)\nend;\nbegin\n  p(3)\nend.\n' > "$T/vfml.pas"
printf 'program vok(output);\ntype s = 1..10; t = set of 1..5;\nvar c: s; i: integer; u: t;\nprocedure a(var b: s);\nbegin\n  b := b + 1\nend;\nprocedure n(var b: integer);\nbegin\n  b := b * 2\nend;\nprocedure w(var b: t);\nbegin\n  b := b + [4]\nend;\nbegin\n  c := 3; a(c); writeln(c); i := 21; n(i); writeln(i); u := [1]; w(u); writeln(4 in u)\nend.\n' > "$T/vok.pas"
for p in vint venm vfml; do
  ( cd "$T" && "$FPC" -Miso -v0 -o"$p.fpc" $p.pas >/dev/null 2>&1 ) && { echo "⛔ GATE REFUSE(2) [$G]: fpc -Miso now ACCEPTS arm $p -- re-cut it"; exit 2; }
  for m in m3 m4; do run $m $p; rc=$?
    if [ "$rc" != 0 ] && [ "$rc" != 99 ] && grep -q 'ISO 7185 6\.6\.3\.3' "$T/e"; then echo "  arm $p $m: refused rc=$rc naming 6.6.3.3, as fpc -Miso refuses it"
    else echo "  ⛔ arm $p $m FAILED: rc=$rc"; echo "      err : $(head -1 "$T/e" | cut -c1-140)"; RC=1; fi; done
done
for p in vok vchr; do
  ( cd "$T" && "$FPC" -Miso -v0 -o$p.fpc $p.pas >/dev/null 2>&1 ) || { echo "⛔ GATE REFUSE(2) [$G]: fpc -Miso would not compile $p"; exit 2; }
  ( cd "$T" && timeout -k 5 20s ./$p.fpc </dev/null >"$T/$p.want" 2>/dev/null ) || { echo "⛔ GATE REFUSE(2) [$G]: fpc -Miso's $p did not run to rc 0"; exit 2; }
  [ -n "${FAIL_ONCE:-}" ] && [ $p = vok ] && echo "corrupted by FAIL_ONCE" >> "$T/vok.want"
  for m in m3 m4; do run $m $p; rc=$?
    if [ "$rc" = 0 ] && cmp -s "$T/$p.want" "$T/o"; then echo "  arm $p $m: byte-identical to fpc -Miso"
    else echo "  ⛔ arm $p $m FAILED: rc=$rc"; echo "      want: $(tr '\n' '|' < "$T/$p.want")"; echo "      got : $(tr '\n' '|' < "$T/o")"; RC=1; fi; done
done
if [ "$RC" = 0 ]; then echo "GATE PASS [$G]: a var actual of a subrange type is refused against a formal of another type, same-type var actuals run, both modes"
else echo "GATE FAIL(1) [$G]: examined 5 arms in 2 modes"; fi
echo "    tree: SCRIP=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY)" \
     " oracle: $FPC $($FPC -iV 2>/dev/null)  measured $(date -u +%Y-%m-%dT%H:%MZ)"
exit $RC
