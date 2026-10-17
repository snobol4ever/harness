#!/usr/bin/env bash
# stale-binary preflight (row test-gate-scripts-that-grade-scrip-refuse-on-a-stale-binary-census-widened, hq_T 2026-09-05)
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
# A match-with-REPLACEMENT whose subject needs a post-match store chain (an ARRAY ELEMENT, a TABLE element) leaves
# that chain's spine carve unreleased at the statement's gamma exit.  zd_exit_pop_s() released down to the MATCH
# watermark, which is the right answer only when nothing outlives the match region -- true for a plain-variable
# subject, whose one post-match slot IR_MATCH_REPLACE frees itself, and false the moment a store chain follows.
# TWO FACES, ONE DEFECT, and the gate grades both because either alone reads as a different bug:
#   (1) inside a DEFINE body the leaked spine is consumed by :(RETURN), which reads its port off a corrupted rsp
#       and jumps to a non-code address -- SIGSEGV in both modes, the four gimpel drivers hq_S rowed.
#   (2) at top level the same statement prints the RIGHT ANSWER and leaks per execution, so it is invisible to
#       every answer-grading arm we own and only a capacity arm can see it.
# The loop arm therefore pins its OWN ulimit -s in a subshell: an environment variable that decides the verdict is
# part of the criterion or the criterion is not one.
set -u
cd "$(dirname "$0")/../../SCRIP" || exit 1
SCRIP=./scrip
[ -x "$SCRIP" ] || { echo "GATE SN4-REPL-SPINE: REFUSE -- no ./scrip, run make"; exit 2; }
. ../harness/scripts/lib_oracle_flags.sh || { echo "GATE SN4-REPL-SPINE: REFUSE -- cannot source lib_oracle_flags.sh"; exit 2; }
SBL=$(sbl_correctness_bin) || { echo "GATE SN4-REPL-SPINE: REFUSE -- no correctness oracle"; exit 2; }
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
pass=0; fail=0; graded=0
cat > "$T/fn.sno" <<'EOF'
        DEFINE('F()')                       :(FEND)
F       A[1] 'A' = 'X'                      :(RETURN)
FEND
        A = ARRAY(3)
        A[1] = 'ABC'
        F()
        OUTPUT = A[1]
END
EOF
cat > "$T/fn2.sno" <<'EOF'
        DEFINE('F()')                       :(FEND)
F       OUTPUT = 'IN1 ' A[1]
        A[1] 'A' = 'X'
        OUTPUT = 'IN2 ' A[1]                :(RETURN)
FEND
        A = ARRAY(3)
        A[1] = 'ABC'
        F()
        OUTPUT = 'OUT ' A[1]
END
EOF
cat > "$T/top.sno" <<'EOF'
        A = ARRAY(3)
        A[1] = 'ABC'
        A[1] 'A' = 'X'
        OUTPUT = A[1]
END
EOF
cat > "$T/loop.sno" <<'EOF'
        A = ARRAY(3)
        I = 0
L       A[1] = 'ABC'
        A[1] 'A' = 'X'
        I = I + 1
        LT(I,200000) :S(L)
        OUTPUT = 'done ' A[1] ' ' I
END
EOF
cat > "$T/var.sno" <<'EOF'
        I = 0
L       S = 'ABC'
        S 'A' = 'X'
        I = I + 1
        LT(I,200000) :S(L)
        OUTPUT = 'var done ' S ' ' I
END
EOF
build_m4() {
  "$SCRIP" --compile "$1" > "$T/p.s" 2>"$T/c.err" || return 1
  as "$T/p.s" -o "$T/p.o" 2>>"$T/c.err" || return 1
  gcc -no-pie "$T/p.o" -Lout -lscrip_rt -lm -Wl,-rpath,"$PWD/out" -Wl,--allow-shlib-undefined -o "$2" 2>>"$T/c.err" || return 1
}
for prog in fn fn2 top loop var; do
  want=$( (ulimit -s 8192; timeout -k 5 120 "$SBL" -bf "$T/$prog.sno" < /dev/null 2>&1) )
  wrc=$?
  if [ "$wrc" -ne 0 ]; then echo "GATE SN4-REPL-SPINE: REFUSE -- oracle rc=$wrc on $prog, cannot cut a want"; exit 2; fi
  for mode in m3 m4; do
    if [ "$mode" = m3 ]; then
      got=$( (ulimit -s 8192; timeout -k 5 120 "$SCRIP" "$T/$prog.sno" < /dev/null 2>&1) ); rc=$?
    else
      build_m4 "$T/$prog.sno" "$T/$prog.bin" || { echo "  FAIL m4 $prog: build failed"; fail=$((fail+1)); graded=$((graded+1)); continue; }
      got=$( (ulimit -s 8192; timeout -k 5 120 "$T/$prog.bin" < /dev/null 2>&1) ); rc=$?
    fi
    graded=$((graded+1))
    if [ "$got" = "$want" ] && [ "$rc" -eq 0 ]; then
      pass=$((pass+1)); echo "  PASS $mode $prog (rc=0, byte-equal to sbl -bf)"
    else
      fail=$((fail+1))
      echo "  FAIL $mode $prog: rc=$rc"
      echo "       want [$(printf '%s' "$want" | tr '\n' '|')]"
      echo "       got  [$(printf '%s' "$got"  | tr '\n' '|')]"
      case $prog in
        fn|fn2) echo "       ^ the post-match store chain's spine survived the statement and :(RETURN) consumed it" ;;
        loop)   echo "       ^ CAPACITY arm: the answer may be right; a per-iteration spine leak exhausts 8 MB" ;;
        top|var) echo "       ^ CONTROL arm -- this shape was green BEFORE the cure, so a red here is a regression" ;;
      esac
    fi
  done
done
if [ "$graded" -eq 0 ]; then echo "GATE SN4-REPL-SPINE: REFUSE -- graded zero witnesses"; exit 2; fi
echo "GATE SN4-REPL-SPINE: $pass passed, $fail failed, $graded graded of 10 expected (5 witnesses x 2 modes)"
[ "$graded" -eq 10 ] || { echo "GATE SN4-REPL-SPINE: REFUSE -- denominator is $graded, expected 10"; exit 2; }
[ "$fail" -eq 0 ] || exit 1
