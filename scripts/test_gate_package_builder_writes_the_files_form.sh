#!/usr/bin/env bash
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
# test_gate_package_builder_writes_the_files_form.sh -- a package in the files form (CIO-59, CIO-113: its ALL.csv has a path column, NAME.in,
# NAME.out and NAME.err beside each program, no container) is rebuilt by util_build_package_suite.py IN the files form, so a rebuild never
# brings ALL.<ext>, ALL.ref, ALL.in or ALL.argv back (the coo 2026-11-10, row packages-form-the-package-builder-writes-a-converted-package-
# in-its-files-form; Lon 2026-11-10: a package keeps the layout of its distribution with NAME.in, NAME.out and NAME.err side by side).
#
# THE ARMS (a scratch Icon package of three programs, the oracle icont/iconx; mode 3 is not run, the builder cuts answers and grades nothing):
#   1  a whole build of the planted files-form package: rc 0, each NAME.out is the oracle's answer (a from stdout, b from its b.in, sub/c
#      from its two arguments in ALL.args), ALL.csv keeps its path column, and no container file is there
#   2  a.out holding the oracle's own last blank line (a prints one) keeps those bytes through a whole rebuild (CIO-117)
#   3  after b.icn changes, --only b rewrites b.out and b's index row, and no other file changes by one byte
#   4  a build that refuses (--only names a program the package does not ship) exits 2 and leaves every file as it stood
#   5  the control: the same three programs with no path column build as a container (ALL.icn is written), so arm 1 reads the form
# EXIT: 0 all arms pass, 1 an arm failed, 2 REFUSED (no binary, no oracle).
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NAME=package_builder_writes_the_files_form
. "$HERE/lib_oracle_flags.sh" 2>/dev/null
IC="$(icont_bin 2>/dev/null)"; [ -n "$IC" ] && [ -x "$IC" ] || { echo "REFUSE(2) [$NAME]: no Icon oracle (icont_bin)"; exit 2; }
T="$(mktemp -d "${TMPDIR:-/tmp}/gate_pkg_files_form.XXXXXX")" || { echo "REFUSE(2) [$NAME]: no scratch directory"; exit 2; }
trap 'rm -rf "$T"' EXIT
B="$HERE/util_build_package_suite.py"
plant() {
  mkdir -p "$1/sub"
  printf 'procedure main()\n    write("alpha");\n    write();\nend\n' > "$1/a.icn"
  printf 'procedure main()\n    local s;\n    while s := read() do write("got ", s);\nend\n' > "$1/b.icn"
  printf 'one\ntwo\n' > "$1/b.in"
  printf 'procedure main(args)\n    every write("arg ", !args);\nend\n' > "$1/sub/c.icn"
}
sums() { ( cd "$1" && find . -type f | LC_ALL=C sort | xargs sha256sum ); }
containers() { ( cd "$1" && ls ALL.icn ALL.ref ALL.in ALL.argv 2>/dev/null | tr '\n' ' ' ); }
pass=0; fail=0
ck() { if [ "$1" = ok ]; then pass=$((pass + 1)); echo "  ok   $2"; else fail=$((fail + 1)); echo "  FAIL $2"; fi; }

P="$T/planted_pkg"; plant "$P"
printf 'entry,path\na,a.icn\nb,b.icn\nsub/c,sub/c.icn\n' > "$P/ALL.csv"
printf 'sub/c\tx\ty z\n' > "$P/ALL.args"
timeout -k 5 600 python3 "$B" "$P" --lang icon > "$T/1.log" 2>&1; r1=$?
[ "$r1" = 2 ] && grep -q -i 'stale\|no scrip\|oracle' "$T/1.log" && { echo "REFUSE(2) [$NAME]: the builder could not run: $(grep -m1 -i 'refus' "$T/1.log" | cut -c1-200)"; exit 2; }
[ "$r1" = 0 ] && [ "$(cat "$P/a.out" 2>/dev/null)" = alpha ] && [ "$(cat "$P/b.out" 2>/dev/null)" = "$(printf 'got one\ngot two')" ] \
  && [ "$(cat "$P/sub/c.out" 2>/dev/null)" = "$(printf 'arg x\narg y z')" ] && head -1 "$P/ALL.csv" | grep -q '^rank,entry,path,' && [ -z "$(containers "$P")" ] \
  && [ "$(cat "$P/ALL.args")" = "$(printf 'sub/c\tx\ty z')" ] \
  && ck ok "(1) a whole build keeps the files form: three answers cut, the path column kept, no container" \
  || ck no "(1) whole build rc=$r1 containers=[$(containers "$P")] head=$(head -1 "$P/ALL.csv" | cut -c1-40) :: $(tail -1 "$T/1.log" | cut -c1-160)"

printf 'alpha\n\n' > "$P/a.out"
timeout -k 5 600 python3 "$B" "$P" --lang icon > "$T/2.log" 2>&1; r2=$?
[ "$r2" = 0 ] && [ "$(od -An -c "$P/a.out" | tr -d ' \n')" = 'alpha\n\n' ] && [ -z "$(containers "$P")" ] \
  && ck ok "(2) a.out keeps the oracle's last blank line through a rebuild" \
  || ck no "(2) rc=$r2 a.out=$(od -An -c "$P/a.out" | tr -d ' \n') containers=[$(containers "$P")]"

sums "$P" > "$T/before3"; grep -v '^[0-9]*,b,' "$P/ALL.csv" > "$T/csv3.before"
sed -i 's/"got "/"saw "/' "$P/b.icn"
timeout -k 5 600 python3 "$B" "$P" --lang icon --only b > "$T/3.log" 2>&1; r3=$?
sums "$P" > "$T/after3"; grep -v '^[0-9]*,b,' "$P/ALL.csv" > "$T/csv3.after"
changed="$(diff "$T/before3" "$T/after3" | grep '^>' | awk '{print $3}' | LC_ALL=C sort | tr '\n' ' ')"
[ "$r3" = 0 ] && [ "$(cat "$P/b.out")" = "$(printf 'saw one\nsaw two')" ] && cmp -s "$T/csv3.before" "$T/csv3.after" && [ -z "$(containers "$P")" ] \
  && case "$changed" in "./b.icn ./b.out "|"./ALL.csv ./b.icn ./b.out ") true;; *) false;; esac \
  && ck ok "(3) --only b rewrites b.out (and b's row) and no other file" \
  || ck no "(3) rc=$r3 changed=[$changed] containers=[$(containers "$P")] :: $(tail -1 "$T/3.log" | cut -c1-160)"

sums "$P" > "$T/before4"
timeout -k 5 600 python3 "$B" "$P" --lang icon --only nosuch > "$T/4.log" 2>&1; r4=$?
sums "$P" > "$T/after4"
[ "$r4" = 2 ] && cmp -s "$T/before4" "$T/after4" \
  && ck ok "(4) a refused build exits 2 and leaves every file as it stood" \
  || ck no "(4) rc=$r4 $(diff "$T/before4" "$T/after4" | grep -c '^[<>]') line(s) of the file list differ"

C="$T/control_pkg"; plant "$C"
timeout -k 5 600 python3 "$B" "$C" --lang icon > "$T/5.log" 2>&1; r5=$?
[ "$r5" = 0 ] && [ -f "$C/ALL.icn" ] && [ -f "$C/ALL.ref" ] && ! head -1 "$C/ALL.csv" | grep -q ',path,' \
  && ck ok "(5) the control with no path column builds as a container" \
  || ck no "(5) rc=$r5 containers=[$(containers "$C")] :: $(tail -1 "$T/5.log" | cut -c1-160)"

echo "PACKAGE_BUILDER_FILES_FORM_BOARD arms=5 pass=$pass fail=$fail (tree $(git -C "$HERE" rev-parse --short HEAD 2>/dev/null))"
[ "$fail" = 0 ] && [ "$pass" = 5 ] && { echo "GATE OK [$NAME]: a files-form package is rebuilt in the files form"; exit 0; }
echo "GATE FAIL [$NAME]: $fail arm(s) failed"; exit 1
