#!/usr/bin/env bash
# test_gate_pas_a_write_reaches_a_routine_in_its_argument_list_after_the_arguments_before_it_have_been_written.sh -- writeln('a', f(1), 'b') writes 'a' BEFORE it calls f,
# so what f itself writes lands between 'a' and f's value: a<f1>2b. SCRIP evaluated every argument first and printed <f1>a2b.
#
# WHY (PasRosetta middle-three-digits: writeln(n:9, ': ', GetMid3dig(Test[i])) where GetMid3dig itself writes 'got too few digits' and returns an empty string; fpc prints
# '        1: got too few digits', SCRIP printed 'got too few digits        1: '): __pas_writeln took all its (value, width) pairs as one call, so a user routine in the list ran
# ahead of every earlier argument. THE CURE (lower_pascal_tree.c, pas_split_writes): a write or writeln whose argument list has a user routine call after another argument is lowered
# as a sequence of write calls cut before each such argument, the original write or writeln last, a file stream repeated in each piece; a list with no such call, or with the call
# first, is one call as before.
#
# MEASURED 2026-10-21 by hq_pascal on the parent against fpc 3.2.2 for middle-three-digits (the lines above). ARMS (both modes, stdout and exit code cut LIVE from fpc): woiso (-Miso:
# a routine that writes, in the middle, at the front, twice in a list, with formatted widths) and woobj ({$mode objfpc}: the same with a string-valued routine, and a file stream written
# with a routine in the list and read back). FAIL_ONCE=1 corrupts woiso's expectation.
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -uo pipefail
G="$(basename "${BASH_SOURCE[0]}" .sh)"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
SCRIP="${SCRIP_BIN:-$ROOT/scrip}"; [ -x "$SCRIP" ] || { echo "⛔ GATE REFUSE(2) [$G]: no scrip at $SCRIP"; exit 2; }
RT_DIR="${RT_DIR:-$ROOT/out}"; [ -f "$RT_DIR/libscrip_rt.so" ] || { echo "⛔ GATE REFUSE(2) [$G]: no runtime at $RT_DIR/libscrip_rt.so"; exit 2; }
FPC="${FPC_BIN:-/usr/bin/fpc}"; [ -x "$FPC" ] || { echo "⛔ GATE REFUSE(2) [$G]: no fpc at $FPC -- every expectation is CUT FROM THE ORACLE"; exit 2; }
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
RC=0; N=0
run() { local m="$1" p="$2"
  if [ "$m" = m3 ]; then ( cd "$T" && LD_LIBRARY_PATH="$RT_DIR" timeout -k 5 20s "$SCRIP" --run "$p.pas" </dev/null >"$T/o" 2>"$T/e" ); return $?; fi
  ( cd "$T" && timeout -k 5 20s "$SCRIP" --compile --out="$T/$p.s" "$p.pas" </dev/null >/dev/null 2>"$T/e" && cc -m64 -no-pie "$p.s" -o "$p.m4" -L"$RT_DIR" -lscrip_rt -lm -Wl,-rpath,"$RT_DIR" >/dev/null 2>&1 ) || { echo "  ⛔ $p m4: did not compile and link ($(head -1 "$T/e" | cut -c1-120))"; return 125; }
  ( cd "$T" && timeout -k 5 20s "./$p.m4" </dev/null >"$T/o" 2>"$T/e" ); return $?; }
fpcrun() { local mode="$2"; mkdir -p "$T/fpc"; ( cd "$T" && "$FPC" $mode -v0 -FE"$T/fpc" -o"$T/$1.fpc" "$T/$1.pas" >/dev/null 2>&1 ) || { echo "⛔ GATE REFUSE(2) [$G]: fpc $mode would not compile $1"; exit 2; }; ( cd "$T" && timeout -k 5 20s "./$1.fpc" </dev/null >"$T/$1.want" 2>/dev/null ); echo $?; }
cat > "$T/woiso.pas" <<'PAS'
program woiso;
var n: integer; r: real;
function noisy(k: integer): integer;
begin
  write('<n', k, '>');
  noisy := k * 2
end;
begin
  n := 5; r := 2.5;
  writeln('a', noisy(1), 'b');
  writeln(n:4, ' ', noisy(2), ' ', r:8:3);
  writeln(r:6:2, noisy(3), noisy(4), n);
  write(noisy(5), 'x', noisy(6)); writeln;
  writeln(noisy(7))
end.
PAS
cat > "$T/woobj.pas" <<'PAS'
{$mode objfpc}
program woobj;
var n: integer; r: real; f: text; s: string;
function noisy(k: integer): integer;
begin
  write('<n', k, '>');
  noisy := k * 2
end;
function tag(s: string): string;
begin
  write('{', s, '}');
  tag := s
end;
begin
  n := 5; r := 2.5;
  writeln('a', noisy(1), 'b');
  writeln(n:4, ' ', tag('t'), ' ', r:8:3);
  writeln(tag('lead'));
  assign(f, 'wo.tmp'); rewrite(f);
  writeln(f, 'f', n:3, ' ', tag('inf'), ' ', noisy(6));
  close(f);
  reset(f); readln(f, s); writeln('read back: ', s); close(f)
end.
PAS
arm() { local p="$1" om="$2" frc
  frc=$(fpcrun "$p" "$om") || exit 2
  if [ -n "${FAIL_ONCE:-}" ] && [ "$p" = woiso ]; then echo "corrupted by FAIL_ONCE" >> "$T/$p.want"; fi
  for m in m3 m4; do run $m "$p"; rc=$?; N=$((N + 1))
    if [ "$rc" = "$frc" ] && cmp -s "$T/$p.want" "$T/o"; then echo "  $p $m: rc=$rc, stdout byte-identical to fpc $om ($(head -1 "$T/o" | cut -c1-40)...)"
    else echo "  ⛔ $p $m FAILED: rc=$rc (fpc $frc)"; diff "$T/$p.want" "$T/o" | head -6 | sed 's/^/      /'; echo "      err : $(head -1 "$T/e" | cut -c1-140)"; RC=1; fi; done; }
arm woiso -Miso
arm woobj -Mobjfpc
if [ "$RC" = 0 ]; then echo "GATE PASS [$G]: a write reaches a routine in its list after the arguments before it have been written, as fpc does, $N of $N arms"
else echo "GATE FAIL(1) [$G]: examined two programs over $N arms"; fi
echo "    tree: SCRIP=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY)" \
     " oracle: $FPC $($FPC -iV 2>/dev/null)  measured $(date -u +%Y-%m-%dT%H:%MZ)"
exit $RC
