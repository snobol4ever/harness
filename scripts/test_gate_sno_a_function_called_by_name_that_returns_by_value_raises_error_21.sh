#!/usr/bin/env bash
# test_gate_sno_a_function_called_by_name_that_returns_by_value_raises_error_21.sh -- a user function called BY NAME (the name operator .f(x),
# a conditional or immediate capture target . f(x) / $ f(x), the subject of an assignment f(x) = v, an assignment inside an expression, a goto
# field :(f(x))) that leaves by RETURN instead of NRETURN raises sbl's error 021 "function called by name returned a value", reported in the
# CALLER's statement, as sbl reports it. A deferred target . *f(x), builtins and DATA field accessors called by name stay legal.
# Row snobol4-a-return-from-a-function-called-by-name-is-error-21-in-sbl-at-five-by-name-contexts-and-scrip-raises-it-at-none-a-per-call-site-by-name-mark
# (found by the cfo 2026-10-03 on the ceo's CEO-1489 hand-off; the cfo's probes and this gate's first draft are theirs).
#
# WHY SCRIP RAISED NOTHING. h(x) with the body `h = .V :(RETURN)`: sbl -bf stops every by-name context with ERROR 021; SCRIP took the RETURNed NAME as
# if it had been NRETURNed ('xy' ? LEN(1) . h(1) set V to x). The call site only consulted the by-name request when the callee had set the NRETURN
# mark, so a by-name call that RETURNed never reached a check. A one-flag check through rt_g_want_name was WRONG for a second reason: SNO$WANTNM
# was lowered BEFORE the call's argument expressions, so the first user call evaluated -- an argument, k2(id(n)) = 9 -- took the request meant for the
# outer call (its prologue parks and clears the global), and a check on the flag read the by-value argument call as by-name (rung32).
# THE CURE has two halves. (1) The lowerer places SNO$WANTNM between the last argument and the call it names (sx_call_named; sno_lower_byname at
# the name operator, a capture target, an assignment subject, an assignment inside an expression and a goto field -- never the deferred target's
# thunk), so no argument call can take the request. (2) Those same sites place SNO$CHKNM(call, name) after the call: when the request still stands
# (the NRETURN consult at the call site consumes it, a RETURN leaves it standing) and the callee did not NRETURN and is a DEFINEd function, error 21.
#
# Arms, each in m3 and m4, every expectation cut from sbl -bf at run time: 0 the comparators read a corrupted ref RED. R the by-name contexts with a
# RETURNing callee raise 21 and print what sbl prints before it. N controls (NRETURN in the same contexts, a DATA field assigned, captured by name
# and named, ITEM by name, a value call inside a subscript, a by-value call as the ARGUMENT of a by-name call) print what sbl prints and raise nothing.
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
SCRIP="${SCRIP_BIN:-$ROOT/scrip}"; [ -x "$SCRIP" ] || { echo "⛔ REFUSE(2): no scrip at $SCRIP"; exit 2; }
SBL="${SBL_BIN:-/home/resources/x64/bin/sbl}"; [ -x "$SBL" ] || { echo "⛔ REFUSE(2): no sbl at $SBL -- the expected output is CUT FROM THE ORACLE, never pinned by hand"; exit 2; }
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
HDR="        DATA('node(val,nxt)')
        n = node(1, '')
        A = ARRAY(3)
        DEFINE('h(x)')                          :(he)
h       h = .V                                  :(RETURN)
he      DEFINE('k(x)')                          :(ke)
k       k = .W                                  :(NRETURN)
ke      DEFINE('lr(x)')                         :(le)
lr      lr = 'LAB'                              :(RETURN)
le      DEFINE('ln(x)')                         :(lne)
ln      ln = .LAB                               :(NRETURN)
lne     DEFINE('k2(x)')                         :(k2e)
k2      k2 = .val(x)                            :(NRETURN)
k2e     DEFINE('k3(x)')                         :(k3e)
k3      k3 = val(x) + 1                         :(RETURN)
k3e     DEFINE('id(x)')                         :(ide)
id      id = x                                  :(RETURN)
ide"
mk() { printf '%s\n        OUTPUT = %s\n%s\n        OUTPUT = %s\n                                                :(END)\nLAB     OUTPUT = %s\nEND\n' "$HDR" "'before'" "$2" "'after V=' V ' W=' W ' val=' val(n) ' A1=' A[1] ' A2=' A[2]" "'at LAB'" > "$T/$1.sno"; }
R="r_nameop r_capcond r_capimm r_stmt r_expr r_goto r_arg"; N="n_nameop n_stmt n_goto n_field n_fieldcap n_item n_fieldname n_valsub n_arg n_argstmt"
mk r_nameop   "        X = .h(1)"
mk r_capcond  "        'xy' ? LEN(1) . h(1)"
mk r_capimm   "        'xy' ? LEN(1) \$ h(1)"
mk r_stmt     "        h(1) = 'z'"
mk r_expr     "        Y = (h(1) = 'z')"
mk r_goto     "        OUTPUT = 'go'                           :(lr(1))"
mk r_arg      "        X = .h(id(1))"
mk n_nameop   "        X = .k(1)"
mk n_stmt     "        k(1) = 'z'"
mk n_goto     "        OUTPUT = 'go'                           :(ln(1))"
mk n_field    "        val(n) = 5"
mk n_fieldcap "        k2(n) = 9"
mk n_item     "        ITEM(A,1) = 'q'"
mk n_fieldname "        X = .val(n)
        \$X = 7"
mk n_valsub   "        A[k3(n)] = 'r'"
mk n_arg      "        X = .k(id(1))"
mk n_argstmt  "        k2(id(n)) = 9"
own() { grep -v '^[[:space:]]*$' | grep -Ev ': ERROR [0-9]{3} --|^in (file|line|statement) |^stmts executed|^execution time|^REGENERATIONS|^memory (used|left)|^stmt / '; }
for P in $R $N; do ( cd "$T" && "$SBL" -bf $P.sno < /dev/null ) > "$T/$P.sbl" 2>&1; own < "$T/$P.sbl" > "$T/$P.ref"; grep -c 'ERROR 021' "$T/$P.sbl" > "$T/$P.e21" || true; done
for P in $R; do [ "$(cat "$T/$P.e21")" != 0 ] || { echo "⛔ REFUSE(2): sbl did not raise 021 on $P -- the probe is not the case this gate claims"; exit 2; }; done
for P in $N; do [ "$(cat "$T/$P.e21")" = 0 ] || { echo "⛔ REFUSE(2): sbl raised 021 on control $P"; exit 2; }; done
bad=0; printf 'x' | cat - "$T/r_nameop.ref" | cmp -s - "$T/r_nameop.ref" && bad=1
[ "$bad" = 0 ] || { echo "⛔ REFUSE(2): arm 0 -- the comparator read a corrupted ref as equal; it cannot fail"; exit 2; }
echo "  PASS arm0 the comparator reads a corrupted ref RED"
RC=0
for M in m3 m4; do
  for P in $R $N; do
    if [ "$M" = m4 ]; then ( cd "$T" && "$SCRIP" --compile --out=$P.s $P.sno </dev/null && gcc $P.s -o $P.bin -L"$ROOT/out" -lscrip_rt -lm -lpthread ) >/dev/null 2>&1 || { echo "⛔ REFUSE(2): mode-4 probe $P did not build"; exit 2; }; fi
    IN=/dev/null
    ( cd "$T" && if [ "$M" = m3 ]; then timeout -k 5 30 "$SCRIP" $P.sno <"$IN"; else LD_LIBRARY_PATH="$ROOT/out" timeout -k 5 30 ./$P.bin <"$IN"; fi ) >"$T/$M.$P.out" 2>"$T/$M.$P.err"; echo $? > "$T/$M.$P.rc"
  done
  for P in $R $N; do
    want=$(cat "$T/$P.e21")
    got=$(grep -c 'error 21: function called by name returned a value' "$T/$M.$P.err"); rc=$(cat "$T/$M.$P.rc")
    if [ "$rc" -ge 128 ]; then echo "  $M $P FAIL (crashed rc $rc: $(head -c 160 "$T/$M.$P.err"))"; RC=1; continue; fi
    if ! own < "$T/$M.$P.out" | cmp -s - "$T/$P.ref"; then echo "  $M $P FAIL (output differs from sbl: $(own < "$T/$M.$P.out" | diff "$T/$P.ref" - | head -3 | tr '\n' '|'))"; RC=1; continue; fi
    if [ $((want > 0)) != $((got > 0)) ]; then echo "  $M $P FAIL (sbl raised 021: $want, scrip raised error 21: $got)"; RC=1; continue; fi
    echo "  $M $P PASS ($([ "$want" -gt 0 ] && echo "error 21 raised, as sbl" || echo "no error, output = sbl"))"
  done
done
if [ "$RC" = 0 ]; then echo "GATE PASS [$(basename "${BASH_SOURCE[0]}" .sh)]: a function called by name that RETURNs raises error 021 in every by-name context, and the NRETURN, field, ITEM and by-value controls stay legal (17 probes x 2 modes)"
else echo "GATE FAIL(1) [$(basename "${BASH_SOURCE[0]}" .sh)]: the by-name return check disagrees with sbl -bf (examined 17 probes x 2 modes)"; fi
echo "    tree: SCRIP=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY)  oracle: $SBL  measured $(date -u +%Y-%m-%dT%H:%MZ)"
exit $RC
