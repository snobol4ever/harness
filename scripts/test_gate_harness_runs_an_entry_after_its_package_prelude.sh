#!/usr/bin/env bash
# test_gate_harness_runs_an_entry_after_its_package_prelude.sh -- corpus_suite_harness.run_suite_entry RUNS EVERY ENTRY AFTER ITS PACKAGE'S
# ALL.prelude (hq_prolog's ask on the ceo's CEO-1632, the Prolog dialect ruling; the coo 2026-10-11). The rosetta-prolog refs were cut by
# swipl, which reads a double-quoted text as a string; SCRIP reads an unmarked program as GNU/ISO, codes. The package's contract with its
# oracle is `:- set_prolog_flag(double_quotes, string).` before every program, declared once in ALL.prelude beside the container, the way
# util_logtalk_grade.py prepends the iso flag. The prelude is prefixed to the entry's FIRST LINE so a line a message names stays the entry's.
# Hermetic, needs the build (it runs scrip in both modes): one Prolog entry printing which reading "ab" got, graded against `string`:
#   arm 1  ALL.prelude holds the directive                    -> PASS in m3 and m4
#   arm 2  no ALL.prelude                                      -> FAIL in m3 and m4 (the entry exactly as before: codes)
#   arm 3  an ALL.prelude of `#` notes and blank lines only    -> FAIL, the entry unchanged
#   arm 4  the directive among notes and blank lines           -> PASS (notes dropped, the rest joined)
# FAIL_ONCE=1 removes arm 1's prelude, which must then read red.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
G=test_gate_harness_runs_an_entry_after_its_package_prelude
[ -x "$HERE/../../SCRIP/scrip" ] || { echo "⛔ REFUSE(2) [$G]: no scrip binary beside the scripts -- run make first"; exit 2; }
"$HERE/util_require_fresh.sh" --gate "$G" "$HERE/../../SCRIP/scrip" "$HERE/../../SCRIP/out/libscrip_rt.so" || exit 2
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
mkdir -p "$T/a1" "$T/a2" "$T/a3" "$T/a4" "$T/tmp"
printf ':- set_prolog_flag(double_quotes, string).\n' > "$T/a1/ALL.prelude"
printf '# notes only -- no directive\n\n# another\n' > "$T/a3/ALL.prelude"
printf '# the contract with the oracle\n\n:- set_prolog_flag(double_quotes, string).\n\n' > "$T/a4/ALL.prelude"
[ -n "${FAIL_ONCE:-}" ] && rm -f "$T/a1/ALL.prelude"
S4E_PROGRESS_OFF=1 python3 - "$HERE" "$T" <<'PY'
import sys
from pathlib import Path
sys.path.insert(0, sys.argv[1])
import corpus_suite_harness as h
T = Path(sys.argv[2]); paths = h.resolve_paths()
src = [':- initialization(main).', 'main :- X = "ab", ( string(X) -> write(string) ; write(codes) ), nl.']
want = {"a1": "PASS", "a2": "FAIL", "a3": "FAIL", "a4": "PASS"}
what = {"a1": "ALL.prelude holds the directive", "a2": "no ALL.prelude: the entry as before",
        "a3": "notes and blank lines only: the entry unchanged", "a4": "the directive among notes and blank lines"}
bad = 0
for arm in ("a1", "a2", "a3", "a4"):
    e = h.Entry("block", 1, "dq", list(src), ["string"])
    v = h.run_suite_entry(paths, e, T / "tmp", ["m3", "m4"], ext=".pl", companion_dir=T / arm)
    got = {m: getattr(v.get(m), "kind", "?") for m in ("m3", "m4")}
    ok = all(k == want[arm] for k in got.values())
    bad += 0 if ok else 1
    print("  %s   arm %s %s -> m3 %s m4 %s (want %s)" % ("ok  " if ok else "FAIL", arm[1], what[arm], got["m3"], got["m4"], want[arm]))
print("population: 4 arms, one Prolog entry, both modes")
sys.exit(1 if bad else 0)
PY
rc=$?
[ "$rc" = 0 ] && { echo "GATE PASS(0) [$G]: an entry runs after its package's ALL.prelude, prefixed to its first line; no prelude, no change"; exit 0; }
[ "$rc" = 1 ] && { echo "GATE FAIL(1) [$G]: the harness does not run an entry after its package's prelude as declared"; exit 1; }
echo "⛔ REFUSE(2) [$G]: the probe could not run (rc=$rc)"; exit 2
