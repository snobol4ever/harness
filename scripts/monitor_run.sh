#!/usr/bin/env bash
# monitor_run.sh -- THE ONE COMMAND AN HQ USES THE IPC SYNC-STEP MONITOR THROUGH (ceo 2026-09-23, CEO-1186; Lon: "finish up IPC
# sync-step monitor and let me know when the HQ's can begin to use"). Design: MONITOR-BINARY-DESIGN.md § THE PLUG INTERFACE.
#
#   bash ../harness/scripts/monitor_run.sh <source>            # --modes: SCRIP mode 3 against SCRIP mode 4 in lock-step (every language)
#   bash ../harness/scripts/monitor_run.sh <source> --trace    # print the trace (statement / assignment / call / return) of a mode-3 run
#   bash ../harness/scripts/monitor_run.sh <source> --oracle   # SCRIP against the language's oracle in lock-step (SNOBOL4: SPITBOL fork; Icon: icx; Prolog: gpx, the GNU Prolog fork, or swx, the SWI-Prolog fork, under MONITOR_PL_ORACLE=swipl; Pascal: fpx, the Free Pascal fork; Raku: rkx, the Rakudo fork)
#   [--input FILE] feeds stdin (default: <base>.input beside the source if present, else /dev/null)
#
# Every mode-3/mode-4 run is preceded by the MONITOR-SAFE CHECK (RULES.md: a monitor verdict is a verdict on a different program):
# the untraced run's stdout must equal the traced run's stdout with the trace lines (****...) removed, else this REFUSES rc=2 --
# the trace changed the program and no verdict from it is about the program you meant. Exit: 0 no graded event diverged /
# trace printed, 1 the modes DIVERGE (the controller's grid names the step), 2 could not measure (a participant never started,
# the source does not compile, the witness is not monitor-safe, or no oracle bridge exists for the language).
# ⛔ rc 0 IS TWO VERDICTS, AND THE LINE SAYS WHICH (row monitor-the-controller-reads-an-untyped-value-as-agree-…, the coo,
# 2026-09-23): "AGREE" only when the controller's VERDICT line reads UNGRADED=0; otherwise "UNGRADED=n", naming every step a
# participant sent untyped (MWT_UNKNOWN) -- those values were never compared, so they are never a match. Until this landing the
# controller wildcarded an untyped value and this line said "agree event-for-event" over a wrong SCRIP Rat against rkx.
#
# ⛔⭐ MODE-4 HAD NO EQUIVALENT CHECK UNTIL 2026-09-23 (hq_icon), and it was not a theoretical gap: on the IPL witness
# unitgenr.icn, the harness's scr4 participant (built exactly as below, --trace --compile --monitor) reported an early
# PROTOCOL ERR "divergence" during options() parsing that did NOT correspond to the real defect -- the real bug was a
# GC-triggered crash much later, present in the PLAIN shipped --compile build and absent when trace instrumentation
# happened to shift allocation timing enough to avoid it (a heisenbug). A --modes run would have pointed straight at
# the wrong code with no warning. --oracle's default "scr" participant runs mode-3 (already covered above); only
# --modes needs scr4, so the check below runs only for that path.
set -u
# THE BINARY IS THIS REPOSITORY'S OWN (the coo 2026-10-03, CEO-1496): SD was $S4E/SCRIP, the sibling checkout beside the root, so from a
# worktree every run below -- and the harness it calls -- graded a different checkout's build than the one the caller stood in.
SD="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../SCRIP" && pwd)"; SCRIP="$SD/scrip"
src="${1:-}"; [ -n "$src" ] && [ -f "$src" ] || { echo "REFUSE(2): usage: monitor_run.sh <source> [--modes|--trace|--oracle] [--input FILE]"; exit 2; }
shift; mode=modes; input=""
while [ $# -gt 0 ]; do case "$1" in --modes) mode=modes;; --trace) mode=trace;; --oracle) mode=oracle;; --input) input="$2"; shift;; *) echo "REFUSE(2): unknown option $1"; exit 2;; esac; shift; done
[ -x "$SCRIP" ] || { echo "REFUSE(2): no $SCRIP -- run make"; exit 2; }
src="$(realpath "$src")"; base="${src%.*}"; ext="${src##*.}"
[ -z "$input" ] && [ -f "$base.input" ] && input="$base.input"; [ -z "$input" ] && input=/dev/null
[ "$input" = /dev/null ] || { [ -f "$input" ] || { echo "REFUSE(2): --input $input is not a file"; exit 2; }; input="$(realpath "$input")"; }   # absolute before the cd into the scratch mirror below
case "${ext,,}" in p|pp|lpr|dpr) ext=pas;; pro|prolog|plt) ext=pl;; esac
case "$ext" in sno|spt|sbl|icn|pl|pas|raku|sc|reb) ;; *) echo "REFUSE(2): $ext is not a SCRIP source extension"; exit 2;; esac
# every run below at the heap and stack the source declares beside itself (<base>.heap / <base>.stack, which extract writes for a suite entry):
# -d/-s after --run, leading each compiled binary's arguments (ceo CEO-1353, RULES.md clause 8 (g)); the participants read the same sidecars
. "$SD/../harness/scripts/lib_declared_arena.sh" || { echo "REFUSE(2): cannot load lib_declared_arena.sh"; exit 2; }
SW="$(declared_switches_beside "$src")" || { echo "REFUSE(2): $src: a .heap or .stack sidecar the reader refuses (it said why above)"; exit 2; }
W=$(mktemp -d); trap 'rm -rf "$W"' EXIT
# ⛔⭐ THE SUBJECT RUNS IN A SCRATCH MIRROR OF ITS OWN DIRECTORY, NEVER IN THE CALLER'S CWD (coo 2026-09-25, on hq_pascal's
# measurement). Every run below -- the traced and untraced mode 3, both mode-4 binaries and the participants -- inherited
# whatever directory the seat stood in. So fpc_tests' test_tisobuf2, test_tisobuf3 and test_tisoread, run from SCRIP/, left
# testfile, textfile and tisoread.tmp in SCRIP/ (16:36-16:41), the tree read dirty, and the PAT runner skipped its SCORE
# row. A relative read also resolved against the caller, not the program. The mirror symlinks every entry of the source's
# directory, so a relative read resolves as it does in the package, and a new file lands in the scratch and dies with it.
# (A program that rewrites an EXISTING companion still writes through the link; none in the corpus is known to.)
RUNDIR="$W/cwd"; mkdir -p "$RUNDIR" || { echo "REFUSE(2): no scratch cwd under $W"; exit 2; }
for _e in "$(dirname "$src")"/* "$(dirname "$src")"/.[!.]*; do [ -e "$_e" ] && ln -s "$_e" "$RUNDIR/" 2>/dev/null; done
cd "$RUNDIR" || { echo "REFUSE(2): cannot enter the scratch cwd $RUNDIR"; exit 2; }
if [ "$mode" = trace ]; then
    timeout -k 5 60 "$SCRIP" --trace --run $SW "$src" < "$input"; rc=$?
    [ "$rc" = 124 ] && { echo "REFUSE(2): the traced run did not finish in 60 s -- this is not a verdict"; exit 2; }
    exit 0
fi
timeout -k 5 60 "$SCRIP" --run $SW "$src" < "$input" > "$W/plain.out" 2> "$W/plain.err"; prc=$?
timeout -k 5 60 "$SCRIP" --trace --run $SW "$src" < "$input" > "$W/traced.out" 2> "$W/traced.err"; trc=$?
if [ "$prc" = 124 ] || [ "$trc" = 124 ]; then echo "REFUSE(2): the witness did not finish in 60 s (plain rc=$prc, traced rc=$trc) -- pick a shorter witness"; exit 2; fi
perl -0pe 's/\*\*\*\*[0-9]+[^\n]*\n//g' "$W/traced.out" > "$W/traced.stripped"
if ! cmp -s "$W/plain.out" "$W/traced.stripped" || [ "$prc" != "$trc" ]; then
    echo "REFUSE(2): NOT MONITOR-SAFE -- the traced run's program output differs from the untraced run's (plain rc=$prc, traced rc=$trc); a verdict under trace would be about a different program. First difference:"
    diff "$W/plain.out" "$W/traced.stripped" | head -6; exit 2
fi
nev=$(grep -oE '\*\*\*\*[0-9]+' "$W/traced.out" | wc -l); echo "[monitor_run] monitor-safe: untraced output identical under trace; $nev trace event(s) in mode 3"
if [ "$mode" = modes ]; then
    ( cd "$(dirname "$src")" && timeout -k 5 60 "$SCRIP" --compile -o "$W/plain4.s" "$src" < /dev/null ) > "$W/plain4.cc.out" 2>&1; pcc=$?
    [ "$pcc" = 0 ] || { echo "REFUSE(2): mode-4 plain compile failed (rc=$pcc): $(tail -2 "$W/plain4.cc.out")"; exit 2; }
    gcc "$W/plain4.s" -L"$SD/out" -lscrip_rt -Wl,-rpath,"$SD/out" -lm -o "$W/plain4.bin" > "$W/plain4.link.out" 2>&1
    [ -x "$W/plain4.bin" ] || { echo "REFUSE(2): mode-4 plain link failed: $(tail -2 "$W/plain4.link.out")"; exit 2; }
    timeout -k 5 60 "$W/plain4.bin" $SW < "$input" > "$W/plain4.out" 2> "$W/plain4.err"; prc4=$?

    ( cd "$(dirname "$src")" && timeout -k 5 60 "$SCRIP" --trace --compile --monitor -o "$W/traced4.s" "$src" < /dev/null ) > "$W/traced4.cc.out" 2>&1; tcc=$?
    [ "$tcc" = 0 ] || { echo "REFUSE(2): mode-4 traced compile failed (rc=$tcc): $(tail -2 "$W/traced4.cc.out")"; exit 2; }
    gcc "$W/traced4.s" -L"$SD/out" -lscrip_rt -Wl,-rpath,"$SD/out" -lm -o "$W/traced4.bin" > "$W/traced4.link.out" 2>&1
    [ -x "$W/traced4.bin" ] || { echo "REFUSE(2): mode-4 traced link failed: $(tail -2 "$W/traced4.link.out")"; exit 2; }
    # No MONITOR_READY_PIPE/MONITOR_BIN set here on purpose: this mirrors the safety-check's own logic, not the
    # harness's -- core.c only opens the IPC pipe when MONITOR_READY_PIPE is present, so a lone traced binary run
    # without it never blocks on an ack partner and its trace hook calls execute as (intended) no-ops. That is
    # exactly the property under test: does the mere PRESENCE of the instrumentation change real behavior.
    timeout -k 5 60 "$W/traced4.bin" $SW < "$input" > "$W/traced4.out" 2> "$W/traced4.err"; trc4=$?

    if [ "$prc4" = 124 ] || [ "$trc4" = 124 ]; then echo "REFUSE(2): the mode-4 witness did not finish in 60 s (plain rc=$prc4, traced rc=$trc4) -- pick a shorter witness"; exit 2; fi
    if ! cmp -s "$W/plain4.out" "$W/traced4.out" || [ "$prc4" != "$trc4" ]; then
        echo "REFUSE(2): NOT MONITOR-SAFE IN MODE 4 -- the --trace --compile --monitor binary's real output differs from the plain --compile binary's (plain rc=$prc4, traced rc=$trc4); a divergence (or an agreement) reported by scr4 under this build would be a verdict about a different program than the one that ships. First difference:"
        diff "$W/plain4.out" "$W/traced4.out" | head -6; exit 2
    fi
    echo "[monitor_run] monitor-safe: untraced mode-4 output identical under --trace --compile --monitor"
fi
if [ "$mode" = oracle ]; then
    case "$ext" in
        sno|spt|sbl) parts="spl scr" ;;
        raku) parts="rkx scr" ;;
        icn) parts="icx scr" ;;
        pl) case "${MONITOR_PL_ORACLE:-gprolog}" in gprolog) parts="gpx scr" ;; swipl) parts="swx scr" ;; *) echo "REFUSE(2): MONITOR_PL_ORACLE=$MONITOR_PL_ORACLE names no Prolog oracle participant (gprolog: gpx, the default; swipl: swx)"; exit 2 ;; esac ;;
        pas) parts="fpx scr" ;;
        *) echo "REFUSE(2): no oracle bridge for .$ext yet -- the design (MONITOR-BINARY-DESIGN.md § THE PLUG INTERFACE, layer 6) adds one only where it earns its cost; use --modes (mode 3 against mode 4) or --trace against the oracle's own output by hand"; exit 2 ;;
    esac
else
    parts="scr3 scr4"
fi
[ "$input" = /dev/null ] || export MONITOR_STDIN="$input"
# MONITOR_HARNESS names a stand-in harness for a gate that must make the controller say something a real run cannot be made to (a
# PROTOCOL ERR); it is never set by a seat. Until SD became this repository (CEO-1496) such a gate swapped the harness through S4E_HOME.
PARTICIPANTS="$parts" timeout -k 5 300 bash "${MONITOR_HARNESS:-$SD/../harness/scripts/test_monitor_3way_sync_step_auto.sh}" "$src" > "$W/harness.out" 2>&1; hrc=$?
steps=$(grep -oE 'all reached END after [0-9]+ steps' "$W/harness.out" | grep -oE '[0-9]+' | head -1)
verdict=$(grep -aoE 'VERDICT AGREE=[0-9]+ DIVERGE=[0-9]+ UNGRADED=[0-9]+' "$W/harness.out" | head -1 | sed 's/^VERDICT //')
ungraded=$(printf '%s' "$verdict" | sed -n 's/.*UNGRADED=\([0-9]*\).*/\1/p')
# ⛔ THE OUTPUT STREAM'S STANDING, NAMED BESIDE EVERY VERDICT (coo 2026-09-25, the OUTPUT event): the controller grades the bytes each side
# writes to standard output only when every participant speaks OUTPUT; until the SCRIP plug does, an AGREE says nothing about output.
outv=$(grep -aoE 'OUTPUT=(graded \([0-9]+ byte\(s\)\)|UNGRADED\([^ :)]*)' "$W/harness.out" | head -1)
case "$outv" in OUTPUT=graded*) outnote="; output graded byte for byte (${outv#OUTPUT=graded })";; OUTPUT=UNGRADED*) outnote="; OUTPUT NOT GRADED -- ${outv#OUTPUT=UNGRADED(} sends no OUTPUT events, so no byte written to stdout was compared (its plug is owed)";; *) outnote="";; esac
if [ "$hrc" = 2 ] || [ "$hrc" = 124 ]; then echo "REFUSE(2): the harness could not measure (rc=$hrc): $(grep -E 'REFUS|FAIL' "$W/harness.out" | head -1 | cut -c1-140)"; exit 2; fi
# ⛔ A BROKEN WIRE IS NOT A DIVERGENCE (coo 2026-09-25, on hq_snobol4's report: aisnobol TEST.sno read "DIVERGE" at exactly step
# 100000). The controller names a PROTOCOL ERR when a participant's stream stops decoding -- a torn or foreign record, a participant
# that died mid-write -- and the harness exits 3 for it, which this script used to print as DIVERGE: an HQ was sent to bisect its
# program at a step where the programs had not disagreed at all (AGREE=99999 DIVERGE=0). No verdict exists past that step, so this
# is could-not-measure, rc 2, with the step and the agreement up to it named.
perr=$(grep -m1 -a 'PROTOCOL ERR' "$W/harness.out" | cut -c1-220)
if [ -n "$perr" ]; then echo "REFUSE(2): THE WIRE BROKE, NOT THE PROGRAM -- ${perr#\[ctrl\] } -- no verdict past that step${verdict:+; up to it: $verdict}. An instrument defect: report it to the coo with this command."; exit 2; fi
if [ "$hrc" = 0 ] && [ -n "$steps" ] && [ "$steps" -gt 0 ] && [ -z "$verdict" ]; then echo "REFUSE(2): the controller printed no VERDICT line (AGREE= DIVERGE= UNGRADED=) -- an agreement whose UNGRADED count is unknown is not a pass"; exit 2; fi
if [ "$hrc" = 0 ] && [ -n "$steps" ] && [ "$steps" -gt 0 ] && [ "$ungraded" = 0 ]; then echo "[monitor_run] AGREE: participants $parts agree event-for-event, clean termination at step $steps ($verdict)$outnote"; exit 0; fi
if [ "$hrc" = 0 ] && [ -n "$steps" ] && [ "$steps" -gt 0 ]; then
    echo "[monitor_run] UNGRADED=$ungraded: participants $parts -- no graded event diverged, clean termination at step $steps ($verdict)$outnote; an UNGRADED step is NEVER a match: a participant sent that value untyped (MWT_UNKNOWN), so it was not compared:"
    grep -a '^\[ctrl\]   UNGRADED ' "$W/harness.out" | sed 's/^\[ctrl\]  /  /'
    exit 0
fi
if [ "$hrc" = 0 ]; then echo "REFUSE(2): the controller printed no lock-step termination line -- an empty agreement is not a pass"; exit 2; fi
echo "[monitor_run] DIVERGE (rc=$hrc): participants $parts${verdict:+ ($verdict)} -- the controller's grid, last-agree trail then the first divergence:"; sed -n '/controller output/,/stdout (head)/p' "$W/harness.out" | grep -a -vE 'controller output|stdout \(head\)|^\s*$' | head -40
exit 1
