#!/usr/bin/env bash
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
# test_gate_gc_site_table_entries_are_three_quads_and_carry_their_word_kind_mask.sh -- THE SPINE WALK IS TOLD ITS CELLS (ARCH-GC-COMPILE-TIME-FRAME-MAPS 16 step (2), the
# cto 2026-10-29, CEO-2011). Every site entry of the GC site table is {pc_off, w, mask}: w = kind | rule << 16 | depth << 32, and mask the word-kind bits of a rule 0 or
# rule 4 site over [r + 8, r + depth) -- bit j the word at r + 8 + 8j, set on the first word of a DESCR cell -- inline in the third quad when depth is at most 512 bytes,
# else a BYTE OFFSET from the table's first quad into a pool of mask words after the last entry (never a pointer). The planner's per-node arrival mask (znode_t wkoff,
# folded from the word_kind column of harness/scripts/box_cell_shapes.tsv) is shifted by the site's depth below the arrival point. Every other rule carries 0.
# The gate compiles two SNOBOL4 core entries in mode 4, reads their .Lgcsites tables and holds: quads = 4 + 3n + pool; an inline mask has no bit at or past depth/8; an
# offset lands inside the pool and the pool holds ceil(depth/512) words for it; a rule that is neither 0 nor 4 carries 0; the small program has at least one nonzero inline
# mask and the deep program at least one pool entry (so the check was exercised); and both programs run to their refs in mode 3 and as a mode-4 binary under
# SCRIP_GC_STRESS=1, which walks the stack through the 24-byte entries. --corrupt drops one quad from the first table (the script's own switch, no seam in SCRIP) and must
# read RED.
# rc 0 held · rc 1 a bar unmet · rc 2 cannot measure (no scrip, no partition entry, a compile refused)
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIP="$(cd "$HERE/../../SCRIP" 2>/dev/null && pwd)" || { echo "REFUSE(2): no SCRIP beside harness"; exit 2; }
CORPUS="$(cd "$HERE/../../corpus" 2>/dev/null && pwd)" || { echo "REFUSE(2): no corpus beside harness"; exit 2; }
[ -x "$SCRIP/scrip" ] || { echo "REFUSE(2): $SCRIP/scrip is not built"; exit 2; }
CORRUPT=0; [ "${1:-}" = "--corrupt" ] && CORRUPT=1
W="$(mktemp -d "${TMPDIR:-/tmp}/gate_gcsite3.XXXXXX")" || { echo "REFUSE(2): mktemp failed"; exit 2; }
trap 'rm -rf "$W"' EXIT
D="$CORPUS/tests/snobol4"
rc=0
for entry in user_function_eval_arbno_branch_1 user_function_fence_span_replace_branch_1; do
    src="$W/$entry.sno"
    python3 "$HERE/corpus_suite_harness.py" extract "$D/ALL.sno" "$D/ALL.ref" "$entry" "$src" --out-ref "$W/$entry.ref" --out-in "$W/$entry.in" > /dev/null 2>&1 || { echo "REFUSE(2): cannot extract $entry"; exit 2; }
    [ -s "$src" ] || { echo "REFUSE(2): $entry extracted empty"; exit 2; }
    ( cd "$SCRIP" && timeout -k 2 120 ./scrip --compile --out="$W/$entry.s" "$src" < /dev/null > /dev/null 2>&1 ) || { echo "REFUSE(2): $entry does not compile in mode 4"; exit 2; }
    out="$(python3 - "$W/$entry.s" "$CORRUPT" "$entry" <<'PY'
import re, sys
path, corrupt, entry = sys.argv[1], sys.argv[2] == '1', sys.argv[3]
lines = open(path, encoding='utf-8').read().split('\n')
tables = []
i = 0
while i < len(lines):
    m = re.match(r'^(\.Lgcsites_\S+):\s+\.quad\s+(\d+)', lines[i])
    if not m:
        i += 1
        continue
    q = []
    i += 1
    while i < len(lines) and not lines[i].strip().startswith('.popsection'):
        mm = re.match(r'^\s+\.quad\s+(.+)$', lines[i])
        if mm:
            q.append(mm.group(1).strip())
        i += 1
    tables.append((m.group(1), int(m.group(2)), q))
if not tables:
    print('NO-TABLES')
    sys.exit(0)
bad, nz_inline, pool_entries, entries = [], 0, 0, 0
for k, (name, n, q) in enumerate(tables):
    if corrupt and k == 0 and q:
        q = q[:-1]
    if len(q) < 3 + 3 * n:
        bad.append('%s: %d quads after the count, want at least %d (3 header + 3 per entry)' % (name, len(q), 3 + 3 * n))
        continue
    pool = q[3 + 3 * n:]
    need = 0
    for e in range(n):
        w = int(q[3 + 3 * e + 1])
        third = int(q[3 + 3 * e + 2])
        rule, depth = (w >> 16) & 0xFFFF, (w >> 32) & 0xFFFFFFFF
        entries += 1
        if rule not in (0, 4):
            if third != 0:
                bad.append('%s entry %d: rule %d carries a mask %#x' % (name, e, rule, third))
            continue
        if depth <= 512:
            if depth % 8 == 0 and (third >> (depth // 8)) != 0:
                bad.append('%s entry %d: inline mask %#x has a bit at or past depth/8 = %d' % (name, e, third, depth // 8))
            if third:
                nz_inline += 1
        elif third:
            pool_entries += 1
            nw = (depth // 8 + 63) // 64
            lo = 32 + 24 * n
            if third < lo or (third - lo) % 8 or (third - lo) // 8 + nw > len(pool):
                bad.append('%s entry %d: pool offset %d outside [%d, %d) for %d words' % (name, e, third, lo, lo + 8 * len(pool), nw))
            need = max(need, (third - lo) // 8 + nw)
    if len(pool) != need and not bad:
        bad.append('%s: the pool holds %d words, the entries use %d' % (name, len(pool), need))
print('TABLES %d ENTRIES %d NONZERO_INLINE %d POOL_ENTRIES %d BAD %d' % (len(tables), entries, nz_inline, pool_entries, len(bad)))
for b in bad[:6]:
    print('  BAD ' + b)
PY
)"
    echo "SITE_TABLE $entry: $(printf '%s\n' "$out" | head -1)"
    printf '%s\n' "$out" | sed -n '2,$p'
    printf '%s\n' "$out" | head -1 | grep -q 'BAD 0$' || rc=1
    case "$entry" in
        user_function_eval_arbno_branch_1) printf '%s\n' "$out" | head -1 | grep -qE 'NONZERO_INLINE [1-9]' || { echo "RED: $entry has no nonzero inline mask -- the check was not exercised"; rc=1; } ;;
        user_function_fence_span_replace_branch_1) printf '%s\n' "$out" | head -1 | grep -qE 'POOL_ENTRIES [1-9]' || { echo "RED: $entry has no pool entry -- the pool path was not exercised"; rc=1; } ;;
    esac
    [ "$CORRUPT" = 1 ] && continue
    inp="$W/$entry.in"; [ -f "$inp" ] || inp=/dev/null
    got="$( cd "$SCRIP" && timeout -k 2 120 ./scrip "$src" < "$inp" 2>&1 )"
    [ "$got" = "$(cat "$W/$entry.ref")" ] || { echo "RED: $entry mode 3 differs from its ref"; rc=1; }
    got="$( cd "$SCRIP" && SCRIP_GC_STRESS=1 timeout -k 2 300 ./scrip "$src" < "$inp" 2>&1 )"
    [ "$got" = "$(cat "$W/$entry.ref")" ] || { echo "RED: $entry mode 3 under SCRIP_GC_STRESS=1 differs from its ref"; rc=1; }
    if gcc -m64 "$W/$entry.s" -o "$W/$entry.bin" -L"$SCRIP/out" -lscrip_rt -Wl,-rpath,"$SCRIP/out" -lm 2> /dev/null; then
        got="$( SCRIP_GC_STRESS=1 timeout -k 2 300 "$W/$entry.bin" < "$inp" 2>&1 )"
        [ "$got" = "$(cat "$W/$entry.ref")" ] || { echo "RED: $entry mode 4 under SCRIP_GC_STRESS=1 differs from its ref"; rc=1; }
    else echo "REFUSE(2): $entry does not link"; exit 2; fi
done
[ "$rc" -eq 0 ] && echo "GATE OK [gc_site_table_entries_are_three_quads_and_carry_their_word_kind_mask]: every entry is {pc, w, mask}, the masks sit inside their depth, the pool offsets land, both programs run under stress" \
    || echo "GATE RED [gc_site_table_entries_are_three_quads_and_carry_their_word_kind_mask]"
exit $rc
