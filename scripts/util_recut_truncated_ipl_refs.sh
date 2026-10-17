#!/usr/bin/env bash
# util_recut_truncated_ipl_refs.sh -- re-cut ipl .ref refs that the 2026-09-05 cutter wrote one byte short.
#
# THE DEFECT THIS REPAIRS (hq_I 2026-09-06, FINDING-2026-09-06-hq_I-the-cutter-was-fixed-and-its-artifacts-
# were-not-so-58-of-89-refs-are-one-byte-short.md). util_cut_icon_ipl_refs.sh at da466d28f wrote each ref as
#     out1="$(cat "$OUT1")" ; printf '%s' "$out1" > "$std"
# and command substitution strips ALL trailing newlines, so every ref minted through that path lost its final
# newline. The cutter was later repaired to `cp` the captured file, which is byte-exact -- but the repair
# never reached the 66 refs the broken version had already minted. FIXING AN INSTRUMENT DOES NOT FIX ITS
# OUTPUT, AND ONLY THE INSTRUMENT IS UNDER TEST: a gate proves the cutter is right today and says nothing
# about the artifacts that are doing the grading. Each such ref is a FALSE FAIL charged to the compiler for
# any program whose output ends in a newline.
#
# WHAT THIS REFUSES TO DO, WHICH IS THE POINT:
#   - It NEVER writes SCRIP's output into a ref. Every byte comes from the oracle. SCRIP and the oracle
#     agreeing is the condition under which self-pinning is most tempting and most wrong.
#   - It re-cuts ONLY when the existing ref is EXACTLY the oracle's output minus trailing newlines. Any
#     other difference means the ref is wrong for some OTHER reason, which is a defect to diagnose, never
#     to overwrite -- overwriting it would erase the evidence and manufacture a pass.
#   - It requires the oracle to exit rc=0 and to be byte-identical across TWO runs. ⛔ A program whose
#     oracle run is KILLED (rc=124) is refused even when its output is byte-stable: stability under a
#     timeout is a reproducible truncation, not determinism, and a ref pinned to a killed process pins a
#     lie. progs/oldicon.icn is the live case -- iconx itself is killed there because it drives vim.
#   - With no --apply it CHANGES NOTHING and prints the same table, so the decision is reviewable first.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"; S4E="$(cd "$HERE/../.." && pwd)"
. "$HERE/lib_oracle_flags.sh"
. "$HERE/lib_icon_ipl_isolation.sh"
PKG="$S4E/corpus/packages/icon/ipl"; SUBDIR="progs"; PROGS="$PKG/$SUBDIR"
TIMEOUT="${TIMEOUT:-15}"; MAX_BYTES=1048576; APPLY=0; ONLY=""
while [ $# -gt 0 ]; do case "$1" in
  --apply) APPLY=1;;
  --only) shift; [ $# -gt 0 ] || { echo "⛔ REFUSES(2): --only needs a program name" >&2; exit 2; }; ONLY="$1";;
  --only=*) ONLY="${1#--only=}";;
  *) echo "⛔ REFUSES(2): unknown argument '$1' -- this script takes --apply and --only NAME only" >&2; exit 2;;
esac; shift; done
[ -d "$PROGS" ] || { echo "⛔ REFUSES(2): no such directory $PROGS" >&2; exit 2; }
ICON="$(icon_bin)" || { echo "⛔ REFUSES(2): no Icon oracle -- cannot measure, and a pass here would be a lie" >&2; exit 2; }
ipl_isolation_init "$PKG" || { echo "⛔ REFUSES(2): isolation template setup failed" >&2; exit 2; }
trap 'ipl_isolation_cleanup; rm -f "$O1" "$O2"' EXIT
O1="$(mktemp)"; O2="$(mktemp)"
run_oracle() {
  local f="$1" outfile="$2"; local -a argv=()
  ipl_argv_read "$PROGS/$f" argv; [ $? -eq 2 ] && return 126
  local stdin_src=/dev/null
  [ -f "$PROGS/${f%.icn}.dat" ] && stdin_src="$PROGS/${f%.icn}.dat"
  [ -f "$PROGS/${f%.icn}.in" ] && stdin_src="$PROGS/${f%.icn}.in"
  IPL_ISO_FIXTURES="$PROGS/$f" ipl_isolation_run "$outfile" "$TIMEOUT" "$stdin_src" "$ICON" "$f" ${argv[@]+"${argv[@]}"}
}
n_scan=0; n_short=0; n_recut=0; n_skip=0
printf 'STATUS\tPROGRAM\tRC\tACTION\n'
for std in "$PROGS"/*.ref; do
  [ -e "$std" ] || continue
  base="$(basename "$std" .ref)"; f="$base.icn"
  [ -n "$ONLY" ] && [ "$base" != "$ONLY" ] && continue
  [ -f "$PROGS/$f" ] || continue
  n_scan=$((n_scan+1))
  [ -s "$std" ] || { printf 'SKIP\t%s\t-\tref is empty; not this defect\n' "$base"; n_skip=$((n_skip+1)); continue; }
  if [ "$(tail -c1 "$std" | od -An -c | tr -d ' ')" = '\n' ]; then continue; fi
  n_short=$((n_short+1))
  run_oracle "$f" "$O1"; rc1=$?
  if [ "$rc1" -ne 0 ]; then printf 'SKIP\t%s\t%s\tthe oracle did not exit clean; a ref is only cut from a clean run\n' "$base" "$rc1"; n_skip=$((n_skip+1)); continue; fi
  if [ "$(wc -c < "$O1")" -gt "$MAX_BYTES" ]; then printf 'SKIP\t%s\t0\toutput exceeds the %s-byte cap\n' "$base" "$MAX_BYTES"; n_skip=$((n_skip+1)); continue; fi
  run_oracle "$f" "$O2"; rc2=$?
  if [ "$rc2" -ne 0 ] || ! cmp -s "$O1" "$O2"; then printf 'SKIP\t%s\t%s\tthe oracle disagreed with itself across two runs; not deterministic here\n' "$base" "$rc2"; n_skip=$((n_skip+1)); continue; fi
  if cmp -s "$O1" "$std"; then printf 'SKIP\t%s\t0\tref already equals the oracle; the missing newline is the program own output\n' "$base"; n_skip=$((n_skip+1)); continue; fi
  stripped="$(mktemp)"; printf '%s' "$(cat "$O1")" > "$stripped"
  if cmp -s "$stripped" "$std"; then
    if [ "$APPLY" -eq 1 ]; then cp "$O1" "$std"; printf 'RECUT\t%s\t0\tref was the oracle output minus its trailing newline; re-cut from the ORACLE\n' "$base"
    else printf 'WOULD_RECUT\t%s\t0\tref is the oracle output minus its trailing newline (no change; pass --apply)\n' "$base"; fi
    n_recut=$((n_recut+1))
  else
    printf 'SKIP\t%s\t0\tdiffers from the oracle by more than trailing newlines -- a real difference, diagnose it, never overwrite it\n' "$base"
    n_skip=$((n_skip+1))
  fi
  rm -f "$stripped"
done
printf 'TOTALS: scanned=%d short_refs=%d recut=%d skipped=%d apply=%d\n' "$n_scan" "$n_short" "$n_recut" "$n_skip" "$APPLY"
[ "$n_scan" -eq 0 ] && { echo "⛔ REFUSES(2): scanned zero refs -- an empty population never prints a success" >&2; exit 2; }
exit 0
