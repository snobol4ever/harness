#!/usr/bin/env bash
# test_gate_rungs_builder_reindex_only.sh -- ACCEPTANCE GATE for util_build_rungs_suite.py --reindex.
# Row master-builder-needs-a-csv-only-reindex-path (ceo mint 2026-09-03, on hq_B's measured gap).
#
# THE GAP: ALL.csv is a DERIVED index, and until now the only way to rebuild it also ABSORBED whatever loose
# pairs happened to be present (prolog 404 -> 408). So a promotion that changes program text had two bad
# options: hand-edit the index, or take an unrelated absorption as a side effect of re-indexing it.
#
# WHAT THIS PROVES:
#   (a) IDENTITY -- on an unmodified tree, --reindex reproduces the committed ALL.csv BYTE-IDENTICALLY.
#       This is the row's own oracle: a correct hand-edit must survive a re-index unchanged.
#   (b) IT ACTUALLY RECOMPUTES -- corrupt one derived cell and --reindex restores it. Without this arm (a)
#       would pass against an implementation that simply copied the file, which is the failure mode a
#       round-trip test invites.
#   (c) CSV-ONLY -- ALL.pl, ALL.ref and every sidecar are byte-identical afterwards. The mode's whole promise.
#   (d) REFUSES rc=2 on an unacknowledged loose pair: an index current for the rungs and silent about
#       unabsorbed sources reads as "everything is accounted for".
#   (e) REFUSES rc=2 when combined with a flag that describes absorption -- a flag that silently means
#       nothing is how a caller believes a run did something it never attempted.
#   (f) CRLF SURVIVES. ALL.csv is CRLF; Python's default universal-newline read+write silently rewrites it to
#       LF, which is invisible to git's text diff and to `file`, and turns a one-cell edit into a whole-file
#       conflict (hq_C measured exactly that on rung 3, 401 lines for one flag). Only od/numstat sees it.
# ⛔ HERMETIC: every arm runs against a COPY of the corpus under a scratch S4E_HOME. The real tree is read once
# to make that copy and never written.
# SUT= overrides the builder under test, so this gate can be proven to FAIL against the pre-reindex version.
set -uo pipefail
# ⭐ PROLOG AND RAKU BY DEFAULT (the coo 2026-10-10, row instruments-the-raku-rungs-regex-attribute-column-marks-3-of-74-...): raku's ALL.csv
# is the area smoke's selector for the regex roll-out, so its index is held to the builder that derives it beside prolog's, in ONE recipe
# line (util_gate_wiring.py doubles: one line per script). LANG_T names one language and runs only that. A red outranks a refusal.
if [ -z "${LANG_T:-}" ]; then
  red=0; refused=0
  for spec in prolog:.pl raku:.raku; do
    LANG_T="${spec%%:*}" EXT_T="${spec#*:}" bash "${BASH_SOURCE[0]}" "$@"; r=$?
    [ "$r" = 1 ] && red=1; [ "$r" -ge 2 ] && refused=1
  done
  [ "$red" = 1 ] && exit 1; [ "$refused" = 1 ] && exit 2; exit 0
fi
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
S4E_REAL="${S4E_HOME:-$(cd "$ROOT/.." && pwd)}"
SUT="${SUT:-$HERE/util_build_rungs_suite.py}"
LANG_T="${LANG_T:-prolog}"; EXT_T="${EXT_T:-.pl}"
refuse(){ echo "⛔ REFUSED-TO-GRADE: $*"; exit 2; }
[ -f "$SUT" ] || refuse "builder under test not found: $SUT"
SRC="$S4E_REAL/corpus/tests/$LANG_T"
[ -f "$SRC/ALL.csv" ] && [ -f "$SRC/ALL$EXT_T" ] || refuse "no $LANG_T rungs under $SRC"
W="$(mktemp -d "${TMPDIR:-/tmp}/gate_reindex.XXXXXX")" || refuse "mktemp failed"
trap 'rm -rf "$W"' EXIT
cp -a "$S4E_REAL/corpus" "$W/corpus" || refuse "could not copy the corpus into the scratch tree"
T="$W/corpus/tests/$LANG_T"
fails=0; checks=0
ck(){ checks=$((checks+1)); if [ "$1" = ok ]; then printf '  ok    %s\n' "$2"; else printf '  FAIL  %s\n' "$2"; fails=$((fails+1)); fi; }
run(){ S4E_HOME="$W" python3 "$SUT" --lang "$LANG_T" --reindex "$@" 2>&1; }
# The loose families are DISCOVERED from the tree under test, never typed here: a hard-coded roster drifts
# from the corpus and then the gate and the tree are wrong together.
ACK="$(run 2>&1 | sed -n 's/^     \([a-z0-9_]*\)$/\1/p' | paste -sd, -)"
echo "=== gate: util_build_rungs_suite.py --reindex (lang=$LANG_T) ==="
echo "--- (d) unacknowledged loose pair REFUSES ---"
if [ -n "$ACK" ]; then
  out="$(run)"; rc=$?
  [ "$rc" -eq 2 ] && ck ok "loose pair present -> rc=2 (got $rc)" || ck no "loose pair present must exit rc=2, got $rc"
  grep -q 'REFUSED' <<<"$out" && ck ok "refusal says REFUSED and names the families" || ck no "refusal must say REFUSED"
  cmp -s "$SRC/ALL.csv" "$T/ALL.csv" && ck ok "refusal wrote nothing" || ck no "a refusal must not have written ALL.csv"
else
  ck ok "no loose pairs in this tree -- arm (d) not applicable, acknowledged"
fi
ACKARG=(); [ -n "$ACK" ] && ACKARG=(--absorb-only "$ACK")
echo "--- (a) identity + (c) CSV-only + (f) CRLF ---"
crlf_before="$(grep -c $'\r$' "$T/ALL.csv" || true)"
md_pl_before="$(md5sum < "$T/ALL$EXT_T")"; md_ref_before="$(md5sum < "$T/ALL.ref")"
out="$(run "${ACKARG[@]}")"; rc=$?
[ "$rc" -eq 0 ] && ck ok "reindex on an unmodified tree exits 0 (got $rc)" || { ck no "reindex must exit 0, got $rc"; echo "$out" | sed 's/^/      /' | tail -4; }
cmp -s "$SRC/ALL.csv" "$T/ALL.csv" && ck ok "(a) ALL.csv reproduced BYTE-IDENTICALLY" || ck no "(a) ALL.csv changed on an unmodified tree -- the committed index and the builder disagree"
[ "$md_pl_before" = "$(md5sum < "$T/ALL$EXT_T")" ] && ck ok "(c) ALL$EXT_T untouched" || ck no "(c) ALL$EXT_T was modified -- --reindex must write ONLY ALL.csv"
[ "$md_ref_before" = "$(md5sum < "$T/ALL.ref")" ] && ck ok "(c) ALL.ref untouched" || ck no "(c) ALL.ref was modified -- --reindex must write ONLY ALL.csv"
[ "$(grep -c $'\r$' "$T/ALL.csv" || true)" = "$crlf_before" ] && ck ok "(f) CRLF preserved ($crlf_before lines)" || ck no "(f) CRLF lost: $crlf_before -> $(grep -c $'\r$' "$T/ALL.csv" || true) (universal-newline rewrite)"
echo "--- (b) it RECOMPUTES, it does not copy ---"
# ⛔ THIS ARM READS THE CELL IT CORRUPTED, never byte-equality with the committed index (coo 2026-09-19,
# row instrument-the-nineteen-non-gc-blocking-arms). cmp against $SRC/ALL.csv CONFLATED (b) with (a):
# when the committed index disagrees with the builder for any OTHER reason, cmp fails even though the
# corrupted cell WAS recomputed correctly, and the arm then reported "copying, not recomputing" -- a
# false cause naming the wrong mechanism. That was the live case: prolog's committed rank column was
# stale, so (b) accused the builder of copying while it was recomputing the cell perfectly.
cell_n_lines() { python3 -c 'import csv,io,sys; rows=list(csv.reader(io.open(sys.argv[1],newline=""))); print(rows[1][rows[0].index("n_lines")])' "$1"; }
b_true="$(cell_n_lines "$T/ALL.csv")"
python3 - "$T/ALL.csv" <<'PY'
import csv,io,sys
p=sys.argv[1]; rows=list(csv.reader(io.open(p,newline='')));h=rows[0]
i=h.index('n_lines')
rows[1][i]=str(int(rows[1][i])+999)          # a derived cell, deliberately wrong
csv.writer(io.open(p,'w',newline='')).writerows(rows)
PY
b_bad="$(cell_n_lines "$T/ALL.csv")"
[ "$b_bad" != "$b_true" ] && ck ok "corrupted one derived cell (n_lines $b_true -> $b_bad)" || ck no "harness error: the corruption did not land"
out="$(run "${ACKARG[@]}")"; rc=$?
[ "$rc" -eq 0 ] && ck ok "reindex over a corrupted index exits 0 (got $rc)" || ck no "reindex must exit 0 over a corrupted index, got $rc"
b_after="$(cell_n_lines "$T/ALL.csv")"
[ "$b_after" = "$b_true" ] && ck ok "(b) the corrupted cell was RECOMPUTED ($b_bad -> $b_after)" || ck no "(b) corruption survived ($b_bad -> $b_after) -- --reindex is copying, not recomputing"
echo "--- (e) absorption flags REFUSE ---"
out="$(S4E_HOME="$W" python3 "$SUT" --lang "$LANG_T" --reindex --delete-absorbed 2>&1)"; rc=$?
[ "$rc" -eq 2 ] && ck ok "--reindex --delete-absorbed -> rc=2 (got $rc)" || ck no "--reindex with an absorption flag must exit rc=2, got $rc"
grep -q 'absorbs nothing' <<<"$out" && ck ok "refusal explains why the combination is refused" || ck no "refusal must explain the combination"
echo "------------------------------------------------------------"
[ "$fails" -ne 0 ] && { echo "⛔ GATE FAIL: $fails of $checks check(s) failed"; exit 1; }
echo "✅ GATE PASS: $checks/$checks checks"; exit 0
