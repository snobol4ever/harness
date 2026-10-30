#!/usr/bin/env bash
# util_zd_check_entry.sh -- THE ZD-CHECK ON ONE PROGRAM, NAMING THE EDGES (ceo CEO-1830 verifier, ARCH-ZETA-ONE-COORDINATE.md section 4; hq_runtime 2026-10-30).
# test_gate_zd_check_reads_zero_violations_on_the_cores.sh sums every core entry and prints only the worst entry per language; a seat whose witness
# enters the master red then needs the three sites, and this prints them: it compiles ONE program with SCRIP_ZD_CHECK=1 (mode 4, asm to scratch,
# nothing linked or run) and counts the verifier's violations by the gate's own rule -- the absolute-coordinate graphs' `violations=N` plus every
# `[ZD-CHECK]   READ` line; a relative graph is reported beside the count and never in it.
# USAGE:
#   util_zd_check_entry.sh <lang> <entry>      a master entry by name (corpus/tests/<lang>/ALL.<ext> through corpus_suite_harness.py extract)
#   util_zd_check_entry.sh --src <file>        a source file by path
#   util_zd_check_entry.sh --shapes            the NESTED-ALTERNATION shapes below, each compiled alone (the fixtures of the SAVED-BETA reading)
# PRINTS each edge line the verifier names (SAVED-BETA, GAMMA-*, OMEGA-*, DISCARD, READ), the graphs that carry a violation, and
#   ZD_ENTRY what=<entry|file|shape> graphs=<g> absolute=<a> violations=<v> relative_reported=<r>
# rc 0 violations 0; rc 1 a violation; rc 2 cannot measure (no scrip, no such entry, nothing compiled, a source that read no graph).
# THE SHAPES (all Prolog; each reads SAVED-BETA gpop=0 against the pop the redo's beta expects, at SCRIP 98b6798b7, planner untouched since 623e48025):
#   a clause whose if-then-else or disjunction ARM holds a second alternation (a disjunction, or an if-then-else with an else) and whose clause
#   exit is a SUCCEED reached through the arm's gate: the exit prices the gate arm's pop 0 and the verifier expects the cells between the arm and
#   the redo gate (48 or 64 bytes). A nested alternation under a builtin condition (n_builtin_cond) reads it too; a nested alternation after a call
#   that is not in an arm (seq_then_disj) and a nested if-then-else whose arms are both user calls (nested_ite_user_calls) read 0.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIP="$(cd "$HERE/../../SCRIP" 2>/dev/null && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP"; exit 2; }
CORPUS="$(cd "$HERE/../../corpus" 2>/dev/null && pwd)" || { echo "REFUSE(2): no corpus beside harness"; exit 2; }
[ -x "$SCRIP/scrip" ] || { echo "REFUSE(2): $SCRIP/scrip is not built"; exit 2; }
W="$(mktemp -d "${TMPDIR:-/tmp}/zd_entry.XXXXXX")" || { echo "REFUSE(2): mktemp failed"; exit 2; }
trap 'rm -rf "$W"' EXIT
check_one() {
    local what="$1" src="$2" out graphs abs viol rel reads
    out="$( cd "$SCRIP" && SCRIP_ZD_CHECK=1 timeout -k 2 120 ./scrip --compile --out="$W/x.s" "$src" < /dev/null 2>&1 >/dev/null | grep '^\[ZD-CHECK\]' )"
    graphs="$(printf '%s\n' "$out" | grep -c ' violations=')"
    [ "$graphs" -gt 0 ] || { echo "REFUSE(2): $what compiled but the verifier read no graph"; return 2; }
    abs="$(printf '%s\n' "$out" | grep -c ' coordinate=absolute ')"
    viol="$(printf '%s\n' "$out" | grep ' coordinate=absolute ' | sed -n 's/.* violations=\([0-9][0-9]*\).*/\1/p' | awk '{s+=$1} END{print s+0}')"
    rel="$(printf '%s\n' "$out" | grep ' coordinate=relative ' | sed -n 's/.* violations=\([0-9][0-9]*\).*/\1/p' | awk '{s+=$1} END{print s+0}')"
    reads="$(printf '%s\n' "$out" | grep -c '^\[ZD-CHECK\]   READ ')"
    viol=$((viol + reads))
    printf '%s\n' "$out" | grep -E '^\[ZD-CHECK\]   (SAVED-BETA|GAMMA|OMEGA|DISCARD|READ)' | sed "s/^\[ZD-CHECK\]   /  $what: /"
    printf '%s\n' "$out" | grep -E ' coordinate=absolute .* violations=[1-9]' | sed "s/^\[ZD-CHECK\] /  $what: violating /"
    echo "ZD_ENTRY what=$what graphs=$graphs absolute=$abs violations=$viol relative_reported=$rel"
    [ "$viol" -eq 0 ]
}
shape() { printf '%s\n' "kp(a,b,c)." "$2" > "$W/$1.pl"; }
case "${1:-}" in
    --src)
        [ -f "${2:-}" ] || { echo "REFUSE(2): --src needs a readable file"; exit 2; }
        check_one "$(basename "$2")" "$2"; exit $?;;
    --shapes)
        shape n_builtin_cond          'm(I) :- ( _ = 1 -> ( true ; I = 1 ) ; true ).'
        shape nested_disj_in_then     'm(I) :- ( kp(a,b,_) -> ( true ; I = 1 ) ; true ).'
        shape nested_disj_in_else     'm(I) :- ( kp(a,b,_) -> true ; ( true ; I = 1 ) ).'
        shape nested_ite_in_then      'm(N,K,V,I) :- ( kp(N,K,V0) -> ( V0 == V -> I = 0 ; I = -1 ) ; I = 1 ).'
        shape nested_two_disj_in_then 'm(I) :- ( kp(a,b,_) -> ( I = 1 ; I = 2 ) ; I = 3 ).'
        shape nested_disj_under_not   'm(I) :- ( \+ kp(a,b,_) -> ( true ; I = 1 ) ; true ).'
        shape seq_then_disj           'm(I) :- kp(a,b,_), ( true ; I = 1 ).'
        shape nested_ite_user_calls   'm(I) :- ( kp(a,b,_) -> ( kp(a,b,_) -> I = 1 ; I = 2 ) ; true ).'
        rc=0; for s in n_builtin_cond nested_disj_in_then nested_disj_in_else nested_ite_in_then nested_two_disj_in_then nested_disj_under_not seq_then_disj nested_ite_user_calls; do
            check_one "$s" "$W/$s.pl"; r=$?; [ "$r" -eq 2 ] && exit 2; [ "$r" -eq 0 ] || rc=1
        done
        [ "$rc" -eq 0 ] && echo "ZD_SHAPES OK: every shape reads 0" || echo "ZD_SHAPES RED: a nested alternation inside an arm reads SAVED-BETA (the lines above name the shapes)"
        exit $rc;;
    ''|-*) echo "REFUSE(2): usage: $0 <lang> <entry> | --src <file> | --shapes"; exit 2;;
esac
lang="$1"; entry="${2:-}"
[ -n "$entry" ] || { echo "REFUSE(2): usage: $0 <lang> <entry>"; exit 2; }
case "$lang" in snobol4) ext=sno;; icon) ext=icn;; prolog) ext=pl;; raku) ext=raku;; pascal) ext=pas;; snocone) ext=sc;; rebus) ext=reb;; *) echo "REFUSE(2): unknown language $lang"; exit 2;; esac
D="$CORPUS/tests/$lang"
[ -f "$D/ALL.$ext" ] && [ -f "$D/ALL.ref" ] || { echo "REFUSE(2): $D has no ALL.$ext or ALL.ref"; exit 2; }
python3 "$HERE/corpus_suite_harness.py" extract "$D/ALL.$ext" "$D/ALL.ref" "$entry" "$W/e.$ext" --out-ref "$W/e.ref" --out-in "$W/e.in" > /dev/null 2>&1 && [ -s "$W/e.$ext" ] \
    || { echo "REFUSE(2): no entry $entry in $D/ALL.$ext"; exit 2; }
check_one "$entry" "$W/e.$ext"
