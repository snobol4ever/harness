#!/usr/bin/env python3
# util_premise_census.py (coo, 2026-09-20 -- row instruments-claim-computes-the-rows-premise-the-way-done-
# computes-its-done-when; ceo CEO-1002).  THE BACKLOG IS NAMED RATHER THAN SILENTLY EXEMPT.
#
# `claim` and `next` now RUN a baton's PREMISE-WHEN and refuse the lock when it comes back red (the one
# cheap command proving the row's central claim is still true on today's tree).  Almost every live baton
# predates the field, and those rows are ADMITTED -- an absent premise may never block work.  That is the
# right call and it is also exactly how a field quietly never gets adopted: the seat is told once, at claim
# time, in a line they can scroll past, and nothing ever counts how many rows are dispatched unchecked.
# This census is the counting.  It answers one question per row -- CAN this row's premise be expressed, and
# IS it -- and it reports by OWNER, because the fix is per-seat and a fleet total is nobody's job.
#
# CLASSES (a row is in exactly one):
#   OK       a runnable PREMISE-WHEN.  The lock is computed for this row.
#   NONE     no PREMISE-WHEN line.  Dispatched unchecked; this is the backlog.
#   STUB     the mint placeholder, still unexpressed.  Visible to its author and never filled in.
#   VACUOUS  a PREMISE-WHEN that certifies nothing (`true`, `:`, a bare `echo`).  ⛔ WORSE THAN NONE: it
#            reads as a checked row to anyone scanning the file, and the gate has to say "certifies nothing"
#            to a seat who believes they wrote one.  The entry-side form of the false green.
#   BROKEN   a PREMISE-WHEN that is not readable as shell (an unclosed heredoc, a dangling continuation).
#            bash would run NOTHING and exit 0 -- it would read GREEN.  The gate refuses to run these.
#   NOBATON  a live QUEUE row with NO task file.  ⛔ THE ONLY CLASS THAT GENUINELY CANNOT EXPRESS A PREMISE:
#            there is no file to write it in.  Named separately so "cannot" is never confused with "has not".
#
# ⛔ THIS COUNTS LIVE ROWS, NOT FILES.  The tasks/ tree holds finished and retired work; a premise on a row
# nobody will ever claim again is not debt, and counting it would inflate the number in the direction that
# invites action rather than scrutiny (the class hq_P's 112-vs-44 over-report taught this fleet).  A row is
# LIVE when QUEUE.tsv carries it and its state is not DONE.  --all drops that filter and says so in the head.
# Exit 0 when every live row's premise is expressed; 1 with findings; 2 if the postoffice is unreadable
# (REFUSE, never a silent green -- a census that cannot read its subject has measured nothing).
# ⛔ NOT WIRED INTO `make test`.  rc=1 here means "the fleet has not written N premises yet", which is a
# true statement about the backlog and not a broken invariant; wiring it would red every seat for work in
# progress.  The GATE (test_gate_claim_computes_the_premise.sh) is the invariant; this is the thermometer.
import os, re, subprocess, sys

PO = os.environ.get("S4E_PO", os.environ.get("S4E_POST", "/home/resources/postoffice"))
ALL = "--all" in sys.argv
NAMES = "--names" in sys.argv or ALL
try:
    qlines = open(os.path.join(PO, "QUEUE.tsv")).readlines()
    tasks_dir = os.path.join(PO, "tasks")
    os.listdir(tasks_dir)
except OSError as e:
    print(f"REFUSED (rc=2): cannot read the postoffice: {e}", file=sys.stderr); sys.exit(2)

rows = []                                  # (topic, owner, state)
for ln in qlines:
    if ln.startswith('#') or not ln.strip(): continue
    p = ln.rstrip('\n').split('\t')
    if len(p) < 2 or not p[0].strip().isdigit(): continue
    topic = p[1]; owner = p[2] if len(p) > 2 else "-"; state = p[3] if len(p) > 3 else "-"
    if not ALL and state.upper().startswith("DONE"): continue
    rows.append((topic, owner, state))

# ⛔ THE FIELD IS READ BY THE BUS'S OWN EXTRACTOR, NEVER BY A REGEX HERE.  A census that re-derives the
# reading rule answers a slightly NARROWER question than the gate does -- multi-line? backticks? placeholder?
# -- and the two then disagree about which rows are covered, which is the one failure a backlog count may not
# have.  It is the four-copies-of-one-sed defect lib_donewhen.sh was written to end.  So the classification is
# asked of `s4e_msg.sh premise --census`, ONE fork for the whole queue, and this file only presents it.
HERE = os.path.dirname(os.path.abspath(__file__))
MSG = os.path.join(HERE, "s4e_msg.sh")
CLASSES = ["OK", "NONE", "STUB", "VACUOUS", "BROKEN", "NOBATON"]
tasks_of = {t: os.path.join(tasks_dir, f"{t}.task.md") for t, _, _ in rows}
env = dict(os.environ, S4E_NO_BANNER="1")
try:
    out = subprocess.run(["bash", MSG, "premise", "--census"],
                         input="\n".join(tasks_of[t] for t, _, _ in rows) + "\n",
                         capture_output=True, text=True, timeout=900, env=env)
except (OSError, subprocess.TimeoutExpired) as e:
    print(f"REFUSED (rc=2): could not run `s4e_msg.sh premise --census`: {e}", file=sys.stderr); sys.exit(2)
if out.returncode != 0:
    print("REFUSED (rc=2): `s4e_msg.sh premise --census` exited "
          f"{out.returncode} -- this census reads the field through the bus on purpose, so it refuses rather\n"
          "  than fall back to a private regex that would answer a different question.\n"
          f"  {out.stderr.strip()[:400]}", file=sys.stderr); sys.exit(2)
verdict = {}
for ln in out.stdout.splitlines():
    # ⛔ ONLY REAL CLASS LINES.  The bus prints its unread-mail banner on stdout, and a census that
    # swallowed a banner line as data would invent a row and then report a population nobody can reconcile.
    if "\t" not in ln: continue
    k, b = ln.split("\t", 1)
    if k not in CLASSES or not b.endswith(".task.md"): continue
    verdict[os.path.basename(b)[:-len(".task.md")]] = k
if len(verdict) != len(rows):
    print(f"REFUSED (rc=2): the extractor answered for {len(verdict)} of {len(rows)} live rows -- a partial\n"
          "  census is not a census.", file=sys.stderr); sys.exit(2)

by_owner, totals, members = {}, dict.fromkeys(CLASSES, 0), {c: [] for c in CLASSES}
for topic, owner, state in rows:
    k = verdict.get(topic, "NOBATON")
    totals[k] += 1; members[k].append((topic, owner, state))
    by_owner.setdefault(owner, dict.fromkeys(CLASSES, 0))[k] += 1

n = len(rows)
scope = "every row in QUEUE.tsv (--all)" if ALL else "LIVE rows only (QUEUE.tsv, state not DONE)"
print(f"PREMISE CENSUS -- {n} rows, {scope}; postoffice {PO}")
print(f"  population {n} = " + " + ".join(f"{totals[c]} {c}" for c in CLASSES))
covered = totals["OK"]
print(f"  COMPUTED AT CLAIM TIME: {covered}/{n}" + (f" ({100*covered//n}%)" if n else ""))
print(f"  DISPATCHED UNCHECKED  : {n-covered}/{n}  -- admitted by the gate, counted here, owned by nobody until named")
print()
print("  BY OWNER (the fix is per-seat; a fleet total is nobody's job)")
print(f"    {'owner':<14} {'rows':>5} " + " ".join(f"{c:>8}" for c in CLASSES))
for owner in sorted(by_owner, key=lambda o: -sum(by_owner[o].values())):
    d = by_owner[owner]
    print(f"    {owner:<14} {sum(d.values()):>5} " + " ".join(f"{d[c]:>8}" for c in CLASSES))
for c in ("VACUOUS", "BROKEN", "NOBATON"):
    if members[c]:
        why = {"VACUOUS": "certifies nothing, and READS as a checked row -- worse than an absent one",
               "BROKEN":  "not readable as shell; bash would run nothing and exit 0, i.e. read GREEN",
               "NOBATON": "no task file exists, so this row CANNOT carry a premise -- the only class that cannot"}[c]
        print(f"\n  {c} ({len(members[c])}) -- {why}")
        for topic, owner, state in members[c]: print(f"    {topic}  [{owner} {state}]")
if NAMES and members["NONE"] + members["STUB"]:
    print(f"\n  UNEXPRESSED ({len(members['NONE'])+len(members['STUB'])}) -- every one is one line away from being computed")
    for topic, owner, state in members["NONE"] + members["STUB"]: print(f"    {topic}  [{owner} {state}]")
elif members["NONE"] + members["STUB"]:
    print(f"\n  (--names lists the {len(members['NONE'])+len(members['STUB'])} unexpressed rows by name)")
print("\n  To close one: add a PREMISE-WHEN: line to its baton naming the ONE CHEAP COMMAND that proves the")
print("  row's central claim still holds. `claim` and `next` run it and refuse the lock when it goes red.")
sys.exit(0 if (n - covered) == 0 else 1)
