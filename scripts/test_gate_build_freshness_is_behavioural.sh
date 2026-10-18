#!/usr/bin/env bash
# test_gate_build_freshness_is_behavioural.sh -- THE BEHAVIOUR PROBE, GATED.
#
# ⛔⭐ THE CLASS (FINDING-2026-09-09-hq_P-a-completed-make-produced-a-binary-that-did-not-match-its-own-templates.md):
# a full `make` reported "Built: scrip" after compiling 198 objects and handed back a compiler that emitted code its own
# template sources do not describe. Three builds on ONE commit produced TWO different compilers. Every freshness check
# on the box PASSED throughout, and two SCORE rows were published from the bad build before an unrelated source edit
# exposed it.
#
# ⛔⭐ WHY THE MTIME GUARD CANNOT SEE IT, WHICH IS STRUCTURAL: the artifacts it stamps are touched by the ACT OF RUNNING
# make, not by the build being right. `scrip`'s only prerequisite is the PHONY `libscrip_rt`, so it relinks on EVERY
# make; `out/libscrip_rt.so` carries FORCE, so its symlink is re-pointed on EVERY make; and $(RT_SO) relinks whenever
# ANY ONE of 269 objects changed. One stale object among 269 therefore leaves every artifact newer than every source.
# ⭐ REPRODUCED DETERMINISTICALLY (hq_T 2026-09-09) and it is arm 6 of this gate: edit a template, make, revert the
# source, touch the object forward so make skips it, touch a second object so the .so relinks -- `make` completes,
# `git status src/` is EMPTY, the binary answers `type=integer image=0` where the tree says `null / &null`, and
# util_require_fresh's mtime half returns rc=0. The probe returns rc=2.
#
# ⭐ WHAT THE PROBE PROVES, STATED HONESTLY: it is a SELF-PIN in exactly the sense CEO-395 draws for rungs refs -- the
# emitted code HAS NOT MOVED under a tree that HAS NOT MOVED. It says nothing about whether that code is RIGHT; the
# oracle diffs do that. That narrow claim is the one the FINDING needed and could not get.
#
# HERMETIC: arms 1-8 run against a SCRATCH root (tiny src/, a Makefile, ../harness/scripts/ and scrip symlinked in) so the live
# out/build_behaviour.sig is never written and no rebuild is needed. ~1s, offline.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
. "$HERE/lib_gate.sh"
GATE_NAME="build_freshness_is_behavioural"; export GATE_NAME
PASS=0; FAIL=0
ok(){ PASS=$((PASS+1)); printf '  ok   %s\n' "$1"; }
no(){ FAIL=$((FAIL+1)); printf '  FAIL %s\n' "$1"; }
chk(){ if [ "$2" = "$3" ]; then ok "$1 ($2)"; else no "$1: expected $3, got $2"; fi; }

[ -x "$ROOT/scrip" ] || { echo "GATE UNPROVEN(2) [$GATE_NAME]: ⛔ REFUSES rc=2: no $ROOT/scrip -- this gate probes a binary and cannot invent one"; gate_stamp; exit 2; }

X="$(mktemp -d)"; trap 'rm -rf "$X"' EXIT
. "$HERE/lib_fixture_root.sh" || { echo "GATE UNPROVEN(2) [$GATE_NAME]: ⛔ REFUSES rc=2: cannot load lib_fixture_root.sh"; gate_stamp; exit 2; }
fixture_root "$X" || { echo "GATE UNPROVEN(2) [$GATE_NAME]: ⛔ REFUSES rc=2: could not stage the scratch root (harness/scripts copied beside a scratch SCRIP, never linked -- CEO-1820)"; gate_stamp; exit 2; }
W="$X/SCRIP"; rm -rf "$W/out"; mkdir -p "$W/src" "$W/out"
printf 'int a(void){return 1;}\n' > "$W/src/a.c"
printf 'all:\n\t@true\n'          > "$W/Makefile"

echo "== tree signature =="
T1="$(gate_tree_signature "$W")"; T2="$(gate_tree_signature "$W")"
chk "1 tree signature is deterministic" "$T1" "$T2"
printf 'int a(void){return 2;}\n' > "$W/src/a.c"
T3="$(gate_tree_signature "$W")"
if [ "$T3" != "$T1" ]; then ok "2 tree signature moves when src/ CONTENT changes"; else no "2 tree signature blind to a content change"; fi
printf 'int a(void){return 1;}\n' > "$W/src/a.c"; touch -d '2020-01-01' "$W/src/a.c"
T4="$(gate_tree_signature "$W")"
# ⭐ THE ARM THAT SAYS WHY THIS IS NOT ANOTHER MTIME CHECK: restoring the CONTENT restores the signature even though the
# file's mtime is now years off. A signature that moved here would be measuring the clock again, which is the instrument
# that failed.
chk "3 tree signature is CONTENT, not mtime (restored content == original sig)" "$T4" "$T1"
printf 'int b(void){return 1;}\n' > "$W/src/b.c"
T5="$(gate_tree_signature "$W")"
if [ "$T5" != "$T1" ]; then ok "4 an UNTRACKED new source moves the signature (it is compiled like any other)"; else no "4 untracked source invisible"; fi
rm -f "$W/src/b.c"; printf 'int a(void){return 1;}\n' > "$W/src/a.c"

echo "== behaviour signature =="
B1="$(gate_behaviour_signature "$W" "$ROOT/scrip")"; B2="$(gate_behaviour_signature "$W" "$ROOT/scrip")"
if [ -n "$B1" ] && [ "$B1" = "$B2" ]; then ok "5 behaviour signature is deterministic ($B1)"; else no "5 behaviour signature not deterministic: '$B1' vs '$B2'"; fi

echo "== the verdict =="
rm -f "$W/out/build_behaviour.sig"
out="$(gate_require_built_from "$W" "$ROOT/scrip" 2>&1)"; rc=$?
chk "6a first observation of a tree RECORDS and passes" "$rc" "0"
case "$out" in *RECORDED*) ok "6b and says so";; *) no "6b first observation did not announce itself: $out";; esac
out="$(gate_require_built_from "$W" "$ROOT/scrip" 2>&1)"; rc=$?
chk "7 a repeat on the same tree and same binary passes" "$rc" "0"
# ⛔ ARM 8 IS THE WHOLE GATE: contradict the ledger for THIS tree and the probe must refuse. Written by hand rather than
# by rebuilding a doctored binary because the doctored-binary reproduction is a 4-minute two-build ceremony and this arm
# has to run inside `make test`; the reproduction itself was measured once, by hand, and is described in this header.
sed -i "s/^\\($(gate_tree_signature "$W") \\)[0-9a-f]\\{32\\}/\\1deadbeefdeadbeefdeadbeefdeadbeef/" "$W/out/build_behaviour.sig"
out="$(gate_require_built_from "$W" "$ROOT/scrip" 2>&1)"; rc=$?
chk "8a A BINARY THAT MOVED UNDER A STATIC TREE REFUSES rc=2" "$rc" "2"
case "$out" in *"MOVED UNDER A TREE THAT DID NOT"*) ok "8b names the class";; *) no "8b refusal does not name the class";; esac
case "$out" in *"deadbeef"*) ok "8c prints the contradicted signature, so it is actionable";; *) no "8c refusal hides the evidence";; esac
out="$(SCRIP_ALLOW_STALE=1 gate_require_built_from "$W" "$ROOT/scrip" 2>&1)"; rc=$?
chk "9a the DECLARED override passes" "$rc" "0"
case "$out" in *"MOVED-BUILD OVERRIDE"*) ok "9b loudly";; *) no "9b override is silent -- the whole point is that it is not";; esac
# ⛔ A MISSING BINARY IS NEVER A PASS-BY-SKIP: nothing ran, so nothing was probed.
out="$(gate_require_built_from "$W" "$W/no-such-binary" 2>&1)"; rc=$?
chk "10 a missing binary REFUSES rc=2 (never skip-as-success)" "$rc" "2"
# ⛔ A BINARY THAT CANNOT EMIT REFUSES rather than printing a signature over zero witnesses.
out="$(gate_require_built_from "$W" /bin/true 2>&1)"; rc=$?
chk "11 a binary that cannot --compile the witnesses REFUSES rc=2" "$rc" "2"
# ⭐ THE LEDGER RIDES EVERY RUNNER'S PREFLIGHT, so an unreadable one must RECORD, never red the fleet for an unrelated reason.
rm -f "$W/out/build_behaviour.sig"; printf '\x00\x00 garbage not a ledger\n' > "$W/out/build_behaviour.sig"
out="$(gate_require_built_from "$W" "$ROOT/scrip" 2>&1)"; rc=$?
chk "12 an unreadable ledger RECORDS, it never refuses" "$rc" "0"

echo "== a ledger belongs to the checkout it describes =="
# ⛔ ARM 12b WAS THE RACED-ARMS CAUSE (the coo 2026-10-15): a scratch root whose out/ was a SYMLINK to another checkout's out/ appended its own tree line to that
# checkout's ledger. No link exists any more (CEO-1820): a scratch root's out/ is its own COPY, so its line lands in its own ledger and the other checkout's is untouched.
REALOUT="$W/realout"; mkdir -p "$REALOUT"; printf 'cafebabecafebabecafebabecafebabe deadbeefdeadbeefdeadbeefdeadbeef none 2026-01-01T00:00:00Z fixture\n' > "$REALOUT/build_behaviour.sig"
L="$X/copyroot"; mkdir -p "$L/src"; printf 'int c(void){return 3;}\n' > "$L/src/c.c"; printf 'all:\n\t@true\n' > "$L/Makefile"
cp -a "$REALOUT" "$L/out"
before="$(md5sum < "$REALOUT/build_behaviour.sig")"
out="$(gate_require_built_from "$L" "$ROOT/scrip" 2>&1)"; rc=$?
chk "12b a root whose out/ is a COPY of another checkout's ledger passes (rc)" "$rc" "0"
case "$out" in *RECORDED*) ok "12c and records into its OWN ledger";; *) no "12c a copied-out root did not record into its own ledger: $out";; esac
chk "12d the other checkout's ledger is byte-for-byte untouched" "$(md5sum < "$REALOUT/build_behaviour.sig")" "$before"

echo "== the one-copy invariant =="
# ⛔ util_require_fresh.sh IS A SHIM AND MUST STAY ONE. The staleness rule already existed twice in this repo and a cure
# to one copy never reached the other, so it was cured a second time nine days later (4c7253e99). The probe is a second
# rule in the same place and must not repeat that.
if grep -vE '^[[:space:]]*#' "$HERE/util_require_fresh.sh" | grep -qE 'build_behaviour\.sig|md5sum|find .*-type f'; then
    no "13 util_require_fresh.sh grew probe LOGIC -- it is a calling convention, the rule lives in lib_gate.sh"
else ok "13 util_require_fresh.sh carries no probe logic (still a shim)"; fi
if grep -vE '^[[:space:]]*#' "$HERE/util_require_fresh.sh" | grep -q 'gate_require_built_from'; then ok "14 and it does call the one authority"; else no "14 shim does not reach gate_require_built_from"; fi
# ⛔ DEFAULT-ON IS THE PROPERTY, NOT AN OPTION: a probe you must remember to ask for is off exactly when it is needed.
if grep -qE '^_behaviour=1' "$HERE/util_require_fresh.sh"; then ok "15 the probe is DEFAULT-ON in the shim"; else no "15 probe is not default-on -- 144 callers would each have to remember"; fi

echo "== the evidence the next build used to destroy =="
# FINDING item 3: "the evidence I would most want is the one thing the next build destroys".
if grep -A6 '^\$(RT_SO): \$(RT_PIC_OBJS)' "$ROOT/Makefile" | grep -q 'out/attic'; then ok "16 the Makefile keeps the previous .so before relinking"; else no "16 the .so link still overwrites its predecessor with no copy kept"; fi

echo "== the witnesses =="
n=$(ls "$ROOT"/../harness/scripts/fixtures/build_behaviour/*.icn "$ROOT"/../harness/scripts/fixtures/build_behaviour/*.sno "$ROOT"/../harness/scripts/fixtures/build_behaviour/*.pl 2>/dev/null | wc -l)
if [ "$n" -ge 3 ]; then ok "17 $n pinned witnesses on disk"; else no "17 only $n pinned witnesses -- the probe's sensitivity is its coverage"; fi
if [ -f "$ROOT/../harness/scripts/fixtures/build_behaviour/README.md" ]; then ok "18 the witnesses carry their do-not-edit warning"; else no "18 no README warning beside the witnesses"; fi

echo "== the guard check accuses no file it did not read =="
# ⛔⭐ THE FALSE-RED MIRROR (hq_T 2026-09-09, found while landing this row): ARM 15 of the stale-binary gate named
# test_gate_pl_gz6b.sh as unguarded, then on a re-run named two DIFFERENT innocent files, while ten other runs of the
# identical loop over the identical 140 files said uncovered=0. Every accused file carries the shim on its own LINE 1.
# The mechanism was not established; what was cured is that a reading which did not happen can no longer become a
# verdict about a file. gate_file_has_fresh_guard is now THREE-VALUED and its callers must not collapse 2 onto 1.
g=0; gate_file_has_fresh_guard "$HERE/test_gate_pl_gz6b.sh" || g=$?
chk "19 a file that HAS the guard reads 0" "$g" "0"
g=0; gate_file_has_fresh_guard /etc/hostname || g=$?
chk "20 a file that genuinely lacks it reads 1 (a real accusation is still possible)" "$g" "1"
g=0; gate_file_has_fresh_guard "$W/no-such-file-at-all" || g=$?
chk "21 a file that CANNOT be read reads 2 -- not 1, which would accuse it" "$g" "2"
# ⛔⭐ THE CONFIRM READ MUST ASK THE SAME QUESTION. A file that MENTIONS the preflight only in a comment calls it
# nowhere and IS a violation; if the confirmation reads the raw file it finds the mention, disagrees with the real
# read, and returns 2 -- turning a nameable guilty file into "could not measure". That fails in the direction that
# HIDES WORK, which is the whole failure mode this three-valued split exists to avoid on the other side.
printf '#!/usr/bin/env bash\n# mentions util_require_fresh.sh only in this comment\necho hi\n' > "$W/commentonly.sh"
g=0; gate_file_has_fresh_guard "$W/commentonly.sh" || g=$?
chk "22 a file that only MENTIONS the preflight in a comment is a VIOLATION (1), not UNMEASURED (2)" "$g" "1"
# ⛔ NO PIPELINE: the one structural difference between this function and its sibling that never flaked (same loop, same
# files, same load) was a pipeline under `set -o pipefail`, where any upstream failure becomes the verdict.
if sed -n '/^gate_file_has_fresh_guard()/,/^}/p' "$HERE/lib_gate.sh" | grep -qE '\|[[:space:]]*grep'; then
    no "23 gate_file_has_fresh_guard grew a pipeline back -- a non-measurement can become a verdict again"
else ok "23 gate_file_has_fresh_guard is pipeline-free"; fi
# ⛔ AND THE CALLERS MUST NOT COLLAPSE 2 ONTO 1, or the defect simply moves one frame up.
if grep -q 'unmeasured2' "$HERE/test_gate_runners_refuse_on_a_stale_binary.sh"; then ok "24 ARM 15 refuses on an unmeasured file rather than naming it"; else no "24 ARM 15 still treats an unreadable file as a violation"; fi
if grep -q 'UNMEASURED' "$HERE/util_gate_preflight.sh"; then ok "25 util_gate_preflight does the same"; else no "25 util_gate_preflight still accuses on an unmeasured file"; fi

printf '\nbuild-freshness-is-behavioural gate: PASS=%d FAIL=%d over %d arms\n' "$PASS" "$FAIL" "$((PASS+FAIL))"
gate_stamp
[ "$FAIL" = 0 ] || exit 1
exit 0
