#!/usr/bin/env bash
# test_gate_sno_mode_4_fatal_error_names_its_line_after_a_kept_runtime_chain.sh -- a fatal error names its source line ("at FILE:LINE; statement N") in
# mode 4 as it does in mode 3 and in sbl -bf, also once the program has KEPT a runtime-built chain (the same EVAL text twice, an EVAL whose value is a
# pattern, CODE). The statement of an error is read from a code map by the return addresses of the emitted frames: the runtime table holds the marks of
# chains built at run time (emit_stno_mark's binary branch), and scrip_stno_from_return_addrs consulted the binary's own static scrip_stno_map section only
# when that runtime table was EMPTY, so once a chain was kept the main program's return addresses went unmapped and the line was lost. stno_rec_find now
# searches the runtime table and, failing that, the static section.
# Row snobol4-mode-4-loses-a-fatal-errors-line-once-a-runtime-chain-is-kept-the-static-stno-map-is-skipped (cfo's cause, hq_snobol4).
#
# THE WITNESSES (each a program that ends in a division by zero, error 14; every expected line is cut from sbl -bf at run time):
#   k1 EVAL('1 + 1') twice   k2 an EVAL whose value is a pattern   k3 CODE(' X = 1')   k4 the error inside a DEFINEd function called after two kept EVALs
#   k5 control: ONE EVAL of a scalar (its chain is released, the static map was always read)
# arm 0 (CEO-1680, a proper test, no seam): the comparator grades a corrupted copy of sbl's answer and must read it RED.
set -u
G=test_gate_sno_mode_4_fatal_error_names_its_line_after_a_kept_runtime_chain
HERE="$(cd "$(dirname "$0")" && pwd)"; SD="$HERE/../../SCRIP"; SCRIP="$SD/scrip"
[ -x "$SCRIP" ] || { echo "⛔ REFUSE(rc=2) [$G]: no scrip binary at $SCRIP -- build first (make)"; exit 2; }
"$HERE/util_require_fresh.sh" --gate "$G" "$SCRIP" "${RT_DIR:-$SD/out}/libscrip_rt.so" || exit 2
. "$HERE/lib_oracle_flags.sh"
SBL="$(sbl_correctness_bin)"; [ -x "$SBL" ] || { echo "⛔ REFUSE(rc=2) [$G]: no correctness oracle ($SBL) -- the ref is cut from the oracle at run time, never typed"; exit 2; }
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
names="k1 k2 k3 k4 k5"
printf "        Z = 0\n        X = EVAL('1 + 1')\n        X = EVAL('1 + 1')\n        Y = 1 / Z\nEND\n" > "$W/k1.sno"
printf "        Z = 0\n        P = EVAL(\"LEN(1) | 'q'\")\n        Y = 1 / Z\nEND\n" > "$W/k2.sno"
printf "        Z = 0\n        C = CODE(' X = 1')\n        Y = 1 / Z\nEND\n" > "$W/k3.sno"
printf "        DEFINE('f(x)')   :(fe)\nf       f = 1 / x   :(RETURN)\nfe      Z = 0\n        X = EVAL('1 + 1')\n        X = EVAL('1 + 1')\n        Y = f(Z)\nEND\n" > "$W/k4.sno"
printf "        Z = 0\n        X = EVAL('1 + 1')\n        Y = 1 / Z\nEND\n" > "$W/k5.sno"
norm() { sed -n -E -e 's/^[^ ]*\.sno\(([0-9]+)\) : ERROR 0*([0-9]+).*/error \2 line \1/p' -e 's/^scrip: error ([0-9]+):.*/error \1/p' -e 's/^  at [^:]*\.sno:([0-9]+);.*/line \1/p' | uniq | paste -sd' '; }
for n in $names; do
    w="$(cd "$W" && timeout -k 5 20 "$SBL" $(sbl_lang_flags) "$n.sno" </dev/null 2>&1 | norm)"
    case "$w" in "error 14 line "*) printf '%s' "$w" > "$W/$n.want";; *) echo "⛔ REFUSE(rc=2) [$G]: the oracle read '$w' for $n, not 'error 14 line N' -- the arms cannot grade"; exit 2;; esac
    (cd "$W" && timeout -k 5 60 "$SCRIP" --compile --out="$n.s" "$n.sno" </dev/null >/dev/null 2>&1) \
        && gcc -no-pie "$W/$n.s" -L"$SD/out" -lscrip_rt -lm -lpthread -Wl,-rpath,"$SD/out" -o "$W/$n.bin" 2>/dev/null \
        || { echo "⛔ REFUSE(rc=2) [$G]: $n did not compile and link in mode 4"; exit 2; }
done
grade() { [ "$1" = "$2" ]; }
w1want="$(cat "$W/k1.want")"; bad="X$w1want"
grade "$w1want" "$bad" && { echo "⛔ REFUSE(rc=2) [$G]: arm 0 -- the comparator read a corrupted ref ('$bad') as GREEN; it cannot fail"; exit 2; }
echo "== [$G] a fatal error's line after a kept runtime chain, graded against $SBL"
echo "  PASS arm0 the comparator reads a corrupted ref ('$bad') RED"
fail=0
for n in $names; do
    want="$(cat "$W/$n.want")"
    v3="$(cd "$W" && timeout -k 5 20 "$SCRIP" "$n.sno" </dev/null 2>&1 | norm)"
    v4="$(cd "$W" && timeout -k 5 20 "$W/$n.bin" -- </dev/null 2>&1 | norm)"
    for m in m3 m4; do
        v="$v3"; [ "$m" = m4 ] && v="$v4"
        if grade "$v" "$want"; then echo "  PASS $n $m = sbl ($want)"; else echo "  ⛔ $n $m RED: got '$v', sbl '$want'"; fail=1; fi
    done
done
[ "$fail" = 0 ] && { echo "OK [$G]: a fatal error names its line in mode 4 after a kept runtime chain, as mode 3 and sbl do"; exit 0; }
echo "⛔ GATE RED [$G]: a fatal error after a kept runtime chain does not name its line as sbl does"; exit 1
