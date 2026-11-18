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
#                       baseline       S0-COUNTS.tsv (step 0's record) holds kernel_A and kernel_B, each a positive count, and a line pNN for each of the sixteen probes
#                       kernelA=le|lt  TOTAL instructions:u of setarch -R util_instr_count.sh -n 5 scrip kernel_a.sno (its answer equal to kernel_a.ref first), not above (le)
#                                      or below (lt) THE SAME SEAT'S count of the baseline commit, read from baselines/<seat>.tsv beside the witnesses
#                       kernelB=le|lt  the same for kernel_b.icn
#                       THE BASELINE IS A COMMIT, NEVER A NUMBER ANOTHER SEAT READ (the chairman 2026-11-18 16:1x CST: one commit read 0.019% apart from three seats, one seat
#                       read two commits 7 instructions apart). A seat writes its own file by --write-baseline with its root at the table's BASELINE-COMMIT; a kernel token
#                       REFUSES a file whose head names another seat or another root. THE BAND IS ONE PART IN A MILLION (about 100 on A, 245 on B): MEASURED 2026-11-18
#                       16:3x CST on SCRIP 61aa32d76a in the cto's seat, the instrument without setarch read kernel A over 3,600 apart in three readings, ASLR the cause;
#                       under setarch -R three readings were 99842194, 99842198, 99842196 (A) and 245145518, 245145507, 245145506 (B)
#                       grep=REGEX@REL     grep -rE REGEX under $S4E_SCRIP/REL finds at least one line (REGEX holds no @ and no whitespace; write \s)
#                       nogrep=REGEX@REL   the same finds none; REL may be several, joined by ;
#                       owed           the step's probe is the cto's to write: REFUSED
#   --write-baseline    with the root at the table's BASELINE-COMMIT and no tracked edit, count both kernels and write baselines/<seat>.tsv, its head naming the seat, the
#                       root and the commit (check the commit out, make, run this, check your branch out again; the build cache serves the old build). It refuses anywhere else.
#                       p12 (an angle-bracket subscript) is no witness: Lon ruled the form out of SCRIP's grammar on 2026-10-02, so it is an expected refusal.
#   --probe             fail once and pass once for every token, on scratch witnesses and a scratch baseline
#
# VERDICT: STEP N <slug>: <token:reading ...> -> GREEN|RED|REFUSED; rc 0 GREEN, 1 RED, 2 could not measure.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/lib_paths.sh"
STEPS="${OSS_STEPS:-$HERE/../designs/one_sequence_storage/STEPS.tsv}"
OSS_W="${OSS_W:-/home/resources/evidence/cto/one-sequence-storage-2026-11-18/witnesses}"
S0F="${OSS_S0:-$OSS_W/../S0-COUNTS.tsv}"
SEAT="${S4E_SEAT:-anon}"
BASE="${OSS_BASELINE:-$OSS_W/../baselines/$SEAT.tsv}"
BASECOMMIT="$(sed -n 's/^# BASELINE-COMMIT: *\([0-9a-f]*\).*/\1/p' "$STEPS" 2>/dev/null | head -1)"
FIXED="/tmp/s4e/$SEAT/oss-count"
SCRIP_BIN="$S4E_SCRIP/scrip"
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
val_of() { awk -v k="$1" '$1==k && $2 ~ /^[0-9]+$/ && $2 > 0 {print $2}' "$2" 2>/dev/null | head -1; }
base_head_ok() { head -1 "$BASE" 2>/dev/null | grep -F -- "seat=$SEAT root=$S4E_SCRIP commit=$BASECOMMIT" > /dev/null; }
base_of() { base_head_ok || return; val_of "$1" "$BASE"; }
count_of() {
    local src="$OSS_W/$1" ref="$OSS_W/${1%.*}.ref" out line
    [ -f "$src" ] && [ -f "$ref" ] || { echo "REFUSE"; return; }
    out="$(cd "$SCR" && timeout -k 5 120 "$SCRIP_BIN" "$src" < /dev/null 2>/dev/null)"
    [ "$out" = "$(cat "$ref")" ] || { echo "WRONG"; return; }
    mkdir -p "$FIXED" || { echo "REFUSE"; return; }
    line="$(cd "$FIXED" && setarch -R bash "$S4E_HARNESS/scripts/util_instr_count.sh" -n 5 scrip "$src" < /dev/null 2>/dev/null | grep '^INSTR ')"
    echo "$line" | sed -n 's/.* total=\([0-9][0-9]*\) .*/\1/p' | grep -E '^[0-9]+$' || echo "REFUSE"
}
tok_kernel() {
    local which="$1" op="$2" file b w
    [ "$which" = A ] && file=kernel_a.sno || file=kernel_b.icn
    [ -f "$BASE" ] || { echo "REFUSE kernel$which:no-baseline-of-seat-$SEAT:write-it-with---write-baseline-at-$BASECOMMIT"; return; }
    base_head_ok || { echo "REFUSE kernel$which:baseline-not-this-seats-root-or-commit"; return; }
    b="$(base_of "kernel_$which")"; [ -n "$b" ] || { echo "REFUSE kernel$which:no-baseline-count"; return; }
    w="$(count_of "$file")"
    case "$w" in REFUSE) echo "REFUSE kernel$which:no-count"; return;; WRONG) echo "FAIL kernel$which:wrong-answer"; return;; esac
    case "$op" in
        le) [ "$w" -le $((b + b / 1000000)) ] && echo "PASS kernel$which:$w<=$b+1ppm" || echo "FAIL kernel$which:$w>$b+1ppm";;
        lt) [ "$w" -lt $((b - b / 1000000)) ] && echo "PASS kernel$which:$w<$b-1ppm" || echo "FAIL kernel$which:$w>=$b-1ppm";;
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
            baseline) [ -n "$(val_of kernel_A "$S0F")" ] && [ -n "$(val_of kernel_B "$S0F")" ] && [ "$(grep -c "^p[0-9][0-9]	" "$S0F" 2>/dev/null)" -ge 16 ] && echo "PASS baseline" || echo "FAIL baseline:$S0F";;
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
        [ -n "$BASECOMMIT" ] || refuse "the table names no BASELINE-COMMIT"
        head="$(git -C "$S4E_SCRIP" rev-parse HEAD 2>/dev/null)"
        case "$head" in "$BASECOMMIT"*) ;; *) refuse "the root is at ${head:0:10}, not the baseline commit $BASECOMMIT: check it out, make, run this again";; esac
        [ -z "$(git -C "$S4E_SCRIP" status --porcelain -uno 2>/dev/null)" ] || refuse "the root holds tracked edits; the baseline is the commit alone"
        [ -f "$BASE" ] && [ "${2:-}" != --force ] && refuse "$BASE exists; --force to write it again"
        a="$(count_of kernel_a.sno)"; b="$(count_of kernel_b.icn)"
        echo "$a $b" | grep -E '^[0-9]+ [0-9]+$' > /dev/null || refuse "a kernel did not count (A=$a B=$b)"
        mkdir -p "$(dirname "$BASE")" || refuse "cannot make $(dirname "$BASE")"
        printf '# seat=%s root=%s commit=%s; setarch -R util_instr_count.sh -n 5 scrip, TOTAL, %s\nkernel_A\t%s\nkernel_B\t%s\n' \
            "$SEAT" "$S4E_SCRIP" "$BASECOMMIT" "$(date '+%Y-%m-%d %H:%M %Z')" "$a" "$b" > "$BASE"
        cat "$BASE"; exit 0;;
    --probe)
        P="$SCR/probe"; mkdir -p "$P/w" "$P/src/x"; fails=0
        printf '```snobol4\n        OUTPUT = "ok"\nEND\n```\n' > "$P/w/g.md"; printf 'ok\n' > "$P/w/g.ref"; cp "$P/w/g.md" "$P/w/r.md"; printf 'no\n' > "$P/w/r.ref"
        printf 'int cap;\n' > "$P/src/x/f.h"
        cp "$OSS_W/kernel_a.sno" "$OSS_W/kernel_a.ref" "$OSS_W/kernel_b.icn" "$OSS_W/kernel_b.ref" "$P/w/"
        { printf 'kernel_A\t999999999999\nkernel_B\t1\n'; for i in $(seq -w 1 16); do printf 'p%s\tPASS\tPASS\n' "$i"; done; } > "$P/s0.tsv"
        { printf '# seat=%s root=%s commit=%s\nkernel_A\t999999999999\nkernel_B\t1\n' "$SEAT" "$S4E_SCRIP" "$BASECOMMIT"; } > "$P/base.tsv"
        { printf '# seat=someone_else root=%s commit=%s\nkernel_A\t999999999999\nkernel_B\t1\n' "$S4E_SCRIP" "$BASECOMMIT"; } > "$P/foreign.tsv"
        chk() { local want="$1"; shift; local got; got="$(OSS_W="$P/w" OSS_BASELINE="$P/base.tsv" S4E_SCRIP_PROBE=1 grade "$@" | awk '{print $1}' | head -1)"; [ "$got" = "$want" ] && echo "probe ok   $want $*" || { echo "probe FAIL want $want got $got: $*"; fails=1; }; }
        OSS_W="$P/w"; BASE="$P/base.tsv"; S0F="$P/s0.tsv"
        chk PASS docs=g; chk FAIL docs=r; chk REFUSE docs=missing
        chk PASS baseline; S0F="$P/none.tsv"; chk FAIL baseline; S0F="$P/s0.tsv"
        BASE="$P/foreign.tsv"; chk REFUSE kernelA=le; BASE="$P/none.tsv"; chk REFUSE kernelA=le; BASE="$P/base.tsv"
        chk PASS kernelA=le; chk FAIL kernelB=le; chk PASS kernelA=lt; chk FAIL kernelB=lt
        SAVE="$S4E_SCRIP"; S4E_SCRIP="$P/src"
        chk PASS 'grep=\bcap\b@x/f.h'; chk FAIL 'grep=\bbase\b@x/f.h'; chk REFUSE 'grep=cap@x/none.h'
        chk PASS 'nogrep=\bbase\b@x/f.h'; chk FAIL 'nogrep=\bcap\b@x/f.h;x/none.h'
        S4E_SCRIP="$SAVE"; chk REFUSE owed; chk REFUSE bogus
        [ "$fails" = 0 ] && { echo "PROBE GREEN"; exit 0; } || { echo "PROBE RED"; exit 1; };;
    *) refuse "usage: --list | --step N | --write-baseline [--force] | --probe";;
esac
