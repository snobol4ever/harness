#!/usr/bin/env bash
bash "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
# test_gate_batch_scripts_run_in_the_batch_slice.sh -- THE BATCH CLASS HOLDS (the cto, ARCH-SHARED-DEVELOPMENT 4.5 (b) and 5, CEO-2041 step 4;
# built by the cfo 2026-10-31). The DONE-WHEN of row shared-dev-step-4-the-batch-class-util-batch-sh-and-the-batch-slice-every-census-identity-
# run-sweep-and-callgrind-runs-in-it-ceo-2041.
# THE ARMS:
#   wrapper   util_batch.sh runs a trivial job in its own scope under s4e-batch.slice (the BATCH_CGROUP line it writes inside the scope).
#   one-seat  a second top-level batch job of the same seat, while the first runs, REFUSES rc 2 and names the holder.
#   slice     inside a quiet slice (S4E_IN_SLICE) util_batch.sh REFUSES rc 2.
#   nested    a batch job that starts a batch job runs it in its own scope: one BATCH_CGROUP line, no second scope.
#   script    every script below that is batch by nature, started with a one-program argument, reports a cgroup under s4e-batch.slice
#             (it enters the class at its own top; the script's own verdict on the one program is not graded here).
#   entry     every batch script without a bounded one-program form (the whole-corpus A/B capture, the gc witness sweep, the oracle flag
#             sweep, the bootstrap identity gate, the placement watch's run, the roast ladder and the bookkeeping census) enters the class by
#             the same line at its top (chunk 2, the cto 2026-10-31; a kick that detaches a run, a capture over 3,000 programs, cannot be run here).
#   runner    a guarded runner's board scope (lib_one_runner.sh) lands in s4e-batch.slice, and in s4e-grader.slice under S4E_CLASS=grader.
#   no-nice   no nice is left in harness/scripts (a nice value is relative inside one cgroup and invisible across them, 4.1):
#             nice -n, os.nice(, a "nice" argv list, the fanout_nice prefix.
# The gate uses its own lock directory (S4E_BATCH_LOCK_DIR) so a seat's real batch job never collides with it, and clears
# S4E_BATCH_HELD so it measures entry even when a batch job (the DONE-WHEN sweep) runs it.
# rc 0 every arm green; rc 1 an arm red (named); rc 2 cannot measure (inside a quiet slice, no systemd-run scope, no ./scrip).
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../.." && pwd)"; SC="$ROOT/SCRIP/scrip"
NAME=test_gate_batch_scripts_run_in_the_batch_slice
[ -z "${S4E_IN_SLICE:-}" ] || { echo "REFUSE(2): inside a quiet slice -- the batch class refuses here by design, nothing to measure"; exit 2; }
[ -x "$SC" ] || { echo "REFUSE(2): no $SC -- build first (make)"; exit 2; }
timeout -k 5 30 systemd-run --user --scope -q -- true >/dev/null 2>&1 || { echo "REFUSE(2): systemd-run --user --scope does not work here -- no scope, no class"; exit 2; }
T="$(mktemp -d /tmp/s4e-batch-gate.XXXXXX)" || { echo "REFUSE(2): mktemp"; exit 2; }
trap 'rm -rf "$T"' EXIT
export S4E_BATCH_LOCK_DIR="$T/locks"; unset S4E_BATCH_HELD
printf "        OUTPUT = 'hi'\nEND\n" > "$T/hello.sno"
printf '%s\n' "$T/hello.sno" > "$T/list"; : > "$T/empty"
( cd "$ROOT/SCRIP" && timeout -k 5 120 "$SC" --compile --out="$T/hello.s" "$T/hello.sno" < /dev/null > /dev/null 2>&1 && gcc "$T/hello.s" -L"$ROOT/SCRIP/out" -lscrip_rt -lm -Wl,-rpath,"$ROOT/SCRIP/out" -o "$T/hello_bin" > /dev/null 2>&1 ) || echo "  (no hello_bin from $SC: the callgrind row reads red)"
B="$HERE/util_batch.sh"; red=""; n=0
inbatch() { grep -c '^BATCH_CGROUP .*/s4e-batch\.slice/' "$1" 2>/dev/null; }
n=$((n + 1)); rm -f "$T/rep"
if [ -f "$B" ] && S4E_BATCH_REPORT="$T/rep" timeout -k 5 300 bash "$B" true > "$T/w.out" 2>&1 && [ "$(inbatch "$T/rep")" = 1 ]; then :; else red="$red wrapper"; fi
n=$((n + 1))
if [ -f "$B" ]; then
  ( timeout -k 5 300 bash "$B" sleep 6 > /dev/null 2>&1 ) & hold=$!
  for _ in $(seq 1 200); do grep -q '^pid=' "$S4E_BATCH_LOCK_DIR"/*.lock 2>/dev/null && break; sleep 0.25; done
  timeout -k 5 60 bash "$B" true > "$T/s.out" 2>&1; second=$?
  wait "$hold"
  { [ "$second" = 2 ] && grep -q 'already runs a batch job' "$T/s.out"; } || red="$red one-seat(rc$second)"
else red="$red one-seat"; fi
n=$((n + 1))
if [ -f "$B" ]; then S4E_IN_SLICE=1 timeout -k 5 60 bash "$B" true > /dev/null 2>&1; r=$?; [ "$r" = 2 ] || red="$red slice(rc$r)"; else red="$red slice"; fi
n=$((n + 1)); rm -f "$T/rep"
if [ -f "$B" ] && S4E_BATCH_REPORT="$T/rep" timeout -k 5 300 bash "$B" bash "$B" true > /dev/null 2>&1 && [ "$(inbatch "$T/rep")" = 1 ] && [ "$(wc -l < "$T/rep")" = 1 ]; then :; else red="$red nested"; fi
while IFS=$'\t' read -r script args; do
  case "$script" in ''|'#'*) continue;; esac
  n=$((n + 1)); rm -f "$T/rep"
  args="${args//@PROG/$T/hello.sno}"; args="${args//@SCRIP/$SC}"; args="${args//@LIST/$T/list}"; args="${args//@BIN/$T/hello_bin}"; args="${args//@EMPTY/$T/empty}"; args="${args//@T/$T}"
  case "$script" in *.py) interp=python3;; *) interp=bash;; esac
  # shellcheck disable=SC2086
  ( cd "$ROOT/SCRIP" && S4E_BATCH_REPORT="$T/rep" timeout -k 5 600 $interp "$HERE/$script" $args < /dev/null > "$T/x.out" 2>&1 )
  [ "$(inbatch "$T/rep")" -ge 1 ] 2>/dev/null || red="$red script:$script"
done <<'TABLE'
# script	one-program arguments (@PROG a one-line SNOBOL4 program, @SCRIP this root's ./scrip, @LIST a list of that one program, @BIN its mode-4 binary, @EMPTY an empty input, @T the scratch dir)
util_population_asm_identity.sh	--control @SCRIP --files @PROG
util_zsm_declared_census.sh	--files @PROG --timeout 60
util_zsm_frame_census.sh	--files @PROG --timeout 60
util_out_sweep.sh	@T/out.md5 @LIST
util_s_md5_sweep.sh	@T/s.md5 @LIST
sweep_rsp_only.sh	@T/rsp.tsv @T
util_blob_spine_slot_sweep.sh	@PROG
profile_callgrind.sh	@BIN @EMPTY @T/cg
util_dyn_caps_witness.sh	census
util_emitter_memory_model_census.py	--list
TABLE
for s in util_template_ab.sh util_gc_witness_sweep.sh util_oracle_flag_sweep.sh test_gate_bootstrap_parse_stage_ir_identity.sh util_placement_watch.sh util_raku_roast_test_ladder.py util_sno_bookkeeping_derivation_census.py; do n=$((n + 1)); grep -qE 'exec bash [^#]*util_batch\.sh|execvp\("bash", \["bash", [^#]*util_batch\.sh' "$HERE/$s" 2>/dev/null || red="$red entry:$s"; done
n=$((n + 1)); printf '%s\n' '#!/usr/bin/env bash' ". \"$HERE/lib_one_runner.sh\"" 'one_runner_mem_scope' "sed -n 's/^0:://p' /proc/self/cgroup" > "$T/fx.sh"
cg="$(cd "$T" && env -u S4E_MEM_SCOPE timeout -k 5 120 bash "$T/fx.sh" 2>/dev/null | tail -1)"; cgg="$(cd "$T" && S4E_CLASS=grader env -u S4E_MEM_SCOPE timeout -k 5 120 bash "$T/fx.sh" 2>/dev/null | tail -1)"
case "$cg" in */s4e-batch.slice/*) :;; *) red="$red runner-batch(${cg:-none})";; esac; case "$cgg" in */s4e-grader.slice/*) :;; *) red="$red runner-grader(${cgg:-none})";; esac
n=$((n + 1))
nices="$(grep -rnE 'nice -n|os\.nice\(|"nice", *"-n"|fanout_nice' "$HERE" --include='*.sh' --include='*.py' 2>/dev/null | grep -v "/$NAME.sh:")"
nn=0; [ -z "$nices" ] || nn="$(printf '%s\n' "$nices" | wc -l)"
[ "$nn" = 0 ] || { red="$red no-nice($nn)"; printf '%s\n' "$nices" | sed 's|^.*/harness/scripts/|  NICE |' | cut -c1-200; }
nred=0; [ -z "$red" ] || nred="$(printf '%s\n' $red | wc -l)"
echo "BATCH_CLASS_BOARD arms=$n red=$nred nices=$nn (tree $(git -C "$ROOT/harness" rev-parse --short HEAD 2>/dev/null))"
[ -z "$red" ] && { echo "GATE OK [$NAME]: $n arms -- the batch class holds and no nice is left"; exit 0; }
echo "GATE FAIL [$NAME]:$red"; exit 1
