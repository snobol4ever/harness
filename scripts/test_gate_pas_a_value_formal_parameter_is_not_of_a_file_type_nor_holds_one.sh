#!/usr/bin/env bash
# test_gate_pas_a_value_formal_parameter_is_not_of_a_file_type_nor_holds_one.sh -- ISO 7185 6.6.3.2 with 6.4.3.5: a value formal-parameter whose type is a file-type, or a structured type with a file-type component, can
# receive no actual-parameter (file values are not assignable), so the declaration is an error (PAT iso7185prt1707b).
#
# MEASURED 2026-10-07 by hq_pascal: PAT 1707b (a record holding a text file as a value formal) compiled and ran to rc 0 in both modes; fpc -Miso accepts it
# too, so the expectation is the ISO text. CURE: pascal.y's value-formal rule runs pas_value_formal_file_check, which refuses text, a typed-file type name
# and a record type holding a file (pas_rectype_has_file), naming the clause at compile time, so both modes refuse with no code generated.
#
# ARMS, both modes: four fault programs (record with text, record with a typed file, a typed-file type name, bare text) must be refused naming 6.6.3.2
# with empty stdout; a control cut LIVE from fpc -Miso (a var text formal, a file-free record by value) must run byte-identical. FAIL_ONCE=1 corrupts the
# control's ref.
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
  ( cd "$T" && timeout -k 5 20s "$SCRIP" --compile -o "$T/$p.s" "$p.pas" </dev/null >/dev/null 2>&1 && cc -m64 -no-pie "$p.s" -o "$p.m4" -L"$RT_DIR" -lscrip_rt -lm -Wl,-rpath,"$RT_DIR" >/dev/null 2>&1 ) || { echo "  ⛔ $p m4: did not compile or link"; return 99; }
  ( cd "$T" && timeout -k 5 20s "./$p.m4" </dev/null >"$T/o" 2>"$T/e" ); return $?; }
fpcrun() { ( cd "$T" && "$FPC" -Miso -v0 -o"$1.fpc" $1.pas >/dev/null 2>&1 ) || { echo "⛔ GATE REFUSE(2) [$G]: fpc -Miso would not compile $1"; exit 2; }; ( cd "$T" && timeout -k 5 20s ./$1.fpc </dev/null >"$T/$1.want" 2>/dev/null ); echo $?; }


cat > "$T/frec.pas" <<'PAS'
program frec(output);
type r = record f: text end;
var d: r;
procedure b(c: r); begin rewrite(c.f) end;
begin b(d) end.
PAS
cat > "$T/ftyp.pas" <<'PAS'
program ftyp(output);
type r = record f: file of integer end;
var d: r;
procedure b(c: r); begin rewrite(c.f) end;
begin b(d) end.
PAS
cat > "$T/fname.pas" <<'PAS'
program fname(output);
type ft = file of integer;
var d: ft;
procedure b(c: ft); begin rewrite(c) end;
begin b(d) end.
PAS
cat > "$T/ftext.pas" <<'PAS'
program ftext(output);
var d: text;
procedure b(c: text); begin rewrite(c) end;
begin b(d) end.
PAS
cat > "$T/ctl.pas" <<'PAS'
program ctl(output);
type r = record n: integer; c: char end; ft = file of integer;
var d: r; f: ft;
procedure b(c: r); begin writeln(c.n, c.c) end;
procedure p(var x: text); begin writeln(x, 'line') end;
begin d.n := 4; d.c := 'q'; b(d); rewrite(f); write(f, 9); reset(f); writeln(f^); p(output) end.
PAS
RC=0; N=0
for m in m3 m4; do
  for p in frec ftyp fname ftext; do
    if [ $m = m3 ]; then run m3 $p; rc=$?; else ( cd "$T" && timeout -k 5 20s "$SCRIP" --compile -o "$T/$p.s" "$p.pas" </dev/null >"$T/o" 2>"$T/e" ); rc=$?; fi; N=$((N + 1))
    if [ "$rc" != 0 ] && [ ! -s "$T/o" ] && grep -q 6.6.3.2 "$T/e"; then echo "  $p $m: refused with 6.6.3.2 (rc=$rc)"
    else echo "  ⛔ $p $m FAILED: rc=$rc stdout=[$(head -c 60 "$T/o" | tr '\n' '|')] err=[$(head -c 100 "$T/e")]"; RC=1; fi
  done
done
frc=$(fpcrun ctl)
if [ -n "${FAIL_ONCE:-}" ]; then echo "corrupted by FAIL_ONCE" >> "$T/ctl.want"; fi
for m in m3 m4; do run $m ctl; rc=$?; N=$((N + 1))
  if [ "$rc" = "$frc" ] && cmp -s "$T/ctl.want" "$T/o"; then echo "  ctl $m: rc=$rc, stdout byte-identical to fpc -Miso ($(wc -l < "$T/o") lines)"
  else echo "  ⛔ ctl $m FAILED: rc=$rc (fpc $frc)"; diff "$T/ctl.want" "$T/o" | head -6 | sed 's/^/      /'; echo "      err : $(head -1 "$T/e" | cut -c1-140)"; RC=1; fi
done
if [ "$RC" = 0 ]; then echo "GATE PASS [$G]: a value formal of a file type or holding a file is refused and a legal control runs as fpc, $N of $N arms"
else echo "GATE FAIL(1) [$G]: examined 5 programs in 2 modes"; fi
echo "    tree: SCRIP=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY)" \
     " oracle: $FPC $($FPC -iV 2>/dev/null)  measured $(date -u +%Y-%m-%dT%H:%MZ)"
exit $RC
