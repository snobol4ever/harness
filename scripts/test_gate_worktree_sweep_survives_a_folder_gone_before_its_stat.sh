#!/usr/bin/env bash
# test_gate_worktree_sweep_survives_a_folder_gone_before_its_stat.sh -- s4e_worktree.sh sweep (and so new) survives a worktree folder another seat removes
# between the sweep's listing and its stat (the cio's ruling 2026-11-11 on officer_04's measurement: junior_19's wt-bt-held vanished, stat printed nothing,
# line 145's arithmetic aborted the whole new). The race is made exact, never timed: a scratch TOP holds one planted marker worktree, and a stat shim on PATH
# answers that one folder as stat answers a folder that is gone (nothing on stdout, rc 1). GREEN: sweep exits 0 and prints its SWEPT line. RED: it does not.
# REFUSE(2): the shim never saw the planted folder (the plant did not reach the stat, so nothing was measured). Scratch only: no live postoffice, no live tube.
set -u
H="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
W="$H/scripts/s4e_worktree.sh"
[ -f "$W" ] || { echo "REFUSE(2) [test_gate_worktree_sweep_survives_a_folder_gone_before_its_stat]: no $W"; exit 2; }
T="$(mktemp -d "${TMPDIR:-/tmp}/s4e-wtsweep.XXXXXX")" || { echo "REFUSE(2) [test_gate_worktree_sweep_survives_a_folder_gone_before_its_stat]: no scratch"; exit 2; }
trap 'rm -rf "$T"' EXIT
mkdir -p "$T/top/seatx/wt-gone" "$T/po/tasks" "$T/bin"
: > "$T/top/seatx/wt-gone/.s4e-worktree"
: > "$T/po/QUEUE.tsv"; : > "$T/po/QUEUE.done.tsv"; : > "$T/po/QUEUE.retired.tsv"
REAL="$(command -v stat)"
cat > "$T/bin/stat" <<EOF
#!/usr/bin/env bash
for a in "\$@"; do case "\$a" in */wt-gone) : > "$T/shim.fired"; echo "stat: cannot statx '\$a': No such file or directory" >&2; exit 1 ;; esac; done
exec "$REAL" "\$@"
EOF
chmod +x "$T/bin/stat"
out="$(S4E_WT_TOP="$T/top" S4E_POSTOFFICE="$T/po" PATH="$T/bin:$PATH" timeout -k 5 60 bash "$W" sweep 2>&1 < /dev/null)"; rc=$?
[ -f "$T/shim.fired" ] || { echo "WORKTREE_SWEEP_BOARD rc=$rc shim=0 (tree $(git -C "$H" rev-parse --short HEAD 2>/dev/null))"; echo "REFUSE(2) [test_gate_worktree_sweep_survives_a_folder_gone_before_its_stat]: the stat shim never saw the planted folder"; exit 2; }
line="$(printf '%s\n' "$out" | grep -m1 '^SWEPT ')"
sl=0; [ -n "$line" ] && sl=1
echo "WORKTREE_SWEEP_BOARD rc=$rc shim=1 swept_line=$sl (tree $(git -C "$H" rev-parse --short HEAD 2>/dev/null))"
if [ "$rc" = 0 ] && [ -n "$line" ]; then echo "GATE OK [test_gate_worktree_sweep_survives_a_folder_gone_before_its_stat]: the sweep went on past a folder gone before its stat"; exit 0; fi
printf '%s\n' "$out" | tail -3 | sed 's/^/  /'
echo "GATE FAIL [test_gate_worktree_sweep_survives_a_folder_gone_before_its_stat]: the sweep did not finish when a folder was gone before its stat (rc=$rc)"
exit 1
