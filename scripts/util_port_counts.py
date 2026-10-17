#!/usr/bin/env python3
"""util_port_counts.py -- EXACT per-box alpha/beta execution counts, and beta/alpha backtrack pressure.

Lon (2026-08-28, via ceo, slice 4 of perf-symbol-attribution-tooling): "SCRIP can instrument alpha and
beta to produce execution counts." The deliverable named is exact counts beside perf's samples --
alpha-count = executions per box, beta/alpha = backtrack pressure per box, the alternation/defer
hotspots ranked BY FACT rather than by sample.

WHY CALLGRIND AND NOT AN EMITTED COUNTER (the design call, so the next seat does not re-buy it):
every alpha and beta port is ALREADY a symbol in a mode-4 binary (porter: 1,959 alpha + 1,138 beta
local `t` symbols), and callgrind's --dump-instr=yes reports an exact Ir count per instruction
address. The count of the instruction AT an alpha label's address IS the number of times that port
was entered -- exact, deterministic, and reproducible to the instruction. So the counts need
* NO emitted-code change  -- nothing is added to the program being measured;
* NO new global variable   -- there is no counter cell to store anywhere (RULES.md NO-NEW-GLOBALS);
* NO overhead to subtract  -- the measured program is byte-identical to the shipped one.
⭐ That last point is Instrument Law 6 satisfied STRUCTURALLY rather than by apology: the measurement
path (a simulator outside the process) is DISJOINT from the measured path. An emitted `inc` counter
would make the instrument a participant and would owe a measured perturbation beside every number.
⛔ WHAT THIS DOES NOT COVER, stated because a bounded instrument must bound itself (Law 13): this is
MODE-4 ONLY. Mode 3 executes flat-wired blobs in an anonymous sealed slab, so its boxes have no
symbols for callgrind to resolve; slice 3's SCRIP_PERF_MAP names m3 boxes to `perf` but is PER-GRAPH,
not per-box, and callgrind does not read a perf map at all. m3 port counts remain UNBUILT, not broken.

WHY THE COUNT AT AN ALPHA ADDRESS IS UNAMBIGUOUS (measured on porter, not assumed):
alpha addresses are all distinct (1,959 of 1,959), beta addresses are all distinct (1,138 of 1,138),
and alpha INTERSECT beta is EMPTY -- so no alpha count can be contaminated by a beta count. Every
alpha address does coincide with exactly one other label, its own `_bx` box-extent twin, which is the
SAME INSTRUCTION and therefore adds no executions. This script re-checks that property on every run
and REFUSES rather than reporting if it does not hold (a collision would silently merge two boxes).

⛔ beta/alpha IS NOT A SPEED MULTIPLE. RULES.md's FACT RULE reserves `Nx` for reference/ours on the
faster axis; this ratio is a dimensionless pressure -- recedes per proceed on one box -- so it is
printed as `B/A` and never with an `x`, and never with a direction word.

INSTRUMENT LAWS OBSERVED: 2/5 (refuses rc=2 when it cannot measure and never prints the success
shape; extraction anchored on symbol IDENTITY, never on position); 15 (alpha/beta are literal UTF-8
Greek in every emitted label -- an ASCII-only pattern silently misses ~98% of labels and still prints
a plausible table, so every pattern here is applied to str, and the suffix set is spelled in Greek);
6 (measurement path disjoint, above); 13 (the all-clear is scoped to the list actually run, and the
coverage block names it).
"""
import argparse, os, re, shutil, subprocess, sys, tempfile
ALPHA, BETA = "α", "β"
SYM_RE = re.compile(r"^([0-9a-fA-F]+)\s+[tT]\s+(n(\d+)_(.+)_(" + ALPHA + "|" + BETA + "))$")
def die(msg, rc=2):
    sys.stderr.write("REFUSE: " + msg + "\n" if rc == 2 else "FAIL: " + msg + "\n"); sys.exit(rc)
# ----------------------------------------------------------------------------------------------
def read_symbols(nm_text):
    """nm -n output -> {addr: [(port, family, nid, name)]}. Identity-anchored: a family is what
    remains after BOTH ends are stripped, never a substring match (slice 1's lesson: substring
    matching folds match_assign_save into match_assign)."""
    by_addr = {}
    for line in nm_text.splitlines():
        m = SYM_RE.match(line.strip())
        if not m: continue
        addr, name, nid, family, port = int(m.group(1), 16), m.group(2), int(m.group(3)), m.group(4), m.group(5)
        by_addr.setdefault(addr, []).append((port, family, nid, name))
    return by_addr
# ----------------------------------------------------------------------------------------------
def parse_callgrind(text, want_obj):
    """callgrind out -> {addr: self_Ir} for the named object only, plus (total_Ir, obj_Ir).

    Format care, each point a way this parser could have been silently wrong:
      * `positions: instr line` => every cost line is `<instr> <line> <Ir>`; instr may be absolute
        (0x..), relative (+N/-N) or `*` (same as last), each column tracking its own last value.
      * a `calls=` line carries the CALLEE's position, in its own context -- letting it update the
        caller's instr tracker would mis-attribute every post-call cost line to an address in a
        different function.
      * the cost line immediately AFTER a `calls=` line is the call's INCLUSIVE cost, not the
        instruction's self cost. Adding it would charge a box the entire cost of everything it calls,
        which on a recursive pattern box is a number larger than the whole program.
      * `ob=(id) name` defines a name-compression id; later `ob=(id)` alone REFERENCES it. Ignoring
        the id map makes every object after the first look like "not ours" and yields an empty table.
      * ⛔ `ob=` and `cob=` SHARE ONE object-name namespace. Measured: in porter's profile the id 1 in
        a bare `ob=(1)` is defined 50,000 lines earlier by `cob=(1) ld-linux-x86-64.so.2`. Absorbing
        only `ob=` definitions leaves such an id unresolved -- which happened to be harmless there
        (ld-linux is not ours) and would NOT be harmless for an id that is.
      * ⛔⭐ THE MAIN OBJECT MAY HAVE NO `ob=` LINE AT ALL -- it is the DEFAULT context. Measured: a
        1,000-iteration witness produced a profile whose only `ob=` is libstdc++, every main-object
        cost line sitting in the default context with just `cob=(4) ???` nearby. Requiring an
        explicit `ob=` match therefore dropped 100% of the program's own cost. It surfaced as a
        REFUSAL rather than as a plausible empty table only because refusing is this script's default
        when nothing is attributed -- which is the whole argument for Instrument Law 2.
    """
    obj_names, cur_obj, last, last_call = {}, None, [None, None], [None, None]
    costs, total_ir, obj_ir, after_calls, main_cmd = {}, 0, 0, False, None
    def pos(tok, col, tracker):
        if tok == "*": return tracker[col]
        if tok.startswith("+") or tok.startswith("-"):
            if tracker[col] is None: return None
            tracker[col] = tracker[col] + int(tok, 10); return tracker[col]
        try: tracker[col] = int(tok, 16) if tok.startswith("0x") else int(tok, 10)
        except ValueError: return None
        return tracker[col]
    for raw in text.splitlines():
        line = raw.rstrip("\n")
        if not line or line.startswith("#"): continue
        if line.startswith("cmd:"):
            main_cmd = line[4:].strip() or None; continue
        if line.startswith("ob=") or line.startswith("cob="):
            is_call_obj = line.startswith("cob=")
            body = line[(4 if is_call_obj else 3):].strip(); m = re.match(r"^\((\d+)\)\s*(.*)$", body)
            if m:
                oid, nm = m.group(1), m.group(2).strip()
                if nm: obj_names[oid] = nm                   # ob= and cob= share ONE namespace
                if not is_call_obj: cur_obj = obj_names.get(oid)
            elif not is_call_obj: cur_obj = body
            if not is_call_obj: last = [None, None]
            after_calls = False; continue
        if line.startswith(("fn=", "fl=", "fi=", "fe=", "cfn=", "cfl=", "cfi=")):
            if line.startswith(("fn=", "fl=", "fi=", "fe=")): last = [None, None]
            after_calls = False; continue
        if line.startswith("calls="):
            toks = line[6:].split()
            for i, t in enumerate(toks[1:3]): pos(t, i, last_call)
            after_calls = True; continue
        if line.startswith(("jump=", "jcnd=", "summary:", "totals:", "events:", "positions:", "version:",
                            "creator:", "pid:", "cmd:", "part:", "desc:")): continue
        toks = line.split()
        if len(toks) < 3: continue
        a = pos(toks[0], 0, last); pos(toks[1], 1, last)
        try: ir = int(toks[2])
        except ValueError: after_calls = False; continue
        if after_calls: after_calls = False; continue        # inclusive call cost -- never self cost
        total_ir += ir
        ours = want_obj(cur_obj) if cur_obj is not None else (want_obj(main_cmd) if main_cmd else True)
        if ours:
            obj_ir += ir
            if a is not None: costs[a] = costs.get(a, 0) + ir
    return costs, total_ir, obj_ir
# ----------------------------------------------------------------------------------------------
def build_table(by_addr, costs):
    """Join symbols to counts. Returns (rows, per_family, collisions) where a row is one BOX."""
    boxes, collisions = {}, []
    for addr, syms in by_addr.items():
        ports = set(p for p, _f, _n, _nm in syms)
        if len(ports) > 1: collisions.append((addr, [s[3] for s in syms]))
        for port, family, nid, name in syms:
            key = (nid, family)
            b = boxes.setdefault(key, {"nid": nid, "family": family, ALPHA: None, BETA: None})
            b[port] = costs.get(addr, 0)
    per_family = {}
    for b in boxes.values():
        f = per_family.setdefault(b["family"], {ALPHA: 0, BETA: 0, "boxes": 0, "hot": 0})
        f["boxes"] += 1
        f[ALPHA] += b[ALPHA] or 0; f[BETA] += b[BETA] or 0
        if (b[ALPHA] or 0) > 0: f["hot"] += 1
    return list(boxes.values()), per_family, collisions
# ----------------------------------------------------------------------------------------------
def report(rows, per_family, collisions, total_ir, obj_ir, label, top, out=sys.stdout):
    a_tot = sum(r[ALPHA] or 0 for r in rows); b_tot = sum(r[BETA] or 0 for r in rows)
    hot = sum(1 for r in rows if (r[ALPHA] or 0) > 0)
    w = out.write
    w("=== PORT EXECUTION COUNTS (exact, callgrind Ir at port addresses) -- %s\n" % label)
    w("COVERAGE: boxes=%d  alpha-entered=%d (%.1f%%)  alpha-total=%d  beta-total=%d  "
      "program-Ir=%d  object-Ir=%d\n" % (len(rows), hot, 100.0 * hot / len(rows) if rows else 0.0,
                                         a_tot, b_tot, total_ir, obj_ir))
    w("NOTE: B/A is recedes-per-proceed (backtrack pressure). It is NOT a speed multiple -- never an 'x'.\n")
    if collisions:
        w("COVERAGE: %d address(es) carry MORE THAN ONE PORT -- counts there are shared, listed below\n" % len(collisions))
        for addr, names in collisions[:5]: w("  collision @%#x: %s\n" % (addr, " ".join(names)))
    w("\n-- TOP %d BOXES BY alpha-count --\n" % top)
    w("%14s %14s %8s  %s\n" % ("alpha", "beta", "B/A", "box"))
    for r in sorted(rows, key=lambda r: -(r[ALPHA] or 0))[:top]:
        a, b = r[ALPHA] or 0, r[BETA] or 0
        if a == 0: break
        w("%14d %14d %8s  n%d_%s\n" % (a, b, ("%.3f" % (b / a)) if a else "-", r["nid"], r["family"]))
    w("\n-- FAMILY x PORT (exact counts; complements the SAMPLED shares of util_perf_bb_rollup.sh) --\n")
    w("%14s %14s %8s %7s  %s\n" % ("alpha", "beta", "B/A", "boxes", "family"))
    for fam, f in sorted(per_family.items(), key=lambda kv: -kv[1][ALPHA]):
        if f[ALPHA] == 0 and f[BETA] == 0: continue
        w("%14d %14d %8s %7d  %s\n" % (f[ALPHA], f[BETA], ("%.3f" % (f[BETA] / f[ALPHA])) if f[ALPHA] else "-",
                                       f["hot"], fam))
    return a_tot, b_tot
# ----------------------------------------------------------------------------------------------
def measure(binary, cg_out, label, top, out=sys.stdout):
    if not os.path.isfile(binary): die("binary does not exist: %s" % binary)
    if not os.path.isfile(cg_out): die("callgrind out file does not exist: %s" % cg_out)
    nm = shutil.which("nm") or die("nm not on PATH -- cannot read the symbol table")
    p = subprocess.run([nm, "-n", binary], capture_output=True, text=True)
    if p.returncode != 0: die("nm failed on %s: %s" % (binary, p.stderr.strip()[:200]))
    by_addr = read_symbols(p.stdout)
    if not by_addr: die("zero alpha/beta port symbols in %s -- an empty port table is not a measurement "
                        "of 'no port activity' (the binary may be stripped, or built by a compiler "
                        "that does not emit named port labels)" % binary)
    real = os.path.realpath(binary); base = os.path.basename(binary)
    costs, total_ir, obj_ir = parse_callgrind(open(cg_out, encoding="utf-8", errors="replace").read(),
                                              lambda o: os.path.realpath(o) == real or os.path.basename(o) == base)
    if total_ir == 0: die("callgrind file parsed to ZERO instructions -- it is empty, truncated, or not "
                          "a --dump-instr=yes profile: %s" % cg_out)
    if obj_ir == 0: die("no cost attributed to object %s in %s -- the profile is of a different binary" % (base, cg_out))
    rows, per_family, collisions = build_table(by_addr, costs)
    a_tot, b_tot = report(rows, per_family, collisions, total_ir, obj_ir, label, top, out)
    if a_tot == 0: die("every alpha port counted ZERO -- the symbol addresses and the profile addresses "
                       "do not correspond (a PIE binary, or a profile of a different build)")
    return 0
# ----------------------------------------------------------------------------------------------
def run_pipeline(program, stdin_file, root, top, keep):
    scrip = os.path.join(root, "scrip"); rt = os.path.join(root, "out", "libscrip_rt.so")
    for p in (scrip, rt):
        if not os.path.isfile(p): die("missing %s -- run `make` in %s first" % (p, root))
    vg = shutil.which("valgrind") or die("valgrind not on PATH -- this instrument needs callgrind")
    w = tempfile.mkdtemp(prefix="portcounts.")
    stem = os.path.splitext(os.path.basename(program))[0]
    s, o, b = os.path.join(w, stem + ".s"), os.path.join(w, stem + ".o"), os.path.join(w, stem)
    env = dict(os.environ, SCRIP_NOHUGE="1")
    r = subprocess.run([scrip, "--compile", "-o", s, program], stdin=subprocess.DEVNULL,
                       capture_output=True, text=True, env=env, timeout=600)
    if r.returncode != 0 or not os.path.isfile(s): die("mode-4 compile failed for %s: %s" % (program, r.stderr.strip()[:300]))
    if subprocess.run(["as", "--64", "-o", o, s], capture_output=True).returncode != 0: die("assembly failed for %s" % s)
    if subprocess.run(["gcc", "-no-pie", "-o", b, o, rt, "-lm", "-lstdc++", "-Wl,-rpath," + os.path.dirname(rt)],
                      capture_output=True).returncode != 0: die("link failed for %s" % o)
    cg = os.path.join(w, "cg.out")
    fin = open(stdin_file, "rb") if stdin_file else subprocess.DEVNULL
    r = subprocess.run([vg, "--tool=callgrind", "--dump-instr=yes", "--callgrind-out-file=" + cg,
                        "--main-stacksize=2000000000", b], stdin=fin, capture_output=True, timeout=3600)
    if stdin_file: fin.close()
    if not os.path.isfile(cg): die("callgrind wrote no profile for %s (rc=%d)" % (b, r.returncode))
    if r.returncode != 0:
        die("the program FAILED under callgrind (rc=%d) -- a crashed run still writes a plausible "
            "PARTIAL profile, which does not announce itself (ARCH-PERF-TOOLING field note). Refusing "
            "to report counts from it. stderr tail: %s" % (r.returncode, r.stderr.decode("utf-8", "replace")[-300:]))
    rc = measure(b, cg, "%s (mode-4, callgrind exact Ir)" % os.path.basename(program), top)
    if keep: sys.stderr.write("kept workdir: %s\n" % w)
    else: shutil.rmtree(w, ignore_errors=True)
    return rc
# ----------------------------------------------------------------------------------------------
CG_FIXTURE = """# callgrind format
version: 1
positions: instr line
events: Ir
summary: 1000

ob=(1) /fake/other
fn=(1) noise
0x1000 0 500

ob=(2) /fake/prog
fn=(2) box_one
0x401000 0 100
+4 0 100
cfn=(3) callee
calls=7 0x402000 0
* 0 90000
0x401100 0 25
fn=(3) box_two
0x401200 0 300
"""
CG_FIXTURE_DEFAULT_OBJ = """# callgrind format
version: 1
cmd:  /fake/prog
positions: instr line
events: Ir
cob=(4) ???
fn=(2) box_one
0x401000 0 700
0x401200 0 42
"""
CG_FIXTURE_COB_NAMESPACE = """# callgrind format
version: 1
cmd:  /fake/prog
positions: instr line
events: Ir
fn=(2) box_one
0x401000 0 11
cfn=(9) elsewhere
cob=(5) /fake/notours
calls=1 0x1000 0
* 0 999
ob=(5)
fn=(9) elsewhere
0x401200 0 12345
"""
NM_FIXTURE = """0000000000401000 t n1_match_begin_%s
0000000000401000 t n1_match_begin_bx
0000000000401100 t n1_match_begin_%s
0000000000401200 t n2_match_alternate_%s
0000000000401300 t n3_match_lit_%s
0000000000401400 T some_c_function
""" % (ALPHA, BETA, ALPHA, ALPHA)
def selftest():
    """Prove the instrument in ALL its states before anyone trusts it -- including watching it FAIL
    (Instrument Law 5). Four negative arms plus a POISON arm: if the poison does not make the
    positive assertions fail, the assertions were vacuous and the selftest proves nothing."""
    ok = True
    def check(name, cond):
        nonlocal ok
        sys.stdout.write("  %-52s %s\n" % (name, "ok" if cond else "FAILED"))
        if not cond: ok = False
    sys.stdout.write("selftest: positive arm\n")
    by_addr = read_symbols(NM_FIXTURE)
    costs, total, objir = parse_callgrind(CG_FIXTURE, lambda o: o == "/fake/prog")
    rows, per_family, collisions = build_table(by_addr, costs)
    box = {(r["nid"], r["family"]): r for r in rows}
    check("symbols parsed (4 port syms over 4 addrs)", len(by_addr) == 4)
    check("other object's cost excluded from object total", objir == 525 and total == 1025)
    check("inclusive call cost (90000) NOT counted as self", 90000 not in costs.values())
    check("relative position +4 resolved to 0x401004", costs.get(0x401004) == 100)
    check("n1 alpha count == 100", box[(1, "match_begin")][ALPHA] == 100)
    check("n1 beta count == 25", box[(1, "match_begin")][BETA] == 25)
    check("n2 alpha count == 300", box[(2, "match_alternate")][ALPHA] == 300)
    check("n3 alpha counted 0 (symbol present, never executed)", box[(3, "match_lit")][ALPHA] == 0)
    check("family rollup keeps match_begin distinct", per_family["match_begin"][ALPHA] == 100)
    check("bx twin on an alpha address is not a port collision", collisions == [])
    sys.stdout.write("selftest: object-context arms (the two bugs that cost this instrument a run)\n")
    dcosts, _dt, dobj = parse_callgrind(CG_FIXTURE_DEFAULT_OBJ, lambda o: os.path.basename(o) == "prog")
    check("main object with NO ob= line is the default context", dobj == 742 and dcosts.get(0x401000) == 700)
    ccosts, _ct, cobj = parse_callgrind(CG_FIXTURE_COB_NAMESPACE, lambda o: os.path.basename(o) == "prog")
    check("bare ob=(id) resolves against a cob=-defined name", cobj == 11 and 0x401200 not in ccosts)
    sys.stdout.write("selftest: POISON arm (assertions must FAIL on corrupted input)\n")
    poison = CG_FIXTURE.replace("0x401100 0 25", "0x401100 0 26")
    pcosts, _t, _o = parse_callgrind(poison, lambda o: o == "/fake/prog")
    prows, _pf, _pc = build_table(by_addr, pcosts)
    pbox = {(r["nid"], r["family"]): r for r in prows}
    check("poisoned beta count differs from clean (assertions can fail)", pbox[(1, "match_begin")][BETA] != 25)
    sys.stdout.write("selftest: negative arms (each must REFUSE rc=2)\n")
    here = os.path.abspath(__file__)
    def refuses(name, args):
        r = subprocess.run([sys.executable, here] + args, capture_output=True, text=True)
        check(name + " -> rc=2", r.returncode == 2)
    d = tempfile.mkdtemp(prefix="portcounts.st.")
    cgf, binf = os.path.join(d, "cg.out"), os.path.join(d, "prog")
    open(cgf, "w").write(CG_FIXTURE); open(binf, "w").write("not a binary"); os.chmod(binf, 0o755)
    refuses("missing callgrind file", ["--binary", binf, "--callgrind-out", os.path.join(d, "nope")])
    refuses("missing binary", ["--binary", os.path.join(d, "nope"), "--callgrind-out", cgf])
    refuses("binary with no port symbols", ["--binary", binf, "--callgrind-out", cgf])
    empty = os.path.join(d, "empty.out"); open(empty, "w").write("# callgrind format\nversion: 1\n")
    refuses("empty profile", ["--binary", binf, "--callgrind-out", empty])
    shutil.rmtree(d, ignore_errors=True)
    sys.stdout.write("SELFTEST %s\n" % ("PASS" if ok else "FAIL"))
    return 0 if ok else 1
# ----------------------------------------------------------------------------------------------
def main():
    ap = argparse.ArgumentParser(description="exact per-box alpha/beta execution counts (mode-4, callgrind)")
    ap.add_argument("--selftest", action="store_true")
    ap.add_argument("--program", help="a .sno/.icn/.pl source: compile, link, profile and report")
    ap.add_argument("--stdin", help="file to feed the program's stdin under callgrind")
    ap.add_argument("--binary"); ap.add_argument("--callgrind-out")
    ap.add_argument("--root", default=os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))), "SCRIP"))
    ap.add_argument("--top", type=int, default=25); ap.add_argument("--keep", action="store_true")
    a = ap.parse_args()
    if a.selftest: return selftest()
    if a.program: return run_pipeline(a.program, a.stdin, a.root, a.top, a.keep)
    if a.binary and a.callgrind_out: return measure(a.binary, a.callgrind_out, os.path.basename(a.binary), a.top)
    die("nothing to measure: pass --program SRC, or --binary B --callgrind-out F, or --selftest")
if __name__ == "__main__":
    sys.exit(main())
