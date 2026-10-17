#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/lib_one_runner.sh" && one_runner_guard "${0##*/}" || exit 2
# ⛔ THE STATEMENT INSTRUMENTATION (--stlimit) IS EACH PROGRAM'S OWN compile_args DECLARATION (clause 8 (f), CEO-1281, landing 4): the rungs' entries declare it in tests/snobol4/ALL.csv, which the harness applies; a demo row declares it in its <stem>.cmdline sidecar, which run_test reads. This board exported SCRIP_SNO_STMTKW=1 for every program until 2026-09-26 (Lon 2026-09-24 16:0x: off by default, never inferred from the source); measured that day, all 23 demos run byte-identical in both modes without it
# ../harness/scripts/test_corpus_snobol4.sh — SNOBOL4 broad corpus, modes 2+3+4
# Mode-4 gate (hard). Modes 2+3 informational. Reinstated 2026-06-08.
# Compares output against .ref files. Reports PASS/FAIL/SKIP per mode.
#
# Self-contained per RULES.md: paths from $0, timeout on every run.
# AUTHORS: Lon Jones Cherryholmes · Claude Sonnet 4.6   DATE: 2026-05-14
S4E="${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"   # D-17 PORTABLE-HOME: the sibling root (all repos + oracles are siblings under ONE root; /home/claude2-style seat roots work with zero env; S4E_HOME overrides)

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export TIMEOUT_RETRY="${TIMEOUT_RETRY:-$HERE/util_timeout_retry.sh}"   # a graded run's timeout (CEO-1335): a timeout under load is retried once, util_timeout_retry.sh
# ⛔⭐ RECORD THE TREE THIS RUN GRADES, AT ITS START (hq_T 2026-09-08). A board takes ten to forty minutes and its
# SCORE.md write happens at the END; a seat who commits and pushes mid-run -- which the CEO-174 dirty-tree guard
# actively pushes you toward, since a dirty tree skips the write entirely -- moves HEAD under a measurement that
# already happened, and the row then names a tree carrying commits it never ran. Measured three times in one
# sitting, twice while doing the disciplined thing. util_score_row.py stamps this instead of HEAD, and says so
# when the two differ; unset, it behaves exactly as it always did.
# ⛔ THE HAND-SPELLED export S4E_TREE_AT_START THAT STOOD HERE IS RETIRED ONTO gate_tree_watch (coo
# 2026-09-10, COO-54). It was written out in THREE runners and ABSENT from the three Icon package
# boards the one runner runs every hour, so three of four boards stamped HEAD AT WRITE TIME -- which is
# CEO-524 (1)'s defect in its second form. One spelling, in lib_gate.sh, set by the same call that takes
# the baseline: a board cannot now acquire the stamp without also acquiring the refusal.
SCRIP="${SCRIP:-$HERE/../../SCRIP/scrip}"
RT_DIR="${RT_DIR:-$HERE/../../SCRIP/out}"
CORPUS="$S4E/corpus"
# ⛔⭐⭐ THE BINARY MAY NOT MOVE UNDER A RUNNING BOARD. Measured here 2026-09-06 (hq_S): a board was started and
# an incremental `make` was run while it was still grading. The harness happened to try to exec ./scrip during
# the relink, died with PermissionError, and REFUSED -- which is the honest outcome and the ONLY reason it was
# noticed. Had the relink finished a second earlier, half the population would have been graded on one binary
# and half on another, and the board would have printed A COMPLETE, PLAUSIBLE TABLE with no way for any reader
# to tell. That is this house's own recurring shape: an instrument that cannot fail prints exactly like one
# that passed.
# ⛔ FINGERPRINT BOTH, AND THE SECOND IS THE ONE THAT MATTERS: ./scrip links the emitter and runtime
# DYNAMICALLY, so it is BYTE-IDENTICAL across the two arms of any emitter or runtime change -- a scrip-only
# check is vacuous exactly when it matters most (measured on an emit.cpp A/B, where two agents verified
# scrip's md5 as proof the binary had not moved and the check was empty for the property in question).
# ⭐ AND THE STRONGER MOVE, WHERE IT IS AFFORDABLE (hq_P, same day): put the change behind a killswitch and run
# BOTH ARMS OFF ONE BUILD, env-only. That removes the hazard rather than detecting it. This guard is for the
# case a killswitch cannot cover -- a board that takes minutes while somebody else, or your own next command,
# rebuilds the tree underneath it.
# ⛔⭐ THE PRIVATE COPY THAT LIVED HERE IS RETIRED ONTO lib_gate.sh (coo 2026-09-10, ceo CEO-524 (1)). This
# board is where the guard was INVENTED, and hq_S hoisted it into gate_bin_watch/gate_bin_unmoved on
# 2026-09-06 so seven boards would not each spell it -- but the donor kept its own copy, so the fleet had the
# authority AND the original side by side, which is the exact shape util_require_fresh.sh's header warns about
# (curing one copy strengthens everyone's belief the class is dead while the other keeps the bug). The rule now
# lives in ONE place; this file states only which artifacts it is watching.
if ! . "$HERE/lib_gate.sh" 2>/dev/null || ! command -v gate_bin_watch >/dev/null 2>&1; then
    echo "⛔ REFUSED TO GRADE rc=2: lib_gate.sh unavailable or missing gate_bin_watch -- this board cannot tell whether its binary moves under it" >&2
    exit 2
fi
GATE_NAME=test_corpus_snobol4 gate_bin_watch "$SCRIP" "$RT_DIR/libscrip_rt.so"
# ⛔⭐ THE TREE MOVED UNDER THIS BOARD, and the stamp that names the tree this row actually graded
# (coo 2026-09-10, COO-54, on the coo's own witness: a pass recorded one corpus hash and a background job
# moved corpus eight seconds later; gate_bin_watch stayed silent and was right to, because the BINARY had
# not moved). One call: gate_tree_watch exports S4E_TREE_AT_START in util_score_row's own vocabulary AND
# takes the baseline, so this board stops stamping HEAD-at-WRITE-time and starts refusing a split reading.
GATE_NAME=test_corpus_snobol4 gate_tree_watch "$(cd "$HERE/../.." && pwd)"
# ⛔⭐ 10s WAS A FAIL FACTORY AT FLEET LOAD, AND THE KILL WAS INDISTINGUISHABLE FROM A WRONG ANSWER
# (hq_C 2026-08-29, verified by hq_B). This bound is PER PROGRAM, not for the board. A program taking 2s on a
# quiet box can exceed 10s at load 30 with ~20 concurrent boards -- and because the captures below said
# `|| true`, rc=124 was DISCARDED at the point of capture, the SIGTERM-truncated stdout was compared to the
# .ref like any other answer, and the board printed FAIL. So two runs of THE CORRECTNESS BLOCKING FLOOR on an
# identical tree at different fleet loads could legitimately disagree, with nothing in the output saying which
# was contended. Raised to an order of magnitude over the measured per-program cost (a 1381-program board
# measures M3=20s M4=53s in total, i.e. tens of ms each) rather than beside it.
# ⛔ The raise alone does NOT remove the ambiguity, it only moves the threshold. The real cure is the third
# state: see the rc capture in run_test and the TIMEOUT-KILLED refusal near the verdict.
# ⛔⭐⭐ TIMEOUT HAS TWO CONSUMERS AND THEY DISAGREE ABOUT WHO SET IT (hq_C 2026-08-29, own-goal report;
# asymmetry measured by hq_B). This script reads it per program, AND corpus_suite_harness.py:120 reads the
# SAME env var per suite entry (float(os.environ.get("TIMEOUT","10"))). Nobody had documented that.
# ⛔ THE TRAP IS THE ASYMMETRY, not the sharing:
#   `TIMEOUT=600 bash ../harness/scripts/test_corpus_snobol4.sh`  -> puts it in the ENVIRONMENT, so the harness
#                                                          INHERITS it and every suite entry gets 600s too.
#   the assignment below                                -> NOT exported, so the harness does NOT see it and
#                                                          keeps its own default of 10.
# So the identical name means different things depending on WHERE it was set, and only the command-line form
# reaches the families. hq_C set 600 believing they were buying immunity from load-manufactured FAILs; it
# propagated into the harness and made every expected-hang XFAIL entry burn up to 600s PER MODE -- a ~50
# minute board against 466s here -- and the verdict was IDENTICAL either way, because those entries are XFAIL
# at 10s and XFAIL at 600s. A large cost for a hazard that did not exist on this population.
# ⚠️ If you want to change what the FAMILIES get, export it or set it per-call (see the TIMEOUT=30 below).
# Changing the value here moves only the loose/hardcoded programs.
TIMEOUT="${TIMEOUT:-120}"
# ⭐ SHARDED / RESUMABLE ARM (row corpus-runner-master-suite-exceeds-single-call-cap, hq_B 2026-09-02). The rungs block
# is one 1700+-entry harness run (~220s here alone, ~7.7 min under fleet load), so a caller under a single-call cap got a
# REFUSAL (rc=2, "no SUITE_BOARD line") instead of a verdict -- honest, but a blocking gate nobody can run in one call is a
# gate nobody runs. Now: `--shard k/N` grades ONLY the rungs' k-th interleaved N-th of the entries (the harness's own
# --shard, so every entry lands in exactly one shard) and writes its SUITE_BOARD to a CHECKPOINT stamped with the scrip
# binary's and the rungs pair's md5 -- then exits WITHOUT a verdict ("verdict at --combine"). `--combine N` reads the N
# checkpoints, REFUSES rc=2 if any is missing or was cut on a different binary/rungs (stale by construction, never summed),
# SUMS every count into one synthesized board line, and then runs everything else (demo arms, floors, GATE line) exactly
# as the monolithic run does. PROVEN byte-equal once: monolithic summary == --shard 1/3, 2/3, 3/3 + --combine 3 (ledger).
# Checkpoints live under $SCRIP_BOARD_CKPT (default /tmp/si_board_shards<seat-root-with-dashes>, per checkout like the objdir).
SHARD=""; COMBINE=""
while [ $# -gt 0 ]; do
    case "$1" in
        --shard=*)   SHARD="${1#--shard=}";;
        --shard)     shift; SHARD="${1:-}";;
        --combine=*) COMBINE="${1#--combine=}";;
        --combine)   shift; COMBINE="${1:-}";;
        -h|--help)   sed -n '/^# ⭐ SHARDED/,/^SHARD=""/p' "$0" | grep '^#' | sed 's/^# \{0,1\}//'; exit 0;;
        *) echo "⛔ REFUSED: unknown argument '$1' (accepted: --shard k/N | --combine N | --help)"; exit 2;;
    esac; shift
done
case "$SHARD" in ""|[0-9]*/[0-9]*) :;; *) echo "⛔ REFUSED: --shard wants k/N, got '$SHARD'"; exit 2;; esac
case "$COMBINE" in ""|[1-9]*) :;; *) echo "⛔ REFUSED: --combine wants N (a count), got '$COMBINE'"; exit 2;; esac
[ -n "$SHARD" ] && [ -n "$COMBINE" ] && { echo "⛔ REFUSED: --shard and --combine are two different calls, not one"; exit 2; }
CKPT="${SCRIP_BOARD_CKPT:-/tmp/si_board_shards$(printf '%s' "$S4E" | tr / -)}"
board_stamp() { printf 'stamp scrip=%s rungs=%s-%s\n' "$(md5sum < "$SCRIP" | cut -c1-12)" "$(md5sum < "$RUNGS_SNO" | cut -c1-12)" "$(md5sum < "$RUNGS_REF" | cut -c1-12)"; }
board_checkpoint_write() {   # <k/N> <run board line>
    local f="$CKPT/rungs.${1%/*}-of-${1#*/}.board"; mkdir -p "$CKPT" || { echo "⛔ REFUSED: cannot create checkpoint dir $CKPT"; exit 2; }
    { board_stamp; printf '%s\n' "$2"; } > "$f"
    echo "SHARD $1 boarded -> $f"; echo "   $2"; echo "   no verdict here: run the other shards, then '$0 --combine ${1#*/}' for the GATE line"
}
# ⭐ `shard` is EXCLUDED from the sum: it matches the generic key pattern, so the old loop summed 1/3+2/3+3/3 and
# printed `shard=6` on a line that grades no shard at all. Harmless to field(), and a plain lie to a human reader.
board_combine() {   # <N> -> prints the synthesized SUITE_BOARD line on stdout; refusals on stderr, rc 2
    local n="$1" k f want="$(board_stamp)" got line prefix key kv
    for k in $(seq 1 "$n"); do
        f="$CKPT/rungs.$k-of-$n.board"
        [ -f "$f" ] || { echo "⛔ GATE REFUSES: checkpoint for shard $k/$n missing at $f -- run '$0 --shard $k/$n' first; a partial sum is not a board" >&2; return 2; }
        got="$(sed -n 1p "$f")"; [ "$got" = "$want" ] || { echo "⛔ GATE REFUSES: checkpoint $k/$n was cut on a different tree ($got vs now $want) -- stale by construction, re-run that shard" >&2; return 2; }
    done
    for prefix in SUITE_BOARD; do
        unset sum; declare -A sum; local -a keys=()
        for k in $(seq 1 "$n"); do
            f="$CKPT/rungs.$k-of-$n.board"
            line="$(grep -m1 "^$prefix " "$f")"; [ -n "$line" ] || { echo "⛔ GATE REFUSES: checkpoint $k/$n carries no $prefix line -- it predates the two-population board; re-run '$0 --shard $k/$n'" >&2; return 2; }
            echo "$line" | grep -q " shard=$k/$n " || { echo "⛔ GATE REFUSES: checkpoint $k/$n's $prefix is tagged '$(echo "$line" | grep -oE 'shard=[0-9/]+')', not shard=$k/$n" >&2; return 2; }
            for kv in $(echo "$line" | grep -oE '[a-z0-9_]+=[0-9]+' | grep -v '^shard='); do key="${kv%%=*}"; [ -n "${sum[$key]+x}" ] || keys+=("$key"); sum[$key]=$(( ${sum[$key]:-0} + ${kv#*=} )); done
        done
        printf '%s family=ALL combined=%s' "$prefix" "$n"; for key in "${keys[@]}"; do printf ' %s=%s' "$key" "${sum[$key]}"; done; printf '\n'
    done
}
TMOUT3=0; TMOUT4=0; TMOUT_LIST=""
INC="${INC:-$CORPUS/include}"
BEAUTY="${BEAUTY:-$CORPUS/tests/snobol4/beauty_suite}"
DEMO="${DEMO:-$CORPUS/demos/snobol4}"

# ⛔⛔⛔ s272 hq_C (CEO audit correction 2) — A MISSING PREREQUISITE IS A REFUSAL (rc=2), NEVER A GREEN EXIT.
# These two arms printed SKIP and exited 0, so a box with no compiler built, or no corpus cloned, reported
# SUCCESS to every caller that reads $? — which is every gate, every board, and handoff_status.sh. That is the
# ABSENT-ORACLE FALSE-GREEN class, and it is the exact twin of the `make test` no-recipe trap: a check that
# ran nothing and said nothing was wrong. ⭐ rc=2 means REFUSED-TO-GRADE and is distinct from rc=1 FAILED:
# a caller can tell 'I could not measure' from 'I measured and it is broken'. Silence could say neither.
if [ ! -x "$SCRIP" ]; then echo "⛔ REFUSED TO GRADE: scrip not built at $SCRIP" >&2; exit 2; fi
if [ ! -d "$CORPUS" ]; then echo "⛔ REFUSED TO GRADE: corpus not found at $CORPUS" >&2; exit 2; fi
# ⛔⭐ A BOARD THAT CANNOT SAY WHAT IT GRADED MUST REFUSE, NOT LABEL (FINDING-2026-08-30-hq_C-the-snobol4-board-
# grades-whatever-scrip-exists-and-labels-that-verdict-with-git-head.md). This script never builds -- it grades
# whichever $SCRIP happens to be sitting in the tree and stamps the report with git HEAD, so a green board was
# not evidence about the SHA it named: a pristine build of the exact commit a board called clean SIGSEGV'd two
# counted entries. gate_require_fresh refuses rc=2 (UNPROVEN, never a silent pass) before grading anything.
if ! . "$HERE/lib_gate.sh" 2>/dev/null || ! command -v gate_require_fresh >/dev/null 2>&1; then
    echo "⛔ REFUSED TO GRADE: lib_gate.sh unavailable or missing gate_require_fresh -- cannot verify binary freshness" >&2
    exit 2
fi
gate_require_fresh "$HERE/../../SCRIP" src "$SCRIP" "$RT_DIR/libscrip_rt.so"
. "$HERE/lib_declared_arena.sh" 2>/dev/null || { echo "⛔ REFUSED TO GRADE rc=2: lib_declared_arena.sh unloadable -- the one reader of a program's declared command line" >&2; exit 2; }
# ⛔⛔ REFUSE ON A MISSING SUBTREE -- DO NOT SILENTLY DISCOVER FEWER PROGRAMS (hq_C s271). This board read
# "PASS=342 FAIL=0" for a whole session because $DEMO pointed at a path that did not exist: every visible signal
# said green while 22 programs had left the denominator. A clean numerator over a shrunken denominator is the most
# dangerous shape a board has, and corpus paths have moved three times in two days, so this WILL happen again.
# FAIL=0 is not a verdict; FAIL=0 over the expected denominator is.
for _d in "$DEMO"; do   # beauty_suite left this list 2026-08-29: its 13 drivers were absorbed into the RUNGS suite (one-flat-suite cutover) and the dir no longer exists; the rungs block refuses on ITS absence instead
    if [ ! -d "$_d" ]; then echo "⛔ GATE REFUSES: corpus subtree missing: $_d"; echo "   The corpus layout moved. Repoint this script; do NOT read a smaller total as a pass."; exit 2; fi
done

PASS3=0; FAIL3=0; FAILURES3=""
PASS4=0; FAIL4=0; SKIP4=0; FAILURES4=""
# ⛔⭐ THE AND PER PROGRAM (ceo-372, 2026-09-06): the number this suite's leaderboard row states is the count of
# programs green in EVERY mode they were graded in -- not m3 alone (what this row published until now), not m4
# alone, and never min(PASS3,PASS4), which counts nothing real: one program red only in m3 and another red only
# in m4 give min()=N-1 while the AND is N-2, so the min silently forgives a program that is red somewhere.
# It is accumulated in run_test(), where one program's two verdicts are both in hand; it cannot be recovered
# from PASS3/PASS4 afterwards, which is exactly why the row had to pick a mode before this.
BOTH=0
# ⛔⭐ XFAILS ARE COUNTED, NOT DROPPED (Lon's FACT RULE via ceo CEO-416: an xfail counts as a FAIL, so it belongs
# in the DENOMINATOR and out of the numerator). Before these two accumulators existed, m3x/m4x were read from the
# board and then given to nothing, so TOTAL summed pass+fail+skip only and every known red vanished from BOTH
# sides at once -- the runner published N/N and re-flipped the ruled announcement row on every run, by any seat.
XFAIL3=0; XFAIL4=0
MISSING=0; MISSING_LIST=""

WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT
T_M3=0; T_M4=0; T0_ALL=$SECONDS

compile_mode4() {
    local sno="$1" out="$2" ca="${3:-}"   # ca: the program's declared compile_args (run_test reads them), after --compile
    local tmp; tmp="$(mktemp -d)"
    SNO_LIB="$INC" "$SCRIP" --compile $ca "$sno" > "$tmp/p.s" 2>/dev/null || { rm -rf "$tmp"; return 1; }
    (cd "$HERE/../../SCRIP" && gcc -c "$tmp/p.s" -o "$tmp/p.o" 2>/dev/null) || { rm -rf "$tmp"; return 1; }
    # ⛔ -no-pie is NOT applied here, deliberately -- RULED, not blocked: row
    # `m4-pie-vs-no-pie-changes-behaviour-not-just-signal` (seat10 2026-08-28), full analysis in
    # .github/ARCH-ENGINE.md § "Mode-4 Link Mode". gdb on the faulting RSP showed -no-pie is the broken arm, not
    # a measurement artifact: fz_red_m2a_fence_cap_gen / fz_segv_10 are .ref="match" (not crash-expected), PIE
    # runs them clean 20/20, -no-pie SIGSEGVs them 20/20 with RSP==0x0 at fault -- a normal stack address at the
    # identical point under PIE. See corpus_suite_harness.py's compile_m4() for the mirrored banner.
    gcc "$tmp/p.o" -L"$RT_DIR" -lscrip_rt -lm \
        -Wl,-rpath,"$RT_DIR" -o "$out" 2>/dev/null || { rm -rf "$tmp"; return 1; }
    rm -rf "$tmp"
}

# ⛔⛔ A HARDCODED PATH THAT NO LONGER RESOLVES IS A MISSING PROGRAM, NOT A MISSING TEST (hq_C s272, seat04's find).
# The s271 guard above checks the DIRECTORIES exist; it cannot see that $DEMO/wordcount/wordcount.sno stopped
# resolving when the tree re-nested underneath it. These two lines used to `return` silently, so each of the ~40
# hardcoded demo rows below could leave the board with NO signal at all -- neither PASS, nor FAIL, nor SKIP. The
# corpus demo paths have now been repointed FIVE times in one day (6ce46ebc dac73079 843cacfb 1177e66e 50923f55),
# and every single break was noticed only because a human recognised the printed total had shrunk. That is not an
# instrument. ⛔ The DISCOVERED corpora (crosscheck, beauty) filter a ref-less .sno BEFORE calling here, so a
# missing file can only ever mean a stale hardcoded path -- which is always a defect and never a legitimate skip.
run_test() {
    local label="$1" sno="$2" ref="$3" input="${4:-}" filter="${5:-}" heap_kb="${6:-}" stack_kb="${7:-}"
    if [ ! -f "$sno" ]; then MISSING=$((MISSING+1)); MISSING_LIST="${MISSING_LIST}  ${label}: no program at ${sno}\n"; return; fi
    if [ ! -f "$ref" ]; then MISSING=$((MISSING+1)); MISSING_LIST="${MISSING_LIST}  ${label}: no oracle ref at ${ref}\n"; return; fi
    local exp; exp=$(cat "$ref")
    local slug; slug=$(echo "$label" | tr '/: ' '_')
    local inp_arg; [ -n "$input" ] && [ -f "$input" ] && inp_arg="$input" || inp_arg=""
    # ⛔⭐ THE DECLARED ARENA, FOR THIS LOOP PROGRAM ONLY (mirrors corpus_suite_harness.py's heap_kb column,
    # CEO-1167): a hardcoded loop-program row has no ALL.csv cell to read, so its declared need is a 6th
    # argv here instead. Empty means the shipped default, so every existing call above (5 args) is
    # byte-identical to before this parameter existed.
    # ⛔ SINCE CEO-1261 (Lon 2026-09-25) a declared heap is the program's MAXIMUM, SPITBOL's -d, exported as the cap and never as the window.
    local heap_env=(); [ -n "$heap_kb" ] && heap_env=("SCRIP_HEAP_CAP_KB=$heap_kb")
    # ⭐ AND THE DECLARED STACK AS AN OPTIONAL 7th argv, the same way (CEO-1225): SCRIP_STACK sizes the m3 process and the m4 binary.
    [ -n "$stack_kb" ] && heap_env+=("SCRIP_STACK=${stack_kb}k")
    # ⭐ AND THE PROGRAM'S OWN COMPILE SWITCHES, from its <stem>.cmdline sidecar (clause 8 (f), CEO-1281, landing 4): placed after --run and
    # --compile, both modes; a sidecar the reader refuses refuses the board, which never grades around a declaration it cannot honour.
    local ca; ca="$(declared_compile_args_beside "$sno")" || { echo "⛔ REFUSED TO GRADE rc=2: $label's command-line sidecar is refused (named above)" >&2; exit 2; }


    # ── Mode 3: --run ──────────────────────────────────────────────────────
    local T0m3=$SECONDS
    local got3
    # ⛔⭐ CAPTURE THE rc INSTEAD OF THROWING IT AWAY. `|| true` discarded rc=124, so the runner never held
    # the one byte that says "we did not wait long enough" -- it then compared truncated stdout to the .ref and
    # reported the only fact it had left. A SIGTERMed program was NOT MEASURED: neither PASS nor FAIL but
    # UNPROVEN, the same three-state doctrine lib_gate.sh exists to enforce.
    local rc3=0
    local m3ok=0   # ⭐ the m3 half of this program's AND -- a TIMEOUT or a FAIL both leave it 0, because neither is green
    if [ -n "$inp_arg" ]; then
        got3=$(env SNO_LIB="$INC" "${heap_env[@]}" "$TIMEOUT_RETRY" "$TIMEOUT" "$SCRIP" --run $ca "$sno" < "$inp_arg" 2>/dev/null); rc3=$?
    else
        got3=$(env SNO_LIB="$INC" "${heap_env[@]}" "$TIMEOUT_RETRY" "$TIMEOUT" "$SCRIP" --run $ca "$sno" < /dev/null 2>/dev/null); rc3=$?
    fi
    [ -n "$filter" ] && got3=$(printf '%s\n' "$got3" | grep -v "$filter" || true)
    T_M3=$((T_M3+SECONDS-T0m3))
    if [ "$rc3" -eq 124 ]; then
        TMOUT3=$((TMOUT3+1)); TMOUT_LIST="${TMOUT_LIST}  TIMEOUT-M3 ${label} (killed at ${TIMEOUT}s -- NOT graded)\n"
    elif [ "$got3" = "$exp" ]; then PASS3=$((PASS3+1)); m3ok=1
    else FAIL3=$((FAIL3+1)); FAILURES3="${FAILURES3}  FAIL-M3 ${label}\n"; fi

    # ── Mode 4: --compile → assemble → link → run ─────────────────────────
    local T0m4=$SECONDS
    if [ ! -f "$RT_DIR/libscrip_rt.so" ]; then SKIP4=$((SKIP4+1)); return; fi
    local bin="$WORKDIR/${slug}.bin"
    if ! compile_mode4 "$sno" "$bin" "$ca"; then SKIP4=$((SKIP4+1)); FAILURES4="${FAILURES4}  SKIP(compile/link) ${label}\n"; return; fi
    local got4
    local rc4=0
    if [ -n "$inp_arg" ]; then
        got4=$(env SNO_LIB="$INC" "${heap_env[@]}" "$TIMEOUT_RETRY" "$TIMEOUT" "$bin" < "$inp_arg" 2>/dev/null); rc4=$?
    else
        got4=$(env SNO_LIB="$INC" "${heap_env[@]}" "$TIMEOUT_RETRY" "$TIMEOUT" "$bin" < /dev/null 2>/dev/null); rc4=$?
    fi
    [ -n "$filter" ] && got4=$(printf '%s\n' "$got4" | grep -v "$filter" || true)
    T_M4=$((T_M4+SECONDS-T0m4))
    if [ "$rc4" -eq 124 ]; then
        TMOUT4=$((TMOUT4+1)); TMOUT_LIST="${TMOUT_LIST}  TIMEOUT-M4 ${label} (killed at ${TIMEOUT}s -- NOT graded)\n"
    elif [ "$got4" = "$exp" ]; then PASS4=$((PASS4+1)); [ "$m3ok" -eq 1 ] && BOTH=$((BOTH+1))
    else FAIL4=$((FAIL4+1)); FAILURES4="${FAILURES4}  FAIL ${label}\n"; fi
}

# ── Crosscheck corpus ──────────────────────────────────────────────────────────
while IFS= read -r sno; do
    ref="${sno%.sno}.ref"
    input="${sno%.sno}.input"
    [ ! -f "$ref" ] && continue
    label=$(basename "$sno" .sno)
    run_test "$label" "$sno" "$ref" "$input" ""
done < <(find "$CORPUS/crosscheck" -name "*.sno" 2>/dev/null | sort)
# ⛔⭐ THE LOOSE CROSSCHECK TREE IS GONE, AND ITS ABSENCE HAS TWO CAUSES THAT LOOK IDENTICAL HERE
# (hq_B 2026-08-29, on seat16's report of `find: corpus/crosscheck: No such file or directory`).
#   (a) CONVERTED -- every loose file became a suite family under $CORPUS/tests/snobol4/crosscheck, which the
#       suite block below discovers and grades. Correct end state; the loop above SHOULD find nothing.
#   (b) MOVED/RENAMED -- the layout shifted again and this path is simply stale, in which case the board loses
#       the whole subtree and still prints FAIL=0.
# The $DEMO/$BEAUTY guard above already refuses (b) for its two subtrees, with the right words: "A clean
# numerator over a shrunken denominator is the most dangerous shape a board has, and corpus paths have moved
# three times in two days, so this WILL happen again." It happened again, to the ONE subtree not in that list.
# ⛔ So crosscheck gets the same refusal, conditioned on the distinguisher the other two do not need: absence of
# the loose tree is acceptable ONLY when the converted families are actually present to be graded instead.
if [ ! -d "$CORPUS/crosscheck" ]; then
    _cc_rungs="$CORPUS/tests/snobol4/ALL.csv"
    if [ -f "$_cc_rungs" ] && grep -q ',crosscheck_' "$_cc_rungs"; then
        echo "note: loose crosscheck tree is absent and its entries live in the RUNGS suite (one-flat-suite ruling) — graded by the rungs block below, not skipped."
    else
        echo "⛔ GATE REFUSES: corpus subtree missing: $CORPUS/crosscheck"
        # ⛔⭐ THIS MESSAGE USED TO NAME $_cc_conv, A VARIABLE THAT NO LONGER EXISTS. The guard was repointed at
        # the RUNGS when crosscheck was absorbed into it, but the refusal text kept citing the old
        # directory variable -- and with no `set -u` an undefined name expands to EMPTY, so the refusal read
        # "...exist at " and pointed the reader nowhere. ⭐ Error paths are the least-exercised code in any
        # instrument, so a stale reference there survives every green run and only surfaces on the day
        # something is already wrong -- degrading the diagnostic exactly when the diagnostic is all you have.
        echo "   AND the rungs suite at $_cc_rungs carries no crosscheck_ entries either, so this board would grade a"
        echo "   NARROWER DENOMINATOR and still print FAIL=0. The corpus layout moved. Repoint this script;"
        echo "   do NOT read a smaller total as a pass."
        exit 2
    fi
fi

# ── THE ONE FLAT SUITE (Lon 2026-08-29: "one big *.sno and one big *.ref ... Not 10's of folders and 100's of files") ──
# Replaces the three per-family discovery blocks that lived here (crosscheck / probe / top-level-misc --
# each with its own floor): every absorbed family's entries are graded through the ONE rungs pair, with
# per-entry provenance in ALL.csv's origin column and levels as rank prefixes. The un-absorbable
# residue (beauty_suite drivers, rtx_func_11, linker, probe_loose, stdin classes) is listed LOUDLY in
# ALL.excluded.txt and still graded by its own blocks below (beauty) or its own instruments.
# Counter folding is byte-identical to the retired blocks': fail+crash -> FAIL, hang/unproven -> TMOUT
# (measured-nothing, never a verdict), m4 compile/link skip -> SKIP4. XFAIL entries are graded separately
# by the harness (a pre-existing red never inflates FAIL); XPASS is echoed loudly -- a cured bug whose
# marker nobody promoted is actionable in the opposite direction.
# ⭐ HARNESS honours an environment override (ladder I rung I9, hq_B 2026-09-01): the row's DONE-WHEN injects a fake harness that
# prints a cause line and exits 1, to prove the refusal below CARRIES the harness's stderr. The default is unchanged; the override is
# a test hook, and a test that cannot inject its instrument cannot prove the fail direction.
HARNESS="${HARNESS:-$HERE/corpus_suite_harness.py}"
# the real harness carries a shebang but no executable bit and is run through python3, unchanged; an INJECTED harness that is
# executable is run directly, so a fail-direction proof can substitute any program for it (the I9 DONE-WHEN injects a bash script).
run_harness() { if [ -x "$HARNESS" ]; then "$HARNESS" "$@"; else python3 "$HARNESS" "$@"; fi; }
RUNGS_SNO="$CORPUS/tests/snobol4/ALL.sno"
RUNGS_REF="$CORPUS/tests/snobol4/ALL.ref"
RUNGS_OUTSIDE="$CORPUS/tests/snobol4/ALL.outside.tsv"
# ⛔⭐ THE OUTSIDE LIST IS PASSED WHEN IT EXISTS, AND THAT WIRING IS THE WHOLE POINT OF THE FILE (hq_P 2026-09-08,
# ceo CEO-423/428). Under ONE ORACLE a program the oracle REFUSES TO RUN has no ground truth and is outside the
# baseline by definition; the harness drops each named entry from the graded denominator and PRINTS it with the
# oracle's own reason. ⛔ A declared outside list that no runner passes is INERT -- the exact shape the csnobol4
# package ALL.mask documents at length ("a mask file that silently does nothing is exactly the false-green shape
# this project keeps finding"). So the file and its wiring land together or neither lands. The harness itself
# REFUSES a list naming an entry that is not in the suite, so a stale row cannot quietly shrink the board.
_outside_arg=""
[ -f "$RUNGS_OUTSIDE" ] && _outside_arg="--outside $RUNGS_OUTSIDE"
# ⛔⭐ THE RUNGS' EXCLUDED.tsv (ceo CEO-1408; Lon 2026-10-02, in-chat to the ceo, verbatim: "Let's move the identifier which
# starts with a nul-character into the exclude column; we'll solve that later."): entries Lon takes OUT of the published
# denominator, the shape every SNOBOL4 package's EXCLUDED.tsv already has (CEO-1286). Its rows ride into the harness WITH the
# outside list (one --outside file, merged here), so they are not graded; the row then publishes pass / (shipped - EXCLUDED) and
# util_score_row.py --excluded fills the SUITE TABLE's Excl column. A row of it naming no entry REFUSES in the harness, as
# ALL.outside.tsv's do, so a stale exclusion cannot quietly shrink the board.
RUNGS_EXCLUDED="$CORPUS/tests/snobol4/EXCLUDED.tsv"
_sn4_excluded=0
if [ -f "$RUNGS_EXCLUDED" ]; then
    _sn4_excluded=$(grep -cvE '^[[:space:]]*(#|$)' "$RUNGS_EXCLUDED")
    if [ "$_sn4_excluded" -gt 0 ]; then
        _rungs_merged_outside="$WORKDIR/rungs_outside_merged.tsv"
        { [ -f "$RUNGS_OUTSIDE" ] && grep -vE '^[[:space:]]*(#|$)' "$RUNGS_OUTSIDE"; grep -vE '^[[:space:]]*(#|$)' "$RUNGS_EXCLUDED"; } > "$_rungs_merged_outside"
        _outside_arg="--outside $_rungs_merged_outside"
    fi
fi
RUNGS_ENTRY_FLOOR="${RUNGS_ENTRY_FLOOR:-1576}"   # FLOOR, not a pinned total (RULES.md): growth needs no re-pin; only an attributed retirement may lower it, in the commit that shrinks the rungs
if [ ! -f "$HARNESS" ]; then
    echo "⛔ GATE REFUSES: corpus_suite_harness.py missing at $HARNESS"; exit 2
fi
if [ ! -f "$RUNGS_SNO" ] || [ ! -f "$RUNGS_REF" ]; then
    echo "⛔ GATE REFUSES: the rungs suite is missing at $RUNGS_SNO"
    echo "   The per-family suite files were RETIRED INTO the rungs (Lon 2026-08-29 one-flat-suite ruling);"
    echo "   a checkout without it cannot grade the suite population at all. Pull corpus; do NOT read the"
    echo "   remaining loose blocks' smaller total as the board."
    exit 2
fi
# ⛔ THE HARNESS'S STDERR IS KEPT, NOT DISCARDED (hq_B 2026-09-01). This line read `2>/dev/null`, so when the rungs run
# produced no SUITE_BOARD line the refusal below could only say THAT it happened -- the cause (a refuse() message, a
# traceback, a linker error, a kill) was gone. Measured live: a board that refused after 7.7 minutes under fleet load
# 18-24 with nothing to read but "no SUITE_BOARD line", while the same harness run by hand with stderr kept was clean.
# ⭐⭐ AND THE EXIT STATUS IS KEPT TOO, WHICH IS THE HALF STDERR CANNOT COVER (seat03 2026-09-01, row
# master-suite-board-refuses-under-fleet-load-..., converged with hq_B's fix above on the same file the same day).
# MEASURED: a SIGTERM'd harness exits **143** and writes **ZERO bytes of stderr** -- Python's default disposition
# terminates without a traceback -- so for the kill case, which is the one this row exists for, keeping stderr alone
# prints an empty tail and still cannot name the cause. `board=$(run_harness ... | grep ...)` also threw the status
# away, because $? is grep's. Three parties read the same bare refusal three different ways on 2026-09-01 (hq_P "my
# binary", hq_C "something kills by name", seat03 "a 600s wrapper timed it out") and all three were guessing.
# ⛔ ALSO READ FROM SOURCE, because it decides which cure this row may take: the harness CANNOT kill "its own
# workers" -- it has none (no multiprocessing/concurrent.futures/threads) and imports no signal module, no os.kill,
# no alarm, no atexit. Its only kill is subprocess.run(timeout=) on a CHILD, which yields a HANG verdict and still
# boards. A missing board therefore means the harness PROCESS died: an external event.
_hout="$(mktemp)"; _herr="$(mktemp)"
# Every entry is graded in both modes: there is no modes column (Lon 2026-09-23, CEO-1218/1230).
if [ -n "$COMBINE" ]; then
    _combined=$(board_combine "$COMBINE") || { rm -f "$_hout" "$_herr"; exit 2; }; harness_rc=0
    board=$(printf '%s\n' "$_combined" | grep '^SUITE_BOARD ')
    echo "rungs: COMBINED from $COMBINE shard checkpoints under $CKPT (each stamped with this binary and rungs)"
else
    run_harness run "$RUNGS_SNO" "$RUNGS_REF" --modes m3,m4 $_outside_arg ${SHARD:+--shard "$SHARD"} > "$_hout" 2> "$_herr"; harness_rc=$?
    board=$(grep '^SUITE_BOARD ' "$_hout")
fi
if [ -z "$board" ]; then
    echo "⛔ GATE REFUSES: harness produced no SUITE_BOARD line for the rungs suite"
    # ⭐⭐ THE REFUSAL CARRIES ONE MACHINE-READABLE LINE, NOT ONLY PROSE (hq_C 2026-09-01, same row). The prose
    # below is for a human reading a log; a gate, a sweep or a DONE-WHEN that wants to know "was this refusal a
    # kill or a real red" must not have to parse English. ⛔ MEASURED, and the reason this line exists: the row's
    # own DONE-WHEN greps this file for `killed-by|cause=|signal=` and matched NOTHING, because the prose spells
    # it "CAUSE:" and "KILLED by SIG..." -- the cure was fully landed and correct and the gate still read as
    # not-done. A criterion written against an IMAGINED wording grades spelling, never behaviour (RULES.md
    # § TRANSCRIPTION IS WHERE PROVENANCE DIES). The contract is now: cause= is one of killed-by-signal |
    # harness-exited-nonzero | harness-printed-no-board; signal= is a SIGNAME or none; rc= is the raw status.
    if [ "$harness_rc" -gt 128 ]; then
        sig=$((harness_rc - 128)); signame="$(kill -l "$sig" 2>/dev/null || echo "$sig")"
        echo "   REFUSAL cause=killed-by-signal signal=SIG${signame} rc=${harness_rc}"
        echo "   CAUSE: the harness was KILLED by SIG${signame} (rc=$harness_rc). It did not fail -- it was killed."
        echo "   ⭐ THIS IS NOT YOUR TREE AND NOT A RED BOARD. RE-RUN IT. Do not diagnose the compiler from this."
        [ "$sig" -eq 15 ] && echo "   SIGTERM has a known external source on this box: a box-wide 'pkill -f corpus_suite_harness.py' kills"
        [ "$sig" -eq 15 ] && echo "   EVERY seat's board, not just the caller's (hq_P disclosure 2026-09-01 ~18:28 CDT, 19 processes killed)."
        [ "$sig" -eq 9 ]  && echo "   SIGKILL is usually the OOM killer or systemd-oomd: check 'journalctl --since -10min | grep -i oom'."
    elif [ "$harness_rc" -ne 0 ]; then
        echo "   REFUSAL cause=harness-exited-nonzero signal=none rc=${harness_rc}"
        echo "   CAUSE: the harness EXITED $harness_rc without boarding -- unlike a kill, this IS your tree or the harness."
    else
        echo "   REFUSAL cause=harness-printed-no-board signal=none rc=0"
        echo "   CAUSE: the harness exited 0 but printed no SUITE_BOARD line -- a defect in the harness itself."
    fi
    if [ -s "$_herr" ]; then
        echo "   harness stderr, last lines (the cause lives here, never in the line above):"
        grep -vE '^\s*$' "$_herr" | tail -8 | sed 's/^/     | /'
    else
        echo "   (harness stderr was EMPTY -- expected for a signal death, which writes nothing.)"
    fi
    rm -f "$_hout" "$_herr"; exit 2
fi
rm -f "$_hout" "$_herr"
if [ -n "$SHARD" ]; then board_checkpoint_write "$SHARD" "$board"; exit 0; fi
field() { echo "$board" | grep -oE "$1=[0-9]+" | cut -d= -f2; }
mt=$(field total)
m3p=$(field m3_pass); m3f=$(field m3_fail); m3c=$(field m3_crash); m3h=$(field m3_hang); m3u=$(field m3_unproven); m3x=$(field m3_xfail); m3xp=$(field m3_xpass)
m4p=$(field m4_pass); m4f=$(field m4_fail); m4c=$(field m4_crash); m4h=$(field m4_hang); m4u=$(field m4_unproven); m4s=$(field m4_skip); m4x=$(field m4_xfail); m4xp=$(field m4_xpass)
# ⛔⭐ THE XFAIL OUTCOME SPLIT (ceo CEO-432 item 2, on hq_U's census of these 26 markers): xfail says EXPECTED RED
# and says nothing about WHICH red, so a SIGSEGV, a hang, a silently wrong answer and a mode-4 that never produced
# a binary all read identically -- four different repairs behind one number. hq_U measured three entries here that
# CRASH in m3 and merely answer WRONG in m4, so the single count hides a PER-MODE split as well as a per-debt one,
# and a bimodal entry could not show without re-running the suite. Published, so it shows without one.
xfsplit() { # $1=mode prefix -> "wrong=A crash=B hang=C unproven=D skip=E", refusing rather than folding a zero
    local m="$1" k v out=""
    for k in wrong crash hang unproven skip; do
        v="$(field "${m}_xfail_${k}")"
        [ -n "$v" ] || { echo "⛔ GATE REFUSES: the SUITE_BOARD carries no ${m}_xfail_${k}= field -- the outcome split cannot be assembled and an absent bucket is not a zero (CEO-432 item 2)." >&2; exit 2; }
        out="${out}${out:+ }${k}=${v}"
    done
    printf '%s' "$out"
}
# ⛔ THE `|| exit 2` IS LOAD-BEARING: xfsplit runs inside a command substitution, so its own `exit 2`
# leaves only the SUBSHELL -- the refusal would print to stderr and the run would carry on with an
# empty split, publishing "xfail=25 ()" as though that were a reading. The assignment's status IS the
# substitution's status, so this is where the refusal actually crosses back out.
m3xs="$(xfsplit m3)" || exit 2
m4xs="$(xfsplit m4)" || exit 2
# ⛔⭐ THE SECOND POPULATION, GRADED HERE OR NOWHERE (hq_B 2026-09-05). The two boards are printed separately and
# NEVER summed by the harness, deliberately -- their denominators mean different things and one number spanning both
# could not be read. But "not summed" must not decay into "not read": grading only SUITE_BOARD would print a full,
# plausible, entirely green verdict with the ast entries graded by nobody. That is the same silently-narrowed
# population as a hard-coded root list or a truncated listing, and it is reached here by fixing the loud refusal.
# ⛔⭐ REFUSE RATHER THAN PUBLISH AN EMPTY xfail/xpass -- SAME CAUSE AS THE all_pass REFUSAL BELOW. `field` returns
# the EMPTY STRING for a field an older harness, or a shard checkpoint cut before that field existed, never emitted.
# "xpass=" in a published cell is not a zero: it is a reading that was never taken, wearing the shape of one that
# was, and it would read as "no stale markers" to every consumer of the row. A runner that cannot measure refuses.
for _f in m3_xfail:m3x m3_xpass:m3xp m4_xfail:m4x m4_xpass:m4xp; do
    _fld="${_f%%:*}"; _var="${_f##*:}"
    [ -n "${!_var}" ] || { echo "⛔ GATE REFUSES: the SUITE_BOARD carries no ${_fld}= field, so this row cannot publish the xpass count that makes movement inside its own known-red set visible (coo 2026-09-08). corpus_suite_harness.py beside this script emits it; a stale shard checkpoint does not (re-run the shards)."; exit 2; }
done
PASS3=$((PASS3+m3p)); FAIL3=$((FAIL3+m3f+m3c)); TMOUT3=$((TMOUT3+m3h+m3u))
PASS4=$((PASS4+m4p)); FAIL4=$((FAIL4+m4f+m4c)); TMOUT4=$((TMOUT4+m4h+m4u)); SKIP4=$((SKIP4+m4s))
XFAIL3=$((XFAIL3+${m3x:-0})); XFAIL4=$((XFAIL4+${m4x:-0}))
# ⛔⭐ THE RUNGS'S AND, FOLDED FROM THE HARNESS AND NEVER RE-DERIVED (ceo-372). m3p and m4p cannot produce it:
# the AND is a fact about each ENTRY, and by the time a board line exists the entries are gone. corpus_suite_harness.py
# emits all_pass for exactly this fold.
# ⛔ REFUSE RATHER THAN FOLD A ZERO. An older harness -- or a shard checkpoint cut before this field existed --
# prints no all_pass, `field` returns empty, and `$(( BOTH + ))` would quietly add nothing: the row would then
# publish the loop population alone and read as a catastrophic regression that never happened. A runner that
# cannot measure REFUSES; it does not print the success shape over a number it failed to read.
m_all=$(field all_pass)
[ -n "$m_all" ] || { echo "⛔ GATE REFUSES: the rungs SUITE_BOARD carries no all_pass= field -- this runner's row is the AND per program (ceo-372) and cannot be assembled without it. The harness beside this script emits it; a stale shard checkpoint does not (re-run the shards)."; exit 2; }
BOTH=$((BOTH+m_all))
[ "$((m3f+m3c))" -gt 0 ] && FAILURES3="${FAILURES3}  FAIL-M3 suite:rungs (rerun: python3 $HARNESS run $RUNGS_SNO $RUNGS_REF --modes m3; per-entry attributes: ALL.csv)\n"
[ "$((m4f+m4c))" -gt 0 ] && FAILURES4="${FAILURES4}  FAIL suite:rungs (rerun: python3 $HARNESS run $RUNGS_SNO $RUNGS_REF --modes m4; per-entry attributes: ALL.csv)\n"
echo "rungs: total=$mt · m3 xfail=$m3x ($m3xs) xpass=$m3xp · m4 xfail=$m4x ($m4xs) xpass=$m4xp"
[ "$((m3xp+m4xp))" -gt 0 ] && echo "⭐ XPASS>0: a bug got FIXED and its XFAIL marker was never promoted -- as actionable as a failure, in the opposite direction (names: python3 $HARNESS run ... | grep XPASS)"
# ⛔ THE FLOOR IS OVER THE WHOLE RUNGS: every entry is in the one run-graded population now.
_mt_all=$mt
if [ "$_mt_all" -lt "$RUNGS_ENTRY_FLOOR" ]; then
    MISSING=$((MISSING+RUNGS_ENTRY_FLOOR-_mt_all))
    MISSING_LIST="${MISSING_LIST}  rungs-entry-count: rungs total ${_mt_all} is under the floor ${RUNGS_ENTRY_FLOOR} -- entries vanished from the rungs, or this checkout is behind origin\n"
fi

# ── Beauty library drivers: RETIRED INTO THE RUNGS (one-flat-suite cutover 2026-08-29) ──
# The 13 *_driver.sno/.ref pairs and their .inc companions were absorbed into ALL.* (origins
# beauty_suite__*, see ALL.csv) and the loose pairs deleted; the rungs block above grades them.

# ── Demo programs ─────────────────────────────────────────────────────────────
# Coverage audit (demo-corpus-coverage-audit, 2026-08-22): wordcount's ref/input were
# missing (silent no-op, neither PASS nor FAIL) -- regenerated via x64/bin/sbl -bf.
run_test "demo_wordcount" "$DEMO/wordcount/wordcount.sno" "$DEMO/wordcount/wordcount.ref" "$DEMO/wordcount/wordcount.input" ""
run_test "demo_treebank"  "$DEMO/treebank/treebank.sno"  "$DEMO/treebank/treebank.ref"  "$DEMO/treebank/treebank.input"  ""
run_test "demo_claws5"    "$DEMO/claws5/claws5.sno"    "$DEMO/claws5/claws5.ref"    "$DEMO/claws5/claws5.input"    ""
TIMEOUT=30 \
run_test "demo_roman"     "$DEMO/roman/roman.sno"     "$DEMO/roman/roman.ref"     ""                      "^ms:"
# 15 rows below newly gated by the same audit -- each independently oracle-verified
# (x64/bin/sbl -bf) and scrip-verified before wiring in; see FINDING-2026-08-22-*-demo-corpus-coverage-audit.md
run_test "demo_arithmetic"          "$DEMO/arithmetic/arithmetic.sno"          "$DEMO/arithmetic/arithmetic.ref"          "" ""
run_test "demo_counter"             "$DEMO/counter/counter.sno"             "$DEMO/counter/counter.ref"             "" ""
run_test "demo_hello"               "$DEMO/hello/hello.sno"               "$DEMO/hello/hello.ref"               "" ""
run_test "demo_pattern_test"        "$DEMO/pattern_test/pattern_test.sno"        "$DEMO/pattern_test/pattern_test.ref"        "" ""
run_test "demo_claws5_match"        "$DEMO/claws5/claws5-match.sno"        "$DEMO/claws5/claws5-match.ref"        "$DEMO/claws5/claws5.input"     ""
run_test "demo_claws5_match_fence"  "$DEMO/claws5/claws5-match-fence.sno"  "$DEMO/claws5/claws5-match-fence.ref"  "$DEMO/claws5/claws5.input"     ""
run_test "demo_treebank_match"      "$DEMO/treebank/treebank-match.sno"      "$DEMO/treebank/treebank-match.ref"      "$DEMO/treebank/treebank.input"   ""
run_test "demo_treebank_match_fence" "$DEMO/treebank/treebank-match-fence.sno" "$DEMO/treebank/treebank-match-fence.ref" "$DEMO/treebank/treebank.input" ""
run_test "demo_treebank_alloc"      "$DEMO/treebank/treebank-alloc.sno"      "$DEMO/treebank/treebank-alloc.ref"      "$DEMO/treebank/treebank.input"   ""
run_test "demo_porter"              "$DEMO/porter/porter.sno"              "$DEMO/porter/porter.ref"              "$DEMO/porter/porter.input"     ""
# calculator-1/-2 (full evaluators) print a trailing nondeterministic "match_ms=" timing
# line -- same class as demo_roman's "^ms:" filter above, just a different literal marker.
# ⭐ THE CALCULATOR ROWS DECLARE THEIR STACK (ceo CEO-1261, measured 2026-09-25 by SCRIP_STACK bisection on this tree): SPITBOL's 4 MB default
# holds calculator-1-match-fence only; calculator-2-match-fence needs 8 MB and the other four 16 MB, because every deferred call in the
# whole-file match keeps its frame on the spine until the match ends (row snobol4-a-deferred-function-call-inside-a-pattern-keeps-its-
# frame-on-the-spine-until-the-match-ends). SPITBOL itself overflows five of the six at its own default (ERROR 246).
run_test "demo_calculator_1"        "$DEMO/calculator/calculator-1.sno"        "$DEMO/calculator/calculator-1.ref"        "$DEMO/calculator/calculator.input" "^match_ms=" "" 16384
run_test "demo_calculator_2"        "$DEMO/calculator/calculator-2.sno"        "$DEMO/calculator/calculator-2.ref"        "$DEMO/calculator/calculator.input" "^match_ms=" "" 16384
# OUTPUT() association to a '[-fn]' descriptor spec, routed by hq_P 2026-08-28: every write to the
# associated variable was silently discarded in BOTH modes (rc=0, ordinary output intact), because
# _OUTPUT_ never called the -fn parser that _INPUT_ had been calling all along. Graded on -f1 rather
# than -f2 because this harness compares stdout; the defect was never fd2-specific.
# feat_io_fd_assoc: retired hardcoded row (one-flat-suite cutover) -- absorbed into the rungs (origin feat_f21_io_fd_assoc... see ALL.csv), graded there; the loose pair is deleted.
# k41: the IMMEDIATE pattern lambda, the arm that is LANDED (row lang-lambda-pattern-primitives).
# ⛔ NOT k40. k40 is the row's INSTRUMENT, authored before the cure and RED ON PURPOSE until the
# whole feature lands (conditional lambda, backtrack-unqueue, stored-pattern round trip are all
# still unlanded) -- wiring THAT into the board would turn a deliberate measurement into a broken
# gate. A red instrument cannot also be a regression guard, so k41 guards what works and k40 keeps
# measuring the distance left. ⛔ SELF-PINNED, never sbl-graded: SPITBOL cannot even LEX the file --
# sbl -bf dies at the Greek line with ERROR 230 "illegal character" -- so no oracle arm exists.
# k41_lambda_immediate: retired hardcoded row (ceo s283h, probe total-conversion) -- the witness now lives in the conformance2 SUITE (tests/snobol4/probe/conformance2.sno, entry k41_lambda_immediate_landed) and is graded by the suite loop below; keeping the loose-path row too would double-grade it against a path that no longer exists.
# ⭐ hq_B, independently and after the fact: ceo's retirement above is CORRECT and the verification is
# recorded here so nobody re-derives it. corpus/probe was deleted wholesale by corpus c06960a1 (seat16, on
# Lon's order, closing corpus-crosscheck-probe-total-conversion), which left this hardcoded path dangling and
# the FLOOR REFUSING rc=2 for every seat until ceo landed the fix. ⛔ This script warns in its own words that
# retiring an entry PERMANENTLY SHRINKS THE BOARD and must not be the reflex for an unresolvable path -- the
# usual cause is a cross-repo window whose right action is `git pull` in corpus. VERIFIED that this was NOT
# that case: the witness survives as `k41_lambda_immediate_landed`, entry 2 of
# tests/snobol4/probe/conformance2.sno AND of its .ref, a boarded family the probe suite loop already grades.
# Coverage moved rather than vanished, so retiring is bookkeeping -- and a REPOINTED line would double-count.
# ⭐ Corpus paths have moved four times in three days. When a hardcoded path breaks the question is never
# "does the file exist" but "is the COVERAGE still graded somewhere": deleting on the first answer shrinks
# the board, deleting on the second is bookkeeping. Two seats reached the same retirement independently
# (ceo/hq_B above, seat15 concurrently below -- same diagnosis, same fix, converged without coordination).
run_test "demo_calculator_1_match"       "$DEMO/calculator/calculator-1-match.sno"       "$DEMO/calculator/calculator-1-match.ref"       "$DEMO/calculator/calculator.input" "" "" 16384
run_test "demo_calculator_1_match_fence" "$DEMO/calculator/calculator-1-match-fence.sno" "$DEMO/calculator/calculator-1-match-fence.ref" "$DEMO/calculator/calculator.input" ""
run_test "demo_calculator_2_match"       "$DEMO/calculator/calculator-2-match.sno"       "$DEMO/calculator/calculator-2-match.ref"       "$DEMO/calculator/calculator.input" "" "" 16384
run_test "demo_calculator_2_match_fence" "$DEMO/calculator/calculator-2-match-fence.sno" "$DEMO/calculator/calculator-2-match-fence.ref" "$DEMO/calculator/calculator.input" "" "" 8192
run_test "demo_json"                     "$DEMO/json/json.sno"                     "$DEMO/json/json.ref"                     "$DEMO/json/json.input"       "" 16384
run_test "demo_json_match"               "$DEMO/json/json-match.sno"               "$DEMO/json/json-match.ref"               "$DEMO/json/json.input"       "" 16384
run_test "demo_json_match_fence"         "$DEMO/json/json-match-fence.sno"         "$DEMO/json/json-match-fence.ref"         "$DEMO/json/json.input"       "" 16384
# ⭐ s266 -- THE THREE json PROGRAMS ARE UN-SKIPPED. They were excluded on a comment reading "HANGS (m3 AND m4)
# ... needs >30s (currently: forever)" and "wrong verdict on valid JSON". Both cures landed 2026-08-23: the hang
# was multi-choice pattern blobs having no drift-immune choice record and no blob re-entry (SCRIP d6eafac3), and
# the citm-scale stack leak was bare-FENCE0 static release (hq_P a42571b7). Measured at that HEAD, stderr kept
# SEPARATE from stdout: all three PASS in m3 AND m4 against their oracle refs. ⛔ THE SEPARATION IS LOad-BEARING
# and is why this looked broken twice: json/calculator write `match_ms=` to TERMINAL precisely so stdout stays
# byte-comparable, so any harness capturing with 2>&1 merges a timing line into the graded stream and reports a
# DIFF that is pure instrument. hq_C re-made that exact mistake while verifying this un-skip and caught it only
# by diffing against the LIVE oracle, which agreed with scrip byte-for-byte while the .ref appeared not to.
# ⭐ The denominator moves 361 -> 364. A skip is a silent subtraction from the denominator: these three were
# green for hours and no board could say so, because the runner had been told once that they hang forever.
# NOT gated -- each has a one-line reason, full repro in the FINDING above:
#   demo/snobol4/calculator/calculator-2.sno                -- diverges from the live oracle almost immediately (not the match_ms line); real bug, not nondeterminism (no RANDOM/RAND in program or generator)
#   demo/expression.sno                  -- -INCLUDEs 15 files (global.sno, ShiftReduce.sno, Gen.sno, ...) absent from this checkout; won't parse

T_ALL=$((SECONDS-T0_ALL))
# ⛔ THE DENOMINATOR INCLUDES THE XFAILS. Dropping them made the row read N/N -- the struck-down convention --
# mechanically, on every run. FAIL4 stays the count of UNEXPECTED reds so the gate's FAIL=0 bar keeps its meaning;
# a known red is not an unexpected one, but it is still not a pass and must not leave the denominator.
TOTAL=$((PASS4+FAIL4+SKIP4+XFAIL4))
echo "mode-3 (--run):     PASS=$PASS3 FAIL=$FAIL3"
echo "mode-4 (--compile): PASS=$PASS4 FAIL=$FAIL4 SKIP=$SKIP4  ($TOTAL total)"
# ⭐ THE HEADLINE, PRINTED WHERE THE HUMAN READS IT TOO -- not only into the leaderboard cell. The two-audiences
# defect this runner already carries a TIMEOUT caveat for: the board everyone quotes and the terminal must agree.
echo "both modes (the AND, what the leaderboard row states): PASS=$BOTH / $TOTAL"

[ -n "$FAILURES3" ] && printf "$FAILURES3" | head -20
[ -n "$FAILURES4" ] && printf "$FAILURES4" | head -40

printf "TIME M3=%ds M4=%ds TOTAL=%ds\n" "$T_M3" "$T_M4" "$T_ALL"
[ "$((TMOUT3+TMOUT4))" -gt 0 ] && printf "TIMEOUT-KILLED m3=%d m4=%d at %ss/program — NOT graded, NOT failures\n" "$TMOUT3" "$TMOUT4" "$TIMEOUT"
# ⛔⭐ STAMP THE TREE ON THE BOARD ITSELF (seat09's ask, 2026-08-29, from a live disagreement).
# seat09 and hq_B both ran THIS SCRIPT and got different denominators -- 1339 and 1377 -- each reproducible
# on demand in its own root. Neither number is stale and neither of us could settle it, because the output
# said what was measured but not WHAT TREE IT WAS MEASURED ON. A denominator is a fact about a corpus, and
# this board folds DEMO + BEAUTY + crosscheck families + misc from a SEPARATE REPO whose commit the SCRIP
# hash does not pin: two roots can sit at the same SCRIP commit and different corpus commits and disagree
# by 38 programs with nothing in either transcript to show it.
# ⭐ lib_gate.sh already stamps per-repo HEAD + dirty/clean + machine on every gate verdict, but THE BOARD
# THAT MATTERS MOST DID NOT SOURCE IT -- the instrument most often quoted in commit messages was the one
# with no provenance. Sourced tolerantly: if the lib is unreachable the board still runs, because a missing
# stamp must never cost a measurement.
if . "$HERE/lib_gate.sh" 2>/dev/null && command -v gate_stamp >/dev/null 2>&1; then gate_stamp
else echo "    (tree stamp unavailable — lib_gate.sh not sourced; record SCRIP and corpus HEAD by hand when quoting these numbers)"; fi

# ⛔⛔ THE VERDICT IS AN EXIT CODE, NOT A PRINTED NUMBER (hq_C s272). Until now this script's last statement was
# the printf above, so it exited 0 with any number of mode-4 failures -- the SAME false-green shape as `make test`,
# sitting inside the blocking set itself. CLAUDE.md has said "mode-4 is the hard gate" throughout; nothing enforced
# it. m3 stays informational per that documented contract, but it is printed in the verdict so it cannot hide.
# ⛔⭐ A TIMEOUT-KILLED PROGRAM WAS NOT MEASURED, SO IT SHRINKS THE DENOMINATOR EXACTLY LIKE A MISSING PATH.
# Reported and refused SEPARATELY from FAIL, because "answered wrong" and "we did not wait long enough" are
# different facts and this board printed one word for both. ⭐ The separation is load-bearing, not the raised
# bound: at ANY bound a contended box can cross it, so the instrument must be able to SAY it was contended
# rather than silently convert contention into a correctness regression.
# ⛔⭐⭐ THE BINARY CHECK RUNS HERE -- IMMEDIATELY AFTER GRADING, BEFORE EVERY CONSUMER AND EVERY OTHER REFUSAL.
# It was originally placed just above the PASS/FAIL verdict, which was two orders too late and BOTH mistakes
# were measured on this very script (hq_S 2026-09-06, by accident: a board ran while its own author rebuilt
# scrip four times for an unrelated branch):
#   (a) the leaderboard write happens BEFORE that point, so a drifted board could publish its row and only
#       then refuse -- the row is the thing everyone quotes, so the check has to precede it;
#   (b) the TIMEOUT-KILLED refusal below also exits first, so a board that BOTH drifted and hit the bound
#       reported only contention and told its reader to "re-run on a quieter box" -- a true sentence about
#       the wrong cause, which is worse than silence because it is confidently actionable in one direction.
# ⭐ The general form, and it is this house's own: the ORDER of two honest refusals is itself a claim about
# which one caused the other.
GATE_NAME=test_corpus_snobol4 gate_bin_unmoved
# ⛔ BEFORE THE FIRST PUBLISHED NUMBER, beside the binary check and for the same reason: an annotation that
# the tree moved is not a refusal -- util_score_row would happily write "graded; HEAD moved during the run"
# onto a number that describes no single tree.
GATE_NAME=test_corpus_snobol4 gate_tree_unmoved
if [ "$((TMOUT3+TMOUT4))" -gt 0 ]; then
    echo "⛔ GATE REFUSES: $((TMOUT3+TMOUT4)) program(s) KILLED at the ${TIMEOUT}s per-program bound (m3=$TMOUT3 m4=$TMOUT4) -- NOT graded:"
    printf "$TMOUT_LIST"
    echo "   These are NOT failures and NOT passes. The board is SMALLER than its PASS counts suggest."
    echo "   ⛔ Do NOT read this as a regression. Re-run on a quieter box, or raise the bound:"
    echo "      TIMEOUT=600 bash ../harness/scripts/test_corpus_snobol4.sh"
    echo "   ⭐ A program killed even on an idle box at a generous bound is a real hang and wants a row."
    exit 2
fi
if [ "$MISSING" -gt 0 ]; then
    echo "⛔ GATE REFUSES: $MISSING hardcoded corpus path(s) no longer resolve -- the board is SMALLER than it looks:"
    printf "$MISSING_LIST"
    # ⛔⭐⭐ WHY THIS BLOCK NOW DIAGNOSES BEFORE IT ADVISES (hq_P 2026-08-27 s276, after THREE seats in ONE DAY).
    # This refusal used to end with the flat instruction "Repoint them". ⛔ THAT NAMED THE WRONG REMEDY FOR THE
    # DOMINANT CAUSE, AND THE WRONG REMEDY IS THE IRREVERSIBLE ONE. A suite family lands as a CROSS-REPO change --
    # the corpus commit carrying <family>.{sno,ref} and the SCRIP commit adding it to the family list -- and there
    # is no atomic commit across two repos, so for a window any checkout that pulled one and not the other sees
    # paths that "do not resolve". The correct action there is `git pull` in corpus. REPOINTING OR RETIRING THE
    # ENTRY INSTEAD PERMANENTLY SHRINKS THE BOARD, and the gate was the thing telling seats to do it: seat12
    # proposed retiring two live families, seat11 proposed repointing seven, and a third report reached seat08
    # secondhand as a phantom regression -- all in one day, all steered by this message.
    # ⭐ THE FIX IS TO ASK THE QUESTION THE SEAT CANNOT: does the path exist at origin? If yes the checkout is
    # STALE; if no it is genuinely gone. Same file, same symptom, opposite cures -- so the gate must not guess.
    # ⛔ AND IT MUST DEGRADE TO "UNDETERMINED", NEVER TO THE DESTRUCTIVE ADVICE: with no origin, no network, or a
    # failed fetch we print both possibilities and recommend NOTHING. An instrument that cannot measure refuses.
    _stale=0; _gone=0; _undet=0
    if [ -d "$CORPUS/.git" ] && git -C "$CORPUS" rev-parse --verify -q origin/main >/dev/null 2>&1; then
        timeout -k 5 20s git -C "$CORPUS" fetch -q origin 2>/dev/null || true  # timeout-retry: exempt -- a git fetch, not a graded unit
        for _p in $(printf "$MISSING_LIST" | grep -oE "$CORPUS/[^ ]+" | sort -u); do
            _rel="${_p#$CORPUS/}"
            if git -C "$CORPUS" cat-file -e "origin/main:$_rel" 2>/dev/null; then _stale=$((_stale+1)); else _gone=$((_gone+1)); fi
        done
    else _undet=1; fi
    _behind="$(git -C "$CORPUS" rev-list --count HEAD..origin/main 2>/dev/null || echo '?')"
    if [ "$_stale" -gt 0 ]; then
        echo "   ⛔⭐ DIAGNOSIS: YOUR CORPUS CHECKOUT IS STALE -- $_stale of the unresolved path(s) EXIST at origin/main"
        echo "      (corpus is $_behind commit(s) behind origin). ⛔ DO NOT REPOINT AND DO NOT RETIRE THESE ENTRIES:"
        echo "      they are live files and the entries are correct. Repointing would shrink the board permanently."
        echo "      ✅ FIX:  git -C $CORPUS pull --ff-only     then re-run this gate."
        [ "$_gone" -gt 0 ] && echo "      ⚠ $_gone other path(s) are absent at origin too -- treat those separately, see below."
    fi
    if [ "$_gone" -gt 0 ] && [ "$_stale" -eq 0 ]; then
        echo "   DIAGNOSIS: $_gone path(s) are absent at origin/main too, so this is NOT a stale checkout."
        echo "      Repoint or retire those family entries; do NOT read the shrunken total as a pass."
    fi
    if [ "$_undet" -eq 1 ]; then
        echo "   ⚠ UNDETERMINED: no corpus origin/main to compare against, so this gate CANNOT tell a stale checkout"
        echo "      from a genuinely retired suite. ⛔ Recommending nothing -- establish which it is before changing anything."
    fi
    echo "   FAIL=0 over a shrunken denominator is not green."
    exit 2
fi
# ⛔⭐⭐ THE ONE LEADERBOARD, AND THIS IS THE HIGHEST-TRAFFIC BOARD WE HAVE -- it sits inside `make test`,
# so every seat runs it constantly, which makes its SCORE.md row both the most worth keeping live and the
# only one whose write could disturb twenty other roots. RULED by ceo CEO-174 (2026-09-03) on hq_T's ask:
# wire it, with this line naming itself out loud so the resulting .github change is never a haunting, AND
# write the row ONLY when the measured tree is clean and committed. That condition lives in the helper, is
# COMPUTED from the tree and cannot be chosen -- a dirty-tree number is a scouting datum, printed here and
# deliberately not landed, because it names a tree nobody else can check out. The clean run IS the landing
# run, so the row rides the landing's own .github-last push and no seat meets an unexplained dirty .github.
# ⛔ Placed ABOVE the FAIL exit: a red board is still a measurement, and a leaderboard that records only
# green runs is a trophy cabinet showing each suite's best remembered day rather than its state.
# ⛔⭐ A TIMEOUT-KILLED PROGRAM IS MISSING FROM THE DENOMINATOR AND THE ROW MUST SAY SO (hq_T ruling
# 2026-09-04, on hq_C's measurement: 4 programs KILLED at the 120s bound under load 3.6 with sixteen seats
# up). This board ALREADY tells the terminal reader -- "TIMEOUT-KILLED m3=N m4=N ... NOT graded, NOT
# failures" -- and told the LEADERBOARD nothing, so the published row read as a full-population measurement
# while N programs had never run. That is the two-audiences shape exactly: the human sees the caveat, the
# board that everyone quotes does not.
# ⭐ THE RULING, written down here because this is where it binds: THE BOUND DOES NOT SCALE WITH LOAD. A
# bound that moves with the machine makes a verdict irreproducible -- the same program passes or fails
# depending on its neighbours, and two roots could never reconcile a disagreement. And boards do NOT need a
# quiet boundary for CORRECTNESS, because a kill is already bucketed as NOT GRADED and NOT A FAILURE. What
# was actually wrong was a CONSUMER rendering that refusal as "FAIL m3=UNPARSEABLE" (rowed separately). The
# only thing owed here is that the row carry the caveat the terminal already carries.
_sn4_killed=""
[ "$((TMOUT3+TMOUT4))" -gt 0 ] && _sn4_killed=" · ⛔ TIMEOUT-KILLED m3=$TMOUT3 m4=$TMOUT4 at ${TIMEOUT}s/program — NOT graded and NOT failures, so this row is measured over a SHORT denominator: re-run at a quieter moment before quoting it as the population"
# ⛔ THE ROW CARRIES THE AST POPULATION TOO, for the reason the TIMEOUT-KILLED caveat above exists: the terminal
# reader sees both boards and the leaderboard everybody quotes would have seen only one, which is the two-audiences
# defect. Fraction form kept on both (util_score_row.py refuses a grid write without one).
# ⛔⭐ THE XPASS COUNT IS PUBLISHED BESIDE THE FRACTION, AND IT IS A BOARD FIX RATHER THAN A COSMETIC ONE (coo
# 2026-09-08, ruling on hq_T's ask): a headline that holds N constant while xfail and xpass trade underneath it is
# STRUCTURALLY BLIND TO MOVEMENT INSIDE ITS OWN KNOWN-RED SET. A seat can cure a real bug and this row cannot show
# it; a marker can go stale and this row cannot show that either. Both are invisible for the SAME reason and in
# OPPOSITE directions, which is why no amount of staring at the fraction distinguishes them.
# ⭐ AND IT CONVERTS AN AMBIGUITY FROM A RUN INTO A READ: "is this rung suite 1871/1898 with 27 live reds, or with some
# of them already cured behind stale markers?" was previously answerable only by re-running the suite. A nonzero
# xpass IS the stale-marker case, printed. Nobody has to reason about which of two indistinguishable shapes they
# are looking at, and nobody has to spend a board to find out.
# ⛔ EVERY FRACTION IN THIS CELL IS NOW OVER THE RUNGS'S OWN POPULATION. The cell is named sno-rungs and carried
# $BOTH/$TOTAL -- rungs PLUS the loop programs -- while the pair DECLARED beside it (--suite-pass/--suite-total)
# was the rungs' own $m_all/$mt. So the human reading the cell and the grid reading the declared pair took two
# different numbers out of one row: the two-readers-of-one-cell shape, in the row that ruling was written about.
# The wider figure is not dropped -- it is moved to the end and labelled as not being this row.
# ⛔⭐ THE ROW IS PASS OVER THE SHIPPED POPULATION WITH OUTSIDE NAMED (CEO-749; Lon 2026-09-16: OUTSIDE is debt; coo, row
# snobol4-master-runner-publishes-over-the-graded-population-1972-not-the-shipped-1980-with-outside-named). The harness prints
# shipped= and outside= beside total= (graded); this runner quotes all_pass/shipped and REFUSES rather than publish the graded
# population as the row's denominator -- 1961/1972 was seven outside passes leaving the numerator and eight entries leaving
# the denominator, read once as engine movement (COO-82). A denominator move needs its stamp: S4E_CRITERION_CHANGED is forwarded.
_sn4_shipped=$(field shipped); _sn4_outside=$(field outside); _sn4_extension=$(field extension)
[ -n "$_sn4_extension" ] || { echo "⛔ GATE REFUSES: the rungs SUITE_BOARD carries no extension= field -- an entry graded against a ref the SPITBOL oracle did not cut would publish unnamed (CEO-1416)" >&2; exit 2; }
[ -n "$_sn4_shipped" ] && [ -n "$_sn4_outside" ] || { echo "⛔ GATE REFUSES: the rungs SUITE_BOARD carries no shipped=/outside= fields -- the row would publish the graded population and drop OUTSIDE silently (CEO-749); the harness beside this runner must print them." >&2; exit 2; }
_sn4_outside=$((_sn4_outside - _sn4_excluded)); _sn4_shipped=$((_sn4_shipped - _sn4_excluded))
_sn4_board="rungs both-modes $m_all/$_sn4_shipped EXCLUDED=$_sn4_excluded OUTSIDE=$_sn4_outside EXTENSION=$_sn4_extension (graded $mt) · m3 $m3p/$mt FAIL=$((m3f+m3c)) xfail=$m3x ($m3xs) xpass=$m3xp · m4 $m4p/$mt FAIL=$((m4f+m4c)) SKIP=$m4s xfail=$m4x ($m4xs) xpass=$m4xp MISSING=0$_sn4_killed · runner-wide (rungs + loop programs, NOT this row) both-modes $BOTH/$TOTAL (\`test_corpus_snobol4.sh\`)"
# ⛔⭐ THE CELL IS NAMED sno-rungs AND MUST RECEIVE THE RUNGS'S OWN PAIR ($m_all/$mt), NOT THE RUNNER'S WIDER ONE.
# $BOTH/$TOTAL spans the rungs PLUS the loop programs, so publishing it put a rung suite+loop number in a rung suite cell --
# the second half of why this row kept re-flipping. The combined figure stays on the terminal, labelled, and the
# published pair is printed beside it so the board everyone quotes and the terminal cannot silently disagree.
echo "sno-rungs ROW PUBLISHED: $m_all/$_sn4_shipped EXCLUDED=$_sn4_excluded OUTSIDE=$_sn4_outside EXTENSION=$_sn4_extension (graded $mt)  (rungs only; m3 xfail=$m3x xpass=$m3xp · m4 xfail=$m4x xpass=$m4xp — xfails counted in the denominator, not the numerator; a nonzero XPASS is a stale marker and is as actionable as a failure, in the opposite direction)"
echo "runner-wide population (rungs + loop, NOT the published row): $BOTH/$TOTAL"
echo "ONE LEADERBOARD: recording this board into .github/SCORE.md (test_corpus_snobol4.sh; skipped with a notice if the tree is dirty)"
# ⛔⭐ THE SUITE ROW'S PAIR IS DECLARED, NEVER PARSED OUT OF THE LINE ABOVE (hq_T 2026-09-06, ceo CEO-363).
# This board line carries FOUR fractions -- the AND, m3, m4 and the ast fixtures -- over TWO different
# populations, so any rule that reads a pair out of it is choosing between them silently, and the ast pair
# (28/28) would publish as the rungs suite's score. The runner names its own headline pair instead.
# ⛔⭐ AND THE HEADLINE PAIR IS THE AND PER PROGRAM (ceo-372, 2026-09-06, RULING on this runner's ask):
# "a suite row states the programs that pass in EVERY graded mode -- a program red in m3 and another red in
# m4 both count against the row; never m3 alone, never m4 alone, never the min of two counts (which hides a
# program red in each)". This row published $PASS3 -- the m3 arm -- until now; it publishes $BOTH from here.
# ⛔ THAT MOVEMENT IS A CRITERION CHANGE, NOT A REGRESSION, and the commit that lands it says so. Nothing got
# worse; the row started counting what it always claimed to count. The cell keeps the per-mode counts beside
# the number so nobody loses the split, which is the other half of the same ruling.
python3 "$HERE/util_score_row.py" write --lang snobol4 --column board --modes m3,m4 \
    --measurer "${S4E_SEAT:-}" --text "$_sn4_board" --suite-pass "$m_all" --suite-total "$_sn4_shipped" --excluded "$_sn4_excluded" \
    ${S4E_CRITERION_CHANGED:+--criterion-changed "$S4E_CRITERION_CHANGED"} \
    || echo "⚠ SCORE.md NOT UPDATED -- record this row by hand (the REFUSED line above says why; a denominator move wants S4E_CRITERION_CHANGED='YYYY-MM-DD:reason' on this runner's call)"
# ⭐ THE PROGRESS LINE, after the rewrite (see board_icon_rungs.sh for the same call and why it is here
# rather than only in lib_gate.sh: this runner writes its row directly, bypassing gate_score_row).
# ⛔ THE PROGRESS LINE IS DELETED (Lon 2026-09-13, verbatim: "All bogus. Delete that. Do not show
# that ever again."). The call that stood here printed it; util_score_row.py progress is now a silent
# no-op and this call is removed so the intent is visible rather than inferred from an empty output.
if [ "$FAIL4" -gt 0 ]; then
    echo "⛔ GATE FAIL: mode-4 FAIL=$FAIL4 (mode-3 FAIL=$FAIL3, informational)"; exit 1
fi
echo "✅ GATE OK: both-modes PASS=$BOTH/$TOTAL · m3 PASS=$PASS3 FAIL=$FAIL3 · m4 PASS=$PASS4 FAIL=$FAIL4 SKIP=$SKIP4 · MISSING=0"
exit 0
