#!/usr/bin/env bash
# test_gate_logtalk_unit_condition_rows_fail_on_every_oracle.sh -- THE FOURTH NO_ORACLE_ANSWER EVIDENCE FORM IS A MEASUREMENT, NOT A MASK (R-2002 and cto, 2026-10-28).
# logtalk_iso's EXCLUDED_CASES.tsv names the twelve cases of control/if_3 NO_ORACLE_ANSWER: the unit carries `condition :- predicate_property(if(_,_,_), built_in).`, lgtunit skips a whole unit
# whose condition fails, and swipl 9.0.4, swipl 10.1.5 and the gprolog oracle all answer that goal false -- no oracle answers any case of the unit. A row like that is true only while every
# oracle keeps answering the condition false. This gate runs the three oracles on the condition of the unit of EVERY NO_ORACLE_ANSWER row whose group file carries a `condition :- G.` clause
# and reds the row the day one of them answers true (the case returns to the denominator in that landing). Only a row whose own reason text claims the
# condition form is probed (cto R-2127): a row justified by another form may carry a Logtalk-local condition (set_encoding/1, max_depth_option_supported/0)
# that plain Prolog answers false vacuously, and that reading would be neither the row's evidence nor its refutation.
# ARMS: (1) every such row: swipl 9.0.4, swipl 10.1.5 and the gprolog oracle each answer the unit's condition false (a call that raises counts false, as lgtunit's condition check does)
#       (2) THE POPULATION IS NOT EMPTY AND IS THE RULED TWELVE OR MORE (a gate that reads zero rows proves nothing)
#       (3) CONTROL: control/soft_cut_2_3's condition (predicate_property('*->'(_,_), built_in)) reads TRUE on swipl 9.0.4 -- the same extractor and the same oracle read TRUE where the condition
#           holds, so arm (1)'s "false" is a reading and not a probe that always answers false
#       (4) CAN FAIL: a mktemp corpus (outside corpus/, R-547) that files a case of that passing unit as a NO_ORACLE_ANSWER row reads RED (rc 1) and names the row stale
#       (5) CAN FAIL AT CASE LEVEL (cto R-2127, 2026-11-04): the same form reads a case's own condition({G}) option (predicate_property_2 lgt_predicate_property_2_23, G false on every
#           oracle, is a row); a mktemp corpus filing lgt_predicate_property_2_22 (its condition true on swipl 9.0.4) as a NO_ORACLE_ANSWER row reads RED (rc 1) and names the row stale
# rc 0 all arms; rc 1 a stale row or a failed control; rc 2 an oracle or the files are absent, or an oracle printed neither true nor false (could not measure).
# Usage: bash ../harness/scripts/test_gate_logtalk_unit_condition_rows_fail_on_every_oracle.sh
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${S4E_HOME:-$(cd "$HERE/../.." && pwd)}"
PKG="${S4E_CORPUS:-$ROOT/corpus}/packages/prolog/logtalk_iso"
refuse() { echo "⛔ REFUSED(2) [logtalk_unit_condition_rows_fail_on_every_oracle]: $*"; exit 2; }
[ -f "$PKG/EXCLUDED_CASES.tsv" ] || refuse "no $PKG/EXCLUDED_CASES.tsv"
. "$HERE/lib_oracle_flags.sh" || refuse "lib_oracle_flags.sh is missing"
SW="$(swipl_bin)" || refuse "the swipl oracle accessor refused"
GP="$(gprolog_bin)" || refuse "the gprolog oracle accessor refused"
SW10=/home/resources/swipl-mon/bin/swipl
[ -x "$SW" ] || refuse "swipl is not executable: $SW"
[ -x "$SW10" ] || refuse "swipl 10.1.5 is not executable: $SW10"
T="$(mktemp -d)" || refuse "mktemp failed"; trap 'rm -rf "$T"' EXIT
python3 -I - "$PKG" "$T" <<'PY' || refuse "the extractor could not read the rows (named above)"
import glob, os, re, sys
pkg, tmp = sys.argv[1], sys.argv[2]
rows = []
for ln in open(os.path.join(pkg, "EXCLUDED_CASES.tsv"), encoding="utf-8"):
    if ln.startswith("#") or not ln.strip():
        continue
    f = ln.rstrip("\n").split("\t")
    if len(f) >= 3 and f[1] == "NO_ORACLE_ANSWER" and "condition" in f[2]:
        rows.append(f[0])
cond = re.compile(r"^[ \t]*condition[ \t]*:-[ \t]*(.*?)\.[ \t]*$", re.M | re.S)
def unit_condition(group):
    for path in glob.glob(os.path.join(pkg, "*", group, "tests.lgt")):
        m = cond.search(open(path, encoding="utf-8").read())
        if m:
            return " ".join(m.group(1).split())
    return None
def case_condition(group, case):
    for path in glob.glob(os.path.join(pkg, "*", group, "tests.lgt")):
        txt = open(path, encoding="utf-8").read()
        i = txt.find("test(" + case + ",")
        if i < 0:
            continue
        j = txt.find(":-", i)
        head = txt[i:j] if j > i else txt[i:i + 2000]
        k = head.find("condition(")
        if k < 0:
            return None
        s, e, depth = k + len("condition("), k + len("condition("), 1
        while e < len(head) and depth > 0:
            depth += (head[e] == "(") - (head[e] == ")"); e += 1
        g = "".join(head[s:e - 1].split())
        return g[1:-1] if g.startswith("{") and g.endswith("}") else g
    return None
out = []
for key in rows:
    g, _, cs = key.partition(":")
    c = unit_condition(g) or case_condition(g, cs)
    if c:
        out.append((key, "row", c))
ctl = unit_condition("soft_cut_2_3")
if ctl is None:
    print("the control unit soft_cut_2_3 carries no condition :- G. clause in its tests.lgt", file=sys.stderr); sys.exit(1)
out.append(("soft_cut_2_3", "control", ctl))
q = lambda s: "'" + s.replace("\\", "\\\\").replace("'", "\\'") + "'"
with open(os.path.join(tmp, "probe.pl"), "w", encoding="utf-8") as fh:
    for i, (key, kind, c) in enumerate(out):
        fh.write("c(%d, %s, %s, ( %s )).\n" % (i, q(key), q(kind), c))
    fh.write(":- initialization(main).\nmain :- forall(c(_, K, Kind, G), ( ( catch(G, _, fail) -> R = true ; R = false ), write(K), write('\\t'), write(Kind), write('\\t'), write(R), nl )), halt.\n")
PY
probe() { timeout -k 5 60 "$@" < /dev/null 2> "$T/err" | grep -P '\t(row|control)\t(true|false)$'; }
probe "$SW" -q -f "$T/probe.pl" -t halt > "$T/sw9" ; probe "$SW10" -q -f "$T/probe.pl" -t halt > "$T/sw10"; probe "$GP" --consult-file "$T/probe.pl" --query-goal halt > "$T/gp"
for f in sw9 sw10 gp; do [ -s "$T/$f" ] || refuse "oracle $f printed no reading of the probe: $(head -c 300 "$T/err")"; done
fails=0; rows=0; ck() { if [ "$1" = ok ]; then echo "  ok    $2"; else echo "  FAIL  $2"; fails=$((fails+1)); fi; }
echo "=== gate: the unit-condition NO_ORACLE_ANSWER rows fail on swipl 9.0.4, swipl 10.1.5 and the gprolog oracle (R-2002) ==="
while IFS=$'\t' read -r key kind v9; do
  [ "$kind" = row ] || continue
  rows=$((rows+1))
  v10="$(awk -F'\t' -v k="$key" '$1==k{print $3}' "$T/sw10")"; vg="$(awk -F'\t' -v k="$key" '$1==k{print $3}' "$T/gp")"
  if [ "$v9" = false ] && [ "$v10" = false ] && [ "$vg" = false ]; then ck ok "(1) $key: the condition is false on swipl 9.0.4, swipl 10.1.5 and the gprolog oracle"
  else ck no "(1) $key: the condition reads swipl 9.0.4 $v9, swipl 10.1.5 ${v10:-nothing}, gprolog ${vg:-nothing} -- an oracle answers TRUE, the row is stale and the case returns to the denominator"; fi
done < "$T/sw9"
[ "$rows" -ge 12 ] && ck ok "(2) population: $rows unit-condition NO_ORACLE_ANSWER row(s) read, at least the ruled twelve" || ck no "(2) population: $rows row(s) read, fewer than the ruled twelve -- the extractor or the table moved"
c="$(awk -F'\t' '$2=="control"{print $3}' "$T/sw9")"
[ "$c" = true ] && ck ok "(3) CONTROL: soft_cut_2_3's condition reads true on swipl 9.0.4 (the extractor and the oracle read TRUE where it holds)" || ck no "(3) CONTROL: soft_cut_2_3's condition read '${c:-nothing}', not true -- the probe cannot tell true from false"
if [ -z "${S4E_UNITCOND_NO_SELF:-}" ]; then
  F="$T/fixture"; mkdir -p "$F/packages/prolog/logtalk_iso/control/soft_cut_2_3" && cp "$PKG/control/soft_cut_2_3/tests.lgt" "$F/packages/prolog/logtalk_iso/control/soft_cut_2_3/" \
    && printf 'soft_cut_2_3:commons_soft_cut_2_3_01\tNO_ORACLE_ANSWER\ta row naming a case of a unit whose condition holds on swipl (gate fixture)\n' > "$F/packages/prolog/logtalk_iso/EXCLUDED_CASES.tsv" || refuse "fixture copy failed"
  S4E_UNITCOND_NO_SELF=1 S4E_CORPUS="$F" bash "$0" > "$T/fixture.out" 2>&1; frc=$?
  [ "$frc" = 1 ] && grep -q 'FAIL  (1) soft_cut_2_3:commons_soft_cut_2_3_01: the condition reads swipl 9.0.4 true' "$T/fixture.out" \
    && ck ok "(4) CAN FAIL: a row naming a case of a unit whose condition holds reads RED (rc 1) and is named stale" \
    || ck no "(4) CAN FAIL: the fixture row read rc=$frc, not rc 1 naming the stale row: $(tail -2 "$T/fixture.out" | tr '\n' ' ')"
  F2="$T/fixture2"; mkdir -p "$F2/packages/prolog/logtalk_iso/predicates/predicate_property_2" "$F2/packages/prolog/logtalk_iso/control/soft_cut_2_3" \
    && cp "$PKG/predicates/predicate_property_2/tests.lgt" "$F2/packages/prolog/logtalk_iso/predicates/predicate_property_2/" && cp "$PKG/control/soft_cut_2_3/tests.lgt" "$F2/packages/prolog/logtalk_iso/control/soft_cut_2_3/" \
    && printf 'predicate_property_2:lgt_predicate_property_2_22\tNO_ORACLE_ANSWER\ta row naming a case whose own condition option holds on swipl (gate fixture)\n' > "$F2/packages/prolog/logtalk_iso/EXCLUDED_CASES.tsv" || refuse "fixture 2 could not be built"
  S4E_UNITCOND_NO_SELF=1 S4E_CORPUS="$F2" bash "$0" > "$T/fixture2.out" 2>&1; frc2=$?
  [ "$frc2" = 1 ] && grep -q 'FAIL  (1) predicate_property_2:lgt_predicate_property_2_22: the condition reads swipl 9.0.4 true' "$T/fixture2.out" \
    && ck ok "(5) CAN FAIL AT CASE LEVEL: a row naming a case whose own condition option holds reads RED (rc 1) and is named stale (R-2127)" \
    || ck no "(5) CAN FAIL AT CASE LEVEL: the fixture row read rc=$frc2, not rc 1 naming the stale row: $(tail -2 "$T/fixture2.out" | tr '\n' ' ')"
fi
[ "$fails" -eq 0 ] && { echo "GATE logtalk_unit_condition_rows_fail_on_every_oracle OK -- $rows row(s), swipl $("$SW" --version | head -1)"; exit 0; }
echo "GATE logtalk_unit_condition_rows_fail_on_every_oracle RED -- $fails arm(s)"; exit 1
