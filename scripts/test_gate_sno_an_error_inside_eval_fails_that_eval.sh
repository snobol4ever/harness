#!/usr/bin/env bash
# test_gate_sno_an_error_inside_eval_fails_that_eval.sh -- AN ERROR RAISED DIRECTLY IN AN EVALED EXPRESSION FAILS THAT EVAL (cfo 2026-10-23, CEO-1926;
# the cto's ruling (b): the innermost EVAL's &FNCLEVEL rides in the G_ERROR_EVAL_STAGE range, an errored EVAL a second range rt_eval_land turns into FAIL).
# Every expectation is CUT FROM THE ORACLE, sbl -bf, at run time. BLOCKING: SCRIP m3 and m4 print what sbl prints for an error inside EVAL of a string
# under a negation and an alternation (fails, &ERRTYPE 14), for EVAL of an unevaluated expression (the DT_X road, its own landing), at &ERRLIMIT 0 (fails, does not terminate), for a nested EVAL (only the innermost fails)
# and for a function the EVAL calls (statement semantics, succeeds). REPORTED, never blocking: THE SIDE-EFFECT GAP (c) -- under (b) the chain still runs
# to its end after the error before the land fails it, so a later arm with a side effect runs where sbl's does not; this arm prints OPEN or CLOSED so the
# gap is measured, not assumed (the cto: "that witness is the row for (c), the redirect through g_rtccb[25] to the fragment's failure exit").
# FAIL_ONCE=1 corrupts the oracle's text so every blocking arm reads red once. rc 0 green, 1 red, 2 could not measure.
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -uo pipefail
G="$(basename "${BASH_SOURCE[0]}" .sh)"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness"; exit 2; }
SCRIP="${SCRIP_BIN:-$ROOT/scrip}"; RT_DIR="${RT_DIR:-$ROOT/out}"
. "$HERE/lib_oracle_flags.sh" || { echo "⛔ GATE REFUSE(2) [$G]: lib_oracle_flags.sh unloadable"; exit 2; }
SBL="$(sbl_correctness_bin)" || { echo "⛔ GATE REFUSE(2) [$G]: no sbl -- every expectation is cut from the oracle"; exit 2; }
[ -x "$SCRIP" ] && [ -f "$RT_DIR/libscrip_rt.so" ] || { echo "⛔ GATE REFUSE(2) [$G]: no scrip or runtime"; exit 2; }
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
cat > "$T/w.sno" <<'SNO'
        &ERRLIMIT = 20
        N = 0
        DEFINE('NEG()')                             :(NEG_END)
NEG     NEG = ~(1 / N)                              :S(RETURN)F(FRETURN)
NEG_END
        V = EVAL('~(1 / N)')                        :S(Y3)
        OUTPUT = '3 F ' &ERRTYPE                    :(E3)
Y3      OUTPUT = '3 S [' V ']'
E3      V = EVAL("(1 / N, 'd')")                    :S(Y4)
        OUTPUT = '4 F ' &ERRTYPE                    :(E4)
Y4      OUTPUT = '4 S [' V ']'
E4      V = EVAL(*((1 / N), 'e'))                   :S(Y5)
        OUTPUT = '5 F'                              :(E5)
Y5      OUTPUT = '5 S [' V ']'
E5      V = EVAL("(EVAL('1 / N'), 'g')")            :S(Y7)
        OUTPUT = '7 F'                              :(E7)
Y7      OUTPUT = '7 S [' V ']'
E7      V = EVAL('NEG()')                           :S(Y8)
        OUTPUT = '8 F'                              :(E8)
Y8      OUTPUT = '8 S [' V ']'
E8      &ERRLIMIT = 0
        V = EVAL('~(1 / N)')                        :S(Y9)
        OUTPUT = '9 F &ERRLIMIT=' &ERRLIMIT         :(E9)
Y9      OUTPUT = '9 S [' V ']'
E9
END
SNO
cat > "$T/se.sno" <<'SNO'
        &ERRLIMIT = 20
        N = 0
        DEFINE('SAY(S)')                            :(SAY_END)
SAY     OUTPUT = 'arm ran ' S
        SAY = S                                     :(RETURN)
SAY_END
        V = EVAL("(1 / N, SAY('two'))")             :S(Y1)
        OUTPUT = 'A F ' &ERRTYPE                    :(E1)
Y1      OUTPUT = 'A S [' V ']'
E1      V = EVAL("~(1 / N) SAY('after')")           :S(Y2)
        OUTPUT = 'B F ' &ERRTYPE                    :(END)
Y2      OUTPUT = 'B S [' V ']'
END
SNO
run3() { ( cd "$T" && LD_LIBRARY_PATH="$RT_DIR" timeout -k 5 20s "$SCRIP" --run "$1" </dev/null 2>/dev/null ); }
run4() { ( cd "$T" && timeout -k 5 20s "$SCRIP" --compile -o "$T/${1%.sno}.s" "$1" </dev/null >/dev/null 2>&1 && cc -m64 -no-pie "$T/${1%.sno}.s" -o "$T/${1%.sno}.m4" -L"$RT_DIR" -lscrip_rt -lm -Wl,-rpath,"$RT_DIR" >/dev/null 2>&1 && timeout -k 5 20s "$T/${1%.sno}.m4" </dev/null 2>/dev/null ); }
want="$( cd "$T" && "$SBL" $(sbl_lang_flags) w.sno </dev/null 2>/dev/null )"; [ -n "$want" ] || { echo "⛔ GATE REFUSE(2) [$G]: sbl printed nothing for the witness"; exit 2; }
[ -n "${FAIL_ONCE:-}" ] && want="$want
corrupted by FAIL_ONCE"
RC=0; N=0
for m in m3 m4; do N=$((N + 1)); got="$( [ $m = m3 ] && run3 w.sno || run4 w.sno )"
  if [ "$got" = "$want" ]; then echo "  witness $m: identical to sbl -bf ($(printf '%s' "$got" | tr '\n' '|'))"
  else echo "  ⛔ witness $m FAILED:"; diff <(printf '%s\n' "$want") <(printf '%s\n' "$got") | sed 's/^/      /' | head -12; RC=1; fi; done
swant="$( cd "$T" && "$SBL" $(sbl_lang_flags) se.sno </dev/null 2>/dev/null )"; sgot="$(run3 se.sno)"
if [ "$sgot" = "$swant" ]; then echo "  REPORTED side-effect gap (c): CLOSED -- no later arm runs after the error, as in sbl -bf"
else echo "  REPORTED side-effect gap (c): OPEN -- SCRIP runs a later arm sbl -bf never reaches (not blocking; the redirect through g_rtccb[25] is its row):"
  diff <(printf '%s\n' "$swant") <(printf '%s\n' "$sgot") | sed 's/^/      /' | head -8; fi
if [ "$RC" = 0 ]; then echo "GATE PASS [$G]: an error directly in an EVALed expression fails that EVAL as sbl -bf does, $N of $N arms"
else echo "GATE FAIL(1) [$G]: $N arms"; fi
echo "    tree: SCRIP=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY) oracle: $SBL measured $(date -u +%Y-%m-%dT%H:%MZ)"
exit $RC
