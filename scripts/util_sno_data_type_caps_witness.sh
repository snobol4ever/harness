#!/usr/bin/env bash
export S4E_ONE_RUNNER_FIXTURE="witness ${0##*/}: a row's criterion run as an instrument, not a board (CEO-523)"
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
# util_sno_data_type_caps_witness.sh -- A DATA TYPE HAS NO FIXED CAP ON ITS FIELD COUNT OR ITS NAME (ceo CEO-1269, 2026-09-25, on the
# coo's COO-185 finding, .github findings/FINDING-2026-09-25-coo-the-fixed-caps-ratchet-is-red-on-origin-since-the-speed-landings-and-
# a-data-type-of-64-fields-or-a-64-character-name-raises-error-22.md). DatType's name[64] and fields[64][64] (rt_runtime.c) and the
# speed landings' _fv[64] clamps (by_name_dispatch.c, SCRIP 82b4a61a8) refuse legal programs: the coo measured error 22 for a 64-field
# type in m3 and a 70-field type in both modes, and error 22 at the constructor of a type with a 70-character name, where sbl -bf
# answers every one (ARCH-DYNAMIC-STORAGE.md: no fixed limit a program can reach).
# THE POINTS: witness A is DATA('T(F1,...,Fn)') with X = T(10,...,n*10), printing F1(X), Fn(X) and a field set and read back, for
# n = 63 (the control point, green on the parent), 64, 70 and 130; witness B is a type name and a field name of 70 characters each,
# printing both fields and DATATYPE(X). Every expected output is cut from the oracle at run time (sbl_correctness_bin, sbl_lang_flags),
# never a literal. m3 is ./scrip; m4 is --compile linked against out/libscrip_rt.so the way the SNOBOL4 gates build it.
# EXIT 0 every point prints the oracle's output in both modes; 1 a point differs or errors; 2 REFUSED (the oracle or the binary missing,
# or the oracle printed nothing for a point).
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
. "$HERE/lib_oracle_flags.sh"
SBL="$(sbl_correctness_bin)"; [ -x "$SBL" ] || { echo "REFUSED(2): correctness oracle missing ($SBL)"; exit 2; }
[ -x "$ROOT/scrip" ] || { echo "REFUSED(2): $ROOT/scrip not built"; exit 2; }
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
gen_fields() {
    local n="$1" p i
    p="T("; for ((i = 1; i <= n; i++)); do p+="F$i"; [ "$i" -lt "$n" ] && p+=","; done; p+=")"
    local a=""; for ((i = 1; i <= n; i++)); do a+="$((i * 10))"; [ "$i" -lt "$n" ] && a+=","; done
    printf "        DATA('%s')\n        X = T(%s)\n        OUTPUT = F1(X) ' ' F%d(X)\n        F%d(X) = 'set'\n        OUTPUT = F%d(X) ' ' DATATYPE(X)\nEND\n" "$p" "$a" "$n" "$n" "$n"
}
gen_names() {
    local t f
    t="$(printf 'T%.0s' $(seq 70))"; f="$(printf 'F%.0s' $(seq 70))"
    printf "        DATA('%s(%s,G)')\n        X = %s(1,2)\n        OUTPUT = %s(X) ' ' G(X) ' ' DATATYPE(X)\nEND\n" "$t" "$f" "$t" "$f"
}
red=0; pts=0
run_point() {
    local label="$1" src="$2" rc
    pts=$((pts + 1))
    "$SBL" $(sbl_lang_flags) "$src" < /dev/null > "$W/$label.ref" 2> /dev/null
    [ -s "$W/$label.ref" ] || { echo "REFUSED(2): the oracle printed nothing for point $label"; exit 2; }
    ( cd "$W" && timeout -k 5 30 "$ROOT/scrip" "$src" < /dev/null > "$label.m3" 2> "$label.m3e" ); rc=$?
    if [ "$rc" -ne 0 ] || ! cmp -s "$W/$label.m3" "$W/$label.ref"; then
        echo "RED m3 $label: rc=$rc got=$(head -c 60 "$W/$label.m3" | tr '\n' '|') want=$(head -c 60 "$W/$label.ref" | tr '\n' '|') err=$(tail -c 100 "$W/$label.m3e" | tr '\n' ' ')"; red=1
    else echo "ok  m3 $label: rc=0, output = the oracle's"; fi
    if ( cd "$W" && "$ROOT/scrip" --compile -o "$W/$label.s" "$src" < /dev/null > /dev/null 2>&1 && gcc "$W/$label.s" -L"$ROOT/out" -lscrip_rt -lm -Wl,-rpath,"$ROOT/out" -o "$W/$label.bin" 2> /dev/null ); then
        ( cd "$W" && timeout -k 5 30 "./$label.bin" < /dev/null > "$label.m4" 2> "$label.m4e" ); rc=$?
        if [ "$rc" -ne 0 ] || ! cmp -s "$W/$label.m4" "$W/$label.ref"; then
            echo "RED m4 $label: rc=$rc got=$(head -c 60 "$W/$label.m4" | tr '\n' '|') want=$(head -c 60 "$W/$label.ref" | tr '\n' '|') err=$(tail -c 100 "$W/$label.m4e" | tr '\n' ' ')"; red=1
        else echo "ok  m4 $label: rc=0, output = the oracle's"; fi
    else echo "RED m4 $label: the witness did not compile or link"; red=1; fi
}
for n in 63 64 70 130; do gen_fields "$n" > "$W/fields$n.sno"; run_point "fields$n" "$W/fields$n.sno"; done
gen_names > "$W/names70.sno"; run_point names70 "$W/names70.sno"
[ "$red" -eq 0 ] && { echo "WITNESS OK: $pts points, both modes, every output the oracle's -- a DATA type carries no fixed cap on its field count or its name"; exit 0; }
echo "WITNESS FAILED: of $pts points a mode differs from sbl -bf (row snobol4-a-data-type-of-64-fields-or-a-64-character-name-raises-error-22-and-130-fields-segfault-and-the-speed-landings-drop-locals-grow-with-it)"; exit 1
