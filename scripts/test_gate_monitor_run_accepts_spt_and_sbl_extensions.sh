#!/usr/bin/env bash
# test_gate_monitor_run_accepts_spt_and_sbl_extensions.sh -- monitor_run.sh's source-extension gate named only sno, icn, pl, pas,
# raku, sc, reb (line 36) and its --oracle participant case named only sno (line 88), even though the driver itself
# (src/driver/scrip.c) treats .spt and .sbl as SNOBOL4 sources on equal footing with .sno (CLAUDE.md: "grep -oE
# '\"\\.[a-z]+\"' src/driver/scrip.c" -> ".sno .spt .sbl are SNOBOL4"). Three package suites carry no other extension --
# spitbol_testpgms/ (8 .spt), spitbol_x32_tests/ (21 .spt), spitbol_x64_tests/ (36 .sbl) -- so every one of their 65 programs
# REFUSED at the top gate before this cure: "REFUSE(2): spt is not a SCRIP source extension". THE MONITOR IS THE METHOD
# (RULES.md), and an instrument gap that blocks a bracket is crawl work (hq_snobol4, CEO-1295(ii) follow-on): the same "spl scr"
# participant pair sno already uses handles spt/sbl content identically -- spl just runs `sbl -bf <file>` and scr runs
# `scrip --trace --run <file>`, neither branches on extension past this gate.
# THE WITNESS: a three-statement OUTPUT='hello' program, copied under all three extensions, run with --oracle. Must AGREE
# identically (same step count, same AGREE/DIVERGE/UNGRADED) on .spt and .sbl as it already does on .sno.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
. "$HERE/lib_gate.sh" || { echo "REFUSED(2): cannot load lib_gate.sh"; exit 2; }; GATE_NAME=monitor_run_accepts_spt_and_sbl_extensions
gate_require_fresh "$ROOT" src "$ROOT/scrip" || exit 2
[ -x "$ROOT/scrip" ] || { echo "⛔ REFUSED(2): no $ROOT/scrip -- run make"; exit 2; }
T="$(mktemp -d)" || { echo "⛔ REFUSED(2): mktemp failed"; exit 2; }; trap 'rm -rf "$T"' EXIT
S4E_ROOT="$(cd "$ROOT/.." && pwd)"
cc=$(git -C "$ROOT" log --format=%h -1 -S'sno) parts="spl scr" ;;' -- ../harness/scripts/monitor_run.sh)
[ -n "$cc" ] || { echo "⛔ REFUSED(2): the pre-cure line is not in this tree's history -- nothing to fail once against"; exit 2; }
git -C "$ROOT" show "$cc^:../harness/scripts/monitor_run.sh" > "$T/old_monitor_run.sh" 2>/dev/null || { echo "⛔ REFUSED(2): cannot read monitor_run.sh at $cc^"; exit 2; }

printf "\tOUTPUT = 'hello'\nEND\n" > "$T/w.spt"
printf "\tOUTPUT = 'hello'\nEND\n" > "$T/w.sbl"
printf "\tOUTPUT = 'hello'\nEND\n" > "$T/w.sno"

run_one() {   # run_one <monitor_run.sh> <file>
    S4E_HOME="$S4E_ROOT" timeout -k 5 120 bash "$1" "$2" --oracle 2>&1
}

fails=0
echo "=== gate: monitor_run.sh accepts .spt and .sbl SNOBOL4 sources through --oracle, same as .sno ==="
sno_out="$(run_one "$HERE/monitor_run.sh" "$T/w.sno")"
sno_verdict="$(grep -oE 'AGREE=[0-9]+ DIVERGE=[0-9]+ UNGRADED=[0-9]+' <<<"$sno_out")"
[ -n "$sno_verdict" ] || { echo "  FAIL: the .sno control witness itself did not AGREE -- gate cannot proceed:"; echo "$sno_out" | sed 's/^/      /'; exit 2; }
echo "  .sno control: $sno_verdict"
for ext in spt sbl; do
    out="$(run_one "$HERE/monitor_run.sh" "$T/w.$ext")"
    verdict="$(grep -oE 'AGREE=[0-9]+ DIVERGE=[0-9]+ UNGRADED=[0-9]+' <<<"$out")"
    if [ "$verdict" = "$sno_verdict" ]; then
        echo "  ARM .$ext ok ($verdict)"
    else
        fails=$((fails+1))
        echo "  ARM .$ext RED -- expected [$sno_verdict], got:"; echo "$out" | sed 's/^/      /'
    fi
done

old_out_spt="$(run_one "$T/old_monitor_run.sh" "$T/w.spt")"
old_out_sbl="$(run_one "$T/old_monitor_run.sh" "$T/w.sbl")"
old_refuses=0
grep -q 'REFUSE(2): spt is not a SCRIP source extension' <<<"$old_out_spt" && old_refuses=$((old_refuses+1))
grep -q 'REFUSE(2): sbl is not a SCRIP source extension' <<<"$old_out_sbl" && old_refuses=$((old_refuses+1))
echo "  the old script ($cc^), the built-in fail-once: refused $old_refuses of 2 extensions (must be 2)"
[ "$old_refuses" = 2 ] || { fails=$((fails+1)); echo "  FAIL: the old script did not refuse the way this cure describes -- spt: $old_out_spt / sbl: $old_out_sbl"; }

if [ "$fails" = 0 ]; then echo "GATE PASS(0) [$GATE_NAME]: .spt and .sbl agree identically to .sno, and the pre-cure script reds exactly as described"; exit 0; fi
echo "⛔ GATE FAIL(1) [$GATE_NAME]: $fails check(s) failed"; exit 1
