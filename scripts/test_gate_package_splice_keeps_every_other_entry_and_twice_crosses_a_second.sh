#!/usr/bin/env bash
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
# test_gate_package_splice_keeps_every_other_entry_and_twice_crosses_a_second.sh -- util_build_package_suite.py --only NAME[,NAME...]
# cuts only the named programs from the oracle and splices them into the existing container, every other entry byte-identical; and
# --twice runs the oracle a second time in a LATER wall-clock second than the first run ended in.
#
# WHY (the cqo 2026-11-04, row corpus-the-twenty-programs-with-no-reading-...-r-2029): a whole rebuild of rosetta-pascal re-cut every
# ref and moved 30 of the 311 its rows had graded, so 18 owed programs could land only by a splice. And --twice absorbed
# sleeping-beauty-problem, whose fpc randomize seeds from the clock in whole seconds: both sub-second runs drew one seed (hand runs
# 2.5 s apart printed 1500363, 1498900, 1499633 wakings), and the same blind spot let date and random printers through the rebuild.
#
# THE ARMS (a scratch SNOBOL4 package, the oracle sbl -bf):
#   1  --only C appends C as entry 3; ALL.sno and ALL.ref before the splice are byte prefixes of after; A's and B's ALL.csv lines unchanged
#   2  --only a name the package does not ship refuses rc=2 and writes nothing
#   3  --twice --only D, where D prints DATE() (seconds), excludes D as nondeterministic and leaves the container as it was
#   4  --twice --only A after A is changed to print DATE() refuses rc=2 (an excluded entry already in the container) and writes nothing
#   5  --only B after B is changed to print 'b2' re-cuts B in place: banner number 2 kept, ref b2, A and C unchanged
#   6  a container whose ALL.csv carries test-cycle step 6's timeout_s column (A 300, B 120, C none) re-splices --only B: rc 0, the
#      header and A's and C's lines unchanged, B's 120 carried (the splice refused rc 2 on all 25 such containers, the cfo 2026-11-07)
# EXIT: 0 all arms pass · 1 an arm failed · 2 REFUSED (no binary, no oracle).
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
NAME=test_gate_package_splice_keeps_every_other_entry_and_twice_crosses_a_second
refuse() { echo "GATE REFUSE(2) [$NAME]: $*"; exit 2; }
[ -x "$ROOT/scrip" ] || refuse "no scrip binary -- cannot measure"
[ -x /home/resources/x64/bin/sbl ] || refuse "no sbl oracle -- the builder cannot cut a ref"
T="$(mktemp -d)" || refuse "no tmpdir"
trap 'rm -rf "$T"' EXIT
P="$T/pkg"; mkdir -p "$P"
src() { printf '%s\n' "        OUTPUT = $2" END > "$P/$1.sno"; }
src A "'a'"; src B "'b'"
bld() { ( cd "$ROOT" && python3 ../harness/scripts/util_build_package_suite.py "$P" --lang snobol4 "$@" > "$T/build.log" 2>&1 ); }
bld || refuse "the builder did not build the scratch package: $(tail -3 "$T/build.log" | tr '\n' '|')"
[ -f "$P/ALL.sno" ] && [ -f "$P/ALL.ref" ] && [ -f "$P/ALL.csv" ] || refuse "the builder wrote no ALL.sno, ALL.ref or ALL.csv"
snap() { rm -rf "$T/$1"; mkdir -p "$T/$1"; cp "$P"/ALL.* "$T/$1/"; }
same() { for f in "$T/$1"/ALL.*; do cmp -s "$f" "$P/$(basename "$f")" || return 1; done; [ "$(ls "$P"/ALL.* | wc -l)" = "$(ls "$T/$1"/ALL.* | wc -l)" ]; }
csvline() { grep -E "^[0-9]+,$2," "$1/ALL.csv"; }
eref() { awk -v e="$2" '$0 ~ "^\\*-+ [0-9]+ "e"$" {f=1; next} /^\*-+ [0-9]+ /{f=0} f' "$1/ALL.ref"; }
banner() { grep -E "^\*-+ [0-9]+ $2$" "$1/ALL.sno" | awk '{print $2}'; }
prefix() { head -c "$(stat -c %s "$T/v0/$1")" "$P/$1" | cmp -s - "$T/v0/$1"; }
[ "$(banner "$P" A)" = 1 ] && [ "$(eref "$P" A)" = a ] || refuse "the scratch container does not read as the gate expects (A banner [$(banner "$P" A)] ref [$(eref "$P" A)])"
fail=0; n=0
arm() { n=$((n+1)); if [ "$2" = ok ]; then echo "  ok   arm $n  $1"; else echo "  FAIL arm $n  $1 -- $2"; fail=1; fi; }
snap v0; src C "'c'"
bld --only C; rc=$?
arm "--only C appends C as entry 3, the old container a byte prefix, A's and B's ALL.csv lines unchanged" "$([ "$rc" = 0 ] && [ "$(banner "$P" C)" = 3 ] && [ "$(eref "$P" C)" = c ] && prefix ALL.sno && prefix ALL.ref && [ "$(csvline "$P" A)" = "$(csvline "$T/v0" A)" ] && [ "$(csvline "$P" B)" = "$(csvline "$T/v0" B)" ] && echo ok || echo "rc=$rc banner=$(banner "$P" C) $(tail -2 "$T/build.log" | tr '\n' '|')")"
snap v1
bld --only NOPE; rc=$?
arm "--only a name not shipped refuses rc=2 and writes nothing" "$([ "$rc" = 2 ] && same v1 && echo ok || echo "rc=$rc")"
src D "DATE()"
bld --twice --only D; rc=$?
arm "--twice --only D (prints DATE() with seconds) excludes D as nondeterministic, the container unchanged" "$([ "$rc" = 0 ] && grep -q 'D: EXCLUDED (oracle nondeterministic)' "$T/build.log" && cmp -s "$T/v1/ALL.sno" "$P/ALL.sno" && cmp -s "$T/v1/ALL.ref" "$P/ALL.ref" && echo ok || echo "rc=$rc $(grep 'D:' "$T/build.log" | tail -1)")"
rm -f "$P/D.sno"; rm -f "$P"/ALL.*; cp "$T/v1"/ALL.* "$P/"
src A "DATE()"
bld --twice --only A; rc=$?
arm "--twice --only A, A now printing DATE(), refuses rc=2 (an entry in the container excluded) and writes nothing" "$([ "$rc" = 2 ] && same v1 && echo ok || echo "rc=$rc $(tail -1 "$T/build.log")")"
src A "'a'"; src B "'b2'"
bld --only B; rc=$?
arm "--only B re-cuts B in place: banner 2 kept, ref b2, A and C unchanged" "$([ "$rc" = 0 ] && [ "$(banner "$P" B)" = 2 ] && [ "$(eref "$P" B)" = b2 ] && [ "$(eref "$P" A)" = a ] && [ "$(eref "$P" C)" = c ] && [ "$(csvline "$P" A)" = "$(csvline "$T/v1" A)" ] && [ "$(csvline "$P" C)" = "$(csvline "$T/v1" C)" ] && echo ok || echo "rc=$rc banner=$(banner "$P" B) ref=$(eref "$P" B)")"
python3 -c 'import csv,sys; f=sys.argv[1]; r=list(csv.reader(open(f))); i=r[0].index("stack_kb")+1; v={"A":"300","B":"120"}; [x.insert(i,"timeout_s" if j==0 else v.get(x[1],"")) for j,x in enumerate(r)]; csv.writer(open(f,"w",newline=""),lineterminator="\n").writerows(r)' "$P/ALL.csv"; snap v2
src B "'b3'"
bld --only B; rc=$?
arm "a container with a timeout_s column re-splices --only B: header, A and C unchanged, B's timeout_s 120 carried" "$([ "$rc" = 0 ] && [ "$(eref "$P" B)" = b3 ] && [ "$(head -1 "$P/ALL.csv")" = "$(head -1 "$T/v2/ALL.csv")" ] && [ "$(csvline "$P" A)" = "$(csvline "$T/v2" A)" ] && [ "$(csvline "$P" C)" = "$(csvline "$T/v2" C)" ] && [ "$(python3 -c 'import csv,sys; r=list(csv.DictReader(open(sys.argv[1]))); print([x["timeout_s"] for x in r if x["entry"]=="B"][0])' "$P/ALL.csv")" = 120 ] && echo ok || echo "rc=$rc ref=$(eref "$P" B) $(tail -1 "$T/build.log")")"
[ "$fail" = 0 ] && { echo "GATE OK [$NAME]: $n arms"; exit 0; }
echo "GATE FAIL [$NAME]: $(( n )) arms, at least one red"; exit 1
