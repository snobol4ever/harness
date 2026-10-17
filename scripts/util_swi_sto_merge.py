#!/usr/bin/env python3
"""util_swi_sto_merge.py ACTUAL SPECS RUNDIR_PREFIX TIMEOUT -- put each sto(rational_trees) case's ALONE verdict where the file's own run deferred it
(ceo CEO-1684, 2026-10-11; hq_prolog's third shim finding).

plunit runs a sto(rational_trees) test with occurs_check=false, both engines' default, so it is an ordinary test; but one that builds a cyclic
term can loop or exhaust the stack and end its whole file (measured on 4783ee83e: core/test_arith 221 cases -> 61, core/test_term 52 -> 9).
So corpus/tests/prolog/plunit.pl DEFERS each one in the file's run -- '  skip: U:T  [sto-deferred only(U,T)]' -- and test_prolog_swi_suite.sh
runs each spec ALONE, in the same program, with only(U,T). in a pj_sto_only.pl in its own directory and its own timeout. This merges:

  ACTUAL         the file's run output (rewritten on stdout)
  SPECS          the distinct only(U,T) specs, one per line, in first-deferral order
  RUNDIR_PREFIX  spec k's alone run is in RUNDIR_PREFIX<k>/ : out (its stdout), err, rc
  TIMEOUT        the alone run's timeout in seconds, named in a FAIL line

The FIRST deferred line of a spec becomes the alone run's verdict lines ('  pass:', '  FAIL:', '  skip:' -- a forall test prints one per
instance), and the spec's later deferred lines (the forall instances the file's run deferred one by one) are dropped, so occurrence order per
name is kept for util_swi_match.py. An alone run that printed no verdict is that case's FAIL, once per deferred line, its why naming the
loop: rc 124 a timeout, 128+N a signal, any other rc the run's first error line.
"""
import os, re, sys

VERDICT = re.compile(r"^  (pass|FAIL|skip): ")


def alone(prefix, k, timeout):
    d = "%s%d" % (prefix, k)
    try:
        out = open(os.path.join(d, "out"), encoding="utf-8", errors="replace").read().split("\n")
    except OSError:
        out = []
    try:
        rc = int(open(os.path.join(d, "rc")).read().strip() or 0)
    except (OSError, ValueError):
        rc = -1
    lines = [l for l in out if VERDICT.match(l)]
    if lines:
        return lines, None
    if rc == 124:
        why = "sto(rational_trees) case alone: no verdict in %s s, a loop" % timeout
    elif rc > 128:
        why = "sto(rational_trees) case alone: died on signal %d" % (rc - 128)
    else:
        err = ""
        try:
            err = next((l.strip() for l in open(os.path.join(d, "err"), encoding="utf-8", errors="replace") if l.strip()), "")
        except OSError:
            pass
        why = "sto(rational_trees) case alone: rc %d, no verdict%s" % (rc, (" -- " + err[:120]) if err else "")
    return None, why


def main(argv):
    if len(argv) != 5:
        print("usage: util_swi_sto_merge.py ACTUAL SPECS RUNDIR_PREFIX TIMEOUT", file=sys.stderr)
        return 2
    act, specs, prefix, timeout = argv[1:]
    specs = [s for s in open(specs, encoding="utf-8").read().split("\n") if s]
    got = {s: alone(prefix, k, timeout) for k, s in enumerate(specs, 1)}
    placed = set()
    for line in open(act, encoding="utf-8", errors="replace").read().split("\n"):
        m = re.search(r"\[sto-deferred (only\(.*\))\]$", line)
        if not m or m.group(1) not in got:
            print(line)
            continue
        spec = m.group(1)
        lines, why = got[spec]
        if lines is not None:
            if spec not in placed:
                for l in lines:
                    print(l)
                placed.add(spec)
            continue
        name = line.split("skip: ", 1)[1].split("  [sto-deferred", 1)[0] if "skip: " in line else spec
        print("  FAIL: %s  (%s)" % (name, why))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
