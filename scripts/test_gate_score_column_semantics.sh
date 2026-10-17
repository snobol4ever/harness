#!/usr/bin/env bash
# test_gate_score_column_semantics.sh — every runner a SCORE.md grid cell cites must be of that COLUMN'S KIND:
# M cites a rung suite runner, L a ladder runner, V a package/conformance runner.
#
# ⛔⭐ THIS IS THE CLASS NO READABILITY CHECK REACHES (ceo ruling 2026-09-03 22:39, minted after hq_T published
# `reb 100%` on the live leaderboard). That number came from a markdown-row "|"-split off-by-one that wrote the
# Rebus LADDER census into the RUNGS column. The fail-closed readability guard in util_score_row.py could not
# help: "11 witnesses, 22/22 both modes" is a WELL-FORMED population in a cell that is ALLOWED to contain one.
# The cell was READABLE AND WRONG -- and no parse rule reaches that, because parsing is exactly what it passes.
# What catches it is knowing what the COLUMN MEANS. Proven against the real defect: reconstructing the slip on
# a scratch copy of the board fires rc=1 naming the cell and the offending citation.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec python3 "$HERE/util_score_row.py" columns
