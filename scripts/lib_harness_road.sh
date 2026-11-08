#!/usr/bin/env bash
# lib_harness_road.sh -- DESIGN-PLAN batch-grader step 7c0 (officer_06, 2026-11-08; skill suites-and-grading section 5, THING 1 FAMILIES C AND D).
# The one library a suite runner with its own per-program loop sources to take the harness road in mode 3: the runner lists its rows
# (hr_row once per program), runs them as ONE scrip --harness (hr_run), and reads each row's verdict from the record (hr_get). A row the record
# does not grade as RAN or CRASH (HANG, REFUSED, no row, or S4E_BATCH not 1) falls back to the runner's per-process line, where its timeout retry lives.
# Sourced, never executed: no set -e, no exit, functions only; each function returns.
hr_begin() {
    mkdir -p "$1/out"
    : > "$1/harness.list"
    rm -f "$1/harness.rec"
    HR_DIR="$1"
}
hr_row() {
    [ "${S4E_BATCH:-}" = 1 ] || return 0
    local merged=0
    if [ "${1:-}" = --merged ]; then merged=1; shift; fi
    local name="$1" src="$2" stdin="$3" tmo="$4" cwd="$5"
    shift 5
    local k="${name//\//__}" serr
    serr="$HR_DIR/out/$k.err"
    [ "$merged" = 1 ] && serr=merged
    local line="name=$name"$'\t'"stdin=$stdin"$'\t'"stdout=$HR_DIR/out/$k.out"$'\t'"stderr=$serr"$'\t'"cwd=$cwd"$'\t'"timeout_s=$tmo"
    while [ $# -gt 0 ] && [ "$1" != -- ]; do line="$line"$'\t'"$1"; shift; done
    [ "${1:-}" = -- ] && shift
    line="$line"$'\t'"$src"
    while [ $# -gt 0 ]; do line="$line"$'\t'"$1"; shift; done
    printf '%s\n' "$line" >> "$HR_DIR/harness.list"
    return 0
}
hr_run() {
    local scrip="$1" n t m ra cr hg rf
    n=$(awk 'END{print NR+0}' "$HR_DIR/harness.list")
    if [ "$n" = 0 ]; then echo "HARNESS_ROAD rows=0"; return 0; fi
    t=$(awk -F'\t' '{for (i=1;i<=NF;i++) if ($i ~ /^timeout_s=/) {v=$i; sub(/^timeout_s=/, "", v); s+=v}} END{print s+60}' "$HR_DIR/harness.list")
    timeout -k 5 "$t" "$scrip" --harness "$HR_DIR/harness.list" --record "$HR_DIR/harness.rec" < /dev/null > "$HR_DIR/scrip.log" 2>&1
    m=0; ra=0; cr=0; hg=0; rf=0
    if [ -f "$HR_DIR/harness.rec" ]; then
        m=$(awk 'END{print NR+0}' "$HR_DIR/harness.rec")
        read -r ra cr hg rf <<< "$(awk -F'\t' '{k[$3]++} END{print k["RAN"]+0, k["CRASH"]+0, k["HANG"]+0, k["REFUSED"]+0}' "$HR_DIR/harness.rec")"
    fi
    echo "HARNESS_ROAD rows=$n recorded=$m ran=$ra crash=$cr hang=$hg refused=$rf"
    return 0
}
hr_get() {
    [ "${S4E_BATCH:-}" = 1 ] || return 1
    [ -f "$HR_DIR/harness.rec" ] || return 1
    local row
    row=$(awk -F'\t' -v n="$1" '$1==n {print $2, $3, $4; exit}' "$HR_DIR/harness.rec")
    [ -n "$row" ] || return 1
    read -r HR_RC HR_KIND HR_SECS <<< "$row"
    case "$HR_KIND" in HANG|REFUSED) return 1 ;; esac
    local k="${1//\//__}"
    HR_OUT="$HR_DIR/out/$k.out"
    HR_ERR="$HR_DIR/out/$k.err"
    return 0
}
