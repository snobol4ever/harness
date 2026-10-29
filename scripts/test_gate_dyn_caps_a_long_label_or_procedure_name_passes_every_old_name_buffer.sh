#!/usr/bin/env bash
# test_gate_dyn_caps_a_long_label_or_procedure_name_passes_every_old_name_buffer.sh -- landing 0 of the fixed-tables row (cfo 2026-10-03,
# no-more-whack-a-mole-every-fixed-table-a-program-can-fill-is-converted-in-one-pass-..., CEO-1496 (3); ARCH-DYNAMIC-STORAGE.md section 5 (4):
# every conversion lands with a witness that exceeds the OLD cap and reads the ORACLE's answer).
#
# MEASURED 2026-10-03 on SCRIP d50a3e1f0: an indirect goto :($N) to a label of 251 characters or more answered "error 38: goto undefined label"
# where sbl -bf reaches it, at every length from 251 (the old cap: "LBL__" plus the name in a 256-byte buffer) to 1000; a direct goto was fine.
# Two buffers truncated the same name on the two sides of one lookup -- lower_snobol4.c registered LBL__<first 250 characters> (two lname[256]
# locals) and runtime_eval.c's rt_goto_resolve_x / rt_entry_resolve looked up LBL__<first 250> (two more) -- and bb_define.cpp's
# bb_ab_seal_entry_cells cut an entry cell's name at 294 characters (cell[300]), runtime_eval.c's runtime-compile prefix proc_<name> at 294
# (_m3pfx[300]). Each is now a stack array sized to the name at the construct's entry (the Lifetime Rule; fmt_len where a format sizes it).
# Arms, each in m3 and m4, each stream byte-identical to sbl -bf: A an indirect goto to a 300-character and to a 1000-character label;
# B one CODE block defining two functions whose 300-character names differ only in their last character, each called by EVAL in both orders.
# FAIL_ONCE=1 corrupts arm A's expected stream to prove the comparison trips.
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
SCRIP="${SCRIP_BIN:-$ROOT/scrip}"; [ -x "$SCRIP" ] || { echo "⛔ REFUSE(2): no scrip at $SCRIP"; exit 2; }
SBL="${SBL_BIN:-/home/resources/x64/bin/sbl}"; [ -x "$SBL" ] || { echo "⛔ REFUSE(2): no sbl at $SBL -- the expected output is CUT FROM THE ORACLE, never pinned by hand"; exit 2; }
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
L3=$(printf 'L%0299d' 0 | tr 0 A); L10=$(printf 'M%0999d' 0 | tr 0 A); P=$(printf 'F%0299d' 0 | tr 0 B)
printf "        N = '%s'\n        OUTPUT = 'start'                        :(\$N)\n        OUTPUT = 'skipped 300'\n%s OUTPUT = 'reached 300'\n        N = '%s'\n        OUTPUT = 'next'                         :(\$N)\n        OUTPUT = 'skipped 1000'\n%s OUTPUT = 'reached 1000'\nEND\n" "$L3" "$L3" "$L10" "$L10" > "$T/a.sno"
printf "        P = '%s'\n        C = CODE(\" DEFINE('\" P \"X()') :(E1);\" P \"X \" P \"X = 'first' :(RETURN);E1 DEFINE('\" P \"Y()') :(E2);\" P \"Y \" P \"Y = 'second' :(RETURN);E2 :(BACK)\")   :<C>\nBACK    OUTPUT = EVAL(P \"X()\") ' ' EVAL(P \"Y()\")\n        OUTPUT = EVAL(P \"Y()\") ' ' EVAL(P \"X()\")\nEND\n" "$P" > "$T/b.sno"
for W in a b; do ( cd "$T" && "$SBL" -bf $W.sno < /dev/null ) > "$T/$W.ref" 2>&1 || { echo "⛔ REFUSE(2): sbl did not run witness $W"; exit 2; }; done
[ "$(tr '\n' ';' < "$T/a.ref")" = "start;reached 300;next;reached 1000;" ] && [ "$(tr '\n' ';' < "$T/b.ref")" = "first second;second first;" ] || { echo "⛔ REFUSE(2): sbl's streams are not the ones this gate was cut on"; exit 2; }
RC=0
for M in m3 m4; do
  for W in a b; do
    if [ "$M" = m4 ]; then ( cd "$T" && "$SCRIP" --compile --out=$W.s $W.sno </dev/null && gcc $W.s -o $W.bin -L"$ROOT/out" -lscrip_rt -lm -lpthread ) >/dev/null 2>&1 || { echo "⛔ REFUSE(2): mode-4 witness $W did not build"; exit 2; }; fi
    ( cd "$T" && if [ "$M" = m3 ]; then timeout -k 5 30 "$SCRIP" $W.sno </dev/null; else LD_LIBRARY_PATH="$ROOT/out" timeout -k 5 30 ./$W.bin </dev/null; fi ) >"$T/$M.$W.out" 2>"$T/$M.$W.err"; echo $? > "$T/$M.$W.rc"
  done
  [ -n "${FAIL_ONCE:-}" ] && sed -i 's/^reached 300$/reached 300X/' "$T/$M.a.out"
  for W in a b; do
    if cmp -s "$T/$W.ref" "$T/$M.$W.out"; then echo "  $M arm $(echo $W | tr ab AB) PASS (byte-identical to sbl -bf: $(tr '\n' ';' < "$T/$M.$W.out"))"
    else echo "  $M arm $(echo $W | tr ab AB) FAIL (rc $(cat "$T/$M.$W.rc")): $(diff "$T/$W.ref" "$T/$M.$W.out" | head -4 | tr '\n' '|') $(head -c 160 "$T/$M.$W.err" | tr '\n' '|')"; RC=1; fi
  done
done
if [ "$RC" = 0 ]; then echo "GATE PASS [$(basename "${BASH_SOURCE[0]}" .sh)]: a label or procedure name past every old name buffer resolves as sbl resolves it (2 arms x 2 modes)"
else echo "GATE FAIL(1) [$(basename "${BASH_SOURCE[0]}" .sh)]: a long name is still cut by a fixed buffer (examined 2 arms x 2 modes)"; fi
echo "    tree: SCRIP=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY)  oracle: $SBL  measured $(date -u +%Y-%m-%dT%H:%MZ)"
exit $RC
