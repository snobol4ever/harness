#!/usr/bin/env bash
# icon_correctness.sh — REAL output diff, not banner diff.
# post.icn suppresses program output unless OUTPUT is set (write := 1 idiom).
# With OUTPUT=1 the true program output lies strictly between the marker line
# "*** Benchmarking with output ***" and the "<name> elapsed time =" line.
# We extract exactly that window from both engines and diff it.
S4E="${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"   # D-17 PORTABLE-HOME: the sibling root (all repos + oracles are siblings under ONE root; /home/claude2-style seat roots work with zero env; S4E_HOME overrides)
S4A="${S4E_ASSETS:-$([ -d "$S4E/x64" ] && echo "$S4E" || echo /home/resources)}"   # D-17b: ASSET root -- oracles/vendor trees live at the HQ root on this machine (Lon: seats carry ONLY .github/SCRIP/corpus); a root owning its own x64 (HQ, or a full standalone clone-set) is self-contained.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/lib_oracle_flags.sh" 2>/dev/null || { echo "REFUSING: cannot load lib_oracle_flags.sh -- the ONE oracle-flag authority (s200/s255), Icon-aware since row icon-oracle-accessors-shared." >&2; exit 3; }
SCRIPDIR="${SCRIPDIR:-$S4E/SCRIP}"
SCRIP="$SCRIPDIR/scrip"; RTDIR="$SCRIPDIR/out"
ICONT="${ICONT:-$(icont_bin)}" || exit 2
ICONX="${ICONX:-$(iconx_bin)}" || exit 2
CORPUS_SRC="${CORPUS_SRC:-$S4E/corpus/benchmarks/icon}"
[ -d "$CORPUS_SRC" ] || { echo "FATAL: no benchmark corpus at $CORPUS_SRC. Set CORPUS_SRC=." >&2; exit 2; }
# ⛔ SCRATCH LIVES UNDER THE SEAT ROOT ON /home, NEVER BARE /tmp (row icon-sweep-scratch-hardening, after the 2026-08-23 s267 outage).
# /tmp is on the 125G ROOT partition; /home is a separate 503G partition. This script used to `mktemp -d /tmp/icn_corr_XXXXXX`
# with no cleanup trap and no output cap, and one diverging program (deal.icn, 6.79GB against the oracle's 285KB) filled the
# root filesystem to 100% and stopped nineteen sessions. The asymmetry between the two partitions is invisible in the word "/tmp".
SCRATCH_ROOT="${S4E_SCRATCH:-$S4E/.scratch}"
mkdir -p "$SCRATCH_ROOT" 2>/dev/null || { echo "REFUSING: cannot create scratch root $SCRATCH_ROOT -- set S4E_SCRATCH to a writable dir ON /home. Refusing rather than falling back to /tmp, which is the root partition." >&2; exit 2; }
WORK="$(mktemp -d "$SCRATCH_ROOT/icn_corr_XXXXXX")"
# ⛔ CLEANUP MUST SURVIVE THE FAILURE PATH. Cleanup that only runs on success is not cleanup: the failure path is exactly when
# the scratch is biggest, and the caller wraps this script in `timeout 900`, so a kill is the EXPECTED exit, not the rare one.
# ICN_KEEP_WORK=1 preserves the dir for debugging (and then says so, instead of printing a path that no longer exists).
icn_corr_cleanup() { [ "${ICN_KEEP_WORK:-0}" = "1" ] && return 0; [ -n "${WORK:-}" ] && [ -d "$WORK" ] && rm -rf "$WORK"; return 0; }
trap icn_corr_cleanup EXIT INT TERM
# ⛔ PER-PROGRAM OUTPUT CAP. A diverging program writes GBs inside the 120s per-program timeout. head -c bounds the write AND
# SIGPIPEs the producer, so a runaway dies instead of racing the disk. Hitting the cap is a REPORTABLE RESULT, never swallowed.
CAP="${ICN_OUT_CAP:-67108864}"
export PATH="$(dirname "$ICONT"):$PATH"
mkdir -p "$WORK/corpus"
cp "$CORPUS_SRC"/*.icn "$CORPUS_SRC"/*.dat "$WORK/corpus/" 2>/dev/null
CORPUS="$WORK/corpus"
IPXIN="$WORK/ipxref_input.icn"; cat "$CORPUS"/*.icn > "$IPXIN"

declare -A STDIN ARGS LINKDEPS
STDIN[concord]="$CORPUS/concord.dat"; ARGS[concord]=""
STDIN[deal]="";                       ARGS[deal]="-h 1000"
STDIN[geddump]="$CORPUS/geddump.dat"; ARGS[geddump]=""
STDIN[ipxref]="$IPXIN";               ARGS[ipxref]=""
STDIN[queens]="";                     ARGS[queens]="-n10"
STDIN[rsg]="$CORPUS/rsg.dat";         ARGS[rsg]=""
STDIN[tgrlink]="";                    ARGS[tgrlink]="$CORPUS/tgrlink.dat"

# extract the true program-output window.
# Programs linked with post.icn bracket their real output between the marker line and the
# elapsed-time line. Programs WITHOUT post.icn (geddump, micsum, tgrlink — see LINKDEPS above)
# never emit the marker, so the awk window came back EMPTY for them; two empty windows then
# compared equal and printed IDENTICAL. That false green reported geddump — a KNOWN live defect
# diverging 12568L vs 13645L — as a pass. When the marker is absent the whole file IS the
# program output, so fall back to it rather than silently yielding nothing.
window() {
  if grep -q '\*\*\* Benchmarking with output \*\*\*' "$1" 2>/dev/null; then
    awk '/\*\*\* Benchmarking with output \*\*\*/{f=1;next} / elapsed time = /{f=0} f' "$1"
  else
    cat "$1"
  fi
}

progs="${*:-concord deal geddump ipxref queens rsg tgrlink}"
printf "%-9s | %-9s | %-9s | %-9s | %s\n" "PROGRAM" "ORACLE L" "SCRIP L" "VERDICT" "FIRST DIFF"
printf -- "----------+-----------+-----------+-----------+---------------------------\n"
for name in $progs; do
  sin="${STDIN[$name]:-}"; [ -z "$sin" ] && sin=/dev/null
  read -ra a <<< "${ARGS[$name]}"
  read -ra ld <<< "${LINKDEPS[$name]:-}"
  ( cd "$CORPUS" && "$ICONT" -s -o "$WORK/$name.icx" "$name.icn" ) >/dev/null 2>&1
  OUTPUT=1 timeout -k 5 120 "$ICONX" "$WORK/$name.icx" "${a[@]}" 2>/dev/null <"$sin" | head -c "$CAP" >"$WORK/$name.orc"
  orc_rc=${PIPESTATUS[0]}
  ( cd "$CORPUS" && timeout -k 5 120 "$SCRIP" --compile --target=x86 "$name.icn" "${ld[@]}" \
      >"$WORK/$name.s" 2>"$WORK/$name.cerr" )
  if [ -s "$WORK/$name.s" ] && gcc -no-pie "$WORK/$name.s" -L"$RTDIR" -lscrip_rt \
        -Wl,-rpath,"$RTDIR" -o "$WORK/$name.bin" 2>"$WORK/$name.lerr"; then
    # ⛔ `stdbuf -o0` IS LOAD-BEARING, NOT TIDINESS (hq_P s269). stdout here is a PIPE, so libc block-buffers it.
    # When the program dies abnormally -- SIGSEGV, or SIGTERM from `timeout` -- the unflushed buffer is LOST, and a
    # program that ran correctly for thousands of lines before crashing reported `0` lines and compared as DIVERGE.
    # That is how FIVE SEGFAULTS were booked as wrong answers: concord printed 20 good lines, ipxref 17, rsg 5017,
    # every one of them discarded at the moment of death. Unbuffered, the partial output survives and the row tells
    # the truth about how far the program got before it died.
    OUTPUT=1 timeout -k 5 120 stdbuf -o0 "$WORK/$name.bin" "${a[@]}" 2>"$WORK/$name.rerr" <"$sin" | head -c "$CAP" >"$WORK/$name.scr"
    scr_rc=${PIPESTATUS[0]}
  else
    printf "%-9s | %-9s | %-9s | %-9s | %s\n" "$name" "-" "-" "EMITFAIL" "$(grep -m1 -oE 'FATAL.{0,30}' "$WORK/$name.cerr")"
    continue
  fi
  window "$WORK/$name.orc" > "$WORK/$name.orc.w"
  window "$WORK/$name.scr" > "$WORK/$name.scr.w"
  ol=$(wc -l <"$WORK/$name.orc.w"); sl=$(wc -l <"$WORK/$name.scr.w")
  # ⛔ A CAP HIT IS A RESULT, NOT A DETAIL TO SWALLOW. Reporting the truncation and NOT the runaway is how one defect hid as
  # three (s267: the same deal.icn runaway filled the disk, caused the 900s timeout, AND scored 0/1 at weight 15). If SCRIP
  # hit the cap and the oracle did not, that IS the finding -- announce it instead of letting a truncated prefix compare.
  cap_o=0; cap_s=0
  [ "$(stat -c%s "$WORK/$name.orc" 2>/dev/null || echo 0)" -ge "$CAP" ] && cap_o=1
  [ "$(stat -c%s "$WORK/$name.scr" 2>/dev/null || echo 0)" -ge "$CAP" ] && cap_s=1
  # ⛔ HOW THE RUN ENDED OUTRANKS WHAT IT PRINTED (hq_P s269, row icon-bench-correct-zero-of-eight). `scr_rc` was
  # CAPTURED HERE AND NEVER READ: the ladder went straight from the cap checks to `cmp`, so a program that SEGFAULTED
  # or HUNG fell through to DIVERGE -- a WRONG-ANSWER verdict for a program that never produced an answer at all.
  # Measured cost: 6 of the 8 rows were misclassified. FIVE were SIGSEGV (concord, geddump, ipxref, tgrlink, rsg) and
  # ONE was a hang (micsum); not one of them was the wrong-output defect the board had been reporting for sessions.
  # A fixer reading DIVERGE goes and diffs outputs; the actual work is a crash. ⭐ Same class as the timeout-scored-as-
  # zero cure above and as `test_gate_bb_one_box.sh`: an instrument that cannot express one of its own outcomes
  # reports the wrong one CONFIDENTLY. These branches come BEFORE `cmp` and AFTER the cap checks -- a cap hit makes
  # `head` close the pipe and the writer die of SIGPIPE (141), so RUNAWAY must keep first claim on that rc.
  if [ "$cap_s" -eq 1 ] && [ "$cap_o" -eq 0 ]; then v="RUNAWAY"; d="SCRIP output hit the ${CAP}-byte cap, oracle did not - unbounded output, NOT a diff"
  elif [ "$cap_o" -eq 1 ] || [ "$cap_s" -eq 1 ]; then v="CAPPED"; d="output truncated at ${CAP} bytes (oracle=$cap_o scrip=$cap_s) - comparison is UNPROVEN, not a pass"
  elif [ "$scr_rc" -ge 128 ]; then v="CRASH"; d="SCRIP died on SIG$(kill -l "$((scr_rc-128))" 2>/dev/null || echo "?($scr_rc)") after $sl good line(s) [oracle $ol] - a CRASH, not a diff$([ -s "$WORK/$name.rerr" ] && printf ': %s' "$(head -c 60 "$WORK/$name.rerr" | tr '\n' ' ')")"
  elif [ "$scr_rc" -eq 124 ]; then v="HANG"; d="SCRIP did not terminate within 120s after $sl good line(s) [oracle $ol] - non-termination, NOT a diff"
  elif [ "$orc_rc" -ge 124 ]; then v="UNPROVEN"; d="the ORACLE itself died/hung (rc=$orc_rc) - no verdict is possible about SCRIP"
  elif [ "$ol" -eq 0 ] && [ "$sl" -eq 0 ]; then v="NO-OUTPUT"; d="both empty - NOT a pass, harness or program produced nothing"
  elif cmp -s "$WORK/$name.orc.w" "$WORK/$name.scr.w"; then v="IDENTICAL"; d="-"
  else v="DIVERGE"; d="$(diff "$WORK/$name.orc.w" "$WORK/$name.scr.w" | head -2 | tr '\n' ' ' | cut -c1-40)"; fi
  printf "%-9s | %-9s | %-9s | %-9s | %s\n" "$name" "$ol" "$sl" "$v" "$d"
done
# ⛔⭐ REFUSE IF THE SCRATCH DIR DID NOT SURVIVE THE RUN. Measured 2026-08-28 (hq_C), injecting a mid-run
# `rm -rf $WORK`: every remaining row classified EMITFAIL -- correct, it does NOT fabricate passes, because
# rows are keyed per-witness so there is no previous iteration's file to grade stale -- but the script still
# EXITED 0. A caller reading $? (scorecard_icon.sh consumes this board) reads green from a run that graded
# nothing. Cannot-fabricate-a-pass and can-refuse are DIFFERENT properties; this had the first and not the
# second. Sibling of hq_P's D2 harness, which had neither (FINDING-2026-08-28-hq_P-d2-witness-tallied-
# iterations-that-never-ran-as-non-crashes) -- same family, opposite halves.
if [ ! -d "$WORK" ]; then
    echo "⛔ REFUSED rc=2: the scratch workdir ($WORK) did not survive the run -- every verdict above after it"
    echo "   vanished is an artefact of missing files, not a measurement. Nothing here may be quoted." >&2
    exit 2
fi
if [ "${ICN_KEEP_WORK:-0}" = "1" ]; then echo "workdir: $WORK (KEPT -- ICN_KEEP_WORK=1; delete it yourself)"; else echo "workdir: $WORK (removed on exit; ICN_KEEP_WORK=1 to keep it)"; fi
