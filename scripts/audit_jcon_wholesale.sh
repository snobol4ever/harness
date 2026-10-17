#!/usr/bin/env bash
# audit_jcon_wholesale.sh — WHOLESALE from-scratch verification of every JCON ir_a_* construct in SCRIP Icon.
#
# WHY: GOAL-IR-IMMUTABLE-EMIT.md (Lon directive 2026-07-01): "do not trust any of it. We need to start the
# list from scratch and run through a one by one verification step." This script IS that list, executable.
#
# WHAT: for each probe in test/icon/jcon_audit/NN_name.icn (one per JCON ir_a_* + SCRIP TT extras):
#   ORC  — canonical icont/iconx oracle output (refs upload build), if ICONT is set/found. Ground truth.
#   EXP  — the checked-in .ref beside the probe. If ORC disagrees with EXP, the PROBE is wrong.
#   M3   — scrip --run      (in-process native x86)
#   M4   — scrip --compile  (x86 text asm -> gcc -no-pie + libscrip_rt.so -> run)
# Verdict: OK (M3==M4==truth) | M3-BAD | M4-BAD | BOTH-BAD | HANG3/HANG4 | CRASH3/CRASH4 | PROBE-BAD.
#   truth = ORC when the oracle both exists and compiled the probe; else EXP.
#
# USAGE: bash ../harness/scripts/audit_jcon_wholesale.sh [name-filter]
#   ICONT=/path/to/icon-master/bin/icont (auto-probed at refs-src + refs locations)
# Timeouts per RULES.md: 8s unit probes.
S4E="${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"   # D-17 PORTABLE-HOME: the sibling root (all repos + oracles are siblings under ONE root; /home/claude2-style seat roots work with zero env; S4E_HOME overrides)
S4A="${S4E_ASSETS:-$([ -d "$S4E/x64" ] && echo "$S4E" || echo /home/resources)}"   # D-17b: ASSET root -- oracles/vendor trees live at the HQ root on this machine (Lon: seats carry ONLY .github/SCRIP/corpus); a root owning its own x64 (HQ, or a full standalone clone-set) is self-contained.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"; ROOT="$HERE/../../SCRIP"
. "$HERE/lib_oracle_flags.sh" 2>/dev/null || { echo "REFUSING(3): cannot load lib_oracle_flags.sh -- the ONE oracle-path authority." >&2; exit 3; }
SCRIP="$ROOT/scrip"; RT="$ROOT/out"
# ⭐ seat03 2026-08-30: the 94 jcon_audit probes were absorbed into the icon rungs
# (icon-scrip-test-icn-absorption) EXCEPT 3 genuine scrip-vs-oracle disagreements, which were
# relocated to corpus/tests/icon/unresolved/ (see its KEEP.md) once tests/scrip_test/icon/ was
# otherwise fully drained -- this audit's own coverage must include both: 91 extracted fresh from
# the rungs, plus the 3 permanent-residue files, combined into one scratch dir so the rest of this
# script (which globs [0-9][0-9]_*.icn and expects a sibling .ref) is unchanged below this point.
DIR="$(mktemp -d)"
RUNGS_DIR="$ROOT/../corpus/tests/icon" RUNGS_EXT=.icn source "$HERE/lib_rungs_extract.sh"
rungs_extract_origin_prefix "scrip_test_icon_jcon_audit_" "$DIR" >/dev/null || { echo "AUDIT REFUSED: could not extract jcon_audit probes from the icon rungs"; exit 2; }
UNRESOLVED="$ROOT/../corpus/tests/icon/unresolved"
for f in "$UNRESOLVED"/jcon_audit_*.icn; do
    [ -f "$f" ] || continue
    b="$(basename "$f" .icn)"; b="${b#jcon_audit_}"
    cp "$f" "$DIR/$b.icn"
    [ -f "$UNRESOLVED/jcon_audit_${b}.ref" ] && cp "$UNRESOLVED/jcon_audit_${b}.ref" "$DIR/$b.ref"
done
trap 'rm -rf "$DIR"' EXIT
FILTER="${1:-}"
ICONT="${ICONT:-}"
# ⛔ THIS PROBE USED TO NAME TWO DEAD PATHS -- $S4A/workspace/refs-src/... (never existed) and $ROOT/refs/...
# (SCRIP/refs deleted org-wide, CEO-765) -- and it did NOT refuse when both missed: it left ICONT empty, skipped
# the oracle block entirely, printed "-" in the ORACLE column and silently graded every probe against the
# checked-in .ref files instead of ground truth. The oracle was reachable the whole time at
# /home/resources/icon-master/bin/icont. icont_bin() is the ONE authority for that path.
if [ -z "$ICONT" ]; then ICONT="$(icont_bin 2>/dev/null)" || ICONT=""; fi
[ -n "$ICONT" ] || echo "⚠ ORACLE UNREACHABLE: the ORACLE column reads '-' and every VERDICT below is graded against the checked-in .ref files, NOT against icont. This is not ground truth." >&2
[ -n "$ICONT" ] && export PATH="$(dirname "$ICONT"):$PATH"
W=/tmp/jcon_audit_work; rm -rf "$W"; mkdir -p "$W"
pass=0; fail=0; probebad=0; skip=0
printf "%-22s %-9s %-9s %-9s %s\n" "PROBE" "ORACLE" "MODE3" "MODE4" "VERDICT"
printf "%-22s %-9s %-9s %-9s %s\n" "-----" "------" "-----" "-----" "-------"
for f in "$DIR"/[0-9][0-9]_*.icn; do
  name="$(basename "$f" .icn)"
  case "$name" in *"$FILTER"*) ;; *) continue;; esac
  exp="$(cat "${f%.icn}.ref")"
  # oracle
  orc_status="-"; truth="$exp"
  if [ -n "$ICONT" ]; then
    if "$ICONT" -s -o "$W/$name.orc" "$f" >/dev/null 2>&1; then
      orc="$(timeout -k 5 8 "$W/$name.orc" </dev/null 2>/dev/null)"; orc_rc=$?
      if [ $orc_rc -eq 124 ]; then orc_status="HANG"
      elif [ "$orc" = "${exp%$'\n'}" ] || [ "$orc"$'\n' = "$exp" ]; then orc_status="=exp"; truth="$exp"
      else orc_status="DIFF"; truth="$orc"$'\n'; fi
    else orc_status="NOCOMP"; fi
  fi
  # mode 3
  m3="$(timeout -k 5 8 "$SCRIP" --run "$f" </dev/null 2>/dev/null)"; rc3=$?
  # mode 4
  m4=""; rc4=1
  if timeout -k 5 8 "$SCRIP" --compile "$f" >"$W/$name.s" 2>/dev/null </dev/null && [ -s "$W/$name.s" ]; then
    if gcc -no-pie "$W/$name.s" -L"$RT" -lscrip_rt -Wl,-rpath,"$RT" -o "$W/$name.bin" 2>/dev/null; then
      m4="$(timeout -k 5 8 "$W/$name.bin" </dev/null 2>/dev/null)"; rc4=$?
    else rc4=200; fi
  else rc4=201; fi
  st3="ok"; st4="ok"; t="${truth%$'\n'}"
  if   [ $rc3 -eq 124 ]; then st3="HANG"
  elif [ $rc3 -ge 128 ]; then st3="CRASH"
  elif [ "$m3" != "$t" ]; then st3="BAD"; fi
  if   [ $rc4 -eq 124 ]; then st4="HANG"
  elif [ $rc4 -eq 200 ]; then st4="NOASM"
  elif [ $rc4 -eq 201 ]; then st4="NOCC"
  elif [ $rc4 -ge 128 ]; then st4="CRASH"
  elif [ "$m4" != "$t" ]; then st4="BAD"; fi
  if [ "$orc_status" = "DIFF" ]; then v="PROBE-EXP-WRONG(oracle rules)"; fi
  if [ "$st3" = "ok" ] && [ "$st4" = "ok" ]; then v="OK"; pass=$((pass+1));
  else v="$st3/$st4"; fail=$((fail+1)); fi
  [ "$orc_status" = "NOCOMP" ] && { v="$v (probe not std Icon?)"; }
  printf "%-22s %-9s %-9s %-9s %s\n" "$name" "$orc_status" "$st3" "$st4" "$v"
done
echo "----"
echo "PASS(both modes match truth)=$pass  FAIL=$fail"

# ⭐ V2-5 GATE HONESTY: this script had NO exit statement, and a filter matching zero probes printed
# PASS=0 FAIL=0 and exited 0 -- zero-probes-examined read exactly like all-pass.
. "$(dirname "$0")/lib_gate.sh"
gate_floor "$((pass + fail + probebad + skip))" 1 "jcon audit probes"
gate_verdict "$fail" "probe(s) disagreed with truth"
