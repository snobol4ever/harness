#!/usr/bin/env python3
"""util_icn_rbp_census.py -- ICN-FB-0: the Icon rbp instrument.

WHY THIS EXISTS AND WHY IT IS NOT util_rbp_region_census.py.  That instrument (FLATDISP-9)
answers the SNOBOL4 question: "does any reference name a base the prologue never established?"
It deliberately EXCLUDES seeded [rbp+N] refs, on the stated grounds that "no frame-pointer rung
can ever remove these, so counting them makes zero unreachable."  THAT ARGUMENT DOES NOT HOLD
ON ICON.  Lon's s204 directive is precisely that the seeded refs must go: "ensure that ALL
operands in EVERY BB is accessed via RSP, NOT RBP.  The only purpose sanctioned for RBP
indexing is HOUSEKEEPING."  On Icon a seeded data ref is removable -- by moving its GRAPH off
the pin -- so it is the ratchet target, not an exempt class.  The two instruments therefore
answer different questions and both are needed; this one lives BESIDE, never inside.

THE REGION IS THE PROCEDURE (cto 2026-09-26, row icon-the-rbp-census-ratchet-counts-against-a-pre-three-zetas-
baseline-...).  A region runs from one procedure entry label to the next.  Since 15d6f203c (2026-08-16) an Icon
procedure's entry is FN__<name>, which ENTRY_RE did not know, so every file read as two regions (a preamble holding
every procedure, then main): the per-region seed test that DRIFT rests on was blind, and once the derived tier
put pinned procedure frames on RBP (cfe044377, 2026-09-09) every host-frame ref in a file with one generator was
counted as E.  COLLAPSED counts regions holding more than one frame seed; it must read 0, and the gate refuses
(rc 2) when it does not, because a collapsed region is the census not looking.

THE FOUR CLASSES (s204 census vocabulary, made mechanical here):
  A CEREMONY  -- prologue seed (`mov rbp, rsp`), caller-rbp save/restore into the header pad,
                 frame-chain walk (`mov rbp, [rbp+-N]`), `push/pop rbp`, `mov rsp, rbp`.
                 The ONLY population the directive sanctions.  ICN-FB-3's gate requires this
                 count to be EXACTLY UNCHANGED across a conversion step: if ceremony moves by
                 even one instruction the step touched a class the directive protects.
  C DATA      -- rbp as a memory BASE for an operand read/write: [rbp+N] / [rbp-N] that is not
                 ceremony.  THE CONVERSION TARGET.  This is what ratchets.
  D SCRATCH   -- `mov rbp, [<gpr> + N]`, rbp as a plain scratch destination.  Measured 0 on
                 Icon at s204 and re-measured 0 here; excluded from the ratchet for the same
                 reason the SNOBOL4 gate excludes it (no frame rung can remove a scratch use).
  DRIFT       -- a class-C ref inside a region whose prologue NEVER seeded rbp.  Such a ref
                 reads the CALLER's frame.  This is the s188/s189 defect class (Icon 250->236,
                 SNOBOL4 295/294->221/219, Prolog 164->120).  MUST BE 0; it is a real
                 zero-assert, not a ratchet, and it is inherited from FLATDISP-9's argument.

DRIFT is a subset of C, reported separately.  A conversion step that lowers C by creating
DRIFT has not converted anything -- it has broken the frame -- which is exactly why both
numbers are printed side by side and only one of them is allowed to be nonzero.
"""
import re, sys, os, subprocess, tempfile

ENTRY_RE = re.compile(r'^(FN__\w+|proc_.*_\u03b1|main|main_init)\s*:')
SEED_RE  = re.compile(r'\bmov\s+rbp\s*,\s*rsp\b')
CLASSD_RE = re.compile(r'\bmov\s+rbp\s*,\s*(qword ptr\s*)?\[r(ax|bx|cx|dx|si|di|8|9|1[0-5])')
CEREM_RE = re.compile(
    r'\bmov\s+\[\s*rsp\s*[+-]\s*\d+\s*\]\s*,\s*rbp\b'      # caller-rbp save into header pad
    r'|\bmov\s+rbp\s*,\s*rsp\b'                            # the seed
    r'|\bmov\s+rsp\s*,\s*rbp\b'                            # epilogue rebalance
    r'|\bmov\s+rbp\s*,\s*(qword ptr\s*)?\[\s*rsp\s*[+-]\s*\d+\s*\]'  # restore from pad
    r'|\bmov\s+rbp\s*,\s*(qword ptr\s*)?\[\s*rbp\s*[+-]\s*\d+\s*\]'  # frame-chain walk
    r'|\b(push|pop)\s+rbp\b')
# A class-C DATA reference is rbp used as a memory BASE.  rbp read/written as a plain register
# VALUE is not a frame reference (class D scratch; the `mov rcx, rbp` wire-adopt marshal) --
# counting either makes zero unreachable, the exact failure mode FLATDISP-9 was written to fix.
DATA_RE = re.compile(r'\[\s*rbp\s*[+\-]')
# ⭐ CLASS E (the FIFTH CLASS -- Lon's grant 2026-08-29, ceo landing): ζ-ACTIVATION refs inside a
# REGION-RESIDENT generator activation frame.  The N-2 alpha establishes rbp by pointing it INTO the
# host-carved region -- `lea rbp, [rax + ft]` -- not by seeding it from rsp, so without this class
# every generator ζ ref would read as class-C-without-a-seed, i.e. DRIFT, and the zero-assert would
# convict the ruled design.  E is counted SEPARATELY and ratchets under its own never-rising baseline
# (ICN_E_BASELINE in the gate); C_data stays a zero-assert everywhere a generator frame is absent.
GENSEED_RE = re.compile(r'\blea\s+rbp\s*,\s*(qword ptr\s*)?\[\s*rax\s*\+\s*\d+\s*\]')


def regions(lines):
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
    a = c = d = e = drift = 0
    offenders = []
    collapsed = []
    for name, body in regions(lines):
        seeded = any(SEED_RE.search(l) for l in body)
        genseeded = any(GENSEED_RE.search(l) for l in body)
        nseeds = sum(1 for l in body if SEED_RE.search(l) or GENSEED_RE.search(l))
        if nseeds > 1:
            collapsed.append((name, nseeds))
        for l in body:
            if CLASSD_RE.search(l):
                d += 1
                continue
            if CEREM_RE.search(l):
                a += 1
                continue
            if DATA_RE.search(l):
                if genseeded:
                    e += 1
                    continue
                c += 1
                if not seeded:
                    drift += 1
                    offenders.append((name, l.strip()))
    return a, c, d, e, drift, offenders, collapsed


def main():
    scrip = os.environ.get('SCRIP', './scrip')
    files = sys.argv[1:]
    if not files:
        print("usage: util_icn_rbp_census.py <prog.icn|prog.s> ...", file=sys.stderr)
        return 2
    tA = tC = tD = tE = tDrift = 0
    all_off = []
    all_col = []
    for f in files:
        if f.endswith('.s'):
            sp, tmp = f, None
        else:
            tmp = tempfile.NamedTemporaryFile(suffix='.s', delete=False)
            tmp.close()
            with open(tmp.name, 'w') as fh:
                r = subprocess.run([scrip, '--compile', f], stdout=fh,
                                   stderr=subprocess.DEVNULL, timeout=180)
            sp = tmp.name
        a, c, d, e, drift, off, col = census(sp)
        tA += a; tC += c; tD += d; tE += e; tDrift += drift
        for cl in col:
            all_col.append((os.path.basename(f),) + cl)
        for o in off:
            all_off.append((os.path.basename(f),) + o)
        print("%-34s A_ceremony=%-5d C_data=%-6d D_scratch=%-3d E_activation=%-5d drift=%-4d %s"
              % (os.path.basename(f), a, c, d, e, drift, 'OK' if drift == 0 else '<-- DRIFT'))
        if tmp:
            os.unlink(tmp.name)
    print("TOTAL A_ceremony=%d  C_data=%d  D_scratch=%d  E_activation=%d  DRIFT=%d"
          % (tA, tC, tD, tE, tDrift))
    print("RATCHET_C=%d" % tC)
    print("CEREMONY_A=%d" % tA)
    print("ACTIVATION_E=%d" % tE)
    print("COLLAPSED=%d" % len(all_col))
    if all_col:
        print("\nCOLLAPSED -- a region holding more than one frame seed spans several procedures, so its seed test is blind:")
        for fn, rg, n in all_col[:40]:
            print("    %-22s %-30s seeds=%d" % (fn, rg, n))
    if all_off:
        print("\nDRIFT -- class-C refs in regions whose prologue never seeded rbp:")
        for fn, rg, l in all_off[:40]:
            print("    %-22s %-30s %s" % (fn, rg, l))
    return 1 if tDrift else 0


if __name__ == '__main__':
    sys.exit(main())
