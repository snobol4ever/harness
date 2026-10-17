#!/usr/bin/env bash
export SCRIP_DIAG=0   # benchmarks run with every diagnostic off: the collector's self-checks and the node-id stores (Lon 2026-09-25, in-chat to the ceo: "For benchmarks turn off all diagnostic code."; ceo CEO-1262)
# bench_sno_match4.sh — the 4-way SNOBOL4 match/eval benchmark protocol (s143).
# claws5/treebank/json (match-only, tape rep52) + calculator-1 (evaluator, tape rep10)
# vs official SPITBOL, interleaved A/B x7 medians.  RT_OPT is whatever libscrip_rt
# was built with (-O0 unless Lon directed otherwise) — LABEL REPORTED NUMBERS WITH IT.
# Same-moment interleaved pairs are the only valid comparison; absolute ms drift
# with host load across runs (s143: treebank 51<->71 same bytes).
S4E="${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"   # D-17 PORTABLE-HOME: the sibling root (all repos + oracles are siblings under ONE root; /home/claude2-style seat roots work with zero env; S4E_HOME overrides)
S4A="${S4E_ASSETS:-$([ -d "$S4E/x64" ] && echo "$S4E" || echo /home/resources)}"   # D-17b: ASSET root -- oracles/vendor trees live at the HQ root on this machine (Lon: seats carry ONLY .github/SCRIP/corpus); a root owning its own x64 (HQ, or a full standalone clone-set) is self-contained.
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; SCRIP="${SCRIP:-$HERE/../../SCRIP/scrip}"; RT="${RT_DIR:-$HERE/../../SCRIP/out}"
. "$HERE/lib_oracle_flags.sh" 2>/dev/null || { echo "REFUSING: cannot load lib_oracle_flags.sh -- the ONE oracle-flag authority (s200/s255)." >&2; exit 3; }
SBL="${SBL:-$(sbl_clean_bin)}"; CORPUS="${CORPUS:-$S4E/corpus}"; D="$CORPUS/demos"; W="${W:-$(mktemp -d)}"   # BENCHMARK oracle (s255)
[ -x "$SBL" ] || { echo "⛔ ORACLE ABSENT: $SBL — every ratio below would be fiction, not a benign gap (row oracle-two-face-adoption). Build /home/resources/spitbol-bench-oracle (see RULES.md Oracles) -- seats do not clone x64 (s255)." >&2; exit 3; }
# ⛔ RESOLVE BY SEARCH, REFUSE ON UNRESOLVABLE -- the flat `$D/<name>` lookup this replaced went silent the same
# way util_regen_demo_s_artifacts.sh did (row demo-regen-broken-subfolder-reorg): the s272 corpus re-grid moved
# every demo source/data file from $D/<name> to $D/snobol4/<family>/<name>, and a coincidental path is not an
# address -- a reorg ends the coincidence. Confirmed live: bare invocation raised python FileNotFoundError on
# every $D/$p.sno lookup, then "claws5-match BUILD FAIL", before this fix.
resolve1() { local hits n; hits="$(find "$D" -name "$1" -type f | sort)"; n="$(printf '%s\n' "$hits" | grep -c . || true)"
    [ "$n" -eq 1 ] || { echo "⛔ REFUSING: $1 resolved to $n file(s) under $D (want exactly 1) -- corpus moved or demo renamed/deleted:" >&2; printf '      %s\n' $hits >&2; exit 3; }
    printf '%s' "$hits"; }
input_of() { case $1 in claws5-match) resolve1 CLAWS5inTASA.dat;; treebank-match) resolve1 VBGinTASA.dat;; json-match) resolve1 twitter.json;; calculator-1-match|calculator-2-match) resolve1 calculator.input;; esac; }
mkrep() { python3 - "$1" "$2" "$3" << 'PYEOF'
import re, sys
src_path, out_path, reps = sys.argv[1], sys.argv[2], int(sys.argv[3])
lines = open(src_path).read().splitlines(); mi = None
for i, l in enumerate(lines):
    # (.+?) not (\S+): a src line's pattern expression can be multiple tokens (e.g. claws5-match's "?   claws"),
    # not always one bare name (e.g. json-match's "json") -- the old single-token regex silently NameError'd on
    # any multi-token pattern (claws5-match, treebank-match, calculator-1-match: 3 of the 5 default PROGS),
    # non-greedy so it still stops at the LAST "  :F(label)" rather than swallowing into it.
    m = re.match(r'^(\s*)src\s+(.+?)\s+:F\((\w+)\)\s*$', l)
    if m and 'INPUT' not in l: mi, ind, pat, flab = i, m.group(1), m.group(2), m.group(3)
tail = [ind+'tape           =  &LCASE &UCASE', ind+'tape           LEN(%d) . reps'%reps,
 'benchloop'.ljust(max(len(ind),10))+'src            '+pat+'                     :F('+flab+')',
 ind+'reps           LEN(1) =                    :S(benchloop)',
 ind+"OUTPUT         =  'matched bytes=' SIZE(src) :(END)", flab.ljust(len(ind))+"OUTPUT         =  'Pattern match failed'", 'END']
open(out_path,'w').write('\n'.join(lines[:mi]+tail)+'\n')
PYEOF
}
evalrep() { python3 - "$(resolve1 calculator-1.sno)" "$1" << 'PYEOF'
import sys
src = open(sys.argv[1]).read().splitlines()
cut = next(i for i,l in enumerate(src) if l.startswith('loop'))
head = '\n'.join(src[:cut]).replace('        &TRIM = 1','        &TRIM = 1\n        lines = ARRAY(200000)')
tail = """rd      n = n + 1
        lines[n] = INPUT                        :S(rd)
        n = n - 1
        tape = &LCASE &UCASE
        tape LEN(9) . reps
bl      k = 0
nx      k = k + 1
        GT(k, n)                                :S(od)
        sp = 0
        lines[k] C                              :F(bad2)
        total = total + DRF(S[1])               :(nx)
od      reps LEN(1) =                           :S(bl)
        OUTPUT = 'total=' total                 :(END)
bad2    OUTPUT = 'Boo!'                         :(END)
END"""
open(sys.argv[2],'w').write(head+'\n'+tail+'\n')
PYEOF
}
cd "$W"
REPS="${REPS:-20}"
PROGS="${PROGS:-claws5-match treebank-match json-match calculator-1-match calculator-2-match}"
_pcount=0; for _p in $PROGS; do _pcount=$((_pcount+1)); done   # ${VAR:-default} only substitutes on unset-or-empty-string; PROGS=" " (whitespace) survives it, and every `for p in $PROGS` loop below then word-splits to zero iterations while the script exits 0 -- silent, contentless success is worse than a printed all-zero table (row bench-sno-match4-progs-space-evasion)
[ "$_pcount" -gt 0 ] || { echo "⛔ REFUSING: PROGS is empty or whitespace-only after defaulting -- nothing to benchmark." >&2; exit 3; }
for p in $PROGS; do mkrep "$(resolve1 "$p.sno")" "$W/$p-rep.sno" "$REPS"; done
for p in $PROGS; do "$SCRIP" --compile "$W/$p-rep.sno" > "$W/$p.s" 2>/dev/null; gcc -no-pie "$W/$p.s" -L"$RT" -lscrip_rt -lm -Wl,-rpath,"$RT" -o "$W/$p.prog" 2>/dev/null || { echo "$p BUILD FAIL"; exit 1; }; done
for p in $PROGS; do IN=$(input_of $p)
  so=$(timeout -k 5 300 "$SBL" $(sbl_lang_flags) "$W/$p-rep.sno" < "$IN" 2>/dev/null); mo=$(timeout -k 5 300 "$W/$p.prog" < "$IN" 2>/dev/null)
  [ "$so" = "$mo" ] || { echo "$p IDENTITY FAIL sbl=[$so] m4=[$mo]"; exit 1; }
  s=(); m=()
  for i in 1 2 3 4 5 6 7; do t0=$(date +%s%N); "$SBL" $(sbl_lang_flags) "$W/$p-rep.sno" < "$IN" > /dev/null 2>&1; t1=$(date +%s%N); s+=( $(( (t1-t0)/1000000 )) )
    t0=$(date +%s%N); "$W/$p.prog" < "$IN" > /dev/null 2>&1; t1=$(date +%s%N); m+=( $(( (t1-t0)/1000000 )) ); done
  sm=$(printf '%s\n' "${s[@]}" | sort -n | sed -n 4p); mm=$(printf '%s\n' "${m[@]}" | sort -n | sed -n 4p)
  echo "$p: scrip_m4=${mm}ms sbl=${sm}ms ratio=$(python3 -c "print(f'{$mm/$sm:.2f}')") identity=OK"
done
