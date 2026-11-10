#!/usr/bin/env bash
# test_gate_container_format_2_two_groups_read_back_identical.sh -- A CONTAINER DIRECTORY IN FORMAT 2 (CIO-24 f, CIO-25, CIO-34; row
# tests-layout-the-container-is-two-groups-one-liner-and-multi-liner-with-stdin-and-stdout-named): ONE.EXT and ONE.out line for line,
# MULTI.md one section a test (the language, args, stdin, stdout and stderr fences), ALL.csv with group, road and nonl after entry. The
# bytes were agreed by officer_01 (the SCRIP switches) and officer_04 (this reader) on 2026-11-10; both LEDGERs hold the text.
# THE ARMS, over a scratch container whose answers are cut from sbl -bf (the ONE oracle, through sbl_correctness_bin):
#   1  regroup converts it: ALL.sno, ALL.ref and ALL.in are gone, ONE.sno holds the one one-liner, MULTI.md the rest, a block holding
#      three backticks is fenced with four, a stdin with no final newline is named in nonl, run_args moved into an args fence;
#   2  READ BACK IDENTICAL: every entry read from the new files equals the entry read from the old ones, every attribute (an independent
#      reading here, beside regroup's own);
#   3  REFUSALS: a one-liner with two answer lines is never put in ONE (it is in MULTI.md); a ONE.out given a second line for its one
#      row, a section out of index order and an unclosed fence each refuse rc 2; regroup of a container with an XFAIL entry refuses rc 2
#      and leaves every byte as it was;
#   4  THE VERDICT: the container graded in mode 3 through corpus_suite_harness.py run reads the same board before and after, every entry
#      PASS; FAIL-ONCE: the one-liner's ONE.out line corrupted in a copy reads that entry FAIL (the new reader is what grades).
# EXIT 0 all hold; 1 an arm failed; 2 could not measure.
export S4E_ONE_RUNNER_FIXTURE="gate arm ${0##*/}: the harness over a scratch container outside the corpus, not a board (R-547)"
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/lib_gate.sh" || { echo "REFUSING(2): cannot load lib_gate.sh"; exit 2; }
GATE_NAME=container_format_2_two_groups_read_back_identical
gate_parse_args "$@"
. "$HERE/lib_oracle_flags.sh" || { echo "GATE UNPROVEN(2) [$GATE_NAME]: cannot load lib_oracle_flags.sh"; exit 2; }
H="$HERE/corpus_suite_harness.py"; gate_require "$H" "corpus_suite_harness.py" || exit 2
"$HERE/util_require_fresh.sh" --gate "$GATE_NAME" >/dev/null 2>&1 || { echo "GATE UNPROVEN(2) [$GATE_NAME]: this tree's binary is stale or unbuilt -- make"; exit 2; }
SBL="$(sbl_correctness_bin)" && [ -x "$SBL" ] || { echo "GATE UNPROVEN(2) [$GATE_NAME]: the SNOBOL4 oracle is not installed"; exit 2; }
W=$(mktemp -d) || exit 2; trap 'rm -rf "$W"' EXIT INT TERM
export TMPDIR="$W"
fails=0; n=0
ck() { n=$((n+1)); if eval "$2"; then echo "  ok   $1"; else fails=$((fails+1)); echo "  FAIL $1"; fi; }

# ---- the fixture: programs, stdin, answers cut from the oracle twice --------------------------------------------------------------
mkdir -p "$W/p"
printf "%s\n" " OUTPUT = 'one';END" > "$W/p/a.sno"
printf "%s\n" " OUTPUT = 'x'; OUTPUT = 'y';END" > "$W/p/b.sno"
printf "%s\n" "L       OUTPUT = INPUT    :S(L)" "        OUTPUT = 'q' '\`\`\`' 'q'" "END" > "$W/p/c.sno"
printf "## not a heading\n\`\`\`\nlast" > "$W/p/c.in"
printf "%s\n" "        X = 1" "END" > "$W/p/e.sno"
printf "%s\n" "        OUTPUT = 'args'" "END" > "$W/p/g.sno"
for p in a b c e g; do
  i=/dev/null; [ -f "$W/p/$p.in" ] && i="$W/p/$p.in"
  for k in 1 2; do timeout -k 5 8 "$SBL" -bf "$W/p/$p.sno" < "$i" > "$W/p/$p.out$k" 2>/dev/null; done
  cmp -s "$W/p/$p.out1" "$W/p/$p.out2" || { echo "GATE UNPROVEN(2) [$GATE_NAME]: sbl -bf gave two answers for $p.sno"; exit 2; }
done
python3 - "$HERE" "$W" <<'PY' || { echo "GATE UNPROVEN(2) [$GATE_NAME]: could not build the scratch container"; exit 2; }
import sys; from pathlib import Path
sys.path.insert(0, sys.argv[1]); import corpus_suite_harness as h
w = Path(sys.argv[2]); p = w / "p"
def out(n): return (p / f"{n}.out1").read_text()
def block(n, **kw): return h.Entry("block", 0, n, h._lf_lines((p / f"{n}.sno").read_text()), h._lf_lines(out(n)), **kw)
es = [h.Entry("line", 0, "a", [(p / "a.sno").read_text().rstrip("\n") + ";* a"], out("a").rstrip("\n")),
      h.Entry("line", 0, "b", [(p / "b.sno").read_text().rstrip("\n") + ";* b"], out("b").rstrip("\n")),
      block("c", stdin=(p / "c.in").read_text()), block("e"), block("g")]
assert es[3].ref == [] and "\n" in es[1].ref and not es[2].stdin.endswith("\n")
for d in ("old", "xf"):
    (w / d).mkdir()
    h.write_suite(es, str(w / d / "ALL.sno"), str(w / d / "ALL.ref"), out_in=str(w / d / "ALL.in"))
    rows = ["rank,entry,origin,family,kind,xfail,n_lines,heap_kb,stack_kb,compile_args,run_args"]
    for i, e in enumerate(es, 1):
        rows.append(f"{i},{e.name},gate,gate,{e.kind},0,{len(e.sno_lines)},,,,{'alpha beta' if e.name == 'g' else ''}")
    (w / d / "ALL.csv").write_text("\n".join(rows) + "\n")
t = (w / "xf" / "ALL.sno").read_text().replace(" c\n", " c XFAIL\n", 1); (w / "xf" / "ALL.sno").write_text(t)
t = (w / "xf" / "ALL.ref").read_text().replace(" c\n", " c XFAIL\n", 1); (w / "xf" / "ALL.ref").write_text(t)
PY
cp -a "$W/old" "$W/new"

# ---- arm 1: regroup ---------------------------------------------------------------------------------------------------------------
o1=$(timeout -k 5 120 python3 "$H" regroup "$W/new" 2>&1); r1=$?
echo "$o1" | grep '^REGROUP_BOARD' | sed 's/^/  /'
ck "regroup rc 0 and its board line" '[ $r1 = 0 ] && grep -q "^REGROUP_BOARD .* entries=5 one=1 multi=4 " <<<"$o1"'
ck "the old files are gone" '! test -e "$W/new/ALL.sno" && ! test -e "$W/new/ALL.ref" && ! test -e "$W/new/ALL.in"'
ck "ONE.sno holds the one one-liner, ONE.out its answer" '[ "$(cat "$W/new/ONE.sno")" = " OUTPUT = '"'"'one'"'"';END;* a" ] && [ "$(cat "$W/new/ONE.out")" = one ]'
ck "MULTI.md: four sections in index order; a stdin line opening with two hashes stays stdin" '[ "$(grep -x -e "## b" -e "## c" -e "## e" -e "## g" "$W/new/MULTI.md" | tr "\n" " ")" = "## b ## c ## e ## g " ] && grep -qx "## not a heading" "$W/new/MULTI.md" && [ "$(python3 -c "import sys;sys.path.insert(0,sys.argv[1]);import corpus_suite_harness as h;print(len(h._fmt2_parse_md(sys.argv[2],\".sno\")))" "$HERE" "$W/new/MULTI.md")" = 4 ]'
ck "three backticks inside a block take a fence of four" 'grep -qx "\`\`\`\`stdin" "$W/new/MULTI.md" && grep -qx "\`\`\`\`stdout" "$W/new/MULTI.md"'
ck "ALL.csv: group road nonl after entry; c names stdin in nonl; g run_args emptied" 'head -1 "$W/new/ALL.csv" | grep -q "^rank,entry,group,road,nonl,origin" && grep -q "^3,c,multi,direct,stdin," "$W/new/ALL.csv" && grep -q "^5,g,multi,direct,,gate,gate,block,0,2,,,,$" "$W/new/ALL.csv"'
ck "g's arguments are an args fence, one a line" 'awk "/^## g\$/{f=1} f" "$W/new/MULTI.md" | grep -A2 -x "\`\`\`args" | tail -2 | tr "\n" " " | grep -qx "alpha beta "'

# ---- arm 2: read back identical, read here independently ------------------------------------------------------------------------
o2=$(python3 - "$HERE" "$W" <<'PY' 2>&1
import sys; from pathlib import Path
sys.path.insert(0, sys.argv[1]); import corpus_suite_harness as h
w = Path(sys.argv[2])
old = h.read_suite(str(w / "old/ALL.sno"), str(w / "old/ALL.ref"), in_path=str(w / "old/ALL.in"))
new = h.read_suite(str(w / "new/ALL.sno"), str(w / "new/ALL.ref"))
print("N", len(old), len(new))
for o, e in zip(old, new):
    print("SAME" if vars(o) == vars(e) else f"DIFF {o.name} {vars(o)} {vars(e)}")
PY
)
ck "every entry read from format 2 equals its old reading, every attribute" '[ "$(grep -c "^SAME" <<<"$o2")" = 5 ] && grep -q "^N 5 5$" <<<"$o2"'

# ---- arm 3: the refusals ----------------------------------------------------------------------------------------------------------
ck "the one-liner with two answer lines is in MULTI.md, never in ONE" '[ "$(wc -l < "$W/new/ONE.sno")" = 1 ] && grep -qx "## b" "$W/new/MULTI.md"'
cp -a "$W/new" "$W/r1"; echo "two" >> "$W/r1/ONE.out"
timeout -k 5 60 python3 "$H" list "$W/r1/ALL.sno" "$W/r1/ALL.ref" >/dev/null 2>&1; rr1=$?
ck "a ONE.out with a second answer line for its one row refuses" '[ $rr1 != 0 ]'
cp -a "$W/new" "$W/r2"; python3 - "$W/r2/MULTI.md" <<'PY'
import sys; t = open(sys.argv[1]).read(); a, b = t.index("## b\n"), t.index("## c\n"); c = t.index("## e\n")
open(sys.argv[1], "w").write(t[b:c] + t[a:b] + t[c:])
PY
timeout -k 5 60 python3 "$H" list "$W/r2/ALL.sno" "$W/r2/ALL.ref" >/dev/null 2>&1; rr2=$?
ck "a section out of index order refuses" '[ $rr2 != 0 ]'
cp -a "$W/new" "$W/r3"; python3 -c "import sys;p=sys.argv[1];t=open(p).read();open(p,'w').write(t[:t.rindex('\`\`\`')])" "$W/r3/MULTI.md"
timeout -k 5 60 python3 "$H" list "$W/r3/ALL.sno" "$W/r3/ALL.ref" >/dev/null 2>&1; rr3=$?
ck "an unclosed fence refuses" '[ $rr3 != 0 ]'
before=$(cd "$W/xf" && sha1sum * | sha1sum)
timeout -k 5 60 python3 "$H" regroup "$W/xf" >/dev/null 2>&1; rx=$?
ck "regroup of a container with an XFAIL entry refuses rc 2 and changes no byte" '[ $rx = 2 ] && [ "$(cd "$W/xf" && sha1sum * | sha1sum)" = "$before" ]'

# ---- arm 4: the same verdict in mode 3 before and after; fail once on a corrupted answer --------------------------------------------
board() { S4E_PROGRESS_DB="$W/db.$2.tsv" timeout -k 5 600 python3 "$H" run "$1/ALL.sno" "$1/ALL.ref" --modes m3 2>&1 | grep '^SUITE_BOARD' | head -1 | grep -o 'total=[0-9]* .* m3_skip=[0-9]*'; }
bo=$(board "$W/old" old); bn=$(board "$W/new" new)
[ -n "$bo" ] && [ -n "$bn" ] || { echo "GATE UNPROVEN(2) [$GATE_NAME]: the harness printed no SUITE_BOARD line (old: ${bo:-none}; new: ${bn:-none})"; exit 2; }
echo "  old: $bo"; echo "  new: $bn"
ck "mode 3 reads the same board before and after regroup" '[ "$bo" = "$bn" ]'
ck "every entry PASS in mode 3 (the fixture grades what it claims)" 'grep -q "m3_n=5 m3_pass=5 m3_fail=0" <<<"$bn"'
cp -a "$W/new" "$W/bad"; echo "not one" > "$W/bad/ONE.out"
bb=$(board "$W/bad" bad)
ck "FAIL-ONCE: the corrupted ONE.out answer reads FAIL" 'grep -q "m3_pass=4 m3_fail=1" <<<"$bb"'

# ---- arm 5: THE POST STEP (CIO-32 (6)): the switches run the tests, run --post grades their OUT; the same board; fail once ----------
SC="$HERE/../../SCRIP/scrip"
"$SC" --run-one-liners "$W/nope" --out "$W/nope2" >/dev/null 2>&1; [ $? = 2 ] || { echo "GATE UNPROVEN(2) [$GATE_NAME]: $SC has no --run-one-liners (CIO-32): build SCRIP at or after f99ab66f2"; exit 2; }
mkdir -p "$W/o1" "$W/om"
SNO_LIB="$HERE/../../corpus/include" timeout -k 5 120 "$SC" --run-one-liners "$W/new" --out "$W/o1" > "$W/r1.tsv" 2>/dev/null; s1=$?
SNO_LIB="$HERE/../../corpus/include" timeout -k 5 120 "$SC" --run-multi-liners "$W/new" --out "$W/om" > "$W/rm.tsv" 2>/dev/null; s2=$?
ck "the switches run every test: rc 0, five report lines, all EXIT" '[ $s1 = 0 ] && [ $s2 = 0 ] && [ "$(cut -f2 "$W/r1.tsv" "$W/rm.tsv" | sort | uniq -c | tr -s " ")" = " 5 EXIT" ]'
post() { S4E_PROGRESS_DB="$W/db.$2.tsv" timeout -k 5 600 python3 "$H" run "$1/ALL.sno" "$1/ALL.ref" --modes m3 --post "$W/o1" "$W/r1.tsv" --post "$W/om" "$W/rm.tsv" 2>&1; }
po=$(post "$W/new" post); bp=$(grep '^SUITE_BOARD' <<<"$po" | head -1 | grep -o 'total=[0-9]* .* m3_skip=[0-9]*')
echo "  post: $bp"; grep '^POST_BOARD' <<<"$po" | sed 's/^/  /'
ck "the post step reads the board the Python road reads, every test graded from OUT" '[ -n "$bp" ] && [ "$bp" = "$bn" ] && grep -q "^POST_BOARD graded_from_out=5 per_process=0 " <<<"$po"'
printf 'corrupted\n' > "$W/om/e.out"
pb=$(post "$W/new" postbad | grep '^SUITE_BOARD' | head -1)
ck "FAIL-ONCE: a corrupted NAME.out reads that test FAIL" 'grep -q "m3_pass=4 m3_fail=1" <<<"$pb"'
echo "e	EXIT	0	0.001	0.001	1" >> "$W/rm.tsv"
post "$W/new" twice >/dev/null 2>&1; rt=$?
ck "a report naming one test twice refuses rc 2" '[ $rt = 2 ]'

if [ "$fails" -eq 0 ]; then echo "GATE PASS [$GATE_NAME]: $n of $n checks hold"; gate_stamp; exit 0; fi
echo "⛔ GATE FAIL [$GATE_NAME]: $fails of $n check(s) failed"; gate_stamp; exit 1
