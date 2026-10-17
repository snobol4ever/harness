#!/usr/bin/env bash
# test_gate_pas_a_file_variable_is_not_altered_while_a_reference_to_its_buffer_exists.sh -- ISO 7185 6.5.5: it is an error to alter the value of a file-variable f when a reference to the buffer-variable f^ exists (PAT iso7185prt1706a).
#
# MEASURED 2026-10-08 by hq_pascal: PAT 1706a (`b(a^)` where the var formal's routine does `get(a)`) ran to rc 0 in both modes; fpc -Miso accepts it too, so the expectation is the ISO text, graded as PAT grades a rejection test.
# CURE (lower_pascal.c only, no parser change, no global): lower_call knows the callee's by-reference mask; when an actual of a var formal is a file buffer (__pas_fbuf_get or __pas_tbuf_get of a file variable F) and
# the callee's body (found by name in the routine list) applies get, put, reset or rewrite to F (pas_tree_alters_file), the call lowers to __pas_rterr 6.5.5 naming F and the routine instead of the call. A VALUE formal takes a copy
# and holds no reference; an alteration of ANOTHER file is legal; both are in the control.
# NOT COVERED, written down: a routine reached through a second call, a procedural parameter, and a read or readln that advances F.
#
# ARMS, both modes: five fault programs (get, put, reset of a typed file in a procedure; rewrite in a function called in an expression; get of a text file) must stop with rc != 0, the pre-stop stdout intact and the 6.5.5 diagnostic;
# a control cut LIVE from fpc -Miso (a buffer passed to a routine that only reads it, to one that alters another file, to a value formal whose routine alters the same file, to a function that reads it) must run byte-identical.
# FAIL_ONCE=1 corrupts the control's ref.
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
cat > "$T/tctl.pas" <<'PAS'
program tctl(output);
var a, b2: file of integer;
procedure show(var c: integer); begin writeln(c) end;
procedure other(var c: integer); begin get(b2) end;
procedure byval(c: integer); begin get(a); writeln(c) end;
function fn(var c: integer): integer; begin fn := c * 2 end;
begin
  rewrite(a); a^ := 1; put(a); a^ := 2; put(a); reset(a);
  rewrite(b2); b2^ := 7; put(b2); b2^ := 8; put(b2); reset(b2);
  show(a^); writeln(a^);
  other(a^); writeln(a^, ' ', b2^);
  byval(a^);
  writeln(fn(a^));
  writeln(a^)
end.
PAS
cat > "$T/fget.pas" <<'PAS'
program fget(output);
var a: file of integer;
procedure b(var c: integer); begin get(a) end;
begin rewrite(a); a^ := 1; put(a); reset(a); writeln('before'); b(a^) end.
PAS
cat > "$T/fput.pas" <<'PAS'
program h2(output);
var a: file of integer; x: integer;
procedure b(var c: integer); begin put(a) end;
begin rewrite(a); a^ := 1; put(a); reset(a); writeln('before'); b(a^) end.
PAS
cat > "$T/freset.pas" <<'PAS'
program h3(output);
var a: file of integer; x: integer;
procedure b(var c: integer); begin reset(a) end;
begin rewrite(a); a^ := 1; put(a); reset(a); writeln('before'); b(a^) end.
PAS
cat > "$T/ffunc.pas" <<'PAS'
program h4(output);
var a: file of integer; x: integer;
function fb(var c: integer): integer; begin rewrite(a); fb := 1 end;
begin rewrite(a); a^ := 1; put(a); reset(a); writeln('before'); x := fb(a^) end.
PAS
cat > "$T/ftext.pas" <<'PAS'
program h5(output);
var t: text;
procedure b(var c: char); begin get(t) end;
begin rewrite(t); write(t, 'xy'); reset(t); writeln('before'); b(t^) end.
PAS
RC=0; N=0
frc=$(fpcrun tctl)
if [ -n "${FAIL_ONCE:-}" ]; then echo "corrupted by FAIL_ONCE" >> "$T/tctl.want"; fi
for m in m3 m4; do run $m tctl; rc=$?; N=$((N + 1))
  if [ "$rc" = "$frc" ] && cmp -s "$T/tctl.want" "$T/o"; then echo "  tctl $m: rc=$rc, stdout byte-identical to fpc ($(wc -l < "$T/o") lines)"
  else echo "  ⛔ tctl $m FAILED: rc=$rc (fpc $frc)"; diff "$T/tctl.want" "$T/o" | head -6 | sed 's/^/      /'; echo "      err : $(head -1 "$T/e" | cut -c1-140)"; RC=1; fi
done
for p in fget fput freset ffunc ftext; do
  for m in m3 m4; do run $m $p; rc=$?; N=$((N + 1))
    if [ "$rc" != 0 ] && grep -q "ISO 7185 6.5.5: the file-variable '[a-z]*' is altered by '[a-z]*' while a reference to its buffer-variable exists" "$T/e"; then echo "  $p $m: stopped naming 6.5.5 (rc=$rc, stdout [$(head -c 30 "$T/o" | tr '\n' '|')])"
    else echo "  ⛔ $p $m FAILED: rc=$rc stdout=[$(head -c 60 "$T/o" | tr '\n' '|')] err=[$(head -c 120 "$T/e")]"; RC=1; fi
  done
done
if [ "$RC" = 0 ]; then echo "GATE PASS [$G]: a file-variable is not altered while a reference to its buffer exists and the legal forms run as fpc does, $N of $N arms"
else echo "GATE FAIL(1) [$G]: examined 6 programs in 2 modes"; fi
exit $RC
