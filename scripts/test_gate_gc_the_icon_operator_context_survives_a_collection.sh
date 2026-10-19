#!/usr/bin/env bash
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
# test_gate_gc_the_icon_operator_context_survives_a_collection.sh
#   cfo 2026-09-26, row gc-core-gc-roots-visits-g-icn-op-s-two-descrs-at-core-c-397-the-last-open-holder-of-the-
#   conservative-auditor (ceo CEO-1289/1291). The conservative auditor's last OPEN holder, measured NOT latent.
#
# WHAT IT GATES.  g_icn_op (core.c) is the Icon operator context a traceback prints: core_icn_op_ctx stores the
# operator and its two operand DESCRs, core_icn_traceback prints them.  No root walk visited them.  icn_field_get and
# rt_field_var_strict (pattern_match.c) set it under &error and return failure without clearing it, so the context of
# a CONVERTED error survives into later code, and the next uncaught error prints it.  Any collection in between moved
# the operand and the traceback read its old ground: on 5d878bfbd, with NO environment at all, the natural witness
# died SIGSEGV in m3 (5 of 5) and printed "{record record_6309217648(0) . field}" in m4 (3 of 3, garbage varying
# per run); under SCRIP_GC_PLANT_FLIP=1 [ZGC-STALE] named "the holder of this pointer was NEVER VISITED".  The cure is
# the CTO-173 errorvalue precedent: two rt_gc_visit_descr calls in core_gc_roots, beside g_icn_errvalue.  A root
# visit, never a pin (ARCH-GC-COMPILE-TIME-FRAME-MAPS.md section 7).
#
# THE PLANT IS GONE (CEO-1680, Lon 2026-10-11: no switch in SCRIP's src/ exists only so a test can fail).  Until
# 2026-10-18 SCRIP_GC_PLANT_ICN_OP held the context past its operation (level 1) and also skipped the two visits
# (level 2), and two arms graded it: (b) the held operand read correctly under HOLD, (c) HOLD+UNROOT failed under the
# flip plant.  Both went with the seam.  THE CARRIER IS ALSO GONE: hq_icon's row cured the converted error's leak, so
# no program found holds the context across a collection -- the natural witness now prints iconx's {1 to 3 by 0}, and
# a converting operator (123456789 || L) sets and reads its context inside one runtime call, with no poll between.
# So (a) grades the natural witness's ANSWER through every collection regime and (d) holds the visit in the source;
# a program that holds the context across a collection again re-arms a dynamic arm.
#
# ARMS.  References are the witnesses' own ZERO-COLLECTION answers (64 MB window, stress 0, collections=0 checked),
# because SCRIP's error format is not iconx's.  A run PASSES when rc=1 (Icon's error exit), its output minus the
# flip plant's banner equals the reference, and no [ZGC-STALE] line appears.
#   (o)  the held-into-a-builtin witness ends its traceback with the live oracle's last line
#   (z)  the natural witness's reference: collections=0 at 64 MB
#   (a)  the natural witness, m3 and m4: the shipped defaults (the arm that crashed), the flip plant at the shipped
#        window, and a 128 KB window at stress 64 with and without the flip plant
#   (d)  core_gc_roots visits g_icn_op.a and g_icn_op.b
#   (e)  REPORTED: whether the natural carrier still exists
# FAIL-ONCE, A PROPER TEST: this gate run against a worktree of SCRIP 4b9cddb69^ (the visits' cure's parent, where
# core_gc_roots does not visit g_icn_op and the converted error's context still leaked) with this harness beside it
# reads (a) RED -- the natural witness dies rc 139 at the shipped defaults and under the flip plant in m3 -- and (d)
# RED; measured in the landing that deleted the plant and quoted in its commit.
set -u
cd "$(dirname "$0")/../../SCRIP" || exit 2
G=gc_the_icon_operator_context_survives_a_collection
refuse(){ echo "⛔ GATE REFUSES(2) [$G]: $*"; exit 2; }
[ -x ./scrip ] || refuse "no ./scrip binary -- run make"
LIBDIR="$(pwd)/out"
[ -f "$LIBDIR/libscrip_rt.so" ] || refuse "no out/libscrip_rt.so -- the m4 arms could not be built"
. ../harness/scripts/lib_oracle_flags.sh 2>/dev/null || refuse "../harness/scripts/lib_oracle_flags.sh did not load -- the oracle is reached by accessor, never by a PATH probe"
ICON="$(icon_bin)" || refuse "the Icon oracle is not reachable by its accessor"
WIT=../harness/scripts/gc_witnesses
WN=hb_icn_op_context_after_a_converted_error
WP=hb_icn_op_context_held_into_a_builtin_traceback
for w in $WN $WP; do [ -f "$WIT/$w.icn" ] || refuse "witness $WIT/$w.icn is missing"; done
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
for w in $WN $WP; do
  cp "$WIT/$w.icn" "$T/"
  ( cd "$T" && timeout -k 5 60s "$OLDPWD/scrip" --compile "$w.icn" < /dev/null > "$w.s" 2> /dev/null \
      && gcc -c "$w.s" -o "$w.o" 2> "$w.ld.log" && gcc "$w.o" -L"$LIBDIR" -lscrip_rt -lm -lpthread -Wl,-rpath,"$LIBDIR" -o "$w.x4" 2>> "$w.ld.log" ) \
      || refuse "mode-4 compile or link of $w failed, so every m4 arm would measure nothing ($(head -c 160 "$T/$w.ld.log" 2>/dev/null))"
done
SCRIP="$(pwd)/scrip"
raw(){ local m="$1" w="$2"; shift 2
  if [ "$m" = m3 ]; then ( cd "$T" && env -u SCRIP_HEAP_MB -u SCRIP_HEAP_KB -u SCRIP_GC_STRESS -u SCRIP_GC_PLANT_FLIP \
        "$@" timeout -k 5 60s "$SCRIP" "$w.icn" < /dev/null 2>&1 ) 2> /dev/null
  else ( cd "$T" && env -u SCRIP_HEAP_MB -u SCRIP_HEAP_KB -u SCRIP_GC_STRESS -u SCRIP_GC_PLANT_FLIP \
        "$@" timeout -k 5 60s "./$w.x4" < /dev/null 2>&1 ) 2> /dev/null; fi; }
body(){ printf '%s\n' "$1" | grep -v '^\[GC-FLIP\] plant:\|^\[GC-EXERCISE\]'; }
ok=0; no=0
ck(){ if [ "$1" = ok ]; then ok=$((ok+1)); echo "  ok   $2"; else no=$((no+1)); echo "  no   $2"; fi; }
echo "=== gate: the Icon operator context survives a collection ==="
ZERO="SCRIP_HEAP_KB=65536 SCRIP_GC_STRESS=0"
zn_raw="$(raw m3 $WN $ZERO SCRIP_GC_EXERCISE=1)"; zn_rc=$?
zn_col="$(printf '%s\n' "$zn_raw" | grep -o 'collections=[0-9]*' | tail -1)"
[ "$zn_col" = collections=0 ] || refuse "the zero-collection reference collected ($zn_col) -- a reference cut through a collection is not independent of the collector"
[ "$zn_rc" = 1 ] || refuse "the zero-collection reference did not take Icon's error exit (rc $zn_rc)"
ZN="$(body "$zn_raw")"
ck ok "(z) reference cut at collections=0: the natural witness ends [$(printf '%s\n' "$ZN" | tail -1 | sed 's/^ *//')]"
want_o="$(cd "$T" && "$ICON" "$WP.icn" < /dev/null 2>&1 | tail -1)"
[ -n "$want_o" ] || refuse "the oracle printed nothing for $WP -- an empty expectation makes the anchor pass"
got_o="$(body "$(raw m3 $WP)")"
if printf '%s\n' "$got_o" | grep -qF "$want_o"; then ck ok "(o) the held-into-a-builtin witness ends its traceback with the oracle's line [$want_o]"
else ck no "(o) the held-into-a-builtin witness does NOT carry the oracle's line [$want_o]; it ends [$(printf '%s\n' "$got_o" | tail -1)]"; fi
pass(){ local out="$1" rc="$2" ref="$3"
  [ "$rc" = 1 ] || return 1; printf '%s\n' "$out" | grep -q 'ZGC-STALE' && return 1; [ "$(body "$out")" = "$ref" ] || return 1; return 0; }
ARMS="ship| flip-ship|SCRIP_GC_PLANT_FLIP=1 kb128-s64|SCRIP_HEAP_KB=128|SCRIP_GC_STRESS=64 kb128-s64-flip|SCRIP_HEAP_KB=128|SCRIP_GC_STRESS=64|SCRIP_GC_PLANT_FLIP=1"
grade(){ local w="$1" ref="$2" reds="" n=0 m a lbl envs out rc
  for m in m3 m4; do for a in $ARMS; do lbl="${a%%|*}"; envs="$(printf '%s' "${a#*|}" | tr '|' ' ')"
    out="$(raw $m $w $envs)"; rc=$?; n=$((n+1))
    case "$envs" in *SCRIP_GC_PLANT_FLIP=1*) printf '%s\n' "$out" | grep -q '^\[GC-FLIP\] plant:' || { reds="$reds $m/$lbl(no [GC-FLIP] banner: the flip never applied)"; continue; };; esac
    pass "$out" "$rc" "$ref" || reds="$reds $m/$lbl(rc=$rc:$(body "$out" | tail -1 | sed 's/^ *//' | cut -c1-60))"
  done; done
  printf '%s|%s' "$n" "$reds"; }
r="$(grade $WN "$ZN")"; n="${r%%|*}"; reds="${r#*|}"
if [ -z "$reds" ]; then ck ok "(a) the natural witness answers its zero-collection reference at all $n arms (m3 and m4: shipped defaults, flip plant at the shipped window, 128 KB stress 64 with and without flip)"
else ck no "(a) RED arms:$reds"; fi
roots="$(awk '/^void core_gc_roots/,/^}/' src/runtime/core/core.c)"
if printf '%s\n' "$roots" | grep -q 'rt_gc_visit_descr(&g_icn_op\.a)' && printf '%s\n' "$roots" | grep -q 'rt_gc_visit_descr(&g_icn_op\.b)'; then ck ok "(d) core_gc_roots visits g_icn_op.a and g_icn_op.b"
else ck no "(d) core_gc_roots does not visit both g_icn_op operands; (a), if green, is a lottery over where a collection lands"; fi
if printf '%s\n' "$ZN" | grep -q ' \. field} from line'; then echo "     (e) REPORTED: the natural carrier still exists -- a converted field error leaves its context set, so (a) exercised the holder without a plant"
else echo "     (e) REPORTED: the natural carrier is gone (the stale-context leak was cured) -- (a) grades the answer and (d) the visit"; fi
if [ "$no" = 0 ]; then echo "✅ GATE PASS [$G]: $ok check(s)"; exit 0; fi
echo "⛔ GATE FAIL(1) [$G]: $no check(s) red"; exit 1
