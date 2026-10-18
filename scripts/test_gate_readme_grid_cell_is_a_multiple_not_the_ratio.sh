#!/usr/bin/env bash
export S4E_MINT_NO_CRITERION="gate fixture: the row under test exercises the bus, not work (CEO-1386)"
# test_gate_readme_grid_cell_is_a_multiple_not_the_ratio.sh -- A PUBLISHED GRID CELL IS THE MULTIPLE ITS CITED TSV GIVES, NEVER
# THE TSV's SELF-AGREEMENT RATIO (coo 2026-09-16; cfo's mint from hq_pascal's measurement; row perf-a-published-grid-cell-must-
# come-from-the-grid-printer-a-gate-reads-each-cited-tsv-and-refuses-a-cell-equal-to-the-ratio-field-not-the-multiple).
#
# THE DEFECT: all eight Pascal cells published in README.md at a44783caf equalled the RATIO column (angle2/angle1, near 1.0 by
# construction) of the run they cited, corpus/benchmarks/pascal/triangulation-20260904T021323Z.tsv, while that run's true
# multiples against fpc were 0.000675x to 0.03x; retracted by the ceo (CEO-798). Every instrument was honest; the COPYING step
# -- a seat pasting a column instead of a printed grid -- had no instrument asserting about it. This gate is that instrument.
#
# WHAT IT READS: every markdown grid row `| <kernel> | **N.NNx** | **N.NNx** |` (m3, m4) in README.md whose section (the text
# since the previous '## ' heading) cites a triangulation-*.tsv. From that TSV (kernel, engine, angle1_rate, angle2_rate, ratio,
# verdict): the MULTIPLE for engine m3/m4 is its angle1_rate over the reference engine's (fpc, sbl, iconx... -- the row that is\n# neither m3 nor m4) angle1_rate; the RATIO is the engine row's own
# ratio field. A cell equal (to two decimals) to the ratio and not to the multiple is REFUSED, by kernel and column.
#
# VERDICT: rc=0 with the population printed (cells graded; a kernel absent from its own cited TSV is UNVERIFIABLE, printed, not\n# red; zero graded is printed as zero, never as a pass of something); rc=1 on
# a ratio cell; rc=2 when a cited TSV is missing or unreadable. --selftest plants a README fragment and a TSV with one ratio cell
# and one multiple cell and proves rc=1 naming the ratio cell, then rc=0 once it is the multiple. FAIL_ONCE=1 corrupts the
# selftest's planted multiple cell into the ratio to prove the arm trips.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
README="${S4E_README:-$ROOT/README.md}"; CORPUS="${S4E_CORPUS_ROOT:-$ROOT/../corpus}"
grade(){ python3 - "$1" "$2" <<'PY'
import sys, re, os
readme, corpus = sys.argv[1], sys.argv[2]
txt = open(readme, encoding="utf-8").read()
graded = 0; bad = []; missing = []
section_start = 0
sections = [m.start() for m in re.finditer(r"^#{2,6} ", txt, re.M)] + [len(txt)]   # every heading level: each language grid sits under its own ### heading
unverifiable = []
for i in range(len(sections) - 1):
    sec = txt[sections[i]:sections[i + 1]]
    cites = re.findall(r"(triangulation-[0-9TZ]+\.tsv)", sec)
    if not cites:
        continue
    rows = re.findall(r"^\|\s*([a-z_0-9]+)\s*\|\s*(?:\*\*)?([0-9.]+)x(?:\*\*)?\s*\|\s*(?:\*\*)?([0-9.]+)x(?:\*\*)?\s*\|", sec, re.M)
    if not rows:
        continue
    tsvs = []
    for c in dict.fromkeys(cites):
        found = None
        for root, _d, files in os.walk(corpus):
            if c in files:
                found = os.path.join(root, c); break
        if not found:
            missing.append(c); continue
        tsvs.append(found)
    if missing and not tsvs:
        continue
    data = {}
    for t in tsvs:
        for l in open(t, encoding="utf-8"):
            if l.startswith("#") or l.startswith("kernel"): continue
            f = l.rstrip("\n").split("\t")
            if len(f) >= 5:
                data.setdefault(f[0], {})[f[1]] = (float(f[2]) if f[2] not in ("", "-") else 0.0, float(f[4]) if f[4] not in ("", "-") else 0.0)
    for kernel, c3, c4 in rows:
        for eng, cell in (("m3", c3), ("m4", c4)):
            graded += 1
            k = data.get(kernel, {})
            refs = [e for e in k if e not in ("m3", "m4", "ast")]
            if eng not in k or not refs:
                graded -= 1
                unverifiable.append(f"{kernel}/{eng}: cell {cell}x -- the cited TSV carries no {eng} row or no reference-engine row for this kernel"); continue
            rate, ratio = k[eng]; ref = k[refs[0]][0]
            mult = rate / ref if ref else 0.0
            if round(float(cell), 2) == round(ratio, 2) and round(float(cell), 2) != round(mult, 2):
                bad.append(f"{kernel}/{eng}: published {cell}x IS the TSV's self-agreement ratio {ratio:.4f}, not the multiple {mult:.6f}x against {refs[0]}")
print(f"population: {graded} grid cell(s) graded against their cited TSV(s)" + (f"; {len(unverifiable)} cell(s) UNVERIFIABLE (kernel not in the cited TSV)" if unverifiable else "") + (f"; {len(missing)} cited TSV(s) missing: {', '.join(missing)}" if missing else ""))
for u in unverifiable: print("    unverifiable: " + u)
if missing and graded == 0:
    print("⛔ GATE REFUSES (rc=2): a grid cites a TSV that is not in the corpus, so its cells cannot be graded"); sys.exit(2)
if bad:
    print(f"⛔ GATE RED [readme_grid_cell_is_a_multiple_not_the_ratio]: {len(bad)} of {graded} cell(s) are the ratio column, not the multiple:")
    for b in bad: print("    " + b)
    print("    cure: paste a grid PRINTED by lib_perf_fmt.sh (perf_row computes the multiple), never a TSV column")
    sys.exit(1)
print(f"GATE PASS [readme_grid_cell_is_a_multiple_not_the_ratio]: {graded} of {graded} cited cell(s) are multiples")
PY
}
if [ "${1:-}" = "--selftest" ]; then
  W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT; mkdir -p "$W/corpus/benchmarks/pascal"
  printf 'kernel\tengine\tangle1_rate\tangle2_rate\tratio\tverdict\n' > "$W/corpus/benchmarks/pascal/triangulation-20990101T000000Z.tsv"
  printf 'queens\tfpc\t1000\t1010\t1.0100\tAGREE\nqueens\tm3\t10\t9.9\t0.9900\tAGREE\nqueens\tm4\t20\t21.4\t1.0700\tAGREE\n' >> "$W/corpus/benchmarks/pascal/triangulation-20990101T000000Z.tsv"
  M4="0.02x"; [ -n "${FAIL_ONCE:-}" ] && M4="1.07x"
  printf '## Pascal\n\nrun triangulation-20990101T000000Z.tsv\n\n| kernel | m3 | m4 |\n|---|---|---|\n| queens | **0.99x** | **%s** |\n' "$M4" > "$W/README.md"
  fails=0; ck(){ if [ "$1" = ok ]; then echo "  ok    $2"; else echo "  FAIL  $2"; fails=$((fails+1)); fi; }
  out="$(grade "$W/README.md" "$W/corpus")"; rc=$?
  [ "$rc" = 1 ] && grep -q 'queens/m3: published 0.99x IS the TSV' <<<"$out" && ! grep -q 'queens/m4:' <<<"$out" && ck ok "(a) the planted ratio cell (m3 0.99x = ratio) is RED by name; the multiple cell (m4 0.02x) is not" || ck no "(a) rc=$rc -- got: $out"
  printf '## Pascal\n\nrun triangulation-20990101T000000Z.tsv\n\n| kernel | m3 | m4 |\n|---|---|---|\n| queens | **0.01x** | **0.02x** |\n' > "$W/README.md"
  out="$(grade "$W/README.md" "$W/corpus")"; rc=$?
  [ "$rc" = 0 ] && grep -q 'population: 2' <<<"$out" && ck ok "(b) both cells the multiples: rc=0, population 2" || ck no "(b) rc=$rc -- got: $out"
  printf '## Pascal\n\nrun triangulation-20000101T000000Z.tsv\n\n| kernel | m3 | m4 |\n|---|---|---|\n| queens | **0.01x** | **0.02x** |\n' > "$W/README.md"
  out="$(grade "$W/README.md" "$W/corpus")"; rc=$?
  [ "$rc" = 2 ] && ck ok "(c) a cited TSV missing from the corpus: rc=2 REFUSES" || ck no "(c) rc=$rc -- got: $out"
  echo "population: 3 selftest arm(s), $fails FAIL"; [ "$fails" = 0 ] && { echo "GATE PASS [readme_grid_cell_is_a_multiple_not_the_ratio --selftest]: 3 of 3"; exit 0; }; echo "⛔ GATE RED [selftest]: $fails FAIL"; exit 1
fi
[ -f "$README" ] || { echo "⛔ GATE REFUSES (rc=2): no README at $README"; exit 2; }
grade "$README" "$CORPUS"
