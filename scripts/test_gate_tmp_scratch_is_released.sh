#!/usr/bin/env bash
# test_gate_tmp_scratch_is_released.sh -- every scratch a script makes under /tmp is released by that script (ceo 2026-10-01,
# Lon: "find out why /tmp keeps filling and fix the root problem"). Measured that morning on a 63 GB /tmp at 90%: 6957
# top-level entries, 4466 of them older than 48 h, from Python censuses that mkdtemp'd and never rmtree'd (gc_cov 754,
# c_alloc_* 2740, suite_pop_diff 481, ...) and shell bodies whose work dir outlived a signal. Two static arms, NO BUILD:
#   ARM 1  every tempfile.mkdtemp( / mkstemp( in ../harness/scripts/*.py either registers its own removal ON THE SAME LINE
#          (atexit ... rmtree / TemporaryDirectory) or sits in a file carrying at least as many rmtree/unlink/remove calls
#          as creations. Offenders must be 0 -- an absolute, because the cure is one clause per site.
#   ARM 2  ../harness/scripts/*.sh calling mktemp with no `trap` anywhere in the file: a RATCHET, at most CEIL (lowered, never raised).
# SELF-PROOF first, on fixtures under mktemp: a planted bare mkdtemp reads 1 offender, a planted registering line reads 0.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
CEIL=73   # measured 2026-10-01 at SCRIP c798131e2 after two cures; lower it when you cure one, never raise it
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT; trap 'rm -rf "$W"; exit 143' TERM; trap 'rm -rf "$W"; exit 130' INT
fail=0; ck() { if [ "$1" = ok ]; then echo "  ✅ $2"; else echo "  ⛔ $2"; fail=$((fail+1)); fi; }
# ⛔ ONE grep PER PATTERN, NOT PER FILE (coo 2026-10-08): the per-file loops forked about 1900 greps over 161 .py and 1642 .sh
# files, 6 to 11 s of CPU (mostly sys) under load, and test_gate_preflight_arms_stay_cheap read this arm SLOW over its 5 s budget
# in pass 42's blocking set. The counts are read in one pass and joined; only an offending file's lines are read one file at a time.
MK='tempfile\.mkdtemp\(|tempfile\.mkstemp\(|_tf\.mkdtemp\(|_tf\.mkstemp\('
FR='rmtree\(|os\.unlink\(|os\.remove\(|_os\.unlink\(|TemporaryDirectory\('
py_offenders() { # py_offenders <dir> -> prints "file:line:text" per offending creation
  local fs=("$1"/*.py) f bad
  [ -e "${fs[0]}" ] || return 0
  bad=$(awk -F: 'FNR == NR {m[$1] = $2; next} ($1 in m) && m[$1] > 0 && $2 < m[$1] {print $1}' <(grep -HcE "$MK" "${fs[@]}" 2>/dev/null) <(grep -HcE "$FR" "${fs[@]}" 2>/dev/null))
  for f in $bad; do grep -nE "$MK" "$f" | grep -vE 'atexit|rmtree|TemporaryDirectory|unlink' | sed "s#^#$f:#"; done
}
sh_untrapped() { # sh_untrapped <dir> -> the count of .sh files that call mktemp and carry no trap
  local fs=("$1"/*.sh) m
  [ -e "${fs[0]}" ] || { echo 0; return; }
  m=$(grep -l 'mktemp' "${fs[@]}" 2>/dev/null)
  [ -n "$m" ] || { echo 0; return; }
  grep -L 'trap ' $m 2>/dev/null | grep -c .
}
echo "--- SELF-PROOF on fixtures ---"
mkdir -p "$W/a" "$W/b"
printf 'import tempfile\nd = tempfile.mkdtemp(prefix="x.")\nprint(d)\n' > "$W/a/leak.py"
printf 'import tempfile\nd = tempfile.mkdtemp(prefix="x."); __import__("atexit").register(__import__("shutil").rmtree, d, True)\nprint(d)\n' > "$W/b/kept.py"
n=$(py_offenders "$W/a" | wc -l); ck "$([ "$n" = 1 ] && echo ok || echo no)" "a planted bare mkdtemp is ONE offender (got $n)"
n=$(py_offenders "$W/b" | wc -l); ck "$([ "$n" = 0 ] && echo ok || echo no)" "a planted mkdtemp that registers its removal is NO offender (got $n)"
printf 'W=$(mktemp -d)\n' > "$W/a/leak.sh"; printf 'W=$(mktemp -d); trap "rm -rf $W" EXIT\n' > "$W/b/kept.sh"
ck "$([ "$(sh_untrapped "$W/a")" = 1 ] && [ "$(sh_untrapped "$W/b")" = 0 ] && echo ok || echo no)" "a planted untrapped mktemp script counts 1, a trapped one 0"
echo "--- ARM 1: Python creations in ../harness/scripts/ that register no removal ---"
off="$(py_offenders "$HERE")"; n=$(printf '%s' "$off" | grep -c .)
ck "$([ "$n" = 0 ] && echo ok || echo no)" "Python mkdtemp/mkstemp sites with no removal: $n (want 0)"; [ "$n" = 0 ] || printf '%s\n' "$off" | head -20
echo "--- ARM 2: shell scripts calling mktemp with no trap (ratchet) ---"
n=$(sh_untrapped "$HERE"); ck "$([ "$n" -le "$CEIL" ] && echo ok || echo no)" "untrapped mktemp shell scripts: $n (ceiling $CEIL)"
[ "$n" -lt "$CEIL" ] && echo "  ⚠ the count fell to $n: lower CEIL in this gate to ratchet it"
[ "$fail" = 0 ] && { echo "✅ GATE OK: every Python scratch registers its release; untrapped shell mktemp is at or under its ceiling"; exit 0; }
echo "⛔ GATE RED: $fail arm(s) failed"; exit 1
