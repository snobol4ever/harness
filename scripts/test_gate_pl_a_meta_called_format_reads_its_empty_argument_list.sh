#!/usr/bin/env bash
# test_gate_pl_a_meta_called_format_reads_its_empty_argument_list.sh -- format(F, []) REACHED THROUGH call/N PRINTS F (ISO-superset format/2;
# hq_prolog 2026-09-25, CEO-1266/1270; the cure is unification.c rt_pl_format_run, which now dereferences its argument list before reading it).
# THE DEFECT. The leftover-argument test asked plc_is_nil of the list cell AS PASSED; a meta-call hands the leaf a reference to [] rather than
# [] itself, so an untouched empty list read as "arguments left over" and raised domain_error(format_arguments, []) -- X = format("b~n", []),
# call(X) failed where the same goal written directly printed b. A list that directives consumed (format("d ~w~n", [1])) was unaffected,
# which is why only the empty list showed it. The ball's culprit carried the same undereferenced cell.
# THE EXPECTATIONS ARE gprolog's (2026-09-25): the five lines below. RED BEFORE on origin eea1ddd0d, m3 AND m4: lines 2, 4 and 5 missing, raised.
set -u
GATE_NAME=test_gate_pl_a_meta_called_format_reads_its_empty_argument_list
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIP="${SCRIP_BIN:-$HERE/../../SCRIP/scrip}"
RT="${RT_DIR:-$(dirname "$SCRIP")/out}"
refuse() { echo "⛔ REFUSED(2) [$GATE_NAME]: $*" >&2; exit 2; }
[ -x "$SCRIP" ] || refuse "no scrip binary at $SCRIP -- run make first"
[ -n "${SCRIP_BIN:-}" ] || "$HERE/util_require_fresh.sh" --gate "$GATE_NAME" "$SCRIP" "$RT/libscrip_rt.so" || exit 2
TMPD="$(mktemp -d)"; trap 'rm -rf "$TMPD"' EXIT
cat > "$TMPD/fm.pl" <<'EOP'
:- initialization(main).
t(G) :- catch(call(G), E, (write(raised(E)), nl)).
main :- format("a~n", []), X = format("b~n", []), t(X), G = format("d ~w~n", [1]), t(G), t(call(format, "e~n", [])), Z = format('f~n', []), t(Z).
EOP
want='a
b
d 1
e
f'
red=0
for mode in m3 m4; do
    if [ "$mode" = m3 ]; then got="$(timeout -k 5 20 "$SCRIP" "$TMPD/fm.pl" </dev/null 2>"$TMPD/err")"; rc=$?
    else
        timeout -k 5 60 "$SCRIP" --compile --out="$TMPD/fm.s" "$TMPD/fm.pl" </dev/null 2>"$TMPD/err" || refuse "m4 compile failed: $(head -c 160 "$TMPD/err")"
        gcc -m64 -no-pie "$TMPD/fm.s" -o "$TMPD/fm.bin" -L"$RT" -lscrip_rt -Wl,-rpath,"$RT" -lm 2>"$TMPD/err" || refuse "m4 link failed: $(head -c 160 "$TMPD/err")"
        got="$(timeout -k 5 20 "$TMPD/fm.bin" </dev/null 2>"$TMPD/err")"; rc=$?
        rm -f "$TMPD/fm.s" "$TMPD/fm.bin"
    fi
    if [ "$rc" = 0 ] && [ "$got" = "$want" ]; then echo "  ok  $mode"
    else echo "  RED $mode: rc=$rc out=[$(printf '%s' "$got" | tr '\n' '|' | cut -c1-200)]"; red=$((red+1)); fi
done
[ "$red" = 0 ] || { echo "GATE FAIL [$GATE_NAME]: $red mode(s) red"; exit 1; }
echo "GATE PASS [$GATE_NAME]: a meta-called format/2 reads an empty argument list as empty, both modes as gprolog"
exit 0
