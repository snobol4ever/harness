#!/usr/bin/env bash
# test_gate_progress_pin_survives_an_abbreviation_change.sh -- THE GROUND MOVES ONLY WHEN THE COMMIT DOES (the grader 2026-11-12). MEASURED on lap
# 23: git lengthened its abbreviation of the grader root's SCRIP from 9 to 10 characters mid-lap, util_progress_append.assert_ground_unmoved
# compared the short forms, read "scrip ea374ea10 -> ea374ea103" as a move, and three graded cells appended nothing (xsb chunk:03, puzzles
# chunk:01 and chunk:02, about 5 h of grading). On two scratch repositories: ARM 1 pins, lengthens core.abbrev in both, and the append-time
# check must NOT refuse; ARM 2 commits in the SCRIP repository after the pin and the check MUST refuse (the gate can still trip).
# rc 0 both arms hold; 1 an arm fails, named; 2 cannot measure (no git, no python, the writer will not import).
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
command -v git > /dev/null && command -v python3 > /dev/null || { echo "REFUSE(2) [test_gate_progress_pin_survives_an_abbreviation_change]: no git or python3"; exit 2; }
T="$(mktemp -d "${TMPDIR:-/tmp}/gate_pin_abbrev.XXXXXX")" || { echo "REFUSE(2): mktemp failed"; exit 2; }
trap 'rm -rf "${T:?}"' EXIT
for r in SCRIP corpus; do
    git -c init.defaultBranch=main init -q "$T/$r" && git -C "$T/$r" config user.email gate@example.invalid && git -C "$T/$r" config user.name gate \
        && git -C "$T/$r" config core.abbrev 7 && echo "$r" > "$T/$r/f" && git -C "$T/$r" add f && git -C "$T/$r" commit -q -m "$r base" \
        || { echo "REFUSE(2): scratch repository $r not made"; exit 2; }
done
mkdir -p "$T/SCRIP/out" && printf 'driver\n' > "$T/SCRIP/scrip" && printf 'runtime\n' > "$T/SCRIP/out/libscrip_rt.so" && chmod +x "$T/SCRIP/scrip"
printf 'scrip\nout/\n' > "$T/SCRIP/.gitignore" && git -C "$T/SCRIP" add .gitignore && git -C "$T/SCRIP" commit -q -m ignore
out="$(S4E_HOME="$T" python3 -I - "$HERE" "$T" 2>&1 <<'PY'
import sys, subprocess
sys.path.insert(0, sys.argv[1]); T = sys.argv[2]
try:
    import util_progress_append as pa
except Exception as e:
    print("REFUSE(2): the writer will not import: %s" % e); sys.exit(2)
pa.pin_context(T + "/SCRIP/scrip", T + "/SCRIP/out")
short0 = pa._PINNED.get("scrip")
for r in ("SCRIP", "corpus"):
    subprocess.run(["git", "-C", T + "/" + r, "config", "core.abbrev", "12"], check=True)
short1 = pa._git_short(T + "/SCRIP")
if short0 == short1 or not short1.startswith(short0):
    print("REFUSE(2): the abbreviation did not lengthen (%s then %s): the arm measures nothing" % (short0, short1)); sys.exit(2)
a1 = 1
try:
    pa.assert_ground_unmoved()
except pa.ProgressGroundMoved as e:
    a1 = 0; print("ARM 1 FAIL: the same commit read as a move after the abbreviation grew (%s -> %s): %s" % (short0, short1, str(e)[:120]))
if a1: print("ARM 1 OK: the abbreviation grew %s -> %s on the same commit and the check stood" % (short0, short1))
subprocess.run(["git", "-C", T + "/SCRIP", "commit", "-q", "--allow-empty", "-m", "a move"], check=True)
a2 = 0
try:
    pa.assert_ground_unmoved()
except pa.ProgressGroundMoved:
    a2 = 1
print("ARM 2 OK: a new commit after the pin is refused" if a2 else "ARM 2 FAIL: a new commit after the pin was not refused")
sys.exit(0 if a1 and a2 else 1)
PY
)"; rc=$?
printf '%s\n' "$out"
[ "$rc" = 2 ] && { echo "REFUSE(2) [test_gate_progress_pin_survives_an_abbreviation_change]"; exit 2; }
echo "PIN_ABBREV_BOARD arms=2 rc=$rc (tree $(git -C "$HERE/.." rev-parse --short HEAD 2>/dev/null))"
[ "$rc" = 0 ] && { echo "GATE OK [test_gate_progress_pin_survives_an_abbreviation_change]"; exit 0; }
echo "GATE FAIL [test_gate_progress_pin_survives_an_abbreviation_change]"; exit 1
