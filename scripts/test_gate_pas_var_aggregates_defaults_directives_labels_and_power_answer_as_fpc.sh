#!/usr/bin/env bash
# test_gate_pas_var_aggregates_defaults_directives_labels_and_power_answer_as_fpc.sh -- the second FPC parse tail (the dialects row
# pascal-dialects-...-ceo-1614, chunk 9), each construct as fpc in its own mode answers, and the ISO label rule kept.
#
# MEASURED 2026-10-11 by hq_pascal on SCRIP 41d9afcd3: among PasRosetta's parse stops were aggregate var initializers (about 15), empty
# () in routine headings, default parameter values, routine directives (inline), identifier labels, and **.
# THE DIALECT, each measured:
#   - fpc -Miso accepts var x: T = (aggregate), () headings and exit(value), so ISO takes them.
#   - fpc -Miso and -Mfpc refuse default parameters and -Mobjfpc accepts them, so they flip to objfpc.
#   - fpc -Miso refuses the inline directive, so routine directives flip to fpc.
#   - ** exists only through the math unit's overloads (fpc), and is left-associative: 2 ** 3 ** 2 = 64.
#   - Identifier labels: fpc -Miso accepts them, but ISO 7185 6.1.6 says a label is a digit-sequence, and PAT's rejection tests
#     iso7185prt0015 and prt1760 require the refusal (CEO-1225, ISO as oracle). So an identifier label is refused with 6.1.6 in an ISO
#     program and accepted once the dialect is fpc or objfpc.
# THE LOWERING:
#   - A var aggregate initializer expands through chunk 4's pas_agg_assign.
#   - Defaults are recorded per routine and parameter index by a pre-pass and appended to calls that stop short: E_call_with_args, a
#     bare procedure call, and a bare function in an expression.
#   - A directive is accepted and dropped.
#   - An identifier label keys its definition above the ISO range and keeps its own name.
#   - ** is __pas_pow: an integer power for integer operands, else pow.
#
# ARMS, both modes, every expectation cut LIVE from fpc in the arm's own mode: varagg, emptyparens and exitval (-Miso);
# defaults_objfpc and defaults_flip (-Mobjfpc); labels_fpc (-Mfpc); power (-Mobjfpc). Two ISO controls refused with 6.1.6:
# label_iso and prt1760. FAIL_ONCE=1 corrupts arm varagg.
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -uo pipefail
G="$(basename "${BASH_SOURCE[0]}" .sh)"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
SCRIP="${SCRIP_BIN:-$ROOT/scrip}"; [ -x "$SCRIP" ] || { echo "⛔ GATE REFUSE(2) [$G]: no scrip at $SCRIP"; exit 2; }
RT_DIR="${RT_DIR:-$ROOT/out}"; [ -f "$RT_DIR/libscrip_rt.so" ] || { echo "⛔ GATE REFUSE(2) [$G]: no runtime at $RT_DIR/libscrip_rt.so"; exit 2; }
FPC="${FPC_BIN:-/usr/bin/fpc}"; [ -x "$FPC" ] || { echo "⛔ GATE REFUSE(2) [$G]: no fpc at $FPC -- every arm's expectation is CUT FROM THE ORACLE"; exit 2; }
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
run() { local m="$1" p="$2"
  if [ "$m" = m3 ]; then ( cd "$T" && timeout -k 5 60s "$SCRIP" --run "$p.pas" </dev/null >"$T/o" 2>"$T/e" ); return $?; fi
  ( cd "$T" && timeout -k 5 60s "$SCRIP" --compile --out="$T/$p.s" "$p.pas" </dev/null >/dev/null 2>"$T/e" && cc -m64 -no-pie "$p.s" -o "$p.m4" -L"$RT_DIR" -lscrip_rt -lm -Wl,-rpath,"$RT_DIR" >/dev/null 2>&1 ) || { echo "  ⛔ $p m4 did not compile or link: $(head -1 "$T/e" | cut -c1-120)" >&2; return 99; }
  ( cd "$T" && timeout -k 5 60s "./$p.m4" </dev/null >"$T/o" 2>"$T/e" ); return $?; }
want() { ( cd "$T" && "$FPC" -M$3 -v0 -o"$1.fpc" $2.pas >/dev/null 2>&1 ) || { echo "⛔ GATE REFUSE(2) [$G]: fpc -M$3 would not compile $2"; exit 2; }; ( cd "$T" && timeout -k 5 60s ./$1.fpc </dev/null >"$T/$1.want" 2>/dev/null ); echo $? > "$T/$1.wrc"; }
cat > "$T/varagg.pas" <<'PAS'
program vi(output);
var a: array [1..3] of integer = (4, 5, 6);
begin writeln(a[2]) end.
PAS
cat > "$T/emptyparens.pas" <<'PAS'
program ep(output);
procedure p(); begin writeln('p') end;
function f(): integer; begin f := 3 end;
begin p(); writeln(f()) end.
PAS
cat > "$T/exitval.pas" <<'PAS'
program ex(output);
function f(n: integer): integer; begin if n > 0 then exit(n * 2); f := 0 end;
begin writeln(f(3), f(-1)) end.
PAS
cat > "$T/defaults_objfpc.pas" <<'PAS'
{$mode objfpc}
program dp3;
const K = 7;
type TV = record x, y, z: integer end;
var a: array [1..3] of integer = (4, 5, 6); v: TV = (x: 3; y: 4; z: 5); m: array [0..1, 0..1] of integer = ((1, 2), (3, 4));
procedure p(n: integer = 5; s: integer = K * 2); begin writeln(n, ' ', s) end;
function f(base: integer = 10): integer; inline; begin f := base * 2 end;
procedure q(); begin writeln('q') end;
begin p; p(1); p(1, 2); writeln(f, ' ', f(3)); q(); writeln(a[3], v.y, m[1, 0]) end.
PAS
cat > "$T/defaults_flip.pas" <<'PAS'
program dp3;
const K = 7;
type TV = record x, y, z: integer end;
var a: array [1..3] of integer = (4, 5, 6); v: TV = (x: 3; y: 4; z: 5); m: array [0..1, 0..1] of integer = ((1, 2), (3, 4));
procedure p(n: integer = 5; s: integer = K * 2); begin writeln(n, ' ', s) end;
function f(base: integer = 10): integer; inline; begin f := base * 2 end;
procedure q(); begin writeln('q') end;
begin p; p(1); p(1, 2); writeln(f, ' ', f(3)); q(); writeln(a[3], v.y, m[1, 0]) end.
PAS
cat > "$T/labels_fpc.pas" <<'PAS'
{$mode fpc}
program lb2f;
label up, 10, done;
var i: integer;
procedure p; label inner; var k: integer; begin k := 0; inner: k := k + 1; if k < 3 then goto inner; writeln('p', k) end;
begin i := 0; up: i := i + 1; if i < 3 then goto up; 10: writeln(i); p; goto done; writeln('skipped'); done: writeln('end') end.
PAS
cat > "$T/power.pas" <<'PAS'
{$mode objfpc}
program pw;
uses math;
var n: integer; x: real;
begin
  n := 3; x := 2.0;
  writeln(n ** 2, ' ', 2 ** 10, ' ', (x ** 3):0:2, ' ', -2 ** 2, ' ', 2 ** 3 ** 2, ' ', (n mod 10) ** 2, ' ', (2.0 ** 0.5):0:6)
end.
PAS
cat > "$T/label_iso.pas" <<'PAS'
program lb2(output);
label up, 10, done;
var i: integer;
procedure p; label inner; var k: integer; begin k := 0; inner: k := k + 1; if k < 3 then goto inner; writeln('p', k) end;
begin i := 0; up: i := i + 1; if i < 3 then goto up; 10: writeln(i); p; goto done; writeln('skipped'); done: writeln('end') end.
PAS
cat > "$T/prt1760.pas" <<'PAS'
program prt1760(output);
label skip;
begin goto skip; writeln('*** Should not execute this'); skip: writeln('At label') end.
PAS
sed -e '1i {$mode objfpc}' "$T/defaults_flip.pas" > "$T/defaults_flip_oracle.pas"
RC=0; N=0
chk() { local m="$1" p="$2" frc; frc=$(cat "$T/$p.wrc"); run $m $p; local rc=$?; N=$((N + 1))
  if [ "$rc" = "$frc" ] && cmp -s "$T/$p.want" "$T/o"; then echo "  $p $m: rc=$rc, stdout byte-identical to fpc ($(wc -l < "$T/o") lines)"
  else echo "  ⛔ $p $m FAILED: rc=$rc (fpc $frc)"; diff "$T/$p.want" "$T/o" | head -6 | sed 's/^/      /'; echo "      err : $(head -1 "$T/e" | cut -c1-140)"; RC=1; fi; }
want varagg varagg iso; want emptyparens emptyparens iso; want exitval exitval iso; want defaults_objfpc defaults_objfpc objfpc
want defaults_flip defaults_flip_oracle objfpc; want labels_fpc labels_fpc fpc; want power power objfpc
if [ -n "${FAIL_ONCE:-}" ]; then echo "corrupted by FAIL_ONCE" >> "$T/varagg.want"; fi
for m in m3 m4; do for p in varagg emptyparens exitval defaults_objfpc defaults_flip labels_fpc power; do chk $m $p; done; done
refuse() { local p="$1"; ( cd "$T" && timeout -k 5 60s "$SCRIP" --run "$p.pas" </dev/null >"$T/o" 2>"$T/e" ); local rc=$?; N=$((N + 1))
  if [ "$rc" != 0 ] && [ ! -s "$T/o" ] && grep -q '6\.1\.6' "$T/e"; then echo "  $p: refused at compile time with 6.1.6 (rc=$rc)"
  else echo "  ⛔ $p FAILED: rc=$rc, want the ISO 6.1.6 refusal: stdout=[$(head -c 60 "$T/o" | tr '\n' '|')] err=[$(head -c 140 "$T/e")]"; RC=1; fi; }
refuse label_iso; refuse prt1760
if [ "$RC" = 0 ]; then echo "GATE PASS [$G]: the second FPC parse tail answers as fpc and the ISO label rule holds, both modes, $N of $N arms"
else echo "GATE FAIL(1) [$G]: see the arms above"; fi
echo "    tree: SCRIP=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY)" \
     " oracle: $FPC $($FPC -iV 2>/dev/null)  measured $(date -u +%Y-%m-%dT%H:%MZ)"
exit $RC
