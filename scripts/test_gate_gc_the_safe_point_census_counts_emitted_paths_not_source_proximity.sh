#!/usr/bin/env bash
# ../harness/scripts/test_gate_gc_the_safe_point_census_counts_emitted_paths_not_source_proximity.sh
# THE SAFE-POINT CENSUS MUST NOT READ A PARTIAL CURE AS A WHOLE ONE (coo, CEO-1109 rank 0, 2026-09-22).
#
# ⛔ THE DEFECT, FOUND BY THE cto AND NOT BY READING THE CODE.  util_gc_census.py safe-points decides POLLED
# by finding poll text in SOURCE within --poll-window lines after the call.  POLLED is a claim about EMITTED
# CONTROL FLOW, and the emitter builds its output by string concatenation, so a call written ONCE inside a
# file-local helper or a #define is spliced into EVERY path that expands that unit.  Where a unit expands
# more than once the two questions come apart, and they come apart in the worst direction: ONE poll in a
# shared body reads the site fully POLLED however many of its paths carry it.  bb_assign_global's comm_var
# tap is that shape -- one x86("call", ...) line, FOUR expansion sites -- and at one of them the fresh
# string is live only in rax:rdx, rooted nowhere.  The cto declined to poll the rooted paths alone and left
# the tap unpolled, which is why this is an instrument row and not a retraction of anyone's landing.
#
# ⛔ THIS GATE PLANTS ITS OWN FAILURE RATHER THAN ASSERTING IT.  The tree cannot produce the bad shape on
# demand -- today partially_polled reads 0 -- so an arm proven only by reading is no arm at all.  FAIL_ONCE
# builds a mktemp root whose bb_assign_global.cpp carries a poll GUARDED BY g_gva_active, which genuinely
# reaches two of the four expansions, and requires the census to call it PARTIAL.  Under the old criterion
# that same plant read a clean POLLED, and the gate proves that too by showing the poll text IS inside the
# source window it would have been read from.  ⛔ NOTHING UNDER src/ IS TOUCHED: the fixture symlinks the
# real .so and the other emitter directories and copies only src/templates/bb (CEO-547 -- a gate's own
# mktemp fixture outside the corpus tree is not a board).
#
# ARMS, EACH BY EXIT CODE: 0 the census declares multi_path_sites and partially_polled, the identity
# partitions the denominator, and the unplanted fixture reads the cto's tap UNPOLLED (their own account of
# what they did); 1 the planted two-of-four reads anything but PARTIAL; 2 a prerequisite is missing.
set -uo pipefail
# ⛔ NO `printf ... | grep -q` IN THIS GATE.  grep -q exits at the first match, printf takes SIGPIPE, and under
# `set -o pipefail` the pipeline then reports FAILURE on a successful match.  It only bites on output big enough
# that printf is still writing -- SCRIP_GC_CENSUS_LIST_ALL prints ~1 MB here -- so it passes on a small fixture and
# lies on the real one.  Every match below is a herestring.
cd "$(dirname "$0")/../../SCRIP" || exit 2
ROOT=$PWD
CENSUS=../harness/scripts/util_gc_census.py
SO=out/libscrip_rt.so
SRC=src/templates/bb/bb_assign_global.cpp

[ -r "$CENSUS" ] || { echo "GATE safe-point-emitted-paths REFUSED(2): $CENSUS missing"; exit 2; }
[ -r "$SO" ]     || { echo "GATE safe-point-emitted-paths REFUSED(2): $SO missing -- run make first"; exit 2; }
[ -r "$SRC" ]    || { echo "GATE safe-point-emitted-paths REFUSED(2): $SRC missing (renamed? tell the gate)"; exit 2; }
# ⛔ THE TAP IS FOUND BY ITS CALL, NEVER BY A PINNED LINE NUMBER (cto 2026-09-26, on the cfo's report): the four arms below used to
# match `bb_assign_global.cpp:37:comm_var`, and d752e30eb (the tap under --stlimit) moved the call to line 36, so the gate read RED
# on origin for two days over a listing that printed the site POLLED with the expected form -- the same keys-by-line defect the bare-poll
# table had. The census names a site by the line of its x86("call") and there is exactly one comm_var call in this template.
TAPLN=$(grep -n 'x86("call", "comm_var_open"' "$SRC" | cut -d: -f1 | head -1)
[ -n "$TAPLN" ] && [ "$(grep -c 'x86("call", "comm_var_open"' "$SRC")" -eq 1 ] || { echo "GATE safe-point-emitted-paths REFUSED(2): $SRC does not carry exactly one comm_var call -- the tap moved or split, tell the gate"; exit 2; }
command -v python3 >/dev/null || { echo "GATE safe-point-emitted-paths REFUSED(2): no python3"; exit 2; }

D=$(mktemp -d) || { echo "GATE safe-point-emitted-paths REFUSED(2): mktemp failed"; exit 2; }
trap 'rm -rf "$D"' EXIT
mkdir -p "$D/out" "$D/src/templates" || exit 2
ln -s "$ROOT/out/libscrip_rt.so" "$D/out/libscrip_rt.so"      || exit 2
ln -s "$ROOT/src/emitter"        "$D/src/emitter"             || exit 2
ln -s "$ROOT/src/templates/xa"   "$D/src/templates/xa"        || exit 2
ln -s "$ROOT/src/templates/x86"  "$D/src/templates/x86"       || exit 2
cp -r "$ROOT/src/templates/bb"   "$D/src/templates/bb"        || exit 2

run_census() { SCRIP_GC_CENSUS_LIST_ALL=1 timeout -k 5 600 python3 "$ROOT/$CENSUS" safe-points --list-polled --root "$1" 2>&1; }

# ---- ARM A: the columns exist at all, and they partition the denominator -------------------------------
base=$(run_census "$D") || true
line=$(grep -m1 '^CENSUS safe-points emitter_call_sites=' <<<"$base")
[ -n "$line" ] || { echo "GATE safe-point-emitted-paths REFUSED(2): census printed no headline"; exit 2; }
grep -qE 'multi_path_sites=[0-9]+' <<<"$line"   || { echo "GATE safe-point-emitted-paths RED: no multi_path_sites column -- $line"; exit 1; }
grep -qE 'partially_polled=[0-9]+' <<<"$line"   || { echo "GATE safe-point-emitted-paths RED: no partially_polled column -- $line"; exit 1; }
grep -q '^CENSUS safe-points IDENTITY' <<<"$base" || { echo "GATE safe-point-emitted-paths RED: no identity line"; exit 1; }
mp=$(grep -oE 'multi_path_sites=[0-9]+' <<<"$line" | head -1 | cut -d= -f2)
[ "${mp:-0}" -gt 0 ] || { echo "GATE safe-point-emitted-paths RED: multi_path_sites=0 -- a tree with spliced helpers cannot have none; the reader is blind"; exit 1; }

# ---- ARM B: the comm_var tap reads POLLED unplanted (the cto polled it in dc6c47216, form poll_res), and a copy
# ---- with that poll REMOVED reads UNPOLLED -- the reader can see an unpolled site, proven on a doctored copy and
# ---- no longer asserted on the real tree, which since 2026-09-24 has none (cto, the seventeen-red row) ---------
grep -qE '^  POLLED .*bb_assign_global\.cpp:'"$TAPLN"':comm_var_open form=x86_rt_gc_poll_res' <<<"$base" \
  || { echo "GATE safe-point-emitted-paths RED: the unplanted comm_var tap does not read POLLED with form x86_rt_gc_poll_res -- the tap's poll (dc6c47216) moved or the reader lost the site"; grep -E 'bb_assign_global' <<<"$base" | head -3; exit 1; }
python3 - "$D/src/templates/bb/bb_assign_global.cpp" <<'UNPLANT' || { echo "GATE safe-point-emitted-paths REFUSED(2): the unpoll doctoring failed"; exit 2; }
import io,sys
p=sys.argv[1]; s=io.open(p,encoding='utf-8').read()
b='+ x86("pop", "rax") + x86_rt_gc_poll_res();\n'
assert b in s, "unpoll anchor missing"
s=s.replace(b, '+ x86("pop", "rax");\n', 1)
io.open(p,'w',encoding='utf-8').write(s)
UNPLANT
unpolled=$(run_census "$D") || true
grep -qE '^  UNPOLLED .*bb_assign_global\.cpp:'"$TAPLN"':comm_var_open' <<<"$unpolled" \
  || { echo "GATE safe-point-emitted-paths RED: with the tap's poll removed on a copy the census still does not read it UNPOLLED -- the reader is blind to an unpolled site"; grep -E 'bb_assign_global' <<<"$unpolled" | head -3; exit 1; }

# ---- ARM C: FAIL ONCE. On that copy plant a poll that genuinely reaches two of the four expansions ---------
python3 - "$D/src/templates/bb/bb_assign_global.cpp" <<'PLANT' || { echo "GATE safe-point-emitted-paths REFUSED(2): plant failed"; exit 2; }
import io,sys
p=sys.argv[1]; s=io.open(p,encoding='utf-8').read()
a='x86("call", "comm_var_open", (uint64_t)(uintptr_t)(void *)comm_var_open)\n'
assert a in s, "plant anchor missing"
s=s.replace(a, a + '         + IF(g_gva_active, x86("lea", "rax", "[rip + g_gc_pending]"))\n', 1)
io.open(p,'w',encoding='utf-8').write(s)
PLANT
planted=$(run_census "$D") || true
pline=$(grep -m1 '^CENSUS safe-points emitter_call_sites=' <<<"$planted")
if ! grep -qE '^  PARTIAL .*bb_assign_global\.cpp:'"$TAPLN"':comm_var_open' <<<"$planted"; then
  echo "GATE safe-point-emitted-paths RED: a poll guarded by g_gva_active reaches two of the tap's four expansions,"
  echo "  and the census did not call the site PARTIAL. A partial cure counted as whole is DARK wearing a number."
  echo "  headline: $pline"
  grep -E '^  (PARTIAL|UNPOLLED) .*bb_assign_global' <<<"$planted" | sed 's/^/  /'
  exit 1
fi
if grep -qE '^  UNPOLLED .*bb_assign_global\.cpp:'"$TAPLN"':comm_var_open' <<<"$planted"; then
  echo "GATE safe-point-emitted-paths RED: the planted site reads UNPOLLED and PARTIAL at once"; exit 1
fi
# and the old criterion really would have read it POLLED: the poll text sits inside the source window
awk -v t="$TAPLN" 'NR>=t+1 && NR<=t+12' "$D/src/templates/bb/bb_assign_global.cpp" | grep -q 'g_gc_pending' \
  || { echo "GATE safe-point-emitted-paths REFUSED(2): the plant did not land inside the poll window -- the fail-once proves nothing"; exit 2; }
pp=$(grep -oE 'partially_polled=[0-9]+' <<<"$pline" | head -1 | cut -d= -f2)
[ "${pp:-0}" -ge 1 ] || { echo "GATE safe-point-emitted-paths RED: PARTIAL named but partially_polled=$pp"; exit 1; }

# ---- ARM D: a partial is NOT counted as polled: the copy took the tap OUT of the polled column (one fewer than
# ---- the real tree) and the guarded poll must not put it back ----------------------------------------------
bp=$(grep -oE ' polled=[0-9]+' <<<"$line"  | head -1 | tr -d ' ' | cut -d= -f2)
np=$(grep -oE ' polled=[0-9]+' <<<"$pline" | head -1 | tr -d ' ' | cut -d= -f2)
[ "$np" = "$((bp - 1))" ] || { echo "GATE safe-point-emitted-paths RED: polled reads $np on the doctored copy against $bp on the tree (want $((bp - 1)): the tap left the column and a guarded poll must not buy it back)"; exit 1; }

echo "GATE safe-point-emitted-paths GREEN: allocating_call_sites=$(grep -oE 'allocating_call_sites=[0-9]+' <<<"$line" | head -1 | cut -d= -f2)"\
" polled=$bp partially_polled=$(grep -oE 'partially_polled=[0-9]+' <<<"$line" | head -1 | cut -d= -f2)"\
" multi_path_sites=$mp; planted two-of-four reads PARTIAL and buys no polled cell (fail-once proven, not asserted)"
exit 0
