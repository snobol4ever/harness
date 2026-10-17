#!/usr/bin/env bash
# Companion negative-test harness for test_gate_snobol4_xfail_markers_are_attributed.sh.
# ⛔ NOT a gate and deliberately NOT named test_gate_*: it is not wired into `make test`, it PROVES the
# gate beside it can both pass and refuse. A gate whose failure paths were never exercised is the
# skip-as-success class waiting to happen -- run this whenever that gate is edited.
# Negative-test every refusal path of test_gate_snobol4_xfail_markers_are_attributed.sh v2.
set -u
SC=/tmp/claude-1000/-home-claude-P/12837230-fb57-4e2f-9250-db2687c007e5/scratchpad
G=/home/claude_P/harness/scripts/test_gate_snobol4_xfail_markers_are_attributed.sh
cd /home/claude_P/SCRIP
run() { printf '%-46s ' "$1"; shift; "$@" >/dev/null 2>&1; echo "rc=$?"; }

echo "ARM 1 real tree (expect rc=1, red today)"
run "  real" bash "$G"

echo "ARM 2 missing QUEUE (expect rc=2)"
run "  missing" env S4E_QUEUE=/nonexistent/Q.tsv bash "$G"

echo "ARM 3 QUEUE parses to zero rows (expect rc=2)"
: > "$SC/empty_queue.tsv"
run "  empty" env S4E_QUEUE="$SC/empty_queue.tsv" bash "$G"

# ARM 4/5 need a rewritten copy pointing at synthetic corpus files
mk() { sed -e "s|^RUNGS_XFAIL=.*|RUNGS_XFAIL=\"$1\"|" -e "s|^RUNGS_CSV=.*|RUNGS_CSV=\"$2\"|" "$G" > "$SC/g.sh"; }

echo "ARM 4 missing ALL.csv (expect rc=2 -- the population is gone)"
mk "/home/claude_P/corpus/tests/snobol4/ALL.xfail" "/nonexistent/ALL.csv"
run "  no csv" bash "$SC/g.sh"

echo "ARM 5 ALL.csv with no xfail column (expect rc=2 -- schema moved)"
printf 'entry,rank\nfoo,1\n' > "$SC/noschema.csv"
mk "/home/claude_P/corpus/tests/snobol4/ALL.xfail" "$SC/noschema.csv"
run "  no column" bash "$SC/g.sh"

echo "ARM 6 POSITIVE CONTROL: every xfail has a reason AND names a live row (expect rc=0)"
python3 - <<'PY'
import re, csv
B=re.compile(r"^\*-+ (?P<seq>\d+) (?P<name>\S+)( XFAIL)?$")
D="/home/claude_P/corpus/tests/snobol4/"
SC="/tmp/claude-1000/-home-claude-P/12837230-fb57-4e2f-9250-db2687c007e5/scratchpad/"
names, out, cur = [], [], None
for ln in open(D+"ALL.xfail", encoding="utf-8", errors="replace"):
    m=B.match(ln.rstrip("\n"))
    if m: out.append(ln); names.append(m.group("name")); cur=m.group("name")
    elif cur: out.append("routed to `synthetic-control-row`\n"); cur=None
    else: out.append(ln)
open(SC+"all_attributed.xfail","w").write("".join(out))
rows=list(csv.DictReader(open(D+"ALL.csv")))
keep=set(names)
for r in rows: r["xfail"]="1" if r["entry"] in keep else "0"
w=csv.DictWriter(open(SC+"synth.csv","w",newline=""), fieldnames=rows[0].keys())
w.writeheader(); w.writerows(rows)
print("   synthetic: %d xfail entries, all with a reason naming a live row" % len(keep))
PY
printf '9\tsynthetic-control-row\thq_P\tFREE\n' > "$SC/synth_queue.tsv"
mk "$SC/all_attributed.xfail" "$SC/synth.csv"
run "  all attributed" env S4E_QUEUE="$SC/synth_queue.tsv" bash "$SC/g.sh"
