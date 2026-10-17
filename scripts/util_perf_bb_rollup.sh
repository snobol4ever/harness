#!/usr/bin/env bash
# util_perf_bb_rollup.sh — WHICH BOX KIND HOGS THE TIME (Lon 2026-08-28, in-chat: "per-BB or per-BB-type
# statistics for which statement or BB is hogging the time"). Rolls a perf report's per-symbol lines up
# into a BB-FAMILY x PORT table, so one read answers "which box kind", not "which of 3036 boxes".
#
# ⛔ INSTRUMENT LAW 5 — REFUSES rc=2 WHEN IT CANNOT MEASURE, never skip-as-success. A rollup that printed an
#    empty table on an unparseable report would look exactly like a program that spends no time in boxes.
# ⛔ IDENTITY-ANCHORED, NOT SUBSTRING (the FAIL-subset-XFAIL lesson): the symbol is matched whole against
#    ^n<id>_<family>_<port>$ and the family is what remains after BOTH ends are removed. Substring matching
#    would fold match_assign_save into match_assign and silently under-report both.
# ⭐ COVERAGE IS PRINTED, ALWAYS. The BB rows are a SHARE of the profile, not the whole of it; a table that
#    does not say what fraction it covers invites its own total to be read as 100%.
#
# usage: util_perf_bb_rollup.sh [--report FILE | --data PERF.DATA | -]  [--min PCT] [--by-family|--by-port]
#        util_perf_bb_rollup.sh --selftest
#        --min-samples N   REFUSE (rc=2) below N samples (default 1000; env ROLLUP_MIN_SAMPLES; 0 disables).
#                          ⛔ A share built on <~1000 samples is a hypothesis, not a measurement.
# env:   PERF_BIN  path to the real perf (default /usr/lib/linux-tools-6.8.0-138/perf — ⛔ never the /usr/bin shim)
set -uo pipefail
PERF_BIN="${PERF_BIN:-/usr/lib/linux-tools-6.8.0-138/perf}"
die2(){ printf '⛔ REFUSES (rc=2): %s\n' "$*" >&2; exit 2; }
MODE=table; SRC=""; SRCKIND=""; MIN=0; MINSAMP="${ROLLUP_MIN_SAMPLES:-1000}"
while [ $# -gt 0 ]; do
  case "$1" in
    --report) SRCKIND=report; SRC="${2:-}"; shift 2 ;;
    --data)   SRCKIND=data;   SRC="${2:-}"; shift 2 ;;
    -)        SRCKIND=stdin;  SRC="-";      shift ;;
    --min)    MIN="${2:-0}";  shift 2 ;;
    --min-samples) MINSAMP="${2:-}"; shift 2 ;;
    --by-family) MODE=family; shift ;;
    --by-port)   MODE=port;   shift ;;
    --selftest)  MODE=selftest; shift ;;
    -h|--help) sed -n '2,16p' "$0"; exit 0 ;;
    *) die2 "unknown argument '$1' (see --help)" ;;
  esac
done

rollup(){   # stdin: a perf --stdio report.  stdout: the table.  rc=2 if it cannot measure.
  awk -v MIN="$MIN" -v MODE="$MODE" -v MINSAMP="$MINSAMP" '
    # mawk has no asorti(); this box ships with mawk only, so sort by hand rather than depend on gawk.
    # ⛔ A tool that needs an absent interpreter is the "instrument that cannot measure" class.
    function sortdesc(src, out,   k, n, i, j, tmp) {
      n = 0; for (k in src) out[++n] = k
      for (i = 2; i <= n; i++) { tmp = out[i]; j = i - 1
        while (j > 0 && src[out[j]] < src[tmp]) { out[j+1] = out[j]; j-- }
        out[j+1] = tmp }
      return n }
    # A perf --stdio row looks like:  "  8.43%  comm  dso  [.] symbol"
    # Anchor on the percent column AND the [.]/[k] marker; anything else is header/comment noise.
    # ⛔⭐ SAMPLE COUNT IS PART OF THE MEASUREMENT (hq_P 2026-08-28). A share is only as good as the number of
    # samples under it. MEASURED: the campaigns top lever was ranked 24.84%/18.18%β from a profile holding 144
    # SAMPLES IN TOTAL -- beta share of that is ~14 samples, four significant figures on fourteen counts. Re-measured
    # at ~4700 samples it is 9.33%/7.15%, i.e. 2.5-2.7x overstated, and the single-pass reading wandered 2.42-10.37
    # across five runs of the SAME binary and input. ⭐ perf reported honestly; the share of the SAMPLES was read as
    # the share of the WORK. The header carries the count, so there is no excuse for not printing it.
    /^#[[:space:]]*Samples:/ {
      sc = $0; sub(/^#[[:space:]]*Samples:[[:space:]]*/, "", sc); sub(/[[:space:]].*$/, "", sc)
      mult = 1
      if (sc ~ /[Kk]$/) mult = 1000; else if (sc ~ /[Mm]$/) mult = 1000000; else if (sc ~ /[Gg]$/) mult = 1000000000
      gsub(/[KkMmGg]$/, "", sc)
      if (sc ~ /^[0-9.]+$/) { NSAMP = sc * mult; HAVE_NSAMP = 1 }
      next
    }
    /^[[:space:]]*[0-9]+\.[0-9]+%/ {
      pct = $1; sub(/%$/, "", pct)
      i = index($0, "[.] "); w = 4
      if (i == 0) { i = index($0, "[k] "); }
      if (i == 0) next
      sym = substr($0, i + w)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", sym)
      seen_rows++; total += pct
      # ---- identity-anchored BB match: ^n<digits>_<family>_<port>$ -------------------------
      if (sym ~ /^n[0-9]+_.+_(α|β|ry|rt|as|af|st|sx|s[0-9]+)$/) {
        body = sym; sub(/^n[0-9]+_/, "", body)                    # strip the node id
        if (match(body, /_(α|β|ry|rt|as|af|st|sx|s[0-9]+)$/)) {
          port = substr(body, RSTART + 1)                          # after the final underscore
          fam  = substr(body, 1, RSTART - 1)                       # everything before it
          if (fam == "") next
          cell[fam SUBSEP port] += pct; fams[fam] += pct; ports[port] += pct
          bbtotal += pct; bbrows++
        }
      } else { nonbb += pct; nonbbrows++ }
    }
    END {
      if (seen_rows == 0) { print "NOPARSE" > "/dev/stderr"; exit 2 }
      if (MODE == "port") {
        printf "%-10s %10s\n", "PORT", "% cycles"; printf "%s\n", "----------------------"
        n = sortdesc(ports, pk)
        for (i = 1; i <= n; i++) if (ports[pk[i]] >= MIN) printf "%-10s %9.2f%%\n", pk[i], ports[pk[i]]
      } else if (MODE == "family") {
        printf "%-24s %10s\n", "BB FAMILY", "% cycles"; printf "%s\n", "-----------------------------------"
        n = sortdesc(fams, fk)
        for (i = 1; i <= n; i++) if (fams[fk[i]] >= MIN) printf "%-24s %9.2f%%\n", fk[i], fams[fk[i]]
      } else {
        np = sortdesc(ports, pk); nf = sortdesc(fams, fk)
        printf "%-24s", "BB FAMILY x PORT"
        for (i = 1; i <= np; i++) printf "%9s", pk[i]
        printf "%10s\n", "TOTAL"
        printf "%s\n", "--------------------------------------------------------------------------------"
        for (i = 1; i <= nf; i++) { f = fk[i]
          if (fams[f] < MIN) continue
          printf "%-24s", f
          for (j = 1; j <= np; j++) { v = cell[f SUBSEP pk[j]] + 0; if (v > 0) printf "%8.2f%%", v; else printf "%9s", "." }
          printf "%9.2f%%\n", fams[f] }
        printf "%s\n", "--------------------------------------------------------------------------------"
        printf "%-24s", "TOTAL (per port)"
        for (j = 1; j <= np; j++) printf "%8.2f%%", ports[pk[j]]
        printf "%9.2f%%\n", bbtotal
      }
      printf "\n"
      printf "COVERAGE: %d BB symbols = %.2f%% of profile | %d non-BB symbols = %.2f%% | %d rows parsed, %.2f%% accounted\n", \
             bbrows, bbtotal, nonbbrows, nonbb, seen_rows, total
      if (HAVE_NSAMP) printf "SAMPLES:  %d in this profile%s\n", NSAMP, (NSAMP < MINSAMP ? "  ⛔ BELOW THE FLOOR" : "")
      else print  "SAMPLES:  ⚠ UNKNOWN — no \"# Samples:\" header. Every share below has an UNKNOWN denominator and is a hypothesis, not a measurement."
      if (HAVE_NSAMP && NSAMP < MINSAMP) {
        printf "⛔ REFUSES (rc=2): %d samples is below the --min-samples floor of %d. A share built on this few samples is a HYPOTHESIS, not a measurement -- at ~14 samples the Poisson error alone is +/-26%% at 1 sigma, before any scheduler noise on a shared box. This is the defect that cost row perf-match-begin-beta-cure its premise: 24.84%%/18.18%% from 144 samples re-measured to 9.33%%/7.15%% at ~4700. ⭐ FIX THE MEASUREMENT, DO NOT OVERRIDE THE FLOOR: lengthen the run (../harness/scripts/bench_wrap.sh --mode=iter --n=N gives fixed work), or raise -F. Override only for a deliberately small probe: --min-samples 0.\n", NSAMP, MINSAMP > "/dev/stderr"
        exit 2
      }
      if (bbrows == 0) { print "⛔ REFUSES (rc=2): parsed " seen_rows " symbol rows but ZERO matched ^n<id>_<family>_<port>$ — either the binary was stripped, this is a mode-3 [JIT] profile (see SCRIP_PERF_MAP), or the label scheme changed. An empty BB table is NOT a measurement of \"no time in boxes\"." > "/dev/stderr"; exit 2 }
    }' || return $?
}

selftest(){
  local t rc out; t="$(mktemp -d)"; trap 'rm -rf "$t"' RETURN
  # ---- canned report: families that share a prefix, ports incl. UTF-8, and non-BB rows ----------
  cat > "$t/good.txt" <<'EOF'
# Samples: 100K of event 'cycles:u'
#
    20.00%  w.bin  libscrip_rt.so  [.] NV_SET_fn
    15.00%  w.bin  w.bin           [.] n1_match_assign_save_α
    10.00%  w.bin  w.bin           [.] n2_match_assign_save_β
     8.00%  w.bin  w.bin           [.] n3_match_assign_α
     5.00%  w.bin  w.bin           [.] n4_match_alternate_s12
     2.00%  w.bin  w.bin           [.] n5_match_begin_af
     1.00%  w.bin  libc.so.6       [.] __strcmp_evex
EOF
  out="$("$0" --report "$t/good.txt" 2>&1)"; rc=$?; out2="$out"
  [ $rc -eq 0 ] || { echo "SELFTEST FAIL: good report returned rc=$rc"; echo "$out"; return 1; }
  # ⭐ THE DISCRIMINATING CHECK — prefix-sharing families must NOT fold together.
  grep -qE '^match_assign_save[[:space:]]' <<<"$out" || { echo "SELFTEST FAIL: match_assign_save row missing"; echo "$out"; return 1; }
  grep -qE '^match_assign[[:space:]]'      <<<"$out" || { echo "SELFTEST FAIL: match_assign row missing (folded into _save?)"; echo "$out"; return 1; }
  grep -qE 'match_assign_save.*25\.00%'    <<<"$out" || { echo "SELFTEST FAIL: match_assign_save total != 25.00% (α15+β10)"; echo "$out"; return 1; }
  grep -qE 'match_assign +.*8\.00%'        <<<"$out" || { echo "SELFTEST FAIL: match_assign total != 8.00% — prefix folding"; echo "$out"; return 1; }
  grep -q  'COVERAGE:'                     <<<"$out" || { echo "SELFTEST FAIL: coverage line absent"; return 1; }
  grep -qE 'COVERAGE: 5 BB symbols = 40\.00%' <<<"$out" || { echo "SELFTEST FAIL: BB coverage != 40.00% over 5 rows"; echo "$out"; return 1; }
  grep -qE '2 non-BB symbols = 21\.00%'    <<<"$out" || { echo "SELFTEST FAIL: non-BB bucket != 21.00% over 2 rows"; echo "$out"; return 1; }
  # ---- ⛔ NEGATIVE ARM 1: a report with NO BB symbols must REFUSE rc=2, not print an empty table ----
  cat > "$t/nobb.txt" <<'EOF'
    50.00%  w.bin  libc.so.6  [.] __strcmp_evex
    50.00%  w.bin  libc.so.6  [.] memcpy
EOF
  "$0" --report "$t/nobb.txt" >/dev/null 2>&1; rc=$?
  [ $rc -eq 2 ] || { echo "SELFTEST FAIL: BB-less report returned rc=$rc, expected 2 (this is the vacuous-table trap)"; return 1; }
  # ---- ⛔ NEGATIVE ARM 2: unparseable input must REFUSE rc=2 ----
  printf 'not a perf report at all\njust prose\n' > "$t/junk.txt"
  "$0" --report "$t/junk.txt" >/dev/null 2>&1; rc=$?
  [ $rc -eq 2 ] || { echo "SELFTEST FAIL: junk input returned rc=$rc, expected 2"; return 1; }
  # ---- ⛔ NEGATIVE ARM 3: a missing file must REFUSE rc=2, never treat absence as an empty profile ----
  "$0" --report "$t/does_not_exist.txt" >/dev/null 2>&1; rc=$?
  [ $rc -eq 2 ] || { echo "SELFTEST FAIL: missing file returned rc=$rc, expected 2"; return 1; }
  # ---- ⛔ NEGATIVE ARM 4: POISON — prove the selftest itself can FAIL (the make-test lesson) ----
  sed 's/n2_match_assign_save_β/n2_match_assign_β/' "$t/good.txt" > "$t/poison.txt"
  out="$("$0" --report "$t/poison.txt" 2>&1)"
  if grep -qE 'match_assign_save.*25\.00%' <<<"$out"; then
    echo "SELFTEST FAIL: poisoned report still reported 25.00% — the assertion is tautological"; return 1; fi
  # ---- positive: the SAMPLES line must always be printed (a share without its denominator is unquotable) ----
  grep -qE '^SAMPLES:  100000 in this profile' <<<"$out2" || { echo "SELFTEST FAIL: SAMPLES line absent or wrong on the good report"; echo "$out2"; return 1; }
  # ---- ⛔ NEGATIVE ARM 5: a LOW-SAMPLE report must REFUSE rc=2 -- the defect that cost a row its premise ----
  sed 's/^# Samples: 100K/# Samples: 144/' "$t/good.txt" > "$t/fewsamp.txt"
  "$0" --report "$t/fewsamp.txt" >/dev/null 2>&1; rc=$?
  [ $rc -eq 2 ] || { echo "SELFTEST FAIL: 144-sample report returned rc=$rc, expected 2 (a share on 144 samples is a hypothesis)"; return 1; }
  # ---- and the override must still work, so a deliberate small probe is possible ----
  "$0" --report "$t/fewsamp.txt" --min-samples 0 >/dev/null 2>&1; rc=$?
  [ $rc -eq 0 ] || { echo "SELFTEST FAIL: --min-samples 0 returned rc=$rc, expected 0 (the floor must be overridable)"; return 1; }
  # ---- ⛔ NEGATIVE ARM 6: an UNKNOWN sample count must SAY SO, loudly, rather than print a bare share ----
  grep -v '^# Samples:' "$t/good.txt" > "$t/nosamp.txt"
  out="$("$0" --report "$t/nosamp.txt" 2>&1)"
  grep -q 'SAMPLES:  ⚠ UNKNOWN' <<<"$out" || { echo "SELFTEST FAIL: missing sample header did not produce the UNKNOWN warning"; echo "$out"; return 1; }
  echo "SELFTEST PASS — 3 positive arms, 6 negative arms (incl. a poison arm proving the assertions can fail)"
  return 0
}

case "$MODE" in
  selftest) selftest; exit $? ;;
esac
[ -n "$SRCKIND" ] || die2 "no input: pass --report FILE, --data PERF.DATA, or - for stdin"
case "$SRCKIND" in
  report) [ -f "$SRC" ] || die2 "report file not found: $SRC"
          rollup < "$SRC"; rc=$? ;;
  data)   [ -f "$SRC" ] || die2 "perf.data not found: $SRC"
          [ -x "$PERF_BIN" ] || die2 "PERF_BIN not executable: $PERF_BIN (⛔ do not fall back to the /usr/bin shim — set PERF_BIN)"
          "$PERF_BIN" report -i "$SRC" --stdio --no-children -q 2>/dev/null | rollup; rc=$? ;;
  stdin)  rollup; rc=$? ;;
esac
exit $rc
