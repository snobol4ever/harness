#!/usr/bin/env bash
export S4E_DB_CHECK_OVERRIDE="gate fixture: this gate plants no progress rows (util_score_row.py db_crosscheck, hq_raku 2026-09-16)"
# test_gate_score_tables_agree.sh — SCORE.md's two tables must agree BY VALUE (ceo approval 2026-09-03).
# The September-10 grid and the standardized display describe the same measurements; `util_score_row.py write`
# updates only the display, so a grid cell goes stale the moment a runner records a row and NOTHING SAYS SO.
#
# ⛔⭐ IT COMPARES VALUES, NEVER DATES, and that is the whole design. Same-day staleness is invisible to a
# freshness check by construction: the raku M cell carried TODAY'S date beside a SUPERSEDED number, because the
# date was written by an earlier measurement that really was today. A timestamp cannot separate "true and
# current" from "true this morning"; only the numbers can.
#
# TWO SIGNAL STRENGTHS, deliberately not conflated: a SAME-DENOMINATOR conflict (both tables name an
# 81-population, one says 39 and the other 41) is unambiguous -- one is wrong and a reader cannot tell which --
# and FAILS. A population present in only one table is the dual-write gap, reported as debt rather than failed,
# because the two tables legitimately summarise at different grains and convicting on that would red the board
# for a design choice.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec python3 "$HERE/util_score_row.py" agree
