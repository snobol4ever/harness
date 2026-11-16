#!/usr/bin/env bash
# util_xpce_kernel_build.sh key | build | check [--deep] | hello -- THE XPCE KERNEL LIBRARY, ONCE FOR THE BOX (DESIGN-PLAN prolog-xpce step 1, the cio 2026-11-16; skill prolog reference, THE XPCE FACILITY).
# XPCE's C kernel of tag V9.0.4 is read where it stands and built by the recipe harness/xpce/CMakeLists.txt as one shared library with no SWI-Prolog in it, the oracle's
# own stream source of 9.0.4 compiled in. The library stands outside every root, at /home/resources/xpce-kernel/KEY/libxpce.so; the one-line text file
# /home/resources/xpce-kernel/CURRENT names the key (a file, never a link). No seat's root holds a copy and no SCRIP make builds it.
#   key     prints KEY: the first 16 hex digits of the sha256 over the kernel tree's src and cmake files, the five stream files, the three cmake helper files,
#           the recipe's build files and the first line of gcc --version and of cmake --version. Names are hashed relative, so the key is the same from any folder.
#   build   builds only when KEY's folder is absent: a scratch build through the batch door, checked for undefined names, staged beside its place and renamed
#           into it, so no seat ever reads a half-built library; then CURRENT is rewritten by rename. One builder at a time (a lock file in the top folder).
#   check   the standing library is the one today's tree, recipe and compiler make: CURRENT's key is today's key, the library's sha256 is the one its build
#           recorded, ldd -r names no undefined name, and it exports the names of harness/xpce/EXPORTS.txt and no other (the kernel's 422, the three host
#           entries of xpce_host.c, no stream name). --deep builds once more in scratch and compares byte for byte (two builds are equal: MEASURED 2026-11-16).
#   hello   the witness: xpce_k_hello.c linked against the standing library ALONE (ldd names no libswipl), run on the screen road twice with the argument
#           text and twice without, each screen line read against the oracle's cut (xpce_k_hello.screen, xpce_k_box.screen: the same pictures as Prolog
#           programs under swipl on one thread).
# rc 0 done or green; rc 1 a measured red (no library stands, stale, differs, a picture differs); rc 2 REFUSE: usage, a tree or a tool missing, the road could not measure.
# One board line a verb: XPCE_KERNEL_BOARD ... ending OK or FAIL. The folders can be named for a test: S4E_XPCE_KERNEL (the top), S4E_XPCE_RECIPE, S4E_XPCE_TREE, S4E_XPCE_STREAM_TREE, S4E_XPCE_CMAKE_HELPERS.
set -u
. "${S4E_HARNESS:-/home/harness}/scripts/lib_paths.sh" || { echo "REFUSE(2): lib_paths.sh did not load"; exit 2; }
RECIPE="${S4E_XPCE_RECIPE:-$S4E_HARNESS/xpce}"
TREE="${S4E_XPCE_TREE:-/home/resources/xpce-V9.0.4}"
STREAMS="${S4E_XPCE_STREAM_TREE:-/home/resources/swipl-V9.0.4-os}"
HELPERS="${S4E_XPCE_CMAKE_HELPERS:-/home/resources/swipl-devel-master}"
TOP="${S4E_XPCE_KERNEL:-/home/resources/xpce-kernel}"
seat="${S4E_SEAT:-$(id -un)}"
SCRATCH="/tmp/s4e/$seat"
STREAM_FILES="src/os/pl-stream.c src/os/pl-utf8.c src/os/pl-utf8.h src/os/pl-stream.h src/os/SWI-Stream.h"
HELPER_FILES="cmake/Utils.cmake cmake/TestBSDSignals.cmake packages/cmake/Sockets.cmake"
BUILD_FILES="CMakeLists.txt xpce_stream_seams.c xpce_host.c seams/config.h seams/pl-mutex.h seams/pl-error.h seams/os/pl-locale.h"
refuse() { echo "REFUSE(2): $*"; exit 2; }
board() { echo "XPCE_KERNEL_BOARD $*"; }
need() {
    local f t
    for t in gcc cmake sha256sum nm ldd; do command -v "$t" > /dev/null || refuse "no $t on this box"; done
    [ -d "$TREE/src" ] && [ -f "$TREE/cmake/XPCESources.cmake" ] || refuse "no XPCE kernel tree at $TREE (src and cmake/XPCESources.cmake)"
    for f in $STREAM_FILES; do [ -f "$STREAMS/$f" ] || refuse "the stream source $STREAMS/$f is absent"; done
    for f in $HELPER_FILES; do [ -f "$HELPERS/$f" ] || refuse "the cmake helper $HELPERS/$f is absent"; done
    for f in $BUILD_FILES EXPORTS.txt; do [ -f "$RECIPE/$f" ] || refuse "the recipe file $RECIPE/$f is absent"; done
}
key() {
    {   gcc --version | head -1; cmake --version | head -1
        ( cd "$TREE" && find src cmake config.h.cmake -type f -print0 | LC_ALL=C sort -z | xargs -0 sha256sum )
        ( cd "$STREAMS" && sha256sum $STREAM_FILES )
        ( cd "$HELPERS" && sha256sum $HELPER_FILES )
        ( cd "$RECIPE" && sha256sum $BUILD_FILES )
    } | sha256sum | cut -c1-16
}
make_into() {   # <build dir> <log>: configure and build the library there through the batch door; rc 1 with the log's last lines when it fails
    local b="$1" log="$2"
    cmake -S "$RECIPE" -B "$b" -DCMAKE_BUILD_TYPE=Release -DXPCE_TREE="$TREE" -DSWIPL_OS_TREE="$STREAMS" -DSWIPL_TREE="$HELPERS" > "$log" 2>&1 || { tail -5 "$log"; return 1; }
    bash "$S4E_HARNESS/scripts/util_batch.sh" cmake --build "$b" -j4 >> "$log" 2>&1 || { grep -m5 -E 'error|Error' "$log"; tail -3 "$log"; return 1; }
    [ -s "$b/libxpce.so" ] || { echo "the build left no libxpce.so in $b"; return 1; }
}
undefined_of() { ldd -r "$1" 2>&1 | grep -c 'undefined symbol' || true; }
exports_of() { nm -D --defined-only "$1" | awk '{print $NF}' | LC_ALL=C sort -u; }
set_current() { printf '%s\n' "$1" > "$TOP/.CURRENT.$$" && mv -f "$TOP/.CURRENT.$$" "$TOP/CURRENT"; }
do_build() {
    need; local k b s u t0
    k="$(key)"; [ -n "$k" ] || refuse "no key could be computed"
    mkdir -p "$TOP" "$TOP/appdata-empty" "$SCRATCH" || refuse "cannot make $TOP or $SCRATCH"
    exec 6> "$TOP/.build.lock" || refuse "cannot open the build lock in $TOP"
    flock -w 1800 6 || refuse "another build has held $TOP/.build.lock for 1800 s"
    if [ -s "$TOP/$k/libxpce.so" ]; then
        [ "$(cat "$TOP/CURRENT" 2>/dev/null)" = "$k" ] || set_current "$k"
        board "key=$k the library stands already at $TOP/$k/libxpce.so, nothing built; CURRENT names it OK"; return 0
    fi
    b="$SCRATCH/xpce-kernel-build.$k.$$"; s="$TOP/.stage.$k.$$"; t0="$(date +%s)"
    rm -rf "$b" "$s"
    make_into "$b" "$SCRATCH/xpce-kernel-build.$k.$$.log" || { board "key=$k the build failed (log $SCRATCH/xpce-kernel-build.$k.$$.log, tree kept $b) FAIL"; return 1; }
    u="$(undefined_of "$b/libxpce.so")"
    [ "$u" = 0 ] || { board "key=$k the built library names $u undefined name(s) (ldd -r $b/libxpce.so) FAIL"; return 1; }
    mkdir -p "$s" && cp "$b/libxpce.so" "$s/libxpce.so" && cp "$b/config.h" "$s/config.h" || refuse "cannot stage into $s"
    exports_of "$s/libxpce.so" > "$s/EXPORTS.txt"
    {   printf 'key\t%s\n' "$k"; printf 'sha256\t%s\n' "$(sha256sum "$s/libxpce.so" | cut -d' ' -f1)"
        printf 'built\t%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"; printf 'seat\t%s\n' "$seat"; printf 'seconds\t%s\n' "$(( $(date +%s) - t0 ))"
        printf 'gcc\t%s\n' "$(gcc --version | head -1)"; printf 'cmake\t%s\n' "$(cmake --version | head -1)"
        printf 'tree\t%s\n' "$TREE"; printf 'streams\t%s\n' "$STREAMS"; printf 'exports\t%s\n' "$(wc -l < "$s/EXPORTS.txt")"
    } > "$s/BUILDINFO.tsv"
    mv -T "$s" "$TOP/$k" 2>/dev/null || { rm -rf "$s"; [ -s "$TOP/$k/libxpce.so" ] || refuse "cannot rename the staged library into $TOP/$k"; }
    set_current "$k"
    rm -rf "$b" "$SCRATCH/xpce-kernel-build.$k.$$.log"
    board "key=$k built in $(( $(date +%s) - t0 )) s and renamed into $TOP/$k (sha256 $(sed -n 's/^sha256\t//p' "$TOP/$k/BUILDINFO.tsv" | cut -c1-16), exports $(sed -n 's/^exports\t//p' "$TOP/$k/BUILDINFO.tsv")); CURRENT names it OK"
}
standing() {   # sets K and LIB, or prints the board line and returns 1
    [ -s "$TOP/CURRENT" ] || { board "no kernel library stands: $TOP/CURRENT is absent (run: util_xpce_kernel_build.sh build) FAIL"; return 1; }
    K="$(head -1 "$TOP/CURRENT" | tr -d '[:space:]')"; LIB="$TOP/$K/libxpce.so"
    [ -s "$LIB" ] && [ -f "$TOP/$K/BUILDINFO.tsv" ] || { board "CURRENT names $K and $TOP/$K holds no library with its BUILDINFO.tsv (run build) FAIL"; return 1; }
}
do_check() {
    need; local deep="${1:-}" now sha want u d b
    standing || return 1
    now="$(key)"
    [ "$K" = "$now" ] || { board "STALE: CURRENT names $K and today's tree, recipe and compiler make $now (run build) FAIL"; return 1; }
    sha="$(sha256sum "$LIB" | cut -d' ' -f1)"; want="$(sed -n 's/^sha256\t//p' "$TOP/$K/BUILDINFO.tsv")"
    [ "$sha" = "$want" ] || { board "key=$K the library's sha256 ${sha:0:16} is not the ${want:0:16} its build recorded FAIL"; return 1; }
    u="$(undefined_of "$LIB")"
    [ "$u" = 0 ] || { board "key=$K the library names $u undefined name(s) (ldd -r) FAIL"; return 1; }
    d="$(diff <(exports_of "$LIB") <(LC_ALL=C sort -u "$RECIPE/EXPORTS.txt") | grep -c '^[<>]' || true)"
    [ "$d" = 0 ] || { diff <(exports_of "$LIB") <(LC_ALL=C sort -u "$RECIPE/EXPORTS.txt") | grep '^[<>]' | head -6; board "key=$K the library's exports differ from $RECIPE/EXPORTS.txt in $d name(s) (< the library, > the list) FAIL"; return 1; }
    if [ "$deep" = --deep ]; then
        mkdir -p "$SCRATCH"; b="$SCRATCH/xpce-kernel-deep.$K.$$"; rm -rf "$b"
        make_into "$b" "$b.log" || { board "key=$K the second build failed (log $b.log) FAIL"; return 1; }
        cmp -s "$b/libxpce.so" "$LIB" || { board "key=$K a second build differs from the standing library byte for byte (kept $b) FAIL"; return 1; }
        rm -rf "$b" "$b.log"
        board "key=$K sha256=${sha:0:16} exports=$(wc -l < "$RECIPE/EXPORTS.txt") undefined=0 a second build byte-equal CHECK OK"; return 0
    fi
    board "key=$K sha256=${sha:0:16} exports=$(wc -l < "$RECIPE/EXPORTS.txt") undefined=0 CHECK OK"
}
do_hello() {
    need; local t form arg ref i got n=0
    for t in xpce_k_hello.c xpce_k_hello.screen xpce_k_box.screen; do [ -f "$RECIPE/$t" ] || refuse "the witness file $RECIPE/$t is absent"; done
    [ -f "$S4E_HARNESS/scripts/util_screen_run.py" ] || refuse "the screen road $S4E_HARNESS/scripts/util_screen_run.py is absent"
    standing || return 1
    mkdir -p "$SCRATCH" "$TOP/appdata-empty"; t="$(mktemp -d "$SCRATCH/xpce-hello.XXXXXX")" || refuse "cannot make a scratch folder"
    gcc -O1 -o "$t/xpce_k_hello" "$RECIPE/xpce_k_hello.c" -I"$TREE/src" -L"$TOP/$K" -lxpce -Wl,-rpath,"$TOP/$K" > "$t/link.log" 2>&1 \
        || { tail -3 "$t/link.log"; board "key=$K the witness does not link against the library alone (log $t/link.log) HELLO FAIL"; return 1; }
    if ldd "$t/xpce_k_hello" | grep -q swipl; then board "key=$K the witness names libswipl (ldd) HELLO FAIL"; rm -rf "$t"; return 1; fi
    for form in "text xpce_k_hello.screen" "- xpce_k_box.screen"; do
        arg="${form%% *}"; ref="${form#* }"; [ "$arg" = - ] && arg=""
        for i in 1 2; do
            XPCE_HOME_DIR="$TREE" XPCE_APPDATA_DIR="$TOP/appdata-empty" python3 "$S4E_HARNESS/scripts/util_screen_run.py" --out "$t/got" -- "$t/xpce_k_hello" $arg < /dev/null > "$t/road.log" 2>&1 \
                || { tail -2 "$t/road.log"; rm -rf "$t"; refuse "the screen road could not measure the witness (${arg:-no argument}, run $i)"; }
            got="$(cat "$t/got")"
            [ "$got" = "$(cat "$RECIPE/$ref")" ] || { board "key=$K the witness with ${arg:-no argument}, run $i, reads '$got' and the oracle's cut $ref reads '$(cat "$RECIPE/$ref")' HELLO FAIL"; rm -rf "$t"; return 1; }
            n=$((n + 1))
        done
    done
    rm -rf "$t"
    board "key=$K the witness on the library alone paints the oracle's two pictures, $n of $n runs HELLO OK"
}
case "${1:-}" in
    key) need; key ;;
    build) do_build ;;
    check) do_check "${2:-}" ;;
    hello) do_hello ;;
    *) refuse "usage: util_xpce_kernel_build.sh key | build | check [--deep] | hello" ;;
esac
