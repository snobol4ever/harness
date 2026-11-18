#!/usr/bin/env bash
"$(dirname "${BASH_SOURCE[0]}")/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
# test_design_one_sequence_storage_steps.sh -- THE STEP-THROUGH HARNESS of DESIGN-PLAN: one-sequence-storage, SNOBOL4 ARRAY AND ICON list ARE ONE STORAGE, THE DT_A BLOCK
# (the cto, 2026-11-18; taken by the chairman 15:5x CST on Lon's word of 15:4x, skill scrip-architecture section 7, the bullet SNOBOL4 AND ICON HOLD EACH STRUCTURE IN ONE
# STORAGE; the design text is skill scrip-memory-model reference, ONE SEQUENCE STORAGE; the plan with its measurements /home/resources/evidence/cto/one-sequence-storage-2026-11-18/PLAN.md).
# The table is $S4E_HARNESS/designs/one_sequence_storage/STEPS.tsv. The witnesses are documents of SNOBOL4 and Icon sections (NAME.md beside NAME.ref, the stdout, and an
# optional NAME.err, a text the first stderr line must hold) in $OSS_W (default /home/resources/evidence/cto/one-sequence-storage-2026-11-18/witnesses): no oracle runs a mix,
# so each answer is written by hand from the design (the notebook-show precedent); the two kernels are one language each, kernel_a.sno cut from sbl -bf, kernel_b.icn from
# Arizona icont -s. EVERY WITNESS RUNS TWICE in mode 3 (no mode 4, Lon 2026-11-18): plain, and under the collector's stress (SCRIP_GC_STRESS=1 SCRIP_HEAP_KB=128
# SCRIP_HEAP_MAX_MB=512), since a block whose live length the collector misreads shows only when a collection moves the heap.
#
#   --list              print the steps and run nothing
#   --step N            grade step N's probe tokens (N as the table spells it, 0 to 9, 5a to 5f):
#                       docs=a,b       each witness, both runs, stdout equal to NAME.ref and, with NAME.err, the first stderr line holding it
#                       baseline       S0-COUNTS.tsv holds kernel_A and kernel_B, each a positive count, and a line pNN for each of the sixteen probes
#                       kernelA=le|lt  util_instr_count.sh -n 5 scrip kernel_a.sno, TOTAL (instructions:u of the whole run, median of 5, the form step 0 recorded) not above (le) or below (lt) S0-COUNTS.tsv's kernel_A; its answer equal to kernel_a.ref first
#                       kernelB=le|lt  the same for kernel_b.icn. THE BAND IS 0.01 PERCENT: le passes at most 0.01% above the baseline, lt only more than 0.01% below it
#                                      (MEASURED 2026-11-18 16:1x CST on SCRIP 61aa32d76a, one binary, the same two programs, two seats: kernel A 99838248 and 99839272, +0.001%;
#                                      kernel B 245137480 and 245146203, +0.004%; so an exact bound reads red with no change made)
#                       grep=REGEX@REL     grep -rE REGEX under $S4E_SCRIP/REL finds at least one line (REGEX holds no @ and no whitespace; write \s)
#                       nogrep=REGEX@REL   the same finds none; REL may be several, joined by ;
#                       owed           the step's probe is the cto's to write: REFUSED
#   --write-baseline    count both kernels on this tree and read the sixteen probes p01 to p16, writing S0-COUNTS.tsv (step 0's road; p12 has no witness here, its a<2>
#                       subscript waits on the angle-bracket row, and reads ANGLE; refuses over an existing file unless --force)
#   --probe             fail once and pass once for every token, on scratch witnesses and a scratch baseline
#
# VERDICT: STEP N <slug>: <token:reading ...> -> GREEN|RED|REFUSED; rc 0 GREEN, 1 RED, 2 could not measure.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/lib_paths.sh"
STEPS="${OSS_STEPS:-$HERE/../designs/one_sequence_storage/STEPS.tsv}"
OSS_W="${OSS_W:-/home/resources/evidence/cto/one-sequence-storage-2026-11-18/witnesses}"
BASE="${OSS_BASELINE:-$OSS_W/../S0-COUNTS.tsv}"
SCRIP_BIN="$S4E_SCRIP/scrip"
SEAT="${S4E_SEAT:-anon}"
STRESS_ENV="SCRIP_GC_STRESS=1 SCRIP_HEAP_KB=128 SCRIP_HEAP_MAX_MB=512"
refuse() { echo "REFUSE(2): $*" >&2; exit 2; }
[ -x "$SCRIP_BIN" ] || refuse "no scrip binary at $SCRIP_BIN"
[ -f "$STEPS" ] || refuse "no step table $STEPS"
SCR="$(mktemp -d "/tmp/s4e/$SEAT/oss.XXXXXX" 2>/dev/null)" || { mkdir -p "/tmp/s4e/$SEAT" && SCR="$(mktemp -d "/tmp/s4e/$SEAT/oss.XXXXXX")"; } || refuse "no scratch under /tmp/s4e/$SEAT"
trap 'rm -rf "$SCR"' EXIT
run_doc() {
    local n="$1" how="$2" md="$OSS_W/$1.md" out err rc
    [ -f "$md" ] && [ -f "$OSS_W/$n.ref" ] || { echo "REFUSE"; return; }
    if [ "$how" = s ]; then out="$(cd "$SCR" && env $STRESS_ENV timeout -k 5 60 "$SCRIP_BIN" "$md" < /dev/null 2> "$SCR/$n.$how.err")"; rc=$?
    else out="$(cd "$SCR" && timeout -k 5 60 "$SCRIP_BIN" "$md" < /dev/null 2> "$SCR/$n.$how.err")"; rc=$?; fi
    [ "$rc" = 124 ] && { echo "TIMEOUT"; return; }
    [ "$out" = "$(cat "$OSS_W/$n.ref")" ] || { echo "DIFF"; return; }
    if [ -f "$OSS_W/$n.err" ]; then head -1 "$SCR/$n.$how.err" | grep -F -- "$(head -1 "$OSS_W/$n.err")" > /dev/null || { echo "STDERR"; return; }; fi
    echo "PASS"
}
tok_docs() {
    local list="$1" n r bad=0 ref=0 rd=""
    for n in ${list//,/ }; do
        for h in p s; do r="$(run_doc "$n" "$h")"; [ "$r" = PASS ] && continue; [ "$r" = REFUSE ] && ref=1; bad=1; rd="$rd $n.$h=$r"; done
    done
    [ "$ref" = 1 ] && { echo "REFUSE docs:missing:$(echo "$rd" | sed 's/^ //; s/ /,/g')"; return; }
    rd="$(echo "$rd" | sed 's/^ //; s/ /,/g')"
    [ "$bad" = 0 ] && echo "PASS docs:$(echo "$list" | tr ',' '\n' | wc -l)x2" || echo "FAIL docs:$rd"
}
base_of() { awk -v k="$1" '$1==k && $2 ~ /^[0-9]+$/ && $2 > 0 {print $2}' "$BASE" 2>/dev/null | head -1; }
count_of() {
    local src="$OSS_W/$1" ref="$OSS_W/${1%.*}.ref" out line
    [ -f "$src" ] && [ -f "$ref" ] || { echo "REFUSE"; return; }
    out="$(cd "$SCR" && timeout -k 5 120 "$SCRIP_BIN" "$src" < /dev/null 2>/dev/null)"
    [ "$out" = "$(cat "$ref")" ] || { echo "WRONG"; return; }
    line="$(cd "$SCR" && bash "$S4E_HARNESS/scripts/util_instr_count.sh" -n 5 scrip "$src" < /dev/null 2>/dev/null | grep '^INSTR ')"
    echo "$line" | sed -n 's/.* total=\([0-9][0-9]*\) .*/\1/p' | grep -E '^[0-9]+$' || echo "REFUSE"
}
tok_kernel() {
    local which="$1" op="$2" file b w
    [ "$which" = A ] && file=kernel_a.sno || file=kernel_b.icn
    b="$(base_of "kernel_$which")"; [ -n "$b" ] || { echo "REFUSE kernel$which:no-baseline"; return; }
    w="$(count_of "$file")"
    case "$w" in REFUSE) echo "REFUSE kernel$which:no-count"; return;; WRONG) echo "FAIL kernel$which:wrong-answer"; return;; esac
    case "$op" in
        le) [ "$w" -le $((b + b / 10000)) ] && echo "PASS kernel$which:$w<=$b+0.01%" || echo "FAIL kernel$which:$w>$b+0.01%";;
        lt) [ "$w" -lt $((b - b / 10000)) ] && echo "PASS kernel$which:$w<$b-0.01%" || echo "FAIL kernel$which:$w>=$b-0.01%";;
        *) echo "REFUSE kernel$which:op-$op";;
    esac
}
tok_grep() {
    local want="$1" spec="$2" re="${2%%@*}" rels="${2#*@}" rel hits=0 miss=0 c
    [ "$re" != "$spec" ] || { echo "REFUSE $want:no-@"; return; }
    for rel in ${rels//;/ }; do
        [ -e "$S4E_SCRIP/$rel" ] || { miss=1; continue; }
        c="$(grep -rEc -- "$re" "$S4E_SCRIP/$rel" 2>/dev/null | awk -F: '{s+=$NF} END {print s+0}')"; hits=$((hits + c))
    done
    if [ "$want" = grep ]; then [ "$miss" = 0 ] || { echo "REFUSE grep:missing-path"; return; }; [ "$hits" -gt 0 ] && echo "PASS grep:$hits" || echo "FAIL grep:0"
    else [ "$hits" = 0 ] && echo "PASS nogrep:0" || echo "FAIL nogrep:$hits"; fi
}
grade() {
    local t
    for t in "$@"; do
        case "$t" in
            docs=*) tok_docs "${t#docs=}";;
            baseline) [ -n "$(base_of kernel_A)" ] && [ -n "$(base_of kernel_B)" ] && [ "$(grep -c "^p[0-9][0-9]	" "$BASE" 2>/dev/null)" -ge 16 ] && echo "PASS baseline" || echo "FAIL baseline:$BASE";;
            kernelA=*) tok_kernel A "${t#kernelA=}";;
            kernelB=*) tok_kernel B "${t#kernelB=}";;
            grep=*) tok_grep grep "${t#grep=}";;
            nogrep=*) tok_grep nogrep "${t#nogrep=}";;
            owed) echo "REFUSE owed:the-cto-writes-this-probe";;
            -) ;;
            *) echo "REFUSE unknown:$t";;
        esac
    done
}
verdict() {
    local label="$1"; shift
    local res; res="$(grade "$@")"
    local line; line="$(echo "$res" | awk '{print $1":"$2}' | tr '\n' ' ')"
    if echo "$res" | grep '^REFUSE' > /dev/null; then echo "STEP $label: $line-> REFUSED"; return 2; fi
    if echo "$res" | grep '^FAIL' > /dev/null; then echo "STEP $label: $line-> RED"; return 1; fi
    echo "STEP $label: $line-> GREEN"; return 0
}
case "${1:-}" in
    --list) grep -v '^#' "$STEPS"; exit 0;;
    --step)
        [ -n "${2:-}" ] || refuse "--step needs N"
        row="$(awk -F'\t' -v n="$2" '!/^#/ && $1==n' "$STEPS")"
        [ -n "$row" ] || refuse "no step $2 in $STEPS"
        slug="$(echo "$row" | cut -f2)"; probe="$(echo "$row" | cut -f5)"
        read -r -a toks <<< "$probe"
        verdict "$2 $slug" "${toks[@]}"; exit $?;;
    --write-baseline)
        [ -f "$BASE" ] && [ "${2:-}" != --force ] && refuse "$BASE exists; --force to write it again"
        a="$(count_of kernel_a.sno)"; b="$(count_of kernel_b.icn)"
        echo "$a $b" | grep -E '^[0-9]+ [0-9]+$' > /dev/null || refuse "a kernel did not count (A=$a B=$b)"
        { printf '# one-sequence-storage step 0: util_instr_count.sh -n 5 scrip, TOTAL; the probes plain and under stress; SCRIP %s, %s\nkernel_A\t%s\nkernel_B\t%s\n' \
            "$(git -C "$S4E_SCRIP" rev-parse --short HEAD)" "$(date '+%Y-%m-%d %H:%M %Z')" "$a" "$b"
          for i in 01 02 03 04 05 06 07 08 09 10 11 12 13 14 15 16; do
              if [ "$i" = 12 ]; then printf 'p12\tANGLE\tANGLE\n'; else printf 'p%s\t%s\t%s\n' "$i" "$(run_doc "p$i" p)" "$(run_doc "p$i" s)"; fi
          done; } > "$BASE"
        cat "$BASE"; exit 0;;
    --probe)
        P="$SCR/probe"; mkdir -p "$P/w" "$P/src/x"; fails=0
        printf '```snobol4\n        OUTPUT = "ok"\nEND\n```\n' > "$P/w/g.md"; printf 'ok\n' > "$P/w/g.ref"; cp "$P/w/g.md" "$P/w/r.md"; printf 'no\n' > "$P/w/r.ref"
        printf 'int cap;\n' > "$P/src/x/f.h"
        cp "$OSS_W/kernel_a.sno" "$OSS_W/kernel_a.ref" "$OSS_W/kernel_b.icn" "$OSS_W/kernel_b.ref" "$P/w/"
        { printf 'kernel_A\t999999999999\nkernel_B\t1\n'; for i in $(seq -w 1 16); do printf 'p%s\tPASS\tPASS\n' "$i"; done; } > "$P/base.tsv"
        chk() { local want="$1"; shift; local got; got="$(OSS_W="$P/w" OSS_BASELINE="$P/base.tsv" S4E_SCRIP_PROBE=1 grade "$@" | awk '{print $1}' | head -1)"; [ "$got" = "$want" ] && echo "probe ok   $want $*" || { echo "probe FAIL want $want got $got: $*"; fails=1; }; }
        OSS_W="$P/w"; BASE="$P/base.tsv"
        chk PASS docs=g; chk FAIL docs=r; chk REFUSE docs=missing
        chk PASS baseline; BASE="$P/none.tsv"; chk FAIL baseline; BASE="$P/base.tsv"
        chk PASS kernelA=le; chk FAIL kernelB=le; chk PASS kernelA=lt; chk FAIL kernelB=lt
        SAVE="$S4E_SCRIP"; S4E_SCRIP="$P/src"
        chk PASS 'grep=\bcap\b@x/f.h'; chk FAIL 'grep=\bbase\b@x/f.h'; chk REFUSE 'grep=cap@x/none.h'
        chk PASS 'nogrep=\bbase\b@x/f.h'; chk FAIL 'nogrep=\bcap\b@x/f.h;x/none.h'
        S4E_SCRIP="$SAVE"; chk REFUSE owed; chk REFUSE bogus
        [ "$fails" = 0 ] && { echo "PROBE GREEN"; exit 0; } || { echo "PROBE RED"; exit 1; };;
    *) refuse "usage: --list | --step N | --write-baseline [--force] | --probe";;
esac
