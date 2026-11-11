#!/usr/bin/env bash
# util_prelude_object.sh [--root DIR] | --probe -- THE PROLOG PRELUDE SHARED OBJECT OF A ROOT'S OWN RUNTIME, BUILT ONCE, OUTSIDE THE ROOT (the cio
# 2026-11-11, CIO-129; Lon 2026-11-09, COO-500: "Make Prolog run much faster by using a shared object for all the prelude code."). The object road
# reads worse than the source road today (the coo 2026-11-11: trealla 313 against 319; a soft cut over an object predicate crashes or answers wrong),
# so it is held off every root; yet a row that cures one of its causes must RUN it. This prints the absolute path of the object compiled from
# DIR/SCRIP's runtime as it stands (default DIR: S4E_HOME), for the path form of the switch:
#     SO="$(bash harness/scripts/util_prelude_object.sh)" && SCRIP_PL_PRELUDE_SO="$SO" ./scrip --run prog.pl      (the object road)
#     SCRIP_PL_PRELUDE_SO=0 ./scrip --run prog.pl                                                                 (the source road)
# The object is keyed by the bytes of DIR/SCRIP/out/libscrip_rt.so and of DIR/SCRIP/scrip and kept in /home/resources/builds/prelude-object/KEY/,
# so every root holding the same build shares one compile (about 60 s and 550 MB, through one run slot and one compile slot); a second caller of
# the same key waits on the first under a lock. Nothing is written under DIR: an object beside a runtime it was not compiled from is loaded
# silently (MEASURED 2026-11-11 on the cio's root: an object of 07:27 beside a runtime fetched at 09:41, and the soft-cut repro died signal 11
# with the switch unset). Entries not used for two days are removed when a new one is built.
# rc 0 and the path on standard output; rc 2 REFUSE (no binary, the compile failed, the object does not load). --probe proves on the caller's
# root that the path form loads the object (a one-line program runs under a tenth of the source road's instructions is NOT asserted: a clock or
# a count is no probe); it asserts that the loader opened the printed file with the path form and opened no prelude object with the switch at 0.
set -u
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
refuse() { echo "REFUSE(2) [util_prelude_object]: $*" >&2; exit 2; }
root="${S4E_HOME:-}"; probe=0
while [ $# -gt 0 ]; do case "$1" in --root) root="${2:-}"; shift;; --probe) probe=1;; *) refuse "usage: util_prelude_object.sh [--root DIR] | --probe";; esac; shift; done
[ -n "$root" ] || refuse "S4E_HOME unset and no --root"
scrip="$root/SCRIP/scrip"; rt="$root/SCRIP/out/libscrip_rt.so"
[ -x "$scrip" ] && [ -f "$rt" ] || refuse "no build at $root/SCRIP (make -j8 first)"
store="${S4E_PRELUDE_OBJECT_STORE:-/home/resources/builds/prelude-object}"
key="$(cat "$rt" "$scrip" | sha256sum | cut -c1-24)"
obj="$store/$key/libscrip_prelude_prolog.so"
build() {
    mkdir -p "$store" || refuse "cannot make $store"
    exec 8> "$store/.$key.lock"; flock 8
    [ -f "$obj" ] && return 0
    local seat="${S4E_SEAT:-prelude}" t
    mkdir -p "/tmp/s4e/$seat"; t="$(mktemp -d "/tmp/s4e/$seat/prelude_object.XXXXXX")" || refuse "no scratch"
    : > "$t/empty.pl"
    ( cd "$t" && SCRIP_PL_PRELUDE_SO=0 timeout -k 10 900 bash "$here/util_run_slot.sh" "$scrip" --prolog-prelude-unit --compile --out="$t/prolog_prelude.s" "$t/empty.pl" < /dev/null > "$t/unit.log" 2>&1 ) || { tail -3 "$t/unit.log" >&2; refuse "the unit compile failed (log $t/unit.log)"; }
    bash "$here/util_cc_slot.sh" gcc -c "$t/prolog_prelude.s" -o "$t/prolog_prelude.o" > "$t/cc.log" 2>&1 || { tail -3 "$t/cc.log" >&2; refuse "the assembler refused the unit (log $t/cc.log)"; }
    bash "$here/util_cc_slot.sh" gcc -shared "$t/prolog_prelude.o" -o "$t/libscrip_prelude_prolog.so" >> "$t/cc.log" 2>&1 || { tail -3 "$t/cc.log" >&2; refuse "the link failed (log $t/cc.log)"; }
    mkdir -p "$store/$key.tmp.$$" && mv "$t/libscrip_prelude_prolog.so" "$store/$key.tmp.$$/" && mv -T "$store/$key.tmp.$$" "$store/$key" 2>/dev/null || { [ -f "$obj" ] || refuse "cannot publish $obj"; }
    rm -rf "$t" "$store/$key.tmp.$$"
    find "$store" -mindepth 1 -maxdepth 1 -type d -atime +2 ! -name "$key" -exec rm -rf {} + 2>/dev/null
    return 0
}
[ -f "$obj" ] || build
[ -f "$obj" ] || refuse "no object at $obj after the build"
touch -a "$store/$key" 2>/dev/null
if [ "$probe" = 0 ]; then echo "$obj"; exit 0; fi
seat="${S4E_SEAT:-prelude}"; mkdir -p "/tmp/s4e/$seat"; p="$(mktemp -d "/tmp/s4e/$seat/prelude_object_probe.XXXXXX")" || refuse "no scratch"
printf ':- initialization(main).\nmain :- member(X, [a,b]), write(X), nl, fail.\nmain.\n' > "$p/w.pl"
on="$(cd "$p" && SCRIP_PL_PRELUDE_SO="$obj" LD_DEBUG=files timeout -k 5 300 bash "$here/util_run_slot.sh" "$scrip" --run "$p/w.pl" < /dev/null 2> "$p/on.err")"; rc_on=$?
off="$(cd "$p" && SCRIP_PL_PRELUDE_SO=0 LD_DEBUG=files timeout -k 5 300 bash "$here/util_run_slot.sh" "$scrip" --run "$p/w.pl" < /dev/null 2> "$p/off.err")"; rc_off=$?
opened_on="$(grep -c "file=$obj" "$p/on.err")"; opened_off="$(grep -c 'libscrip_prelude_prolog' "$p/off.err")"
want="$(printf 'a\nb')"
[ "$rc_off" = 0 ] && [ "$off" = "$want" ] || refuse "the source road does not print the witness's answer (rc $rc_off): the probe measures nothing"
echo "PRELUDE_OBJECT_PROBE key=$key object_opened_by_path=$opened_on object_opened_at_0=$opened_off answer_on_object_road=$([ "$on" = "$want" ] && [ "$rc_on" = 0 ] && echo equal || echo differs)"
rm -rf "$p"
[ "$opened_on" -ge 1 ] && [ "$opened_off" = 0 ] && [ "$on" = "$want" ] && [ "$rc_on" = 0 ] && { echo "GATE OK [util_prelude_object --probe]: the path form loads the object and the switch at 0 loads none"; exit 0; }
echo "GATE FAIL [util_prelude_object --probe]"; exit 1
