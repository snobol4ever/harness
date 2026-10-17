#!/usr/bin/env bash
# util_fuzz_witness_stability.sh — measure whether the row fuzz-nondeterminism-rootcause's 5 witnesses (see util_fuzz_witness_materialize.sh — they are rungs-suite entries now, not files) are STABLE AGAINST THEMSELVES,
# in BOTH modes, comparing (stdout, rc) AS A PAIR.  Refuses (rc=2) if it cannot measure.
#
# ⛔⭐ WHY THIS EXISTS — A WITNESS SET WHOSE OWN STABILITY IS UNMEASURED CANNOT FALSIFY ANYTHING.
# Row `fuzz-nondeterminism-rootcause` spent SIX sessions grading candidate cures against these
# witnesses without ever measuring the witnesses.  Two independent measurements the same afternoon
# disagreed, and BOTH were correct:
#   * hq_C ran 10x, sampled STDOUT FIRST LINE, in MODE 3 only  -> "fz_red_m4a is stable 30/30"
#   * hq_B ran  5x, sampled EXIT CODE,        default arm       -> "fz_red_m4a cycles rc 0/132/139"
# A witness can be perfectly stable in its output and cycling in its rc.  Each of us called our own
# instrument "the witness".  So this runner fixes all three axes that were left implicit:
#   (1) N repeats, refuse on ANY disagreement -- never "looks the same, ship it";
#   (2) BOTH modes -- a sample drawn from m3 alone cannot see an m4 crash-signal effect;
#   (3) (stdout, rc) AS A PAIR -- either alone reproduces the exact ambiguity this exists to remove.
# ⭐ The catch that produced this script was not vigilance: hq_B got lucky that an accidental second
# sample existed minutes later.  Vigilance does not transfer; repeat-and-refuse does.  That is the
# whole argument for putting it in the tool (RULES.md § A SIGNAL REACHABLE BY TWO CAUSES THAT NAMES
# ONLY ONE, applied to an instrument rather than a defect).
#
# EXIT: 0 = every witness stable in both modes · 1 = at least one witness UNSTABLE (that is a real
# result, not an error) · 2 = REFUSE, could not measure (missing binary/RT/dir, or zero witnesses).
# ⛔ An unstable witness is NOT a failure of this script.  Instability is the measurement.  Use rc=1
# as "do not grade a cure against this set until the named witnesses are stabilised or excluded".
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; SD="$HERE/../../SCRIP"; ROOT="$(cd "$SD/.." && pwd)"
SCRIP="$SD/scrip"; RT_DIR="$SD/out"
DIR="${FUZZ_DIR:-$ROOT/corpus/tests/snobol4/probe_loose/fuzz}"
N="${N:-10}"; TIMEOUT="${TIMEOUT:-8s}"; MODES="${MODES:-m3 m4}"
[ -d "$DIR" ]                  || { echo "⛔ REFUSE(rc=2): witness dir missing: $DIR"; echo "   The one-flat-suite cutover (corpus c06960a1) ABSORBED 4 of the 5 witnesses into the rungs suite"; echo "   under new names and deleted this directory; only fz_red_m4b survives as a loose pair. The witnesses"; echo "   are not gone, only unreachable BY PATH. Materialize the full set and point FUZZ_DIR at it:"; echo "       FUZZ_DIR=\"\$(bash ../harness/scripts/util_fuzz_witness_materialize.sh)\" bash ../harness/scripts/$(basename "$0")"; exit 2; }
[ -x "$SCRIP" ]                || { echo "⛔ REFUSE(rc=2): no scrip binary at $SCRIP — build first (make)"; exit 2; }
[ -f "$RT_DIR/libscrip_rt.so" ]|| { echo "⛔ REFUSE(rc=2): no $RT_DIR/libscrip_rt.so"; exit 2; }
case "$N" in ''|*[!0-9]*) echo "⛔ REFUSE(rc=2): N must be a positive integer, got '$N'"; exit 2;; esac
[ "$N" -ge 2 ]                 || { echo "⛔ REFUSE(rc=2): N=$N cannot detect disagreement — need at least 2"; exit 2; }
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
mapfile -t SNOS < <(find "$DIR" -maxdepth 1 -name '*.sno' | sort)
[ "${#SNOS[@]}" -gt 0 ]        || { echo "⛔ REFUSE(rc=2): zero .sno witnesses in $DIR — an empty set is not a stable set"; exit 2; }
# ⛔ One run = one (stdout,rc) PAIR.  Never compare either half alone; see the header.
one_run() {  # $1=mode  $2=sno  -> prints "rc=<n> out=<sha of stdout>"
    local mode="$1" sno="$2" out rc
    if [ "$mode" = m3 ]; then out="$(cd "$W" && timeout -k 5 "$TIMEOUT" "$SCRIP" "$sno" < /dev/null 2>/dev/null)"; rc=$?
    else
        local s="$W/m4.s" b="$W/m4.bin"; rm -f "$s" "$b"
        if ! (cd "$W" && timeout -k 5 "$TIMEOUT" "$SCRIP" --compile -o "$s" "$sno" < /dev/null >/dev/null 2>&1); then echo "rc=CC out=CC"; return; fi
        if ! gcc -no-pie "$s" -o "$b" -L"$RT_DIR" -lscrip_rt -Wl,-rpath,"$RT_DIR" -lm >/dev/null 2>&1; then echo "rc=LINK out=LINK"; return; fi
        out="$(cd "$W" && timeout -k 5 "$TIMEOUT" "$b" < /dev/null 2>/dev/null)"; rc=$?
    fi
    printf 'rc=%s out=%s\n' "$rc" "$(printf '%s' "$out" | md5sum | cut -c1-12)"
}
echo "── fuzz witness stability · ${#SNOS[@]} witnesses · N=$N repeats · modes: $MODES · (stdout,rc) compared AS A PAIR"
echo "   SCRIP $(git -C "$SD" rev-parse --short HEAD 2>/dev/null || echo '?')  corpus $(git -C "$ROOT/corpus" rev-parse --short HEAD 2>/dev/null || echo '?')"
UNSTABLE=0; STABLE=0; UNSTABLE_NAMES=""
for sno in "${SNOS[@]}"; do
    name="$(basename "$sno" .sno)"
    for mode in $MODES; do
        : > "$W/obs"
        for _ in $(seq 1 "$N"); do one_run "$mode" "$sno" >> "$W/obs"; done
        distinct="$(sort -u "$W/obs" | wc -l)"
        if [ "$distinct" -eq 1 ]; then
            STABLE=$((STABLE+1)); printf '  STABLE   %-38s %-3s %s\n' "$name" "$mode" "$(head -1 "$W/obs")"
        else
            UNSTABLE=$((UNSTABLE+1)); UNSTABLE_NAMES="$UNSTABLE_NAMES $name/$mode"
            printf '  UNSTABLE %-38s %-3s %d distinct in %d runs:\n' "$name" "$mode" "$distinct" "$N"
            sort "$W/obs" | uniq -c | sed 's/^/       /'
        fi
    done
done
echo
echo "stable=$STABLE unstable=$UNSTABLE  (witness×mode pairs; N=$N)"
if [ "$UNSTABLE" -gt 0 ]; then
    echo "⛔ UNSTABLE:$UNSTABLE_NAMES"
    echo "⛔ DO NOT GRADE A CURE AGAINST THIS SET until those are stabilised or explicitly excluded —"
    echo "   an A/B against an unstable witness can read 'all identical' by luck, which is exactly how"
    echo "   this runner came to be written."
    exit 1
fi
echo "✅ every witness is self-stable in every measured mode — the set can falsify a cure."
