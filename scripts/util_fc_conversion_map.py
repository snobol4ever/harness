#!/usr/bin/env python3
# util_fc_conversion_map.py -- RUNG ZB-FC: per-IR-kind FORTH conversion STATUS, derived from source.
#
# WHY THIS EXISTS.  "Is this kind converted to the rsp FORTH cell?" cannot be answered from fc_geom's
# registry, and a census of the FLAT-frame field map (scrip --dump-zeta) answers it WRONGLY -- it cannot see
# a kind converted by RETIRING its state instead of being granted a cell.  IR_MATCH_SEQUENCE is the trap:
# fc_geom never mentions it and --dump-zeta shows it owning locals, yet it is fully converted via
# fc_seq_active (ZB-FC-3b, "seq_i/delta retired; the LIFO stack position IS the element index").  A widening
# ladder ordered from the flat census therefore aims at already-converted kinds.  SIX mechanisms exist:
#   1 CELL        fc_geom grants a fixed cell (some arms conditional on fc_*_active / fc_alt_fpmax)
#   2 ZERO-LAW    owns no box-private RW scratch, so a ZERO cell IS its FORTH form -- nothing to convert
#   3 ZERO-RETIRE state retired outright (SEQUENCE: stack position replaces the index)
#   4 WINDOW      op_fc_wbytes partial window for a self-pushing box (HEAD); some fields stay FLAT BY DESIGN
#   5 XBOX-READ   op_fc_disp -- reads ANOTHER box's cell, owns none (ASSIGN_COND / ASSIGN_IMM)
#   6 TAIL        participates in a tail-granted statement (op_tail / op_defer_leaf_susp)
# Anything owning locals and matching none of these is UNCONVERTED and is real widening work.
#
# THIS IS A LEDGER, NOT A GATE -- same philosophy as util_fc_spine_census.sh.  It reads source, so it needs
# no build and no corpus.  Cross-check it against util_fc_spine_census.sh: every kind that shows CELL here
# should appear there with a nonzero push count, and vice versa.
import re, sys, os
ROOT = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))), "SCRIP")
ZS   = open(os.path.join(ROOT, 'src/planner/frame_layout.c')).read()
EM   = open(os.path.join(ROOT, 'src/emitter/emit.cpp')).read()
def body(src, start, end):
    i = src.index(start); j = src.index(end, i); return src[i:j]
def strip_comments(s): return re.sub(r'/\*.*?\*/', '', s, flags=re.S)
# ---- mechanism 1: fc_geom cell grants -------------------------------------------------------------------
fc = body(ZS, 'int fc_geom(const IR_t * nd, long * k)', '\n}')
cell = {}
for line in fc.split('\n'):
    l = strip_comments(line)
    for k in re.findall(r'op == (IR_[A-Z_0-9]+)', l):
        cond = re.search(r'fc_[a-z_]+_active\(nd\)|fc_alt_fpmax\(nd\) >= 0', l)
        cell[k] = cond.group(0) if cond else 'unconditional'
# ---- who owns box-private locals (a case arm that actually registers a field) ----------------------------
gl = strip_comments(body(ZS, 'static int zls_grant_locals', '\nstatic int zls_is_wiring'))
owns, pending = {}, []
for chunk in re.split(r'(case IR_[A-Z_0-9]+:)', gl)[1:]:
    m = re.fullmatch(r'case (IR_[A-Z_0-9]+):', chunk.strip())
    if m: pending.append(m.group(1)); continue
    if not chunk.strip(): continue   # fallthrough gap between stacked labels -- body belongs to ALL of them
    has = 'zls_field(' in chunk
    for k in pending: owns[k] = has
    pending = []
if re.search(r'nd->op == IR_CALL \|\| ir_is_call_kind', gl): owns['IR_CALL'] = True
# ---- mechanisms 3-6: what each emit.cpp arm engages ------------------------------------------------------
# an emit arm may span lines (ARBNO opens a block), so take each case label up to the NEXT label
EL = EM.split('\n')
starts = [(i, m.group(1)) for i, l in enumerate(EL) for m in [re.match(r'\s*case (IR_[A-Z_0-9]+):', l)] if m]
mech, bydesign = {}, {}
for n, (i, k) in enumerate(starts):
    arm = '\n'.join(EL[i:(starts[n + 1][0] if n + 1 < len(starts) else i + 1)])
    tags = []
    if 'op_fc_seq'    in arm: tags.append('ZERO-RETIRE (fc_seq_active)')
    if 'op_fc_wbytes' in arm: tags.append('WINDOW (op_fc_wbytes)')
    if 'op_fc_disp'   in arm: tags.append('XBOX-READ (op_fc_disp)')
    if 'op_tail = 1' in arm or 'op_defer_leaf_susp' in arm or 'fc_tail_' in arm: tags.append('TAIL')
    if tags: mech.setdefault(k, []).extend(tags)
    d = re.search(r'NO fc_geom BY DESIGN[^*]*', arm)
    if d: bydesign[k] = ' '.join(d.group(0).split())[:150]
# ---- classify -------------------------------------------------------------------------------------------
kinds = sorted(set(cell) | set(owns) | set(mech) | set(bydesign))
rows = []
for k in kinds:
    o = owns.get(k)
    if   k in cell:      st, d = 'CELL',         cell[k]
    elif k in bydesign:  st, d = 'NO-CONVERT',   bydesign[k]
    elif k in mech:      st, d = mech[k][0].split()[0], '; '.join(sorted(set(mech[k])))
    elif o is False:     st, d = 'ZERO-LAW',     'arm registers no field -- zero cell IS its FORTH form'
    elif o is True:      st, d = 'UNCONVERTED',  'owns locals, engages no FORTH mechanism'
    else:                st, d = 'n/a',          'no locals arm and no mechanism'
    rows.append((st, k, d))
order = {'UNCONVERTED': 0, 'NO-CONVERT': 0.5, 'WINDOW': 1, 'TAIL': 2, 'XBOX-READ': 3, 'ZERO-RETIRE': 4, 'CELL': 5, 'ZERO-LAW': 6, 'n/a': 7}
rows.sort(key=lambda r: (order.get(r[0], 9), r[1]))
w = max(len(r[1]) for r in rows)
print(f"{'STATUS':12} {'IR KIND':{w}}  DETAIL")
print('-' * (14 + w + 60))
for st, k, d in rows:
    if st == 'n/a': continue
    print(f"{st:12} {k:{w}}  {d}")
n_unconv = sum(1 for r in rows if r[0] == 'UNCONVERTED')
print(f"\nUNCONVERTED (real widening work): {n_unconv}")
print("NOTE: ZERO-LAW and ZERO-RETIRE are DONE -- nothing to convert.  WINDOW/TAIL/XBOX-READ are converted")
print("      forms too; a WINDOW box legitimately keeps some fields FLAT (see test_gate_fc_no_residual_rbp.sh).")
