#!/bin/bash
# test_gate_stdin_block_keeps_a_missing_final_newline.sh -- A STDIN BLOCK IS THE PROGRAM'S STDIN TO THE BYTE, ITS LAST NEWLINE INCLUDED OR NOT.
# Found by hq_runtime 2026-10-24: ProRosetta universal-lambda-machine.in is 8 bytes with no final newline and its ref was cut from those 8;
# read_stdin_sidecar ended every block with a newline, so the graded run fed 9 bytes and the program (swipl too) halted silent -- a staging
# red, not SCRIP's. corpus_suite_harness.py closes such a block with STDIN_NO_FINAL_NEWLINE, written by write_stdin_sidecar, dropped by the reader.
# TWO ARMS: (1) a mktemp fixture outside corpus/ round-trips five stdins through the real writer and reader (none, empty, no final newline, one
# final newline, a trailing blank line) and every one must come back byte-equal; (2) every raw <stem>.in in a corpus table beside an ALL.in that
# lacks a final newline must read back from that ALL.in byte-equal to the raw file. rc 0 both hold, 1 a stdin changed, 2 could not measure.
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CORPUS="$HERE/../../corpus"
[ -d "$CORPUS" ] || { echo "GATE REFUSE(2) [stdin_block_keeps_a_missing_final_newline]: no corpus at $CORPUS"; exit 2; }
exec python3 - "$HERE" "$CORPUS" <<'PY'
import os, sys, tempfile
here, corpus = sys.argv[1], sys.argv[2]
sys.path.insert(0, here)
import corpus_suite_harness as h
if not hasattr(h, "STDIN_NO_FINAL_NEWLINE"):
    print("GATE FAIL [stdin_block_keeps_a_missing_final_newline]: corpus_suite_harness.py names no STDIN_NO_FINAL_NEWLINE -- a block always ends with a newline")
    sys.exit(1)
cases = [("no_stdin", None), ("empty", ""), ("no_final_newline", "00100110"), ("one_final_newline", "a\nb\n"), ("trailing_blank", "x\n\n")]
bad = []
with tempfile.TemporaryDirectory(prefix="gate_stdin_eol.") as d:
    p = os.path.join(d, "ALL.in")
    ents = [h.Entry("block", i + 1, n, ["x."], ["x"], stdin=s) for i, (n, s) in enumerate(cases)]
    h.write_stdin_sidecar(ents, p, "%", "")
    back = [h.Entry("block", i + 1, n, ["x."], ["x"]) for i, (n, _) in enumerate(cases)]
    h.read_stdin_sidecar(p, h.banner_re_for("%", ""), back)
    for (n, s), e in zip(cases, back):
        if e.stdin != s:
            bad.append("fixture %s: wrote %r, read %r" % (n, s, e.stdin))
print("STDIN_EOL_FIXTURE cases=%d round_trip=%d" % (len(cases), len(cases) - len(bad)))
raw = 0
for root, dirs, files in os.walk(corpus):
    dirs[:] = [x for x in dirs if x != ".git"]
    if "ALL.in" not in files:
        continue
    stems = [f[:-3] for f in files if f.endswith(".in") and f != "ALL.in"]
    lack = [s for s in stems if (lambda b: b and not b.endswith(b"\n"))(open(os.path.join(root, s + ".in"), "rb").read())]
    if not lack:
        continue
    lines = open(os.path.join(root, "ALL.in")).read().splitlines()
    opener = lines[0][:1] if lines else "%"
    rx = h.banner_re_for(opener, "")
    names = [m.group("name") for m in map(rx.match, lines) if m]
    ents = [h.Entry("block", i + 1, n, ["x."], ["x"]) for i, n in enumerate(names)]
    h.read_stdin_sidecar(os.path.join(root, "ALL.in"), rx, ents)
    got = {e.name: e.stdin for e in ents}
    for s in lack:
        raw += 1
        want = open(os.path.join(root, s + ".in"), "rb").read().decode()
        if got.get(s) != want:
            bad.append("corpus %s/%s: %s.in is %d bytes, its ALL.in block reads %r" % (os.path.relpath(root, corpus), s, s, len(want), got.get(s)))
print("STDIN_EOL_CORPUS raw_without_final_newline=%d agree=%d" % (raw, raw - len([b for b in bad if b.startswith("corpus")])))
for b in bad:
    print("  " + b)
if bad:
    print("GATE FAIL [stdin_block_keeps_a_missing_final_newline]: %d stdin(s) do not come back byte-equal" % len(bad))
    sys.exit(1)
print("GATE PASS [stdin_block_keeps_a_missing_final_newline]: %d fixture stdins and %d corpus stdins without a final newline read back byte-equal" % (len(cases), raw))
PY
