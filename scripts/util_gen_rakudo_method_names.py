#!/usr/bin/env python3
"""util_gen_rakudo_method_names.py -- generate src/runtime/rk_rakudo_method_names.inc, the sorted list of every method name Rakudo's own core types have (Mu, Any, Cool, Str, Int, List, Hash, IO::Path, Exception, Grammar, ...), which the Raku runtime (by_name_dispatch.c rk_is_rakudo_method) uses to tell a METHOD THAT DOES NOT EXIST ("zzz", "nosuch": X::Method::NotFound) from a REAL Rakudo method that SCRIP has not implemented yet (the statement still fails quietly, as it always did, and is a gap to fill, not a typo to report).

Usage: python3 ../harness/scripts/util_gen_rakudo_method_names.py [--raku /usr/bin/raku] [--out PATH] [--check]

  --raku   the Rakudo oracle (default /usr/bin/raku); the names come from `.^methods(:all)` of each core type, run inside a `try` per type because a few meta-objects refuse introspection (the Grammar and Cursor lookups are flaky, so the oracle runs four times and the union is taken, plus the three Grammar entry points by name).
  --check  write nothing; exit 0 when the checked-in file equals what would be generated.

The generated file is passed through ../harness/scripts/util_reflow_200.py --apply (the repository's 200-column rule), so it is byte-stable under that tool and --check compares after the same pass. It holds data only: one const array of strings sorted bytewise (strcmp order) and its length.
"""
import argparse, os, subprocess, sys, tempfile

TYPES = """Mu Any Cool Str Int Num Rat FatRat Complex Numeric Real Rational List Array Hash Map Pair Range Seq Bool Block Code Routine Sub Method Submethod Match Regex Junction Set SetHash Bag BagHash Mix MixHash Setty Baggy Mixy QuantHash Buf Blob utf8 IO::Path IO::Handle IO::Spec IO::CatHandle Exception Failure Instant Duration DateTime Date Dateish Capture Positional Associative Iterable Iterator Callable Order Version Supply Promise Channel Thread Lock Proc Whatever WhateverCode Slip Nil Stringy Systemic Distro Kernel VM Signature Parameter Attribute Variable Scalar Uni NFC NFD NFKC NFKD Encoding Label ForeignCode Cancellation Semaphore Backtrace CallFrame Telemetry UInt int8 uint8 int num str IntStr NumStr RatStr ComplexStr StrDistance IO::Special IO::ArgFiles Sequence buf8 blob8 Grammar Cursor""".split()
PROG = """my %seen;
for <@TYPES@> -> $n {
    try {
        my $t = ::($n);
        for $t.^methods(:all) -> $m { my $nm = $m.name; %seen{$nm} = 1 if $nm ne '<anon>' && $nm ne '' }
    }
}
.say for %seen.keys.sort;
"""

EXTRA = ["parse", "parsefile", "subparse"]

def names(raku):
    got = set(EXTRA)
    with tempfile.TemporaryDirectory() as td:
        p = os.path.join(td, "names.raku")
        open(p, "w").write(PROG.replace("@TYPES@", " ".join(TYPES)))
        for _ in range(4):
            r = subprocess.run([raku, p], capture_output=True, text=True)
            got |= {l for l in r.stdout.split("\n") if l}
    out = sorted(got, key=lambda s: s.encode("utf-8"))
    if len(out) < 500: sys.exit("only %d names from the oracle (stderr: %s)" % (len(out), r.stderr[:200]))
    return out

def emit(ns):
    body = ",\n".join("    " + '"' + n.replace("\\", "\\\\").replace('"', '\\"') + '"' for n in ns)
    return "static const char *const rk_rakudo_methods[] = {\n%s\n};\nstatic const int rk_rakudo_methods_n = %d;\n" % (body, len(ns))

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--raku", default="/usr/bin/raku")
    ap.add_argument("--out", default=os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "src", "runtime", "rk_rakudo_method_names.inc"))
    ap.add_argument("--check", action="store_true")
    a = ap.parse_args()
    ns = names(a.raku)
    text = emit(ns)
    here = os.path.dirname(os.path.abspath(__file__))
    def reflowed(path):
        subprocess.run([sys.executable, os.path.join(here, "util_reflow_200.py"), "--apply", path], check=True, stdout=subprocess.DEVNULL)
        return open(path, encoding="utf-8").read()
    if a.check:
        with tempfile.TemporaryDirectory() as td:
            tmp = os.path.join(td, "rk_rakudo_method_names.inc")
            open(tmp, "w", encoding="utf-8").write(text)
            text = reflowed(tmp)
        cur = open(a.out, encoding="utf-8").read() if os.path.exists(a.out) else ""
        print("FRESH" if cur == text else "STALE: the checked-in method names differ from the generator's output")
        sys.exit(0 if cur == text else 1)
    open(a.out, "w", encoding="utf-8").write(text)
    reflowed(a.out)
    print("wrote %s: %d method names" % (a.out, len(ns)))

main()
