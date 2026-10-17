#!/usr/bin/env bash
export SCRIP_DIAG=0   # benchmarks run with every diagnostic off: the collector's self-checks and the node-id stores (Lon 2026-09-25, in-chat to the ceo: "For benchmarks turn off all diagnostic code."; ceo CEO-1262)
# SCRIP-only Icon/JCON benchmark runner — no icont/iconx oracle required.
# Runs each of the 10 benchmark programs under mode-3 (--run) and mode-4 (--compile+gcc),
# reports rc / output-line-count / mode-3==mode-4 byte-identity. Oracle column intentionally
# omitted (icon-master.zip absent this session). m3==m4 is a real correctness invariant
# (RULES: the two modes must be 1:1 corresponding).
S4E="${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"   # D-17 PORTABLE-HOME: the sibling root (all repos + oracles are siblings under ONE root; /home/claude2-style seat roots work with zero env; S4E_HOME overrides)
set -u
# ⭐ V2-5 GATE HONESTY: examining nothing (wiped/empty corpus) must exit UNPROVEN(2), never read as a pass.
. "$(dirname "$0")/lib_gate.sh"
SCRIP="${SCRIP:-$S4E/SCRIP/scrip}"
RTDIR="${RTDIR:-$S4E/SCRIP/out}"
CORPUS_SRC="${CORPUS_SRC:-$S4E/corpus/benchmarks/icon}"
WORK="${WORK:-/tmp/bench_scrip_only}"
TMO="${TMO:-30}"
rm -rf "$WORK"; mkdir -p "$WORK/corpus"
cp "$CORPUS_SRC"/*.icn "$CORPUS_SRC"/*.dat "$WORK/corpus/" 2>/dev/null
CORPUS="$WORK/corpus"
[ -x "$SCRIP" ] || { echo "FATAL: $SCRIP missing"; exit 2; }
[ -f "$RTDIR/libscrip_rt.so" ] || echo "WARN: $RTDIR/libscrip_rt.so missing — mode-4 will LINKFAIL"

# ipxref input: a real .icn source to cross-reference
IPXIN="$WORK/ipxref_input.icn"; cat "$CORPUS"/*.icn > "$IPXIN"

declare -A STDIN ARGS LINK
STDIN[concord]="$CORPUS/concord.dat"; ARGS[concord]="";        LINK[concord]=""
STDIN[deal]="";                       ARGS[deal]="-h 1000";     LINK[deal]=""
STDIN[geddump]="$CORPUS/geddump.dat"; ARGS[geddump]="";         LINK[geddump]=""
STDIN[ipxref]="$IPXIN";               ARGS[ipxref]="";          LINK[ipxref]=""
STDIN[queens]="";                     ARGS[queens]="-n10";      LINK[queens]=""
STDIN[rsg]="$CORPUS/rsg.dat";         ARGS[rsg]="";             LINK[rsg]=""
STDIN[tgrlink]="";                    ARGS[tgrlink]="$CORPUS/tgrlink.dat"; LINK[tgrlink]=""
progs="concord deal geddump ipxref queens rsg tgrlink"

printf "%-9s | %-26s | %-30s | %-7s\n" "PROGRAM" "SCRIP m3 (--run)" "SCRIP m4 (--compile)" "m3==m4"
printf "%-9s-+-%-26s-+-%-30s-+-%-7s\n" "---------" "--------------------------" "------------------------------" "-------"
p3=0; p4=0; ident=0; total=0; examined=0
for name in $progs; do
  total=$((total+1))
  sin="${STDIN[$name]:-}"; [ -z "$sin" ] && sin=/dev/null
  read -ra a <<< "${ARGS[$name]}"
  read -ra ld <<< "${LINK[$name]:-}"
  [ -f "$CORPUS/$name.icn" ] && examined=$((examined+1))

  # mode-3
  ( cd "$CORPUS" && timeout -k 5 "$TMO" "$SCRIP" --run "$name.icn" "${ld[@]}" -- "${a[@]}" >"$WORK/$name.m3.out" 2>"$WORK/$name.m3.err" <"$sin"; echo $? >"$WORK/$name.m3.rc" )
  rc3=$(cat "$WORK/$name.m3.rc")
  if [ "$rc3" = 0 ] && [ -s "$WORK/$name.m3.out" ]; then s3="OK $(wc -l <"$WORK/$name.m3.out")L"; p3=$((p3+1))
  elif [ "$rc3" = 0 ]; then s3="EMPTY-OUT"
  elif [ "$rc3" = 124 ]; then s3="TIMEOUT"
  else s3="FAIL rc=$rc3: $(head -c40 "$WORK/$name.m3.err"|tr '\n' ' ')"; fi

  # mode-4
  ( cd "$CORPUS" && timeout -k 5 "$TMO" "$SCRIP" --compile --target=x86 "$name.icn" "${ld[@]}" >"$WORK/$name.s" 2>"$WORK/$name.m4c.err" )
  if [ -s "$WORK/$name.s" ] && ! grep -q '\[SMX\]' "$WORK/$name.m4c.err"; then
    if gcc -no-pie "$WORK/$name.s" -L"$RTDIR" -lscrip_rt -Wl,-rpath,"$RTDIR" -o "$WORK/$name.bin" 2>"$WORK/$name.m4l.err"; then
      ( cd "$CORPUS" && timeout -k 5 "$TMO" "$WORK/$name.bin" "${a[@]}" >"$WORK/$name.m4.out" 2>"$WORK/$name.m4.err" <"$sin"; echo $? >"$WORK/$name.m4.rc" )
      rc4=$(cat "$WORK/$name.m4.rc")
      if [ "$rc4" = 0 ] && [ -s "$WORK/$name.m4.out" ]; then s4="OK $(wc -l <"$WORK/$name.m4.out")L"; p4=$((p4+1))
      elif [ "$rc4" = 0 ]; then s4="EMPTY-OUT"
      elif [ "$rc4" = 124 ]; then s4="TIMEOUT"
      else s4="RUNFAIL rc=$rc4"; fi
    else s4="LINKFAIL: $(grep -m1 'undefined reference' "$WORK/$name.m4l.err"|head -c40)"; fi
  else
    if grep -q '\[SMX\]' "$WORK/$name.m4c.err"; then s4="REFUSED"; else s4="COMPILEFAIL: $(tail -c50 "$WORK/$name.m4c.err"|tr '\n' ' ')"; fi
  fi

  # byte-identity m3 vs m4 (only meaningful if both produced output)
  if [ -s "$WORK/$name.m3.out" ] && [ -s "$WORK/$name.m4.out" ]; then
    if diff -q "$WORK/$name.m3.out" "$WORK/$name.m4.out" >/dev/null; then bi="YES"; ident=$((ident+1)); else bi="NO"; fi
  else bi="-"; fi

  printf "%-9s | %-26s | %-30s | %-7s\n" "$name" "$s3" "$s4" "$bi"
done
echo "---"
echo "scrip-m3(--run)=$p3/$total  scrip-m4(--compile)=$p4/$total  m3==m4 byte-identical=$ident/$total"
echo "files examined (source .icn found)=$examined/$total"
gate_floor "$examined" "$total" "programs found/opened"
exit 0
