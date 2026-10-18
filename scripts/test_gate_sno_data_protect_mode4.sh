#!/usr/bin/env bash
# stale-binary preflight (row test-gate-scripts-that-grade-scrip-refuse-on-a-stale-binary-census-widened, hq_T 2026-09-05)
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
# test_gate_sno_data_protect_mode4.sh -- DATA() of a protected system-function name raises ERROR 248 under SCRIP
# mode 4 (compile + link), and execution does not continue past it. Isolated as a minimal witness rather than
# running SPITBOL testpgms test6.spt itself (test6.spt line 16 is the real-world case -- DATA('ITEM(COUNT,TOP)')
# -- but the file doesn't compile at all under mode 4 for an unrelated reason: a name-operator pattern-match/EVAL
# form outside the landed subset, see GOAL-SNOBOL4-BB.md). This gate does not check the diagnostic's file/line
# fields -- those read as "(0)"/"in statement 0" because rt_stmt_enter (src/runtime/keywords.c:443) is never
# emitted for DATA/DEFINE/OPSYN's declarative dispatch (confirmed live under gdb: core_runtime_error's caller
# chain never passes through rt_stmt_enter for this class of statement). That gap is systemic across "the whole
# error-path population" (hq_P), not specific to DATA, and is out of scope here -- see the companion FINDING.
# EXIT 0 mode-4 binary reports ERROR 248 and does not continue · 1 it doesn't/does · 2 REFUSED (not built)
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
SCRIP="${SCRIP:-$ROOT/scrip}"; [ -x "$SCRIP" ] || { echo "⛔ GATE REFUSE(2) [sno-data-protect-mode4]: $SCRIP not built"; exit 2; }
LIBDIR="$ROOT/out"; [ -f "$LIBDIR/libscrip_rt.so" ] || { echo "⛔ GATE REFUSE(2) [sno-data-protect-mode4]: $LIBDIR/libscrip_rt.so missing"; exit 2; }
W="/tmp/$$-sno-data-protect-mode4"; mkdir -p "$W"; trap 'rm -rf "$W"' EXIT
printf "\tDATA(%sITEM(COUNT,TOP)%s)\n\tOUTPUT = %sunreached%s\nEND\n" "'" "'" "'" "'" > "$W/w.sno"
"$SCRIP" --compile "$W/w.sno" -o "$W/w.s" </dev/null || { echo "⛔ GATE FAIL(1) [sno-data-protect-mode4]: mode-4 compile itself aborted -- protection must fire at RUNTIME, not compile time"; exit 1; }
gcc -m64 -no-pie -rdynamic "$W/w.s" -Wl,-rpath,"$LIBDIR" -L"$LIBDIR" -lscrip_rt -lm -lpthread -o "$W/w" 2>"$W/ld.log" || { echo "⛔ GATE REFUSE(2) [sno-data-protect-mode4]: link failed, see $W/ld.log"; exit 2; }
out="$("$W/w" </dev/null 2>&1)"
echo "$out" | grep -qi 'error 248' || { echo "⛔ GATE FAIL(1) [sno-data-protect-mode4]: no ERROR 248 in mode-4 output: $out"; exit 1; }
echo "$out" | grep -qi 'unreached' && { echo "⛔ GATE FAIL(1) [sno-data-protect-mode4]: execution continued past the protected DATA() call: $out"; exit 1; }
echo "✅ GATE PASS(0) [sno-data-protect-mode4]: DATA() of a protected name raises ERROR 248 under mode 4 and execution does not continue"
exit 0
