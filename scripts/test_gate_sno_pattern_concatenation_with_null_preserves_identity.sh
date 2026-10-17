#!/usr/bin/env bash
# test_gate_sno_pattern_concatenation_with_null_preserves_identity.sh -- concatenating a pattern with the null string, on
# either side, is a no-op in SPITBOL: it returns the ORIGINAL pattern object, not a freshly wrapped SEQ, so IDENT(P NULL,P)
# and IDENT(NULL P,P) both succeed. pat_cat (pattern_match.c) always built a new TT_SEQ node wrapping both sides regardless
# of value, so the wrapped result was never IDENT to the bare pattern -- descr_identical compares DT_P values by raw bytes
# (values.c c_descr_identical, the default memcmp arm), and two distinct dtp_new() allocations never share that identity.
#
# ⛔ THE DEFECT (row snobol4-all-eight-spitbol-testpgms-..., class (b) of the SPITBOL testpgms task; test1.spt stmts
# 194/195, TEST = DIFFER(BAL NULL,BAL) STARS / TEST = DIFFER(NULL BAL,BAL) STARS): sbl -bf finds BAL NULL and NULL BAL
# IDENT to BAL, so DIFFER fails silently and no error prints; SCRIP built a new SEQ(BAL,"") node each time, so DIFFER
# succeeded and printed a spurious "ERROR DETECTED" line SPITBOL never prints.
# THE CURE: pat_cat elides the SEQ wrap when either operand is the null string (the same emptiness test values.c's
# c_descr_identical already uses for two null strings), returning the other operand's DESCR_t verbatim -- same object,
# same identity, whether that operand is itself a pattern or gets promoted to one downstream.
#
# THE ARMS (expectations cut from sbl -bf):
#   1-2  m3 / m4: an 8-line IDENT/DIFFER census (BAL/ARB, both concat orders, a literal '' on both sides, a control pair
#        proving a REAL pattern-vs-string pair still reads DIFFER, and a plain-string-only control) equals sbl -bf
#        -- RED on base (ident1/ident2/ident5 read "no", not "yes")
# EXIT: 0 all arms pass · 1 an arm failed · 2 REFUSED (no binary, no oracle, the oracle's answer moved).
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
SCRIP="$ROOT/scrip"
RT_DIR="$ROOT/out"
NAME=sno_pattern_concatenation_with_null_preserves_identity
refuse() { echo "GATE REFUSE(2) [$NAME]: $*"; exit 2; }
[ -x "$SCRIP" ] || refuse "no scrip binary at $SCRIP -- cannot measure"
[ -f "$RT_DIR/libscrip_rt.so" ] || refuse "no $RT_DIR/libscrip_rt.so -- cannot measure mode 4"
. "$HERE/lib_oracle_flags.sh" 2>/dev/null || true
SBL="$(sbl_correctness_bin 2>/dev/null || true)"; [ -n "${SBL:-}" ] && [ -x "$SBL" ] || SBL=/home/resources/x64/bin/sbl
[ -x "$SBL" ] || refuse "no sbl oracle -- cannot measure (a missing oracle prints a full false table)"
T="$(mktemp -d)" || refuse "no tmpdir"
trap 'rm -rf "$T"' EXIT
cat > "$T/census.sno" <<'EOF'
          OUTPUT = 'ident1 ' (IDENT(BAL NULL,BAL) 'yes', 'no')
          OUTPUT = 'ident2 ' (IDENT(NULL BAL,BAL) 'yes', 'no')
          OUTPUT = 'ident3 ' (IDENT('' BAL,BAL) 'yes', 'no')
          OUTPUT = 'ident4 ' (IDENT(BAL '',BAL) 'yes', 'no')
          OUTPUT = 'ident5 ' (IDENT(ARB NULL,ARB) 'yes', 'no')
          OUTPUT = 'differ1 ' (DIFFER('X' NULL,'X') 'yes', 'no')
          s = 'abc' BAL
          s2 = 'abc'
          OUTPUT = 'ident6 ' (IDENT(s,s2) 'yes', 'no')
          OUTPUT = 'ident7 ' (IDENT('ab' 'c' NULL,'ab' 'c') 'yes', 'no')
END
EOF
( cd "$T" && timeout -k 5 20 "$SBL" -bf census.sno < /dev/null > census.oracle 2>&1 ) || refuse "sbl did not run the census cleanly"
grep -qx 'ident1 yes' "$T/census.oracle" && grep -qx 'ident6 no' "$T/census.oracle" || refuse "sbl's answer moved: [$(tr '\n' '|' < "$T/census.oracle" | head -c 160)]"
fail=0; n=0
arm() { n=$((n+1)); if [ "$2" = ok ]; then echo "  ok   arm $n  $1"; else echo "  FAIL arm $n  $1 -- $2"; fail=1; fi; }
same() { [ "$1" = 0 ] || { echo "rc=$1"; return; }; cmp -s "$T/$2" "$T/$3" && echo ok || echo "$(diff "$T/$3" "$T/$2" | grep '^[<>]' | tr '\n' '|' | head -c 160)"; }
m3() { ( cd "$T" && timeout -k 5 20 "$SCRIP" "$1.sno" < /dev/null > "$1.m3" 2>&1; echo $? ); }
m4() { ( cd "$T" && timeout -k 5 30 "$SCRIP" --compile -o "$1.s" "$1.sno" < /dev/null > /dev/null 2>&1 && gcc "$1.s" -L"$RT_DIR" -lscrip_rt -Wl,-rpath,"$RT_DIR" -lm -o "$1.bin" > /dev/null 2>&1 && timeout -k 5 20 "./$1.bin" < /dev/null > "$1.m4" 2>&1; echo $? ); }
rc=$(m3 census); arm "m3: pattern-null concatenation IDENT/DIFFER census equals sbl -bf" "$(same "$rc" census.m3 census.oracle)"
rc=$(m4 census); arm "m4: pattern-null concatenation IDENT/DIFFER census equals sbl -bf" "$(same "$rc" census.m4 census.oracle)"
[ "$fail" = 0 ] && { echo "PASS [$NAME]: $n arms"; exit 0; }
echo "FAIL [$NAME]"; exit 1
