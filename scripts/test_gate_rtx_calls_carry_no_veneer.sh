#!/usr/bin/env bash
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
# test_gate_rtx_calls_carry_no_veneer.sh -- EMITTED CODE CALLS EVERY ASM-RUNTIME ENTRY BARE AND THROUGH THE GOT, AND EVERY
# CALL INTO THE C RUNTIME STILL CARRIES THE VENEER (cto 2026-09-23, CEO-1224, row
# spine-no-rtccb-veneer-on-any-call-into-the-asm-runtime-the-rtx-abi-preserves-r8-to-r11; Lon in-chat to the ceo, verbatim:
# "get rid of veneer for all RT ASM instances.").
#
# THE EMITTER HALF OF THE CONTRACT whose callee half test_gate_rtx_entries_keep_the_rtcc_four.sh proves. Before this row
# x86_rtcc_clob_raw() hand-listed thirteen asm callees and defaulted every other symbol to the full veneer, so 12,862 of
# 14,813 emitted calls into the asm runtime across the committed .s artifacts spilled r8/r10/r11 into g_rtccb and reloaded
# r8-r11 after (958 across this gate's thirteen witnesses at SCRIP 8a2e9bdff). The list is now DERIVED: the emitter asks
# rtx_entry_is(), which scans the rtx_entry_names section RTX_FUNC and RTX_ENTRY write.
#
# FOUR READINGS over two mode-4 compiles per language (the first two corpus/benchmarks programs of each of the seven):
#   (a) veneered calls into a registered entry -- a write-back into g_rtccb before, or a reload after, LOOKING THROUGH up to six
#       intervening moves that do not touch g_rtccb (hq_runtime 2026-10-07, on the cto's word: the bb_call_fn by-name road put a
#       mov ecx between its write-back and its call_bare and the adjacent-line read never saw it) -- must be 0, beyond the
#       DECLARED count (a2): the by-name road's hand veneer into rt_call_bid_sn4, measured 10 over the eight
#       benchmarks/snocone/parsers chains this gate also compiles, a ceiling that may only fall;
#   (b) calls into a registered entry through a PLT slot or a bare symbol must be 0: a lazily bound slot resolves through
#       _dl_runtime_resolve, which jumps to the callee through r11, so the FIRST call of every entry would hand the callee a
#       clobbered r10/r11 to "preserve" (mode 4 emits call qword ptr [rip + sym@GOTPCREL]; mode 3 calls by address);
#   (c) calls into a registered entry through the GOT must be > 0 -- the witnesses did reach the asm runtime;
#   (d) veneered calls into the C runtime must be > 0 -- the control: the veneer was kept where the callee is gcc's.
# NEGATIVE-TESTED IN EVERY RUN: one witness is recompiled under SCRIP_RTX_PLANT_VENEER=1, which hands the asm entries back
# the full veneer, and reading (a) must then be > 0 -- a count that cannot see a veneer when one is planted proves nothing.
#
# Usage: bash ../harness/scripts/test_gate_rtx_calls_carry_no_veneer.sh    (exit 0 = green, 1 = measured broken, 2 = could not measure)
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../SCRIP" && pwd)"
CORPUS="$ROOT/../corpus"
SO="$ROOT/out/libscrip_rt.so"
[ -x "$ROOT/scrip" ] || { echo "REFUSED(2): scrip is not built"; exit 2; }
[ -e "$SO" ] || { echo "REFUSED(2): $SO is missing"; exit 2; }
[ -d "$CORPUS/benchmarks" ] || { echo "REFUSED(2): no corpus/benchmarks beside this tree"; exit 2; }
command -v objcopy >/dev/null 2>&1 || { echo "REFUSED(2): objcopy is not installed"; exit 2; }
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
objcopy -O binary --only-section=rtx_entry_names "$(readlink -f "$SO")" "$WORK/names.bin" 2>/dev/null || { echo "REFUSED(2): the library has no rtx_entry_names section"; exit 2; }
n=0
for le in snobol4:sno icon:icn prolog:pl pascal:pas raku:raku snocone:sc rebus:reb; do
    l=${le%%:*}; e=${le#*:}
    for f in $(find "$CORPUS/benchmarks/$l" -type f -name "*.$e" | sort | head -2); do
        ( cd "$WORK" && timeout -k 5 60 "$ROOT/scrip" --compile --out="$WORK/w$n.s" "$f" < /dev/null > /dev/null 2>&1 ) && n=$((n+1))
    done
done
[ "$n" -ge 10 ] || { echo "REFUSED(2): only $n witnesses compiled (floor 10)"; exit 2; }
nb=0
for f in $(find "$CORPUS/benchmarks/snocone/parsers" -maxdepth 1 -type f -name 'parser_*.sc' | sort); do
    ( cd "$(dirname "$f")" && timeout -k 5 120 "$ROOT/scrip" --compile --out="$WORK/v$nb.s" "$(basename "$f")" < /dev/null > /dev/null 2>&1 ) && nb=$((nb+1))
done
[ "$nb" -ge 7 ] || { echo "REFUSED(2): only $nb by-name witnesses (benchmarks/snocone/parsers) compiled (floor 7)"; exit 2; }
plant_src=$(find "$CORPUS/benchmarks/icon" -type f -name "*.icn" | sort | head -1)
( cd "$WORK" && SCRIP_RTX_PLANT_VENEER=1 timeout -k 5 60 "$ROOT/scrip" --compile --out="$WORK/plant.s" "$plant_src" < /dev/null > /dev/null 2>&1 ) \
    || { echo "REFUSED(2): the plant witness did not compile"; exit 2; }
python3 - "$WORK" "$n" <<'PY'
import re, sys, glob, os
work, n = sys.argv[1], int(sys.argv[2])
names = set(x.decode('utf-8') for x in open(os.path.join(work, 'names.bin'), 'rb').read().split(b'\0') if x)
if len(names) < 200:
    print('REFUSED(2): the library registers %d entries (floor 200)' % len(names)); sys.exit(2)
WB = re.compile(r'^\s*mov\s+qword ptr \[rip \+ g_rtccb\+\d+\],\s*r(?:8|9|10|11)\s*$')
RL = re.compile(r'^\s*mov\s+r(?:8|9|10|11),\s*qword ptr \[rip \+ g_rtccb\+\d+\]\s*$')
CALL = re.compile(r'^\s*call\s+(?:qword ptr \[rip \+ ([^\]@\s]+)@GOTPCREL\]|([A-Za-z_.$][^\s@]*)(@PLT)?)\s*$')
MOVE = re.compile(r'^\s*(?:mov|movabs|lea|xor)\s')
def near(body, i, step, pat):
    j = i + step
    while 0 <= j < len(body) and abs(j - i) <= 6:
        if pat.match(body[j]): return True
        if not MOVE.match(body[j]) or 'g_rtccb' in body[j]: return False
        j += step
    return False
def read(path):
    c = dict(got=0, plt=0, ven=0, cven=0, vsym={})
    lines = open(path, encoding='utf-8', errors='replace').read().split('\n')
    body = [re.sub(r'^[^\s:]+:\s*', '', ln.split('#')[0].rstrip()) for ln in lines]
    for i, ln in enumerate(body):
        m = CALL.match(ln)
        if not m: continue
        sym = m.group(1) or m.group(2)
        nxt = body[i + 1] if i + 1 < len(body) else ''
        prv = body[i - 1] if i > 0 else ''
        veneered = bool(RL.match(nxt)) or bool(WB.match(prv)) or near(body, i, -1, WB) or near(body, i, 1, RL)
        if sym in names:
            if m.group(1): c['got'] += 1
            else: c['plt'] += 1
            if veneered: c['ven'] += 1; c['vsym'][sym] = c['vsym'].get(sym, 0) + 1
        elif veneered:
            c['cven'] += 1
    return c
tot = dict(got=0, plt=0, ven=0, cven=0)
vsym = {}
for p in sorted(glob.glob(os.path.join(work, 'w*.s')) + glob.glob(os.path.join(work, 'v*.s'))):
    r = read(p)
    for k in tot: tot[k] += r[k]
    for k, v in r['vsym'].items(): vsym[k] = vsym.get(k, 0) + v
KNOWN = {'rt_call_bid_sn4': 10}
over = {k: v - KNOWN.get(k, 0) for k, v in vsym.items() if v > KNOWN.get(k, 0)}
held = {k: min(v, KNOWN[k]) for k, v in vsym.items() if k in KNOWN}
tot['ven'] = sum(over.values())
pl = read(os.path.join(work, 'plant.s'))
print('=== %d witnesses + the by-name parser chains, %d registered entries ===' % (n, len(names)))
print('  (a) veneered calls into an asm entry ........ %d   (want 0)' % tot['ven'])
for k in sorted(KNOWN):
    print('  (a2) DECLARED hand veneer into %s ..... %d   (ceiling %d, may only fall: the bb_call_fn by-name road writes g_rtccb back and reloads it around its call_bare; the spine-bake row retires it)' % (k, held.get(k, 0), KNOWN[k]))
    if held.get(k, 0) < KNOWN[k]: print('       RATCHET: the count fell to %d -- lower KNOWN[%s] to it in this gate' % (held.get(k, 0), k))
print('  (b) asm-entry calls through a PLT or bare ... %d   (want 0)' % tot['plt'])
print('  (c) asm-entry calls through the GOT ......... %d   (want > 0)' % tot['got'])
print('  (d) veneered calls into the C runtime ....... %d   (want > 0, the control)' % tot['cven'])
print('  plant SCRIP_RTX_PLANT_VENEER=1, one witness:  veneered asm-entry calls %d   (want > 0: the count can see a veneer)' % pl['ven'])
bad = []
if tot['ven']: bad.append('(a) %d asm-entry calls still carry the veneer, beyond the declared ceiling: %s' % (tot['ven'], over))
if tot['plt']: bad.append('(b) %d asm-entry calls go through a PLT slot or a bare symbol' % tot['plt'])
if not tot['got']: bad.append('(c) no witness reached the asm runtime through the GOT -- nothing was measured')
if not tot['cven']: bad.append('(d) no call into the C runtime carries the veneer -- the control is gone')
if not pl['ven']: bad.append('the planted veneer was not seen -- the count is blind')
for b in bad: print('FAIL: ' + b)
if bad: sys.exit(1)
print('PASS: every asm-runtime call is bare and through the GOT; the C runtime keeps its veneer; the plant is seen.')
PY
