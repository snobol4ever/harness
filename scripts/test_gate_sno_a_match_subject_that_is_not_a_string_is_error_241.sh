#!/usr/bin/env bash
# test_gate_sno_a_match_subject_that_is_not_a_string_is_error_241.sh -- a SNOBOL4 pattern match whose SUBJECT is an ARRAY, TABLE, DATA instance, PATTERN, CODE or EXPRESSION value raises ERROR 241 and the statement then FAILS.
#
# # ⛔ THE DEFECT (found by hq_snobol4 2026-10-07 while curing the infinite_snobol4 concatenation, baton snobol4-every-suite-to-100-under-nonet-ceo-1266): sbl -bf answers  a ? 'i'  with a = ARRAY('0:3')
#   "ERROR 241 pattern match left operand is not a string" and the statement takes its failure branch; SCRIP read the ARRAY's bytes as a string, matched nothing and FAILED SILENTLY -- no error, &ERRTYPE unset, a program
#   that traps it (SETEXIT) or ends on it (the default) behaved as if the match had merely missed. The class, measured against sbl one type at a time: ARRAY, TABLE, a DATA instance, a PATTERN, a CODE and an
#   EXPRESSION raise 241; a NAME, an INTEGER, a REAL and the NULL string are subjects (they stringify or are empty) and raise nothing.
#   THE CURE: c_rt_match_enter (gen_runtime.c, the slow path every non-string subject takes; the asm rt_match_enter in rtx_match.s tail-calls it for anything but a nonempty DT_S) raises 241 for the six types and returns a
#   NULL subject, and bb_match_begin tests that NULL at the box's entry and takes the box's own failure exit (the one a first-step miss takes), so a pattern that would match the empty string FAILS too, as sbl's does.
#
# THE ARMS (expectations cut from sbl -bf AT RUN TIME): each program in m3 and in m4
#   1-2  BAD SUBJECTS: ARRAY, TABLE, DATA, PATTERN, CODE, EXPRESSION against a literal, an empty-matching pattern (NULL, ARBNO), a pattern with a conditional capture, and in the replacement form  s ? 'i' = 'x'   -- RED on base (no error)
#   3-4  CONTROLS: NAME, INTEGER, REAL and NULL subjects, string subjects that match and that miss, a subject that is the value of a call, a nested match inside a deferred pattern
# EXIT: 0 all arms pass · 1 an arm failed · 2 REFUSED (no binary, no oracle, no tmpdir, the oracle's answer moved).
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
SCRIP="$ROOT/scrip"
RT_DIR="$ROOT/out"
NAME=sno_a_match_subject_that_is_not_a_string_is_error_241
refuse() { echo "GATE REFUSE(2) [$NAME]: $*"; exit 2; }
[ -x "$SCRIP" ] || refuse "no scrip binary at $SCRIP -- cannot measure"
[ -f "$RT_DIR/libscrip_rt.so" ] || refuse "no $RT_DIR/libscrip_rt.so -- cannot measure mode 4"
. "$HERE/lib_oracle_flags.sh" 2>/dev/null || true
SBL="$(sbl_correctness_bin 2>/dev/null || true)"; [ -n "${SBL:-}" ] && [ -x "$SBL" ] || SBL=/home/resources/x64/bin/sbl
[ -x "$SBL" ] || refuse "no sbl oracle -- cannot measure (a missing oracle prints a full false table)"
T="$(mktemp -d)" || refuse "no tmpdir"
trap 'rm -rf "$T"' EXIT
mkprog() { local out="$1" n=0 e; shift
    { cat <<'EOS'
        DATA('rec(f)')
        &ERRLIMIT = 1000
        SETEXIT('errh')
        a = ARRAY('0:3'); t = TABLE(); d = rec(1); p = LEN(1); c = CODE(' x = 1'); e = *x; nm = .z; i = 5; r = 2.5; nu = ''; s = 'hello'
        k = 0
        :(go)
errh    SETEXIT('errh')
        OUTPUT = k ' ERROR ' &ERRTYPE                           :(CONTINUE)
go
EOS
      while IFS= read -r e; do n=$((n + 1))
          printf "        k = %d\n        %s                                   :S(s%d)F(f%d)\ns%d     OUTPUT = k ' SUCCESS'                         :(n%d)\nf%d     OUTPUT = k ' FAIL'\nn%d\n" "$n" "$e" "$n" "$n" "$n" "$n" "$n" "$n"
      done
      printf "END\n"; } > "$out"; }
cat > "$T/bad.txt" <<'EOS'
a ? 'i'
t ? 'i'
d ? 'i'
p ? 'i'
c ? 'i'
e ? 'i'
a ? NULL
t ? ARBNO('x')
d ? ''
p ? LEN(0)
a ? 'i' . v
c ? REM
e ? POS(0)
a ? 'i' = 'x'
d ? ARB = 'y'
EOS
cat > "$T/ctl.txt" <<'EOS'
nm ? 'z'
nm ? 'q'
i ? '5'
i ? '6'
r ? '2.5'
nu ? 'x'
nu ? NULL
nu ? ''
s ? 'ell'
s ? 'xyz'
s ? 'ell' = 'ipp'
DUPL('ab', 2) ? 'ba'
s ? *(LEN(1) 'e')
EOS
mkprog "$T/bad.sno" < "$T/bad.txt"
mkprog "$T/ctl.sno" < "$T/ctl.txt"
want() { timeout -k 5 30 "$SBL" -bf "$T/$1.sno" < /dev/null > "$T/$1.want" 2>/dev/null; [ -s "$T/$1.want" ] || refuse "sbl -bf produced no output for $1 -- the oracle's answer moved"; }
want bad; want ctl
grep -q '^1 ERROR 241$' "$T/bad.want" || refuse "sbl -bf no longer answers an ARRAY match subject with ERROR 241"
grep -q ' ERROR ' "$T/ctl.want" && refuse "sbl -bf now raises an error on a control subject -- the controls moved"
fail=0; pass=0
arm() { local n="$1" what="$2" ok="$3"
    if [ "$ok" = 1 ]; then pass=$((pass + 1)); echo "  arm $n PASS  $what"; else fail=$((fail + 1)); echo "  arm $n FAIL  $what"; fi; }
same_m3() { timeout -k 5 60 "$SCRIP" -d131072k -s4096k "$T/$1.sno" < /dev/null > "$T/$1.m3" 2>&1
    cmp -s "$T/$1.want" "$T/$1.m3" || { diff "$T/$1.want" "$T/$1.m3" | head -6 | cut -c1-160 | sed 's/^/      /'; return 1; }; }
same_m4() { timeout -k 5 120 "$SCRIP" --compile -o "$T/$1.s" "$T/$1.sno" < /dev/null > /dev/null 2>&1 \
        && gcc -no-pie "$T/$1.s" -L"$RT_DIR" -lscrip_rt -lm -Wl,-rpath,"$RT_DIR" -o "$T/$1.bin" 2>/dev/null || { echo "      COMPILE-FAILED"; return 1; }
    timeout -k 5 60 "$T/$1.bin" -d131072k -s4096k -- < /dev/null > "$T/$1.m4" 2>&1
    cmp -s "$T/$1.want" "$T/$1.m4" || { diff "$T/$1.want" "$T/$1.m4" | head -6 | cut -c1-160 | sed 's/^/      /'; return 1; }; }
n=0
for spec in "bad|BAD SUBJECTS: ARRAY TABLE DATA PATTERN CODE EXPRESSION, empty-matching patterns, the replacement form" "ctl|CONTROLS: NAME INTEGER REAL NULL and string subjects"; do
    p="${spec%%|*}"; w="${spec#*|}"
    n=$((n + 1)); same_m3 "$p" && arm $n "m3 $w" 1 || arm $n "m3 $w" 0
    n=$((n + 1)); same_m4 "$p" && arm $n "m4 $w" 1 || arm $n "m4 $w" 0
done
if [ "$fail" -eq 0 ]; then echo "GATE PASS(0) [$NAME]: $pass arms -- a non-string match subject is ERROR 241 and the match fails, both modes"; exit 0; fi
echo "GATE FAIL(1) [$NAME]: $fail of $((pass + fail)) arms red"; exit 1
