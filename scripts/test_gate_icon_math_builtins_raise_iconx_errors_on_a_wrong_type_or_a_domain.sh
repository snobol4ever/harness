#!/usr/bin/env bash
# test_gate_icon_math_builtins_raise_iconx_errors_on_a_wrong_type_or_a_domain.sh -- ICON'S MATH BUILTINS CONVERT AND CHECK AS ICONX DOES: sqrt sin cos tan asin acos exp log dtor rtod abs
# (row gate-raku-rat-an-icon-record-is-now-taken-as-numeric-error-102-in-icn-05-ceo-1807, cfo 2026-10-17).
#
# THE DEFECT: on the Icon road sqrt, sin, cos, tan, asin, acos, exp, log, dtor and rtod read their argument through TONUM, which answers 0 for a record, a list, a table, &null, "" and "abc" and strtod's
# prefix for "36rZZ" (36) and "0x10" (16), and 0 for a large integer; and they returned nan or inf where iconx raises 205 (sqrt and log of a negative, asin and acos outside [-1,1], a log base of 1 or
# below 0) or 204 (exp and tan overflowing). Arizona iconx 9.5 (fmath.r) converts each argument with cnv:C_double -- 102 when it is not numeric, "1e400" included -- then checks the domain.
# abs and atan had the type check already (SCRIP 49c2cdaee); "1e400" was still taken by abs.
# THE CURE: src/runtime/by_name_dispatch.c -- icn_math1 and icn_math_log answer the strict (Icon) road through icn_cvt_num_ok, relop_radix_coerce and to_real, then iconx's domain checks;
# icn_cvt_num_ok refuses a real-syntax string whose value overflows. Raku and the other non-strict roads keep TONUM.
# THE WITNESS: ../harness/scripts/fixtures/icon_math_builtins/math_types_and_domains.icn, 26 arguments x 11 builtins plus 28 two-argument logs and one uncaught error; its ref (stdout and rc) is CUT FROM ICONX,
# and this gate re-runs iconx and refuses if the oracle no longer prints the ref. The one known departure is left out of the witness: image() of an infinite real prints inf where iconx prints inf.0
# (string_ops.c's shared real formatter).
# FAILED ONCE: on SCRIP 1300d99af (the parent) 153 of the 315 ref lines differ in both modes.
#
# EXIT: 0 both modes print the ref; 1 a mode differs; 2 REFUSED (stale binary, no gcc, no iconx, or the oracle disagrees with the ref).
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
cd "$ROOT"
. "$HERE/lib_gate.sh"
. "$HERE/lib_oracle_flags.sh"
GATE_NAME="icon_math_builtins_iconx_errors"
gate_parse_args "$@"
gate_require_fresh "$ROOT" src "$ROOT/scrip" "$ROOT/out/libscrip_rt.so"
command -v gcc >/dev/null 2>&1 || { echo "⛔ REFUSE(rc=2) [$GATE_NAME]: gcc not found -- mode 4 cannot be linked, so half the population is unmeasured"; exit 2; }
FX="$ROOT/../harness/scripts/fixtures/icon_math_builtins"
P=math_types_and_domains
[ -f "$FX/$P.icn" ] && [ -f "$FX/$P.ref" ] || { echo "⛔ REFUSE(rc=2) [$GATE_NAME]: no witness at $FX/$P.icn"; exit 2; }
ICONT="$(icont_bin)" || { echo "⛔ REFUSE(rc=2) [$GATE_NAME]: the Icon oracle is missing"; exit 2; }
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
fails=0; GATE_EXAMINED=0
cp "$FX/$P.icn" "$W/"
(cd "$W" && "$ICONT" -s -o "$W/$P.x" "$P.icn" </dev/null >/dev/null 2>&1) || { echo "⛔ REFUSE(rc=2) [$GATE_NAME]: icont could not translate the witness"; exit 2; }
oracle="$(cd "$W" && timeout -k 5 30 "$W/$P.x" </dev/null 2>/dev/null; echo "rc=$?")"
[ "$oracle" = "$(cat "$FX/$P.ref")" ] || { echo "⛔ REFUSE(rc=2) [$GATE_NAME]: iconx no longer prints the ref -- re-cut $FX/$P.ref from the oracle before grading"; exit 2; }
for m in m3 m4; do
    GATE_EXAMINED=$((GATE_EXAMINED + 1))
    if [ "$m" = m3 ]; then got="$(cd "$W" && timeout -k 5 60 "$ROOT/scrip" "$P.icn" </dev/null 2>/dev/null; echo "rc=$?")"
    elif (cd "$W" && timeout -k 5 60 "$ROOT/scrip" --compile -o "$W/$P.s" "$P.icn" </dev/null >"$W/cerr" 2>&1) && gcc -o "$W/$P.bin" "$W/$P.s" -L"$ROOT/out" -lscrip_rt -Wl,-rpath,"$ROOT/out" -lm -lpthread >>"$W/cerr" 2>&1; then
        got="$(cd "$W" && timeout -k 5 60 "$W/$P.bin" </dev/null 2>/dev/null; echo "rc=$?")"
    else got="COMPILE-FAIL: $(head -1 "$W/cerr" | cut -c1-100)"; fi
    if [ "$got" = "$(cat "$FX/$P.ref")" ]; then printf '  ok   %s %s: %s lines = iconx\n' "$P" "$m" "$(printf '%s\n' "$got" | wc -l)"
    else
        n="$(diff <(printf '%s\n' "$got") "$FX/$P.ref" | grep -c '^>')"
        printf '  FAIL %s %s: %s ref line(s) differ; first: %s\n' "$P" "$m" "$n" "$(diff <(printf '%s\n' "$got") "$FX/$P.ref" | grep -m1 '^[<>]' | cut -c1-140)"
        fails=$((fails + 1))
    fi
done
gate_verdict "$fails" "mode(s) differ from iconx on the Icon math builtins' conversions and domain errors"
