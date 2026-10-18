#!/usr/bin/env bash
# test_gate_sno_a_statement_level_query_takes_a_concatenated_subject_and_chains_left_to_right.sh -- a SNOBOL4 statement whose subject is a CONCATENATION followed by the binary ? parses, and a statement-level chain  S ? P ? Q  parses.
#
# # ⛔ THE DEFECT (the coo's telegram 2026-10-08, on SCRIP e22bf956b, row snobol4-a-concatenated-subject-before-binary-query-does-not-parse-at-statement-level; and hq_snobol4's 2026-09-24 row snobol4-a-statement-level-query-chain-s-query-p-query-q-is-a-parse-error):
#   sbl -bf runs  'pq' 'rs' ? LEN(1)  and  X 'rs' ? LEN(1)  and  'abc' ? 'b' ? ''  -- SPITBOL's ? is the lowest binary operator, left associative (manual Chapter 15), so everything before the first ? is the
#   subject EXPRESSION and every further ? wraps what stands before it. SCRIP's snobol4.y read the first blank after a statement's first operand as the subject/pattern separator (opt_subject: expr14 T_CONCAT expr2, the
#   one standing shift/reduce conflict on T_CONCAT, shift wins) and so met the ? with no derivation: "parse error: syntax error" then "missing END statement", nothing generated; a second top-level ? had none either.
#   THE CURE: snobol4.y gains the nonterminal qsubject -- expr2 ? opt_pattern | expr14 T_CONCAT expr4 ? opt_pattern | qsubject ? opt_pattern -- folded into opt_subject (it replaces the twelve duplicated
#   `expr2 T_2QUEST opt_pattern ...` statement rules), no new conflict; the concatenated subject is TT_SEQ(first, rest) and each further ? wraps the scan so far in a TT_SCAN. bootstrap/parser_snobol4.sc mirrors it
#   (StmtQuery, and the concatenated-subject alternative tried first), so the C tree and the .sc tree stay the same tree.
#
# THE ARMS (expectations cut from sbl -bf AT RUN TIME): each program in m3 and in m4
#   1-2  CONCATENATED SUBJECTS before ?: the coo's witnesses, labelled and unlabelled, variables and literals, a captured value, the goto forms :S :F :F:S, a ? chain after a concatenated subject
#   3-4  QUERY CHAINS  S ? P ? Q  (the 2026-09-24 row's DONE-WHEN programs and longer chains)
#   5-6  CONTROLS: subject-pattern juxtaposition with and without a replacement, a one-term subject, a concatenation on an assignment's right side, a binary-@ pattern
#   7    A REPLACEMENT behind a value subject (  X 'b' ? LEN(1) = 'Z'  and  Y ? 'l' ? '' = 'L'  ) is ERROR 212 to sbl at compile time: SCRIP refuses non-zero and runs nothing -- never a silent match
#   8    THE TREE: out/parser_snobol4 and the bootstrap/parser_snobol4.sc chain print the same tree for the three programs
# EXIT: 0 all arms pass · 1 an arm failed · 2 REFUSED (no binary, no oracle, no tmpdir, the oracle's answer moved).
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
SCRIP="$ROOT/scrip"
RT_DIR="$ROOT/out"
NAME=sno_a_statement_level_query_takes_a_concatenated_subject_and_chains_left_to_right
refuse() { echo "GATE REFUSE(2) [$NAME]: $*"; exit 2; }
[ -x "$SCRIP" ] || refuse "no scrip binary at $SCRIP -- cannot measure"
[ -f "$RT_DIR/libscrip_rt.so" ] || refuse "no $RT_DIR/libscrip_rt.so -- cannot measure mode 4"
. "$HERE/lib_oracle_flags.sh" 2>/dev/null || true
SBL="$(sbl_correctness_bin 2>/dev/null || true)"; [ -n "${SBL:-}" ] && [ -x "$SBL" ] || SBL=/home/resources/x64/bin/sbl
[ -x "$SBL" ] || refuse "no sbl oracle -- cannot measure (a missing oracle prints a full false table)"
T="$(mktemp -d)" || refuse "no tmpdir"
trap 'rm -rf "$T"' EXIT
cat > "$T/concat.sno" <<'EOS'
        X = 'a'
        Y = 'hello'
L1      'pq' 'rs' ? LEN(1)
        OUTPUT = 'ok1'
L2      X 'rs' ? LEN(1)
        OUTPUT = 'ok2'
        'ab' 'cd' ? 'bc' . OUTPUT
        'ab' 'cd' 'ef' ? LEN(5) . OUTPUT
        Y 'x' ? 'hellox' . OUTPUT
        Y X 'z' ? 'helloaz' . OUTPUT
        'ab' 'cd' ? 'zz'                  :S(S1)F(F1)
S1      OUTPUT = 'bad'                    :(N1)
F1      OUTPUT = 'miss ok'
N1      'ab' 'cd' ? 'cd' . OUTPUT         :S(S2)
        OUTPUT = 'bad2'
S2      'ab' 'cd' ? 'zz'                  :F(F3)S(S3)
S3      OUTPUT = 'bad3'                   :(N3)
F3      OUTPUT = 'miss3 ok'
N3      Y 'x' ? 'h' . OUTPUT ? 'hello' . OUTPUT
        Y 'x' ? 'h' . OUTPUT ? 'h' . OUTPUT
        OUTPUT = 'end'
END
EOS
cat > "$T/chain.sno" <<'EOS'
        'abc' ? 'b' ? ''              :S(A1)F(B1)
A1      OUTPUT = 'p1 s'               :(N1)
B1      OUTPUT = 'p1 f'
N1      'abc' ? 'x' ? ''              :S(A2)F(B2)
A2      OUTPUT = 'p2 s'               :(N2)
B2      OUTPUT = 'p2 f'
N2      'abcd' ? 'bc' . OUTPUT ? 'c' . OUTPUT
        'abcd' ? LEN(2) . OUTPUT ? LEN(1) . OUTPUT
L3      'abcd' ? 'b' ? 'c' ? 'd'      :S(A3)F(B3)
A3      OUTPUT = 'p3 s'               :(N3)
B3      OUTPUT = 'p3 f'
N3      OUTPUT = 'end'
END
EOS
cat > "$T/ctl.sno" <<'EOS'
        X = 'a'
        Y = 'hello'
        'pq' ? LEN(1) . OUTPUT
        Y 'ell' . OUTPUT
        Y 'ell' 'o' . OUTPUT
        Y 'l' = 'L'
        OUTPUT = Y
        Z = 'ab' 'cd' ? LEN(1)
        OUTPUT = Z
        OUTPUT = 'ab' 'cd' ? 'bc'
        X 'b' | 'a' . OUTPUT
        Y ? 'L' . OUTPUT
        OUTPUT = 'end'
END
EOS
printf "        X = 'a'\n        X 'b' ? LEN(1) = 'Z'\n        OUTPUT = 'ran ' X\nEND\n" > "$T/refuse1.sno"
printf "        Y = 'hello'\n        Y ? 'l' ? '' = 'L'\n        OUTPUT = 'ran ' Y\nEND\n" > "$T/refuse2.sno"
printf "        X = 'a'\nL1      'pq' 'rs' ? LEN(1)\n        OUTPUT = 'ok'\nEND\n" > "$T/coo.sno"
want() { timeout -k 5 30 "$SBL" -bf "$T/$1.sno" < /dev/null > "$T/$1.want" 2>/dev/null; [ -s "$T/$1.want" ] || refuse "sbl -bf produced no output for $1 -- the oracle's answer moved"; }
want concat; want chain; want ctl; want coo
grep -q ' ERROR ' "$T/concat.want" "$T/chain.want" "$T/ctl.want" "$T/coo.want" && refuse "sbl -bf now raises an error on a program the arms expect to run -- the oracle moved"
for r in refuse1 refuse2; do (cd "$T" && timeout -k 5 30 "$SBL" -bf -o=s.lst "$r.sno" < /dev/null 2>&1 | grep -q 'ERROR 212') || refuse "sbl -bf no longer answers $r with ERROR 212 -- the oracle's answer moved"; done
fail=0; pass=0
arm() { local n="$1" what="$2" ok="$3"
    if [ "$ok" = 1 ]; then pass=$((pass + 1)); echo "  arm $n PASS  $what"; else fail=$((fail + 1)); echo "  arm $n FAIL  $what"; fi; }
same_m3() { timeout -k 5 60 "$SCRIP" "$T/$1.sno" < /dev/null > "$T/$1.m3" 2>&1
    cmp -s "$T/$1.want" "$T/$1.m3" || { diff "$T/$1.want" "$T/$1.m3" | head -6 | cut -c1-160 | sed 's/^/      /'; return 1; }; }
same_m4() { timeout -k 5 120 "$SCRIP" --compile -o "$T/$1.s" "$T/$1.sno" < /dev/null > /dev/null 2>&1 \
        && gcc -no-pie "$T/$1.s" -L"$RT_DIR" -lscrip_rt -lm -Wl,-rpath,"$RT_DIR" -o "$T/$1.bin" 2>/dev/null || { echo "      COMPILE-FAILED"; return 1; }
    timeout -k 5 60 "$T/$1.bin" < /dev/null > "$T/$1.m4" 2>&1
    cmp -s "$T/$1.want" "$T/$1.m4" || { diff "$T/$1.want" "$T/$1.m4" | head -6 | cut -c1-160 | sed 's/^/      /'; return 1; }; }
n=0
for spec in "coo|THE COO'S WITNESS" "concat|CONCATENATED SUBJECTS before ?" "chain|QUERY CHAINS S ? P ? Q" "ctl|CONTROLS"; do
    p="${spec%%|*}"; w="${spec#*|}"
    n=$((n + 1)); same_m3 "$p" && arm $n "m3 $w" 1 || arm $n "m3 $w" 0
    n=$((n + 1)); same_m4 "$p" && arm $n "m4 $w" 1 || arm $n "m4 $w" 0
done
n=$((n + 1)); ok=1
for r in refuse1 refuse2; do
    out="$(timeout -k 5 30 "$SCRIP" "$T/$r.sno" < /dev/null 2>&1)"; rc=$?
    { [ "$rc" -ne 0 ] && ! printf '%s' "$out" | grep -q '^ran '; } || { ok=0; echo "      $r: rc=$rc out=$(printf '%s' "$out" | head -2 | cut -c1-100)"; }
done
arm $n "a replacement behind a value subject is refused at compile (ERROR 212 to sbl), never run" "$ok"
n=$((n + 1)); ok=1
B="$ROOT/bootstrap"; CORPUS="${CORPUS:-$(cd "$ROOT/.." && pwd)/corpus}"
CHAIN="$B/global.sc $B/case.sc $B/assign.sc $B/match.sc $B/counter.sc $B/stack.sc $B/tree.sc $B/ShiftReduce.sc $B/tdump.sc $B/gen.sc $B/qize.sc $B/semantic.sc $B/omega.sc $B/trace.sc"
. "$HERE/lib_declared_arena.sh" || refuse "cannot load lib_declared_arena.sh"
( . "$HERE/lib_build_currency.sh" && assert_parser_current snobol4 "$ROOT" ) > "$T/cur.txt" 2>&1 || { cat "$T/cur.txt"; refuse "out/parser_snobol4 is missing or older than a source it was compiled from -- make parsers"; }
SW="$(declared_switches_beside "$B/parser_snobol4.sc")" && [ -n "$SW" ] || refuse "bootstrap/parser_snobol4.sc declares no heap or stack"
cat $CHAIN "$B/parser_snobol4.sc" > "$T/chain.sc"
"$SCRIP" --compile "$T/chain.sc" -o "$T/chain.s" < /dev/null > /dev/null 2>&1 && gcc -m64 -no-pie -rdynamic "$T/chain.s" -Wl,-rpath,"$RT_DIR" -L"$RT_DIR" -lscrip_rt -lm -lpthread -o "$T/chain.bin" 2>/dev/null \
    || refuse "the .sc parser chain did not compile or link to a mode-4 binary"
for p in coo concat chain ctl; do
    ( cd "$T"; SNO_LIB="$CORPUS/include" timeout -k 5 60 "$ROOT/out/parser_snobol4" - < "$p.sno" > "$T/$p.cdump" 2> /dev/null ); crc=$?
    ( cd "$T"; timeout -k 5 120 "$T/chain.bin" $SW < "$p.sno" > "$T/$p.sdump" 2> /dev/null ); src=$?
    if [ "$crc" -ne 0 ] || [ "$src" -ne 0 ] || [ ! -s "$T/$p.cdump" ] || grep -q '^Parse Error' "$T/$p.cdump" "$T/$p.sdump" || ! cmp -s "$T/$p.cdump" "$T/$p.sdump"; then
        ok=0; echo "      $p: C rc=$crc .sc rc=$src"; diff "$T/$p.cdump" "$T/$p.sdump" | head -6 | cut -c1-120 | sed 's/^/      /'; fi
done
arm $n "the C parser and the bootstrap .sc parser print the same tree for the four programs" "$ok"
if [ "$fail" -eq 0 ]; then echo "GATE PASS(0) [$NAME]: $pass arms -- a concatenated statement subject before ? and a statement-level ? chain parse and run as sbl does, both modes, one tree from both parsers"; exit 0; fi
echo "GATE FAIL(1) [$NAME]: $fail of $((pass + fail)) arms red"; exit 1
