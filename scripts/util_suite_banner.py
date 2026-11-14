#!/usr/bin/env python3
"""THE SUITE BANNER — one compressed line per turn, driven by /home/resources/progress/SUITES.tsv (the machine record of SCORE.md § THE SUITE TABLE).
usage: util_suite_banner.py [--plain] [--line] [--md] [--grid] [--check] [--render --only KEY | --render --all-rows] [--set KEY PASS TOTAL [DATE] [TREE] [--criterion-changed 'YYYY-MM-DD:reason'] [--secs N] [--excluded N]]
  (no args)  print the banner as an aligned GRID (Lon 2026-09-06): header with the suite count and how many are done, then 3 columns x N rows of cells: nick pass/total left state emoji
  --line     the one-line form (cells joined by │)
  --plain    no ANSI colour
  --md       print the markdown table for SCORE.md § THE SUITE TABLE
  --set      rewrite one row's today_* (DATE defaults to the box clock day) and print the banner
             -- and RE-RENDER SCORE.md § THE SUITE TABLE from the TSV in the same call (coo 2026-09-06, on hq_R's
             finding that the markdown table was a third home for the number nothing rendered)
  --render   re-render SCORE.md § THE SUITE TABLE rows from SUITES.tsv, in place; print what changed
  --open KEY@ENGINE FROM_KEY   open a port engine's row (CEO-1822): copy FROM_KEY's nick, emoji and lang, readings empty; run by
             util_score_row.py from-progress on the engine's FIRST publish, never by hand
STALE rule (Lon 2026-09-06 'Do not depend on cron', MASTER-PLAN THE PACE RULES 10): a row whose today_date is older than the box-clock day reads U+23F3 in place of its emoji and is counted on the first line; a STALE row is a rank-0 measure pick in its lane.
ETA rule: rate = (today_pass - first_pass) / max(1, days(first_date..today_date)); eta = remaining / rate; a suite that has not moved reads STUCK; complete reads DONE; a suite with one reading reads NEW.
CRITERION rule (hq_T 2026-09-06, after ceo-372; AMENDED coo 2026-09-08 on Lon's word "Fix it so you CAN do a comparison"). A row may carry criterion_changed = <YYYY-MM-DD>:<slug>. When its first_date PREDATES that day, first_* and today_* answer two different questions and their difference is not a movement -- that much stands, and first_* is still never re-baselined. ⛔ WHAT NO LONGER STANDS is printing n/c and stopping: that is true about those two numbers and useless as an answer to "are we getting better?". Instead likeforlike() holds the POPULATION fixed -- today's graded set -- and asks the progress table what those same programs did then and do now. Same programs, same modes, two dates, so a changed denominator cannot distort it, and nothing is invented: it re-reads per-program evidence already on file. The row then gets a real rate and a real ETA like any other. Programs with no reading at the earlier date are excluded from BOTH sides rather than counted as failures-then-passes-now, which would manufacture progress out of missing data. Only two states remain uncomparable and they are told apart: `no rows` (the table has never seen the suite) and `1 day` (rows exist but all from one day, so there is no earlier reading yet) -- both facts about our instrumentation, never verdicts about the suite.
"""
import sys, os, re, subprocess, tempfile, datetime as dt, unicodedata as _ud
def dw(s):
    """DISPLAY columns, not len(). The grid misaligned because padding counted CHARACTERS (Lon 2026-09-06:
    "get the suites banner to line up vertically; most likely your length counts are off due to unicode").
    Three independent ways len() lies here, all live in this banner:
      - a WIDE char is 1 char and 2 columns: U+2705 done, U+26D4 stuck, U+1F195 new, and every W emoji;
      - a VARIATION SELECTOR is 1 char and 0 columns, and it makes its NARROW base render wide: ❄️ and 🏛️
        are U+2744/U+1F3DB + U+FE0F, len()==2, one 2-column glyph;
      - a REGIONAL INDICATOR PAIR is 2 chars and one 2-column glyph: 🇫🇷 is U+1F1EB U+1F1F7.
    U+2192 (the ETA arrow) is east_asian_width 'A' (ambiguous) and renders NARROW, which is why the ETA cells
    were the ones that lined up and the done/stuck/new cells were not."""
    w = 0; i = 0; n = len(s)
    while i < n:
        ch = s[i]; o = ord(ch)
        if o in (0xFE0F, 0xFE0E) or _ud.combining(ch): i += 1; continue
        if 0x1F1E6 <= o <= 0x1F1FF:
            w += 2; i += 2 if (i + 1 < n and 0x1F1E6 <= ord(s[i + 1]) <= 0x1F1FF) else 1; continue
        if i + 1 < n and ord(s[i + 1]) == 0xFE0F: w += 2; i += 2; continue
        if _ud.east_asian_width(ch) in ('W', 'F') or 0x1F300 <= o <= 0x1FAFF: w += 2
        else: w += 1
        i += 1
    return w
def pad(s, width):
    """left-justify to WIDTH display columns; never truncates, so a wide cell pushes its row instead of lying."""
    d = dw(s)
    return s + ' ' * (width - d) if d < width else s
def rpad(s, width):
    """RIGHT-justify to WIDTH display columns (Lon 2026-09-13: "right justify the numbers"), for NUMERIC cells
    only. A column of right-aligned figures puts the units under the units, so 2619 and 6 and 1928 compare by
    eye down the column; left-aligned they do not, which is the whole reason a reader scans a score grid.
    Never truncates, same as pad(): a wide cell pushes its row rather than lying about its value."""
    d = dw(s)
    return ' ' * (width - d) + s if d < width else s
HERE=os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import harness_paths
GH=os.path.join(HERE,'..') if os.path.basename(os.path.abspath(os.path.join(HERE,'..')))=='.github' else str(harness_paths.github())   # the scripts folder of harness since 2026-11-11 (Lon: "move scripts to harness."); a fixture's copy of these scripts beneath its own .github still finds that .github   # one-disk: not a path
# ⛔ S4E_SUITES_TSV EXISTS SO A SCRATCH HARNESS CAN BE SCRATCH IN BOTH OF ITS OUTPUTS (hq_T 2026-09-06,
# ceo CEO-363).  util_score_row.py now mirrors a V/M write into the suite table by calling this script,
# so its selftest -- which grades a COPY of SCORE.md -- was writing its fake rebus numbers into the REAL
# SUITES.tsv, the file the banner and Lon read, while printing that it works on a scratch copy.  A
# redirect that covers one of two outputs is not a redirect; measured live, it moved a real row.
# ⛔⭐⭐ ONE FILE, ONE LOCATION (Lon 2026-10-09 15:2x CDT, in-chat to the coo, verbatim: "You choose to put the one single data location to be
# spread across all root via GitHub instead of choosing one file in /home/resources. That was stupid."). The record lived in .github, so every
# root read its own clone of it, as current as that seat's last pull: hq_collector's banner read 27 suites at 100% while the coo's read 31,
# its clone a pull behind four rows. The record is now ONE file beside the progress database, read and written by every seat in place; the
# SCORE.md table and SCRIP's README table are renders of it, and every write appends the rows it moved to SUITES.history.tsv beside it.
SUITES_HOME='/home/resources/progress'
TSV=os.environ.get('S4E_SUITES_TSV') or os.path.join(SUITES_HOME,'SUITES.tsv')
HIST=os.path.join(os.path.dirname(os.path.abspath(TSV)),'SUITES.history.tsv')
R='\033[31m'; G='\033[32m'; Y='\033[33m'; C='\033[36m'; B='\033[1m'; Z='\033[0m'
# ⛔⭐ DEFERRED IS READ, NEVER INFERRED FROM AN EMPTY READING (hq_T 2026-09-12, ceo CEO-593). A row with no
# today_pass renders `◻ no runner`, which is the honest word for A POPULATION NOBODY GRADES YET -- and it is
# the WRONG word for one Lon has ruled DEFERRED (CEO-579, *"Do not count the FD as failures for us."*). The
# two look identical in this table and are opposite facts: "no runner" is a debt nobody has scheduled, and
# DEFERRED is a debt SCHEDULED OUT, on the record, with the work it waits on named. ⛔ So the discriminator is
# `.github/DEFERRED.tsv` and nothing else: never the emptiness of a cell, and never the suite's name.
DEFERRED_TSV=os.environ.get('S4E_DEFERRED_TSV') or os.path.join(GH,'DEFERRED.tsv')
def deferred_rows():
    """{suite_key: {'count': N, 'ruled_by': str, 'waiting_on': str}} -- {} when the record is absent."""
    out={}
    if not os.path.exists(DEFERRED_TSV): return out
    head=None
    for l in open(DEFERRED_TSV,encoding='utf-8'):
        if l.startswith('#') or not l.strip(): continue
        f=l.rstrip('\n').split('\t')
        if head is None: head=f; continue
        r=dict(zip(head,f))
        k=r.get('suite','').strip()
        if not k: continue
        e=out.setdefault(k,{'count':0,'ruled_by':'','waiting_on':''})
        try: e['count'] += int(r.get('count','0') or 0)
        except ValueError: pass
        for col in ('ruled_by','waiting_on'):
            if r.get(col): e[col] = (e[col] + '; ' + r[col]) if e[col] else r[col]
    return out
def load(path=None):
    rows=[]; head=None
    for l in open(path or TSV,encoding='utf-8'):
        if l.startswith('#') or not l.strip(): continue
        f=l.rstrip('\n').split('\t')
        if head is None: head=f; continue
        r=dict(zip(head,f))
        for h in head: r.setdefault(h,'')
        rows.append(r)
    return head,rows
# ⛔⭐ A PORT ENGINE'S ROWS ARE KEYED <key>@<engine> IN THIS ONE TABLE (Lon 2026-10-17 to hq_dotnet: "The suite banner should represent the
# snobol4dotnet executable program, not SCRIP."; ceo CEO-1822): SCRIP's views -- SCORE.md's suite table, the README's, the grid of a seat
# with no port engine -- read the bare keys only, and a port seat's grid reads its own engine's keys only. load() returns EVERY row,
# because --set saves back what it loaded; each SCRIP reader narrows with _scrip(). An @-row shares its nick with SCRIP's (SnoRungs), so a
# reader that maps nick to key over all rows would hand SCRIP's row the port's key.
def _engine_of(key): return (key or '').partition('@')[2]
def _scrip(rows): return [r for r in rows if not _engine_of(r.get('key',''))]
def _dbname(key):
    base,at,engine=(key or '').partition('@'); return DBNAME.get(base,base)+at+engine
def write_tsv(text):
    """Replace the record whole: every seat's banner reads this one file, so a reader sees the old table or the new one, never a torn one."""
    fd,tmp=tempfile.mkstemp(prefix='.SUITES.', suffix='.tmp', dir=os.path.dirname(os.path.abspath(TSV)))
    with os.fdopen(fd,'w',encoding='utf-8') as f: f.write(text)
    os.chmod(tmp,0o664); os.replace(tmp,TSV)
def history(head,before,rows):
    """Append every row this write moved to SUITES.history.tsv: the history git kept while the record lived in .github. Each line carries
    the writer's seat and session id, so a gate proving its fixture left the shared record alone excuses another session's concurrent write."""
    old={l.split('\t',1)[0]:l for l in before.split('\n') if l and not l.startswith('#')}
    moved=['\t'.join(r.get(h,'') for h in head) for r in rows]
    moved=[l for l in moved if old.get(l.split('\t',1)[0])!=l]
    if not moved: return
    cols='# columns: at_utc\tseat\tsid\t'+'\t'.join(head)
    have=open(HIST,encoding='utf-8').read() if os.path.exists(HIST) else ''
    last=[l for l in have.split('\n') if l.startswith('# columns: ')]
    at=dt.datetime.now(dt.timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')
    seat=os.environ.get('S4E_SEAT') or re.sub(r'^claude_','',os.path.basename(os.path.abspath(os.path.join(HERE,'..','..'))))
    with open(HIST,'a',encoding='utf-8') as f:
        if not last or last[-1]!=cols: f.write(cols+'\n')
        for l in moved: f.write(f"{at}\t{seat}\t{os.getsid(0)}\t{l}\n")
def save(head,rows):
    lines=[l for l in open(TSV,encoding='utf-8') if l.startswith('#')]
    lines.append('\t'.join(head)+'\n')
    for r in rows: lines.append('\t'.join(r.get(h,'') for h in head)+'\n')
    write_tsv(''.join(lines))
def d(s): return dt.date.fromisoformat(s)
def box_clock_day():
    """The BOX-CLOCK day -- the box's own zone (/etc/timezone, else the /etc/localtime link), never the calling process's TZ.

    ⛔ WHY NOT dt.date.today() (coo 2026-09-23, CEO-1229, row instruments-suite-banner-set-refuses-a-date-later-than-the-box-clock-
    day): SUITES.tsv's dates are box-clock CDT days, and a writer running under another zone labels an evening reading TOMORROW --
    measured: .github 4f4ca80f, committed 19:59 CDT on 2026-09-23, wrote pat and pas-rungs dated 2026-09-24 while fpc and
    pascal-bench-ref in the same commit read 2026-09-23. A guard computed in the caller's zone would inherit the caller's error."""
    tz = ""
    try:
        tz = open("/etc/timezone", encoding="utf-8").read().strip()
    except OSError:
        pass
    if not tz:
        try:
            _l = os.readlink("/etc/localtime")
            tz = _l.split("zoneinfo/", 1)[1] if "zoneinfo/" in _l else ""
        except OSError:
            pass
    try:
        from zoneinfo import ZoneInfo
        return dt.datetime.now(ZoneInfo(tz)).date() if tz else dt.date.today()
    except Exception:
        return dt.date.today()
def recriterioned(r):
    """The row's first reading was taken under a DIFFERENT criterion than today's, so today_pass
    and first_pass are not two readings of one thing and their difference is not a movement.

    ⛔⭐ WHY A MARKER AND NOT A RE-BASELINE (hq_T 2026-09-06, on hq_V's report; ceo-372 is the first
    criterion change to hit this table). When ceo-372 moved four suite rows from a single mode to the
    AND per program, this column began subtracting a PRE-CRITERION number from a POST-CRITERION one:
    PAT rendered -6 in a sitting it moved FORWARD six programs, and FPC -3, and because eta() reads
    rate<=0 as STUCK both rows put a false stuck marker into the headline verdict Lon reads.
    ⭐ hq_V found it and deliberately did NOT re-baseline the two rows they own, on the grounds that a
    seat quietly re-cutting the baseline of its own rows to make its own lane look better is the exact
    shape nobody could audit later. That judgement is why this is a marker: the honest alternative --
    a first reading re-measured under the new criterion -- would mean re-running trees that no longer
    exist, so it could only ever be invented. ⛔ A COMPARISON ACROSS TWO CRITERIA IS NOT A MEASUREMENT,
    and the cure for a number that cannot be computed is to say so, never to print a plausible one.
    The marker is SELF-CLEARING: it stops firing the day a first reading under the current criterion
    is recorded, so nothing has to remember to remove it."""
    mark=(r.get('criterion_changed') or '').strip()
    if not mark: return ''
    when=mark.split(':',1)[0]
    # ⛔ STRICTLY AFTER, because dates here are DAYS and a criterion can change mid-day: a first reading
    # stamped the SAME day as the change cannot be placed on either side of it. Treating it as pre-criterion
    # is the conservative arm -- it prints "not computable" for a reading that might have been comparable,
    # rather than printing a movement for one that certainly is not. Self-clearing the next day either way.
    try:
        if d(r['first_date']) > d(when): return ''
    except ValueError:
        return ''
    return mark
PROGRESS=os.environ.get('S4E_PROGRESS') or '/home/resources/progress/results.tsv'
# SUITES.tsv key -> the name the progress table records this suite under.
DBNAME={'sno-rungs':'snobol4-rungs','icn-rungs':'icon-rungs','pl-rungs':'prolog-rungs',
        'pas-rungs':'pascal-rungs','raku-rungs':'raku-rungs','snc-rungs':'snocone-rungs',
        'reb-rungs':'rebus-rungs','testpgms':'spitbol_testpgms'}
_LFL_CACHE=None
def _progress_by_suite():
    """One lean pass over the progress table -> {suite: [(ts, program, mode, outcome)]}.

    ⛔ THE PROGRAM KEY IS NORMALISED TO ITS BARE NAME, and that is not cosmetic. The recorded convention
    CHANGED mid-history: gimpel rows read 'snobol4/gimpel/AGT_driver.sno' through 2026-09-05 and
    'packages/snobol4/gimpel/AGT_driver.sno' from 2026-09-06. A join on raw names across that boundary
    finds NOTHING in common and reports a suite as having no comparable history while +45 sits in the
    table -- measured coo 2026-09-08, which is how this was found.
    ⛔ DIRTY TREES ARE DROPPED: a -dirty stamp is cited for its number, never for its position in a series."""
    global _LFL_CACHE
    if _LFL_CACHE is not None: return _LFL_CACHE
    out={}
    try: fh=open(PROGRESS,encoding='utf-8',errors='replace')
    except OSError:
        _LFL_CACHE={}; return _LFL_CACHE
    # ⛔⭐ ONE RECORD PER (suite, program, mode, DAY), NOT ONE PER ROW (coo 2026-09-23, the ceo's CEO-1212 under CEO-801): this
    # loaded every row of the table -- 4.18M, 684-716 MB for EVERY score-row write, seven arms of the blocking set -- while its one
    # consumer, likeforlike(), only ever asks for the last reading at or before the END OF A DAY (its basis) and the latest reading
    # overall (its newest), which is the last record of the last day. So each (suite, program, mode, day) keeps only its max-ts
    # record, the first seen on a tie exactly as _state_at() breaks ties, and every quantity likeforlike() computes -- newest,
    # latest_day, pop, basis, then, now -- reads the same on the kept records as on all of them (275k of 4.18M on the day this
    # changed). test_gate_progress_readers_stream_and_answer_the_same.sh holds the old and the new answer equal, suite by suite.
    groups={}
    with fh:
        head=fh.readline().rstrip('\n').split('\t')
        try: i_ts,i_scrip,i_corp,i_suite,i_prog,i_mode,i_out=(head.index(c) for c in
            ('ts_utc','scrip','corpus','suite','program','mode','outcome'))
        except ValueError:
            _LFL_CACHE={}; return _LFL_CACHE
        for l in fh:
            f=l.split('\t')
            if len(f)<=i_out: continue
            if f[i_mode] not in ('m3','m4'): continue
            if '-dirty' in f[i_scrip] or '-dirty' in f[i_corp]: continue   # scrip, then corpus: both dirty-tree stamps are unread
            prog=f[i_prog].rsplit('/',1)[-1]
            if '.' in prog: prog=prog.rsplit('.',1)[0]
            ts=f[i_ts]; g=groups.get(f[i_suite])
            if g is None: g=groups[f[i_suite]]={}
            k=(prog,f[i_mode],ts[:10]); cur=g.get(k)
            if cur is None or ts>cur[0]: g[k]=(ts,prog,f[i_mode],f[i_out])
    out={s_:list(g.values()) for s_,g in groups.items()}
    _LFL_CACHE=out
    return out
def _state_at(recs,cutoff,only=None):
    """AND-per-program greenness as of cutoff, from each program's latest reading at or before it."""
    latest={}
    for ts,prog,mode,outc in recs:
        if ts<=cutoff and (only is None or prog in only):
            k=(prog,mode)
            if k not in latest or ts>latest[k][0]: latest[k]=(ts,outc)
    per={}
    for (prog,mode),(_ts,outc) in latest.items(): per.setdefault(prog,{})[mode]=outc
    return {p:all(v=='PASS' for v in m.values()) for p,m in per.items()}
def likeforlike(r):
    """THE COMPARISON A CHANGED CRITERION CANNOT BREAK (Lon 2026-09-08: "Fix it so you CAN do a comparison").

    A criterion change makes first_pass/first_total and today_pass/today_total answers to two different
    questions, so their difference is not a movement -- that much the CRITERION rule had right. Its mistake
    was to stop there and print n/c, which is true about those two numbers and useless as an answer to
    "are we getting better?".

    ⭐ SO HOLD THE POPULATION FIXED INSTEAD OF THE DENOMINATOR. The progress table records every program
    individually with a timestamp, so today's graded set can be asked what IT did then and what it does now.
    Same programs, same modes, two dates: a movement, and a changed denominator cannot distort it.
    ⛔ THIS INVENTS NOTHING, which is what the old rule was right to refuse. It re-reads evidence already on
    file; it never re-baselines first_*, and those columns keep saying exactly what they always said.
    ⛔ PROGRAMS WITH NO READING AT THE EARLIER DATE ARE EXCLUDED FROM BOTH SIDES, never counted as failures
    then and passes now -- that would manufacture progress out of missing data, which is the failure this
    project keeps naming. They are returned as `unseen` so the gap is visible rather than absorbed.

    Returns None when the table holds nothing for the suite, else a dict; `basis` is the earliest day the
    comparison could actually start from, which may be later than first_date -- the window is stated, never
    implied."""
    recs=_progress_by_suite().get(_dbname(r['key']))
    if not recs: return None
    newest=max(t for t,_,_,_ in recs); latest_day=newest[:10]
    pop={p for ts,p,_,_ in recs if ts[:10]==latest_day}
    if not pop: return None
    earlier=[ts for ts,p,_,_ in recs if ts[:10]<latest_day and p in pop]
    if not earlier: return None
    basis=min(earlier)[:10]
    then=_state_at(recs,basis+'T23:59:59',pop)
    now=_state_at(recs,newest,pop)
    seen=[p for p in pop if p in then and p in now]
    if not seen: return None
    return {'then':sum(1 for p in seen if then[p]),'now':sum(1 for p in seen if now[p]),
            'pop':len(seen),'unseen':len(pop)-len(seen),'basis':basis}
def lfl_why(r):
    """Why likeforlike() could not compare -- 'norows' (the table has never seen this suite) or 'oneday'
    (it has rows, but all from a single day, so there is no earlier reading to compare today against).
    ⛔ THESE ARE DIFFERENT FACTS AND THE BANNER MUST NOT PRINT ONE FOR THE OTHER: 'no rows' on a suite with
    537 recorded rows sends a reader to instrument the runner when the only thing missing is a second day."""
    recs=_progress_by_suite().get(_dbname(r['key']))
    if not recs: return 'norows'
    return 'oneday'
# ⛔⭐ AN XFAIL COUNTS AS A FAIL, SO A SUITE CARRYING ONE IS NOT DONE (ceo CEO-416, 2026-09-08,
# on Lon's own FACT RULE of 2026-09-03: "there is no such thing now as XFAIL. We are shooting for 100%").
# THE DEFECT THIS CLOSES, and the coo walked into it before the ruling: the SNOBOL4 rungs row read
# 1894/1894 FAIL=0 and this banner printed it "done", while 27 known-red entries sat OUTSIDE BOTH SIDES
# of that fraction. Dropping a red from the numerator AND the denominator renders it as if it did not
# exist -- wrong in the flattering direction, on the row Lon's 100% question gets answered from.
#
# ⛔ THE COUNT IS A UNION OF THREE SPELLINGS, NEVER A SUM. An xfail is spelled three ways -- ALL.csv's
# `xfail` column, banner lines in ALL.xfail, and per-entry *.xfail marker files -- and adding them
# double-counts: snobol4's ALL.xfail holds 54 LINES for 27 ENTRIES (a banner line plus a prose line
# each), naming the same 27 the CSV column names. MEASURED by the coo across all seven rung_suites
# 2026-09-08: snobol4 csv 27 and ALL.xfail 27 overlapping 27 of 27; icon 20 markers only; raku 156,
# snocone 16, rebus 4, all csv-only; prolog and pascal 0. Six of the seven use a SINGLE spelling, so
# no overlap is possible there -- which is why the union is safe to take and the sum is not.
# ⛔ AN UNREADABLE CORPUS RETURNS None AND IS SAID ALOUD, NEVER 0: a census that cannot see its
# population must never print the success shape. That is the whole instrument law in one return value.
_XF_CACHE = {}
def xfail_by_lang(lang):
    """Distinct xfail ENTRIES for a rung suite language: union of the three spellings, or None if unreadable."""
    if lang in _XF_CACHE: return _XF_CACHE[lang]
    import csv as _csv, glob as _glob
    # a scratch record finds the scratch corpus beside it; the real record (no longer in a root) reads this root's corpus
    # ⛔ THE REAL RECORD NAMED BY PATH IS STILL THE REAL RECORD (the coo 2026-10-11): util_score_row.py passes S4E_SUITES_TSV on every write, the
    # real one included, and the corpus was then sought beside /home/resources/progress -- every rung row it wrote rendered "xfail unreadable"
    # (five of pass 48's, the --check disagreement). Only a record somewhere else is a scratch record.
    _scratch = os.environ.get('S4E_SUITES_TSV') and os.path.abspath(TSV) != os.path.abspath(os.path.join(SUITES_HOME, 'SUITES.tsv'))
    base = os.path.dirname(os.path.abspath(TSV)) if _scratch else GH
    d = os.path.join(str(harness_paths.corpus(os.path.dirname(os.path.dirname(os.path.abspath(TSV))) if _scratch else None)), 'tests', lang)
    d = os.path.normpath(d)
    if not os.path.isdir(d):
        _XF_CACHE[lang] = None; return None
    names = set()
    try:
        c = os.path.join(d, 'ALL.csv')
        if os.path.exists(c):
            with open(c, newline='', encoding='utf-8', errors='replace') as f:
                r = _csv.reader(f); hdr = next(r)
                if 'xfail' in hdr:
                    i = hdr.index('xfail')
                    for row in r:
                        if len(row) > i and row[i].strip() == '1': names.add(row[1])
        x = os.path.join(d, 'ALL.xfail')
        if os.path.exists(x):
            for l in open(x, encoding='utf-8', errors='replace'):
                m = re.match(r'^\*-+\s+\d+\s+(\S+)\s+XFAIL\s*$', l.rstrip('\n'))
                if m: names.add(m.group(1))
        for f in _glob.glob(os.path.join(d, '*.xfail')):
            if not f.endswith('ALL.xfail'): names.add(os.path.basename(f)[:-6])
    except Exception:
        _XF_CACHE[lang] = None; return None
    _XF_CACHE[lang] = len(names)
    return len(names)
def eta(r,today):
    """MEASURED MOVEMENT, NEVER A PROJECTION (Lon 2026-09-12 15:0x CDT, in-chat to cfo, verbatim: "I see that in your
    grid you will deliver some yesterday. Hmm?" -- the cells read "-> 09-12" on 09-12: a date computed as
    today + remaining/rate, i.e. an extrapolation, and one that could land in the past).  The economy rule of this
    seat is measured never projected, and a banner Lon reads is the last place a projection belongs.  What a cell
    can state is what was MEASURED: two readings of the same population and their difference.  Returns
    ('MOVE', (delta, basis_date)) where delta = today_pass - the earlier reading on the same criterion (the first
    reading, or the like-for-like basis when the criterion changed), or DONE / XFAIL / XFUNKNOWN / NEW / NOROWS /
    ONEDAY / NORUNNER exactly as before.  Nothing here is a rate, an ETA, or a curve."""
    if r['today_pass'].strip()=='' or r['today_date'].strip()=='': return 'NORUNNER',None
    fp,ft,tp,tt=int(r['first_pass']),int(r['first_total']),int(r['today_pass']),int(r['today_total'])
    rem=tt-tp
    if rem<=0:
        # CEO-416: a rung suite carrying xfails is NOT done however the fraction reads (see xfail_by_lang).
        if 'rungs' in r['key']:
            xf = xfail_by_lang(r['lang'])
            if xf is None: return 'XFUNKNOWN', None
            if xf > 0:     return 'XFAIL', xf
        return 'DONE',None
    # ⭐ A RE-CRITERIONED ROW IS COMPARED, NOT EXCUSED (Lon 2026-09-08): likeforlike() reads the progress table on a
    # fixed population, so the movement is real; only a suite the table cannot see falls through to NOROWS/ONEDAY.
    if recriterioned(r):
        L=likeforlike(r)
        if not L: return ('NOROWS' if lfl_why(r)=='norows' else 'ONEDAY'),None
        return 'MOVE', (L['now']-L['then'], L['basis'])
    days=(d(r['today_date'])-d(r['first_date'])).days
    if days<=0: return 'NEW',None
    return 'MOVE', (tp-fp, r['first_date'])
def xfail_annotation(r, k):
    """The one sentence a rung suite row carrying xfails must show when eta() is NOT already saying it.
    Returns '' for a non-rungs, an unreadable census, a zero count, or k=='XFAIL' (which says it itself)."""
    if k in ('XFAIL', 'XFUNKNOWN') or 'rungs' not in r['key']: return ''
    xf = xfail_by_lang(r['lang'])
    if not xf: return ''
    gap = int(r['today_total']) - int(r['today_pass'])
    same = ' — the whole gap' if gap == xf else f' of a {gap}-wide gap'
    return (f"{xf} xfail counted as FAIL{same} (CEO-416): they are in the denominator and not the "
            f"numerator, so this row can only close by CURING them, never by re-captioning")
# ⛔⛔⛔ THE PRINTED SUITE BANNER IS DELETED (Lon 2026-09-13, in-chat to hq_S, verbatim: "See that banner you
# just output. The header says suite pass/tot gap date state. Delete whatever produced that. I want it gone.
# I've ordered that removed." and, when the first cut took only the header row: "I want the entire text gone.
# Not just the header.").  banner() and grid() -- the two functions that rendered that table to STDOUT -- are
# GONE, and so is the dispatch that called them, so a no-arg run of this script now prints NOTHING and exits 0.
# ⛔ DO NOT RE-ADD A DISPLAY PATH HERE.  What survives is FILE WRITING ONLY: --set writes one SUITES.tsv row and
# re-renders that row in SCORE.md, --render and --md return the table TEXT for SCORE.md.  Those are the ONE
# LEADERBOARD Lon ordered kept ("so whenever we want to know the state it is there not an hour away of running
# tests") -- a file a reader opens on purpose, which is the opposite of text printed at someone every turn.
def md():
    head,rows=load(); rows=_scrip(rows); today=dt.date.today(); DEF=deferred_rows()
    print('| suite | lang | result | graded | tree | state |'); print('|---|---|---|---|---|---|')
    for r in rows:
        k,e=eta(r,today)
        if k=='NORUNNER':
            why=r['criterion_changed'].split(':',1)[-1] if r['criterion_changed'] else "its lane's runner has not written it"
            dfr=DEF.get(r['key'])
            if dfr:
                # ⛔ DEFERRED PRINTS ITS RULING AND THE WORK IT WAITS ON, every time, because that is condition 3
                # of ARCH-PROGRAM-LEDGER § DEFERRED: a deferral that stops naming what it waits on has become an
                # abandonment, and nothing on the board would say so.
                # ⛔ THE RULING'S OWN TEXT IS DATA IN A MARKDOWN TABLE, so every `|` in it becomes `·`. Measured:
                # gnu_fd's waiting_on names the grep proving the substrate is absent (attr_var·put_attr·coroutin)
                # and those three pipes turned one 7-field row into nine -- the table stops parsing for every
                # reader downstream. ⭐ SUBSTITUTED, NOT BACKSLASH-ESCAPED: `\\|` satisfies a markdown renderer
                # and NOT an instrument that splits the row on '|', and the instruments are the harder reader.
                _w=dfr['waiting_on'][:400].replace('|','·'); _b=dfr['ruled_by'].replace('|','·')
                print(f"| {r['nick']} | {r['lang']} | -/{r['today_total']} ({dfr['count']} DEFERRED, not counted as failures) | never graded | - | DEFERRED by Lon ({_b}), IN SCOPE AND NOT A FAILURE - waiting on: {_w} |")
            else:
                # ⛔ NO READING IS NOT "VENDORED, NO RUNNER" (coo 2026-09-23, row instruments-benchmarks-enter-the-suite-grid-...): the seven
                # benchmark rows entered this table EMPTY because their lanes write them (CEO-775) and several lanes' runners already exist,
                # so the old words told a reader two false things about a row nobody has graded yet. An unknown total prints `-`, never `-/`.
                _tt=(r.get('today_total') or '').strip()
                print(f"| {r['nick']} | {r['lang']} | {('-/' + _tt) if _tt else '-'} (no reading yet) | never graded | - | NO READING YET: {why} - a population with no grader is a debt on the board, never an absence from it |")
            continue
        rc=recriterioned(r)
        if rc:
            L=likeforlike(r)
            if L:
                mv=(f"{L['now']-L['then']:+d}"
                    f" <sup>[{L['then']}→{L['now']} of {L['pop']} since {L['basis'][5:]}]</sup>")
            else:
                mv='—'
        else:
            mv=f"{int(r['today_pass'])-int(r['first_pass']):+d}"
        named={'DONE':'done','XFAIL':f'{e} xfail=fail','XFUNKNOWN':'xfail unreadable'}
        tail=named[k] if k in named else ''
        # ⭐ AND THE CONVENTION IS STATED WHEREVER THE ROW IS READ, not only when the fraction closes.
        # eta() can only return 'XFAIL' when pass==total, so the moment a rung suite row is corrected to the
        # honest 1871/1898 the xfail count VANISHES from the cell -- the reader then sees a 27-wide gap with
        # no way to know it IS the known-red set rather than 27 unmeasured entries. Four rung suites were in
        # exactly that state and said nothing (SnoRungs 27, RakRungs 156, SncRungs 16, RebRungs 4).
        # (ceo ruling to the coo, 2026-09-08: "Set it, state the convention in the cell.")
        xa = xfail_annotation(r, k)
        if xa: tail = (tail + ' · ' if tail else '') + xa
        _vd=(r.get('today_void') or '').strip()
        if _vd: tail = f"READING VOID, NOT A REGRESSION: {_vd}" + (' · ' + tail if tail else '')
        # ⛔ THE GRADED CELL IS THE DATE OF THE GRADING AND NOTHING RELATIVE TO THE RENDER (coo 2026-09-23, row instruments-score-md-graded-
        # cell-freezes-a-relative-age-so-a-row-not-re-rendered-today-still-reads-today). Lon 2026-09-13: "Add the date of the grading for each
        # test suite. Say when was the last time the test was run which produced the results which are being reported." The cell also
        # carried '(today)' / '(yesterday)' / '(N days ago)' reckoned against the day of the RENDER, and render_table(only_key=...) re-renders
        # only the row a run measured, so every other row kept the age it was written with: on 2026-09-23 all 26 cells read '(today)', among
        # them Dotnet, TPgm and Roast graded 2026-09-16 -- a false label by construction. A date cannot go stale; an age written into a
        # file can. The age is the reader's subtraction, or --check's (which now compares a render that no longer moves with the calendar).
        # the CEO-749 shape: OUTSIDE named in the same row -- the last OUTSIDE=N token of the row's own criterion stamp (coo 2026-09-16,
        # row util-suite-banner-render-rewrites-rows-a-seat-did-not-measure-and-there-is-no-check-mode-that-writes-nothing: a render
        # used to drop a hand-written OUTSIDE clause, hq_raku measured SnoRungs 1961/1980 OUTSIDE=8 rendered to a plain 1961/1980)
        _ot=re.findall(r'OUTSIDE=(\d+)', r.get('criterion_changed') or '')
        # the CEO-1286 shape (Lon 2026-09-26): EXCLUDED=k, the programs NOT IN THE SPITBOL DIALECT the denominator leaves out, from the
        # row's own today_excluded column (set by --set ... --excluded k), shown whenever the column carries a count, zero included.
        _ex=(r.get('today_excluded') or '').strip()
        _ws=(r.get('today_secs') or '').strip()
        _res=f"{r['today_pass']}/{r['today_total']}" + (f" EXCLUDED={_ex}" if _ex.isdigit() else "") + (f" OUTSIDE={_ot[-1]}" if _ot else "") + (f" WALL={_ws}s" if _ws.isdigit() else "")
        print(f"| {r['nick']} | {r['lang']} | {_res} | {r['today_date']} | `{r['tree']}` | {tail} |")
# a scratch TSV keeps its scratch SCORE.md beside it (a fixture that redirects the record redirects the render with it); the real record
# renders into the .github beside this script
SCORE=os.environ.get('S4E_SCORE_MD') or (os.path.join(os.path.dirname(os.path.abspath(TSV)),'SCORE.md') if os.environ.get('S4E_SUITES_TSV') else os.path.join(GH,'SCORE.md'))
def md_lines():
    import io, contextlib
    buf=io.StringIO()
    with contextlib.redirect_stdout(buf): md()
    return buf.getvalue().rstrip('\n').split('\n')
_NICK2KEY=None
def _row_key(line):
    """The suite key a rendered markdown row belongs to: the row names the suite by its NICKNAME only (Lon
    2026-09-12: one name, not the nickname and the key), and the nickname resolves to the key through SUITES.tsv.
    None for the header and separator rows, and for any first cell that is not a nickname on file."""
    global _NICK2KEY
    if _NICK2KEY is None:
        _head,_rows=load(); _NICK2KEY={r['nick']:r['key'] for r in _scrip(_rows)}
    m = re.match(r'^\|\s*([^|]+?)\s*\|', line)
    return _NICK2KEY.get(m.group(1)) if m else None
def check_table():
    """--check: every suite-table row where SCORE.md and a fresh render from SUITES.tsv DISAGREE, printed side by side, WRITING
    NOTHING. rc 1 on a disagreement, 0 when the table agrees (population printed), 2 when the table cannot be found. The batch
    audit runs this every tick; a seat verifying after a rebase runs this, never --render (hq_raku 2026-09-16: --render as a
    verification step rewrote Zona, Jcon and SnoRungs rows it never measured, twice, and the only way to ask whether the files agreed
    was the command that made them agree)."""
    if not os.path.exists(SCORE):
        print(f"REFUSE(rc=2): {SCORE} missing beside the TSV"); return 2
    L=open(SCORE,encoding='utf-8').read().split('\n')
    hdr=[i for i,l in enumerate(L) if l.startswith('| suite | lang |')]
    if len(hdr)!=1:
        print(f"REFUSE(rc=2): {len(hdr)} '| suite | lang |' header(s) in {SCORE}, expected exactly one"); return 2
    st=hdr[0]; en=st
    while en<len(L) and L[en].startswith('|'): en+=1
    fresh={_row_key(l):l for l in md_lines() if _row_key(l)}
    cur={_row_key(l):l for l in L[st:en] if _row_key(l)}
    diff=[k for k in cur if k in fresh and cur[k]!=fresh[k]]
    only_score=[k for k in cur if k not in fresh]; only_tsv=[k for k in fresh if k not in cur]
    n=len(cur)
    for k in diff:
        print(f"DISAGREE {k}:"); print(f"  SCORE.md : {cur[k]}"); print(f"  SUITES.tsv renders: {fresh[k]}")
    for k in only_score: print(f"DISAGREE {k}: in SCORE.md's table, no SUITES.tsv row renders it")
    for k in only_tsv: print(f"DISAGREE {k}: SUITES.tsv row with no SCORE.md table row")
    bad=len(diff)+len(only_score)+len(only_tsv)
    print(f"population: {n} table row(s) checked against SUITES.tsv; {bad} disagree; nothing written")
    if bad:
        print("  a display row is rewritten only by the seat that measured it: util_suite_banner.py --render --only <key>  (or the runner's own write); --render --all-rows rewrites every row from SUITES.tsv and is a different act")
        return 1
    print(f"CHECK OK: SCORE.md's suite table agrees with SUITES.tsv on all {n} rows")
    return 0
def render_table(only_key=None):
    """Re-render SCORE.md § THE SUITE TABLE (the rows under the '| suite | lang |' header) from SUITES.tsv, in place.
    Returns a one-line note; never silent, never a guess: a table it cannot find is said NOT rendered.

    ⛔⭐ only_key SCOPES THE WRITE TO THE ONE ROW THE CALLER ACTUALLY MEASURED, and `--set` always passes it
    (coo 2026-09-08, on hq_P's measured report; the unscoped re-render below was the coo's own 2026-09-06
    change and this is its correction). THE DEFECT: this function rebuilt EVERY row from the LOCAL
    SUITES.tsv, so a seat measuring one suite rewrote the display cells of suites its run never touched --
    with whatever its local TSV happened to hold. When that TSV was behind origin, the write was a SILENT
    REVERT of another seat's newer number, landing inside a commit whose message truthfully described
    something else entirely. hq_P measured it happening twice in one evening: their tree held
    `Budne 64/93 (0bd961e07)` while origin already held `Budne 66/93 (251693227)`, and only a rebase
    conflict caught it -- `git add -A` after a board would have pushed the revert silently.
    ⛔ The blast radius was the WHOLE TABLE and the trigger was ordinary: run any board, commit normally.
    A row nobody measured this session is left BYTE-IDENTICAL now, which is also what makes a genuine
    disagreement surface as a conflict instead of resolving itself in the wrong direction.
    `--render` keeps the unscoped whole-table behaviour, because asking for it explicitly is a different
    act from a board run doing it as a side effect nobody typed."""
    if not os.path.exists(SCORE):
        return f"⚠ suite table NOT rendered: {SCORE} missing beside the TSV (SUITES.tsv is set; the markdown table reads STALE until a renderer runs)"
    L=open(SCORE,encoding='utf-8').read().split('\n')
    hdr=[i for i,l in enumerate(L) if l.startswith('| suite | lang |')]
    if len(hdr)!=1:
        return f"⚠ suite table NOT rendered: {len(hdr)} '| suite | lang |' header(s) in {SCORE}, expected exactly one"
    st=hdr[0]; en=st
    while en<len(L) and L[en].startswith('|'): en+=1
    new=md_lines(); old=L[st:en]
    scope=""
    if only_key is not None:
        fresh={_row_key(l):l for l in new if _row_key(l)}
        if only_key not in fresh:
            return f"⚠ suite table NOT rendered: no rendered row for suite key {only_key!r} (SUITES.tsv is set; the markdown row reads STALE)"
        merged=[fresh[only_key] if _row_key(l)==only_key else l for l in old]
        if only_key not in {_row_key(l) for l in old}: merged.append(fresh[only_key])
        new=merged
        scope=f" (scoped to {only_key}; rows for suites this run did not measure left byte-identical)"
    changed=sum(1 for a,b in zip(old,new) if a!=b)+abs(len(old)-len(new))
    if changed==0: return "suite table: SCORE.md § THE SUITE TABLE already matches SUITES.tsv (0 rows changed)%s" % scope
    L[st:en]=new; open(SCORE,'w',encoding='utf-8').write('\n'.join(L))
    return f"suite table: SCORE.md § THE SUITE TABLE re-rendered from SUITES.tsv in the same call ({changed} row(s) changed){scope}"
def wall(r):
    """The grid's Wall cell: the row's today_secs (CEO-1562) as 95s, 24m36s or 1h08m; blank when the row carries no reading of it."""
    v=(r.get('today_secs') or '').strip()
    if not v.isdigit(): return ""
    n=int(v)
    if n<60: return f"{n}s"
    if n<3600: return f"{n//60}m{n%60:02d}s"
    return f"{n//3600}h{(n%3600)//60:02d}m"
def run_range(r):
    """The grid's Run cell: the date and time range of the readings the row was assembled from, the oldest reading to the newest, in the box's own
    clock (Lon 2026-11-11 10:2x CST, in the coo's window, verbatim: "The stop turn banner should display the date/time-range of the run that
    created the row."). The row's today_run_first and today_run_last hold the two readings' UTC stamps (util_score_row.py from-progress sets them,
    --set-run). One day: 11-11 08:27-08:31. More than one day: 11-08>11-11 09:12 (the first day, then the last day and time). Blank when the row
    carries no stamps (a row no reading has written since the column exists)."""
    import calendar, time
    def _loc(v):
        m=re.match(r'^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2})(?::(\d{2}))?', (v or '').strip())
        if not m: return None
        return time.localtime(calendar.timegm((int(m.group(1)),int(m.group(2)),int(m.group(3)),int(m.group(4)),int(m.group(5)),int(m.group(6) or 0),0,0,0)))
    a,b=_loc(r.get('today_run_first')),_loc(r.get('today_run_last'))
    if not a or not b: return ""
    d=lambda t: f"{t.tm_mon:02d}-{t.tm_mday:02d}"; h=lambda t: f"{t.tm_hour:02d}:{t.tm_min:02d}"
    return f"{d(a)} {h(a)}-{h(b)}" if (a.tm_year,a.tm_yday)==(b.tm_year,b.tm_yday) else f"{d(a)}>{d(b)} {h(b)}"
def run_stamps(r):
    """The grid's Earliest and Latest cells (Lon 2026-11-12 19:0x CST, in the grader's window, verbatim: "You can then report two date/time stampes,
    the earliest , and the latest most recent. Do not show the run range anymore."): the box-clock MM-DD HH:MM of the oldest and of the newest reading
    the row was assembled from (today_run_first, today_run_last, set by from-progress); blank when the row carries none."""
    import calendar, time
    def _s(v):
        m=re.match(r'^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2})(?::(\d{2}))?', (v or '').strip())
        if not m: return ""
        t=time.localtime(calendar.timegm((int(m.group(1)),int(m.group(2)),int(m.group(3)),int(m.group(4)),int(m.group(5)),int(m.group(6) or 0),0,0,0)))
        return f"{t.tm_mon:02d}-{t.tm_mday:02d} {t.tm_hour:02d}:{t.tm_min:02d}"
    return [_s(r.get('today_run_first')), _s(r.get('today_run_last'))]
# ⭐ A SEAT'S GRID SHOWS ITS OWN LANGUAGES ON ITS OWN ENGINE (Lon 2026-10-17, in-chat to hq_jvm, verbatim: "The test suite banner is wrong
# for this seat, since JVM is only SNOBOL4 and Snocone and Rebus." · "The test suite banners have the wrong languages." · "The suite banner
# should represent the snobol4jvm program, not SCRIP."; to hq_dotnet: "The test suite banner is wrong since .NET supports only SNOBOL4,
# actually SPITBOL." · "The suite banner should represent the snobol4dotnet executable program, not SCRIP."; ceo CEO-1822). GRID_ENGINES
# names a port seat's engine: its grid reads only the <key>@<engine> rows, every one measured on that engine, so no SCRIP number reaches it,
# and before its first board it says "no row yet (engine x)" rather than borrowing SCRIP's. GRID_LANGS then keeps only the rows whose lang
# the seat lists. Every other seat reads the bare keys, SCRIP's, exactly as before. The seat is derived the way the history writer derives
# it (S4E_SEAT, else the root's own folder name /home/claude_<seat>), so the banner verb passes no new argument.
GRID_LANGS={'jvm':('snobol4','snocone','rebus'),'dotnet':('snobol4',)}
# ⭐ THE ENGINE IS A RUNNER SETTING (CEO-1822): a port seat's grid reads its own engine's <key>@<engine> rows from this one table and no
# other; the separate snobol4jvm table hq_jvm's 4bf4aa29 pointed at is retired on the ceo's ruling (one results.tsv, one SUITES.tsv).
GRID_ENGINES={'jvm':'jvm','dotnet':'dotnet'}
GRID_PROGRAMS={'jvm':'snobol4jvm','dotnet':'snobol4dotnet'}
def _grid_seat():
    # ⛔ S4E_SEAT IS THE BUS IDENTITY (hq_dotnet, hq_jvm) SINCE util_fleet_settings.sh wrote it into every root's env (CEO-2041); the folder
    # fallback reads dotnet/jvm. Both forms name the same port: strip the hq_ prefix, or a port seat's grid falls through to SCRIP's (ceo CEO-2081).
    return re.sub(r'^hq_','',os.environ.get('S4E_SEAT') or re.sub(r'^claude_','',os.path.basename(os.path.abspath(os.path.join(HERE,'..','..')))))
def _grid_langs():
    return GRID_LANGS.get(_grid_seat())
def _grid_engine():
    return GRID_ENGINES.get(_grid_seat())
def delta(r, tp, tt):
    """THE DELTA COLUMN (Lon 2026-11-04, in-chat to the cto: "In the display banner add a column for a delta/difference and distribute the
    new double-sided banner across the fleet." and, 09:2x: "The delta column represents how many failures remain."; CEO-2129): Total minus
    Pass, the programs of the printed denominator still to cure. 0 on a done suite; blank only where the row has no reading."""
    return f"{tt-tp}"
def grid(plain=False):
    """THE SUITE SCORE GRID (Lon 2026-09-13, in-chat to cfo, verbatim, in order: "And a grid of the test suite
    scores." - "Ensure a grid is output not text from the shell script." - "No, the grid must not be text." -
    "I want a excel type grid with lines and cells." - "I mean border lines." - "make it smaller." - "Take the
    grid you had and make it smaller.").
    SCORE IS TWO COLUMNS, Pass and Total (Lon 2026-09-13: "break out score into two columns."), so both
    numbers right-align in their own cell and a reader can compare denominators down the column instead of
    parsing a slash out of a string.
    LANG IS THE FIRST COLUMN (Lon 2026-09-13: "Put lang column first."), which is also the sort key, so the
    column a reader scans and the order the rows are in are the same thing.
    ROWS ARE ORDERED BY LANG, THEN BY SUITE NAME (Lon 2026-09-13: "Put rows in order by lang and then suite
    name."). The TSV's own order is custody order, which is not a reading order.
    ONE SUITE PER ROW with its own columns, which is the grid Lon kept -- made SMALLER by spending less on
    whitespace and rules rather than by re-laying it out: cells are padded by one column instead of two, and
    the rule between every data row is gone, keeping the outer border and the header rule. 24 suites go from
    51 lines to 28 and the width drops with it. Widths come from dw(), this file's display-width authority."""
    eng=_grid_engine(); langs=_grid_langs()
    head,rows=load()
    rows=[r for r in rows if _engine_of(r.get('key',''))==eng] if eng else _scrip(rows)
    if langs: rows=[r for r in rows if (r.get('lang') or '').strip().lower() in langs]
    data=[]
    # ⭐ M3 and M4 (Lon 2026-11-04, in-chat to the cto, verbatim: "The display banner need modifying to show both mode 3 and mode 4 numbers
    # seperately."; CTO-482): each mode's own pass count over the SAME population and tree as Pass, from the today_m3_pass and today_m4_pass
    # columns the row's writer sets (--set ... --m3 N --m4 N, util_score_row.py from-progress counts them beside the both-modes AND). A row whose
    # reading carries no per-mode count prints "-" in both cells: the number is the writer's or it is absent, never read from another population.
    def _pm(r):
        return [((r.get(c) or '').strip() or "-") for c in ('today_m3_pass','today_m4_pass')]
    for r in rows:
        # ⛔ A ROW WITH NO READING IS PRINTED, NEVER SKIPPED (coo 2026-09-23, row instruments-benchmarks-enter-the-suite-grid-...). This
        # loop used to `continue` past any row whose today_* did not parse, so a suite nobody had graded yet vanished from the grid while
        # md() printed it as a debt -- harmless while all 24 rows carried readings, and it would have hidden all seven benchmark rows the
        # day they entered EMPTY. A suite is a debt on the board, never an absence from it: dashes, and the state says why.
        try: tp,tt=int(r['today_pass']),int(r['today_total'])
        except (ValueError,KeyError):
            _t=(r.get('today_total') or '').strip()
            data.append([r.get('lang',''), r['nick'], "-", _t if _t.isdigit() else "-"] + _pm(r) + ["", (r.get('today_excluded') or '').strip() or "", "-", wall(r)] + run_stamps(r) + ["NO READING"] + ([_read_day(r)] if eng else [])); continue
        # ⛔ `.0f` alone rounds 823/826 (99.64%) up to "100%" while the State column beside it correctly
        # reads not-DONE (tp<tt) -- a contradiction inside one row (Lon 2026-09-23, caught reading this
        # exact grid). 100% is reserved for tp>=tt (RULES.md: "100% only when FAIL=0 over the printed
        # denominator"); clamp a short suite's rounded display at 99% so it can never borrow that word.
        if not tt: pct="-"
        else:
            pv=round(100.0*tp/tt)
            if tp<tt and pv>=100: pv=99
            pct=f"{pv}%"
        # ⭐ EXCL (Lon 2026-09-26, CEO-1286: "We want to show this number of EXCLUDED tests in the test-suite grid."): the programs not in
        # the SPITBOL dialect that this row's Total leaves out, from today_excluded; blank for a suite with no such ruling (the rung suites).
        data.append([r.get('lang',''), r['nick'], f"{tp}", f"{tt}"] + _pm(r) + [delta(r, tp, tt), (r.get('today_excluded') or '').strip(), pct, wall(r)] + run_stamps(r) + ["VOID" if (r.get('today_void') or '').strip() else ("DONE" if tt and tp>=tt else "")] + ([_read_day(r)] if eng else []))
    data.sort(key=lambda r: (r[0].lower(), r[1].lower()))
    if not data:
        if eng: print(f"SUITE GRID: no row yet (engine {eng}) -- no board has graded {GRID_PROGRAMS.get(eng, eng)} into SUITES.tsv"); return
        print("SUITE GRID: no readable rows in SUITES.tsv"); return
    hdr=["Lang","Suite","Pass","Total","M3","M4","\u0394","Excl","Pct","Wall","Earliest","Latest","State"] + (["Date"] if eng else [])
    cols=len(hdr)
    # ⭐ ONE EXTRA COLUMN OF ROOM PER CELL (Lon 2026-09-13: "Give one extra space in each column to give room
    # to breath."). Added to the WIDTH, so the rules that span each column widen with it and the box still
    # closes; pad() and rpad() then place the slack on the correct side -- left of a right-justified number,
    # right of a left-justified name -- which is why this is one number here and not a space glued onto a cell.
    w=[max(dw(hdr[c]), max(dw(r[c]) for r in data)) + 1 for c in range(cols)]
    def rule(l,m,rr): return l + m.join("\u2500"*(w[c]) for c in range(cols)) + rr
    NUM={2,3,4,5,6,7,8,9}   # Pass, Total, M3, M4, Delta, Excl, Pct, Wall -- the numeric cells, right-justified; Lang/Suite/State stay left.
    def line(cs, hdr_row=False):
        # ⭐ THE EXTRA COLUMN IS A TRAILING SPACE ON EVERY CELL, not slack handed to the justifier. Give it to
        # rpad() instead and a right-justified number lands FLUSH AGAINST THE RIGHT BORDER with the gap on its
        # far side, which is the opposite of room to breathe. So each cell is justified into w-1 and then gets
        # one space: names breathe on the right, numbers breathe on the right, and the columns still line up.
        def cell(c):
            j = rpad if (c in NUM and not hdr_row) else pad
            return j(cs[c], w[c]-1) + " "
        return "\u2502" + "\u2502".join(cell(c) for c in range(cols)) + "\u2502"
    _si=hdr.index("State")   # by name: the Run column moved State from the eleventh cell to the twelfth, and the count read 0 at 100% (COO-517, the same hour)
    done=sum(1 for r in data if r[_si]=="DONE")
    print(rule("\u250c","\u252c","\u2510"))
    print(line(hdr, hdr_row=True))
    print(rule("\u251c","\u253c","\u2524"))
    for r in data: print(line(r))
    print(rule("\u2514","\u2534","\u2518"))
    if eng:
        stale=[r[1] for r in data if r[hdr.index('Date')]!=dt.date.today().strftime('%m-%d')]
        print(f"{len(data)} suites, {done} at 100% -- {GRID_PROGRAMS.get(eng, eng)}'s own readings (engine {eng}), {', '.join(langs or ())}")
        if stale: print(f"NOT WRITTEN TODAY: {', '.join(stale)} -- file them with the coo (s4e_test_request.sh --engine {eng} <key> --part chunk:NN|core); a row is current only when every entry has a reading (ceo CEO-1903)")
    else: print(f"{len(data)} suites, {done} at 100%")
def _read_day(r):
    d=(r.get('today_date') or '').strip()
    return d[5:] if len(d)==10 else "-"
# ⭐⭐⭐ THE ENGINE LEADERBOARD (Lon 2026-10-22 12:0x CDT, in-chat to the ceo, verbatim: "Get both HQ-JVM and HQ-DOTNET working with leader boards."; ceo
# CEO-1903): every suite a port engine has a row for, one line each, SCRIP's reading beside snobol4dotnet's and snobol4jvm's from this one table, each port
# cell with the day its row was last written, so a stale cell shows its age and the race between the three engines is one glance. It prints ONLY on request,
# --engines, never in any seat's default banner, and carries no STANDINGS line (Lon 2026-10-22 12:3x, in-chat to the ceo, verbatim: "Just make sure not to display that STANDINGS banner. What happened to the
# previous banner?" -- printed under the ceo's grid it pushed the grid's top rows past the Stop hook's tail -40, and the STANDINGS line is gone). It reads
# SUITES.tsv only and runs nothing.
def engines(plain=False):
    head,rows=load(); by={r['key']:r for r in rows}
    ports=[e for e in ('dotnet','jvm')]
    bases=sorted({k.partition('@')[0] for k in by if _engine_of(k) in ports}, key=lambda b: ((by.get(b) or by.get(b+'@jvm') or by.get(b+'@dotnet') or {}).get('lang',''), (by.get(b) or by.get(b+'@jvm') or by.get(b+'@dotnet') or {}).get('nick','')))
    if not bases: print("ENGINE LEADERBOARD: no port engine row in SUITES.tsv"); return
    def cell(r):
        if not r: return ("", "")
        try: tp,tt=int(r['today_pass']),int(r['today_total'])
        except (ValueError,KeyError): return ("-", _read_day(r))
        return (f"{tp}/{tt}" + (" ✓" if tt and tp>=tt else ""), _read_day(r))
    hdr=["Lang","Suite","SCRIP",".NET","date","JVM","date"]
    data=[]
    for b in bases:
        any_r=by.get(b) or by.get(b+'@jvm') or by.get(b+'@dotnet')
        sc=cell(by.get(b)); dn=cell(by.get(b+'@dotnet')); jv=cell(by.get(b+'@jvm'))
        data.append([any_r.get('lang',''), any_r.get('nick',b), sc[0], dn[0], dn[1], jv[0], jv[1]])
    cols=len(hdr); w=[max(dw(hdr[c]), max(dw(r[c]) for r in data)) + 1 for c in range(cols)]
    def rule(l,m,rr): return l + m.join("\u2500"*(w[c]) for c in range(cols)) + rr
    NUM={2,3,5}
    def line(cs, h=False): return "\u2502" + "\u2502".join(((rpad if (c in NUM and not h) else pad)(cs[c], w[c]-1) + " ") for c in range(cols)) + "\u2502"
    print("ENGINE LEADERBOARD -- SCRIP against snobol4dotnet (hq_dotnet) and snobol4jvm (hq_jvm), every suite a port engine grades; date = the day the row was last written from its readings")
    print(rule("\u250c","\u252c","\u2510")); print(line(hdr, True)); print(rule("\u251c","\u253c","\u2524"))
    for r in data: print(line(r))
    print(rule("\u2514","\u2534","\u2518"))
# ⭐ THE README'S SUITE TABLE IS GENERATED FROM THIS RECORD, NEVER TYPED (Lon 2026-09-23 16:2x, in-chat to the ceo: "We want the
# test suite numbers and the benchmark numbers in the README."; CEO-1216; row instruments-the-readme-suite-table-is-written-from-the-
# suite-table-and-a-gate-holds-it-current, the coo). SCRIP/README.md read the leaderboard "on 2026-09-07" sixteen days later -- Gimpel
# 104/127 against 127/132, IPL 75/89 against 194/194 -- because a hand-kept copy has no writer. --readme renders the block between two
# marker lines from SUITES.tsv and stamps the .github commit it read (the PIN); --readme-check [--pinned] holds it: --pinned proves the
# block is exactly the render of SUITES.tsv AT ITS PIN (a hand edit or a corrupted cell reds, and it never flaps), the full check also
# proves every row matches SUITES.tsv as it stands now (the currency the other repo moves about fifty times a day, so it can lag).
# Raku is labelled IN DEVELOPMENT on Lon's word (CEO-1219) and no other language carries a label.
README_BEGIN = '<!-- SUITE-TABLE:BEGIN'
README_END = '<!-- SUITE-TABLE:END -->'
README_LANGS = [('snobol4', 'SNOBOL4'), ('icon', 'Icon'), ('prolog', 'Prolog'), ('pascal', 'Pascal'), ('raku', 'Raku'), ('snocone', 'Snocone'), ('rebus', 'Rebus'),
                ('scriptix', 'SCRIPtix (hybrid)')]
# ⛔ THE README SHOWS FIVE LANGUAGES' NUMBERS (Lon 2026-09-26 13:5x CDT, in-chat to the ceo, verbatim: "Do not show Rebus or Snocone test-suite
#   or benchmark numbers in the README."; ceo CEO-1284): the Snocone and Rebus rows stay in SUITES.tsv and SCORE.md (the leaderboard grades them
#   like every other suite) and are HIDDEN from the README block -- placed, never refused, never rendered.
# ⭐ AND SCRIP, THE EIGHTH, HYBRID LANGUAGE, IS SHOWN (Lon 2026-09-27, in-chat to the ceo, verbatim: "You can add SCRIP to the README. Not sure what
#   my 5-language word was. But there are 7 languages and then *.scrip (markdown files) makes a eigth \"hybrid\" language."; ceo CEO-1324): the polyglot
#   .scrip document -- one markdown file, one fenced section per language, compiled and run together -- is rendered after the five as SCRIP (hybrid);
#   Snocone and Rebus stay hidden on the 09-26 word, which this does not touch.
# ⭐ SNOCONE AND REBUS SHOWN AGAIN (Lon 2026-10-25 20:3x CDT, in-chat to the ceo, verbatim: "Do not hide Snocone and Rebus suites."; ceo CEO-1986): a
#   reversal of the 2026-09-26 word above (CEO-1284), stated as one. The README block renders all 44 SCRIP suites, as the banner does.
README_HIDDEN_LANGS = set()
README_IN_DEVELOPMENT = {'raku'}
README_HEAD_N = 8   # the BEGIN line, four prose lines, a blank, the table header and its rule -- rows start here
README_RUNNER = {
    'gimpel': 'test_snobol4_gimpel_suite.sh', 'csnobol4': 'test_snobol4_csnobol4_suite.sh', 'snoflake': 'test_snoflake_suite.sh',
    'aisnobol': 'test_snobol4_aisnobol_suite.sh', 'dotnet': 'test_snobol4_dotnet_suite.sh',
    'testpgms': 'test_snobol4_spitbol_testpgms_suite.sh', 'x64tests': 'test_snobol4_spitbol_x64_suite.sh',
    # ⭐ x32tests (the coo 2026-09-27, ceo CEO-1315): hq_snobol4's X32T row reached SUITES.tsv with no runner named here, so the README
    # render and its gate's reported default arm refused rc 2 on origin for the whole table.
    'x32tests': 'test_snobol4_spitbol_x32_suite.sh',
    'arizona': 'test_icon_arizona_suite.sh', 'jcon': 'test_icon_jcon_suite.sh', 'ipl': 'test_icon_ipl_suite.sh',
    'inria': 'test_prolog_inria_suite.sh', 'swi': 'test_prolog_swi_suite.sh', 'gnu': 'test_prolog_gnu_suite.sh',
    'logtalk': 'test_prolog_logtalk_suite.sh',
    # ⭐ puzzles and pascal-demos (the ceo 2026-10-10, CEO-1606, Lon: "Ensure that the new rows in the test suite banner for all the new test suites are
    # inserted"): the rows were opened UNGRADED the day their packages reached origin, with their runners named here the same day, so the README render
    # never refuses on them (the X32T lesson of CEO-1315).
    'puzzles': 'test_prolog_puzzles_suite.sh', 'pascal-demos': 'test_demos_suite.sh pascal',
    'raku-demos': 'test_demos_suite.sh raku',
    # trealla (the coo opened TreallaTests at SCRIP da42f411d without naming its runner here; the ceo added it 2026-10-10, CEO-1616 -- the X32T lesson a third time: THE RENDERER'S MAP IS PART OF OPENING A ROW).
    'trealla': 'test_prolog_trealla_suite.sh', 'xsb': 'test_prolog_xsb_suite.sh', 'fpc': 'test_pascal_fpc_suite.sh', 'wirth76': 'test_pascal_wirth76_suite.sh', 'pat': 'test_pascal_pat_suite.sh', 'rosetta-pascal': 'test_pascal_rosetta_suite.sh', 'rosetta-prolog': 'test_prolog_rosetta_suite.sh',
    'unitests': 'test_icon_unicon_suite.sh',
    # the sixteen suites found by the sweep of /home/resources (the cio 2026-11-10, CIO-113; Lon: "make it official and add all the new test suites to the test suite banner."):
    # opened UNGRADED with their runner named the same day (the X32T lesson); each is built and graded by the one grader when its mining row lands.
    # pascal-sets (PasSets) became six rows 2026-11-11 on Lon's word in the coo's window: "So since they are six things, make them six items on the banner." (COO-514)
    # hakank-more (HakankMore) and other-prologs (OtherProlog) left the banner 2026-11-11 on Lon's word in the coo's window: "Get rid of the bogus test suites added." (COO-512; the grader's census: neither has entries of its own)
    # snobol4-more (SnoMore) left the banner 2026-11-11 on Lon's word in the grader's window: "It seems your SnoMore is invalid. That is not one thing, that is a mess." / "So then you remove the bogus SnoMore row in the banner."
    'vanilla': 'corpus_suite_harness.py', 'icon-packs': 'corpus_suite_harness.py', 'unicon-uni': 'corpus_suite_harness.py',
    'chat80': 'corpus_suite_harness.py', 'press': 'corpus_suite_harness.py', 'trealla-more': 'corpus_suite_harness.py',
    'xsb-examples': 'corpus_suite_harness.py', 'prolog-sets': 'corpus_suite_harness.py', 'fpc-source': 'corpus_suite_harness.py',
    'stanford-pascal': 'corpus_suite_harness.py', 'advpas350': 'corpus_suite_harness.py', 'tply': 'corpus_suite_harness.py', 'cocor-pascal': 'corpus_suite_harness.py', 'dsa': 'corpus_suite_harness.py', 'pascal-lisp': 'corpus_suite_harness.py', 'tex': 'corpus_suite_harness.py', 'rakudo-t': 'corpus_suite_harness.py', 'raku-examples': 'corpus_suite_harness.py',
    'roast': 'raku_roast_scoreboard.sh --run', 'sno-rungs': 'test_corpus_snobol4.sh', 'icn-rungs': 'board_icon_rungs.sh',
    'pl-rungs': 'corpus_suite_harness.py run tests/prolog/ALL.pl', 'pas-rungs': 'corpus_suite_harness.py run tests/pascal/ALL.pas',
    'raku-rungs': 'corpus_suite_harness.py run tests/raku/ALL.raku', 'snc-rungs': 'corpus_suite_harness.py run tests/snocone/ALL.sc',
    'reb-rungs': 'corpus_suite_harness.py run tests/rebus/ALL.reb',
    # ⭐ THE BENCHMARK ROWS (Lon 2026-09-23 17:2x, CEO-1221; row instruments-benchmarks-enter-the-suite-grid-..., the coo): KEY = the
    # progress table's suite name, so no key-to-DB map anywhere needs an entry. None = the lane has not landed its runner yet: a row
    # with no reading renders `—` there, and a MEASURED row whose runner is None REFUSES the render -- a README row says what produced it.
    'snobol4-bench-ref': 'test_snobol4_bench_suite.sh', 'icon-bench-ref': 'test_icon_bench_suite.sh', 'prolog-bench-ref': 'test_prolog_bench_suite.sh', 'pascal-bench-ref': 'test_pascal_bench_suite.sh',
    'raku-bench-ref': 'test_raku_bench_suite.sh', 'snocone-bench-ref': 'test_snocone_bench_suite.sh', 'rebus-bench-ref': 'test_rebus_bench_suite.sh',
    # ⭐ THE DEMO ROWS (Lon 2026-09-27: "all demos are also benchmarks. They are work-horse benchmarks."; ceo CEO-1312/1313; coo COO-206):
    # one runner for every language, graded in both modes against each demo's oracle ref on its sample input.
    'snobol4-demos': 'test_demos_suite.sh snobol4', 'snocone-demos': 'test_demos_suite.sh snocone', 'icon-demos': 'test_demos_suite.sh icon',
    'prolog-demos': 'test_demos_suite.sh prolog', 'scriptix-demos': 'test_demos_suite.sh scriptix'}
BENCH_SUFFIX = '-bench-ref'
def _readme_path():
    return os.path.join(str(harness_paths.scrip()), 'README.md')
def _rows_from_text(text):
    rows=[]; head=None
    for l in text.split('\n'):
        if l.startswith('#') or not l.strip(): continue
        f=l.split('\t')
        if head is None: head=f; continue
        rows.append(dict(zip(head,f)))
    return rows
def readme_block(rows, pin):
    """The generated block, markers included. Refuses (SystemExit 2) on a suite with no runner named or a language it cannot place."""
    rows = _scrip(rows)   # SCRIP's README is SCRIP's rows, from today's table and from a pinned one alike (CEO-1822)
    known = dict(README_LANGS)
    def graded(r): return bool((r.get('today_pass') or '').strip() and (r.get('today_total') or '').strip())
    for r in rows:
        if r['key'] not in README_RUNNER:
            sys.stderr.write(f"REFUSE(rc=2): SUITES.tsv row {r['key']!r} has no runner named in README_RUNNER -- a README row must say what produced it\n"); sys.exit(2)
        if README_RUNNER[r['key']] is None and graded(r):
            sys.stderr.write(f"REFUSE(rc=2): SUITES.tsv row {r['key']!r} carries a reading and README_RUNNER names no runner for it -- name the runner that wrote it, a README row must say what produced it\n"); sys.exit(2)
        if r.get('lang') not in known and r.get('lang') not in README_HIDDEN_LANGS:
            sys.stderr.write(f"REFUSE(rc=2): SUITES.tsv row {r['key']!r} has language {r.get('lang')!r}, which the README does not place\n"); sys.exit(2)
    # ⛔ THE PROSE NAMES THE BENCH ROWS ONLY WHEN THE RECORD CARRIES THEM, so a README rendered at an older pin re-renders byte-identical
    # under this code and the blocking --pinned arm cannot red in the minute between the .github and SCRIP pushes of one landing.
    bench = any(r['key'].endswith(BENCH_SUFFIX) for r in rows)
    # a .github@<commit> pin is a block rendered while the record lived in .github, and re-renders byte-identical
    src, rec = (('.github/SUITES.tsv', "`.github/SUITES.tsv` (the SUITE TABLE of `.github/SCORE.md`),") if pin.startswith('.github@')  # one-disk: not a path
               else (os.path.join(SUITES_HOME, 'SUITES.tsv'), f"`{os.path.join(SUITES_HOME, 'SUITES.tsv')}` (rendered into `.github/SCORE.md`),"))
    out = [f"{README_BEGIN} generated by .github/scripts/util_suite_banner.py --readme from {src} at {pin} -- do not edit by hand; ../harness/scripts/test_gate_readme_suite_table_matches_suites_tsv.sh holds it -->",   # one-disk: not a path
           f"Every row is generated from the leaderboard's machine record, {rec}",
           "never typed by hand: the suite's latest reading, written by that suite's own runner in the landing that measured it, in the suite banner's columns --",
           "passing / graded (a program passes only when it passes in BOTH modes), the programs excluded from the denominator (no oracle answer, or outside the",
           "oracle's dialect, each named beside its package), the percentage, the wall time of the suite's last full reading, ✅ at 100%, and the day measured. The seven rung suites are our own flat",
           ("suites with refs cut from each oracle; each Bench row is that language's benchmark programs graded as tests, a program passing "
            "when it prints its ref under all three angles (wrapper process, fixed iterations, fixed time limit); the others are vendored "
            "third-party suites. Raku is IN DEVELOPMENT: its rows stand as measured.") if bench else
           "suites with refs cut from each oracle; the others are vendored third-party suites. Raku is IN DEVELOPMENT: its rows stand as measured.",
           "",
           "| Language | Suite | passing / graded | excluded | % | wall | state | measured |",
           "|:---|:---|---:|---:|---:|---:|:---:|:---|"]
    # ⭐ THE BANNER'S COLUMNS (Lon 2026-10-25 20:2x CDT, in-chat to the ceo, verbatim: "Also, update the section reporting test suite coverage with the
    # test-suite banner information formatted nicely of course."; ceo CEO-1985): excluded, % (100% only at tp >= tt, a short suite clamped at 99% as the
    # banner clamps it), wall (the banner's wall()), state (✅ at 100%, VOID on a void reading), and a footer counting the suites at 100%. The first three
    # columns keep their shape (the gate's FAIL-ONCE arm corrupts the passing / graded cell); Snocone and Rebus stay hidden on CEO-1284.
    def pct_of(p_, t_):
        if not (p_.isdigit() and t_.isdigit()) or int(t_) == 0: return '—'
        pv = round(100.0 * int(p_) / int(t_))
        if int(p_) < int(t_) and pv >= 100: pv = 99
        return f"{pv}%"
    shown, done = 0, 0
    for lang, name in README_LANGS:
        mine = [r for r in rows if r.get('lang') == lang]
        mine = ([r for r in mine if not r['key'].endswith('-rungs') and not r['key'].endswith(BENCH_SUFFIX)]
                + [r for r in mine if r['key'].endswith('-rungs')] + [r for r in mine if r['key'].endswith(BENCH_SUFFIX)])
        label = name + (' — IN DEVELOPMENT' if lang in README_IN_DEVELOPMENT else '')
        for r in mine:
            suite = r['nick'] + (' (rungs)' if r['key'].endswith('-rungs') else '')
            p_, t_ = (r.get('today_pass') or '').strip(), (r.get('today_total') or '').strip()
            cell = f"**{p_}/{t_}**" if p_ and t_ else "not graded"
            day = (r.get('today_date') or '').strip()
            ex = (r.get('today_excluded') or '').strip() or '—'
            pc = pct_of(p_, t_)
            ok = bool(p_ and t_ and p_.isdigit() and t_.isdigit() and int(t_) > 0 and int(p_) >= int(t_))
            st = 'VOID' if (r.get('today_void') or '').strip() else ('✅' if ok else '')
            shown += 1; done += 1 if st == '✅' else 0
            out.append(f"| {label} | {suite} | {cell} | {ex} | {pc} | {wall(r) or '—'} | {st} | {('`' + day + '`') if day else ''} |")
    out.append("")
    out.append(f"**{done} of {shown} suites at 100%.**")
    out.append(README_END)
    return out
def _readme_split(path):
    L = open(path, encoding='utf-8').read().split('\n')
    b = [i for i, l in enumerate(L) if l.startswith(README_BEGIN)]
    e = [i for i, l in enumerate(L) if l == README_END]
    if len(b) != 1 or len(e) != 1 or e[0] < b[0]:
        return L, None, None
    return L, b[0], e[0]
# THE PIN IS THE RECORD'S CONTENT HASH (2026-10-09, the record left git): --readme freezes the table it rendered as
# suites-pins/SUITES.<hash>.tsv beside the record, written once and never changed, so --readme-check --pinned re-reads exactly that state.
def _pins_dir():
    return os.path.join(os.path.dirname(os.path.abspath(TSV)), 'suites-pins')
def _suites_pin():
    import hashlib
    text = open(TSV, 'rb').read(); h = hashlib.sha1(text).hexdigest()[:12]
    snap = os.path.join(_pins_dir(), f'SUITES.{h}.tsv')
    if not os.path.exists(snap):
        os.makedirs(_pins_dir(), exist_ok=True)
        fd, tmp = tempfile.mkstemp(prefix='.SUITES.', suffix='.tmp', dir=_pins_dir())
        with os.fdopen(fd, 'wb') as f: f.write(text)
        os.chmod(tmp, 0o444); os.replace(tmp, snap)
    return f'suites@{h}', None
def _pinned_text(pin):
    """The record as it stood at PIN, or (None, why)."""
    kind, h = pin.split('@', 1)
    if kind == 'suites':
        snap = os.path.join(_pins_dir(), f'SUITES.{h}.tsv')
        return (open(snap, encoding='utf-8').read(), None) if os.path.exists(snap) else (None, f"the pin {pin} has no frozen copy at {snap}")
    gh = GH
    old = subprocess.run(['git', '-C', gh, 'show', f'{h}:SUITES.tsv'], capture_output=True, text=True)
    return (old.stdout, None) if old.returncode == 0 else (None, f"the pin {pin} is not in {os.path.abspath(gh)}'s history -- pull .github, then re-check")
def readme_write(path):
    pin, why = _suites_pin()
    if not pin:
        sys.stderr.write(f"REFUSE(rc=2): --readme: {why}\n"); return 2
    L, b, e = _readme_split(path)
    if b is None:
        sys.stderr.write(f"REFUSE(rc=2): --readme: {path} needs exactly one '{README_BEGIN} ...' line and one '{README_END}' line after it\n"); return 2
    _h, rows = load()
    new = readme_block(rows, pin)
    if L[b:e + 1] == new:
        print(f"README suite table: already the render of SUITES.tsv at {pin} (0 lines changed)"); return 0
    L[b:e + 1] = new
    open(path, 'w', encoding='utf-8').write('\n'.join(L))
    print(f"README suite table: rendered {len(new) - README_HEAD_N - 1} row(s) from SUITES.tsv at {pin} into {path}"); return 0
def readme_check(path, pinned_only=False):
    """rc 0 the block is exactly its pin's render (and, unless pinned_only, every row matches SUITES.tsv now); 1 a cell differs; 2 unmeasurable."""
    if not os.path.exists(path):
        print(f"README-CHECK REFUSED(2): no README at {path}"); return 2
    L, b, e = _readme_split(path)
    if b is None:
        print(f"README-CHECK RED(1): {path} carries no single generated block ({README_BEGIN} ... {README_END}) -- the table is not generated"); return 1
    m = re.search(r'at ((?:\.github|suites)@[0-9a-f]{7,40}) ', L[b])
    if not m:
        print(f"README-CHECK RED(1): the block's first line names no suites@<hash> (or older .github@<commit>) pin -- nobody can re-read what it was rendered from"); return 1
    pin = m.group(1)
    text, why = _pinned_text(pin)
    if text is None:
        print(f"README-CHECK REFUSED(2): {why}"); return 2
    got = L[b:e + 1]
    want = readme_block(_rows_from_text(text), pin)
    bad = [(i, g, w) for i, (g, w) in enumerate(zip(got, want)) if g != w] + ([(-1, f'{len(got)} lines', f'{len(want)} lines')] if len(got) != len(want) else [])
    if bad:
        print(f"README-CHECK RED(1): {len(bad)} line(s) of the README block are not the render of SUITES.tsv at its pin {pin} -- a hand edit or a corrupted cell:")
        for i, g, w in bad[:10]: print(f"    README:   {g}\n    RENDERED: {w}")
        return 1
    print(f"README-CHECK PINNED OK: the block is exactly the render of SUITES.tsv at {pin} ({len(got) - README_HEAD_N - 1} rows)")
    if pinned_only: return 0
    _h, rows = load()
    cur = readme_block(rows, pin)
    lag = [(g, w) for g, w in zip(got[README_HEAD_N:-1], cur[README_HEAD_N:-1]) if g != w] + ([('(row count)', f'{len(got)} vs {len(cur)} lines')] if len(got) != len(cur) else [])
    if lag:
        print(f"README-CHECK RED(1): {len(lag)} README row(s) lag SUITES.tsv as it stands now (the block reads {pin}) -- regenerate: python3 .github/scripts/util_suite_banner.py --readme")   # one-disk: not a path
        for g, w in lag[:12]: print(f"    README: {g}\n    NOW:    {w}")
        return 1
    print(f"README-CHECK CURRENT OK: every README row matches SUITES.tsv as it stands now")
    return 0
# ⛔⭐ ONE WRITER AT A TIME ON THE SUITE TABLE (coo 2026-09-25, hq_pascal's report, measured twice in one sitting): a lane running
# its runners in parallel (fpc, PAT, bench and the rungs' util_score_row.py) had each one read SCORE.md, re-render its own row and
# write the whole file back -- the classic lost update: the LAST writer put back a line another runner had just set. SUITES.tsv read
# fpc 158/181 on 48d98c99c while SCORE.md's FPC line still read 156, twice, the same runner losing both times. Every read-modify-write
# of SUITES.tsv and SCORE.md now holds an exclusive flock on SUITES.tsv.lock beside the record for its whole span (on the record's own
# inode until 2026-10-09: write_tsv now replaces the record whole, a new inode per write, so the lock moved to a file that stays put) --
# and util_score_row.py holds the same lock across its write and hands S4E_SUITE_TABLE_LOCKED to the --set it runs, so
# the child does not wait on its own parent. A lock not granted within S4E_SUITE_TABLE_LOCK_S (120 s) refuses rc 2: never a hang.
def _suite_table_lock():
    if os.environ.get('S4E_SUITE_TABLE_LOCKED'): return None
    import fcntl, time
    fd=os.open(TSV+'.lock', os.O_RDWR|os.O_CREAT, 0o664); limit=time.monotonic()+float(os.environ.get('S4E_SUITE_TABLE_LOCK_S','120'))
    while True:
        try: fcntl.flock(fd, fcntl.LOCK_EX|fcntl.LOCK_NB); break
        except BlockingIOError:
            if time.monotonic()>limit:
                sys.stderr.write(f"REFUSE(rc=2): another writer has held the suite-table lock on {TSV}.lock past {os.environ.get('S4E_SUITE_TABLE_LOCK_S','120')} s -- NOTHING WAS WRITTEN; re-run when it finishes.\n"); sys.exit(2)
            time.sleep(0.05)
    os.environ['S4E_SUITE_TABLE_LOCKED']=str(os.getpid())
    return fd
def main(a):
    if '--set' in a or '--render' in a or '--open' in a or '--open-row' in a or '--set-wall' in a or '--set-run' in a or '--nick' in a: _suite_table_lock()
    if '--nick' in a:
        # ⭐ A ROW IS RENAMED IN ONE WRITE (the grader 2026-11-14; Lon 07:3x CST, in the grader's window, verbatim: "Your names are not consistent
        # PasRosetta versus RosettaSnobo. get it right."): --nick KEY NICK sets the nick of the bare row KEY and of every KEY@<engine> row, which shares
        # it (SnoRungs), under the table's lock and its history writer; the readings are untouched. Refuses a key with no bare row, a nick empty or over
        # 12 characters, or a nick another bare key holds (nick_to_key would hand that row's readings to this one). NOTHING IS WRITTEN on a refusal.
        i=a.index('--nick'); key,nick=(a[i+1:i+3]+['',''])[:2]
        head,rows=load()
        if not any(r['key']==key for r in rows) or _engine_of(key) or not nick or len(nick)>12:
            sys.stderr.write(f"REFUSE(rc=2): --nick {key!r} {nick!r}: KEY must be a bare row of {TSV} and NICK 1 to 12 characters. NOTHING WAS WRITTEN.\n"); sys.exit(2)
        other=[r['key'] for r in _scrip(rows) if r['nick']==nick and r['key']!=key]
        if other:
            sys.stderr.write(f"REFUSE(rc=2): --nick {key!r} {nick!r}: the nick is {other[0]}'s. NOTHING WAS WRITTEN.\n"); sys.exit(2)
        old=next(r['nick'] for r in rows if r['key']==key)
        if old==nick:
            print(f"--nick {key}: already {nick}; nothing written"); return
        before=open(TSV,encoding='utf-8').read()
        n=0
        for r in rows:
            if r['key']==key or r['key'].partition('@')[0]==key: r['nick']=nick; n+=1
        save(head,rows); history(head,before,rows)
        print(f"⭐ --nick {key}: {old} -> {nick} ({n} row{'s' if n!=1 else ''})")
        return
    if '--open' in a:
        # ⛔⭐ A PORT ENGINE'S ROW IS OPENED BY ITS FIRST PUBLISH (ceo CEO-1822, to hq_dotnet: "A port engine's SUITES.tsv row is created by
        # that engine's FIRST PUBLISH through util_score_row.py, the table's one writer, under its lock and history writer, never by hand").
        # --set refuses a key with no row, so from-progress opens it here first: the identity cells (nick, emoji, lang) are the bare key's,
        # because the suite is the same population graded on another engine; every reading is left empty for the --set that follows.
        i=a.index('--open'); key=a[i+1] if len(a)>i+1 else ''; src=a[i+2] if len(a)>i+2 else ''
        eng=_engine_of(key)
        if not eng or eng not in GRID_ENGINES.values() or key.partition('@')[0]!=src:
            sys.stderr.write(f"REFUSE(rc=2): --open {key!r} {src!r}: the key must be <bare key>@<port engine> ({', '.join(sorted(set(GRID_ENGINES.values())))}) and FROM_KEY its bare key. NOTHING WAS WRITTEN.\n"); sys.exit(2)
        head,rows=load()
        if any(r['key']==key for r in rows):
            print(f"--open {key}: the row is already open; nothing written"); return
        base=next((r for r in rows if r['key']==src),None)
        if base is None:
            sys.stderr.write(f"REFUSE(rc=2): --open {key}: no bare row {src} in {TSV} to take its nick, emoji and lang from. NOTHING WAS WRITTEN.\n"); sys.exit(2)
        new={h:'' for h in head}; new.update(key=key, nick=base['nick'], emoji=base['emoji'], lang=base['lang'])
        before=open(TSV,encoding='utf-8').read()
        rows.append(new); save(head,rows); history(head,before,rows)
        print(f"⭐ --open {key}: the {eng} engine's row is open in SUITES.tsv ({base['nick']}, {base['lang']}), readings empty until its --set")
        return
    if '--open-row' in a:
        # ⛔⭐ THE CYCLE OPENS THE ROW OF A SUITE IT GRADES (the grader 2026-11-13; Lon, in the grader's window, verbatim: "You need to fix the REFUSALS
        # instead of just appending errors at the end of the banner."; MEASURED that hour: six gate_cases_<lang> rows of SUITE_RUNNERS.tsv were graded
        # every lap and every row write refused "no suite key", because no row was ever opened; rows were opened by hand before, CIO-113). --open-row
        # KEY NICK EMOJI LANG appends a row with its identity cells only, for a KEY that is a master or pkg row of SUITE_RUNNERS.tsv; the first --set
        # fills every reading and first_*. Refuses any other key, a nick over 12 characters, and an open key (nothing written).
        i=a.index('--open-row'); key,nick,emoji,lang=(a[i+1:i+5]+['','','',''])[:4]
        _rn=os.path.join(os.path.dirname(os.path.abspath(__file__)),'SUITE_RUNNERS.tsv')
        _graded={f[0]:f[1] for f in (l.rstrip('\n').split('\t') for l in open(_rn,encoding='utf-8') if not l.startswith('#')) if len(f)>=5 and f[1] in ('master','pkg')}
        if key not in _graded or not nick or len(nick)>12 or not emoji or not lang:
            sys.stderr.write(f"REFUSE(rc=2): --open-row {key!r} {nick!r} {emoji!r} {lang!r}: KEY must be a master or pkg row of {_rn}, NICK 1 to 12 characters, EMOJI and LANG given. NOTHING WAS WRITTEN.\n"); sys.exit(2)
        head,rows=load()
        if any(r['key']==key for r in rows):
            print(f"--open-row {key}: the row is already open; nothing written"); return
        new={h:'' for h in head}; new.update(key=key, nick=nick, emoji=emoji, lang=lang, criterion_changed=f"{box_clock_day()}:ROW-OPENED by the cycle, {key} is a {_graded[key]} row of SUITE_RUNNERS.tsv graded every lap")
        before=open(TSV,encoding='utf-8').read()
        rows.append(new); save(head,rows); history(head,before,rows)
        print(f"⭐ --open-row {key}: the row is open in SUITES.tsv ({nick}, {lang}), readings empty until its --set")
        return
    if '--set-run' in a:
        # THE RUN'S DATE AND TIME RANGE (Lon 2026-11-11, verbatim: "The stop turn banner should display the date/time-range of the run that created the
        # row."): --set-run KEY FIRST LAST writes the UTC stamps of the oldest and the newest reading the row was assembled from into today_run_first
        # and today_run_last (the two columns are added on first use, as today_secs was) and touches no other cell; the word none for both blanks them.
        i=a.index('--set-run'); key=a[i+1] if len(a)>i+1 else ''; f1=a[i+2] if len(a)>i+2 else ''; f2=a[i+3] if len(a)>i+3 else ''
        _ts=r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}(:\d{2})?Z?$'
        if not key or not ((re.match(_ts,f1) and re.match(_ts,f2)) or (f1=='none' and f2=='none')):
            sys.stderr.write("REFUSE(rc=2): --set-run takes a suite key and two UTC stamps YYYY-MM-DDTHH:MM[:SS] (the oldest and the newest reading), or none none. NOTHING WAS WRITTEN.\n"); sys.exit(2)
        head,rows=load(); r=next((x for x in rows if x['key']==key),None)
        if r is None: sys.stderr.write(f"REFUSE(rc=2): no suite key {key} in {TSV}. NOTHING WAS WRITTEN.\n"); sys.exit(2)
        for c in ('today_run_first','today_run_last'):
            if c not in head:
                head.append(c)
                for x in rows: x.setdefault(c,'')
        n1,n2=('','') if f1=='none' else (f1.rstrip('Z'),f2.rstrip('Z'))
        if ((r.get('today_run_first') or '').strip(),(r.get('today_run_last') or '').strip())==(n1,n2):
            print(f"--set-run {key}: the Run already reads {run_range(r) or 'blank'}; nothing written"); return
        before=open(TSV,encoding='utf-8').read()
        r['today_run_first'],r['today_run_last']=n1,n2; save(head,rows)
        history(head,before,rows)
        print(f"--set-run {key}: the Run reads {run_range(r) or 'blank'}")
        return
    if '--set-wall' in a:
        # ⛔⭐ THE WALL IS THE SUM OF EACH MEMBER'S MINIMUM TIME, NEVER THE MAXIMUM AND NEVER THE CURRENT (Lon 2026-10-18, in-chat to the coo, verbatim: "Fix the
        # test-suite display banner to show the sum of minimum times of eac member. NOT the maximum nor the current."): util_score_row.py from-progress computes the
        # sum (the suite's programs and modes, each the smallest PASS seconds <db>.min holds) and this verb REPLACES today_secs with it -- a larger sum included (a
        # member gained its first minimum). ZERO SECONDS IS A MEASURE AND IS SHOWN AS 0s (Lon 2026-11-11 09:3x, in the coo's window, verbatim: "Well, stupid, 0
        # seconds is a valid measure I suppose at this scale." / "I want to see the time measurement in the stop hook banner."; MEASURED: eight suites whose
        # passing programs sum to under half a second read blank, like a suite never run); the word none blanks the cell (no member has a minimum). It
        # touches no other cell; a run's clock (--secs) never reaches the Wall again.
        i=a.index('--set-wall'); key=a[i+1] if len(a)>i+1 else ''; n=a[i+2] if len(a)>i+2 else ''
        if not key or not re.match(r'^(\d+|none)$', n):
            sys.stderr.write("REFUSE(rc=2): --set-wall takes a suite key and a whole number of seconds, or the word none. NOTHING WAS WRITTEN.\n"); sys.exit(2)
        head,rows=load(); r=next((x for x in rows if x['key']==key),None)
        if r is None: sys.stderr.write(f"REFUSE(rc=2): no suite key {key} in {TSV}. NOTHING WAS WRITTEN.\n"); sys.exit(2)
        if 'today_secs' not in head:
            head.append('today_secs')
            for x in rows: x.setdefault('today_secs','')
        new='' if n=='none' else str(int(n))
        if (r.get('today_secs') or '').strip()==new:
            print(f"--set-wall {key}: the Wall already reads {new or 'blank'}; nothing written"); return
        before=open(TSV,encoding='utf-8').read()
        r['today_secs']=new; save(head,rows)
        try:
            note=render_table(only_key=key) if not _engine_of(key) else \
                f"{key} is the {_engine_of(key)} engine's row: SUITES.tsv set; SCORE.md's suite table is SCRIP's and carries no port row (CEO-1822)"
        except Exception as ex:
            write_tsv(before)
            sys.stderr.write(f"REFUSE(rc=2): the Wall was NOT set. Rendering SCORE.md raised {type(ex).__name__}: {ex}. SUITES.tsv has been RESTORED.\n"); sys.exit(2)
        history(head,before,rows)
        print(f"--set-wall {key}: the Wall reads {(new + ' s') if new else 'blank'}" + (f"\n{note}" if note else ""))
        return
    if '--add-mode-columns' in a:
        # ⭐ THE ONE-TIME SCHEMA STEP OF CTO-482 (Lon 2026-11-04: "show both mode 3 and mode 4 numbers seperately."): today_m3_pass and today_m4_pass join the
        # record empty, under the table lock and the history writer; every later --set fills the one row it writes. Idempotent; a table that has them is untouched.
        _suite_table_lock()
        head,rows=load()
        if 'today_m3_pass' in head and 'today_m4_pass' in head:
            print(f"--add-mode-columns: {TSV} already carries today_m3_pass and today_m4_pass; nothing written"); return
        before=open(TSV,encoding='utf-8').read()
        for c in ('today_m3_pass','today_m4_pass'):
            if c not in head:
                head.append(c)
                for x in rows: x.setdefault(c,'')
        save(head,rows); history(head,before,rows)
        print(f"--add-mode-columns: today_m3_pass and today_m4_pass added to {TSV} ({len(rows)} rows, every cell empty until its row's next from-progress write)"); return
    if '--readme' in a:
        j=a.index('--readme'); path=a[j+1] if len(a)>j+1 and not a[j+1].startswith('-') else _readme_path()
        sys.exit(readme_write(path))
    if '--readme-check' in a:
        j=a.index('--readme-check'); path=a[j+1] if len(a)>j+1 and not a[j+1].startswith('-') else _readme_path()
        sys.exit(readme_check(path, pinned_only=('--pinned' in a)))
    if '--set' in a:
        # ⛔ THE CRITERION STAMP (coo 2026-09-16, CEO-785; row instruments-util-score-row-cannot-stamp-a-criterion-change-so-
        # every-denominator-move-is-hand-edited-or-unstamped): `--criterion-changed '<YYYY-MM-DD>:<reason in words>'` APPENDS
        # to column 12 (criterion_changed) with the ' | ' separator the column already uses, and a --set whose TOTAL differs
        # from the row's previous today_total REFUSES rc=2 without it -- a denominator move without its stamp is the
        # dishonest-denominator class of CEO-546, and until today the only way to stamp one was a hand edit (the coo's Budne
        # stamp of 09-13, .github 11de13f9) or none at all (hq_pascal's PAT instrument change, SCRIP fe37edc72, 284 -> 296).
        stamp=None
        if '--criterion-changed' in a:
            j=a.index('--criterion-changed')
            if len(a)<=j+1 or not re.match(r'^\d{4}-\d{2}-\d{2}:\S', a[j+1]):
                sys.stderr.write("REFUSE(rc=2): --criterion-changed takes '<YYYY-MM-DD>:<reason in words>' (the day the criterion moved, a colon, then why)\n"); sys.exit(2)
            stamp=a[j+1]; a=a[:j]+a[j+2:]
        # ⭐ --excluded N (Lon 2026-09-26, CEO-1286): the programs NOT IN THE SPITBOL DIALECT this row's TOTAL leaves out, written to the
        # today_excluded column and shown as EXCLUDED=N in the suite table and as Excl in the grid; the column is added to the record on
        # first use so an older TSV still loads.
        excluded=None
        if '--excluded' in a:
            j=a.index('--excluded')
            if len(a)<=j+1 or not re.match(r'^\d+$', a[j+1]):
                sys.stderr.write("REFUSE(rc=2): --excluded takes a count\n"); sys.exit(2)
            excluded=a[j+1]; a=a[:j]+a[j+2:]
        # ⭐ --secs N (Lon 2026-10-08, in-chat to the ceo: "List in a grid the total time for each test suite to run."; CEO-1562): the run's
        # wall clock in seconds, from the runner's own start (util_score_row.py reads S4E_RUN_T0, stamped by one_runner_guard) to its row
        # write, written to the today_secs column (added on first use, as today_excluded was) and shown as WALL= and in the grid's Wall column.
        # ⭐ --m3 N --m4 N (Lon 2026-11-04: "show both mode 3 and mode 4 numbers seperately."; CTO-482): the reading's pass count in each mode alone,
        # over the row's own population, written to today_m3_pass and today_m4_pass (columns added on first use) and shown as the grid's M3 and M4.
        # A --set that carries neither is a reading with no per-mode count: it CLEARS both cells unless it re-sets the same reading, so a stale per-mode
        # number never sits beside a new Pass.
        pm={}
        for _mo in ('--m3','--m4'):
            if _mo in a:
                j=a.index(_mo)
                if len(a)<=j+1 or not re.match(r'^\d+$', a[j+1]):
                    sys.stderr.write(f"REFUSE(rc=2): {_mo} takes a count\n"); sys.exit(2)
                pm[_mo[2:]]=a[j+1]; a=a[:j]+a[j+2:]
        secs=None
        if '--secs' in a:
            j=a.index('--secs')
            if len(a)<=j+1 or not re.match(r'^\d+$', a[j+1]):
                sys.stderr.write("REFUSE(rc=2): --secs takes a whole number of seconds\n"); sys.exit(2)
            secs=a[j+1]; a=a[:j]+a[j+2:]
        # ⛔ --void '<reason>' (ceo to the coo 2026-10-15, on the Logtalk 3190/3552 at 52f822b69: "Mark the SUITES row's 3190 reading as
        # load-voided wherever the table can say so, so nobody quotes it as a regression."): the reading stands as written, and the today_void
        # column (added on first use) says why it is no reading -- the grid's State reads VOID and SCORE.md's state cell names the reason. A
        # --set without --void is a new reading and clears it, so a void never outlives the reading it voids; the same pass, total and tree re-set keeps it.
        void=''
        if '--void' in a:
            j=a.index('--void')
            if len(a)<=j+1 or not a[j+1].strip() or a[j+1].startswith('-'):
                sys.stderr.write("REFUSE(rc=2): --void takes the reason in words\n"); sys.exit(2)
            void=a[j+1].replace('\t',' ').replace('|','·'); a=a[:j]+a[j+2:]
        i=a.index('--set'); key,p,t=a[i+1],a[i+2],a[i+3]; date=a[i+4] if len(a)>i+4 and not a[i+4].startswith('-') else box_clock_day().isoformat(); tree=a[i+5] if len(a)>i+5 and not a[i+5].startswith('-') else None
        # ⛔ A READING CANNOT BE GRADED TOMORROW (CEO-1229): a DATE later than the box-clock day is refused before a byte moves, naming
        # the key, the date and the day, so the writer that computed its day in another zone is found by the refusal on its next run.
        try:
            _dd = d(date)
        except ValueError:
            sys.stderr.write(f"REFUSE(rc=2): {key}'s DATE {date!r} is not YYYY-MM-DD. NOTHING WAS WRITTEN.\n"); sys.exit(2)
        _bc = box_clock_day()
        if _dd > _bc:
            sys.stderr.write(f"REFUSE(rc=2): {key}'s DATE {date} is later than the box-clock day {_bc} -- a reading cannot be graded "
                             f"tomorrow; the writer computed its day in another zone (UTC past 19:00 CDT is the measured case). The "
                             f"table's dates are box-clock days. NOTHING WAS WRITTEN.\n"); sys.exit(2)
        head,rows=load(); r=next((x for x in rows if x['key']==key),None)
        # ⛔ A REFUSAL EXITS 2 (coo 2026-09-23): sys.exit(<a string>) exits 1, so this refusal and the render refusal below printed
        # "REFUSE(rc=2)" while returning a RED's code -- measured on the benchmark rows' first write, which is how it was noticed.
        if r is None: sys.stderr.write(f"REFUSE(rc=2): no suite key {key} in {TSV}. NOTHING WAS WRITTEN.\n"); sys.exit(2)
        prev=(r.get('today_total') or '').strip()
        if prev and str(t).strip()!=prev and not stamp:
            sys.stderr.write(f"REFUSE(rc=2): {key}'s denominator moves {prev} -> {t} and no --criterion-changed '<YYYY-MM-DD>:<reason>' names why. "
                             f"A denominator move without its stamp is the dishonest-denominator class (CEO-546, CEO-749): pass the stamp, or keep the total. "
                             f"NOTHING WAS WRITTEN.\n"); sys.exit(2)
        _same_reading=((r.get('today_pass') or '').strip(),(r.get('today_total') or '').strip(),(r.get('tree') or '').strip())==(str(p).strip(),str(t).strip(),(tree or (r.get('tree') or '')).strip())
        r['today_pass'],r['today_total'],r['today_date']=p,t,date
        # ⛔ A ROW'S FIRST READING IS ALSO ITS first_* (coo 2026-09-23, row instruments-benchmarks-enter-the-suite-grid-...): a row that
        # entered the table empty had no first_pass, so eta() read int('') and the render inside this call raised -- the lane's FIRST
        # write would have been refused and the TSV restored. first_* is "the first graded reading on file"; the write that is the
        # first reading fills it, once, and never again (an existing first_* is never re-baselined).
        if not all((r.get(c) or '').strip() for c in ('first_date','first_pass','first_total')):
            r['first_date'],r['first_pass'],r['first_total']=date,p,t
        if tree: r['tree']=tree
        if excluded is not None:
            if 'today_excluded' not in head:
                head.append('today_excluded')
                for x in rows: x.setdefault('today_excluded','')
            r['today_excluded']=excluded
        # ⛔ THE COLUMNS ARE NEVER ADDED BY A ROW WRITE (the port-engine gate, first proof of CTO-482): growing the header rewrites EVERY row's line, and a
        # port's publish must leave SCRIP's row untouched. --add-mode-columns adds them to a table once; a table without them records no per-mode count.
        if 'today_m3_pass' in head and 'today_m4_pass' in head:
            for m in ('m3','m4'):
                r['today_'+m+'_pass']=pm.get(m, (r.get('today_'+m+'_pass') or '') if (_same_reading and not pm) else '')
        elif pm: print(f"--set {key}: per-mode counts not recorded -- {TSV} has no today_m3_pass/today_m4_pass columns (util_suite_banner.py --add-mode-columns adds them once)")
        if void or (r.get('today_void') or '').strip():
            if 'today_void' not in head:
                head.append('today_void')
                for x in rows: x.setdefault('today_void','')
            # the SAME reading re-assembled (the pass, the total and the tree unchanged: from-progress over no new readings, 10-17 22:26 cleared
            # Logtalk's 3190 void this way) is not a new reading, so its void stands; any changed number or tree is a new reading and clears it
            r['today_void']=void or ((r.get('today_void') or '') if _same_reading else '')
        if secs is not None:
            if 'today_secs' not in head:
                head.append('today_secs')
                for x in rows: x.setdefault('today_secs','')
            # ⛔ THE WALL IS THE MINIMUM (Lon 2026-10-18, in-chat to the coo: "That column is meant to represent the MINIMUM amount of time to run the test."): a
            # runner writes its own run's clock, a loaded pass or a timeout makes it large, so a new value replaces the old only when it is SMALLER, and only
            # while the denominator is the one the old value timed (a moved total is a new population and starts again)
            _o=(r.get('today_secs') or '').strip()
            if _o.isdigit() and int(_o)>0 and str(secs).isdigit() and prev and str(t).strip()==prev:
                # a ZERO is "no reading of seconds" (a ledger with nothing for this suite, a runner that did not time itself), never a minimum
                r['today_secs']=str(min(int(_o),int(secs))) if int(secs)>0 else _o
            else:
                r['today_secs']=secs
        if stamp:
            cur=(r.get('criterion_changed') or '').strip()
            # ⛔ THE SAME STAMP TWICE SAYS NOTHING NEW (the coo 2026-10-10): a runner that names its standing move on every write (INRIA's
            # 2026-09-23 file_manip stamp, test_prolog_inria_suite.sh) appended it once per pass, and the inria cell carried the one
            # sentence 28 times. A stamp equal to the one before it is collapsed into it, so the cell keeps one copy and heals on its
            # next stamped write; the read-back (util_score_row.py: the cell ends with the stamp forwarded) holds, and a different
            # stamp still appends.
            parts=[x for x in cur.split(' | ') if x] if cur else []
            parts=[x for i,x in enumerate(parts) if i==0 or x!=parts[i-1]]
            if not parts or parts[-1]!=stamp: parts.append(stamp)
            r['criterion_changed']=' | '.join(parts)
        before=open(TSV,encoding='utf-8').read()
        save(head,rows)
        try:
            note=render_table(only_key=key) if not _engine_of(key) else \
                f"⭐ {key} is the {_engine_of(key)} engine's row: SUITES.tsv set; SCORE.md's suite table is SCRIP's and carries no port row (CEO-1822)"
        except Exception as ex:
            write_tsv(before)      # ⛔ the two sites move together or not at all
            sys.stderr.write(f"REFUSE(rc=2): the row was NOT set. Rendering SCORE.md raised {type(ex).__name__}: {ex}. "
                             f"SUITES.tsv has been RESTORED to what it held before this call, because a written TSV "
                             f"beside an unwritten SCORE.md is the split state every board reader then has to guess at.\n"); sys.exit(2)
        history(head,before,rows)
        print(note)
    if '--check' in a: sys.exit(check_table())
    if '--render' in a:
        # ⛔ --render REWRITES EVERY ROW FROM THE TSV: a different act from verifying, so it is asked for by name -- --all-rows,
        # or scoped to the one row the caller measured with --only KEY (coo 2026-09-16, hq_raku's finding).
        if '--only' in a:
            j=a.index('--only'); k=a[j+1] if len(a)>j+1 else ''
            head,rows=load()
            if k not in {r['key'] for r in rows}: sys.stderr.write(f"REFUSE(rc=2): --only {k!r} is no SUITES.tsv key\n"); sys.exit(2)
            print(render_table(only_key=k)); return
        if '--all-rows' not in a:
            sys.stderr.write("REFUSE(rc=2): --render rewrites EVERY suite-table row of SCORE.md from SUITES.tsv, rows you never measured included. "
                             "To verify, run --check (writes nothing). To rewrite one row you measured: --render --only <key>. To rewrite them all, say so: --render --all-rows. NOTHING WAS WRITTEN.\n"); sys.exit(2)
        print(render_table()); return
    if '--md' in a: md(); return
    if '--engines' in a: engines(plain='--plain' in a); return
    if '--single' in a:
        grid(plain='--plain' in a)
    else:   # the coo 2026-11-04 (Lon: "no reason to keep the single sided version"): the printed grid is the DOUBLE-SIDED banner by default, banner_compact.py beside this script; --single keeps the one-row-per-suite grid for a reader that parses it
        import io, contextlib, subprocess
        _buf = io.StringIO()
        with contextlib.redirect_stdout(_buf):
            grid(plain='--plain' in a)
        _bc = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'banner_compact.py')
        _r = subprocess.run([sys.executable, '-I', _bc], input=_buf.getvalue(), capture_output=True, text=True) if os.path.isfile(_bc) else None
        sys.stdout.write(_r.stdout if _r is not None and _r.returncode == 0 and _r.stdout.strip() else _buf.getvalue())
    return
# ⛔⭐ AN IMPORT MUST NEVER BE A COMMAND (hq_B 2026-09-13). This module is the tree's ONE display-width
# authority -- dw() -- so any consumer that wants it must import this file; util_fit_columns.py does exactly
# that. A bare `main(sys.argv[1:])` at module scope RUNS ON IMPORT WITH THE IMPORTER'S OWN ARGV, so a caller
# whose command line happens to carry --md or --render would print a table by importing a width helper, and
# --set would WRITE SUITES.tsv. ⚠ STATED HONESTLY: that is LATENT, not live -- today's only importer passes
# a bare width, and the 3.1-SECOND import stall this guard was originally measured against died with
# banner(), which Lon deleted. What is left is a loaded gun with nobody currently in front of it, and the
# guard costs one line. The CLI is unchanged: run as a script, __name__ IS "__main__" and main() still runs.
if __name__ == "__main__":
    main(sys.argv[1:])
