#!/usr/bin/env bash
export SCRIP_DIAG=0   # benchmarks run with every diagnostic off: the collector's self-checks and the node-id stores (Lon 2026-09-25, in-chat to the ceo: "For benchmarks turn off all diagnostic code."; ceo CEO-1262)
# test_icon_bench_corpus.sh — build (if needed) + run corpus/benchmarks/icon/*.icn through
# the iconx oracle and both SCRIP execution modes; report per-program PASS/FAIL + timing.
#
# WHY THIS SCRIPT EXISTS: this corpus (icon-master/tests/bench + jcon-master/bmark, merged —
# see corpus/benchmarks/README-ICON-JCON.md) is link-heavy (concord/deal/ipxref/queens/rsg/tgrlink
# all `link options[, post[, shuffle]]`) and is NOT covered by any existing runner:
#   - update_icon_bench_asm.sh only checks --compile assembles; never links/runs/times.
#   - audit_jcon_wholesale.sh does the same ORC/M3/M4 pattern this script uses, but against the
#     link-free test/icon/jcon_audit probes, not this corpus.
#   - test_icon_bench_rung36.sh targets the dormant -jvm backend against a different corpus.
# The *.std files beside these sources are icont self-benchmark dumps (&features/&storage banner
# + elapsed-time), NOT diffable oracles — see README-ICON-JCON.md. This script builds a real
# oracle from source instead (classic Icon via icont/iconx).
#
# ICONT/ICONX RESOLUTION, PER doc/files.htm + man/man1/icont.1 (verified 2026-07-02):
#   `link X` resolves to `X.u1`, searched for in the current directory first, then $IPATH.
#   `icont -c a.icn b.icn` stops after translation and leaves a.u1/b.u1 behind — "a directory of
#   such files functions as a linkable library" (man/man1/icont.1). So link dependencies must be
#   pre-translated with -c *before* compiling anything that links them.
#
# SCRIP'S `link` IS A NO-OP (corrected same session, after this script's first draft guessed
# wrong): it parses `link X` into a placeholder AST node and never reads X.icn — proved with
# `link this_file_does_not_exist_anywhere`, which fails identically to a real target. The earlier
# theory here ("scrip resolves link against sibling source") was wrong; what actually happens is
# LOWER speculatively emits an unresolved IR_CALL for any unrecognized callee name, deferring to a
# runtime name lookup that has nothing registered, hence the FATAL. The real, verified fix: pass
# the linked .icn files as EXTRA scrip command-line arguments (see SCRIP_LINK_DEPS[] below) — the
# driver's per-file loop (src/driver/scrip.c) compiles every argument into the same program, which
# is what actually gets the callee into IR_CALL_PROC_STAGED.
#
# USAGE:
#   bash ../harness/scripts/test_icon_bench_corpus.sh              # build if needed, run everything
#   SKIP_BUILD=1 bash ../harness/scripts/test_icon_bench_corpus.sh  # assume scrip/libscrip_rt exist
#   ICONT=/path/to/icont ICONX=/path/to/iconx bash ../harness/scripts/test_icon_bench_corpus.sh   # override the oracle
#
# Exit: 0 always (this is a report, not a gate) — read the PASS/FAIL counts in the final line.
S4E="${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"   # D-17 PORTABLE-HOME: the sibling root (all repos + oracles are siblings under ONE root; /home/claude2-style seat roots work with zero env; S4E_HOME overrides)
S4A="${S4E_ASSETS:-$([ -d "$S4E/x64" ] && echo "$S4E" || echo /home/resources)}"   # D-17b: ASSET root -- oracles/vendor trees live at the HQ root on this machine (Lon: seats carry ONLY .github/SCRIP/corpus); a root owning its own x64 (HQ, or a full standalone clone-set) is self-contained.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/lib_oracle_flags.sh" 2>/dev/null || { echo "REFUSING: cannot load lib_oracle_flags.sh -- the ONE oracle-flag authority (s200/s255), Icon-aware since row icon-oracle-accessors-shared." >&2; exit 3; }
ROOT="$HERE/../../SCRIP"                                    # .../SCRIP
SCRIP="$ROOT/scrip"
RTDIR="$ROOT/out"
CORPUS_SRC="${CORPUS_SRC:-$S4E/corpus/benchmarks/icon}"
SKIP_BUILD="${SKIP_BUILD:-0}"
WORK="$(mktemp -d /tmp/icon_bench_corpus_XXXXXX)"
trap 'rm -rf "$WORK"' EXIT

# ---------- 1. build (idempotent — skip anything already present) ----------
# ⛔ NO AUTO-BUILDING THE ICON ORACLE HERE (dropped under row icon-oracle-accessors-shared): the
# oracle is a SHARED asset every seat grades against, and rebuilding it from an arbitrary board
# script mid-fleet is exactly the unannounced-swap hazard the ORACLE-SWAP procedure (ARCH-FLEET-
# CEO.md) exists to forbid. A missing shared oracle is now a loud refusal (icont_bin/iconx_bin),
# never a silent from-source rebuild.
if [ "$SKIP_BUILD" != "1" ]; then
  if [ ! -x "$SCRIP" ]; then
    echo "building scrip ..."; bash "$ROOT/../harness/scripts/build_scrip.sh" || { echo "FATAL: scrip build failed"; exit 2; }
  fi
  if [ ! -f "$RTDIR/libscrip_rt.so" ]; then
    echo "building libscrip_rt ..."; ( cd "$ROOT" && make libscrip_rt ) || { echo "FATAL: libscrip_rt build failed"; exit 2; }
  fi
fi
ICONT="${ICONT:-$(icont_bin)}" || exit 2
ICONX="${ICONX:-$(iconx_bin)}" || exit 2
# JCON (Proebsting/Townsend, Icon->JVM) — optional 4th column when built. TRAPS (see GOAL-ICON-BB.md
# §ICON BENCHMARK MAP): jcont is #!/bin/sh but uses bashisms (dash dies "Bad substitution") — ALWAYS
# invoke via `bash`; and it writes ../$name.zip relative paths — ALWAYS run from the source dir with
# bare filenames. jcont needs Arizona icont on PATH for its own operation.
# ⛔⭐ BOTH RIVAL PATHS COME FROM lib_oracle_flags.sh ACCESSORS, NEVER FROM A HAND-ASSEMBLED ENV VAR
# (ceo CEO-490b, cured hq_P 2026-09-10). This block carried two defects with OPPOSITE volumes, and the
# quiet one is the dangerous one:
#   (1) LOUD -- `export PATH="$ICONM/bin:$PATH"` referenced ICONM, which nothing in this script ever set.
#       Under `set -u` (line 40) that is "ICONM: unbound variable" and the script died at line 75 having
#       run NOT ONE PROGRAM. A board that cannot start is at least honest about it.
#   (2) ⛔ SILENT, AND IT HAD BEEN SILENT FOR WEEKS -- JCONM defaulted to "$S4E/jcon-src/jcon-master",
#       a path that exists in no root on this box; jcont lives at /home/resources/jcon-master/bin/jcont.
#       `[ -f "$JCONT" ]` then set HAVE_JCON=0 and every jcon arm below SKIPPED ITSELF, so the board
#       printed a complete, plausible three-column table with the fourth column simply absent -- the
#       CLAUDE.md missing-oracle class exactly, wearing "optional 4th column when built" as its excuse.
#       Lon asked on 2026-09-10 how SCRIP compares to Arizona AND JCON, and the reason no answer existed
#       was this line. ⭐ An accessor REFUSES; a `[ -f ]` guard around a hand-built path cannot.
# ⛔ Do not reintroduce either variable. icont's own directory is what jcont needs on PATH (it shells out
# to icont), and the only place that directory is known correctly is the accessor that resolved ICONT.
export PATH="$(dirname "$ICONT"):$PATH"
JCONT="$(jcont_bin 2>/dev/null)" || JCONT=""
HAVE_JCON=0
if [ -n "$JCONT" ] && [ -x "$JCONT" ] && command -v java >/dev/null 2>&1; then HAVE_JCON=1; fi
# ⛔ A MISSING RIVAL IS NAMED, NEVER INFERRED FROM A GAP IN THE GRID: with HAVE_JCON=0 every jcon cell is
# absent below, and an absent cell and a measured-slower cell look identical to a reader scanning columns.
if [ "$HAVE_JCON" = "1" ]; then
  echo "JCON RIVAL: $JCONT (java $(java -version 2>&1 | head -1 | tr -d '\n'))"
else
  echo "⚠ JCON RIVAL ABSENT -- every jcont column below is EMPTY BECAUSE IT WAS NOT MEASURED, not because"
  echo "  jcont was slow: jcont=${JCONT:-<accessor refused>} java=$(command -v java || echo '<not on PATH>')"
fi
for exe in "$SCRIP" "$ICONT" "$ICONX"; do
  [ -x "$exe" ] || { echo "FATAL: $exe missing/not executable (build failed or SKIP_BUILD=1 without a prior build)"; exit 2; }
done
[ -f "$RTDIR/libscrip_rt.so" ] || { echo "FATAL: $RTDIR/libscrip_rt.so missing"; exit 2; }
[ -d "$CORPUS_SRC" ] || { echo "FATAL: corpus dir $CORPUS_SRC not found (CORPUS_SRC=... to override)"; exit 2; }

# ---------- 2. stage corpus + build the icont link units ----------
mkdir -p "$WORK/corpus"
cp "$CORPUS_SRC"/*.icn "$CORPUS_SRC"/*.dat "$WORK/corpus/" 2>/dev/null
CORPUS="$WORK/corpus"

# authentic ipxref stdin: a real Icon source file to cross-reference (jcon originally used its own
# translator source, tran/bytecode.icn — substitute any real .icn source of comparable size)
IPXIN="$WORK/ipxref_input.icn"
cat "$CORPUS"/*.icn > "$IPXIN"


# ---------- 3. per-program args/stdin (mirrors jcon-master/bmark/Makefile's `run` target) ----------
declare -A STDIN ARGS
STDIN[concord]="$CORPUS/concord.dat"; ARGS[concord]=""
STDIN[deal]="";                       ARGS[deal]="-h 1000"
STDIN[geddump]="$CORPUS/geddump.dat"; ARGS[geddump]=""
STDIN[ipxref]="$IPXIN";               ARGS[ipxref]=""
STDIN[queens]="";                     ARGS[queens]="-n10"
STDIN[rsg]="$CORPUS/rsg.dat";         ARGS[rsg]=""
STDIN[tgrlink]="";                    ARGS[tgrlink]="$CORPUS/tgrlink.dat"
progs="concord deal geddump ipxref queens rsg tgrlink"
# SCRIP's `link` directive is currently a no-op (confirmed 2026-07-02: it parses `link X` into a
# placeholder AST node and never reads X.icn — verified with a `link nonexistent_file` repro that
# fails identically to a real one). The WORKAROUND, which works today with zero source changes:
# pass the linked .icn files as extra arguments on SCRIP's command line — the driver compiles every
# file argument into the same program (src/driver/scrip.c's per-file loop), so this reaches
# IR_CALL_PROC_STAGED instead of a bare unresolved IR_CALL. iconx needs no such workaround (real
# `link` support) but DOES need its dependencies pre-translated to .u1 first — see the -c step above.
declare -A SCRIP_LINK_DEPS
# ARGS[] forwarding (landed with the ICNBENCH-ARGS rung): mode-3 receives program args after a
# `--` separator on scrip's own command line (everything before -- is source files; after is the
# Icon program's args list); mode-4 binaries build args from their OWN C argc/argv at runtime, so
# passing "${a[@]}" to the produced binary is now live, not harmless-inert.

pass_o=0; pass3=0; pass4=0; pass_j=0; total=0

if [ "$HAVE_JCON" = "1" ]; then
  printf "%-9s | %-28s | %-24s | %-28s | %-28s\n" "PROGRAM" "ICONX (oracle)" "JCON (JVM)" "SCRIP m3 (--run)" "SCRIP m4 (--compile)"
  printf "%-9s-+-%-28s-+-%-24s-+-%-28s-+-%-28s\n" "---------" "----------------------------" "------------------------" "----------------------------" "----------------------------"
else
  printf "%-9s | %-28s | %-28s | %-28s\n" "PROGRAM" "ICONX (oracle)" "SCRIP m3 (--run)" "SCRIP m4 (--compile)"
  printf "%-9s-+-%-28s-+-%-28s-+-%-28s\n" "---------" "----------------------------" "----------------------------" "----------------------------"
fi

for name in $progs; do
  total=$((total+1))
  icn="$CORPUS/$name.icn"
  sin="${STDIN[$name]:-}"; [ -z "$sin" ] && sin=/dev/null
  read -ra a <<< "${ARGS[$name]}"
  read -ra linkdeps <<< "${SCRIP_LINK_DEPS[$name]:-}"

  # ---- ICONX oracle: -c pre-build above already produced link units; -s -o compiles+links ----
  o_status="?"
  ( cd "$CORPUS" && "$ICONT" -s -o "$WORK/$name.icx" "$name.icn" ) >"$WORK/$name.icont.err" 2>&1
  if [ -f "$WORK/$name.icx" ]; then
    t0=$(date +%s%N); timeout -k 5 30 "$ICONX" "$WORK/$name.icx" "${a[@]}" >"$WORK/$name.iconx.out" 2>"$WORK/$name.iconx.err" <"$sin"
    rc=$?; t1=$(date +%s%N); ms=$(( (t1-t0)/1000000 ))
    if [ $rc -eq 0 ]; then o_status="OK ${ms}ms $(wc -l <"$WORK/$name.iconx.out")L"; pass_o=$((pass_o+1))
    else o_status="RUNERR rc=$rc"; fi
  else o_status="COMPILEFAIL: $(head -c60 "$WORK/$name.icont.err"|tr '\n' ' ')"; fi

  # ---- JCON: compile (untimed; link deps ride as extra .icn sources like SCRIP's workaround —
  #      jcont links them into the one program) then run the standalone .jxe (timed) ----
  j_status="-"
  if [ "$HAVE_JCON" = "1" ]; then
    ( cd "$CORPUS" && timeout -k 5 180 bash "$JCONT" -s -o "$WORK/$name.jxe" "$name.icn" ${linkdeps[@]+"${linkdeps[@]}"} ) >"$WORK/$name.jcont.err" 2>&1
    if [ -x "$WORK/$name.jxe" ]; then
      t0=$(date +%s%N); timeout -k 5 60 "$WORK/$name.jxe" "${a[@]}" >"$WORK/$name.jcon.out" 2>"$WORK/$name.jcon.err" <"$sin"
      rc=$?; t1=$(date +%s%N); ms=$(( (t1-t0)/1000000 ))
      if [ $rc -eq 0 ]; then j_status="OK ${ms}ms $(wc -l <"$WORK/$name.jcon.out")L"; pass_j=$((pass_j+1))
      elif [ $rc -eq 124 ]; then j_status="TIMEOUT"
      else j_status="RUNERR rc=$rc"; fi
    else j_status="COMPILEFAIL: $(grep -m1 -iE 'error' "$WORK/$name.jcont.err"|head -c40)"; fi
  fi

  # ---- SCRIP mode-3 (--run): in-process, primary native mode ----
  m3_status="?"
  out3=$( cd "$CORPUS" && timeout -k 5 30 "$SCRIP" --bench --run "$name.icn" "${linkdeps[@]}" -- "${a[@]}" >"$WORK/$name.m3.out" 2>"$WORK/$name.m3.err" <"$sin"; echo "rc=$?" )
  rc3="${out3##*rc=}"
  if [ "$rc3" = "0" ] && [ -s "$WORK/$name.m3.out" ]; then
    bench=$(grep -o 'total=[0-9.]*ms' "$WORK/$name.m3.err" | tail -1)
    m3_status="OK ${bench:-?} $(wc -l <"$WORK/$name.m3.out")L"; pass3=$((pass3+1))
  elif [ "$rc3" = "124" ]; then m3_status="TIMEOUT"
  else m3_status="FAIL rc=$rc3: $(head -c70 "$WORK/$name.m3.err"|tr '\n' ' ')"; fi

  # ---- SCRIP mode-4 (--compile -> as/gcc + libscrip_rt.so -> run) ----
  m4_status="?"
  ( cd "$CORPUS" && timeout -k 5 30 "$SCRIP" --compile --target=x86 "$name.icn" "${linkdeps[@]}" >"$WORK/$name.s" 2>"$WORK/$name.m4.compile.err" )
  if [ -s "$WORK/$name.s" ] && ! grep -q '\[SMX\]' "$WORK/$name.m4.compile.err"; then
    if gcc -no-pie "$WORK/$name.s" -L"$RTDIR" -lscrip_rt -Wl,-rpath,"$RTDIR" -o "$WORK/$name.bin" 2>"$WORK/$name.m4.link.err"; then
      t0=$(date +%s%N); timeout -k 5 30 "$WORK/$name.bin" "${a[@]}" >"$WORK/$name.m4.out" 2>"$WORK/$name.m4.err" <"$sin"
      rc=$?; t1=$(date +%s%N); ms=$(( (t1-t0)/1000000 ))
      if [ $rc -eq 0 ] && [ -s "$WORK/$name.m4.out" ]; then m4_status="OK ${ms}ms $(wc -l <"$WORK/$name.m4.out")L"; pass4=$((pass4+1))
      elif [ $rc -eq 124 ]; then m4_status="TIMEOUT"
      else m4_status="RUNFAIL rc=$rc"; fi
    else
      # Usually the SAME fault as m3, surfacing downstream: emission was truncated mid-graph
      # (the shared IR-walking driver died before finishing), leaving jump/call targets
      # referenced but undefined — a linker error, not an independent mode-4-only bug. Confirm
      # by diffing the m3 vs m4 FATAL line before treating this as a distinct issue.
      m4_status="LINKFAIL(likely-same-fault-as-m3): $(grep -m1 'undefined reference' "$WORK/$name.m4.link.err"|head -c50)"
    fi
  else
    if grep -q '\[SMX\]' "$WORK/$name.m4.compile.err"; then m4_status="REFUSED"
    else m4_status="COMPILEFAIL: $(tail -c70 "$WORK/$name.m4.compile.err"|tr '\n' ' ')"; fi
  fi

  if [ "$HAVE_JCON" = "1" ]; then
    printf "%-9s | %-28s | %-24s | %-28s | %-28s\n" "$name" "$o_status" "$j_status" "$m3_status" "$m4_status"
  else
    printf "%-9s | %-28s | %-28s | %-28s\n" "$name" "$o_status" "$m3_status" "$m4_status"
  fi
done

echo "---"
if [ "$HAVE_JCON" = "1" ]; then
  echo "oracle(iconx)=$pass_o/$total  jcon=$pass_j/$total  scrip-m3(--run)=$pass3/$total  scrip-m4(--compile)=$pass4/$total"
else
  echo "oracle(iconx)=$pass_o/$total  scrip-m3(--run)=$pass3/$total  scrip-m4(--compile)=$pass4/$total"
fi
