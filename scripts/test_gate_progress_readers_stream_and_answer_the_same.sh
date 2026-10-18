#!/usr/bin/env bash
# test_gate_progress_readers_stream_and_answer_the_same.sh -- THE TWO PROGRESS-TABLE READERS STREAM THE TABLE AND GIVE THE SAME ANSWER
# THEY GAVE WHEN THEY HELD IT WHOLE.
#
# ⛔ THE DEFECT (coo 2026-09-23, the ceo's CEO-1212 under CEO-801, found by the memory-scope row's own measurement): two .github
# readers held the whole progress table -- 4.18M rows, 619 MB -- to answer questions about a few aggregates. util_progress_flips.py
# --ratchet built a dict per row (4,721,516 KB peak, the heaviest arm of the blocking set and the one that set its memory cap), and
# util_suite_banner.py's _progress_by_suite() kept every row (713,648 KB) behind every score-row write. Both grow with the table.
# THE CURE: ratchet_scan() reads the file twice with load()'s own csv dialect, row filter and column semantics and emulates its stable
# timestamp sort with (ts, file position) keys (14,456 KB); _progress_by_suite() keeps one record per (suite, program, mode, DAY), the
# last of that day, because likeforlike() only ever reads a day-end state and the newest state (146,304 KB). Same 4,180,597-row
# snapshot, old against new: the ratchet's output byte-identical, likeforlike and lfl_why identical for all 24 suites.
#
# THE ARMS. The OLD readers are taken from .github's own history -- the parent of the commit that introduced each cure, found with
# `git log -S`, never a copy kept here -- and run against the NEW ones on the SAME table:
#   1 ratchet, planted fixtures (both arms red, ties, more than 12 pairs, a lane that stops declaring, rows out of timestamp order,
#     rows without a timestamp or program): stdout and rc byte-identical, fixture by fixture.
#   2 ratchet refusals: an unnamed extra column (load()'s SystemExit) and a table with nothing after the baseline (rc 2) -- identical.
#   3 banner: likeforlike and lfl_why for every SUITES.tsv row on a planted table (days, same-day repeats, dirty trees, other modes,
#     and an equal-timestamp tie with different outcomes at a basis day-end AND at the newest reading) -- identical.
#   4 both readers on the live table's last 300,000 rows (header kept): identical answers, and the streaming ratchet's peak RSS under
#     64 MB there (a whole-table load of those rows measured about 340 MB), with every peak printed.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
. "$HERE/lib_gate.sh" || { echo "REFUSING(2): cannot load lib_gate.sh"; exit 2; }
GATE_NAME=progress_readers_stream_and_answer_the_same
GATE_STRICT=1
gate_parse_args "$@"
GH="$(cd "$ROOT/.." && pwd)/.github"
. "$(dirname "${BASH_SOURCE[0]}")/lib_suites_tsv.sh" || { echo "REFUSED(2): cannot load lib_suites_tsv.sh"; exit 2; }
F="$GH/scripts/util_progress_flips.py"; B="$GH/scripts/util_suite_banner.py"; DB="${S4E_PROGRESS_DB_LIVE:-/home/resources/progress/results.tsv}"
gate_require "$F" "util_progress_flips.py" || exit 2
gate_require "$B" "util_suite_banner.py" || exit 2
gate_require "$DB" "the live progress table (read, never written)" || exit 2
gate_require "$SUITES_TSV_REAL" ".github/SUITES.tsv" || exit 2
SCRATCH="${S4E_SCRATCH:-$(cd "$ROOT/.." && pwd)/.scratch}"
mkdir -p "$SCRATCH" || { echo "REFUSING(2) [$GATE_NAME]: cannot create $SCRATCH"; exit 2; }
WORK=$(mktemp -d "$SCRATCH/gate_progress_readers_XXXXXX") || exit 2
trap '[ -n "${WORK:-}" ] && rm -rf "$WORK"' EXIT INT TERM
fails=0; examined=0

# The old readers, from history: the parent of the commit that introduced each cure.
cf=$(git -C "$GH" log --format=%h -1 -S'def ratchet_scan' -- ../harness/scripts/util_progress_flips.py)
cb=$(git -C "$GH" log --format=%h -1 -S'ONE RECORD PER (suite, program, mode, DAY)' -- ../harness/scripts/util_suite_banner.py)
if [ -z "$cf" ] || [ -z "$cb" ]; then echo "GATE UNPROVEN(2) [$GATE_NAME]: the cure commits are not in $GH's history (ratchet '$cf', banner '$cb') -- pull .github"; gate_stamp; exit 2; fi
mkdir -p "$WORK/old"
git -C "$GH" show "$cf^:../harness/scripts/util_progress_flips.py" > "$WORK/old/util_progress_flips.py" || { echo "GATE UNPROVEN(2) [$GATE_NAME]: cannot read the old ratchet at $cf^"; gate_stamp; exit 2; }
git -C "$GH" show "$cb^:../harness/scripts/util_suite_banner.py" > "$WORK/old/util_suite_banner.py" || { echo "GATE UNPROVEN(2) [$GATE_NAME]: cannot read the old banner at $cb^"; gate_stamp; exit 2; }
# The seven rung suites were renamed after both cures (Lon 2026-09-29: sno-master -> sno-rungs, snobol4-master -> snobol4-rungs,
# class master -> rungs): the old readers get the same names, so the comparison stays one of algorithms, never of spellings.
perl -pi -e 's/\b(sno|icn|pl|pas|raku|snc|reb|snobol4|icon|prolog|pascal|snocone|rebus)-master\b/$1-rungs/g; s/(["\x27])master\1/$1rungs$1/g; s/board_icon_master/board_icon_rungs/g' "$WORK/old/util_progress_flips.py" "$WORK/old/util_suite_banner.py"
echo "  old readers: util_progress_flips.py at $cf^, util_suite_banner.py at $cb^ (.github history)"

HDR="$(head -1 "$DB")"
# fixture <name> <rows-python> -- write a table with the live header and rows built by a python expression over the column names
fixture() {
  python3 - "$WORK/$1.tsv" "$HDR" <<PY
import sys
out, hdr = sys.argv[1], sys.argv[2].split('\t')
def row(**kw):
    return '\t'.join(kw.get(c, '') for c in hdr)
def short(n_keep, **kw):
    return '\t'.join(kw.get(c, '') for c in hdr[:n_keep])
rows = $2
open(out, 'w', encoding='utf-8').write('\t'.join(hdr) + '\n' + ''.join(r + '\n' for r in rows))
PY
}
# ratchet_cmp <table> -- old and new --ratchet on one table: stdout, stderr and rc must agree.
ratchet_cmp() {
  python3 "$WORK/old/util_progress_flips.py" --db "$1" --ratchet > "$WORK/o.out" 2> "$WORK/o.err"; orc=$?
  python3 "$F" --db "$1" --ratchet > "$WORK/n.out" 2> "$WORK/n.err"; nrc=$?
  [ "$orc" = "$nrc" ] && cmp -s "$WORK/o.out" "$WORK/n.out" && cmp -s "$WORK/o.err" "$WORK/n.err"
}
BASE=2026-09-21T17:53:17
CI="$(printf '%s\n' "$HDR" | tr '\t' '\n' | grep -nx config | cut -d: -f1)"

# ARM 1 -- ratchet, planted fixtures.
examined=$((examined+1)); a1=""
fixture green "[row(ts_utc='2026-09-22T0%d:00:00' % i, program='p%d' % i, mode='m3', suite='s%d' % (i % 2), measurer='hq_a', config='shipped', outcome='PASS') for i in range(6)]"
fixture redA "[short($CI - 1, ts_utc='2026-09-22T10:%02d:00' % (i % 60), program='p', mode='m3', suite='s%d' % (i % 14), measurer='hq_%d' % (i % 3)) for i in range(60)] + [row(ts_utc='2026-09-22T09:00:00', program='q', mode='m4', suite='s0', measurer='hq_0', config='shipped')]"
fixture redB "[row(ts_utc=t, program=p, mode=m, suite=s, measurer=who, config=c) for (t, p, m, s, who, c) in [('2026-09-22T12:00:00','a','m3','s1','hq_x','shipped'), ('2026-09-22T11:00:00','b','m3','s1','hq_x',''), ('2026-09-22T12:00:00','c','m4','s1','hq_x',''), ('2026-09-22T13:00:00','d','m3','s1','hq_x',''), ('2026-09-22T12:30:00','e','m3','s2','hq_y','SCRIP_GC_STRESS=5'), ('2026-09-22T12:30:00','f','m3','s2','hq_y',''), ('2026-09-22T14:00:00','g','m4','s2','hq_y',''), ('2026-09-22T15:00:00','h','m3','s3','hq_z',''), ('2026-09-20T15:00:00','i','m3','s1','hq_x','')]] + [row(ts_utc='', program='j', mode='m3', suite='s1', measurer='hq_x'), row(ts_utc='2026-09-22T16:00:00', program='', mode='m3', suite='s1', measurer='hq_x')]"
# redA2 DISCRIMINATES THE ORDERS a regular fixture cannot: pairs A and B tie at two short rows each, A's first row precedes B's
# while A's LAST row follows B's (a max-key or last-seen implementation reorders them), and pair C's two rows sit in the file out
# of timestamp order (a file-order implementation takes the wrong one as first); thirteen one-row pairs push past the 12 printed.
fixture redA2 "[short($CI - 1, ts_utc=t, program='p', mode='m3', suite=s, measurer=m) for (t, s, m) in [('2026-09-22T10:00:00','sA','hq_1'), ('2026-09-22T10:05:00','sB','hq_1'), ('2026-09-22T10:06:00','sB','hq_1'), ('2026-09-22T10:30:00','sC','hq_2'), ('2026-09-22T10:01:00','sC','hq_2'), ('2026-09-22T10:10:00','sA','hq_1')] + [('2026-09-22T11:%02d:00' % i, 'sx%d' % i, 'hq_9') for i in range(13)]]"
# redB2 DISCRIMINATES THE DECLARE ORDER: a lane's declared row sits LATER in the file but EARLIER in time than undeclared rows it must
# count, an undeclared row at the SAME timestamp as the declaration counts only if it follows it in the file, and two lanes tie on
# their count so their printed order is their first undeclared row's (ts, position).
fixture redB2 "[row(ts_utc=t, program=p, mode='m3', suite=s, measurer=who, config=c) for (t, p, s, who, c) in [('2026-09-22T12:10:00','u1','s1','hq_x',''), ('2026-09-22T12:00:00','u2','s1','hq_x',''), ('2026-09-22T11:00:00','d1','s1','hq_x','shipped'), ('2026-09-22T11:00:00','u3','s1','hq_x',''), ('2026-09-22T12:05:00','v1','s2','hq_y',''), ('2026-09-22T09:00:00','d2','s2','hq_y','shipped'), ('2026-09-22T12:01:00','v2','s2','hq_y',''), ('2026-09-22T12:02:00','v3','s2','hq_y','')]]"
for fx in green redA redB redA2 redB2; do ratchet_cmp "$WORK/$fx.tsv" || a1="${a1:+$a1, }$fx (old rc=$orc new rc=$nrc)"; done
[ -z "$a1" ] || { fails=$((fails+1)); echo "  FAIL arm1: the streaming ratchet answers differently on: $a1"; diff "$WORK/o.out" "$WORK/n.out" | head -6 | sed 's/^/        /'; }

# ARM 2 -- ratchet refusals.
examined=$((examined+1)); a2=""
fixture unnamed "[row(ts_utc='2026-09-22T10:00:00', program='p', mode='m3', suite='s', measurer='hq', config='shipped') + '\textra1\textra2']"
fixture empty "[row(ts_utc='2026-09-01T10:00:00', program='p', mode='m3', suite='s', measurer='hq', config='shipped')]"
for fx in unnamed empty; do ratchet_cmp "$WORK/$fx.tsv" || a2="${a2:+$a2, }$fx (old rc=$orc new rc=$nrc)"; done
[ -z "$a2" ] || { fails=$((fails+1)); echo "  FAIL arm2: the refusals differ on: $a2"; }

# ARM 3 -- banner likeforlike/lfl_why on a planted table, every SUITES.tsv row.
examined=$((examined+1))
cat > "$WORK/lfl.py" <<'PY'
import sys, json, importlib.util
spec = importlib.util.spec_from_file_location("usb", sys.argv[1]); m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
_h, rows = m.load()
print(json.dumps({r['key']: [m.likeforlike(r), m.lfl_why(r)] for r in rows}, sort_keys=True))
PY
fixture lfl "[row(ts_utc='2026-09-%02dT%02d:%02d:00' % (d, h, mi), scrip=('abc1234-dirty' if (d + h) % 7 == 0 else 'abc1234'), suite=s, program='x/%s/p%d.sno' % (s, pn), mode=md, outcome=o) for d in (18, 19, 21, 23) for h in (3, 9, 9, 15) for mi in (0, 30) for s in ('snobol4-rungs', 'gimpel', 'icon-rungs', 'rebus-rungs') for pn in range(4) for md in ('m3', 'm4', 'ast') for o in [('PASS' if (d + pn + h) % 3 else 'FAIL')]] + [row(ts_utc=t, scrip='abc1234', suite='rebus-rungs', program='x/rebus/z.reb', mode=md, outcome=o) for (t, md, o) in [('2026-09-18T12:00:00', 'm4', 'PASS'), ('2026-09-18T23:59:59', 'm3', 'FAIL'), ('2026-09-18T23:59:59', 'm3', 'PASS'), ('2026-09-23T18:00:00', 'm3', 'FAIL'), ('2026-09-23T18:00:00', 'm3', 'PASS'), ('2026-09-23T18:00:00', 'm4', 'PASS')]]"
o3=$(S4E_PROGRESS="$WORK/lfl.tsv" S4E_SUITES_TSV="$SUITES_TSV_REAL" python3 "$WORK/lfl.py" "$WORK/old/util_suite_banner.py" 2>&1); n3=$(S4E_PROGRESS="$WORK/lfl.tsv" S4E_SUITES_TSV="$SUITES_TSV_REAL" python3 "$WORK/lfl.py" "$B" 2>&1)
if [ "$o3" != "$n3" ] || ! printf '%s' "$n3" | grep -q '"then"'; then
  fails=$((fails+1)); echo "  FAIL arm3: likeforlike/lfl_why differ on the planted table (or compared nothing)"
fi

# ARM 4 -- the live table's last 300,000 rows: same answers, and the streaming ratchet in constant memory.
examined=$((examined+1)); a4=""
{ head -1 "$DB"; tail -n 300000 "$DB"; } > "$WORK/live.tsv"
peak() { /usr/bin/time -f '%M' "$@" 2>&1 >/dev/null | tail -1; }
ratchet_cmp "$WORK/live.tsv" || a4="the ratchet (old rc=$orc new rc=$nrc)"
po=$(peak python3 "$WORK/old/util_progress_flips.py" --db "$WORK/live.tsv" --ratchet); pn=$(peak python3 "$F" --db "$WORK/live.tsv" --ratchet)
o4=$(S4E_PROGRESS="$WORK/live.tsv" S4E_SUITES_TSV="$SUITES_TSV_REAL" python3 "$WORK/lfl.py" "$WORK/old/util_suite_banner.py" 2>&1); n4=$(S4E_PROGRESS="$WORK/live.tsv" S4E_SUITES_TSV="$SUITES_TSV_REAL" python3 "$WORK/lfl.py" "$B" 2>&1)
[ "$o4" = "$n4" ] || a4="${a4:+$a4; }likeforlike"
bo=$(S4E_PROGRESS="$WORK/live.tsv" S4E_SUITES_TSV="$SUITES_TSV_REAL" peak python3 "$WORK/lfl.py" "$WORK/old/util_suite_banner.py"); bn=$(S4E_PROGRESS="$WORK/live.tsv" S4E_SUITES_TSV="$SUITES_TSV_REAL" peak python3 "$WORK/lfl.py" "$B")
echo "  live sample (300000 rows): ratchet peak ${po} KB old -> ${pn} KB new; banner peak ${bo} KB old -> ${bn} KB new"
[ "${pn:-999999}" -lt 65536 ] 2>/dev/null || a4="${a4:+$a4; }the streaming ratchet peaked at ${pn} KB (want under 64 MB -- it holds aggregates, never rows)"
[ -z "$a4" ] || { fails=$((fails+1)); echo "  FAIL arm4: $a4"; }

GATE_EXAMINED=$examined
gate_verdict "$fails" "arm(s) failed (the streaming progress readers must answer exactly as the whole-table readers did)"
