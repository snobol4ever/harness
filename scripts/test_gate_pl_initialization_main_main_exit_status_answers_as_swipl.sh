#!/usr/bin/env bash
# test_gate_pl_initialization_main_main_exit_status_answers_as_swipl.sh
#
# THE DEFECT (hq_prolog 2026-10-15, found curing the rungs' bb7cfbe56 reds; ceo CEO-1766 ordered the row): a program whose
# `:- initialization(main, main).` goal FAILS exits 1 under swipl 9.0.4 ("main: false" on stderr) and 0 under SCRIP in mode 3.
# The main/2 form is swipl's script contract: success halts 0, an uncaught error halts 2, a failure halts 1.
#
# Each arm writes one program, runs swipl on it for the oracle's exit status (swipl-cut, read live, never typed here), then SCRIP
# in both modes; verdict is the exit status equal to swipl's and stdout byte-equal to swipl's.
# rc=0 clean · rc=1 a divergence · rc=2 REFUSAL.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
B="$HERE/../../SCRIP"
refuse() { echo "⛔ REFUSES rc=2: $*"; exit 2; }
. "$HERE/lib_oracle_flags.sh" || refuse "lib_oracle_flags.sh unloadable"
SWIPL="$(swipl_bin)" || refuse "no swipl oracle"
[ -x "$B/scrip" ] || refuse "$B/scrip is not built -- cannot measure"
[ -f "$B/out/libscrip_rt.so" ] || refuse "out/libscrip_rt.so is not built -- mode 4 cannot link"
D="$(mktemp -d)" || refuse "no scratch dir"
trap 'rm -rf "$D"' EXIT
n=0; red=0
one() {
    local name="$1" body="$2"
    printf ':- initialization(main, main).\nmain :- %s.\n' "$body" > "$D/$name.pl"
    ( cd "$D" && timeout -k 5 30 "$SWIPL" "$name.pl" < /dev/null > "$name.ow" 2>/dev/null; echo $? > "$name.orc" )
    local orc; orc="$(cat "$D/$name.orc")"
    case "$orc" in 0|1|2) ;; *) refuse "$name.pl: swipl exited $orc -- no oracle answer";; esac
    ( cd "$D" && timeout -k 5 30 "$B/scrip" "$name.pl" < /dev/null > "$name.m3" 2>/dev/null; echo $? > "$name.rc3" )
    ( cd "$D" && timeout -k 5 60 "$B/scrip" --compile --out="$name.s" "$name.pl" < /dev/null > /dev/null 2>&1 && gcc -no-pie "$name.s" -L"$B/out" -lscrip_rt -lm -lpthread -Wl,-rpath,"$B/out" -o "$name.bin" 2>/dev/null ) || refuse "$name.pl: mode 4 did not compile"
    ( cd "$D" && timeout -k 5 30 "./$name.bin" < /dev/null > "$name.m4" 2>/dev/null; echo $? > "$name.rc4" )
    for m in 3 4; do
        n=$((n + 1)); local rc; rc="$(cat "$D/$name.rc$m")"
        if [ "$rc" = "$orc" ] && cmp -s "$D/$name.ow" "$D/$name.m$m"; then echo "  ok   $name m$m: rc $rc as swipl"
        else echo "  FAIL $name m$m: rc $rc, swipl rc $orc$(cmp -s "$D/$name.ow" "$D/$name.m$m" || echo ', stdout differs')"; red=$((red + 1)); fi
    done
}
one main_fails 'write(before), nl, fail'
one main_succeeds 'write(done), nl'
one main_raises 'write(before), nl, throw(oops)'
if [ $red -eq 0 ]; then echo "GATE PASS(0): initialization(main, main) exits as swipl does in both modes, $n arm(s)"; exit 0; fi
echo "GATE FAIL(1): $red of $n arm(s) diverge"; exit 1
