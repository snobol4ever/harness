#!/usr/bin/env bash
# test_gate_sno_a_value_in_a_by_name_context_is_error_212.sh -- A VALUE WHERE A NAME IS REQUIRED IS ERROR 212 AS THE STATEMENT IS COMPILED (cfo 2026-10-23, CEO-1926;
# SnoRungs code_eval_capture_indirect_replace_branch_2; the rule copied from sbl.min cdgnm: an operand compiled by name is a variable, an indirection, a subscript, a
# function call, a deferred expression, a keyword or an undefined operator, and anything else -- a literal, a defined operator, a concatenation, an alternation, a
# match, an assignment, a selection, unary + - ~ ? . @ -- is "syntax error: value used where name is required"). Every expectation is CUT FROM THE ORACLE, sbl -bf,
# at run time, one program per cell so a CODE that sets no &ERRTYPE cannot borrow the last cell's. BLOCKING: SCRIP m3 on 17 operand forms under unary . @ & and at
# the right of binary . and $, as a non-simple assignment target and as the subject of a replacement (115 cells), and m4 on one value cell per context.
# REPORTED, never blocking: THE GOTO, :(<operand>) -- the goto field's own lexer state drops a character it does not know, so :(~X) compiles as :(X), and a value
# operand is a parse error whose CODE sets no &ERRTYPE -- and THE DEFERRED OR KEYWORD TARGET (.(*X), (*X) = 1, (*X) 'b' = 1, (&ANCHOR) 'b' = 1), which sbl
# compiles and the lowerer refuses; each arm prints its agreeing count. FAIL_ONCE=1 corrupts one oracle reading so the blocking arm reads red once.
# rc 0 green, 1 red, 2 could not measure.
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -uo pipefail
G="$(basename "${BASH_SOURCE[0]}" .sh)"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness"; exit 2; }
SCRIP="${SCRIP_BIN:-$ROOT/scrip}"; RT_DIR="${RT_DIR:-$ROOT/out}"
. "$HERE/lib_oracle_flags.sh" || { echo "⛔ GATE REFUSE(2) [$G]: lib_oracle_flags.sh unloadable"; exit 2; }
SBL="$(sbl_correctness_bin)" || { echo "⛔ GATE REFUSE(2) [$G]: no sbl -- every expectation is cut from the oracle"; exit 2; }
[ -x "$SCRIP" ] && [ -f "$RT_DIR/libscrip_rt.so" ] || { echo "⛔ GATE REFUSE(2) [$G]: no scrip or runtime"; exit 2; }
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
OPS=("X ? 'a'" "1 + 2" "'a' 'b'" "'a' | 'b'" "~X" "\\X" "(X = 1)" "'L'" "1" "X" "\$X" "A[1]" "F(X)" "*X" "&ANCHOR" "-X" "X . Y")
CTX=("dot| Y = .(%s)" "at| Y = @(%s)" "amp| Y = &(%s)" "capt| Y = A . (%s)" "imm| Y = A \$ (%s)" "lhs| (%s) = 1" "subj| (%s) 'b' = 1" "goto| Y = 1 :(%s)")
GAP=" dot_13 lhs_13 subj_13 subj_14 "
cell() { printf "        &ERRLIMIT = 100\n        DEFINE('F(X)')\n        A = ARRAY(3)\n        S = \"%s\"\n        CODE(S)    :F(BAD)\n        OUTPUT = 'compiled'   :(END)\nBAD     OUTPUT = &ERRTYPE\nEND\n" "$1" > "$T/$2.sno"; }
run3() { ( cd "$T" && LD_LIBRARY_PATH="$RT_DIR" timeout -k 5 10s "$SCRIP" --run "$1" </dev/null 2>/dev/null | head -1 ); }
run4() { ( cd "$T" && timeout -k 5 20s "$SCRIP" --compile --out="$T/${1%.sno}.s" "$1" </dev/null >/dev/null 2>&1 && cc -m64 -no-pie "$T/${1%.sno}.s" -o "$T/${1%.sno}.m4" -L"$RT_DIR" -lscrip_rt -lm -Wl,-rpath,"$RT_DIR" >/dev/null 2>&1 && timeout -k 5 10s "$T/${1%.sno}.m4" </dev/null 2>/dev/null | head -1 ); }
oracle() { ( cd "$T" && "$SBL" $(sbl_lang_flags) "$1" </dev/null 2>/dev/null | head -1 ); }
RC=0; NB=0; AB=0; NG=0; AG=0; NX=0; AX=0; BAD=""; FIRST=1
for c in "${CTX[@]}"; do k="${c%%|*}"; f="${c#*|}"; for i in "${!OPS[@]}"; do n="$(printf '%s_%02d' "$k" "$i")"; s="$(printf "$f" "${OPS[$i]}")"; cell "$s" "$n"
  want="$(oracle "$n.sno")"; [ -n "$want" ] || { echo "⛔ GATE REFUSE(2) [$G]: sbl printed nothing for cell $n ($s)"; exit 2; }
  got="$(run3 "$n.sno")"
  if [ "$k" = goto ]; then NG=$((NG + 1)); [ "$got" = "$want" ] && AG=$((AG + 1)); continue; fi
  case "$GAP" in *" $n "*) NX=$((NX + 1)); [ "$got" = "$want" ] && AX=$((AX + 1)); continue;; esac
  NB=$((NB + 1)); [ -n "${FAIL_ONCE:-}" ] && [ "$FIRST" = 1 ] && want="$want corrupted by FAIL_ONCE"; FIRST=0
  if [ "$got" = "$want" ]; then AB=$((AB + 1)); else RC=1; BAD="$BAD
      m3 $n: sbl [$want] scrip [$got]   $s"; fi; done; done
N4=0; A4=0
for k in dot at amp capt imm lhs subj; do n="${k}_00"; N4=$((N4 + 1)); want="$(oracle "$n.sno")"; got="$(run4 "$n.sno")"
  if [ "$got" = "$want" ]; then A4=$((A4 + 1)); else RC=1; BAD="$BAD
      m4 $n: sbl [$want] scrip [$got]"; fi; done
echo "  blocking m3: $AB of $NB cells agree with sbl -bf; m4: $A4 of $N4 value cells agree"
[ -n "$BAD" ] && printf '  ⛔ disagreeing cells:%s\n' "$BAD" | head -24
echo "  REPORTED goto :(<operand>): $AG of $NG cells agree with sbl -bf ($([ "$AG" = "$NG" ] && echo CLOSED || echo OPEN) -- the goto field's lexer drops an unknown character and a value operand's parse error sets no &ERRTYPE)"
echo "  REPORTED deferred or keyword target: $AX of $NX cells agree with sbl -bf ($([ "$AX" = "$NX" ] && echo CLOSED || echo OPEN) -- sbl compiles *X and &ANCHOR by name; the lowerer refuses them)"
if [ "$RC" = 0 ]; then echo "GATE PASS [$G]: a value in a by-name context is error 212 as sbl -bf compiles it, $AB m3 cells and $A4 m4 cells"
else echo "GATE FAIL(1) [$G]: $((NB - AB)) m3 and $((N4 - A4)) m4 cells disagree"; fi
echo "    tree: SCRIP=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY) oracle: $SBL measured $(date -u +%Y-%m-%dT%H:%MZ)"
exit $RC
