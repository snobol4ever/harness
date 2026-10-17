#!/usr/bin/env bash
# test_gate_pas_a_tag_field_is_not_passed_as_a_variable_parameter.sh -- ISO 7185 6.6.3.3: an actual variable-parameter shall not denote a tag-field of a variant-part (PAT iso7185prt1843).
#
# MEASURED 2026-10-07 by hq_pascal: PAT 1843 (a boolean tag field of a record passed to a var boolean formal) compiled and ran to rc 0 in both modes; fpc -Miso accepts it
# too, so the expectation is the ISO text. CURE: pascal.y's call_with_args runs pas_actual_is_tagfield beside the packed-component check; the variant table (pas_vt) already
# marks the selection node of a tag field (state 7 for a plain variable, 5 through a pointer) and the with-scope rewrite now marks it too (state 8, inert to every other reader), so
# procedure calls and function calls, plain, pointer and with-scope selections are all refused at compile time naming the clause.
#
# ARMS, both modes: five fault programs (a tag of a plain variable, through a pointer, into a function's var formal, inside a with, an enumerated tag) must be refused naming 6.6.3.3
# with empty stdout; a control cut LIVE from fpc -Miso (a fixed field and a variant field passed as var, the tag passed by value to a procedure and a function) must run
# byte-identical. FAIL_ONCE=1 corrupts the control's ref.
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


cat > "$T/tplain.pas" <<'PAS'
program tplain(output);
var r: record case b: boolean of true: (i: integer); false: (c: char) end;
procedure a(var x: boolean); begin x := true end;
begin a(r.b); writeln(r.b) end.
PAS
cat > "$T/tptr.pas" <<'PAS'
program tptr(output);
type rt = record case b: boolean of true: (i: integer); false: (c: char) end;
var p: ^rt;
procedure a(var x: boolean); begin x := true end;
begin new(p); a(p^.b); writeln(p^.b) end.
PAS
cat > "$T/tfunc.pas" <<'PAS'
program tfunc(output);
var r: record case b: boolean of true: (i: integer); false: (c: char) end; v: integer;
function f(var x: boolean): integer; begin x := true; f := 1 end;
begin v := f(r.b); writeln(v) end.
PAS
cat > "$T/twith.pas" <<'PAS'
program twith(output);
var r: record case b: boolean of true: (i: integer); false: (c: char) end;
procedure a(var x: boolean); begin x := true end;
begin with r do a(b); writeln(r.b) end.
PAS
cat > "$T/tenum.pas" <<'PAS'
program tenum(output);
type k = (red, green, blue);
var r: record case t: k of red: (i: integer); green: (c: char); blue: (x: boolean) end;
procedure a(var x: k); begin x := green end;
begin a(r.t); writeln(ord(r.t)) end.
PAS
cat > "$T/tctl.pas" <<'PAS'
program tctl(output);
type k = (red, green, blue);
var r: record n: integer; case t: k of red: (i: integer); green: (c: char); blue: (x: boolean) end;
    q: record case b: boolean of true: (j: integer); false: (d: char) end;
procedure inc1(var x: integer); begin x := x + 1 end;
procedure pv(x: k); begin writeln(ord(x)) end;
function fv(x: boolean): integer; begin if x then fv := 1 else fv := 0 end;
begin
  r.n := 5; inc1(r.n); writeln(r.n);
  r.t := red; r.i := 40; inc1(r.i); writeln(r.i);
  pv(r.t); q.b := true; q.j := 3; writeln(fv(q.b)); inc1(q.j); writeln(q.j)
end.
PAS
RC=0; N=0
for m in m3 m4; do
  for p in tplain tptr tfunc twith tenum; do
    if [ $m = m3 ]; then run m3 $p; rc=$?; else ( cd "$T" && timeout -k 5 20s "$SCRIP" --compile -o "$T/$p.s" "$p.pas" </dev/null >"$T/o" 2>"$T/e" ); rc=$?; fi; N=$((N + 1))
    if [ "$rc" != 0 ] && [ ! -s "$T/o" ] && grep -q "ISO 7185 6.6.3.3 violation: a tag-field" "$T/e"; then echo "  $p $m: refused naming 6.6.3.3 (rc=$rc)"
    else echo "  ⛔ $p $m FAILED: rc=$rc stdout=[$(head -c 60 "$T/o" | tr '\n' '|')] err=[$(head -c 100 "$T/e")]"; RC=1; fi
  done
done
for c in tctl; do
  frc=$(fpcrun $c)
  if [ -n "${FAIL_ONCE:-}" ]; then echo "corrupted by FAIL_ONCE" >> "$T/$c.want"; fi
  for m in m3 m4; do run $m $c; rc=$?; N=$((N + 1))
    if [ "$rc" = "$frc" ] && cmp -s "$T/$c.want" "$T/o"; then echo "  $c $m: rc=$rc, stdout byte-identical to fpc ($(wc -l < "$T/o") lines)"
    else echo "  ⛔ $c $m FAILED: rc=$rc (fpc $frc)"; diff "$T/$c.want" "$T/o" | head -6 | sed 's/^/      /'; echo "      err : $(head -1 "$T/e" | cut -c1-140)"; RC=1; fi
  done
done
if [ "$RC" = 0 ]; then echo "GATE PASS [$G]: a tag-field passed as a variable parameter is refused and a legal program runs as fpc, $N of $N arms"
else echo "GATE FAIL(1) [$G]: examined 6 programs in 2 modes"; fi
echo "    tree: SCRIP=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY)" \
     " oracle: $FPC $($FPC -iV 2>/dev/null)  measured $(date -u +%Y-%m-%dT%H:%MZ)"
exit $RC
