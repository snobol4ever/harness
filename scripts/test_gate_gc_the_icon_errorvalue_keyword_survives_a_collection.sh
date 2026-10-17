#!/usr/bin/env bash
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
# test_gate_gc_the_icon_errorvalue_keyword_survives_a_collection.sh
#   cto 2026-09-26, row icon-master-under-scrip-gc-stress-5-... (row 774, rewritten on the ceo's CEO-1271 to read
#   its named IcnRungs entries as extracted witnesses). The last red of its 22 was procedure_record_every_replace_12:
#   under SCRIP_GC_STRESS=5 its &errorvalue read back as "record record_-2604246222170760229(0)" where iconx reads
#   list_13(0).
#
# WHAT IT GATES.  Icon's &errorvalue lives in g_icn_errvalue (core.c), a C global DESCR written when a run-time error
# is converted to failure (&error nonzero) and read by the keyword until the next error.  No root walk visited it,
# so the first collection after the error moved or reclaimed the offending value and the keyword read the old
# ground: a garbage record at stress 5, a SIGSEGV at the SHIPPED arena once a program allocates enough to collect.
# The cure is one visit in core_gc_roots, beside the definition.  It is the Icon twin of hq_snobol4's &ERRTEXT
# root (test_gate_gc_the_errtext_keyword_value_survives_a_collection.sh): the class is a heap value held in a C
# global no root walk names.
#
# ⛔ WHY THE WITNESS KEEPS THE LIST LIVE.  With the program's own reference dropped, iconx 9.5.25a ITSELF answers
# garbage (measured: list_17356(3) 3 17355 -- its &errorvalue is not marked either, and the block is reused), so
# no ref can be cut from the oracle for that shape.  Kept live, iconx collects and answers identically every run,
# and an unrooted cell in SCRIP still reads moved-from ground, because our collector moves the list.
#
# ARMS: (o) the committed ref equals the live oracle; (a) the witness answers the ref in m3 and m4 at the shipped
# arena and across a stress band at a 128 KB arena; (b) core_gc_roots visits g_icn_errvalue.
set -u
cd "$(dirname "$0")/../../SCRIP" || exit 2
G=gc_the_icon_errorvalue_keyword_survives_a_collection
refuse(){ echo "⛔ GATE REFUSES(2) [$G]: $*"; exit 2; }
[ -x ./scrip ] || refuse "no ./scrip binary -- run make"
LIBDIR="$(pwd)/out"
[ -f "$LIBDIR/libscrip_rt.so" ] || refuse "no out/libscrip_rt.so -- the m4 arms could not be built"
. ../harness/scripts/lib_oracle_flags.sh 2>/dev/null || refuse "../harness/scripts/lib_oracle_flags.sh did not load -- the oracle is reached by accessor, never by a PATH probe"
ICON="$(icon_bin)" || refuse "the Icon oracle is not reachable by its accessor"
W=hb_icn_errorvalue_keyword
WIT=../harness/scripts/gc_witnesses
[ -f "$WIT/$W.icn" ] && [ -f "$WIT/$W.ref" ] || refuse "witness $WIT/$W.icn or its .ref is missing"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
cp "$WIT/$W.icn" "$T/"
( cd "$T" && "$ICON" "$W.icn" < /dev/null > "$W.live" 2>&1 ) || refuse "the oracle did not run $W cleanly"
[ -s "$T/$W.live" ] || refuse "the oracle's answer is EMPTY; an empty expectation makes every arm pass"
( cd "$T" && timeout -k 5 60s "$OLDPWD/scrip" --compile "$W.icn" < /dev/null > "$W.s" 2> /dev/null \
    && gcc -c "$W.s" -o "$W.o" 2> "$W.ld.log" && gcc "$W.o" -L"$LIBDIR" -lscrip_rt -lm -lpthread -Wl,-rpath,"$LIBDIR" -o "$W.x4" 2>> "$W.ld.log" ) \
    || refuse "mode-4 compile or link failed, so every m4 arm measured nothing ($(head -c 160 "$T/$W.ld.log" 2>/dev/null))"
WANT="$(cat "$WIT/$W.ref")"
PTS="0 1 2 3 4 5 8 16"
echo "=== gate: the Icon &errorvalue keyword survives a collection ==="
ok=0; no=0
ck(){ if [ "$1" = ok ]; then ok=$((ok+1)); echo "  ok   $2"; else no=$((no+1)); echo "  no   $2"; fi; }
if cmp -s "$T/$W.live" "$WIT/$W.ref"; then ck ok "(o) the committed ref equals the live oracle ($ICON)"
else ck no "(o) the committed ref has DRIFTED from the oracle: committed [$(tr '\n' '|' < "$WIT/$W.ref")] live [$(tr '\n' '|' < "$T/$W.live")]"; fi
arms=0; reds=""
run(){ local m="$1" lbl="$2" got rc; shift 2
  if [ "$m" = m3 ]; then got="$(cd "$T" && env -u SCRIP_HEAP_MB -u SCRIP_HEAP_KB "$@" timeout -k 5 60s "$OLDPWD/scrip" "$W.icn" < /dev/null 2>&1)"; rc=$?
  else got="$(cd "$T" && env -u SCRIP_HEAP_MB -u SCRIP_HEAP_KB "$@" timeout -k 5 60s "./$W.x4" < /dev/null 2>&1)"; rc=$?; fi
  arms=$((arms+1))
  if [ "$rc" = 0 ] && [ "$got" = "$WANT" ]; then return 0; fi
  reds="$reds $m/$lbl(rc=$rc:$(printf '%s' "$got" | head -1 | cut -c1-60))"; }
for m in m3 m4; do
  run "$m" shipped
  for N in $PTS; do run "$m" "kb128-s$N" SCRIP_HEAP_KB=128 SCRIP_HEAP_MAX_MB=512 SCRIP_GC_STRESS="$N"; done
done
if [ -z "$reds" ]; then ck ok "(a) the witness answers the oracle at all $arms arms (m3 and m4; the shipped arena and a 128 KB arena at stress $PTS)"
else ck no "(a) RED arms:$reds"; fi
if awk '/^void core_gc_roots/,/^}/' src/runtime/core/core.c | grep -q 'rt_gc_visit_descr(&g_icn_errvalue)'; then ck ok "(b) core_gc_roots visits g_icn_errvalue"
else ck no "(b) NO ROOT WALK VISITS g_icn_errvalue in core_gc_roots; arm (a)'s green, if green, is a lottery over where a collection lands"; fi
if [ "$no" = 0 ]; then echo "✅ GATE PASS [$G]: $ok check(s), $arms arms"; exit 0; fi
echo "⛔ GATE FAIL(1) [$G]: $no check(s) red"; exit 1
