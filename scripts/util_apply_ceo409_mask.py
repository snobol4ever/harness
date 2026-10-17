#!/usr/bin/env python3
"""util_apply_ceo409_mask.py -- apply the CEO-409 line masks of ONE suite entry to a stream on stdin.

⛔⭐ THIS IS A SHIM OVER corpus_suite_harness.py, NEVER A SECOND IMPLEMENTATION.  It imports that file's own
read_mask_sidecar() and apply_line_mask(), so a bash runner and the python harness mask the SAME lines by the
SAME rules: the same sidecar path derivation (<stem>.mask beside <stem>.ref), the same REGEX DIALECT (python's,
not awk's ERE -- a mask written once must not mean two different things depending on which runner reads it), and
the same replace-never-delete marker.  ⭐ THE DIALECT IS THE WHOLE REASON THIS IS A SHIM: `\\d`, `(?i)` and lazy
quantifiers are all silently different or absent in an ERE, so a re-implementation would agree on every mask
anyone happened to test and diverge on the first one they did not.

Usage:  util_apply_ceo409_mask.py <ref-path> <entry-name> <count-out-path> [--side=oracle|scrip]  < stream > masked-stream
--side names whose stream this is (CEO-1316 (2)): an ORACLE-ONLY row removes its one line only from --side=oracle, and does
nothing on --side=scrip or with no side -- a caller that cannot say which stream it holds can never delete a line.
Writes the masked stream to stdout and the masked-line COUNT to <count-out-path> (guardrail 3: an invisible mask
is the hiding mechanism, a counted one is a measurement).  REFUSES rc=2 on a malformed sidecar, which is
read_mask_sidecar()'s own refusal -- not a copy of its policy.  ⭐ And <count-out-path>.major: 1 when guardrail 4 makes THIS stream's
fixture UNGRADABLE, 0 otherwise, decided by the harness's own mask_majority() over the stream's line count (grep -c '' counts the
same lines) -- so a bash runner never restates the rule, and an ORACLE-IDENTITY row (ceo CEO-1351) is exempt there exactly as here.
"""
import importlib.util, os, sys, pathlib
def refuse(msg):
    sys.stderr.write("REFUSE(rc=2): util_apply_ceo409_mask.py: %s\n" % msg); sys.exit(2)
side = "both"
if len(sys.argv) == 5 and sys.argv[4] in ("--side=oracle", "--side=scrip"):
    side = sys.argv[4].split("=", 1)[1]
elif len(sys.argv) != 4:
    refuse("needs <ref-path> <entry-name> <count-out-path> [--side=oracle|scrip]; got %r" % (sys.argv[1:],))
ref_path, entry, count_out = sys.argv[1], sys.argv[2], sys.argv[3]
h = pathlib.Path(__file__).resolve().parent / "corpus_suite_harness.py"
if not h.is_file():
    refuse("corpus_suite_harness.py is not beside this file (%s) -- the shared body moved; re-point rather than "
           "re-implement, because a second masker is a second dialect" % h)
spec = importlib.util.spec_from_file_location("_csh", str(h))
mod = importlib.util.module_from_spec(spec)
try:
    spec.loader.exec_module(mod)
except SystemExit:
    raise
except Exception as e:
    refuse("cannot import corpus_suite_harness.py: %s: %s" % (type(e).__name__, e))
for fn in ("read_mask_sidecar", "apply_line_mask", "masks_for", "mask_guard_patterns", "mask_majority"):
    if not hasattr(mod, fn):
        refuse("corpus_suite_harness.py has no %s() -- the mask mechanism was renamed or removed; re-derive this "
               "shim rather than grade a name that no longer exists" % fn)
masks = mod.read_mask_sidecar(ref_path)          # its own rc=2 refusal on a row with no reason
pats = mod.masks_for(masks, entry)               # `*` + this entry's own rows, resolved by the harness's rule
# ⛔⭐ BYTES IN, THE SAME BYTES OUT -- surrogateescape, NOT errors="replace" (hq_T 2026-09-08, found by running it:
# csnobol4's 8bit.sno prints byte 0x80 and plain text mode raised UnicodeDecodeError on the first program of the
# suite). A masker sits in the GRADING path, so anything it does to a byte it did not mask is a verdict change it
# was never asked to make: "replace" would rewrite every non-UTF-8 byte to U+FFFD on BOTH sides, and two streams
# that differ only in bytes it mangled would then compare EQUAL. surrogateescape round-trips arbitrary bytes
# losslessly, so an unmasked line leaves exactly as it arrived.
text = sys.stdin.buffer.read().decode("utf-8", "surrogateescape")
out, n = mod.apply_line_mask(text, pats, side=side)
g = mod.apply_line_mask(text, mod.mask_guard_patterns(pats), side=side)[1]
lines = text.count("\n") + (1 if text and not text.endswith("\n") else 0)
pathlib.Path(count_out).write_text(str(n))
pathlib.Path(count_out + ".major").write_text("1" if n and mod.mask_majority(lines, n, g) else "0")
sys.stdout.buffer.write(out.encode("utf-8", "surrogateescape"))
