#!/usr/bin/env bash
# test_gate_suite_banner_check_writes_nothing_and_render_is_scoped.sh -- THE SUITE TABLE CAN BE CHECKED WITHOUT BEING WRITTEN, AND
# A RENDER TOUCHES ONLY THE ROW ITS CALLER MEASURED (coo 2026-09-16; hq_raku's finding; row util-suite-banner-render-rewrites-rows-
# a-seat-did-not-measure-and-there-is-no-check-mode-that-writes-nothing).
#
# THE DEFECT: util_suite_banner.py --render re-rendered EVERY suite-table row of SCORE.md from the local SUITES.tsv, so a seat
# reaching for it to VERIFY agreement after a rebase rewrote rows it never measured (Zona 88/88 -> 88/90, Jcon, SnoRungs' OUTSIDE=8
# clause dropped), twice; and the only way to ask whether the two files agreed was the command that made them agree.
#
# THE CURE UNDER TEST (util_suite_banner.py): --check prints every disagreement side by side and writes nothing (rc 1 on a
# disagreement, 0 agree, 2 no table); --render refuses rc=2 without --all-rows or --only KEY and writes nothing; --render --only KEY
# rewrites that one display row and no other; the rendered result cell carries the last OUTSIDE=N token of the row's criterion stamp.
#
# ARMS (scratch copies of the live SUITES.tsv + SCORE.md under mktemp; the live files are never touched):
#   (a) SCORE.md's row for one suite hand-staled: --check exits 1 naming that key, both files byte-identical after
#   (b) --render with no scope: rc=2, both files byte-identical
#   (c) --render --only <key>: exactly that display row changes, every other line of SCORE.md byte-identical; --check then agrees on it
#   (d) a TSV row whose criterion stamp ends 'OUTSIDE=7' renders its result cell as 'pass/total OUTSIDE=7' (with EXCLUDED=k between them when the row carries today_excluded, CEO-1286, and WALL=<n>s after it when the row carries today_secs, CEO-1562)
# FAIL_ONCE=1 runs arm (a)'s check on an AGREEING pair so the expected disagreement never comes, proving the arm trips.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; GH="$HERE/../../.github"; B="$GH/scripts/util_suite_banner.py"
. "$(dirname "${BASH_SOURCE[0]}")/lib_suites_tsv.sh" || { echo "REFUSED(2): cannot load lib_suites_tsv.sh"; exit 2; }
refuse(){ echo "⛔ REFUSED-TO-GRADE: $*"; exit 2; }
[ -f "$B" ] && [ -f "$SUITES_TSV_REAL" ] && [ -f "$GH/SCORE.md" ] || refuse "need $B, SUITES.tsv and SCORE.md"
W="$(mktemp -d "${TMPDIR:-/tmp}/gate_banner_check.XXXXXX")" || refuse "mktemp failed"; trap 'rm -rf "$W"' EXIT
TSV="$W/SUITES.tsv"; MD="$W/SCORE.md"
run(){ S4E_SUITES_TSV="$TSV" S4E_SCORE_MD="$MD" python3 "$B" "$@" 2>&1; }
fresh(){ cp "$SUITES_TSV_REAL" "$TSV"; cp "$GH/SCORE.md" "$MD"; S4E_SUITES_TSV="$TSV" S4E_SCORE_MD="$MD" python3 "$B" --render --all-rows >/dev/null 2>&1 || refuse "could not bring the scratch pair to agreement"; }
KEY=gimpel; NICK="$(awk -F'\t' -v k="$KEY" '!/^#/ && $1==k{print $2; exit}' "$SUITES_TSV_REAL")"; [ -n "$NICK" ] || refuse "no row $KEY in SUITES.tsv"
fails=0; checks=0; ck(){ checks=$((checks+1)); if [ "$1" = ok ]; then printf '  ok    %s\n' "$2"; else printf '  FAIL  %s\n' "$2"; fails=$((fails+1)); fi; }
echo "=== gate: --check writes nothing, --render is scoped (hq_raku 2026-09-16) ==="
fresh; out="$(run --check)"; rc=$?
[ "$rc" = 0 ] && ck ok "(0) a freshly rendered pair: --check agrees rc=0 (population printed: $(grep -o 'population: [0-9]*' <<<"$out"))" || ck no "(0) rc=$rc on an agreeing pair -- got: $(tail -2 <<<"$out")"
# (a) hand-stale the display row for KEY (unless FAIL_ONCE, which leaves the pair agreeing)
[ -z "${FAIL_ONCE:-}" ] && sed -i "s/^| $NICK | \([a-z0-9]*\) | [0-9]*\/[0-9]*/| $NICK | \1 | 1\/999/" "$MD"
m0="$(cat "$TSV" "$MD" | md5sum)"; out="$(run --check)"; rc=$?; m1="$(cat "$TSV" "$MD" | md5sum)"
[ "$rc" = 1 ] && [ "$m0" = "$m1" ] && grep -q "^DISAGREE $KEY:" <<<"$out" && ck ok "(a) a hand-staled display row: --check exits 1 naming $KEY and writes nothing" || ck no "(a) rc=$rc identical=$([ "$m0" = "$m1" ] && echo yes || echo no) -- got: $(grep -E 'DISAGREE|population' <<<"$out" | head -2)"
out="$(run --render)"; rc=$?; m2="$(cat "$TSV" "$MD" | md5sum)"
[ "$rc" = 2 ] && [ "$m1" = "$m2" ] && grep -q 'NOTHING WAS WRITTEN' <<<"$out" && ck ok "(b) --render with no scope: REFUSED rc=2, both files byte-identical" || ck no "(b) rc=$rc identical=$([ "$m1" = "$m2" ] && echo yes || echo no) -- got: $(tail -1 <<<"$out" | cut -c1-160)"
cp "$MD" "$W/before_only.md"; out="$(run --render --only "$KEY")"; rc=$?
nd="$(diff "$W/before_only.md" "$MD" | grep -c '^>')"; out2="$(run --check)"; rc2=$?
[ "$rc" = 0 ] && [ "$nd" = 1 ] && ! grep -q "^DISAGREE $KEY:" <<<"$out2" && ck ok "(c) --render --only $KEY rewrote exactly one line of SCORE.md (that row) and --check no longer names it" || ck no "(c) rc=$rc lines-changed=$nd check-rc=$rc2"
python3 - "$TSV" "$KEY" <<'PY'
import sys
p,k=sys.argv[1],sys.argv[2]; L=open(p,encoding='utf-8').read().split('\n')
for i,l in enumerate(L):
    if l.startswith(k+'\t'):
        f=l.split('\t'); f[11]=(f[11]+' | ' if f[11] else '')+'2026-09-16:gate fixture OUTSIDE=7'; L[i]='\t'.join(f)
open(p,'w',encoding='utf-8').write('\n'.join(L))
PY
out="$(run --md)"; grep -qE "^\| $NICK \| [a-z0-9]+ \| [0-9]+/[0-9]+( EXCLUDED=[0-9]+)? OUTSIDE=7( WALL=[0-9]+s)? \|" <<<"$out" && ck ok "(d) a criterion stamp ending OUTSIDE=7 renders the result cell as pass/total OUTSIDE=7" || ck no "(d) rendered row: $(grep "^| $NICK " <<<"$out" | cut -c1-120)"
echo "population: $checks arm(s) graded, $fails FAIL"
[ "$fails" = 0 ] && { echo "GATE PASS [suite_banner_check_writes_nothing_and_render_is_scoped]: $checks of $checks arms hold"; exit 0; }
echo "⛔ GATE RED [suite_banner_check_writes_nothing_and_render_is_scoped]: $fails of $checks arms FAIL"; exit 1
