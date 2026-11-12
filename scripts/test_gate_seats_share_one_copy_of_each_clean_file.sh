#!/usr/bin/env bash
# test_gate_seats_share_one_copy_of_each_clean_file.sh -- util_shared_pristine.sh keeps read-only pristine checkouts and util_relink_root.py
# makes each clean tracked file of a seat a hard link to the pristine's (the cio 2026-11-12, row fleet-32-16-8-4-shared-repos; Lon: "Can not ALL
# the seats share a corpus repo?" / "We should save huge space this way."). A scratch origin, a scratch "coo root", a pristine and a seat.
#
# THE ARMS:
#   1  init clones the pristine --shared (objects/info/alternates names the coo root), at origin/main, every tracked regular file read-only,
#      the symlink untouched, status clean
#   2  --check on the seat reads linkable > 0 and exits 1
#   3  the relink links a, x and d/c to the pristine's inodes; b (dirty in the seat) is not linked; s (a symlink) is not linked; a file whose
#      pristine copy is writable (w) is never a link source; the seat's git status lists only b
#   4  an in-place write to the seat's a fails and the pristine's a is unchanged
#   5  origin moves a: the seat's pull gives the seat the new a on a new inode while the pristine keeps the old one; update moves the pristine,
#      leaves it clean and read-only; a second relink links a again
#   6  --check after it exits 0; a root whose repo is no checkout refuses rc 2
# EXIT: 0 all arms pass, 1 an arm failed, 2 REFUSED (no scratch, no git).
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NAME=test_gate_seats_share_one_copy_of_each_clean_file
command -v git >/dev/null || { echo "REFUSE(2) [$NAME]: no git"; exit 2; }
T="$(mktemp -d "${TMPDIR:-/tmp}/gate_relink.XXXXXX")" || { echo "REFUSE(2) [$NAME]: no scratch"; exit 2; }
trap 'chmod -R u+w "$T" 2>/dev/null; rm -rf "$T"' EXIT
G=(git -c user.name=gate -c user.email=gate@gate -c init.defaultBranch=main)
O="$T/origin.git"; C="$T/coo"; S="$T/seat"; SH="$T/shared"
"${G[@]}" init -q --bare "$O" && "${G[@]}" clone -q "$O" "$T/work" 2>/dev/null || { echo "REFUSE(2) [$NAME]: no scratch origin"; exit 2; }
( cd "$T/work" && mkdir d && printf 'a1\n' > a && printf 'b1\n' > b && printf 'x1\n' > x && chmod +x x && printf 'c1\n' > d/c && printf 'w1\n' > w && ln -s a s \
  && "${G[@]}" add -A && "${G[@]}" commit -qm one && "${G[@]}" push -q origin main ) || { echo "REFUSE(2) [$NAME]: no first commit"; exit 2; }
mkdir -p "$C" && "${G[@]}" clone -q "$O" "$C/corpus" && "${G[@]}" clone -q "$O" "$S/corpus" || { echo "REFUSE(2) [$NAME]: no clones"; exit 2; }
P="$SH/corpus"; pass=0; fail=0
ck() { if [ "$1" = ok ]; then pass=$((pass + 1)); echo "  ok   $2"; else fail=$((fail + 1)); echo "  FAIL $2"; fi; }
ino() { stat -c %i "$1" 2>/dev/null; }
wr() { [ -n "$(find "$1" -maxdepth 0 -perm /222 2>/dev/null)" ] && echo w || echo r; }
export S4E_SHARED="$SH" S4E_SHARED_FROM="$C"
bash "$HERE/util_shared_pristine.sh" init corpus > "$T/1.log" 2>&1; r1=$?
[ "$r1" = 0 ] && grep -qxF "$C/corpus/.git/objects" "$P/.git/objects/info/alternates" 2>/dev/null && [ "$(cat "$P/a" 2>/dev/null)" = a1 ] \
  && [ "$(wr "$P/a")$(wr "$P/x")$(wr "$P/d/c")" = rrr ] && [ -L "$P/s" ] && [ "$(wr "$P/s")" = w ] && [ -z "$(git -C "$P" status --porcelain)" ] \
  && ck ok "(1) init clones the pristine --shared at origin/main, its tracked files read-only, the symlink untouched, status clean" \
  || ck no "(1) rc=$r1 a=[$(cat "$P/a" 2>/dev/null)] modes=[$(wr "$P/a")$(wr "$P/x")$(wr "$P/d/c")] :: $(tail -1 "$T/1.log")"
printf 'b2\n' >> "$S/corpus/b"; chmod u+w "$P/w"
python3 -I "$HERE/util_relink_root.py" "$S" --repo corpus --check > "$T/2.log" 2>&1; r2=$?
[ "$r2" = 1 ] && grep -qE 'linkable=[1-9]' "$T/2.log" && ck ok "(2) --check reads files to link and exits 1" || ck no "(2) rc=$r2 :: $(tail -1 "$T/2.log")"
python3 -I "$HERE/util_relink_root.py" "$S" --repo corpus > "$T/3.log" 2>&1; r3=$?
[ "$r3" = 0 ] && [ "$(ino "$S/corpus/a")" = "$(ino "$P/a")" ] && [ "$(ino "$S/corpus/x")" = "$(ino "$P/x")" ] && [ "$(ino "$S/corpus/d/c")" = "$(ino "$P/d/c")" ] \
  && [ "$(ino "$S/corpus/b")" != "$(ino "$P/b")" ] && [ "$(ino "$S/corpus/w")" != "$(ino "$P/w")" ] && [ -L "$S/corpus/s" ] && grep -q 'linked=3 ' "$T/3.log" \
  && [ "$(git -C "$S/corpus" status --porcelain)" = " M b" ] \
  && ck ok "(3) the relink links a, x and d/c; not the dirty b, the symlink s, or w whose pristine copy is writable; status lists only b" \
  || ck no "(3) rc=$r3 status=[$(git -C "$S/corpus" status --porcelain | tr '\n' ';')] :: $(tail -1 "$T/3.log")"
chmod a-w "$P/w"
( printf 'oops\n' >> "$S/corpus/a" ) 2>/dev/null; r4=$?
[ "$r4" != 0 ] && [ "$(cat "$P/a")" = a1 ] && [ "$(cat "$S/corpus/a")" = a1 ] && ck ok "(4) an in-place write to a linked file fails and the pristine is unchanged" \
  || ck no "(4) write rc=$r4 pristine a=[$(cat "$P/a")]"
( cd "$T/work" && printf 'a2\n' > a && "${G[@]}" commit -qam two && "${G[@]}" push -q origin main ) || ck no "(5) the second commit"
git -C "$S/corpus" checkout -q -- b && git -C "$S/corpus" pull -q --ff-only > /dev/null 2>&1; r5a=$?
s5="$(cat "$S/corpus/a")"; p5="$(cat "$P/a")"; n5="$(stat -c %h "$S/corpus/a")"
bash "$HERE/util_shared_pristine.sh" update corpus > "$T/5.log" 2>&1; r5b=$?
python3 -I "$HERE/util_relink_root.py" "$S" --repo corpus > "$T/5c.log" 2>&1; r5c=$?
[ "$r5a" = 0 ] && [ "$s5" = a2 ] && [ "$p5" = a1 ] && [ "$n5" = 1 ] && [ "$r5b" = 0 ] && [ "$(cat "$P/a")" = a2 ] && [ "$(wr "$P/a")" = r ] \
  && [ -z "$(git -C "$P" status --porcelain)" ] && [ "$r5c" = 0 ] && [ "$(ino "$S/corpus/a")" = "$(ino "$P/a")" ] && [ -z "$(git -C "$S/corpus" status --porcelain)" ] \
  && ck ok "(5) the seat's pull takes the new a on its own inode, the pristine keeps a1 until its update, and a second relink links a again" \
  || ck no "(5) pull rc=$r5a seat a=[$s5] pristine a=[$p5] links=$n5 update rc=$r5b relink rc=$r5c :: $(tail -1 "$T/5c.log")"
python3 -I "$HERE/util_relink_root.py" "$S" --repo corpus --check > "$T/6.log" 2>&1; r6=$?
mkdir -p "$T/bad/corpus"; python3 -I "$HERE/util_relink_root.py" "$T/bad" --repo corpus > "$T/6b.log" 2>&1; r6b=$?
[ "$r6" = 0 ] && [ "$r6b" = 2 ] && ck ok "(6) --check after the relink exits 0; a root whose repo is no checkout refuses rc 2" || ck no "(6) check rc=$r6 bad root rc=$r6b :: $(tail -1 "$T/6.log")"
echo "SEATS_SHARE_BOARD arms=6 pass=$pass fail=$fail (tree $(git -C "$HERE" rev-parse --short HEAD 2>/dev/null))"
[ "$fail" = 0 ] && [ "$pass" = 6 ] && { echo "GATE OK [$NAME]: a seat's clean files are links to one read-only pristine, and no write reaches another seat"; exit 0; }
echo "GATE FAIL [$NAME]: $fail arm(s) failed"; exit 1
