#!/usr/bin/env bash
# test_gate_icn_no_stack.sh — GROUND ZERO 3 no-value-stack gate for the Icon BB path.
#
# THE RULE (RULES.md FACT RULE, ICON STACKLESS ONE-REGISTER FRAME): no g_vstack, no rt_push_*/rt_pop_*
# value-stack traffic in Icon graphs.  Each box's value lives in its own storage cell and consumers read
# the producer's cell directly (Proebsting); there is no operand stack anywhere on the Icon path.
#
# ⛔ SURFACE REPAIRED + BASELINE 127 -> 0 (s247, seat1, rung N-0).  The gate as written censused
# "${SRC}/templates/ ${SRC}/emitter/emit_bb.c".  emit_bb.c HAS NOT EXISTED FOR MANY SESSIONS: grep printed
# "No such file" to stderr, kept going with the surviving path, and the pipe to wc discarded its exit
# status — so half the named surface was silently absent and nobody was told.  Worse, the ceiling stayed at
# the s205-era BASELINE=127 while the measured count is 0 TREE-WIDE, so 127 new value-stack emissions could
# have landed with the gate still printing OK.  Two laws come out of that and are mechanized below:
#   (1) CENSUS A TREE, NEVER A FILE LIST — a directory cannot be renamed out from under the gate the way a
#       file can, and this gate's own rot is the proof.
#   (2) THE SURFACE MUST BE ASSERTED — if a censused root is missing the gate FAILS LOUD (exit 2) instead of
#       measuring whatever is left.  A gate that cannot see its subject must say so, never return OK.
# The family is now genuinely extinct (0 occurrences in ALL of src/), so this is a ZERO-ASSERT, not a
# ratchet: any reintroduction fails.  Negative-tested by injection at s247 (a planted rt_push_value in a
# template makes it exit 1).
# AUTHORS: Lon Jones Cherryholmes · Jeffrey Cooper M.D. · Claude Sonnet · Claude Fable  DATE: 2026-05-30 (repaired 2026-08-21)
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="${HERE}/../../SCRIP/src"
MAX="${MAX:-0}"

[ -d "${SRC}" ] || { echo "GATE FAIL(2): census surface ${SRC} does not exist — the gate cannot see its subject."; exit 2; }

HITS=$(grep -rnoE 'rt_(push|pop)_[a-z_]+|g_vstack' "${SRC}" 2>/dev/null | grep -v _pl_ || true)
COUNT=$(printf '%s' "${HITS}" | grep -c . || true)

echo "=== GROUND ZERO 3 — Icon no-value-stack gate ==="
echo "surface: ${SRC} (whole tree)"
echo "rt_push_*/rt_pop_*/g_vstack occurrences on the Icon path: ${COUNT}  (ceiling ${MAX}, target 0)"
if [ "${COUNT}" -gt 0 ]; then
    echo "--- per-file breakdown ---"
    printf '%s\n' "${HITS}" | sed -E 's,.*/([^/:]+):[0-9]+:,\1  ,' | sort | uniq -c | sort -rn
fi

if [ "${COUNT}" -gt "${MAX}" ]; then
    echo "FAIL: count ${COUNT} exceeds ceiling ${MAX} — a value-stack emission was reintroduced."
    exit 1
fi
echo "OK: count ${COUNT} <= ceiling ${MAX} — the value stack is extinct on the Icon path."
exit 0
