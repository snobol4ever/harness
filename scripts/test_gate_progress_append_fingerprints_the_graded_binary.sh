#!/usr/bin/env bash
# test_gate_progress_append_fingerprints_the_graded_binary.sh -- THE PROGRESS APPENDER'S GROUND IS THE GRADED BINARY'S, NOT THE SEAT ROOT'S
# (the coo 2026-09-28, row instruments-util-progress-append-fingerprints-the-seat-roots-binary-not-the-one-the-harness-graded-so-a-worktree-
# run-ends-the-ground-moved-after-a-green-board; ceo CEO-1352 ruled it rank 1).
# THE DEFECT, measured three times the same day: corpus_suite_harness.py pins the digest of the binary it GRADES (paths['scrip_bin'], a
# worktree's or SCRIP=), and util_progress_append.py re-read S4E_HOME/SCRIP/scrip at append time -- so every harness run in a worktree
# ended "THE GROUND MOVED UNDER THIS RUN" rc 2 after a green board, and a row's scrip stamp named the seat root's commit.
# THE ARMS (hermetic: two scratch git checkouts, no scrip run):
#   1  WORKTREE SHAPE: S4E_HOME is checkout A (its own SCRIP/scrip and out/libscrip_rt.so), the graded binary lives in checkout B;
#      pin_context(B's binary) then assert_ground_unmoved() does NOT raise, and the pinned scrip stamp is B's commit, not A's;
#   2  A REAL MOVE STILL REFUSES: rewriting B's binary after the pin makes assert_ground_unmoved() raise ProgressGroundMoved;
#   3  bin_fingerprint() (S4E_BIN_AT_START's shape) with SCRIP/RT_DIR set reads the named binary, and the rebuild of it is seen;
#   4  FAIL-ONCE: the old derivation (S4E_HOME/SCRIP) planted back into a copy of the appender raises on arm 1's fixture.
# EXIT 0 all hold; 1 an arm failed; 2 could not measure.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/lib_gate.sh" || { echo "REFUSING(2): cannot load lib_gate.sh"; exit 2; }
GATE_NAME=progress_append_fingerprints_the_graded_binary
gate_parse_args "$@"
A="$HERE/util_progress_append.py"
gate_require "$A" "util_progress_append.py" || exit 2
W=$(mktemp -d) || exit 2; trap 'rm -rf "$W"' EXIT INT TERM
mkrepo() { mkdir -p "$1/SCRIP/out" "$1/corpus"; printf '%s' "$2" > "$1/SCRIP/scrip"; printf '%s-rt' "$2" > "$1/SCRIP/out/libscrip_rt.so";
  (cd "$1/SCRIP" && git init -q && git add -A && git -c user.name=g -c user.email=g@g commit -q -m "$2") && (cd "$1/corpus" && git init -q && : > f && git add f && git -c user.name=g -c user.email=g@g commit -q -m c); }
mkrepo "$W/A" binary-A; mkrepo "$W/B" binary-B
HA=$(git -C "$W/A/SCRIP" rev-parse --short HEAD); HB=$(git -C "$W/B/SCRIP" rev-parse --short HEAD)
probe() {  # <appender file> <mode> -> prints OK/RAISED and the pinned scrip stamp
  S4E_HOME="$W/A" python3 - "$1" "$W/B/SCRIP/scrip" "$W/B/SCRIP/out" "$2" <<'PY'
import importlib.util, sys
spec = importlib.util.spec_from_file_location("upa", sys.argv[1]); m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
b, rt, mode = sys.argv[2], sys.argv[3], sys.argv[4]
g = m.pin_context(b, rt)
if mode == "move":
    open(b, "w").write("binary-B-rebuilt")
try:
    m.assert_ground_unmoved(); print("OK", g.get("scrip"))
except m.ProgressGroundMoved as e:
    print("RAISED", g.get("scrip"))
PY
}
fails=0; n=0
ck() { n=$((n+1)); if eval "$2"; then echo "  ok   $1"; else fails=$((fails+1)); echo "  FAIL $1"; fi; }

echo "--- ARM 1: the worktree shape appends and stamps the graded checkout ---"
o1="$(probe "$A" still 2>&1)"
ck "1a assert_ground_unmoved does not raise when the graded binary sits outside S4E_HOME ($o1)" 'grep -q "^OK " <<<"$o1"'
ck "1b the pinned scrip stamp is the graded checkout B ($HB), not the seat root A ($HA)" 'grep -q "^OK $HB" <<<"$o1"'

echo "--- ARM 2: a real rebuild of the graded binary still refuses ---"
o2="$(probe "$A" move 2>&1)"
ck "2 rewriting B's binary after the pin raises ProgressGroundMoved ($o2)" 'grep -q "^RAISED" <<<"$o2"'
printf 'binary-B' > "$W/B/SCRIP/scrip"

echo "--- ARM 3: bin_fingerprint reads the named binary ---"
f1="$(SCRIP="$W/B/SCRIP/scrip" RT_DIR="$W/B/SCRIP/out" S4E_HOME="$W/A" python3 -c "import importlib.util,sys; s=importlib.util.spec_from_file_location('u','$A'); m=importlib.util.module_from_spec(s); s.loader.exec_module(m); print(m.bin_fingerprint())")"
printf 'binary-B2' > "$W/B/SCRIP/scrip"
f2="$(SCRIP="$W/B/SCRIP/scrip" RT_DIR="$W/B/SCRIP/out" S4E_HOME="$W/A" python3 -c "import importlib.util,sys; s=importlib.util.spec_from_file_location('u','$A'); m=importlib.util.module_from_spec(s); s.loader.exec_module(m); print(m.bin_fingerprint())")"
ck "3 the fingerprint of the named binary changes when it is rebuilt ($f1 -> $f2)" '[ -n "$f1" ] && [ "$f1" != "$f2" ]'
printf 'binary-B' > "$W/B/SCRIP/scrip"

echo "--- ARM 4: FAIL-ONCE -- the old seat-root derivation planted back ---"
sed 's/^    now = _ground(_PINNED_BIN.get("scrip_bin"), _PINNED_BIN.get("rt_dir"))$/    now = _ground()  # PLANTED: the old seat-root derivation/' "$A" > "$W/upa_old.py"
grep -q 'PLANTED: the old seat-root derivation' "$W/upa_old.py" || { echo "GATE UNPROVEN(2) [$GATE_NAME]: the plant found no anchor in util_progress_append.py -- re-anchor"; gate_stamp; exit 2; }
o4="$(probe "$W/upa_old.py" still 2>&1)"
ck "4 with the old derivation the worktree shape raises THE GROUND MOVED ($o4)" 'grep -q "^RAISED" <<<"$o4"'

echo "------------------------------------------------------------"
echo "population: $n check(s) over two scratch checkouts (the seat root and a worktree-shaped second checkout), one planted old derivation"
if [ "$fails" -eq 0 ]; then echo "GATE PASS [$GATE_NAME]: $n of $n checks hold"; gate_stamp; exit 0; fi
echo "⛔ GATE FAIL [$GATE_NAME]: $fails of $n check(s) failed"; gate_stamp; exit 1
