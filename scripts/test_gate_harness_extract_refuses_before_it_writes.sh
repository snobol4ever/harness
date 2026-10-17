#!/usr/bin/env bash
# test_gate_harness_extract_refuses_before_it_writes.sh -- `corpus_suite_harness.py extract` of an entry that carries stdin, asked
# without --out-in, refuses rc 2 AND WRITES NOTHING; with --out-in it writes the program, its .ref and its stdin.
#
# WHY (the coo 2026-10-03, on the ceo's report that SncM's trim_size_keyword_replace_1 and trim_dupl_size_replace_1 would not
# extract by name): extract found both and refused, as it should, because each carries stdin -- but it wrote the program and its .ref
# BEFORE the refusal, so an rc 2 left exactly the stdin-starved witness the refusal exists to prevent on disk, for any caller that read
# the files and not the rc. The population is a scratch container of two entries, one with stdin and one without.
#   R  the stdin entry without --out-in: rc 2, the refusal names --out-in, and none of the three paths exists
#   I  the stdin entry with --out-in: rc 0, the program, the .ref and the stdin all written, the stdin byte-equal to the container's
#   N  the entry without stdin and without --out-in: rc 0, the program written (no refusal where there is nothing to refuse)
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GATE_NAME=harness_extract_refuses_before_it_writes
. "$HERE/lib_gate.sh"
H="$HERE/corpus_suite_harness.py"
gate_require "$H" "corpus_suite_harness.py"
W="$(mktemp -d "${TMPDIR:-/tmp}/gate_extract.XXXXXX")" || { echo "GATE UNPROVEN(2) [$GATE_NAME]: mktemp failed"; exit 2; }
trap 'rm -rf "$W"' EXIT
PASS=0; FAIL=0
ok()  { echo "  ✅ $1: $2"; PASS=$((PASS+1)); }
red() { echo "  ⛔ $1 RED: $2"; FAIL=$((FAIL+1)); }

python3 - "$HERE" "$W" <<'PY' || { echo "GATE UNPROVEN(2) [$GATE_NAME]: could not build the scratch container"; exit 2; }
import sys; sys.path.insert(0, sys.argv[1]); import corpus_suite_harness as h
W = sys.argv[2]; b1 = h.make_banner(1, "reads"); b2 = h.make_banner(2, "plain")
open(f"{W}/ALL.sno", "w").write(f"{b1}\n        OUTPUT = INPUT\nEND\n{b2}\n        OUTPUT = 'x'\nEND\n")
open(f"{W}/ALL.ref", "w").write(f"{b1}\nhello\n{b2}\nx\n")
open(f"{W}/ALL.in", "w").write(f"{b1}\nhello\n")
PY

o=$(python3 "$H" extract "$W/ALL.sno" "$W/ALL.ref" reads "$W/r.sno" --out-ref "$W/r.ref" 2>&1); r=$?
left=$(ls "$W/r.sno" "$W/r.ref" "$W/r.in" 2>/dev/null | wc -l)
[ "$r" = 2 ] && grep -q -- '--out-in was not given' <<<"$o" && [ "$left" = 0 ] \
  && ok R "a stdin entry without --out-in refuses rc 2 and writes none of its files" \
  || red R "rc=$r files-left=$left (want rc 2 and 0): $(head -1 <<<"$o" | cut -c1-140)"

o=$(python3 "$H" extract "$W/ALL.sno" "$W/ALL.ref" reads "$W/i.sno" --out-ref "$W/i.ref" --out-in "$W/i.in" 2>&1); r=$?
[ "$r" = 0 ] && [ -s "$W/i.sno" ] && [ -s "$W/i.ref" ] && [ "$(cat "$W/i.in" 2>/dev/null)" = hello ] \
  && ok I "with --out-in the program, its .ref and its stdin are written, the stdin byte-equal to the container's" \
  || red I "rc=$r sno=$(wc -c < "$W/i.sno" 2>/dev/null) ref=$(wc -c < "$W/i.ref" 2>/dev/null) in='$(cat "$W/i.in" 2>/dev/null)': $(head -1 <<<"$o" | cut -c1-140)"

o=$(python3 "$H" extract "$W/ALL.sno" "$W/ALL.ref" plain "$W/n.sno" --out-ref "$W/n.ref" 2>&1); r=$?
[ "$r" = 0 ] && [ -s "$W/n.sno" ] && [ ! -e "$W/n.in" ] \
  && ok N "an entry without stdin extracts rc 0 without --out-in" \
  || red N "rc=$r sno=$(wc -c < "$W/n.sno" 2>/dev/null): $(head -1 <<<"$o" | cut -c1-140)"

echo "population: 3 arms over a scratch container of 2 entries (1 carrying stdin)"
if [ "$FAIL" = 0 ]; then echo "GATE PASS [$GATE_NAME]: $PASS of 3 arms green"; exit 0; fi
echo "⛔ GATE FAIL [$GATE_NAME]: $FAIL of 3 arms red"; exit 1
