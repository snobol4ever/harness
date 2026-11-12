#!/usr/bin/env bash
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
# test_gate_gc_rule_1_and_rule_2_mask_coverage_stays_at_or_over_its_floor.sh -- THE MASKS OF THE RULE-1 AND RULE-2 SITES NAME THE LIVE CELLS THE PLAN DECLARES (hq_zetas,
# zeta-layout step 4a-3, the omega-edge cure). The word-kind fold (zd_wk_fold) carries a box's declared cells to its successors; it followed only gamma and arm-environment
# edges, so a node reached by an OMEGA edge (the exit of an IR_TO, an alternation's failure arm) started with an empty state and every site after it declared almost nothing
# (MEASURED 2026-11-04 on hb_wsb_rk_iter_grep: the first site after the exit of an IR_TO, E=528, NW 68, one set bit where its predecessor had 26): live cells the walk would then
# not be told. Poisoning the tag of each such search-accepted word breaks the Raku witnesses (SCRIP_GC_STRESS=3), so they are live roots, not leftovers.
# THE GATE compiles each witness of gc_rule12_mask_coverage_floor.tsv in mode 4, reads its .Lgcsites tables (four quads per entry, the third quad of a rule-1 or rule-2 entry is
# pool offset | NW << 32) and sums the set bits inside each such site's extent; every program must read at or over its floor. A floor only rises.
# rc 0 held · rc 1 a program under its floor (named, with both numbers) · rc 2 cannot measure (no scrip, a witness or its compile missing, no table)
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"; SC="$ROOT/SCRIP/scrip"; FLOOR="$HERE/gc_rule12_mask_coverage_floor.tsv"
NAME=test_gate_gc_rule_1_and_rule_2_mask_coverage_stays_at_or_over_its_floor
[ -x "$SC" ] || { echo "REFUSE(2): $SC is not built"; exit 2; }
[ -f "$FLOOR" ] || { echo "REFUSE(2): no floor file $FLOOR"; exit 2; }
W="$(mktemp -d "${TMPDIR:-/tmp}/gate_cov12.XXXXXX")" || { echo "REFUSE(2): mktemp failed"; exit 2; }
trap 'rm -rf "$W"' EXIT
n=0; red=""
while IFS=$'\t' read -r wit floor; do
    case "$wit" in ''|'#'*|witness) continue ;; esac
    case "$wit" in design:*/*) _pl="${wit#design:}"; _pl="${_pl%%/*}"; _f="${wit##*/}"   # a design witness (it left the shared tests folder): its master entry or its loose pair, staged
        . "$HERE/lib_design_witness.sh" || { echo "REFUSE(2): lib_design_witness.sh unloadable"; exit 2; }
        _sd="$W/cov12_${_f%.*}"; design_witness_stage "$_pl" "$_sd" "${_f%.*}" || { echo "REFUSE(2): the witness $wit did not stage"; exit 2; }; src="$_sd/$_f" ;;
    *) src="$HERE/$wit" ;; esac
    [ -f "$src" ] || { echo "REFUSE(2): no witness $src"; exit 2; }
    base="$(basename "${wit%.*}")"
    ( cd "$ROOT/SCRIP" && timeout -k 2 300 ./scrip --compile --out="$W/$base.s" "$src" < /dev/null > /dev/null 2>&1 ) || { echo "REFUSE(2): $wit does not compile in mode 4"; exit 2; }
    got="$(python3 - "$W/$base.s" <<'PY'
import re, sys
lines = open(sys.argv[1], encoding='utf-8', errors='replace').read().split('\n')
i, tabs, bits, sites = 0, 0, 0, 0
while i < len(lines):
    m = re.match(r'^(\.Lgcsites_\S+):\s+\.quad\s+(\d+)', lines[i])
    if not m:
        i += 1
        continue
    n = int(m.group(2)); q = []; i += 1; tabs += 1
    while i < len(lines) and not lines[i].strip().startswith('.popsection'):
        mm = re.match(r'^\s+\.quad\s+(.+)$', lines[i])
        if mm:
            q.append(mm.group(1).strip())
        i += 1
    if len(q) < 3 + 4 * n:
        continue
    pool = [int(x) for x in q[3 + 4 * n:]]; lo = 32 + 32 * n
    for e in range(n):
        w = int(q[3 + 4 * e + 1]); third = int(q[3 + 4 * e + 2]); rule = (w >> 16) & 0xFFFF
        if rule in (1, 2) and third:
            s = ((third & 0xFFFFFFFF) - lo) // 8; nw = third >> 32; sites += 1
            for k in range(nw):
                bits += (pool[s + k // 64] >> (k % 64)) & 1
print('%d %d %d' % (tabs, sites, bits))
PY
)"
    set -- $got; tabs="$1"; sites="$2"; bits="$3"
    [ "${tabs:-0}" -ge 1 ] 2>/dev/null || { echo "REFUSE(2): $wit has no site table"; exit 2; }
    n=$((n + 1))
    echo "COVERAGE12 $base: sites=$sites bits=$bits floor=$floor"
    [ "$bits" -ge "$floor" ] || red="$red $base($bits<$floor)"
done < "$FLOOR"
[ "$n" -ge 1 ] || { echo "REFUSE(2): the floor file names no witness"; exit 2; }
[ -z "$red" ] && { echo "GATE OK [$NAME]: $n programs, every rule-1 and rule-2 mask coverage at or over its floor"; exit 0; }
echo "GATE FAIL [$NAME]:$red"; exit 1
