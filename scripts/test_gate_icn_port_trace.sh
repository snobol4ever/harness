#!/usr/bin/env bash
export SCRIP_SNO_STMTKW=1   # this grader asks for the instrumentation switch (--stlimit): Icon &trace rides the call/return hooks that are off by default since SCRIP 2026-09-24 (Lon: monitor hooks behind the switch)
# stale-binary preflight (row test-gate-scripts-that-grade-scrip-refuse-on-a-stale-binary-census-widened, hq_T 2026-09-05)
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
# test_gate_icn_port_trace.sh -- THE ICON PORT-TRACE INSTRUMENT (GOAL-TEST-SUITE-CONSISTENCY.md item 6;
# row icon-port-trace-gate-against-ampersand-trace, ceo mint 2026-09-03T21:09:11Z). Shape copied from
# test_gate_pl_port_trace.sh per the task brief; two things differ on purpose, both explained below.
#
# THE INSTRUMENT SCRIP already has: SCRIP_PL_TRACE=1 (x86_port_hook -> rt_pl_port_trace) is wired into
# EVERY box's every port, for every language -- "language identity stops at lower" means the hook cannot
# tell Icon from Prolog. Despite the "PL" in its name it already fires for Icon with zero code changes;
# verified live 2026-09-03 (SCRIP `c5334ce9d`): `SCRIP_PL_TRACE=1 scrip --run rung03_suspend_gen.icn`
# prints "(N) D Call/Exit/Redo/Fail: n<K>_proc_gen <name> [-> target]" lines for the box that calls a
# user procedure capable of suspending. A procedure with NO suspend in it (rung03_suspend_fail.icn)
# never touches proc_gen at all -- Icon compiles resumable and non-resumable calls through DIFFERENT
# box families, so this gate is scoped to the ones that suspend (see POPULATION below).
#
# DIFFERENCE 1 -- WHERE THE REF COMES FROM. Prolog's ref is cut from SCRIP's OWN past-good output (no
# real oracle has a comparable port trace to diff against). Icon's oracle (icont/iconx) DOES have one:
# `&trace := -1` prints "name(args)" / "name suspended V" / "name resumed" / "name returned V" /
# "name failed" for every user-procedure activation. So corpus/tests/icon/ALL.trace is cut from iconx's
# REAL trace, normalised onto the same four ports Prolog uses (Call=alpha, Redo=beta, Exit=gamma,
# Fail=omega -- RULES.md Byrd-box vocabulary), and BOTH modes are graded against that ONE oracle-anchored
# block (there is no per-mode split in ALL.trace, unlike Prolog's ALL.trace: the reference is "what Icon
# semantics require", not "what SCRIP printed last time", so it does not vary by mode by construction).
#
# DIFFERENCE 2 -- GRANULARITY. SCRIP's raw trace logs every sub-expression box (kw_icon, var, binop,
# assign, ...); iconx's trace logs only user-procedure call/suspend/resume/return/fail. The two line up
# 1:1 ONLY after reducing SCRIP's trace to lines whose SUBJECT (not target) is a proc_gen box, dropping
# node numbers and every other box family -- verified empirically equal, letter-for-letter and name-for-
# name, across all four rung03 suspend witnesses, both modes.
#
# ONE NORMALISATION EARNS its own paragraph: a procedure that exits via `return` (not `suspend`) leaves
# no continuation, but SCRIP's caller-side box still issues one courtesy Redo and gets Fail back for it;
# iconx's tracer does not log a resumed/failed pair once a generator has no continuation left. Confirmed
# on rung03_suspend_return.icn: SCRIP's proc_gen sequence is alpha gamma beta gamma beta omega, iconx's
# is alpha gamma beta gamma (four events, no trailing pair). Both sides are dropped of a literal trailing
# "beta then omega" pair (drop_trailing_pair below) before comparison -- applied identically to both
# sides, so a witness that legitimately ends in a matched beta/omega handshake (every other witness here)
# loses the SAME two lines from both sides and still matches; it only ever hides this one named artifact,
# never a wrong count or a wrong order anywhere else in the sequence.
#
# POPULATION: every family in corpus/tests/icon/ALL.csv named `hello` (rung 0) or `rung0*N_*` (rung N),
# further restricted to origins whose extracted source contains the token `suspend` -- a family with no
# `suspend` (e.g. rung03_suspend_fail, which only returns/falls through) never touches proc_gen and is
# reported SKIP, never silently dropped and never counted as a pass. If a rung range yields origins but
# NONE contain `suspend`, that is UNPROVEN(2), not a vacuous pass (lib_gate.sh's own reason: zero-examined
# must never look like all-clean). Plain (non-suspend) calls are a real gap -- they go through a sibling
# box family (bb_call*, not proc_gen) -- and are explicitly left for a follow-up row, not silently assumed
# covered.
#
# SELECTORS (mutually exclusive, same contract as test_gate_pl_port_trace.sh):
#   --to N     grade/cut rungs 0..N CUMULATIVELY.
#   --only N   grade/cut rung N ALONE.
#   (neither)  every rung-tagged family currently registered.
# --cut (re)writes corpus/tests/icon/ALL.trace from iconx's live output -- the ONE way the ref changes;
#   never hand-edit it. Under a selector, --cut is a MERGE: graded origins' blocks are re-cut, every
#   other block is kept verbatim (same law as Prolog's gate, same reason: a rung-3 re-cut must not erase
#   rung-0's blocks just because rung 0 was not part of this run's selection).
# EXIT: 0 every generator witness matches in both modes; 1 a mismatch, killswitch or perturbation
#   failure; 2 REFUSED (cannot measure -- missing binary, empty population, instrument silent).
S4E="${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)"; cd "$ROOT"
. "$HERE/lib_gate.sh"
TO=""; ONLY=""; ARGS=(); while [ $# -gt 0 ]; do case "$1" in --to) TO="${2:-}"; shift 2;; --to=*) TO="${1#--to=}"; shift;; --only) ONLY="${2:-}"; shift 2;; --only=*) ONLY="${1#--only=}"; shift;; *) ARGS+=("$1"); shift;; esac; done; set -- "${ARGS[@]}"
case "$TO" in ""|*[!0-9]*) [ -z "$TO" ] || { echo "GATE UNPROVEN(2) [test_gate_icn_port_trace]: --to wants a rung number, got '$TO'"; exit 2; };; esac
case "$ONLY" in ""|*[!0-9]*) [ -z "$ONLY" ] || { echo "GATE UNPROVEN(2) [test_gate_icn_port_trace]: --only wants a rung number, got '$ONLY'"; exit 2; };; esac
[ -z "$TO" ] || [ -z "$ONLY" ] || { echo "GATE UNPROVEN(2) [test_gate_icn_port_trace]: --to $TO and --only $ONLY name two different populations (cumulative 0..N vs rung N alone) -- pass one, never both"; exit 2; }
if [ -n "$ONLY" ]; then SELDESC="at rung $ONLY alone"; SELTAG="--only $ONLY"; elif [ -n "$TO" ]; then SELDESC="at or below rung $TO"; SELTAG="--to $TO"; else SELDESC="over every rung-tagged family"; SELTAG="all rungs"; fi
CUT=0; for a in "$@"; do [ "$a" = --cut ] && CUT=1; done
gate_parse_args "$@"
SCRIP="${SCRIP:-$ROOT/scrip}"; RT="${RT_DIR:-$ROOT/out}"
RUNGS_DIR="$S4E/corpus/tests/icon"; RUNGS_EXT=.icn; export RUNGS_DIR RUNGS_EXT
REF="$RUNGS_DIR/ALL.trace"; PREFIX_CAP="${PREFIX_CAP:-400}"; T="${TIMEOUT:-20}"
gate_require_exec "$SCRIP" "scrip binary"
gate_require "$RT/libscrip_rt.so" "runtime library"
gate_require "$RUNGS_DIR/ALL.icn" "Icon rungs suite"
gate_require "$RUNGS_DIR/ALL.csv" "Icon rungs suite index"
[ "$CUT" = 1 ] || gate_require "$REF" "trace refs (run with --cut to create them)"
. "$HERE/lib_rungs_extract.sh" || { echo "GATE UNPROVEN(2) [$GATE_NAME]: cannot source lib_rungs_extract.sh"; exit 2; }
if [ "$CUT" = 1 ]; then
  . "$HERE/lib_oracle_flags.sh" 2>/dev/null || { echo "GATE UNPROVEN(2) [$GATE_NAME]: cannot load lib_oracle_flags.sh"; exit 2; }
  ICONT="$(icont_bin)" || exit 2
  ICONX="$(iconx_bin)" || exit 2
fi
rung_of_family() { [ "$1" = hello ] && { echo 0; return; }; printf '%s\n' "$1" | sed -nE 's/^rung0*([0-9]+)_.*/\1/p'; }
ALLFAMS=$(awk -F, 'NR>1{print $4}' "$RUNGS_DIR/ALL.csv" | sort -u)
KEEPFAMS=""
for fam in $ALLFAMS; do
  rn=$(rung_of_family "$fam"); [ -n "$rn" ] || continue
  if [ -n "$ONLY" ]; then [ "$rn" -eq "$ONLY" ] 2>/dev/null && KEEPFAMS="$KEEPFAMS $fam"
  elif [ -n "$TO" ]; then [ "$rn" -le "$TO" ] 2>/dev/null && KEEPFAMS="$KEEPFAMS $fam"
  else KEEPFAMS="$KEEPFAMS $fam"; fi
done
[ -n "${KEEPFAMS// /}" ] || { echo "GATE UNPROVEN(2) [$GATE_NAME]: no rung-tagged families $SELDESC in $RUNGS_DIR/ALL.csv"; gate_stamp; exit 2; }
origins=""
for fam in $KEEPFAMS; do o=$(rungs_origins_of_family "$fam") || { echo "GATE UNPROVEN(2) [$GATE_NAME]: family $fam has no origins in $RUNGS_DIR/ALL.csv"; gate_stamp; exit 2; }; origins="$origins $o"; done
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
drop_trailing_pair() { awk '{ln[NR]=$0} END{n=NR; if (n>=2 && ln[n] ~ /^omega /  && ln[n-1] ~ /^beta /) n-=2; for (i=1;i<=n;i++) print ln[i]}'; }
scrip_trace_norm() {
  grep -E ': n[0-9]+_proc_gen ' "$1" \
    | sed -E 's/^.*(Call|Redo|Exit|Fail): n[0-9]+_proc_gen ([^ ]+).*$/\1 \2/' \
    | sed -E 's/^Call /alpha /; s/^Redo /beta /; s/^Exit /gamma /; s/^Fail /omega /' \
    | drop_trailing_pair
}
oracle_strip() { awk -F'\\|' '{n=NF; s=$n; gsub(/^[ \t]+/,"",s); if (n==1) sub(/^[^:]+:[ \t]*[0-9]+[ \t]+/,"",s); print s}'; }
oracle_map() {
  sed -E '
    s/^main (failed|returned.*|suspended.*)$//
    s/^([A-Za-z_][A-Za-z0-9_]*) failed$/omega \1/
    s/^([A-Za-z_][A-Za-z0-9_]*) resumed$/beta \1/
    s/^([A-Za-z_][A-Za-z0-9_]*) returned .*$/gamma \1/
    s/^([A-Za-z_][A-Za-z0-9_]*) suspended .*$/gamma \1/
    s/^([A-Za-z_][A-Za-z0-9_]*)\(.*\)$/alpha \1/
  ' | sed '/^$/d'
}
oracle_trace_for() {
  local src="$1" stdin_f="${2:-/dev/null}" wd base rc=0
  wd="$(mktemp -d)"; base="$(basename "$src" .icn)"
  awk '{print} /^[[:space:]]*procedure[[:space:]]+main[[:space:]]*\(/ && !done {print "&trace := -1"; done=1}' "$src" > "$wd/$base.icn"
  ( cd "$wd" && timeout -k 5 "$T" "$ICONT" -s "$base.icn" ) >/dev/null 2>&1
  if [ -x "$wd/$base" ]; then
    ( cd "$wd" && timeout -k 5 "$T" "$ICONX" "$base" ) <"$stdin_f" >/dev/null 2>"$wd/raw.trace"
  else
    : > "$wd/raw.trace"; rc=1
  fi
  oracle_strip < "$wd/raw.trace" | oracle_map | drop_trailing_pair
  rm -rf "$wd"; return $rc
}
m4build() { [ -s "$1" ] && as --64 -o "$1.o" "$1" 2>/dev/null && gcc -no-pie -o "$2" "$1.o" "$RT/libscrip_rt.so" -lm -lstdc++ -Wl,-rpath,"$RT" 2>/dev/null; }
refblock() { awk -v o="$1" '$0 ~ "^%---- " o " " {on=1; next} /^%---- /{on=0} on' "$REF"; }
refmeta()  { grep -E "^%---- $1 " "$REF" | head -1 | sed -E 's/.* total=([0-9]+) prefix=([0-9]+).*/\1 \2/'; }
n=0; bad=0; noref=0; skip=0; ans_ok=0; ans_red=0; declare -a lines
[ "$CUT" = 1 ] && : > "$W/ALL.trace"
for o in $origins; do
  src="$W/$o.icn"; ref="$W/$o.ref"
  rungs_extract_origin "$o" "$src" "$ref" >/dev/null 2>&1 || { echo "GATE UNPROVEN(2) [$GATE_NAME]: cannot extract $o from the rungs suite"; gate_stamp; exit 2; }
  # ⛔⭐ FEED THE ENTRY ITS OWN STDIN. rungs_extract_name already requests --out-in unconditionally,
  # so a stdin-bearing entry arrives here with "$W/$o.in" beside its source -- and every run below read
  # </dev/null anyway, so rung36_jcon_recogn hit EOF on read(), exited before reaching any `suspend`, and
  # this gate refused with "produced ZERO proc_gen lines". ⭐ THE REFUSAL WAS ALWAYS CORRECT and was
  # misattributed three times as a gate gap (hq_U 2026-09-08): it had no run, not no ports. The file it
  # needed was sitting in $W the whole time. A missing/empty sidecar keeps /dev/null, so every non-stdin
  # entry is byte-identical to before. COMPILE steps below keep </dev/null on purpose -- a compile reads
  # no stdin, and CLAUDE.md's rule is that the redirect is wrong only on a run that is actually fed.
  IN="$W/$o.in"; [ -s "$IN" ] || IN=/dev/null
  if ! grep -qw suspend "$src"; then
    lines+=("$(printf '%-40s SKIP (no suspend -- not a proc_gen/generator witness)' "$o")"); skip=$((skip+1)); continue
  fi
  n=$((n+1))
  (cd "$W" && timeout -k 5 "$T" "$SCRIP" --compile -o "$o.s0" "$src" </dev/null >/dev/null 2>&1); (cd "$W" && SCRIP_PL_TRACE=0 timeout -k 5 "$T" "$SCRIP" --compile -o "$o.s0b" "$src" </dev/null >/dev/null 2>&1)
  (cd "$W" && SCRIP_PL_TRACE=1 timeout -k 5 "$T" "$SCRIP" --compile -o "$o.s1" "$src" </dev/null >/dev/null 2>&1)
  ks=OK; { cmp -s "$W/$o.s0" "$W/$o.s0b" && [ -s "$W/$o.s0" ] && ! cmp -s "$W/$o.s0" "$W/$o.s1"; } || { ks=FAIL; bad=$((bad+1)); }
  timeout -k 5 "$T" "$SCRIP" --run "$src" <"$IN" >"$W/$o.m3.out0" 2>/dev/null; r30=$?
  SCRIP_PL_TRACE=1 timeout -k 5 "$T" "$SCRIP" --run "$src" <"$IN" >"$W/$o.m3.out1" 2>"$W/$o.m3.raw"; r31=$?
  pert3=OK; { [ "$r30" = "$r31" ] && cmp -s "$W/$o.m3.out0" "$W/$o.m3.out1"; } || { pert3=FAIL; bad=$((bad+1)); }
  pert4=OK
  if m4build "$W/$o.s0" "$W/$o.bin0" && m4build "$W/$o.s1" "$W/$o.bin1"; then
    timeout -k 5 "$T" "$W/$o.bin0" <"$IN" >"$W/$o.m4.out0" 2>/dev/null; r40=$?
    SCRIP_PL_TRACE=1 timeout -k 5 "$T" "$W/$o.bin1" <"$IN" >"$W/$o.m4.out1" 2>"$W/$o.m4.raw"; r41=$?
    { [ "$r40" = "$r41" ] && cmp -s "$W/$o.m4.out0" "$W/$o.m4.out1"; } || { pert4=FAIL; bad=$((bad+1)); }
  else pert4=NOBUILD; bad=$((bad+1)); : > "$W/$o.m4.raw"; fi
  cmp -s "$W/$o.m3.out0" "$ref" && { ans=ok; ans_ok=$((ans_ok+1)); } || { ans=RED; ans_red=$((ans_red+1)); }
  scrip_trace_norm "$W/$o.m3.raw" > "$W/$o.m3.norm"
  scrip_trace_norm "$W/$o.m4.raw" > "$W/$o.m4.norm"
  for m in m3 m4; do
    total=$(wc -l < "$W/$o.$m.norm")
    [ "$total" -gt 0 ] || { echo "GATE UNPROVEN(2) [$GATE_NAME]: $o $m: source contains 'suspend' but SCRIP_PL_TRACE=1 produced ZERO proc_gen lines -- the instrument is not firing, this is not 'no ports'"; gate_stamp; exit 2; }
  done
  if [ "$CUT" = 1 ]; then
    oracle_trace_for "$src" "$IN" > "$W/$o.oracle.norm"
    otot=$(wc -l < "$W/$o.oracle.norm")
    [ "$otot" -gt 0 ] || { echo "GATE UNPROVEN(2) [$GATE_NAME]: $o: iconx produced ZERO normalised trace lines -- cannot cut a ref from nothing"; gate_stamp; exit 2; }
    p=$otot; [ "$p" -gt "$PREFIX_CAP" ] && p=$PREFIX_CAP
    { echo "%---- $o total=$otot prefix=$p"; head -n "$p" "$W/$o.oracle.norm"; } >> "$W/ALL.trace"
    tr3=CUT; tr4=CUT
  else
    meta=$(refmeta "$o"); rt=${meta%% *}; rp=${meta##* }
    for m in m3 m4; do
      total=$(wc -l < "$W/$o.$m.norm")
      # ⛔⭐⭐ NOREF IS A CANNOT-MEASURE, NOT A FAILED CHECK (hq_T 2026-09-11, on the ceo's finding that these
      # gates are wired into no recipe and that icn reads "22 failed checks of 24"). A witness with NO REF BLOCK
      # has never been pinned; the gate learned nothing about it. Counting it into `bad` publishes a backlog that
      # looks like defects and is not one -- MEASURED across all six self-pin gates plus icn: 218 of the failed
      # checks are NOREF, and ZERO witnesses have a wrong answer or a failed killswitch. icn's 22 of 24 is exactly
      # 11 unpinned witnesses x 2 modes; its one pinned witness passes both modes.
      # ⭐ THE TELL THAT THIS IS THE INSTRUMENT AND NOT THE COMPILER: every row reads killswitch=OK perturb=OK
      # answer=ok, and only the trace column speaks. A real port-order regression cannot leave the answer correct
      # in both modes across 130 witnesses.
      # ⭐⭐ AND THE BODY ALREADY KNEW THE DISTINCTION TWO LINES ABOVE: a witness that compiles and emits ZERO
      # trace lines REFUSES rc=2 with "the instrument is not firing; this is not 'no ports'". The same function
      # draws the cannot-measure/fail line correctly for one absence and wrongly for the other. ⛔ A FAIL AND A
      # CANNOT-MEASURE ARE DIFFERENT FACTS -- rc=1 sends a reader hunting a defect in the compiler that is really
      # an unpinned witness. The lane cured this exact shape once already in test_icon_ir_rung_03.sh; it survived
      # here because it was filed as a fact about that script instead of a fact about verdicts.
      if [ -z "$meta" ]; then v=NOREF; noref=$((noref+1))
      elif [ "$rt" != "$total" ]; then v="FAIL(total $total != ref $rt)"; bad=$((bad+1))
      elif ! refblock "$o" | cmp -s - <(head -n "$rp" "$W/$o.$m.norm"); then v="FAIL(diff within first $rp)"; bad=$((bad+1)); refblock "$o" | diff - <(head -n "$rp" "$W/$o.$m.norm") | head -6 | sed 's/^/        /' > "$W/$o.$m.diff"
      else v="ok($total)"; fi
      [ "$m" = m3 ] && tr3="$v" || tr4="$v"
    done
  fi
  lines+=("$(printf '%-40s killswitch=%-4s perturb m3=%-4s m4=%-7s trace m3=%-22s m4=%-22s answer=%s' "$o" "$ks" "$pert3" "$pert4" "$tr3" "$tr4" "$ans")")
  for m in m3 m4; do [ -f "$W/$o.$m.diff" ] && lines+=("$(cat "$W/$o.$m.diff")"); done
done
printf '%s\n' "${lines[@]}"
[ "$n" -gt 0 ] || { echo "GATE UNPROVEN(2) [$GATE_NAME]: $skip origin(s) $SELDESC, none contain 'suspend' -- no proc_gen/generator activity to measure (plain non-suspend calls are a known follow-up gap, not covered here)"; gate_stamp; exit 2; }
if [ "$CUT" = 1 ]; then
  if [ -n "$TO$ONLY" ] && [ -f "$REF" ]; then
    printf '%s\n' $origins > "$W/graded.txt"
    awk -v gl="$W/graded.txt" 'BEGIN{while ((getline l < gl) > 0) g[l]=1} /^%---- /{keep = !($2 in g)} keep' "$REF" > "$W/kept.trace"
    cat "$W/kept.trace" "$W/ALL.trace" > "$REF"; echo "refs CUT (merged, $SELTAG re-cut, other blocks kept) -> $REF ($(grep -c '^%---- ' "$REF") blocks, prefix cap $PREFIX_CAP)"
  else cp "$W/ALL.trace" "$REF"; echo "refs CUT -> $REF ($(grep -c '^%---- ' "$REF") blocks, prefix cap $PREFIX_CAP)"; fi
fi
echo "witnesses=$n skipped=$skip ($SELTAG) modes=2 (m3 --run, m4 --compile+as+gcc) . answer ok=$ans_ok red=$ans_red (informational: the rungs suite grades answers) . oracle=iconx &trace, normalised Call/Redo/Exit/Fail -> alpha/beta/gamma/omega, node numbers stripped, a trailing beta+omega handshake dropped from both sides (see header)"
# ⛔⭐ A RUNNER THAT GRADED ZERO TRACE CHECKS REFUSES rc=2 RATHER THAN PRINTING THE SUCCESS SHAPE. With
# NOREF correctly out of `bad`, a gate whose witnesses are ALL unpinned would otherwise report
# "0 failed checks" -- the cleanest possible green over a measurement that never happened, and strictly
# worse than the false red it replaces. ⭐ This is the ladder-runner rule of GOAL-TEST-SUITE-CONSISTENCY
# arriving in the trace family: it prints its denominator, and it refuses when the denominator is zero.
_pinned=$(( n*2 - noref ))
if [ "$noref" -gt 0 ]; then
    echo "⛔ $noref of $((n*2)) trace check(s) have NO REF BLOCK and were NOT graded -- unpinned witnesses are a CANNOT-MEASURE, never a failed check. Re-cut with the gate's own CUT mode; until then this gate speaks for $_pinned check(s) only."
fi
if [ "$_pinned" -le 0 ]; then
    echo "GATE UNPROVEN(2) [$GATE_NAME]: every one of the $((n*2)) trace check(s) is unpinned (NOREF), so this gate graded NOTHING. A runner that cannot measure must not print a verdict."
    gate_stamp; exit 2
fi
echo "trace checks graded=$_pinned of $((n*2)) (unpinned/NOREF=$noref, out of the denominator and named above)"
GATE_EXAMINED=$((n*2)); gate_verdict "$bad" "failed checks across killswitch/perturbation/trace"
