#!/usr/bin/env bash
# test_gate_pas_a_with_statement_evaluates_its_record_once_at_entry.sh -- the record-variable of a with-statement is accessed once, before the statement, and every field name in the body refers to that record however the body changes the pointer or the index (ISO 7185 6.8.3.10).
#
# MEASURED 2026-10-09 by hq_pascal against fpc -Miso: `with p^ do begin p := next; writeln(n) end` printed the second record's n where fpc prints the first's, in both modes, because every field reference in the body cloned the selector `p^` and so re-read p; the same for `with a[i] do begin i := 2; n := 5 end`
# (the write went to a[2]), for a nested `with p^, next^`, and for `with g, g.t^ do begin t := nx; ... nx ... end`. Found running Pascal-P5's compiler: pcom's `with gattr, typtr^ do ... typtr := eltype; ... taggedrec(eltype)` read the new record's field, so every tagged record behind a pointer got the plain
# `chka` check where the native compiler emits `ckla`, and the P-code differed from the native compiler's.
# CURE (pascal.y only; no new global): pas_with_capture rewrites the selector of each with element so that the pointer of a dereference and the index of an array element are read once into hidden per-routine locals (__pas_wpN, pas_local_add, so a recursive routine's activations do not share them;
# a pointer temporary is registered with the target record type so the field names still resolve) before the statement; pas_with_finish emits those assignments ahead of the body. The original selector stays on the with stack for the 6.5.4 dispose check.
#
# ARMS, both modes: two controls cut LIVE from fpc -Miso that must be byte-identical: a list walk that moves the pointer inside `with p^`, an array element whose index changes inside `with a[i]`, a nested `with p^, next^` and a body that sets the pointer to nil; and a variant record reached through a
# record field that the body reassigns (`with g, g.t^ do begin t := nx; ... end`). FAIL_ONCE=1 corrupts the first control's ref.
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -uo pipefail
G="$(basename "${BASH_SOURCE[0]}" .sh)"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
SCRIP="${SCRIP_BIN:-$ROOT/scrip}"; [ -x "$SCRIP" ] || { echo "⛔ GATE REFUSE(2) [$G]: no scrip at $SCRIP"; exit 2; }
RT_DIR="${RT_DIR:-$ROOT/out}"; [ -f "$RT_DIR/libscrip_rt.so" ] || { echo "⛔ GATE REFUSE(2) [$G]: no runtime at $RT_DIR/libscrip_rt.so"; exit 2; }
FPC="${FPC_BIN:-/usr/bin/fpc}"; [ -x "$FPC" ] || { echo "⛔ GATE REFUSE(2) [$G]: no fpc at $FPC -- every arm's expectation is CUT FROM THE ORACLE"; exit 2; }
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
run() { local m="$1" p="$2"
  if [ "$m" = m3 ]; then ( cd "$T" && timeout -k 5 20s "$SCRIP" --run "$p.pas" </dev/null >"$T/o" 2>"$T/e" ); return $?; fi
  ( cd "$T" && timeout -k 5 20s "$SCRIP" --compile -o "$T/$p.s" "$p.pas" </dev/null >/dev/null 2>&1 && cc -m64 -no-pie "$p.s" -o "$p.m4" -L"$RT_DIR" -lscrip_rt -lm -Wl,-rpath,"$RT_DIR" >/dev/null 2>&1 ) || { echo "  ⛔ $p m4: did not compile or link"; return 99; }
  ( cd "$T" && timeout -k 5 20s "./$p.m4" </dev/null >"$T/o" 2>"$T/e" ); return $?; }
fpcrun() { ( cd "$T" && "$FPC" -Miso -v0 -o"$1.fpc" $1.pas >/dev/null 2>&1 ) || { echo "⛔ GATE REFUSE(2) [$G]: fpc -Miso would not compile $1"; exit 2; }; ( cd "$T" && timeout -k 5 20s ./$1.fpc </dev/null >"$T/$1.want" 2>/dev/null ); echo $?; }
cat > "$T/tctl1.pas" <<'PAS'
program tctl1(output);
type rp = ^rec;
     rec = record n: integer; next: rp end;
var head, p: rp; a: array[1..3] of rec; i: integer;
begin
  new(head); head^.n := 1; new(head^.next); head^.next^.n := 2; head^.next^.next := nil;
  p := head;
  with p^ do begin p := next; writeln(n); n := 10; writeln(p^.n) end;
  writeln(head^.n, ' ', head^.next^.n);
  a[1].n := 7; a[2].n := 8; i := 1;
  with a[i] do begin i := 2; writeln(n); n := 5 end;
  writeln(a[1].n, ' ', a[2].n);
  p := head;
  with p^, next^ do begin p := nil; writeln(n) end;
  p := head;
  with p^ do begin p := nil; n := 99 end;
  writeln(head^.n)
end.
PAS
cat > "$T/tctl2.pas" <<'PAS'
program tctl2(output);
type e = (ea, eb);
     sp = ^st;
     st = record case f: e of ea: (nx: sp); eb: (v: integer) end;
     attr = record t: sp; k: integer end;
var g: attr; q, r: sp;
begin
  new(q, ea); new(r, eb); q^.f := ea; r^.f := eb; q^.nx := r; r^.v := 42; g.t := q; g.k := 3;
  with g, g.t^ do begin t := nx; if nx = r then writeln('same') else writeln('different'); k := 4 end;
  writeln(g.k);
  if g.t = r then writeln('moved') else writeln('stayed')
end.
PAS
RC=0; N=0
for c in tctl1 tctl2; do
  frc=$(fpcrun $c)
  if [ -n "${FAIL_ONCE:-}" ] && [ "$c" = tctl1 ]; then echo "corrupted by FAIL_ONCE" >> "$T/$c.want"; fi
  for m in m3 m4; do run $m $c; rc=$?; N=$((N + 1))
    if [ "$rc" = "$frc" ] && cmp -s "$T/$c.want" "$T/o"; then echo "  $c $m: rc=$rc, stdout byte-identical to fpc ($(wc -l < "$T/o") lines)"
    else echo "  ⛔ $c $m FAILED: rc=$rc (fpc $frc)"; diff "$T/$c.want" "$T/o" | head -6 | sed 's/^/      /'; echo "      err : $(head -1 "$T/e" | cut -c1-140)"; RC=1; fi
  done
done
if [ "$RC" = 0 ]; then echo "GATE PASS [$G]: a with-statement reads its record once, as fpc does, $N of $N arms"
else echo "GATE FAIL(1) [$G]: examined 2 programs in 2 modes"; fi
exit $RC
