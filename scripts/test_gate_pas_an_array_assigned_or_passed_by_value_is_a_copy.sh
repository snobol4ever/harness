#!/usr/bin/env bash
# test_gate_pas_an_array_assigned_or_passed_by_value_is_a_copy.sh -- an array variable assigned whole, or given to a value formal,
# is a copy: writing the copy leaves the original as it was, for arrays of integers, two-dimensional arrays, arrays of char arrays
# and arrays of records, as fpc -Miso has it (ISO 7185 6.8.2.2, 6.6.3.2; row pascal-p4-self-hosts-under-scrip..., ceo CEO-1311)
#
# MEASURED 2026-09-27 by hq_pascal, both modes. A real (arr_make) array was held by reference: b := a; b[1] := 50 changed a[1], and a
# value formal wrote through to its actual -- which is also what kept arrays of records string-held (one SOH-separated string, so
# every field write rebuilt the whole array: P4's interpreter store is 18000 records). THE CURE: the parser wraps the right side of
# a whole-array assignment and an array actual given to a value formal in __pas_arr_copy, a new block copying bounds and cells
# (by_name_dispatch.c), and an array of records is a real array (pas_array_is_real).
#
# ARMS, both modes, stdout and exit code cut LIVE from fpc -Miso: (1) whole -- b := a, a value procedure and function, a var formal
# still aliasing, a two-dimensional array, an array of packed char arrays; (2) recs -- an array of records assigned whole both ways;
# (3) fwd -- routines declared forward whose bodies repeat no parameter list, called after the body: a var array formal and a var
# record formal still alias and a value array formal still copies. The body's heading registered NO formals, so every call after it
# read each formal as a value formal and the copy was made for a var actual (the record actual lost its variable: rc 134, BOMB
# rt_assign_var); the body now registers the forward heading's formals (pas_scope_fwd_params).
# OPEN, NOT GRADED HERE: a FORMAL of an array-of-records type is not registered as one, so v[1].k inside the routine falls back
# to an unresolved field (prints empty; a var formal writes nothing back) -- on the parent alike, a row of its own.
# FAILS on the parent b6b9308ba in arm (1) in both modes (b := a; b[1] := 50 prints a1=50); arm (3) fails on the batch without the
# forward-formals cure (rc 134 both modes). FAIL_ONCE=1 corrupts arm (2)'s ref.
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -uo pipefail
G="$(basename "${BASH_SOURCE[0]}" .sh)"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
SCRIP="${SCRIP_BIN:-$ROOT/scrip}"; [ -x "$SCRIP" ] || { echo "⛔ GATE REFUSE(2) [$G]: no scrip at $SCRIP"; exit 2; }
RT_DIR="${RT_DIR:-$ROOT/out}"; [ -f "$RT_DIR/libscrip_rt.so" ] || { echo "⛔ GATE REFUSE(2) [$G]: no runtime at $RT_DIR/libscrip_rt.so"; exit 2; }
FPC="${FPC_BIN:-/usr/bin/fpc}"; [ -x "$FPC" ] || { echo "⛔ GATE REFUSE(2) [$G]: no fpc at $FPC -- every arm's expectation is CUT FROM THE ORACLE"; exit 2; }
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
RC=0; N=0
run() { local m="$1" p="$2"
  if [ "$m" = m3 ]; then ( cd "$T" && LD_LIBRARY_PATH="$RT_DIR" timeout -k 5 20s "$SCRIP" --run "$p.pas" </dev/null >"$T/o" 2>"$T/e" ); return $?; fi
  ( cd "$T" && timeout -k 5 20s "$SCRIP" --compile --out="$T/$p.s" "$p.pas" </dev/null >/dev/null 2>&1 && cc -m64 -no-pie "$p.s" -o "$p.m4" -L"$RT_DIR" -lscrip_rt -lm -Wl,-rpath,"$RT_DIR" >/dev/null 2>&1 ) || { echo "  ⛔ $p m4: did not compile and link"; return 125; }
  ( cd "$T" && timeout -k 5 20s "./$p.m4" </dev/null >"$T/o" 2>"$T/e" ); return $?; }
fpcrun() { ( cd "$T" && "$FPC" -Miso -v0 -o"$1.fpc" $1.pas >/dev/null 2>&1 ) || { echo "⛔ GATE REFUSE(2) [$G]: fpc -Miso would not compile $1"; exit 2; }; ( cd "$T" && timeout -k 5 20s ./$1.fpc </dev/null >"$T/$1.want" 2>/dev/null ); echo $?; }
cat > "$T/whole.pas" <<'PAS'
program whole(output);
type arr = array [1..3] of integer;
     mat = array [1..2, 1..2] of integer;
     alpha = packed array [1..4] of char;
     names = array [1..2] of alpha;
var a, b: arr; m, n: mat; x, y: names;
procedure byval(v: arr); begin v[1] := 99; writeln('byval sees ', v[1]:1) end;
procedure byref(var v: arr); begin v[2] := 77 end;
function sum(v: arr): integer; begin v[3] := 0; sum := v[1] + v[2] + v[3] end;
begin
  a[1] := 1; a[2] := 2; a[3] := 3;
  b := a; b[1] := 50; writeln('a1=', a[1]:1, ' b1=', b[1]:1);
  byval(a); writeln('after byval a1=', a[1]:1);
  byref(a); writeln('after byref a2=', a[2]:1);
  writeln('sum=', sum(a):1, ' a3=', a[3]:1);
  m[1, 1] := 1; m[2, 2] := 4; n := m; n[2, 2] := 9; writeln('m22=', m[2, 2]:1, ' n22=', n[2, 2]:1);
  x[1] := 'abcd'; y := x; y[1] := 'wxyz'; writeln('x1=', x[1], ' y1=', y[1])
end.
PAS
cat > "$T/recs.pas" <<'PAS'
program recs(output);
type cell = record k: integer; c: char end;
     cells = array [1..3] of cell;
var s, t: cells; i: integer;
begin
  for i := 1 to 3 do begin t[i].k := i * 10; t[i].c := chr(ord('a') + i) end;
  s := t; s[1].k := 9; s[2].c := 'z';
  writeln('t1=', t[1].k:1, ' t2=', t[2].c, ' s1=', s[1].k:1, ' s2=', s[2].c);
  t := s; t[3].k := 33; writeln('t1=', t[1].k:1, ' t2=', t[2].c, ' t3=', t[3].k:1, ' s3=', s[3].k:1)
end.
PAS
cat > "$T/fwd.pas" <<'PAS'
program fwd(output);
type arr = array [1..3] of integer;
     item = record typ: integer end;
var a: arr; g: item;
procedure setv(var v: arr; x: integer); forward;
procedure keep(v: arr); forward;
function bump(var r: item): integer; forward;
procedure setv; begin v[1] := x end;
procedure keep; begin v[2] := 88; writeln('keep sees ', v[2]:1) end;
function bump; begin r.typ := r.typ + 1; bump := r.typ end;
begin
  a[1] := 1; a[2] := 2; a[3] := 3; g.typ := 4;
  setv(a, 42); writeln('after setv a1=', a[1]:1);
  keep(a); writeln('after keep a2=', a[2]:1);
  writeln('bump=', bump(g):1, ' g=', g.typ:1)
end.
PAS
for p in whole recs fwd; do
  frc=$(fpcrun $p)
  if [ "$p" = recs ] && [ -n "${FAIL_ONCE:-}" ]; then echo "corrupted by FAIL_ONCE" >> "$T/$p.want"; fi
  for m in m3 m4; do run $m $p; rc=$?; N=$((N + 1))
    if [ "$rc" = "$frc" ] && cmp -s "$T/$p.want" "$T/o"; then echo "  $p $m: rc=$rc, stdout byte-identical to fpc -Miso ($(wc -l < "$T/o") lines)"
    else echo "  ⛔ $p $m FAILED: rc=$rc (fpc $frc)"; diff "$T/$p.want" "$T/o" | head -6 | sed 's/^/      /'; echo "      err : $(head -1 "$T/e" | cut -c1-140)"; RC=1; fi; done
done
if [ "$RC" = 0 ]; then echo "GATE PASS [$G]: an array assigned or passed by value is a copy as fpc -Miso makes it, $N of $N program x mode arms"
else echo "GATE FAIL(1) [$G]: examined 3 programs in 2 modes"; fi
echo "    tree: SCRIP=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY)" \
     " oracle: $FPC $($FPC -iV 2>/dev/null)  measured $(date -u +%Y-%m-%dT%H:%MZ)"
exit $RC
