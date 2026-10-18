#!/usr/bin/env bash
# test_gate_pas_a_set_held_in_a_record_field_combines_as_a_set.sh -- a set-typed field of a record (an element of an array of
# records, named or anonymous, a record variable, a record through a pointer) is a set to + * - = <> <= >= and in, as fpc -Miso
# has it (ISO 7185 6.7.2.4, 6.7.2.5; row pascal-p4-self-hosts-under-scrip..., ceo CEO-1311)
#
# MEASURED 2026-09-27 by hq_pascal, both modes. pas_is_setexpr knew set variables and set constructors but no field, so with neither
# operand a plain set variable store[sp].vs + store[sp + 1].vs parsed as numeric addition: the program stopped silently rc 1, or,
# inside P4's int.pas, the union kept one operand ([8] + [0 1 2 3 6] gave [8]) and generation 2 reported error 6 at source line 34.
# THE CURE (pascal.y): pas_field_typename reads a field's declared type name back from the node's own shape (the field index of a
# flattened array-of-records access, or of a record or pointer field) and pas_is_settype answers; g_pas_arrrecs keeps each field's
# type name (an anonymous record's recorded rname is the last type name seen, not the record's); each record field's type name
# is scoped to its own type, so a subrange after a set field is not taken for a set; an inline set-of field gets a named set type.
#
# ARMS, both modes, stdout and exit code cut LIVE from fpc -Miso: (1) named -- an array of a named variant record, a record variable;
# (2) anon -- P4's store shape, an array of an anonymous variant record, with = and <=; (3) inline -- set-of fields declared inline in
# a record, a pointer's record and an anonymous array element, beside an integer and a char field.
# FAILS on the parent b6b9308ba in every arm (rc 1, nothing printed). FAIL_ONCE=1 corrupts arm (2)'s ref.
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
  ( cd "$T" && timeout -k 5 20s "$SCRIP" --compile -o "$T/$p.s" "$p.pas" </dev/null >/dev/null 2>&1 && cc -m64 -no-pie "$p.s" -o "$p.m4" -L"$RT_DIR" -lscrip_rt -lm -Wl,-rpath,"$RT_DIR" >/dev/null 2>&1 ) || { echo "  ⛔ $p m4: did not compile and link"; return 125; }
  ( cd "$T" && timeout -k 5 20s "./$p.m4" </dev/null >"$T/o" 2>"$T/e" ); return $?; }
fpcrun() { ( cd "$T" && "$FPC" -Miso -v0 -o"$1.fpc" $1.pas >/dev/null 2>&1 ) || { echo "⛔ GATE REFUSE(2) [$G]: fpc -Miso would not compile $1"; exit 2; }; ( cd "$T" && timeout -k 5 20s ./$1.fpc </dev/null >"$T/$1.want" 2>/dev/null ); echo $?; }
cat > "$T/named.pas" <<'PAS'
program named(output);
type set058 = set of 0..58;
     cell = record case integer of 1: (vi: integer); 2: (vs: set058) end;
var store: array [0..9] of cell; sp, k: integer; r: cell; s: set058;
procedure pr(s: set058); var k: integer; begin for k := 0 to 58 do if k in s then write(k:1, ' '); writeln end;
begin
  store[1].vs := [8]; store[2].vs := [0, 1, 2, 3, 6]; sp := 1;
  store[sp].vs := store[sp].vs + store[sp + 1].vs; pr(store[1].vs);
  store[3].vs := [8]; store[3].vs := store[3].vs + store[2].vs; pr(store[3].vs);
  store[4].vs := [8]; s := store[2].vs; store[4].vs := store[4].vs + s; pr(store[4].vs);
  r.vs := [8]; r.vs := r.vs + store[2].vs; pr(r.vs);
  store[5].vs := [1, 2] * store[2].vs; pr(store[5].vs);
  store[6].vs := store[2].vs - [1]; pr(store[6].vs)
end.
PAS
cat > "$T/anon.pas" <<'PAS'
program anon(output);
type set058 = set of 0..58;
     datatype = (undef, int, sett);
var store: array [0..9] of record case datatype of undef: (); int: (vi: integer); sett: (vs: set058) end;
    sp, k: integer;
begin
  store[1].vs := [8]; store[2].vs := [0, 1, 2, 3, 6]; sp := 1;
  store[sp].vs := store[sp].vs + store[sp + 1].vs;
  for k := 0 to 58 do if k in store[1].vs then write(k:1, ' '); writeln;
  writeln(store[1].vs = store[2].vs, ' ', store[2].vs <= store[1].vs)
end.
PAS
cat > "$T/inline.pas" <<'PAS'
program inline(output);
type rec = record n: integer; s: set of 0..20; c: char end;
     prec = ^rec;
var r, t: rec; p: prec; k: integer; a: array [1..3] of record s: set of 0..20; m: 0..9 end;
begin
  r.s := [1, 2]; t.s := [2, 5]; new(p); p^.s := [7];
  r.s := r.s + t.s; p^.s := p^.s + r.s; r.n := 4; r.c := 'x';
  for k := 0 to 20 do if k in p^.s then write(k:1, ' '); writeln;
  writeln(r.s = [1, 2, 5], ' ', t.s <= r.s, ' ', r.n + 1, ' ', r.c);
  a[1].s := [3]; a[2].s := [4]; a[3].s := a[1].s + a[2].s; a[3].m := 9;
  for k := 0 to 20 do if k in a[3].s then write(k:1, ' '); writeln(a[3].m + 1)
end.
PAS
for p in named anon inline; do
  frc=$(fpcrun $p)
  if [ "$p" = anon ] && [ -n "${FAIL_ONCE:-}" ]; then echo "corrupted by FAIL_ONCE" >> "$T/$p.want"; fi
  for m in m3 m4; do run $m $p; rc=$?; N=$((N + 1))
    if [ "$rc" = "$frc" ] && cmp -s "$T/$p.want" "$T/o"; then echo "  $p $m: rc=$rc, stdout byte-identical to fpc -Miso ($(wc -l < "$T/o") lines)"
    else echo "  ⛔ $p $m FAILED: rc=$rc (fpc $frc)"; diff "$T/$p.want" "$T/o" | head -6 | sed 's/^/      /'; echo "      err : $(head -1 "$T/e" | cut -c1-140)"; RC=1; fi; done
done
if [ "$RC" = 0 ]; then echo "GATE PASS [$G]: a set held in a record field combines as a set as fpc -Miso does, $N of $N program x mode arms"
else echo "GATE FAIL(1) [$G]: examined 3 programs in 2 modes"; fi
echo "    tree: SCRIP=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY)" \
     " oracle: $FPC $($FPC -iV 2>/dev/null)  measured $(date -u +%Y-%m-%dT%H:%MZ)"
exit $RC
