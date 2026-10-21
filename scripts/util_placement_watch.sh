#!/usr/bin/env bash
# util_placement_watch.sh -- THE RSP/RBP HOST COUNT, KEPT CURRENT PER ORIGIN TREE (Lon 2026-10-21, in-chat to the ceo, verbatim: "I want to see a
# COUNT of RSP hosted locals and operands, and a COUNT of RBP hosted locals and operands. I should see that at every turn. As you fix the
# programs I should see the numbers changing." · "I should also see a count of RSP resets at BETA and see the count go to ZERO."; ceo CEO-1855).
#
# The count is util_bb_placement_census.py's BB_HOSTS line per language over the committed-artifact programs (every benchmark and demo that
# carries a .s), compiled by SCRIP at origin/main. A census takes minutes, so it never runs inside a turn: `kick` starts a measurement in the
# background when origin/main of SCRIP, corpus or harness has moved past the last reading, and `show` prints the newest reading and its change
# against the reading before it, instantly, from the record. The measurement runs in git worktrees of this root's own repos under
# /tmp/s4e-placement-<root> (never a link, never this root's working tree, so nothing the seat is doing moves under it), built with its own
# objdir at make -j8 under nice.
#
#   util_placement_watch.sh show    the newest reading (four lines), whether a newer origin is being measured
#   util_placement_watch.sh kick    start a measurement in the background if origin moved; returns at once
#   util_placement_watch.sh run     measure now, in the foreground (what kick runs)
#
# RECORD: /home/resources/progress/PLACEMENT.tsv, one row per (reading, language): when, scrip, corpus, harness, lang, ops_rsp, ops_rbp,
# ops_precarved, ops_none, loc_rsp, loc_rbp, loc_rbp_forced, loc_rbp_misplaced, loc_none, graphs (each distinct graph once), ops_prealloc.
# PRE-ALLOCATIONS (Lon 2026-10-21: "I should see a count of pre-allocations and see it go to ZERO. SPINE allocations MUST ONLY be allocated
# PER BOX and at ALPHA at EACH BOX.") = ops_prealloc (a box granted a frame slot at entry that is not its RBP home) + ops_precarved (an operand
# carved at entry) + loc_rbp_misplaced (a local carved at entry that passes both tests).
# BETA RESETS: /home/resources/progress/BETA_RESETS.tsv, one row per (reading, language): when, scrip, corpus, harness, lang, beta_resets, functions,
# programs, beta_allocs (Lon: "I'd like to also see a count of ALLOCATIONS at BETA." -- reported, not forbidden: util_alloc_by_port_census.py's
# beta segments whose code leaves rsp below where it found it) -- util_rsp_reset_by_port_census.py over every committed-artifact program plus every Pascal, Raku, Snocone and Rebus demo and benchmark
# source, compiled at the same origin (Lon: a beta never resets rsp; the count goes to zero).
# rc 0 shown/measured/nothing to do · rc 2 could not measure (named: fetch, worktree, build or census failed).
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
W="/tmp/s4e-placement-$(basename "$ROOT")"
REC=/home/resources/progress/PLACEMENT.tsv
BREC=/home/resources/progress/BETA_RESETS.tsv
LOCK="$W.lock"
LOG="$W.log"
HDR='when	scrip	corpus	harness	lang	ops_rsp	ops_rbp	ops_precarved	ops_none	loc_rsp	loc_rbp	loc_rbp_forced	loc_rbp_misplaced	loc_none	graphs	ops_prealloc'

tips() { for r in SCRIP corpus harness; do git -C "$ROOT/$r" rev-parse --short=9 origin/main 2>/dev/null || echo '?'; done | tr '\n' ' '; }

do_show() {
    if [ ! -s "$REC" ] || [ "$(wc -l < "$REC")" -lt 2 ]; then echo "PLACEMENT: no reading yet -- the first is measuring (util_placement_watch.sh)"; return 0; fi
    python3 - "$REC" "$LOCK" "$(git -C "$ROOT/SCRIP" rev-parse --short=9 origin/main 2>/dev/null)" "$BREC" <<'PY'
import sys, os, fcntl
rec, lock, tip, brec = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
rows = [l.rstrip('\n').split('\t') for l in open(rec, encoding='utf-8') if l.strip() and not l.startswith('when\t')]
keys = []
for r in rows:
    k = (r[0], r[1])
    if not keys or keys[-1] != k:
        keys.append(k)
def agg(k):
    t, per = {}, {}
    for r in rows:
        if (r[0], r[1]) != k:
            continue
        v = dict(zip(['ops_rsp', 'ops_rbp', 'ops_precarved', 'ops_none', 'loc_rsp', 'loc_rbp', 'loc_rbp_forced', 'loc_rbp_misplaced', 'loc_none', 'graphs', 'ops_prealloc'], map(int, r[5:16])))
        v.setdefault('ops_prealloc', -1)
        v['prealloc'] = v['ops_prealloc'] + v['ops_precarved'] + v['loc_rbp_misplaced'] if v['ops_prealloc'] >= 0 else -1
        per[r[4]] = v
        for kk, vv in v.items():
            t[kk] = t.get(kk, 0) + vv
    return t, per
busy = False
try:
    fd = os.open(lock, os.O_RDONLY)
    try:
        fcntl.flock(fd, fcntl.LOCK_EX | fcntl.LOCK_NB); fcntl.flock(fd, fcntl.LOCK_UN)
    except OSError:
        busy = True
except OSError:
    pass
cur = keys[-1]
t, per = agg(cur)
f = lambda n: format(n, ',')
state = '' if tip == cur[1] else (' -- measuring origin %s now' % tip if busy else ' -- origin is at %s, not yet measured' % tip)
print('PLACEMENT @ SCRIP %s, read %s, %d graphs of the committed Icon/Prolog/SNOBOL4 programs%s' % (cur[1], cur[0][11:16], t['graphs'], state))
print('  operands: RSP %s  RBP %s   |   locals: RSP %s  RBP %s (%s forced, %s misplaced)' % (f(t['ops_rsp']), f(t['ops_rbp']), f(t['loc_rsp']), f(t['loc_rbp']), f(t['loc_rbp_forced']), f(t['loc_rbp_misplaced'])))
pa = t['prealloc'] if all(v['prealloc'] >= 0 for v in per.values()) else None
print('  PRE-ALLOCATIONS: %s (frame slots granted to a non-RBP box %s, operands carved at entry %s, locals carved at entry that pass both tests %s)' % (f(pa), f(t['ops_prealloc']), f(t['ops_precarved']), f(t['loc_rbp_misplaced'])) if pa is not None else '  PRE-ALLOCATIONS: not in this reading (the next one carries it)')
print('  ' + ' · '.join('%s RSP %s/%s RBP %s/%s' % (l, f(v['ops_rsp']), f(v['loc_rsp']), f(v['ops_rbp']), f(v['loc_rbp'])) for l, v in sorted(per.items())) + '  (operands/locals)')
if len(keys) > 1:
    p, _ = agg(keys[-2])
    d = lambda k: '%+d' % (t[k] - p[k])
    print('  since SCRIP %s: operands RSP %s RBP %s | locals RSP %s RBP %s | pre-allocations %s' % (keys[-2][1], d('ops_rsp'), d('ops_rbp'), d('loc_rsp'), d('loc_rbp'), d('prealloc') if p.get('prealloc', -1) >= 0 and t.get('prealloc', -1) >= 0 else 'n/a'))
if os.path.isfile(brec):
    br = [l.rstrip('\n').split('\t') for l in open(brec, encoding='utf-8') if l.strip() and not l.startswith('when\t')]
    bk = []
    for r in br:
        if not bk or bk[-1] != (r[0], r[1]):
            bk.append((r[0], r[1]))
    if bk:
        cb = {r[4]: int(r[5]) for r in br if (r[0], r[1]) == bk[-1]}
        ca = {r[4]: int(r[8]) for r in br if (r[0], r[1]) == bk[-1] and len(r) > 8 and int(r[8]) >= 0}
        tot = sum(cb.values())
        prev = ''
        if len(bk) > 1:
            pb = sum(int(r[5]) for r in br if (r[0], r[1]) == bk[-2])
            prev = ' (%+d since SCRIP %s)' % (tot - pb, bk[-2][1])
        print('  RSP resets at beta @ SCRIP %s: %s%s -- %s' % (bk[-1][1], f(tot), prev, ' · '.join('%s %s' % (l, f(v)) for l, v in sorted(cb.items(), key=lambda kv: -kv[1]))))
        if ca:
            print('  allocations at beta (reported, allowed): %s -- %s' % (f(sum(ca.values())), ' · '.join('%s %s' % (l, f(v)) for l, v in sorted(ca.items(), key=lambda kv: -kv[1]))))
PY
}

do_run() {
    exec 9>"$LOCK"
    flock -n 9 || return 0
    for r in SCRIP corpus harness; do git -C "$ROOT/$r" fetch -q origin 2>>"$LOG" || { echo "REFUSE(2): fetch of $r failed" >>"$LOG"; return 2; }; done
    local t s c h last
    t="$(tips)"; s="$(echo $t | cut -d' ' -f1)"; c="$(echo $t | cut -d' ' -f2)"; h="$(echo $t | cut -d' ' -f3)"
    last="$( [ -s "$REC" ] && tail -1 "$REC" | cut -f2-4 | tr '\t' ' ')"
    [ "$last" = "$s $c $h" ] && return 0
    mkdir -p "$W"
    for r in SCRIP corpus harness; do
        if [ -e "$W/$r/.git" ]; then git -C "$W/$r" checkout -q --detach origin/main 2>>"$LOG" || { echo "REFUSE(2): checkout in $W/$r" >>"$LOG"; return 2; }
        else git -C "$ROOT/$r" worktree prune; git -C "$ROOT/$r" worktree add -q --detach "$W/$r" origin/main 2>>"$LOG" || { echo "REFUSE(2): worktree $r" >>"$LOG"; return 2; }; fi
    done
    ( cd "$W/SCRIP" && nice -n 10 make -j8 ) >>"$LOG" 2>&1 || { echo "REFUSE(2): build at $s" >>"$LOG"; return 2; }
    local out="$W/census.out"
    ( cd "$W/SCRIP" && env -u S4E_HOME nice -n 10 python3 "$W/harness/scripts/util_bb_placement_census.py" ) >"$out" 2>>"$LOG" || { echo "REFUSE(2): census at $s" >>"$LOG"; return 2; }
    grep -q '^BB_HOSTS ' "$out" || { echo "REFUSE(2): census printed no BB_HOSTS at $s" >>"$LOG"; return 2; }
    [ -s "$REC" ] || printf '%s\n' "$HDR" > "$REC"
    local now; now="$(date '+%Y-%m-%dT%H:%M:%S')"
    python3 - "$out" "$now" "$s" "$c" "$h" >> "$REC" <<'PY'
import re, sys
out, now, s, c, h = sys.argv[1:6]
progs = {}
for ln in open(out, encoding='utf-8'):
    m = re.match(r'^BB_PLACEMENT (\S+) graphs=(\d+)', ln)
    if m:
        progs[m.group(1)] = int(m.group(2))
for ln in open(out, encoding='utf-8'):
    if ln.startswith('BB_HOSTS '):
        p = ln.split()
        v = dict(x.split('=') for x in p[2:])
        cols = [v[k] for k in ('ops_rsp', 'ops_rbp', 'ops_precarved', 'ops_none', 'loc_rsp', 'loc_rbp', 'loc_rbp_forced', 'loc_rbp_misplaced', 'loc_none')]
        sys.stdout.write('\t'.join([now, s, c, h, p[1]] + cols + [str(progs.get(p[1], 0)), v.get('ops_prealloc', '-1')]) + '\n')
PY
    local A="$W/asm" i=0 lang f stem e
    rm -rf "$A"; mkdir -p "$A"
    { find "$W/corpus/benchmarks" "$W/corpus/demos" -name '*.s' | sort | while read -r f; do stem="${f%.s}"; for e in sno icn pl; do [ -f "$stem.$e" ] && echo "$e $stem.$e"; done; done
      for e in pas raku sc reb; do find "$W/corpus/demos" "$W/corpus/benchmarks" -name "*.$e" | sort | sed "s|^|$e |"; done; } > "$A/list"
    while read -r e f; do
        case "$e" in sno) lang=snobol4;; icn) lang=icon;; pl) lang=prolog;; pas) lang=pascal;; raku) lang=raku;; sc) lang=snocone;; reb) lang=rebus;; esac
        i=$((i+1)); mkdir -p "$A/$lang"
        ( cd "$(dirname "$f")" && timeout -k 5 300 nice -n 10 "$W/SCRIP/scrip" --compile $( [ "$lang" = prolog ] && echo --target=x86 ) -o "$A/$lang/$i.s" "$(basename "$f")" < /dev/null >/dev/null 2>&1 ) || rm -f "$A/$lang/$i.s"
    done < "$A/list"
    [ -s "$BREC" ] || printf 'when\tscrip\tcorpus\tharness\tlang\tbeta_resets\tfunctions\tprograms\tbeta_allocs\n' > "$BREC"
    local BTMP="$W/beta_rows.tmp"; : > "$BTMP"
    for lang in $(ls "$A" | grep -v '^list$'); do
        local n; n="$(ls "$A/$lang"/*.s 2>/dev/null | wc -l)"; [ "$n" -gt 0 ] || continue
        local line; line="$(nice -n 10 python3 "$W/harness/scripts/util_rsp_reset_by_port_census.py" "$A/$lang"/*.s 2>>"$LOG" | grep '^RSP_RESET functions=')"
        [ -n "$line" ] || { echo "REFUSE(2): rsp reset census measured nothing for $lang at $s" >>"$LOG"; continue; }
        local b fn; b="$(echo "$line" | grep -o 'beta=[0-9]*' | cut -d= -f2)"; fn="$(echo "$line" | grep -o 'functions=[0-9]*' | cut -d= -f2)"
        local ba; ba="$(nice -n 10 python3 "$W/harness/scripts/util_alloc_by_port_census.py" "$A/$lang.alloc.tsv" "$A/$lang"/*.s 2>>"$LOG" | grep '^NET_PORT port=beta ' | grep -o 'allocating=[0-9]*' | cut -d= -f2)"
        printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$now" "$s" "$c" "$h" "$lang" "${b:-0}" "${fn:-0}" "$n" "${ba:--1}" >> "$BTMP"
    done
    cat "$BTMP" >> "$BREC"; rm -f "$BTMP"
    rm -rf "$A"
    return 0
}

case "${1:-show}" in
    show) do_show ;;
    kick) ( setsid nohup bash "$HERE/util_placement_watch.sh" run >/dev/null 2>&1 & ) ; exit 0 ;;
    run)  do_run; exit $? ;;
    *) echo "usage: util_placement_watch.sh show|kick|run" >&2; exit 2 ;;
esac
