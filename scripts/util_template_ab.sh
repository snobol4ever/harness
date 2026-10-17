#!/usr/bin/env bash
# util_template_ab.sh — THE TEMPLATE A/B WITNESS, BOUNDED ON DISK (hq_templates, row
# templates-economy-the-watch-loop-wrote-19-gb-into-its-session-scratchpad-in-80-minutes-..., ceo CEO-1332).
#
# The loop's law 1 (behavior-neutral always) is proven by the mode-4 .s of every corpus program before and after a
# template edit. The ad-hoc capture it replaces kept every .s on disk -- 3253 files, 4.7 GB per side, four sides in
# one sitting, 19 GB of /tmp in 80 minutes. This one streams each .s through the line-tag normalizer into sha256sum
# and keeps ONE LINE per program: a side is a ~300 KB TSV, overwritten when its label is reused, and no .s ever
# touches the disk. A program whose hashes differ is re-compiled by hand, one file, to read the diff.
#
#   util_template_ab.sh capture LABEL [DIR]   every corpus program -> DIR/LABEL.tsv  (path, rc, sha of normalized .s)
#   util_template_ab.sh diff A.tsv B.tsv      the programs whose rc or sha differ; rc 1 when any do, 0 when none
#
# DIR defaults to ${TMPDIR:-/tmp}/template_ab. THE NORMALIZER: the "<file>.cpp:<line>" tags a gc_poll comment carries
# name a template's SOURCE line, which any edit above it moves; they read as "<file>.cpp:N", nothing else changes.
# A program killed by the timeout (AB_TIMEOUT, default 60 s; rc 124) wrote a partial .s, so its sha reads "timeout",
# and diff counts a timeout on EITHER side as UNPROVEN, printed apart, never as a difference: under load a 90 MB .s
# (jcon jtran.icn) finishes on one side and times out on the other with the same binary.
# FAN-OUT (ceo CEO-1333): the workers are lib_fanout.sh's fanout_width, max(2, min(4, cores minus load)), under its
# fanout_nice; AB_JOBS overrides. At width 2 a side takes about ten minutes.
# The binary is ./scrip of the tree this script lives in, as built: build before each side.
set -uo pipefail
here=$(cd "$(dirname "$0")/../../SCRIP" && pwd)
root=$(cd "$here/.." && pwd)
verb=${1:-}
case "$verb" in
capture)
    label=${2:?usage: util_template_ab.sh capture LABEL [DIR]}
    dir=${3:-${TMPDIR:-/tmp}/template_ab}
    mkdir -p "$dir"
    out="$dir/$label.tsv"
    : > "$out.part"
    export SCRIP_BIN="$here/scrip" AB_OUT="$out.part"
    [ -x "$SCRIP_BIN" ] || { echo "REFUSE(2): no binary at $SCRIP_BIN -- make first" >&2; exit 2; }
    one() {
        local f=$1 sha rc
        sha=$(cd "$(dirname "$f")" && timeout -k 5 "${AB_TIMEOUT:-60}" "$SCRIP_BIN" --compile -o /dev/stdout "$(basename "$f")" < /dev/null 2>/dev/null \
            | sed -E 's/([A-Za-z0-9_]+\.cpp):[0-9]+/\1:N/g' | sha256sum | cut -c1-16; exit "${PIPESTATUS[0]}")
        rc=$?
        [ "$rc" -eq 124 ] && sha=timeout
        printf '%s\t%s\t%s\n' "$f" "$rc" "$sha" >> "$AB_OUT"
    }
    export -f one
    . "$here/../harness/scripts/lib_fanout.sh"
    jobs=${AB_JOBS:-$(fanout_width)}
    echo "capture $label: $jobs worker(s) under $(fanout_nice) -- $(fanout_report)" >&2
    cd "$root" || exit 2
    find corpus -type f \( -name '*.sno' -o -name '*.icn' -o -name '*.raku' -o -name '*.pl' -o -name '*.sc' -o -name '*.pas' -o -name '*.reb' \) \
        | sort | $(fanout_nice) xargs -P "$jobs" -I{} bash -c 'one "$1"' _ {}
    sort -o "$out" "$out.part" && rm -f "$out.part"
    echo "$out: $(wc -l < "$out") programs, $(du -h "$out" | cut -f1)"
    ;;
diff)
    a=${2:?usage: util_template_ab.sh diff A.tsv B.tsv}; b=${3:?usage: util_template_ab.sh diff A.tsv B.tsv}
    ul=$(join -t $'\t' -j1 "$a" "$b" | awk -F'\t' '$2==124 || $4==124 {print "UNPROVEN\t" $0}')
    nl=$(join -t $'\t' -j1 "$a" "$b" | awk -F'\t' '$2!=124 && $4!=124 && ($2!=$4 || $3!=$5) {print "DIFFERS\t" $0}')
    [ -n "$ul" ] && printf '%s\n' "$ul"
    [ -n "$nl" ] && printf '%s\n' "$nl"
    u=$(printf '%s' "$ul" | grep -c .); n=$(printf '%s' "$nl" | grep -c .)
    only=$(join -t $'\t' -v1 -v2 -j1 "$a" "$b" | wc -l)
    echo "A/B: $(wc -l < "$a") vs $(wc -l < "$b") programs; $n differ; $u unproven (timeout); $only in one side only"
    [ "$n" -eq 0 ] && [ "$only" -eq 0 ]
    ;;
*)
    echo "usage: util_template_ab.sh capture LABEL [DIR] | diff A.tsv B.tsv" >&2; exit 2 ;;
esac
