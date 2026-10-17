#!/usr/bin/env python3
"""util_raku_roast_test_ladder.py -- Roast as a ladder of TESTS, ordered by complexity, the file each test lives in ignored.

Lon, in-chat to hq_raku 2026-09-27, verbatim, in order: "forget the benchmark kernels and start crawling the simple
rungs of Roast, tests at a time, not files at a time." / "So we just need a sort order for the complexity-index of all
the test. Just ignore which file they belong." / "No, it is lost. Just proceed without it. Make a new one." / "So you
should end up with a list of sets of tests from all the files." The method is the ceo's CEO-1289 answer to Lon's "Is
there a way to order the Roast such that the complexity grows from simple to more complex?": order by measured
construct sets, fewest new constructs first, grade per TAP test, `use Test` is rung one.

THREE VERBS.
  cut     THE PER-TEST REFS. Every in-tier file of Rakudo's spectest manifest (the scoreboard's tier rule: S01 S15 S22
          S26 excluded, S17 S24 tier C) is fudged for rakudo (roast's own ./fudge, as Rakudo's spectest runs it) into a
          symlink mirror of the roast tree (so `use lib $*PROGRAM.parent(2)...` still resolves), and run by Rakudo with
          TestLine preloaded: a wrapper on every Test routine that prints `#TL <line>`, the line in the test file that
          made the call (the SECOND backtrace frame naming the test file -- the first is the wrapper itself, which
          Rakudo reports under the test file's name; callframe() gives the enclosing block's line, never the call's) -- so a test inside a loop or a helper sub is tied to its source exactly, not guessed. Each TAP
          test becomes one row of corpus/packages/raku/roast/TESTS.tsv: rel n status(ok|notok|skip|todo) line
          constructs description, keyed by the md5 of the file's text (unchanged files are not re-cut; --recut all).
          A file Rakudo did not finish in --oracle-timeout seconds is named in the stderr census and cut no rows.
  rungs   THE COMPLEXITY INDEX. A test's constructs are the running union of its file's tests up to it (its context);
          over the tests Rakudo passes (status ok), every construct is ranked by how many of those unions hold it, most
          common first; a test's rung is the rank of its RAREST construct. So rung k is exactly the set of tests
          that need construct k and nothing rarer -- every rung adds ONE new construct to everything below it, which is
          the fewest-new-constructs order at test grain. Writes the rung column into TESTS.tsv and one row per rung to
          corpus/packages/raku/roast/RUNGS.tsv (rung, the construct it adds, its tests, the cumulative count).
  grade   THE CRAWL, ONE TEST AT A TIME. A test is graded in its PREFIX UNIT: the fudged file cut after the statement of
          the file's last test in rungs 0..K, its open brackets closed -- so nothing LATER in the file (a rarer
          construct the test never needed) can sink it; everything earlier is the test's own context, which is why a
          test's constructs are the running union of its file's tests up to it (rungs only rise along a file, and the
          tests of rungs <= K of any file are its tests 1..N). A test missing from the long prefix's output is re-run in
          ITS OWN prefix (cut after it), so a later statement the compiler refuses cannot sink an earlier test; the first
          test that fails in its own prefix is a genuine failure, and the file's later tests keep the long prefix's
          verdict (that failure is their context). --oracle-check runs Rakudo on the same prefix and drops
          (counting) any test the cut changed. Runs scrip (mode 3) on each prefix unit and prints per rung
          pass/total (a test passes when Rakudo printed `ok N` and scrip printed `ok N` WITH RAKUDO'S DESCRIPTION -- a
          test that silently never ran shifts every later number, and a number alone would credit the wrong test), the total, and the CRAWL
          CURSOR: the first failing test in rung order, with its statement. --m4 grades mode 4 as well. Writes nothing.
CONSTRUCTS are read off the test's code -- the code run since the previous test's statement (when the file flows
straight on to this test) plus the test's own statement, from its #TL line to its end -- by a Raku-aware tokenizer: keywords, operators (longest match), method names, sub calls, variable sigils and twigils, literal and quote
kinds, regexes, blocks, pointies, colonpairs, meta-operators. REFUSES rc=2 when it cannot measure.
ECONOMY (ceo CEO-1333): --jobs defaults to max(2, min(4, 16 - load)) read from /proc/loadavg, and every Rakudo and scrip
child runs under nice -n 19.
"""
import argparse, collections, hashlib, os, re, subprocess, sys, tempfile, shutil
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

HERE = Path(__file__).resolve().parent
SCRIP_DIR = (HERE.parent.parent / "SCRIP")
HOME = SCRIP_DIR.parent
SCRIP = SCRIP_DIR / "scrip"
RT = SCRIP_DIR / "out"
OUTDIR = HOME / "corpus" / "packages" / "raku" / "roast"
TESTS = OUTDIR / "TESTS.tsv"
RUNGS = OUTDIR / "RUNGS.tsv"
RAKU = "/usr/bin/raku"
TESTLINE = r'''no precompilation;
use Test;
for <ok nok is isnt is-deeply is-approx cmp-ok like unlike isa-ok does-ok can-ok lives-ok dies-ok eval-lives-ok eval-dies-ok throws-like fails-like pass flunk use-ok subtest skip todo> -> $n {
    my $r = ::("&$n");
    next unless $r ~~ Callable;
    $r.wrap(-> |c {
        my $t = $*PROGRAM-NAME; my $ln = 0;
        my $seen = 0; for Backtrace.new.list -> $f { if $f.file eq $t { if $seen++ { $ln = $f.line; last } } }
        $*OUT.say: "#TL $ln";
        callsame
    });
}
'''
TAPL = re.compile(r"^(not )?ok (\d+)(?: - ?(.*?))?(?:\s+#\s*(SKIP|TODO|skip|todo)\b.*)?$")
KEYWORDS = set("""my our has state constant sub method submethod multi proto only class role grammar module package unit enum
subset token rule regex for if elsif else unless with without orwith given when default while until loop repeat do
return take gather last next redo try CATCH CONTROL die fail warn once start await supply react whenever BEGIN END INIT
ENTER LEAVE FIRST LAST NEXT KEEP UNDO PRE POST is does of as but where so not and or xor andthen orelse notandthen
Nil Any Mu True False Inf NaN self EVAL eval sink quietly lazy eager hyper race temp let use need require import
new bless callsame nextsame samewith callwith nextwith""".split())
TESTFNS = set("ok nok is isnt is-deeply is_deeply is-approx is_approx cmp-ok like unlike isa-ok isa_ok does-ok can-ok lives-ok lives_ok dies-ok dies_ok eval-lives-ok eval_lives_ok eval-dies-ok eval_dies_ok throws-like fails-like pass flunk use-ok subtest skip todo plan done-testing diag".split())
OPS = sorted("""... ..^ ^..^ ^.. .. :: := ::= => -> <-> ==> <== ==> === !== =:= !=:= =~= eqv !eqv ~~ !~~ == != <= >= <=> < > + - * / % %% ** ~ x xx
&& || ^^ // ! ? ^ | & +& +| +^ +< +> ~& ~| ~^ ?& ?| ?^ ++ -- += -= *= /= ~= //= ||= &&= **= %= x= xx= = , ; ?? !! .= .? .+ .* .^ .& >>. ».
<< >> « » (elem) (cont) (|) (&) (-) (^) (+) (.) ∈ ∉ ∋ ∪ ∩ ⊆ ⊂ ⊇ ⊃ ≡ ≤ ≥ ≠ ∘ …""".split(), key=len, reverse=True)
WORDOPS = set("div mod gcd lcm cmp leg lt le gt ge eq ne min max minmax before after unicmp coll".split())


def fanout_width():
    try:
        load = float(open("/proc/loadavg").read().split()[0])
    except OSError:
        load = 16.0
    return max(2, min(4, int(16 - load)))


NICE = ["nice", "-n", "19"]
NAMEKINDS = ("call", "word", "type", "meth")
MINFILES = 5


def refuse(msg):
    print(f"⛔ REFUSE(rc=2) [util_raku_roast_test_ladder]: {msg}", file=sys.stderr)
    raise SystemExit(2)


def resolve(env, *cands):
    for c in ([os.environ.get(env)] if os.environ.get(env) else []) + list(cands):
        if c and Path(c).exists():
            return Path(c)
    return None


def roots():
    manifest = resolve("RAKU_ROAST_MANIFEST", "/home/resources/rakudo-main/t/spectest.data.6.c")
    roast = resolve("RAKU_ROAST_TREE", "/home/resources/roast-master")
    if not manifest or not roast:
        refuse("no spectest manifest or no roast tree")
    return manifest, roast


def population(manifest, roast):
    rels = []
    for line in manifest.read_text(errors="replace").splitlines():
        s = line.strip()
        if not s or s.startswith("#"):
            continue
        rel = s.split()[0]
        if rel.split("-", 1)[0] in ("S01", "S15", "S26", "S22", "S17", "S24") or not (roast / rel).is_file():
            continue
        rels.append(rel)
    return rels


def mirror_of(roast, td):
    m = Path(td) / "roast"
    subprocess.run(["cp", "-rs", str(roast), str(m)], check=True)
    return m


def staged(m, rel):
    return m / (rel[:-2] + ".raku")


def stage(roast, m, rel):
    dst = staged(m, rel)
    p = subprocess.run([str(roast / "fudge"), "rakudo", str(roast / rel), str(dst)], cwd=str(roast), capture_output=True, text=True)
    if not dst.exists():
        shutil.copyfile(roast / rel, dst)
    return dst


PAIRS = {"(": ")", "[": "]", "{": "}", "<": ">", "\u00ab": "\u00bb", "\u300c": "\u300d", "\u300e": "\u300f", "\uff08": "\uff09", "\u300a": "\u300b", "\u3008": "\u3009"}


def embedded_end(text, i):
    if text[i + 1:i + 2] != "`" or text[i + 2:i + 3] not in PAIRS:
        return 0
    o = text[i + 2]
    k = 1
    while text[i + 2 + k:i + 3 + k] == o:
        k += 1
    j = text.find(PAIRS[o] * k, i + 2 + k)
    return len(text) if j < 0 else j + k


def code_only(s):
    out, i, n = [], 0, len(s)
    while i < n:
        c = s[i]
        if c == "#":
            j = embedded_end(s, i)
            if j:
                i = j
                continue
            break
        if c in "'\"":
            j = i + 1
            while j < n and s[j] != c:
                j += 2 if s[j] == "\\" else 1
            out.append(c + c)
            i = j + 1
            continue
        out.append(c)
        i += 1
    return "".join(out)


def statement(lines, ln):
    return statement_span(lines, ln)[0]


def statement_span(lines, ln):
    if ln < 1 or ln > len(lines):
        return "", ln
    out, depth, i = [], 0, ln - 1
    while i < len(lines) and len(out) < 40:
        s = lines[i]
        out.append(s)
        code = code_only(s)
        for ch in code:
            if ch in "([{":
                depth += 1
            elif ch in ")]}":
                depth -= 1
        if depth <= 0 and (code.rstrip().endswith(";") or code.rstrip().endswith("}")):
            break
        i += 1
    return "\n".join(out), i + 1


def constructs(text):
    f, i, n = set(), 0, len(text)
    while i < n:
        c = text[i]
        if c.isspace():
            i += 1
            continue
        if c == "#":
            j = embedded_end(text, i)
            if j:
                f.add("comment:embedded")
                i = j
                continue
            j = text.find("\n", i)
            i = n if j < 0 else j
            f.add("comment")
            continue
        if c in "'\"":
            j = i + 1
            while j < n and text[j] != c:
                j += 2 if text[j] == "\\" else 1
            body = text[i + 1:j]
            if c == '"' and re.search(r"[$@%&]\w|\{", body):
                f.add("lit:interp")
            f.add("lit:str" + ("2" if c == '"' else "1"))
            i = j + 1
            continue
        m = re.match(r"(0[xob][0-9a-fA-F_]+|\d[\d_]*(\.\d[\d_]*)?([eE][-+]?\d+)?)", text[i:])
        if c.isdigit() and m:
            t = m.group(0)
            f.add("lit:radix" if t[:2] in ("0x", "0o", "0b") else "lit:num" if m.group(3) else "lit:dec" if m.group(2) else "lit:int")
            i += len(t)
            continue
        m = re.match(r"([$@%&])([.!*^?:=~<]?)([^\W\d][\w'-]*)?", text[i:])
        if c in "$@%&" and m and (m.group(3) or m.group(2) in ("<",) or (c == "$" and text[i + 1:i + 2] in "_/!0123456789")):
            f.add("var:" + c)
            if m.group(2):
                f.add("twigil:" + m.group(2))
            if m.group(3) in ("_", None) and c == "$" and text[i + 1:i + 2] == "_":
                f.add("var:$_")
            i += len(m.group(0)) or 1
            continue
        m = re.match(r"[^\W\d]\w*(?:[-'][^\W\d]\w*)*(?:::[^\W\d]\w*)*", text[i:])
        if m and (c.isalpha() or c == "_"):
            w = m.group(0)
            prev = text[i - 1] if i else ""
            nxt = text[i + len(w):i + len(w) + 1]
            if prev == "." and (i < 2 or text[i - 2] != "."):
                f.add("meth:" + w)
            elif w in ("rx", "m", "s", "tr") and nxt in "/{":
                f.add("regex:" + w)
            elif w in ("q", "qq", "Q", "qw", "qqw") and nxt in "/{[(<|":
                f.add("quote:" + w)
            elif w in TESTFNS:
                f.add("test:" + w)
            elif w in KEYWORDS:
                f.add("kw:" + w)
            elif w in WORDOPS:
                f.add("op:" + w)
            elif w[:1].isupper():
                f.add("type:" + w)
            elif nxt == "(" or nxt == " ":
                f.add("call:" + w)
            else:
                f.add("word:" + w)
            i += len(w)
            continue
        if c == "<" and re.match(r"<[\w\s.,:+-]*>", text[i:]) and (i == 0 or text[i - 1] in " (,=[{"):
            f.add("quote:<>")
            i = text.index(">", i) + 1
            continue
        if c == "/" and (i == 0 or text[i - 1] in " (,~="):
            j = text.find("/", i + 1)
            if j > i:
                f.add("regex:/")
                i = j + 1
                continue
        if c == ":" and re.match(r":!?[A-Za-z]", text[i:]):
            f.add("colonpair")
            i += 1
            continue
        if c == "[" and re.match(r"\[[-+*~]+\]|\[\\?[a-z]+\]", text[i:]):
            f.add("meta:reduce")
        if c == "{":
            f.add("block")
        for op in OPS:
            if text.startswith(op, i):
                f.add("op:" + op)
                i += len(op)
                break
        else:
            i += 1
    f.discard("op:;")
    f.discard("op:,")
    return f


def read_tests():
    rows = []
    if TESTS.exists():
        for ln in TESTS.read_text().splitlines():
            if ln.startswith("#") or ln.startswith("rung\t"):
                continue
            p = ln.split("\t")
            if len(p) >= 8:
                rows.append(p)
    return rows


def write_tests(rows):
    OUTDIR.mkdir(parents=True, exist_ok=True)
    head = ["# TESTS.tsv -- one row per Roast TAP test, cut by util_raku_roast_test_ladder.py cut from Rakudo running the",
            "# rakudo-fudged file with TestLine preloaded (line = the call site in the test file); rung set by `rungs`.",
            "rung\trel\tmd5\tn\tstatus\tline\tconstructs\tdescription"]
    TESTS.write_text("\n".join(head + ["\t".join(r) for r in rows]) + "\n")


def cmd_cut(a):
    manifest, roast = roots()
    rels = [r for r in population(manifest, roast) if r.startswith(a.section)]
    if a.limit:
        rels = rels[:a.limit]
    old = read_tests()
    have = collections.defaultdict(list)
    for r in old:
        have[r[1]].append(r)
    md5 = {r: hashlib.md5((roast / r).read_bytes()).hexdigest() for r in rels}
    todo = [r for r in rels if a.recut or r not in have or have[r][0][2] != md5[r]]
    keep = [r for r in old if r[1] not in set(todo)]
    print(f"CUT: {len(todo)} of {len(rels)} file(s) to cut ({a.jobs} jobs)", file=sys.stderr)
    with tempfile.TemporaryDirectory(prefix="rk_ladder_") as td:
        tl = Path(td) / "tl"
        tl.mkdir()
        (tl / "TestLine.rakumod").write_text(TESTLINE)
        m = mirror_of(roast, td)

        def one(rel):
            try:
                return one_(rel)
            except Exception as e:
                print(f"  CUT-ERROR {rel}: {type(e).__name__}: {e}", file=sys.stderr)
                return rel, False, []

        def one_(rel):
            dst = stage(roast, m, rel)
            try:
                p = subprocess.run(NICE + [RAKU, f"-I{tl}", "-MTestLine", str(dst.relative_to(m))], cwd=str(m), stdin=subprocess.DEVNULL,
                                   capture_output=True, timeout=a.oracle_timeout)
                out, done = p.stdout.decode(errors="replace"), True
            except subprocess.TimeoutExpired as e:
                out, done = (e.stdout or b"").decode(errors="replace"), False
            src = dst.read_text(errors="replace").splitlines()
            rows, last, prev_end = [], 0, 0
            for line in out.splitlines():
                if line.startswith("#TL "):
                    last = int(line[4:].strip() or 0)
                    continue
                t = TAPL.match(line)
                if not t:
                    continue
                st = "skip" if (t.group(4) or "").lower() == "skip" else "todo" if (t.group(4) or "").lower() == "todo" else "notok" if t.group(1) else "ok"
                cons = ""
                if last:
                    txt, end = statement_span(src, last)
                    if last - 1 >= prev_end:
                        txt = "\n".join(src[prev_end:last - 1] + [txt])
                    prev_end = max(prev_end, end)
                    cons = " ".join(sorted(constructs(txt)))
                desc = (t.group(3) or "").replace("\t", " ")[:160]
                rows.append(["", rel, md5[rel], t.group(2), st, str(last), cons, desc])
                last = 0
            return rel, done, rows
        new, timeouts = [], []
        with ThreadPoolExecutor(a.jobs) as ex:
            for rel, done, rows in ex.map(one, todo):
                new += rows
                if not done:
                    timeouts.append(rel)
    allrows = keep + new
    order = {r: i for i, r in enumerate(population(manifest, roast))}
    allrows.sort(key=lambda r: (order.get(r[1], 1 << 30), int(r[3])))
    write_tests(allrows)
    st = collections.Counter(r[4] for r in allrows)
    print(f"ROAST_TEST_REFS files={len(set(r[1] for r in allrows))} tests={len(allrows)} ok={st['ok']} notok={st['notok']} skip={st['skip']} todo={st['todo']} "
          f"unlocated={sum(1 for r in allrows if r[5] == '0')} timeouts_this_cut={len(timeouts)}")
    for t in timeouts:
        print(f"  TIMEOUT {t}", file=sys.stderr)
    return 0


def cmd_rungs(a):
    rows = read_tests()
    if not rows:
        refuse(f"no refs at {TESTS} -- run cut first")
    spread = collections.defaultdict(set)
    for r in rows:
        for c in r[6].split():
            if c.split(":", 1)[0] in NAMEKINDS:
                spread[c].add(r[1])

    def norm(c):
        k = c.split(":", 1)[0]
        return k + ":*" if k in NAMEKINDS and len(spread[c]) < MINFILES else c
    ok = [r for r in rows if r[4] == "ok" and r[5] != "0"]
    unloc = sum(1 for r in rows if r[4] == "ok" and r[5] == "0")
    cums, cum, cur = {}, set(), None
    for r in sorted(rows, key=lambda r: (r[1], int(r[3]))):
        if r[1] != cur:
            cum, cur = set(), r[1]
        cum = cum | set(map(norm, r[6].split()))
        cums[id(r)] = cum
    freq = collections.Counter(c for r in ok for c in cums[id(r)])
    rank = {c: i + 1 for i, (c, _) in enumerate(sorted(freq.items(), key=lambda kv: (-kv[1], kv[0])))}
    byc = {v: k for k, v in rank.items()}
    counts = collections.Counter()
    for r in rows:
        cum = cums[id(r)]
        r[0] = (str(max((rank.get(c, 0) for c in cum), default=0)) if r[5] != "0" else "U") if r[4] == "ok" else ""
        if r[4] == "ok" and r[5] != "0":
            counts[int(r[0])] += 1
    write_tests(rows)
    cum, out = 0, ["# RUNGS.tsv -- rung k = the Roast tests (Rakudo ok) whose rarest construct is the k-th most common one; rung 0 = no construct read",
                   "rung\tadds\tusers\ttests\tcumulative"]
    for k in sorted(counts):
        cum += counts[k]
        out.append(f"{k}\t{byc.get(k, '-')}\t{freq.get(byc.get(k), 0)}\t{counts[k]}\t{cum}")
    RUNGS.write_text("\n".join(out) + "\n")
    print(f"ROAST_TEST_RUNGS tests={len(ok)} constructs={len(rank)} rungs_nonempty={len(counts)} unlocated={unloc} (rung U, outside the ladder) (first ten below)")
    for line in out[2:12]:
        print("  " + line)
    return 0


def closers(lines):
    stack = []
    for ln in lines:
        for ch in code_only(ln):
            if ch in "([{":
                stack.append(ch)
            elif ch in ")]}" and stack:
                stack.pop()
    return "\n".join(PAIRS[o] + (";" if o == "{" else "") for o in reversed(stack))


def cmd_grade(a):
    manifest, roast = roots()
    every = read_tests()
    rows = [r for r in every if r[4] == "ok" and r[0] not in ("", "U") and int(r[0]) <= a.to]
    if not rows:
        refuse("no graded refs up to that rung -- run cut and rungs first")
    nk = collections.defaultdict(int)
    for r in rows:
        nk[r[1]] = max(nk[r[1]], int(r[3]))
    line_of = collections.defaultdict(dict)
    for r in every:
        if r[1] in nk and int(r[3]) <= nk[r[1]] and r[5] != "0":
            line_of[r[1]][int(r[3])] = int(r[5])
    want = collections.defaultdict(set)
    desc = {}
    for r in rows:
        want[r[1]].add(int(r[3]))
        desc[(r[1], int(r[3]))] = r[7]
    files = sorted(nk)
    with tempfile.TemporaryDirectory(prefix="rk_grade_") as td:
        m = mirror_of(roast, td)
        probe = Path(td) / "probe.raku"
        probe.write_text("say 1;\n")
        p = subprocess.run([a.scrip, str(probe)], capture_output=True, stdin=subprocess.DEVNULL, timeout=30)
        if p.returncode != 0 or p.stdout.decode().strip() != "1":
            refuse("scrip cannot run `say 1;`")
        rt = Path(a.scrip).resolve().parent / "out"

        def tapset(out):
            return {int(t.group(2)): (t.group(3) or "").replace("\t", " ")[:160] for t in map(TAPL.match, out.splitlines()) if t and not t.group(1) and not t.group(4)}

        def runout(cmd, cwd):
            try:
                return subprocess.run(NICE + cmd, cwd=cwd, stdin=subprocess.DEVNULL, capture_output=True, timeout=a.timeout).stdout.decode(errors="replace")
            except subprocess.TimeoutExpired as e:
                return (e.stdout or b"").decode(errors="replace")

        def run_prefix(rel, dst, src, end, tag, oracle):
            pre = src[:end]
            unit = dst.with_name(f"{dst.stem}__prefix{tag}.raku")
            unit.write_text("\n".join(pre) + "\n" + closers(pre) + "\n")
            ur = str(unit.relative_to(m))
            got = {"m3": tapset(runout([a.scrip, ur], str(m)))}
            if a.m4:
                base = Path(td) / f"{rel.replace('/', '_')}{tag}"
                s_, o_, b_ = str(base) + ".s", str(base) + ".o", str(base) + ".bin"
                ok = subprocess.run(NICE + [a.scrip, "--compile", ur, "-o", s_], cwd=str(m), stdin=subprocess.DEVNULL, capture_output=True).returncode == 0
                ok = ok and subprocess.run(["gcc", "-c", s_, "-o", o_], capture_output=True).returncode == 0
                ok = ok and subprocess.run(["gcc", o_, "-o", b_, f"-L{rt}", "-lscrip_rt", "-lm", f"-Wl,-rpath,{rt}"], capture_output=True).returncode == 0
                got["m4"] = tapset(runout([b_], str(m))) if ok else set()
            if oracle:
                got["rakudo"] = tapset(runout([RAKU, ur], str(m)))
            return got

        def one(rel):
            dst = stage(roast, m, rel)
            src = dst.read_text(errors="replace").splitlines()
            ends, hi = {}, 0
            for n in sorted(line_of[rel]):
                hi = max(hi, statement_span(src, line_of[rel][n])[1])
                ends[n] = hi
            got = run_prefix(rel, dst, src, ends.get(nk[rel], len(src)), "", a.oracle_check)
            modes_ = ["m3"] + (["m4"] if a.m4 else [])
            def hit(tap, t):
                return t in tap and tap[t] == desc[(rel, t)]
            for t in sorted(want[rel]):
                if all(hit(got[md], t) for md in modes_):
                    continue
                own = run_prefix(rel, dst, src, ends.get(t, len(src)), f"_{t}", False)
                if all(hit(own[md], t) for md in modes_):
                    for md in modes_:
                        got[md][t] = own[md][t]
                    continue
                break
            return rel, got

        with ThreadPoolExecutor(a.jobs) as ex:
            got = dict(ex.map(one, files))
    modes = ["m3"] + (["m4"] if a.m4 else [])
    per = collections.defaultdict(lambda: [0, 0])
    cursor, unsure, verdicts, fails = None, 0, [], []
    for r in sorted(rows, key=lambda r: (int(r[0]), r[1], int(r[3]))):
        k, n = int(r[0]), int(r[3])
        if a.oracle_check and got[r[1]]["rakudo"].get(n) != r[7]:
            unsure += 1
            continue
        passed = all(got[r[1]][md].get(n) == r[7] for md in modes)
        verdicts.append((r[1], n, k, int(passed)))
        per[k][1] += 1
        per[k][0] += passed
        if not passed:
            if cursor is None:
                cursor = r
            if len(fails) < a.cursors:
                fails.append(r)
    if a.tsv:
        with open(a.tsv, "w") as f:
            f.write("rel\tn\trung\tpass\n")
            for v in verdicts:
                f.write("\t".join(map(str, v)) + "\n")
    tp, tt = sum(v[0] for v in per.values()), sum(v[1] for v in per.values())
    extra = f" prefix_changed_rakudo={unsure}" if a.oracle_check else ""
    print(f"ROAST_TEST_LADDER --to {a.to} modes={'+'.join(modes)} units(files)={len(files)} tests={tt} pass={tp} ({100.0 * tp / max(tt, 1):.2f}%){extra}")
    for k in sorted(per)[:a.show]:
        print(f"  rung {k:4d}  {per[k][0]:5d}/{per[k][1]:<5d}")
    if cursor:
        src = (roast / cursor[1]).read_text(errors="replace").splitlines()
        print(f"CRAWL CURSOR: rung {cursor[0]}  {cursor[1]} test {cursor[3]} (line {cursor[5]}) -- {cursor[7]}")
        print("  " + statement(src, int(cursor[5])).replace("\n", "\n  "))
    for r in fails[1:]:
        src = (roast / r[1]).read_text(errors="replace").splitlines()
        print(f"  next: rung {r[0]}  {r[1]} test {r[3]} (line {r[5]}) -- {statement(src, int(r[5])).strip()[:110]}")
    return 0


def main():
    ap = argparse.ArgumentParser()
    sp = ap.add_subparsers(dest="verb", required=True)
    c = sp.add_parser("cut")
    c.add_argument("--section", default="")
    c.add_argument("--limit", type=int, default=0)
    c.add_argument("--jobs", type=int, default=0)
    c.add_argument("--oracle-timeout", type=int, default=180)
    c.add_argument("--recut", action="store_true")
    sp.add_parser("rungs")
    g = sp.add_parser("grade")
    g.add_argument("--to", type=int, default=10)
    g.add_argument("--jobs", type=int, default=0)
    g.add_argument("--timeout", type=int, default=30)
    g.add_argument("--m4", action="store_true")
    g.add_argument("--show", type=int, default=40)
    g.add_argument("--oracle-check", action="store_true")
    g.add_argument("--tsv")
    g.add_argument("--cursors", type=int, default=1)
    g.add_argument("--scrip", default=str(SCRIP))
    a = ap.parse_args()
    if getattr(a, "scrip", None):
        a.scrip = str(Path(a.scrip).resolve())
    if getattr(a, "jobs", None) is not None:
        a.jobs = a.jobs or fanout_width()
    return {"cut": cmd_cut, "rungs": cmd_rungs, "grade": cmd_grade}[a.verb](a)


if __name__ == "__main__":
    sys.exit(main())
