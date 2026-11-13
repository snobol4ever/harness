#!/usr/bin/env bash
# util_shared_pristine.sh -- THE PRISTINE CHECKOUTS EVERY SEAT LINKS ITS FILES TO (the cio 2026-11-12, row fleet-32-16-8-4-shared-repos; Lon,
# 16:3x in the coo's window, verbatim: "Can not ALL the seats share a corpus repo?" / "We should save huge space this way.").
#
#   util_shared_pristine.sh init   [repo ...]   clone each repo --shared from the coo root (its objects borrowed, none copied), at origin/main
#   util_shared_pristine.sh update [repo ...]   fetch and fast-forward each one to origin/main, under one lock (any seat may be the updater)
#   util_shared_pristine.sh status [repo ...]   print each one's HEAD, its dirty count and its writable tracked files
#   util_shared_pristine.sh selftest            prove init, update, util_relink_root.py and util_sync_root.sh on scratch repos (rc 0 all arms
#                                               pass, 1 an arm failed, 2 REFUSED: no scratch, no git). THE ARMS:
#   1  init clones the pristine --shared (objects/info/alternates names the coo root), at origin/main, every tracked regular file read-only,
#      the symlink untouched, status clean
#   2  --check on the seat reads linkable > 0 and exits 1
#   3  the relink links a, x and d/c to the pristine's inodes; b (dirty in the seat) is not linked; s (a symlink) is not linked; a file whose
#      pristine copy is writable (w) is never a link source; the seat's git status lists only b; the repo is marked s4e.shared
#   4  an in-place write to the seat's a fails and the pristine's a is unchanged
#   5  origin moves a: the seat's pull gives the seat the new a on a new inode while the pristine keeps the old one; update moves the pristine,
#      leaves it clean and read-only; a second relink links a again
#   6  --check after it exits 0; a root whose repo is no checkout refuses rc 2
#   7  util_sync_root.sh: origin moves d/c; a marked root's sync brings the pristine to its HEAD and links the new d/c; an unmarked root's sync
#      takes the new d/c and links nothing
#   8  a seat file whose mtime is newer than the pristine's is linked keeping that mtime: the shared inode moves forward, never back (the cto
#      2026-11-12: build_monitor_ipc_bin_libraries.sh and util_parser_sc_recognition.sh keep a derived file newer than its source); trustctime off
#
# repos: corpus harness .github (the default: all three). S4E_SHARED names the directory (default /home/resources/shared), S4E_SHARED_FROM the
# root whose objects they borrow (default /home/claude_coo). Every tracked regular file of a pristine is READ-ONLY: util_relink_root.py makes a
# seat's clean file a hard link to it, so an in-place write anywhere fails loudly instead of writing into every seat (MEASURED 2026-11-12: git's
# own checkout replaces a file by a new inode, so a pull in a seat or here never writes through a link). A pristine is never edited: one that
# reads dirty refuses rc 2 and is not moved. Only a file that is writable is chmodded, so an unchanged file keeps its ctime and no seat's git
# re-reads it.
# EXIT: 0 done, 2 REFUSED (no source repo, a dirty pristine, a fetch or merge that failed); selftest as above.
set -uo pipefail
SH="${S4E_SHARED:-/home/resources/shared}"; SRC="${S4E_SHARED_FROM:-/home/claude_coo}"
cmd="${1:-}"; shift 2>/dev/null
repos=("$@"); [ "${#repos[@]}" -gt 0 ] || repos=(corpus harness .github)
refuse() { echo "REFUSE(2) [shared-pristine]: $*"; exit 2; }
readonly_all() {   # dir -> every tracked regular file that is writable loses its write bits; prints how many
    git -C "$1" ls-files -s -z | python3 -I -c '
import os, stat, sys
d = sys.argv[1]; n = 0
for rec in sys.stdin.buffer.read().split(b"\0"):
    if not rec:
        continue
    meta, _, path = rec.partition(b"\t")
    mode, _, stage = meta.split(b" ")
    if stage != b"0" or mode not in (b"100644", b"100755"):
        continue
    p = os.path.join(d.encode(), path)
    try:
        st = os.lstat(p)
    except FileNotFoundError:
        continue
    if stat.S_ISREG(st.st_mode) and st.st_mode & 0o222:
        os.chmod(p, st.st_mode & ~0o222); n += 1
print(n)' "$1"
}
selftest() {   # the tool proves itself on scratch repos (folded from test_gate_seats_share_one_copy_of_each_clean_file.sh, the coo 2026-11-12 17:4x:
    # no gate is written, skill gates-and-witnesses section 0); a scratch origin, a scratch "coo root", a pristine and a seat; nothing live is touched
    local HERE NAME=shared-pristine-selftest; HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
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
      && [ "$(git -C "$S/corpus" status --porcelain)" = " M b" ] && [ "$(git -C "$S/corpus" config --get s4e.shared)" = true ] \
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
    R7="$T/root7"; R8="$T/root8"
    for R in "$R7" "$R8"; do mkdir -p "$R/harness/scripts" && cp "$HERE/util_relink_root.py" "$HERE/util_shared_pristine.sh" "$R/harness/scripts/" && "${G[@]}" clone -q "$O" "$R/corpus"; done
    python3 -I "$HERE/util_relink_root.py" "$R7" --repo corpus > /dev/null 2>&1
    ( cd "$T/work" && printf 'c3\n' > d/c && "${G[@]}" commit -qam three && "${G[@]}" push -q origin main ) || ck no "(7) the third commit"
    S4E_HOME="$R7" S4E_SYNC_REPOS=corpus TMPDIR="$T" bash "$HERE/util_sync_root.sh" > "$T/7.log" 2>&1; r7=$?
    S4E_HOME="$R8" S4E_SYNC_REPOS=corpus TMPDIR="$T" bash "$HERE/util_sync_root.sh" > "$T/8.log" 2>&1; r8=$?
    [ "$r7" = 0 ] && [ "$r8" = 0 ] && [ "$(cat "$R7/corpus/d/c")" = c3 ] && [ "$(cat "$P/d/c")" = c3 ] && [ "$(ino "$R7/corpus/d/c")" = "$(ino "$P/d/c")" ] \
      && [ "$(cat "$R8/corpus/d/c")" = c3 ] && [ "$(ino "$R8/corpus/d/c")" != "$(ino "$P/d/c")" ] && [ "$(ino "$R8/corpus/a")" != "$(ino "$P/a")" ] && [ -z "$(git -C "$R7/corpus" status --porcelain)" ] \
      && ck ok "(7) a marked root's sync brings the pristine to its HEAD and links what the merge rewrote; an unmarked root's sync links nothing" \
      || ck no "(7) sync rc=$r7/$r8 R7 d/c=[$(cat "$R7/corpus/d/c")] pristine d/c=[$(cat "$P/d/c")] :: $(tail -2 "$T/7.log" | tr '\n' '|' | cut -c1-200)"
    R9="$T/root9"; "${G[@]}" clone -q "$O" "$R9/corpus" && touch -d '+2 hours' "$R9/corpus/x" && m9="$(stat -c %Y "$R9/corpus/x")"
    python3 -I "$HERE/util_relink_root.py" "$R9" --repo corpus > "$T/9.log" 2>&1; r9=$?
    [ "$r9" = 0 ] && [ "$(ino "$R9/corpus/x")" = "$(ino "$P/x")" ] && [ "$(stat -c %Y "$R9/corpus/x")" -ge "$m9" ] && [ "$(stat -c %Y "$P/x")" -ge "$m9" ] \
      && [ "$(git -C "$R9/corpus" config --get core.trustctime)" = false ] && [ -z "$(git -C "$R9/corpus" status --porcelain)" ] \
      && ck ok "(8) a seat file newer than the pristine's is linked with its own mtime kept (the shared inode moves forward, never back); trustctime off" \
      || ck no "(8) rc=$r9 mtime before=$m9 after=$(stat -c %Y "$R9/corpus/x") pristine=$(stat -c %Y "$P/x") :: $(tail -1 "$T/9.log")"
    echo "SHARED_PRISTINE_SELFTEST arms=8 pass=$pass fail=$fail (tree $(git -C "$HERE" rev-parse --short HEAD 2>/dev/null))"
    [ "$fail" = 0 ] && [ "$pass" = 8 ] && { echo "SELFTEST OK [$NAME]: a seat's clean files are links to one read-only pristine, and no write reaches another seat"; exit 0; }
    echo "SELFTEST FAIL [$NAME]: $fail arm(s) failed"; exit 1
}
case "$cmd" in
    init)
        mkdir -p "$SH" || refuse "cannot make $SH"
        for r in "${repos[@]}"; do
            p="$SH/$r"
            if [ -e "$p/.git" ]; then echo "PRISTINE $r exists at $p (init leaves it; update moves it)"; continue; fi
            [ -d "$SRC/$r/.git" ] || refuse "$SRC/$r is not a repo"
            git clone -q --shared --no-checkout "$SRC/$r" "$p" || refuse "clone --shared $SRC/$r failed"
            git -C "$p" remote set-url origin "$(git -C "$SRC/$r" remote get-url origin)" || refuse "$r: no origin url in $SRC/$r"
            git -C "$p" fetch -q origin && git -C "$p" checkout -q -B main origin/main || refuse "$r: fetch or checkout of origin/main failed"
            echo "PRISTINE $r init at $p head=$(git -C "$p" rev-parse --short=9 HEAD) readonly_set=$(readonly_all "$p")"
        done ;;
    update)
        mkdir -p "$SH" || refuse "no $SH"
        exec 9> "$SH/.update.flock"; flock 9
        for r in "${repos[@]}"; do
            p="$SH/$r"; [ -e "$p/.git" ] || refuse "no pristine $p (init makes it)"
            [ -z "$(git -C "$p" status --porcelain --untracked-files=no)" ] || refuse "$p reads dirty: a pristine is never edited; find the writer"
            old="$(git -C "$p" rev-parse HEAD)"
            git -C "$p" fetch -q origin && git -C "$p" merge -q --ff-only origin/main || refuse "$r: fetch or fast-forward failed"
            echo "PRISTINE $r ${old:0:9}..$(git -C "$p" rev-parse --short=9 HEAD) readonly_set=$(readonly_all "$p")"
        done ;;
    status)
        for r in "${repos[@]}"; do
            p="$SH/$r"; [ -e "$p/.git" ] || { echo "PRISTINE $r absent"; continue; }
            w="$(git -C "$p" ls-files -z | (cd "$p" && xargs -0 -r find 2>/dev/null -maxdepth 0 -type f -perm /222) | wc -l)"
            echo "PRISTINE $r head=$(git -C "$p" rev-parse --short=9 HEAD) dirty=$(git -C "$p" status --porcelain --untracked-files=no | wc -l) writable=$w"
        done ;;
    selftest) selftest ;;
    *) refuse "usage: util_shared_pristine.sh init|update|status [corpus|harness|.github ...] | selftest" ;;
esac
