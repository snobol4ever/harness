#!/usr/bin/env bash
# test_gate_lib_rungs_extract_refuses_without_a_language.sh -- lib_rungs_extract.sh HAS NO DEFAULT RUNGS: unset RUNGS_DIR and
# no RUNGS_LANG is a REFUSAL rc=2, never a quiet snobol4 (coo 2026-09-16; hq_snocone's witness, hq_pascal's precedent lib_ladder.sh
# line 49; row lib-master-extract-defaults-master-dir-to-the-snobol4-master-when-unset-instead-of-refusing).
#
# THE DEFECT: line 72 read RUNGS_DIR from the environment OR ELSE defaulted to corpus/tests/snobol4, so a consumer that forgot to
# set it graded the SNOBOL4 rungs and said nothing; entry names collide across rung suites, so the wrong-language answer was
# well-formed and plausible (hq_snocone's named-entry arm: three Snocone entries read as SNOBOL4 entries of the same name).
#
# ARMS: (a) RUNGS_DIR and RUNGS_LANG both unset: sourcing refuses rc=2 naming both variables; (b) RUNGS_LANG=icon derives
# corpus/tests/icon and ALL.icn; (c) RUNGS_DIR set explicitly is honoured as given; (d) an unknown RUNGS_LANG refuses rc=2;
# (e) CENSUS: every script that sources the library sets RUNGS_DIR or RUNGS_LANG (inline or before), printed as a count.
# FAIL_ONCE=1 plants one consumer without either variable into the census farm, to prove arm (e) trips.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; LIB="$HERE/lib_rungs_extract.sh"
[ -f "$LIB" ] || { echo "⛔ REFUSED-TO-GRADE: no $LIB"; exit 2; }
fails=0; checks=0; ck(){ checks=$((checks+1)); if [ "$1" = ok ]; then printf '  ok    %s\n' "$2"; else printf '  FAIL  %s\n' "$2"; fails=$((fails+1)); fi; }
echo "=== gate: lib_rungs_extract has no default rungs ==="
out="$(env -u RUNGS_DIR -u RUNGS_LANG bash -c ". '$LIB'" 2>&1)"; rc=$?
[ "$rc" = 2 ] && grep -q 'RUNGS_DIR' <<<"$out" && grep -q 'RUNGS_LANG' <<<"$out" && ck ok "(a) both unset: REFUSED rc=2 naming RUNGS_DIR and RUNGS_LANG" || ck no "(a) rc=$rc -- got: $(head -1 <<<"$out" | cut -c1-140)"
out="$(env -u RUNGS_DIR RUNGS_LANG=icon bash -c ". '$LIB' && printf '%s\n%s\n' \"\$RUNGS_DIR\" \"\$RUNGS_SNO\"" 2>&1)"; rc=$?
[ "$rc" = 0 ] && grep -q 'corpus/tests/icon$' <<<"$out" && grep -q 'ALL\.icn$' <<<"$out" && ck ok "(b) RUNGS_LANG=icon derives corpus/tests/icon and ALL.icn" || ck no "(b) rc=$rc -- got: $out"
out="$(env -u RUNGS_LANG RUNGS_DIR=/tmp/explicit-rungs bash -c ". '$LIB' && printf '%s\n' \"\$RUNGS_SNO\"" 2>&1)"; rc=$?
[ "$rc" = 0 ] && [ "$(tail -1 <<<"$out")" = "/tmp/explicit-rungs/ALL.sno" ] && ck ok "(c) an explicit RUNGS_DIR is honoured as given" || ck no "(c) rc=$rc -- got: $out"
out="$(env -u RUNGS_DIR RUNGS_LANG=cobol bash -c ". '$LIB'" 2>&1)"; rc=$?
[ "$rc" = 2 ] && grep -q "cobol" <<<"$out" && ck ok "(d) an unknown RUNGS_LANG refuses rc=2 naming it" || ck no "(d) rc=$rc -- got: $(head -1 <<<"$out" | cut -c1-120)"
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT; cp "$HERE"/*.sh "$W"/ 2>/dev/null
[ -n "${FAIL_ONCE:-}" ] && printf '#!/usr/bin/env bash\n. "$(dirname "$0")/lib_rungs_extract.sh"\n' > "$W/zz_planted_consumer.sh"
missing=""; n=0
for f in "$W"/*.sh; do
  b="$(basename "$f")"; [ "$b" = lib_rungs_extract.sh ] && continue
  grep -v '^\s*#' "$f" | grep -q 'lib_rungs_extract' || continue
  n=$((n+1))
  grep -qE 'RUNGS_DIR=|RUNGS_LANG=' "$f" || missing="$missing $b"
done
[ -z "$missing" ] && ck ok "(e) CENSUS: all $n consumers set RUNGS_DIR or RUNGS_LANG before sourcing" || ck no "(e) CENSUS: $n consumers, these rely on a default that no longer exists:$missing"
echo "population: $checks arm(s) graded, $fails FAIL; consumers: $n"
[ "$fails" = 0 ] && { echo "GATE PASS [lib_rungs_extract_refuses_without_a_language]: $checks of $checks arms hold"; exit 0; }
echo "⛔ GATE RED [lib_rungs_extract_refuses_without_a_language]: $fails of $checks arms FAIL"; exit 1
