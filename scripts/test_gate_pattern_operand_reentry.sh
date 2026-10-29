#!/usr/bin/env bash
# test_gate_pattern_operand_reentry.sh -- pattern operand temporaries must be per-ACTIVATION, not per-SITE.
# Row snobol4-pattern-operand-temporaries-are-per-site-globals-clobbered-by-reentry (hq_C mint, seat01 census,
# hq_P cure 2026-09-06); re-cut 2026-10-11 (CEO-1663).
#
# ⛔⭐ WHY THIS GATE CARRIES A MIRROR ARM. A cure that stores operand 0 LAST, after the re-entrant call returns,
# MOVES the window rather than closing it, and reverses SNOBOL4's left-to-right evaluation order on the way. A
# gate holding only the published witness (recursion in the RIGHT operand) is GREEN on that wrong fix. The MIRROR
# arm -- the same shape with the recursion in the LEFT operand -- is what rejects it. Arm 4 recurses on BOTH sides
# of a three-way alternation, so neither evaluation order can hide a per-site staging slot.
#
# ⭐ ARM 3 IS THE DISCRIMINATOR AND MUST STAY GREEN: recursion WITHOUT re-entry of the staging site was never
# broken. It is here so a future reader cannot conclude "recursion is the trigger" -- the trigger is SITE
# RE-ENTRY. If arm 3 ever goes red the cure has broken ordinary recursion, which no board would attribute here.
#
# ⭐ THE EXPECTED OUTPUT IS THE ORACLE'S. Every arm's ref is cut from sbl -bf at run time, never typed, and each
# arm also prints a NO-MATCH line, so a pattern that is too broad reds as surely as one that lost an alternative.
# Lon 2026-10-11, in-chat: "Do not add broken code just to enable a test to determine a bug in PATTERN matching is
# fixed. Just create a proper test instead." -- the earlier self-test ran the arms under a pre-cure lowering knob
# (SCRIP_PB_ARGORDER, gone since cac4d66ca); no planted defect stands in for it.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"; SD="$HERE/../../SCRIP"; SCRIP="$SD/scrip"
[ -x "$SCRIP" ] || { echo "⛔ REFUSE(rc=2): no scrip binary at $SCRIP -- build first (make)"; exit 2; }
"$HERE/util_require_fresh.sh" --gate test_gate_pattern_operand_reentry "$SCRIP" "${RT_DIR:-$SD/out}/libscrip_rt.so" || exit 2
. "$HERE/lib_oracle_flags.sh"
SBL="$(sbl_correctness_bin)"; [ -x "$SBL" ] || { echo "⛔ REFUSE(rc=2): no correctness oracle ($SBL) -- the refs are cut from the oracle at run time, never typed"; exit 2; }
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
# arm 1 -- re-entrant call in the RIGHT operand (the row's own shape).  arm 2 -- the MIRROR, in the LEFT.
# Both yield the full alternation a1 | a2 | a3; a clobbered outer operand loses exactly the OUTERMOST one.
cat > "$W/right.sno" <<'EOF'
	DEFINE('F(N)')				:(F_END)
F	F  =  'a' N
	GE(N,3)					:S(RETURN)
	F  =  F  |  F(N + 1)			:(RETURN)
F_END
	DEFINE('T(NAME,SUBJ,PAT)')		:(T_END)
T	SUBJ  POS(0) *PAT RPOS(0)		:F(TF)
	OUTPUT  =  NAME ' matched'		:(RETURN)
TF	OUTPUT  =  NAME ' NO-MATCH'		:(RETURN)
T_END
	P  =  F(1)
	T('a1', 'a1', P)
	T('a2', 'a2', P)
	T('a3', 'a3', P)
	T('a4', 'a4', P)
END
EOF
sed 's/F  =  F  |  F(N + 1)/F  =  F(N + 1)  |  F/' "$W/right.sno" > "$W/left.sno"
# arm 3 -- the DISCRIMINATOR: recursive, but the staging site runs only at the outermost level.
cat > "$W/norentry.sno" <<'EOF'
	DEFINE('A(N)')				:(A_END)
A	NE(N,1)					:S(A_DEEP)
	A  =  'x1'
	A  =  A  |  A(2)			:(RETURN)
A_DEEP	A  =  'x2'				:(RETURN)
A_END
	DEFINE('T(NAME,SUBJ,PAT)')		:(T_END)
T	SUBJ  POS(0) *PAT RPOS(0)		:F(TF)
	OUTPUT  =  NAME ' matched'		:(RETURN)
TF	OUTPUT  =  NAME ' NO-MATCH'		:(RETURN)
T_END
	P  =  A(1)
	T('x1', 'x1', P)
	T('x2', 'x2', P)
	T('x3', 'x3', P)
END
EOF
# arm 4 -- re-entry on BOTH sides: G(N+1) | G | G(N+1), plus a LEN(N) operand whose value is the activation's own N.
cat > "$W/both.sno" <<'EOF'
	DEFINE('G(N)')				:(G_END)
G	G  =  'b' N
	GE(N,4)					:S(RETURN)
	G  =  G(N + 1)  |  G LEN(N)  |  G(N + 1)	:(RETURN)
G_END
	DEFINE('T(NAME,SUBJ,PAT)')		:(T_END)
T	SUBJ  POS(0) *PAT RPOS(0)		:F(TF)
	OUTPUT  =  NAME ' matched'		:(RETURN)
TF	OUTPUT  =  NAME ' NO-MATCH'		:(RETURN)
T_END
	P  =  G(1)
	T('b1x', 'b1x', P)
	T('b2xy', 'b2xy', P)
	T('b3xyz', 'b3xyz', P)
	T('b4', 'b4', P)
	T('b1', 'b1', P)
	T('b2x', 'b2x', P)
END
EOF
fail=0
grade() {  # $1 label  $2 file
    local lab="$1" f="$2" want m3 m4 rc=0
    want="$(cd "$W" && timeout -k 5 20 "$SBL" $(sbl_lang_flags) "$f" </dev/null 2>/dev/null)"
    [ -n "$want" ] || { echo "  ⛔ REFUSE(rc=2): $lab -- the oracle printed nothing for $f"; exit 2; }
    m3="$(cd "$W" && timeout -k 5 20 "$SCRIP" --run "$f" </dev/null 2>&1)"
    [ "$m3" = "$want" ] || { echo "  ⛔ $lab m3 RED:"; diff <(printf '%s\n' "$want") <(printf '%s\n' "$m3") | sed 's/^/      /'; rc=1; }
    if (cd "$W" && timeout -k 5 60 "$SCRIP" --compile --out="$W/p.s" "$f" </dev/null >/dev/null 2>&1) \
       && gcc -no-pie "$W/p.s" -L"$SD/out" -lscrip_rt -lm -Wl,-rpath,"$SD/out" -o "$W/p.bin" 2>/dev/null; then
        m4="$(cd "$W" && timeout -k 5 20 "$W/p.bin" </dev/null 2>&1)"
        [ "$m4" = "$want" ] || { echo "  ⛔ $lab m4 RED:"; diff <(printf '%s\n' "$want") <(printf '%s\n' "$m4") | sed 's/^/      /'; rc=1; }
    else echo "  ⛔ $lab m4 REFUSED: compile/link failed"; rc=1; fi
    [ "$rc" = 0 ] && echo "  PASS $lab (both modes = sbl)"
    return $rc
}
echo "== pattern operand staging must be per-ACTIVATION (row: per-site-globals-clobbered-by-reentry), graded against $SBL"
grade "arm1 re-entry in RIGHT operand" right.sno || fail=1
grade "arm2 re-entry in LEFT operand (MIRROR)" left.sno || fail=1
grade "arm3 recursion WITHOUT site re-entry (discriminator)" norentry.sno || fail=1
grade "arm4 re-entry on BOTH sides with a LEN(N) operand" both.sno || fail=1
[ "$fail" = 0 ] && { echo "OK: operand temporaries survive re-entry of their own staging site (4 arms, both modes, oracle refs)"; exit 0; }
echo "⛔ GATE RED: a pattern operand was clobbered by re-entry of its staging site"; exit 1
