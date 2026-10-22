#!/usr/bin/env bash
# util_suite_row_at_100.sh <suite-key> -- ONE SUITE TABLE ROW AT 100 PERCENT, READ, NEVER RUN (ceo CEO-1903; Lon 2026-10-22 12:0x CDT, in-chat to the ceo,
# verbatim: "Get both HQ-JVM and HQ-DOTNET working with leader boards."). The DONE-WHEN of a board row -- a port engine's <key>@<engine> (gimpel@jvm,
# sno-rungs@dotnet) or SCRIP's bare key -- reads /home/resources/progress/SUITES.tsv by header name and runs nothing: the row moves only when the coo's
# loop grades its programs and util_score_row.py writes it, so a seat's `done` measures the board instead of running one (CEO-1342, CEO-1872).
#   rc 0  today_pass == today_total > 0 and the row is not VOID      (printed: SUITE_ROW key pass/total date tree)
#   rc 1  below 100 percent, or VOID                                  (printed the same way, with the count still owed)
#   rc 2  could not measure: no key, no such row, an unreadable table, a reading that is not a number
set -u
K="${1:-}"; T=/home/resources/progress/SUITES.tsv
[ -n "$K" ] || { echo "REFUSE(2): usage: util_suite_row_at_100.sh <suite-key>"; exit 2; }
[ -r "$T" ] || { echo "REFUSE(2): $T unreadable"; exit 2; }
python3 - "$K" "$T" <<'PYEOF'
import sys
k, t = sys.argv[1], sys.argv[2]
rows = [l.rstrip("\n").split("\t") for l in open(t, encoding="utf-8") if not l.startswith("#")]
h = rows[0]; r = next((dict(zip(h, x)) for x in rows[1:] if x and x[0] == k), None)
if r is None: print("REFUSE(2): no row %s in %s" % (k, t)); sys.exit(2)
try: p, n = int(r["today_pass"]), int(r["today_total"])
except (ValueError, KeyError): print("REFUSE(2): %s has no reading in %s" % (k, t)); sys.exit(2)
void = (r.get("today_void") or "").strip()
line = "SUITE_ROW %s %d/%d %s tree=%s" % (k, p, n, r.get("today_date", ""), r.get("tree", ""))
if n > 0 and p >= n and not void: print(line + " -- at 100 percent"); sys.exit(0)
print(line + (" -- VOID: %s" % void if void else " -- %d owed" % (n - p))); sys.exit(1)
PYEOF
