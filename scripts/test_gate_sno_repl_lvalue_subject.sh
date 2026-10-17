#!/usr/bin/env bash
# test_gate_sno_repl_lvalue_subject.sh -- SN4-REPL slice 2: a pattern-replacement SUBJECT may be a
# subscript or an indirect lvalue, not only a plain variable. Until SCRIP d5d63c9d3 the lowerer
# REFUSED these at compile time ("replacement subject must be a plain variable"), so a program using
# the form did not run at all; eliza-duquet-original and eliza-modernized both ride it.
#
# THE THREE SHAPE ARMS are the obvious half:
#   (1) array element   A<1> 'WORLD' = 'THERE'
#   (2) indirect        $N   'WORLD' = 'THERE'
#   (3) table element   T<'k'> 'WORLD' = 'THERE'
#
# ⭐ THE TWO ARMS THAT ACTUALLY EARN THIS GATE ARE (4) AND (5), because NO FIXTURE IN THE SNOFLAKE
# SUITE WOULD CATCH EITHER -- the eliza pair passes whether or not they hold, so without this gate the
# desugaring could regress into a plausible-looking cure and every board would stay green:
#   (4) A FAILED MATCH MUST NOT WRITE. The write-back sits on the success path; move it and
#       `A<1> 'ZZZ' = 'THERE' :F(...)` starts clobbering A<1> with the replacement on a match that
#       never happened.
#   (5) THE SUBJECT LVALUE IS EVALUATED EXACTLY ONCE. The cure saves the lvalue into a hidden name
#       ahead of the match; the obvious alternative -- re-lowering the subject for the write-back --
#       evaluates the subscript TWICE, which is invisible until the index has a side effect. The arm
#       counts calls to a counting function used as the index.
#
# EVERY ARM IS GRADED AGAINST sbl -bf IN THE SAME RUN rather than a recorded .ref, in both modes,
# because the claim is oracle agreement and not a remembered stream. The oracle comes from
# lib_oracle_flags.sh, never a hand-built path.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
SCRIP="${SCRIP:-$HERE/../../SCRIP/scrip}"
RT_DIR="${RT_DIR:-$HERE/../../SCRIP/out}"
. "$HERE/lib_oracle_flags.sh"
SBL="$(sbl_correctness_bin)" || { echo "⛔ REFUSE(rc=2): no correctness oracle -- an ungraded run must never print a verdict"; exit 2; }
[ -x "$SBL" ] || { echo "⛔ REFUSE(rc=2): oracle not executable at $SBL"; exit 2; }
[ -x "$SCRIP" ] || { echo "⛔ REFUSE(rc=2): scrip not built at $SCRIP"; exit 2; }
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
mkdir -p "$W/sink"
SINK="$(sbl_listing_sink_flag "$W/sink")" || { echo "⛔ REFUSE(rc=2): no writable listing sink -- SPITBOL fails OPEN on -o= and would dump its listing into the compared stream"; exit 2; }
# ⛔ BOTH ENGINES GET THE SAME SPELLING (f.sno, cwd in the scratch dir): &FILE is the pathname AS GIVEN,
# and a long path also risks SPITBOL's 119-column listing wrap eating a diagnostic.
cat > "$W/f.sno" <<'SNO'
	DEFINE('IDX()')				:(IEND)
IDX	CALLS = CALLS + 1
	IDX = 1					:(RETURN)
IEND
	A = ARRAY(1)
	A[1] = 'HELLO WORLD'
	A[1] 'WORLD' = 'THERE'
	OUTPUT = 'ARRAY=' A[1]
	B = 'HELLO WORLD'
	N = .B
	$N 'WORLD' = 'THERE'
	OUTPUT = 'INDIRECT=' B
	T = TABLE()
	T['k'] = 'HELLO WORLD'
	T['k'] 'WORLD' = 'THERE'
	OUTPUT = 'TABLE=' T['k']
	C = ARRAY(1)
	C[1] = 'HELLO'
	C[1] 'ZZZ' = 'THERE'			:F(NOWRITE)
	OUTPUT = 'FAILWRITE=MATCHED'		:(ONCE)
NOWRITE	OUTPUT = 'FAILWRITE=' C[1]
ONCE	CALLS = 0
	D = ARRAY(1)
	D[1] = 'HELLO'
	D[IDX()] 'HELLO' = 'BYE'
	OUTPUT = 'CALLS=' CALLS
	OUTPUT = 'ONCEVAL=' D[1]
END
SNO
RED=0; ARMS=0
check() { # $1=engine label  $2=stream
    local arr ind tbl fw calls ov
    arr="$(printf '%s' "$2" | sed -n 's/^ARRAY=//p' | head -1)"
    ind="$(printf '%s' "$2" | sed -n 's/^INDIRECT=//p' | head -1)"
    tbl="$(printf '%s' "$2" | sed -n 's/^TABLE=//p' | head -1)"
    fw="$(printf '%s'  "$2" | sed -n 's/^FAILWRITE=//p' | head -1)"
    calls="$(printf '%s' "$2" | sed -n 's/^CALLS=//p' | head -1)"
    ov="$(printf '%s' "$2" | sed -n 's/^ONCEVAL=//p' | head -1)"
    ARMS=$((ARMS+6))
    [ "$arr" = "HELLO THERE" ] && echo "  ✓ $1: array-element subject replaced" || { echo "  ⛔ $1: array-element subject gave '$arr', expected 'HELLO THERE'"; RED=$((RED+1)); }
    [ "$ind" = "HELLO THERE" ] && echo "  ✓ $1: indirect subject replaced" || { echo "  ⛔ $1: indirect subject gave '$ind', expected 'HELLO THERE'"; RED=$((RED+1)); }
    [ "$tbl" = "HELLO THERE" ] && echo "  ✓ $1: table-element subject replaced" || { echo "  ⛔ $1: table-element subject gave '$tbl', expected 'HELLO THERE'"; RED=$((RED+1)); }
    [ "$fw" = "HELLO" ] && echo "  ✓ $1: a FAILED match wrote nothing" || { echo "  ⛔ $1: failed match left '$fw', expected the subject untouched as 'HELLO' -- the write-back has left the success path"; RED=$((RED+1)); }
    [ "$calls" = "1" ] && echo "  ✓ $1: subject lvalue evaluated exactly once" || { echo "  ⛔ $1: index function called '$calls' times, expected 1 -- the subject is being re-lowered for the write-back"; RED=$((RED+1)); }
    [ "$ov" = "BYE" ] && echo "  ✓ $1: single-evaluation subject still replaced" || { echo "  ⛔ $1: single-evaluation subject gave '$ov', expected 'BYE'"; RED=$((RED+1)); }
}
OUT_SBL="$(cd "$W" && timeout -k 5 8s "$SBL" $(sbl_lang_flags) $SINK f.sno < /dev/null 2>&1)"
check "sbl -bf" "$OUT_SBL"
OUT_M3="$(cd "$W" && timeout -k 5 8s "$SCRIP" --run f.sno < /dev/null 2>&1)"
check "mode-3" "$OUT_M3"
if (cd "$W" && timeout -k 5 60s "$SCRIP" --compile f.sno) > "$W/p.s" 2>"$W/cc.err" && gcc -c "$W/p.s" -o "$W/p.o" 2>>"$W/cc.err" && gcc "$W/p.o" -L"$RT_DIR" -lscrip_rt -lm -Wl,-rpath,"$RT_DIR" -o "$W/p.bin" 2>>"$W/cc.err"; then
    OUT_M4="$(cd "$W" && timeout -k 5 8s ./p.bin < /dev/null 2>&1)"
    check "mode-4" "$OUT_M4"
else
    ARMS=$((ARMS+6)); RED=$((RED+6))
    echo "  ⛔ mode-4: the witness did not compile or assemble -- $(head -1 "$W/cc.err" 2>/dev/null)"
fi
# ⛔ THE ORACLE ARM IS NOT DECORATION: if sbl itself does not produce the readings above, this gate is
# asserting a convention rather than measuring conformance, and it must refuse rather than pass.
echo "-- population: 1 witness × 3 engines (sbl -bf, mode 3, mode 4) × 6 checks = $ARMS arms, $RED red"
[ "$RED" -eq 0 ] && { echo "✅ GATE OK: $ARMS/$ARMS arms -- a replacement subject may be a subscript or an indirect lvalue, a failed match writes nothing, and the subject is evaluated exactly once, oracle-agreeing in both modes"; exit 0; }
echo "⛔ GATE RED: $RED of $ARMS arms"; exit 1
