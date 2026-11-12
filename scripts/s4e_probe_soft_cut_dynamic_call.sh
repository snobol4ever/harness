#!/usr/bin/env bash
# s4e_probe_soft_cut_dynamic_call.sh [--list] -- A SOFT CUT WHOSE CONDITION IS A RUN-TIME-RESOLVED CALL (IR_CALL_VALUE) ANSWERS AS swipl (officer_02
# 2026-11-11, the true cause A of prelude-object step 4, CIO-129). Three programs put a call of a predicate consulted at run time from a second
# file (so lower sends it down pl_meta_call_dyn) under *-> : leaving a choice point, determinate, and inside a conjunction; a fourth puts the
# first under -> as the control. Each runs on the source road (SCRIP_PL_PRELUDE_SO=0) in mode 3 (--run) and mode 4 (--compile, gcc, run) and is compared with
# swipl 9.0.4 through util_oracle.sh. MEASURED 2026-11-11 at SCRIP 145ad3835 (officer_02): the three soft cuts die signal 11 in mode 3, the
# control prints as swipl (the first, consulted, in both modes; the others measured with '$dl_dyn' conditions).
# rc 0 GREEN, 1 RED naming each program and mode that differs, 2 REFUSE (no binary, no oracle, the control red). Writes only under /tmp/s4e/<seat>.
set -u
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="${S4E_HOME:?REFUSE(2): S4E_HOME unset}"
me="s4e_probe_soft_cut_dynamic_call"
refuse() { echo "REFUSE(2) [$me]: $*"; exit 2; }
[ "${1:-}" = "--list" ] && { sed -n '2,8p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0; }
scrip="$root/SCRIP/scrip"; [ -x "$scrip" ] || refuse "no binary at $scrip (make -j8 first)"
bash "$here/util_require_fresh.sh" --gate "$me" >/dev/null 2>&1 || { bash "$here/util_require_fresh.sh" --gate "$me"; exit 2; }
seat="${S4E_SEAT:-probe}"; mkdir -p "/tmp/s4e/$seat"; t="$(mktemp -d "/tmp/s4e/$seat/softcut_dyn.XXXXXX")" || refuse "no scratch"
trap 'rm -rf "$t"' EXIT
tree="$(git -C "$root/SCRIP" rev-parse --short=9 HEAD 2>/dev/null)"
printf 'mm(X,[X|_]).\nmm(X,[_|T]) :- mm(X,T).\n' > "$t/other.pl"
printf ':- initialization(main).\nmain :- consult(%s), go.\ngo :- between(1,2,N), ( mm(N,[2,1,2]) *-> write(h1) ; write(h2) ), write(N), fail.\ngo :- nl.\n' "'other.pl'" > "$t/consulted.pl"
printf ':- initialization(main).\nmain :- consult(%s), go.\ngo :- between(1,2,N), ( mm(X,[a]) *-> write(X) ; write(e) ), write(N), fail.\ngo :- nl.\n' "'other.pl'" > "$t/consulted_det.pl"
printf ':- initialization(main).\nmain :- consult(%s), go.\ngo :- between(1,2,N), ( mm(X,[a,b]), X \\== N *-> write(X) ; write(e) ), write(N), fail.\ngo :- nl.\n' "'other.pl'" > "$t/consulted_conj.pl"
printf ':- initialization(main).\nmain :- consult(%s), go.\ngo :- between(1,2,N), ( mm(N,[2,1,2]) -> write(h1) ; write(h2) ), write(N), fail.\ngo :- nl.\n' "'other.pl'" > "$t/control_ite.pl"
want() { ( cd "$t" && bash "$here/util_oracle.sh" swipl --timeout 60 -- -q -t halt "$1" < /dev/null 2>&1 ); }
m3() { ( cd "$t" && SCRIP_PL_PRELUDE_SO=0 bash "$here/util_run_slot.sh" timeout -k 5 60 "$scrip" --dialect=swi --run "$1" < /dev/null 2>&1 ); }
m4() {
    local b; b="$(basename "$1" .pl)"
    ( cd "$t" && SCRIP_PL_PRELUDE_SO=0 bash "$here/util_run_slot.sh" timeout -k 5 600 "$scrip" --dialect=swi --compile --target=x86 "$1" < /dev/null > "$t/$b.s" 2> "$t/$b.cerr" ) || { echo "(mode 4: compile failed)"; return; }
    s4e_m4_link "$t/$b.s" "$t/$b.bin" "$root/SCRIP/out" > "$t/$b.lerr" 2>&1 || { echo "(mode 4: link failed: $(head -1 "$t/$b.lerr"))"; return; }
    ( cd "$t" && bash "$here/util_run_slot.sh" timeout -k 5 60 "$t/$b.bin" < /dev/null 2>&1 )
}
. "$here/lib_mode4_link.sh" || refuse "lib_mode4_link.sh unloadable"
red=0; n=0
for p in control_ite consulted consulted_det consulted_conj; do
    w="$(want "$t/$p.pl")"; [ -n "$w" ] || refuse "swipl gave no answer for $p"
    for mode in m3 m4; do
        n=$((n + 1)); o="$($mode "$t/$p.pl")"
        if [ "$o" != "$w" ]; then
            [ "$p" = control_ite ] && refuse "the control $p reads wrong in $mode ($(printf '%s' "$o" | head -1 | cut -c1-80)): the probe measures nothing"
            red=$((red + 1)); echo "  RED $p $mode: prints $(printf '%s' "$o" | head -1 | cut -c1-100)   swipl prints $(printf '%s' "$w" | head -1)"
        fi
    done
done
echo "SOFT_CUT_DYNAMIC_CALL_BOARD runs=$n red=$red (tree $tree)"
[ "$red" = 0 ] && { echo "GATE OK [$me]: every soft cut over a run-time-resolved call answers as swipl in both modes"; exit 0; }
echo "GATE FAIL [$me]: $red of $n runs differ from swipl"; exit 1
