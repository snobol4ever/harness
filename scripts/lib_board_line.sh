#!/usr/bin/env bash
# lib_board_line.sh -- THE ONE WAY TO READ A FIELD OUT OF A SUITE_BOARD LINE (coo, CEO-839).
#
# ⛔ EXTRACTION ANCHORS ON IDENTITY, NEVER POSITION (RULES.md INSTRUMENT LAWS).  A check that greps
# 'total=2 m3_n=2' asserts that nothing sits BETWEEN those two fields, which is a claim about the board's
# layout and not about its numbers.  SCRIP 3ade619f2 inserted `shipped=` and `outside=` there (CEO-749/772)
# and test_gate_harness_refusal_is_rc2.sh arm 9 went red against a CORRECT board and stayed red for a day,
# reporting it as "no board over the 2 entries" -- the failure mode reads like the run graded nothing rather
# than like the pattern is stale.  util_board_field_matcher_census.py counts what is left; this is what they
# are cured TO.  Source it, never copy it (the tree already carried two divergent hand-rolled readers).
#
#   board_field <line> <name>   -> the field's value on stdout, rc=0; rc=1 and empty when the field is absent
#   board_has   <line> <name>   -> rc=0 when the field is present at all (a field may legitimately be 0)
#   board_is    <line> <name> <want> -> rc=0 when present AND equal
#
# A NAME MATCHES WHOLE: `m3_n` never matches inside `m3_n_something`, and `n` never matches inside `m3_n`,
# because the field is read as a word-bounded NAME=VALUE token.  An absent field is rc=1, NEVER the empty
# string treated as 0 -- "the board does not print this field" and "the board prints zero" are different
# readings and a comparison that conflates them is the same silent staleness one indirection out.

board_field() {
    local line="$1" name="$2" v
    v="$(printf '%s\n' "$line" | grep -oE "(^|[[:space:]])${name}=[^[:space:]]+" | head -1 | cut -d= -f2-)"
    [ -n "$v" ] || return 1
    printf '%s' "$v"
}

board_has() {
    printf '%s\n' "$1" | grep -qE "(^|[[:space:]])${2}=[^[:space:]]+"
}

board_is() {
    local got
    got="$(board_field "$1" "$2")" || return 1
    [ "$got" = "$3" ]
}
