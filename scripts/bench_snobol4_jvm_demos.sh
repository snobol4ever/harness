#!/usr/bin/env bash
# bench_snobol4_jvm_demos.sh [demo-stem ...] -- the WORK-HORSE DEMOS of corpus/demos/snobol4 on snobol4jvm, pristine SPITBOL and CSNOBOL4, start-up reported apart (hq_jvm;
# Lon 2026-11-01: "You must break out the startup time away from the other numbers and report those seperately."; demos are work-horse benchmarks, Lon 2026-09-27, R-1313).
# Each demo runs ONCE on the input its <stem>.workhorse sidecar declares (the stdin file repeated `scale` times, DEMO-SCALE.tsv), in a scratch copy of its directory with
# corpus/include copied beside it (the oracles resolve -INCLUDE from their working directory): SPITBOL (the benchmark build, spitbol-bench-oracle/sbl: minimal patches, no monitor hooks; -bf and the demo's declared oracle_args), CSNOBOL4,
# and the jar through run_snobol4jvm.sh with the demo's declared -d/-s. The measure is user instructions (perf stat -e instructions:u, R-2035) and the wall clock of that run.
# START-UP is measured first, on an empty program (bare, without the timeout guard the demo runs carry), five runs per engine, median instructions and fastest wall; every figure printed after it is the engine's TOTAL LESS ITS OWN START-UP.
# A jar figure under 1 G is inside the spread of its start-up (about 0.3 G) and prints as "start-up only"; SPITBOL's counts resolve to about 1 M. An engine whose output differs from SPITBOL's
# prints n/a, never a number. A total is a total, not a slope: a demo has no iteration loop (DEMO-SCALE.tsv).
# USE: bash harness/scripts/bench_snobol4_jvm_demos.sh [demo-stem ...]      all 24 by default (the jar needs about 10 minutes for them: treebank alone takes 400 s)
# EXIT: 0 printed; 2 could not measure (no perf, no oracle, a demo with a refused sidecar).
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; . "$HERE/lib_paths.sh"; DEMOS="$S4E_CORPUS/demos/snobol4"
. "$HERE/lib_oracle_flags.sh" || { echo "REFUSE(2): lib_oracle_flags.sh unloadable"; exit 2; }
. "$HERE/lib_declared_arena.sh" || { echo "REFUSE(2): lib_declared_arena.sh unloadable"; exit 2; }
SBL="$(sbl_clean_bin)" || exit 2; SBLF="$(sbl_lang_flags snobol4)"; CSN="$(csnobol4_bin)" || exit 2
PERF=""; for p in perf /usr/lib/linux-tools-*/perf; do command -v "$p" >/dev/null 2>&1 || [ -x "$p" ] || continue; "$p" stat -x, -e instructions:u -o /dev/null true >/dev/null 2>&1 && { PERF="$p"; break; }; done
[ -n "$PERF" ] || { echo "REFUSE(2): no perf that counts instructions:u on this kernel"; exit 2; }
W="$(mktemp -d "${TMPDIR:-/tmp}/bench_jvm_demos.XXXXXX")" || exit 2; trap 'rm -rf "$W"' EXIT
STEMS=("$@"); if [ ${#STEMS[@]} -eq 0 ]; then while IFS= read -r f; do STEMS+=("$(basename "$f" .workhorse)"); done < <(cd "$DEMOS" && find . -name '*.workhorse' | sort); fi
run() { local name="$1"; shift; /usr/bin/time -f '%e' -o "$W/t" "$PERF" stat -e instructions:u -x, -o "$W/ps" ${GUARD-timeout -k 5 900} "$@" < "$W/in" > "$W/out.$name" 2> "$W/err.$name"; RC=$?; WALL="$(tail -1 "$W/t")"; INSTR="$(awk -F, '/instructions/ {print $1}' "$W/ps")"; }
med() { sort -n | awk '{v[NR]=$1} END {print v[int((NR+1)/2)]}'; }
printf 'END\n' > "$W/empty.sno"; : > "$W/in"
for e in sbl csn jar; do
    : > "$W/su.$e"; wmin=999
    for i in 1 2 3 4 5; do
        case "$e" in sbl) GUARD= run sbl "$SBL" $SBLF "$W/empty.sno";; csn) GUARD= run csn "$CSN" "$W/empty.sno";; jar) GUARD= run jar bash "$HERE/run_snobol4jvm.sh" "$W/empty.sno";; esac
        echo "$INSTR" >> "$W/su.$e"; wmin="$(awk -v a="$wmin" -v b="$WALL" 'BEGIN {print (b < a) ? b : a}')"
    done
    eval "SU_$e=$(med < "$W/su.$e")"; eval "SUW_$e=$wmin"
done
: > "$W/rows.tsv"
for s in "${STEMS[@]}"; do
    wh="$(cd "$DEMOS" && find . -name "$s.workhorse" | head -1)"; [ -n "$wh" ] || { echo "REFUSE(2): no workhorse sidecar for $s"; exit 2; }
    d="$(dirname "$wh")"; src="$DEMOS/$d/$s.sno"
    stdin="$(awk -F'\t' '$1=="stdin" {print $2}' "$DEMOS/$wh")"; scale="$(awk -F'\t' '$1=="scale" {print $2}' "$DEMOS/$wh")"
    rm -rf "$W/d"; cp -r "$DEMOS/$d" "$W/d"; cp -n "$S4E_CORPUS"/include/* "$W/d/" 2>/dev/null; : > "$W/in"
    [ "$stdin" = - ] || for i in $(seq 1 "$scale"); do cat "$DEMOS/$d/$stdin" >> "$W/in"; done
    oa="$(declared_oracle_args_beside "$src")" || exit 2; sw="$(declared_switches_beside "$src")" || exit 2
    export SNO_LIB="$W/d:$S4E_CORPUS/include" SNOPATH="$W/d:$S4E_CORPUS/include"
    ( cd "$W/d" || exit 2
      run sbl "$SBL" $SBLF $oa "$s.sno"; sI=$INSTR; sW=$WALL
      run csn "$CSN" "$s.sno"; cI=$INSTR; cW=$WALL
      run jar bash "$HERE/run_snobol4jvm.sh" $sw "$s.sno"; jI=$INSTR; jW=$WALL
      ca=same; cmp -s "$W/out.csn" "$W/out.sbl" || ca=differs; ja=same; cmp -s "$W/out.jar" "$W/out.sbl" || ja=differs
      printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$s" "$scale" "$(stat -c %s "$W/in")" "$sI" "$cI" "$jI" "$sW" "$cW" "$jW" "$ca" "$ja" >> "$W/rows.tsv" )
done
SU_SBL="$SU_sbl" SU_CSN="$SU_csn" SU_JAR="$SU_jar" SUW_SBL="$SUW_sbl" SUW_CSN="$SUW_csn" SUW_JAR="$SUW_jar" python3 - "$W/rows.tsv" <<'PY'
import os, sys
su = {k: float(os.environ["SU_" + k.upper()]) for k in ("sbl", "csn", "jar")}
suw = {k: float(os.environ["SUW_" + k.upper()]) for k in ("sbl", "csn", "jar")}
def fmt(v): return f"{v/1e9:.2f} G" if v >= 1e9 else (f"{v/1e6:.1f} M" if v >= 1e6 else f"{v/1e6:.2f} M")
def size(b): return "—" if b == 0 else (f"{b/1e6:.1f} MB" if b >= 1e6 else f"{b/1e3:.0f} KB")
print("START-UP (empty program, 5 runs, median instructions and fastest wall; subtracted from every figure below)")
print(f"  SPITBOL    {fmt(su['sbl'])}  {suw['sbl']:.2f} s")
print(f"  CSNOBOL4   {fmt(su['csn'])}  {suw['csn']:.2f} s")
print(f"  snobol4jvm {fmt(su['jar'])}  {suw['jar']:.2f} s")
print()
print("| Demo | Input (scale) | jar | SPITBOL | CSNOBOL4 | jar / SPITBOL | jar / CSNOBOL4 | Net wall: jar / SPITBOL / CSNOBOL4 |")
print("|---|---:|---:|---:|---:|---:|---:|---:|")
for line in open(sys.argv[1]):
    n, sc, ib, sg, cg, jg, sw, cw, jw, ca, ja = line.rstrip("\n").split("\t")
    sW, cW, jW = float(sg) - su["sbl"], float(cg) - su["csn"], float(jg) - su["jar"]
    jt = "start-up only" if jW < 1e9 else fmt(jW)
    st = "<1 M" if sW < 1e6 else fmt(sW)
    ct = fmt(cW) if ca == "same" else "n/a"
    r1 = "—" if sW < 5e6 or jW < 1e9 or ja != "same" else f"{jW/sW:,.0f}×"
    r2 = "—" if ca != "same" or cW < 5e6 or jW < 1e9 or ja != "same" else f"{jW/cW:,.0f}×"
    w = lambda t, k: max(0.0, float(t) - suw[k])
    wt = f"{w(jw,'jar'):.1f} s / {w(sw,'sbl'):.2f} s / " + (f"{w(cw,'csn'):.2f} s" if ca == "same" else "n/a")
    if ja != "same": jt = "OUTPUT DIFFERS"
    print(f"| {n} | {(size(int(ib)) + ' (×' + sc + ')') if int(ib) else '—'} | {jt} | {st} | {ct} | {r1} | {r2} | {wt} |")
PY
