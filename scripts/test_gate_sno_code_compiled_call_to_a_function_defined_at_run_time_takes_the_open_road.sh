#!/usr/bin/env bash
# test_gate_sno_code_compiled_call_to_a_function_defined_at_run_time_takes_the_open_road.sh -- code compiled at run time by CODE() that calls a function DEFINEd at run time (a computed prototype, or a second DEFINE of the name) calls it.
#
# # ⛔ THE DEFECT (the cfo's reading to hq_snobol4, 2026-10-07 10:4x CDT, SCRIP f5512845c): P = 'CAT(A,B)'; DEFINE(P); body CAT = A '-' B :(RETURN); C = CODE('TW TW = CAT(X, X) :(RETURN)'); DEFINE('TW(X)'); OUTPUT = TW(7)
#   sbl prints 7-7; SCRIP, in mode 3 and in mode 4 (the fragment is compiled at run time in both), died with a BOMB in bb_call_proc_staged ("the CALL2BB slice-2 slim road (zref arm) retired ... the SCC probe held but no
#   tiny or signature arm took the call") and dumped core. The run-time DEFINE (rt_sno_runtime_define) marks the procedure `redefined`, which refuses bb_tiny_shim_ok, while bb_scc_probe -- asked at the call site of a fragment compiled
#   AFTER the DEFINE ran -- still held: the one combination the site's arms reach no road for. A main-program call to the same function was compiled before the DEFINE ran, saw no procedure, and took the open road.
#   THE CURE: bb_scc_probe refuses a redefined procedure (rt_proc_is_redefined), so a site that cannot name a stable entry takes the open road a main-program site takes. The class is every redefined procedure called from a fragment.
#
# THE ARMS (expectations cut from sbl -bf AT RUN TIME): each program in m3 and in m4
#   1-2  COMPUTED PROTOTYPE: the cfo's five-statement witness                                                      -- RED on base (BOMB)
#   3-4  COMPUTED PROTOTYPE, MAIN-PROGRAM CALL FIRST, then the fragment's                                          -- RED on base
#   5-6  A SECOND DEFINE of the name with another entry label, then the fragment's call                            -- RED on base
#   7-8  THREE FORMALS AND TWO LOCALS, computed prototype                                                          -- RED on base
#   9-10 CONTROL: a literal DEFINE, the fragment calls it (the road that always worked)
# EXIT: 0 all arms pass · 1 an arm failed · 2 REFUSED (no binary, no oracle, no tmpdir, the oracle's answer moved).
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
SCRIP="$ROOT/scrip"
RT_DIR="$ROOT/out"
NAME=sno_code_compiled_call_to_a_function_defined_at_run_time_takes_the_open_road
refuse() { echo "GATE REFUSE(2) [$NAME]: $*"; exit 2; }
[ -x "$SCRIP" ] || refuse "no scrip binary at $SCRIP -- cannot measure"
[ -f "$RT_DIR/libscrip_rt.so" ] || refuse "no $RT_DIR/libscrip_rt.so -- cannot measure mode 4"
. "$HERE/lib_oracle_flags.sh" 2>/dev/null || true
SBL="$(sbl_correctness_bin 2>/dev/null || true)"; [ -n "${SBL:-}" ] && [ -x "$SBL" ] || SBL=/home/resources/x64/bin/sbl
[ -x "$SBL" ] || refuse "no sbl oracle -- cannot measure (a missing oracle prints a full false table)"
T="$(mktemp -d)" || refuse "no tmpdir"
trap 'rm -rf "$T"' EXIT
cat > "$T/wit.sno" <<'EOS'
        P = 'CAT(A,B)'
        DEFINE(P)                               :(CATEND)
CAT     CAT = A '-' B                           :(RETURN)
CATEND
        C = CODE('TW TW = CAT(X, X) :(RETURN)')
        DEFINE('TW(X)')
        OUTPUT = TW(7)
END
EOS
cat > "$T/main.sno" <<'EOS'
        P = 'CAT(A,B)'
        DEFINE(P)                               :(CATEND)
CAT     CAT = A '-' B                           :(RETURN)
CATEND
        OUTPUT = CAT(7, 8)
        C = CODE('TW TW = CAT(X, X) :(RETURN)')
        DEFINE('TW(X)')
        OUTPUT = TW(7)
END
EOS
cat > "$T/redef.sno" <<'EOS'
        DEFINE('F(X)','F1')                     :(E1)
F1      F = 'one-' X                            :(RETURN)
F2      F = 'two-' X                            :(RETURN)
E1      OUTPUT = F(1)
        DEFINE('F(X)','F2')
        C = CODE('G1 G1 = F(X) :(RETURN)')
        DEFINE('G1(X)')
        OUTPUT = G1(5)
END
EOS
cat > "$T/locals.sno" <<'EOS'
        P = 'ADD3(A,B,C)L1,L2'
        DEFINE(P)                               :(E1)
ADD3    L1 = A + B ; L2 = L1 + C
        ADD3 = L2                               :(RETURN)
E1      C1 = CODE('H1 H1 = ADD3(X, 2, 3) :(RETURN)')
        DEFINE('H1(X)')
        OUTPUT = H1(10)
        OUTPUT = ADD3(1,2,3)
END
EOS
cat > "$T/lit.sno" <<'EOS'
        DEFINE('CAT(A,B)')                      :(CATEND)
CAT     CAT = A '-' B                           :(RETURN)
CATEND
        C = CODE('TW TW = CAT(X, X) :(RETURN)')
        DEFINE('TW(X)')
        OUTPUT = TW(7)
END
EOS
want() { timeout -k 5 30 "$SBL" -bf "$T/$1.sno" < /dev/null > "$T/$1.want" 2>/dev/null; [ -s "$T/$1.want" ] || refuse "sbl -bf produced no output for $1 -- the oracle's answer moved"; }
for p in wit main redef locals lit; do want $p; done
grep -qx '7-7' "$T/wit.want" || refuse "sbl -bf no longer answers the witness 7-7"
fail=0; pass=0
arm() { local n="$1" what="$2" ok="$3"
    if [ "$ok" = 1 ]; then pass=$((pass + 1)); echo "  arm $n PASS  $what"; else fail=$((fail + 1)); echo "  arm $n FAIL  $what"; fi; }
same_m3() { timeout -k 5 60 "$SCRIP" "$T/$1.sno" < /dev/null > "$T/$1.m3" 2>&1
    cmp -s "$T/$1.want" "$T/$1.m3" || { diff "$T/$1.want" "$T/$1.m3" | head -4 | cut -c1-160 | sed 's/^/      /'; return 1; }; }
same_m4() { timeout -k 5 120 "$SCRIP" --compile -o "$T/$1.s" "$T/$1.sno" < /dev/null > /dev/null 2>&1 \
        && gcc -no-pie "$T/$1.s" -L"$RT_DIR" -lscrip_rt -lm -Wl,-rpath,"$RT_DIR" -o "$T/$1.bin" 2>/dev/null || { echo "      COMPILE-FAILED"; return 1; }
    timeout -k 5 60 "$T/$1.bin" < /dev/null > "$T/$1.m4" 2>&1
    cmp -s "$T/$1.want" "$T/$1.m4" || { diff "$T/$1.want" "$T/$1.m4" | head -4 | cut -c1-160 | sed 's/^/      /'; return 1; }; }
n=0
for spec in "wit|COMPUTED PROTOTYPE, the cfo's witness" "main|COMPUTED PROTOTYPE, a main-program call first" "redef|a second DEFINE of the name with another entry label" "locals|three formals and two locals, computed prototype" "lit|CONTROL: a literal DEFINE"; do
    p="${spec%%|*}"; w="${spec#*|}"
    n=$((n + 1)); same_m3 "$p" && arm $n "m3 $w" 1 || arm $n "m3 $w" 0
    n=$((n + 1)); same_m4 "$p" && arm $n "m4 $w" 1 || arm $n "m4 $w" 0
done
if [ "$fail" -eq 0 ]; then echo "GATE PASS(0) [$NAME]: $pass arms -- CODE()-compiled code calls a function DEFINEd at run time, both modes"; exit 0; fi
echo "GATE FAIL(1) [$NAME]: $fail of $((pass + fail)) arms red"; exit 1
