#!/usr/bin/env bash
# test_gate_pas_a_field_of_an_anonymous_record_variable_keeps_its_record_type.sh -- a record variable declared with its own record-type
# (no type-identifier) whose field is of a record type: that field's own fields are selected, assigned and written (ISO 7185 6.5.3.3)
#
# MEASURED 2026-09-26 by hq_pascal, both modes, row pascal-every-suite-to-100-under-nonet-ceo-1266. FOUND BY PROBING, NOT BY ANY SUITE
# (the rungs' nested records all go through a named outer type): type q = record a, b: integer end; var g: record x: integer; c: q end;
# g.c.a := 42; writeln(g.c.a) wrote nothing and every statement after it was skipped, where fpc -Miso prints 42. The selector g.c.a lowers
# through pas_nested_field_resolve, which asked pas_with_sel_rtype for the record type of g.c -- and that function found a record-type for
# g only when some DECLARED record type happened to carry g's field names, so an anonymous g had none and g.c.a fell to an unresolved
# by-name field. The cure reads g's own registered field record type (pas_recvar_field_rectype) first. PAT iso7185prt1849's
# r.r.d.b has the same shape one level deeper, behind a second defect (an anonymous record nested in a record is flattened into it).
#
# ARMS, both modes, each run byte-identical to fpc -Miso: (1) na -- g.c.a/g.c.b of an anonymous g with a field of record type q;
# (2) nc -- the inner record holds a char field, written in one writeln; (3) nw -- the inner fields assigned through with g do c.a; (4) nh -- two
# anonymous variables copying inner fields between them; (5) nn -- the named outer type (the rungs' shape, green before and after).
# It FAILS on the parent (arms na/nc/nw/nh). NOT CURED HERE, measured and rowed: a store through with g.c do a := 4, and a store two
# record levels deep (g.c.u.a), are lost through a NAMED outer type too -- separate defects.
# FAIL_ONCE=1 corrupts arm nn's ref to prove it can fail.
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
  if [ "$m" = m3 ]; then ( cd "$T" && timeout -k 5 20s "$SCRIP" --run "$p.pas" </dev/null >"$T/o" 2>"$T/e" ); return $?; fi
  ( cd "$T" && timeout -k 5 20s "$SCRIP" --compile --out="$T/$p.s" "$p.pas" </dev/null >"$T/o" 2>"$T/e" ) || return $?
  ( cd "$T" && cc -m64 -no-pie "$p.s" -o "$p.m4" -L"$RT_DIR" -lscrip_rt -lm -Wl,-rpath,"$RT_DIR" >/dev/null 2>&1 ) || { echo "  ⛔ $p m4: did not link"; return 99; }
  ( cd "$T" && timeout -k 5 20s "./$p.m4" </dev/null >"$T/o" 2>"$T/e" ); return $?; }
printf 'program na(output);\ntype q = record a, b: integer end;\nvar g: record x: integer; c: q end;\nbegin\n  g.x := 1; g.c.a := 42; g.c.b := 7;\n  writeln(g.x); writeln(g.c.a); writeln(g.c.b)\nend.\n' > "$T/na.pas"
printf 'program nc(output);\ntype q = record c: char; n: integer end;\nvar r: record i: integer; s: q end;\nbegin\n  r.i := 5; r.s.n := 7; r.s.c := %s;\n  writeln(r.i, r.s.c, r.s.n)\nend.\n' "'x'" > "$T/nc.pas"
printf 'program nw(output);\ntype q = record a, b: integer end;\nvar g: record x: integer; c: q end;\nbegin\n  with g do begin x := 3; c.a := 4; c.b := c.a + x end;\n  writeln(g.x, g.c.a, g.c.b)\nend.\n' > "$T/nw.pas"
printf 'program nh(output);\ntype q = record a, b: integer end;\nvar g, h: record x: integer; c: q end;\nbegin\n  g.c.a := 4; g.c.b := 5; h.c.a := g.c.b; h.c.b := g.c.a + h.c.a;\n  writeln(h.c.a, h.c.b)\nend.\n' > "$T/nh.pas"
printf 'program nn(output);\ntype q = record a, b: integer end; w = record x: integer; c: q end;\nvar g: w;\nbegin\n  g.x := 1; g.c.a := 42; g.c.b := 7;\n  writeln(g.x, g.c.a, g.c.b)\nend.\n' > "$T/nn.pas"
for p in na nc nw nh nn; do
  ( cd "$T" && "$FPC" -Miso -v0 -o$p.fpc $p.pas >/dev/null 2>&1 ) || { echo "⛔ GATE REFUSE(2) [$G]: fpc -Miso would not compile $p"; exit 2; }
  ( cd "$T" && timeout -k 5 20s ./$p.fpc </dev/null >"$T/$p.want" 2>/dev/null ) || { echo "⛔ GATE REFUSE(2) [$G]: fpc -Miso's $p did not run to rc 0"; exit 2; }
  [ -n "${FAIL_ONCE:-}" ] && [ $p = nn ] && echo "corrupted by FAIL_ONCE" >> "$T/$p.want"
  for m in m3 m4; do run $m $p; rc=$?
    if [ "$rc" = 0 ] && cmp -s "$T/$p.want" "$T/o"; then echo "  arm $p $m: byte-identical to fpc -Miso"
    else echo "  ⛔ arm $p $m FAILED: rc=$rc"; echo "      want: $(od -c "$T/$p.want" | head -2 | tr -s ' ' | tr '\n' '|')"; echo "      got : $(od -c "$T/o" | head -2 | tr -s ' ' | tr '\n' '|')"; RC=1; fi; done
done
if [ "$RC" = 0 ]; then echo "GATE PASS [$G]: a record-typed field of an anonymous record variable is selected, assigned and written, directly, through with and between two variables, both modes"
else echo "GATE FAIL(1) [$G]: examined 5 arms in 2 modes"; fi
echo "    tree: SCRIP=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY)" \
     " oracle: $FPC $($FPC -iV 2>/dev/null)  measured $(date -u +%Y-%m-%dT%H:%MZ)"
exit $RC
