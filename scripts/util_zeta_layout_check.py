#!/usr/bin/env python3
# util_zeta_layout_check.py --asm run.s --plan plan.txt [--classes C,C] [--show N] [--quiet] -- THE LAYOUT CHECKER of DESIGN-PLAN zeta-layout (step 1).
#
# ONE SOURCE OF TRUTH FOR THE THREE ZETAS' LAYOUTS (ARCH-ZETA-LAYOUT-ONE-SOURCE-OF-TRUTH.md section 5, CEO-2019): the planner's row (./scrip --dump-plan) is the
# record of every box's depth; this checks a program's MODE-4 assembly against it. It is an INSTRUMENT, the one place our own generated text is re-parsed (the
# compiler never re-reads its output, CEO-2019 R2). It changes nothing and reads no binary.
#
# Inputs: --asm  the mode-4 text from `./scrip --compile --out=run.s prog`;   --plan  `./scrip --dump-plan prog` on stdout.
# Pairing: the Nth PLAN graph is the Nth chain of the text (a `.Lgccode_` label opens a chain) and its rows are the chain's boxes in order (`.type nI_kind_bx`
#   ... `.size`); the number I in a label is NOT a row index (the id counter is shared with helper labels). A count or kind that does not pair is an ALIGN line.
# A row is ARMED when its `definite` column is 1 and its `depth` and K are numbers; an unarmed row (a graph the depth planner did not arm, or a run with no known
#   base) is skipped by every check below, and the summary says how many rows were armed. DEPTHS ARE ABSOLUTE: a row's E and X are relative to its claim's base, so
#   the exit depth is the `depth` column (the claim base plus X) and the entry depth is that minus K; comparing E or X across two claims would read a false edge.
#
# FINDINGS (one line each, `CLASS graph box Lline detail`; line is the line of the text; the total is `mismatches=` on the LAST line):
#   EXCURSION graph box Lline insn bytes=N     an rsp write inside a box that is not the carve, the pop or a declared edge site (R1, the flat cell rule): a push, a
#                                              pop, a sub or add of rsp, a lea or mov into rsp. ALLOWED are: the CARVE (the run of `sub rsp, imm` that starts at the
#                                              alpha label), an EXIT write (a straight run to a jmp or ret out of the box with no label, call or conditional jump
#                                              between: the pop at gamma/omega, a call frame pushed before the transfer), a `mov`/`lea` into rsp in a box whose row
#                                              declares a `restore` (the discard), and the ZSM instrument's balanced push/pop around rt_zdp_ev (named and skipped).
#   SPILL-PAIR graph box Lline insn pop=Lline  (R1, the cto's review of step 1) a push whose balancing pop comes on the same straight run to the way out of the box,
#                                              with no label, call or conditional jump between the push and the exit: the spill of a value around code, the same R1
#                                              violation as an EXCURSION, counted in mismatches (step 2a declares the cell word and takes them to 0). A pop with
#                                              nothing between it and the way out and no push of its own on the run is the exit's pop, not a finding.
#   GATE-PAIR count=N                          (the cto's ruling of 2026-10-30, ARCH-ZETA-LAYOUT 5 item E) x86_gc_gate's `push R; mov R, [g_gc_pending]; mov E, [R]; test E, E; pop R`
#                                              before the `je` that skips a poll: a NAMED EXEMPTION of R1's class until step 6 deletes it (no site, no allocation, no call,
#                                              label or jump inside; the depth at every site is unchanged by it). Counted apart, NOT in mismatches, and never an EXCURSION;
#                                              any other push/pop pair stays an EXCURSION or a SPILL-PAIR. Printed as one `GATE-PAIR count=N` line.
#   CARVE graph box Lline carved=N want=K      the alpha carve differs from the row's K (none counts as 0).
#   EDGE graph box Lline target have=D want=D  a jmp or jcc out of the box lands on another box's port at a depth other than the target's E (an alpha port) or X (a
#                                              beta port): the edge laws of ARCH-ZETA-ONE-COORDINATE 1.1 read off the code. The depth is SIMULATED from the port:
#                                              alpha enters at E, beta at X, then every rsp write moves it. A path whose depth cannot be known (an indirect jump,
#                                              a mov into rsp) is UNCHECKED, counted, never a finding. An edge with a RETAINING row at either end (`retains_code`
#                                              not 0: a gate that holds, a suspend, a retaining callee) is not read: the planner's edge laws for a retaining node are
#                                              its own (ARCH-ZETA-ONE-COORDINATE section 8). It prints as a RETAINING-EDGE line `graph box Lline target retains=S/T`
#                                              (never skipped in silence), counted apart: NOT in mismatches, until step 3 states the check.
#   TRANSFER-POP graph box Lline popped=P wanted=W   (R9) a box of a transfer kind (IR_GOTO_DEFERRED, IR_INDIRECT_GOTO, IR_SETEXIT_TEST, IR_GOTO) whose claim
#                                              root (the row named by the `owner` column) is a SNOBOL4 statement entry (IR_STATEMENT_BEGIN or IR_SETEXIT_TEST, the
#                                              program top) leaves by an indirect jump or a jump to a user label (LBL_*) at a depth other than that root's entry
#                                              depth E_t: it popped P bytes of the X-E_t it owed. The zl02 leak of 2026-10-29 reads here. A transfer whose root is
#                                              not a statement entry (IR_INDIRECT_GOTO of an if-type construct: R9 states no E_t for it) is counted UNCHECKED.
#   SITE graph box Lline rule=R depth=D want=W a GC site record whose pc lies in a box, graded per rule by ARCH-GC 13.13 and the cto's item 8 (ARCH-ZETA-LAYOUT 5):
#                                              rule 0 (rsp-relative) depth = X of the row (= E + K, R2); rules 1 and 3 (the frame's home is rbp) depth 0; rule 2 (a flat
#                                              generator frame addressed down from rbp) depth = the row's `flat_gen_rbp` column when the plan dump prints it; rule 6 (a site
#                                              inside a pattern match) depth = the depth of its OWNING ENTER (the nl-th open MATCH_ENTER site, kind bits 8-11 the level,
#                                              12-15 the enter's kind): the enter's row X when ek is 0, 0 when ek is 1 or 3. The owning enter is read from the site table
#                                              itself (kind 4 opens, kind 5 closes), never from the site's own box.
#   RULE5 graph box Lline depth=D              a rule-5 site (the encoder lost the distance, the chain stops with `unknown-depth`): a finding wherever it appears, in mismatches.
#   SITE-UNGRADED rule=N count=M               printed for each rule whose depth the plan row does not carry: rule 2 until the dump prints the generator frame, rule 4
#                                              (two assigners with two formulas; its aligned arm needs the live vdj bytes the plan does not carry, and no witness emits it
#                                              yet), and `ext=nonzero` for a nonzero GC_SITE_EXT byte (the rule field's high byte, not described in 13.13). Not in mismatches.
#   SITE-HOP rule=N count=M                    rules 7, 8 and 9 describe no frame (a return-road hop, an FN_EXIT hop, the shim-self hop): counted, no depth expectation.
#   SITE-UNEXERCISED rule=N                    every rule 0 to 9 this program's sites do not emit (rule 5 is unexercised by design); the step harness intersects the lines
#                                              over its witnesses, so a rule no witness emits is never a 0 by silence.
#   TRANSFER-UNCHECKED count=M                 printed when a transfer's claim root is not a statement entry (R9 states no E_t for it until step 2a gives the row its tpop).
#   ALIGN graph chain detail                   the plan and the text do not pair (a graph with no chain, a different box count, a different kind at a row).
#
# rc: 0 no finding, 1 findings, 2 an input could not be read (no `mismatches=` line is printed).   The harness (test_design_zeta_layout_steps.sh) reads the line.
# Run under `python3 -I`; standard library only.
import argparse, collections, re, sys

CLASSES = ('EXCURSION', 'SPILL-PAIR', 'CARVE', 'EDGE', 'TRANSFER-POP', 'SITE', 'RULE5', 'ALIGN')
APART = ('RETAINING-EDGE',)
SITE_GRADED = {0, 1, 3, 5, 6}
SITE_HOP = {7, 8, 9}
SITE_RULES = range(10)
TRANSFER_KINDS = {'IR_GOTO_DEFERRED', 'IR_INDIRECT_GOTO', 'IR_SETEXIT_TEST', 'IR_GOTO'}
STATEMENT_ROOTS = {'IR_STATEMENT_BEGIN', 'IR_SETEXIT_TEST'}
ZSM_PUSH = ['rax', 'rax', 'rdi', 'rsi', 'rdx', 'rcx', 'r8', 'r9', 'r10', 'r11']
JCC = {'je', 'jne', 'jz', 'jnz', 'ja', 'jae', 'jb', 'jbe', 'jg', 'jge', 'jl', 'jle', 'js', 'jns', 'jo', 'jno', 'jp', 'jnp', 'jc', 'jnc', 'jna', 'jnae', 'jnb', 'jnbe',
       'jng', 'jnge', 'jnl', 'jnle', 'jpe', 'jpo', 'jcxz', 'jecxz', 'jrcxz', 'loop', 'loope', 'loopne'}
REGS64 = {'rax', 'rbx', 'rcx', 'rdx', 'rsi', 'rdi', 'rbp', 'rsp', 'r8', 'r9', 'r10', 'r11', 'r12', 'r13', 'r14', 'r15'}
LABEL = re.compile(r'^([\w.$@]+):\s*')
BOXNAME = re.compile(r'^n(\d+)_(.+)_bx$')
PORT = re.compile(r'^n(\d+)_(.+?)_(α|β)$')
IMM = re.compile(r'^[-+]?(0x[0-9a-fA-F]+|\d+)$')
LEA_RSP = re.compile(r'^\[\s*rsp\s*([-+])\s*(0x[0-9a-fA-F]+|\d+)\s*\]$')
SITE_ENT = re.compile(r'^(\.Lgcsite_\S+?)-(\.Lgccode_\S+)$')
NOEFF = (False, 0)


def armed(r):
    return r['definite'] == 1 and r['depth'] is not None and r['K'] is not None


def xa(r):
    return r['depth']


def ea(r):
    return r['depth'] - r['K']


class Ins:
    __slots__ = ('ln', 'op', 'a', 'labels', 'eff', 'text', 'target', 'zsm')

    def __init__(self, ln, op, a, labels):
        self.ln, self.op, self.a, self.labels, self.zsm = ln, op, a, labels, False
        self.text = (op + ' ' + ', '.join(a)).strip()
        self.eff = rsp_effect(op, a)
        self.target = a[0] if (op == 'jmp' or op in JCC) and a else None


class Box:
    __slots__ = ('name', 'id', 'kind', 'start', 'ins', 'lab', 'num', 'tail', 'alpha', 'beta')

    def __init__(self, name, start):
        m = BOXNAME.match(name)
        self.name, self.start, self.ins, self.lab, self.num, self.tail = name, start, [], {}, collections.defaultdict(list), []
        self.id, self.kind = int(m.group(1)), m.group(2)
        self.alpha, self.beta = 'n%d_%s_α' % (self.id, self.kind), 'n%d_%s_β' % (self.id, self.kind)


class Chain:
    __slots__ = ('code', 'line', 'boxes', 'by_id')

    def __init__(self, code, line):
        self.code, self.line, self.boxes, self.by_id = code, line, [], {}


def split_args(s):
    out, depth, cur = [], 0, []
    for c in s:
        if c == '[':
            depth += 1
        elif c == ']':
            depth -= 1
        if c == ',' and depth == 0:
            out.append(''.join(cur).strip())
            cur = []
        else:
            cur.append(c)
    t = ''.join(cur).strip()
    if t:
        out.append(t)
    return out


def imm(s):
    if s is None or not IMM.match(s):
        return None
    return int(s, 0)


def rsp_effect(op, a):
    """(writes rsp, delta) with delta None when the new depth is not a constant distance from the old one."""
    if op in ('push', 'pushfq'):
        return (True, -8)
    if op in ('pop', 'popfq'):
        return (True, 8)
    if op == 'leave':
        return (True, None)
    if not a or a[0].lower() != 'rsp':
        return NOEFF
    if op in ('sub', 'add'):
        v = imm(a[1] if len(a) > 1 else None)
        if v == 0:
            return NOEFF
        return (True, None if v is None else (-v if op == 'sub' else v))
    if op == 'lea':
        m = LEA_RSP.match(a[1]) if len(a) > 1 else None
        return (True, None if m is None else (int(m.group(2), 0) if m.group(1) == '+' else -int(m.group(2), 0)))
    if op in ('mov', 'and', 'xchg', 'or', 'xor', 'cmovz', 'cmovnz'):
        return (True, None)
    return NOEFF


def strip_comment(s):
    q = None
    for i, c in enumerate(s):
        if q:
            if c == q and s[i - 1] != '\\':
                q = None
        elif c in '"\'':
            q = c
        elif c == '#':
            return s[:i]
    return s


def split_stmts(s):
    out, q, cur = [], None, []
    for i, c in enumerate(s):
        if q:
            cur.append(c)
            if c == q and s[i - 1] != '\\':
                q = None
        elif c in '"\'':
            q = c
            cur.append(c)
        elif c == ';':
            out.append(''.join(cur))
            cur = []
        else:
            cur.append(c)
    out.append(''.join(cur))
    return out


def parse_plan(path):
    graphs, cols = [], None
    with open(path, encoding='utf-8', errors='replace') as f:
        for raw in f:
            if raw.startswith('PLAN_COLUMNS'):
                cols = raw.split()[1:]
            elif raw.startswith('PLAN '):
                m = re.match(r'PLAN graph=(\S+) serial=(\d+) chain=(\S+) n=(\d+)', raw)
                if not m:
                    raise ValueError('unreadable PLAN line: ' + raw.strip())
                graphs.append({'name': m.group(1), 'chain': m.group(3), 'n': int(m.group(4)), 'rows': []})
            elif raw.startswith('PLAN_ROW '):
                if cols is None or not graphs:
                    raise ValueError('PLAN_ROW before PLAN_COLUMNS or PLAN')
                t = raw.split()
                row = {'i': int(t[1].split('=')[1]), 'kind': t[3].split('=')[1]}
                for c, v in zip(cols, t[4:]):
                    row[c] = None if v == '-' else (int(v) if re.match(r'^-?\d+$', v) else v)
                graphs[-1]['rows'].append(row)
    for need in ('K', 'definite', 'depth', 'owner', 'restore'):
        if cols is None or need not in cols:
            raise ValueError('PLAN_COLUMNS lacks ' + need)
    return graphs


def parse_asm(path):
    chains, tabs, site_box = [], {}, {}
    section, stack, cur, box, pend, tab = 'text', [], None, None, [], None
    with open(path, encoding='utf-8', errors='replace') as f:
        for ln, raw in enumerate(f, 1):
            s = strip_comment(raw).strip()
            if not s:
                continue
            for stmt in split_stmts(s):
                stmt = stmt.strip()
                while True:
                    m = LABEL.match(stmt)
                    if not m:
                        break
                    lab, stmt = m.group(1), stmt[m.end():]
                    if section == 'text':
                        if lab.startswith('.Lgccode_'):
                            cur = Chain(lab, ln)
                            chains.append(cur)
                            box = None
                        if lab.startswith('.Lgcsite_'):
                            site_box[lab] = (ln, box)
                        pend.append(lab)
                    elif lab.startswith('.Lgcsites_'):
                        tab = []
                        tabs[lab] = tab
                if not stmt:
                    continue
                if stmt[0] == '.':
                    w = stmt.split(None, 1)
                    d, rest = w[0], (w[1] if len(w) > 1 else '')
                    if d == '.pushsection':
                        stack.append(section)
                        section = 'text' if re.match(r'^\.text\b', rest) else 'data'
                    elif d == '.popsection':
                        section = stack.pop() if stack else 'text'
                    elif d in ('.text',):
                        section = 'text'
                    elif d in ('.data', '.bss', '.section'):
                        section = 'text' if (d == '.section' and re.match(r'^\.text\b', rest)) else 'data'
                    elif d == '.quad' and tab is not None and section != 'text':
                        tab.append(rest.strip())
                    elif d == '.type' and section == 'text' and cur is not None:
                        nm = split_args(rest)[0]
                        if BOXNAME.match(nm):
                            box = Box(nm, ln)
                            cur.boxes.append(box)
                            cur.by_id[box.id] = box
                            pend = []
                    elif d == '.size' and box is not None and split_args(rest)[0] == box.name:
                        box.tail = pend
                        pend = []
                        box = None
                    if d != '.quad':
                        tab = None
                    continue
                if section != 'text':
                    continue
                w = stmt.split(None, 1)
                op = w[0].lower()
                if op in ('rep', 'repe', 'repne', 'repz', 'repnz', 'lock') and len(w) > 1:
                    w = w[1].split(None, 1)
                    op = op + ' ' + w[0].lower()
                a = split_args(w[1]) if len(w) > 1 else []
                if box is not None:
                    I = Ins(ln, op, a, pend)
                    for lab in pend:
                        box.lab[lab] = len(box.ins)
                        if re.match(r'^\d+$', lab):
                            box.num[lab].append(len(box.ins))
                    box.ins.append(I)
                pend = []
    return chains, tabs, site_box


def mark_zsm(box):
    """The ZSM instrument's own balanced sequence around rt_zdp_ev is the one named exemption (ARCH-ZETA-LAYOUT R1): exactly the ten pushes and ten pops of
    x86_zsm_ev and x86_zsm_disc (x86_asm.h), taken from the nearest pushes before the call and the nearest pops after it, with the movs between them."""
    ins, n = box.ins, len(box.ins)
    stop = JCC | {'jmp', 'call', 'ret'}
    for c in range(n):
        if ins[c].op != 'call' or not ins[c].a or 'rt_zdp_ev' not in ins[c].a[0]:
            continue
        pushes, s = [], c
        while s > 0 and not ins[s].labels and ins[s - 1].op not in stop and (ins[s - 1].op == 'push' or not ins[s - 1].eff[0]):
            s -= 1
            if ins[s].op == 'push':
                pushes.append(s)
        pops, e = [], c
        while e + 1 < n and (e == c or not ins[e + 1].labels) and ins[e + 1].op not in stop and (ins[e + 1].op == 'pop' or not ins[e + 1].eff[0]):
            e += 1
            if ins[e].op == 'pop':
                pops.append(e)
        zp, zq = pushes[:len(ZSM_PUSH)][::-1], pops[:len(ZSM_PUSH)]
        if [ins[k].a[0] for k in zp if ins[k].a] != ZSM_PUSH or [ins[k].a[0] for k in zq if ins[k].a] != ZSM_PUSH[::-1]:
            continue
        for k in range(zp[0], zq[-1] + 1):
            ins[k].zsm = True


def internal_labels(box):
    return {l for l in box.lab if l != box.alpha and l != box.beta}


def resolve(box, idx, t):
    """The instruction index a jump target names inside the box, or None when it leaves the box."""
    if re.match(r'^\d+[fb]$', t):
        c = box.num.get(t[:-1], [])
        if t[-1] == 'f':
            for j in c:
                if j > idx:
                    return j
        else:
            for j in reversed(c):
                if j <= idx:
                    return j
        return None
    if t in box.lab and t != box.alpha and t != box.beta:
        return box.lab[t]
    return None


def exit_ok(box, k):
    """True when the rsp write at k reaches a jmp or ret out of the box, or the end of the box, with no label, call or conditional jump between."""
    ins, n = box.ins, len(box.ins)
    j = k + 1
    while j < n:
        I = ins[j]
        if I.labels and not (I.zsm and ins[j - 1].zsm):
            return False
        if I.zsm:
            j += 1
            continue
        if I.op == 'ret':
            return True
        if I.op == 'jmp':
            return not I.a or resolve(box, j, I.a[0]) is None
        if I.op in JCC or I.op == 'call':
            return False
        j += 1
    return True


def spill_pairs(box):
    """{push index: pop index}: a push on a straight run to the way out of the box (exit_ok) whose balancing pop, by the stack discipline, comes on that same run."""
    ins, n = box.ins, len(box.ins)
    out = {}
    for k in range(n):
        if ins[k].zsm or ins[k].op not in ('push', 'pushfq') or not exit_ok(box, k):
            continue
        bal = 1
        for j in range(k + 1, n):
            J = ins[j]
            if J.zsm:
                continue
            if J.op in ('jmp', 'ret'):
                break
            if J.op in ('push', 'pushfq'):
                bal += 1
            elif J.op in ('pop', 'popfq'):
                bal -= 1
                if bal == 0:
                    out[k] = j
                    break
            elif J.eff[0]:
                break
    return out


def gate_pairs(box):
    """The indices of the push and the pop of every x86_gc_gate flag read: push R, mov R [..g_gc_pending..], mov E [R..], test E E, pop R, no label inside."""
    ins, out = box.ins, set()
    for k in range(len(ins) - 4):
        a, b, c, d, e = ins[k:k + 5]
        if a.op != 'push' or len(a.a) != 1 or e.op != 'pop' or e.a != a.a:
            continue
        r = a.a[0]
        if b.labels or c.labels or d.labels or e.labels:
            continue
        if b.op == 'mov' and len(b.a) == 2 and b.a[0] == r and 'g_gc_pending' in b.a[1] and c.op == 'mov' and len(c.a) == 2 and '[' + r in c.a[1].replace(' ', '') and d.op == 'test' and len(d.a) == 2 and d.a[0] == d.a[1]:
            out.add(k)
            out.add(k + 4)
    return out


def simulate(box, start, state):
    """Walk the box from instruction `start` at rsp depth `state`: [(kind, target, depth, line)] for every way out; a depth the code does not fix is None."""
    ins, n = box.ins, len(box.ins)
    exits, seen, work = [], {}, [(start, state)]
    while work:
        idx, st = work.pop()
        while True:
            if idx >= n:
                exits.append(('fall', None, st, ins[-1].ln if ins else box.start))
                break
            if idx in seen:
                if seen[idx] == st or seen[idx] is None:
                    break
                seen[idx] = None
                st = None
            else:
                seen[idx] = st
            I = ins[idx]
            if I.eff[0]:
                st = None if (st is None or I.eff[1] is None) else st - I.eff[1]
            if I.op == 'ret':
                exits.append(('ret', None, st, I.ln))
                break
            if I.op == 'jmp' or I.op in JCC:
                t = I.target
                tgt = resolve(box, idx, t) if t else None
                if tgt is not None:
                    if I.op == 'jmp':
                        idx = tgt
                        continue
                    work.append((tgt, st))
                else:
                    exits.append(('ind' if (t is None or t in REGS64 or '[' in t) else 'jmp', None if (t is None or t in REGS64 or '[' in t) else t.split('@')[0], st, I.ln))
                    if I.op == 'jmp':
                        break
            idx += 1
    return exits


def check(graphs, chains, tabs, site_box):
    found = collections.defaultdict(list)
    info = collections.Counter()
    rule_seen = collections.Counter()

    def add(cls, gname, box, ln, detail):
        found[cls].append('%s %s %s L%d %s' % (cls, gname, box, ln, detail))

    if len(graphs) != len(chains):
        add('ALIGN', '*', '*', 0, 'plan has %d graphs, text has %d chains' % (len(graphs), len(chains)))
    paired = []
    for gi, g in enumerate(graphs[:len(chains)]):
        ch = chains[gi]
        if len(g['rows']) != len(ch.boxes):
            add('ALIGN', g['name'], ch.code, ch.line, 'plan has %d rows, text has %d boxes' % (len(g['rows']), len(ch.boxes)))
            continue
        bad = [(r, b) for r, b in zip(g['rows'], ch.boxes) if b.kind != r['kind'][3:].lower()[:47]]
        if bad:
            add('ALIGN', g['name'], ch.code, ch.line, 'row %d is %s but the box is %s' % (bad[0][0]['i'], bad[0][0]['kind'], bad[0][1].name))
            continue
        paired.append((g, ch))
    box_row = {}
    for g, ch in paired:
        for r, b in zip(g['rows'], ch.boxes):
            box_row[id(b)] = (g, r)
            info['boxes'] += 1
            if armed(r):
                info['armed'] += 1
    for g, ch in paired:
        rows = g['rows']
        for r, b in zip(rows, ch.boxes):
            mark_zsm(b)
            live = armed(r)
            a = b.lab.get(b.alpha)
            carve_idx, carved = set(), 0
            if a is not None:
                j = a
                while j < len(b.ins):
                    I = b.ins[j]
                    if I.zsm:
                        j += 1
                    elif (j == a or not I.labels) and I.op == 'sub' and I.eff[0] and I.eff[1] is not None:
                        carved -= I.eff[1]
                        carve_idx.add(j)
                        j += 1
                    else:
                        break
            else:
                info['no_alpha_label'] += 1
            if live and a is not None and carved != r['K']:
                add('CARVE', g['name'], b.name, b.ins[a].ln if a < len(b.ins) else b.start, 'carved=%d want=%d' % (carved, r['K']))
            spill = spill_pairs(b)
            spill_pops = set(spill.values())
            gate = gate_pairs(b)
            for k, I in enumerate(b.ins):
                if I.zsm:
                    info['zsm_writes'] += 1 if I.eff[0] else 0
                    continue
                if not I.eff[0]:
                    continue
                info['rsp_writes'] += 1
                if k in carve_idx:
                    info['carve_writes'] += 1
                elif k in gate:
                    info['gate_pairs'] += 1 if I.op == 'push' else 0
                elif k in spill:
                    add('SPILL-PAIR', g['name'], b.name, I.ln, '%s pop=L%d' % (I.text, b.ins[spill[k]].ln))
                elif k in spill_pops:
                    info['spill_pops'] += 1
                elif exit_ok(b, k):
                    info['exit_writes'] += 1
                elif r.get('restore') is not None and I.eff[1] is None and I.op in ('mov', 'lea'):
                    info['declared_restore'] += 1
                else:
                    add('EXCURSION', g['name'], b.name, I.ln, '%s bytes=%s' % (I.text, '?' if I.eff[1] is None else I.eff[1]))
            if not live:
                continue
            owner = rows[r['owner']] if (r['owner'] is not None and 0 <= r['owner'] < len(rows)) else None
            xfer = r['kind'] in TRANSFER_KINDS
            based = owner is not None and armed(owner) and owner['kind'] in STATEMENT_ROOTS
            starts = []
            if a is not None:
                starts.append((a, ea(r)))
            bi = b.lab.get(b.beta)
            if bi is not None:
                starts.append((bi, xa(r)))
            for idx, st in starts:
                for kind, tgt, depth, ln in simulate(b, idx, st):
                    if kind in ('ind', 'jmp') and xfer and (kind == 'ind' or (tgt or '').startswith('LBL_')):
                        if depth is None or not based:
                            info['transfer_unchecked'] += 1
                        elif depth != ea(owner):
                            add('TRANSFER-POP', g['name'], b.name, ln, 'popped=%d wanted=%d' % (xa(r) - depth, xa(r) - ea(owner)))
                        else:
                            info['transfer_ok'] += 1
                        continue
                    m = PORT.match(tgt) if tgt else None
                    tb = ch.by_id.get(int(m.group(1))) if m else None
                    if tb is None or tb.name != 'n%s_%s_bx' % (m.group(1), m.group(2)):
                        info['edge_unchecked'] += 1
                        continue
                    trow = box_row[id(tb)][1]
                    want = (ea(trow) if m.group(3) == 'α' else xa(trow)) if armed(trow) else None
                    if r.get('retains_code') or trow.get('retains_code'):
                        info['edge_retaining'] += 1
                        add('RETAINING-EDGE', g['name'], b.name, ln, '%s retains=%s/%s' % (tgt, r.get('retains_code'), trow.get('retains_code')))
                    elif depth is None or want is None:
                        info['edge_unchecked'] += 1
                    elif depth != want:
                        add('EDGE', g['name'], b.name, ln, '%s have=%d want=%d' % (tgt, depth, want))
                    else:
                        info['edge_ok'] += 1
    by_code = {}
    for g, ch in paired:
        by_code[ch.code] = (g, ch)
    for tname, q in tabs.items():
        if len(q) < 4 or not q[0].isdigit() or q[3] not in by_code:
            continue
        g, ch = by_code[q[3]]
        n = int(q[0])
        enters = []
        for k in range(n):
            if 6 + 3 * k >= len(q):
                break
            m = SITE_ENT.match(q[4 + 3 * k])
            if not m or not q[5 + 3 * k].isdigit():
                continue
            w = int(q[5 + 3 * k])
            rule, depth, kind, ext = (w >> 16) & 255, w >> 32, w & 0xffff, (w >> 24) & 255
            rule_seen[rule] += 1
            if ext:
                info['ext_sites'] += 1
            ln, b = site_box.get(m.group(1), (0, None))
            if b is None:
                info['sites_outside_boxes'] += 1
                continue
            at = b.lab.get(m.group(1))
            if at is not None and at < len(b.ins) and b.ins[at].zsm:
                info['sites_zsm'] += 1
                continue
            r = box_row[id(b)][1]
            if kind & 0xff == 4:
                enters.append(r)
            elif kind & 0xff == 5 and enters:
                enters.pop()
            if rule == 5:
                add('RULE5', g['name'], b.name, ln, 'depth=%d' % depth)
            elif rule == 0 and armed(r) and depth != xa(r):
                add('SITE', g['name'], b.name, ln, 'rule=0 depth=%d want=%d' % (depth, xa(r)))
            elif rule in (1, 3) and depth != 0:
                add('SITE', g['name'], b.name, ln, 'rule=%d depth=%d want=0' % (rule, depth))
            elif rule == 2 and r.get('flat_gen_rbp') is not None:
                if depth != r['flat_gen_rbp']:
                    add('SITE', g['name'], b.name, ln, 'rule=2 depth=%d want=%d' % (depth, r['flat_gen_rbp']))
                else:
                    info['sites_ok'] += 1
            elif rule == 6:
                nl, ek = (kind >> 8) & 15, (kind >> 12) & 15
                if nl < 1 or nl > len(enters):
                    add('SITE', g['name'], b.name, ln, 'rule=6 nl=%d but %d match enter(s) are open' % (nl, len(enters)))
                else:
                    er = enters[-nl]
                    want = 0 if ek in (1, 3) else (xa(er) if armed(er) else None)
                    if want is None:
                        info['sites_unchecked'] += 1
                    elif depth != want:
                        add('SITE', g['name'], b.name, ln, 'rule=6 depth=%d want=%d (the owning enter nl=%d ek=%d)' % (depth, want, nl, ek))
                    else:
                        info['sites_ok'] += 1
            elif rule in SITE_GRADED - {5, 6}:
                info['sites_ok'] += 1
            else:
                info['ungraded_%d' % rule] += 1
    return found, info, rule_seen


def main(argv):
    p = argparse.ArgumentParser(add_help=True)
    p.add_argument('--asm', required=True)
    p.add_argument('--plan', required=True)
    p.add_argument('--classes', default=','.join(CLASSES + APART))
    p.add_argument('--show', type=int, default=-1)
    p.add_argument('--quiet', action='store_true')
    args = p.parse_args(argv)
    want = [c for c in args.classes.split(',') if c]
    for c in want:
        if c not in CLASSES + APART:
            print('unknown class ' + c + ' (the classes are ' + ','.join(CLASSES + APART) + ')', file=sys.stderr)
            return 2
    try:
        graphs = parse_plan(args.plan)
        chains, tabs, site_box = parse_asm(args.asm)
    except (OSError, ValueError) as e:
        print('util_zeta_layout_check: cannot read the inputs: %s' % e, file=sys.stderr)
        return 2
    found, info, rule_seen = check(graphs, chains, tabs, site_box)
    total = 0
    for c in CLASSES + APART:
        if c not in want:
            continue
        lines = found.get(c, [])
        total += len(lines) if c in CLASSES else 0
        if not args.quiet:
            for ln in (lines if args.show < 0 else lines[:args.show]):
                print(ln)
    if not args.quiet:
        for rule, n in sorted(rule_seen.items()):
            if rule in SITE_HOP:
                print('SITE-HOP rule=%d count=%d' % (rule, n))
            elif info['ungraded_%d' % rule]:
                print('SITE-UNGRADED rule=%d count=%d' % (rule, info['ungraded_%d' % rule]))
        if info['ext_sites']:
            print('SITE-UNGRADED ext=nonzero count=%d' % info['ext_sites'])
        for rule in SITE_RULES:
            if rule not in rule_seen:
                print('SITE-UNEXERCISED rule=%d' % rule)
        if info['gate_pairs']:
            print('GATE-PAIR count=%d' % info['gate_pairs'])
        if info['transfer_unchecked']:
            print('TRANSFER-UNCHECKED count=%d' % info['transfer_unchecked'])
    counts = ' '.join('%s=%d' % (c, len(found.get(c, []))) for c in CLASSES + APART) + ' GATE-PAIR=%d' % info['gate_pairs']
    if not args.quiet:
        print('summary graphs=%d chains=%d boxes=%d armed=%d no_alpha_label=%d rsp_writes=%d (carve=%d exit=%d spill_pops=%d restore=%d zsm=%d) edges(ok=%d unchecked=%d retaining=%d) transfers(ok=%d unchecked=%d) sites(graded_ok=%d outside=%d zsm=%d by_rule=%s)' % (
            len(graphs), len(chains), info['boxes'], info['armed'], info['no_alpha_label'], info['rsp_writes'], info['carve_writes'], info['exit_writes'], info['spill_pops'], info['declared_restore'], info['zsm_writes'], info['edge_ok'],
            info['edge_unchecked'], info['edge_retaining'], info['transfer_ok'], info['transfer_unchecked'], info['sites_ok'], info['sites_outside_boxes'], info['sites_zsm'],
            ','.join('r%d:%d' % (r, n) for r, n in sorted(rule_seen.items())) or 'none'))
    print('layoutcheck %s %s mismatches=%d' % (args.asm.rsplit('/', 1)[-1], counts, total))
    return 1 if total else 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
