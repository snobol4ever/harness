#!/usr/bin/env bash
# test_gate_sno_convert_of_a_matched_substring_is_that_substring.sh -- CONVERT of a string a pattern captured (a counted view into
# its subject) converts THAT string, to STRING, INTEGER, NUMERIC, REAL, NAME and PATTERN alike, in both modes.
#
# ⛔ THE DEFECT (hq_snobol4 2026-09-25; aisnobol TEST's divergence at output line 364: "(A P P E N D E X T R A)" printed as
# "(A PA PPA EPPA NEPPA DNEPPA ...)"). EXPLODE builds its list with A LEN(1) . CH =, so each atom is a one-character view into the
# subject; the list was right, but UNREAD.ATOM's CONVERT(L,"STRING") copied the view with VARVAL_fn + strdup, which reads to the
# subject's NUL -- 'Y' became 'YZ'. VARVAL_fn returns the caller's pointer by design, so a C-string reader must materialize the
# counted view (rt_cstr_d); only the REAL arm did. THE CLASS: CONVERT has three implementations -- core.c _CONVERT_ (and the
# NAME() builtin beside it), the by-name BID_CONVERT arm and bn_convert (the path compiled code reaches) -- and every string arm
# of all three read the raw pointer. THE CURE: each normalizes a string argument once at entry through rt_cstr_d.
#
# THE ARMS (expectations cut from sbl -bf AT RUN TIME):
#   1-2  m3 / m4: CONVERT of LEN(1), LEN(2) and mid-subject captures to STRING, INTEGER, NUMERIC, REAL, NAME and PATTERN
#   3    m3: a list of one-character captures built in a loop converts element by element
#   4    CONTROL: CONVERT of whole strings and of an integer, as before
# EXIT: 0 all arms pass · 1 an arm failed · 2 REFUSED (no binary, no oracle, the oracle's answer moved).
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
SCRIP="$ROOT/scrip"
RT_DIR="$ROOT/out"
NAME=sno_convert_of_a_matched_substring_is_that_substring
refuse() { echo "GATE REFUSE(2) [$NAME]: $*"; exit 2; }
[ -x "$SCRIP" ] || refuse "no scrip binary at $SCRIP -- cannot measure"
[ -f "$RT_DIR/libscrip_rt.so" ] || refuse "no $RT_DIR/libscrip_rt.so -- cannot measure mode 4"
. "$HERE/lib_oracle_flags.sh" 2>/dev/null || true
SBL="$(sbl_correctness_bin 2>/dev/null || true)"; [ -n "${SBL:-}" ] && [ -x "$SBL" ] || SBL=/home/resources/x64/bin/sbl
[ -x "$SBL" ] || refuse "no sbl oracle -- cannot measure (a missing oracle prints a full false table)"
T="$(mktemp -d)" || refuse "no tmpdir"
trap 'rm -rf "$T"' EXIT
cat > "$T/conv.sno" <<'EOF'
        A = 'XYZ'
        A LEN(1) . CH
        OUTPUT = 'string [' CONVERT(CH, 'STRING') ']'
        A LEN(2) . C2
        OUTPUT = 'string2 [' CONVERT(C2, 'STRING') '] size ' SIZE(CONVERT(C2, 'STRING'))
        B = 'MNOP'
        B LEN(1) LEN(2) . C3
        OUTPUT = 'mid [' CONVERT(C3, 'STRING') ']'
        N = '1234'
        N LEN(2) . C4
        OUTPUT = 'int [' CONVERT(C4, 'INTEGER') '] num [' CONVERT(C4, 'NUMERIC') '] real [' CONVERT(C4, 'REAL') ']'
        V = 'ABCD'
        V LEN(2) . C5
        AB = 'ab-value'
        OUTPUT = 'name [' $CONVERT(C5, 'NAME') ']'
        P = 'QRST'
        P LEN(2) . C6
        'xxQRyy' CONVERT(C6, 'PATTERN') . M
        OUTPUT = 'pattern [' M ']'
END
EOF
cat > "$T/loop.sno" <<'EOF'
        DATA('PR(HD,TL)')
        DEFINE('EXPL(A)CH')                     :(EXPL.END)
EXPL
EXPL1   A LEN(1) . CH =                         :F(RETURN)
        EXPL = PR(CH, EXPL)                     :(EXPL1)
EXPL.END
        L = EXPL('APPEND')
LOOP    OUTPUT = CONVERT(HD(L), 'STRING')       :F(END)
        L = TL(L)
        IDENT(L)                                :S(END)F(LOOP)
END
EOF
cat > "$T/ctl.sno" <<'EOF'
        OUTPUT = CONVERT('whole', 'STRING') ' ' CONVERT('42', 'INTEGER') + 1 ' ' CONVERT(17, 'STRING')
END
EOF
for w in conv loop ctl; do ( cd "$T" && timeout -k 5 10 "$SBL" -bf "$w.sno" < /dev/null > "$w.oracle" 2>&1 ) || refuse "sbl did not run $w cleanly"; done
grep -qx 'string \[X\]' "$T/conv.oracle" && grep -qx 'mid \[NO\]' "$T/conv.oracle" || refuse "sbl's answer moved: [$(tr '\n' '|' < "$T/conv.oracle")]"
fail=0; n=0
arm() { n=$((n+1)); if [ "$2" = ok ]; then echo "  ok   arm $n  $1"; else echo "  FAIL arm $n  $1 -- $2"; fail=1; fi; }
same() { [ "$1" = 0 ] || { echo "rc=$1"; return; }; cmp -s "$T/$2" "$T/$3" && echo ok || echo "got [$(tr '\n' '|' < "$T/$2" | head -c 110)] want [$(tr '\n' '|' < "$T/$3" | head -c 110)]"; }
m3() { ( cd "$T" && timeout -k 5 10 "$SCRIP" "$1.sno" < /dev/null > "$1.m3" 2>&1; echo $? ); }
rc=$(m3 conv); arm "m3: CONVERT of captured views to STRING INTEGER NUMERIC REAL NAME PATTERN" "$(same "$rc" conv.m3 conv.oracle)"
rc=$( cd "$T" && timeout -k 5 20 "$SCRIP" --compile -o c.s conv.sno < /dev/null > /dev/null 2>&1 && gcc c.s -L"$RT_DIR" -lscrip_rt -Wl,-rpath,"$RT_DIR" -lm -o c.bin > /dev/null 2>&1 && timeout -k 5 10 ./c.bin < /dev/null > conv.m4 2>&1; echo $? )
arm "m4: CONVERT of captured views to STRING INTEGER NUMERIC REAL NAME PATTERN" "$(same "$rc" conv.m4 conv.oracle)"
rc=$(m3 loop); arm "m3: one-character captures built into a list convert element by element" "$(same "$rc" loop.m3 loop.oracle)"
rc=$(m3 ctl); arm "CONTROL: CONVERT of whole strings and an integer" "$(same "$rc" ctl.m3 ctl.oracle)"
[ "$fail" = 0 ] && { echo "PASS [$NAME]: $n arms"; exit 0; }
echo "FAIL [$NAME]"; exit 1
