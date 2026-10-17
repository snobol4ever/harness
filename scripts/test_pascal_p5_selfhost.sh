#!/usr/bin/env bash
# test_pascal_p5_selfhost.sh -- Pascal-P5 self-hosting, the SECOND Pascal milestone, with a WORK time per program
#
# Lon to the coo 2026-09-12, verbatim: "If P5 has self hosting, then make that a second milestone." and "For each P4
# and P5 self host test, ensure the speed performance is measured for each program." The P4 twin is
# ../harness/scripts/test_pascal_p4_selfhost.sh and this script prints the same shape of verdict.
#
# P5 ships TWO halves and its own preprocessing step, which is not optional: source/pcom.pas (the compiler, 6771 lines)
# and source/pint.pas (the interpreter, 3168 lines) both begin with C-preprocessor lines that no Pascal compiler reads,
# fpc -Miso included. P5's own bin/pascpp runs cpp over them; this script runs the same cpp invocation directly so the
# step is visible in the log rather than hidden in a vendor wrapper. The sources are the vendored copies in
# corpus/packages/pascal/p5/source (upstream f730c1c03, byte for byte); P5_DIR names another package directory.
#
# THE FLOW (measured 2026-10-09 by hq_pascal): scrip runs pcom.pas preprocessed WITHOUT -DSELF_COMPILE -- that flavour reads its
# source from the file `prd` and writes P-code to the file `prr` -- and the source it is asked to compile is pcom.pas preprocessed
# WITH -DSELF_COMPILE (the flavour a P-code interpreter can run: it reads standard input). Generation 1 is that compile. The
# interpreter half is a known-answer probe: scrip-compiled pcom compiles P5's hello sample, scrip-compiled pint runs the P-code
# and the transcript (from its second line, the first is each program's banner) must equal P5's own hello.cmp. Generation 2 is
# pint running the generation-1 P-code (the compiler, compiled by itself) over a source: pint reads the program from the file prd and the
# interpreted program goes on reading the same file, so prd holds the P-code followed by the source. Two sources: P5's hello (the quick
# probe, minutes: its P-code must equal the native compiler's) and pcom.pas itself (the full generation 2, hours at today's interpreter speed:
# GEN2_TIMEOUT_S bounds it, and a timeout reads BLOCKED); the verdict compares the full run's P-code with generation 1's.
#
# Declared sizes (RULES.md hard-cap clause 8 (g)): pint's store is sixteen million cells and needs a declared arena; PCOM_HEAP_KB and
# PINT_HEAP_KB are the declarations, passed as -d<kb>k to every run of that program.
#
# Verdict line: "P5_SELFHOST: pre=<rc> pcom=<rc|BLOCKED> pint=<match|differs|BLOCKED> gen1_pcode_lines=<n> gen1_native=<identical|differs|unavailable> gen1_hello=<identical|differs> gen2=<rc|BLOCKED> pcode_identical=<yes|no|n/a>"
# then "SELFHOST OK" (gen2 reproduced gen1's P-code), "SELFHOST PARTIAL" (both halves run, the P-code differs) or
# "SELFHOST BLOCKED" (a half cannot run, with the reason printed).
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
SCRIP="${SCRIP_BIN:-$ROOT/scrip}"; [ -x "$SCRIP" ] || { echo "⛔ REFUSE(2): no scrip at $SCRIP"; exit 2; }
P5="${P5_DIR:-$ROOT/../corpus/packages/pascal/p5}"; SRC="$P5/source"; SMP="$P5/sample_programs"
[ -f "$SRC/pcom.pas" ] && [ -f "$SRC/pint.pas" ] || { echo "⛔ REFUSE(2): no Pascal-P5 pcom.pas and pint.pas at $SRC"; exit 2; }
[ -f "$SMP/hello.pas" ] && [ -f "$SMP/hello.cmp" ] || { echo "⛔ REFUSE(2): no P5 hello sample and transcript at $SMP"; exit 2; }
command -v cpp >/dev/null || { echo "⛔ REFUSE(2): no cpp -- P5's own preprocessing step cannot run"; exit 2; }
PCOM_HEAP_KB="${PCOM_HEAP_KB:-800000}"; PINT_HEAP_KB="${PINT_HEAP_KB:-800000}"; GEN2_TIMEOUT_S="${GEN2_TIMEOUT_S:-900}"
W=$(mktemp -d) || exit 2; trap 'rm -rf "$W"' EXIT
TREE="SCRIP=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY) RT_OPT=-O0 mode=m3 oracle-note=fpc-Miso-refuses-both-halves-unpreprocessed"
echo "P5 self-host on $TREE"
# ---- the preprocessing step, timed, one WORK line per product ------------------------------------------------------
prerc=0
pre() { local out="$1" defs="$2" half="$3"
  /usr/bin/time -f "%e %M" -o "$W/tp_$out" cpp -P -nostdinc -traditional-cpp $defs "$SRC/$half.pas" > "$W/$out.pas" 2>"$W/$out.cpp.err"
  local rc=$?; [ "$rc" -eq 0 ] || prerc=$rc
  read -r s k < <(tail -1 "$W/tp_$out"); case "$s" in ""|*[!0-9.]*) s=unmeasured; k=unmeasured;; esac
  echo "WORK $out.pas(preprocess $half.pas, P5's own cpp step) wall=${s}s rss=${k}KB lines=$(wc -l < "$W/$out.pas")  ($TREE)"; }
pre pcom "-DWRDSIZ32" pcom
pre pcom_self "-DWRDSIZ32 -DSELF_COMPILE" pcom
pre pint "-DWRDSIZ32" pint
[ "$prerc" -eq 0 ] || { echo "P5_SELFHOST: pre=$prerc pcom=BLOCKED pint=BLOCKED gen1_pcode_lines=0 gen2=BLOCKED pcode_identical=n/a"; echo "SELFHOST BLOCKED (P5's preprocessing step failed: rc=$prerc)"; exit 1; }
# ---- half 1: the compiler compiles its own source (generation 1) ---------------------------------------------------
cp "$W/pcom_self.pas" "$W/prd"
( cd "$W" && rm -f prr && /usr/bin/time -f "%e %M" -o "$W/t1" timeout -k 5 900s "$SCRIP" -d${PCOM_HEAP_KB}k --run pcom.pas -- prd prr < /dev/null > pcom.out 2> pcom.err ); pcomrc=$?
read -r s1 k1 < <(tail -1 "$W/t1"); case "$s1" in ""|*[!0-9.]*) s1=unmeasured; k1=unmeasured;; esac
echo "WORK pcom.pas(gen1, compiling its own preprocessed source) wall=${s1}s rss=${k1}KB  ($TREE)"
g1lines=$(wc -l < "$W/prr" 2>/dev/null); g1lines=${g1lines:-0}
g1errs=$(grep -c 'Errors in program: 0' "$W/pcom.out" 2>/dev/null)
echo "pcom: rc=$pcomrc out_lines=$(wc -l < "$W/pcom.out") pcode_lines=$g1lines no_errors=$g1errs $(grep -v '^Command' "$W/pcom.err" | head -c 160 | tr '\n' ' ')"
if [ "$pcomrc" -ne 0 ] || [ "$g1lines" -eq 0 ]; then
  echo "P5_SELFHOST: pre=0 pcom=$pcomrc pint=BLOCKED gen1_pcode_lines=$g1lines gen2=BLOCKED pcode_identical=n/a"
  echo "SELFHOST BLOCKED (the compiler half did not produce P-code: pcom rc=$pcomrc)"
  exit 1
fi
cp "$W/prr" "$W/gen1.pcode"
# ---- the native oracle: P5's own compiler built by fpc from the same preprocessed source compiles the same program -------------
FPC="${FPC_BIN:-/usr/bin/fpc}"; gnat=unavailable
if [ -x "$FPC" ]; then
  mkdir -p "$W/native"; cp "$W/pcom.pas" "$W/native/pcom_fpc.pas"; cp "$W/pcom_self.pas" "$W/native/prd"
  if ( cd "$W/native" && "$FPC" -Miso -v0 -opcom_fpc pcom_fpc.pas >/dev/null 2>&1 && timeout -k 5 300s ./pcom_fpc prd prr < /dev/null > native.out 2>&1 ); then
    if cmp -s "$W/native/prr" "$W/gen1.pcode"; then gnat=identical; else gnat=differs; fi
  fi
fi
echo "native: fpc-built pcom on the same source -> gen1 P-code $gnat ($( [ -f "$W/native/prr" ] && wc -l < "$W/native/prr" || echo 0) lines)"
# ---- half 2: the interpreter, a known-answer probe: P5's hello sample through scrip-compiled pcom and pint ---------
cp "$SMP/hello.pas" "$W/prd"
( cd "$W" && rm -f prr && timeout -k 5 300s "$SCRIP" -d${PCOM_HEAP_KB}k --run pcom.pas -- prd prr < /dev/null > hello_c.out 2> hello_c.err ); hcrc=$?
cp "$W/prr" "$W/hello.pcode" 2>/dev/null; cp "$W/hello.pcode" "$W/prd"
( cd "$W" && rm -f prr && /usr/bin/time -f "%e %M" -o "$W/t2" timeout -k 5 300s "$SCRIP" -d${PINT_HEAP_KB}k --run pint.pas -- prd prr < /dev/null > hello_i.out 2> hello_i.err ); pintrc=$?
read -r s2 k2 < <(tail -1 "$W/t2"); case "$s2" in ""|*[!0-9.]*) s2=unmeasured; k2=unmeasured;; esac
echo "WORK pint.pas(hello probe, the P-code of P5's hello sample) wall=${s2}s rss=${k2}KB  ($TREE)"
if [ "$hcrc" -eq 0 ] && [ "$pintrc" -eq 0 ] && diff <(tail -n +2 "$SMP/hello.cmp") <(tail -n +2 "$W/hello_i.out") >/dev/null 2>&1; then pintv=match; else pintv=differs; fi
echo "pint: rc=$pintrc hello_transcript=$pintv first_line=$(head -1 "$W/hello_i.out" | cut -c1-60) $(grep -v '^Command' "$W/hello_i.err" | head -c 120 | tr '\n' ' ')"
# ---- generation 2, the quick probe: the compiler, compiled by itself and run by pint, compiles P5's hello -----------------
cat "$W/gen1.pcode" "$SMP/hello.pas" > "$W/prd"
( cd "$W" && rm -f prr && /usr/bin/time -f "%e %M" -o "$W/t3" timeout -k 5 1200s "$SCRIP" -d${PINT_HEAP_KB}k --run pint.pas -- prd prr < /dev/null > g2h.out 2> g2h.err ); g2hrc=$?
read -r s3 k3 < <(tail -1 "$W/t3"); case "$s3" in ""|*[!0-9.]*) s3=unmeasured; k3=unmeasured;; esac
echo "WORK pint.pas(gen2 probe, the gen1 P-code compiling P5's hello) wall=${s3}s rss=${k3}KB  ($TREE)"
if [ "$g2hrc" -eq 0 ] && cmp -s "$W/prr" "$W/hello.pcode"; then g1h=identical; else g1h=differs; fi
echo "gen2 probe: rc=$g2hrc hello_pcode=$g1h pcode_lines=$(wc -l < "$W/prr" 2>/dev/null)"
# ---- generation 2, in full: the gen1 P-code compiles pcom's own source -------------------------------------------------
cat "$W/gen1.pcode" "$W/pcom_self.pas" > "$W/prd"
( cd "$W" && rm -f prr && /usr/bin/time -f "%e %M" -o "$W/t4" timeout ${GEN2_TIMEOUT_S}s "$SCRIP" -d${PINT_HEAP_KB}k --run pint.pas -- prd prr < /dev/null > gen2.out 2> gen2.err ); gen2rc=$?
read -r s4 k4 < <(tail -1 "$W/t4"); case "$s4" in ""|*[!0-9.]*) s4=unmeasured; k4=unmeasured;; esac
echo "WORK pint.pas(gen2, running the gen1 P-code on pcom's own source) wall=${s4}s rss=${k4}KB  ($TREE)"
g2lines=$(wc -l < "$W/prr" 2>/dev/null); g2lines=${g2lines:-0}
echo "gen2: rc=$gen2rc out_lines=$(wc -l < "$W/gen2.out") pcode_lines=$g2lines $(grep -v '^Command' "$W/gen2.err" | head -c 160 | tr '\n' ' ')"
if [ "$gen2rc" -ne 0 ] || [ "$g2lines" -eq 0 ]; then
  echo "P5_SELFHOST: pre=0 pcom=0 pint=$pintv gen1_pcode_lines=$g1lines gen1_native=$gnat gen1_hello=$g1h gen2=BLOCKED pcode_identical=n/a"
  echo "SELFHOST BLOCKED (generation 2 did not finish: rc=$gen2rc)"; exit 1
fi
if cmp -s "$W/prr" "$W/gen1.pcode"; then
  echo "P5_SELFHOST: pre=0 pcom=0 pint=$pintv gen1_pcode_lines=$g1lines gen1_native=$gnat gen1_hello=$g1h gen2=0 pcode_identical=yes"; echo "SELFHOST OK"; exit 0
fi
echo "first differing line: $(diff "$W/prr" "$W/gen1.pcode" | head -2 | tr '\n' ' ' | cut -c1-160)"
echo "P5_SELFHOST: pre=0 pcom=0 pint=$pintv gen1_pcode_lines=$g1lines gen1_native=$gnat gen1_hello=$g1h gen2=0 pcode_identical=no"; echo "SELFHOST PARTIAL"; exit 1
