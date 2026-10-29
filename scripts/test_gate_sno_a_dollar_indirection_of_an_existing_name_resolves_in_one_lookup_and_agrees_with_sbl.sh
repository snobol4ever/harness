#!/usr/bin/env bash
# test_gate_sno_a_dollar_indirection_of_an_existing_name_resolves_in_one_lookup_and_agrees_with_sbl.sh
#
# THE ROW (the speed row of name_indirection, 0.73x SPITBOL in the README of 2026-09-26): bn_sno_name, the run-time $ indirection, resolved an existing variable's name in three
# passes -- NV_name_needs_key (a memchr), NV_intern_name_n (a second memchr and a hash) and NV_CELL_IF_FASTSET_fn (a second hash and a strcmp) -- 1270 Ir per iteration of
# `$holder = $holder + 1` under callgrind. THE CURE: NV_CELL_FAST_n(s, n) walks the bucket once with the entry's own length-and-memcmp key and returns the value cell, and declines
# (NULL, so the unchanged slow path runs) for every name the slow path treats specially: a leading \x01 or &, an embedded NUL, an I/O-associated entry, INPUT, OUTPUT, TERMINAL, a
# protected pattern name, a name not yet interned, and any run with a monitor tap armed. MEASURED: 2,539,972,750 -> 1,776,992,847 Ir over 100 x 20000 iterations (888 per iteration).
# ARMS (expectations cut from sbl -bf AT RUN TIME): (A) one program of twenty indirections -- an existing name read and set, a name created through $, a literal $'k', an integer holder,
# a name with a blank, a keyword name through $, $$, $.name and DATATYPE of both forms -- in mode 3 and in mode 4; (B) the same program in both modes under SCRIP_GC_STRESS=1.
# rc=0 clean · rc=1 a divergence · rc=2 REFUSAL.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
B="$HERE/../../SCRIP"
refuse() { echo "⛔ REFUSES rc=2: $*"; exit 2; }
[ -x "$B/scrip" ] || refuse "$B/scrip is not built -- cannot measure"
. "$HERE/lib_oracle_flags.sh" 2>/dev/null || true
SBL="$(sbl_correctness_bin 2>/dev/null || true)"; [ -n "${SBL:-}" ] && [ -x "$SBL" ] || SBL=/home/resources/x64/bin/sbl
[ -x "$SBL" ] || refuse "no sbl oracle -- the expectations are cut from it at run time"
"$HERE/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
D="$(mktemp -d)" || refuse "no scratch dir"
trap 'rm -rf "$D"' EXIT
RT="$B/out"; RC=0; n=0
ok()  { n=$((n + 1)); echo "  ok    $*"; }
red() { n=$((n + 1)); RC=1; echo "  RED   $*"; }
cat > "$D/d.sno" <<'SNO'
        target = 'tv'
        holder = 'target'
        OUTPUT = 'read ' $holder
        $holder = 'set'
        OUTPUT = 'after ' target
        n = 'fresh'
        $n = 'created'
        OUTPUT = 'fresh ' fresh
        $'k' = 'lit'
        OUTPUT = 'k ' k
        i = 7
        $i = 'int named 7'
        OUTPUT = $7
        $'two words' = 'sp'
        OUTPUT = $'two words'
        &ANCHOR = 0
        h2 = '&ANCHOR'
        OUTPUT = 'kw ' $h2
        $h2 = 1
        OUTPUT = 'kw set ' &ANCHOR
        t = TABLE()
        t['a'] = 'ta'
        h3 = 'size'
        size = 99
        OUTPUT = $h3 + 1
        OUTPUT = $'OUTPUT'
        $'OUTPUT' = 'via out'
        hh = 'holder'
        OUTPUT = $$hh
        $$hh = 'changed'
        OUTPUT = target
        OUTPUT = DATATYPE($.holder) ' ' DATATYPE($holder)
END
SNO
want="$(cd "$D" && timeout -k 5 60 "$SBL" -bf d.sno < /dev/null 2>&1)"
[ -n "$want" ] || refuse "the oracle printed nothing for the witness"
"$B/scrip" --compile --out="$D/d.s" "$D/d.sno" < /dev/null > /dev/null 2>&1 && gcc -no-pie -o "$D/d.bin" "$D/d.s" -L "$RT" -lscrip_rt -lm -Wl,-rpath,"$RT" 2> /dev/null || refuse "the witness does not build in mode 4"
for env in "" "SCRIP_GC_STRESS=1"; do
  got3="$(cd "$D" && env $env timeout -k 5 120 "$B/scrip" d.sno < /dev/null 2>&1)"
  got4="$(cd "$D" && env $env timeout -k 5 120 ./d.bin < /dev/null 2>&1)"
  if [ "$got3" = "$want" ]; then ok "m3${env:+ ($env)}: $(printf '%s' "$want" | tr '\n' '|' | cut -c1-60)"; else red "m3${env:+ ($env)}: want [$(printf '%s' "$want" | tr '\n' '|' | cut -c1-100)] got [$(printf '%s' "$got3" | tr '\n' '|' | cut -c1-100)]"; fi
  if [ "$got4" = "$want" ]; then ok "m4${env:+ ($env)}: same"; else red "m4${env:+ ($env)}: want [$(printf '%s' "$want" | tr '\n' '|' | cut -c1-100)] got [$(printf '%s' "$got4" | tr '\n' '|' | cut -c1-100)]"; fi
done
[ "$RC" -eq 0 ] && echo "GREEN: $n arms" || echo "RED: a dollar indirection disagrees with sbl"
exit "$RC"
