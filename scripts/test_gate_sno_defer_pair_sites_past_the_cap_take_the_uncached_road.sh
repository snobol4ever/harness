#!/usr/bin/env bash
# test_gate_sno_defer_pair_sites_past_the_cap_take_the_uncached_road.sh -- the deferred-capture pair cache g_sno_defer_cells is a
# fixed 2048-word table (1024 sites of two words, pattern_match.c) whose fill is guarded at COMPILE time: emit.cpp defer_prepare
# hands a *X site an index only while its never-reset counter is under 1024, and a site past the cap takes site -1, the uncached
# road (rt_defer_probe_run resolves the name every time). This gate proves that road answers as sbl does.
# Row snobol4-the-deferred-capture-cells-are-a-fixed-4096-word-table-and-a-fixed-island-that-emitted-code-indexes (cfo mint,
# CEO-1507 (4)); the cfo's answer of 2026-10-11 (ask cells-census-spill): delete the unreached cell half, keep the pair half with
# its at-cap road, and hold the road with this witness; the census reads the table as SPILL by naming this gate.
#
# THE WITNESS: 1500 EVAL units, each compiling one *W<i> site under a name the source never spells, so the compile-time counter
# runs past 1024 and every unit's site is its own. Each site matches three times: a hit, a hit after its variable is rebound (a
# cache that kept the old value would capture b<i>), and a miss. A collection runs inside the loop (DUPL churn); arm 3 repeats
# under SCRIP_GC_STRESS=1, so the cache's root walk is exercised at every poll.
# arm 1: both modes print sbl's answer.  arm 2: gdb at rt_defer_probe_run counts the calls by their site argument: 3072 cached
# (1024 sites x 3) and 1428 past the cap (476 x 3) -- the witness REACHES both roads, or the gate refuses.  arm 3: the stress run.
# arm 0 (CEO-1680, a proper test, no seam): the comparator grades a corrupted copy of sbl's answer and must read it RED.
set -u
G=test_gate_sno_defer_pair_sites_past_the_cap_take_the_uncached_road
HERE="$(cd "$(dirname "$0")" && pwd)"; SD="$HERE/../../SCRIP"; SCRIP="$SD/scrip"
[ -x "$SCRIP" ] || { echo "⛔ REFUSE(rc=2) [$G]: no scrip binary at $SCRIP -- build first (make)"; exit 2; }
"$HERE/util_require_fresh.sh" --gate "$G" "$SCRIP" "${RT_DIR:-$SD/out}/libscrip_rt.so" || exit 2
. "$HERE/lib_oracle_flags.sh"
SBL="$(sbl_correctness_bin)"; [ -x "$SBL" ] || { echo "⛔ REFUSE(rc=2) [$G]: no correctness oracle ($SBL) -- the ref is cut from the oracle at run time, never typed"; exit 2; }
command -v gdb >/dev/null || { echo "⛔ REFUSE(rc=2) [$G]: no gdb -- arm 2 cannot prove the witness reaches the road past the cap"; exit 2; }
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
cat > "$W/spill.sno" <<'EOF'
	sites  =  1500
	count  =  0
	i  =  0
LOOP	i  =  LT(i, sites) i + 1	:F(DONE)
	$('W' i)  =  'b' i
	pat  =  EVAL("'a' *W" i " . V" i)
	('ab' i)  pat	:F(BAD)
	IDENT($('V' i), 'b' i)	:F(BAD)
	$('W' i)  =  'c' i
	('ac' i)  pat	:F(BAD)
	IDENT($('V' i), 'c' i)	:F(BAD)
	('ab' i)  pat	:S(BAD)
	junk  =  DUPL('x', 64) i
	count  =  count + 1	:(LOOP)
DONE	OUTPUT  =  'ok ' count ' ' V1 ' ' V1024 ' ' V1025 ' ' V1500	:(END)
BAD	OUTPUT  =  'fail at ' i ' V=' $('V' i)
END
EOF
(cd "$W" && timeout -k 5 120 "$SCRIP" --compile -o spill.s spill.sno </dev/null >/dev/null 2>&1) \
    && gcc "$W/spill.s" -L"$SD/out" -lscrip_rt -lm -Wl,-rpath,"$SD/out" -o "$W/spill.bin" 2>/dev/null \
    || { echo "⛔ REFUSE(rc=2) [$G]: the witness did not compile and link in mode 4"; exit 2; }
want="$(cd "$W" && timeout -k 5 60 "$SBL" $(sbl_lang_flags) spill.sno </dev/null 2>/dev/null)"
[ "$want" = "ok 1500 c1 c1024 c1025 c1500" ] || { echo "⛔ REFUSE(rc=2) [$G]: the oracle printed '$want', not the witness's answer -- the arms cannot grade"; exit 2; }
grade() { [ "$1" = "$2" ]; }
bad="${want%0}9"
grade "$want" "$bad" && { echo "⛔ REFUSE(rc=2) [$G]: arm 0 -- the comparator read a corrupted ref ('$bad') as GREEN; it cannot fail"; exit 2; }
echo "== [$G] pair sites past the 1024 cap, graded against $SBL"
echo "  PASS arm0 the comparator reads a corrupted ref ('$bad') RED"
fail=0
run_m() { if [ "$1" = m3 ]; then (cd "$W" && timeout -k 5 120 env ${2:+$2} "$SCRIP" spill.sno </dev/null 2>&1); else (cd "$W" && timeout -k 5 120 env ${2:+$2} "$W/spill.bin" -- </dev/null 2>&1); fi; }
for m in m3 m4; do v="$(run_m $m)"; if grade "$v" "$want"; then echo "  PASS arm1 $m = sbl ($want)"; else echo "  ⛔ arm1 $m RED: got '$(printf '%s' "$v" | head -c 200)', sbl '$want'"; fail=1; fi; done
cat > "$W/count.gdb" <<'EOF'
set pagination off
set breakpoint pending on
break rt_defer_probe_run
commands
silent
if $rdx == -1
  set $neg = $neg + 1
else
  set $pos = $pos + 1
end
continue
end
set $neg = 0
set $pos = 0
run
printf "SITES cached=%d spilled=%d\n", $pos, $neg
EOF
for m in m3 m4; do
    if [ "$m" = m3 ]; then c="$(cd "$W" && timeout -k 5 300 gdb -q -batch -x count.gdb --args "$SCRIP" spill.sno </dev/null 2>&1 | grep -o 'SITES cached=[0-9]* spilled=[0-9]*')"
    else c="$(cd "$W" && timeout -k 5 300 gdb -q -batch -x count.gdb --args "$W/spill.bin" -- </dev/null 2>&1 | grep -o 'SITES cached=[0-9]* spilled=[0-9]*')"; fi
    [ "$c" = "SITES cached=3072 spilled=1428" ] || { echo "⛔ REFUSE(rc=2) [$G]: arm 2 $m -- gdb read '$c', not 3072 cached and 1428 past the cap: the witness no longer reaches both roads"; exit 2; }
    echo "  PASS arm2 $m reaches both roads ($c)"
done
for m in m3 m4; do v="$(run_m $m SCRIP_GC_STRESS=1)"; if grade "$v" "$want"; then echo "  PASS arm3 $m under SCRIP_GC_STRESS=1 = sbl"; else echo "  ⛔ arm3 $m stress RED: got '$(printf '%s' "$v" | head -c 200)'"; fail=1; fi; done
[ "$fail" = 0 ] && { echo "OK [$G]: 1024 cached pair sites and 476 past the cap answer as sbl, both modes, with and without collection stress"; exit 0; }
echo "⛔ GATE RED [$G]: a deferred-capture site past the pair cache's cap does not answer as sbl"; exit 1
