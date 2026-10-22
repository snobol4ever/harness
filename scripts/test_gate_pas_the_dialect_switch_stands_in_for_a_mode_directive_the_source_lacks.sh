#!/usr/bin/env bash
# test_gate_pas_the_dialect_switch_stands_in_for_a_mode_directive_the_source_lacks.sh -- scrip --dialect=NAME (iso, fpc, objfpc, delphi,
# tp, macpas, delphiunicode) makes a Pascal source with no {$mode} line read as that dialect, exactly as if the source began with
# {$mode NAME}; an unknown name is refused rc 2; a {$mode} line in the source still wins over the switch, as fpc's own -M does.
#
# WHY (the cfo's ruling pascal-dialect-route, CEO-1281, 2026-10-21): 50 of the 111 PasRosetta programs that read FAIL rc=1 carry NO mode
# directive and have a ref cut from fpc-default or objfpc (corpus rosetta-pascal ALL.dialect), so SCRIP read the raw text as ISO and refused
# it. Source-side inference would break ISO_EXPECTED_REFUSALS (fpc -Miso accepts declaration-order violations that SCRIP must keep refusing),
# so the test unit's own compile_args carries the dialect and the runner types none. THE CURE: pascal_dialect_directive in pascal_driver.c
# and scrip.c, which reserves the directive text in front of the source buffer without a newline, so line numbers do not move.
#
# ARMS (both modes, stdout and exit code cut LIVE from fpc under the matching -M): dswvar with --dialect=objfpc (a var-part after a procedure
# and UInt64, which ISO refuses); the same program with NO switch must still be refused 6.2.1 (the default is unchanged); dswfn under objfpc,
# delphi and tp (a function that reads its own name: 256 as a result variable in fpc and objfpc, 5 as a recursive call in delphi and tp);
# dswfn2 whose source says {$mode objfpc} under --dialect=delphi (the directive wins: 256); --dialect=nosuch refused rc 2.
# FAIL_ONCE=1 corrupts dswvar's expectation. MEASURED on the parent (no switch): every switch arm refused rc 2.
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -uo pipefail
G="$(basename "${BASH_SOURCE[0]}" .sh)"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
SCRIP="${SCRIP_BIN:-$ROOT/scrip}"; [ -x "$SCRIP" ] || { echo "⛔ GATE REFUSE(2) [$G]: no scrip at $SCRIP"; exit 2; }
RT_DIR="${RT_DIR:-$ROOT/out}"; [ -f "$RT_DIR/libscrip_rt.so" ] || { echo "⛔ GATE REFUSE(2) [$G]: no runtime at $RT_DIR/libscrip_rt.so"; exit 2; }
FPC="${FPC_BIN:-/usr/bin/fpc}"; [ -x "$FPC" ] || { echo "⛔ GATE REFUSE(2) [$G]: no fpc at $FPC -- every expectation is CUT FROM THE ORACLE"; exit 2; }
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
RC=0; N=0
run() { local m="$1" p="$2" sw="$3"
  if [ "$m" = m3 ]; then ( cd "$T" && LD_LIBRARY_PATH="$RT_DIR" timeout -k 5 20s "$SCRIP" $sw --run "$p.pas" </dev/null >"$T/o" 2>"$T/e" ); return $?; fi
  ( cd "$T" && timeout -k 5 20s "$SCRIP" --compile $sw -o "$T/$p.s" "$p.pas" </dev/null >/dev/null 2>"$T/e" && cc -m64 -no-pie "$p.s" -o "$p.m4" -L"$RT_DIR" -lscrip_rt -lm -Wl,-rpath,"$RT_DIR" >/dev/null 2>&1 ) || { echo "  ⛔ $p m4: did not compile and link ($(head -1 "$T/e" | cut -c1-120))"; return 125; }
  ( cd "$T" && timeout -k 5 20s "./$p.m4" </dev/null >"$T/o" 2>"$T/e" ); return $?; }
fpcrun() { local mode="$2"; mkdir -p "$T/fpc"; ( cd "$T" && "$FPC" $mode -v0 -FE"$T/fpc" -o"$T/$1.fpc" "$T/$1.pas" >/dev/null 2>&1 ) || { echo "⛔ GATE REFUSE(2) [$G]: fpc $mode would not compile $1"; exit 2; }; ( cd "$T" && timeout -k 5 20s "./$1.fpc" </dev/null >"$T/$1.want" 2>/dev/null ); echo $?; }
cat > "$T/dswvar.pas" <<'PAS'
program dswvar;
procedure hello;
begin
  writeln('hello')
end;
var x: UInt64; i: integer;
begin
  hello;
  x := 5;
  for i := 1 to 3 do x := x * 2;
  writeln(x)
end.
PAS
cat > "$T/dswfn.pas" <<'PAS'
program dswfn;
var glob: integer;
function countchars: integer;
begin
  countchars := 255;
  if glob = 5 then countchars := 0
  else begin inc(glob); countchars := 1 + countchars end
end;
begin
  glob := 0;
  writeln(countchars)
end.
PAS
{ echo '{$mode objfpc}'; cat "$T/dswfn.pas"; } > "$T/dswfn2.pas"
arm() { local p="$1" sw="$2" om="$3" frc
  frc=$(fpcrun "$p" "$om") || exit 2
  if [ -n "${FAIL_ONCE:-}" ] && [ "$p" = dswvar ]; then echo "corrupted by FAIL_ONCE" >> "$T/$p.want"; fi
  for m in m3 m4; do run $m "$p" "$sw"; rc=$?; N=$((N + 1))
    if [ "$rc" = "$frc" ] && cmp -s "$T/$p.want" "$T/o"; then echo "  $p $m $sw: rc=$rc, stdout byte-identical to fpc $om ($(tr '\n' '|' < "$T/o" | cut -c1-40))"
    else echo "  ⛔ $p $m $sw FAILED: rc=$rc (fpc $frc)"; diff "$T/$p.want" "$T/o" | head -6 | sed 's/^/      /'; echo "      err : $(head -1 "$T/e" | cut -c1-140)"; RC=1; fi; done; }
arm dswvar --dialect=objfpc -Mobjfpc
arm dswfn --dialect=objfpc -Mobjfpc
arm dswfn --dialect=delphi -Mdelphi
arm dswfn --dialect=tp -Mtp
arm dswfn2 --dialect=delphi -Mdelphi
run m3 dswvar ""; rc=$?; N=$((N + 1))
if [ "$rc" = 1 ] && grep -q '6\.2\.1' "$T/e"; then echo "  dswvar m3 (no switch): refused rc=1 with the ISO 6.2.1 diagnostic, the default is unchanged"
else echo "  ⛔ dswvar m3 (no switch) FAILED: rc=$rc, expected the ISO refusal (rc 1, 6.2.1): $(head -1 "$T/e" | cut -c1-120)"; RC=1; fi
( cd "$T" && timeout -k 5 20s "$SCRIP" --dialect=nosuch --run dswvar.pas </dev/null >"$T/o" 2>"$T/e" ); rc=$?; N=$((N + 1))
if [ "$rc" = 2 ] && grep -q 'nosuch' "$T/e"; then echo "  --dialect=nosuch: refused rc=2 naming the value"
else echo "  ⛔ --dialect=nosuch FAILED: rc=$rc, expected rc 2 naming the value: $(head -1 "$T/e" | cut -c1-120)"; RC=1; fi
if [ "$RC" = 0 ]; then echo "GATE PASS [$G]: --dialect stands in for a mode directive the source lacks, the default is unchanged, a source directive wins, an unknown name is refused, $N of $N arms"
else echo "GATE FAIL(1) [$G]: examined three programs and two refusals over $N arms"; fi
echo "    tree: SCRIP=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY)" \
     " oracle: $FPC $($FPC -iV 2>/dev/null)  measured $(date -u +%Y-%m-%dT%H:%MZ)"
exit $RC
