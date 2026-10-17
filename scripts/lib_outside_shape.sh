#!/usr/bin/env bash
# lib_outside_shape.sh -- THE CEO-749 SHAPE FOR A PACKAGE ROW, ONE AUTHORITY FOR EVERY RUNNER THAT PUBLISHES ONE (row
# snobol4-four-package-rows-leave-their-outside-baseline-programs-out-of-the-denominator-ceo-749, hq_snobol4 2026-09-23).
#
# CEO-749 and Lon's word of 2026-09-16 ("Get those fixed"): a program outside the SPITBOL baseline -- one the oracle itself
# cannot answer, listed in the package's OUTSIDE_SPITBOL_BASELINE.tsv -- STAYS IN ITS ROW'S DENOMINATOR, named, as debt to cure.
# The shape is PASS over SHIPPED with OUTSIDE=k named in the same row. Before this file, five package runners published
# PASS over GRADED: Gimpel 127/132 with 12 listed, Budne 71/71 with 49 listed, Flake 110/124 with 56 listed and Dotnet 5/5
# with 9 listed. TPgm's 1/8 OUTSIDE=6 had been restored BY HAND, and its own runner would have undone it on the next run.
#
# THE MECHANISM IT RIDES: util_score_row.py refuses a denominator move without a --criterion-changed stamp, and APPENDS the
# stamp to SUITES.tsv column 12; util_suite_banner.py renders the LAST OUTSIDE=N token of column 12 beside the fraction.
# So a runner owes a stamp exactly when the published total moves OR the outside count differs from the last OUTSIDE=N
# already recorded -- and owes nothing on a run that changes neither, so the criterion date is not rewritten every run.
#
# USAGE (source it, then):  stamp="$(outside_shape_stamp <suites-key> <shipped-total> <outside-count>)"
#   prints the '<YYYY-MM-DD>:<reason>' stamp when one is owed, nothing when none is. An explicit S4E_CRITERION_CHANGED
#   always wins at the call site (the runner passes ${S4E_CRITERION_CHANGED:-$stamp}).
# A missing SUITES.tsv prints a stamp (a first row always names its criterion); a malformed count REFUSES rc=2.
outside_shape_stamp() {
  local key="${1:-}" total="${2:-}" out="${3:-}" tsv prev cc last
  case "$total$out" in ''|*[!0-9]*) echo "⛔ REFUSE(2) outside_shape_stamp: total [$total] and outside [$out] must be counts" >&2; return 2;; esac
  [ -n "$key" ] || { echo "⛔ REFUSE(2) outside_shape_stamp: no suites key" >&2; return 2; }
  tsv="$(. "$(dirname "${BASH_SOURCE[0]}")/lib_suites_tsv.sh"; suites_tsv "${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}")"
  if [ -f "$tsv" ]; then
    prev="$(awk -F'\t' -v k="$key" '$1==k {print $10; exit}' "$tsv")"
    cc="$(awk -F'\t' -v k="$key" '$1==k {print $12; exit}' "$tsv")"
    last="$(printf '%s\n' "$cc" | grep -oE 'OUTSIDE=[0-9]+' | tail -1 | cut -d= -f2)"
    [ "$prev" = "$total" ] && [ "$last" = "$out" ] && return 0
  fi
  printf '%s:CEO-749-shape-pass-over-shipped-%s-with-OUTSIDE=%s-named-in-OUTSIDE_SPITBOL_BASELINE.tsv-they-stay-in-the-denominator-as-debt-to-cure' "$(date +%F)" "$total" "$out"
}

# ⛔⭐ THE CEO-1286 SHAPE (Lon 2026-09-26): a program NOT IN THE SPITBOL DIALECT -- rejected by SPITBOL, and rejected for a CSNOBOL4
# feature SPITBOL does not support, both measured, named in the package's EXCLUDED.tsv -- LEAVES THE DENOMINATOR, and the row shows
# EXCLUDED=k. A program the oracle refuses for any other cause stays (the CEO-749 shape above, unchanged for it). The published row
# is PASS over (shipped - EXCLUDED) with EXCLUDED=k in SUITES.tsv column today_excluded (util_score_row.py --excluded) and OUTSIDE=j
# still named in the stamp. A stamp is owed when the denominator moves, or the excluded count differs from the last EXCLUDED=k
# recorded (none recorded counts as different, so the first CEO-1286 write of every row stamps once), or the outside count differs.
# USAGE: stamp="$(excluded_shape_stamp <suites-key> <denominator> <outside-count> <excluded-count> [<containers>])"
# ⭐ GENERALIZED (Lon 2026-09-26, "use the Excl column to properly classify the exclusions for good reasons only"; CEO-1288): Excl is
# EVERY shipped unit the denominator leaves out, any language. With <containers> given, <excluded-count> is the row's whole Excl --
# its include fragments (CONTAINERS.tsv, CEO-1272) plus its programs not in the SPITBOL dialect (EXCLUDED.tsv) -- and the stamp
# names both classes. An <outside-count> of - is a language with no SPITBOL baseline (Icon, Prolog): no OUTSIDE token is written,
# because the grid prints the last OUTSIDE=N of a row's stamps and OUTSIDE=0 on an Icon row would be a label for nothing.
excluded_shape_stamp() {
  local key="${1:-}" total="${2:-}" out="${3:-}" exc="${4:-}" con="${5:-}" tsv prev cc lasto laste oc
  [ "$out" = - ] && oc="" || oc="$out"
  case "$total$oc$exc$con" in ''|*[!0-9]*) echo "⛔ REFUSE(2) excluded_shape_stamp: denominator [$total], outside [$out], excluded [$exc] and containers [$con] must be counts (outside may be -)" >&2; return 2;; esac
  [ -n "$oc" ] || [ -n "$con" ] || { echo "⛔ REFUSE(2) excluded_shape_stamp: an outside of - is a language with no SPITBOL baseline, and only a row that names its containers has one" >&2; return 2; }
  [ -z "$con" ] || [ "$con" -le "$exc" ] || { echo "⛔ REFUSE(2) excluded_shape_stamp: containers [$con] exceed the row's whole Excl [$exc] -- Excl is containers plus EXCLUDED.tsv" >&2; return 2; }
  [ -n "$key" ] || { echo "⛔ REFUSE(2) excluded_shape_stamp: no suites key" >&2; return 2; }
  tsv="$(. "$(dirname "${BASH_SOURCE[0]}")/lib_suites_tsv.sh"; suites_tsv "${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}")"
  if [ -f "$tsv" ]; then
    prev="$(awk -F'\t' -v k="$key" '$1==k {print $10; exit}' "$tsv")"
    cc="$(awk -F'\t' -v k="$key" '$1==k {print $12; exit}' "$tsv")"
    lasto="$(printf '%s\n' "$cc" | grep -oE 'OUTSIDE=[0-9]+' | tail -1 | cut -d= -f2)"
    laste="$(printf '%s\n' "$cc" | grep -oE 'EXCLUDED=[0-9]+' | tail -1 | cut -d= -f2)"
    [ "$prev" = "$total" ] && [ "$lasto" = "$oc" ] && [ "$laste" = "$exc" ] && return 0
  fi
  if [ -z "$con" ]; then
    printf '%s:CEO-1286-shape-pass-over-shipped-minus-EXCLUDED=%s-not-in-the-SPITBOL-dialect-named-in-EXCLUDED.tsv-denominator-%s-with-OUTSIDE=%s-spitbol-programs-the-oracle-refuses-kept-as-debt' "$(date +%F)" "$exc" "$total" "$out"
  else
    printf '%s:CEO-1288-Excl-classified-EXCLUDED=%s-every-shipped-unit-the-denominator-%s-leaves-out-%s-include-fragments-named-in-CONTAINERS.tsv-and-%s-not-in-the-SPITBOL-dialect-named-in-EXCLUDED.tsv%s' "$(date +%F)" "$exc" "$total" "$con" "$((exc - con))" "${oc:+-with-OUTSIDE=$oc-spitbol-programs-the-oracle-refuses-kept-as-debt}"
  fi
}
# excluded_in_outside <pkgdir> "<names of THIS run's outside set, one per line or space, with or without extension or _driver>"
# -- prints how many EXCLUDED.tsv programs are in that live set: the count the row subtracts. A name compares by its stem (extension
# and a _driver suffix stripped on both sides, because gimpel's outside set names drivers and its EXCLUDED.tsv names libraries).
# rc 2 when the sidecar is malformed. Names in EXCLUDED.tsv that the live set does not carry are printed on stderr as NOT-OUTSIDE-
# THIS-RUN: either they ship without a graded pair (never in the population, csnobol4_suite's 14) or the oracle now RUNS them, in
# which case the first half of Lon's test no longer holds and the row is removed by hand -- the gate reads the sidecar against
# OUTSIDE_SPITBOL_BASELINE.tsv for that.
excluded_in_outside() {
  local d="${1:-}" live="${2:-}" n stem l ls hit=0 miss=""
  [ -d "$d" ] || { echo "⛔ REFUSE(2) excluded_in_outside: $d is not a directory" >&2; return 2; }
  . "$(dirname "${BASH_SOURCE[0]}")/lib_inventory.sh" 2>/dev/null || true
  local names; names="$(inventory_excluded_names "$d")" || return 2
  for n in $names; do
    stem="${n##*/}"; stem="${stem%.*}"; stem="${stem%_driver}"
    local found=0
    for l in $live; do ls="${l##*/}"; ls="${ls%.*}"; ls="${ls%_driver}"; [ "$ls" = "$stem" ] && { found=1; break; }; done
    if [ "$found" = 1 ]; then hit=$((hit + 1)); else miss="$miss $n"; fi
  done
  [ -z "$miss" ] || echo "EXCLUDED.tsv NOT-OUTSIDE-THIS-RUN (not in this run's population, or the oracle now runs them):$miss" >&2
  echo "$hit"
}
excluded_names_count() { local n; n="$(inventory_excluded_names "${1:-}")" || return 2; printf '%s\n' "$n" | grep -c . || true; }
