#!/usr/bin/env bash
# test_gate_sno_a_setexit_trap_runs_for_an_error_raised_inside_a_match_evaluation.sh -- an error raised while a match evaluates a deferred expression or a capture target (SPAN(*$X) with X null,
# ANY(*$X), x = *$X then '8' ? x, a stored p = *$X matched) reaches the SETEXIT trap, as SPITBOL runs it, in both modes -- it is not a
# quiet match failure that only sets &ERRTYPE.
#
# THE DEFECT (row snobol4-an-error-raised-while-a-match-evaluates-a-deferred-expression-or-a-capture-target-is-a-match-failure-in-scrip-where-sbl-raises-it-239-21-46,
#   ceo CEO-1486, found by the infinite_snobol4 closed world): with &ERRLIMIT above zero the match path's error entry (kwb_error) counted the
#   limit down, published &ERRTYPE and returned without ever consulting the SETEXIT exit, so the trap sbl runs (and prints 'TRAP 239') never ran
#   and the match failed silently.
# THE CURE (src/runtime/keywords.c kwb_error): when a SETEXIT exit is armed the error goes through core_runtime_error, the one place the exit
#   is taken; core_setexit_armed() exposes the armed state. With no exit armed the &ERRLIMIT countdown is unchanged.
# THE ARMS (expectations cut from sbl -bf AT RUN TIME):
#   1-2  m3 / m4 TRAPPED: five match-evaluation errors under an armed SETEXIT -- the trap runs once per error and the run continues
#   3-4  CONTROL m3 / m4: the four SPAN/ANY/deferred/stored errors with NO exit armed -- &ERRLIMIT counts down, &ERRTYPE is set, the match fails, and a plain capture target (base already did this)
# EXIT: 0 all arms pass · 1 an arm failed · 2 REFUSED (no binary, no oracle, no tmpdir, the oracle's answer moved).
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
SCRIP="$ROOT/scrip"
RT_DIR="$ROOT/out"
NAME=sno_a_setexit_trap_runs_for_an_error_raised_inside_a_match_evaluation
refuse() { echo "GATE REFUSE(2) [$NAME]: $*"; exit 2; }
[ -x "$SCRIP" ] || refuse "no scrip binary at $SCRIP -- cannot measure"
[ -f "$RT_DIR/libscrip_rt.so" ] || refuse "no $RT_DIR/libscrip_rt.so -- cannot measure mode 4"
. "$HERE/lib_oracle_flags.sh" 2>/dev/null || true
SBL="$(sbl_correctness_bin 2>/dev/null || true)"; [ -n "${SBL:-}" ] && [ -x "$SBL" ] || SBL=/home/resources/x64/bin/sbl
[ -x "$SBL" ] || refuse "no sbl oracle -- cannot measure (a missing oracle prints a full false table)"
T="$(mktemp -d)" || refuse "no tmpdir"
trap 'rm -rf "$T"' EXIT
cat > "$T/st.sno" <<'EOF'
        &ERRLIMIT = 99
        SETEXIT(.trap)                                          :(go)
trap    OUTPUT = 'TRAP ' &ERRTYPE                               :(CONTINUE)
go      X =
        'abc' SPAN(*$X)                                         :F(a1)
        OUTPUT = 'span matched'
a1      SETEXIT(.trap)
        'abc' ANY(*$X)                                          :F(a2)
        OUTPUT = 'any matched'
a2      SETEXIT(.trap)
        x = *$X
        '8' ? x                                                 :F(a3)
        OUTPUT = 'deferred matched'
a3      SETEXIT(.trap)
        p = SPAN(*$X)
        'abc' ? p                                               :F(a4)
        OUTPUT = 'stored matched'
a4      SETEXIT(.trap)
        'abc' LEN(1) . *$X                                      :F(a5)
        OUTPUT = 'capture matched'
a5      OUTPUT = 'end ' &ERRTYPE
END
EOF
cat > "$T/ct.sno" <<'EOF'
        &ERRLIMIT = 99
        X =
        'abc' SPAN(*$X)                                         :F(a1)
        OUTPUT = 'span matched'
a1      OUTPUT = 'failed with ' &ERRTYPE
        'abc' ANY(*$X)                                          :F(a2)
        OUTPUT = 'any matched'
a2      OUTPUT = 'failed with ' &ERRTYPE
        x = *$X
        '8' ? x                                                 :F(a3)
        OUTPUT = 'deferred matched'
a3      OUTPUT = 'failed with ' &ERRTYPE
        p = SPAN(*$X)
        'abc' ? p                                               :F(a4)
        OUTPUT = 'stored matched'
a4      OUTPUT = 'failed with ' &ERRTYPE
        'abc' LEN(1) . Y                                      :F(a5)
        OUTPUT = 'capture matched'
a5      OUTPUT = 'end ' &ERRTYPE
END
EOF
want() { timeout -k 5 30 "$SBL" -bf "$T/$1.sno" < /dev/null > "$T/$1.want" 2>/dev/null; [ -s "$T/$1.want" ] || refuse "sbl -bf produced no output for $1 -- the oracle's answer moved"; }
want st; want ct
grep -q '^TRAP 239$' "$T/st.want" || refuse "sbl -bf no longer runs the SETEXIT trap for a match-evaluation error (first line: $(head -1 "$T/st.want"))"
fail=0; pass=0
arm() { local n="$1" what="$2" got="$3" w="$4"
    if cmp -s "$w" "$got"; then pass=$((pass + 1)); echo "  arm $n PASS  $what"
    else fail=$((fail + 1)); echo "  arm $n FAIL  $what"; diff "$w" "$got" | head -8 | sed 's/^/      /'; fi; }
m3() { timeout -k 5 30 "$SCRIP" "$T/$1.sno" < /dev/null > "$T/$1.m3" 2>/dev/null; }
m4() { : > "$T/$1.m4"
       if timeout -k 5 120 "$SCRIP" --compile -o "$T/$1.s" "$T/$1.sno" < /dev/null > /dev/null 2>&1 \
          && gcc -no-pie "$T/$1.s" -L"$RT_DIR" -lscrip_rt -lm -Wl,-rpath,"$RT_DIR" -o "$T/$1.bin" 2>/dev/null
       then timeout -k 5 30 "$T/$1.bin" < /dev/null > "$T/$1.m4" 2>/dev/null; else echo COMPILE-FAILED > "$T/$1.m4"; fi; }
m3 st; arm 1 "m3 TRAPPED: five match-evaluation errors run the SETEXIT trap as sbl -bf does" "$T/st.m3" "$T/st.want"
m4 st; arm 2 "m4: the same" "$T/st.m4" "$T/st.want"
m3 ct; arm 3 "CONTROL m3: no exit armed -- the errors count down &ERRLIMIT and fail the match" "$T/ct.m3" "$T/ct.want"
m4 ct; arm 4 "CONTROL m4: the same" "$T/ct.m4" "$T/ct.want"
if [ "$fail" -eq 0 ]; then echo "GATE PASS(0) [$NAME]: $pass arms -- a SETEXIT trap runs for an error raised inside a match evaluation, both modes"; exit 0; fi
echo "GATE FAIL(1) [$NAME]: $fail of $((pass + fail)) arms red"; exit 1
