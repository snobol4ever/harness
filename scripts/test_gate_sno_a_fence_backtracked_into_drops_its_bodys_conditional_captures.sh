#!/usr/bin/env bash
# test_gate_sno_a_fence_backtracked_into_drops_its_bodys_conditional_captures.sh -- when the match backtracks into FENCE(P), every
# conditional assignment (. NAME, . *F()) that P recorded is discarded, as SPITBOL does, in both modes: only the attempt that reaches
# the end of the match assigns.
#
# ⛔ THE DEFECT (row snobol4-the-indirect-counter-increment-at-bootstrap-counter-sc-16-raises-error-41-..., CEO-1295; and the cto's
# row snobol4-a-fence-inside-an-alternation-changes-its-never-matched-siblings-..., the json members). IR_MATCH_FENCE1's beta
# jumped straight to omega without running its body's beta, so the 24-byte conditional-capture records the body pushed on r12
# (bb_match_capture phase 1: alpha add r12,24 / beta sub r12,24) survived and ran at match end:
#   'ab' ? 'a' ARBNO('b') FENCE('' . *mark('R')) RPOS(0)   -> sbl logs R, SCRIP logged RR (RRR on 'abb').
# The Snocone parser's Expr17, nPush nInc *Expr0 ARBNO(',' nInc *Expr0) FENCE(reduce VLIST | epsilon) nPop ')', ran the abandoned
# attempt's reduce and nPop too; the counter stack underflowed and IncCounter raised error 41 on library/counter.sc.
# MONITOR BRACKET: parser_snocone.sno on counter.sc, --oracle, reads its first divergence at step 2182 (VALUE @S STRING against
# ARRAY) -- a value-report artifact; the parser's own xTrace = 5 log is the bracket that names it: after Push(TT_ALT) PopCounter()
# sbl runs 2 = IncCounter() for the second list member, SCRIP ran 1 = TopCounter() Reduce(TT_VLIST, 1) first.
# THE CURE: FENCE1 saves r12 at alpha in its own zls pad (FRQ(off+8); FFCQ(8) in the frame-slot regime) and restores it at beta.
#
# THE ARMS (expectations cut from sbl -bf AT RUN TIME):
#   1-2  m3 / m4: FENCE(P) holding a conditional capture, backtracked into after ARBNO; FENCE in FENCE; FENCE of a deferred
#        pattern; a capture before the FENCE kept                                                              -- RED on base
#   3    m3: parser_snocone.sno (the transpiled bootstrap chain) parsing corpus library/counter.sc, byte-equal to sbl  -- RED on base
#   4-5  CONTROL m3 / m4: forms base already answers -- captures through a FENCE that is never backtracked into, the same capture
#        without the FENCE, deferred/stored/EVAL fences, a bare FENCE and an ABORT arm (both fail the whole match), two arms
# EXIT: 0 all arms pass · 1 an arm failed · 2 REFUSED (no binary, no oracle, no corpus, the chain did not build, the oracle moved).
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
SCRIP="$ROOT/scrip"
RT_DIR="$ROOT/out"
S4E="${S4E_HOME:-$(cd "$ROOT/.." && pwd)}"
SRC="$S4E/corpus/library/counter.sc"
NAME=sno_a_fence_backtracked_into_drops_its_bodys_conditional_captures
refuse() { echo "GATE REFUSE(2) [$NAME]: $*"; exit 2; }
[ -x "$SCRIP" ] || refuse "no scrip binary at $SCRIP -- cannot measure"
[ -f "$RT_DIR/libscrip_rt.so" ] || refuse "no $RT_DIR/libscrip_rt.so -- cannot measure mode 4"
[ -f "$SRC" ] || refuse "no $SRC -- pull corpus"
. "$HERE/lib_oracle_flags.sh" 2>/dev/null || true
SBL="$(sbl_correctness_bin 2>/dev/null || true)"; [ -n "${SBL:-}" ] && [ -x "$SBL" ] || SBL=/home/resources/x64/bin/sbl
[ -x "$SBL" ] || refuse "no sbl oracle -- cannot measure (a missing oracle prints a full false table)"
T="$(mktemp -d)" || refuse "no tmpdir"
trap 'rm -rf "$T"' EXIT
cat > "$T/fb.sno" <<'EOF'
          DEFINE('mark(tag)')                                 :(mark_end)
mark      log = log tag
          mark = .dummy                                       :(NRETURN)
mark_end  p1 = '' . *mark('R')
          log = ''
          'ab' ? 'a' ARBNO('b') FENCE('' . *mark('R') | '') RPOS(0)
          OUTPUT = 'fence alt [' log ']'
          log = ''
          'abb' ? 'a' ARBNO('b') FENCE('' . *mark('R')) RPOS(0)
          OUTPUT = 'fence one [' log ']'
          log = ''
          'ab' ? '' . *mark('P') 'a' ARBNO('b') FENCE('' . *mark('R')) RPOS(0)
          OUTPUT = 'before fence [' log ']'
          log = ''
          'abb' ? 'a' ARBNO('b') FENCE(FENCE('' . *mark('N'))) RPOS(0)
          OUTPUT = 'nested fence [' log ']'
          log = ''
          'abb' ? 'a' ARBNO('b') FENCE('' . *mark('R') FENCE('' . *mark('Q'))) RPOS(0)
          OUTPUT = 'fence in fence [' log ']'
          log = ''
          'abb' ? 'a' ARBNO('b') FENCE(*p1) RPOS(0)
          OUTPUT = 'fence of deferred [' log ']'
          log = ''
          '(a,b)' ? '(' ANY('ab') ARBNO(',' '' . *mark('I') ANY('ab')) FENCE('' . *mark('V')) ')'
          OUTPUT = 'list [' log ']'
END
EOF
cat > "$T/ctl.sno" <<'EOF'
          DEFINE('mark(tag)')                                 :(mark_end)
mark      log = log tag
          mark = .dummy                                       :(NRETURN)
mark_end  p1 = '' . *mark('R')
          p2 = FENCE('' . *mark('R'))
          log = ''
          'abc' ? 'a' . *mark('A') FENCE('b' . *mark('B')) 'c' . *mark('C')
          OUTPUT = 'kept through [' log ']'
          log = ''
          'ab' ? 'a' ARBNO('b') ('' . *mark('R') | '') RPOS(0)
          OUTPUT = 'plain alt [' log ']'
          log = ''
          'abb' ? 'a' ARBNO('b') *p1 RPOS(0)
          OUTPUT = 'deferred plain [' log ']'
          log = ''
          'abb' ? 'a' ARBNO('b') *p2 RPOS(0)
          OUTPUT = 'deferred fence [' log ']'
          log = ''
          'abb' ? 'a' ARBNO('b') p2 RPOS(0)
          OUTPUT = 'stored fence [' log ']'
          log = ''
          'abb' ? 'a' ARBNO('b') EVAL("FENCE('' . *mark('R'))") RPOS(0)
          OUTPUT = 'eval fence [' log ']'
          log = ''
          'abb' ? 'a' ARBNO('b') ('' . *mark('R') FENCE) RPOS(0)
          OUTPUT = 'bare fence after [' log ']'
          log = ''
          'abb' ? 'a' ARBNO('b') ('' . *mark('R') | ABORT) RPOS(0)
          OUTPUT = 'abort arm [' log ']'
          log = ''
          'abb' ? 'a' ARBNO('b') ('' . *mark('R') | '' . *mark('S')) RPOS(0)
          OUTPUT = 'two arms [' log ']'
          last = ''
          'abc' ? ARBNO(LEN(1)) . head FENCE(LEN(1) . last) RPOS(0)
          OUTPUT = 'head [' head '] last [' last ']'
END
EOF
for w in fb ctl; do ( cd "$T" && timeout -k 5 20 "$SBL" -bf "$w.sno" < /dev/null > "$w.oracle" 2>&1 ) || refuse "sbl did not run $w cleanly"; done
grep -qx 'fence one \[R\]' "$T/fb.oracle" && grep -qx 'fence in fence \[RQ\]' "$T/fb.oracle" && grep -qx 'kept through \[ABC\]' "$T/ctl.oracle" || refuse "sbl's answer moved: [$(tr '\n' '|' < "$T/fb.oracle")]"
S4E_HOME="$S4E" SCRIP="$SCRIP" timeout -k 5 300 python3 "$HERE/test_bootstrap_parsers.py" snocone --arm m3 --only library/counter.sc --no-rungs --timeout 120 --work "$T/bp" > "$T/bp.log" 2>&1
PSNO="$T/bp/snocone/parser_snocone.sno"
[ -s "$PSNO" ] || refuse "the snocone chain did not transpile: $(tail -2 "$T/bp.log" | tr '\n' ' ')"
( cd "$T" && timeout -k 5 120 "$SBL" -bf -s2000m -d4000m "$PSNO" < "$SRC" > counter.oracle 2>&1 ) || refuse "sbl did not run the snocone parser on counter.sc"
grep -q 'Parse Error\|ERROR' "$T/counter.oracle" && refuse "sbl no longer parses counter.sc cleanly"
fail=0; n=0
arm() { n=$((n+1)); if [ "$2" = ok ]; then echo "  ok   arm $n  $1"; else echo "  FAIL arm $n  $1 -- $2"; fail=1; fi; }
same() { [ "$1" = 0 ] || { echo "rc=$1"; return; }; cmp -s "$T/$2" "$T/$3" && echo ok || echo "got [$(tr '\n' '|' < "$T/$2" | head -c 110)] want [$(tr '\n' '|' < "$T/$3" | head -c 110)]"; }
m3() { ( cd "$T" && timeout -k 5 20 "$SCRIP" "$1.sno" < /dev/null > "$1.m3" 2>&1; echo $? ); }
m4() { ( cd "$T" && timeout -k 5 30 "$SCRIP" --compile -o "$1.s" "$1.sno" < /dev/null > /dev/null 2>&1 && gcc "$1.s" -L"$RT_DIR" -lscrip_rt -Wl,-rpath,"$RT_DIR" -lm -o "$1.bin" > /dev/null 2>&1 && timeout -k 5 20 "./$1.bin" < /dev/null > "$1.m4" 2>&1; echo $? ); }
rc=$(m3 fb); arm "m3: FENCE(P) backtracked into after ARBNO, FENCE in FENCE, FENCE of a deferred pattern" "$(same "$rc" fb.m3 fb.oracle)"
rc=$(m4 fb); arm "m4: FENCE(P) backtracked into after ARBNO, FENCE in FENCE, FENCE of a deferred pattern" "$(same "$rc" fb.m4 fb.oracle)"
rc=$( ( cd "$T" && timeout -k 5 120 "$SCRIP" -s4096m -d16384m "$PSNO" < "$SRC" > counter.m3 2>&1; echo $? ) ); arm "m3: parser_snocone.sno parses library/counter.sc as sbl does" "$(same "$rc" counter.m3 counter.oracle)"
rc=$(m3 ctl); arm "CONTROL m3: unbacktracked FENCE, plain/deferred/stored/EVAL forms, bare FENCE, ABORT arm, two arms" "$(same "$rc" ctl.m3 ctl.oracle)"
rc=$(m4 ctl); arm "CONTROL m4: unbacktracked FENCE, plain/deferred/stored/EVAL forms, bare FENCE, ABORT arm, two arms" "$(same "$rc" ctl.m4 ctl.oracle)"
[ "$fail" = 0 ] && { echo "PASS [$NAME]: $n arms"; exit 0; }
echo "FAIL [$NAME]"; exit 1
