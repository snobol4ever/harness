#!/usr/bin/env bash
# test_crosscheck_x86_single_program.sh — ⛔ REFUSES rc=2. THREE OF ITS FOUR INGREDIENTS NO LONGER EXIST.
# Row dead-suite-path-consumer-sweep (hq_C 2026-09-04). Sprint-A10 fossil: it compiled beauty.sno with a
# `-x86` flag, assembled the result with `nasm`, and diffed against corpus/crosscheck/beauty/. Measured
# 2026-09-04 on SCRIP cb60deb7f:
#   1. `./scrip -x86 …` → "scrip: cannot open '-x86'" rc=1 — THE FLAG IS GONE. ⛔ Note the failure shape:
#      an unrecognised flag falls through to the FILENAME path, so a dead flag is indistinguishable from a
#      typo'd source path, and the message names the flag while a skimmer reads it as a missing program.
#   2. corpus/crosscheck/ is GONE (converted into the rungs suites, corpus d5513783 / da098747).
#   3. The emitter emits GAS via the x86(...) encoder, not nasm syntax; the live route is `--compile`.
# ⭐ THE SUBJECT IS STILL LIVE AND ALREADY COVERED — that is why this is a refusal and not a rewrite.
# beauty.sno self-hosting through mode 4 is graded by `test_gate_sn7_beauty_self_host.sh` and
# `test_gate_em_beauty_subsystems_mode4.sh`; the two crosscheck_beauty entries live in the SNOBOL4 rungs
# (`crosscheck_beauty__gen_tab_marker`, `crosscheck_beauty__gen_cont_split`) and are graded by
# `test_corpus_snobol4.sh`. Reviving this script would add a fourth, weaker grader of the same thing.
echo "⛔ REFUSE(2): this crosscheck cannot measure — the '-x86' flag was removed from the driver, corpus/crosscheck/ was folded into the rungs suites, and the emitter is GAS-via-x86() not nasm. beauty.sno mode-4 self-hosting is graded by test_gate_sn7_beauty_self_host.sh and the rungs' crosscheck_beauty entries." >&2
exit 2
