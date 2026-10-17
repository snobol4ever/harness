#!/usr/bin/env bash
export S4E_MINT_NO_CRITERION="gate fixture: the row under test exercises the bus, not work (CEO-1386)"
# test_gate_rungs_banner_seq_is_position.sh — the invariant gate for `banner number == entry position`
# in a language rungs, and for the two instruments that depend on it (hq_T 2026-09-13, on the cfo's
# routed brief "the-sanctioned-add-a-witness-path-is-refusing-on-five-of-seven-masters").
#
# WHAT IT PROTECTS, AND WHY THE PROPERTY IS LOAD-BEARING RATHER THAN COSMETIC. read_block_suite() and
# read_suite() IGNORE the number printed in a banner and re-derive seq positionally; the writers print
# e.seq back out. So `banner number == position` is an invariant of every rung suite those readers have
# round-tripped, and util_add_ladder_witness.py's byte-for-byte round-trip proof — the check that stops
# the sanctioned mint path from writing until reader+writer reproduce the rungs exactly — is red for as
# long as the invariant is broken. corpus a6646f04c removed the 620 modes=ast entries from all seven
# rung suites without renumbering and took the mint path down for FIVE LANGUAGES AT ONCE.
#
# ⛔⭐ THIS GATE GRADES THE INSTRUMENTS, NOT THE LIVE RUNG_SUITES, AND THAT IS DELIBERATE. Six of seven
# rung suites carry drift today and every one of them belongs to another lane (icon→ceo, prolog→cto/hq_C/hq_R,
# pascal→coo, rebus→hq_S, snobol4→cfo, snocone→hq_I). A blocking gate over another seat's data turns one
# lane's unlanded cure into thirteen seats' red board, which is how a correct invariant gets a gate
# switched off. The live census is printed as REPORTED at the end — visible every run, blocking nobody —
# and the arms that BLOCK are the ones over this root's own instruments, which are hq_T's to keep green.
#
# ⛔ THE FAIL-ONCE ARMS ARE THE POINT. A renumber tool that cannot be shown refusing is a tool nobody
# should point at 1000 lines of somebody else's rungs. Arms 3 and 4 corrupt a synthetic rungs in the
# two ways that matter — a moved content byte and a renamed entry — and require rc=2 with the files
# UNCHANGED, because "it refused" and "it refused before writing" are different facts.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$HERE/../../SCRIP" || exit 2
RENUM="../harness/scripts/util_renumber_rungs_banners.py"
pass=0; fail=0; refuse=0
ok()   { pass=$((pass+1)); printf '  ok   %s\n' "$1"; }
bad()  { fail=$((fail+1)); printf '  FAIL %s\n' "$1"; }
unm()  { refuse=$((refuse+1)); printf '  REFUSE %s\n' "$1"; }

[ -f "$RENUM" ] || { echo "⛔ REFUSE: $RENUM is not on disk"; exit 2; }
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
LANGDIR="$TMP/raku"; mkdir -p "$LANGDIR"

# A synthetic three-entry Raku rungs whose banners are numbered 7, 8, 9 instead of 1, 2, 3 — the exact
# shape a6646f04c left behind (every number high by a constant, names and content correct).
mk_rungs() {
  cat > "$LANGDIR/ALL.raku" <<'EOF'
#--------------------------------------------------------------- 7 alpha_one
say 1;
#--------------------------------------------------------------- 8 beta_two
say 2;
#---------------------------------------------------------------- 9 gamma_three
say 3;
EOF
  cat > "$LANGDIR/ALL.ref" <<'EOF'
#--------------------------------------------------------------- 7 alpha_one
1
#--------------------------------------------------------------- 8 beta_two
2
#---------------------------------------------------------------- 9 gamma_three
3
EOF
}

# ARM 1 — the tool SEES the drift and reports it without writing (dry run is not a write).
mk_rungs
before_md5="$(md5sum "$LANGDIR/ALL.raku" | cut -d' ' -f1)"
out="$(S4E_TESTS_ROOT="$TMP" python3 "$RENUM" --lang raku 2>&1)"; rc=$?
if [ "$rc" = 1 ] && printf '%s' "$out" | grep -q 'src=3/3'; then ok "arm1 dry-run reports 3/3 stale banners, rc=1"
else bad "arm1 dry-run: rc=$rc out=$out"; fi
[ "$(md5sum "$LANGDIR/ALL.raku" | cut -d' ' -f1)" = "$before_md5" ] \
  && ok "arm1 dry-run wrote nothing" || bad "arm1 dry-run MODIFIED the rungs"

# ARM 2 — --apply restores the invariant, changes banner lines ONLY, and is idempotent.
out="$(S4E_TESTS_ROOT="$TMP" python3 "$RENUM" --lang raku --apply 2>&1)"; rc=$?
if [ "$rc" = 0 ] && printf '%s' "$out" | grep -q 'PROOF: 4/4'; then ok "arm2 apply runs all four proof arms, rc=0"
else bad "arm2 apply: rc=$rc out=$out"; fi
if grep -q ' 1 alpha_one$' "$LANGDIR/ALL.raku" && grep -q ' 3 gamma_three$' "$LANGDIR/ALL.raku"; then
  ok "arm2 banners now equal positions in ALL.raku"; else bad "arm2 banners not renumbered"; fi
if grep -q ' 1 alpha_one$' "$LANGDIR/ALL.ref" && grep -q ' 3 gamma_three$' "$LANGDIR/ALL.ref"; then
  ok "arm2 ALL.ref renumbered in lockstep"; else bad "arm2 ALL.ref out of step with ALL.raku"; fi
if [ "$(grep -c '^say ' "$LANGDIR/ALL.raku")" = 3 ] && [ "$(grep -cx '[123]' "$LANGDIR/ALL.ref")" = 3 ]; then
  ok "arm2 every non-banner line survived byte-for-byte"; else bad "arm2 content moved"; fi
out="$(S4E_TESTS_ROOT="$TMP" python3 "$RENUM" --lang raku 2>&1)"; rc=$?
[ "$rc" = 0 ] && ok "arm2 idempotent — a renumbered rungs reports zero drift, rc=0" \
              || bad "arm2 not idempotent: rc=$rc $out"

# ARM 3 — FAIL ONCE: a banner naming an entry the reader never produced must REFUSE, not renumber.
mk_rungs
sed -i 's/ 8 beta_two$/ 8 beta_two_RENAMED/' "$LANGDIR/ALL.raku"
before_md5="$(md5sum "$LANGDIR/ALL.raku" | cut -d' ' -f1)"
out="$(S4E_TESTS_ROOT="$TMP" python3 "$RENUM" --lang raku --apply 2>&1)"; rc=$?
if [ "$rc" = 2 ]; then ok "arm3 a desynced .raku/.ref banner pair refuses rc=2"
else bad "arm3 expected rc=2, got rc=$rc: $out"; fi
[ "$(md5sum "$LANGDIR/ALL.raku" | cut -d' ' -f1)" = "$before_md5" ] \
  && ok "arm3 refused BEFORE writing" || bad "arm3 wrote despite refusing"

# ARM 4 — FAIL ONCE: duplicate entry names make a name-keyed renumber unprovable; it must refuse.
mk_rungs
sed -i 's/ 9 gamma_three$/ 9 alpha_one/' "$LANGDIR/ALL.raku"
sed -i 's/ 9 gamma_three$/ 9 alpha_one/' "$LANGDIR/ALL.ref"
before_md5="$(md5sum "$LANGDIR/ALL.raku" | cut -d' ' -f1)"
out="$(S4E_TESTS_ROOT="$TMP" python3 "$RENUM" --lang raku --apply 2>&1)"; rc=$?
if [ "$rc" = 2 ] && printf '%s' "$out" | grep -qi 'duplicate'; then ok "arm4 duplicate entry names refuse rc=2 by name"
else bad "arm4 expected a duplicate-name rc=2, got rc=$rc: $out"; fi
[ "$(md5sum "$LANGDIR/ALL.raku" | cut -d' ' -f1)" = "$before_md5" ] \
  && ok "arm4 refused BEFORE writing" || bad "arm4 wrote despite refusing"

# ARM 5 — the DIAGNOSIS half: util_add_ladder_witness.py's round-trip refusal must name the stale banner
# and the cure, never accuse itself. This is the arm that would have saved four lanes a diagnosis each.
ADD="../harness/scripts/util_add_ladder_witness.py"
if [ -f "$ADD" ]; then
  if grep -q 'util_renumber_rungs_banners.py --lang' "$ADD" && grep -q 'def banner_drift' "$ADD"; then
    ok "arm5 the mint path diagnoses stale banners and names the cure command"
  else bad "arm5 the mint path's round-trip refusal does not separate its two causes"; fi
else unm "arm5 $ADD is not on disk"; fi

# REPORTED, never blocking: the live drift census across all seven rung suites (see the header).
echo "  --- REPORTED (blocks nobody): live rungs banner drift ---"
S4E_TESTS_ROOT="" python3 "$RENUM" --all 2>&1 | sed 's/^/  | /'

printf 'GATE %s(%d) pass=%d fail=%d refused=%d\n' \
  "$([ "$fail" = 0 ] && { [ "$refuse" = 0 ] && echo PASS || echo REFUSE; } || echo FAIL)" \
  "$([ "$fail" != 0 ] && echo 1 || { [ "$refuse" != 0 ] && echo 2 || echo 0; })" "$pass" "$fail" "$refuse"
[ "$fail" != 0 ] && exit 1
[ "$refuse" != 0 ] && exit 2
exit 0
