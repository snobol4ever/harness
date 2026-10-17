#!/usr/bin/env bash
# test_smoke_snobol4_js.sh — ⛔ REFUSES rc=2. THE SUBJECT IS GONE, NOT THE FIXTURES.
# Row dead-suite-path-consumer-sweep (hq_C 2026-09-04). This script used to smoke the SNOBOL4→JavaScript
# emitter over corpus/tests/snobol4/smoke/. BOTH halves of it are gone, and only one of them was visible:
#   1. THE PATH: corpus/tests/snobol4/smoke/ went away with the one-flat-suite ruling. The rungs carries
#      exactly ONE smoke-named origin (`smoke_null__smoke_null`), so there is no population to repoint at.
#   2. ⛔ THE BACKEND: `--target=js` is REMOVED FROM THE DRIVER. Measured 2026-09-04 on SCRIP cb60deb7f:
#      `./scrip --target=js x.sno` prints "[SMX] --target=js removed (Stack-Machine codegen removed)." rc=1
#      (src/driver/scrip.c — every --target other than x86 is refused there). x86 is the only live backend;
#      jvm/js/net/wasm are the PLANNED roadmap (Lon 2026-08-28), stubbed, not built.
# ⭐ WHY THIS REFUSES INSTEAD OF BEING REPOINTED: repointing a path would have produced a runnable script that
# grades a backend the driver rejects — a green-or-red verdict about nothing. And it exited 1 before, which
# reads as A FAILING TEST rather than AN ABSENT ONE (RULES.md § an instrument must distinguish "measured and
# clean" from "never ran"; a test that cannot measure REFUSES rc=2). Anyone reviving the JS backend should
# restore this script from git history alongside it — `git log --follow -- ../harness/scripts/test_smoke_snobol4_js.sh`.
echo "⛔ REFUSE(2): the SNOBOL4→JavaScript smoke cannot measure — the driver removed --target=js (Stack-Machine codegen removed, src/driver/scrip.c), and corpus/tests/snobol4/smoke/ no longer exists. Not a failing test: an absent one. x86 is the only live backend." >&2
exit 2
