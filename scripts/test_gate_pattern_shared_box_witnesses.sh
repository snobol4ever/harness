#!/usr/bin/env bash
# test_gate_pattern_shared_box_witnesses.sh -- seat18's FLEET-20 walk under hq_U (row
# pattern-engine-shared-box-witness-set-with-oracle-cut-refs, task minted by hq_U 2026-09-05T18:15:50Z).
#
# WHAT THIS IS: a minimal-witness set for the shared Byrd boxes SNOBOL4 patterns exercise -- operand
# parking per site, ARBNO, SPAN/ANY/BREAK snapshots, capture -- graded m3+m4 against the live `sbl -bf`
# oracle, with each witness's port trace checked (killswitch, no-perturbation, self-pin against
# refs_pattern_shared_box_witnesses.trace). "The seat witnesses, hq_U cures" (GOAL-HQ-UNIFY.md) --
# this gate only WITNESSES; it does not itself attempt any cure.
#
# ⛔⭐ THE SEED PAIR NAMED IN THE TASK BRIEF IS STALE -- CURED BEFORE THE TASK WAS EVEN MINTED. The brief
# pointed at FINDING-2026-09-05-hq_C-outer-capture-reads-its-own-home-...md sec 1 as "red today" (that
# FINDING itself was committed .github 80c773c70, 2026-09-04T21:14:49-05:00, and says so honestly at the
# time it was written). But its own follow-up, FINDING-2026-09-05-hq_C-flat-alternation-leaves-32-live-
# bytes-...md (.github b5370143b, 2026-09-04T23:54:20-05:00 -- ~2.5h later, and still ~13h before this
# task's 2026-09-05T18:15:50Z mint time), records the landed cure: SCRIP `0a1a94239`, the `alt_flat_live_
# bytes()` clause in the `_xh` hop loop at src/emitter/emit.cpp (search `IR_MATCH_ALTERNATE) { _xh +=`).
# Verified empirically THIS session, both ways: `git checkout 70f7b562e -- src/emitter/emit.cpp` (the
# parent of the cure commit) reproduces COMMON=[] exactly as the stale FINDING describes; `git checkout
# HEAD -- src/emitter/emit.cpp` (today's tree) matches the oracle. Groups 1-3 below are therefore
# REGRESSION PINS on an already-cured class, not open class rows -- EXPECTED to PASS today, and a witness
# going RED means the cure regressed, not "still broken". See
# FINDING-2026-09-05-seat18-pattern-shared-box-witness-walk.md for the full writeup.
#
# THE FOUR GROUPS:
#   capture            cap_pin_break   -- the seed pair itself (SCRIP 0a1a94239).
#   span-any-break     cap_pin_any, cap_pin_notany, cap_pin_span -- seat18's OWN construction, same
#                      LEN(1)-then-alternation shape as the seed with ANY/NOTANY/SPAN swapped in for
#                      BREAK, EACH independently verified this session to reproduce pre-cure (against
#                      70f7b562e) and pass post-cure -- new coverage the original FINDING never checked.
#   operand-parking    park_pin_seize -- FINDING-2026-09-05-hq_C-a-deferred-patterns-live-depth-...md's
#                      own decisive witness verbatim (SCRIP 2243452ad): one compiled capture site, called
#                      twice with a SEIZE local bound to two different patterns, so the SAME site must
#                      park and re-find two different operand shapes. As close to "operand parking per
#                      site" as this codebase's own vocabulary gets.
#   arbno              arbno_pin_reentry -- an OPEN class row, not a regression pin, credited to seat14's
#                      independent isolation this same session (FINDING-2026-09-05-seat14-arbno-frame-arm-
#                      hangs-re-entering-a-choice-bearing-body.md, routed to hq_U there already -- this
#                      gate does not re-route it, only adopts the already-isolated witness for standing
#                      coverage). `ARBNO(<body>)` with an internally-choice-bearing body (an alternation)
#                      HANGS on re-entry -- a genuine non-terminating cycle in `bb_match_arbno_frame()`,
#                      confirmed independently this session against the real rungs-suite entry
#                      (`probe_passthru__ptw_min_defer2_hang`, already carried as `arbno_pos_rpos_branch_81`
#                      xfail=1). EXPECTED verdict today is FAIL/timeout -- this is the one group where a
#                      witness going GREEN is the news (hq_U's cure landed), never a gate violation.
#
# capture/span-any-break share ONE passing control (cap_ctrl: the alternation replaced by bare REM, which
# is semantically equivalent on this subject -- LEN(1) already exhausts the remaining char, so either
# alternation arm or bare REM matches zero more characters; the ONLY structural difference is whether the
# second concat element is an IR_DISJUNCTION node, which is precisely what isolates this class). arbno has
# its own control, arbno_ctrl (ARBNO with a choice-free body -- terminates fine, isolates the alternation
# as the ingredient exactly as seat14's own v1/v6 pair does).
#
# PORT TRACE CHECK, per witness, mode-4 (the medium `--compile` makes inspectable):
#   (1) KILLSWITCH: .s with SCRIP_PL_TRACE unset and =0 are byte-identical; =1 differs.
#   (2) NO PERTURBATION: stdout+rc identical with/without the trace, both m3 and m4.
#   (3) THE INSTRUMENT FIRES: SCRIP_PL_TRACE=1 produces a nonzero normalised port-trace line count.
#   (4) SELF-PIN: the normalised trace matches refs_pattern_shared_box_witnesses.trace (--cut rewrites
#       it). ⛔ Same doctrine as lib_port_trace.sh: this is a SELF-consistency pin, not an oracle diff --
#       it proves the port sequence has not MOVED, never that it is right. This gate does not reuse
#       lib_port_trace.sh itself because that library is shaped around the rungs-suite ladder (families,
#       rungs, --to/--only over corpus/tests/<lang>/ALL.csv); these witnesses are not rungs-suite members
#       (deliberately -- they are a from-FINDING ad hoc set, not general corpus), so the same four checks
#       are re-implemented directly below over an inline, self-contained witness set instead.
#
# CORRECTNESS CHECK: gate_oracle_stdout_match (lib_gate.sh) against a LIVE `sbl -bf` run per witness, both
# modes -- the same helper test_one_witness.sh uses, not a stored .ref (nothing here is a rung suite entry).
#
# EXIT: 0 every regression-pin witness (groups 1-3) matches the oracle and all port-trace checks pass,
# AND the arbno group's status is one of its two EXPECTED shapes (still hangs, or hq_U's cure landed and
# it now passes -- either is fine; see EXPECT_FAIL below). 1 an ACTUAL regression: a group 1-3 pin went
# red, a killswitch/perturbation/self-pin check failed, or arbno stopped hanging AND stopped matching the
# oracle (neither expected shape -- a NEW, different defect). 2 UNPROVEN (unbuilt scrip, missing oracle,
# or refs missing -- run --cut once to seed refs_pattern_shared_box_witnesses.trace).
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }; cd "$ROOT"
S4E="${S4E_HOME:-$(cd "$ROOT/.." && pwd)}"
. "$HERE/lib_oracle_flags.sh" 2>/dev/null || { echo "REFUSING: cannot load lib_oracle_flags.sh -- the ONE oracle-flag authority (s200/s255)." >&2; exit 3; }
. "$HERE/lib_gate.sh" 2>/dev/null || { echo "REFUSING: cannot load lib_gate.sh -- the ONE gate-honesty authority." >&2; exit 3; }
gate_parse_args "$@"
CUT=0; for a in "$@"; do [ "$a" = --cut ] && CUT=1; done

SCRIP="${SCRIP:-$ROOT/scrip}"; RT="${RT_DIR:-$ROOT/out}"
SBL="${SBL:-$(sbl_correctness_bin)}"
gate_require_exec "$SCRIP" "scrip binary"
gate_require "$RT/libscrip_rt.so" "runtime library"
gate_require_fresh "$ROOT" src "$SCRIP" "$RT/libscrip_rt.so"
gate_require_exec "$SBL" "sbl -bf correctness oracle"
REF="$HERE/refs_pattern_shared_box_witnesses.trace"
[ "$CUT" = 1 ] || gate_require "$REF" "port-trace self-pin refs (run with --cut to create them)"

PORT_TRACE_ENV="SCRIP_PL_TRACE"
T="${TIMEOUT:-8}"   # 8s: seat14 measured this witness non-terminating at 8s AND 30s alike (a tight cycle,
                    # not a slow search) -- 8s distinguishes every witness here (all others finish <0.1s).
# EXPECT_FAIL: witnesses whose CORRECTNESS check is expected to currently FAIL (an open bug, not a pin).
# HANGS: witnesses that do not terminate under $T -- their port-trace self-pin is skipped (a cycle that
# never reaches an instrumented port produces zero trace lines, confirmed empirically this session; that
# is not the same thing as "the instrument failed to fire" on a witness that actually runs to completion).
EXPECT_FAIL=" arbno_pin_reentry "
HANGS=" arbno_pin_reentry "
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT

write() { printf '%s\n' "$2" > "$W/$1.sno"; }

write cap_ctrl      ' LIST = ",a"; LIST POS(0) "," (LEN(1) REM) . CAP :S(Y)F(N);Y OUTPUT = "CAP=[" CAP "]" :(END);N OUTPUT = "NOMATCH";END'
write cap_pin_break  ' LIST = ",a"; LIST POS(0) "," (LEN(1) (BREAK(",") | REM)) . CAP :S(Y)F(N);Y OUTPUT = "CAP=[" CAP "]" :(END);N OUTPUT = "NOMATCH";END'
write cap_pin_any    ' LIST = ",a"; LIST POS(0) "," (LEN(1) (ANY("a") | REM)) . CAP :S(Y)F(N);Y OUTPUT = "CAP=[" CAP "]" :(END);N OUTPUT = "NOMATCH";END'
write cap_pin_notany ' LIST = ",a"; LIST POS(0) "," (LEN(1) (NOTANY("x") | REM)) . CAP :S(Y)F(N);Y OUTPUT = "CAP=[" CAP "]" :(END);N OUTPUT = "NOMATCH";END'
write cap_pin_span   ' LIST = ",a"; LIST POS(0) "," (LEN(1) (SPAN("a") | REM)) . CAP :S(Y)F(N);Y OUTPUT = "CAP=[" CAP "]" :(END);N OUTPUT = "NOMATCH";END'
cat > "$W/park_pin_seize.sno" <<'SNOEOF'
	DEFINE("F(LIST,K)SEIZE,ANC,COMMON,IC")
	OUTPUT = F(",ABLE,ACTOR",1)
	OUTPUT = F(",ABLE,ACTOR",2)	:(END)
F	ANC = POS(0) ","
	SEIZE = REM
	EQ(K,1)	:S(GO)
	SEIZE = BREAK(",") | REM
GO	LIST  ANC  (BAL . IC  SEIZE) . COMMON	:F(FRETURN)
	F = "K=" K " COMMON=[" COMMON "] IC=[" IC "]"	:(RETURN)
END
SNOEOF
# arbno_ctrl / arbno_pin_reentry -- seat14's v1/v6 pair (FINDING-2026-09-05-seat14-arbno-frame-arm-hangs-
# re-entering-a-choice-bearing-body.md sec 2), reproduced here via the real rungs-suite entry
# (probe_passthru__ptw_min_defer2_hang, entry arbno_pos_rpos_branch_81) for arbno_pin_reentry, and the
# same shape with the alternation removed for arbno_ctrl. Deferred pattern-variable reference (*G1, *P)
# is part of the witness, not incidental -- it is how the corpus entry is phrased; seat14's own v2/v3
# (direct, non-deferred) reproduce identically, so the defer is not the ingredient here (the alternation
# body inside ARBNO is).
cat > "$W/arbno_ctrl.sno" <<'SNOEOF'
          G1 = ARBNO('a')
          P = *G1 RPOS(0)
          'abcdef' POS(0) *P                    :S(OK)F(NO)
OK        OUTPUT = 'match'                      :(END)
NO        OUTPUT = 'nomatch'
END
SNOEOF
cat > "$W/arbno_pin_reentry.sno" <<'SNOEOF'
          G1 = ARBNO('a' | 'ab')
          P = *G1 RPOS(0)
          'abcdef' POS(0) *P                    :S(OK)F(NO)
OK        OUTPUT = 'match'                      :(END)
NO        OUTPUT = 'nomatch'
END
SNOEOF

# name:group -- group is informational only (printed per row); every row is graded identically except
# where EXPECT_FAIL/HANGS above name it.
WITNESSES="cap_ctrl:capture cap_pin_break:capture cap_pin_any:span-any-break cap_pin_notany:span-any-break cap_pin_span:span-any-break park_pin_seize:operand-parking arbno_ctrl:arbno arbno_pin_reentry:arbno"

norm() { grep -E '^\([0-9]+\) [0-9]+ (Call|Exit|Redo|Fail|Exception): ' "$1" | sed -E 's/^(\([0-9]+\)) [0-9]+ /\1 /; s/\bn[0-9]+_//g; s/\$2F/\//g; s/ r15=0x[0-9a-f]+$//'; }
m4build() { [ -s "$1" ] && as --64 -o "$1.o" "$1" 2>/dev/null && gcc -no-pie -o "$2" "$1.o" "$RT/libscrip_rt.so" -lm -lstdc++ -Wl,-rpath,"$RT" 2>/dev/null; }
refblock() { awk -v o="$1" '$0 ~ "^%---- " o " " {on=1; next} /^%---- /{on=0} on' "$REF"; }
refmeta()  { grep -E "^%---- $1 total=[0-9]+$" "$REF" | head -1 | sed -E 's/.*total=([0-9]+)$/\1/'; }

is_in() { case "$2" in *" $1 "*) return 0;; *) return 1;; esac; }

n=0; bad=0; declare -a lines
[ "$CUT" = 1 ] && : > "$W/NEW.trace"
for entry in $WITNESSES; do
  o="${entry%%:*}"; grp="${entry##*:}"
  n=$((n+1)); src="$W/$o.sno"
  xfail=0; is_in "$o" "$EXPECT_FAIL" && xfail=1

  "$SBL" $(sbl_lang_flags) "$src" </dev/null >"$W/$o.ora" 2>/dev/null; orc=$?
  timeout -k 5 "$T" "$SCRIP" --run "$src" </dev/null >"$W/$o.m3out" 2>"$W/$o.m3err"; m3rc=$?
  if gate_oracle_stdout_match "$W/$o.ora" "$W/$o.m3out" "$W/$o.m3err" "$m3rc"; then
    if [ "$xfail" = 1 ]; then m3v="PASS(!)"; else m3v=PASS; fi   # PASS(!) on an xfail witness = news (cure landed), never a violation
  else
    if [ "$xfail" = 1 ]; then m3v="FAIL(exp)"; else m3v=FAIL; bad=$((bad+1)); fi
  fi

  timeout -k 5 "$T" "$SCRIP" --compile -o "$W/$o.s0" "$src" </dev/null >/dev/null 2>&1
  if m4build "$W/$o.s0" "$W/$o.bin0"; then
    timeout -k 5 "$T" "$W/$o.bin0" </dev/null >"$W/$o.m4out" 2>"$W/$o.m4err"; m4rc=$?
    if gate_oracle_stdout_match "$W/$o.ora" "$W/$o.m4out" "$W/$o.m4err" "$m4rc"; then
      if [ "$xfail" = 1 ]; then m4v="PASS(!)"; else m4v=PASS; fi
    else
      if [ "$xfail" = 1 ]; then m4v="FAIL(exp)"; else m4v=FAIL; bad=$((bad+1)); fi
    fi
  else
    : >"$W/$o.m4out"
    if [ "$xfail" = 1 ]; then m4v="FAIL(exp)"; else m4v=ASMLINK; bad=$((bad+1)); fi
  fi

  # ⛔ MUST pass the SAME path STRING (here always "$src", absolute) as the s0 build above: the compiler
  # embeds the literal command-line path into the .file debug directive, so an absolute-vs-relative
  # mismatch (e.g. via a `cd` subshell) produces a byte diff that is a test artifact, not a real one.
  env "$PORT_TRACE_ENV=0" timeout -k 5 "$T" "$SCRIP" --compile -o "$W/$o.s0b" "$src" </dev/null >/dev/null 2>&1
  env "$PORT_TRACE_ENV=1" timeout -k 5 "$T" "$SCRIP" --compile -o "$W/$o.s1" "$src" </dev/null >/dev/null 2>&1
  ks=OK; { [ -s "$W/$o.s0" ] && cmp -s "$W/$o.s0" "$W/$o.s0b" && ! cmp -s "$W/$o.s0" "$W/$o.s1"; } || { ks=FAIL; bad=$((bad+1)); }

  env "$PORT_TRACE_ENV=1" timeout -k 5 "$T" "$SCRIP" --run "$src" </dev/null >"$W/$o.m3out.tr" 2>"$W/$o.m3.raw"; m3rc_tr=$?
  pert3=OK; { [ "$m3rc" = "$m3rc_tr" ] && cmp -s "$W/$o.m3out" "$W/$o.m3out.tr"; } || { pert3=FAIL; bad=$((bad+1)); }
  if m4build "$W/$o.s1" "$W/$o.bin1"; then
    env "$PORT_TRACE_ENV=1" timeout -k 5 "$T" "$W/$o.bin1" </dev/null >"$W/$o.m4out.tr" 2>"$W/$o.m4.raw"; m4rc_tr=$?
    pert4=OK; { [ "$m4rc" = "$m4rc_tr" ] && cmp -s "$W/$o.m4out" "$W/$o.m4out.tr"; } || { pert4=FAIL; bad=$((bad+1)); }
  else pert4=NOBUILD; bad=$((bad+1)); : >"$W/$o.m4.raw"; fi

  if is_in "$o" "$HANGS"; then
    # A tight non-terminating cycle that never reaches an instrumented port produces ZERO trace lines by
    # construction (confirmed empirically, not assumed -- SCRIP_PL_TRACE=1 under an 8s timeout on this
    # exact witness: 0 stderr lines). That is not "the instrument failed to fire"; there is no port trace
    # to pin for a witness that does not terminate. Skip the self-pin, do not penalize it.
    trv="N/A(hangs)"
  else
  norm "$W/$o.m4.raw" > "$W/$o.norm"; total=$(wc -l < "$W/$o.norm")
  if [ "$total" -eq 0 ]; then trv="ZEROLINES"; bad=$((bad+1))
  elif [ "$CUT" = 1 ]; then
    { echo "%---- $o total=$total"; cat "$W/$o.norm"; } >> "$W/NEW.trace"; trv=CUT
  else
    rt=$(refmeta "$o")
    if [ -z "$rt" ]; then trv="NOREF"; bad=$((bad+1))
    elif [ "$rt" != "$total" ]; then trv="FAIL(total $total != ref $rt)"; bad=$((bad+1))
    elif ! refblock "$o" | cmp -s - "$W/$o.norm"; then trv="FAIL(diff)"; bad=$((bad+1))
    else trv="ok($total)"; fi
  fi
  fi

  lines+=("$(printf '%-14s %-16s m3=%-4s m4=%-7s killswitch=%-4s perturb m3=%-4s m4=%-7s trace=%s' "$grp" "$o" "$m3v" "$m4v" "$ks" "$pert3" "$pert4" "$trv")")
done
printf '%s\n' "${lines[@]}"

if [ "$CUT" = 1 ]; then cp "$W/NEW.trace" "$REF"; echo "refs CUT -> $REF ($(grep -c '^%---- ' "$REF") blocks)"; fi

echo "witnesses=$n (capture=2 span-any-break=3 operand-parking=1 arbno=2) . modes m3+m4 . groups capture/span-any-break/operand-parking are REGRESSION PINS on already-cured classes -- EXPECTED PASS/OK."
echo "⭐ arbno_pin_reentry is an OPEN class row, not a pin (credited to FINDING-2026-09-05-seat14-arbno-frame-arm-hangs-re-entering-a-choice-bearing-body.md, already routed to hq_U there -- see that FINDING"
echo "  and FINDING-2026-09-05-seat18-pattern-shared-box-witness-walk.md sec 4 for the mechanism). m3/m4=FAIL(exp) above means it is STILL HANGING, i.e. status quo, not a gate violation. m3/m4=PASS(!) would mean"
echo "  hq_U's cure landed -- also not a violation, but promote this witness out of EXPECT_FAIL/HANGS at that point since it would then behave like groups 1-3."

GATE_EXAMINED=$n; gate_verdict "$bad" "failed checks across correctness/killswitch/perturbation/self-pin (arbno's expected-hang status does not count against this tally, see trailer above)"
