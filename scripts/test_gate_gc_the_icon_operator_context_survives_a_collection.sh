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
# ⛔ WHY A PLANT AND NOT ONLY THE FOUND WITNESS (CEO-554, CEO-576).  The natural carrier is an Icon traceback defect
# in its own right -- iconx names {1 to 3 by 0} where we name the stale field operation -- and hq_icon holds that row.
# The day it is cured the natural witness stops holding a context across a collection and every arm built on it
# goes quietly untrippable.  So the holder is also reached through a seam that does not depend on any site's clear:
#   SCRIP_GC_PLANT_ICN_OP=1  HOLD        core_icn_op_ctx_clear and core_icn_bi_push leave the context set
#   SCRIP_GC_PLANT_ICN_OP=2  HOLD+UNROOT core_gc_roots also skips the two visits: the pre-cure defect, on purpose
# The seam prints "[GC-ICNOP] plant:" once per process, and that line is the only proof it applied.  INERT, measured
# at landing in the CEO-554 order: the build WITHOUT the seam was captured first (all 75 gc_witnesses programs, the
# shipped arena and 128 KB at stress 3, rc + stdout md5 + stderr md5 + collections, 437,866 collections in all), then
# the seam build with the variable unset: 0 of 150 runs differed on any column, and the capture itself was
# deterministic run to run on one build.
#
# ARMS.  References are the witnesses' own ZERO-COLLECTION answers (64 MB window, stress 0, collections=0 checked),
# because SCRIP's error format is not iconx's; the plant witness's unplanted answer is additionally anchored on the
# live oracle's traceback line.  A run PASSES when rc=1 (Icon's error exit), its output minus the plants' banner
# lines equals the reference, and no [ZGC-STALE] line appears.
#   (o)  the plant witness, unplanted, ends its traceback with the live oracle's last line
#   (z)  the references: collections=0 at 64 MB; the plant witness under HOLD prints the held field context (else this
#        gate REFUSES -- the carrier is gone, re-anchor it; that is a countdown named, not hidden)
#   (a)  the natural witness, unplanted, m3 and m4: the shipped defaults (the arm that crashed), the flip plant at the
#        shipped window, and a 128 KB window at stress 64 with and without the flip plant
#   (b)  the plant witness under HOLD, the same four arms in both modes: the visit keeps a held operand valid
#   (c)  FAIL-ONCE, the negation of (b)'s own predicate: under HOLD+UNROOT the flip plant at the shipped window must
#        FAIL it in both modes (measured: m3 SIGSEGV 10 of 10 with ASLR on and off, m4 a garbage record 10 of 10); and
#        at the zero-collection window HOLD+UNROOT must PASS it, so the failure is the missing visit and not the HOLD
#   (d)  core_gc_roots visits g_icn_op.a and g_icn_op.b
#   (e)  REPORTED: whether the natural carrier still exists (the stale-context leak hq_icon's row cures)
# ⛔ STRESS 1 IS NOT AN ARM HERE: 200,001 collections, 15-23 s a run at load 27; the flip plant at the shipped window
# moves every live block at each of its ~78 collections in ~0.3 s and discriminates in both modes.  At 128 KB stress 64
# the HOLD+UNROOT read can land on ground the operand occupies again (m3 read it correctly), so it is graded only
# for the cure, never as the fail-once.
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
raw(){ local m="$1" w="$2" lv="$3"; shift 3
  if [ "$m" = m3 ]; then ( cd "$T" && env -u SCRIP_HEAP_MB -u SCRIP_HEAP_KB -u SCRIP_GC_STRESS -u SCRIP_GC_PLANT_FLIP -u SCRIP_GC_PLANT_ICN_OP \
        ${lv:+SCRIP_GC_PLANT_ICN_OP=$lv} "$@" timeout -k 5 60s "$SCRIP" "$w.icn" < /dev/null 2>&1 ) 2> /dev/null
  else ( cd "$T" && env -u SCRIP_HEAP_MB -u SCRIP_HEAP_KB -u SCRIP_GC_STRESS -u SCRIP_GC_PLANT_FLIP -u SCRIP_GC_PLANT_ICN_OP \
        ${lv:+SCRIP_GC_PLANT_ICN_OP=$lv} "$@" timeout -k 5 60s "./$w.x4" < /dev/null 2>&1 ) 2> /dev/null; fi; }
body(){ printf '%s\n' "$1" | grep -v '^\[GC-FLIP\] plant:\|^\[GC-ICNOP\] plant:\|^\[GC-EXERCISE\]'; }
ok=0; no=0
ck(){ if [ "$1" = ok ]; then ok=$((ok+1)); echo "  ok   $2"; else no=$((no+1)); echo "  no   $2"; fi; }
echo "=== gate: the Icon operator context survives a collection ==="
ZERO="SCRIP_HEAP_KB=65536 SCRIP_GC_STRESS=0"
zn_raw="$(raw m3 $WN "" $ZERO SCRIP_GC_EXERCISE=1)"; zn_rc=$?
zp_raw="$(raw m3 $WP 1 $ZERO SCRIP_GC_EXERCISE=1)"; zp_rc=$?
zn_col="$(printf '%s\n' "$zn_raw" | grep -o 'collections=[0-9]*' | tail -1)"; zp_col="$(printf '%s\n' "$zp_raw" | grep -o 'collections=[0-9]*' | tail -1)"
[ "$zn_col" = collections=0 ] && [ "$zp_col" = collections=0 ] || refuse "the zero-collection references collected ($zn_col / $zp_col) -- a reference cut through a collection is not independent of the collector"
[ "$zn_rc" = 1 ] && [ "$zp_rc" = 1 ] || refuse "the zero-collection references did not take Icon's error exit (rc $zn_rc / $zp_rc)"
printf '%s\n' "$zp_raw" | grep -q '^\[GC-ICNOP\] plant: level 1' || refuse "the HOLD plant's banner is missing from its reference run -- the seam never applied"
ZN="$(body "$zn_raw")"; ZP="$(body "$zp_raw")"
printf '%s\n' "$ZP" | grep -q ' \. field} from line' \
  || refuse "the plant witness under HOLD no longer prints a held field context [$(printf '%s\n' "$ZP" | tail -1)] -- the carrier this gate stands on is gone; re-anchor the witness on an operator context that is set under &error, then read by a builtin's traceback"
ck ok "(z) references cut at collections=0: natural ends [$(printf '%s\n' "$ZN" | tail -1 | sed 's/^ *//')], HOLD ends [$(printf '%s\n' "$ZP" | tail -1 | sed 's/^ *//')]"
want_o="$(cd "$T" && "$ICON" "$WP.icn" < /dev/null 2>&1 | tail -1)"
[ -n "$want_o" ] || refuse "the oracle printed nothing for $WP -- an empty expectation makes the anchor pass"
got_o="$(body "$(raw m3 $WP "")")"
if printf '%s\n' "$got_o" | grep -qF "$want_o"; then ck ok "(o) the plant witness, unplanted, ends its traceback with the oracle's line [$want_o]"
else ck no "(o) the plant witness, unplanted, does NOT carry the oracle's line [$want_o]; it ends [$(printf '%s\n' "$got_o" | tail -1)]"; fi
pass(){ local out="$1" rc="$2" ref="$3"
  [ "$rc" = 1 ] || return 1; printf '%s\n' "$out" | grep -q 'ZGC-STALE' && return 1; [ "$(body "$out")" = "$ref" ] || return 1; return 0; }
ARMS="ship| flip-ship|SCRIP_GC_PLANT_FLIP=1 kb128-s64|SCRIP_HEAP_KB=128|SCRIP_GC_STRESS=64 kb128-s64-flip|SCRIP_HEAP_KB=128|SCRIP_GC_STRESS=64|SCRIP_GC_PLANT_FLIP=1"
grade(){ local w="$1" lv="$2" ref="$3" need_banner="$4" reds="" n=0 m a lbl envs out rc
  for m in m3 m4; do for a in $ARMS; do lbl="${a%%|*}"; envs="$(printf '%s' "${a#*|}" | tr '|' ' ')"
    out="$(raw $m $w "$lv" $envs)"; rc=$?; n=$((n+1))
    if [ "$need_banner" = 1 ] && ! printf '%s\n' "$out" | grep -q '^\[GC-ICNOP\] plant:'; then reds="$reds $m/$lbl(no plant banner)"; continue; fi
    case "$envs" in *SCRIP_GC_PLANT_FLIP=1*) printf '%s\n' "$out" | grep -q '^\[GC-FLIP\] plant:' || { reds="$reds $m/$lbl(no [GC-FLIP] banner: the flip never applied)"; continue; };; esac
    pass "$out" "$rc" "$ref" || reds="$reds $m/$lbl(rc=$rc:$(body "$out" | tail -1 | sed 's/^ *//' | cut -c1-60))"
  done; done
  printf '%s|%s' "$n" "$reds"; }
r="$(grade $WN "" "$ZN" 0)"; n="${r%%|*}"; reds="${r#*|}"
if [ -z "$reds" ]; then ck ok "(a) the natural witness answers its zero-collection reference at all $n arms (m3 and m4: shipped defaults, flip plant at the shipped window, 128 KB stress 64 with and without flip)"
else ck no "(a) RED arms:$reds"; fi
r="$(grade $WP 1 "$ZP" 1)"; n="${r%%|*}"; reds="${r#*|}"
if [ -z "$reds" ]; then ck ok "(b) under HOLD (SCRIP_GC_PLANT_ICN_OP=1) the held operand reads correctly at all $n arms -- the visit keeps it valid across every collection"
else ck no "(b) RED arms under HOLD:$reds"; fi
fo=""; fc=0
for m in m3 m4; do out="$(raw $m $WP 2 SCRIP_GC_PLANT_FLIP=1)"; rc=$?
  printf '%s\n' "$out" | grep -q '^\[GC-ICNOP\] plant: level 2' || refuse "the HOLD+UNROOT banner is missing from the $m fail-once run -- the plant never applied, so (c) would grade nothing"
  printf '%s\n' "$out" | grep -q '^\[GC-FLIP\] plant:' || refuse "the [GC-FLIP] banner is missing from the $m fail-once run -- no block moved to disjoint ground, so (c) would grade an unplanted run"
  if pass "$out" "$rc" "$ZP"; then fo="$fo $m(PASSED -- the missing visit went unseen)"; else fc=$((fc+1)); fo="$fo $m(rc=$rc,stale=$(printf '%s\n' "$out" | grep -c 'ZGC-STALE'),$(body "$out" | tail -1 | sed 's/^ *//' | cut -c1-44))"; fi
done
out="$(raw m3 $WP 2 $ZERO)"; rc=$?
if [ "$fc" = 2 ] && pass "$out" "$rc" "$ZP"; then ck ok "(c) FAIL-ONCE: with the visits skipped (SCRIP_GC_PLANT_ICN_OP=2) the flip plant fails (b)'s predicate in both modes:$fo -- and the same plant at the zero-collection window passes it, so the failure is the missing visit"
else ck no "(c) the fail-once did not hold: flip arms$fo; zero-collection control rc=$rc -- a gate that cannot see the missing visit grades nothing"; fi
roots="$(awk '/^void core_gc_roots/,/^}/' src/runtime/core/core.c)"
if printf '%s\n' "$roots" | grep -q 'rt_gc_visit_descr(&g_icn_op\.a)' && printf '%s\n' "$roots" | grep -q 'rt_gc_visit_descr(&g_icn_op\.b)'; then ck ok "(d) core_gc_roots visits g_icn_op.a and g_icn_op.b"
else ck no "(d) core_gc_roots does not visit both g_icn_op operands; (a) and (b), if green, are a lottery over where a collection lands"; fi
if printf '%s\n' "$ZN" | grep -q ' \. field} from line'; then echo "     (e) REPORTED: the natural carrier still exists -- a converted field error leaves its context set, so (a) exercised the holder without a plant"
else echo "     (e) REPORTED: the natural carrier is gone (the stale-context leak was cured) -- (a) now grades only the answer, and (b)/(c) carry the holder"; fi
if [ "$no" = 0 ]; then echo "✅ GATE PASS [$G]: $ok check(s)"; exit 0; fi
echo "⛔ GATE FAIL(1) [$G]: $no check(s) red"; exit 1
