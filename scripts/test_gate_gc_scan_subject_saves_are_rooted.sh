#!/usr/bin/env bash
# test_gate_gc_scan_subject_saves_are_rooted.sh -- A SAVED SCAN SUBJECT IS A ROOT, NOT A POINTER THAT HAPPENS TO ALIAS A LIVE ONE.
# ⛔ THE MEASURED DEFECT (cfo 2026-09-18): gen_gc_roots visited the LIVE scan_subj and nothing else, so every saved outer subject of a
# nested scan and every suspended coexpression's ScanState (rt_scan_state_capture, held on ctx->scan_state) carried a collected-heap
# subject pointer that NO root walk visited -- unmarked and unregistered for forwarding; an EMITTED rooted holder aliased the same
# block, an alibi, not a root.
# ⛔ RE-CUT 2026-10-14 (hq_collector, row gc-blocking-gate-scan-subject-saves-are-rooted-refuses-heap-0-everywhere-ceo-1697): the
# population moved. The per-scan saves of the outer subject no longer live on a scan_saved[] stack (NO GLOBAL HOLDS A STACK, CEO-1542):
# they are cells of the scanning frame (outer_Σ in the match/scan prologue), typed in the frame's static layout and visited by the
# chain over the maps (ARCH-GC 13); the only saves the SCRIP_GC_AUDIT_SLOTS audit still walks are the ScanStates a co-expression
# SWITCH captures (g_root_ctx.scan_state and each parked context's). The old arm asked the audit about a witness with no
# co-expression, read heap=0 everywhere and REFUSED on a tree where both populations are rooted. The two populations are graded
# where each lives, and the discriminating evidence is THE ORACLE'S ANSWER UNDER MOVING COLLECTIONS, never a count alone:
#   (1) FRAME SAVES: a plain scanning generator whose body allocates (a collection at every second safe point, relocation and
#       verification on, SCRIP_GC_CHAIN_CHECK=3) answers exactly what icont/iconx answers, in BOTH media, with the chain walk whole
#       (whole == runs, offchain-swept 0, missing 0) and at least one collection taken; an unrooted saved subject reads a stale
#       pointer after the move and the answer or the walk says so.
#   (2) CAPTURED SAVES: a co-expression created and activated INSIDE a scan under the same knobs answers what iconx answers, and the
#       audit reads heap >= 1 at some collection (the captured subject IS a collected-heap pointer) and unrooted = 0 at every one.
# Both refs are cut LIVE from icont; FAIL_ONCE=1 corrupts arm 1's ref (CEO-1680: a proper fail-once is a witness red against a
# corrupted ref or the oracle's different answer). A stale binary or a missing icont REFUSES rc=2; a refusal is not a red.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }; cd "$ROOT" || exit 2
G=gc_scan_subject_saves_are_rooted
bash ../harness/scripts/util_require_fresh.sh >/dev/null 2>&1 || { echo "REFUSES rc=2: stale or missing ./scrip -- run make"; exit 2; }
. "$HERE/lib_oracle_flags.sh"
ICONT="$(icont_bin)" || { echo "⛔ GATE REFUSE(2) [$G]: no icont -- both refs are cut from the oracle"; exit 2; }
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
cat > "$W/w.icn" <<'ICN'
procedure main();
   local i, t, n;
   n := 0;
   every i := (repl("hello world ", 40) ? find("o")) do {
      t := repl("x", 2000);
      n := n + i + *t;
      };
   write("n=", n);
end
ICN
cat > "$W/c.icn" <<'ICN'
procedure main();
   local e, n, k;
   n := 0;
   repl("abc ", 50) ? {
      e := create |(repl("y", 1500), 1);
      every k := 1 to 20 do n := n + @e;
      n := n + find("c");
      };
   write("n=", n);
end
ICN
oracle() { ( cd "$W" && cp "$1.icn" "o_$1.icn" && "$ICONT" -s "o_$1.icn" -x </dev/null 2>/dev/null ) | head -1; }
WANT_W="$(oracle w)"; WANT_C="$(oracle c)"
[ -n "$WANT_W" ] && [ -n "$WANT_C" ] || { echo "⛔ GATE REFUSE(2) [$G]: icont printed nothing for a witness (w='$WANT_W' c='$WANT_C')"; exit 2; }
[ "${FAIL_ONCE:-0}" = 1 ] && WANT_W="n=corrupted"
build4() { ( cd "$W" && timeout -k 5 120 "$ROOT/scrip" --compile --out="$1.s" "$1.icn" </dev/null >/dev/null 2>&1 && gcc "$1.s" -L"$ROOT/out" -lscrip_rt -lm -lpthread -Wl,-rpath,"$ROOT/out" -o "$1.m4" >/dev/null 2>&1 ) || { echo "⛔ GATE REFUSE(2) [$G]: mode 4 did not build $1"; exit 2; }; }
build4 w; build4 c
num() { printf '%s\n' "$1" | sed -n "s/.* $2=\([0-9]*\).*/\1/p"; }
bad=0
run_w() {
    local lbl="$1"; shift
    env SCRIP_GC_STRESS=2 SCRIP_GC_VERIFY=1 SCRIP_GC_CHAIN_CHECK=3 timeout -k 5 120 "$@" </dev/null >"$W/o" 2>"$W/e"; local rc=$?
    local got; got="$(head -1 "$W/o")"; local s; s="$(grep -a '^\[CHAIN-WALK\] SUMMARY ' "$W/e" | tail -1)"
    local runs whole off miss; runs="$(num "$s" runs)"; whole="$(num "$s" whole)"; off="$(num "$s" offchain-swept)"; miss="$(num "$s" missing)"
    if [ -z "$s" ] || [ "${runs:-0}" -lt 1 ]; then echo "⛔ GATE REFUSE(2) [$G]: $lbl took no collection under stress 2 -- nothing about a saved subject was measured"; exit 2; fi
    if [ "$rc" = 0 ] && [ "$got" = "$WANT_W" ] && [ "$whole" = "$runs" ] && [ "$off" = 0 ] && [ "$miss" = 0 ]; then echo "  arm 1 $lbl PASS: $got as iconx under $runs moving collection(s), chain whole=$whole/$runs offchain-swept=0 missing=0"
    else echo "⛔ arm 1 $lbl RED: rc=$rc got '$got' want '$WANT_W' chain runs=${runs:-?} whole=${whole:-?} offchain-swept=${off:-?} missing=${miss:-?} $(grep -ao 'REFUSED.*\|BOMB.*' "$W/e" | head -1 | cut -c1-120)"; bad=1; fi
}
run_c() {
    local lbl="$1"; shift
    env SCRIP_GC_AUDIT_SLOTS=1 SCRIP_GC_STRESS=2 SCRIP_GC_VERIFY=1 timeout -k 5 120 "$@" </dev/null >"$W/o" 2>"$W/e"; local rc=$?
    local got; got="$(head -1 "$W/o")"
    local c hi un; c="$(grep -ac '^\[GC-AUDIT\] scan-save' "$W/e")"
    hi=$(awk '/^\[GC-AUDIT\] scan-save/{for(i=1;i<=NF;i++){if($i~/^heap=/){split($i,a,"=");if(a[2]+0>m)m=a[2]+0}}} END{print m+0}' "$W/e")
    un=$(awk '/^\[GC-AUDIT\] scan-save/{for(i=1;i<=NF;i++){if($i~/^unrooted=/){split($i,a,"=");s+=a[2]}}} END{print s+0}' "$W/e")
    if [ "$c" -lt 1 ]; then echo "⛔ GATE REFUSE(2) [$G]: $lbl took no audited collection -- the captured population was not measured"; exit 2; fi
    if [ "$hi" -lt 1 ]; then echo "⛔ GATE REFUSE(2) [$G]: $lbl audit reads heap=0 at every one of $c collection(s) -- the captured subject is off the collected heap, so rooting cannot be measured (the cure is a root, not a different allocator)"; exit 2; fi
    if [ "$rc" = 0 ] && [ "$got" = "$WANT_C" ] && [ "$un" = 0 ]; then echo "  arm 2 $lbl PASS: $got as iconx, $c audited collection(s), captured subjects on the heap at most $hi, unrooted=0"
    else echo "⛔ arm 2 $lbl RED: rc=$rc got '$got' want '$WANT_C' audited=$c heap<=$hi unrooted=$un"; bad=1; fi
}
run_w "m3" "$ROOT/scrip" "$W/w.icn"
run_w "m4" "$W/w.m4"
run_c "m3" "$ROOT/scrip" "$W/c.icn"
run_c "m4" "$W/c.m4"
if [ "$bad" = 0 ]; then echo "GATE PASS(0) [$G]: a saved scan subject is a root in both of its homes -- the scanning frame's cell (walked by the chain) and the co-expression's captured ScanState (registered for forwarding) -- both media, under moving collections, iconx's answers"; exit 0; fi
echo "GATE FAIL(1) [$G]: a saved scan subject is not rooted where it lives (see the arms above)"; exit 1
