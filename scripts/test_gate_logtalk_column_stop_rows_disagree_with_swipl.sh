#!/usr/bin/env bash
# test_gate_logtalk_column_stop_rows_disagree_with_swipl.sh -- THE THIRD NO_ORACLE_ANSWER EVIDENCE FORM IS A MEASUREMENT, NOT A MASK (ceo CEO-1977, 2026-10-25,
# amending CEO-1696 for six rows). logtalk_iso's EXCLUDED_CASES.tsv names format_2 and format_3 tab_table_pip_0110_16, _19 and _20 NO_ORACLE_ANSWER: each asserts
# the text a NEWER swipl lays out for a ~t fill point and a ~N+ column stop, and the pinned oracle swipl 9.0.4 prints a different text. A row like that is true only
# while swipl keeps disagreeing with the assertion. This gate runs the oracle (the swipl_bin accessor) on the control string of EVERY NO_ORACLE_ANSWER row whose
# test body is a column-stop format/2,3 call and reds the row whose asserted text swipl now prints (the row is stale: the case returns to the denominator).
# ARMS: (1) every such row: swipl's text differs from the asserted text, the population (rows read) printed beside the verdict
#       (2) THE POPULATION IS NOT EMPTY AND IS THE RULED SIX OR MORE (a gate that reads zero rows proves nothing)
#       (3) CONTROL: tab_table_pip_0110_17, a column-stop case the suite passes, ASSERTS the text swipl prints -- the same extractor and the same oracle read AGREE
#           there, so arm (1)'s "differ" is a reading and not a parser that always differs
#       (4) CAN FAIL: a mktemp corpus (outside corpus/, CEO-547) that files the passing control case as a NO_ORACLE_ANSWER row reads RED (rc 1) and names it stale
# rc 0 all arms; rc 1 a stale row or a failed control; rc 2 swipl or the files are absent (could not measure).
# Usage: bash ../harness/scripts/test_gate_logtalk_column_stop_rows_disagree_with_swipl.sh
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${S4E_HOME:-$(cd "$HERE/../.." && pwd)}"
PKG="${S4E_CORPUS:-$ROOT/corpus}/packages/prolog/logtalk_iso"
refuse() { echo "⛔ REFUSED(2) [logtalk_column_stop_rows_disagree_with_swipl]: $*"; exit 2; }
[ -f "$PKG/EXCLUDED_CASES.tsv" ] || refuse "no $PKG/EXCLUDED_CASES.tsv"
. "$HERE/lib_oracle_flags.sh" || refuse "lib_oracle_flags.sh is missing"
SW="$(swipl_bin)" || refuse "the swipl oracle accessor refused"
[ -x "$SW" ] || refuse "swipl is not executable: $SW"
T="$(mktemp -d)" || refuse "mktemp failed"; trap 'rm -rf "$T"' EXIT
python3 -I - "$PKG" "$T" <<'PY' || refuse "the extractor could not read the rows (named above)"
import os, re, sys
pkg, tmp = sys.argv[1], sys.argv[2]
rows = []
for ln in open(os.path.join(pkg, "EXCLUDED_CASES.tsv"), encoding="utf-8"):
    if ln.startswith("#") or not ln.strip():
        continue
    f = ln.rstrip("\n").split("\t")
    if len(f) >= 2 and f[1] == "NO_ORACLE_ANSWER":
        rows.append(f[0])
pat = re.compile(r"test\((\w+),\s*true\(Assertion\)\)\s*:-\s*\^\^set_text_output\((?:out,\s*)?''\),\s*\{format\((?:out,\s*)?\"([^\"]*)\",\s*\[\]\)\},\s*\^\^text_output_assertion\((?:out,\s*)?'([^']*)',\s*Assertion\)", re.S)
def body(group, name):
    path = os.path.join(pkg, "predicates", group, "tests.lgt")
    if not os.path.isfile(path):
        return None
    for m in pat.finditer(open(path, encoding="utf-8").read()):
        if m.group(1) == name:
            return m.group(2), m.group(3)
    return None
out = []
for key in rows:
    group, case = key.split(":", 1)
    b = body(group, case)
    if b and "~t" in b[0] and re.search(r"~\d+\+", b[0]):
        out.append((key, "row", b[0], b[1]))
ctl = body("format_2", "lgt_format_2_tab_table_pip_0110_17")
if ctl is None:
    print("the control case lgt_format_2_tab_table_pip_0110_17 is not in format_2/tests.lgt as a column-stop format test", file=sys.stderr); sys.exit(1)
out.append(("format_2:lgt_format_2_tab_table_pip_0110_17", "control", ctl[0], ctl[1]))
q = lambda s: "'" + s.replace("\\", "\\\\").replace("'", "\\'") + "'"
with open(os.path.join(tmp, "probe.pl"), "w", encoding="utf-8") as fh:
    for i, (key, kind, fmt, exp) in enumerate(out):
        fh.write("c(%d, %s, %s, %s, %s).\n" % (i, q(key), q(kind), '"' + fmt.replace("\\", "\\\\").replace('"', '\\"') + '"', q(exp)))
    fh.write(":- initialization(main).\nmain :- forall(c(_, K, Kind, F, E), ( with_output_to(string(S), format(F, [])), atom_string(A, S), ( A == E -> R = agree ; R = differ ), format(\"~w\\t~w\\t~w\\t~q~n\", [K, Kind, R, A]) )), halt.\n")
PY
timeout 60 "$SW" -q -f "$T/probe.pl" -t halt < /dev/null > "$T/out" 2> "$T/err" || refuse "swipl could not run the probe: $(head -c 300 "$T/err")"
fails=0; rows=0; ck() { if [ "$1" = ok ]; then echo "  ok    $2"; else echo "  FAIL  $2"; fails=$((fails+1)); fi; }
echo "=== gate: the column-stop NO_ORACLE_ANSWER rows disagree with swipl 9.0.4 (CEO-1977) ==="
while IFS=$'\t' read -r key kind verdict printed; do
  [ "$kind" = row ] || continue
  rows=$((rows+1))
  if [ "$verdict" = differ ]; then ck ok "(1) $key: swipl prints $printed, not the asserted text"; else ck no "(1) $key: swipl PRINTS the asserted text $printed -- the row is stale, the case returns to the denominator"; fi
done < "$T/out"
[ "$rows" -ge 6 ] && ck ok "(2) population: $rows column-stop NO_ORACLE_ANSWER row(s) read, at least the ruled six" || ck no "(2) population: $rows row(s) read, fewer than the ruled six -- the extractor or the table moved"
c="$(awk -F'\t' '$2=="control"{print $3}' "$T/out")"
[ "$c" = agree ] && ck ok "(3) CONTROL: tab_table_pip_0110_17 asserts the text swipl prints (the extractor and the oracle read AGREE)" || ck no "(3) CONTROL: tab_table_pip_0110_17 read '${c:-nothing}', not agree -- the probe cannot tell agree from differ"
if [ -z "${S4E_COLSTOP_NO_SELF:-}" ]; then
  F="$T/fixture"; mkdir -p "$F/packages/prolog/logtalk_iso/predicates/format_2" && cp "$PKG/predicates/format_2/tests.lgt" "$F/packages/prolog/logtalk_iso/predicates/format_2/" \
    && printf 'format_2:lgt_format_2_tab_table_pip_0110_17\tNO_ORACLE_ANSWER\ta row naming a case swipl agrees with (gate fixture)\n' > "$F/packages/prolog/logtalk_iso/EXCLUDED_CASES.tsv" || refuse "fixture copy failed"
  S4E_COLSTOP_NO_SELF=1 S4E_CORPUS="$F" bash "$0" > "$T/fixture.out" 2>&1; frc=$?
  [ "$frc" = 1 ] && grep -q 'FAIL  (1) format_2:lgt_format_2_tab_table_pip_0110_17: swipl PRINTS the asserted text' "$T/fixture.out" \
    && ck ok "(4) CAN FAIL: a row naming a case swipl agrees with reads RED (rc 1) and is named stale" \
    || ck no "(4) CAN FAIL: the fixture row read rc=$frc, not rc 1 naming the stale row: $(tail -2 "$T/fixture.out" | tr '\n' ' ')"
fi
[ "$fails" -eq 0 ] && { echo "GATE logtalk_column_stop_rows_disagree_with_swipl OK -- $rows row(s), swipl $("$SW" --version | head -1)"; exit 0; }
echo "GATE logtalk_column_stop_rows_disagree_with_swipl RED -- $fails arm(s)"; exit 1
