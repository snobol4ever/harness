#!/bin/bash
# box_act.sh -- THE TICK'S ACTUATORS (row tick-act-arms-copied-from-the-controller, the cio's ruling 2026-11-07; skill shared-box): a verbatim copy of box_controller.sh's unit_of(), apply() (its lines 39 to 57) and the BOX.state line (its lines 122, 124 and 125), with the decided substitutions: $S/ -> ${S4E_BOX_S:-/home/claude_coo/.scratch/verifier}/; the BOX.state path -> ${S4E_BOX_STATE:-/home/resources/progress/BOX.state}; systemctl set-property prefixed by run; the jobserver set and the s4e_msg.sh send pipes prefixed by run (the jobserver's run sits before setsid, which cannot exec a shell function); the decide text read from stdin into $DL where the controller reads $S/decide.last. S4E_ACT_DRY=1 prints each run line as DRY and runs nothing. Usage: box_act.sh < decide.last (apply, then the BOX.state line).
U=/sys/fs/cgroup/user.slice/user-$(id -u).slice/user@$(id -u).service; TERM_SL=$U/app.slice/app-org.gnome.Terminal.slice; export XDG_RUNTIME_DIR=/run/user/$(id -u)
_act_here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; JS=$_act_here/util_jobserver.sh; MSG=$_act_here/s4e_msg.sh; P=${S4E_BOX_P:-/home/resources/progress}
run() { if [ "${S4E_ACT_DRY:-0}" = 1 ]; then printf 'DRY %s\n' "$*"; else "$@"; fi; }
unit_of() { local p n; for p in $(pgrep -f '^claude --name '); do n=$(tr '\0' ' ' < /proc/$p/cmdline | awk '{print tolower($3)}' | tr '-' '_'); [ "$n" = "$1" ] && { cut -d: -f3 /proc/$p/cgroup | sed 's|.*/||'; return 0; }; done; return 1; }
apply() {  # the ACTUATOR lines of decide() on stdin -> the box; every change logged in box_controller.log
  local k a b c d kv seat q fr t pid act u
  while read -r k a rest; do [ "$k" = ACTUATOR ] || continue; declare -A v=(); for kv in $rest; do v[${kv%%=*}]=${kv#*=}; done
    case "$a" in
      grader) echo "${v[width]}" > ${S4E_BOX_S:-/home/claude_coo/.scratch/verifier}/box.width.tmp && mv ${S4E_BOX_S:-/home/claude_coo/.scratch/verifier}/box.width.tmp ${S4E_BOX_S:-/home/claude_coo/.scratch/verifier}/box.width;;
      sessions) [ "${v[quota]}" != "${v[from]}" ] && run systemctl --user set-property --runtime app-org.gnome.Terminal.slice CPUQuota=${v[quota]}% 2>/dev/null && echo "$(date '+%F %T') SESSIONS QUOTA ${v[from]}% -> ${v[quota]}% ${v[why]}";;
      batch) [ "${v[quota]}" != "$(awk '{if ($1=="max") print 1600; else printf "%d", $1/$2*100}' $U/s4e.slice/s4e-batch.slice/cpu.max)" ] && run systemctl --user set-property --runtime s4e-batch.slice CPUQuota=${v[quota]}% 2>/dev/null && echo "$(date '+%F %T') BATCH QUOTA -> ${v[quota]}%";;
      jobserver) [ "${v[tokens]}" != "${v[from]}" ] && { ( exec 7>&-; run setsid timeout -k 2 20 bash $JS set "${v[tokens]}" > /dev/null 2>&1 & ); echo "$(date '+%F %T') JOBSERVER TOKENS ${v[from]} -> ${v[tokens]} ${v[why]} (detached; a set that waits for tokens never blocks the tick, 16:02 stall)"; };;
      seatcap) seat=${v[seat]}; u=$(unit_of "$seat") || continue
        if [ "${v[quota]}" = 200 ]; then run systemctl --user set-property --runtime "$u" CPUQuota=200% 2>/dev/null && mkdir -p ${S4E_BOX_S:-/home/claude_coo/.scratch/verifier}/governor && printf '%s\t%s\t%s\t%s\n' "$(date +%s)" "$u" "${v[why]##*=}" "$(awk '/usage_usec/{print $2}' $TERM_SL/$u/cpu.stat)" > ${S4E_BOX_S:-/home/claude_coo/.scratch/verifier}/governor/$seat.cap && echo "$(date '+%F %T') SEATCAP $seat -> 200% ${v[why]}" && printf 'coo box controller, %s: your session ran %s cores holding no run or compile slot, so it is capped at 2 cores until it runs calm 30 min. Take a slot (util_run_slot.sh) or the batch class (util_batch.sh) for heavy work.\n' "$(date '+%F %H:%M')" "${v[why]##*=}" | run bash "$MSG" send "$seat" "box-seatcap-$(date +%Y%m%dT%H%M)" --stdin > /dev/null 2>&1
        else run systemctl --user set-property --runtime "$u" CPUQuota=400% 2>/dev/null && rm -f ${S4E_BOX_S:-/home/claude_coo/.scratch/verifier}/governor/$seat.cap ${S4E_BOX_S:-/home/claude_coo/.scratch/verifier}/governor/$seat.last && echo "$(date '+%F %T') SEATCAP $seat -> 400% ${v[why]}"; fi;;
      orphan) pid=${v[pid]}; mkdir -p ${S4E_BOX_S:-/home/claude_coo/.scratch/verifier}/orphan.told; f=${S4E_BOX_S:-/home/claude_coo/.scratch/verifier}/orphan.told/$pid   # Lon 2026-11-04: "can you not co-ordinate with proper seat to kill their own orphans?" -- the seat kills its own, by pid
        if [ ! -f "$f" ]; then date +%s > "$f"; echo "$(date '+%F %T') ORPHAN TOLD seat=${v[seat]} pid=$pid ${v[why]}"
          printf 'coo box controller, %s: your session has an ORPHANED process, pid %s (%s), its parent gone. Kill it by pid with its children now (kill %s; pgrep -P %s for the children), unless it is a live job you want, in which case reply one line and move such work to util_batch.sh or the tool'"'"'s own background mode. You are told once; if it still runs in 30 min the coo follows up.\n' "$(date '+%F %H:%M')" "$pid" "${v[why]}" "$pid" "$pid" | run bash "$MSG" send "${v[seat]}" "box-orphan-$pid" --stdin > /dev/null 2>&1
        elif [ $(( $(date +%s) - $(cat "$f") )) -ge 1800 ] && [ ! -f "$f.esc" ]; then touch "$f.esc"; printf '%s WAKE %s orphan pid %s still runs 30 min after the seat was told (%s)\n' "$(date '+%F %T')" "$(echo ${v[seat]} | tr a-z_ A-Z-)" "$pid" "${v[why]}" >> ${S4E_BOX_S:-/home/claude_coo/.scratch/verifier}/wake.pending; echo "$(date '+%F %T') ORPHAN ESCALATED seat=${v[seat]} pid=$pid"; fi;;
      maint) echo "${v[admit]}" > ${S4E_BOX_S:-/home/claude_coo/.scratch/verifier}/maint.admit; echo "${v[why]}" > ${S4E_BOX_S:-/home/claude_coo/.scratch/verifier}/maint.why;;
      reclaim) u=$(unit_of "${v[seat]}") && echo "2G swappiness=0" > $TERM_SL/$u/memory.reclaim 2>/dev/null;;
    esac; unset v; done
}
write_box_state() {   # the BOX.state line of box_controller.sh, the same three lines (DL holds the decide text)
  w=$(cat ${S4E_BOX_S:-/home/claude_coo/.scratch/verifier}/box.width); why=$(awk '$2=="grader" {for (i=3;i<=NF;i++) if ($i ~ /^why=/) print substr($i,5)}' "$DL"); rec=$(grep -c '^ACTUATOR reclaim' "$DL")
  state=$(printf 'ts=%s busy=%s cores=%s cpu_psi10=%s cpu_psi60=%s mem_psi10=%s io_psi10=%s grader_cpu_psi10=%s grader_mem_psi10=%s memavail_mb=%s tmp_pct=%s home_pct=%s%s grader_queue=%s rows_per_hour=%s %s seat_cpu=%s timeouts10=%s grader_width=%s action=%s reclaimed=%s' "$(date '+%FT%T%z')" "$busy" "$(nproc)" "$cpu10" "$cpu60" "$mem10" "$io10" "$gcpu10" "$gmem10" "$memavail" "$tmpp" "$homep" "$sl" "$q" "$rph" "$lap" "${scpu#,}" "$to_now" "$w" "${why// /_}" "${rec:-none}")
  printf '%s\n' "$state" | tr ' ' '\n' > ${S4E_BOX_STATE:-/home/resources/progress/BOX.state}.tmp && mv ${S4E_BOX_STATE:-/home/resources/progress/BOX.state}.tmp ${S4E_BOX_STATE:-/home/resources/progress/BOX.state}; printf '%s\n' "$state" | tr ' ' '\t' >> $P/BOX.tsv
}
main() {   # the tick's hand on the box: the decide text on stdin, applied, then the state line
  DL="$(mktemp "${TMPDIR:-/tmp}/box_act.XXXXXX")" || return 2
  cat > "$DL"; apply < "$DL"; write_box_state; rm -f "$DL"
}
[ "${BASH_SOURCE[0]}" = "$0" ] && main "$@"
