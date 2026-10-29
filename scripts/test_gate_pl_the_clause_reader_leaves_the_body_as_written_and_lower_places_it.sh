#!/usr/bin/env bash
# test_gate_pl_the_clause_reader_leaves_the_body_as_written_and_lower_places_it.sh -- THE PROLOG CLAUSE READER HANDS LOWER THE BODY AS THE SOURCE WROTE IT AND LOWER PLACES IT (hq_prolog 2026-10-29,
# row prolog-the-clause-body-placing-moves-from-the-parser-into-lower; CEO-1532 "a parser moves nothing, the lowerer places it"; ARCH-PROLOG-CLPR-CHR section 8, cto CTO-397).
#
# Today the clause reader (src/parsers/prolog/prolog_parse.c) turns ( C -> T ; E ) into a TT_IF node and flattens conjunctions before lower sees the clause, so --dump-ast prints the PLACED form. The
# rule is one placing function in src/lower/, called by the clause road and the CHR road alike; the parser keeps the source shape: the disjunction as TT_FNC ;, the if-then as TT_FNC ->, the soft cut
# as TT_FNC *->, a parenthesised conjunction as TT_FNC ,. Two measurements, both on the witness w.pl:
#   shape   --dump-ast of p/1 and q/1 shows the source operators and NO TT_IF node (p: ( X > 1 -> a ; b ), c, d; q: a, ( b, c ), d; r: a soft cut and a negation)
#   same    the witness runs in mode 3 and mode 4 and prints what swipl 9 prints, cut from swipl in THIS run (swipl_bin) -- the move changes no behaviour
# (the IR half of the move -- --dump-ir of the witness procedures byte-identical before and after -- is the landing's own before/after hash, recorded in the row's ledger: a pinned hash would
# go stale with every unrelated lowerer landing.) rc=0 both hold · rc=1 one does not · rc=2 REFUSAL (no swipl, no build, swipl did not answer).
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }; G=pl_the_clause_reader_leaves_the_body_as_written_and_lower_places_it
[ -x "$ROOT/scrip" ] || { echo "GATE REFUSED(2) [$G]: no $ROOT/scrip -- run make"; exit 2; }
[ -f "$ROOT/out/libscrip_rt.so" ] || { echo "GATE REFUSED(2) [$G]: out/libscrip_rt.so is not built -- mode 4 cannot link"; exit 2; }
"$HERE/util_require_fresh.sh" --gate "$G" "$ROOT/scrip" "$ROOT/out/libscrip_rt.so" || exit 2
command -v gcc >/dev/null 2>&1 || { echo "GATE REFUSED(2) [$G]: gcc absent"; exit 2; }
. "$HERE/lib_oracle_flags.sh" || { echo "GATE REFUSED(2) [$G]: lib_oracle_flags.sh unloadable -- the one accessor of the oracle binaries"; exit 2; }
SW="$(swipl_bin)"; [ -x "$SW" ] || { echo "GATE REFUSED(2) [$G]: no swipl at $SW -- the oracle (swipl_bin)"; exit 2; }
W="$(mktemp -d "${TMPDIR:-/tmp}/plplace.XXXXXX")" || { echo "GATE REFUSED(2) [$G]: no workdir"; exit 2; }; trap 'rm -rf "$W"' EXIT
cat > "$W/w.pl" <<'EOF'
a :- write(a).
b :- write(b).
c :- write(c).
d :- write(d), nl.
p(X) :- ( X > 1 -> a ; b ), c, d.
q(_) :- a, ( b, c ), d.
r(X) :- a, \+ X = 3, ( X = 1 *-> d ; write(g), nl ).
main :- p(2), p(0), q(0), r(1), r(2), ( r(3) -> true ; write(no), nl ).
:- initialization(main).
EOF
timeout -k 5 20 "$SW" -q -t halt "$W/w.pl" < /dev/null > "$W/w.ref" 2> "$W/ref.err"
[ -s "$W/w.ref" ] || { echo "GATE REFUSED(2) [$G]: swipl did not answer the witness ($(head -c 160 "$W/ref.err"))"; exit 2; }
bad=0
"$ROOT/scrip" --dump-ast "$W/w.pl" < /dev/null 2> /dev/null | awk '/^\(STMT/ { if (l != "") print l; l = $0; next } { sub(/^[ \t]+/, ""); l = l " " $0 } END { if (l != "") print l }' > "$W/ast.txt"
shape() { k="$1"; shift; ln="$(grep -m1 "TT_CHOICE $k " "$W/ast.txt")"
    [ -n "$ln" ] || { echo "GATE REFUSED(2) [$G]: --dump-ast prints no clause for $k"; exit 2; }
    miss=""; case "$ln" in *TT_IF*) miss="$miss TT_IF(the placed node)";; esac
    for need in "$@"; do case "$ln" in *"$need"*) ;; *) miss="$miss no[$need]";; esac; done
    if [ -z "$miss" ]; then echo "  ok  shape $k: the clause keeps the source operators and has no TT_IF"; else echo "  RED shape $k:$miss"; bad=1; fi; }
shape p/1 'TT_FNC ;' 'TT_FNC ->' 'TT_FNC ,'
shape q/1 'TT_FNC ,'
shape r/1 'TT_FNC *->' 'TT_FNC ;'
"$ROOT/scrip" "$W/w.pl" < /dev/null > "$W/m3.out" 2>&1; r3=$?
"$ROOT/scrip" --compile -o "$W/w.s" "$W/w.pl" < /dev/null > "$W/c.err" 2>&1 || { echo "GATE REFUSED(2) [$G]: the witness does not compile ($(head -c 120 "$W/c.err"))"; exit 2; }
gcc -no-pie -o "$W/w.bin" "$W/w.s" -L"$ROOT/out" -lscrip_rt -Wl,-rpath,"$ROOT/out" -lm -lpthread > "$W/link.err" 2>&1 || { echo "GATE REFUSED(2) [$G]: the witness does not link ($(head -c 120 "$W/link.err"))"; exit 2; }
timeout -k 5 8 "$W/w.bin" < /dev/null > "$W/m4.out" 2>&1; r4=$?
for m in m3 m4; do rc=$([ $m = m3 ] && echo $r3 || echo $r4)
    if [ "$rc" -eq 0 ] && cmp -s "$W/$m.out" "$W/w.ref"; then echo "  ok  same $m: rc=0, as swipl ($(tr '\n' ' ' < "$W/w.ref"))"; else echo "  RED same $m: rc=$rc, swipl prints $(tr '\n' ' ' < "$W/w.ref") and SCRIP prints $(tr '\n' ' ' < "$W/$m.out" | head -c 160)"; bad=1; fi
done
TREE="$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null || echo '?')$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY)"
if [ $bad -eq 0 ]; then echo "GATE PASS(0) [$G]: the clause reader leaves ( -> ; ) *-> and , as written, lower places them, and both modes print what swipl prints (tree SCRIP=$TREE)"; exit 0; fi
echo "GATE FAIL(1) [$G]: the clause reader still places the body (a TT_IF node, flattened conjunctions) or the run differs from swipl (tree SCRIP=$TREE)"; exit 1
