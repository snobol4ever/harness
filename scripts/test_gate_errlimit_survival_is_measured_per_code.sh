#!/usr/bin/env bash
# test_gate_errlimit_survival_is_measured_per_code.sh -- &ERRLIMIT SURVIVAL IS DECIDED PER ERROR CODE BY THE
# ORACLE, NOT BY MEMBERSHIP IN A LIST BUILT FOR A DIFFERENT QUESTION.  hq_U 2026-09-12, curing the coo's
# bisected rungs regression keyword_replace_branch_9 (SNOBOL4 rungs 1869/1894, FAIL=1 where the previous
# pass read FAIL=0).
#
# ⛔⭐ THE DEFECT THIS PINS, AND IT IS A CLASS, NOT A CODE.  70a0bc6c0 (hq_U) cured a real bug -- a goto to an
# undefined label was absorbed by &ERRLIMIT and the program ended silently where sbl stops -- by making the
# &ERRLIMIT arm consult core_err_is_terminal().  That list already existed and already held eleven codes, and
# it was built to answer "does this exit nonzero".  Reading it for "may this be absorbed" moved ELEVEN codes
# on one commit's evidence about ONE of them.  It was wrong for 022 the same day: sbl -bf absorbs an undefined
# function call under &ERRLIMIT and prints nothing, and we began printing ERROR 022 and exiting 1.
# ⭐ EIGHT OF THE ELEVEN ARE RAISED AT ZERO SITES IN THIS TREE, so the first consultation silently changed
# behaviour for codes for which no witness can even be minted -- the part that makes this worth a gate rather
# than a one-line revert.  A classification is safe to consult only for the question it was measured for.
#
# THE ARMS -- each witness run under `&ERRLIMIT = 10` against the ONE oracle (sbl -bf) and against SCRIP in
# BOTH modes, and SCRIP must agree with the oracle on WHETHER EXECUTION CONTINUED:
#   022 undefined function called   `X = NOSUCHFN(1) :F(NX)`   oracle ABSORBS, prints nothing, continues
#   038 goto undefined label        `:(NOSUCHLABEL)`           oracle REPORTS and stops
#   242 return from level zero      `:(RETURN)` at depth zero   oracle REPORTS and stops
# ⭐ 038 AND 242 ARE THE CONTROL ARMS AND THEY ARE NOT DECORATION: they are the two cures this gate must not
# let a future "just absorb everything" revert undo (038 is hq_U's 70a0bc6c0, 242 is hq_S's 99d4be3aa).  A
# gate holding only the 022 arm would go green on the exact regression that produced 70a0bc6c0.
#
# ⛔ THE INSTRUMENT IS THE ORACLE, RE-ASKED EVERY RUN, NEVER A PINNED STRING.  Each witness is run through sbl
# -bf in the same invocation and SCRIP is compared against THAT, so a cure moves both sides together and
# cannot invalidate the gate; and nothing here encodes "022 survives" as a fact this file believes -- it
# encodes "SCRIP answers whatever the oracle answers", which stays true if SPITBOL is ever measured again and
# disagrees with today's reading.
#
# REFUSES rc=2 (never a pass, never a fail) when it cannot measure: no oracle, stale binary, or a witness the
# oracle itself cannot run.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
cd "$ROOT"
. "$HERE/lib_gate.sh"
gate_parse_args "$@"
G=errlimit_survival_is_measured_per_code
"$HERE/util_require_fresh.sh" --gate "test_gate_$G" "$ROOT/scrip" "$ROOT/out/libscrip_rt.so" >/dev/null 2>&1 || { echo "GATE UNPROVEN(2) [$G]: this tree's binary is stale or unbuilt -- run make"; exit 2; }
. "$HERE/lib_oracle_flags.sh" 2>/dev/null || { echo "GATE UNPROVEN(2) [$G]: lib_oracle_flags.sh unloadable"; exit 2; }
SBL="$(sbl_correctness_bin)"; SBL_FLAGS="$(sbl_lang_flags)"
[ -x "$SBL" ] || { echo "GATE UNPROVEN(2) [$G]: sbl -bf oracle absent"; exit 2; }
W="$(mktemp -d "${TMPDIR:-/tmp}/gate_errl.XXXXXX")" || { echo "GATE UNPROVEN(2) [$G]: mktemp failed"; exit 2; }
trap 'rm -rf "$W"' EXIT
# THE WITNESSES.  Each prints the marker CONTINUED iff execution survived the raised error; if the engine
# stops instead, the marker never appears.  ⛔ "Did it continue" is the whole question, so the arms compare
# THAT and not the diagnostic text -- two engines that agree an error is terminal still word it differently,
# and comparing the wording would manufacture a disagreement out of an agreement.
cat > "$W/e022.sno" <<'SNO'
	&ERRLIMIT = 10
	X = NOSUCHFN(1)		:F(NX)
	OUTPUT = "NOFAIL"
NX	OUTPUT = "CONTINUED"
END
SNO
cat > "$W/e038.sno" <<'SNO'
	&ERRLIMIT = 10
	OUTPUT = "BEFORE"		:(NOSUCHLABEL)
NX	OUTPUT = "CONTINUED"
END
SNO
cat > "$W/e242.sno" <<'SNO'
	&ERRLIMIT = 10
	OUTPUT = "BEFORE"		:(RETURN)
NX	OUTPUT = "CONTINUED"
END
SNO
PASS=0; FAIL=0; EXAMINED=0
red() { FAIL=$((FAIL+1)); echo "  ⛔ $1"; }
ok()  { PASS=$((PASS+1)); echo "  ✅ $1"; }
continued() { grep -q '^CONTINUED$' "$1" && echo yes || echo no; }
for code in 022 038 242; do
    sno="$W/e$code.sno"
    ( cd "$W" && timeout -k 5 20 "$SBL" $SBL_FLAGS "$sno" < /dev/null > "$W/o.$code" 2>&1 ) 2>/dev/null; orc=$?
    [ "$orc" -ge 128 ] && { echo "GATE UNPROVEN(2) [$G]: the oracle died (sig $((orc-128))) on the $code witness -- nothing to compare against"; exit 2; }
    oc="$(continued "$W/o.$code")"
    # mode 3
    EXAMINED=$((EXAMINED+1))
    timeout -k 5 20 bash -c 'cd "$1" || exit 2; "$2" --run "$3" < /dev/null > "$4" 2>&1' _ "$W" "$ROOT/scrip" "$sno" "$W/m3.$code" 2>/dev/null
    s3="$(continued "$W/m3.$code")"
    if [ "$s3" = "$oc" ]; then ok "$code m3 continued=$s3, the oracle continued=$oc"
    else red "$code m3 continued=$s3 but the oracle continued=$oc -- &ERRLIMIT survival disagrees with sbl -bf"; fi
    # mode 4
    EXAMINED=$((EXAMINED+1))
    if timeout -k 5 60 "$ROOT/scrip" --compile "$sno" > "$W/p.s" 2>/dev/null \
       && gcc -c "$W/p.s" -o "$W/p.o" 2>/dev/null \
       && gcc "$W/p.o" -L"$ROOT/out" -lscrip_rt -lm -Wl,-rpath,"$ROOT/out" -o "$W/p.bin" 2>/dev/null; then
        timeout -k 5 20 bash -c 'cd "$1" || exit 2; "$2" < /dev/null > "$3" 2>&1' _ "$W" "$W/p.bin" "$W/m4.$code" 2>/dev/null
        s4="$(continued "$W/m4.$code")"
        if [ "$s4" = "$oc" ]; then ok "$code m4 continued=$s4, the oracle continued=$oc"
        else red "$code m4 continued=$s4 but the oracle continued=$oc -- &ERRLIMIT survival disagrees with sbl -bf"; fi
    else
        echo "GATE UNPROVEN(2) [$G]: mode 4 would not build the $code witness -- cannot measure, and a build failure is not a verdict"; exit 2
    fi
done
gate_floor "$EXAMINED" 6 "witness/mode arms (3 codes x 2 modes)"
echo "------------------------------------------------------------"
gate_verdict "$FAIL" "arm(s) where SCRIP's &ERRLIMIT survival disagrees with the live sbl -bf reading"
