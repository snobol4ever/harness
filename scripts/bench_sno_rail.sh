#!/usr/bin/env bash
export SCRIP_DIAG=0   # benchmarks run with every diagnostic off: the collector's self-checks and the node-id stores (Lon 2026-09-25, in-chat to the ceo: "For benchmarks turn off all diagnostic code."; ceo CEO-1262)
# bench_sno_rail.sh — SNOBOL4 demo MEASUREMENT RAIL (s147, replaces the fixed-N wall protocol).
# Van-Roy-style adequacy + TIME() self-timing: the bench loop times ITSELF in-program
# (compute_ms via TIME() delta), so process startup/link/compile are excluded EXACTLY —
# no startup-floor estimation.  N auto-ranges x4 per engine until compute >= MIN_MS
# (default 800ms; cap NMAX 16384), making the window a controlled variable.  R rounds
# (default 5) interleaved sbl/scrip(O0so)/scrip(O2so); medians; per-iteration us.
# WHY: 2026-07-24 all-day variance postmortem — every demo below ~1s window swung 1.4x-3.9x
# run-to-run while calculator-1 (the one >=2s window) held 1.96-2.09 across ALL conditions.
# Window inadequacy + startup contamination was the disease; ratios from sub-100ms wall are BOGUS.
# .so swap: programs link -L$SODIR -rpath $SODIR; caller stages rt variants there.
S4E="${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"   # D-17 PORTABLE-HOME: the sibling root (all repos + oracles are siblings under ONE root; /home/claude2-style seat roots work with zero env; S4E_HOME overrides)
S4A="${S4E_ASSETS:-$([ -d "$S4E/x64" ] && echo "$S4E" || echo /home/resources)}"   # D-17b: ASSET root -- oracles/vendor trees live at the HQ root on this machine (Lon: seats carry ONLY .github/SCRIP/corpus); a root owning its own x64 (HQ, or a full standalone clone-set) is self-contained.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; SCRIP="${SCRIP:-$HERE/../../SCRIP/scrip}"
. "$HERE/lib_oracle_flags.sh" 2>/dev/null || { echo "REFUSING: cannot load lib_oracle_flags.sh -- the ONE oracle-flag authority (s200/s255). A private fallback would time a DIFFERENT LANGUAGE or the wrong binary. Fix the checkout; do not work around this." >&2; exit 3; }
SBL="${SBL:-$(sbl_clean_bin)}"; CORPUS="${CORPUS:-$S4E/corpus}"   # BENCHMARK oracle (s255) -- never x64/bin/sbl, it is instrumented ~2.2-3.5x slower
[ -x "$SBL" ] || { echo "⛔ ORACLE ABSENT: $SBL — us/iter numbers below would be fiction, not a benign gap. Build /home/resources/spitbol-bench-oracle (see RULES.md Oracles) -- seats do not clone x64 (s255)." >&2; exit 3; }
D="$CORPUS/demos"; W="${W:-$(mktemp -d)}"; SODIR="${SODIR:-/tmp}"
MIN_MS="${MIN_MS:-800}"; NMAX="${NMAX:-16384}"; R="${R:-5}"
SO_A="${SO_A:-/tmp/rt_o0.so}"; SO_B="${SO_B:-}"   # SO_B empty = single-config mode
DEMO="${1:?usage: bench_sno_rail.sh <demo-stem e.g. json-match>}"
case $DEMO in claws5-match|claws5-match-fence) IN=$D/CLAWS5inTASA.dat;;
  treebank-match|treebank-match-fence) IN=$D/VBGinTASA.dat;;
  json-match|json-match-fence) IN=$D/twitter.json;;
  calculator-1-match|calculator-2-match|calculator-1-match-fence|calculator-2-match-fence) IN=$D/calculator.input;;
  *) echo "unknown demo $DEMO"; exit 1;; esac
gen() { python3 - "$D/$DEMO.sno" "$2" "$1" << 'PY'
import re, sys
src, out, n = sys.argv[1], sys.argv[2], int(sys.argv[3])
L = open(src).read().splitlines(); mi = None
for i, l in enumerate(L):
    m = re.match(r'^(\s*)src\s+(\S+)\s+:F\((\w+)\)\s*$', l)
    if m and 'INPUT' not in l: mi, ind, pat, flab = i, m.group(1), m.group(2), m.group(3)
lab = 'benchloop'.ljust(max(len(ind), 10))
tail = [ind + "reps           =  DUPL('x', %d)" % n,
        ind + "BENCH.T0       =  TIME()",
        lab + 'src            ' + pat + '                     :F(' + flab + ')',
        ind + "reps           LEN(1) =                    :S(benchloop)",
        ind + "BENCH.T1       =  TIME()",
        ind + "OUTPUT         =  'compute_ms=' (BENCH.T1 - BENCH.T0)",
        ind + "OUTPUT         =  'matched bytes=' SIZE(src) :(END)",
        flab.ljust(max(len(ind), len(flab) + 1)) + "OUTPUT         =  'Pattern match failed'",
        'END']
open(out, 'w').write('\n'.join(L[:mi] + tail) + '\n')
PY
}
runsbl() { timeout -k 5 300 "$SBL" $(sbl_lang_flags) "$1" < "$IN" 2>/dev/null; }
runscr() { timeout -k 5 300 "$1" < "$IN" 2>/dev/null; }
msof()   { sed -n 's/^compute_ms=//p' | head -1; }
build()  { "$SCRIP" --compile "$1" > "$W/b.s" 2>/dev/null && gcc -no-pie "$W/b.s" -L"$SODIR" -Wl,-rpath,"$SODIR" -lscrip_rt -lm -o "$2" 2>/dev/null; }
# ---- identity gate at N=4 (compute_ms lines stripped) ----
gen 4 "$W/id.sno"; cp "$SO_A" "$SODIR/libscrip_rt.so"
build "$W/id.sno" "$W/id.prog" || { echo "$DEMO BUILD-FAIL"; exit 1; }
diff <(runsbl "$W/id.sno" | grep -v '^compute_ms=') <(runscr "$W/id.prog" | grep -v '^compute_ms=') > /dev/null \
  || { echo "$DEMO IDENTITY-FAIL"; exit 1; }
# ---- auto-range N per engine ----
arange() { # $1 = sbl|scr  -> echoes chosen N
  local n=4 ms
  while :; do
    gen "$n" "$W/a.sno"
    if [ "$1" = sbl ]; then ms=$(runsbl "$W/a.sno" | msof)
    else build "$W/a.sno" "$W/a.prog" || { echo 0; return; }; ms=$(runscr "$W/a.prog" | msof); fi
    [ -n "$ms" ] || { echo 0; return; }
    [ "$ms" -ge "$MIN_MS" ] && { echo "$n"; return; }
    [ "$n" -ge "$NMAX" ] && { echo "$n"; return; }
    n=$((n * 4))
  done
}
NS=$(arange sbl); cp "$SO_A" "$SODIR/libscrip_rt.so"; NC=$(arange scr)
[ "$NS" -gt 0 ] && [ "$NC" -gt 0 ] || { echo "$DEMO AUTORANGE-FAIL NS=$NS NC=$NC"; exit 1; }
gen "$NS" "$W/s.sno"
gen "$NC" "$W/c.sno"; cp "$SO_A" "$SODIR/libscrip_rt.so"; build "$W/c.sno" "$W/c.prog" || { echo "$DEMO BUILD-FAIL"; exit 1; }
# ---- R interleaved rounds ----
A=""; B=""; S=""
for r in $(seq "$R"); do
  S="$S $(runsbl "$W/s.sno" | msof)"
  cp "$SO_A" "$SODIR/libscrip_rt.so"; A="$A $(runscr "$W/c.prog" | msof)"
  if [ -n "$SO_B" ]; then cp "$SO_B" "$SODIR/libscrip_rt.so"; B="$B $(runscr "$W/c.prog" | msof)"; fi
done
python3 - "$DEMO" "$NS" "$NC" "$S" "$A" "$B" << 'PY'
import sys, statistics as st
demo, ns, nc = sys.argv[1], int(sys.argv[2]), int(sys.argv[3])
tok = lambda s: [int(x) for x in s.split()] if s.strip() else []
s, a, b = tok(sys.argv[4]), tok(sys.argv[5]), tok(sys.argv[6])
ms, ma = st.median(s), st.median(a)
ps, pa = ms * 1000.0 / ns, ma * 1000.0 / nc
line = f"{demo}: sbl {ps:.1f}us/iter (N={ns}, win={ms:.0f}ms)  scripA {pa:.1f}us/iter (N={nc}, win={ma:.0f}ms)  ratioA={pa/ps:.2f}"
if b:
    mb = st.median(b); pb = mb * 1000.0 / nc
    line += f"  scripB {pb:.1f}us/iter (win={mb:.0f}ms)  ratioB={pb/ps:.2f}"
print(line + "  identity=OK")
PY
