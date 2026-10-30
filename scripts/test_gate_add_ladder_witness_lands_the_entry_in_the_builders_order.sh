#!/usr/bin/env bash
export S4E_MINT_NO_CRITERION="gate fixture: the row under test exercises the bus, not work (CEO-1386)"
# test_gate_add_ladder_witness_lands_the_entry_in_the_builders_order.sh -- A MINT LANDS ITS ENTRY WHERE THE BUILDER'S KEY PUTS IT (ceo CEO-2019,
# the SnoRungs order gate red at 880 of 2189 with nine hq_dotnet harvests at the tail). util_add_ladder_witness.py used to APPEND the new
# entry and leave the sort to a --resort nobody ran after a harvest, so every mint broke test_gate_rungs_order_is_the_builders_order
# (Lon's level law: `rank <= N` selects the greenest N). It now places the entry by the builder's own key through the builder's resort_rungs,
# moving only the new entry, and REFUSES on a rungs that is not already in the builder's order (the reorder is its own commit).
# Hermetic: scratch copies of the SNOBOL4 rungs under mktemp (re-sorted by the builder first, so the live master's state never decides an
# arm), the real tool, the real oracle (sbl -bf cuts the witness's ref), nothing under corpus/ touched. The red proof runs a copy of the tool with
# the placement block removed -- the old append-only tool -- and asserts the order gate reads FAIL on what it writes.
# EXIT: 0 every arm holds; 1 an arm red; 2 could not measure.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; S4E="${S4E_HOME:-$(cd "$HERE/../.." && pwd)}"
G=add_ladder_witness_lands_the_entry_in_the_builders_order; TOOL="$HERE/util_add_ladder_witness.py"; ORDER="$HERE/test_gate_rungs_order_is_the_builders_order.sh"; M="$S4E/corpus/tests/snobol4"
refuse() { echo "⛔ REFUSED(2) [$G]: $*" >&2; exit 2; }
[ -f "$TOOL" ] && [ -f "$ORDER" ] && [ -f "$HERE/util_build_rungs_suite.py" ] || refuse "no tool, order gate or builder beside this gate in $HERE"
for f in ALL.csv ALL.sno ALL.ref; do [ -s "$M/$f" ] || refuse "no $M/$f -- the SNOBOL4 rungs is the scratch source"; done
[ -x /home/resources/x64/bin/sbl ] || refuse "no SNOBOL4 oracle at /home/resources/x64/bin/sbl (the tool cuts the witness's ref from it)"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
# fresh <name> -> a scratch ROOT $T/<name>/corpus/tests/snobol4 holding the live rungs and its sidecars, re-sorted into the builder's order (the order gate's S4E_HOME)
fresh() { local r="$T/$1" f; rm -rf "$r"; mkdir -p "$r/corpus/tests/snobol4"; for f in ALL.csv ALL.sno ALL.ref ALL.in ALL.xfail ALL.wantrc; do [ -f "$M/$f" ] && cp "$M/$f" "$r/corpus/tests/snobol4/"; done
    python3 - "$HERE" "$r/corpus/tests/snobol4" <<'PY' >/dev/null 2>&1 || return 2
import importlib.util, sys
here, d = sys.argv[1], sys.argv[2]
sys.path.insert(0, here); import corpus_suite_harness as csh
spec = importlib.util.spec_from_file_location("mb", here + "/util_build_rungs_suite.py"); mb = importlib.util.module_from_spec(spec); sys.argv = ["x"]; spec.loader.exec_module(mb)
sys.exit(mb.resort_rungs(d, ".sno", "snobol4", csh, "*", "", mb.LANG_TABLES["snobol4"][0], set(), set()))
PY
    echo "$r"; }
printf "\tOUTPUT = 'gate'\nEND\n" > "$T/w.sno"
ORIGIN=ladder__rung00_gate_placed_by_the_key; ATTR="--heap-kb 131072 --stack-kb 4096 --compile-args= --run-args="
names() { python3 - "$1" <<'PY'
import csv, sys
print("\n".join(r["entry"] for r in csv.DictReader(open(sys.argv[1] + "/ALL.csv", newline=""))))
PY
}
ok=0; red=0; ck() { if [ "$1" = ok ]; then ok=$((ok+1)); echo "  ok    $2"; else red=$((red+1)); echo "  FAIL  $2"; fi; }
order() { S4E_HOME="$1" LANGS=snobol4 bash "$ORDER" > "$T/order.out" 2>&1; }
# (1) on a rungs in the builder's order, the real tool mints a two-line witness (it sorts near the top) and the ORDER GATE still passes on the result
R="$(fresh a)" || refuse "could not stage a re-sorted scratch rungs"; D="$R/corpus/tests/snobol4"; names "$D" > "$T/before.txt"
order "$R" || refuse "the re-sorted scratch rungs does not itself pass the order gate: $(tail -2 "$T/order.out" | tr '\n' ' ')"
python3 "$TOOL" --lang snobol4 --rungs-dir "$D" --origin "$ORIGIN" --source "$T/w.sno" $ATTR > "$T/dry.out" 2>&1 || refuse "the tool's dry run failed: $(tail -2 "$T/dry.out" | tr '\n' ' ')"
python3 "$TOOL" --lang snobol4 --rungs-dir "$D" --origin "$ORIGIN" --source "$T/w.sno" $ATTR --apply > "$T/apply.out" 2>&1; rc=$?
[ "$rc" = 0 ] || refuse "the tool did not mint on the scratch rungs (rc=$rc): $(grep -m1 REFUSED "$T/apply.out")"
names "$D" > "$T/after.txt"
if order "$R"; then ck ok "(1) the order gate PASSES on the rungs after a mint ($(wc -l < "$T/after.txt") entries in the builder's order)"; else ck no "(1) the order gate on the minted rungs: $(grep -m1 FAIL "$T/order.out")"; fi
# (2) the entry sits where the dry run said, not at the tail, and every other entry kept its relative order
want="$(sed -n 's/^would add: rank=\([0-9]*\) .*/\1/p' "$T/dry.out")"; got="$(grep -nx "$ORIGIN" "$T/after.txt" | cut -d: -f1)"; total="$(wc -l < "$T/after.txt")"
if [ -n "$want" ] && [ "$want" = "$got" ] && [ "$got" -lt "$total" ] && [ "$(grep -vx "$ORIGIN" "$T/after.txt" | cmp - "$T/before.txt" && echo same)" = same ]; then
    ck ok "(2) the entry is at rank $got of $total (the dry run said $want), the other $((total-1)) kept their order"
else ck no "(2) placement: dry run said '$want', entry at '$got' of $total, or the others moved"; fi
# (3) a rungs with one entry out of place REFUSES rc 2 by name with the cure, and the three files are byte-for-byte as they were
R="$(fresh b)" || refuse "could not stage a re-sorted scratch rungs"; D="$R/corpus/tests/snobol4"
python3 - "$D" "$HERE" <<'PY' || refuse "could not displace an entry in the scratch rungs"
import csv, sys
d, here = sys.argv[1], sys.argv[2]
sys.path.insert(0, here); import corpus_suite_harness as csh
es = csh.read_suite(d + "/ALL.sno", d + "/ALL.ref", in_path=csh.sidecar_in_path(d + "/ALL.sno"), x_path=csh.sidecar_xfail_path(d + "/ALL.sno"))
i = next(k for k in range(len(es) - 1) if es[k].kind == "block" and es[k + 1].kind == "block" and es[k].name != es[k + 1].name)
es[i], es[i + 1] = es[i + 1], es[i]
for k, e in enumerate(es, 1): e.seq = k
csh.write_suite(es, d + "/ALL.sno", d + "/ALL.ref")
rows = {r["entry"]: r for r in csv.DictReader(open(d + "/ALL.csv", newline=""))}; f = list(next(iter(rows.values())).keys())
w = csv.DictWriter(open(d + "/ALL.csv", "w", newline=""), fieldnames=f, lineterminator="\n"); w.writeheader()
for k, e in enumerate(es, 1): r = dict(rows[e.name]); r["rank"] = str(k); w.writerow(r)
PY
order "$R" && refuse "the displaced scratch rungs still passes the order gate -- the fixture did not displace anything"
cp -r "$D" "$T/b.snap"
out="$(python3 "$TOOL" --lang snobol4 --rungs-dir "$D" --origin "$ORIGIN" --source "$T/w.sno" $ATTR --apply 2>&1)"; rc=$?
{ [ "$rc" = 2 ] && grep -qF "is not in the builder's order" <<<"$out" && grep -qF -- "--resort" <<<"$out" && ! grep -q "$ORIGIN" "$D/ALL.csv" && cmp -s "$D/ALL.sno" "$T/b.snap/ALL.sno" && cmp -s "$D/ALL.ref" "$T/b.snap/ALL.ref" && cmp -s "$D/ALL.csv" "$T/b.snap/ALL.csv"; } \
  && ck ok "(3) a rungs with an entry out of place REFUSES rc 2, names the --resort cure, and leaves ALL.sno ALL.ref ALL.csv untouched" || ck no "(3) the displaced rungs: rc=$rc $(printf '%s\n' "$out" | grep -m1 -E 'REFUSED|Traceback')"
# (4) RED PROOF: the tool without the placement block -- the append-only tool -- writes the entry at the tail, and the order gate reads FAIL on it
. "$HERE/lib_fixture_root.sh" || exit 2; fixture_root "$T/dx" || { echo "GATE UNPROVEN(2) [$G]: cannot stage a copied root at $T/dx"; exit 2; }
python3 - "$T/dx/harness/scripts/util_add_ladder_witness.py" <<'PY' || refuse "the doctoring edit did not apply (the placement block moved)"
import sys; p = sys.argv[1]; s = open(p, encoding="utf-8").read()
a, b = s.find("    # ── PLACE THE ENTRY BY THE BUILDER'S KEY"), s.find("    # ── FINAL PROOF")
if a < 0 or b < a: sys.exit(1)
open(p, "w", encoding="utf-8").write(s[:a] + '    with open(rungs_csv, newline="") as fh:\n        rank = next(r["rank"] for r in csv.DictReader(fh) if r["entry"] == entry_name)\n' + s[b:])
PY
R="$(fresh c)" || refuse "could not stage a re-sorted scratch rungs"; D="$R/corpus/tests/snobol4"
S4E_HOME="$S4E" python3 "$T/dx/harness/scripts/util_add_ladder_witness.py" --lang snobol4 --rungs-dir "$D" --origin "$ORIGIN" --source "$T/w.sno" $ATTR --apply > "$T/doc.out" 2>&1; rc=$?
[ "$rc" = 0 ] || refuse "the doctored (append-only) tool did not mint (rc=$rc): $(tail -1 "$T/doc.out")"
names "$D" > "$T/doc.txt"
if [ "$(tail -1 "$T/doc.txt")" = "$ORIGIN" ] && ! order "$R" && grep -q 'FAIL  snobol4' "$T/order.out"; then
    ck ok "(4) RED PROOF: the append-only tool leaves the entry at the tail and the order gate reads FAIL on it ($(grep -m1 'FAIL  snobol4' "$T/order.out" | sed 's/  */ /g' | cut -c1-90)) -- arm 1 would read FAIL on that build"
else ck no "(4) the red proof did not hold: last entry '$(tail -1 "$T/doc.txt")', order gate: $(tail -1 "$T/order.out")"; fi
echo "population: $((ok+red)) arm(s) over three scratch copies of the SNOBOL4 rungs ($(($(wc -l < "$M/ALL.csv")-1)) rows each, re-sorted by the builder first), one two-line witness, the real tool and one doctored copy"
[ "$red" = 0 ] && { echo "GATE PASS(0) [$G]: $ok of $ok arms hold"; exit 0; }
echo "⛔ GATE FAIL(1) [$G]: $red of $((ok+red)) arms red"; exit 1
