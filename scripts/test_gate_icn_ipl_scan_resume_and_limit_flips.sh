#!/usr/bin/env bash
# test_gate_icn_ipl_scan_resume_and_limit_flips.sh -- hq_R, OCTET row flip-ipl-scan-resume-and-limit.
# ⛔⭐ R IS COMPUTED FROM THIS SCRIPT'S OWN LOCATION AND MUST STAY THAT WAY (cfo 2026-09-09 17:17). This
# line used to compute R and then immediately reassign it to the literal /home/claude_R, so the gate ran
# THIS author's binary against THIS author's corpus inside every other seat's make test: a green there
# graded a tree nobody was landing, and a red would have been the wrong seat's to explain on their own
# console. A gate that hardcodes one root measures one root, whatever thirteen consoles print.
# ⭐ NOTE THE TWO HALVES ARE ONE DEFECT: cfo's freshness guard (47781cd12) checks the SEAT'S OWN binary,
# and the literal below it pointed the gate body at a DIFFERENT one -- so the guard would have certified
# the caller's tree while the arms graded mine. Both lines have to agree about which root this is, and
# now they do, because there is only one expression for it.
R="$(cd "$(dirname "$0")/../.." && pwd)"
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
. "$R/harness/scripts/lib_icon_ipl_isolation.sh"
PKG="$R/corpus/packages/icon/ipl"; SCRIP="$R/SCRIP/scrip"
T=$(mktemp -d); trap 'rm -rf "$T"; ipl_isolation_cleanup' EXIT
ipl_isolation_init "$PKG"
rc=0
for base in datmerge ibrow miu; do
  icn=$(ls "$PKG"/*/"$base".icn | head -1); std="${icn%.icn}.ref"
  declare -a A=(); ipl_argv_read "$icn" A
  export IPL_ISO_SUBDIR="$(basename "$(dirname "$std")")" IPL_ISO_FIXTURES="$icn"
  sin=/dev/null; [ -f "${icn%.icn}.in" ] && sin="${icn%.icn}.in"
  if [ "${#A[@]}" -gt 0 ]; then ipl_isolation_run "$T/$base.m3" 60 "$sin" "$SCRIP" --run "$icn" -- "${A[@]}"; else ipl_isolation_run "$T/$base.m3" 60 "$sin" "$SCRIP" --run "$icn"; fi
  diff -q "$std" "$T/$base.m3" >/dev/null || { echo "RED $base m3"; rc=1; }
  "$SCRIP" --compile "$icn" > "$T/$base.s" 2>/dev/null </dev/null
  gcc -no-pie "$T/$base.s" -L"$R/SCRIP/out" -lscrip_rt -Wl,-rpath,"$R/SCRIP/out" -o "$T/$base.bin" 2>/dev/null
  if [ "${#A[@]}" -gt 0 ]; then ipl_isolation_run "$T/$base.m4" 60 "$sin" "$T/$base.bin" "${A[@]}"; else ipl_isolation_run "$T/$base.m4" 60 "$sin" "$T/$base.bin"; fi
  diff -q "$std" "$T/$base.m4" >/dev/null || { echo "RED $base m4"; rc=1; }
  [ $rc -eq 0 ] && echo "GREEN $base m3+m4"
done
exit $rc
