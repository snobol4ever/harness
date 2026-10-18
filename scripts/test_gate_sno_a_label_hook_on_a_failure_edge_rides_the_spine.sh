#!/usr/bin/env bash
# test_gate_sno_a_label_hook_on_a_failure_edge_rides_the_spine.sh -- under the --stlimit switch (SCRIP_SNO_STMTKW=1) a
# statement whose FAILURE goto lands on a label runs that label's SNO$STMT hook, and inside a called function body the
# hook must not write anywhere but the spine. Both modes answer the oracle.
#
# ⛔ THE DEFECT (hq_snobol4 2026-09-25, row snobol4-the-graders-stlimit-switch-changes-three-package-answers-tictacto-
# treeread-hsort). sno_label_trace_wrap builds the hook as two source-less nodes (IR_LIT_STRING -> IR_CALL "SNO$STMT").
# The zd planner in emit.cpp claims a run only from a head -- a node carrying source text, or the failure target of a
# test-kind node -- and a hook on the SUCCESS edge is swept into the previous statement's gamma run, but a hook on the
# FAILURE edge is the omega target of IR_STATEMENT_BEGIN and neither kind of head. It stayed unclaimed and fell back to
# frame slots addressed [rsp + frame-offset], which is main's frame only while rsp IS main's frame base: in a SNOBOL4
# function body (dynamic scope, no frame of its own) those writes land in the caller's stack. MEASURED: TREEREAD's
# restored LEVEL/N/TREEREAD came back as the label strings READ_1/READ_2; TICTACTO, demo_porter and benchmark_porter
# jumped to 0x300000002 (a DESCR popped as a return address); aisnobol HSORT raised 235. THE CURE: bb_src_note on the
# hook head (and on the SNO$NOFAIL call, the other source-less failure-edge chain) so each begins its own run -- the
# lower_raku.c rk_*_cond idiom. The monitor bracket REFUSED this witness (the traced run arms trace and answers right).
#
# THE ARMS (expectations cut from sbl -bf AT RUN TIME):
#   1  W1 (G takes :F(G_1) then RETURNs; F calls G and recurses) m3 under the switch == oracle, rc 0
#   2  W1 m4 under the switch == oracle, rc 0
#   3  W2 (TREEREAD's shape: a caller's saved locals restored across a failure-edge label) m3 under the switch == oracle
#   4  W2 m4 under the switch == oracle
#   5  STRUCTURE: in W1's mode-4 asm under the switch, every box that loads a label name for the hook opens with a
#      spine push (sub rsp, N) -- none writes a frame slot off an unreserved rsp. RE-CUT 2026-10-14 (hq_snobol4, row
#      snobol4-blocking-gate-a-label-hook-on-a-failure-edge-refuses-hooks-moved-ceo-1697): since f947ec8e6 the hook is a
#      sealed IR_STMT_MARK box (asm comment "# sno_label_hook") that carves a pending-trace record and passes the label from
#      the .S<n> string pool (lea rdi, [rip + .Sn]); the old scan read an inline .string after a _lit_string_α label and
#      found 0. The scan now resolves each sno_label_hook box's .Sn to its label and reads the box's first instruction.
#   6  CONTROL: W1 and W2 in m3 WITHOUT the switch == oracle, so arms 1-4 grade the hook and not the witness
# EXIT: 0 all arms pass · 1 an arm failed · 2 REFUSED (no binary, no oracle, oracle shape moved).
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
SCRIP="$ROOT/scrip"
RT_DIR="$ROOT/out"
NAME=sno_a_label_hook_on_a_failure_edge_rides_the_spine
refuse() { echo "GATE REFUSE(2) [$NAME]: $*"; exit 2; }
[ -x "$SCRIP" ] || refuse "no scrip binary at $SCRIP -- cannot measure"
[ -f "$RT_DIR/libscrip_rt.so" ] || refuse "no $RT_DIR/libscrip_rt.so -- cannot measure mode 4"
. "$HERE/lib_oracle_flags.sh" 2>/dev/null || true
SBL="$(sbl_correctness_bin 2>/dev/null || true)"; [ -n "${SBL:-}" ] && [ -x "$SBL" ] || SBL=/home/resources/x64/bin/sbl
[ -x "$SBL" ] || refuse "no sbl oracle -- cannot measure (a missing oracle prints a full false table)"
T="$(mktemp -d)" || refuse "no tmpdir"
trap 'rm -rf "$T"' EXIT
cat > "$T/w1.sno" <<'EOF'
        DEFINE('G()')                           :(G_END)
G       IDENT(X, 'no')                          :F(G_1)
G_1                                             :(RETURN)
G_END
        DEFINE('F(L)')                          :(F_END)
F       EQ(L, 2)                                :S(RETURN)
        G()
        F(L + 1)                                :(RETURN)
F_END
        F(0)
        OUTPUT = 'done'
END
EOF
cat > "$T/w2.sno" <<'EOF'
        DEFINE('READ(P)')                       :(READ_END)
READ    LT(NF_INPUT, 0)                         :S(FRETURN)
        IDENT(INPUT_BUF, NULL)                  :F(READ_1)
        INPUT_BUF  =  INPUT                     :F(READ_2)
READ_1
        INPUT_BUF    P                          :F(FRETURN)
        READ  =  INPUT_BUF
        INPUT_BUF  =  NULL                      :(RETURN)
READ_2  NF_INPUT  =  NF_INPUT - 1               :(READ)
READ_END
        DEFINE('TREEREAD(LEVEL)SONS,N')
        TR_BC  =  ','
        LEVEL.TREEREAD  =  POS(0)  (SPAN(' ') | NULL)  *LEVEL SPAN(' ')  REM . TREEREAD  :(TREEREAD_END)
TREEREAD        READ(LEVEL.TREEREAD)            :F(FRETURN)
        TREEREAD  =  TRIM(TREEREAD)  TR_BC
TREEREAD_1      SONS  =  SONS  TREEREAD(LEVEL + 1)      :F(TREEREAD_2)
        N  =  N + 1                             :(TREEREAD_1)
TREEREAD_2      TREEREAD  =  TREEREAD  N  TR_BC  SONS   :(RETURN)
TREEREAD_END
        NF_INPUT  =  99
        OUTPUT  =  TREEREAD(0)                  :S(END)
        OUTPUT  =  'FAILED'
END
EOF
printf '0 root\n 1 alpha\n 1 beta\n  2 beta1\n 1 gamma\n' > "$T/w2.in"
: > "$T/w1.in"
for w in w1 w2; do ( cd "$T" && timeout -k 5 10 "$SBL" -bf "$w.sno" < "$w.in" > "$w.oracle" 2>/dev/null ) || refuse "the oracle did not run $w cleanly"; done
[ "$(cat "$T/w1.oracle")" = done ] || refuse "the oracle's W1 answer moved: [$(head -c 80 "$T/w1.oracle")]"
[ "$(cat "$T/w2.oracle")" = "root,3,alpha,,beta,1,beta1,,gamma,," ] || refuse "the oracle's W2 answer moved: [$(head -c 80 "$T/w2.oracle")]"
fail=0; n=0
arm() { n=$((n+1)); if [ "$2" = ok ]; then echo "  ok   arm $n  $1"; else echo "  FAIL arm $n  $1 -- $2"; fail=1; fi; }
run3() { ( cd "$T" && SCRIP_SNO_STMTKW="$2" timeout -k 5 10 "$SCRIP" "$1.sno" < "$1.in" > "$1.m3.$2" 2>/dev/null ); echo $?; }
run4() { ( cd "$T" && SCRIP_SNO_STMTKW="$2" timeout -k 5 20 "$SCRIP" --compile -o "$1.$2.s" "$1.sno" < /dev/null > /dev/null 2>&1 ) || { echo cc; return; }
         gcc "$T/$1.$2.s" -L"$RT_DIR" -lscrip_rt -Wl,-rpath,"$RT_DIR" -lm -o "$T/$1.$2.bin" > /dev/null 2>&1 || { echo link; return; }
         ( cd "$T" && timeout -k 5 10 "./$1.$2.bin" < "$1.in" > "$1.m4.$2" 2>/dev/null ); echo $?; }
verdict() { [ "$1" = 0 ] || { echo "rc=$1"; return; }; cmp -s "$T/$2" "$T/$3" && echo ok || echo "stdout differs from the oracle: [$(head -c 60 "$T/$2" | tr '\n' '|')]"; }
rc=$(run3 w1 1); arm "W1 m3 under the switch answers the oracle" "$(verdict "$rc" w1.m3.1 w1.oracle)"
rc=$(run4 w1 1); arm "W1 m4 under the switch answers the oracle" "$(verdict "$rc" w1.m4.1 w1.oracle)"
rc=$(run3 w2 1); arm "W2 m3 under the switch restores the caller's locals" "$(verdict "$rc" w2.m3.1 w2.oracle)"
rc=$(run4 w2 1); arm "W2 m4 under the switch restores the caller's locals" "$(verdict "$rc" w2.m4.1 w2.oracle)"
if [ -f "$T/w1.1.s" ]; then
    scan=$(awk 'FNR == NR { if ($1 ~ /^\.S[0-9]+:$/) { s = $NF; gsub(/"/, "", s); k = $1; sub(/:$/, "", k); pool[k] = s }; next }
                /^# sno_label_hook/ { inb = 1; lab = ""; first = ""; next }
                inb && first == "" && $1 ~ /_α:$/ { lab = $1; first = $2 " " $3 }
                inb && /lea +rdi, \[rip \+ \.S[0-9]+\]/ { m = $0; sub(/.*\[rip \+ /, "", m); sub(/\].*/, "", m); if (pool[m] ~ /^(G|G_1|G_END|F|F_END)$/) print (first ~ /^sub rsp,/ ? "spine" : "FRAME") " " lab; inb = 0 }' "$T/w1.1.s" "$T/w1.1.s")
    hooks=$(printf '%s\n' "$scan" | grep -c .); bad=$(printf '%s\n' "$scan" | awk '$1 == "FRAME" { print $2 }')
    [ "$hooks" -ge 3 ] || refuse "W1's mode-4 asm under the switch carries $hooks label-hook statement-mark boxes -- the hooks moved and this arm cannot see them"
    arm "every one of W1's $hooks label-hook statement-mark boxes opens with a spine push" "$([ -z "$bad" ] && echo ok || echo "frame-slot store off an unreserved rsp at: $(echo $bad | tr '\n' ' ')")"
else arm "every label-hook statement-mark box opens with a spine push" "no mode-4 asm for W1 under the switch"; fi
rc1=$(run3 w1 0); rc2=$(run3 w2 0); v1=$(verdict "$rc1" w1.m3.0 w1.oracle); v2=$(verdict "$rc2" w2.m3.0 w2.oracle)
arm "CONTROL: W1 and W2 in m3 without the switch answer the oracle" "$([ "$v1" = ok ] && [ "$v2" = ok ] && echo ok || echo "W1: $v1 / W2: $v2")"
[ "$fail" = 0 ] && { echo "PASS [$NAME]: $n arms"; exit 0; }
echo "FAIL [$NAME]"; exit 1
