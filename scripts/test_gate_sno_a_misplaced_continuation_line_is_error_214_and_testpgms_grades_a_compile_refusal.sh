#!/usr/bin/env bash
export S4E_ONE_RUNNER_FIXTURE="gate arm ${0##*/}: the testpgms runner invoked on a scratch fixture, not a board (CEO-547)"
# test_gate_sno_a_misplaced_continuation_line_is_error_214_and_testpgms_grades_a_compile_refusal.sh -- ceo CEO-1323 (2026-09-27, on
# Lon's "I want to see TPgm go to 8/8. I'm tired of seeing that 1/8."), both halves:
#  (a) SCRIP REFUSES WHAT THE ONE ORACLE REFUSES: a continuation line ('+' or '.' in column 1) where no statement is open to continue
#      -- after a ';'-terminated statement, after a comment line, at the start of the file -- is ERROR 214 "bad label or misplaced
#      continuation line" at that line, through the one error voice, and no code is generated. sbl -bf measured on 18 shapes
#      (2026-09-27): 214 on c d e g h i j l; ACCEPTED on a f m n o p q r (an incomplete statement, a label with or without trailing
#      blanks, a whitespace-only line -- a statement is open, and the continuation joins it); b (a COMPLETE statement continued) is
#      ERROR 212 and k (after a BLANK line) is ERROR 221 -- both refused by SCRIP too, in their own voices, outside this gate.
#      s t u: a GOTO FIELD continued on the next line (:S(L1) then + F(L2)) is one statement in sbl; SCRIP's GT state ended at the
#      newline, so the continuation used to parse as a new statement calling an undefined function F (error 22 on HEAD for s and u)
#      -- found by this landing's 2622-program compile A/B (snoflake's syntactic-recognizer.sno line 117), cured by <GT>{CONT}.
#      MECHANISM: src/parsers/snobol4/snobol4.l -- every ';' enters AFTER_SEMI (blanks and the newline before a continuation marker go
#      to INITIAL, anything else is pushed back unchanged); a blank line enters AFTER_BLANK (today's behaviour kept: sbl's 221 class);
#      BODY_START and GT take a continuation as whitespace (the statement is open); <INITIAL>[+.] raises 214 through
#      core_error_voice_at, the one voice's single formatter, factored out of core_error_voice.
#  (b) THE TESTPGMS RUNNER GRADES A COMPILE REFUSAL the way CEO-1316 grades a post-mortem: util_spitbol_compile_refusal.py reads sbl's
#      diagnostics as (line, code) pairs; SCRIP's stderr rendered through util_render_error_voice.py spitbol must read the same set,
#      SCRIP exiting nonzero with nothing on stdout (m3) and no assembly (m4). The rc alone never grades (the cfo's condition).
#
#   L*  each of the 21 shapes in m3 against sbl -bf live (214 shapes also in m4, the compile step refusing with the same pairs)
#   H1..H5  the helper: a refusal -> rc 0 and its pair; an answer -> 3; rc 0 with a diagnostic -> 2; a diagnostic beside a post-mortem
#           -> 2; a timeout -> 3
#   G   the runner on a one-program fixture (shape c): graded, PASS both modes, COMPILE_REFUSAL graded=1
#   R1  the runner on shape b (sbl ERROR 212; SCRIP's refusal is not in the one voice): graded and RED both modes
#   R2  a SCRIP wrapper whose voice names line 99: RED in m3 (the line is graded, not only the code), m4 untouched and PASS
# FAIL_ONCE (recorded, hq_snobol4 2026-09-27): on 696d16b68 with the lexer, core.c and runner changes stashed, 19 of 34 red -- all 16
#   arms of the eight 214 shapes (SCRIP accepted and ran seven of them; shape i it refused only as a plain parse error, no voice), and
#   G, R1 and R2 (the runner scored the fixture OUTSIDE, unscored=1, rc 2); the helper arms stood (a new file). The goto-continuation
#   arms s and u were added after that run and read error 22 on the same HEAD binary (measured directly). With the change 37/37.
# EXIT: 0 every arm passes . 1 an arm is red . 2 REFUSED (no oracle, stale binary, the oracle moved)
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
GATE_NAME="$(basename "${BASH_SOURCE[0]}" .sh)"
. "$HERE/lib_oracle_flags.sh" || { echo "GATE UNPROVEN(2) [$GATE_NAME]: lib_oracle_flags.sh unavailable"; exit 2; }
. "$HERE/lib_gate.sh"          || { echo "GATE UNPROVEN(2) [$GATE_NAME]: lib_gate.sh unavailable"; exit 2; }
O="$(sbl_correctness_bin)" || exit 2
gate_require_exec "$ROOT/scrip" "the scrip binary"
gate_require_fresh "$ROOT" src "$ROOT/scrip" "$ROOT/out/libscrip_rt.so"
T="$(mktemp -d)" || { echo "GATE UNPROVEN(2) [$GATE_NAME]: mktemp failed"; exit 2; }
trap 'rm -rf "$T"' EXIT
H="$HERE/util_spitbol_compile_refusal.py"; V="$HERE/util_render_error_voice.py"; RUNNER="$HERE/test_snobol4_spitbol_testpgms_suite.sh"; S="$ROOT/scrip"; RT="$ROOT/out"
refuse() { echo "GATE UNPROVEN(2) [$GATE_NAME]: $*"; exit 2; }
red=0; n=0
arm() { n=$((n+1)); if [ "$2" = ok ]; then echo "  ok   $1"; else echo "  RED  $1 -- $3"; red=$((red+1)); fi; }
mk() { printf "$2" > "$T/L/$1.sno"; }
mkdir -p "$T/L"
mk a '         X = 1 +\n.            2\n         OUTPUT = X\nEND\n'
mk b '         X = 1\n.        Y = 2\n         OUTPUT = X\nEND\n'
mk c '         X = 1 ;\n.        Y = 2\n         OUTPUT = X\nEND\n'
mk d '         X = 1 ;\n+        Y = 2\n         OUTPUT = X\nEND\n'
mk e '         X = 1 ; Y = 2 ;\n.        Z = 3\n         OUTPUT = X Y\nEND\n'
mk f '         X = 1 ; Y =\n.        2\n         OUTPUT = X Y\nEND\n'
mk g '         X = 1 ;   \n.        Y = 2\n         OUTPUT = X\nEND\n'
mk h '         X = 1 ;\n* a comment\n.        Y = 2\n         OUTPUT = X\nEND\n'
mk i '         X = 1\n* a comment\n.        + 2\n         OUTPUT = X\nEND\n'
mk j 'L1       ;\n.        Y = 2\n         OUTPUT = Y\nEND\n'
mk k '         X = 1\n\n.        + 2\n         OUTPUT = X\nEND\n'
mk l '.        X = 5\n         OUTPUT = X\nEND\n'
mk m 'L1\n.        X = 7\n         OUTPUT = X\nEND\n'
mk n 'L1   \n.        X = 8\n         OUTPUT = X\nEND\n'
mk o '         X = 1 ;\n\n         OUTPUT = X\nEND\n'
mk p '         X = 1\n     \n.        X = 9\n         OUTPUT = X\nEND\n'
mk q 'L1       \n.        X = 10\n.        + 1\n         OUTPUT = X\nEND\n'
mk r 'L1   :(L2)\nL2       \n.        X = 11\n         OUTPUT = X\nEND\n'
mk s "         X = 1\n         EQ(X,2)                    :S(L1)\n+                                   F(L2)\nL1       OUTPUT = 'S'            :(END)\nL2       OUTPUT = 'F'\nEND\n"
mk t "         X = 2\n         EQ(X,2)            :S(L1)\n.                           F(L2)\nL1       OUTPUT = 'S'    :(END)\nL2       OUTPUT = 'F'\nEND\n"
mk u "         X = 1\n         EQ(X,2)            :S(L1)\n.                           F(L2) ;\nL1       OUTPUT = 'S'    :(END)\nL2       OUTPUT = 'F'\nEND\n"
for c in a b c d e f g h i j k l m n o p q r s t u; do
    ( cd "$T/L" && timeout -k 5 10 "$O" -bf "$c.sno" < /dev/null > "$c.sbl" 2>/dev/null ); orc=$?
    op="$(python3 "$H" oracle "$T/L/$c.sbl" "$orc" 2>/dev/null)"; hrc=$?
    case "$c" in
        c|d|e|g|h|i|j|l) [ "$hrc" = 0 ] && printf '%s\n' "$op" | grep -q $'\t214$' || refuse "sbl -bf no longer refuses shape $c with ERROR 214 (helper rc=$hrc, pairs [$op]) -- the oracle moved; re-measure" ;;
        a|f|m|n|o|p|q|r|s|t|u) [ "$orc" = 0 ] && [ "$hrc" = 3 ] || refuse "sbl -bf no longer accepts shape $c (rc=$orc) -- the oracle moved; re-measure" ;;
        b|k) [ "$hrc" = 0 ] || refuse "sbl -bf no longer refuses shape $c at compile (helper rc=$hrc) -- the oracle moved" ;;
    esac
    ( cd "$T/L" && timeout -k 5 10 "$S" "$c.sno" < /dev/null > "$c.m3" 2> "$c.m3err" ); r3=$?
    case "$c" in
        c|d|e|g|h|i|j|l)
            g3="$(python3 "$V" spitbol < "$T/L/$c.m3err" | python3 "$H" pairs -)"
            { [ "$r3" -ne 0 ] && [ ! -s "$T/L/$c.m3" ] && [ "$g3" = "$op" ]; } && arm "L$c m3 refused with ERROR 214 at sbl's line ($op)" ok || arm "L$c m3" red "rc=$r3 stdout=$(grep -c '' "$T/L/$c.m3") line(s), voice pairs [$g3] want [$op]"
            ( cd "$T/L" && timeout -k 5 10 "$S" --compile "$c.sno" < /dev/null > "$c.s" 2> "$c.s.err" ); r4=$?
            g4="$(python3 "$V" spitbol < "$T/L/$c.s.err" | python3 "$H" pairs -)"
            { [ "$r4" -ne 0 ] && [ ! -s "$T/L/$c.s" ] && [ "$g4" = "$op" ]; } && arm "L$c m4 compile refused with the same pair" ok || arm "L$c m4" red "compile rc=$r4 asm=$(grep -c '' "$T/L/$c.s") line(s), voice pairs [$g4] want [$op]" ;;
        a|f|m|n|o|p|q|r|s|t|u)
            { [ "$r3" = 0 ] && cmp -s "$T/L/$c.sbl" "$T/L/$c.m3"; } && arm "L$c m3 accepted, output equals sbl" ok || arm "L$c m3" red "rc=$r3, output [$(head -2 "$T/L/$c.m3" | tr '\n' ' ')] want [$(tr '\n' ' ' < "$T/L/$c.sbl")]" ;;
        b|k)
            [ "$r3" -ne 0 ] && arm "L$c m3 refused, as sbl refuses (sbl's own code is outside this gate)" ok || arm "L$c m3" red "SCRIP ran a program sbl refuses at compile (rc=$r3)" ;;
    esac
done

python3 "$H" oracle "$T/L/c.sbl" 231 > "$T/h1"; r=$?; { [ "$r" = 0 ] && [ "$(cat "$T/h1")" = $'2\t214' ]; } && arm H1 ok || arm H1 red "rc=$r pairs [$(cat "$T/h1")]"
python3 "$H" oracle "$T/L/a.sbl" 1 >/dev/null 2>&1; r=$?; [ "$r" = 3 ] && arm H2 ok || arm H2 red "rc=$r, want 3 (an answer is not a refusal)"
python3 "$H" oracle "$T/L/c.sbl" 0 >/dev/null 2>&1; r=$?; [ "$r" = 2 ] && arm H3 ok || arm H3 red "rc=$r, want 2 (a diagnostic at rc 0 was never measured)"
{ cat "$T/L/c.sbl"; printf 'in statement 3\nstmts executed      3\n'; } > "$T/h4"; python3 "$H" oracle "$T/h4" 1 >/dev/null 2>&1; r=$?; [ "$r" = 2 ] && arm H4 ok || arm H4 red "rc=$r, want 2 (a post-mortem is a run-time error)"
python3 "$H" oracle "$T/L/c.sbl" 124 >/dev/null 2>&1; r=$?; [ "$r" = 3 ] && arm H5 ok || arm H5 red "rc=$r, want 3 (a timeout is not a refusal)"

board() { printf '%s\n' "$1" | grep -E '^SPITBOL_TESTPGMS_BOARD '; }
# a board field is read by its NAME, never by its neighbours (util_board_field_matcher_census.py, CEO-839): fld <board> <name>
fld() { printf '%s\n' "$1" | tr ' ' '\n' | awk -F= -v k="$2" '$1==k {print $2; exit}'; }
want() { local b="$1"; shift; local kv; for kv in "$@"; do [ "$(fld "$b" "${kv%%=*}")" = "${kv#*=}" ] || return 1; done; }
fixture() { rm -rf "$T/fx"; mkdir -p "$T/fx"; cp "$T/L/$1.sno" "$T/fx/testcr.spt"; : > "$T/fx/testpgms.in"; printf 'entry,heap_kb,stack_kb,compile_args,run_args\ntestcr,131072,4096,,\n' > "$T/fx/ALL.csv"; }
fixture c
out="$(cd "$ROOT" && SPITBOL_TESTPGMS_SUITE="$T/fx" timeout -k 5 300 bash "$RUNNER" 2>&1)"; rc=$?
{ [ "$rc" = 0 ] && want "$(board "$out")" scored=1 unscored=0 m3_pass=1 m3_fail=0 m4_pass=1 m4_fail=0 && printf '%s\n' "$out" | grep -q '^SPITBOL_TESTPGMS_COMPILE_REFUSAL graded=1 '; } \
  && arm G ok || arm G red "rc=$rc board [$(board "$out")]; $(printf '%s\n' "$out" | grep -E 'REFUSE|RED |UNSCORED' | head -3 | tr '\n' ' ')"
fixture b
out="$(cd "$ROOT" && SPITBOL_TESTPGMS_SUITE="$T/fx" timeout -k 5 300 bash "$RUNNER" 2>&1)"; rc=$?
{ [ "$rc" = 1 ] && want "$(board "$out")" scored=1 unscored=0 m3_pass=0 m3_fail=1 m4_pass=0 m4_fail=1 && printf '%s\n' "$out" | grep -q 'RED  testcr m3 .*sbl refuses at compile'; } \
  && arm R1 ok || arm R1 red "rc=$rc board [$(board "$out")]; $(printf '%s\n' "$out" | grep -E 'REFUSE|RED |UNSCORED' | head -2 | tr '\n' ' ')"
fixture c; mkdir -p "$T/w1"
printf '#!/usr/bin/env bash\nfor a in "$@"; do [ "$a" = --compile ] && exec "%s" "$@"; done\ne=$(mktemp); "%s" "$@" 2>"$e"; rc=$?; sed "s/^  at \\(.*\\):[0-9]*$/  at \\1:99/" "$e" >&2; rm -f "$e"; exit $rc\n' "$S" "$S" > "$T/w1/scrip"; chmod +x "$T/w1/scrip"
out="$(cd "$ROOT" && SCRIP="$T/w1/scrip" SPITBOL_TESTPGMS_SUITE="$T/fx" timeout -k 5 300 bash "$RUNNER" 2>&1)"; rc=$?
{ [ "$rc" = 1 ] && want "$(board "$out")" m3_pass=0 m3_fail=1 m4_pass=1 m4_fail=0 && printf '%s\n' "$out" | grep -q 'RED  testcr m3 .*99:214'; } \
  && arm R2 ok || arm R2 red "rc=$rc board [$(board "$out")]; $(printf '%s\n' "$out" | grep -E 'REFUSE|RED ' | head -2 | tr '\n' ' ')"

[ "$n" -gt 0 ] || refuse "zero arms ran"
if [ "$red" -eq 0 ]; then echo "GATE PASS(0) [$GATE_NAME]: $n arms"; exit 0; fi
echo "GATE FAIL(1) [$GATE_NAME]: $red of $n arm(s) red"; exit 1
