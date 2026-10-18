#!/usr/bin/env bash
# test_gate_icn_function_builtin_names_dispatchable.sh -- hq_I 2026-09-06, OCTET row flip-ipl-declchck.
#
# WHAT IT PINS. Icon's function() is a 0-argument generator yielding the names of the built-in functions.
# SCRIP lowers it (src/lower/lower_icon.c, lower_function_gen) as the existing `!["abs", ...]` shape over a
# static table icn_function_names[]. A HAND-TYPED TABLE IS A CLAIM ABOUT A SET, and this file is the thing
# that keeps it true: it grades the table in BOTH directions against the live Icon oracle.
#
# ⛔⭐⭐ RE-CUT BY RULING (ceo CEO-481, 2026-09-09 19:04, applying CEO-463). THIS GATE NO LONGER DEMANDS
# DISPATCHABILITY. function() ENUMERATES THE ORACLE'S LIST, name for name, display included; the enumeration
# is compared against iconx's own function() output and nothing else. A name's DISPATCH is a separate
# question with a separate owner -- display's is hq_B's rung-41 display row, and its red there is honest.
# ⛔⭐ WHY THE RULING WENT THAT WAY, AND IT IS THE WHOLE LESSON OF THIS FILE. The gate previously held that
# the table must name only what SCRIP can CALL, so a name that raises ERROR 022 had to be omitted. Read as
# current, that doctrine cost an origin program: hq_R dropped "display" at bdd554570 to green ARM 4a, and IPL
# progs/ifncsgen went RED in both modes -- because ifncsgen.std is cut from iconx, and iconx's function()
# YIELDS display, so the .std carries a Display block SCRIP then omitted (diff 109,114d108). ⭐ A REFLECTIVE
# BUILTIN IS GRADED BY THE ORACLE'S ANSWER, NOT BY OUR OWN CAPABILITIES: shortening the list to match what we
# implement makes every oracle-cut ref in the corpus wrong, and it hides the missing builtin instead of
# reporting it. The dispatch probe below is KEPT and still prints, because knowing which names cannot be
# called is worth having -- but it is INFORMATIONAL and can never red this gate. A gate that reds on a
# truthful enumeration is measuring the wrong thing.
# ⭐ AND THE ERROR UNDER THE ERROR, worth more than either verdict: the doctrine hq_R acted on was stated in
# THIS COMMENT, which said "the table is 83, the 8 omitted are chdir delay display getch getche kbhit
# loadfunc rename". True when written; by 09-09 hq_B's rung-41 had landed SEVEN of those eight, so the prose
# named an eight-wide hole that was one name wide. A COUNT IN PROSE BESIDE A GATE THAT MEASURES THE SAME
# COUNT IS ALWAYS THE STALER OF THE TWO. The numbers here are dated and are worked examples, never an
# authority: run the gate, which prints the live sets by name.
#
# ⛔ WHERE THIS NOTE LIVES, AND WHY IT IS NOT IN THE .c: hq_B asked for the 8 names in the cure's own comment.
# src/ carries ZERO prose comments by law -- strip_comments.py --check reds any file holding one, and it red
# this cure twice while it was being written -- so the rationale lives here, in the gate that grades the
# table, which is the file a reader of icn_function_names[] is sent to anyway. hq_B is told, not substituted.
#
# ⛔⭐ THE DISPATCHABILITY PROBE, AND WHY IT IS BUILT THIS WAY. ERROR 022 is raised BOTH for an unknown name
# AND for a known builtin called at the wrong arity -- measured: `abs()` with no argument raises 022 exactly
# as `chdir(".")` does. A census that calls every name with a fixed argument count therefore cannot tell
# "unimplemented" from "implemented and refused these arguments", and one that did reported 76 of 91 missing
# against a true answer of 9. So every probe here is built at THE ORACLE'S OWN ARITY, read from the live
# oracle at run time (never a table typed here).
#
# ⛔⭐ AND ARITY ALONE IS NOT ENOUGH -- THIS GATE CAUGHT ITS OWN AUTHOR ASSERTING THAT IT WAS. The claim
# "at the right arity the argument TYPES do not matter" was measured on iand("a","b"), sqrt("zz"), open(1),
# char("q") and tab("x"), all silent, and it is FALSE: the aggregate family (get pop pull push put sort
# sortf) raises 022 for an untyped scalar, and the first run of this gate reported all seven as missing
# builtins when every one of them is present. The sample simply did not contain the discriminating pair --
# the same shape as a cross-type sort witness too narrow to hold the pair that is out of order. So a name
# counts as DISPATCHABLE if EITHER shape is free of 022: all-scalar arguments, or an aggregate first
# argument. Both shapes are still built at oracle arity. Proven to clear all seven and to leave the eight
# genuinely-missing names red.
#
# REFUSES rc=2 rather than reporting green whenever it cannot measure: no oracle, no arity list, zero names
# graded. A test that cannot measure never prints the success shape.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
SCRIP="$ROOT/scrip"
. "$HERE/lib_oracle_flags.sh" 2>/dev/null || { echo "⛔ GATE REFUSES(2): lib_oracle_flags.sh unloadable"; exit 2; }
ICONT="$(icont_bin 2>/dev/null)"
[ -x "${ICONT:-}" ] || { echo "⛔ GATE REFUSES(2): no Icon oracle -- cannot grade a name set against nothing"; exit 2; }
[ -x "$SCRIP" ] || { echo "⛔ GATE REFUSES(2): $SCRIP not built"; exit 2; }
# ⛔ STALENESS PREFLIGHT (hq_B 2026-09-06, wiring an omission caught by test_gate_runners_refuse_on_a_stale_binary.sh
# ARM 14's census, not by this gate failing): this gate EXECUTES "$SCRIP" to decide whether a name dispatches, so
# without the guard it grades whatever binary happens to sit in the tree and stamps the verdict with a git SHA that
# is not evidence about it -- the exact class that produced two false-red audits in one day (a 10:57 binary read RED
# at 14:03 and GREEN after nothing but an incremental make). One authority, sourced, never reimplemented: the rule
# is gate_require_fresh in lib_gate.sh and nowhere else (ARM 10's one-copy invariant).
. "$HERE/lib_gate.sh" || { echo "⛔ GATE REFUSES(2): lib_gate.sh unloadable"; exit 2; }
gate_require_fresh "$ROOT" src "$ROOT/scrip" "$ROOT/out/libscrip_rt.so"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
FAIL=0; red() { echo "  ⛔ $*"; FAIL=$((FAIL+1)); }
# -- the oracle's own name+arity list, generated by the oracle, never typed here --------------------------
cat > "$TMP/arity.icn" <<'ICN'
procedure main()
   local n, i;
   every n := function() do {
      i := args(proc(n, 0));
      write(n, " ", i)
      };
end
ICN
( cd "$TMP" && "$ICONT" -s arity.icn >/dev/null 2>&1 && ./arity > oracle_arity.txt 2>/dev/null )
[ -s "$TMP/oracle_arity.txt" ] || { echo "⛔ GATE REFUSES(2): the oracle produced no name/arity list"; exit 2; }
ORACLE_N=$(wc -l < "$TMP/oracle_arity.txt")
awk '{print $1}' "$TMP/oracle_arity.txt" | sort > "$TMP/oracle_names.txt"
# -- ARM 1: SCRIP's function() yields a non-empty, sorted, duplicate-free list in m3 ----------------------
cat > "$TMP/fn.icn" <<'ICN'
procedure main()
   every write(function());
end
ICN
"$SCRIP" --run "$TMP/fn.icn" < /dev/null > "$TMP/m3.txt" 2>&1
OURS_N=$(grep -c . "$TMP/m3.txt" 2>/dev/null || echo 0)
[ "$OURS_N" -gt 0 ] || { echo "⛔ GATE REFUSES(2): function() yielded ZERO names -- nothing to grade"; cat "$TMP/m3.txt"; exit 2; }
sort "$TMP/m3.txt" > "$TMP/ours_sorted.txt"
cmp -s "$TMP/m3.txt" "$TMP/ours_sorted.txt" || red "ARM 1: function() does not yield its names in sorted order"
[ "$(sort -u "$TMP/m3.txt" | wc -l)" -eq "$OURS_N" ] || red "ARM 1: function() yields duplicate names"
# -- ARM 2: m3 and m4 agree byte for byte ----------------------------------------------------------------
"$SCRIP" --compile "$TMP/fn.icn" > "$TMP/fn.s" 2>/dev/null < /dev/null
if [ -s "$TMP/fn.s" ] && gcc -no-pie "$TMP/fn.s" -L"$ROOT/out" -lscrip_rt -Wl,-rpath,"$ROOT/out" -o "$TMP/fn.bin" 2>/dev/null; then
    "$TMP/fn.bin" < /dev/null > "$TMP/m4.txt" 2>&1
    cmp -s "$TMP/m3.txt" "$TMP/m4.txt" || red "ARM 2: m3 and m4 disagree about the function() name set"
else
    red "ARM 2: mode-4 compile/link of the function() witness failed"
fi
# -- ARM 3: THE ENUMERATION IS THE ORACLE'S, NAME FOR NAME, IN BOTH DIRECTIONS (ceo CEO-481) --------------
# This is the gate's whole verdict now. Both directions are named separately because they fail for opposite
# reasons: an invented name is a table nobody checked against iconx, a missing one silently rewrites every
# oracle-cut ref that prints function() -- which is exactly how IPL ifncsgen went red at bdd554570.
INVENTED="$(comm -23 "$TMP/ours_sorted.txt" "$TMP/oracle_names.txt" | tr '\n' ' ')"
ABSENT="$(comm -13 "$TMP/ours_sorted.txt" "$TMP/oracle_names.txt" | tr '\n' ' ')"
[ -z "$INVENTED" ] || red "ARM 3: function() yields names the Icon oracle does not:$INVENTED"
[ -z "$ABSENT" ] || red "ARM 3: the Icon oracle yields names function() does not -- add them to icn_function_names[]:$ABSENT"
# -- ARM 4: BOTH DIRECTIONS, at the oracle's own arity ----------------------------------------------------
probe_one_shape() {
    printf 'procedure main()\n   %s(%s);\nend\n' "$1" "$2" > "$TMP/probe.icn"
    "$SCRIP" --run "$TMP/probe.icn" < /dev/null 2>&1 | grep -q 'scrip: error 22:' && return 1
    return 0
}
probe_dispatchable() {
    local name="$1" ar="$2" scalar="" aggregate="" i=0
    [ "$ar" -lt 0 ] && ar=1
    while [ "$i" -lt "$ar" ]; do
        scalar="$scalar${scalar:+, }1"
        if [ "$i" -eq 0 ]; then aggregate="[1]"; else aggregate="$aggregate, 1"; fi
        i=$((i+1))
    done
    probe_one_shape "$name" "$scalar" && return 0
    probe_one_shape "$name" "$aggregate" && return 0
    return 1
}
GRADED=0; MISSING_FROM_TABLE=""; NOT_DISPATCHABLE=""
while read -r name ar; do
    [ -n "$name" ] || continue
    GRADED=$((GRADED+1))
    if probe_dispatchable "$name" "$ar"; then dispatchable=1; else dispatchable=0; fi
    if grep -qx "$name" "$TMP/ours_sorted.txt"; then listed=1; else listed=0; fi
    [ "$listed" = 1 ] && [ "$dispatchable" = 0 ] && NOT_DISPATCHABLE="$NOT_DISPATCHABLE $name"
    [ "$listed" = 0 ] && [ "$dispatchable" = 1 ] && MISSING_FROM_TABLE="$MISSING_FROM_TABLE $name"
done < "$TMP/oracle_arity.txt"
[ "$GRADED" -gt 0 ] || { echo "⛔ GATE REFUSES(2): graded zero names"; exit 2; }
# ⛔ INFORMATIONAL ONLY (ceo CEO-481) -- these two lines REPORT and never red. Dispatch is a separate
# question with a separate owner; a truthful enumeration must not be blocked by an unimplemented builtin.
[ -z "$NOT_DISPATCHABLE" ] && echo "  · every yielded name dispatches at the oracle's arity" || echo "  ⚠ REPORTED, not a failure: yielded but not dispatchable (ERROR 022 at oracle arity) --$NOT_DISPATCHABLE"
[ -z "$MISSING_FROM_TABLE" ] || echo "  ⚠ REPORTED, not a failure: SCRIP dispatches these but function() does not yield them --$MISSING_FROM_TABLE"
# -- ARM 4c: hq_B's condition -- SORTED and of type string, asserted DIRECTLY IN BOTH MODES, never inferred
# from ARM 1 plus ARM 2. A generator that yields the right SET in the wrong ORDER passes declchck by luck.
cat > "$TMP/typed.icn" <<'ICN'
procedure main()
   local prev, n, c;
   prev := "";
   c := 0;
   every n := function() do {
      if type(n) ~== "string" then write("NOT-STRING ", image(n));
      if n <<= prev then write("OUT-OF-ORDER ", prev, " then ", n);
      prev := n;
      c +:= 1;
      };
   write("names=", c);
end
ICN
"$SCRIP" --run "$TMP/typed.icn" < /dev/null > "$TMP/typed.m3" 2>&1
grep -q "^names=$OURS_N$" "$TMP/typed.m3" || red "ARM 4c(m3): the ordered/typed walk counted $(grep '^names=' "$TMP/typed.m3" | head -1) against $OURS_N yielded names"
grep -qE '^(NOT-STRING|OUT-OF-ORDER)' "$TMP/typed.m3" && red "ARM 4c(m3): $(grep -E '^(NOT-STRING|OUT-OF-ORDER)' "$TMP/typed.m3" | head -3 | tr '\n' ' ')"
"$SCRIP" --compile "$TMP/typed.icn" > "$TMP/typed.s" 2>/dev/null < /dev/null
if [ -s "$TMP/typed.s" ] && gcc -no-pie "$TMP/typed.s" -L"$ROOT/out" -lscrip_rt -Wl,-rpath,"$ROOT/out" -o "$TMP/typed.bin" 2>/dev/null; then
    "$TMP/typed.bin" < /dev/null > "$TMP/typed.m4" 2>&1
    grep -q "^names=$OURS_N$" "$TMP/typed.m4" || red "ARM 4c(m4): the ordered/typed walk counted $(grep '^names=' "$TMP/typed.m4" | head -1) against $OURS_N yielded names"
    grep -qE '^(NOT-STRING|OUT-OF-ORDER)' "$TMP/typed.m4" && red "ARM 4c(m4): $(grep -E '^(NOT-STRING|OUT-OF-ORDER)' "$TMP/typed.m4" | head -3 | tr '\n' ' ')"
else
    red "ARM 4c: mode-4 compile/link of the ordered/typed witness failed"
fi
# -- ARM 5: a user-defined procedure of that name still wins, as it does on the oracle --------------------
cat > "$TMP/usr.icn" <<'ICN'
procedure function()
   return "MINE";
end
procedure main()
   write(function());
end
ICN
got="$("$SCRIP" --run "$TMP/usr.icn" < /dev/null 2>&1 | head -1)"
[ "$got" = "MINE" ] || red "ARM 5: a user-defined 'procedure function()' is shadowed by the builtin (got '$got', oracle says MINE)"
echo "ICN_FUNCTION_NAMES_GATE oracle_names=$ORACLE_N scrip_yields=$OURS_N graded=$GRADED fails=$FAIL"
[ "$FAIL" -eq 0 ] || { echo "⛔ GATE RED: $FAIL arm(s) failed"; exit 1; }
echo "✅ GATE GREEN"
