#!/usr/bin/env bash
# test_gate_sno_cset_from_a_string_view_uses_its_length.sh -- a cset built from a CAPTURED substring
# contains that substring's characters and no others.
#
# THE DEFECT (row snobol4-gimpel-hyphenat-and-line-error-246-is-a-third-mechanism-not-the-capture-class):
# a SNOBOL4 conditional assignment (`. U`) can bind U to a VIEW -- a pointer plus a length INTO a larger
# string, with no NUL at the end of the view. The pattern builders then flattened that descriptor with
# VARVAL_fn, which returns the bare pointer and IGNORES slen, and pat_mk_cset() took strlen() of it. The
# cset therefore ran past the capture to the end of the enclosing buffer.
#
# ⛔ IT IS A SILENT WRONG ANSWER, WHICH IS WHY IT SURVIVED SO LONG AND WHY THIS GATE IS NOT OPTIONAL.
# Nothing crashed and nothing refused: SIZE(U) read 3, `OUTPUT = U` printed exactly 3 characters, and only
# the CSET was wrong. The two Gimpel programs that exposed it had been attributed to a stack-overflow
# class by two earlier rows and to a capture-over-a-defer class by a third; all three were refuted, and the
# real fault was one flattening call.
#
# THE ARMS, and each one has to be able to go red on its own:
#   1  a cset built from a capture that is FOLLOWED by more text contains only the captured characters
#   2  the SECOND and THIRD such csets are not contaminated either -- the original symptom was cumulative,
#      the first capture picking up every later one, so a single-entry arm would have passed throughout
#   3  the same through a TABLE value, which is the shape the real program used
#   4  a capture at the END of the subject (already NUL-terminated) still works -- the cure must not
#      break the case that was always right
# ⭐ EVERY EXPECTATION IS CUT FROM sbl -bf AT RUN TIME, not pinned from us: the gate runs the oracle on the
# same witness and diffs. A pinned expectation here would have frozen our own wrong answer.
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
SCRIP="$ROOT/scrip"
NAME=sno_cset_from_a_string_view_uses_its_length
refuse() { echo "GATE REFUSE(2) [$NAME]: $*"; exit 2; }
[ -x "$SCRIP" ] || refuse "no scrip binary at $SCRIP -- cannot measure"
. "$HERE/lib_oracle_flags.sh" 2>/dev/null || true
SBL="$(sbl_clean_bin 2>/dev/null || true)"; [ -n "${SBL:-}" ] && [ -x "$SBL" ] || SBL=/home/resources/x64/bin/sbl
[ -x "$SBL" ] || refuse "no sbl oracle -- cannot measure (a missing oracle prints a full false table)"
T="$(mktemp -d)" || refuse "no tmpdir"
trap 'rm -rf "$T"' EXIT
cat > "$T/w.sno" <<'SNO'
        DEFINE('MEM(P)A,C')                     :(MEM_END)
MEM     A = 'abcdefgxy,'
MEM_L   A LEN(1) . C =                          :F(RETURN)
        C P                                     :F(MEM_L)
        MEM = MEM C                             :(MEM_L)
MEM_END
        D = 'bcd,efg,xy,'
        D BREAK(',') . U ',' =
        V1 = ANY(U)
        D BREAK(',') . U ',' =
        V2 = ANY(U)
        D BREAK(',') . U ',' =
        V3 = ANY(U)
        OUTPUT = '1 ' MEM(V1)
        OUTPUT = '2 ' MEM(V2)
        OUTPUT = '3 ' MEM(V3)
        T1 = TABLE(30)
        E = 'bcd,efg,xy,'
        E BREAK(',') . W ',' =
        T1['a'] = ANY(W)
        E BREAK(',') . W ',' =
        T1['b'] = ANY(W)
        OUTPUT = 'ta ' MEM(T1['a'])
        OUTPUT = 'tb ' MEM(T1['b'])
        F = 'bcd'
        F BREAK(',') . Z                        :F(FEND)
        OUTPUT = 'end ' MEM(ANY(Z))             :(FDONE)
FEND    OUTPUT = 'end ' MEM(ANY(F))
FDONE
        OUTPUT = 'sp ' MEM(SPAN(U))
END
SNO
timeout -k 5 60 "$SBL" -bf "$T/w.sno" </dev/null > "$T/ora" 2>&1 || refuse "the sbl oracle could not run the witness -- cannot measure"
[ -s "$T/ora" ] || refuse "the oracle produced ZERO BYTES -- that is not a score"
grep -q '^1 bcd$' "$T/ora" || refuse "the oracle did not produce the expected shape -- the witness or the oracle moved, re-measure rather than score"
timeout -k 5 60 "$SCRIP" "$T/w.sno" </dev/null > "$T/got" 2>&1
graded=0; fail=0
while read -r tag; do
  graded=$((graded+1))
  o="$(grep -m1 "^$tag " "$T/ora" || true)"; g="$(grep -m1 "^$tag " "$T/got" || true)"
  if [ -z "$o" ]; then refuse "oracle printed no line for arm '$tag' -- cannot measure"; fi
  if [ "$o" = "$g" ]; then echo "  PASS $tag  [$o]"; else echo "  FAIL $tag  oracle[$o] got[$g]"; fail=$((fail+1)); fi
done <<'TAGS'
1
2
3
ta
tb
end
sp
TAGS
[ "$graded" = 7 ] || refuse "expected 7 arms, graded $graded"
echo "graded=$graded FAIL=$fail (every expectation cut from sbl -bf AT RUN TIME, never pinned from us. ⛔ AND THEY DO NOT ALL DISCRIMINATE, measured on the pre-cure binary rather than assumed: 3 of the 7 go RED -- ta and tb, the TABLE shape the real program used, and sp for SPAN -- and arms 1, 2, 3 and end do NOT. I expected the plain-variable captures to be detectors and they are not; that path already materialised. So arms 1-3 and end are ORACLE-AGREEMENT arms that would catch a cure overshooting into breaking the cases that were always right, and they must never be counted as evidence this class is detectable. The three that bite are the ones where the cset outlives the capture in a container.)"
if [ "$fail" -ne 0 ]; then echo "GATE FAIL(1) [$NAME]: $fail/$graded"; exit 1; fi
echo "GATE PASS(0) [$NAME]: $graded/$graded"
exit 0
