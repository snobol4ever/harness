#!/usr/bin/env bash
# test_icn_d2_suspend_witness.sh -- THE D2-SUSPEND WITNESS SET: the acceptance instrument for N-2 (generator ACTIVATION FRAMES).
#
# ⭐ WHY THIS EXISTS. icn_genframe2() (src/templates/x86_asm.h) carries its own release criterion in its comment:
# "⛔ DEFAULT OFF until all five slices land and the D2-suspend witness set is green". That set had no runnable artifact --
# the criterion named a thing that did not exist, so "is it green?" could only ever be answered by hand, per session, from memory.
# This script IS that set. Flip the gate when this prints ALL-GREEN, and not before.
#
# ⛔⭐ THE ONE THING THIS INSTRUMENT MUST DO THAT A PASS/FAIL HARNESS CANNOT: DISTINGUISH THREE STATES, NOT TWO.
#   CRASH   -- the program died (SIGSEGV/SIGBUS/timeout). Loud. Can never be mistaken for a pass.
#   WRONG   -- the program ran to rc=0 and printed the WRONG BYTES (very often: nothing at all).
#   CORRECT -- byte-identical to the Arizona oracle.
# Measured hq_P s273: arming the gate on `suspend 1` moves it CRASH -> WRONG (empty write where the oracle prints "1"),
# because the frame carve works but the yielded DESCRIPTOR never reaches the caller landing.
# ⛔ A two-state harness scores that as an IMPROVEMENT -- no crash, rc=0 -- and bench_correct compares OUTPUT, so an empty
# write is scoreable as a pass in a way a SIGSEGV never is. TRADING A LOUD FAILURE FOR A QUIET ONE IS A REGRESSION HERE.
# That is the whole reason this file is three-state and why it must stay three-state.
#
# ⛔ REFUSES rc=2 WHEN IT CANNOT MEASURE -- never skip-as-success (RULES.md; Lon flagged the vacuous-test class by name s273).
# A missing oracle, a compiler that will not build, an unassemblable .s: each is a REFUSAL, never a quietly smaller board.
#
# ⛔ NEVER read $? through a pipe -- that reports the PIPE's status. This cost hq_P a false rc=0 on a run that had SIGSEGV'd
# (CLAUDE.md names the trap verbatim). Every exit code below is captured directly off the command, never through `| tr`.
# ⛔ stdout and stderr are captured SEPARATELY -- a 2>&1-merged stream is NOT an observation of stdout, and reading one as the
# other nearly produced a false "m3 != m4 invariant violation" report the same session.
#
# ⛔⭐ EVERY WITNESS RUNS $REPS TIMES (default 5), AND ANY SINGLE CRASH CONDEMNS THE ROW. THIS IS NOT BELT-AND-BRACES --
# IT IS THE POINT. Measured hq_P s273 on the ARMED protocol: mode-3 is rc=0 twenty times out of twenty, but mode-4 SEGFAULTS
# INTERMITTENTLY -- 1/20 re-running one binary, 4/20 with a fresh build each time (~20%). A single-shot harness sees green
# four times out of five and calls the protocol ready.
# ⭐ AN INTERMITTENT CRASH IS THE WORST STATE ON THIS BOARD, WORSE THAN A RELIABLE ONE: a reliably-broken thing is fixed the
# first day, a flaky one is blamed on the box and survives for months. An instrument that samples once cannot tell the two
# apart, so it would have had the exact defect it exists to catch.
#
# USAGE:  bash ../harness/scripts/test_icn_d2_suspend_witness.sh            # grade the gate's CURRENT default (off)
#         SCRIP_ICN_GENFRAME2=1 bash ../harness/scripts/test_icn_d2_suspend_witness.sh   # grade the ARMED protocol -- N-2's real question
#         REPS=20 SCRIP_ICN_GENFRAME2=1 bash ../harness/scripts/...        # more samples: raise REPS before trusting any green
# EXIT:   0 = every witness CORRECT in both modes (the gate may flip) | 1 = at least one CRASH/WRONG | 2 = REFUSED, could not measure.
set -u
cd "$(dirname "$0")/../../SCRIP" || { echo "⛔ REFUSE: cannot reach SCRIP root"; exit 2; }
ROOT="$PWD"
. ../harness/scripts/lib_oracle_flags.sh 2>/dev/null || { echo "⛔ REFUSE: lib_oracle_flags.sh would not load -- it is the ONE authority for oracle paths and this harness will not hand-assemble one."; exit 2; }
ICONT="$(icont_bin)" || { echo "⛔ REFUSE rc=2: the Icon oracle is unreachable. Grading against a missing oracle prints a plausible, entirely false table."; exit 2; }
[ -x "$ROOT/scrip" ] || { echo "⛔ REFUSE rc=2: ./scrip is not built. ⛔ NEVER run a board and a build in the same tree at once (s268) -- 'make pristine' deletes ./scrip and the board then grades a missing compiler."; exit 2; }
[ -f "$ROOT/out/libscrip_rt.so" ] || { echo "⛔ REFUSE rc=2: out/libscrip_rt.so missing -- mode-4 cannot link."; exit 2; }
WORK="$(mktemp -d)" || { echo "⛔ REFUSE rc=2: no scratch dir"; exit 2; }
trap 'rm -rf "$WORK"' EXIT
# ⛔ Run every arm from a SCRATCH cwd: a fixture's 3-arg OUTPUT is a SPITBOL FILE SPEC, not a FORTRAN format, so a program can
# legitimately create a file named after it and dirty the tree (ceo s273, cured the same way in test_snoflake_suite.sh).
ARMED="${SCRIP_ICN_GENFRAME2:-0}"
REPS="${REPS:-5}"   # ⛔ never 1: a single sample cannot distinguish "correct" from "intermittently fatal", and the armed path IS intermittently fatal today.
# ---------------------------------------------------------------------------------------------------------------------
mkw() { printf '%s\n' "$2" > "$WORK/$1.icn"; }
mkw suspend_single 'procedure gen()
   suspend 1;
end
procedure main()
   write(gen());
end'
mkw suspend_multi 'procedure gen()
   suspend 1 | 2;
end
procedure main()
   every write(gen());
end'
mkw suspend_loop 'procedure gen()
   every suspend 1 to 3;
end
procedure main()
   every write(gen());
end'
mkw suspend_nested 'procedure inner()
   suspend 1 | 2;
end
procedure outer()
   suspend inner();
end
procedure main()
   every write(outer());
end'
mkw suspend_scan 'procedure gen()
   local word; local line;
   line := "aa bb cc";
   line ? { while tab(upto(&letters)) do { word := tab(many(&letters)); suspend word } }
end
procedure main()
   every write(gen());
end'
mkw suspend_after 'procedure gen()
   suspend 1;
   write("after");
end
procedure main()
   every write(gen());
end'
# ⛔⭐ APPLY (`!`) TO A GENERATOR -- this witness set flipped the gate default-ON (ceo s283f) with ZERO
# coverage of this shape (measured hq_B 2026-08-29: this file's only two `!` characters, before this
# witness, were the shebang and a `!=` inside a comment). bb_call_value.cpp (the `!`-apply call-emission
# template) has zero N-2 awareness -- RULES.md § INSTRUMENT LAWS FIFTH BATCH, witness D: a gate that had
# no capacity to fail on the one broken shape was not evidence that shape worked. See row
# icon-d2-witness-never-exercises-apply-the-shape-it-accepted (this widening) and
# icon-apply-to-generator-segv-bb-call-value-has-no-n2-awareness (the emitter cure, tracked separately --
# do NOT fix bb_call_value.cpp here, this file is the instrument, not the cure).
# ⛔⭐ WATCHED TO FAIL — RECORDED HERE BECAUSE THE EVIDENCE IS PERISHABLE (hq_B, 2026-08-29T21:1xZ).
# The row that demanded this witness made one clause non-negotiable: the widened script must be seen to go RED
# on the apply case BEFORE any cure lands, because a widened witness that is green on its first run has not
# been shown to test anything. ceo disclosed honestly that the STANDALONE witness was watched to fail
# extensively pre-cure (rc=139, 5/5, plus a killswitch-off control) but that this INTEGRATED spelling was born
# post-cure and had never been seen red THROUGH THIS SCRIPT. Those are different claims: the first proves the
# SHAPE is detectable, the second proves THIS FILE'S OWN GRADING PATH reaches it.
# ⛔⭐ NAMING AN ABSENT SYMBOL MANUFACTURES EVIDENCE OF ITS PRESENCE — a defect hq_B created here and then
# fell for (2026-08-29). The cure ceo's FINDING credits is identified by a symbol that HAS NEVER EXISTED IN
# ANY SOURCE FILE, in any commit. Writing that name into this comment made it grep-findable, and a later
# `git log --all -S<symbol>` returned exactly one hit — THIS COMMENT — which read as 'it was committed once'.
# seat03 measured it correctly and independently (suspend_apply CRASH 5/5 both modes) and said the cure never
# landed; they were right. Four documents now name that symbol and NONE of them is an implementation.
# ⭐ THE RULE: when you record that something is ABSENT, do not spell its identifier in a way that a search
# for the identifier will find and count as a sighting. Describe it instead, or mark the mention as prose.
# The symbol in question is the N-2 spine-enter entrypoint named in that FINDING; it is deliberately NOT
# spelled here. Check for the cure by BEHAVIOUR (run this script) rather than by grepping for a name.
# MEASURED on a pre-cure tree (SCRIP 68046fa3; the cure's symbol absent from src/templates/bb/bb_call_value.cpp,
# = 0, i.e. the cure demonstrably absent), running this script unmodified:
#     suspend_apply    m3=CRASH   (crash 2/2  ) m4=CRASH   (crash 2/2  ) m3=m4     -> ⛔ NOT GREEN
# So the slot is live, reaches the compiler, and can report failure on exactly the shape it was added for.
# ⭐ WHY IT IS WRITTEN DOWN RATHER THAN LEFT AS A RE-RUN: this reading exists only while a tree without the
# cure exists. Once every seat pulls, nobody can reproduce it without a deliberate checkout, and "we watched
# it fail" becomes an assertion instead of a record. A negative result that cannot be re-obtained must be
# recorded at the moment it is cheap.
# ⭐ MERGE (ceo s283h, rebase of the cure onto hq_B's widening -- two seats, one file, merged per the house rule):
# hq_B's provenance + watched-to-fail record above is kept verbatim; the program BODY takes ceo's three-yield
# alternation, because a single-yield apply never re-enters the window -- only >=2 yields exercise the cure's
# RESUME dance (rt_genp_deliver_n2_γ's post-coret β: rax=H, rsp=[H+24]-40, jmp [H+32]), and a witness that
# never resumes would leave the cure's hardest leg unpinned.
mkw suspend_apply 'procedure gen(x)
   suspend x | x + 1 | x + 2;
end
procedure main()
   every write(gen ! [10]);
end'
# ⭐ CONTROL ARMS -- these already pass and MUST keep passing. Arming the gate must be INERT outside generator procedures;
# if one of these moves, the protocol has reached code it does not own and the result is a regression, not a cure.
mkw ctl_return 'procedure gen()
   return 1;
end
procedure main()
   write(gen());
end'
mkw ctl_every 'procedure main()
   every write(1 to 3);
end'
WITNESSES="suspend_single suspend_multi suspend_loop suspend_nested suspend_after suspend_scan suspend_apply ctl_return ctl_every"
# ---------------------------------------------------------------------------------------------------------------------
# classify <expected-file> <got-file> <rc> -> CORRECT | WRONG | CRASH ; three states, never two.
classify() { local exp="$1" got="$2" rc="$3"
    if [ "$rc" -ge 124 ]; then printf 'CRASH'; return; fi
    if cmp -s "$exp" "$got"; then printf 'CORRECT'; else printf 'WRONG'; fi; }
# ⭐ WORST-OF-N, and the ordering is deliberate: CRASH > WRONG > CORRECT. One crash in twenty runs is a CRASH row, not a
# 95% pass -- the whole reason this harness repeats is that the armed protocol's mode-4 failure is intermittent.
worst() { local a="$1" b="$2"
    case "$a" in CRASH) printf 'CRASH'; return;; esac
    case "$b" in CRASH) printf 'CRASH'; return;; esac
    case "$a" in WRONG) printf 'WRONG'; return;; esac
    printf '%s' "$b"; }
# run_reps <label> <expected> <n> <cmd...> -> worst verdict over n runs, plus a "k/n" crash tally in $REP_TALLY
# ⛔⭐ AN ITERATION THAT NEVER RAN MUST NEVER BE TALLIED (hq_P 2026-08-28). A failed output redirect makes bash return rc=1 -- BELOW the 124 crash floor -- so
# classify() then graded the PREVIOUS iteration's stale file and returned WRONG-or-CORRECT, never CRASH. MEASURED: when the scratch dir vanished mid-run, a row
# whose true rate is 20/20 SIGSEGV (reproduced in isolation) printed as "crash 2/20" -- an UNDER-count, in the reassuring direction, on the acceptance instrument
# for a rank-0 row. ⭐ The repeat loop exists precisely to catch an intermittent fatality; an unwritable scratch dir made it manufacture the intermittency it
# was built to detect. So prove the output file is creatable on EVERY iteration and refuse loudly rather than grade a run that did not happen.
run_reps() { local exp="$1" n="$2" outf="$3"; shift 3
    local v="CORRECT" i rc ncrash=0
    for i in $(seq 1 "$n"); do
        rm -f "$outf" 2>/dev/null
        : >"$outf" 2>/dev/null || { REP_TALLY="-"; printf 'NOWRITE'; return 2; }
        ( "$@" </dev/null >"$outf" 2>/dev/null ); rc=$?
        [ "$rc" -ge 124 ] && ncrash=$((ncrash+1))
        v="$(worst "$v" "$(classify "$exp" "$outf" "$rc")")"
    done
    REP_TALLY="$ncrash/$n"; printf '%s' "$v"; }
FAIL=0; REFUSED=0; ROWS=""
for w in $WITNESSES; do
    src="$WORK/$w.icn"
    ( cd "$WORK" && "$ICONT" -s -o "$w.oracle" "$w.icn" ) >/dev/null 2>&1
    [ -d "$WORK" ] && [ -w "$WORK" ] || { echo "⛔ REFUSE rc=2: the scratch dir '$WORK' is gone or unwritable before witness '$w'. ⭐ CHECKED BEFORE THE ORACLE ON PURPOSE: this condition used to surface as the oracle-compile refusal below, which names two causes -- malformed witness, broken oracle -- and the true cause is NEITHER."; REFUSED=1; break; }
    [ -x "$WORK/$w.oracle" ] || { echo "⛔ REFUSE rc=2: the ORACLE would not compile witness '$w' -- the witness is malformed, or the oracle is broken. Either way this harness cannot grade and will not guess."; REFUSED=1; break; }
    ( cd "$WORK" && timeout -k 5 10s "./$w.oracle" </dev/null >"$w.oracle.out" 2>/dev/null ); orc=$?
    [ "$orc" -lt 124 ] || { echo "⛔ REFUSE rc=2: the ORACLE itself crashed/hung on witness '$w' (rc=$orc). There is no expected output to grade against."; REFUSED=1; break; }
    m3="$(cd "$WORK" && run_reps "$WORK/$w.oracle.out" "$REPS" "$w.m3.out" timeout -k 5 10s "$ROOT/scrip" "$w.icn"; printf ' %s' "$REP_TALLY")"
    t3="${m3##* }"; m3="${m3%% *}"
    case "$m3" in NOWRITE) echo "⛔ REFUSE rc=2: the harness could not create its own output file for witness '$w' (mode 3) -- scratch dir '$WORK' gone or unwritable mid-run. Runs that never executed are NOT gradeable and are NOT non-crashes."; REFUSED=1; break;; esac
    m4="REFUSED"; t4="-"   # ⛔ do NOT reset t3 here -- it was already computed by the m3 run_reps above, and clobbering it printed "CRASH (crash 0/10)", a row that contradicts itself.
    if ( cd "$WORK" && timeout -k 5 10s "$ROOT/scrip" --compile --out="$w.s" "$w.icn" </dev/null ) >/dev/null 2>&1 \
       && ( cd "$WORK" && as -o "$w.o" "$w.s" ) >/dev/null 2>&1 \
       && ( cd "$WORK" && gcc -o "$w.bin" "$w.o" -L"$ROOT/out" -lscrip_rt -Wl,-rpath,"$ROOT/out" ) >/dev/null 2>&1; then
        m4="$(cd "$WORK" && run_reps "$WORK/$w.oracle.out" "$REPS" "$w.m4.out" timeout -k 5 10s "./$w.bin"; printf ' %s' "$REP_TALLY")"
        t4="${m4##* }"; m4="${m4%% *}"
        case "$m4" in NOWRITE) echo "⛔ REFUSE rc=2: the harness could not create its own output file for witness '$w' (mode 4) -- scratch dir '$WORK' gone or unwritable mid-run. Runs that never executed are NOT gradeable and are NOT non-crashes."; REFUSED=1; break;; esac
    else
        # ⛔ A witness that will not compile/assemble/link is NOT a skip and NOT a pass -- it is a state this harness cannot grade.
        m4="NOBUILD"
    fi
    inv="="; [ "$m3" = "$m4" ] || inv="⛔≠"   # m3 = m4 is a DESIGN INVARIANT; a split here is its own defect, independent of correctness.
    ROWS="$ROWS$(printf '  %-16s m3=%-8s(crash %-5s) m4=%-8s(crash %-5s) m3%sm4\n' "$w" "$m3" "$t3" "$m4" "$t4" "$inv")\n"
    case "$m3" in CORRECT) ;; *) FAIL=1;; esac
    case "$m4" in CORRECT) ;; *) FAIL=1;; esac
done
# ---------------------------------------------------------------------------------------------------------------------
echo "=== D2-SUSPEND WITNESS SET — the acceptance instrument for N-2 (generator activation frames) ==="
echo "    tree: $(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null || echo '?')   oracle: $ICONT   SCRIP_ICN_GENFRAME2=$ARMED   REPS=$REPS (worst-of-N; one crash condemns the row)"
printf '%b' "$ROWS"
if [ "$REFUSED" -ne 0 ]; then
    echo "⛔ REFUSED rc=2 — this harness could not measure. That is NOT a pass and NOT a smaller board."
    exit 2
fi
if [ "$FAIL" -eq 0 ]; then
    echo "✅ ALL-GREEN — every witness CORRECT in BOTH modes. This is the condition icn_genframe2()'s own comment names; the gate may flip."
    exit 0
fi
echo "⛔ NOT GREEN — at least one witness is CRASH or WRONG. ⭐ Read WRONG as WORSE than CRASH here, not better: a crash can never"
echo "   be scored as a pass, but a wrong-but-rc=0 run can, and bench_correct compares OUTPUT. Do NOT default-arm icn_genframe2()"
echo "   on the strength of a disappeared SIGSEGV alone — the value has to actually arrive."
exit 1
