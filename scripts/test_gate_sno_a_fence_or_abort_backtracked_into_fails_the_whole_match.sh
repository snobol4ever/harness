#!/usr/bin/env bash
# test_gate_sno_a_fence_or_abort_backtracked_into_fails_the_whole_match.sh -- backtracking into a bare FENCE, or reaching ABORT, fails
# the WHOLE pattern match -- no other alternative and no later start position is tried -- when the FENCE ends an alternation arm, and
# when the FENCE or ABORT sits in a pattern held in a variable (inlined, deferred *P, or a recursive thunk), in both modes, as SPITBOL
# answers it.
#
# ⛔ THE DEFECTS (two, one class; Flake kalah-opening-search error 239 and fullscan-palindrome, graded reds, both modes).
#   (A) INLINE: TT_SEQ lowered the FIRST bare FENCE of a sequence with its omega on the sequence's LOCAL failure (the first_f0 rule),
#       so a FENCE ending an alternation arm backtracked into the next arm: 'XAYAC' ('A' FENCE | 'Q') 'C' -> sbl fails, SCRIP matched
#       at cursor 3. A stored R = 'A' FENCE inlined as R 'C' or *R 'C' is the same shape.
#   (B) THUNK: a pattern that is not inlined (ABORT inside it, or recursion such as kalah's INITBRD_PAT = FENCE ... *INITBRD_PAT) is a
#       thunk whose seal was its OWN failure exit, so ABORT or a sealed FENCE failed only the thunk and the unanchored scan moved on:
#       P = ('B' | ABORT) / 'SNOBOL' P -> sbl fails, SCRIP matched; kalah called *INITBRD1(P) at a later cursor with P = '' and died
#       on $'' (error 239).
# THE CURE (SNOBOL4's own nodes): (A) a bare FENCE's own omega is the enclosing pat_seal; (B) every pattern-thunk builder seals to a
# SNOBOL4-only IR_MATCH_ABORT marker (literal payload 1) that sets r14d = -2 -- an impossible cursor -- and leaves by the thunk's
# failure; each IR_MATCH_DEFER carries its enclosing seal as an operand, resolved into the t1 target port, and at its omega return
# tests r14d == -2 and jumps there, so an abort chains outward through nested thunks to the statement.
# MONITOR BRACKET (kalah, 2026-09-25): step 527 stno 219 -- spl LABEL 209 after RETURN INITBRD1, scr resumes the scan and assigns P.
#
# THE ARMS (expectations cut from sbl -bf AT RUN TIME):
#   1-2  m3 / m4: the diverging shapes -- a FENCE ending an arm (inline, stored, deferred), a stored and a nested-thunk ABORT, a
#        recursive FENCE-led stored pattern calling a function at match time                                        -- RED on base
#   3    m3: Flake kalah-opening-search with its @input block                                                        -- RED on base
#   4    m3: Flake fullscan-palindrome with its @input block                                                         -- RED on base
#   5-6  CONTROL m3 / m4: shapes base already answers -- FENCE inside one sequence, FENCE(P), ARBNO with FENCE or ABORT, a
#        leading FENCE, a plain stored pattern that still retries at the next cursor
# EXIT: 0 all arms pass · 1 an arm failed · 2 REFUSED (no binary, no oracle, no Flake package, the oracle's answer moved).
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
SCRIP="$ROOT/scrip"
RT_DIR="$ROOT/out"
S4E="${S4E_HOME:-$(cd "$ROOT/.." && pwd)}"
PKG="$S4E/corpus/packages/snobol4/snoflake_suite"
NAME=sno_a_fence_or_abort_backtracked_into_fails_the_whole_match
refuse() { echo "GATE REFUSE(2) [$NAME]: $*"; exit 2; }
[ -x "$SCRIP" ] || refuse "no scrip binary at $SCRIP -- cannot measure"
[ -f "$RT_DIR/libscrip_rt.so" ] || refuse "no $RT_DIR/libscrip_rt.so -- cannot measure mode 4"
[ -f "$PKG/kalah-opening-search.sno" ] && [ -f "$PKG/fullscan-palindrome.sno" ] || refuse "no Flake kalah/palindrome under $PKG -- pull corpus"
. "$HERE/lib_oracle_flags.sh" 2>/dev/null || true
SBL="$(sbl_correctness_bin 2>/dev/null || true)"; [ -n "${SBL:-}" ] && [ -x "$SBL" ] || SBL=/home/resources/x64/bin/sbl
[ -x "$SBL" ] || refuse "no sbl oracle -- cannot measure (a missing oracle prints a full false table)"
T="$(mktemp -d)" || refuse "no tmpdir"
trap 'rm -rf "$T"' EXIT
for p in kalah-opening-search fullscan-palindrome; do cp "$PKG/$p.sno" "$T/"
    sed -n '/^\* @input >>>/,/^\* <<</p' "$PKG/$p.sno" | sed '1d;$d' | sed 's/^\* \{0,1\}//' > "$T/$p.in"; done
cat > "$T/fa.sno" <<'EOF'
        R = 'A' FENCE
        'XAB' (*R 'C' | 'B')                    :S(Y1)F(N1)
Y1      OUTPUT = 'deferred-trailing-fence: yes' :(T2)
N1      OUTPUT = 'deferred-trailing-fence: no'
T2      'XAB' (R 'C' | 'B')                     :S(Y2)F(N2)
Y2      OUTPUT = 'stored-trailing-fence: yes'   :(T3)
N2      OUTPUT = 'stored-trailing-fence: no'
T3      'XAYAC' ('A' FENCE | 'Q') 'C'           :S(Y3)F(N3)
Y3      OUTPUT = 'arm-ending-fence: yes'        :(T4)
N3      OUTPUT = 'arm-ending-fence: no'
T4      P = ('B' | ABORT)
        'SNOBOL' P                              :S(Y4)F(N4)
Y4      OUTPUT = 'stored-abort: yes'            :(T5)
N4      OUTPUT = 'stored-abort: no'
T5      INNER = ('X' | ABORT)
        OUTER = 'Q' | *INNER
        'SNOBOL' ('Z' | OUTER)                  :S(Y5)F(N5)
Y5      OUTPUT = 'nested-thunk-abort: yes'      :(T6)
N5      OUTPUT = 'nested-thunk-abort: no'
T6      DEFINE('F(X)')                          :(F_END)
F       OUTPUT = 'F sees [' X ']'
        F = ''                                  :(RETURN)
F_END   PAT = FENCE BREAK(' ') $ Q *F(Q) SPAN(' ') *PAT
        'AB CD EF ' PAT
        OUTPUT = 'end'
END
EOF
cat > "$T/ctl.sno" <<'EOF'
        'XAYAC' ('A' FENCE 'C')                 :S(Y1)F(N1)
Y1      OUTPUT = 'fence-in-sequence: yes'       :(T2)
N1      OUTPUT = 'fence-in-sequence: no'
T2      'XAB' (('A' FENCE) 'C' | 'B')           :S(Y2)F(N2)
Y2      OUTPUT = 'flattened-fence: yes'         :(T3)
N2      OUTPUT = 'flattened-fence: no'
T3      P = 'B'
        'SNOBOL' P                              :S(Y3)F(N3)
Y3      OUTPUT = 'plain-thunk-retry: yes'       :(T4)
N3      OUTPUT = 'plain-thunk-retry: no'
T4      'SNOBOL' ARBNO('S' | ABORT) 'X'         :S(Y4)F(N4)
Y4      OUTPUT = 'arbno-abort: yes'             :(T5)
N4      OUTPUT = 'arbno-abort: no'
T5      'AAB' ARBNO('A' FENCE) 'B'              :S(Y5)F(N5)
Y5      OUTPUT = 'arbno-fence: yes'             :(T6)
N5      OUTPUT = 'arbno-fence: no'
T6      'XAYAB' (FENCE('A') 'B')                :S(Y6)F(N6)
Y6      OUTPUT = 'fence-function-retry: yes'    :(T7)
N6      OUTPUT = 'fence-function-retry: no'
T7      PF = FENCE 'B'
        'BB' ('X' | *PF)                        :S(Y7)F(N7)
Y7      OUTPUT = 'leading-fence-deferred: yes'  :(T8)
N7      OUTPUT = 'leading-fence-deferred: no'
T8      'SNOBOL' ('B' | ABORT)                  :S(Y8)F(N8)
Y8      OUTPUT = 'inline-abort: yes'            :(END)
N8      OUTPUT = 'inline-abort: no'
END
EOF
for w in fa ctl; do ( cd "$T" && timeout -k 5 20 "$SBL" -bf "$w.sno" < /dev/null > "$w.oracle" 2>&1 ) || refuse "sbl did not run $w cleanly"; done
for p in kalah-opening-search fullscan-palindrome; do ( cd "$T" && timeout -k 5 20 "$SBL" -bf "$p.sno" < "$p.in" > "$p.oracle" 2>&1 ) || refuse "sbl did not run $p cleanly"; done
grep -qx 'arm-ending-fence: no' "$T/fa.oracle" && grep -qx 'stored-abort: no' "$T/fa.oracle" && grep -qx 'end' "$T/fa.oracle" || refuse "sbl's answer moved: [$(tr '\n' '|' < "$T/fa.oracle")]"
grep -q 'I pick pot' "$T/kalah-opening-search.oracle" || refuse "sbl's kalah answer moved"
fail=0; n=0
arm() { n=$((n+1)); if [ "$2" = ok ]; then echo "  ok   arm $n  $1"; else echo "  FAIL arm $n  $1 -- $2"; fail=1; fi; }
same() { [ "$1" = 0 ] || { echo "rc=$1"; return; }; cmp -s "$T/$2" "$T/$3" && echo ok || echo "got [$(tr '\n' '|' < "$T/$2" | head -c 110)] want [$(tr '\n' '|' < "$T/$3" | head -c 110)]"; }
m3() { ( cd "$T" && timeout -k 5 20 "$SCRIP" "$1.sno" < "${2:-/dev/null}" > "$1.m3" 2>&1; echo $? ); }
m4() { ( cd "$T" && timeout -k 5 30 "$SCRIP" --compile --out="$1.s" "$1.sno" < /dev/null > /dev/null 2>&1 && gcc "$1.s" -L"$RT_DIR" -lscrip_rt -Wl,-rpath,"$RT_DIR" -lm -o "$1.bin" > /dev/null 2>&1 && timeout -k 5 20 "./$1.bin" < /dev/null > "$1.m4" 2>&1; echo $? ); }
rc=$(m3 fa); arm "m3: a FENCE ending an arm, stored/deferred/nested-thunk FENCE and ABORT, a recursive FENCE-led pattern" "$(same "$rc" fa.m3 fa.oracle)"
rc=$(m4 fa); arm "m4: a FENCE ending an arm, stored/deferred/nested-thunk FENCE and ABORT, a recursive FENCE-led pattern" "$(same "$rc" fa.m4 fa.oracle)"
rc=$(m3 kalah-opening-search "$T/kalah-opening-search.in"); arm "m3: Flake kalah-opening-search" "$(same "$rc" kalah-opening-search.m3 kalah-opening-search.oracle)"
rc=$(m3 fullscan-palindrome "$T/fullscan-palindrome.in"); arm "m3: Flake fullscan-palindrome" "$(same "$rc" fullscan-palindrome.m3 fullscan-palindrome.oracle)"
rc=$(m3 ctl); arm "CONTROL m3: FENCE in a sequence, FENCE(P), ARBNO with FENCE/ABORT, leading FENCE, plain thunk retry" "$(same "$rc" ctl.m3 ctl.oracle)"
rc=$(m4 ctl); arm "CONTROL m4: FENCE in a sequence, FENCE(P), ARBNO with FENCE/ABORT, leading FENCE, plain thunk retry" "$(same "$rc" ctl.m4 ctl.oracle)"
[ "$fail" = 0 ] && { echo "PASS [$NAME]: $n arms"; exit 0; }
echo "FAIL [$NAME]"; exit 1
