#!/usr/bin/env python3
"""util_emitted_alloc_cost.py -- THE EMITTED COST OF AN ALLOCATION SITE, IN BYTES AND IN INSTRUCTIONS.

⛔⭐ LON, IN-CHAT TO THE ceo 2026-09-20 13:3x CDT, VERBATIM: "Ensure that you do not bloat BBs with GC allocation code
that is more than 4-6 instructions. Beware of code size getting too large."  The ceo made it MANDATORY rather than
optional the same sitting (CEO-997, granting the coo's CEO-985 ask): every arm measuring the inline-versus-leaf class
carries its EMITTED BYTE COUNT beside its wall clock, BOTH ARMS, same tree plus the one change -- and THE INSTRUCTION
COUNT AT THE SITE, DISASSEMBLED, IS THE GRADED QUANTITY, because Lon gave a number and a number nothing reads is a wish.

⛔ THIS IS NOT test_gate_instr_budget.sh AND THE TWO MUST NOT BE CONFUSED.  That gate pins callgrind Ir -- instructions
EXECUTED at run time, a property of the workload.  This one counts instructions EMITTED at the site -- a property of the
code we generate, which is what Lon's sentence is about.  A change can move either one without the other.

⛔⭐ WHY THE SITE COUNT COMES FROM THE *BEFORE* ARM, and this is the whole measurement rather than a detail: the point of
the inline bump is that the `call` DISAPPEARS, so counting "allocation sites" in the after arm counts the very thing the
change removes and the per-site cost would divide by a number that fell.  THE NUMBER OF ALLOCATION SITES IS A PROPERTY OF
THE PROGRAM, not of the form we emit them in, so the before arm -- where every site still names itself with a call to an
entry in GC_ALLOC_TAB -- is what counts them, for both arms.  ⭐ THE cto GAVE THIS RULE A STRONGER REASON THAN MINE
(2026-09-20, from their own hand disassembly): in their after arm the call was STILL THERE as the miss path, so counting
sites in the after arm would have counted ONE site twice -- once as a call, once as an inline sequence -- and divided by
two.  The before-arm rule holds whether the change REMOVES the call or KEEPS it, which is the property, and "the call
disappears" was only the case I happened to be looking at.
⛔ ITS FIRST REAL READING RETIRED THE ROW IT WAS BUILT FOR, WHICH IS WHAT AN INSTRUMENT IS FOR (Lon, in-chat to the cto
2026-09-20, verbatim: "So forget the inline GC bump. It is just too long."):  ONE concat site in
bench_icnstr_concat_table.icn went 15 -> 86 emitted instructions, the bump ALONE 27 against Lon's ceiling of 6, object
text 3319 -> 3923 bytes over the program.  The cto's arithmetic for whoever proposes emitted allocation next: eight
instructions are irreducible before any guard, every available fold stops at thirteen, and 4-6 needs pre-formatted
size-class runs -- a different collector.  --max-insns expresses a different bar (the bump plus the separately granted
owner guard of up to 5 is --max-insns 11); the DEFAULT stays Lon's 6 so nobody inherits a widened bar by accident.  Same program, same tree plus the one change: that is the
control the INSTRUMENT LAWS require of a before/after pair, and this tool refuses a pair that does not carry it.

MEASURE ONE TREE:   util_emitted_alloc_cost.py measure <program> [<program>...] [--label L] [--out FILE]
GRADE A PAIR:       util_emitted_alloc_cost.py grade --before A.tsv --after B.tsv [--max-insns 6]
PROVE IT CAN FAIL:  util_emitted_alloc_cost.py --selftest

Every line it prints names its tree, its mode and its arena, because a number that does not is not labelled (RULES.md
THE INSTRUMENT LAWS).  rc=0 measured and within the bar, rc=1 OVER THE BAR (a real finding), rc=2 COULD NOT MEASURE.
"""
import os, re, subprocess, sys, tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
SCRIP = os.path.abspath(os.path.join(HERE, "..", "..", "SCRIP"))
TABLE = os.path.join(SCRIP, "src", "templates", "x86", "gc_allocating_table.inc")
BAR_LO, BAR_HI = 4, 6          # Lon's own number, 2026-09-20; BAR_HI is what grades


def refuse(msg, rc=2):
    print("⛔ COULD NOT MEASURE (rc=%d): %s" % (rc, msg))
    sys.exit(rc)


def allocating_entries():
    """The generated table is the ONE list of allocating entries -- never a hand-kept copy beside it."""
    if not os.path.exists(TABLE):
        refuse("%s is missing -- the allocating-entry table is generated (util_gen_gc_allocating_table.py) and is the "
               "only list of what an allocation site calls; without it this tool would be guessing at names" % TABLE)
    names = set(re.findall(r'\{\s*"([A-Za-z_][A-Za-z0-9_]*)"\s*,\s*GC_RET_', open(TABLE, encoding="utf-8").read()))
    if not names:
        refuse("%s parsed to ZERO entries -- its shape changed under this reader; re-pin the pattern rather than "
               "reading an empty set as 'no allocation sites'" % TABLE)
    return names


def tree_stamp():
    def h(repo):
        try:
            r = subprocess.run(["git", "-C", os.path.join(SCRIP, "..", repo), "rev-parse", "--short", "HEAD"],
                               capture_output=True, text=True, timeout=30)
            d = subprocess.run(["git", "-C", os.path.join(SCRIP, "..", repo), "status", "--porcelain"],
                               capture_output=True, text=True, timeout=30)
            if r.returncode:
                return "?"
            return r.stdout.strip() + ("-dirty" if d.stdout.strip() else "")
        except Exception:
            return "?"
    return "SCRIP=%s corpus=%s" % (h("SCRIP"), h("corpus"))


INSN = re.compile(r"^\s+([a-z][a-z0-9.]*)\b")


def count_insns(asm_text):
    """Instruction MNEMONICS in an emitted .s -- directives, labels, blank lines and comments are not instructions."""
    n = 0
    for ln in asm_text.split("\n"):
        s = ln.split("#", 1)[0].rstrip()
        if not s.strip() or s.strip().endswith(":") or s.lstrip().startswith("."):
            continue
        if INSN.match(s):
            n += 1
    return n


def count_alloc_calls(asm_text, entries):
    sites = {}
    for m in re.finditer(r"^\s+call\s+\*?([A-Za-z_][A-Za-z0-9_]*)(?:@[A-Z]+)?\s*$", asm_text, re.M):
        nm = m.group(1)
        if nm in entries:
            sites[nm] = sites.get(nm, 0) + 1
    return sites


def text_bytes(asm_path):
    """The EMITTED BYTE COUNT Lon asked for: .text of the assembled object, never the size of the .s file."""
    o = asm_path + ".o"
    r = subprocess.run(["gcc", "-c", asm_path, "-o", o], capture_output=True, text=True, timeout=300)
    if r.returncode != 0:
        return None, "gcc -c refused this .s: %s" % (r.stderr.strip().split("\n")[-1] if r.stderr.strip() else "no message")
    r = subprocess.run(["size", "-A", o], capture_output=True, text=True, timeout=120)
    if r.returncode != 0:
        return None, "size -A refused the object"
    for ln in r.stdout.split("\n"):
        f = ln.split()
        if len(f) >= 2 and f[0] == ".text":
            try:
                return int(f[1]), None
            except ValueError:
                pass
    return None, "no .text line in size -A output"


def measure(argv):
    progs, label, out = [], "", ""
    i = 0
    while i < len(argv):
        a = argv[i]
        if a == "--label":
            label = argv[i + 1]; i += 2
        elif a == "--out":
            out = argv[i + 1]; i += 2
        else:
            progs.append(a); i += 1
    if not progs:
        refuse("no program named -- this tool measures what the compiler emits for a REAL program, never a synthetic .s")
    scrip = os.path.join(SCRIP, "scrip")
    if not os.path.exists(scrip):
        refuse("no ./scrip at %s -- build first; a cost measured against a binary that is not there is not a measurement" % scrip)
    entries = allocating_entries()
    arena = os.environ.get("SCRIP_HEAP_MB", "default")
    stamp = tree_stamp()
    rows = []
    for p in progs:
        if not os.path.exists(p):
            refuse("%s does not exist" % p)
        with tempfile.TemporaryDirectory() as td:
            s_path = os.path.join(td, os.path.basename(p) + ".s")
            r = subprocess.run([scrip, "--compile", os.path.abspath(p)], capture_output=True, text=True, timeout=600)
            if r.returncode != 0:
                refuse("mode 4 refused %s (rc=%d): %s" % (p, r.returncode, (r.stderr or "").strip().split("\n")[-1]))
            open(s_path, "w", encoding="utf-8").write(r.stdout)
            tb, why = text_bytes(s_path)
            if tb is None:
                refuse("could not size the emitted object for %s: %s" % (p, why))
            ins = count_insns(r.stdout)
            sites = count_alloc_calls(r.stdout, entries)
            nsites = sum(sites.values())
            rows.append((os.path.basename(p), ins, tb, nsites, sites))
            print("EMITTED_COST prog=%s mode=m4 insns=%d text_bytes=%d alloc_call_sites=%d distinct_entries=%d "
                  "arena=%s tree=%s label=%s" % (os.path.basename(p), ins, tb, nsites, len(sites), arena, stamp, label or "-"))
            if nsites:
                top = sorted(sites.items(), key=lambda kv: -kv[1])[:6]
                print("  sites: " + ", ".join("%s x%d" % (k, v) for k, v in top)
                      + ("" if len(sites) <= 6 else " (+%d more entries)" % (len(sites) - 6)))
            else:
                print("  ⛔ ZERO allocation call sites in this program's emitted code. That is a fact about THE PROGRAM, "
                      "not a pass: as a BEFORE arm it can measure no per-site cost and grade() will refuse it.")
    if out:
        with open(out, "w", encoding="utf-8") as f:
            f.write("# util_emitted_alloc_cost.py measure\ttree=%s\tarena=%s\tlabel=%s\n" % (stamp, arena, label or "-"))
            f.write("prog\tinsns\ttext_bytes\talloc_call_sites\n")
            for nm, ins, tb, ns, _ in rows:
                f.write("%s\t%d\t%d\t%d\n" % (nm, ins, tb, ns))
        print("wrote %s (%d program(s)) -- hand this file to `grade --before/--after`" % (out, len(rows)))
    return 0


def _read(path):
    if not os.path.exists(path):
        refuse("%s does not exist" % path)
    head, rows = "", {}
    for ln in open(path, encoding="utf-8"):
        ln = ln.rstrip("\n")
        if ln.startswith("#"):
            head = ln; continue
        f = ln.split("\t")
        if len(f) != 4 or f[0] == "prog":
            continue
        rows[f[0]] = (int(f[1]), int(f[2]), int(f[3]))
    if not rows:
        refuse("%s carries no measured rows" % path)
    return head, rows


def grade(argv):
    before = after = ""
    bar = BAR_HI
    i = 0
    while i < len(argv):
        if argv[i] == "--before":
            before = argv[i + 1]; i += 2
        elif argv[i] == "--after":
            after = argv[i + 1]; i += 2
        elif argv[i] == "--max-insns":
            bar = int(argv[i + 1]); i += 2
        else:
            i += 1
    if not before or not after:
        refuse("grade needs --before and --after, each a file written by `measure --out`")
    hb, rb = _read(before)
    ha, ra = _read(after)
    tb_ = re.search(r"tree=(\S+ \S+)", hb)
    ta_ = re.search(r"tree=(\S+ \S+)", ha)
    print("GRADE emitted allocation cost against Lon's bar of %d-%d instructions at the site (graded at %d)"
          % (BAR_LO, BAR_HI, bar))
    print("  before: %s" % hb.lstrip("# "))
    print("  after:  %s" % ha.lstrip("# "))
    if tb_ and ta_ and tb_.group(1) == ta_.group(1):
        print("  ⛔ BOTH ARMS NAME THE SAME TREE (%s). A before/after pair is a measurement only when the two arms are "
              "the same tree PLUS THE ONE CHANGE -- these two are the same tree and nothing else, so the delta below "
              "is noise wearing a number." % tb_.group(1))
        return 2
    common = sorted(set(rb) & set(ra))
    if not common:
        refuse("the two arms share no program -- a delta between different programs is not a measurement")
    worst, bad, graded = None, 0, 0
    for p in common:
        bi, bb, bs = rb[p]
        ai, ab, _ = ra[p]
        if bs == 0:
            print("  %-28s REFUSED: the BEFORE arm found no allocation call site, so there is nothing to divide by "
                  "(the site count is the program's property and the before arm is what counts it)" % p)
            continue
        graded += 1
        di, db = ai - bi, ab - bb
        per_i, per_b = di / float(bs), db / float(bs)
        verdict = "OVER THE BAR" if per_i > bar else "within the bar"
        if per_i > bar:
            bad += 1
        if worst is None or per_i > worst[1]:
            worst = (p, per_i)
        print("  %-28s sites=%-4d insns %d -> %d (%+d, %+.2f/site)  text_bytes %d -> %d (%+d, %+.1f/site)  %s"
              % (p, bs, bi, ai, di, per_i, bb, ab, db, per_b, verdict))
    if graded == 0:
        # ⛔ A PASS OVER AN EMPTY GRADED SET IS THE VACUOUS GREEN THIS TOOL EXISTS TO REFUSE: every program was skipped
        # for want of a site in the before arm, so nothing was divided and nothing was compared. UNMEASURED MUST NOT
        # READ GREEN (my own line in the make test-arena tally, 2026-09-20).
        print("⛔ COULD NOT MEASURE (rc=2): %d program(s) in common and NONE carried an allocation site in the before "
              "arm, so no per-site cost exists to grade. This is not a pass." % len(common))
        return 2
    if bad:
        print("⛔ OVER LON'S BAR: %d of %d graded program(s) add more than %d emitted instructions per allocation site "
              "(worst %s at %.2f). Lon 2026-09-20: do not bloat BBs with GC allocation code that is more than 4-6 "
              "instructions." % (bad, graded, bar, worst[0], worst[1]))
        return 1
    print("✅ WITHIN LON'S BAR: %d graded program(s), worst %s at %.2f emitted instructions per allocation site (bar %d). "
          "The byte count is printed beside it on every line because code size is the other half of the sentence."
          % (graded, worst[0] if worst else "-", worst[1] if worst else 0.0, bar))
    return 0


def selftest():
    """⛔ THE FAIL PATH IS PROVEN HERE, NOT ASSERTED: a planted pair that adds 9 per site must read rc=1."""
    import io
    ok = True
    with tempfile.TemporaryDirectory() as td:
        b = os.path.join(td, "before.tsv"); a = os.path.join(td, "after.tsv")
        open(b, "w").write("# measure\ttree=SCRIP=aaaaaaa corpus=bbbbbbb\tarena=1\tlabel=leaf\nprog\tinsns\ttext_bytes\talloc_call_sites\nw.sno\t100\t400\t10\n")
        open(a, "w").write("# measure\ttree=SCRIP=ccccccc corpus=bbbbbbb\tarena=1\tlabel=inline\nprog\tinsns\ttext_bytes\talloc_call_sites\nw.sno\t190\t760\t2\n")
        rc = grade(["--before", b, "--after", a])
        print("  selftest A (9 per site, the bloat case): rc=%d %s" % (rc, "OK" if rc == 1 else "FAIL -- it cannot say no"))
        ok &= (rc == 1)
        open(a, "w").write("# measure\ttree=SCRIP=ccccccc corpus=bbbbbbb\tarena=1\tlabel=inline\nprog\tinsns\ttext_bytes\talloc_call_sites\nw.sno\t150\t600\t2\n")
        rc = grade(["--before", b, "--after", a])
        print("  selftest B (5 per site, inside Lon's 4-6): rc=%d %s" % (rc, "OK" if rc == 0 else "FAIL -- it cannot say yes"))
        ok &= (rc == 0)
        open(a, "w").write("# measure\ttree=SCRIP=aaaaaaa corpus=bbbbbbb\tarena=1\tlabel=inline\nprog\tinsns\ttext_bytes\talloc_call_sites\nw.sno\t150\t600\t2\n")
        rc = grade(["--before", b, "--after", a])
        print("  selftest C (both arms the same tree): rc=%d %s" % (rc, "OK" if rc == 2 else "FAIL -- it graded an uncontrolled pair"))
        ok &= (rc == 2)
        open(b, "w").write("# measure\ttree=SCRIP=aaaaaaa corpus=bbbbbbb\tarena=1\tlabel=leaf\nprog\tinsns\ttext_bytes\talloc_call_sites\nw.sno\t100\t400\t0\n")
        open(a, "w").write("# measure\ttree=SCRIP=ccccccc corpus=bbbbbbb\tarena=1\tlabel=inline\nprog\tinsns\ttext_bytes\talloc_call_sites\nw.sno\t190\t760\t0\n")
        rc = grade(["--before", b, "--after", a])
        ok &= (rc == 2)
        print("  selftest D (no site in the before arm -- nothing graded): rc=%d %s"
              % (rc, "OK -- a pass over an empty graded set is refused" if rc == 2 else "FAIL -- it read green over nothing"))
    print("SELFTEST %s" % ("PASS -- it can say no, say yes, and refuse an uncontrolled pair" if ok else "FAIL"))
    return 0 if ok else 1


def main():
    av = sys.argv[1:]
    if not av or av[0] in ("-h", "--help"):
        print(__doc__); return 2
    if av[0] == "--selftest":
        return selftest()
    if av[0] == "measure":
        return measure(av[1:])
    if av[0] == "grade":
        return grade(av[1:])
    refuse("unknown subcommand %r -- measure | grade | --selftest" % av[0])


if __name__ == "__main__":
    sys.exit(main())
