#!/usr/bin/env python3
# util_queue_visibility_census.py (ceo, 2026-08-28 — born from Lon's trust audit: "if items got lost the
# instant they were minted, you must go back and scan for missed items").  THE PICKER'S RULE IS THE
# INSTRUMENT: any claim file hides a row, DONE or not (s4e_msg.sh next).  Every prior by-eye health check
# that read QUEUE.tsv's state column over-counted pickable work and missed hidden rows — this script asks
# the authoritative question instead, and it found (first run): the beauty blocker hidden behind a false
# bare-DONE whose DONE-WHEN named a script that never existed; 7 rowless batons incl. an announce-tier
# item; 3 claims held by stood-down seats.  Classes:
#   A2  FREE row hidden behind a DONE-marked claim (the suites-row class — verify the DONE, then release)
#   B   live claim held by a stood-down seat (liveness law: corroborate, then beta)
#   C!  task file with NO row in QUEUE.tsv AND none in QUEUE.done.tsv (unreachable work)
#   E   task file with no ^DONE-WHEN: line (unclosable by construction)
#   F   PARKED/BLOCKED row with no owner (nobody re-runs its gate)
#   P   task file whose ^DONE-WHEN: line is still the MINT PLACEHOLDER (unclosable the same way E is, but
#       harder to see: the line EXISTS, so E cannot catch it, and `done` executes it whole -- prose is not a
#       command, so a seat can do the whole job correctly and still get a refusal INDISTINGUISHABLE from the
#       one a genuinely wrong cure produces (hq_P census 2026-09-05, ceo ruling CEO-289).
# ⛔⭐ CLASS P KEYS ON THE DONE-WHEN LINE, NEVER ON THE FILE, AND THAT IS THE WHOLE POINT OF THE ARM.  The
# obvious census -- grep -l the placeholder text over tasks/ -- returns 112 where the true figure is 44, a
# 2.5x OVER-REPORT, because ledger lines, handoff notes and QA answers MENTION the placeholder; hq_P found
# two such lines they had written themselves an hour earlier recording that they had REMOVED one.  The
# instrument counted the cure as the disease.  ⭐ It fails in the INFLATING direction, which is the more
# persuasive one: a scary number invites action rather than scrutiny.  Same family as `command -v` for an
# oracle -- a well-formed answer to a slightly different question.
# Exit 0 with all classes empty; exit 1 with findings; exit 2 if the postoffice is unreadable (REFUSE,
# never a silent green — a census that cannot read its subject has measured nothing).
import os, sys
PO = os.environ.get("S4E_PO", "/home/resources/postoffice")
try:
    qlines = open(os.path.join(PO, "QUEUE.tsv")).readlines()
    dlines = open(os.path.join(PO, "QUEUE.done.tsv")).readlines()
    rpath = os.path.join(PO, "QUEUE.retired.tsv"); rlines = open(rpath).readlines() if os.path.exists(rpath) else []
    claims_dir = os.path.join(PO, "claims"); tasks_dir = os.path.join(PO, "tasks")
    claim_files = os.listdir(claims_dir); task_files = os.listdir(tasks_dir)
except OSError as e:
    print(f"REFUSED (rc=2): cannot read the postoffice: {e}", file=sys.stderr); sys.exit(2)
def rows_of(lines):
    out = {}
    for ln in lines:
        if ln.startswith('#') or not ln.strip(): continue
        p = ln.rstrip('\n').split('\t')
        if len(p) >= 4: out[p[1]] = {'rank': p[0], 'owner': p[2], 'state': p[3]}
        elif len(p) >= 2: out[p[1]] = {'rank': p[0], 'owner': '?', 'state': '?'}
    return out
rows = rows_of(qlines); done_rows = rows_of(dlines); retired_rows = rows_of(rlines)
claims = {}
for f in claim_files:
    if not f.endswith('.claim'): continue
    body = [l.strip() for l in open(os.path.join(claims_dir, f)) if l.strip()]
    claims[f[:-6]] = {'holder': body[0] if body else '?', 'done': 'DONE' in body}
tasks = set(f[:-8] for f in task_files if f.endswith('.task.md'))
mode = open(os.path.join(PO, "MODE")).readline().strip()
n = int(mode.split('-')[1]) if mode.startswith('FLEET-') else 0
# ⛔ hq_B and hq_T were MISSING from this set until 2026-09-05 (hq_T) -- a copy-forward from the TRIO era,
# when only two HQs existed.  Harmless TODAY only because class B filters holders that start with 'seat', so
# no HQ is ever tested against it; the moment that filter widens, every hq_B/hq_T claim reads as stood-down.
# A latent wrong answer that is currently unreachable is still a wrong answer, and it costs one line to fix.
active = set(f"seat{i:02d}" for i in range(1, n + 1)) | {'hq_B', 'hq_C', 'hq_P', 'hq_T', 'hq_U', 'hq_S', 'hq_I', 'hq_R', 'hq_V', 'ceo', 'cto', 'coo'}
A2 = sorted(t for t, r in rows.items() if r['state'] == 'FREE' and t in claims and claims[t]['done'])
B  = sorted(t for t, c in claims.items() if not c['done'] and c['holder'].startswith('seat') and c['holder'] not in active)
# ⭐ A TOMBSTONE IS NOT LOST WORK (hq_C 2026-08-27, from triaging this census's own first C! list).  A baton
# whose header says SUPERSEDED or RENAMED is a deliberate REDIRECT that deliberately has no row -- it exists so
# the next reader is sent to the live topic.  The RETIRED- prefix was already excluded for exactly this reason;
# these are the same thing spelled in the header instead of the filename.  ⛔ Counting them made 4 of the first
# 6 C! findings false, and 1 of 1 E findings false (a rename stub needs no DONE-WHEN) -- and a census that
# re-reports correctly-retired work every run trains its readers to skim it, which costs more than the misses
# it was built to catch.  Measured on the first list: icon-r0-bisect (RENAMED by an hq_C ruling),
# raku-print-say-local-arg-marshal-bomb, rebus-raku-loop-condition-hang-family and
# scrip-crashes-not-cleanly-on-unrunnable-input (all three SUPERSEDED, each naming its live successor).
def _head(t):
    try: return open(os.path.join(tasks_dir, t + '.task.md')).readline()
    except OSError: return ''
def _tombstone(t):
    h = _head(t).upper()
    # RESOLVED-BEFORE-CLAIM joined the tombstone family 2026-08-28 (ceo): a baton kept for PROVENANCE after
    # its defect was independently fixed before anyone claimed it — deliberately de-indexed so it cannot be
    # picked up (witness: conform-opsyn-alias-..., flagged as C! four census runs in a row before this line).
    return t.startswith('RETIRED') or 'SUPERSEDED' in h or 'RENAMED' in h or 'RESOLVED' in h
# ⛔⭐ A RETIRED ROW IS ACCOUNTED FOR, NOT LOST (ceo 2026-10-01, CEO-1386/1387 -- the queue zero-base moved 539 rows to
# QUEUE.retired.tsv and every one of their batons read C! on the next census, 539 false findings). A row in the retired
# file is the law's own tombstone: nothing is deleted, the baton stays under tasks/, and the row comes back only by a
# re-mint from a current red. E and P likewise read only the LIVE rows: a placeholder on a done or retired baton is
# history, not an unclosable row; a live claim or umbrella still wearing one is the finding.
Cx = sorted(tasks - set(rows) - set(done_rows) - set(retired_rows) - {t for t in tasks if _tombstone(t)})
E  = sorted(t for t in tasks if t in rows and not _tombstone(t) and 'DONE-WHEN:' not in open(os.path.join(tasks_dir, t + '.task.md')).read())
PLACEHOLDER = 'MUST BE MADE RUNNABLE'
def _donewhen_line(t):
    try:
        for ln in open(os.path.join(tasks_dir, t + '.task.md'), encoding='utf-8', errors='replace'):
            if ln.startswith('DONE-WHEN:'): return ln
    except OSError: pass
    return ''
P  = sorted(t for t in tasks if t in rows and not _tombstone(t) and PLACEHOLDER in _donewhen_line(t))
F  = sorted(t for t, r in rows.items() if ('PARKED' in r['state'] or r['state'] == 'BLOCKED') and r['owner'] == 'unassigned')
# ⛔⭐ R: a DONE row with NO COMPUTED RECEIPT (coo 2026-09-16, ceo CEO-790/793) -- the state column says DONE but no claims/<topic>.claim
# carries DONE, so it reached DONE by a path outside `done` (the verb that COMPUTES completion and, since today, writes a
# RECEIPT line: rc, tree, elapsed, via, time, seat). 17 such rows on 2026-09-16; one, reopened by audit, was RED on origin.
# --grade-receiptless runs each such row's DONE-WHEN (under a 120 s timeout) and classes it: prose (no runnable criterion / the mint
# placeholder), refuses (rc 2, 120, 126, 127), red (any other non-zero), green (rc 0 -- close it through `done` for its receipt).
R  = sorted(t for t, r in rows.items() if r['state'].split(':')[0] == 'DONE' and not (t in claims and claims[t]['done']))
Rh = sorted(t for t, r in done_rows.items() if r['state'].split(':')[0] == 'DONE' and not (t in claims and claims[t]['done']))
GRADE = '--grade-receiptless' in sys.argv
def _grade(t):
    import subprocess
    dw = _donewhen_line(t)
    if not dw or PLACEHOLDER in dw: return 'prose'
    body = dw[len('DONE-WHEN:'):].strip()
    if not body or body.startswith('⛔') or body.startswith('TBD') or body.lower().startswith('tbd'): return 'prose'
    root = os.environ.get('S4E_HOME') or os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
    # S4E_DONE_WHEN_RUN=1 admits THE RUN (lib_one_runner.sh) and, since ceo CEO-997, publishes NOTHING: util_score_row.py
    # no longer reads it as a leaderboard-write door. It had to be closed there rather than dropped here -- this census
    # grades EVERY receiptless row's criterion, so while that door stood, a hygiene pass over a row whose DONE-WHEN is a
    # board was a fleet-wide publish button, and the row's own seat never ran it.
    try:
        r = subprocess.run(['bash', '-c', body], cwd=root, env=dict(os.environ, S4E_HOME=root, S4E_DONE_WHEN_RUN='1'), capture_output=True, text=True, timeout=120)
        rc = r.returncode
    except subprocess.TimeoutExpired:
        rc = 124
    if rc == 0: return 'green (rc 0 -- close it through `done` so the claim carries its receipt)'
    if rc in (2, 120, 124, 126, 127): return f'refuses (rc {rc})'
    return f'red (rc {rc})'
findings = 0
for name, lst, note in (("A2 FREE-behind-DONE-claim", A2, "verify each DONE, then release"),
                        ("B  claim held by stood-down seat", B, f"MODE={mode}; corroborate then beta"),
                        ("C! rowless task file", Cx, "mint a row or retire with a note"),
                        ("E  no DONE-WHEN line", E, "unclosable by construction"),
                        ("F  parked/blocked, no owner", F, "name an owner/cadence"),
                        ("P  DONE-WHEN is still the mint placeholder", P, "write a real criterion and prove it RED once; `done` executes this line whole"),
                        ("R  DONE row with NO COMPUTED RECEIPT (no claim carrying DONE)", R, "reached DONE outside `done`; sweep refuses it; re-run `done` for a receipt, or reopen")):
    if lst:
        findings += len(lst)
        print(f"{name} ({len(lst)}) — {note}:")
        for t in lst:
            r = rows.get(t, {})
            print(f"    {t}" + (f"  [rank {r.get('rank','?')}, owner {r.get('owner','?')}]" + (f"  criterion: {_grade(t)}" if GRADE else "") if name.startswith('R ') else ''))
if Rh:
    print(f"R  (history, informational) {len(Rh)} row(s) in QUEUE.done.tsv carry DONE with no claim carrying DONE -- swept before the receipt existed; not counted")
# ⭐⭐ THE TWO SWEEP LINES (the coo 2026-09-27, ceo CEO-1306, row instruments-the-queue-census-names-blocking-red-rows-past-their-two-hour-
# window-and-hq-lane-rows-unserved-past-24-hours-ceo-1306). Measured the morning they were ruled: three blocking-red rows of the 09-26 audit
# board sat FREE for 23 hours while every seat's make test read them as tolerated reds, and 227 rank-0/1 rows sat FREE in HQ lanes -- 40
# at rank 0 -- that their HQs would not serve while each held its one row. The ceo swept both by hand; these two lines make the sweep a
# reading, printed EVERY run, zero included.
#   BLOCKING-RED PAST WINDOW  a row whose baton LINKS line carries BLOCKING-RED and whose owner has not STARTED within two hours of the later
#       of the tagged time (`since <ISO>`) and the row's first assignment. STARTED is the owner's own act: its claim from FREE (CLAIMED:<owner>,
#       or a claim file it holds with no ASSIGNED-BY line), a RUNNING mark on the claim it was assigned (`next` writes one as it serves the row
#       ASSIGNED->RUNNING, and `claim` by name since the same landing), or a LEDGER line of its own dated inside or after the window (an
#       undated one counts: the owner acted). An assignment alone never counts. A row whose times cannot be read is named, never counted.
#   HQ-LANE UNSERVED PAST 24H  a FREE rank-0 or rank-1 row in an HQ lane (owner hq_*), minted more than 24 hours ago, while that HQ holds
#       another live claim -- rank 0 first, oldest first.
# Each named row carries its age and the officer RULES.md's escalation channel (clause 2) routes it to by default: the collector, rt.c and
# the safe-point road to the cfo; the emitter, planner, templates and spine to the cto; instruments, gates, censuses and the bus to the
# coo; everything else to the ceo. S4E_CENSUS_NOW=YYYY-MM-DDTHH:MM:SSZ pins the clock, so a fixture reads the same answer every run.
import re as _re
from datetime import datetime as _dt, timedelta as _td, timezone as _tz
def _iso(s):
    for f in ('%Y-%m-%dT%H:%M:%SZ', '%Y-%m-%dT%H:%MZ'):
        try: return _dt.strptime(s, f).replace(tzinfo=_tz.utc)
        except (ValueError, TypeError): pass
    return None
_nv = os.environ.get('S4E_CENSUS_NOW', '')
NOW = _iso(_nv) if _nv else _dt.now(_tz.utc)
if NOW is None: print(f"REFUSED (rc=2): S4E_CENSUS_NOW={_nv!r} is not YYYY-MM-DDTHH:MM:SSZ", file=sys.stderr); sys.exit(2)
def _baton(t):
    try: return open(os.path.join(tasks_dir, t + '.task.md'), encoding='utf-8', errors='replace').read()
    except OSError: return ''
def _claim_lines(t):
    try: return [l.strip() for l in open(os.path.join(claims_dir, t + '.claim'), encoding='utf-8', errors='replace') if l.strip()]
    except OSError: return []
_ROUTE = (('cfo', ('gc', 'collector', 'collection', 'safe-point', 'safepoint', 'heap', 'arena', 'allocator', 'rt-c')),
          ('cto', ('emitter', 'planner', 'template', 'templates', 'spine', 'codegen', 'zeta', 'lowerer')),
          ('coo', ('instrument', 'instruments', 'gate', 'gates', 'census', 'bus', 'picker', 'postoffice', 'runner', 'runners',
                   'harness', 'board', 'boards', 'progress', 'triangulator', 'triangulation')))
def _route(t):
    w = set(t.lower().replace('_', '-').replace('.', '-').split('-'))
    for who, keys in _ROUTE:
        if w & set(keys): return who
    return 'ceo'
_LEDGER = _re.compile(r'^- \[([A-Za-z0-9_]+)·([^\]]*)\]')
def _ledger_when(s):
    m = _re.match(r'(\d{4}-\d\d-\d\d)(?:[ T](\d\d):(\d)(\d|x))?', s.strip())
    if not m: return None
    d = _dt.strptime(m.group(1), '%Y-%m-%d').replace(tzinfo=_tz.utc)
    if m.group(2) is None: return d
    t = d + _td(hours=int(m.group(2)), minutes=int(m.group(3)) * 10 + (0 if m.group(4) == 'x' else int(m.group(4))))
    return t + _td(hours=5) if 'CDT' in s else t
def _owner_acted(b, owner, since):
    for ln in b.split('\n'):
        m = _LEDGER.match(ln)
        if not m or m.group(1) != owner: continue
        w = _ledger_when(m.group(2))
        if w is None or w >= since - _td(minutes=10): return True
    return False
BR, BRx = [], []
for t, r in rows.items():
    st = r['state'].split(':')[0]
    if st in ('DONE', 'SUPERSEDED', 'RETIRED'): continue
    b = _baton(t)
    links = next((l for l in b.split('\n') if l.startswith('LINKS:')), '')
    if 'BLOCKING-RED' not in links: continue
    m = _re.search(r'BLOCKING-RED:.*?\bsince\s+(\S+?)[.,;)]*(?:\s|$)', links)
    tag = _iso(m.group(1)) if m else None
    cl = _claim_lines(t)
    asg = next((_iso(x.split()[2]) for x in cl if x.startswith('ASSIGNED-BY ') and len(x.split()) >= 3), None)
    known = [x for x in (tag, asg) if x is not None]
    if not known: BRx.append(t); continue
    start = max(known); owner = r['owner']
    held = bool(cl) and cl[0] == owner
    started = (r['state'] == 'CLAIMED:' + owner) or (held and ('RUNNING' in cl or not any(x.startswith('ASSIGNED-BY ') for x in cl))) \
              or _owner_acted(b, owner, start)
    if not started and NOW > start + _td(hours=2):
        BR.append((NOW - start - _td(hours=2), t, owner, r['rank'], r['state'], start))
live_by = {}
for t, c in claims.items():
    rr = rows.get(t)
    if c['done'] or rr is None or rr['state'].split(':')[0] in ('DONE', 'SUPERSEDED', 'RETIRED'): continue
    live_by.setdefault(c['holder'], []).append(t)
def _minted(t):
    b = _baton(t)
    m = _re.search(r'minted via `(?:s4e_msg\.sh )?mint` by \S+?,\s*(\d{4}-\d\d-\d\dT[\d:]+Z)', b)
    if m: return _iso(m.group(1))
    for ln in b.split('\n'):
        mm = _LEDGER.match(ln)
        if mm and 'Minted via' in ln: return _ledger_when(mm.group(2))
    return None
HQ, HQx = [], []
for t, r in rows.items():
    if r['state'] not in ('FREE', '') or r['rank'] not in ('0', '1') or not r['owner'].startswith('hq_') or t in claims: continue
    others = [x for x in live_by.get(r['owner'], []) if x != t]
    if not others: continue
    mt = _minted(t)
    if mt is None: HQx.append(t); continue
    if NOW - mt > _td(hours=24): HQ.append((r['rank'], -(NOW - mt).total_seconds(), t, r['owner'], others[0], NOW - mt))
BR.sort(key=lambda x: -x[0].total_seconds()); HQ.sort()
print(f"BLOCKING-RED PAST WINDOW: {len(BR)}  (window: two hours from the later of the BLOCKING-RED `since` time and the first assignment; now {NOW:%Y-%m-%dT%H:%MZ})")
for late, t, owner, rank, state, start in BR:
    print(f"    {t}  [owner {owner}, rank {rank}, {state}, window opened {start:%Y-%m-%dT%H:%MZ}, not started {late.total_seconds() / 3600 + 2:.1f} h] -> {_route(t)}")
if BRx: print(f"    (named, not counted: {len(BRx)} BLOCKING-RED row(s) with no readable `since` time and no assignment -- {' '.join(BRx[:5])})")
print(f"HQ-LANE UNSERVED PAST 24H: {len(HQ)}  (FREE, rank 0 or 1, minted over 24 h ago, while the owning HQ holds another claim)")
for rank, _, t, owner, other, age in HQ:
    print(f"    {t}  [rank {rank}, minted {age.total_seconds() / 3600:.0f} h ago, {owner} holds {other}] -> {_route(t)}")
if HQx: print(f"    (named, not counted: {len(HQx)} such row(s) whose mint time the baton does not carry -- {' '.join(HQx[:5])})")
findings += len(BR) + len(HQ)
# DONE-WHEN RUNS A BOARD (ceo CEO-1342 clause 5; the coo's row bus-done-runs-no-board-for-any-seat-..., 2026-09-28): the bus's
# computed done no longer admits a board run for any seat but the lane owner, so a live row whose DONE-WHEN runs a suite, a board or
# the guard can never close through done -- named here for its lane to rewrite (read the coo's SUITE TABLE row through
# ../harness/scripts/util_suite_row_at_or_after.sh instead). The names come from util_donewhen_exemption_census.py, the one reader of that class.
import subprocess as _sp, json as _json
_xc = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'util_donewhen_exemption_census.py')
DB = []
try:
    _env = dict(os.environ); _env.setdefault('S4E_TASKS', tasks_dir)
    _p = _sp.run([sys.executable, _xc, '--json'], capture_output=True, text=True, timeout=300, env=_env)
    _d = _json.loads(_p.stdout or '{}')
    DB = [r for r in _d.get('rows', []) if r.get('live') and r.get('class') in ('BOARD', 'GUARD')]
    _xc_note = ''
except Exception as _e:
    _xc_note = f" (the exemption census could not be read: {type(_e).__name__}: {_e})"
print(f"DONE-WHEN RUNS A BOARD (cannot close through done, CEO-1342 clause 5): {len(DB)}{_xc_note}")
for r in sorted(DB, key=lambda r: (r.get('owner', ''), r.get('topic', ''))):
    print(f"    {r.get('topic')}  [owner {r.get('owner')}, {r.get('state')}, {r.get('class')} <- {', '.join(sorted(set(r.get('mechanism') or [])))[:120]}] -> rewrite to read the coo's row: ../harness/scripts/util_suite_row_at_or_after.sh <key> <tree>")
findings += len(DB)
if findings == 0: print("CENSUS CLEAN: every minted row is pickable, closable, and owned."); sys.exit(0)
print(f"TOTAL FINDINGS: {findings}"); sys.exit(1)
