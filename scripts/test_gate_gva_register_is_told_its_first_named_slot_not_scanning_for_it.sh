#!/usr/bin/env bash
set -u
cd "$(dirname "$0")/../../SCRIP" || exit 1
../harness/scripts/util_require_fresh.sh --gate "$(basename "$0" .sh)" || exit $?
# test_gate_gva_register_is_told_its_first_named_slot_not_scanning_for_it.sh -- THE COMPILER KNOWS WHICH SLOT OF THE GLOBAL-NAME TABLE IS THE FIRST NAMED ONE, SO IT PASSES THAT INDEX AND gva_register DOES NOT WALK
# THE LEADING NULL SLOTS (row icon-speed-the-empty-icon-program-starts-in-at-most-400000-user-instructions-ceo-2035).
# ⛔ THE MEASURED DEFECT: an empty Icon program passes gva_register n = 741 slots and EVERY name is NULL (__gva_names is 741 zero quads, the hidden reserve), and gva_register ran
# `while (k0 < n && !names[k0]) k0++` over all of them: at -O0 about 12 instructions a slot, 8,700 of the 9,400 user instructions the function costs (hardware counter, skip-experiment 2026-11-04).
# The emitter writes `.quad 0` for exactly the slots whose gva_note is empty, so the first named slot is known at compile time: gva_register(names, cells, n, first) takes it as its fourth argument.
# THREE ARMS. STATIC: in every Icon and SNOBOL4 benchmark that registers globals (mode 4), the `mov ecx, K` before `call gva_register@PLT` equals the number of leading `.quad 0` in __gva_names (K is
# neither more nor less: more would skip a named slot, less would only cost the scan back). STRUCTURE: no scan of the names for the first non-null remains in gva_register, and the three callers
# (the emitter, the mode-3 driver, the SC module) pass a fourth argument. BEHAVIOURAL: one Icon witness with globals first named at slot 0, at later slots, a procedure name that shadows a builtin, and
# a global that is never assigned, run in BOTH modes byte-equal to the oracle (Arizona icont 9.5.25a), the oracle's output carrying the lines compared.
# FAIL-ONCE: STATIC and STRUCTURE are red on SCRIP 00580d758 (no mov ecx before the call; the scan loop present). No plant anywhere in src/.
# Board line: GVA_FIRST_BOARD programs=<p> with_call=<c> match=<m> mismatch=<x> structure=<ok|bad> m3=<same|differs> m4=<same|differs> (tree <hash>)
# rc 0 all arms green · rc 1 an arm red, named · rc 2 cannot measure (no oracle, no benchmarks, a program did not compile, the witness did not build).
NAME=gva_register_is_told_its_first_named_slot_not_scanning_for_it
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(pwd)"
refuse() { echo "⛔ GATE REFUSE(2) [$NAME]: $*"; exit 2; }
. "$HERE/lib_oracle_flags.sh" || refuse "cannot source lib_oracle_flags.sh"
ICONT="$(icont_bin)" || refuse "no icont oracle (lib_oracle_flags icont_bin) -- a missing oracle prints a full, plausible, entirely false all-FAIL table"
ICONX="$(iconx_bin)" || refuse "no iconx oracle"
[ -f "$ROOT/out/libscrip_rt.so" ] || refuse "out/libscrip_rt.so missing -- run make"
B="$ROOT/../corpus/benchmarks"
ls "$B"/icon/*.icn >/dev/null 2>&1 || refuse "no Icon benchmarks at $B/icon"
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
cat > "$W/chk.py" <<'EOS'
import re, sys
L = open(sys.argv[1], encoding='utf-8', errors='replace').read().split('\n')
st = [l.strip() for l in L]
calls = [i for i, l in enumerate(st) if re.match(r'call\s+gva_register@PLT', l)]
if not calls: print('NOCALL'); sys.exit(0)
try: t = next(i for i, l in enumerate(st) if l == '__gva_names:')
except StopIteration: print('BAD no __gva_names table'); sys.exit(0)
z = 0
for l in st[t + 1:]:
    if re.match(r'\.quad\s+0$', l): z += 1
    elif l.startswith('.quad'): break
    else: break
m = None
for j in range(calls[0] - 1, max(calls[0] - 10, 0), -1):
    mm = re.match(r'mov\s+ecx,\s*(\d+)$', st[j])
    if mm: m = int(mm.group(1)); break
if m is None: print('BAD no mov ecx before the call (table has %d leading zero quads)' % z); sys.exit(0)
print('OK' if m == z else 'BAD mov ecx,%d but %d leading zero quads' % (m, z))
EOS
bad=0; progs=0; withcall=0; match=0; mism=0
for f in "$B"/icon/*.icn "$B"/snobol4/*.sno; do
    [ -f "$f" ] || continue
    timeout -k 5 120 ./scrip --compile --out="$W/b.s" "$f" < /dev/null >/dev/null 2>&1 || refuse "$(basename "$f") did not compile in mode 4 -- the count would not cover the population"
    progs=$((progs + 1))
    r=$(python3 -I "$W/chk.py" "$W/b.s")
    case "$r" in
        NOCALL) ;;
        OK) withcall=$((withcall + 1)); match=$((match + 1));;
        *) withcall=$((withcall + 1)); mism=$((mism + 1)); bad=1; echo "  STATIC RED: $(basename "$f"): $r";;
    esac
done
[ "$withcall" -gt 0 ] || refuse "no benchmark registers globals -- the census would be empty"
structure=ok
if grep -n -E 'while \(k0 < n && !names\[k0\]\) k0\+\+' src/runtime/rt/rt.c > "$W/scan.txt"; then structure=bad; bad=1; echo "  STRUCTURE RED: gva_register still scans the leading null names: $(head -1 "$W/scan.txt" | cut -c1-120)"; fi
if ! grep -q -E 'DESCR_t \*gva_register\(const char \*\*names, DESCR_t \*cells, int n, int first\)' src/runtime/rt/rt.c; then structure=bad; bad=1; echo "  STRUCTURE RED: gva_register does not take the first named slot as its fourth argument"; fi
for pat in 'gva_register(m3_gva_nms, (DESCR_t \*)m3_gva_arena, n_gva_m3, ' 'gva_register(d->gva_names, m->base, (int)d->n_gva, '; do
    grep -q -F -- "$(echo "$pat" | sed 's/\\//g')" src/driver/scrip.c src/runtime/rt/rt_sc_module.c || { structure=bad; bad=1; echo "  STRUCTURE RED: a caller of gva_register does not pass the fourth argument ($pat)"; }
done
cat > "$W/w.icn" <<'EOS'
global g0, g1, g2
global never
procedure write(a, b, c, d);
    return &null;
end
procedure show(label, v);
    return;
end
procedure bump(n);
    g1 +:= n;
    return g1;
end
procedure main();
    local s;
    g0 := 7;
    g1 := 10;
    g2 := "str";
    s := bump(5) + g0;
    every i := 1 to 3 do g1 +:= i;
    stop(g0, " ", g1, " ", g2, " ", s, " ", image(never), " ", type(g2), " ", *g2);
end
EOS
( cd "$W" && "$ICONT" -s -o oracle_bin w.icn >/dev/null 2>&1 ) || refuse "the oracle did not build the witness"
( cd "$W" && timeout -k 5 60 "$ICONX" oracle_bin < /dev/null > oracle.out 2>&1 )
grep -qaF -- "7 21 str 22 &null string 3" "$W/oracle.out" || refuse "the oracle's output lacks the answer line: [$(head -c 160 "$W/oracle.out")] -- the comparison would be empty against empty"
( cd "$W" && timeout -k 5 120 "$ROOT/scrip" w.icn < /dev/null > m3.out 2>&1 )
( cd "$W" && timeout -k 5 120 "$ROOT/scrip" --compile --out=w.s w.icn < /dev/null >/dev/null 2>&1 && gcc w.s -o w4 -L"$ROOT/out" -lscrip_rt -lm -lpthread -Wl,-rpath,"$ROOT/out" >/dev/null 2>&1 ) || refuse "the witness did not build in mode 4"
( cd "$W" && timeout -k 5 60 ./w4 < /dev/null > m4.out 2>&1 )
m3=same; m4=same
cmp -s "$W/oracle.out" "$W/m3.out" || { m3=differs; bad=1; echo "  BEHAVIOURAL RED: mode 3 differs from the oracle:"; diff -a "$W/oracle.out" "$W/m3.out" | head -6; }
cmp -s "$W/oracle.out" "$W/m4.out" || { m4=differs; bad=1; echo "  BEHAVIOURAL RED: mode 4 differs from the oracle:"; diff -a "$W/oracle.out" "$W/m4.out" | head -6; }
echo "GVA_FIRST_BOARD programs=$progs with_call=$withcall match=$match mismatch=$mism structure=$structure m3=$m3 m4=$m4 (tree $(git rev-parse --short HEAD))"
[ "$bad" = 0 ] && { echo "GATE OK [$NAME]: $withcall programs pass the first named slot and it equals the table's leading zero quads, no scan is left, and the witness equals the oracle in both modes"; exit 0; }
echo "GATE FAIL [$NAME]"; exit 1
