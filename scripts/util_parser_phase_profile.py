#!/usr/bin/env python3
# util_parser_phase_profile.py -- the classifier behind util_parser_phase_profile.sh: reads ONE callgrind profile that holds only
# the parse clock's instructions (the shell's rt_time_ns toggle) and splits them into LEX, SYNTAX and TREE BUILD, with OUTSIDE (the
# dump, the quoting, the code generator and the tracer, which the clock should never reach) and UNCLASSIFIED named beside them.
#
#   util_parser_phase_profile.py annotate <in.s> <out.s>
#   util_parser_phase_profile.py report <callgrind.out> <chain.s> <map> <binary-basename> [topn]
#   util_parser_phase_profile.py compare <base.phases> <plant.phases> <phase-that-must-move>
#
# ⛔ ANNOTATE FIRST (measured 2026-09-30 on the snobol4 chain): a function's own code between its entry and its first statement box
# (FN__Reduce / Reduce_α_body / Reduce_α, the prologue) and after its last (RETURN_Reduce, NRETURN_Reduce, Reduce_res, Reduce_γ,
# Reduce_ω, the epilogue) carries only zero-size NOTYPE labels, and callgrind charges an instruction no sized function covers to the
# function that JUMPED there -- 16 nops planted at Reduce_α read +118128 in the parser's own call boxes (SYNTAX) and +0 in TREE.
# A JUMP TO ANY ADDRESS BUT A FUNCTION'S FIRST INSTRUCTION STAYS CHARGED TO THE JUMPER (measured the same day: covering those runs
# with sized symbols of their own moved nothing, because Reduce_α then sat inside Shift_res's run; callgrind treats a jump to a
# function's start as a call and any other jump as staying in the jumper), so a box's β, γ and ω ports -- reached by jumps from
# other boxes -- would be charged to the box that jumped. `annotate` therefore makes EVERY column-0 label in .text (a box, each of
# its ports, a function entry, an epilogue) the start of a sized @function running to the next such label, and drops the emitter's
# box-wide pairs; labels at one address leave the last of them sized. The symbol table changes and not one instruction does (the
# shell checks the .text bytes against the unannotated build), and it assembles the annotated .s for every run it profiles.
#
# THE RULES, IN ORDER (first match wins; a landing that changes one changes this file, so the diff names it):
#   1. EMITTED CODE (the object is the parser's own binary) is classed by its box kind, the symbol less its node number and port:
#        LEX       the leaf boxes -- match_span break breakx any notany lit len pos rpos tab rtab rem arb fail succeed abort bal
#        SYNTAX    the control boxes -- match_alternate arbno fence* defer begin end atp, disjunction, and the PAT$n / EXPR$n thunks
#                  (their prologues, exits and resume protocol)
#        TREE      the capture boxes -- match_assign_* (the . and $ writes that hand a token to Shift/Reduce) and match_replace
#      and every other emitted box (a statement of some function, or a function's own prologue and epilogue, named FN__<f>,
#      <f>_α_body, RETURN_<f>, NRETURN_<f>, <f>_res and the like) by the chain file that holds the function it belongs to -- the
#      file that declares `function <f>(` when the symbol names one, else the file of the .s's .loc line in effect at it:
#        TREE      counter.sc stack.sc tree.sc ShiftReduce.sc (Push, Pop, Shift, Reduce, the counters, tree() and its fields)
#        OUTSIDE   tdump.sc qize.sc gen.sc trace.sc
#        SYNTAX    everything else (parser_<lang>.sc's own functions, match.sc, assign.sc, semantic.sc, case.sc, global.sc, omega.sc)
#   2. RUNTIME CODE named by a family (RT below): the call road (rt_call_*, rt_defer_*, rt_dcap_*, rt_proc_*, the by-name dispatch)
#      is SYNTAX; the allocator, the collector, DATA and its fields, DATATYPE and the NV cell writes are TREE; the scanners are LEX.
#   3. EVERYTHING ELSE INHERITS: libc, the loader, a runtime helper no family names, and a bare address (a stub the runtime built at
#      run time) take the phases of their callers, each caller weighted by the inclusive cost callgrind recorded on that call arc,
#      walked up to eight callers deep (a recursion level, callgrind's name'2, is its function, and a function's arcs to itself
#      are no callers). The share that arrived this way is printed beside each phase ("inherited"), never hidden.
#      A cost whose callers never reach a classed symbol is UNCLASSIFIED and is printed by symbol.
import collections, re, sys

LEX_K = r'match_(span|break|breakx|any|notany|lit|len|pos|rpos|tab|rtab|rem|arb|fail|succeed|abort|bal)'
SYN_K = r'match_(alternate|arbno|fence\d*|defer|begin|end|atp)|disjunction|(FN__)?(PAT|EXPR)\$n|LT[px]\$n'
TREE_K = r'match_(assign_\w+|replace)'
FILE_PHASE = {'counter.sc': 'TREE', 'stack.sc': 'TREE', 'tree.sc': 'TREE', 'ShiftReduce.sc': 'TREE',
              'tdump.sc': 'OUTSIDE', 'qize.sc': 'OUTSIDE', 'gen.sc': 'OUTSIDE', 'trace.sc': 'OUTSIDE'}
RT = [
    ('LEX', r'rt_sxt_|rt_sg_scan|bb_match_(span|break|breakx|any|notany|lit|len|pos|rpos|tab|rtab)\b'),
    ('TREE', r'dat_|rt_gcheap_alloc|rt_str_alloc|rt_heap_alloc|rt_ws_alloc|gc_|rt_gc_(?!poll|point|cb_|runs_count)|bn_type_datatype|'
             r'bn_datatype|NV_SET|NV_CELL|rt_assign_var|rt_field_|rt_call_fld_|array_new|rt_ctor_|sno_array_from|c_rt_table_|table_|'
             r'rt_table_|rt_list_view|rt_data_is_record'),
    ('SYNTAX', r'rt_defer_|rt_call_|c_rt_call_|try_call_builtin|rt_proc_|proc_|rt_dcap_|rt_name_save|rt_name_restore|rt_nret_|'
               r'rt_dyn_alpha|rt_alpha_cell|rt_c2bb_|bb_|ab_cell|rt_eval_stage|rt_lvl_cell|rt_wn_|bid_of|rt_fire_buildplan|'
               r'sn4_is_system_fn|sn4_name_is_identifier|_func_hash|rt_cap_|rt_gva_cell'),
]
PHASES = ['LEX', 'SYNTAX', 'TREE', 'OUTSIDE', None]


def parse(path):
    """({fn: exclusive Ir}, {(caller, callee): inclusive Ir}, {fn: object}) from a callgrind profile with name compression"""
    names = {'fn': {}, 'ob': {}}

    def nm(kind, tok):
        m = re.match(r'\((\d+)\)(?: (.*))?$', tok)
        if not m:
            return tok
        if m.group(2) is not None:
            names[kind][m.group(1)] = m.group(2)
        return names[kind].get(m.group(1), m.group(1))
    selfc, arcs, objof = collections.Counter(), collections.Counter(), {}
    ob = fn = cfn = None
    pending = False
    for ln in open(path, errors='replace'):
        c = ln[:1]
        if c.isdigit() or c in '+-*':
            v = ln.split()
            if len(v) < 2:
                continue
            if pending:
                arcs[(fn, cfn)] += int(v[1])
                pending = False
            else:
                selfc[fn] += int(v[1])
        elif ln.startswith('fn='):
            fn = nm('fn', ln[3:].rstrip('\n'))
            objof[fn] = ob
        elif ln.startswith('ob='):
            ob = nm('ob', ln[3:].rstrip('\n'))
        elif ln.startswith('cob='):
            nm('ob', ln[4:].rstrip('\n'))
        elif ln.startswith('cfn='):
            cfn = nm('fn', ln[4:].rstrip('\n'))
        elif ln.startswith('calls='):
            pending = True
    return selfc, arcs, objof


def annotate(src, dst):
    """every column-0 label in .text starts a sized @function that runs to the next one; the emitter's own box-wide pairs go"""
    out, sec, cur, n_fn, n_drop = [], 'text', None, 0, 0
    lab = re.compile(r'([A-Za-z_$][^\s:#]*):(.*)$')
    data = re.compile(r'\.(byte|short|word|long|quad|zero|skip|ascii|asciz|string|octa)\b')
    boxfn = set()

    def close():
        nonlocal cur, n_fn
        if cur and cur[1]:
            out.insert(cur[0], '                        .type            %s, @function\n' % cur[2])
            out.append('                        .size            %s, .-%s\n' % (cur[2], cur[2]))
            n_fn += 1
        cur = None
    for ln in open(src, errors='surrogateescape'):
        ln = re.sub(r'\.LT([px]\d+)', r'LT\1', ln)
        st = ln.strip()
        m = re.match(r'\.(section\s+(\S+)|text\b|data\b|bss\b)', st)
        if m:
            sec = 'text' if (m.group(2) or m.group(1)).startswith(('.text', 'text')) else 'other'
            out.append(ln)
            continue
        m = re.match(r'\.type\s+([^,\s]+)\s*,\s*@function', st)
        if m:
            boxfn.add(m.group(1)); n_drop += 1
            continue
        m = re.match(r'\.size\s+([^,\s]+)\s*,', st)
        if m and m.group(1) in boxfn:
            continue
        if sec == 'text':
            m = lab.match(ln)
            if m and not m.group(1).startswith('.L'):
                close()
                rest = m.group(2).split('#', 1)[0].strip()
                cur = [len(out), bool(rest), m.group(1)]
                out.append(ln)
                continue
            if cur and not cur[1] and st and (not st.startswith(('.', '#')) or data.match(st)) and not re.match(r'\d+:\s*$', st):
                cur[1] = True
        out.append(ln)
    if cur and cur[1]:
        out.append('                        .text\n')
    close()
    open(dst, 'w', errors='surrogateescape').writelines(out)
    print('ANNOTATED %d sized function(s) from every text label; the emitter\'s %d box-wide pair(s) dropped' % (n_fn, n_drop))
    return 0


def line_of_symbol(sfile):
    """{emitted symbol: the .loc line in effect at its first instruction} from the mode-4 .s"""
    out, pend = {}, []
    last = None
    for ln in open(sfile, errors='replace'):
        m = re.match(r'\s+\.loc\s+1\s+(\d+)', ln)
        if m:
            last = int(m.group(1))
            for s in pend:
                out[s] = last
            pend = []
            continue
        m = re.match(r'([^\s#:.][^\s:]*):', ln)
        if m:
            pend.append(m.group(1))
    for s in pend:
        out[s] = last
    return out


def file_of_line(mapfile):
    """the map the shell wrote: 'range <file> <lo> <hi>' lines, one per chain file or per function body"""
    ranges = []
    for ln in open(mapfile):
        f = ln.split()
        if len(f) == 4 and f[0] == 'range':
            ranges.append((int(f[2]), int(f[3]), f[1]))
    ranges.sort(key=lambda r: (r[1] - r[0], r[0]))   # the narrowest range wins: a function body inside a file's span
    funcs = {}
    for ln in open(mapfile):
        f = ln.split()
        if len(f) == 3 and f[0] == 'func':
            funcs.setdefault(f[1], f[2])

    def look(line):
        if line is None:
            return '?'
        for lo, hi, name in ranges:
            if lo <= line <= hi:
                return name
        return '?'
    return look, funcs


def kind(sym):
    k = re.sub(r"'\d+$", '', sym)
    k = re.sub(r'^n\d+_', '', k)
    k = re.sub(r'^(FN__PAT|FN__EXPR|PAT|EXPR)\$\d+', r'\1$n', k)
    k = re.sub(r'^LT([px])\d+', r'LT\1$n', k)
    return re.sub(r'_(bx|α_body|α|β|γ|ω|res)$', '', k)


def report(cg, sfile, mapfile, binname, topn):
    selfc, arcs, objof = parse(cg)
    look, funcs = file_of_line(mapfile)
    lines = line_of_symbol(sfile)
    lang_file = next((l.split()[1] for l in open(mapfile) if l.startswith('lang ')), '?')

    def emitted(s):
        return (objof.get(s) or '').endswith('/' + binname)

    def classify(s):
        b = re.sub(r"'\d+$", '', s)
        ob = objof.get(s) or ''
        if emitted(s):
            k = kind(s)
            if re.fullmatch(LEX_K, k):
                return 'LEX'
            if re.fullmatch(SYN_K, k):
                return 'SYNTAX'
            if re.fullmatch(TREE_K, k):
                return 'TREE'
            m = re.fullmatch(r'(?:FN__|N?RETURN_)?(.+?)(?:_(?:α_body|α|β|γ|ω|res))?', b)
            f = funcs.get(m.group(1)) if m else None
            if not f:
                f = look(lines.get(b))
            if f == '?':
                f = lang_file
            return FILE_PHASE.get(f, 'SYNTAX')
        if re.search(r'/(libc|ld-linux|libm|libgcc|libstdc|vgpreload)', ob) or re.fullmatch(r'0x[0-9a-f]+', b):
            return 'INHERIT'
        for ph, rx in RT:
            if re.match(r'(?:' + rx + r')', b):
                return ph
        return 'INHERIT'
    def base(x):   # a recursion level (callgrind's name'2) is the same function for inheritance
        return re.sub(r"'\d+$", '', x)
    for s in list(objof):
        objof.setdefault(base(s), objof[s])
    syms = {base(x) for x in set(selfc) | {c for _, c in arcs} | {a for a, _ in arcs}}
    cls = {s: classify(s) for s in syms}
    callers = collections.defaultdict(collections.Counter)
    for (a, b), v in arcs.items():
        if base(a) != base(b):
            callers[base(b)][base(a)] += v
    memo = {}

    def resolve(s, depth, seen):
        s = base(s)
        c = cls.get(s)
        if c != 'INHERIT':
            return {c: 1.0}
        if s in memo:
            return memo[s]
        if depth > 8 or s in seen:
            return {None: 1.0}
        tot = sum(callers[s].values())
        if not tot:
            return {None: 1.0}
        out = collections.Counter()
        for a, v in callers[s].items():
            for ph, w in resolve(a, depth + 1, seen | {s}).items():
                out[ph] += w * v / tot
        if depth == 0:
            memo[s] = out
        return out
    phase, inh = collections.Counter(), collections.Counter()
    bysym = collections.defaultdict(collections.Counter)
    for s, v in selfc.items():
        label = kind(s) if emitted(s) else re.sub(r"'\d+$", '', s)
        for ph, w in resolve(s, 0, frozenset()).items():
            phase[ph] += v * w
            bysym[ph][label] += v * w
            if cls.get(base(s)) == 'INHERIT':
                inh[ph] += v * w
    tot = sum(selfc.values())
    print('TOTAL %d' % tot)
    for ph in PHASES:
        top = '  '.join('%s %.1f' % (k, 100 * v / tot) for k, v in bysym[ph].most_common(topn) if v * 1000 >= tot)
        print('PHASE %s %d %d %s' % (ph or 'UNCLASSIFIED', round(phase[ph]), round(inh[ph]), top))
    return 0


def compare(a, b, must):
    def load(p):
        out = {}
        for ln in open(p):
            f = ln.split()
            if f[:1] == ['TOTAL']:
                out['TOTAL'] = int(f[1])
            elif f[:1] == ['PHASE']:
                out[f[1]] = int(f[2])
        return out
    x, y = load(a), load(b)
    if not x or not y:
        print('PLANT REFUSE: a phase file is empty')
        return 2
    tol = max(1, x['TOTAL'] // 10000)   # a hundredth of a percent of the base: the layout of the planted binary may move a hash
    bad = []
    for ph in ['LEX', 'SYNTAX', 'TREE', 'OUTSIDE', 'UNCLASSIFIED']:
        d = y.get(ph, 0) - x.get(ph, 0)
        if ph == must:
            if d <= 0:
                bad.append('%s did not move (%+d)' % (ph, d))
        elif abs(d) > tol:
            bad.append('%s moved %+d (tolerance %d)' % (ph, d, tol))
    moved = ' '.join('%s %+d' % (ph, y.get(ph, 0) - x.get(ph, 0)) for ph in ['LEX', 'SYNTAX', 'TREE', 'OUTSIDE', 'UNCLASSIFIED'])
    print(('PLANT OK' if not bad else 'PLANT FAIL') + ' [%s planted]: %s%s' % (must, moved, ('  -- ' + '; '.join(bad)) if bad else ''))
    return 1 if bad else 0


if __name__ == '__main__':
    if len(sys.argv) == 4 and sys.argv[1] == 'annotate':
        sys.exit(annotate(sys.argv[2], sys.argv[3]))
    if len(sys.argv) >= 6 and sys.argv[1] == 'report':
        sys.exit(report(sys.argv[2], sys.argv[3], sys.argv[4], sys.argv[5], int(sys.argv[6]) if len(sys.argv) > 6 else 8))
    if len(sys.argv) == 5 and sys.argv[1] == 'compare':
        sys.exit(compare(sys.argv[2], sys.argv[3], sys.argv[4]))
    print(__doc__ or 'usage: report <cg> <s> <map> <binary> [topn] | compare <base> <plant> <PHASE>')
    sys.exit(2)
