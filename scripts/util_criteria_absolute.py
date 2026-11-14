#!/usr/bin/env python3
# util_criteria_absolute.py -- STEP 5 OF THE ONE-DISK MOVE: every live row's DONE-WHEN and PREMISE-WHEN names the absolute paths
# (row harness-one-disk-step-5-every-criterion-names-the-absolute-paths, officer_05 2026-11-13; Lon 18:1x CST: "all shell scripts
# will change from the SIBLING model to the ABSOLUtE model."). One tool, run once:
#   --plan  OUT.tsv           each live row's header criterion that names a sibling, its rewrite, and every token rewritten or left
#   --verify PLAN.tsv OUT.tsv  run each old and new criterion as the bus runs it (bash -c, S4E_HOME exported, cwd the root, a bound);
#                              PARALLEL=N workers, a pair back to back in one worker; the verdict is the rc class 0 / 1 / 2 / timeout
#   --apply VERIFY.tsv         recut every row whose old and new verdict agree (s4e_msg.sh recut, the old kept on DONE-WHEN-WAS)
#   --check                    rc 0 when no live row's header criterion names a sibling (the same scanner as --plan)
#   --selftest                 the rewrites on a table of shapes. CRITERIA_ABSOLUTE ok|RED
# THE FORM (skill gates-and-witnesses section 1): cd "${S4E_HOME:?REFUSE(2): S4E_HOME unset}" && . "${S4E_HARNESS:-/home/harness}/scripts/lib_paths.sh" && ...
# then $S4E_HARNESS/scripts/..., $S4E_CORPUS/..., $S4E_GITHUB/... and $S4E_SCRIP/... (cd "$S4E_SCRIP" for cd SCRIP).
# THE SCANNER respects bash's quoting: a path inside '...' is never rewritten (it is a pattern or a program text), only reported;
# one in "..." or bare is; $( ) and backticks inside "..." are bare again. A word is a sibling path only at a word start
# (after a blank, a quote, ( = ; | & < > : or `), never after a / or a name character, so /home/claude_cio/harness/ stays.
import os, re, subprocess, sys, time
PO = os.environ.get('S4E_POST', '/home/resources/postoffice')
PFX = 'cd "${S4E_HOME:?REFUSE(2): S4E_HOME unset}" && '
PFXS = 'cd "${S4E_HOME:?REFUSE(2): S4E_HOME unset}/SCRIP" && '   # one-disk: not a path
SRC = '. "${S4E_HARNESS:-/home/harness}/scripts/lib_paths.sh" && '
VAR = {'SCRIP': 'S4E_SCRIP', 'harness': 'S4E_HARNESS', 'corpus': 'S4E_CORPUS', '.github': 'S4E_GITHUB'}
BOUND = set(' \t"(=;|&<>:`\n')
HOMEV = re.compile(r'(\$\{S4E_HOME(?::\?[^}]*)?\}|\$S4E_HOME\b|"\$S4E_HOME"|"\$\{S4E_HOME\}")/(SCRIP|harness|corpus|\.github)(?=/|\b|")')
REL = re.compile(r'((?:\.\./)*|\./)(SCRIP|harness|corpus|\.github)(/|(?=[\s;|&)"`]|$))')

def contexts(s):
    """yield (i, ctx) for each char: ctx 'S' inside single quotes, 'D' inside double quotes, 'U' bare (top or $( ) or backticks)."""
    st = ['U']; i = 0; out = []
    while i < len(s):
        c = s[i]; top = st[-1]
        if top == 'S':
            out.append('S');
            if c == "'": st.pop()
            i += 1; continue
        if c == '\\':
            out += [top, top]; i += 2; continue
        if top == 'D':
            if c == '"': st.pop(); out.append('D'); i += 1; continue
            if s.startswith('$(', i): st.append('P'); out += ['D', 'D']; i += 2; continue
            if c == '`': st.append('B'); out.append('D'); i += 1; continue
            out.append('D'); i += 1; continue
        # U, P (inside $( )), B (inside backticks)
        if c == "'": st.append('S'); out.append('S'); i += 1; continue
        if c == '"': st.append('D'); out.append('D'); i += 1; continue
        if top == 'B' and c == '`': st.pop(); out.append('U'); i += 1; continue
        if c == '`': st.append('B'); out.append('U'); i += 1; continue
        if s.startswith('$(', i): st.append('P'); out += ['U', 'U']; i += 2; continue
        if c == '(' : st.append('Q') if top in ('P', 'Q') else None; out.append('U'); i += 1; continue
        if c == ')' and top in ('P', 'Q'): st.pop(); out.append('U'); i += 1; continue
        out.append('U'); i += 1
    return out[:len(s)]

def rewrite(v):
    """return (new, notes): notes lists each token as rewritten or kept-in-single-quotes."""
    notes = []; head = ''
    if v.startswith(PFX): head, body = PFX + SRC, v[len(PFX):]
    elif v.startswith(PFXS): head, body = PFX + SRC + 'cd "$S4E_SCRIP" && ', v[len(PFXS):]
    else: body = v
    ctx = contexts(body); o = []; i = 0
    while i < len(body):
        cx = ctx[i]
        if cx != 'S':
            m = HOMEV.match(body, i)
            if m:
                rep = '$' + VAR[m.group(2)]
                if m.group(1).startswith('"'): rep = '"' + rep + '"'
                o.append(rep); notes.append(('home', m.group(0), rep)); i = m.end(); continue
            prev = body[i - 1] if i else ' '
            if prev in BOUND:
                m = REL.match(body, i)
                if m and (m.group(3) == '/' or re.search(r'(cd|-C|-[defx])\s+$', body[:i])):
                    dots = m.group(1)
                    var = '$' + VAR[m.group(2)]
                    if m.group(3) == '/': rep = var + '/'
                    else: rep = ('"' + var + '"') if cx == 'U' else var
                    o.append(rep); notes.append((cx, m.group(0), rep)); i = m.end(); continue
        elif (i == 0 or body[i - 1] in BOUND | {"'"}) and REL.match(body, i) and REL.match(body, i).group(3) == '/':
            notes.append(('S', REL.match(body, i).group(0), 'kept'))
        o.append(body[i]); i += 1
    if not any(n[2] != 'kept' for n in notes): return v, notes
    new = head + ''.join(o)
    if not head: new = SRC + new
    return new, notes

def header_criteria(path):
    """(label, value) of the header's DONE-WHEN and PREMISE-WHEN lines (above the first ## section): the ones the bus runs."""
    out = []
    for l in open(path, encoding='utf-8', errors='replace'):
        if l.startswith('## '): break
        for k in ('DONE-WHEN', 'PREMISE-WHEN'):
            if l.startswith(k + ':'): out.append((k, l[len(k) + 1:].strip()))
    return out

def live_rows():
    rows = []
    for l in open(os.path.join(PO, 'QUEUE.tsv'), encoding='utf-8', errors='replace'):
        c = l.rstrip('\n').split('\t')
        if len(c) > 3 and c[0].isdigit() and not re.search('RETIRED|DONE', c[3]): rows.append((c[1], c[3]))
    return rows

def plan(out):
    n = 0
    with open(out, 'w') as f:
        for t, st in live_rows():
            p = os.path.join(PO, 'tasks', t + '.task.md')
            if not os.path.exists(p): continue
            for k, v in header_criteria(p):
                new, notes = rewrite(v)
                if new == v: continue
                n += 1
                f.write('\t'.join([t, k, st, v, new, ' | '.join(f'{a}:{b}->{c}' for a, b, c in notes)]) + '\n')
    print(f'PLAN criteria={n} file={out}')

def run(cmd, home, to):
    t0 = time.time()
    try:
        p = subprocess.run(['setsid', 'bash', '-c', cmd], cwd=home, env=dict(os.environ, S4E_HOME=home), stdin=subprocess.DEVNULL,
                           stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=to)
        rc = p.returncode; tail = p.stdout.decode('utf-8', 'replace').strip().splitlines()[-1:] or ['']
    except subprocess.TimeoutExpired as e:
        rc = 124; tail = ['timeout']
    return rc, round(time.time() - t0, 1), tail[0][:150].replace('\t', ' ')

def cls(rc): return {0: '0', 1: '1', 2: '2', 124: 'timeout'}.get(rc, '1' if rc not in (2, 124) else str(rc))

def verify(planf, out):
    from concurrent.futures import ThreadPoolExecutor
    home = os.environ['S4E_HOME']; to = int(os.environ.get('BOUND_S', '300')); par = int(os.environ.get('PARALLEL', '4'))
    rows = [l.rstrip('\n').split('\t') for l in open(planf)]
    done = set()
    if os.path.exists(out):
        for l in open(out): c = l.split('\t'); done.add((c[0], c[1]))
    serial = [r for r in rows if re.search(r'\bmake\b', r[3]) and (r[0], r[1]) not in done]
    rest = [r for r in rows if r not in serial and (r[0], r[1]) not in done]
    def one(r):
        a = run(r[3], home, to); b = run(r[4], home, to)
        line = '\t'.join([r[0], r[1], cls(a[0]), cls(b[0]), str(a[0]), str(b[0]), str(a[1]), str(b[1]), a[2], b[2]]) + '\n'
        with open(out, 'a') as f: f.write(line)
        return line
    with ThreadPoolExecutor(par) as ex: list(ex.map(one, rest))
    for r in serial: one(r)
    v = [l.split('\t') for l in open(out)]
    same = sum(1 for c in v if c[2] == c[3]); print(f'VERIFY pairs={len(v)} same={same} moved={len(v) - same} file={out}')

def apply(verf, planf):
    pl = {(c[0], c[1]): c for c in (l.rstrip('\n').split('\t') for l in open(planf))}
    ver = {}
    for l in open(verf):
        c = l.rstrip('\n').split('\t'); ver[(c[0], c[1])] = c
    by = {}
    for key, c in pl.items(): by.setdefault(key[0], []).append(key)
    ok = moved = fail = 0; sh = os.path.join(os.path.dirname(os.path.abspath(__file__)), 's4e_msg.sh')
    for t, keys in sorted(by.items()):
        bad = [k for k in keys if k not in ver or ver[k][2] != ver[k][3] or ver[k][2] == 'timeout']
        if bad: moved += 1; print('LEFT', t, ' '.join(f'{k[1]}:{ver[k][2]}->{ver[k][3]}' if k in ver else f'{k[1]}:unread' for k in bad)); continue
        body = ''.join(f'{k[1]}: {pl[k][4]}\n' for k in keys) + 'WHY: the one-disk move, step 5: the criterion names $S4E_HARNESS, $S4E_CORPUS, $S4E_GITHUB and $S4E_SCRIP after sourcing lib_paths.sh; old and new read the same verdict (util_criteria_absolute.py --verify)\n'
        p = subprocess.run(['bash', sh, 'recut', t, '--stdin'], input=body.encode(), stdout=subprocess.PIPE, stderr=subprocess.STDOUT, env=dict(os.environ, S4E_NO_BANNER='1'))
        if p.returncode == 0: ok += 1
        else: fail += 1; print('REFUSED', t, p.stdout.decode('utf-8', 'replace').strip().splitlines()[0][:200])
    print(f'APPLY recut={ok} left={moved} refused={fail}')

def check():
    n = 0
    for t, st in live_rows():
        p = os.path.join(PO, 'tasks', t + '.task.md')
        if not os.path.exists(p): continue
        if any(rewrite(v)[0] != v for k, v in header_criteria(p)): n += 1; print('SIBLING', t)
    print(f'rows still sibling: {n}'); return 0 if n == 0 else 1

def selftest():
    P = PFX; S = SRC; T = [
        (P + 'bash harness/scripts/test_x.sh', P + S + 'bash $S4E_HARNESS/scripts/test_x.sh'),   # one-disk: not a path
        (P + 'cd SCRIP && ./scrip a.sno', P + S + 'cd "$S4E_SCRIP" && ./scrip a.sno'),
        (P + 'o="$(SCRIP/scrip corpus/x.icn)"; [ "$o" = 1 ]', P + S + 'o="$($S4E_SCRIP/scrip $S4E_CORPUS/x.icn)"; [ "$o" = 1 ]'),   # one-disk: not a path
        (P + "grep -q 'corpus/tests' f", P + "grep -q 'corpus/tests' f"),   # one-disk: not a path
        (P + 'test -f /home/claude_cio/harness/scripts/x', P + 'test -f /home/claude_cio/harness/scripts/x'),
        (PFXS + 'P=../corpus/packages/icon && ./scrip $P/a.icn', P + S + 'cd "$S4E_SCRIP" && P=$S4E_CORPUS/packages/icon && ./scrip $P/a.icn'),
        (P + 'cd "$S4E_HOME/SCRIP" && make', P + S + 'cd "$S4E_SCRIP" && make'),   # one-disk: not a path
        (P + 'test -x "$S4E_HOME"/SCRIP/scrip', P + S + 'test -x "$S4E_SCRIP"/scrip'),
        (P + 'git -C corpus log -1', P + S + 'git -C "$S4E_CORPUS" log -1'),
        (P + 'echo "no harness here"', P + 'echo "no harness here"'),
        (P + 'grep -c x .github/skills/a.md', P + S + 'grep -c x $S4E_GITHUB/skills/a.md'),   # one-disk: not a path
        (P + 'o="$(cd corpus/a/b/c && ../../../../SCRIP/scrip t.icn)"', P + S + 'o="$(cd $S4E_CORPUS/a/b/c && $S4E_SCRIP/scrip t.icn)"'),   # one-disk: not a path
        (P + 'cd corpus && ../SCRIP/scrip t.sno', P + S + 'cd "$S4E_CORPUS" && $S4E_SCRIP/scrip t.sno'),
    ]
    why = [f'{a!r} -> {rewrite(a)[0]!r}, want {b!r}' for a, b in T if rewrite(a)[0] != b]
    if why: print('CRITERIA_ABSOLUTE RED:\n  ' + '\n  '.join(why)); return 1
    print(f'CRITERIA_ABSOLUTE ok arms={len(T)}'); return 0

if __name__ == '__main__':
    a = sys.argv[1:]
    if a[:1] == ['--plan']: plan(a[1])
    elif a[:1] == ['--verify']: verify(a[1], a[2])
    elif a[:1] == ['--apply']: apply(a[1], a[2])
    elif a[:1] == ['--check']: sys.exit(check())
    elif a[:1] == ['--selftest']: sys.exit(selftest())
    else: print(__doc__ or 'usage: --plan OUT | --verify PLAN OUT | --apply VERIFY PLAN | --check | --selftest', file=sys.stderr); sys.exit(2)
