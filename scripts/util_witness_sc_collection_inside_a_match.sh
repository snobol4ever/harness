#!/usr/bin/env bash
# util_witness_sc_collection_inside_a_match.sh -- THE WITNESS of a collection in the middle of a pattern match with pending conditional assignments (the ceo, CEO-1650).
# bootstrap/parser_snobol4.sc notes each statement's start position from inside its Compiland match (an immediate cursor assignment and a deferred predicate); when the
# note went into a TABLE, the table's growth allocated during the match, a collection ran while the match held hundreds of pending conditional assignments, and the
# tree the pends built afterwards carried a child that was not a node: TreeDumpAt died with error 41 (field function argument is wrong datatype) on
# corpus/programs/lon_cherryholmes/sno/attr31.sno under PARSER_TREE_HASH=1, deterministically, and not with a 3 GB first window. The parser stores the notes in an
# ARRAY sized before the match (no allocation inside the match) and is green; this witness rebuilds the TABLE variant from the tree's parser by one textual
# substitution and runs attr31 through it. GREEN (rc 0) when the variant parses attr31 in hash mode: the collector keeps every pend; RED (rc 1) while it does not.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)"; B="$ROOT/bootstrap"; CORPUS="${CORPUS:-$(cd "$ROOT/../corpus" 2>/dev/null && pwd)}"
W="$CORPUS/programs/lon_cherryholmes/sno/attr31.sno"
[ -x "$ROOT/scrip" ] || { echo "⛔ REFUSE(2): no $ROOT/scrip -- make first"; exit 2; }
[ -f "$W" ] || { echo "⛔ REFUSE(2): no witness $W"; exit 2; }
. "$HERE/lib_declared_arena.sh" || { echo "⛔ REFUSE(2): cannot load lib_declared_arena.sh"; exit 2; }
SW="$(declared_switches_beside "$B/parser_snobol4.sc")" && [ -n "$SW" ] || { echo "⛔ REFUSE(2): bootstrap/parser_snobol4.sc declares no heap or stack"; exit 2; }
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
grep -q 'StmtPosA\[StmtPosN\] = StmtAt;' "$B/parser_snobol4.sc" || { echo "⛔ REFUSE(2): the parser no longer notes statement positions into StmtPosA -- re-cut this witness"; exit 2; }
sed -e 's/StmtPosA\[StmtPosN\] = StmtAt;/StmtPosT[StmtPosN] = StmtAt;/' -e 's/StmtPosA = ARRAY(SIZE(Src) + 2);/StmtPosT = TABLE(64);/' -e 's/p = StmtPosA\[StmtNo + 1\];/p = StmtPosT[StmtNo + 1];/' "$B/parser_snobol4.sc" > "$T/parser_variant.sc"
grep -q 'StmtPosT' "$T/parser_variant.sc" || { echo "⛔ REFUSE(2): the substitution produced no TABLE variant"; exit 2; }
cat "$B/global.sc" "$B/case.sc" "$B/assign.sc" "$B/match.sc" "$B/counter.sc" "$B/stack.sc" "$B/tree.sc" "$B/ShiftReduce.sc" "$B/tdump.sc" "$B/gen.sc" "$B/qize.sc" "$B/semantic.sc" "$B/omega.sc" "$B/trace.sc" "$T/parser_variant.sc" > "$T/chain.sc"
"$ROOT/scrip" --compile "$T/chain.sc" -o "$T/chain.s" </dev/null >/dev/null 2>&1 && gcc -m64 -no-pie -rdynamic "$T/chain.s" -Wl,-rpath,"$ROOT/out" -L"$ROOT/out" -lscrip_rt -lm -lpthread -o "$T/chain.bin" 2>/dev/null \
    || { echo "⛔ REFUSE(2): the TABLE variant of the chain did not compile or link"; exit 2; }
( cd "$(dirname "$W")"; PARSER_TREE_HASH=1 timeout -k 5 300 "$T/chain.bin" $SW < "$W" > "$T/out.txt" 2> "$T/err.txt" ); rc=$?
( cd "$(dirname "$W")"; PARSER_TREE_HASH=1 timeout -k 5 300 "$T/chain.bin" $SW -i3000m < "$W" > "$T/out_big.txt" 2> "$T/err_big.txt" ); rcb=$?
echo "WITNESS sc-collection-inside-a-match: attr31 through the TABLE variant rc=$rc ($(head -1 "$T/err.txt" | cut -c1-70)); with a 3 GB first window rc=$rcb"
[ $rc -eq 0 ] && { echo "✅ GREEN: a collection inside the match kept every pend"; exit 0; }
[ $rcb -eq 0 ] && { echo "⛔ RED: the tree built after a collection inside the match carries a child that is not a node (rc $rc), and not when no collection runs (rc $rcb)"; exit 1; }
echo "⛔ REFUSE(2): the variant fails even without a collection (rc $rcb): the witness is not the collector's"; exit 2
