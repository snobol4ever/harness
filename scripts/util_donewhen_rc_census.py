#!/usr/bin/env python3
# util_donewhen_rc_census.py -- THE ONE AUTHORITY for "can this DONE-WHEN tell a refusal from a red".
# hq_B 2026-09-13, on the ceo audit FINDING-2026-09-11-ceo-a-done-when-that-captures-a-board-turns-could-not-
# measure-into-failed.md. Two classes, both found by that audit, both cured in place by this script's --cure.
# CLASS A -- a DONE-WHEN captures a runner's output and never consults that runner's rc. Under ONE RUNNER, ONE
#   BOARD a runner answers any seat but the coo with rc=2 REFUSE; the criterion captures that TEXT, the marker
#   grep misses, and a refusal degrades into rc=1 FAILED. The row is fine and the audit reads it as red.
# CLASS B -- a DONE-WHEN pins a SEAT ROOT in the text the bus actually runs, so the criterion grades whichever
#   tree that seat happens to hold rather than origin HEAD. TWO SPELLINGS, one class:
#   (i) the S4E_HOME FALLBACK (${S4E_HOME:-/home/claude_cfo}) -- `s4e_msg.sh done` exports S4E_HOME so the
#       fallback never fires there; it fires exactly when a seat runs the criterion BY HAND to audit it, and
#       then it silently grades ANOTHER SEAT'S TREE and can print PASS.
#   (ii) the BARE form (`cd /home/claude_ceo/SCRIP && ...`, `bash /home/claude_T/harness/scripts/x.sh`) -- coo
#       2026-09-23 on CEO-1163, RULES.md THE INSTRUMENT LAWS thirty-fourth batch clause 3: a criterion that
#       names a seat root names a tree. It has NO fallback at all, so it does not even degrade.
#   ⛔ 28 of the 46 found at that landing pin a root that HAS NOT EXISTED SINCE CEO-767 (the lettered
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
HEADS = r'^(GOAL|LINKS|RANK|SCOPE|LEDGER|OWNER|BLOCKED-ON|FINDING|MINTED BY|DONE-WHEN|## )'
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
            roots.append(m.group(0)); spans_out.append((a+ls+m.start(), a+ls+m.end()))
    return roots, spans_out
def classB_fallback(seg):
    return [m.group(1).strip() for m in re.finditer(r'\$\{S4E_HOME:-([^}]*)\}', seg)
            if re.match(r'^/home/claude', m.group(1).strip())]
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
    A, B, SUBJ, honest, touched = [], [], [], 0, 0
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
        subject = len(uniq) >= 2
        if subject and uniq: SUBJ.append({'baton': base, 'roots': uniq})
        if fbs or (uniq and not subject):
            B.append({'baton': base, 'fallbacks': sorted(set(fbs)), 'bare': ([] if subject else uniq),
                      'dead': sorted(r for r in ([] if subject else uniq) if not os.path.isdir(r))})
        edits, h = scan(seg); honest += h
        for var_e in edits:
            A.append({'baton': base, 'piped': var_e[3], 'at': seg[var_e[0]:var_e[0]+70].strip()})
        if ap_cure:
            # ⛔ CLASS B FIRST, THEN RE-SCAN. The B substitution SHORTENS the criterion (${S4E_HOME:-/home/
            # claude_ceo} -> ${S4E_HOME:-$PWD} loses 12 bytes), so class-A offsets computed against the
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
            # ⛔ THE SUBJECT EXEMPTION IS RE-APPLIED HERE, NOT ASSUMED FROM THE DETECT PASS. Measured by the
            # gate's arm 2d on the first run of this cure: the roster-sweep fixture was rewritten anyway,
            # because the cure called the raw reader and the exemption lived only in main()'s counting. An
            # exemption that exists in the census but not in the rewriter is the worse half of the pair.
            if len(set(_brs)) >= 2: _bsp = []
            for _a, _b in reversed(_bsp):
                seg = seg[:_a] + '${S4E_HOME:-$PWD}' + seg[_b:]
            edits, _h2 = scan(seg)
            for a, en, repl, _ in reversed(edits):
                seg = seg[:a] + repl + seg[en:]
            if seg != orig:
                open(p, 'w', encoding='utf-8').write(raw[:s] + seg + raw[e:]); touched += 1
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
    print(f"  CLASS B-SUBJECT  (sweeps >=2 roots, so the roots ARE the question):     {len(SUBJ)}  -- not a defect, never rewritten")
    if ap_cure:
        print(f"  CURED IN PLACE: {touched} baton file(s) rewritten"); return 0
    if '--list' in sys.argv:
        for x in A: print(f"    A{'|pipe' if x['piped'] else '     '} {x['baton']}  [{x['at']}]")
        for x in B:
            _d = f"  DEAD-ROOT{x['dead']}" if x.get('dead') else ""
            print(f"    B       {x['baton']}  fallback={x['fallbacks']} bare={x.get('bare', [])}{_d}")
        for x in SUBJ: print(f"    B|subj  {x['baton']}  {x['roots']}")
    return 1 if (A or B) else 0
sys.exit(main())
