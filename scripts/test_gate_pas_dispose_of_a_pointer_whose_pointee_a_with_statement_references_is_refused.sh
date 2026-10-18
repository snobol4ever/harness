#!/usr/bin/env bash
# test_gate_pas_dispose_of_a_pointer_whose_pointee_a_with_statement_references_is_refused.sh -- ISO 7185 6.5.4: it is an error to remove from the set of values of the
# pointer-type the identifying-value of an identified-variable (6.6.5.3) when a reference to the identified-variable exists. A with-statement over p^ holds such a reference
# for the whole of its statement, so dispose(p) inside it is an error.
#
# MEASURED 2026-10-07 by hq_pascal on PAT iso7185prt1874 (dispose(rp) inside with rp^ do): rc 0 in both modes. CURE: mk_call's dispose arm asks pas_with_holds_pointee_of, which
# compares the pointer operand structurally against the pointer of every open `with p^` selector (g_with_stk) and counts a 6.5.4 violation, so nothing is generated.
#
# ARMS, both modes: two fault programs (dispose of the pointer inside its own with, and inside a nested with whose outer selector is the pointer) must be refused with 6.5.4 on
# stderr, rc non-zero and no stdout (fpc -Miso accepts both, so the expectation is the ISO text); and a control cut LIVE from fpc -Miso (dispose after the with has closed,
# dispose of a different pointer inside a with, a with over a plain record variable) that must run byte-identical. FAIL_ONCE=1 corrupts the control's ref.
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -uo pipefail
G="$(basename "${BASH_SOURCE[0]}" .sh)"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
SCRIP="${SCRIP_BIN:-$ROOT/scrip}"; [ -x "$SCRIP" ] || { echo "⛔ GATE REFUSE(2) [$G]: no scrip at $SCRIP"; exit 2; }
RT_DIR="${RT_DIR:-$ROOT/out}"; [ -f "$RT_DIR/libscrip_rt.so" ] || { echo "⛔ GATE REFUSE(2) [$G]: no runtime at $RT_DIR/libscrip_rt.so"; exit 2; }
FPC="${FPC_BIN:-/usr/bin/fpc}"; [ -x "$FPC" ] || { echo "⛔ GATE REFUSE(2) [$G]: no fpc at $FPC -- every arm's expectation is CUT FROM THE ORACLE"; exit 2; }
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
run() { local m="$1" p="$2"
  if [ "$m" = m3 ]; then ( cd "$T" && timeout -k 5 20s "$SCRIP" --run "$p.pas" </dev/null >"$T/o" 2>"$T/e" ); return $?; fi
  : >"$T/o"; ( cd "$T" && timeout -k 5 20s "$SCRIP" --compile -o "$T/$p.s" "$p.pas" </dev/null >/dev/null 2>"$T/e" && cc -m64 -no-pie "$p.s" -o "$p.m4" -L"$RT_DIR" -lscrip_rt -lm -Wl,-rpath,"$RT_DIR" >/dev/null 2>&1 ) || return 99;
  ( cd "$T" && timeout -k 5 20s "./$p.m4" </dev/null >"$T/o" 2>"$T/e" ); return $?; }
fpcrun() { ( cd "$T" && "$FPC" -Miso -v0 -o"$1.fpc" $1.pas >/dev/null 2>&1 ) || { echo "⛔ GATE REFUSE(2) [$G]: fpc -Miso would not compile $1"; exit 2; }; ( cd "$T" && timeout -k 5 20s ./$1.fpc </dev/null >"$T/$1.want" 2>/dev/null ); echo $?; }

cat > "$T/win.pas" <<'PAS'
program win(output);
type r = record i: integer end;
var rp: ^r;
begin
  writeln('before'); new(rp);
  with rp^ do begin rp^.i := 42; dispose(rp) end;
  writeln('after')
end.
PAS
cat > "$T/wnest.pas" <<'PAS'
program wnest(output);
type r = record i: integer end;
var rp, sp: ^r; v: r;
begin
  writeln('before'); new(rp); new(sp);
  with rp^ do with v do begin i := 1; dispose(rp) end;
  writeln('after')
end.
PAS
cat > "$T/ctl.pas" <<'PAS'
program ctl(output);
type r = record i: integer end;
var rp, sp: ^r; v: r;
begin
  new(rp); new(sp); sp^.i := 7;
  with rp^ do i := 42;
  writeln(rp^.i);
  with v do begin i := 5; writeln(i) end;
  with sp^ do begin i := i + 1; dispose(rp); writeln(i) end;
  new(rp); with rp^ do i := 9; writeln(rp^.i); dispose(rp); dispose(sp)
end.
PAS
RC=0; N=0
for m in m3 m4; do
  for p in win wnest; do
    run $m $p; rc=$?; N=$((N + 1))
    if [ "$rc" != 0 ] && [ ! -s "$T/o" ] && grep -q 6.5.4 "$T/e"; then echo "  $p $m: refused with 6.5.4, no output (rc=$rc)"
    else echo "  ⛔ $p $m FAILED: rc=$rc stdout=[$(head -c 60 "$T/o" | tr '\n' '|')] err=[$(head -c 100 "$T/e")]"; RC=1; fi
  done
done
frc=$(fpcrun ctl)
if [ -n "${FAIL_ONCE:-}" ]; then echo "corrupted by FAIL_ONCE" >> "$T/ctl.want"; fi
for m in m3 m4; do run $m ctl; rc=$?; N=$((N + 1))
  if [ "$rc" = "$frc" ] && cmp -s "$T/ctl.want" "$T/o"; then echo "  ctl $m: rc=$rc, stdout byte-identical to fpc -Miso ($(wc -l < "$T/o") lines)"
  else echo "  ⛔ ctl $m FAILED: rc=$rc (fpc $frc)"; diff "$T/ctl.want" "$T/o" | head -6 | sed 's/^/      /'; echo "      err : $(head -1 "$T/e" | cut -c1-140)"; RC=1; fi
done
if [ "$RC" = 0 ]; then echo "GATE PASS [$G]: dispose of a pointer inside a with over its pointee is refused in two forms and a legal control runs as fpc, $N of $N arms"
else echo "GATE FAIL(1) [$G]: examined 3 programs in 2 modes"; fi
echo "    tree: SCRIP=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY)" \
     " oracle: $FPC $($FPC -iV 2>/dev/null)  measured $(date -u +%Y-%m-%dT%H:%MZ)"
exit $RC
