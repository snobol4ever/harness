#!/usr/bin/env python3
"""util_rbp_region_census.py -- FLATDISP-9: classify every rbp reference by whether the
enclosing GRAPH REGION's prologue actually SEEDED rbp (`mov rbp, rsp`).

WHY THIS EXISTS.  test_gate_rbp_census_ratchet.sh counts rbp references per FILE.  That was
the right instrument while the frame base was a BUILD CONSTANT, because then every rbp
reference in the tree belonged to one global decision and a falling count meant real
progress.  FLATDISP-8 (s197) made the base PER-GRAPH -- rbp for graphs whose prologue pins
it, rsp for depth-static determinate ones -- so a file-level count now moves whenever the
pin CLASSIFICATION legitimately changes, in either direction, with no defect either way.
A count that moves for correct reasons cannot ratchet.

THE SPLIT.  For each region (a `proc_*_alpha:` / `main:` entry through the next such entry):
  SEEDED   -- the prologue emits `mov rbp, rsp`.  rbp IS this activation's frame base and is
              depth-immune; every [rbp+N] in the region is the pinned frame model working as
              designed.  NO frame-pointer rung can remove these -- same argument the ratchet
              already accepts for CLASS D scratch loads -- so counting them makes zero
              unreachable and the gate meaningless.
  UNSEEDED -- the prologue never established rbp, so rbp holds the CALLER's value.  Any
              [rbp+N] frame reference here names a base this activation never set up: it
              reads the caller's frame.  THIS IS THE DEFECT CLASS -- exactly the s188/s189
              drift (accessors stopped naming the base the prologue established) that cost
              Icon 250->236, SNOBOL4 295/294->221/219 and Prolog 164->120 before s197.
              The correct count is ZERO and it is a real zero-assert.

CLASS D (`mov rbp, <non-rsp base>` scratch loads) and the save/seed/restore CEREMONY itself
are excluded from both counts: ceremony is not a frame reference.
"""
import re, sys, os, subprocess, tempfile

REGION_RE = re.compile(r'^([A-Za-z_$.][A-Za-z0-9_$.\u03b1-\u03c9]*):')
ENTRY_RE  = re.compile(r'^(proc_.*_\u03b1|main|main_init)\s*:')
SEED_RE   = re.compile(r'\bmov\s+rbp\s*,\s*rsp\b')
CLASSD_RE = re.compile(r'\bmov\s+rbp\s*,\s*(qword ptr\s*)?\[r(ax|bx|cx|dx|si|di|8|9|1[0-5])')
# ceremony: caller-rbp save into the header pad, the seed, the restores, push/pop
CEREM_RE  = re.compile(r'\bmov\s+\[rsp\s*\+\s*\d+\]\s*,\s*rbp\b|\bmov\s+rbp\s*,\s*rsp\b|'
                       r'\bmov\s+rbp\s*,\s*\[rbp\s*[+-]\s*\d+\]|\b(push|pop)\s+rbp\b')
# A FRAME REFERENCE is rbp used as a memory BASE -- [rbp + N] / [rbp - N].  rbp read or
# written as a plain register VALUE is not a frame reference: CLASS D (`mov rbp,[gpr+N]`,
# scratch destination) and the wire-adopt marshal (`mov rcx, rbp`, the depth-static arm
# deliberately passing the caller's LIVE rbp because no [kt-8] save slot exists -- see
# bb_define.cpp role 3) both read/write the register without naming a frame.  Counting
# either makes zero unreachable, which is the exact failure mode this instrument replaces.
RBP_RE    = re.compile(r'\[\s*rbp\s*[+\-\]]')

def regions(lines):
    """Yield (name, [lines]) for each graph region, splitting at entry labels."""
    cur, name, out = [], None, []
    for ln in lines:
        m = ENTRY_RE.match(ln.strip())
        if m:
            if name is not None:
                out.append((name, cur))
            name, cur = m.group(1), [ln]
        else:
            if name is None:
                name, cur = '<preamble>', []
            cur.append(ln)
    if name is not None:
        out.append((name, cur))
    return out

def census(path):
    lines = open(path, encoding='utf-8', errors='replace').read().splitlines()
    seeded_refs = unseeded_refs = 0
    offenders = []
    for name, body in regions(lines):
        seeded = any(SEED_RE.search(l) for l in body)
        for l in body:
            if not RBP_RE.search(l):
                continue
            if CLASSD_RE.search(l) or CEREM_RE.search(l):
                continue
            if seeded:
                seeded_refs += 1
            else:
                unseeded_refs += 1
                offenders.append((name, l.strip()))
    return seeded_refs, unseeded_refs, offenders

def main():
    scrip = os.environ.get('SCRIP', './scrip')
    files = sys.argv[1:]
    tot_s = tot_u = 0
    all_off = []
    for f in files:
        if f.endswith('.s'):
            sp = f
            tmp = None
        else:
            tmp = tempfile.NamedTemporaryFile(suffix='.s', delete=False)
            tmp.close()
            with open(tmp.name, 'w') as fh:
                subprocess.run([scrip, '--compile', f], stdout=fh,
                               stderr=subprocess.DEVNULL, timeout=120)
            sp = tmp.name
        s, u, off = census(sp)
        tot_s += s
        tot_u += u
        for o in off:
            all_off.append((os.path.basename(f),) + o)
        print("%-26s seeded=%-5d unseeded=%-4d %s" %
              (os.path.basename(f), s, u, 'OK' if u == 0 else '<-- DRIFT'))
        if tmp:
            os.unlink(tmp.name)
    print("TOTAL seeded=%d (pinned frame model, by design) unseeded=%d (drift; must be 0)"
          % (tot_s, tot_u))
    if all_off:
        print("\nUNSEEDED rbp REFERENCES -- a base the prologue never established:")
        for fn, rg, l in all_off[:40]:
            print("    %-22s %-30s %s" % (fn, rg, l))
    return 1 if tot_u else 0

if __name__ == '__main__':
    sys.exit(main())
