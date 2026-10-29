#!/usr/bin/env bash
# test_gate_sno_data_type_named_list_is_a_record.sh -- a SNOBOL4 DATA type named list is a record: its fields read and assign, and a field function on a wrong datatype is ERROR 41, as under SPITBOL (ceo CEO-646).
#
# MEASURED 2026-09-12 on 88dfe7505 (the cfo's report): DATA('list(n,a)') then a(x) = ARRAY(...) raised Icon's 107 "record
# expected" in both modes -- three rungs entries lost (user_function_{rem_array,eval_pos}_replace_branch_*) -- because the
# Icon non-record guard that landed in CEO-644 keyed on the TYPE NAME "list" and sat on the field-variable entry both
# lowerers share; a field function on a wrong datatype read 107 or 207 where SPITBOL says ERROR 041. Cure: the list test is
# the runtime's list tag (rt_list_view), and the field-variable box picks rt_field_var_strict (Icon: 107 / 207) on the strict
# node the Icon lowerer marks and rt_field_var (SPITBOL: ERROR 41 on any argument that is not an instance carrying the field)
# otherwise. Arms: the witness's stdout byte-identical to the oracle's in both modes, the two wrong-datatype lvalue arms
# converted under &ERRLIMIT with &ERRTYPE printed, so the number itself is on the graded stream. FAIL_ONCE=1 corrupts the
# captured stdout to prove the diff arm trips.
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -uo pipefail
G="$(basename "${BASH_SOURCE[0]}" .sh)"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
SCRIP="${SCRIP_BIN:-$ROOT/scrip}"; [ -x "$SCRIP" ] || { echo "⛔ GATE REFUSE(2) [$G]: no scrip at $SCRIP"; exit 2; }
. "$HERE/lib_oracle_flags.sh" || { echo "⛔ GATE REFUSE(2) [$G]: cannot load lib_oracle_flags.sh"; exit 2; }
SBL="$(sbl_correctness_bin 2>/dev/null)"; [ -n "$SBL" ] && [ -x "$SBL" ] || { echo "⛔ GATE REFUSE(2) [$G]: SPITBOL correctness oracle not executable -- the ref is CUT FROM THE ORACLE, never pinned by hand"; exit 2; }
FLAGS="$(sbl_lang_flags)"
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
cat > "$T/w.sno" <<'SNO'
                DATA('list(n,a)')
                DATA('pt(x,y)')
                x = list(0, ARRAY('0:3'))
                a(x)[1] = 5
                OUTPUT = a(x)[1]
                a(x) = ARRAY('0:7')
                n(x) = n(x) + 2
                OUTPUT = n(x) ' ' PROTOTYPE(a(x))
                y = list(3, 'abc')
                a(y) = a(y) 'def'
                OUTPUT = a(y) ' ' DATATYPE(y)
                &ERRLIMIT = 5
                z = pt(1,2)
                a(z) = 9
                OUTPUT = 'wrong-type ' &ERRTYPE
                a(5) = 9
                OUTPUT = 'non-record ' &ERRTYPE
                OUTPUT = x(z) ' ' y(z)
END
SNO
( cd "$T" && "$SBL" $FLAGS w.sno </dev/null ) >"$T/w.ref" 2>"$T/w.ref.err"
grep -q '^wrong-type 41$' "$T/w.ref" || { echo "⛔ GATE REFUSE(2) [$G]: the oracle's stream does not carry the 'wrong-type 41' row this gate pins -- the oracle moved: $(head -3 "$T/w.ref" | tr '\n' '|')"; exit 2; }
grep -q '^non-record 41$' "$T/w.ref" || { echo "⛔ GATE REFUSE(2) [$G]: the oracle's stream does not carry the 'non-record 41' row this gate pins"; exit 2; }
RC=0
for M in m3 m4; do
  if [ "$M" = m3 ]; then ( cd "$T" && timeout -k 5 20 "$SCRIP" w.sno </dev/null ) >"$T/$M.out" 2>"$T/$M.err"
  else ( cd "$T" && timeout -k 5 20 "$SCRIP" --compile --out=w.s w.sno </dev/null && gcc w.s -o w.bin -L"$ROOT/out" -lscrip_rt -lm -lpthread ) >/dev/null 2>&1 || { echo "⛔ GATE REFUSE(2) [$G]: mode-4 witness did not build"; exit 2; }
       ( cd "$T" && LD_LIBRARY_PATH="$ROOT/out" timeout -k 5 20 ./w.bin </dev/null ) >"$T/$M.out" 2>"$T/$M.err"
  fi
  if [ -n "${FAIL_ONCE:-}" ]; then sed -i '1s/^5$/6/' "$T/$M.out"; fi
  if diff -u "$T/w.ref" "$T/$M.out" >"$T/$M.diff"; then echo "  $M PASS ($(wc -l <"$T/w.ref") lines byte-identical to $SBL $FLAGS)"
  else echo "  $M FAIL ($(grep -c '^[-+][^-+]' "$T/$M.diff") diff lines)"; sed -n '1,14p' "$T/$M.diff" | sed 's/^/      /'; sed -n '1,3p' "$T/$M.err" | sed 's/^/      stderr: /'; RC=1; fi
done
if [ "$RC" = 0 ]; then echo "GATE PASS [$G]: a DATA type named list is a record in both modes, and a field function on a wrong datatype is ERROR 41 as the oracle says"
else echo "GATE FAIL(1) [$G]: a DATA type named list or a wrong-datatype field function does not agree with SPITBOL (examined 2 modes)"; fi
echo "    tree: SCRIP=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY)  oracle: $SBL $FLAGS  measured $(date -u +%Y-%m-%dT%H:%MZ)"
exit $RC
