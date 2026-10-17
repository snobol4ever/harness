#!/usr/bin/env bash
# FACT RULE "ONE MEDIUM, INVISIBLE": a BB template never hand-encodes an instruction as raw bytes nor
# branches on the medium for an instruction with a RAW, unsanctioned spelling. Forbidden in
# src/templates/{bb,xa}/*.cpp (comments stripped):
#   raw-byte producers: x86_Lrec, x86_Jrec, x86_Drec, x86_b1(, x86_b2(, x86_b3(, bytes(, u8(, u32le, u64le
#   RAW medium-branch scatter: IF(MEDIUM_BINARY, IF(MEDIUM_TEXT, IF(MEDIUM_MACRO_DEF
# ⭐ RE-SCOPED under RULES.md § MODES MAY DIVERGE (Lon 2026-08-28, row `gate-mode-arms-rescope`): the old
# m3≡m4 byte-identity law is LIFTED and a DELIBERATE per-mode template arm is now legal -- but only
# through ONE sanctioned, greppable spelling: IF_M3(...)/IF_M4(...) (src/emitter/emit.h, thin wrappers
# over IF(MEDIUM_BINARY,...)/IF(MEDIUM_TEXT,...) living beside IF() itself -- "encapsulate mode 3 and
# mode 4 changes within an upper set of helpers", Lon, same sitting). The raw IF(MEDIUM_*,...) forms
# above stay forbidden -- an idea is sanctioned or it is scatter, never both spellings for the same one.
# x86_asm.h is the encoder impl (exempt). Historic prey that SURVIVES the re-scope, unconditionally, in
# PART 2 and PART 3 below: ACCIDENTAL divergence (any raw MEDIUM_* token in bb_*.cpp -- ratchet, ceiling
# 0) and a SANCTIONED arm that reaches into port instrumentation (a mode arm may change INSTRUCTIONS,
# never a port's x86_deflabel canary/ZDP/ZLS2 hook -- RULES.md: "port-seam protection stays absolute").
# PART 1 (raw-byte producers + raw scatter) is an informational WIP baseline; --strict enforces zero.
SELF_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$(dirname "$0")/../../SCRIP" || exit 2
. "$SELF_DIR/lib_gate.sh"
gate_parse_args "$@"
# ⛔⭐ THE POPULATION IS COUNTED BEFORE EITHER PART RUNS (coo 2026-09-18, the cto's finding, seat10's list).  Both
# parts loop over globs -- src/templates/{bb,xa}/*.cpp and src/templates/bb/bb_*.cpp -- and an unmatched glob in
# bash expands to the literal pattern, so on an EMPTY tree the loop bodies scan nothing, total stays 0, and PART 1
# printed "every BB template is medium-invisible" over zero templates.
# ⛔ AND PART 2 IS A RATCHET against MEDIUM_RATCHET, so a vacuous scan there does not merely look clean -- it reads
# as the ceiling having been beaten, which is the shape that invites the next seat to lower a ceiling onto a
# measurement nobody took.  Refuse on the empty population FIRST, before either verdict.
census_files=0
for _f in src/templates/bb/*.cpp src/templates/xa/*.cpp; do [ -f "$_f" ] && census_files=$((census_files+1)); done
gate_floor "$census_files" 1 "src/templates bb/xa template file(s) -- both parts, the ratchet included, are asserted over this population"
# =====================================================================================================
# SHARED SCANNERS -- the real-tree scans below and this script's own § SELF-TEST fixtures call these SAME
# functions, so "what the gate checks" and "what the self-test proves" cannot drift apart from each other
# (RULES.md INSTRUMENT LAW #6: a measurement path disjoint from what it proves is a participant, not a
# witness -- sharing the function, not just the intent, is what keeps this one honest).
strip_comments() { perl -0777 -pe 's{/\*.*?\*/}{}gs; s{//[^\n]*}{}g' "$1"; }
count_medium_tokens() { strip_comments "$1" | grep -o 'MEDIUM_[A-Z_]*' | wc -l; }
count_seam_violations() {
  perl -0777 -ne '
    my $code = $_; $code =~ s{/\*.*?\*/}{}gs; $code =~ s{//[^\n]*}{}g; my $v = 0;
    while ($code =~ /\bIF_M[34]\s*\(/g) {
      my $start = pos($code); my $depth = 1; my $i = $start; my $len = length($code);
      while ($i < $len && $depth > 0) { my $c = substr($code,$i,1); $depth++ if $c eq "("; $depth-- if $c eq ")"; $i++; }
      my $inner = substr($code, $start, $i - $start - 1);
      $v++ if $inner =~ /x86_deflabel\w*\s*\(|x86_alpha\s*\(|x86_beta\w*\s*\(|x86\(\s*"label"\s*,\s*_\.lbl_/;
    }
    print $v;
  ' "$1"
}
rc=0
# =====================================================================================================
# PART 1 -- RAW-BYTE PRODUCERS + RAW (UNSANCTIONED) MEDIUM SCATTER. Informational baseline; --strict enforces 0.
total=0; hits=""
for f in src/templates/{bb,xa}/*.cpp; do
  m=$(strip_comments "$f" | grep -cE 'x86_Lrec|x86_Jrec|x86_Drec|x86_b1\(|x86_b2\(|x86_b3\(|\bbytes\(|\bu8\(|\bu32le|\bu64le|IF\(MEDIUM_BINARY|IF\(MEDIUM_TEXT|IF\(MEDIUM_MACRO_DEF')
  if [ "$m" -gt 0 ]; then total=$((total+m)); hits="$hits $(basename "$f")($m)"; fi
done
echo "raw-byte producers / raw medium scatter in BB templates (code): $total  (target 0)"
if [ "$total" -ne 0 ]; then
  echo "REMAINING:$hits"
  echo "(informational WIP baseline -- use the SANCTIONED IF_M3(...)/IF_M4(...) spelling for a real mode arm, never raw IF(MEDIUM_*.)"
  [ "${1:-}" = "--strict" ] && { echo "GATE FAIL (--strict)."; rc=1; }
else
  echo "OK: every BB template is medium-invisible or uses the sanctioned IF_M3/IF_M4 spelling."
fi

# =====================================================================================================
# BOTH-MEDIUM RATCHET (RULES.md "NO MEDIUM_* IN TEMPLATES") — added s169 (seat1, queue row gates-dead-paths).
# RULES.md carried the ratchet as a TYPED NUMBER (29) next to a DIFFERENT command (`grep -rn 'MEDIUM_'
# src/templates/bb/bb_*.cpp`, which yields 38). A ratchet whose number and whose command disagree cannot be
# enforced: the next seat runs the documented command, sees 38, and reads a 9-site regression that never
# happened. The 29 is the GUARD-SITE count -- `if (MEDIUM_` plus `IF(MEDIUM_` -- and guard sites are what
# the rule actually forbids ("any function gating output on MEDIUM_TEXT/MEDIUM_BINARY is a violation").
# That is the number pinned here, computed, never typed. Retire the sites via queue row `medium-retire`.
# ⛔ BLIND SPOT CLOSED s170 (seat1, row `medium-retire`). The s169 ratchet counted `if (MEDIUM_` + `IF(MEDIUM_`
# because those were the shapes the census had seen. They are NOT the only way to gate on the medium: two live
# sites in bb_call_proc_staged spelled it as a CONDITIONAL EXPRESSION -- `(MEDIUM_BINARY && cell ? A : B)` --
# and the guard regex walked straight past both, so the true count was 31, not 29. A ratchet that enumerates
# SPELLINGS will always be one syntax behind the code. This one now counts every MEDIUM_* token that survives
# comment-stripping, which is spelling-independent and is what the rule actually says ("Zero MEDIUM_* in any
# bb_*.cpp"); the guard-site number is kept beside it as a breakdown, never as the gate.
# ⛔ RATCHET CLOSED s172 (seat6, row `ab-cell-hoist`): 3 -> 0.  The last three were all in bb_define.cpp and all one class -- the AB fn-cell
# store (g_ab_fn_cells + bb_ab_cell_addr) is C-side LIVE-IMAGE state that only a BINARY image has, so the template had to ask the
# medium whether a cell existed.  The store was hoisted to src/emitter/emit.cpp (the file that owns g_medium) and bb_ab_cell_addr now
# answers NULL for TEXT; all three sites became tests of the returned POINTER.  Per-medium byte-identity measured: 0 movers / 527
# comparable .s and 0 movers / 575 mode-3 runs.  THE CEILING IS NOW ZERO AND MUST STAY ZERO -- this is no longer a known-red ratchet
# but a live invariant: a single MEDIUM_* token in any bb_*.cpp fails this gate.
# ⭐ RE-SCOPED, not re-measured, 2026-08-28 (row gate-mode-arms-rescope): the ceiling and the scanning logic
# below are UNCHANGED -- a raw MEDIUM_* token is still an unconditional failure. What changed is that a
# DELIBERATE arm now has a legal escape (IF_M3/IF_M4, PART 1 above) that is INVISIBLE to this regex by
# construction, since its own spelling contains no "MEDIUM_" substring -- that is what makes it the
# sanctioned door rather than a second violation class. § SELF-TEST proves this both ways rather than
# just asserting it.
MEDIUM_RATCHET="${MEDIUM_RATCHET:-0}"
sites=0
for f in src/templates/bb/bb_*.cpp; do
  n=$(count_medium_tokens "$f")
  [ "$n" -gt 0 ] && { sites=$((sites+n)); echo "  MEDIUM_ code sites: $(basename "$f") ($n)"; }
done
guards=$(grep -hoE 'if \(MEDIUM_|IF\(MEDIUM_' src/templates/bb/bb_*.cpp 2>/dev/null | wc -l)
echo "BOTH-MEDIUM code sites in src/templates/bb/bb_*.cpp: $sites  (ratchet ceiling $MEDIUM_RATCHET, target 0; of these, $guards are if/IF guard sites)"
if [ "$sites" -gt "$MEDIUM_RATCHET" ]; then
  echo "RATCHET FAIL: $sites MEDIUM_* code site(s) > ceiling $MEDIUM_RATCHET — the known-red count MAY NOT GROW."
  rc=1
fi
[ "$sites" -lt "$MEDIUM_RATCHET" ] && echo "RATCHET IMPROVED: $sites < $MEDIUM_RATCHET — lower MEDIUM_RATCHET in this script to lock the gain in."

# =====================================================================================================
# PART 3 -- SANCTIONED-ARM SEAM CHECK, NEW 2026-08-28 (row gate-mode-arms-rescope), UNCONDITIONAL.
# RULES.md § MODES MAY DIVERGE: "port-seam protection (x86_deflabel hooks) stays absolute ... an arm may
# change instructions, never a port's instrumentation contract." A mode arm may emit whatever
# INSTRUCTIONS it likes inside IF_M3(...)/IF_M4(...); it may never itself DEFINE A PORT there
# (x86_deflabel/x86_alpha/x86_beta*, or a raw x86("label", _.lbl_*) port-label bypass) -- ports stay
# unconditional so the canary/ZDP/ZLS2 hook fires identically regardless of mode. Ceiling 0, absolute --
# no --strict gate, same standing as the ratchet above. KNOWN LIMITATION, stated plainly rather than
# overclaimed: this is a paren-depth balance over the token stream, not a real C++ parse -- an unbalanced
# string literal or macro-generated paren inside an IF_M3/IF_M4 argument can confuse the boundary. A lint,
# not a proof, the same honesty this file already keeps about the guard-site regex above.
seam=0
for f in src/templates/{bb,xa}/*.cpp; do
  n=$(count_seam_violations "$f")
  [ "$n" -gt 0 ] && { seam=$((seam+n)); echo "  SEAM VIOLATION (port call inside IF_M3/IF_M4): $(basename "$f") ($n)"; }
done
echo "sanctioned-arm seam violations: $seam  (ceiling 0, absolute)"
[ "$seam" -gt 0 ] && { echo "SEAM FAIL: a mode arm defined a port instead of only instructions."; rc=1; }

# =====================================================================================================
# § SELF-TEST -- TWO-PART PROOF BY INJECTION (RULES.md THE INSTRUMENT LAWS #2: exercise a criterion in
# BOTH directions before trusting it -- "a criterion nobody has seen fail is not a criterion", and one
# that can never say YES is the free-r10 defect's twin). Three fixtures, none under src/: raw scatter
# still refuses (the old law survives); a clean sanctioned arm still passes (the gate CAN say YES to the
# new shape, not just NO to the old one); a sanctioned arm that reaches into a port still refuses (seam
# protection actually fires, not just reads as present). A broken self-test fails THIS gate, loudly -- an
# un-exercised re-scope is exactly the "criterion nobody has seen fail" defect this law was written against.
selftest_dir="$(mktemp -d)"
trap 'rm -rf "$selftest_dir"' EXIT
cat > "$selftest_dir/raw_scatter.cpp" <<'EOF'
std::string bb_fixture_raw_str() { std::string s; if (g_medium == BB_MEDIUM_BINARY) { s += "raw"; } return s; }
EOF
cat > "$selftest_dir/sanctioned_clean.cpp" <<'EOF'
std::string bb_fixture_clean_str() { return IF_M3(x86("mov", "rax", "1")) + IF_M4(x86("mov", "rax", "2")); }
EOF
cat > "$selftest_dir/sanctioned_seam.cpp" <<'EOF'
std::string bb_fixture_seam_str() { return IF_M3(x86_beta()) + IF_M4(x86_alpha()); }
EOF
st_rc=0
st_check() { # $1 label, $2 actual, $3 expected
  if [ "$2" -eq "$3" ]; then echo "  SELF-TEST OK: $1 ($2)"; else echo "  SELF-TEST FAIL: $1 got $2, expected $3"; st_rc=1; fi
}
st_check "raw scatter still counted"                  "$(count_medium_tokens "$selftest_dir/raw_scatter.cpp")"       1
st_check "sanctioned clean arm: zero MEDIUM_ tokens"   "$(count_medium_tokens "$selftest_dir/sanctioned_clean.cpp")" 0
st_check "sanctioned clean arm: zero seam violations"  "$(count_seam_violations "$selftest_dir/sanctioned_clean.cpp")" 0
st_check "sanctioned seam violation: caught"           "$(count_seam_violations "$selftest_dir/sanctioned_seam.cpp")" 2
[ "$st_rc" -ne 0 ] && { echo "SELF-TEST FAIL: the re-scoped gate's own proof did not hold -- DO NOT TRUST the checks above."; rc=1; }
exit "$rc"
