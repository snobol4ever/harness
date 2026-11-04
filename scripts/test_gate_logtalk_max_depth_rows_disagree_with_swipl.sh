#!/usr/bin/env bash
# test_gate_logtalk_max_depth_rows_disagree_with_swipl.sh -- THE FIFTH NO_ORACLE_ANSWER EVIDENCE FORM IS A MEASUREMENT, NOT A MASK (cto R-2117, 2026-11-04, on the
# coo's verifier reds of 2026-11-04). logtalk_iso's EXCLUDED_CASES.tsv names write_term_3 lgt_write_term_3_132 and _134 NO_ORACLE_ANSWER: each asserts GNU Prolog's
# text for a LIST written under write_term's max_depth ([1,2,3|...] at max_depth(3), [1|...] at max_depth(1)); the generated case program carries no dialect marker,
# so it is the default dialect, which takes SWI where GNU and SWI conflict (R-1536), and the pinned oracle swipl 9.0.4 prints [1,2|...] and [...|...]. A row like
# that is true only while swipl keeps disagreeing with the assertion. This gate runs the oracle (the swipl_bin accessor) on the goal of EVERY NO_ORACLE_ANSWER row
# whose test body is a max_depth write_term of a list and reds the row whose asserted text swipl now prints (the row is stale: the case returns to the denominator).
# ARMS: (1) every such row: swipl's text differs from the asserted text, the population (rows read) printed beside the verdict
#       (2) THE POPULATION IS NOT EMPTY AND IS THE RULED TWO OR MORE (a gate that reads zero rows proves nothing)
#       (3) CONTROL: lgt_write_term_3_130, a max_depth list case the suite passes ([1,2,3,4,5] at max_depth(6)), ASSERTS the text swipl prints -- the same extractor
#           and the same oracle read AGREE there, so arm (1)'s "differ" is a reading and not a parser that always differs
#       (4) CAN FAIL: a mktemp corpus (outside corpus/, R-547) that files the passing control case as a NO_ORACLE_ANSWER row reads RED (rc 1) and names it stale
# rc 0 all arms; rc 1 a stale row or a failed control; rc 2 swipl or the files are absent (could not measure).
# Usage: bash ../harness/scripts/test_gate_logtalk_max_depth_rows_disagree_with_swipl.sh
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${S4E_HOME:-$(cd "$HERE/../.." && pwd)}"
PKG="${S4E_CORPUS:-$ROOT/corpus}/packages/prolog/logtalk_iso"
refuse() { echo "⛔ REFUSED(2) [logtalk_max_depth_rows_disagree_with_swipl]: $*"; exit 2; }
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
pat = re.compile(r"test\((\w+),\s*true\(Assertion\),\s*\[condition\(max_depth_option_supported\)\]\)\s*:-\s*\^\^set_text_output\(''\),\s*\{write_term\((\[[^\]]*\]),\s*\[max_depth\((\d+)\)\]\)\},\s*\^\^text_output_assertion\('([^']*)',\s*Assertion\)", re.S)
def body(group, name):
    path = os.path.join(pkg, "predicates", group, "tests.lgt")
    if not os.path.isfile(path):
        return None
    for m in pat.finditer(open(path, encoding="utf-8").read()):
        if m.group(1) == name:
            return m.group(2), m.group(3), m.group(4)
    return None
out = []
for key in rows:
    group, case = key.split(":", 1)
    b = body(group, case)
    if b:
        out.append((key, "row", b[0], b[1], b[2]))
ctl = body("write_term_3", "lgt_write_term_3_130")
if ctl is None:
    print("the control case lgt_write_term_3_130 is not in write_term_3/tests.lgt as a max_depth list test", file=sys.stderr); sys.exit(1)
out.append(("write_term_3:lgt_write_term_3_130", "control", ctl[0], ctl[1], ctl[2]))
q = lambda s: "'" + s.replace("\\", "\\\\").replace("'", "\\'") + "'"
with open(os.path.join(tmp, "probe.pl"), "w", encoding="utf-8") as fh:
    for i, (key, kind, lst, depth, exp) in enumerate(out):
        fh.write("c(%d, %s, %s, %s, %s, %s).\n" % (i, q(key), q(kind), lst, depth, q(exp)))
    fh.write(":- initialization(main).\nmain :- forall(c(_, K, Kind, L, D, E), ( with_output_to(string(S), write_term(L, [max_depth(D)])), atom_string(A, S), ( A == E -> R = agree ; R = differ ), format(\"~w\\t~w\\t~w\\t~q~n\", [K, Kind, R, A]) )), halt.\n")
PY
timeout 60 "$SW" -q -f "$T/probe.pl" -t halt < /dev/null > "$T/out" 2> "$T/err" || refuse "swipl could not run the probe: $(head -c 300 "$T/err")"
fails=0; rows=0; ck() { if [ "$1" = ok ]; then echo "  ok    $2"; else echo "  FAIL  $2"; fails=$((fails+1)); fi; }
echo "=== gate: the max_depth list NO_ORACLE_ANSWER rows disagree with swipl 9.0.4 (R-2117) ==="
while IFS=$'\t' read -r key kind verdict printed; do
  [ "$kind" = row ] || continue
  rows=$((rows+1))
  if [ "$verdict" = differ ]; then ck ok "(1) $key: swipl prints $printed, not the asserted text"; else ck no "(1) $key: swipl PRINTS the asserted text $printed -- the row is stale, the case returns to the denominator"; fi
done < "$T/out"
[ "$rows" -ge 2 ] && ck ok "(2) population: $rows max_depth list NO_ORACLE_ANSWER row(s) read, at least the ruled two" || ck no "(2) population: $rows row(s) read, fewer than the ruled two -- the extractor or the table moved"
c="$(awk -F'\t' '$2=="control"{print $3}' "$T/out")"
[ "$c" = agree ] && ck ok "(3) CONTROL: lgt_write_term_3_130 asserts the text swipl prints (the extractor and the oracle read AGREE)" || ck no "(3) CONTROL: lgt_write_term_3_130 read '${c:-nothing}', not agree -- the probe cannot tell a reading from a parser that always differs"
if [ -z "${S4E_MAXDEPTH_NO_SELF:-}" ]; then
  F="$T/fixture"; mkdir -p "$F/packages/prolog/logtalk_iso/predicates/write_term_3" && cp "$PKG/predicates/write_term_3/tests.lgt" "$F/packages/prolog/logtalk_iso/predicates/write_term_3/" \
    && printf 'write_term_3:lgt_write_term_3_130\tNO_ORACLE_ANSWER\ta row naming a case swipl agrees with (gate fixture)\n' > "$F/packages/prolog/logtalk_iso/EXCLUDED_CASES.tsv" || refuse "fixture copy failed"
  S4E_MAXDEPTH_NO_SELF=1 S4E_CORPUS="$F" bash "$0" > "$T/fixture.out" 2>&1; frc=$?
  [ "$frc" = 1 ] && grep -q 'FAIL  (1) write_term_3:lgt_write_term_3_130: swipl PRINTS the asserted text' "$T/fixture.out" \
    && ck ok "(4) CAN FAIL: a row naming a case swipl agrees with reads RED (rc 1) and is named stale" \
    || ck no "(4) CAN FAIL: the fixture row read rc=$frc, not rc 1 naming the stale row: $(tail -2 "$T/fixture.out" | tr '\n' ' ')"
fi
[ "$fails" -eq 0 ] && { echo "GATE logtalk_max_depth_rows_disagree_with_swipl OK -- $rows row(s), swipl $("$SW" --version | head -1)"; exit 0; }
echo "GATE logtalk_max_depth_rows_disagree_with_swipl RED -- $fails arm(s)"; exit 1
