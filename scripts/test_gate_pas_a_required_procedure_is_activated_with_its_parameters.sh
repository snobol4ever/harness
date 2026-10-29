#!/usr/bin/env bash
# test_gate_pas_a_required_procedure_is_activated_with_its_parameters.sh -- get, put, reset, rewrite, new, dispose, pack, unpack, read and
# write take actual-parameters; a bare activation of one is an ISO 7185 violation, not a call of an undefined routine
#
# MEASURED 2026-09-25 by hq_pascal, row pascal-every-suite-to-100-under-nonet-ceo-1266. FPC webtbs_tw37949 ({$MODE ISO}: "get; put") was
# accepted and died at run time with "error 108: list expected": the parser's call rule sent a bare identifier that is no user routine to
# mk_call with no arguments, and nothing asked whether it named a required procedure whose activation takes parameters. ISO 7185 gives
# get(f)/put(f)/reset(f)/rewrite(f) (6.6.5.2), new(p)/dispose(p) (6.6.5.3), pack/unpack (6.6.5.4), read (6.9.1) and write (6.9.3) no
# parameterless form -- unlike readln, writeln and page, which default to input/output. fpc -Miso compiles tw37949 (defaulting get/put to
# input/output), so it joins ISO_EXPECTED_REFUSALS.tsv under the ISO-as-oracle ruling (CEO-1225, CEO-1228). NO BRACKET: the program is
# refused at compile, before any event. The cure: pas_required_needs_params in the call rule's non-user branch names the clause.
#
# ARMS: (1) each of the ten, alone as a statement, must be REFUSED in both modes with its own clause named; (2) a control cut LIVE from
# fpc -Miso -- bare readln and writeln, and a user procedure named get -- must run byte-identical in both modes (a user routine is still
# called). It FAILS on the parent (every arm-1 program is accepted there). FAIL_ONCE=1 drops the refusal requirement of one arm to prove
# it can fail.
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -uo pipefail
G="$(basename "${BASH_SOURCE[0]}" .sh)"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
SCRIP="${SCRIP_BIN:-$ROOT/scrip}"; [ -x "$SCRIP" ] || { echo "⛔ GATE REFUSE(2) [$G]: no scrip at $SCRIP"; exit 2; }
RT_DIR="${RT_DIR:-$ROOT/out}"; [ -f "$RT_DIR/libscrip_rt.so" ] || { echo "⛔ GATE REFUSE(2) [$G]: no runtime at $RT_DIR/libscrip_rt.so"; exit 2; }
FPC="${FPC_BIN:-/usr/bin/fpc}"; [ -x "$FPC" ] || { echo "⛔ GATE REFUSE(2) [$G]: no fpc at $FPC -- the control arm's expectation is CUT FROM THE ORACLE"; exit 2; }
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
RC=0; N=0
for pair in get:6.6.5.2 put:6.6.5.2 reset:6.6.5.2 rewrite:6.6.5.2 new:6.6.5.3 dispose:6.6.5.3 pack:6.6.5.4 unpack:6.6.5.4 read:6.9.1 write:6.9.3; do
  nm=${pair%%:*}; cl=${pair#*:}; N=$((N+1))
  printf 'program r%s(input, output);\nbegin\n  %s\nend.\n' "$nm" "$nm" > "$T/r$nm.pas"
  for m in m3 m4; do
    if [ "$m" = m3 ]; then ( cd "$T" && timeout -k 5 20s "$SCRIP" --run "r$nm.pas" </dev/null >"$T/r$nm.$m.out" 2>"$T/r$nm.$m.err" ); rc=$?
    else ( cd "$T" && timeout -k 5 20s "$SCRIP" --compile --out="$T/r$nm.s" "r$nm.pas" </dev/null >"$T/r$nm.$m.out" 2>"$T/r$nm.$m.err" ); rc=$?; fi
    want="ISO 7185 $cl violation: the required procedure '$nm'"
    if [ -n "${FAIL_ONCE:-}" ] && [ "$nm" = get ] && [ "$m" = m3 ]; then want="corrupted by FAIL_ONCE"; fi
    if [ "$rc" -ne 0 ] && [ "$rc" -ne 124 ] && grep -qF "$want" "$T/r$nm.$m.err"; then echo "  arm $nm $m: refused rc=$rc, names $cl"
    else echo "  ⛔ arm $nm $m FAILED: rc=$rc, want a refusal naming \"$want\""; echo "      err: $(head -2 "$T/r$nm.$m.err" | tr '\n' '|' | cut -c1-200)"; RC=1; fi
  done
done
cat > "$T/ctl.pas" <<'PAS'
program ctl(input, output);
var n: integer;
procedure get;
begin
  n := n + 1; writeln('user get ', n)
end;
begin
  n := 0; get; writeln; get; readln; writeln('done')
end.
PAS
( cd "$T" && "$FPC" -Miso -v0 -o"ctl.fpc" ctl.pas >/dev/null 2>&1 && timeout -k 5 20s ./ctl.fpc </dev/null ) > "$T/ctl.want" 2>&1
[ -s "$T/ctl.want" ] || { echo "⛔ GATE REFUSE(2) [$G]: the oracle produced no output for the control arm"; exit 2; }
for m in m3 m4; do
  if [ "$m" = m3 ]; then ( cd "$T" && timeout -k 5 20s "$SCRIP" --run ctl.pas </dev/null >"$T/ctl.$m.out" 2>"$T/ctl.$m.err" ); rc=$?
  else ( cd "$T" && timeout -k 5 20s "$SCRIP" --compile --out="$T/ctl.s" ctl.pas </dev/null >/dev/null 2>&1 && cc -m64 -no-pie ctl.s -o ctl.m4 -L"$RT_DIR" -lscrip_rt -lm -Wl,-rpath,"$RT_DIR" >/dev/null 2>&1 \
         && timeout -k 5 20s ./ctl.m4 </dev/null >"$T/ctl.$m.out" 2>"$T/ctl.$m.err" ); rc=$?; fi
  if [ "$rc" = 0 ] && cmp -s "$T/ctl.want" "$T/ctl.$m.out"; then echo "  control arm $m: byte-identical to fpc -Miso"
  else echo "  ⛔ control arm $m FAILED: rc=$rc"; echo "      want: $(tr '\n' '|' < "$T/ctl.want")"; echo "      got : $(tr '\n' '|' < "$T/ctl.$m.out")"; RC=1; fi
done
if [ "$RC" = 0 ]; then echo "GATE PASS [$G]: a bare required procedure is refused with its clause ($N of $N, both modes), and a user routine of the same name still runs"
else echo "GATE FAIL(1) [$G]: examined $N refusal arms and 1 control arm in 2 modes"; fi
echo "    tree: SCRIP=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY)" \
     " oracle: $FPC $($FPC -iV 2>/dev/null)  measured $(date -u +%Y-%m-%dT%H:%MZ)"
exit $RC
