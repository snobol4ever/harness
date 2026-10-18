#!/usr/bin/env bash
export S4E_ONE_RUNNER_FIXTURE="gate arm ${0##*/}: a runner invoked as an instrument fixture, not a board (CEO-523)"
export S4E_MINT_NO_CRITERION="gate fixture: the row under test exercises the bus, not work (CEO-1386)"
# test_gate_ref_cutters_refuse_a_dead_oracle.sh -- THE ACCEPTANCE GATE for row every-ref-cutting-path-refuses-
# when-the-oracle-dies-mid-cut (ceo -> hq_T 2026-09-04, instrument side of seat07's rung04 FINDING; the ORACLE
# cure is hq_P's row snobol4-oracle-sbl-bf-sigsegv-on-error-212-recovery-cuts-refs-silently).
#
# THE DEFECT CLASS: `sbl -bf` SIGSEGVs on about half its ERROR 212 runs WHILE PRINTING the diagnostic. A cutter
# that asks only "did the oracle produce bytes?" then writes a TRUNCATED ref -- and a truncated ref is the worst
# artifact this project can produce, because it is a plausible-looking pin that grades every future run against
# a lie, and nothing downstream can tell it from a good one.
#
# ⛔⭐ FOUR OF FIVE CUTTERS ALREADY REFUSED WHEN THIS ROW WAS MINTED. That is why this file is a GATE and not a
# sweep of cures: the value here is the CENSUS WITH A PRINTED DENOMINATOR (ARM 6), so a NEW cutter -- the sixth,
# written a month from now by someone who never read seat07's finding -- reds HERE, rather than by pinning a
# truncated ref that nobody notices for weeks. A cure protects the paths that exist; a census protects the ones
# that do not exist yet.
#
# ⛔⛔ THE PROBE PRINTS OUTPUT AND *THEN* SEGFAULTS, and that is the whole difficulty. An oracle that dies
# silently is caught by any "did it produce anything?" check, so a gate built on one would pass on a cutter that
# has no status check at all. The synthetic oracle below emits two good lines AND the ERROR 212 footer before
# killing itself with SIGSEGV -- the exact shape of the real failure, in which every byte written so far looks
# like a correct answer.
#
# ⭐ ARM 7 IS THE CONTROL, AND IT IS NOT OPTIONAL: with a WELL-BEHAVED synthetic oracle the same paths must
# actually mint. Without it, a cutter that refused everything unconditionally -- or a probe harness that never
# reached the cutter at all -- would pass every other arm here (RULES.md THE INSTRUMENT LAWS: agreement counts
# only when the arms can disagree).
#
# ARMS: 1 the probe itself behaves as designed · 2 the harness's shared oracle reader classifies it CRASH, which
# is the mechanism cmd_capture_oracle_refs's `kind != RAN` guard rests on · 3 the package builder excludes it
# naming the signal · 4 scorecard's cmd_oracle (util_ref_mint's one door to the oracle) classifies SIG11 and so
# never reaches its LIVE mint path · 5 util_mint_bench_refs names the signal and mints nothing · 6 the CENSUS,
# printed denominator · 7 the control: a healthy oracle still mints.
# EXIT: 0 all arms · 1 an arm failed · 2 REFUSED (could not measure: no python3, missing cutter, mktemp failed).
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
S4E="${S4E_HOME:-$(cd "$ROOT/.." && pwd)}"
command -v python3 >/dev/null 2>&1 || { echo "⛔ REFUSED-TO-GRADE rc=2: python3 not on PATH"; exit 2; }
for f in corpus_suite_harness.py util_build_package_suite.py util_ref_mint.sh util_mint_bench_refs.sh scorecard_snobol4.sh; do
    [ -f "$HERE/$f" ] || { echo "⛔ REFUSED-TO-GRADE rc=2: cutter under test missing: $HERE/$f"; exit 2; }
done
W="$(mktemp -d "${TMPDIR:-/tmp}/gate_refcut.XXXXXX")" || { echo "⛔ REFUSED-TO-GRADE rc=2: mktemp failed"; exit 2; }
trap 'rm -rf "$W"' EXIT
fails=0; checks=0
ck() { checks=$((checks+1)); if [ "$1" = ok ]; then printf '  ok    %s\n' "$2"; else printf '  FAIL  %s\n' "$2"; fails=$((fails+1)); fi; }

# ── the two synthetic oracles. DEAD prints good output, then the real ERROR 212 footer, then SIGSEGVs.
cat > "$W/oracle_dead" <<'EOF'
#!/usr/bin/env bash
printf 'HELLO\nWORLD\n'
printf ' : ERROR 212 -- recovery\nin statement 7\n'
kill -SEGV $$
EOF
cat > "$W/oracle_live" <<'EOF'
#!/usr/bin/env bash
printf 'HELLO\nWORLD\n'
EOF
chmod +x "$W/oracle_dead" "$W/oracle_live"
printf ' OUTPUT = "HELLO"\n OUTPUT = "WORLD"\nEND\n' > "$W/probe.sno"

echo "=== gate: every ref-cutting path refuses when the oracle dies mid-cut ==="
echo "--- ARM 1: the probe behaves as designed -- output FIRST, signal death SECOND ---"
out="$("$W/oracle_dead" "$W/probe.sno" 2>/dev/null)"; rc=$?
[ "$rc" = 139 ] && ck ok "synthetic oracle exits 139 (SIGSEGV)" || ck no "probe must die by SIGSEGV; got rc=$rc"
[ "$(printf '%s\n' "$out" | grep -c .)" -ge 2 ] && ck ok "and it printed plausible output before dying (the hard case)" \
    || ck no "probe printed nothing -- a silently-dying oracle proves nothing about this class"

echo "--- ARM 2: the harness's shared oracle reader classifies it CRASH (the guard capture-oracle-refs rests on) ---"
# ⭐ Driven at the FUNCTION, not through the CLI, on purpose: sbl_correctness_bin() hardcodes the shared oracle
# path with no env override -- deliberately, so nobody can quietly grade against a private fallback (RULES.md).
# Adding a test-only backdoor to make this arm convenient would weaken the very rule that makes the real oracle
# trustworthy, so the arm reaches the mechanism directly instead.
out="$(cd "$HERE" && python3 - "$W" <<'PY' 2>&1
import sys, importlib.util, pathlib
W = pathlib.Path(sys.argv[1])
spec = importlib.util.spec_from_file_location("h", "corpus_suite_harness.py")
h = importlib.util.module_from_spec(spec); sys.argv = ["h"]
try: spec.loader.exec_module(h)
except SystemExit: pass
text, rc, kind = h.run_oracle(str(W / "oracle_dead"), "", W / "probe.sno", 20)
print("kind=%s rc=%s bytes=%d" % (kind, rc, len(text)))
guard_skips = kind != "RAN"
print("capture_guard_skips=%s" % guard_skips)
PY
)"; rc=$?
grep -q 'kind=CRASH' <<<"$out" && ck ok "run_oracle classifies a signal death as CRASH" || ck no "want kind=CRASH; got: $out"
grep -q 'capture_guard_skips=True' <<<"$out" && ck ok "cmd_capture_oracle_refs's 'kind != RAN' guard therefore skips the stem" \
    || ck no "the capture guard would have minted a ref: $out"
grep -qE 'bytes=[1-9]' <<<"$out" && ck ok "and it did so DESPITE the oracle having produced output (the truncated-ref case)" \
    || ck no "the probe produced no output at the reader, so this arm proved the easy case only: $out"

echo "--- ARM 3: the package builder excludes a signal-killed oracle, naming the signal ---"
out="$(cd "$HERE" && python3 - "$W" <<'PY' 2>&1
import sys, importlib.util, pathlib
W = pathlib.Path(sys.argv[1])
spec = importlib.util.spec_from_file_location("h", "corpus_suite_harness.py")
h = importlib.util.module_from_spec(spec); sys.argv = ["h"]
try: spec.loader.exec_module(h)
except SystemExit: pass
_t, rc, _k = h.run_oracle(str(W / "oracle_dead"), "", W / "probe.sno", 20)
# util_build_package_suite's own guard, quoted from its source: `if ora_rc is not None and ora_rc < 0`
print("builder_excludes=%s signal=%s" % (rc is not None and rc < 0, -rc if rc is not None and rc < 0 else "n/a"))
PY
)"
grep -q 'builder_excludes=True' <<<"$out" && ck ok "build()'s 'ora_rc < 0' guard excludes it (signal named, no entry minted)" \
    || ck no "the package builder would have absorbed a truncated ref: $out"
grep -q "ora_rc is not None and ora_rc < 0" "$HERE/util_build_package_suite.py" \
    && ck ok "and that guard is still the one in the file (this arm is not quoting a deleted line)" \
    || ck no "util_build_package_suite.py no longer carries the 'ora_rc < 0' guard this arm models"

echo "--- ARM 4: scorecard's cmd_oracle classifies SIG11, so util_ref_mint never reaches its LIVE mint path ---"
out="$(SBL="$W/oracle_dead" timeout -k 5 60 bash "$HERE/scorecard_snobol4.sh" oracle feature_test "$W/probe.sno" "$W/sc.out" 2>&1)"
st="$(printf '%s' "$out" | tail -1 | cut -f1)"
case "$st" in
    SIG11) ck ok "cmd_oracle classifies the run SIG11 (never LIVE, so util_ref_mint mints nothing)" ;;
    LIVE)  ck no "cmd_oracle called a segfaulted run LIVE -- util_ref_mint would pin a truncated ref" ;;
    *)     ck ok "cmd_oracle refuses the run (status=$st, not LIVE)" ;;
esac

echo "--- ARM 5: util_mint_bench_refs names the signal and mints nothing ---"
out="$(SBL="$W/oracle_dead" timeout -k 5 300 bash "$HERE/util_mint_bench_refs.sh" 2>/dev/null)"
grep -q 'KILLED BY SIGNAL' <<<"$out" && ck ok "the refusal NAMES the signal (it once printed 'rc=0' for a SIGSEGV)" \
    || ck no "the refusal does not name the signal -- a refusal whose diagnostic says the oracle succeeded"
grep -qE 'minted: 0' <<<"$out" && ck ok "and minted 0 refs" || ck no "refs were minted from a dead oracle: $(tail -2 <<<"$out")"

echo "--- ARM 6 (census, PRINTED DENOMINATOR): every script that cuts a .ref from a live oracle reads the status ---"
# ⛔ THE DENOMINATOR IS COMPUTED, NEVER PINNED: a cutter is any script that both invokes an oracle binary AND
# writes a .ref. Pinning the count would make this arm pass on the day someone adds the sixth cutter, which is
# the ONLY day it matters.
cutters=0; missing=""
for f in "$HERE"/*.sh "$HERE"/*.py; do
    b="$(basename "$f")"
    case "$b" in test_gate_ref_cutters_refuse_a_dead_oracle.sh) continue;; esac
    # ⛔ COMMENTS STRIPPED FIRST, or this census matches a DESCRIPTION of ref-cutting instead of ref-cutting.
    # Measured on the first run: test_crosscheck_all_backends.sh was named as a cutter with no status check, on
    # the strength of four header lines reading "compile .sno -> .s -> nasm -> run, diff vs .ref". It writes no
    # ref at all -- it DIFFS against one. Same trap as the stale-binary gate's ARM 11, in a different file, two
    # hours later: a grep for a string is a statement about what a file SAYS.
    body="$(grep -vE '^[[:space:]]*(#|//)' "$f")"
    grep -qE '\bsbl|icont|iconx|swipl|gprolog|rakudo|\$SBL|oracle_bin' <<<"$body" || continue
    grep -qE '>[[:space:]]*"?[^|]*\.ref|write_text|cp [^|]*\.ref|out_ref' <<<"$body" || continue
    cutters=$((cutters+1))
    # a status check = it reads a return code, a signal, or routes through a classifier that does
    grep -qE 'rc\b|returncode|\$\?|SIG|kind|cmd_oracle|run_oracle|sc_oracle_run' <<<"$body" || missing="$missing $b"
done
echo "    cutters=$cutters"
[ "$cutters" -ge 4 ] && ck ok "census floor: $cutters ref-cutting path(s) examined (zero-examined would be indistinguishable from all-clean)" \
    || ck no "only $cutters cutter(s) found -- the census is not reaching the tree it claims to cover"
[ -z "$missing" ] && ck ok "every censused cutter reads the oracle's status" \
    || ck no "cutter(s) with no status check:$missing"

echo "--- ARM 7 (THE CONTROL): a HEALTHY oracle still mints -- the guards are not refusing unconditionally ---"
out="$(cd "$HERE" && python3 - "$W" <<'PY' 2>&1
import sys, importlib.util, pathlib
W = pathlib.Path(sys.argv[1])
spec = importlib.util.spec_from_file_location("h", "corpus_suite_harness.py")
h = importlib.util.module_from_spec(spec); sys.argv = ["h"]
try: spec.loader.exec_module(h)
except SystemExit: pass
text, rc, kind = h.run_oracle(str(W / "oracle_live"), "", W / "probe.sno", 20)
print("kind=%s rc=%s text=%r" % (kind, rc, text))
PY
)"
grep -q 'kind=RAN' <<<"$out" && ck ok "a well-behaved oracle reads RAN (so ARM 2's CRASH is a real discrimination)" \
    || ck no "even a healthy oracle is refused -- every arm above would pass on a cutter that refuses everything: $out"
out="$(SBL="$W/oracle_live" timeout -k 5 60 bash "$HERE/scorecard_snobol4.sh" oracle feature_test "$W/probe.sno" "$W/sc2.out" 2>&1)"
st="$(printf '%s' "$out" | tail -1 | cut -f1)"
[ "$st" = LIVE ] && ck ok "and cmd_oracle calls the healthy run LIVE (ARM 4's SIG11 is a real discrimination)" \
    || ck no "cmd_oracle refused a healthy oracle too (status=$st) -- ARM 4 proves nothing"

echo "------------------------------------------------------------"
if [ "$fails" -ne 0 ]; then echo "⛔ GATE FAIL: $fails of $checks check(s) failed (cutters censused: $cutters)"; exit 1; fi
echo "✅ GATE PASS: $checks/$checks checks (cutters censused: $cutters)"; exit 0
