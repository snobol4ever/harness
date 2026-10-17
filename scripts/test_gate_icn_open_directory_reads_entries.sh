#!/bin/bash
# Icon open(<directory>) READS THE DIRECTORY'S ENTRIES. Row: the CEO-516 item-2 held three
# (rung36_jcon_recent). Exposed by the jcon suite, cured by hq_I 2026-09-10.
#
# THE DEFECT THIS PINS, in two parts -- the second is the one a plausible cure gets wrong:
#  (1) open(".") SUCCEEDED and then yielded NOTHING. fopen() on a directory succeeds on Linux, so
#      open() returned a healthy handle and every read() off it failed -- "entries read: 0" while
#      type(f) == "file". Not a diagnostic anywhere; the program simply found no files.
#  (2) reads(f, n) ON A DIRECTORY RETURNS ONE ENTRY, truncated to n -- NOT n raw bytes. iconx does
#      not treat a directory as a byte stream. The first cure here snapshotted the entries into a
#      tmpfile, which fixed (1) and left (2) wrong: reads(f,25) then spanned entry boundaries and
#      returned "Makefile\nrecent.dat\nrecen", so a name-membership test found 3 of 5 names instead
#      of 5. rung36_jcon_recent reads in a read/!f/reads rotation and is exactly what caught it --
#      its own comment ("assumes no name longer than 25") is the upstream author saying reads()
#      returns one name.
#
# ⛔ WHY BOTH ARMS RUN IN ONE DIRECTORY, SAME INODE. A directory listing is readdir order, which is
# per-directory: two directories holding the same NAMES can enumerate in different ORDER, and any
# byte-offset-sensitive read over them then diverges legitimately. Grading the oracle in one temp
# dir against SCRIP in another measured that difference and reported it as a defect (3 "missing"
# lines that were nothing of the kind) until both arms were moved into the same directory. The
# oracle's compiled binary is deliberately kept OUTSIDE the run directory, since it would otherwise
# be an entry on one side only -- the same confound wearing a smaller face.
# ⭐ ARM A is order-INDEPENDENT by construction (it collects entries into a set and prints them
# sorted), so it cannot go red on a filesystem that enumerates differently. ARM B is deliberately
# order-SENSITIVE-FREE too: it asserts one entry per reads() by shape (no embedded newline, and the
# set of names complete), never by position.
# ⛔ A GATE THAT CANNOT MEASURE REFUSES rc=2 -- all 4 runs (2 witnesses x 2 modes) must be graded.
# ⭐ NEGATIVE-TESTED AS A DISCRIMINATOR (CEO-510), both parts separately: with rt_dir_snapshot's
# call site removed, ARM A goes RED in both modes ("entries read: 0"); with only the reads() 'd'
# branch removed, ARM A stays GREEN and ARM B goes RED with 25-char chunks carrying newlines --
# which is the point of having two arms, because part (2) is invisible to part (1)'s witness.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
cd "$ROOT" || exit 2
[ -x ./scrip ] && [ -f out/libscrip_rt.so ] || { echo "⛔ GATE REFUSES (rc=2): scrip/runtime not built at $ROOT"; exit 2; }
ICONT=/home/resources/icon-master/bin/icont; ICONX=/home/resources/icon-master/bin/iconx
[ -x "$ICONT" ] && [ -x "$ICONX" ] || { echo "⛔ GATE REFUSES (rc=2): Icon oracle missing at $ICONT / $ICONX -- it is NOT on PATH, so command -v answers a narrower question than this gate is asking"; exit 2; }
. "$ROOT/../harness/scripts/lib_gate.sh" || { echo "⛔ GATE REFUSES (rc=2): ../harness/scripts/lib_gate.sh unreadable"; exit 2; }
gate_require_fresh "$ROOT" src "$ROOT/scrip" "$ROOT/out/libscrip_rt.so"
d=$(mktemp -d) || exit 2
trap 'rm -rf "$d"' EXIT
cat > "$d/armA.icn" <<'EOF'
procedure main();
   local f, fset, s;
   f := open(".") | stop("open(.) failed");
   write("type=", type(f));
   fset := set();
   while insert(fset, read(f)) do {
      insert(fset, !f);
      insert(fset, reads(f, 25));
      };
   close(f);
   write("entries=", *fset);
   every s := !sort(fset) do write("entry: ", s);
end
EOF
cat > "$d/armB.icn" <<'EOF'
procedure main();
   local f, s, n;
   f := open(".") | stop("open(.) failed");
   n := 0;
   while s := reads(f, 25) do {
      n := n + 1;
      if find("\n", s) then write("EMBEDDED NEWLINE in chunk ", n, ": ", image(s));
      };
   close(f);
   write("chunks=", n);
end
EOF
"$ICONT" -s -o "$d/armA.ora" "$d/armA.icn" >/dev/null 2>&1 || { echo "⛔ GATE REFUSES (rc=2): icont rejected armA -- cannot measure"; exit 2; }
"$ICONT" -s -o "$d/armB.ora" "$d/armB.icn" >/dev/null 2>&1 || { echo "⛔ GATE REFUSES (rc=2): icont rejected armB -- cannot measure"; exit 2; }
graded=0; bad=0
# ONE run directory, shared by every arm, with fixed contents. The .ora binaries and the .s/.m4
# artifacts live in $d, never in $d/run, so they are not entries on one side only.
mkdir -p "$d/run" || exit 2
: > "$d/run/alpha.txt"; : > "$d/run/beta.txt"; : > "$d/run/gamma_named_longer.txt"; mkdir -p "$d/run/subdir"
for w in armA armB; do
    want=$( cd "$d/run" && timeout -k 5 30 "$ICONX" "$d/$w.ora" </dev/null 2>/dev/null ); wrc=$?
    [ "$wrc" != 124 ] || { echo "⛔ GATE REFUSES (rc=2): the ORACLE timed out on $w -- cannot measure"; exit 2; }
    case "$w" in
      armA) printf '%s\n' "$want" | /usr/bin/grep -q '^entries=6$' || { echo "⛔ GATE REFUSES (rc=2): oracle armA reported $(printf '%s\n' "$want" | /usr/bin/grep '^entries=' ) -- expected entries=6 (. .. alpha.txt beta.txt gamma_named_longer.txt subdir); cannot measure"; exit 2; } ;;
      armB) printf '%s\n' "$want" | /usr/bin/grep -q '^chunks=6$' || { echo "⛔ GATE REFUSES (rc=2): oracle armB reported $(printf '%s\n' "$want" | /usr/bin/grep '^chunks=' ) -- expected chunks=6, one per entry; cannot measure"; exit 2; } ;;
    esac
    got=$( cd "$d/run" && timeout -k 5 30 "$ROOT/scrip" "$d/$w.icn" </dev/null 2>/dev/null ); grc=$?
    graded=$((graded+1))
    if [ "$got" != "$want" ] || [ "$grc" != "$wrc" ]; then
        echo "  ⛔ RED m3 $w: rc=$grc (oracle rc=$wrc)"; diff <(printf '%s\n' "$want") <(printf '%s\n' "$got") | sed 's/^/      /'; bad=1
    fi
    if timeout -k 5 180 "$ROOT/scrip" --compile -o "$d/$w.s" "$d/$w.icn" </dev/null >/dev/null 2>&1 \
       && gcc -m64 -no-pie "$d/$w.s" -o "$d/$w.m4" -L"$ROOT/out" -lscrip_rt -Wl,-rpath,"$ROOT/out" -lm -lpthread 2>/dev/null; then
        got=$( cd "$d/run" && timeout -k 5 30 "$d/$w.m4" </dev/null 2>/dev/null ); grc=$?
        graded=$((graded+1))
        if [ "$got" != "$want" ] || [ "$grc" != "$wrc" ]; then
            echo "  ⛔ RED m4 $w: rc=$grc (oracle rc=$wrc)"; diff <(printf '%s\n' "$want") <(printf '%s\n' "$got") | sed 's/^/      /'; bad=1
        fi
    else
        graded=$((graded+1)); echo "  ⛔ RED m4 $w: does not compile/link"; bad=1
    fi
done
[ "$graded" = 4 ] || { echo "⛔ GATE REFUSES (rc=2): graded $graded of the 4 required runs"; exit 2; }
[ "$bad" = 0 ] || { echo "⛔ GATE RED [icn_open_directory_reads_entries]: open(<directory>) does not answer as the oracle does"; exit 1; }
echo "✅ GATE OK [icn_open_directory_reads_entries]: open(.) yields all 6 entries through read/!f/reads, and reads(f,25) returns ONE entry per call rather than 25 raw bytes -- BOTH modes, graded live against iconx in one shared directory"
