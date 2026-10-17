#!/usr/bin/env bash
# util_blob_spine_slot_sweep.sh — census the BLOB-SPINE COLLISION class across a corpus of programs.
#
# ⛔⭐ THE CLASS (hq_C s284, measured on corpus/probe/fuzz's fz_segv_09 / fz_red_m4a).  A stored-pattern
# blob (`.LTp<n>`) carves an rbp ACTIVATION FRAME of exactly blob_head_bytes() + 16*count bytes and
# EVERY BYTE OF IT IS OWNED: the head holds the WIRE-STACK banked (γ,ω) pair at [rbp-8]/[rbp-16] plus
# rdx and the casmark, and frame_slot_off() hands the cells out from -(head+8) DOWNWARD.  So the ζ-SPINE
# `[rsp + N]` plane has ZERO CAPACITY inside a blob: any FR-family slot access there necessarily lands on
# an allocated cell, on the banked pair, or above rbp on the CALLER's stack.  ⭐ Nothing is out of bounds
# when it happens — every store hits mapped, writable, plausible stack — so the corruption is silent and
# surfaces one indirect jump later, in a different function, as a wild jump to a stack address.
#
# WHAT IT REPORTS: for every blob region (.LTp<n>_α_body .. .LTp<n>_ω) in the emitted asm, any `[rsp + N]`
# memory operand with N >= 32.  ⛔ WHY 32 AND NOT 0: the four-word γ-SUSPEND resume record ([rsp+0]=&res,
# +8=γ, +16=ω, +24=saved rbp) and the caller's PUSHed wire pair are LEGITIMATE small-offset rsp reads and
# are the overwhelming majority of in-blob rsp traffic.  A cutoff of 0 drowns the signal in them; 32 is
# above the largest sanctioned record.  ⚠️ That makes this a DETECTOR WITH A FLOOR, not a proof of
# absence — a collision at N<32 would not be reported.  State it that way when quoting a zero.
#
# ⛔⭐ THIS IS A SCREEN, NOT A DEFECT DETECTOR, AND THE DIFFERENCE IS LOAD-BEARING.  `[rsp + N]` inside a
# blob is a collision only if rsp is AT THE FRAME BASE at that instruction.  A box that has carved its own
# stack (`sub rsp, K`) addresses its own carve through the same syntax, and this sweep cannot see control
# flow, so it cannot tell the two apart.  The fz_segv_09 fence was unambiguous because its carve was
# `sub rsp, 0` -- rsp WAS the frame base -- but a hit here is a SUSPECT, and the corpus proves that
# directly: `beauty.sno` reports hits and self-hosts to its own fixed point, so most of what this prints
# is legitimate or benign.  ⭐ THE WAY TO SPEND THE OUTPUT IS AS AN A/B, NOT AS A LIST: run it in both
# arms of a candidate change (SCRIP_BLOB_FENCE_FRAME=0 is one) and read the DIFFERENCE -- refs that vanish
# are what the change fixed, refs present in both are pre-existing suspects needing their own carve
# analysis, and refs that APPEAR are the change's own new exposure.  Quoting the raw count as a defect
# count would be the over-claim this file exists to help avoid.
#
# ⛔ AND IT REPORTS ITS OWN BLIND SPOT IN THE SUMMARY LINE, DELIBERATELY: a program that will not
# `--compile` standalone (an -INCLUDE resolved against a working directory, a missing companion) is
# NOT SWEPT, and the count of those is printed beside the count of those that were.  Read "0 findings"
# only together with that number -- the s188/beauty lesson is that an instrument run outside the
# program's own directory reports a clean, plausible, entirely uninformative result.
#
# EXIT: 0 = swept, findings printed (a finding is NOT a failure — this is a census, not a gate) ·
#       2 = REFUSE, could not sweep (no compiler, no programs).  Never silently reports an empty corpus.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; SD="$HERE/../../SCRIP"; ROOT="$(cd "$SD/.." && pwd)"
SCRIP="${SCRIP:-$SD/scrip}"
say() { printf '%s\n' "$*" >&2; }
[ -x "$SCRIP" ] || { say "⛔ REFUSE(rc=2): no compiler at $SCRIP"; exit 2; }
FILES=()
if [ "$#" -gt 0 ]; then for a in "$@"; do [ -e "$a" ] && FILES+=("$a"); done
else while IFS= read -r f; do FILES+=("$f"); done < <(find "$ROOT/corpus" -name '*.sno' -type f 2>/dev/null | sort); fi
[ "${#FILES[@]}" -gt 0 ] || { say "⛔ REFUSE(rc=2): zero programs to sweep"; exit 2; }
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
nprog=0; nblob=0; nhit=0; nfile=0; nskip=0
for f in "${FILES[@]}"; do
    if ! timeout -k 5 20 "$SCRIP" --compile -o "$TMP/p.s" "$f" < /dev/null > /dev/null 2>&1; then nskip=$((nskip+1)); continue; fi
    nprog=$((nprog+1))
    out="$(awk '
        /^\.LTp[0-9]+_α_body:/ { inblob=1; blob=$0; sub(/_α_body:.*/,"",blob); blobs[blob]=1; next }
        /^\.LTp[0-9]+_ω:/      { inblob=0; next }
        inblob && match($0, /\[rsp \+ [0-9]+\]/) {
            off = substr($0, RSTART+6, RLENGTH-7) + 0
            if (off >= 32) { gsub(/^[ \t]+|[ \t]+$/,"",$0); printf "    %s   %s\n", blob, $0 } }
        END { }' "$TMP/p.s")"
    b="$(grep -c '^\.LTp[0-9]*_α_body:' "$TMP/p.s" 2>/dev/null)"; b="${b//[^0-9]/}"; nblob=$((nblob + ${b:-0}))
    if [ -n "$out" ]; then nfile=$((nfile+1)); h=$(printf '%s\n' "$out" | grep -c .); nhit=$((nhit+h))
        printf '⛔ %s\n%s\n' "${f#$ROOT/}" "$out"; fi
done
printf '\n── BLOB-SPINE SWEEP: %d programs compiled (%d would not compile, not swept) · %d blobs · %d files with findings · %d in-blob [rsp+N>=32] refs\n' \
       "$nprog" "$nskip" "$nblob" "$nfile" "$nhit"
[ "$nprog" -gt 0 ] || { say "⛔ REFUSE(rc=2): nothing compiled"; exit 2; }
exit 0
