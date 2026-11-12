#!/usr/bin/env bash
# test_design_prolog_witnesses.sh -- run a folder of Prolog design witnesses (each W.pl beside W.ref cut from swipl) in mode 3 and mode 4 and grade stdout
# against the ref (the cto, 2026-10-30; ARCH-PROLOG-ACTIVATION-LIFETIME 10.6 and ARCH-EXCEPTIONS-ONE-PROTOCOL 9.6).
#   usage: test_design_prolog_witnesses.sh <group> [stem ...]   (the group a family of the prolog master, or a loose corpus/tests/prolog/<group>)        (--modes 3|4|34, default 34; an optional W.args sidecar holds sizing switches)
# A witness that produces no scrip binary is REFUSED rc 2 (build the tree first); rc 0 only when every witness agrees in every requested mode; rc 1 on the first disagreement set.
set -u
cd "${S4E_HOME:?REFUSE(2): S4E_HOME unset}" || exit 2
modes=34
if [ "${1:-}" = "--modes" ]; then modes=$2; shift 2; fi
dir=$1; shift
. "$PWD/harness/scripts/lib_design_witness.sh" || { echo "REFUSE(2): lib_design_witness.sh unloadable"; exit 2; }
D=$(mktemp -d /tmp/s4e-dw-wit-XXXXXX)   # the group's witnesses staged: the entries DIR__stem of the prolog master (the cto entered the groups, corpus 243754fde), else a loose corpus/tests/prolog/DIR
design_witness_stage_all "$dir" "$D" > /dev/null || { echo "REFUSE(2): the witnesses of $dir did not stage (lib_design_witness.sh)"; rm -rf "$D"; exit 2; }
[ -x SCRIP/scrip ] && [ -f SCRIP/out/libscrip_rt.so ] || { echo "REFUSE(2): SCRIP/scrip or SCRIP/out/libscrip_rt.so missing -- make -C SCRIP first"; exit 2; }
stems=("$@"); [ ${#stems[@]} -gt 0 ] || mapfile -t stems < <(cd "$D" && ls *.pl | sed 's/\.pl$//')
T=$(mktemp -d /tmp/s4e-dw-XXXXXX); trap 'rm -rf "$T" "$D"' EXIT
red=0; n=0
for w in "${stems[@]}"; do
    src=$D/$w.pl; ref=$D/$w.ref; args=""; [ -f "$D/$w.args" ] && args=$(cat "$D/$w.args")
    [ -f "$src" ] && [ -f "$ref" ] || { echo "REFUSE(2): $w needs $w.pl and $w.ref"; exit 2; }
    case $modes in *3*)
        n=$((n+1)); (cd "$T" && timeout -k 5 8s "$OLDPWD/SCRIP/scrip" $args "$src" < /dev/null > "$T/$w.m3.out" 2> "$T/$w.m3.err"); rc=$?
        if cmp -s "$T/$w.m3.out" "$ref"; then echo "AGREE m3 $w"; else red=$((red+1)); echo "DIFF  m3 $w rc=$rc :: got $(head -c 160 "$T/$w.m3.out" | tr '\n' '|') :: err $(head -c 160 "$T/$w.m3.err" | tr '\n' '|')"; fi;;
    esac
    case $modes in *4*)
        n=$((n+1))
        if (cd "$T" && timeout -k 5 30s "$OLDPWD/SCRIP/scrip" --compile "$src" < /dev/null > "$T/$w.s" 2> "$T/$w.m4.cerr" && gcc -c "$T/$w.s" -o "$T/$w.o" 2>> "$T/$w.m4.cerr" && gcc "$T/$w.o" -L"$OLDPWD/SCRIP/out" -lscrip_rt -lm -lpthread -Wl,-rpath,"$OLDPWD/SCRIP/out" -o "$T/$w.bin" 2>> "$T/$w.m4.cerr"); then
            (cd "$T" && timeout -k 5 8s "$T/$w.bin" $args < /dev/null > "$T/$w.m4.out" 2> "$T/$w.m4.err"); rc=$?
            if cmp -s "$T/$w.m4.out" "$ref"; then echo "AGREE m4 $w"; else red=$((red+1)); echo "DIFF  m4 $w rc=$rc :: got $(head -c 160 "$T/$w.m4.out" | tr '\n' '|') :: err $(head -c 160 "$T/$w.m4.err" | tr '\n' '|')"; fi
        else red=$((red+1)); echo "DIFF  m4 $w could not build :: $(head -c 200 "$T/$w.m4.cerr" | tr '\n' '|')"; fi;;
    esac
done
echo "summary dir=$dir runs=$n red=$red"
[ "$red" -eq 0 ]
