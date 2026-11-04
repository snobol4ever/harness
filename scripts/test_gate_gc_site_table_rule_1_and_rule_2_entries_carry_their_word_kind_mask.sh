#!/usr/bin/env bash
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
# test_gate_gc_site_table_rule_1_and_rule_2_entries_carry_their_word_kind_mask.sh -- THE THIRD QUAD AT RULE-1 AND RULE-2 SITES (ARCH-GC-COMPILE-TIME-FRAME-MAPS 16.1 (b), the cto
# 2026-10-30, R-2046; zeta-layout step 4a-2; the pool shared by prefix, the cto 2026-11-04, R-2118). The sibling gate holds the rule-0 and rule-4 entries; this one holds the rbp
# frames of Prolog, Raku and Icon (rule 1) and the flat generator (rule 2): such an entry's third quad is 0 (the site declares no cells) or NW in its HIGH 32 bits (the extent in
# 8-byte words of the run, w = 0 its oldest word) and in its LOW 32 bits a BYTE OFFSET from the table's first quad into the pool after the last entry, at which sit the mask words
# (bit w names the word at R + 8A - 8(w + 1), set on the first word of a DESCR cell, the planner's arrival carve stack folded from the word_kind column, CTO-504); the site reads
# ceil(NW / 64) of them. A, the run base's distance from R in words, rides in the entry's FOURTH quad (CTO-509): the run base is not rbp where the run sits on an INDEF base, so
# the anchor is the compile-time constant dk / 8 (zl03: a run at R + 80 to 192 under an rbp 1872 above R); it is 0 exactly when the third is 0, and NW never exceeds it. THE POOL IS SHARED BY PREFIX (R-2118): a site whose mask is a prefix of a longer site's mask points
# into that longer block, so a clause that builds a term cell by cell (every site one word deeper than the last) costs one block, not one per site; before it the pool was quadratic
# in a clause's size (hakank_swi_sudoku: 436,148 quads at 1,600 elements, the assembler killed at 8.3 GB). A LANDING site (kind 2) carries 0: its K is not the call's (Icon
# proc_gen landings overshoot their base by 40 bytes, measured).
# The gate compiles zl03 (Icon: rules 1 and 2), zl05 (Prolog: rule 1) and zl08 (Raku: rules 1 and 2) in mode 4 and reads their .Lgcsites tables: quads = 4 + 4n + pool; a rule 1 or
# rule 2 third quad is 0 or an aligned offset into the pool with NW >= 1 above it; the block at an offset holds at least ceil(NW / 64) words for every site naming it and no bit at
# or past the LARGEST NW naming it; the pool is tiled exactly by the longest block at each offset (rule 0 and 4 deep masks included); a kind-2 entry carries 0; every witness has a
# block with a set bit at rule 1 and the Icon and Raku witnesses one at rule 2 (so the check was exercised). Then each witness runs as a mode-4 binary under the collector's stress
# (every 8th poll collects; the step harness runs stress 1) with SCRIP_GC_CHAIN_CHECK=3, whose census (gc_told_window) reads the masks: its stdout must equal the ref, at least one
# rule-1 or rule-2 window must have been read, and no declared extent may reach past the site's anchor (declared_past_base 0). --corrupt sets a bit one word past the first
# block's largest extent (the static arm must read RED); --corrupt-over gives every kind-2 rule-1 or rule-2 entry of the Icon witness the largest block of its table, NW and all,
# and re-runs the census (declared_past_base must read above 0, RED); --flip clears the lowest set bit of the first rule-1 block of every zl05 table and re-runs it beside the unflipped binary:
# the mask bits the census reads (agree + mask_only + mask_scalar + outside, none of them run noise) must fall (RED).
# rc 0 held · rc 1 a bar unmet · rc 2 cannot measure (no scrip, no witness, a compile or link refused)
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIP="$(cd "$HERE/../../SCRIP" 2>/dev/null && pwd)" || { echo "REFUSE(2): no SCRIP beside harness"; exit 2; }
CORPUS="$(cd "$HERE/../../corpus" 2>/dev/null && pwd)" || { echo "REFUSE(2): no corpus beside harness"; exit 2; }
[ -x "$SCRIP/scrip" ] || { echo "REFUSE(2): $SCRIP/scrip is not built"; exit 2; }
MODE=0; case "${1:-}" in --corrupt) MODE=1 ;; --corrupt-over) MODE=2 ;; --flip) MODE=3 ;; "") ;; *) echo "REFUSE(2): usage: $0 [--corrupt | --corrupt-over | --flip]"; exit 2 ;; esac
W="$(mktemp -d "${TMPDIR:-/tmp}/gate_gcsite12.XXXXXX")" || { echo "REFUSE(2): mktemp failed"; exit 2; }
trap 'rm -rf "$W"' EXIT
D="$CORPUS/tests/shared/zeta_layout"
rc=0
for wit in zl03_icn_generators_coexpr.icn zl05_pl_assert_findall.pl zl08_rk_lists_hashes.raku; do
    n="${wit%.*}"; src="$D/$wit"
    [ -f "$src" ] && [ -f "$D/$n.ref" ] || { echo "REFUSE(2): no witness $wit or its ref in $D"; exit 2; }
    [ "$MODE" = 2 ] && [ "$n" != zl03_icn_generators_coexpr ] && continue
    [ "$MODE" = 3 ] && [ "$n" != zl05_pl_assert_findall ] && continue
    ( cd "$SCRIP" && timeout -k 2 300 ./scrip --compile --out="$W/$n.s" "$src" < /dev/null > /dev/null 2>&1 ) || { echo "REFUSE(2): $wit does not compile in mode 4"; exit 2; }
    [ "$MODE" = 3 ] && cp "$W/$n.s" "$W/$n.base.s"
    out="$(python3 - "$W/$n.s" "$MODE" "$n" <<'PY'
import re, sys
path, mode, name = sys.argv[1], int(sys.argv[2]), sys.argv[3]
lines = open(path, encoding='utf-8').read().split('\n')
tables = []
i = 0
while i < len(lines):
    m = re.match(r'^(\.Lgcsites_\S+):\s+\.quad\s+(\d+)', lines[i])
    if not m:
        i += 1
        continue
    q = []
    qi = []
    i += 1
    while i < len(lines) and not lines[i].strip().startswith('.popsection'):
        mm = re.match(r'^(\s+\.quad\s+)(.+)$', lines[i])
        if mm:
            q.append(mm.group(2).strip())
            qi.append(i)
        i += 1
    tables.append((m.group(1), int(m.group(2)), q, qi))
if not tables:
    print('NO-TABLES')
    sys.exit(0)
bad, blocks, setbits, landing = [], {1: 0, 2: 0}, {1: 0, 2: 0}, 0
done_corrupt = False
for k, (tname, n, q, qi) in enumerate(tables):
    if len(q) < 3 + 4 * n:
        bad.append('%s: %d quads after the count, want at least %d (3 header + 4 per entry)' % (tname, len(q), 3 + 4 * n))
        continue
    pool = q[3 + 4 * n:]
    lo = 32 + 32 * n
    refs = {}
    ents = []
    for e in range(n):
        w = int(q[3 + 4 * e + 1])
        third = int(q[3 + 4 * e + 2])
        anchor = int(q[3 + 4 * e + 3])
        kind, rule, depth = w & 0xFFFF, (w >> 16) & 0xFFFF, (w >> 32) & 0xFFFFFFFF
        ents.append((e, kind, rule, depth, third))
        if rule in (1, 2) and (third == 0) != (anchor == 0):
            bad.append('%s entry %d: rule %d third %#x with anchor %d (both or neither)' % (tname, e, rule, third, anchor))
        if rule in (1, 2) and third != 0 and (third >> 32) > anchor:
            bad.append('%s entry %d: rule %d NW %d past its anchor %d' % (tname, e, rule, third >> 32, anchor))
        if rule not in (0, 1, 2, 4) and anchor != 0:
            bad.append('%s entry %d: rule %d carries anchor %d' % (tname, e, rule, anchor))
        if rule in (1, 2):
            if (kind & 255) == 2 and third != 0:
                bad.append('%s entry %d: a LANDING site at rule %d carries a mask offset %d' % (tname, e, rule, third))
                landing += 1
            if third == 0:
                continue
            off, nw = third & 0xFFFFFFFF, third >> 32
            if off < lo or (off - lo) % 8 or (off - lo) // 8 >= len(pool):
                bad.append('%s entry %d: rule %d offset %d outside [%d, %d)' % (tname, e, rule, off, lo, lo + 8 * len(pool)))
                continue
            s = (off - lo) // 8
            if nw < 1:
                bad.append('%s entry %d: rule %d entry at %d states NW %d' % (tname, e, rule, s, nw))
                continue
            want = (nw + 63) // 64
            if s + want > len(pool):
                bad.append('%s entry %d: rule %d block at %d (NW %d) runs past the pool of %d words' % (tname, e, rule, s, nw, len(pool)))
                continue
            if s not in refs or nw > refs[s][2]:
                refs[s] = (want, rule, nw)
        elif rule in (0, 4) and depth > 512 and third:
            if third < lo or (third - lo) % 8 or (third - lo) // 8 + (depth // 8 + 63) // 64 > len(pool):
                bad.append('%s entry %d: rule %d pool offset %d outside the pool' % (tname, e, rule, third))
            else:
                refs[(third - lo) // 8] = ((depth // 8 + 63) // 64, rule, 0)
    if mode == 1 and not done_corrupt:
        for s, (ln, rule, nw) in sorted(refs.items()):
            if rule in (1, 2) and nw % 64:
                pool[s + nw // 64] = str(int(pool[s + nw // 64]) | (1 << (nw % 64)))
                done_corrupt = True
                break
    if mode == 3:
        for s, (ln, rule, nw) in sorted(refs.items()):
            ws = [int(x) for x in pool[s:s + (nw + 63) // 64]]
            if rule == 1 and any(ws):
                wi = next(i for i, x in enumerate(ws) if x)
                bit = ws[wi] & -ws[wi]
                pool[s + wi] = str(ws[wi] & ~bit)
                lines[qi[3 + 4 * n + s + wi]] = re.sub(r'(\.quad\s+)\S+$', lambda m: m.group(1) + pool[s + wi], lines[qi[3 + 4 * n + s + wi]])
                break
    for s, (ln, rule, nw) in sorted(refs.items()):
        if rule not in (1, 2):
            continue
        words = [int(x) for x in pool[s:s + (nw + 63) // 64]]
        blocks[rule] += 1
        if any(words):
            setbits[rule] += 1
        top = nw % 64
        if words and top and (words[-1] >> top) != 0:
            bad.append('%s: rule %d block at %d has a bit at or past its extent NW %d' % (tname, rule, s, nw))
    pos = 0
    for s in sorted(refs):
        ln = refs[s][0]
        if s != pos:
            bad.append('%s: the pool is not tiled by its blocks (word %d, next block at %d)' % (tname, pos, s))
            pos = s
        pos = s + ln
    if pos != len(pool) and not any(t.startswith(tname) for t in bad):
        bad.append('%s: the pool holds %d words, the blocks reach %d' % (tname, len(pool), pos))
    if mode == 2:
        big = None
        for s, (ln, rule, nw) in refs.items():
            if rule in (1, 2) and (big is None or nw > refs[big][2]):
                big = s
        if big is not None:
            for (e, kind, rule, depth, third) in ents:
                if rule in (1, 2) and (kind & 255) == 2 and third == 0:
                    lines[qi[3 + 4 * e + 2]] = re.sub(r'(\.quad\s+)\S+$', lambda m: m.group(1) + str((lo + 8 * big) | (refs[big][2] << 32)), lines[qi[3 + 4 * e + 2]])
                    landing += 1
if mode in (2, 3):
    open(path, 'w', encoding='utf-8').write('\n'.join(lines))
print('TABLES %d RULE1_BLOCKS %d RULE1_SET %d RULE2_BLOCKS %d RULE2_SET %d LANDING_MASKED %d BAD %d' % (len(tables), blocks[1], setbits[1], blocks[2], setbits[2], landing, len(bad)))
for b in bad[:6]:
    print('  BAD ' + b)
PY
)"
    echo "SITE_TABLE12 $n: $(printf '%s\n' "$out" | head -1)"
    printf '%s\n' "$out" | sed -n '2,$p'
    if [ "$MODE" != 2 ]; then
        printf '%s\n' "$out" | head -1 | grep -q 'BAD 0$' || rc=1
        printf '%s\n' "$out" | head -1 | grep -qE 'RULE1_SET [1-9]' || { echo "RED: $n has no rule-1 block with a set bit -- the check was not exercised"; rc=1; }
        case "$n" in zl03_*|zl08_*) printf '%s\n' "$out" | head -1 | grep -qE 'RULE2_SET [1-9]' || { echo "RED: $n has no rule-2 block with a set bit -- the check was not exercised"; rc=1; } ;; esac
    fi
    if [ "$MODE" = 3 ]; then
        rc=0; ag=""
        for v in base flip; do
            sv="$W/$n.s"; [ "$v" = base ] && sv="$W/$n.base.s"
            gcc -m64 "$sv" -o "$W/$n.$v.bin" -L"$SCRIP/out" -lscrip_rt -lm -lpthread -Wl,-rpath,"$SCRIP/out" 2> "$W/$n.gcc" || { echo "REFUSE(2): $n.$v does not link"; exit 2; }
            ( cd "$W" && env -u SCRIP_HEAP_MB SCRIP_GC_CHAIN_CHECK=3 SCRIP_GC_STRESS=8 SCRIP_HEAP_KB=128 SCRIP_HEAP_MAX_MB=512 timeout -k 5 600 "$W/$n.$v.bin" -d131072k -s4096k < /dev/null > "$W/$n.$v.out" 2> "$W/$n.$v.err" )
            ag="$ag $(awk '/^\[GC-TOLD\] SUMMARY /{ for (i = 1; i <= NF; i++) { split($i, a, "="); if (a[1] == "agree" || a[1] == "mask_only" || a[1] == "mask_scalar" || a[1] == "outside") t += a[2] } } END { print t + 0 }' "$W/$n.$v.err")"
        done
        set -- $ag
        echo "FLIP $n: mask bits the census read, base $1, the first set bit of each table's first rule-1 block cleared $2"
        [ "$1" -ge 1 ] || { echo "REFUSE(2): $n base census read no mask bit -- nothing for a cleared bit to lose"; exit 2; }
        [ "$2" -lt "$1" ] && rc=1
        continue
    fi
    [ "$MODE" = 1 ] && continue
    if ! gcc -m64 "$W/$n.s" -o "$W/$n.bin" -L"$SCRIP/out" -lscrip_rt -lm -lpthread -Wl,-rpath,"$SCRIP/out" 2> "$W/$n.gcc"; then echo "REFUSE(2): $n does not link"; head -3 "$W/$n.gcc"; exit 2; fi
    ( cd "$W" && env -u SCRIP_HEAP_MB SCRIP_GC_CHAIN_CHECK=3 SCRIP_GC_STRESS=8 SCRIP_HEAP_KB=128 SCRIP_HEAP_MAX_MB=512 timeout -k 5 600 "$W/$n.bin" -d131072k -s4096k < /dev/null > "$W/$n.out" 2> "$W/$n.err" )
    if [ "$MODE" != 2 ] && ! cmp -s "$W/$n.out" "$D/$n.ref"; then echo "RED: $n mode 4 under SCRIP_GC_STRESS=8 differs from its ref"; rc=1; fi
    cen="$(awk '/^\[GC-TOLD\] RULE12-MASKS /{ for (i = 1; i <= NF; i++) { split($i, a, "="); if (a[1] == "windows") w += a[2]; if (a[1] == "declared_past_base") o += a[2] } } END { printf "%d %d", w, o }' "$W/$n.err")"
    echo "CENSUS12 $n: rule-1/2 mask windows read $(echo "$cen" | cut -d' ' -f1), declared past the frame base $(echo "$cen" | cut -d' ' -f2)"
    [ "$(echo "$cen" | cut -d' ' -f1)" -ge 1 ] || { echo "RED: $n census read no rule-1 or rule-2 mask -- the check was not exercised"; rc=1; }
    if [ "$MODE" = 2 ]; then [ "$(echo "$cen" | cut -d' ' -f2)" -ge 1 ] && rc=1; continue; fi
    [ "$(echo "$cen" | cut -d' ' -f2)" -eq 0 ] || { echo "RED: $n declares an extent past the frame base"; rc=1; }
done
[ "$MODE" = 3 ] && { [ "$rc" -eq 1 ] && echo "GATE RED [gc_site_table_rule_1_and_rule_2_entries_carry_their_word_kind_mask] (--flip: the census read fewer mask bits after cleared bits)" || echo "NOT RED: --flip did not lower the mask bits the census read"; exit "$rc"; }
[ "$MODE" = 2 ] && { [ "$rc" -eq 1 ] && echo "GATE RED [gc_site_table_rule_1_and_rule_2_entries_carry_their_word_kind_mask] (--corrupt-over: a landing mask past its base was read)" || echo "NOT RED: --corrupt-over did not make the census read a past-base extent"; exit "$rc"; }
[ "$rc" -eq 0 ] && echo "GATE OK [gc_site_table_rule_1_and_rule_2_entries_carry_their_word_kind_mask]: every rule-1 and rule-2 entry is 0 or NW over an offset to its mask words (shared by prefix), the blocks tile the pool, no landing is masked, no extent passes its base, three witnesses run under stress" \
    || echo "GATE RED [gc_site_table_rule_1_and_rule_2_entries_carry_their_word_kind_mask]"
exit $rc
