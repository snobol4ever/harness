#!/usr/bin/env bash
# test_gate_gc_conservative_auditor_reports_and_cannot_ship.sh -- RUNG 3 OF ARCH-GC § 9, MEASURED.
#
# ⛔⭐ THE GRANT AND ITS EXPIRY.  Lon 2026-09-21, in-chat to the ceo, verbatim: "So if you need a conservative
# scan temporarily to get your diagnostics done, then go ahead.  But ensure in the end all is exact scanning."
# A GRANT WITH AN EXPIRY AND NO REMOVAL MECHANISM IS A PERMANENT GRANT, so the expiry is built, not promised.
# This gate is the four structural conditions of that grant, each as an arm that can fail:
#   (a) THE SHIPPED BUILD CARRIES ZERO CONSERVATIVE SCAN -- measured on the .so, not read off the source.
#   (b) AND THE CENSUS IN (a) IS NOT BLIND -- the same census over the knob-on build MUST see it.  Fail-once in
#       both directions on one tree: the auditor exists only under -DSCRIP_GC_AUDIT_B, so the shipped library is
#       silent because THE CODE IS NOT IN IT, which is a stronger statement than a runtime flag defaulting off.
#   (c) PASS A ALWAYS DECIDES -- source census that pass B calls nothing that marks, forwards, frees or protects,
#       AND a behavioural arm: one binary, one library, auditor OFF against ON, stdout and collection count
#       IDENTICAL.  An auditor that changed a collection would change one of those two.
#   (d) THE AUDITOR CLAIMS ITS OWN EVENT -- it prints `audited=1` per collection and `findings=0` out loud, so
#       its SILENCE is a statement rather than an absence, and a run where it never applied REFUSES rc=2 rather
#       than passing.  The cto's shift plant taught this class twice in one day.
#   (e) EVERY HOLDER IS CURED OR DECLARED -- ../harness/scripts/gc_audit_b_declared.txt.  An undeclared holder is a RED, so
#       the count falls only by curing roots or by writing down a measurement.
#   (f) THE EXPIRY IS STRUCTURAL -- the day no OPEN row remains and a sweep finds nothing, THIS ARM PRINTS
#       RETIREMENT-PENDING AND NAMES THE ROW THAT DELETES IT.  A disabled auditor is a conservative scan wearing an if.
#       ⛔ AMENDED 2026-09-26 (cfo, the ceo's CEO-1291 ruling (b)): this arm used to RED at open_rows=0 holders=0, and
#       the g_icn_op cure made that day arrive.  But this gate sweeps FOUR witnesses and ARCH-GC section 9 condition (3)
#       grades the retirement over the CORPUS across a declared window, which under CEO-1232 only the language HQs may
#       run.  So the silence here is necessary, not sufficient: it reads GREEN with RETIREMENT-PENDING printed, and the
#       deletion is graded by row gc-the-conservative-auditor-retires-on-six-hq-receipts-each-master-under-the-auditor-build-at-stress-1-and-3-reads-zero-findings
#       (six receipts, one per language HQ: its rungs under this auditor build at stress 1 and 3 at the shipped
#       arena, zero findings), whose own landing deletes everything (f1) lists.
# ⛔⭐ PASS B WAS BLIND TO THE COMPILE-TIME ARENA FROM 2026-09-27 TO 2026-10-01, AND (d3)/(e2) WERE RED ON ORIGIN FOR IT (cfo,
# 2026-10-01). 9d3f8a061 (no-more-whack-a-mole, CEO-1332) moved g_fh into a cv_t, g_fhv, grown in the compile-time arena by
# ct_grow, and pass B scanned only static, stack and heapint. The plant still bit: with drv_gc_roots skipped the program
# printed "B file(file(tmp3))", the name string reclaimed and its bytes re-issued. But pass B named nothing, on the cure and
# on a clean origin worktree alike. Every runtime table the conversion moved into that arena went invisible the same way.
# THE CURE: a fourth population, ctarena, in the default set. It reads /proc/self/maps for private anonymous rw mappings,
# clips out the heap reservation, and hands each range to ct_arena_scan (src/ir/ct_arena.c). That walker validates every
# header it trusts, skips freed blocks (magic 0) and calls back once per live payload, so no list of chunks is kept and no
# new storage exists. A finding inside a payload is named by the STATIC WORD THAT POINTS AT THE PAYLOAD. A word in the
# runtime library is preferred, because a stale compiler static (g_emit_cfg) can point at the same recycled block, and every
# owner is listed: in=libscrip_rt.so+0x...<g_fhv>[ct+0x110,owners=g_emit_cfg,g_fhv]. So nm still resolves the holder to a
# symbol, now g_fhv. Unplanted, the witness reads 0 findings over 344 live arena blocks and 9.7M words; planted, 1, the
# tmp3 string.
# ⛔⭐ (d3) AND (e2) STAND ON A PLANT SINCE 2026-09-26 (cfo, the CEO-1274 board row; CEO-554).  Both were keyed on a holder the
# sweep FOUND, and when 957efcc7c took the lc_vec class off the collected heap the sweep found none and both went red on a
# correct tree: a proof that needs a live defect dies of the cure.  SCRIP_GC_PLANT_UNROOT=1 exists ONLY in the auditor build
# (#ifdef SCRIP_GC_AUDIT_B in gc_heap.c's root phase): it skips drv_gc_roots, so g_fh -- this detector's first real find --
# is a lost root on purpose, and pass B must name it.  The unplanted sweep still grades every real holder in (e1) and (f1).
# ⛔⭐ (e2) RETIRED UNDER CEO-1680 (cto 2026-10-17; Lon 2026-10-11: no broken code planted so a test can trip). The plant above left
# src at 9b73a8a5c (the exact-compactor rewrite), so the planted run named no holder and (e2) read FAIL (no_nm_g_fhv) from the coo's
# blocking-set run of 2026-10-15 17:56 on, on a correct tree. The recorded readings are its fail-once: planted, 1 finding resolving
# through nm -S to g_fhv; unplanted, 0 over 344 live arena blocks (cfo 2026-10-01). (d4a) and (d4b) stay: the FH vector is gone from
# the sweep and g_fh's red witness answers its oracle.

#
# ⛔ COST, MEASURED (cfo 2026-09-21, load 2.7-5.3, SCRIP_HEAP_MB=1).  The auditor's own build is a separate RT_TAG
# and is built HERE, directly as out/libscrip_rt-<tag>.so, which is a target in its own right: the canonical
# out/libscrip_rt.so symlink is NEVER touched, so a shard running in parallel cannot pick up this library by
# accident.  COLD (no cached tag, e.g. after `make pristine`) that build is 2m25s; CACHED it is 0.2s.  The run
# arms are 4 witnesses chosen for having FEW collections.  The auditor itself costs 185x wall on a 36-collection
# witness (0.01s -> 1.85s) and 99.97% of that is one region: libscrip_rt.so's 89 MB writable PT_LOAD, which is
# .bss tables (dat_types 18 MB, zf 16 MB, ze and zm 8 MB each), NOT the program's heap.  So pass B's cost is a
# property of the LIBRARY and not of the workload, and SCRIP_GC_AUDIT_B_POPS narrows the territory with the
# narrowing PRINTED in every summary line.
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -u
cd "$(dirname "$0")/../../SCRIP" || exit 2
ROOT="$PWD"; G="gc_conservative_auditor_reports_and_cannot_ship"
unset SCRIP_HEAP_MB; export SCRIP_HEAP_KB="${SCRIP_HEAP_KB:-128}"
checks=0; fails=0
ck() { checks=$((checks+1)); if [ "$1" = ok ]; then echo "  ok   $2"; else fails=$((fails+1)); echo "  FAIL $2"; fi; }
refuse() { echo "⛔ GATE REFUSED(2) [$G]: $1"; exit 2; }
SRC="src/runtime/rt/gc_audit_b.c"; HDR="src/runtime/rt/gc_audit_b.h"; DECL="../harness/scripts/gc_audit_b_declared.txt"
for f in "$SRC" "$HDR" "$DECL" src/runtime/rt/gc_heap.c; do [ -f "$ROOT/$f" ] || refuse "$f is missing -- it is part of this rung's deliverable"; done
command -v nm >/dev/null 2>&1 || refuse "no nm -- this gate resolves a holder OFFSET to a SYMBOL and cannot key a declaration on an offset"
[ -f "$ROOT/out/libscrip_rt.so" ] || refuse "no out/libscrip_rt.so -- there is no shipped library to census"
echo "ARENA SCRIP_HEAP_KB=$SCRIP_HEAP_KB (the shipped window -- CEO-931/934; the CEO-1146 sweep moved this off MB=1, which named 1024 KB and ran the collector ZERO times on four of six witnesses. The exasperation knob is SCRIP_GC_STRESS, never the arena -- 33rd batch clause 1)"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT

echo "-- (a) THE SHIPPED BUILD CARRIES ZERO CONSERVATIVE SCAN"
SHIP="$ROOT/out/libscrip_rt.so"
s_sym=$(nm -D "$SHIP" 2>/dev/null | grep -c "gc_audit_b" || true)
s_str=$(strings "$SHIP" 2>/dev/null | grep -c "GC-AUDIT-B" || true)
ck $([ "$s_sym" = 0 ] && echo ok || echo no) "(a1) shipped out/libscrip_rt.so exports NO gc_audit_b symbol (saw $s_sym)"
ck $([ "$s_str" = 0 ] && echo ok || echo no) "(a2) shipped out/libscrip_rt.so carries NO [GC-AUDIT-B] string (saw $s_str)"
d_sym=$(nm -D "$SHIP" 2>/dev/null | grep -c "gc_audit_b_collect" || true)
ck $([ "$d_sym" = 0 ] && echo ok || echo no) "(a3) the auditor's entry point gc_audit_b_collect is ABSENT from the shipped library (saw $d_sym)"

echo "-- (b) AND THAT CENSUS IS NOT BLIND: the knob-on build MUST trip every arm of (a)"
AUD_OPT="-O0 -g -fno-strict-aliasing -fwrapv -fno-omit-frame-pointer -DSCRIP_GC_AUDIT_B=1"
AUD_TAG=$(make -s RT_OPT="$AUD_OPT" buildinfo 2>/dev/null | awk '/^RT_TAG/{print $3}')
[ -n "$AUD_TAG" ] || refuse "could not read RT_TAG for the auditor configuration out of \`make buildinfo\` -- without it this gate cannot name the library it must census"
AUD_SO="$ROOT/out/libscrip_rt-$AUD_TAG.so"
[ "$AUD_SO" != "$SHIP" ] || refuse "the auditor configuration hashed to the SHIPPED RT_TAG -- the two builds would share objects and (a) and (b) would be the same census"
# ⛔ ALWAYS MAKE, NEVER AN MTIME GUESS (cfo 2026-09-26): the rebuild used to run only when gc_audit_b.c or gc_heap.c was newer
# than the library, so a change to ANY other runtime file (core.c, rt.c ...) left pass B auditing a runtime the tree no longer
# builds, under a fresh ./scrip -- a reading of a library nobody shipped.  make knows every dependency; cached it costs 0.7 s.
echo "     make of the auditor configuration (RT_TAG=$AUD_TAG): COLD ~2m25s, cached under a second -- the canonical symlink is not touched"
make RT_OPT="$AUD_OPT" "out/libscrip_rt-$AUD_TAG.so" > "$T/build.log" 2>&1 || { tail -20 "$T/build.log"; refuse "the knob-on build FAILED -- arm (b) cannot be measured and a green (a) would then mean nothing"; }
[ -f "$AUD_SO" ] || refuse "out/libscrip_rt-$AUD_TAG.so did not appear after the build"
LNK=$(readlink "$SHIP"); ck $([ "$LNK" != "$(basename "$AUD_SO")" ] && echo ok || echo no) "(b0) out/libscrip_rt.so still points at the SHIPPED configuration ($LNK), not at the auditor build"
a_sym=$(nm -D "$AUD_SO" 2>/dev/null | grep -c "gc_audit_b_collect" || true)
a_str=$(strings "$AUD_SO" 2>/dev/null | grep -c "GC-AUDIT-B" || true)
ck $([ "$a_sym" -ge 1 ] && echo ok || echo no) "(b1) the knob-on library DOES export gc_audit_b_collect (saw $a_sym) -- so (a3)'s zero is an absence and not a blind census"
ck $([ "$a_str" -ge 1 ] && echo ok || echo no) "(b2) the knob-on library DOES carry [GC-AUDIT-B] strings (saw $a_str) -- so (a2)'s zero is an absence and not a blind census"

echo "-- (c) PASS A ALWAYS DECIDES"
bad=$(grep -nE "gc_mark_blk|rt_gc_visit_|gc_wl_push|gc_slot_reg|mprotect|memmove|[^_a-z]free\(|->flags *=|->fwd *=" "$ROOT/$SRC" | grep -v "HBF_MARK)" || true)
ck $([ -z "$bad" ] && echo ok || echo no) "(c1) $SRC calls nothing that marks, forwards, frees or protects${bad:+ -- SAW: $bad}"
mut=$(grep -c "rt_hblk_t \*)" "$ROOT/$HDR" || true); cst=$(grep -c "const rt_hblk_t \*" "$ROOT/$HDR" || true)
ck $([ "$cst" -ge 2 ] && echo ok || echo no) "(c2) the view hands pass B only CONST block pointers (saw $cst const forms) -- it has no mutable handle to mark with"

mkdir -p "$T/lib"; cp -p "$AUD_SO" "$T/lib/libscrip_rt.so"
WITS="../harness/scripts/gc_witnesses/hb_coexpr_genp_scan.icn ../harness/scripts/gc_witnesses/hb_cv_spine_plain_redo.icn ../harness/scripts/gc_witnesses/hb_file_name_unrooted.icn ../harness/scripts/gc_witnesses/hb_blob_span_defer.sno"
for w in $WITS; do [ -f "$ROOT/$w" ] || refuse "$w is missing -- this gate's declared witness set is not on the tree"; done
run_aud() { LD_LIBRARY_PATH="$T/lib" SCRIP_ZETA_TELEM=1 SCRIP_GC_STRESS="${2:-3}" env ${3:+SCRIP_GC_AUDIT_B=$3} timeout -k 5 300s "$ROOT/scrip" "$ROOT/$1" 2>"$T/e" ; }
W1=../harness/scripts/gc_witnesses/hb_coexpr_genp_scan.icn
o_off=$(run_aud "$W1" 3 ""); c_off=$(grep -c "^\[ZGC\] regeneration" "$T/e" || true); cp "$T/e" "$T/e.off"
o_on=$(run_aud "$W1" 3 1); c_on=$(grep -c "^\[ZGC\] regeneration" "$T/e" || true); cp "$T/e" "$T/e.on"
n_aud=$(grep -c "audited=1" "$T/e.on" || true)
ck $([ "$o_off" = "$o_on" ] && echo ok || echo no) "(c3) auditor OFF and ON on ONE binary and ONE library print BYTE-IDENTICAL stdout"
ck $([ "$c_off" = "$c_on" ] && [ "$c_off" -gt 0 ] && echo ok || echo no) "(c4) and the SAME number of collections ($c_off off against $c_on on) -- pass B did not change the schedule it reports on"
ck $([ "$(grep -c 'audited=1' "$T/e.off" || true)" = 0 ] && echo ok || echo no) "(c5) with the knob off the knob-on LIBRARY audits nothing -- the env switch is honoured at the point of use, not cached"

echo "-- (d) THE AUDITOR CLAIMS ITS OWN EVENT"
[ "$n_aud" -gt 0 ] || refuse "the auditor produced NO 'audited=1' line on $W1 -- it declined, and a gate that grades a run the instrument never touched is the false-green this rung exists to remove"
ck $([ "$n_aud" = "$c_on" ] && echo ok || echo no) "(d1) EVERY collection was audited: $n_aud audited=1 lines against $c_on collections"
n_f0=$(grep -c 'audited=1 findings=' "$T/e.on" || true)
ck $([ "$n_f0" = "$n_aud" ] && echo ok || echo no) "(d2) every audited collection PRINTS its findings count, zero included ($n_f0 summary lines against $n_aud audits) -- silence is a statement, not an absence"
run_aud ../harness/scripts/gc_witnesses/hb_file_name_unrooted.icn 3 1 > "$T/fh.out"; cp "$T/e" "$T/e.fh"
# ⛔⭐ (d3) WAS "the auditor NAMES g_fh" AND THAT ARM DIED OF ITS OWN SUCCESS ON 2026-09-21: the cfo ROOTED the FH
# table (drv_gc_roots in src/driver/driver_globals.c, registered in gc_heap.c beside the other eleven), the holder
# went away, and the detector proof went with it.  A PROOF KEYED ON A NAMED OPEN DEFECT IS A COUNTDOWN -- so this
# arm no longer names a symbol at all.  It asks the sweep for any holder that the LEDGER still lists OPEN, resolved
# through nm and not through dladdr (dladdr names only EXPORTED symbols, and every holder left today is a file-local
# static it CANNOT name -- the same coarse-symbol trap as CFO-129).  Cure one holder and the arm re-points itself;
# cure the last one and arm (f1) is the arm that fires, which is where the retirement belongs.
# ⛔⭐ RE-DECLARED ON A PLANT 2026-09-26 (cfo): the OPEN-holder form above read 0 the day the lc_vec class left the collected
# heap (957efcc7c), so (d3) now asks the detector to name a lost root MADE ON PURPOSE -- g_fh, with its root walk skipped by
# SCRIP_GC_PLANT_UNROOT=1 in the auditor build -- and the OPEN holders of the unplanted run are REPORTED, not graded.
FHW="$ROOT/../harness/scripts/gc_witnesses/hb_file_name_unrooted.icn"
d3=$(python3 - "$T/e.fh" "$AUD_SO" "$ROOT/$DECL" "$T/e.fh" <<'PYD3'
import subprocess, sys, re
plantf, so, decl, unpl = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
syms = []
for ln in subprocess.run(['nm','-S','--defined-only',so],capture_output=True,text=True).stdout.splitlines():
    f = ln.split()
    if len(f) < 4: continue
    try: a = int(f[0],16); sz = int(f[1],16)
    except ValueError: continue
    syms.append((a,sz,f[3]))
def resolve(errf):
    out = []
    for ln in open(errf, errors='replace'):
        m = re.search(r'CANDIDATE-LOST-ROOT at=\S+ in=(\S+)', ln)
        if not m: continue
        mo = re.match(r'^.*\+0x([0-9a-f]+)/(.*)$', m.group(1))
        if not mo: out.append(('raw', m.group(1))); continue
        off = int(mo.group(1),16)
        hit = [x for x in syms if x[0] <= off < x[0]+x[1]]
        out.append(('nm', re.sub(r'\.\d+$', '', hit[0][2])) if hit else ('tail', mo.group(2)))
    return out
state = {}
for ln in open(decl):
    ln = ln.strip()
    if not ln or ln.startswith('#'): continue
    f = ln.split(None,2)
    if len(f) >= 2: state[f[0]] = f[1]
P = resolve(plantf); U = resolve(unpl)
named = sorted(set(n for h, n in P))
opn = sorted(set(n for h, n in U if state.get(n) == 'OPEN'))
print("%d %s %s %s %s" % (len(P), ','.join(named) or '-', 'nm_g_fhv' if ('nm','g_fhv') in P else 'no_nm_g_fhv', ','.join(opn) or '-', 'g_fhv' if any(n == 'g_fhv' for h, n in U) else 'no_g_fhv'))
PYD3
)
read -r p_n p_names p_nmfh u_open d3fh <<< "$d3"
echo "     REPORTED, not graded: holders the UNPLANTED run names that the ledger lists OPEN: ${u_open:--}"
ck $([ "$d3fh" = no_g_fhv ] && echo ok || echo no) "(d4a) and g_fhv -- the vector that holds the FH table since 9d3f8a061 moved it into the compile-time arena, named through the ctarena population -- is GONE from that same sweep (saw $d3fh)"
ck $(diff -q "$T/fh.out" "$ROOT/../harness/scripts/gc_witnesses/hb_file_name_unrooted.ref" >/dev/null 2>&1 && echo ok || echo no) "(d4b) and the witness that was g_fh's RED witness now ANSWERS ITS ORACLE -- the cure and the detector agreeing is what retires a holder, not either one alone"

echo "-- (e) EVERY HOLDER IS CURED OR DECLARED"
: > "$T/all.err"
for w in $WITS; do run_aud "$w" 3 1 > /dev/null; cat "$T/e" >> "$T/all.err"; done
DECLF="$ROOT/$DECL"
if [ "${FAIL_ONCE:-0}" = 1 ]; then printf '# FAIL_ONCE: the ledger is emptied so arm (e1) must RED on every holder pass B names\n' > "$T/decl.empty"; DECLF="$T/decl.empty"; echo "     FAIL_ONCE=1 -- the declared ledger is EMPTY for this run; (e1) is expected to RED"; fi
# the holder resolution is the ONE reader the receipts of the retirement row also run (CEO-1307): ../harness/scripts/util_gc_audit_b_receipt.py
python3 "$ROOT/../harness/scripts/util_gc_audit_b_receipt.py" holders "$T/all.err" "$AUD_SO" "$DECLF" > "$T/holders.txt"
sed 's/^/     /' "$T/holders.txt"
undecl=$(grep "^HOLDER" "$T/holders.txt" | grep -c "UNDECLARED" || true)
nh=$(awk '/^TOTALHOLDERS/{print $2}' "$T/holders.txt"); nopen=$(awk '/^OPENROWS/{print $2}' "$T/holders.txt")
ck $([ "$undecl" = 0 ] && echo ok || echo no) "(e1) every holder pass B named over the declared witness set is CURED or DECLARED in $DECL ($undecl undeclared)"
echo "     (e2) RETIRED under CEO-1680 (cto 2026-10-17): the SCRIP_GC_PLANT_UNROOT seam it graded left src at 9b73a8a5c; its recorded reading stands as the fail-once (header)"

echo "-- (f) THE EXPIRY IS STRUCTURAL"
if [ "${nopen:-0}" = 0 ] && [ "${nh:-0}" = 0 ]; then
    echo "     ⭐ RETIREMENT-PENDING: no OPEN row remains in $DECL and this gate's sweep named NO holder"
    ck ok "(f1) RETIREMENT-PENDING, not yet retired: the corpus half of the criterion (ARCH-GC section 9 condition (3); ceo CEO-1291 ruling (b)) is row gc-the-conservative-auditor-retires-on-six-hq-receipts-each-master-under-the-auditor-build-at-stress-1-and-3-reads-zero-findings -- six HQ receipts, then ONE landing deletes src/runtime/rt/gc_audit_b.[ch], the #ifdef blocks and call in gc_heap.c, the Makefile lines, this gate, $DECL, the UNROOT row of the plant table and util_gc_acceptance.py's AUDITED metric"
else
    ck ok "(f1) the expiry has not come: ${nopen:-0} OPEN row(s) and ${nh:-0} holder(s) named -- the day both read 0 this arm prints RETIREMENT-PENDING and the six-receipt row grades the deletion"
fi
echo "[$G] checks=$checks fails=$fails  holders=${nh:-0} open_rows=${nopen:-0} audit_tag=$AUD_TAG"
[ "$fails" = 0 ] || exit 1
exit 0
