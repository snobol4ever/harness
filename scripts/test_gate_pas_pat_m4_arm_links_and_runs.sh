#!/usr/bin/env bash
# test_gate_pas_pat_m4_arm_links_and_runs.sh -- the PAT rejection arm's m4 column may never go back to compile-only
#
# WHY THIS GATE EXISTS (hq_pascal 2026-09-16, cfo ruling with the ceo copied, row pascal-pat-suite-427-to-100-percent-by-class).
# test_pascal_pat_suite.sh graded its REJECTION arm's m4 column with `--compile -o /dev/null`, which only COMPILES. A
# rejection test whose ISO condition fires at RUN time therefore could never fail that arm, so the m4 column did not mean
# "refused in m4", it meant "refused AT COMPILE TIME in m4", and both_pass was floored by the instrument rather than by
# the engine. MEASURED ON ONE TREE (SCRIP e83244874): old arm both_pass=284 m4_pass=284 m4_fail=143; new arm
# both_pass=296 m4_pass=296 m4_fail=131. TWELVE entries changed class, ZERO went the other way.
#
# ⛔ THIS GATE IS NOT A BOARD AND MUST NEVER BECOME ONE. It grades its OWN minted fixture in a mktemp dir, never the
# vendored PAT population, so it carries no one-runner guard and any seat may run it (CEO-547: the population decides).
#
# THE TWO ARMS:
#  (1) STRUCTURAL -- the runner's m4 rejection arm must link and run, and must not grade with `--compile -o /dev/null`.
#      A structural check alone would be a grep that a refactor could satisfy while changing the meaning, which is why
#      arm (2) exists and is the one that actually decides.
#  (2) BEHAVIOURAL, AND IT IS THE POINT -- a minted witness whose ISO condition fires ONLY at run time is compiled,
#      linked and run. Compile-only must report SUCCESS on it (proving a compile-only arm is blind to this witness) and
#      compile-link-run must report FAILURE (proving the arm we ship can see it). If those two ever agree, either the
#      witness stopped being runtime-only or the arm stopped running, and both mean this gate can no longer tell the
#      difference -- so it REFUSES rc=2 rather than passing, because an instrument that cannot discriminate must not
#      report the success shape.
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -uo pipefail
G="$(basename "${BASH_SOURCE[0]}" .sh)"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
SCRIP="${SCRIP_BIN:-$ROOT/scrip}"; [ -x "$SCRIP" ] || { echo "⛔ GATE REFUSE(2) [$G]: no scrip at $SCRIP"; exit 2; }
RT_DIR="${RT_DIR:-$ROOT/out}"; [ -f "$RT_DIR/libscrip_rt.so" ] || { echo "⛔ GATE REFUSE(2) [$G]: no runtime at $RT_DIR/libscrip_rt.so"; exit 2; }
RUNNER="$HERE/test_pascal_pat_suite.sh"; [ -f "$RUNNER" ] || { echo "⛔ GATE REFUSE(2) [$G]: no $RUNNER to inspect"; exit 2; }
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
RC=0
# ⛔ COMMENT LINES ARE STRIPPED BEFORE THE STRUCTURAL GREP, AND THAT IS NOT TIDYING. The runner's own comment EXPLAINS
# the retired form by quoting it, so a grep over raw text convicts the documentation for describing the cure -- measured
# the first time this gate was run. A gate that cannot tell a quotation from a use will be satisfied by deleting the
# explanation, which is the worst possible thing to incentivise.
ARM=$(sed -n '/^    for m in m3 m4; do$/,/^        # .*THE VERDICT IS STABLE/p' "$RUNNER" | sed -E 's/^[[:space:]]*#.*$//')
[ -n "$(printf '%s' "$ARM" | tr -d '[:space:]')" ] || { echo "⛔ GATE REFUSE(2) [$G]: could not locate the rejection arm in $RUNNER -- this gate cannot grade what it cannot find"; exit 2; }
if printf '%s' "$ARM" | grep -q -- '--compile -o /dev/null'; then
  echo "  ⛔ the m4 rejection arm grades with --compile -o /dev/null again -- it can no longer see a runtime refusal"; RC=1
else echo "  structural: the m4 rejection arm does not grade with --compile -o /dev/null"; fi
if printf '%s' "$ARM" | grep -q 'lscrip_rt'; then echo "  structural: the m4 rejection arm links against the runtime"
else echo "  ⛔ the m4 rejection arm no longer links -- a compiled program that is never run cannot be observed to fail"; RC=1; fi
cat > "$T/w.pas" <<'PAS'
program runtimeonly(output);
var f: file of integer;
begin
   write(f, 1)
end.
PAS
[ -n "${FAIL_ONCE:-}" ] && cat > "$T/w.pas" <<'PAS'
program compiletimebad(output);
begin
   undeclaredthing := 1
end.
PAS
( cd "$T" && timeout -k 5 20s "$SCRIP" --compile -o "$T/w.s" w.pas </dev/null >"$T/co" 2>&1 ); crc=$?
if [ "$crc" != 0 ]; then
  echo "  ⛔ GATE REFUSE(2) [$G]: the minted witness is refused AT COMPILE TIME (rc=$crc), so it cannot tell a compile-only arm from a running one"; exit 2; fi
echo "  compile-only arm on the minted runtime-only witness: rc=$crc (blind, as expected -- this is what the old arm measured)"
( cd "$T" && cc -m64 -no-pie w.s -o w -L"$RT_DIR" -lscrip_rt -lm -Wl,-rpath,"$RT_DIR" >/dev/null 2>&1 ) || { echo "  ⛔ GATE REFUSE(2) [$G]: the minted witness compiled but would not link"; exit 2; }
( cd "$T" && timeout -k 5 20s ./w </dev/null >"$T/ro" 2>&1 ); rrc=$?
if [ "$rrc" -ne 0 ] && [ -n "$(cat "$T/ro")" ]; then
  echo "  compile-link-run arm on the same witness: rc=$rrc with a diagnostic -- the shipped arm SEES what compile-only cannot"
else
  echo "  ⛔ compile-link-run did not observe the refusal either (rc=$rrc, $(wc -c <"$T/ro") bytes) -- the two arms agree, so this gate can no longer discriminate"; RC=1; fi
if [ "$RC" = 0 ]; then echo "GATE PASS [$G]: the PAT m4 rejection arm compiles, links and runs, and a runtime-only witness proves it discriminates from compile-only"
else echo "GATE FAIL(1) [$G]: the m4 rejection arm cannot observe a runtime refusal"; fi
echo "    tree: SCRIP=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY)  measured $(date -u +%Y-%m-%dT%H:%MZ)"
exit $RC
