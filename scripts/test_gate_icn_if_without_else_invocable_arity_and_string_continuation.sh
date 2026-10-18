#!/usr/bin/env bash
# test_gate_icn_if_without_else_invocable_arity_and_string_continuation.sh -- hq_I 2026-09-06, OCTET rows
# icon-ipl-if-then-with-no-else-is-a-parse-error-in-expression-position,
# icon-ipl-invocable-with-an-operator-string-and-arity-suffix-is-a-parse-error,
# icon-ipl-underscore-line-continuation-inside-a-string-literal-is-not-implemented.
#
# WHAT IT PINS -- three Icon surface-syntax classes the IPL package exposed, all three graded against the
# LIVE ORACLE rather than against a typed expectation, and all three in BOTH modes.
#
# 1. `if e1 then e2` WITH NO else. The cure touches BOTH if-sites -- parse_ctrl (expression position, where the bug bit) and parse_stmt (statement position, where the trailing match already absorbed the semicolon so behaviour is unchanged) -- so if_statement_position_control grades the second site rather than merely asserting it was safe. parse_ctrl() ate a TK_SEMICOL after the then-branch
#    so that `if a then b; else c` would work; with no else that semicolon WAS the statement terminator, and
#    the caller then reported `expected ; (got <next line's first token>)` -- a diagnostic pointing one line
#    PAST the construct it was complaining about, which is why it read as a mystery for so long. The cure
#    consumes the semicolon only when p->peek is TK_ELSE.
# 2. `invocable "op":n`. The entry loop broke at the colon, so the top-level loop restarted on `:` and said
#    `expected procedure, record, global, link, or invocable`.
# 3. A trailing `_` inside a "..." literal continues the string: the underscore, the newline, and the next
#    line's leading whitespace are all dropped.
#
# ⛔⭐ EVERY ARM CARRIES ITS CONTROL, AND THAT IS THE POINT. Each of the three cures makes a parser accept
# something it used to reject -- the cheap way for such a cure to be wrong is to ALSO change the construct it
# was already getting right. So `if/then/else` is graded beside `if/then`, `invocable a, b` beside
# `invocable "op":n`, and an interior `_` (which must stay a literal underscore) beside a trailing one. An
# arm with no control proves the new case works and says nothing about the 99 percent that already did.
#
# ⛔ THE ORACLE IS THE REFERENCE, NEVER A TYPED STRING. icont/iconx are reached through lib_oracle_flags.sh
# (never `command -v`, never a hardcoded path). If the oracle is unreachable this gate REFUSES rc=2 -- it
# never skips-as-success, because a gate that cannot measure must not print the success shape.
# ⛔⭐ MEASURED WHILE WRITING THIS GATE, AND IT INVERTS THE REASON THE BUG EXISTED. The semicolon-eating line
# was there to accept `if a then b; else c` -- and the ORACLE REJECTS THAT FORM outright ("else": invalid
# expression). So the swallow was serving a construct real Icon does not have, while breaking one it does.
# SCRIP still accepts it (the guard consumes the semicolon when the next token is `else`), which is a
# harmless over-acceptance and NOT a regression of this cure -- it is deliberately not pinned here, because
# a gate that pins an over-acceptance freezes it. Recorded so the next reader does not "restore" the swallow.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
SCRIP="${SCRIP:-$ROOT/scrip}"
. "$HERE/lib_oracle_flags.sh" 2>/dev/null || { echo "⛔ REFUSED(2): lib_oracle_flags.sh unloadable" >&2; exit 2; }
ICONT="$(icont_bin 2>/dev/null)"; [ -x "$ICONT" ] || { echo "⛔ REFUSED(2): no icont oracle at '${ICONT:-<empty>}'" >&2; exit 2; }
[ -x "$SCRIP" ] || { echo "⛔ REFUSED(2): no scrip binary at $SCRIP -- run make" >&2; exit 2; }
"$HERE/util_require_fresh.sh" --gate test_gate_icn_if_without_else_invocable_arity_and_string_continuation \
    "$SCRIP" "$ROOT/out/libscrip_rt.so" || exit 2

WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT
PASS=0; FAIL=0; GRADED=0
# ⛔ Programs are written by a QUOTED heredoc (<<'ICN'). An unquoted one hands the shell every backtick and
# every $ in the Icon source -- the exact trap this root's digest records being hit three times in one hour.
run_case() { # name <<program
    local name="$1"; local src="$WORK/$name.icn"; cat > "$src"
    GRADED=$((GRADED+1))
    local exp scrip3 scrip4 orc
    orc="$WORK/$name.oracle"
    ( cd "$WORK" && "$ICONT" -s "$name.icn" -x ) > "$orc" 2>&1; local orc_rc=$?
    if [ "$orc_rc" -ne 0 ]; then
        echo "⛔ REFUSED(2): oracle itself failed on $name (rc=$orc_rc) -- the case is malformed, not the compiler" >&2
        cat "$orc" >&2; exit 2
    fi
    exp="$(cat "$orc")"
    scrip3="$(cd "$WORK" && timeout -k 5 20 "$SCRIP" --run "$src" < /dev/null 2>&1)"
    local m4bin="$WORK/$name.bin" m4s="$WORK/$name.s" ok4=1
    if ! ( cd "$WORK" && timeout -k 5 40 "$SCRIP" --compile "$src" -o "$m4s" < /dev/null ) >/dev/null 2>&1 \
       || ! gcc -no-pie "$m4s" -L"$ROOT/out" -lscrip_rt -Wl,-rpath,"$ROOT/out" -o "$m4bin" 2>/dev/null; then
        ok4=0; scrip4="<compile/link failed>"
    else
        scrip4="$(cd "$WORK" && timeout -k 5 20 "$m4bin" < /dev/null 2>&1)"
    fi
    if [ "$scrip3" = "$exp" ] && [ "$ok4" -eq 1 ] && [ "$scrip4" = "$exp" ]; then
        PASS=$((PASS+1)); printf '  ok   %-34s m3+m4 == oracle\n' "$name"
    else
        FAIL=$((FAIL+1)); printf '  FAIL %-34s\n' "$name"
        printf '       oracle: %s\n' "$(printf '%s' "$exp"    | head -3 | tr '\n' '|')"
        printf '       m3    : %s\n' "$(printf '%s' "$scrip3" | head -3 | tr '\n' '|')"
        printf '       m4    : %s\n' "$(printf '%s' "$scrip4" | head -3 | tr '\n' '|')"
    fi
}

echo "-- 1. if/then with no else, in expression position (and its if/then/else control) --"
run_case if_noelse_taken <<'ICN'
procedure main()
   local x;
   x := "unset";
   x := if 1 = 1 then "taken";
   write(x);
end
ICN
run_case if_noelse_failed <<'ICN'
procedure main()
   local x;
   x := "unset";
   x := if 1 = 2 then "taken";
   write(x);
end
ICN
run_case if_withelse_control <<'ICN'
procedure main()
   local x;
   x := if 1 = 2 then "taken" else "other";
   write(x);
end
ICN
run_case if_noelse_nested_in_scan <<'ICN'
procedure main()
   local x;
   x := "unset";
   "abcd" ? x := if ="ab" then "matched";
   write(x);
end
ICN

run_case if_statement_position_control <<'ICN'
procedure main()
   local i, n;
   n := 0;
   every i := 1 to 4 do {
      if i = 2 then write("two");
      if i = 3 then write("three") else write("not3");
      n +:= 1;
   };
   write("n=", n);
   if n = 4 then write("four");
end
ICN

echo "-- 2. invocable \"op\":arity (and the plain invocable control) --"
run_case invocable_op_arity <<'ICN'
invocable "=":1
procedure main()
   write("invocable-op-arity-parsed");
end
ICN
run_case invocable_plain_control <<'ICN'
invocable all
procedure main()
   write("invocable-plain-parsed");
end
ICN

echo "-- 3. trailing _ line continuation inside a string (and its interior-underscore control) --"
run_case string_continuation <<'ICN'
procedure main()
   write("abc_
      def");
end
ICN
run_case string_continuation_interior_control <<'ICN'
procedure main()
   write("abc_def");
end
ICN
run_case string_continuation_twice <<'ICN'
procedure main()
   write("one_
     two_
         three");
end
ICN

echo ""
echo "ICN_SURFACE_SYNTAX_GATE graded=$GRADED pass=$PASS fail=$FAIL (m3+m4, each against the live icont oracle)"
if [ "$GRADED" -eq 0 ]; then echo "⛔ REFUSED(2): graded zero cases" >&2; exit 2; fi
[ "$FAIL" -eq 0 ] || exit 1
