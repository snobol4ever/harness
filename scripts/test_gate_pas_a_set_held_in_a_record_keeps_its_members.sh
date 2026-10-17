#!/usr/bin/env bash
# test_gate_pas_a_set_held_in_a_record_keeps_its_members.sh -- a set stored in a field of a heap record, or in a field of an element
# of an array of records, keeps its members, as fpc -Miso does (row pascal-p4-self-hosts-under-scrip..., ceo CEO-1311)
#
# MEASURED 2026-09-27 by hq_pascal, both modes. A Pascal set is a 32-byte bitmap; a heap record and an array of records are held as
# one string of SOH-separated fields, and their writers flattened each value with to_cstring/strlen, so a bitmap was cut at its first
# NUL byte (a byte 0x01 would split the record) and read back as the empty set. P4's compiler stores every set constant with
# new(lvp,pset); lvp^.pval := cstpart, so generation 1 wrote all 154 of them as ldc() -- the only difference from the fpc-built
# reference P-code -- and P4's interpreter stores them in store[scp].vs and searches the table with store[q].vs = s, which failed,
# and the failure left its procedure before readln, so the next P-code line was read one character early.
# THE CURE, Pascal's own nodes only: the five __pas_* record writers flatten through pas_cell_cstring, which writes a set bitmap that
# holds a NUL or SOH as ESC plus 64 hex digits; a set assigned into an element of a string-held array is wrapped in __pas_set_cell,
# the same encoding; pas_set_bits, the one decoder every set operator already uses, reads it. The shared arr_set_pure is untouched.
# FOUND BY THIS GATE'S OWN ARMS AND CURED WITH IT: (a) a field copied between two elements of an array of records was taken for a
# whole-element span copy, its already-flattened index multiplied by the record width again (store[13].vs := store[12].vs wrote slot
# 54 of a 42-slot array; store[j].vi := store[i].vi copied nothing) -- pas_arrrec_flatten now marks the node it builds as a field
# access; (b) the range constructor [a..b] (__pas_setrange) was not a set expression, so p^.s <= [1..5] compared numbers (error 102).
#
# ARMS, both modes, stdout and exit code cut LIVE from fpc -Miso: (1) hrec -- a set in a heap variant record's field, read directly,
# through with, through an array of pointers, copied to a set variable, and stored from a constructor; (2) arec -- P4's interpreter's
# store: a set in an array of variant records, compared, searched with repeat..until, copied cell to cell, tested with in.
# FAILS on the parent 964982d54 in both arms. FAIL_ONCE=1 corrupts arm (2)'s ref.
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -uo pipefail
G="$(basename "${BASH_SOURCE[0]}" .sh)"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
SCRIP="${SCRIP_BIN:-$ROOT/scrip}"; [ -x "$SCRIP" ] || { echo "⛔ GATE REFUSE(2) [$G]: no scrip at $SCRIP"; exit 2; }
RT_DIR="${RT_DIR:-$ROOT/out}"; [ -f "$RT_DIR/libscrip_rt.so" ] || { echo "⛔ GATE REFUSE(2) [$G]: no runtime at $RT_DIR/libscrip_rt.so"; exit 2; }
FPC="${FPC_BIN:-/usr/bin/fpc}"; [ -x "$FPC" ] || { echo "⛔ GATE REFUSE(2) [$G]: no fpc at $FPC -- every arm's expectation is CUT FROM THE ORACLE"; exit 2; }
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
RC=0; N=0
run() { local m="$1" p="$2"
  if [ "$m" = m3 ]; then ( cd "$T" && LD_LIBRARY_PATH="$RT_DIR" timeout -k 5 20s "$SCRIP" --run "$p.pas" </dev/null >"$T/o" 2>"$T/e" ); return $?; fi
  ( cd "$T" && timeout -k 5 20s "$SCRIP" --compile -o "$T/$p.s" "$p.pas" </dev/null >/dev/null 2>&1 && cc -m64 -no-pie "$p.s" -o "$p.m4" -L"$RT_DIR" -lscrip_rt -lm -Wl,-rpath,"$RT_DIR" >/dev/null 2>&1 ) || { echo "  ⛔ $p m4: did not compile and link"; return 125; }
  ( cd "$T" && timeout -k 5 20s "./$p.m4" </dev/null >"$T/o" 2>"$T/e" ); return $?; }
fpcrun() { ( cd "$T" && "$FPC" -Miso -v0 -o"$1.fpc" $1.pas >/dev/null 2>&1 ) || { echo "⛔ GATE REFUSE(2) [$G]: fpc -Miso would not compile $1"; exit 2; }; ( cd "$T" && timeout -k 5 20s ./$1.fpc </dev/null >"$T/$1.want" 2>/dev/null ); echo $?; }
cat > "$T/hrec.pas" <<'PAS'
program hrec(output);
const setlow = 0; sethigh = 63;
type setlohi = set of setlow..sethigh;
     cstclass = (reel, pset, strg);
     csp = ^constant;
     constant = record case cclass: cstclass of
                  reel: (rval: packed array [1..8] of char);
                  pset: (pval: setlohi);
                  strg: (slgth: 0..8; sval: packed array [1..8] of char)
                end;
var lvp: csp; cstpart, s2: setlohi; k: integer; cstptr: array [1..4] of csp;
procedure show(tag: char; s: setlohi);
  var k: integer;
begin write(tag, '('); for k := setlow to sethigh do if k in s then write(k:3); writeln(')') end;
begin
  cstpart := [2, 3];
  new(lvp, pset); lvp^.pval := cstpart; lvp^.cclass := pset;
  write('a('); for k := setlow to sethigh do if k in lvp^.pval then write(k:3); writeln(')');
  with lvp^ do begin write('b('); for k := setlow to sethigh do if k in pval then write(k:3); writeln(')') end;
  cstptr[2] := lvp;
  with cstptr[2]^ do begin write('c('); for k := setlow to sethigh do if k in pval then write(k:3); writeln(')') end;
  s2 := lvp^.pval; show('d', s2);
  new(lvp, pset); lvp^.pval := [0, 9, 12, 63]; show('e', lvp^.pval);
  writeln('eq ', lvp^.pval = [0, 9, 12, 63], ' ', cstptr[2]^.pval = cstpart, ' ', cstptr[2]^.pval <= [1..5])
end.
PAS
cat > "$T/arec.pas" <<'PAS'
program arec(output);
type set058 = set of 0..58;
     datatype = (undef, int, reel, bool, sett, adr, mark, car);
var store: array [0..20] of record case datatype of
                               undef: ();
                               int: (vi: integer);
                               reel: (vr: real);
                               bool: (vb: boolean);
                               sett: (vs: set058);
                               car: (vc: char);
                               adr: (va: integer);
                               mark: (vm: integer)
                             end;
    s: set058; q, scp, k: integer;
begin
  s := [2, 3]; scp := 11;
  store[scp].vs := s; writeln('eq direct: ', store[scp].vs = s);
  q := 10;
  repeat q := q + 1 until store[q].vs = s;
  writeln('found at q=', q:1);
  store[12].vs := [0, 1, 58]; store[13].vs := store[12].vs;
  write('copied('); for k := 0 to 58 do if k in store[13].vs then write(k:3); writeln(')');
  writeln('in ', 58 in store[13].vs, ' ', 57 in store[13].vs, ' ', store[13].vs = [0, 1, 58])
end.
PAS
for p in hrec arec; do
  frc=$(fpcrun $p)
  if [ "$p" = arec ] && [ -n "${FAIL_ONCE:-}" ]; then echo "corrupted by FAIL_ONCE" >> "$T/$p.want"; fi
  for m in m3 m4; do run $m $p; rc=$?; N=$((N + 1))
    if [ "$rc" = "$frc" ] && cmp -s "$T/$p.want" "$T/o"; then echo "  $p $m: rc=$rc, stdout byte-identical to fpc -Miso ($(wc -l < "$T/o") lines)"
    else echo "  ⛔ $p $m FAILED: rc=$rc (fpc $frc)"; diff "$T/$p.want" "$T/o" | head -6 | sed 's/^/      /'; echo "      err : $(head -1 "$T/e" | cut -c1-140)"; RC=1; fi; done
done
if [ "$RC" = 0 ]; then echo "GATE PASS [$G]: a set held in a record keeps its members as fpc -Miso does, $N of $N program x mode arms"
else echo "GATE FAIL(1) [$G]: examined 2 programs in 2 modes"; fi
echo "    tree: SCRIP=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY)" \
     " oracle: $FPC $($FPC -iV 2>/dev/null)  measured $(date -u +%Y-%m-%dT%H:%MZ)"
exit $RC
