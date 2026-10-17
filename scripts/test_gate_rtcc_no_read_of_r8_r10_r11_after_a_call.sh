#!/usr/bin/env bash
# test_gate_rtcc_no_read_of_r8_r10_r11_after_a_call.sh -- EMITTED CODE NEVER READS r8, r10 OR r11 AFTER A CALL OR A POLL
# BEFORE IT WRITES IT, SO NOTHING SPILLS THEM INTO rtccb AND NOTHING RELOADS THEM (cto ruling-retire-the-r8-r10-r11-writeback-
# yes-with-a-standing-reader-gate, 2026-10-09, condition (1); hq_runtime).
#
# THE RETIREMENT IT HOLDS: the rtcc bracket around a C call and the poll wrote r8, r10 and r11 into rtccb+40, +56, +64 and
# reloaded them after; nothing in C reads those slots, and a masked asm leaf leaving a heap word in r8 or r10 had that word
# spilled into the block at the next poll (hq_collector, 3925 detections). The bracket now carries r9 alone (the GVA base) and
# r11 only under SCRIP_DIAG_REGS; the driver's entry trampolines load r9 alone. That is sound only while no emitted path reads
# one of the three after a call before a write, and this gate is that proof, so a template that starts reading r10 after a
# call reds here by name instead of breaking silently.
#
# ARMS: (a) the reader's selftest (eleven planted streams, the reload-skip fail-once among them); (b) MODE 4: every gc witness
# compiled to .s and graded at every call and every global entry, want reads=0; (c) MODE 3: the sealed slabs of six witnesses
# across the languages, dumped by gdb at bb_seal, cut at the slab's ZMAP frame-map block (the data the emitter appends after
# the last instruction, which a linear disassembly would read as code), disassembled by objdump, want reads=0; (d) THE PLANT,
# both media: a read of r8 inserted after the first call of a real witness stream reads red and names r8; (e) THE BRACKET IS
# GONE: no witness .s stores or reloads r8, r10 or r11 through rtccb; (f) THE DIAG ROAD (the cto's review, condition 2):
# five witnesses under SCRIP_DIAG_REGS=1 print exactly what they print without it, in both modes under stress 1, and
# carry r11 (its rtccb+64 reload) and not r8 or r10; a plant that drops r11 from the mask is seen.
# LIMIT, NAMED: a later call that takes r8 as its fifth argument without writing it is a read no stream reader can see.
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -uo pipefail
G="$(basename "${BASH_SOURCE[0]}" .sh)"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
SCRIP="${SCRIP_BIN:-$ROOT/scrip}"; [ -x "$SCRIP" ] || { echo "⛔ GATE REFUSE(2) [$G]: no scrip at $SCRIP"; exit 2; }
command -v gdb >/dev/null || { echo "⛔ GATE REFUSE(2) [$G]: gdb missing"; exit 2; }
command -v objdump >/dev/null || { echo "⛔ GATE REFUSE(2) [$G]: objdump missing"; exit 2; }
R="$HERE/util_rtcc_scratch_read_after_call.py"
WD="$HERE/gc_witnesses"
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
FAILS=0; ARMS=0
arm() { ARMS=$((ARMS+1)); if [ "$1" = ok ]; then echo "  ok    $2"; else echo "  FAIL  $2"; FAILS=$((FAILS+1)); fi; }
echo "=== gate: emitted code reads none of r8, r10, r11 after a call or a poll before it writes it ==="
python3 "$R" --selftest > "$T/self.txt" 2>&1
grep -q 'selftest: 0 FAIL' "$T/self.txt" && arm ok "(a) the reader's selftest: $(grep -c '  ok ' "$T/self.txt") planted streams graded as planted" || { cat "$T/self.txt"; arm fail "(a) the reader's selftest"; }
ASMS=(); n=0
for w in "$WD"/*.sno "$WD"/*.icn "$WD"/*.pl "$WD"/*.raku "$WD"/*.pas "$WD"/*.sc; do
    [ -f "$w" ] || continue
    o="$T/m4_$(basename "$w").s"
    timeout -k 5 60 "$SCRIP" --compile -o "$o" "$w" < /dev/null > /dev/null 2>&1 && [ -s "$o" ] && { ASMS+=(--asm "$o"); n=$((n+1)); }
done
[ "$n" -gt 0 ] || { echo "⛔ GATE REFUSE(2) [$G]: no witness compiled"; exit 2; }
python3 "$R" "${ASMS[@]}" --entry > "$T/m4.txt" 2>&1; rc=$?
head -1 "$T/m4.txt"
[ $rc -eq 0 ] && arm ok "(b) mode 4: $n witness .s, $(sed -n 's/.*sites=\([0-9]*\).*/\1/p' "$T/m4.txt" | head -1) call and entry sites, reads=0" || { sed -n '2,20p' "$T/m4.txt"; arm fail "(b) mode 4: a read of r8, r10 or r11 after a call (rc=$rc)"; }
SLABS=(); ns=0
for w in hb_arr.sno hb_datblk.sno hb_coexpr_sigma.icn hb_pl_findall.pl; do
    [ -f "$WD/$w" ] || continue
    d="$T/m3_$w"; mkdir -p "$d"
    printf 'set pagination off\nstart\nset $i = 0\nbreak bb_seal\ncommands\n  silent\n  eval "dump binary memory %s/slab_%%d.bin buf buf+size", $i\n  set $i = $i + 1\n  continue\nend\ncontinue\n' "$d" > "$d/g.cmds"
    timeout -k 5 120 gdb -batch -x "$d/g.cmds" --args "$SCRIP" "$WD/$w" < /dev/null > /dev/null 2>&1
    for s in "$d"/slab_*.bin; do
        [ -s "$s" ] || continue
        off=$(grep -obUaP 'ZMAP' "$s" | head -1 | cut -d: -f1)
        [ -n "$off" ] && { head -c "$off" "$s" > "$s.code"; } || cp "$s" "$s.code"
        objdump -D -b binary -m i386:x86-64 -M intel "$s.code" > "$s.dis" 2>/dev/null && { SLABS+=(--objdump "$s.dis"); ns=$((ns+1)); }
    done
done
if [ "$ns" -eq 0 ]; then arm fail "(c) mode 3: no slab was dumped -- the arm could not measure, never a pass"
else
    python3 "$R" "${SLABS[@]}" --entry > "$T/m3.txt" 2>&1; rc=$?
    head -1 "$T/m3.txt"
    [ $rc -eq 0 ] && arm ok "(c) mode 3: $ns sealed slabs, every call and every slab entry, reads=0" || { sed -n '2,20p' "$T/m3.txt"; arm fail "(c) mode 3: a read of r8, r10 or r11 after a call (rc=$rc)"; }
fi
p4="${ASMS[1]}"
awk 'BEGIN{d=0} {print} !d && $1=="call" {print "                        mov              rax, r8"; d=1}' "$p4" > "$T/plant.s"
python3 "$R" --asm "$T/plant.s" > "$T/p4.txt" 2>&1; rc4=$?
rc3=2
if [ "$ns" -gt 0 ]; then
    p3="${SLABS[1]}"
    awk 'BEGIN{d=0} {print} !d && $0 ~ /\tcall / {print "  ffff0:\t4c 89 c0             \tmov    rax,r8"; d=1}' "$p3" > "$T/plant.dis"
    python3 "$R" --objdump "$T/plant.dis" > "$T/p3.txt" 2>&1; rc3=$?
fi
[ $rc4 -eq 1 ] && grep -q 'READ .* r8 ' "$T/p4.txt" && [ $rc3 -eq 1 ] && grep -q 'READ .* r8 ' "$T/p3.txt" \
    && arm ok "(d) the plant: a read of r8 after the first call reads red by name in both media" \
    || arm fail "(d) the plant did not red (mode 4 rc=$rc4, mode 3 rc=$rc3) -- the detector fails open"
nb=$(cat "${ASMS[@]/--asm/}" 2>/dev/null | grep -cE 'rtccb\+(40|56|64)')
[ "$nb" -eq 0 ] && arm ok "(e) the bracket is gone: no witness .s spills or reloads r8, r10 or r11 through rtccb" || arm fail "(e) $nb rtccb+40/56/64 store or reload(s) remain in the witness .s"
run4() { "$SCRIP" --compile -o "$1.s" "$2" < /dev/null > /dev/null 2>&1 && gcc "$1.s" -L"$ROOT/out" -lscrip_rt -lm -lpthread -Wl,-rpath,"$ROOT/out" -o "$1" 2>/dev/null \
    && { SCRIP_GC_STRESS=1 timeout -k 5 120 "$1" < /dev/null; echo "rc=$?"; }; }
dbad=""; dn=0
for w in hb_arr.sno hb_datblk.sno hb_coexpr_sigma.icn hb_pl_findall.pl hb_cv_spine_plain_redo.icn; do
    [ -f "$WD/$w" ] || continue
    d="$T/diag_$w"; mkdir -p "$d"
    { SCRIP_GC_STRESS=1 timeout -k 5 120 "$SCRIP" "$WD/$w" < /dev/null; echo "rc=$?"; } > "$d/m3.plain" 2>&1
    { SCRIP_DIAG_REGS=1 SCRIP_GC_STRESS=1 timeout -k 5 120 "$SCRIP" "$WD/$w" < /dev/null; echo "rc=$?"; } > "$d/m3.diag" 2>&1
    run4 "$d/p" "$WD/$w" > "$d/m4.plain" 2>&1
    SCRIP_DIAG_REGS=1 run4 "$d/q" "$WD/$w" > "$d/m4.diag" 2>&1
    cmp -s "$d/m3.plain" "$d/m3.diag" || dbad="$dbad $w:m3"
    cmp -s "$d/m4.plain" "$d/m4.diag" || dbad="$dbad $w:m4"
    r11=$(grep -cE 'mov +r11, +qword ptr \[rip \+ rtccb\+64\]' "$d/q.s"); rest=$(grep -cE 'rtccb\+(40|56)' "$d/q.s")
    [ "$r11" -gt 0 ] && [ "$rest" -eq 0 ] || dbad="$dbad $w:r11=$r11,r8r10=$rest"
    dn=$((dn+1))
done
SCRIP_DIAG_REGS=1 SCRIP_RTCC_VENEER=2 "$SCRIP" --compile -o "$T/dplant.s" "$WD/hb_arr.sno" < /dev/null > /dev/null 2>&1
dpl=$(grep -cE 'mov +r11, +qword ptr \[rip \+ rtccb\+64\]' "$T/dplant.s")
[ "$dn" -eq 5 ] && [ -z "$dbad" ] && [ "$dpl" -eq 0 ] \
    && arm ok "(f) SCRIP_DIAG_REGS: $dn witnesses print the same with and without it in both modes under stress 1, r11 still carried and r8/r10 not; the plant that drops r11 (SCRIP_RTCC_VENEER=2) is seen" \
    || arm fail "(f) SCRIP_DIAG_REGS: graded $dn of 5;${dbad:- none differ}; plant r11 reloads=$dpl (want 0)"
echo "population: $ARMS arm(s), $FAILS FAIL; mode 4 $n witness .s, mode 3 $ns slab(s)"
[ $FAILS -eq 0 ] && { echo "✅ GATE GREEN [$G]"; exit 0; }
echo "⛔ GATE RED [$G]: $FAILS of $ARMS arms FAIL"; exit 1
