#!/usr/bin/env bash
# test_gate_no_stored_code_address_in_the_prolog_gate.sh -- LON ORDERED IR_MOVE_LABEL DELETED AND THIS IS
# WHAT HOLDS IT DELETED. Lon 2026-09-13, in-chat to ceo, verbatim: "The IR_MOVE_LABEL is invalid. There are
# no labels. That is a carry over from JCON. Delete that IR." (CEO-693).
#
# WHAT THE OP WAS: IR_MOVE_LABEL stored a CODE ADDRESS into a frame slot (bb_move_label.cpp: lea rax,<target>
# then mov [gate+16],rax) and IR_INDIRECT_GOTO jumped through it on its beta port (bb_indirect_goto.cpp: jmp
# [gate+16]). The two are ONE IDIOM and neither survives alone -- INDIRECT_GOTO had no other writer in the
# tree, so deleting the writer and keeping the reader leaves a box jumping through a slot nobody fills. They
# are lowered by Prolog if-then-else (lower_prolog.c pl_lower_ite) and soft cut (pl_lower_softcut) and by
# nothing else in any frontend, which is why this is a Prolog-lane row and not an engine-wide one.
#
# ⛔ WHY A GATE AND NOT A GREP-ONCE: the ceo's second hazard (CEO-693) is the quiet one. IR_MOVE_LABEL is
# CLASSIFIED IN FOUR PLACES IN frame_layout.c -- the gate.stored-resume-target field at :173, zls_is_wiring
# at :207, and two shape lists at :228 and :279. An op deleted from the enum but left in one of those lists
# is A SILENT SLOT-GRANTING CHANGE, NOT A COMPILE ERROR: the enum value is reused by whatever op follows it,
# so the classification silently starts applying to a different op. All four move together or none do, and
# that is a claim spanning five files, which RULES.md says must be held by an instrument and not by memory.
#
# ARM 1 (the red one before the cure): no source in src/ names the deleted ops or their templates.
# ARM 2 (the control, GREEN BEFORE AND AFTER): the if-then-else and soft-cut witness set answers BYTE-
# IDENTICALLY to swipl in BOTH MODES. It is 28 lines over 15 predicates and it is chosen to exercise the
# GATE and not merely the construct -- a deterministic arm, an arm that leaves a redo, an arm containing a
# cut, an else arm that backtracks, a nested if-then-else, soft cut with and without an else, soft cut whose
# condition leaves a choicepoint, both forms inside findall, and BACKTRACKING BACK INTO an arm from after
# the construct, which is the only shape that reads the gate's beta port at all. A cure that deletes the op
# and quietly makes if-then-else deterministic passes arm 1 and fails arm 2 -- that is the point of arm 2.
# ⛔ ARM 2 IS NOT A BOARD: it grades ONE mktemp witness written by this script, no corpus population, so
# every seat may run it (ONE RUNNER, ONE BOARD, CEO-523).
# ARM 3 (the scoping arm, ruled by CEO-694 on Lon 2026-09-13, verbatim: "We use static wiring only, unless
# it is an if-type construct. So fix that."): the gate ops may be BUILT only inside the two if-type lowerings
# in lower_prolog.c. ⛔ THIS IS THE HALF THAT MATTERS MORE THAN THE RENAME, and the ceo named the reason: the
# deleted op's real damage was that it MADE A SELECTED CONTINUATION AVAILABLE AS A GENERAL FACILITY that any
# construct could reach for, so an exception to static wiring quietly became the ordinary case with nobody
# ruling that it should. A FACILITY REACHABLE BY EVERYTHING IS USED BY EVERYTHING. Scoping it to the
# construct permitted to have it is what makes the exception ENFORCEABLE rather than advisory, and a census
# is what makes the scope a fact rather than a convention a future seat has to know about.
# ⛔ THE CEO'S OWN SPLIT OF THESE SITES IS CORRECTED HERE ON THE SOURCE, not disputed in prose (cto, CEO-694):
# CEO-693/694 read lower_prolog.c:542-544 and :564 as "the catch/3 error-catcher-try triple" and ruled them
# NOT if-type, so three sites move and one stays. THEY ARE NOT catch/3. They are pl_lower_softcut -- the ISO
# soft cut (C *-> T ; E) -- and pl_lower_catch, which begins below them, builds NO gate at all and never did.
# A soft cut is an if-then-else whose condition does not commit, so under Lon's rule as written ALL FIVE
# sites are if-type constructs and the exception covers all five. That is why this arm names TWO functions
# rather than one, and it is a census a reader can re-run instead of a claim about who was right.
# ⭐ AND catch/3 IS THE THIRD, BY NAME (ceo CEO-1270, 2026-09-25, on hq_prolog's ask after the cfo found this arm red since cf11735cb):
# catch/3 selects one of two arms at run time -- the goal, or the recovery when a ball unifies with the catcher -- and must re-enter the
# SELECTED arm on backtracking (ISO 7.8.9), the same reason if-then-else and soft cut carry the gate; static wiring could do it only by
# compiling the continuation once per arm. The ceo's 09-13 sentence calling catch/3 not if-type was written about sites that proved to be
# soft cut and is superseded for catch/3. The census stays a list of NAMED lowerings, so the exception stays enforceable.
# EXIT 0 all arms green; 1 an arm red (named); 2 REFUSED -- could not measure, never a quiet pass.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
SCRIP="$ROOT/scrip"
[ -x "$SCRIP" ] || { echo "⛔ GATE REFUSED (rc=2): no $SCRIP -- nothing was checked" >&2; exit 2; }
# ⛔ THE STALE-BINARY GUARD, ADDED 2026-09-13 BY hq_R (not this gate's author): arm 2 runs ./scrip, and
# test_gate_runners_refuse_on_a_stale_binary.sh census #2 named this file as the one scrip-executing gate
# without it -- 253 of 254 wired -- which reds that census for every seat. A gate that grades a binary older
# than the tree it is standing in reports yesterday's behaviour under today's tree hash, which is the one
# failure mode an ARM-2 BYTE-IDENTICAL claim cannot survive.
"$HERE/util_require_fresh.sh" --gate "${0##*/}" "$SCRIP" "${RT_DIR:-$ROOT/out}/libscrip_rt.so" || exit 2
command -v swipl >/dev/null 2>&1 || { echo "⛔ GATE REFUSED (rc=2): no swipl oracle -- nothing was checked" >&2; exit 2; }
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
rc=0
DEAD='IR_MOVE_LABEL|IR_INDIRECT_GOTO|bb_move_label|bb_indirect_goto|g_move_label_tgt'
hits="$(grep -rnE "$DEAD" "$ROOT/src" 2>/dev/null | grep -v '^Binary' || true)"
if [ -n "$hits" ]; then
    echo "ARM 1 RED: the deleted idiom is still named in src/ --"
    printf '%s\n' "$hits" | sed 's/^/    /' | cut -c1-160
    nfl="$(printf '%s\n' "$hits" | grep -c 'frame_layout\.c' || true)"
    echo "    (of which $nfl in frame_layout.c -- the four classifications move together or none do)"
    rc=1
else
    echo "ARM 1 GREEN: no source in src/ names IR_MOVE_LABEL, IR_INDIRECT_GOTO or their templates"
fi
LOW="$ROOT/src/lower/lower_prolog.c"
[ -r "$LOW" ] || { echo "⛔ GATE REFUSED (rc=2): cannot read $LOW -- ARM 3 checked nothing" >&2; exit 2; }
builds="$(grep -rn 'build(cx, IR_GATE\(_ARM\)\?,' "$ROOT/src" 2>/dev/null || true)"
if [ -z "$builds" ]; then echo "⛔ GATE REFUSED (rc=2): ARM 3 found NO construction of the gate ops at all -- it is grading nothing" >&2; exit 2; fi
outside=""
while IFS= read -r b; do
    [ -z "$b" ] && continue
    f="${b%%:*}"; rest="${b#*:}"; ln="${rest%%:*}"
    case "$f" in *lower_prolog.c) ;; *) outside="$outside$b"$'\n'; continue ;; esac
    fn="$(awk -v L="$ln" 'NR<=L && /^static IR_t \* pl_lower_[a-z_]+\(/ {m=$0} END {print m}' "$f")"
    case "$fn" in *pl_lower_ite\(*|*pl_lower_softcut\(*|*pl_lower_catch\(*) ;; *) outside="$outside$b   [in: ${fn:-<no enclosing pl_lower_*>}]"$'\n' ;; esac
done <<< "$builds"
nb=$(printf '%s\n' "$builds" | grep -c . || true)
if [ -n "$outside" ]; then
    echo "ARM 3 RED: a selected continuation is reachable outside the if-type lowerings ($nb construction site(s) censused) --"
    printf '%s' "$outside" | sed 's/^/    /' | cut -c1-160
    rc=1
else
    echo "ARM 3 GREEN: all $nb gate-op construction sites are inside pl_lower_ite, pl_lower_softcut or pl_lower_catch"
fi
cat > "$TMP/g.pl" <<'EOF'
:- initialization(main).
p(1). p(2). p(3).
q(a). q(b).
det(X) :- ( X > 1 -> write(big) ; write(small) ), nl.
nore(X) :- ( p(X) -> write(found(X)) ; write(none) ), nl.
redoarm :- ( true -> p(Y), write(y(Y)), nl, fail ; true ).
redoarm :- write(redoarm_done), nl.
cutarm :- ( true -> p(Y), Y > 1, !, write(cut(Y)), nl ; true ).
elseredo :- ( fail -> true ; q(Z), write(z(Z)), nl, fail ).
elseredo :- write(elseredo_done), nl.
nested :- ( p(A) -> ( A > 0 -> write(pos(A)) ; write(neg(A)) ) ; write(no) ), nl.
sc1 :- ( p(X) *-> write(sc(X)), nl, fail ; write(scnone), nl ).
sc1 :- write(sc1_done), nl.
sc2 :- ( fail *-> write(never) ; write(scelse) ), nl.
sc3 :- ( q(W) *-> ( W == b -> write(scb) ; write(sca) ) ; write(scno) ), nl, fail.
sc3 :- write(sc3_done), nl.
sccut :- ( p(X) *-> X > 1, !, write(sccut(X)), nl ; write(no) ).
sccut :- write(sccut_done), nl.
noelse :- ( p(X), X > 2 -> write(ne(X)), nl ; true ).
ite_in_findall :- findall(V, ( p(V0), ( V0 > 1 -> V = big(V0) ; V = small(V0) ) ), L), write(L), nl.
sc_in_findall :- findall(V, ( q(V1) *-> V = got(V1) ; V = none ), L), write(L), nl.
ite_backtrack_into :- ( true -> p(X) ; true ), write(bt(X)), nl, X >= 3, write(bt_done), nl.
main :- det(0), det(5), nore(_), redoarm, cutarm, elseredo, nested, sc1, sc2, sc3, sccut, noelse,
        ite_in_findall, sc_in_findall, ite_backtrack_into.
EOF
strip() { sed -e 's/[[:space:]]*$//' | sed -e :a -e '/^$/{$d;N;ba' -e '}'; }
timeout -k 5 60 swipl -q -g true "$TMP/g.pl" </dev/null 2>/dev/null | strip > "$TMP/oracle.txt"
orn=$(wc -l < "$TMP/oracle.txt")
if [ "$orn" -lt 20 ]; then echo "⛔ GATE REFUSED (rc=2): oracle produced $orn lines, expected 28 -- nothing was graded" >&2; exit 2; fi
timeout -k 5 60 "$SCRIP" "$TMP/g.pl" </dev/null 2>&1 | strip > "$TMP/m3.txt"
( cd "$TMP" && timeout -k 5 120 "$SCRIP" --compile g.pl > g.s 2>/dev/null \
  && gcc -c g.s -o g.o 2>/dev/null \
  && gcc g.o -L"$ROOT/out" -lscrip_rt -lm -Wl,-rpath,"$ROOT/out" -o g.bin 2>/dev/null ) || {
    echo "⛔ GATE REFUSED (rc=2): the m4 witness would not compile or link -- m4 was not graded" >&2; exit 2; }
timeout -k 5 60 "$TMP/g.bin" </dev/null 2>&1 | strip > "$TMP/m4.txt"
a2=0
for m in m3 m4; do
    if diff -q "$TMP/oracle.txt" "$TMP/$m.txt" >/dev/null 2>&1; then
        echo "ARM 2 $m GREEN: $orn lines byte-identical to swipl"
    else
        echo "ARM 2 $m RED: differs from swipl --"; diff "$TMP/oracle.txt" "$TMP/$m.txt" | head -30 | sed 's/^/    /'; a2=1
    fi
done
[ "$a2" -eq 0 ] || rc=1
exit $rc
