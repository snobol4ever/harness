#!/usr/bin/env python3
# patsweep.py [DEPTH] : patterns built from a small grammar (28 leaves; at depth 2 every pair concatenated and alternated, ARBNO, conditional and
# immediate captures, a cursor assignment) matched against 8 subjects, on sbl -bf and on the dotnet console; prints the cases on which they
# differ ("n ok [matched] C1 C2 P1 errtype" or "n fail errtype"). A chunk of patterns that does not end in 15 seconds on either engine is halved until
# the pattern that loops is alone, and is reported as "TIMEOUT sbl|net": SPITBOL loops on some patterns too (ARBNO of a null pattern).
# Run it from an empty scratch directory.
import itertools, os, re, subprocess, sys

REPO = os.environ.get("S4E_DOTNET_ROOT", "/home/claude_dotnet")
SBL = os.environ.get("SBL", "/home/resources/x64/bin/sbl")
NET = ["dotnet", os.environ.get("DLL", os.path.join(REPO, "Snobol4", "bin", "Release", "net10.0", "Snobol4.dll"))]
LEAVES = ["'a'", "'ab'", "''", "LEN(1)", "LEN(2)", "LEN(0)", "POS(0)", "POS(1)", "RPOS(0)", "RPOS(1)", "TAB(2)", "RTAB(1)", "REM", "ARB", "BAL",
          "SPAN('ab')", "BREAK('b')", "BREAKX('b')", "ANY('ab')", "NOTANY('a')", "FENCE", "FAIL", "SUCCEED", "ABORT", "'b'", "'c'", "*X", "'a' | 'b'"]
SUBJECTS = ["''", "'a'", "'ab'", "'abc'", "'aab'", "'baab'", "'(a)b'", "'abab'"]


def patterns(depth):
    pats = list(LEAVES)
    if depth >= 2:
        for a, b in itertools.product(LEAVES, LEAVES):
            pats += ["(%s) (%s)" % (a, b), "(%s) | (%s)" % (a, b)]
        for a in LEAVES:
            pats += ["ARBNO(%s)" % a, "(%s) . C1 (%s)" % (a, a), "(%s) $ C2" % a, "@P1 (%s)" % a]
    return pats


def program(pats, first):
    out = ["        &ERRLIMIT = 1000000", "        &TRIM = 0", "        X = 'a'"]
    n = first
    for p in pats:
        for s in SUBJECTS:
            n += 1
            out += ["        &ERRTYPE = 0", "        R = 'none'", "        C1 = 'n'", "        C2 = 'n'", "        P1 = -1",
                    "        %s ? (%s) . R   :S(S%d)F(F%d)" % (s, p, n, n),
                    "S%d     OUTPUT = '%d ok [' R '] ' C1 ' ' C2 ' ' P1 ' ' &ERRTYPE   :(N%d)" % (n, n, n),
                    "F%d     OUTPUT = '%d fail ' &ERRTYPE" % (n, n), "N%d" % n]
    return "\n".join(out + ["END"]) + "\n", n


def run(cmd, path):
    try:
        r = subprocess.run(cmd + ["-bf", path], stdin=subprocess.DEVNULL, capture_output=True, timeout=15, text=True, errors="replace")
        return {m.group(1): m.group(0) for m in re.finditer(r"^(\d+) (?:ok|fail) .*$", r.stdout + r.stderr, re.M)}, "UNEXPECTED EXCEPTION" in r.stderr + r.stdout
    except subprocess.TimeoutExpired:
        return None, False


def compare(pats, first):
    text, last = program(pats, first)
    open("patchunk.sno", "w").write(text)
    a, _ = run([SBL], "patchunk.sno")
    b, crashed = run(NET, "patchunk.sno")
    if a is None or b is None:
        if len(pats) > 1:
            half = len(pats) // 2
            compare(pats[:half], first)
            compare(pats[half:], first + half * len(SUBJECTS))
        else:
            print("TIMEOUT %s: %s" % ("sbl" if a is None else "net", pats[0]) + ("" if (a is None) == (b is None) else "   (the other engine ended)"))
        return
    for k in sorted(set(a) | set(b), key=int):
        if a.get(k) != b.get(k):
            pattern = pats[(int(k) - first - 1) // len(SUBJECTS)]
            print("%-40s [%s] sbl: %s | net: %s" % (pattern, SUBJECTS[(int(k) - first - 1) % len(SUBJECTS)], (a.get(k) or "-").split(" ", 1)[-1], (b.get(k) or "-").split(" ", 1)[-1]))
    if crashed:
        print("CRASH in chunk starting", pats[0])


if __name__ == "__main__":
    pats = patterns(int(sys.argv[1]) if len(sys.argv) > 1 else 1)
    for i in range(0, len(pats), 40):
        compare(pats[i:i + 40], i * len(SUBJECTS))
