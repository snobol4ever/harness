#!/usr/bin/env python3
# pl_quad_regs_scan.py -- the analysis half of test_gate_pl_quad_regs.sh, THE QUAD GATE (hq_P 2026-09-02; row
# prolog-quad-gate-no-r12-r15-write-outside-tr-b-root-ball; ARCH-PROLOG-BYRD-BOX-TRANSLATION.md § E instrument lane).
#
# THE CONTRACT BEING CHECKED (Lon's grant, ARCH-PROLOG-BYRD-BOX-TRANSLATION.md top table): in a Prolog graph
#   r12 = TR   the trail (Prolog's C.A.S.)      r13 = B    the youngest live choice frame
#   r14 = ROOT the ζ-STANDING record            r15 = the ball in flight, or 0
# are LIVE FOR THE WHOLE RUN.  Any instruction that writes one of them outside the helpers that own the role (the ROOT
# seeds, the B landings/cut restore, the TR unwind/bump, the BALL set/clear) silently corrupts engine state -- the
# rung-2.0 scratch class (`bb_call_fn.cpp lea r12,[rip+...]`) that the cut deleted and this instrument keeps deleted.
#
# WHAT IT DOES.  For each emitted mode-4 .s (Intel syntax, as SCRIP --compile writes it): every instruction whose
# destination is r12..r15 under ANY width alias (r13, r13d, r13w, r13b, r13l) is a WRITE.  Each write is attributed to
# its SITE -- the driver block (`main:` up to the root graph's α), the root graph's seed (that α up to `<root>_α_body:`),
# or the enclosing box `nN_<kind>` and port segment (α/β/γ/ω) / function -- and matched against ENROLLED, the explicit
# per-register shape table below.  A write that matches no enrolled shape is a VIOLATION.  Then the runtime asm the
# program can reach is scanned the same way: every `call`/`jmp` target the .s names that is defined by RTX_FUNC in
# --rtx-dir, closed transitively over the rtx tree's own calls/jmps; a write inside a reachable routine is a violation
# unless the routine is a TR helper by name, or the write is bracketed by that routine's own push/pop of the register
# (a preserved scratch use is invisible to the caller and is printed as such, never as clean-by-omission).
#
# FAIL-CLOSED ON WHAT IT DOES NOT KNOW: an instruction it cannot classify whose FIRST operand is a quad register is
# reported as a write with shape `?<mnemonic>` -- which no table entry matches, so the unknown is loud, never silent.
#
# WHAT IT CANNOT SEE (an instrument's blind spots are part of its result): mode-4 TEXT only (MODES MAY DIVERGE: this
# verdict names its mode and does not bind mode 3); C runtime code is NOT scanned -- r12..r15 are callee-saved under
# SysV, so every C service preserves them for free (ARCH rule (1)); indirect `call rax`/`jmp rax` targets are not
# followed; a polyglot boundary (.scrip entering SNOBOL4/Icon) is out of population.
#
# ENROLLING A NEW WRITER (the ONE legitimate way this gate goes green again after a rung adds a B/TR/BALL writer):
# add ONE line to ENROLLED naming the register, the site condition and the exact shape, citing the ARCH section that
# rules it.  Never widen a shape to "any write in box kind X" -- that re-admits the scratch class by the back door.
#
# usage: pl_quad_regs_scan.py [--rtx-dir DIR] [--rtx-scan-all] [--tr-helper-rx RX] file.s ...
#   --tr-helper-rx RX (or env QUAD_HELPER_RX): the rtx ROUTINE names that ARE the TR helper -- a whole asm routine whose job is
#   to write the trail is the helper by definition, so for rtx the unit of enrolment is the routine NAME; for emitted code it is
#   never a name, always a (site, register, shape) row of ENROLLED.
# exit: 0 clean · 1 violations · 2 could not measure (no readable input).  One line per write, then a summary line
# `quad-scan: files=N writes=W enrolled=E violations=V rtx-defined=D rtx-reachable=R rtx-writes=X rtx-violations=Y`.
import re, sys, os, glob
QUAD  = {'r12': 'TR', 'r13': 'B', 'r14': 'ROOT', 'r15': 'BALL'}
ALIAS = re.compile(r'^r(1[2-5])(?:d|w|b|l)?$')
LBL   = re.compile(r'^([A-Za-z_.$][\w.$αβγω]*):\s*(.*)$')
BOXTY = re.compile(r'^\s*\.type\s+(n\d+)_([\w$]+?)_bx\s*,\s*@function')
PORT  = re.compile(r'^(n\d+)_([\w$]+?)_([αβγω])(?:_|$)')
RTXF  = re.compile(r'^\s*RTX_FUNC\((\w+)\)')
RTXE  = re.compile(r'^\s*RTX_ENDF\((\w+)\)')
XFER  = re.compile(r'^(?:call|jmp)\s+\**([A-Za-z_][\w.$]*)(?:@\w+)?$')
MEMFR = re.compile(r'^(?:qword\s+ptr\s+)?\[\s*(rbp|rsp|r13)\s*(?:[+-]\s*\d+)?\s*\]$')
R12B  = re.compile(r'^\[\s*r12\s*[+-]\s*\d+\s*\]$')
RSPB  = re.compile(r'^(?:qword\s+ptr\s+)?\[\s*rsp\s*(?:[+-]\s*\d+)?\s*\]$')
RCX   = {'rcx', 'ecx', 'cx', 'cl', 'ch'}
RCXIMP = {'loop', 'loope', 'loopne', 'loopz', 'loopnz', 'cpuid', 'rdtscp', 'syscall', 'call'}
DISJ_OPEN_KINDS = {'bound', 'to', 'disjunction'}
READ_FIRST = {'cmp', 'test', 'push', 'bt', 'jmp', 'call', 'ret', 'mul', 'div', 'idiv', 'ud2', 'int3', 'nop', 'endbr64'}
PREFIX = {'rep', 'repe', 'repz', 'repne', 'repnz', 'lock', 'notrack', 'bnd'}
def canon(tok):
    m = ALIAS.match(tok.strip().lower()); return 'r' + m.group(1) if m else None
def statements(raw):
    s = raw.strip()
    if not s or s.startswith('.') or s.startswith('#'): return []
    s = s.split('#', 1)[0]
    return [t.strip() for t in s.split(';') if t.strip()]
def parse_insn(st):
    toks = st.split(None, 1); mn = toks[0].lower()
    if mn in PREFIX and len(toks) > 1: return parse_insn(toks[1])
    ops = [o.strip() for o in toks[1].split(',')] if len(toks) > 1 else []
    return mn, ops
def writes_of(mn, ops):
    if not ops or mn in READ_FIRST: return []
    if mn == 'imul' and len(ops) == 1: return []
    out = []; d = canon(ops[0])
    if d: out.append(d)
    if mn == 'xchg' and len(ops) > 1:
        d2 = canon(ops[1]); d2 and out.append(d2)
    return out
KNOWN = {'mov', 'movabs', 'lea', 'movsx', 'movsxd', 'movzx', 'add', 'sub', 'adc', 'sbb', 'and', 'or', 'xor', 'shl', 'shr', 'sar', 'rol', 'ror',
         'imul', 'inc', 'dec', 'neg', 'not', 'pop', 'xchg', 'bsf', 'bsr', 'popcnt', 'lzcnt', 'tzcnt', 'cmpxchg', 'btc', 'btr', 'bts'} \
        | {'cmov' + c for c in 'e ne z nz a ae b be g ge l le s ns o no p np c nc'.split()} | {'set' + c for c in 'e ne z nz a ae b be g ge l le s ns o no p np c nc'.split()}
def norm(mn, ops): return mn + (' ' + ', '.join(re.sub(r'\s+', ' ', o) for o in ops) if ops else '')
def rcx_written(mn, ops, rep):
    if rep or mn in RCXIMP: return True
    if not ops or mn in READ_FIRST: return False
    return ops[0].strip().lower() in RCX or (mn == 'xchg' and len(ops) > 1 and ops[1].strip().lower() in RCX)
def enrolled(site, reg, mn, ops, kind, seg, rcx_h=False):
    both = len(ops) == 2 and canon(ops[0]) == reg and canon(ops[1]) == reg
    if mn not in KNOWN: return None
    if site == 'driver': return 'ROOT/driver-seed'
    if site == 'graph' and kind is None and reg == 'r13' and mn == 'lea' and len(ops) == 2 and RSPB.match(ops[1]):
        return 'B/choice-open B:=H in the pinned prologue (ARCH-PROLOG-C-OUT-OF-THE-BOX § 2.2)'
    if site == 'box' and kind in DISJ_OPEN_KINDS and seg == 'α' and reg == 'r13' and mn == 'mov' and len(ops) == 2 and ops[1] == 'rcx' and rcx_h:
        return 'B/disj-open take B:=H, rcx the lea of this frame header (ARCH-PROLOG-C-OUT-OF-THE-BOX § 2.2)'
    if site == 'rootseed':
        if reg == 'r13' and mn == 'xor' and both: return 'ROOT/seed B=0 (ARCH § A.1)'
        if reg == 'r15' and mn == 'xor' and both: return 'ROOT/seed ball=0 (ARCH § A.1)'
        if reg == 'r14' and ((mn == 'lea' and len(ops) == 2 and MEMFR.match(ops[1])) or (mn == 'mov' and len(ops) == 2 and ops[1] in ('rsp', 'rbp'))): return 'ROOT/seed r14=H (ARCH § A.1)'
        return None
    if len(ops) == 2:
        if reg == 'r13' and mn == 'mov' and (ops[1] == 'rbp' or MEMFR.match(ops[1])): return 'B/landing-or-cut restore (ARCH § A.1)'
        if reg == 'r12' and mn == 'mov' and MEMFR.match(ops[1]): return 'TR/unwind-to-mark (ARCH § A.1 F.TRMARK)'
        if reg == 'r12' and mn in ('add', 'sub') and ops[1].isdigit(): return 'TR/bump (ARCH top table)'
        if reg == 'r12' and mn == 'lea' and R12B.match(ops[1]): return 'TR/bump (ARCH top table)'
        if reg == 'r15' and kind and 'catch' in kind and seg == 'β' and mn == 'xor' and both: return 'BALL/catch-clear (ARCH § B.10)'
        if reg == 'r15' and kind and 'throw' in kind and mn == 'mov': return 'BALL/throw-set (ARCH § B.10)'
    return None
def scan_program(path):
    try: lines = open(path, encoding='utf-8', errors='replace').read().split('\n')
    except OSError as e: return None
    site = 'graph'; kind = None; seg = None; driver_on = False; root = None; rootseed_on = False; func = '?'
    targets = set(); rows = []; last_driver_jmp = None; rcx_h = False
    for ln, raw in enumerate(lines, 1):
        rest = raw
        m = LBL.match(raw.lstrip())
        if m:
            lab, rest = m.group(1), m.group(2)
            if not lab.startswith('.L'): rcx_h = False
            if lab == 'main': driver_on = True; site = 'driver'; func = 'main'; kind = None; seg = None
            elif root and lab == root + '_α': rootseed_on = True; driver_on = False; site = 'rootseed'; func = lab
            elif rootseed_on and (lab == root + '_α_body' or PORT.match(lab) or lab.startswith('FN__')): rootseed_on = False; site = 'graph'
            pm = PORT.match(lab)
            if pm: kind = pm.group(2); seg = pm.group(3); site = 'box' if site not in ('driver', 'rootseed') else site
            elif lab.startswith('FN__'): func = lab; kind = None; seg = None; site = 'graph' if site not in ('driver', 'rootseed') else site
        bm = BOXTY.match(raw)
        if bm: kind = bm.group(2); seg = None; rcx_h = False
        for st in statements(rest):
            mn, ops = parse_insn(st)
            rep = st.split(None, 1)[0].lower().startswith('rep')
            xm = XFER.match(norm(mn, ops))
            if xm:
                t = xm.group(1).split('@')[0]
                if not t.startswith('.L'): targets.add(t)
                if driver_on and mn == 'jmp' and not t.startswith('.L'): last_driver_jmp = t
            if driver_on and mn == 'jmp' and last_driver_jmp and last_driver_jmp.endswith('_α'):
                root = last_driver_jmp[:-2]; driver_on = False; site = 'driver-done'
            for reg in writes_of(mn, ops):
                if reg not in QUAD: continue
                shape = norm(mn, ops) if mn in KNOWN else '?' + norm(mn, ops)
                where = site if site != 'driver-done' else 'graph'
                cls = enrolled(where, reg, mn, ops, kind, seg, rcx_h)
                loc = f'{where}' + (f' {func}' if where in ('driver', 'rootseed') else (f' box={kind}_{seg or "?"}' if kind else f' fn={func}'))
                rows.append((cls is None, f'{os.path.basename(path)}:{ln}', reg, loc, shape, cls))
            if rcx_written(mn, ops, rep):
                fm = MEMFR.match(ops[1]) if mn == 'lea' and len(ops) == 2 and ops[0].strip().lower() == 'rcx' else None
                rcx_h = bool(fm and fm.group(1) in ('rbp', 'rsp'))
    return rows, targets
def scan_rtx(rtx_dir):
    funcs = {}
    for f in sorted(glob.glob(os.path.join(rtx_dir, 'rtx_*.s')) + glob.glob(os.path.join(rtx_dir, 'rtx_*.S'))):
        cur = None
        for ln, raw in enumerate(open(f, encoding='utf-8', errors='replace').read().split('\n'), 1):
            fm = RTXF.match(raw)
            if fm: cur = fm.group(1); funcs[cur] = {'file': os.path.basename(f), 'calls': set(), 'writes': [], 'push': {}, 'pop': {}}; continue
            if RTXE.match(raw): cur = None; continue
            if cur is None: continue
            for st in statements(raw):
                mn, ops = parse_insn(st)
                xm = XFER.match(norm(mn, ops))
                if xm and not xm.group(1).startswith('.L'): funcs[cur]['calls'].add(xm.group(1).split('@')[0])
                if mn == 'push' and ops and canon(ops[0]): funcs[cur]['push'][canon(ops[0])] = funcs[cur]['push'].get(canon(ops[0]), 0) + 1
                if mn == 'pop' and ops and canon(ops[0]): funcs[cur]['pop'][canon(ops[0])] = funcs[cur]['pop'].get(canon(ops[0]), 0) + 1
                for reg in writes_of(mn, ops):
                    if reg in QUAD: funcs[cur]['writes'].append((ln, reg, mn, norm(mn, ops) if mn in KNOWN else '?' + norm(mn, ops)))
    return funcs
TR_HELPER = re.compile(os.environ.get('QUAD_HELPER_RX') or r'^(?:rt_pl_quad_seed|rt_pl_tr_unwind|rt_pl_choice_open|rt_pl_disj_open|rt_pl_cut_barrier|rt_pl_fence_commit|rt_pl_throw_raise|rt_pl_exist_raise|rt_pl_exist_key_raise|rt_pl_goal_gen_h|rt_pl_ball_take|rt_pl_catch_handle|rt_pl_dop_db_alive|rt_pl_ax_cold|rt_pl_cmp_cold|rt_pl_is_cold|rt_pl_zguard_cold|rt_pl_anum_cold|rt_pl_dop_nb_getval_guard|rt_pl_dop_char_guard|rt_pl_dop_between_guard|rt_pl_dop_stream_guard|rt_pl_dop_curstream_guard|rt_pl_dop_goal_guard|rt_pl_dop_list_guard|rt_pl_dop_db_t_guard|rt_pl_dop_pl_cp_guard|rt_pl_dop_halt|rt_pl_dop_unify(?:_ci|_ca)?|rt_pl_dop_clause_unify|rt_pl_dop_mkc|rt_pl_dop_(?:compare|functor|arg|univ|copy_term|numbervars3|numbervars1|succ|plus|sort|msort|char_type|term_string|atom_length|atom_concat|atom_chars|atom_codes|atom_number|atom_string|upcase_atom|downcase_atom|string_concat|string_length|string_lower|string_upper|string_to_atom|number_string|atomic_list_concat|concat_atom|char_code|number_codes|number_chars|name|get_char|peek_char|read|atom_to_term|read_s|get_char_s|peek_char_s|current_output|current_input|open|open4|keysort|format3))$')  # THE ONE ALLOW-LIST, exact names (rung 1, hq_C): rt_pl_quad_seed seeds r12 TR / r13 B / r14 ROOT / r15 BALL from the root graph's pinned prologue; rt_pl_disj_open (rung 3) writes F.HI at [H+32] and raises r13 to H only when the live choice is older than this frame or absent, so an inline disjunction is a choice without a frame of its own; rt_pl_cut_barrier (rung 4) restores B from F.B0 at [H+24] -- the WAM B <- B0 barrier, the cut box's only quad write; the four binder gates of rtx_plunify.s park {r12,r13} in a ctx for their C bodies and reload r12 on return. rung 9 (hq_C) adds the four BALL helpers, the only writers of r15 outside the root seed: rt_pl_throw_raise and rt_pl_exist_raise set it from a heap-copied ball and return DT_FAIL so the calling box takes omega; rt_pl_catch_handle tests it, unifies the catcher and clears it on a catch; rt_pl_ball_take hands it to the root omega and zeroes it. THE GATE CAUGHT ALL FOUR UNENROLLED ON THE FIRST make test OF THE RUNG -- they are NAMED here, never relaxed. rung 10b (hq_C) adds ONE more r15 writer, rt_pl_dop_db_alive: a call to a predicate that abolish/1 has removed must raise existence_error(procedure, N/A) at the CALL, not fail silently, so the leaf sets r15 from the heap ball and returns DT_FAIL exactly as rt_pl_exist_raise does -- same shape, different producer tag (MOD_OP 146), enrolled here by name. Task prolog-builtins-fail-silently-instead-of-throwing-iso-type-errors (seat02) adds FOUR more, same shape as rt_pl_dop_ax_zguard, each a pre-check guard leaf inserted by the lowerer before the real call rather than a runtime policy change: rt_pl_dop_char_guard (put_char/1 argument must be a one-character atom -- type_error(character,_) else), rt_pl_dop_between_guard (between/3 Low/High/X -- instantiation_error or type_error(integer,_)), rt_pl_dop_stream_guard (set_output/1, set_input/1 -- instantiation_error / existence_error(stream,_) / domain_error(stream_or_alias,_) / permission_error(output|input,stream,_)), rt_pl_dop_curstream_guard (current_output/1, current_input/1 -- domain_error(stream,_) for a non-stream-shaped bound argument). A rung that adds a writer adds its exact name here; ISO sec 8.16/8.5 argument validation (hq_R) adds THREE more of the identical shape -- rt_pl_dop_anum_guard2/3/5, the arity-split veneers behind the one pl_anum_check() checker for atom_chars/atom_codes/number_chars/number_codes/char_code/atom_length/atom_concat/sub_atom and arg/3 + functor/3 -- and rung 10 (seat10) adds rt_pl_dop_nb_getval_guard for nb_getval/2 on an unset key. All four set r15 from a heap ball and return DT_FAIL exactly as rt_pl_dop_ax_zguard does. ⛔ THEY LANDED UNENROLLED AND THE GATE WAS RED ON ORIGIN UNTIL 2026-09-06 (ceo CEO-312 named the four line numbers): the writer was added and its name was not, which is the exact debt the sentence before this one exists to prevent -- recorded rather than silently enrolled, because the gate did its job and the landing did not do its half. The all-solutions goal-conversion landing (hq_R, ISO sec 7.6.2 / 8.10) adds ONE more of that same shape, rt_pl_dop_goal_guard -- the Goal argument of findall/3 bagof/3 setof/3, instantiation_error on an unbound goal and type_error(callable,_) on a non-callable one, r15 from a heap ball and DT_FAIL, MOD_OP 221. Enrolled by hq_R in the arith-catchable landing; env QUAD_HELPER_RX overrides for a measurement. TWO MORE, BOTH LANDED 2026-09-13 AND NEITHER ENROLLED, so this gate was RED ON ORIGIN FOR SEVEN DAYS (coo, measured 2026-09-20: the allow-list's last touch was 187392071 on 09-12, both writers are newer) -- the exact debt the CEO-312 sentence above exists to prevent, arriving a third time: rt_pl_fence_commit (rtx_plunify.s:35, SCRIP 4a9404cdb, rung 9's opaque-goal barrier) writes r13 with `mov r13, rdi` -- byte-identical to the enrolled rt_pl_choice_open two routines above it in the same file, and its own commit message names the write: THE FENCE BANKS B and commits to it at gamma, so banking B IS writing r13; rt_pl_dop_list_guard (rtx_plunify.s:450, SCRIP 926628d49) sets r15 from the heap ball its C helper returned and returns DT_FAIL -- byte-identical to the enrolled rt_pl_dop_goal_guard IMMEDIATELY ABOVE IT, the same PL_CTX_LEAF_BALL protocol 187392071 enrolled its three siblings under. ⛔ ENROLLED BY NAME, NOT RELAXED: the criterion is untouched, the two canaries still prove the scan reds on an injected scratch write and on a reachable rtx write, and a rung that adds a writer still adds its exact name here. ⭐ THE SHAPE IS NOW MEASURED, NOT ANECDOTAL: three separate landings have added a quad writer without its name (CEO-312's four, 187392071's three, these two), so the omission is structural -- the allow-list is edited in a file no Prolog landing opens, which is why NOT editing it is the default outcome. R7 OF THE PROLOG REWRITE (hq_prolog 2026-09-26, ARCH-PROLOG-BB-REWRITE.md section 11, row prolog-bb-is-2-comparison-and-type-tests-compute-inline-in-the-box-for-the-small-integer-case-with-an-asm-leaf-behind-them): rt_pl_dop_is_v, rt_pl_dop_ax_zguard and rt_pl_dop_anum_guard2/3/5 are DELETED, because is/2, the arithmetic operators, the comparisons, the type tests and the ISO argument guards are now decided inline in the box for the small-integer case (src/templates/bb/bb_call_pl_leaf.cpp); the five cold value services behind those inline arms -- rt_pl_ax_cold, rt_pl_cmp_cold, rt_pl_is_cold, rt_pl_zguard_cold, rt_pl_anum_cold (rtx_plunify.s, the PL_COLD_* macros) -- set r15 from the heap ball and return DT_FAIL exactly as the veneers they replace did, and are enrolled here by name in the same landing; rt_pl_type_cold and rt_pl_atop_cold raise nothing and write no quad. R1 OF THE REWRITE (hq_prolog 2026-09-27, ARCH-PROLOG-BB-REWRITE.md section 3): a head constant that is an atom unifies through rt_pl_dop_unify_ca, the atom-id twin of rt_pl_dop_unify_ci -- the same four-instruction ctx park of {r12,r13} around its C body and the same reload of r12 on return, enrolled here by name in the landing that adds it; rt_pl_dop_unify_cs, the C-string twin it replaces, is deleted in the same landing (no head constant reaches it once an atom is an id).
def main(argv):
    global TR_HELPER
    rtx_dir = None; scan_all = False; files = []
    i = 0
    while i < len(argv):
        a = argv[i]
        if a == '--rtx-dir': rtx_dir = argv[i + 1]; i += 2; continue
        if a == '--rtx-scan-all': scan_all = True; i += 1; continue
        if a == '--tr-helper-rx': TR_HELPER = re.compile(argv[i + 1]); i += 2; continue
        files.append(a); i += 1
    if not files: print('quad-scan: REFUSE(2) no input .s files'); return 2
    nfiles = 0; writes = 0; enr = 0; viol = 0; alltargets = set()
    for p in files:
        r = scan_program(p)
        if r is None: print(f'quad-scan: cannot read {p}'); continue
        rows, targets = r; nfiles += 1; alltargets |= targets
        for bad, loc, reg, site, shape, cls in rows:
            writes += 1
            if bad: viol += 1; print(f'VIOLATION  {loc:<44} {reg}({QUAD[reg]})  {site:<40} {shape}')
            else: enr += 1; print(f'ok         {loc:<44} {reg}({QUAD[reg]})  {site:<40} {shape}   [{cls}]')
    if nfiles == 0: print('quad-scan: REFUSE(2) no readable input .s files'); return 2
    rdef = rreach = rwr = rviol = 0
    if rtx_dir:
        funcs = scan_rtx(rtx_dir); rdef = len(funcs)
        if rdef == 0: print(f'quad-scan: REFUSE(2) no RTX_FUNC routines found under {rtx_dir}'); return 2
        reach = set(t for t in alltargets if t in funcs) if not scan_all else set(funcs)
        todo = list(reach)
        while todo:
            f = todo.pop()
            for c in funcs[f]['calls']:
                if c in funcs and c not in reach: reach.add(c); todo.append(c)
        rreach = len(reach)
        for f in sorted(reach):
            fn = funcs[f]
            for ln, reg, mn, shape in fn['writes']:
                rwr += 1; loc = f"{fn['file']}:{ln}"
                if TR_HELPER.match(f): print(f'ok         {loc:<44} {reg}({QUAD[reg]})  rtx={f:<34} {shape}   [TR/helper by name]')
                elif fn['push'].get(reg, 0) and fn['pop'].get(reg, 0): print(f'ok         {loc:<44} {reg}({QUAD[reg]})  rtx={f:<34} {shape}   [preserved: push/pop bracket in the routine]')
                else: rviol += 1; print(f'VIOLATION  {loc:<44} {reg}({QUAD[reg]})  rtx={f:<34} {shape}')
        print(f'rtx reachable from the population: ' + (', '.join(sorted(reach)) if reach else '(none)'))
    print(f'quad-scan: files={nfiles} writes={writes} enrolled={enr} violations={viol} rtx-defined={rdef} rtx-reachable={rreach} rtx-writes={rwr} rtx-violations={rviol}')
    return 1 if (viol or rviol) else 0
if __name__ == '__main__': sys.exit(main(sys.argv[1:]))
