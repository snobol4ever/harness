#!/usr/bin/env bash
# util_unicon_xwin_build.sh key | build | check -- THE UNICON WINDOW OBJECT, ONCE FOR THE BOX (step U4 of designs/unicon_graphics, the cqo's ruling 2026-11-16 20:2x CST, skill unicon section 8 U4; officer_09).
# Unicon's window kernel, translated raw from the user's own checkout and linked with the hand-written shim and arena of designs/icon_xwin/unicon by
# util_gen_icon_xwin_device.py --dialect unicon --shim-check ROOT --object DIR, is ONE shared object with the interface's soname, libscrip_xwin.so. It stands
# outside every root, at /home/resources/unicon-xwin/object/KEY/libscrip_xwin.so; the one-line text file /home/resources/unicon-xwin/object/CURRENT names the
# key (a file, never a link). No SCRIP make builds it: SCRIP's Makefile copies it to out/libscrip_xwin_unicon.so while CURRENT stands, as it names XPCE's kernel.
#   key     prints KEY: the first 16 hex digits of the sha256 over the Unicon checkout's revision (git HEAD and its tracked edits), the generator, every file of
#           designs/icon_xwin/unicon, the SCRIP interface files the object compiles against (src/runtime/xwin_interface.tsv and its contract
#           xwin_interface_contract.tsv, src/ir/descr.h, src/ir/descr_tags_dt_platom.h, src/ir/pin_va.h of the SCRIP root S4E_SCRIP) and the first line of gcc --version. Names are hashed relative.
#   build   builds only when KEY's folder is absent: the generator's --shim-check in scratch (its object loaded beside the root's libscrip_rt.so, every export
#           of the interface there, the forms equal), the object staged beside its place and renamed into it, so no seat reads a half-built object; then
#           CURRENT is rewritten by rename. A SHIM FAIL installs nothing. One builder at a time (a lock file in the top folder). About 13 minutes under load.
#   check   the standing object is the one today's checkout, generator, designs, interface and compiler make: CURRENT's key is today's key, the object's sha256
#           is the one its build recorded, its soname is libscrip_xwin.so, and it defines every name the interface's export rows name.
# rc 0 done or green; rc 1 a measured red (no object stands, stale, differs, the build failed); rc 2 REFUSE: usage, a tree or a tool missing.
# One board line a verb: UNICON_XWIN_BOARD ... ending OK or FAIL. The folders can be named for a test: S4E_UNICON_XWIN (the top), S4E_UNICON_XWIN_SRC (the checkout's src).
set -u
. "${S4E_HARNESS:-/home/harness}/scripts/lib_paths.sh" || { echo "REFUSE(2): lib_paths.sh did not load"; exit 2; }
GEN="$S4E_HARNESS/scripts/util_gen_icon_xwin_device.py"
DESIGN="$S4E_HARNESS/designs/icon_xwin/unicon"
TOP="${S4E_UNICON_XWIN:-/home/resources/unicon-xwin/object}"
ROOT="${S4E_SCRIP:-}"
seat="${S4E_SEAT:-$(id -un)}"
SCRATCH="/tmp/s4e/$seat"
IFACE_FILES="src/runtime/xwin_interface.tsv src/runtime/xwin_interface_contract.tsv src/ir/descr.h src/ir/descr_tags_dt_platom.h src/ir/pin_va.h"
refuse() { echo "REFUSE(2): $*"; exit 2; }
board() { echo "UNICON_XWIN_BOARD $*"; }
need() {
    local f t
    for t in gcc git sha256sum nm readelf python3 flock; do command -v "$t" > /dev/null || refuse "no $t on this box"; done
    [ -f "$GEN" ] || refuse "the generator $GEN is absent"
    [ -f "$DESIGN/DIALECT.tsv" ] || refuse "the dialect $DESIGN/DIALECT.tsv is absent"
    SRC="${S4E_UNICON_XWIN_SRC:-$(sed -n 's/^src\t//p' "$DESIGN/DIALECT.tsv" | head -1)}"
    [ -n "$SRC" ] && [ -d "$SRC/runtime" ] && [ -d "$SRC/h" ] || refuse "no Unicon checkout src at '$SRC' (runtime and h)"
    [ -n "$ROOT" ] && [ -d "$ROOT/src" ] || refuse "no SCRIP root (S4E_SCRIP='$ROOT')"
    for f in $IFACE_FILES; do [ -f "$ROOT/$f" ] || refuse "the SCRIP root lacks $f"; done
}
key() {
    {   gcc --version | head -1
        git -C "$SRC" rev-parse HEAD 2>/dev/null || echo unversioned
        git -C "$SRC" diff HEAD 2>/dev/null | sha256sum
        ( cd "$(dirname "$GEN")" && sha256sum "$(basename "$GEN")" )
        ( cd "$DESIGN" && find . -type f -print0 | LC_ALL=C sort -z | xargs -0 sha256sum )
        ( cd "$ROOT" && sha256sum $IFACE_FILES )
    } | sha256sum | cut -c1-16
}
iface_exports() { awk -F'\t' '!/^#/ && $1 == "export" {print $2}' "$ROOT/src/runtime/xwin_interface.tsv" | LC_ALL=C sort -u; }
defined_of() { nm -D --defined-only "$1" | awk '{print $NF}' | sed 's/@.*//' | LC_ALL=C sort -u; }
soname_of() { readelf -d "$1" | sed -n 's/.*(SONAME).*\[\(.*\)\].*/\1/p'; }
set_current() { printf '%s\n' "$1" > "$TOP/.CURRENT.$$" && mv -f "$TOP/.CURRENT.$$" "$TOP/CURRENT"; }
do_build() {
    need; local k w s t0 log rc
    [ -f "$ROOT/out/libscrip_rt.so" ] || refuse "the SCRIP root $ROOT is not built (no out/libscrip_rt.so; run make there)"
    k="$(key)"; [ -n "$k" ] || refuse "no key could be computed"
    mkdir -p "$TOP" "$SCRATCH" || refuse "cannot make $TOP or $SCRATCH"
    exec 6> "$TOP/.build.lock" || refuse "cannot open the build lock in $TOP"
    flock -w 3600 6 || refuse "another build has held $TOP/.build.lock for 3600 s"
    if [ -s "$TOP/$k/libscrip_xwin.so" ]; then
        [ "$(cat "$TOP/CURRENT" 2>/dev/null)" = "$k" ] || set_current "$k"
        board "key=$k the object stands already at $TOP/$k/libscrip_xwin.so, nothing built; CURRENT names it OK"; return 0
    fi
    w="$SCRATCH/unicon-xwin-build.$k.$$"; s="$TOP/.stage.$k.$$"; log="$w.log"; t0="$(date +%s)"
    rm -rf "$w" "$s"; mkdir -p "$w"
    python3 -I "$GEN" --dialect unicon --src "$SRC" --shim-check "$ROOT" --object "$w" > "$log" 2>&1 < /dev/null; rc=$?
    [ "$rc" = 2 ] && { tail -3 "$log"; refuse "the generator refused (log $log)"; }
    [ "$rc" = 0 ] && grep -q '^SHIM OK' "$log" || { grep -E '^SHIM (RED|FAIL)' "$log" | head -8; board "key=$k the shim check read rc=$rc (log $log, tree kept $w) FAIL"; return 1; }
    [ -s "$w/libscrip_xwin.so" ] || { board "key=$k the generator left no libscrip_xwin.so in $w FAIL"; return 1; }
    mkdir -p "$s" && cp "$w/libscrip_xwin.so" "$s/libscrip_xwin.so" && cp "$log" "$s/BUILD.log" || refuse "cannot stage into $s"
    {   printf 'key\t%s\n' "$k"; printf 'sha256\t%s\n' "$(sha256sum "$s/libscrip_xwin.so" | cut -d' ' -f1)"
        printf 'built\t%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"; printf 'seat\t%s\n' "$seat"; printf 'seconds\t%s\n' "$(( $(date +%s) - t0 ))"
        printf 'gcc\t%s\n' "$(gcc --version | head -1)"; printf 'unicon\t%s %s\n' "$SRC" "$(git -C "$SRC" rev-parse HEAD 2>/dev/null || echo unversioned)"
        printf 'scrip\t%s %s\n' "$ROOT" "$(git -C "$ROOT" rev-parse HEAD 2>/dev/null || echo unversioned)"; printf 'harness\t%s\n' "$(git -C "$S4E_HARNESS" rev-parse HEAD 2>/dev/null || echo unversioned)"
        printf 'soname\t%s\n' "$(soname_of "$s/libscrip_xwin.so")"
    } > "$s/BUILDINFO.tsv"
    mv -T "$s" "$TOP/$k" 2>/dev/null || { rm -rf "$s"; [ -s "$TOP/$k/libscrip_xwin.so" ] || refuse "cannot rename the staged object into $TOP/$k"; }
    set_current "$k"
    rm -rf "$w" "$log"
    board "key=$k built in $(( $(date +%s) - t0 )) s and renamed into $TOP/$k (sha256 $(sed -n 's/^sha256\t//p' "$TOP/$k/BUILDINFO.tsv" | cut -c1-16), SHIM OK); CURRENT names it OK"
}
do_check() {
    need; local K LIB now sha want so miss
    [ -s "$TOP/CURRENT" ] || { board "no Unicon window object stands: $TOP/CURRENT is absent (run: util_unicon_xwin_build.sh build) FAIL"; return 1; }
    K="$(head -1 "$TOP/CURRENT" | tr -d '[:space:]')"; LIB="$TOP/$K/libscrip_xwin.so"
    [ -s "$LIB" ] && [ -f "$TOP/$K/BUILDINFO.tsv" ] || { board "CURRENT names $K and $TOP/$K holds no object with its BUILDINFO.tsv (run build) FAIL"; return 1; }
    now="$(key)"
    [ "$K" = "$now" ] || { board "STALE: CURRENT names $K and today's checkout, generator, designs, interface and compiler make $now (run build) FAIL"; return 1; }
    sha="$(sha256sum "$LIB" | cut -d' ' -f1)"; want="$(sed -n 's/^sha256\t//p' "$TOP/$K/BUILDINFO.tsv")"
    [ "$sha" = "$want" ] || { board "key=$K the object's sha256 ${sha:0:16} is not the ${want:0:16} its build recorded FAIL"; return 1; }
    so="$(soname_of "$LIB")"
    [ "$so" = libscrip_xwin.so ] || { board "key=$K the object's soname is '$so', not the interface's libscrip_xwin.so FAIL"; return 1; }
    miss="$(LC_ALL=C comm -23 <(iface_exports) <(defined_of "$LIB") | tr '\n' ' ')"
    [ -z "$miss" ] || { board "key=$K the interface exports names the object does not define: $miss FAIL"; return 1; }
    board "key=$K sha256=${sha:0:16} soname=libscrip_xwin.so exports=$(iface_exports | wc -l) of the interface CHECK OK"
}
case "${1:-}" in
    key) need; key ;;
    build) do_build ;;
    check) do_check ;;
    *) refuse "usage: util_unicon_xwin_build.sh key | build | check" ;;
esac
