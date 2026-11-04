#!/usr/bin/env bash
# util_load_board.sh -- THE LEDGER FOR LON: WHO LOADED THE BOX (ARCH-SHARED-DEVELOPMENT.md 2.3, shared-dev step 1, R-2041). It reads
# /home/resources/progress/LOAD.tsv (written every five minutes by util_seat_census.py run) and never samples.
#   util_load_board.sh              the newest run: the BOX line, then every seat and class by cores, highest first
#   util_load_board.sh --hours N    the history over the last N hours: per seat its mean and peak cores, mean memory and the runs it was seen in,
#                                   then the BOX's mean busy cores and cpu pressure
# rc 0 printed, rc 2 no ledger.
set -u
L="${S4E_LOAD_TSV:-/home/resources/progress/LOAD.tsv}"
[ -s "$L" ] || { echo "REFUSED(2): no ledger at $L (util_seat_census.py run writes it)"; exit 2; }
H=0
[ "${1:-}" = "--hours" ] && H="${2:-1}"
exec python3 - "$L" "$H" <<'PY'
import sys, time, calendar
path, hours = sys.argv[1], float(sys.argv[2])
rows = [l.rstrip("\n").split("\t") for l in open(path) if l.strip() and not l.startswith("utc")]
if not rows:
    print("REFUSED(2): the ledger is empty"); sys.exit(2)
if hours <= 0:
    last = rows[-1][0]
    run = [r for r in rows if r[0] == last]
    box = next((r[4] for r in run if r[1] == "BOX"), "")
    print("LOAD %s  %s" % (last, box))
    for r in sorted((r for r in run if r[1] in ("UNIT", "CLASS")), key=lambda r: (r[1] != "CLASS", -float(r[4]))):
        print("  %-5s %-6s %-14s %6s cores  mem %6s MB  peak %6s MB  oom %s  pids %s  cc %s  run %s  tmp %s MB" % (r[1], r[2], r[3], r[4], r[5], r[6], r[7], r[8], r[9], r[10], r[11]))
    sys.exit(0)
cut = time.time() - hours * 3600
keep = [r for r in rows if calendar.timegm(time.strptime(r[0], "%Y-%m-%dT%H:%M:%SZ")) >= cut]
runs = sorted({r[0] for r in keep})
print("LOAD history: %d run(s) over the last %g hour(s), %s to %s" % (len(runs), hours, runs[0] if runs else "-", runs[-1] if runs else "-"))
acc = {}
for r in keep:
    if r[1] != "UNIT":
        continue
    e = acc.setdefault((r[2], r[3]), [0.0, 0.0, 0.0, 0])
    c = float(r[4]); e[0] += c; e[1] = max(e[1], c); e[2] += float(r[5]) if r[5].isdigit() else 0.0; e[3] += 1
for (cls, name), e in sorted(acc.items(), key=lambda kv: -kv[1][0] / max(1, kv[1][3])):
    print("  %-6s %-14s mean %5.2f cores  peak %5.2f  mem %6.0f MB  in %d run(s)" % (cls, name, e[0] / e[3], e[1], e[2] / e[3], e[3]))
busy, pres = [], []
for r in keep:
    if r[1] == "BOX":
        kv = dict(x.split("=", 1) for x in r[4].split() if "=" in x)
        try: busy.append(float(kv["cores_busy"])); pres.append(float(kv["pressure_some_avg60"]))
        except (KeyError, ValueError): pass
if busy:
    print("  BOX mean busy %.1f cores, mean cpu pressure %.0f, peak pressure %.0f" % (sum(busy) / len(busy), sum(pres) / len(pres), max(pres)))
PY
