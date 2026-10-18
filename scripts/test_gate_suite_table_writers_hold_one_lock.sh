#!/usr/bin/env bash
# test_gate_suite_table_writers_hold_one_lock.sh -- ONE WRITER AT A TIME ON THE SUITE TABLE (coo 2026-09-25, hq_pascal's report: a lane
# running its runners in parallel lost its own SCORE.md line -- SUITES.tsv read fpc 158/181 while SCORE.md's FPC line read 156, twice).
# Every writer read SUITES.tsv and SCORE.md, changed its row and wrote the whole file back, so the last writer put back what it had
# read: a lost update. MEASURED BEFORE THE CURE on scratch copies: 12 parallel `util_suite_banner.py --set` on 12 different rows kept
# 1 of 12 in both files, three runs of three (the others lost in SUITES.tsv and SCORE.md alike). Now util_suite_banner.py (--set,
# --render) and util_score_row.py (write) hold an exclusive flock on SUITES.tsv's own inode across the read-modify-write, the child
# --set inheriting its parent's hold through S4E_SUITE_TABLE_LOCKED, and a lock not granted in S4E_SUITE_TABLE_LOCK_S refuses rc 2.
# ARMS (all on scratch copies of .github/SUITES.tsv and SCORE.md; the real files are read, never written): (1) 4 parallel --set on
# 4 rows keep 4 of 4 in both files; (2) the banner refuses rc 2, writing nothing, while another holder keeps the lock past its
# ceiling; (3) util_score_row.py write refuses rc 2 the same way -- it takes the lock before its first read; (4) a --set run under
# S4E_SUITE_TABLE_LOCKED (a writer's own child) proceeds while its parent holds the lock -- no self-deadlock.
# ⛔ FAILED ONCE (measured at the landing): on the scripts before the lock, arm 1 kept 1 of 4 and arms 2 and 3 went through a held lock.
# EXIT 0 every arm holds; 1 an arm is red; 2 REFUSED (the fixture could not be built -- nothing measured).
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }; GH="$(cd "$ROOT/.." && pwd)/.github"
. "$(dirname "${BASH_SOURCE[0]}")/lib_suites_tsv.sh" || { echo "REFUSED(2): cannot load lib_suites_tsv.sh"; exit 2; }
B="$GH/scripts/util_suite_banner.py"; R="$HERE/util_score_row.py"
[ -f "$B" ] && [ -f "$SUITES_TSV_REAL" ] && [ -f "$GH/SCORE.md" ] && [ -f "$R" ] || { echo "⛔ REFUSED(2): $B, the shared SUITES.tsv, SCORE.md or util_score_row.py missing"; exit 2; }
T="$(mktemp -d)"; trap 'kill $(jobs -p) 2>/dev/null; rm -rf "$T"' EXIT
fails=0; checks=0
ck() { checks=$((checks+1)); if [ "$1" = ok ]; then printf '  ok    %s\n' "$2"; else printf '  FAIL  %s\n' "$2"; fails=$((fails+1)); fi; }
fresh() { cp "$SUITES_TSV_REAL" "$T/SUITES.tsv"; cp "$GH/SCORE.md" "$T/SCORE.md"; }
export S4E_SUITES_TSV="$T/SUITES.tsv" S4E_SCORE_MD="$T/SCORE.md"
hold() { python3 -c 'import fcntl,os,sys,time; fd=os.open(sys.argv[1],os.O_RDWR|os.O_CREAT); fcntl.flock(fd,fcntl.LOCK_EX); open(sys.argv[2],"w").write("held"); time.sleep(float(sys.argv[3]))' "$T/SUITES.tsv.lock" "$T/held" "$1" & }
waitheld() { local n=0; while [ ! -f "$T/held" ] && [ $n -lt 200 ]; do sleep 0.05; n=$((n+1)); done; [ -f "$T/held" ]; }

# (1) the race
fresh
mapfile -t KEYS < <(awk -F'\t' '$1!~/^#/ && $1!="key" && $10+0>2 {print $1"\t"$10}' "$T/SUITES.tsv" | head -4)
[ "${#KEYS[@]}" = 4 ] || { echo "⛔ REFUSED(2): SUITES.tsv offers ${#KEYS[@]} rows with a total above 2, want 4"; exit 2; }
for kt in "${KEYS[@]}"; do k="${kt%%$'\t'*}"; t="${kt##*$'\t'}"; ( python3 "$B" --set "$k" "$((t-1))" "$t" 2026-09-25 racetree > "$T/set.$k.out" 2>&1 ) & done; wait
chk="$(python3 "$B" --check 2>/dev/null)"; ok=0; lost=""
for kt in "${KEYS[@]}"; do k="${kt%%$'\t'*}"; t="${kt##*$'\t'}"
  if awk -F'\t' -v k="$k" -v p="$((t-1))" '$1==k && $9==p {f=1} END{exit !f}' "$T/SUITES.tsv" && ! grep -q "DISAGREE $k:" <<<"$chk"; then ok=$((ok+1)); else lost="$lost $k"; fi
done
[ "$ok" = 4 ] && ck ok "(1) 4 parallel --set on 4 rows keep 4 of 4 in SUITES.tsv and SCORE.md alike" || ck no "(1) the race kept $ok of 4 -- lost:$lost"
# (2) the banner waits, then refuses, while another holder keeps the lock
fresh; rm -f "$T/held"; hold 6; waitheld || { echo "⛔ REFUSED(2): the lock holder never took the lock"; exit 2; }
k1="${KEYS[0]%%$'\t'*}"; t1="${KEYS[0]##*$'\t'}"; before="$(md5sum < "$T/SUITES.tsv")"
S4E_SUITE_TABLE_LOCK_S=1 python3 "$B" --set "$k1" "$((t1-1))" "$t1" 2026-09-25 locktree > "$T/b2.out" 2>&1; rc=$?
[ "$rc" = 2 ] && grep -q 'suite-table lock' "$T/b2.out" && [ "$(md5sum < "$T/SUITES.tsv")" = "$before" ] \
  && ck ok "(2) util_suite_banner.py --set refuses rc 2 while another writer holds the lock past its ceiling, and writes nothing" || ck no "(2) the banner under a held lock: rc=$rc $(head -c 160 "$T/b2.out")"
# (3) util_score_row.py write takes the same lock before its first read
mkdir -p "$T/home/.github" && cp "$T/SUITES.tsv" "$T/SCORE.md" "$T/home/.github/"
rm -f "$T/held"; python3 -c 'import fcntl,os,sys,time; fd=os.open(sys.argv[1],os.O_RDWR|os.O_CREAT); fcntl.flock(fd,fcntl.LOCK_EX); open(sys.argv[2],"w").write("held"); time.sleep(6)' "$T/SUITES.tsv.lock" "$T/held" & waitheld || { echo "⛔ REFUSED(2): the lock holder never took the lock"; exit 2; }
before="$(md5sum < "$T/home/.github/SCORE.md")"
S4E_HOME="$T/home" S4E_SUITE_TABLE_LOCK_S=1 python3 "$R" write --lang icon --column vendor --suite IPL --text "fixture" --measurer "${S4E_SEAT:-}" --suite-pass 1 --suite-total 2 > "$T/r3.out" 2>&1; rc=$?
[ "$rc" = 2 ] && grep -q 'suite-table lock' "$T/r3.out" && [ "$(md5sum < "$T/home/.github/SCORE.md")" = "$before" ] \
  && ck ok "(3) util_score_row.py write refuses rc 2 under a held lock before it reads a byte -- it takes the lock first" || ck no "(3) util_score_row under a held lock: rc=$rc $(grep -m1 -v '^\s*$' "$T/r3.out" | cut -c1-160)"
# (4) a writer's own child proceeds under its parent's hold
fresh; rm -f "$T/held"; hold 6; waitheld || { echo "⛔ REFUSED(2): the lock holder never took the lock"; exit 2; }
S4E_SUITE_TABLE_LOCKED=parent S4E_SUITE_TABLE_LOCK_S=1 python3 "$B" --set "$k1" "$((t1-1))" "$t1" 2026-09-25 childtree > "$T/b4.out" 2>&1; rc=$?
[ "$rc" = 0 ] && awk -F'\t' -v k="$k1" '$1==k && $11=="childtree" {f=1} END{exit !f}' "$T/SUITES.tsv" \
  && ck ok "(4) a --set under S4E_SUITE_TABLE_LOCKED (a writer's own child) proceeds while the lock is held -- no self-deadlock" || ck no "(4) the child --set: rc=$rc $(head -c 160 "$T/b4.out")"
echo "population: $checks arm(s) over scratch copies of SUITES.tsv ($(grep -vc '^#' "$SUITES_TSV_REAL") lines) and SCORE.md; 4 concurrent writers in arm 1 (each --set costs ~4.6 s, so all four read before any writes)"
if [ "$fails" = 0 ]; then echo "GATE PASS(0) [suite_table_writers_hold_one_lock]: $checks of $checks arms hold"; exit 0; fi
echo "⛔ GATE FAIL(1) [suite_table_writers_hold_one_lock]: $fails of $checks arms red"; exit 1
