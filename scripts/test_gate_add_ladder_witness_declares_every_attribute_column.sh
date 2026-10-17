#!/usr/bin/env bash
export S4E_MINT_NO_CRITERION="gate fixture: the row under test exercises the bus, not work (CEO-1386)"
# test_gate_add_ladder_witness_declares_every_attribute_column.sh -- util_add_ladder_witness.py WRITES EVERY ATTRIBUTE COLUMN
# (heap_kb, stack_kb, compile_args, run_args) on the ALL.csv row it adds (ceo CEO-1323, on hq_snocone's entry 1994 filled by
# hand; RULES.md hard-cap rule clause 8 (f), Lon 2026-09-26: every test unit stores the command line its compile and run
# need). The values are READ from the rungs' own ladder rows -- never baked into the tool -- an explicit switch overrides,
# and a rung suite whose ladder rows disagree REFUSES rc 2. Hermetic: a scratch copy of the SNOBOL4 rungs under mktemp, the
# real tool, the real oracle (sbl -bf cuts the witness's ref), nothing under corpus/ touched. The red proof runs a copy of
# the tool with the one line that fills the columns removed and asserts the row comes out blank -- so a tool build that
# leaves them blank fails arm 1's assertion, which is the point.
# EXIT: 0 every arm holds; 1 an arm red; 2 could not measure.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; S4E="${S4E_HOME:-$(cd "$HERE/../.." && pwd)}"
G=add_ladder_witness_declares_every_attribute_column; TOOL="$HERE/util_add_ladder_witness.py"; M="$S4E/corpus/tests/snobol4"
refuse() { echo "⛔ REFUSED(2) [$G]: $*" >&2; exit 2; }
[ -f "$TOOL" ] || refuse "no $TOOL"
for f in ALL.csv ALL.sno ALL.ref; do [ -s "$M/$f" ] || refuse "no $M/$f -- the SNOBOL4 rungs is the scratch source"; done
[ -x /home/resources/x64/bin/sbl ] || refuse "no SNOBOL4 oracle at /home/resources/x64/bin/sbl (the tool cuts the witness's ref from it)"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
fresh() { rm -rf "$T/$1"; mkdir -p "$T/$1"; cp "$M/ALL.csv" "$M/ALL.sno" "$M/ALL.ref" "$T/$1/"; [ -f "$M/ALL.wantrc" ] && cp "$M/ALL.wantrc" "$T/$1/"; echo "$T/$1"; }
printf "\tOUTPUT = 'gate'\nEND\n" > "$T/w.sno"
ORIGIN=ladder__rung00_gate_attribute_columns
# col <csv> <row-match> <column-name> -> the named column's value, read BY HEADER NAME never by position
col() { python3 - "$1" "$2" "$3" <<'PY'
import csv, sys
rows = [r for r in csv.DictReader(open(sys.argv[1], newline="")) if r["origin"] == sys.argv[2]]
sys.exit(1) if len(rows) != 1 else print(rows[0].get(sys.argv[3], "<no such column>"))
PY
}
# the convention the rungs' ladder rows carry, read here independently of the tool (one value per column, or the arm refuses)
conv() { python3 - "$M/ALL.csv" "$1" <<'PY'
import csv, sys
vals = sorted({r.get(sys.argv[2]) or "" for r in csv.DictReader(open(sys.argv[1], newline="")) if r["origin"].startswith("ladder__")})
sys.exit(2) if len(vals) != 1 else print(vals[0])
PY
}
ok=0; red=0; ck() { if [ "$1" = ok ]; then ok=$((ok+1)); echo "  ok    $2"; else red=$((red+1)); echo "  FAIL  $2"; fi; }
for c in heap_kb stack_kb compile_args run_args; do declare "C_$c=$(conv $c)" || refuse "the rungs' ladder rows do not agree on $c -- the convention this gate reads is not one value"; done
[ -n "$C_heap_kb" ] && [ -n "$C_stack_kb" ] && [ -n "$C_compile_args" ] || refuse "the rungs' ladder convention is itself blank on heap/stack/compile_args ($C_heap_kb/$C_stack_kb/$C_compile_args) -- nothing to prove against"
# (1) the real tool on a fresh copy: every attribute column on the new row equals the convention, heap/stack/compile non-empty
D="$(fresh a)"; out="$(python3 "$TOOL" --lang snobol4 --rungs-dir "$D" --origin "$ORIGIN" --source "$T/w.sno" --apply 2>&1)"; rc=$?
[ "$rc" = 0 ] || refuse "the tool did not mint on the scratch rungs (rc=$rc): $(printf '%s\n' "$out" | tail -2 | tr '\n' ' ')"
got=""; for c in heap_kb stack_kb compile_args run_args; do v="$(col "$D/ALL.csv" "$ORIGIN" "$c")" || { got="$got $c=<no row>"; continue; }; got="$got $c='$v'"; done
[ "$(col "$D/ALL.csv" "$ORIGIN" heap_kb)" = "$C_heap_kb" ] && [ "$(col "$D/ALL.csv" "$ORIGIN" stack_kb)" = "$C_stack_kb" ] \
  && [ "$(col "$D/ALL.csv" "$ORIGIN" compile_args)" = "$C_compile_args" ] && [ "$(col "$D/ALL.csv" "$ORIGIN" run_args)" = "$C_run_args" ] \
  && ck ok "(1) the minted row carries the rungs' ladder convention: heap_kb=$C_heap_kb stack_kb=$C_stack_kb compile_args=$C_compile_args run_args='$C_run_args' (read from the ladder rows, none blank but run_args by convention)" \
  || ck no "(1) the minted row's attribute columns:$got (convention $C_heap_kb/$C_stack_kb/$C_compile_args/'$C_run_args')"
grep -q 'attribute row (clause 8 f)' <<<"$out" && ck ok "(2) the tool's report names the attribute row it wrote" || ck no "(2) the tool's report is silent about the attribute row"
# (3) explicit switches override the convention
D="$(fresh b)"; python3 "$TOOL" --lang snobol4 --rungs-dir "$D" --origin "$ORIGIN" --source "$T/w.sno" --heap-kb=262144 --stack-kb=65536 --compile-args= --run-args=-x --apply > /dev/null 2>&1; rc=$?
# (compile_args is a closed enumeration in the harness, --stlimit alone today, so the override proven here is the EMPTY cell)
[ "$rc" = 0 ] && [ "$(col "$D/ALL.csv" "$ORIGIN" heap_kb)" = 262144 ] && [ "$(col "$D/ALL.csv" "$ORIGIN" stack_kb)" = 65536 ] \
  && [ "$(col "$D/ALL.csv" "$ORIGIN" compile_args)" = '' ] && [ "$(col "$D/ALL.csv" "$ORIGIN" run_args)" = '-x' ] \
  && ck ok "(3) explicit --heap-kb/--stack-kb/--compile-args/--run-args override the convention on the row" || ck no "(3) the overrides (rc=$rc): heap=$(col "$D/ALL.csv" "$ORIGIN" heap_kb) stack=$(col "$D/ALL.csv" "$ORIGIN" stack_kb)"
# (4) a rung suite whose ladder rows disagree on heap_kb REFUSES rc 2 (nothing written), and --heap-kb resolves it
# (the tool says "the rungs' heap_kb convention" since 645ecc909 renamed master -> rungs; this arm grepped 'rungs.s', which a
#  plural possessive cannot match, and read the right refusal as red -- the coo 2026-10-01, a fixed string now)
D="$(fresh c)"; python3 - "$D/ALL.csv" <<'PY'
import csv, sys
p = sys.argv[1]; rows = list(csv.DictReader(open(p, newline=""))); f = list(rows[0].keys())
lad = [r for r in rows if r["origin"].startswith("ladder__")]; lad[0]["heap_kb"] = "65536"
w = csv.DictWriter(open(p, "w", newline=""), fieldnames=f, lineterminator="\n"); w.writeheader(); [w.writerow(r) for r in rows]
PY
out="$(python3 "$TOOL" --lang snobol4 --rungs-dir "$D" --origin "$ORIGIN" --source "$T/w.sno" --apply 2>&1)"; rc=$?
{ [ "$rc" = 2 ] && grep -qF "cannot determine the rungs' heap_kb convention" <<<"$out" && ! grep -q "$ORIGIN" "$D/ALL.csv"; } \
  && ck ok "(4) ladder rows disagreeing on heap_kb REFUSE rc 2 by name, nothing written" || ck no "(4) the disagreeing rungs: rc=$rc $(printf '%s\n' "$out" | grep -m1 REFUSED)"
python3 "$TOOL" --lang snobol4 --rungs-dir "$D" --origin "$ORIGIN" --source "$T/w.sno" --heap-kb 131072 --apply > /dev/null 2>&1; rc=$?
[ "$rc" = 0 ] && [ "$(col "$D/ALL.csv" "$ORIGIN" heap_kb)" = 131072 ] && ck ok "(5) --heap-kb resolves the disagreement and the row is minted with it" || ck no "(5) --heap-kb on the disagreeing rungs: rc=$rc"
# (6) RED PROOF: a copy of the tool with the one line that fills the columns removed leaves all four BLANK -- the build CEO-1323 found
# (the doctored dir is ../harness/scripts/ mirrored by symlink, so the tool's sibling modules and the harness it re-invokes resolve as in
#  the tree; only the tool itself is a real, doctored copy. Its S4E root then reads wrong, and --rungs-dir makes that moot.)
. "$HERE/lib_fixture_root.sh" || exit 2; fixture_root "$T/dx" || { echo "GATE UNPROVEN(2) [$GATE_NAME]: cannot stage a copied root at $T/dx"; exit 2; }; rm -f "$T/dx/harness/scripts/util_add_ladder_witness.py"; cp "$TOOL" "$T/dx/harness/scripts/"
python3 - "$T/dx/harness/scripts/util_add_ladder_witness.py" <<'PY' || refuse "the doctoring edit did not apply (the line that fills the attribute columns moved)"
import sys; p = sys.argv[1]; s = open(p).read(); b = s
s = s.replace("    new_row.update(attrs)\n", "")
sys.exit(1) if s == b else open(p, "w").write(s)
PY
D="$(fresh d)"; S4E_HOME="$S4E" python3 "$T/dx/harness/scripts/util_add_ladder_witness.py" --lang snobol4 --rungs-dir "$D" --origin "$ORIGIN" --source "$T/w.sno" --apply > "$T/doc.out" 2>&1; rc=$?
if [ "$rc" != 0 ]; then refuse "the doctored tool did not mint (rc=$rc): $(tail -1 "$T/doc.out")"; fi
blank=0; for c in heap_kb stack_kb compile_args run_args; do [ -z "$(col "$D/ALL.csv" "$ORIGIN" "$c")" ] && blank=$((blank+1)); done
[ "$blank" = 4 ] && ck ok "(6) RED PROOF: the tool without its fill line leaves all four attribute columns blank on the row, exactly the defect (arm 1 would read FAIL on that build)" || ck no "(6) the doctored tool left $blank of 4 blank -- the red proof does not discriminate"
echo "population: $((ok+red)) arm(s) over four scratch copies of the SNOBOL4 rungs ($(($(wc -l < "$M/ALL.csv")-1)) rows), one two-line witness, the real tool and one doctored copy; convention read $C_heap_kb/$C_stack_kb/$C_compile_args/'$C_run_args'"
[ "$red" = 0 ] && { echo "GATE PASS(0) [$G]: $ok of $ok arms hold"; exit 0; }
echo "⛔ GATE FAIL(1) [$G]: $red of $((ok+red)) arms red"; exit 1
