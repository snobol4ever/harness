#!/usr/bin/env bash
# test_gate_pas_an_anonymous_record_variable_borrows_no_declared_record_type.sh -- a record variable declared with its own record-type
# (no type-identifier) keeps its own field types: a field declared integer is written as an integer (ISO 7185 6.4.3.3, 6.9.3)
#
# MEASURED 2026-09-26 by hq_pascal, both modes, row pascal-every-suite-to-100-under-nonet-ceo-1266. FOUND BY PROBING, NOT BY ANY SUITE:
# after type q = record c: char; n: integer end, the program var r: record i: integer; j: integer end; r.i := 5; writeln(r.i) printed
# byte 0x05 where fpc -Miso prints 5, and with r do writeln(i) printed 'A' for 65. pas_with_sel_rtype, asked the record type of a record
# variable, fell back to g_pas_rectypes[0] -- the FIRST record type declared anywhere -- when no declared type's fields matched the
# variable's, and the field-selector rule (and the with-statement) then took that type's per-index char flags. The cure answers no type
# when none matches; a declared type whose fields do match is still found (arm rm).
#
# ARMS, both modes, each run byte-identical to fpc -Miso: (1) ra -- r.i and r.j of an anonymous record after q; (2) rw -- the same through
# with-statements; (3) rm -- an anonymous record whose fields match q's names, beside a variable of type q, direct and through with;
# (4) rp -- an anonymous record beside a pointer to q. It FAILS on the parent (arms ra/rw/rp). FAIL_ONCE=1 corrupts arm rm's ref.
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
  ( cd "$T" && timeout -k 5 20s "$SCRIP" --compile -o "$T/$p.s" "$p.pas" </dev/null >"$T/o" 2>"$T/e" ) || return $?
  ( cd "$T" && cc -m64 -no-pie "$p.s" -o "$p.m4" -L"$RT_DIR" -lscrip_rt -lm -Wl,-rpath,"$RT_DIR" >/dev/null 2>&1 ) || { echo "  ⛔ $p m4: did not link"; return 99; }
  ( cd "$T" && timeout -k 5 20s "./$p.m4" </dev/null >"$T/o" 2>"$T/e" ); return $?; }
printf 'program ra(output);\ntype q = record c: char; n: integer end;\nvar r: record i: integer; j: integer end;\nbegin\n  r.i := 5; r.j := 6; writeln(r.i, r.j)\nend.\n' > "$T/ra.pas"
printf 'program rw(output);\ntype q = record c: char; n: integer end;\nvar r: record i: integer; j: integer end;\nbegin\n  with r do begin i := 65; j := 66 end;\n  with r do writeln(i, j)\nend.\n' > "$T/rw.pas"
printf 'program rm(output);\ntype q = record c: char; n: integer end;\nvar r: record c: char; n: integer end; x: q;\nbegin\n  r.c := %s; r.n := 7; x.c := %s; x.n := 8;\n  writeln(r.c, r.n, x.c, x.n);\n  with r do writeln(c, n)\nend.\n' "'a'" "'b'" > "$T/rm.pas"
printf 'program rp(output);\ntype q = record c: char end; p = ^q;\nvar r: record i: integer end; v: p;\nbegin\n  new(v); v^.c := %s; r.i := 5; writeln(r.i, v^.c)\nend.\n' "'z'" > "$T/rp.pas"
for p in ra rw rm rp; do
  ( cd "$T" && "$FPC" -Miso -v0 -o$p.fpc $p.pas >/dev/null 2>&1 ) || { echo "⛔ GATE REFUSE(2) [$G]: fpc -Miso would not compile $p"; exit 2; }
  ( cd "$T" && timeout -k 5 20s ./$p.fpc </dev/null >"$T/$p.want" 2>/dev/null ) || { echo "⛔ GATE REFUSE(2) [$G]: fpc -Miso's $p did not run to rc 0"; exit 2; }
  [ -n "${FAIL_ONCE:-}" ] && [ $p = rm ] && echo "corrupted by FAIL_ONCE" >> "$T/$p.want"
  for m in m3 m4; do run $m $p; rc=$?
    if [ "$rc" = 0 ] && cmp -s "$T/$p.want" "$T/o"; then echo "  arm $p $m: byte-identical to fpc -Miso"
    else echo "  ⛔ arm $p $m FAILED: rc=$rc"; echo "      want: $(od -c "$T/$p.want" | head -2 | tr -s ' ' | tr '\n' '|')"; echo "      got : $(od -c "$T/o" | head -2 | tr -s ' ' | tr '\n' '|')"; RC=1; fi; done
done
if [ "$RC" = 0 ]; then echo "GATE PASS [$G]: an anonymous record variable keeps its own field types beside declared record types, direct and through with, both modes"
else echo "GATE FAIL(1) [$G]: examined 4 arms in 2 modes"; fi
echo "    tree: SCRIP=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY)" \
     " oracle: $FPC $($FPC -iV 2>/dev/null)  measured $(date -u +%Y-%m-%dT%H:%MZ)"
exit $RC
