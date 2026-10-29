#!/usr/bin/env bash
# test_gate_pas_a_tag_allocated_variable_is_not_accessed_as_a_whole_variable.sh -- ISO 7185 6.6.5.3: it is an error if a variable created by the second form of
# new, new(p, c1, ..., cn), is accessed by the identified-variable of the variable-access of a factor, of an assignment-statement, or of an actual-parameter.
#
# MEASURED 2026-10-07 by hq_pascal on PAT iso7185prt1871 (factor), 1872 (assignment target) and 1873 (var actual): each ran to rc 0 in both modes. CURE: the
# bit 2 that new(p, c...) already sets in the block's heap-dead flag byte is now read by __pas_tagwhole, which pas_vt_check_of puts in front of a bare
# p^ whose pointer targets a record with a tagged variant part (a factor and an assignment target through the existing wrappers; a var actual by
# moving the check onto the pointer operand so the actual stays an lvalue); p^.field is not a whole-variable access and is untouched.
#
# ARMS, both modes: four fault programs (factor, assignment target, var actual, value actual) each print `before`, then fault -- stdout must be exactly `before`,
# rc non-zero, stderr naming 6.6.5.3 (fpc -Miso does not fault on these, so the expectation is the ISO text); and a control cut LIVE from fpc -Miso (whole use
# of a variable made by the plain new, field use of a tag-allocated one) that must run byte-identical. FAIL_ONCE=1 corrupts the control's ref.
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
  ( cd "$T" && timeout -k 5 20s "$SCRIP" --compile --out="$T/$p.s" "$p.pas" </dev/null >/dev/null 2>&1 && cc -m64 -no-pie "$p.s" -o "$p.m4" -L"$RT_DIR" -lscrip_rt -lm -Wl,-rpath,"$RT_DIR" >/dev/null 2>&1 ) || { echo "  ⛔ $p m4: did not compile or link"; return 99; }
  ( cd "$T" && timeout -k 5 20s "./$p.m4" </dev/null >"$T/o" 2>"$T/e" ); return $?; }
fpcrun() { ( cd "$T" && "$FPC" -Miso -v0 -o"$1.fpc" $1.pas >/dev/null 2>&1 ) || { echo "⛔ GATE REFUSE(2) [$G]: fpc -Miso would not compile $1"; exit 2; }; ( cd "$T" && timeout -k 5 20s ./$1.fpc </dev/null >"$T/$1.want" 2>/dev/null ); echo $?; }

cat > "$T/wfac.pas" <<'PAS'
program wfac(output);
type a = record case b: boolean of true: (c: integer); false: (d: char) end;
var e: ^a; x: a;
begin
  writeln('before'); new(e, true); e^.b := true; e^.c := 42; x := e^; writeln('after')
end.
PAS
cat > "$T/wasg.pas" <<'PAS'
program wasg(output);
type a = record case b: boolean of true: (c: integer); false: (d: char) end;
var e: ^a; x: a;
begin
  writeln('before'); new(e, true); x.b := true; x.c := 42; e^ := x; writeln('after')
end.
PAS
cat > "$T/wvar.pas" <<'PAS'
program wvar(output);
type a = record case b: boolean of true: (c: integer); false: (d: char) end;
var e: ^a;
procedure y(var z: a); begin end;
begin
  writeln('before'); new(e, true); e^.b := true; e^.c := 42; y(e^); writeln('after')
end.
PAS
cat > "$T/wval.pas" <<'PAS'
program wval(output);
type a = record case b: boolean of true: (c: integer); false: (d: char) end;
var e: ^a;
procedure y(z: a); begin end;
begin
  writeln('before'); new(e, true); e^.b := true; e^.c := 42; y(e^); writeln('after')
end.
PAS
cat > "$T/ctl.pas" <<'PAS'
program ctl(output);
type a = record case b: boolean of true: (c: integer); false: (d: integer) end;
var v: a; f, e: ^a;
procedure show(var z: a); begin writeln(ord(z.b)) end;
procedure copy(z: a); begin writeln(ord(z.b)) end;
begin
  new(f); f^.b := true; f^.c := 4; v := f^; writeln(v.c); f^ := v; show(f^); copy(f^);
  new(e, true); e^.b := true; e^.c := 5; writeln(e^.c); writeln(ord(e^.b));
  dispose(e, true); dispose(f)
end.
PAS
RC=0; N=0
for m in m3 m4; do
  for p in wfac wasg wvar wval; do
    run $m $p; rc=$?; N=$((N + 1))
    if [ "$rc" != 0 ] && [ "$(cat "$T/o")" = before ] && grep -q 6.6.5.3 "$T/e"; then echo "  $p $m: refused with 6.6.5.3 after printing before (rc=$rc)"
    else echo "  ⛔ $p $m FAILED: rc=$rc stdout=[$(head -c 60 "$T/o" | tr '\n' '|')] err=[$(head -c 100 "$T/e")]"; RC=1; fi
  done
done
frc=$(fpcrun ctl)
if [ -n "${FAIL_ONCE:-}" ]; then echo "corrupted by FAIL_ONCE" >> "$T/ctl.want"; fi
for m in m3 m4; do run $m ctl; rc=$?; N=$((N + 1))
  if [ "$rc" = "$frc" ] && cmp -s "$T/ctl.want" "$T/o"; then echo "  ctl $m: rc=$rc, stdout byte-identical to fpc -Miso ($(wc -l < "$T/o") lines)"
  else echo "  ⛔ ctl $m FAILED: rc=$rc (fpc $frc)"; diff "$T/ctl.want" "$T/o" | head -6 | sed 's/^/      /'; echo "      err : $(head -1 "$T/e" | cut -c1-140)"; RC=1; fi
done
if [ "$RC" = 0 ]; then echo "GATE PASS [$G]: whole-variable access of a tag-allocated variable is refused in four forms and a legal control runs as fpc, $N of $N arms"
else echo "GATE FAIL(1) [$G]: examined 5 programs in 2 modes"; fi
echo "    tree: SCRIP=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY)" \
     " oracle: $FPC $($FPC -iV 2>/dev/null)  measured $(date -u +%Y-%m-%dT%H:%MZ)"
exit $RC
