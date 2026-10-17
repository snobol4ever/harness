#!/usr/bin/env bash
# test_gate_pas_a_value_assigned_through_a_pointer_is_compatible_with_its_domain_type.sh -- ISO 7185 6.8.2.2, 6.4.6, 6.2.2.9: `p^ := v` needs v assignment-compatible with the domain type of p (PAT iso7185prt1820, backwards association).
#
# MEASURED 2026-10-08 by hq_pascal: `var cp: ^char; begin new(cp); cp^ := 1 end` compiled and ran rc 0; fpc -Miso refuses it (Incompatible types: got ShortInt expected Char). pas_value_compat classified only a plain
# variable on the left, so every assignment through a dereference was unchecked. PAT 1820 is that gap: inside a procedure whose type-definition-part reads `type b = ^a; a = char;` the domain of b is the LATER a
# (6.2.2.9, 6.4.1, backwards association), so `cp^ := 1` is an integer given to a char. CURE: pascal.y pas_deref_assign_compat, called beside pas_value_compat for an assignment whose left side is a dereference;
# the domain type's class comes from pas_typename_class (the alias-chain walk pas_var_decl_class already did, now shared) and the right side's from pas_expr_lit_class, plus a TT_ILIT into a char domain,
# which no legal program writes. The alias table answers with the most recent definition of the domain name, which is the later one in the same part -- the backwards association itself.
# SAME LANDING, the same class lookup: writeln(p^) of a char domain printed the ordinal (120 for x) and of a boolean domain printed 1, because pas_is_charexpr and pas_is_boolexpr had no dereference arm; both now ask
# pas_typename_class of the pointer target, and the control prints a char and a boolean through a pointer.
# LIMIT, not graded: a pointer TYPE declared in an outer block whose domain name is redefined in an inner block resolves to the inner definition at the use site; the arms avoid that shape.
#
# ARMS, both modes: four fault programs (a char domain given an integer, the same through a type alias, PAT 1820's backward association, a boolean-valued literal into a char domain) must be REFUSED at compile time
# naming 6.8.2.2 with empty stdout; a control cut LIVE from fpc -Miso (every legal pointee class assigned a legal literal, a record domain, a forward domain defined later in the same part, an outer domain with no
# redefinition) must run byte-identical. FAIL_ONCE=1 corrupts the control's ref.
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
cat > "$T/fchar.pas" <<'PAS'
program fchar(output);
type pc = ^char;
var cp: pc;
begin new(cp); cp^ := 1; writeln('x') end.
PAS
cat > "$T/falias.pas" <<'PAS'
program falias(output);
type a = char; b = ^a;
var cp: b;
begin new(cp); cp^ := 1; writeln('x') end.
PAS
cat > "$T/fback.pas" <<'PAS'
program fback(output);
type a = integer;
var k: a;
procedure b;
type b = ^a;
     a = char;
var cp: b;
begin new(cp); cp^ := 1 end;
begin k := 1; b end.
PAS
cat > "$T/fnum.pas" <<'PAS'
program fnum(output);
const n = 66;
type pc = ^char;
var cp: pc;
begin new(cp); cp^ := n; writeln('x') end.
PAS
cat > "$T/tctl.pas" <<'PAS'
program tctl(output);
type a = integer; pa = ^a; pc = ^char; pr = ^real; pb = ^boolean;
     rec = record n: integer; c: char end; prec = ^rec;
     later = ^item; item = record v: integer; nxt: later end;
var ip: pa; cp: pc; rp: pr; bp: pb; rr: prec; lp: later;
procedure inner;
type q = ^a;
var ip2: q;
begin new(ip2); ip2^ := 7; writeln(ip2^) end;
begin
  new(ip); ip^ := 5; writeln(ip^);
  new(cp); cp^ := 'x'; writeln(cp^);
  new(rp); rp^ := 2; writeln(rp^:5:1);
  new(bp); bp^ := true; writeln(bp^);
  new(rr); rr^.n := 3; rr^.c := 'z'; writeln(rr^.n, rr^.c);
  new(lp); lp^.v := 9; lp^.nxt := nil; writeln(lp^.v);
  inner
end.
PAS
RC=0; N=0
for p in fchar falias fback fnum; do
  for m in m3 m4; do
    if [ $m = m3 ]; then run m3 $p; rc=$?; else ( cd "$T" && timeout -k 5 20s "$SCRIP" --compile -o "$T/$p.s" "$p.pas" </dev/null >"$T/o" 2>"$T/e" ); rc=$?; fi; N=$((N + 1))
    if [ "$rc" != 0 ] && [ ! -s "$T/o" ] && grep -q "ISO 7185 6.8.2.2 violation: the variable referenced through a pointer of the domain type" "$T/e"; then echo "  $p $m: refused naming 6.8.2.2 (rc=$rc)"
    else echo "  ⛔ $p $m FAILED: rc=$rc stdout=[$(head -c 60 "$T/o" | tr '\n' '|')] err=[$(head -c 100 "$T/e")]"; RC=1; fi
  done
done
c=tctl
frc=$(fpcrun $c)
if [ -n "${FAIL_ONCE:-}" ]; then echo "corrupted by FAIL_ONCE" >> "$T/$c.want"; fi
for m in m3 m4; do run $m $c; rc=$?; N=$((N + 1))
  if [ "$rc" = "$frc" ] && cmp -s "$T/$c.want" "$T/o"; then echo "  $c $m: rc=$rc, stdout byte-identical to fpc ($(wc -l < "$T/o") lines)"
  else echo "  ⛔ $c $m FAILED: rc=$rc (fpc $frc)"; diff "$T/$c.want" "$T/o" | head -6 | sed 's/^/      /'; echo "      err : $(head -1 "$T/e" | cut -c1-140)"; RC=1; fi
done
if [ "$RC" = 0 ]; then echo "GATE PASS [$G]: a value given through a pointer is compatible with the domain type and a legal program runs as fpc, $N of $N arms"
else echo "GATE FAIL(1) [$G]: examined 5 programs in 2 modes"; fi
exit $RC
