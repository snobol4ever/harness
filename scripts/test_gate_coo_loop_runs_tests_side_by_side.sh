#!/usr/bin/env bash
# test_gate_coo_loop_runs_tests_side_by_side.sh [results.tsv] [hours] -- THE coo's ROUND ROBIN RUNS SEVERAL TESTS AT ONCE, AT MOST FOUR (Lon
# 2026-10-31, in-chat to the ceo, verbatim: "Then release my restriction and run as many as would be prudent to match the tradeoffs of other seats
# work versus completing in a timely fashion."; ceo CEO-2068, lifting CEO-1805/1891's one test at a time). Reads the coo's rr=1 readings in
# progress/results.tsv over the last HOURS (default 6). A program's interval is [end - its summed m3+m4 secs, end]. GREEN when some program of
# at least 3 s holds another program's end strictly inside its interval with a 1 s margin either side (a serial loop cannot produce that), and no
# instant inside such a long interval sees more than 4 programs (the cap; short programs can only be undercounted, so the cap arm never reads a
# false red). RED rc 1 otherwise. REFUSES rc 2 with no readable table or no coo rr=1 reading in the window.
f="${1:-/home/resources/progress/results.tsv}"
[ -r "$f" ] || { echo "REFUSE(2): no results table at $f"; exit 2; }
python3 - "$f" "${2:-6}" <<'PY'
import sys, csv, datetime as dt
path, hours = sys.argv[1], float(sys.argv[2])
now = dt.datetime.now(dt.timezone.utc).replace(tzinfo=None)
lo = now - dt.timedelta(hours=hours)
prog = {}
with open(path, newline='') as fh:
    for r in csv.DictReader(fh, delimiter='\t'):
        if r.get('measurer') != 'coo' or 'rr=1' not in (r.get('config') or ''):
            continue
        try:
            t = dt.datetime.fromisoformat(r['ts_utc'][:19]); s = float(r['secs'] or 0)
        except (ValueError, KeyError):
            continue
        if t < lo:
            continue
        k = (r['suite'], r['program'], r['ts_utc'][:19])
        e = prog.setdefault(k, [t, 0.0]); e[1] += s
if not prog:
    print("REFUSE(2): no coo rr=1 reading in the last %g h of %s" % (hours, path)); sys.exit(2)
iv = [(t - dt.timedelta(seconds=s), t, s, k) for k, (t, s) in prog.items()]
ends = sorted(t for _, t, _, _ in iv)
side, peak = 0, 1
one = dt.timedelta(seconds=1)
for a, b, s, k in iv:
    if s < 3:
        continue
    inside = [e for e in ends if a + one < e < b - one]
    if inside:
        side += 1
    for e in inside:
        peak = max(peak, sum(1 for a2, b2, _, _ in iv if a2 <= e <= b2))
print("COO_LOOP_SIDE_BY_SIDE programs=%d long_with_overlap=%d peak=%d cap=4 window=%gh" % (len(iv), side, peak, hours))
sys.exit(0 if side > 0 and peak <= 4 else 1)
PY
