#!/usr/bin/env python3
# util_donewhen_rc_census.py -- THE ONE AUTHORITY for "can this DONE-WHEN tell a refusal from a red".
# hq_B 2026-09-13, on the officer audit FINDING-2026-09-11-officer-a-done-when-that-captures-a-board-turns-could-not-
# measure-into-failed.md. Two classes, both found by that audit, both cured in place by this script's --cure.
# CLASS A -- a DONE-WHEN captures a runner's output and never consults that runner's rc. Under ONE RUNNER, ONE
#   BOARD a runner answers any seat but the coo with rc=2 REFUSE; the criterion captures that TEXT, the marker
#   grep misses, and a refusal degrades into rc=1 FAILED. The row is fine and the audit reads it as red.
# CLASS B -- a DONE-WHEN pins a SEAT ROOT in the text the bus actually runs, so the criterion grades whichever
#   tree that seat happens to hold rather than origin HEAD. TWO SPELLINGS, one class:
#   (i) the S4E_HOME FALLBACK (${S4E_HOME:-/home/claude_cfo}) -- `s4e_msg.sh done` exports S4E_HOME so the
#       fallback never fires there; it fires exactly when a seat runs the criterion BY HAND to audit it, and
#       then it silently grades ANOTHER SEAT'S TREE and can print PASS.
#   (ii) the BARE form (`cd /home/claude_cto/SCRIP && ...`, `bash /home/claude_T/harness/scripts/x.sh`) -- coo
#       2026-09-23 on R-1163, RULES.md THE INSTRUMENT LAWS thirty-fourth batch clause 3: a criterion that
#       names a seat root names a tree. It has NO fallback at all, so it does not even degrade.
#   ⛔ 28 of the 46 found at that landing pin a root that HAS NOT EXISTED SINCE R-767 (the lettered
#   /home/claude_{B,C,I,P,R,S,T,U} and the numbered /home/claude01..20). Those grade no tree whatever, and the
#   direction they fail in is NOT always visible: `rung-gate-false-green-audit`'s criterion is
#   `! grep -qi ... /home/claude10/.github/FINDING-...md`, and grep's rc=2 on a missing file INVERTS to rc=0 --
#   a row that closes DONE on an evidence file that has not existed for a month. Measured, not reasoned.
# +-- WHAT THIS DOES NOT CALL A DEFECT, WHICH IS THE HALF THAT TOOK THE WORK -------------------------------+
# A capture that never looks at rc but REFUSES rc=2 when the expected marker is absent can already tell "never
# ran" from "ran and red" -- it grades a marker instead of a status, which is a different correct answer, not a
# worse one. 50 criteria are that shape. Calling them defective and "curing" them would be this row's own
# lesson inverted: an instrument answering a narrower question than it thinks it asked. They are counted and
# printed as HONEST and never rewritten.
# +-- AND THE TRAP INSIDE THE CURE --------------------------------------------------------------------------+
# 19 of the defective captures PIPE the runner into grep/tail. For those, appending `rc=$?` reads THE PIPE's
# status, not the runner's -- the $?-after-a-pipeline trap, i.e. the cure would wear the defect's own shape.
# Those are restructured instead: capture raw, check rc, THEN filter.
# The inserted guard is a BRACE GROUP ending in `[ "$_dwrc" = 0 ]` so a capture sitting inside an `&&` chain
# keeps its short-circuit exactly; appending `; _dwrc=$?` bare would silently break the chain.
# ⛔ IT NEVER EXECUTES A CRITERION and never expands one. Static text only.
import re, os, glob, sys, json, subprocess
TEXTTOOL = {'grep','egrep','fgrep','ls','sed','awk','cat','wc','find','head','tail','nm','git','printf',
            'echo','mktemp','date','stat','sort','uniq','cut','tr','basename','dirname','md5sum','readlink',
            'objdump','readelf','cmp','diff','jq','realpath','pwd','id','comm','xargs','true','false'}
RUNNER = re.compile(r'(?:^|[\s;&|(])(?:bash|sh|python3|\./|\$\{?[A-Za-z_])[^;|&]*?[\w/.$}"\']+\.(sh|py)\b')
CAP = re.compile(r'([A-Za-z_][A-Za-z0-9_]*)=\$\(')
GUARD = ('_dwrc=$?; if [ "$_dwrc" = 2 ]; then '
         'echo "REFUSE(2): the runner could not measure (rc=2) -- this is not a red"; exit 2; fi; ')
# ⭐ PREMISE-WHEN ends the criterion block (the cio's census cure, 2026-11-07): the block ran past it, so a rewrite and its
# receipt carried a copy of the premise. The other baton fields end it too.
HEADS = r'^(GOAL|LINKS|RANK|SCOPE|LEDGER|OWNER|BLOCKED-ON|FINDING|MINTED BY|DONE-WHEN|PREMISE-WHEN|STATE|QUEUE-JOB|TOUCHES|SKILLS|## )'
def block(text):
    m = re.search(r'^DONE-WHEN:', text, re.M)
    if not m: return None
    s = m.end()
    nxt = re.search(HEADS, text[s:], re.M)
    return (s, s + nxt.start()) if nxt else (s, len(text))
def first_word(inner):
    t = inner.strip()
    for _ in range(3):
        t = re.sub(r'^(?:[A-Za-z_][A-Za-z0-9_]*=(?:"[^"]*"|\'[^\']*\'|\S*)\s+)+', '', t)
        t = re.sub(r'^timeout\s+\S+\s+', '', t)
        t = re.sub(r'^(?:cd\s+(?:"[^"]*"|\S+)\s*(?:\|\|\s*\S+\s*)?&&\s*)+', '', t)
    return t.split()[0] if t.split() else ''
def top_pipe(s):
    d = 0; q = None
    for i, c in enumerate(s):
        if q:
            if c == q: q = None
            continue
        if c in '"\'': q = c
        elif c in '([{': d += 1
        elif c in ')]}': d -= 1
        elif c == '|' and d == 0:
            return -1 if (i + 1 < len(s) and s[i+1] == '|') else i
    return -1
def spans(s):
    out = []
    for m in CAP.finditer(s):
        i = m.end(); depth = 1
        while i < len(s) and depth:
            if s[i] == '(': depth += 1
            elif s[i] == ')': depth -= 1
            i += 1
        out.append((m.group(1), m.start(), m.end(), i))
    return out
def scan(seg):
    """-> (defective_edits, honest_count).  edit = (start, end, replacement, piped)"""
    edits, honest = [], 0
    for var, a_start, i_start, end in spans(seg):
        inner = seg[i_start:end-1]
        fw = first_word(inner)
        if fw.split('/')[-1] in TEXTTOOL or fw in TEXTTOOL: continue
        if not RUNNER.search(inner): continue
        if not re.search(r'[\$"\{]' + re.escape(var) + r'\b', seg[end:]): continue
        tail = seg[end:end+120]
        rc_checked = bool(re.match(r'\s*;?\s*(rc|RC|r|_rc|st|status|_dwrc)=\$\?', tail)) or bool(re.match(r'\s*\|\|', tail))
        pi = top_pipe(inner); piped = pi >= 0
        refuses = False
        for g in re.finditer(r'[\$"\{]' + re.escape(var) + r'\b', seg[end:]):
            sub = seg[end+g.start(): end+g.start()+260]
            if re.search(r'\|\|\s*\{[^}]*exit\s+2', sub) or re.search(r'&&\s*\{[^}]*exit\s+2', sub):
                refuses = True; break
        if (rc_checked and not piped) or refuses:
            if refuses and not rc_checked: honest += 1
            continue
        if piped:
            runner, filt = inner[:pi].strip(), inner[pi+1:].strip()
            repl = '{ _dwraw=$(' + runner + '); ' + GUARD + var + '=$(printf "%s\\n" "$_dwraw" | ' + filt + '); }'
        else:
            repl = '{ ' + var + '=$(' + inner + '); ' + GUARD + '[ "$_dwrc" = 0 ]; }'
        edits.append((a_start, end, repl, piped))
    # ⛔ NESTED/OVERLAPPING CAPTURES CORRUPT A REVERSE-ORDER REWRITE. `VAR=$(` matches inside an outer
    # capture too, and applying both edits shifts the other's offsets -- measured: it spliced a guard into
    # the middle of `g=$(cd "$R/S` and produced two unparseable criteria. Keep the OUTERMOST of any
    # overlapping pair and drop the rest; a criterion that needs two guards gets the one that encloses.
    kept = []
    for ed in sorted(edits, key=lambda x: (x[0], -x[1])):
        if all(ed[1] <= k[0] or ed[0] >= k[1] for k in kept):
            kept.append(ed)
    return kept, honest
BARE_ROOT = re.compile(r'/home/claude(?:_[A-Za-z0-9]+|[0-9]{2})')
FALLBACK  = re.compile(r'\$\{S4E_HOME:-[^}]*\}')
_EOF_ERR  = re.compile(r'here-document.*delimited by end-of-file'
                       r'|unexpected EOF while looking for matching'
                       r'|syntax error: unexpected end of file')
def _incomplete(t):
    """s4e_msg.sh's OWN discriminator (s4e_donewhen_incomplete), same two clauses in the same order."""
    if re.search(r'(\\|&&|\|\||\|)\s*$', t.rstrip()): return True
    try:
        pr = subprocess.run(['bash', '-n', '/dev/stdin'], input=t,
                            capture_output=True, text=True, timeout=20)
    except Exception:
        return False
    return bool(_EOF_ERR.search(pr.stderr))
def exec_span(seg):
    """(start, end) of the text the BUS WILL ACTUALLY RUN, inside the DONE-WHEN field block.
    ⛔⭐ THIS IS THE HALF THAT DECIDES WHETHER A BARE SEAT ROOT IS A DEFECT AT ALL, and it is measured:
    s4e_msg.sh's s4e_field_criterion_text runs the FIRST LINE and reads the rest of the block ONLY when
    that first line is INCOMPLETE SHELL -- everything else under it is PROSE ANNOTATION the shell never
    sees, and the live convention puts exactly that there ("⛔ DONE-WHEN REWRITTEN 2026-08-24: the line
    above used to be ..."). Scanning the whole block instead would have flagged SIX batons on 2026-09-23,
    TWO of which are annotations RECORDING that the pin was already cured -- i.e. this census would have
    called a cure receipt a defect and then rewritten the receipt. That is this file's own header lesson
    ("what this does not call a defect") one class further down.
    ⛔ A SECOND READER OF A RULE THAT LIVES IN ANOTHER FILE GOES STALE SILENTLY, which is why
    test_gate_baton_donewhen_reads_its_runner_rc.sh arm D re-derives BOTH readings over the live tree and
    REDS on any disagreement, rather than trusting this one to stay right."""
    nl = seg.find('\n')
    if nl < 0: return (0, len(seg))
    return (0, len(seg)) if _incomplete(seg[:nl]) else (0, nl)
def live_ranges(s):
    """Ranges of s the shell EXECUTES: everything outside an UNQUOTED '#' comment. A seat root inside a
    trailing comment is documentation, not a tree pin -- one live baton
    (util-progress-flips-names-every-lost-since-base-program) carries exactly that and is not a defect."""
    out = []; q = None; i = 0; start = 0
    while i < len(s):
        c = s[i]
        if q:
            if c == q: q = None
        elif c in '"\'':
            q = c
        elif c == '#' and (i == 0 or s[i-1] in ' \t\n;&|('):
            j = s.find('\n', i); out.append((start, i))
            if j < 0: return out
            start = j; i = j
        i += 1
    out.append((start, len(s)))
    return out
DELIBERATE, RULING, REFUSED, MULTI_DONE = [], [], [], []
# the two unicon batons also invert their PREMISE-WHEN onto the same ROSTER loop (the coo's condition, 2026-11-07)
PREMISE_INVERSE = {'unicon-skill-reference-distilled-from-the-unicon-documentation-langref-diffs-classes-large-string-thread-system-struct-lon-2026-11-04', 'unicon-the-unicon-skill-a-skill-of-its-own-for-the-superset-markers-oracle-classes-packages-threads-unitests-lon-2026-11-04'}
# ⭐ THE THREE MULTI-ROOT BATONS (the cio's ruling, relayed by the coo 2026-11-07): each criterion's pinned roots become a loop
# over the seat roots of the LIVE ROSTER (the ROSTER line of the live MODE), never a single root. Reviewed exact replacements,
# keyed by baton; each fragment must occur exactly once in the live criterion or the baton is refused, not guessed at.
MULTIROOT = {
    'seat-digest-dead-map-sweep-and-computed-map': [('for r in /home/claude03 /home/claude04 /home/claude05 /home/claude06 /home/claude07 /home/claude08 /home/claude09 /home/claude10 /home/claude11 /home/claude12 /home/claude13 /home/claude14 /home/claude15 /home/claude16; do', 'for r in $(grep "^ROSTER:" /home/resources/postoffice/MODE | cut -d" " -f2- | tr " " "\\n" | sed "s#^#/home/claude_#"); do')],
    'unicon-skill-reference-distilled-from-the-unicon-documentation-langref-diffs-classes-large-string-thread-system-struct-lon-2026-11-04': [('&& [ -f /home/claude_unicon/.claude/skills/unicon/reference.md ] && [ -f /home/claude_icon/.claude/skills/unicon/reference.md ]', '&& for r in $(grep "^ROSTER:" /home/resources/postoffice/MODE | cut -d" " -f2- | tr " " "\\n" | sed "s#^#/home/claude_#"); do [ -f "$r/.claude/skills/unicon/reference.md" ] || exit 1; done')],
    'unicon-the-unicon-skill-a-skill-of-its-own-for-the-superset-markers-oracle-classes-packages-threads-unitests-lon-2026-11-04': [('&& [ -f /home/claude_unicon/.claude/skills/unicon/SKILL.md ] && [ -f /home/claude_icon/.claude/skills/unicon/SKILL.md ] && grep', '&& for r in $(grep "^ROSTER:" /home/resources/postoffice/MODE | cut -d" " -f2- | tr " " "\\n" | sed "s#^#/home/claude_#"); do [ -f "$r/.claude/skills/unicon/SKILL.md" ] || exit 1; done && grep')],
}
def _parses(t):
    try:
        return subprocess.run(['bash', '-n', '/dev/stdin'], input=t, capture_output=True, text=True, timeout=20).returncode == 0
    except Exception:
        return None
def bare_roots(seg):
    """-> (roots, cure_spans) over the EXECUTED, UNCOMMENTED text only.
    ⭐ S4E_DWRC_FAIL_ONCE=1 restores the PRE-2026-09-23 reader (fallback form only, bare form invisible) so
    the gate can PROVE its bare arms are load-bearing instead of asserting it -- an arm that has never been
    seen to go red reads as 'there was never a bug here'. The ${S4E_HOME:-...} form is NOT
    counted here -- it is the older class-B half and is detected by classB_fallback below."""
    if os.environ.get('S4E_DWRC_FAIL_ONCE') == '1': return [], []
    a, b = exec_span(seg)
    roots, spans_out = [], []
    for (ls, le) in live_ranges(seg[a:b]):
        chunk = seg[a+ls:a+le]
        for m in BARE_ROOT.finditer(chunk):
            if any(f.start() <= m.start() < f.end() for f in FALLBACK.finditer(chunk)): continue
            # the coo's own loop files are DELIBERATE absolute pins (the coo's ruling, 2026-11-07): counted, never a seat-root defect
            if chunk[m.end():].startswith('/.scratch/'): DELIBERATE.append(m.group(0)); continue
            roots.append(m.group(0)); spans_out.append((a+ls+m.start(), a+ls+m.end()))
    return roots, spans_out
def classB_fallback(seg):
    return [m.group(1).strip() for m in re.finditer(r'\$\{S4E_HOME:-([^}]*)\}', seg)
            if re.match(r'^/home/claude', m.group(1).strip())]
QUEUE = os.environ.get('S4E_QUEUE', '/home/resources/postoffice/QUEUE.tsv')
CLAIMS = os.environ.get('S4E_CLAIMS', '/home/resources/postoffice/claims')
def _live_claimed(base):
    # a baton whose row a seat holds RIGHT NOW (CLAIMED, ASSIGNED, RUNNING or MEASURING) is never rewritten under it
    try:
        for ln in open(QUEUE, encoding='utf-8', errors='replace').read().splitlines():
            f = ln.split('\t')
            if len(f) >= 4 and f[1] == base and re.match(r'(CLAIMED:|ASSIGNED:|RUNNING|MEASURING:)', f[3]): return True
    except OSError:
        return True
    c = os.path.join(CLAIMS, base + '.claim')
    return os.path.isfile(c) and 'DONE' not in open(c, encoding='utf-8', errors='replace').read().split()
def main():
    # ⛔ AN UNRECOGNISED ARGUMENT IS A REFUSAL, NEVER A SILENT NO-OP (coo 2026-09-19, row
    # instrument-the-nineteen-non-gc-blocking-arms). Every flag here is read as `'--x' in sys.argv`, so
    # before this check a misspelled or invented flag was simply ignored -- and this tool's --cure
    # REWRITES LIVE BATON FILES. This seat ran `--cure --tasks-dir <a copy>` intending to work on a copy,
    # exactly as the COO-114 discipline requires; --tasks-dir is not a flag this tool has, it was
    # swallowed, and the LIVE tasks tree was rewritten instead. No harm done that time -- the rewrite was
    # the designated cure and it was verified -- but an instrument that accepts an instruction it does not
    # implement, and then reports success, is THE recurring failure the INSTRUMENT LAWS name.
    # The population is scoped by the S4E_TASKS environment variable, not by a flag; that is said in the
    # refusal so the next reader does not have to find it the way this one did.
    _known = {'--cure', '--json', '--list', '--help', '-h'}
    _unknown = [a for a in sys.argv[1:] if a not in _known]
    if _unknown:
        print("REFUSE(2): unrecognised argument(s): %s" % " ".join(_unknown))
        print("           known flags: --cure --json --list")
        print("           to scope the population (e.g. to a COPY before a --cure), set S4E_TASKS=<dir>;")
        print("           there is no --tasks-dir. Refusing rather than ignoring it: --cure rewrites live batons.")
        return 2
    ap_cure = '--cure' in sys.argv
    tasks = os.environ.get('S4E_TASKS', '/home/resources/postoffice/tasks')
    if not os.path.isdir(tasks):
        print(f"REFUSE(2): tasks directory unreachable at {tasks} -- a census that cannot see its population must not print 0")
        return 2
    files = sorted(glob.glob(os.path.join(tasks, "*.task.md")))
    if not files:
        print(f"REFUSE(2): no *.task.md under {tasks} -- cannot measure")
        return 2
    A, B, SUBJ, honest, touched, SKIPPED = [], [], [], 0, 0, []
    if ap_cure and not os.path.isfile(QUEUE):
        print(f"REFUSE(2): the queue {QUEUE} is unreadable -- --cure cannot tell a live claim from a free baton; nothing written")
        return 2
    for p in files:
        raw = open(p, encoding='utf-8', errors='replace').read()
        br = block(raw)
        if not br: continue
        s, e = br; seg = raw[s:e]; orig = seg
        base = os.path.basename(p)[:-len('.task.md')]
        fbs = classB_fallback(seg)
        brs, bspans = bare_roots(seg)
        uniq = sorted(set(brs))
        # ⛔⭐ THE SUBJECT EXEMPTION, AND IT IS NAMED RATHER THAN SILENT. A criterion that sweeps the
        # ROSTER -- `for r in /home/claude03 /home/claude04 ... ; do [ -r "$r/CLAUDE.md" ] || continue`
        # -- is ASKING A QUESTION ABOUT those roots, not standing in one, and $S4E_HOME would DELETE the
        # test. One baton on the live tree is that shape (seat-digest-dead-map-sweep-and-computed-map, 14
        # roots); every other names exactly ONE. The threshold is printed with its population so a reader
        # can challenge it, and a subject baton is COUNTED AND NAMED, never rewritten -- the same
        # treatment this file already gives the 50 honest class-A captures.
        # ⛔ THE SUBJECT EXEMPTION IS RETIRED (the coo's ruling, 2026-11-07, the cio's GO): a criterion that pins two
        # or more seat roots pins them exactly as a one-root criterion does, and a sweep over pinned roots grades
        # whichever trees the seat holds. Counted as class B like any other; the B-SUBJECT line stays at 0.
        subject = len(uniq) >= 2
        if subject: SUBJ.append({'baton': base, 'roots': uniq})
        if fbs or uniq:
            B.append({'baton': base, 'fallbacks': sorted(set(fbs)), 'bare': uniq,
                      'dead': sorted(r for r in uniq if not os.path.isdir(r)), 'subject': subject})
        edits, h = scan(seg); honest += h
        for var_e in edits:
            A.append({'baton': base, 'piped': var_e[3], 'at': seg[var_e[0]:var_e[0]+70].strip()})
        if ap_cure and subject:
            # ⭐ MULTI-ROOT: only the three reviewed batons in MULTIROOT are rewritten (the cio's ruling); every other one is RULING PENDING
            if base not in MULTIROOT:
                RULING.append(base); continue
            seg2 = seg
            for _old, _new in MULTIROOT[base]:
                if seg2.count(_old) != 1:
                    REFUSED.append(base + ' (a reviewed fragment is not found exactly once in the live criterion)'); break
                seg2 = seg2.replace(_old, _new)
            else:
                if _live_claimed(base):
                    SKIPPED.append(base); continue
                if _parses(seg2) is not True:
                    REFUSED.append(base + ' (the rewritten criterion does not parse)'); continue
                m0 = re.search(r'^DONE-WHEN:', raw, re.M)
                receipt = ('DONE-WHEN-WAS: ' + orig.strip() + '\n'
                           'DONE-WHEN-WHY: census --cure 2026-11-07, ruled by the cio (multi-root roster loop), run by worker_05: the pinned roots read the live ROSTER\n')
                new_text = raw[:m0.start()] + receipt + raw[m0.start():s] + seg2 + raw[e:]
                if base in PREMISE_INVERSE:
                    # the premise is the EXACT INVERSE of the new criterion, run in a subshell so the criterion's exit cannot read as the premise's own
                    pm = list(re.finditer(r'^PREMISE-WHEN:.*$', new_text, re.M))
                    if len(pm) != 1 or not any(_o in pm[0].group(0) for _o, _n in MULTIROOT[base]):
                        REFUSED.append(base + ' (the PREMISE-WHEN does not carry the reviewed fragment exactly once)'); continue
                    body = seg2.strip()
                    if _parses(body) is not True:
                        REFUSED.append(base + ' (the inverted premise does not parse)'); continue
                    old_line = pm[0].group(0)
                    rec2 = ('PREMISE-WHEN-WAS: ' + old_line[len('PREMISE-WHEN:'):].strip() + '\n'
                            'PREMISE-WHEN-WHY: census --cure 2026-11-07, ruled by the cio and the coo (multi-root roster loop): the premise is the exact inverse of the new DONE-WHEN, in a subshell\n')
                    new_text = new_text[:pm[0].start()] + rec2 + 'PREMISE-WHEN: ! ( ' + body + ' )' + new_text[pm[0].end():]
                open(p, 'w', encoding='utf-8').write(new_text); touched += 1
                MULTI_DONE.append(base)
            continue
        if ap_cure:
            # ⛔ CLASS B FIRST, THEN RE-SCAN. The B substitution SHORTENS the criterion (${S4E_HOME:-/home/
            # claude_cto} -> ${S4E_HOME:-$PWD} loses 12 bytes), so class-A offsets computed against the
            # pre-substitution text land 12 bytes late and splice a guard into the middle of a token --
            # measured: it produced `g=$(cd "$R/S{ _dwraw=$(...`, two criteria that no longer parse. An
            # offset is only valid against the exact string it was computed from.
            seg = re.sub(r'(\$\{S4E_HOME:-)/home/claude[A-Za-z0-9_]*(\})', r'\1$PWD\2', seg)
            # ⛔ THE BARE FORM, REWRITTEN TO THE ONE SPELLING ALREADY IN THE TREE. `${S4E_HOME:-$PWD}` and
            # not a bare `$S4E_HOME`: the bus runs every criterion as `( cd "$S4E" && S4E_HOME="$S4E" ...
            # bash -c "$dw" )` (s4e_msg.sh:2540), so under `done` the two are the SAME value and the
            # fallback is dead text; it fires only in a HAND audit, where S4E_HOME is unset in a seat's
            # ambient shell (measured) and a bare `$S4E_HOME/SCRIP` would read `/SCRIP`. Two spellings of
            # one idea in one tree is how the next reader learns the wrong one, so this matches the
            # fallback cure above exactly. ⛔ Recomputed AFTER the fallback substitution for the same
            # offset reason stated there, and applied in REVERSE so earlier spans keep their offsets.
            _brs, _bsp = bare_roots(seg)
            for _a, _b in reversed(_bsp):
                seg = seg[:_a] + '${S4E_HOME:-$PWD}' + seg[_b:]
            edits, _h2 = scan(seg)
            for a, en, repl, _ in reversed(edits):
                seg = seg[:a] + repl + seg[en:]
            if seg != orig:
                if _live_claimed(base):
                    SKIPPED.append(base); continue
                # the receipt is two lines BESIDE the criterion, never inside it: a non-executable DONE-WHEN-WAS with the old
                # criterion verbatim, and a DONE-WHEN-WHY naming the ruler (the cio) and the run
                if _parses(seg) != _parses(orig):
                    REFUSED.append(base); continue
                m0 = re.search(r'^DONE-WHEN:', raw, re.M)
                receipt = ('DONE-WHEN-WAS: ' + orig.strip() + '\n'
                           'DONE-WHEN-WHY: census --cure 2026-11-07, ruled by the cio, run by worker_05: a seat-root pin re-homed to ${S4E_HOME:-$PWD}\n')
                open(p, 'w', encoding='utf-8').write(raw[:m0.start()] + receipt + raw[m0.start():s] + seg + raw[e:]); touched += 1
    if '--json' in sys.argv:
        print(json.dumps({'population': len(files), 'A': A, 'B': B, 'B_subject': SUBJ, 'honest': honest}, indent=1)); return 0
    print(f"DONE-WHEN rc/root census over {len(files)} batons at {tasks}")
    print(f"  CLASS A defective (captures a runner, cannot tell a refusal from a red): {len(A)}"
          f"  [piped, where rc=$? would read the pipe: {sum(1 for x in A if x['piped'])}]")
    print(f"  CLASS A honest   (no rc check, but refuses 2 when the marker is absent): {honest}  -- not a defect, never rewritten")
    _bare_n = sum(1 for x in B if x.get('bare'))
    _dead_n = sum(1 for x in B if x.get('dead'))
    # ⛔⭐ THE COUNT IS THE LAST THING ON THIS LINE AND THE BREAKDOWN GETS ITS OWN, because a LIVE criterion
    # parses it: the row's DONE-WHEN reads `^ +CLASS B .*: +0$` for its green and `^ +CLASS B ` piped to
    # `[0-9]+$` for its diagnostic. Appending `  [bare: N, ...]` here -- which this file did for one draft --
    # made the green test unmatchable AT ZERO and blanked the diagnostic, i.e. an instrument edit turned a
    # criterion into one that could never pass. Measured at this landing: `RED: 12 ... (census class B line: )`.
    # ⭐ And the SUBJECT line is spelled `CLASS B-SUBJECT`, with no space after the B, so `^ +CLASS B ` still
    # matches exactly ONE line and the diagnostic cannot silently start reporting two numbers.
    print(f"  CLASS B defective (a seat root pinned in the EXECUTED criterion, fallback or bare): {len(B)}")
    print(f"      of those {len(B)}: bare {_bare_n}, fallback {len(B) - _bare_n}, pinning a root that NO LONGER EXISTS {_dead_n}")
    print(f"  CLASS B-SUBJECT  (sweeps >=2 roots; the cio rules, never rewritten here):     {len(SUBJ)}")
    print(f"  DELIBERATE absolute pins (the coo's loop files, counted, never rewritten):     {len(DELIBERATE)}")
    if ap_cure:
        for x in SKIPPED: print(f"  SKIPPED live-claim (not rewritten): {x}")
        for x in RULING: print(f"  RULING PENDING, the cio (multi-root, not rewritten): {x}")
        for x in MULTI_DONE: print(f"  MULTI-ROOT rewritten to the live ROSTER: {x}")
        for x in REFUSED: print(f"  REFUSED (the cure would change whether the criterion parses): {x}")
        print(f"  CURED IN PLACE: {touched} baton file(s) rewritten (each keeps a DONE-WHEN-WAS receipt)"); return 0
    if '--list' in sys.argv:
        for x in A: print(f"    A{'|pipe' if x['piped'] else '     '} {x['baton']}  [{x['at']}]")
        for x in B:
            _d = f"  DEAD-ROOT{x['dead']}" if x.get('dead') else ""
            _k = '    B|subj ' if x.get('subject') else '    B       '
            print(f"{_k}{x['baton']}  fallback={x['fallbacks']} bare={x.get('bare', [])}{_d}")
    return 1 if (A or B) else 0
sys.exit(main())
