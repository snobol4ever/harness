#!/usr/bin/env bash
# test_gate_no_header_reaches_more_units_than_its_users.sh -- NO HEADER REACHES MORE UNITS THAN ITS USERS (ARCH-HEADER-SPLIT.md sections 1 and 2, CEO-2032, step 1a;
# Lon 2026-10-30, in-chat to the ceo: "I want the header files designed properly NOT to cause total re-builds.").
#
# ARM 1  fan-in: no header is over the R4 ceiling (fanin <= users + 4, and <= one third of the units outside the base set) that was not over it in
#        header_fanin.baseline.tsv, and no over-ceiling header's fanin has risen above its baseline figure. A set of names, never a count.
# ARM 2  umbrella: no header with two or more includes and no declaration of its own that the baseline does not already hold.
# ARM 3  inline: no header outside the base set and header_inline_allowed.tsv holds more multi-statement inline bodies than its baseline figure (R3).
# ARM 4  path: no unit or header writes a bare-name include of a header in another directory more often than its baseline figure (R2).
# ARM 5  unused: no unit carries more direct includes none of whose declarations it names than its baseline figure (R2).
# ARM 6  (control) the instrument CAN fail: a fixture tree built from hand-written .d files reads exactly the over-ceiling header, umbrella, unused include,
#        bare include and long inline body that were put in it, and a clean fixture reads none (a PROPER test: no seam in SCRIP's own code, CEO-1680).
# ARM 7  (control) the baseline is lowered and never raised: against a fixture baseline set one figure lower than the fixture, each arm's ratchet names
#        the figure, --write-baseline refuses, and against an equal baseline every arm reads 0.
# ARM 8  (control) util_objects_identical_stripped.sh: identical trees read objects=N identical=N differing=0 rc 0; one object recompiled with a different
#        constant is named DIFF rc 1; an object in one tree only is named ONLY-A rc 1; a build-id directory suffix still pairs.
# DECLARED RULING (reporting) at step 1a, BLOCKING at step 7 when every arm reads 0 (the page). It needs a built tree: fewer than 200 .d files is rc 2.
# rc 0 green · rc 1 red · rc 2 could not measure.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
FAN="$HERE/util_header_fanin.py"
OBJ="$HERE/util_objects_identical_stripped.sh"
command -v python3 >/dev/null && [ -f "$FAN" ] && [ -f "$OBJ" ] || { echo "⛔ REFUSE(2): python3, $FAN or $OBJ is absent"; exit 2; }
[ -f "$HERE/header_fanin.baseline.tsv" ] && [ -f "$HERE/header_base_set.tsv" ] || { echo "⛔ REFUSE(2): the baseline or the base set is absent"; exit 2; }
fan() { python3 -I "$FAN" --root "$ROOT/SCRIP" "$@"; }
fail=0
out="$(fan --ratchet all 2>&1)"; rc=$?
if [ "$rc" = 2 ] || ! printf '%s\n' "$out" | grep -q '^summary over='; then echo "⛔ REFUSE(2): $out" | head -3; exit 2; fi
for arm in "1 fanin fan-in over the ceiling" "2 umbrella umbrella headers" "3 inline long inline bodies" "4 bare bare-name cross-directory includes" "5 unused unused direct includes"; do
    set -- $arm; n="$1"; kind="$2"; shift 2
    last="$(printf '%s\n' "$out" | grep "^arm $kind violations=")"
    if [ "$last" = "arm $kind violations=0" ]; then echo "  ok   ARM $n: $* ($last)"
    else echo "  RED  ARM $n: $* ($last)"; printf '%s\n' "$out" | grep '^RAISED' | grep -F " $kind " | head -8 | cut -c1-200 | sed 's/^/         /'; fail=1; fi
done
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
mk() { mkdir -p "$(dirname "$T/$1")"; cat > "$T/$1"; }
mkd() { local u="$1"; shift; mk "obj/$u.d" <<EOF
$u.o: src/$u.c \\
 $*
EOF
}
build_fixture() {
    mk src/wide.h <<'EOF'
#ifndef WIDE_H
#define WIDE_H
int wide_fn(int);
#endif
EOF
    mk src/tiny.h <<'EOF'
#ifndef TINY_H
#define TINY_H
typedef struct { int v; } tiny_t;
#endif
EOF
    mk src/umb.h <<'EOF'
#ifndef UMB_H
#define UMB_H
#include "wide.h"
#include "tiny.h"
#endif
EOF
    mk src/inl.h <<'EOF'
#ifndef INL_H
#define INL_H
static inline int inl_f(int a) { int b = a; b += 2; return b; }
static inline int inl_g(int a) { return a + 1; }
#endif
EOF
    local i
    for i in 1 2 3 4 5 6 7 8; do
        mk "src/u$i.c" <<EOF
#include "wide.h"
$( [ "$i" = 1 ] && echo 'int u1(void) { return wide_fn(1); }' || echo "int u$i(void) { return $i; }" )
EOF
        mkd "u$i" "src/wide.h"
    done
    mk src/u9.c <<'EOF'
#include "umb.h"
#include "inl.h"
tiny_t u9_v;
int u9(void) { return inl_g(1) + inl_f(2); }
EOF
    mkd u9 src/umb.h src/wide.h src/tiny.h src/inl.h
    mk src/q/q.c <<'EOF'
#include "wide.h"
int q(void) { return wide_fn(2); }
EOF
    mk obj/q.d <<'EOF'
q.o: src/q/q.c \
 src/wide.h
EOF
}
build_fixture
printf '' > "$T/empty_base.tsv"; printf '' > "$T/empty_inline.tsv"
ffan() { python3 -I "$FAN" --root "$T" --obj "$T/obj" --min-units 1 --base-file "$T/empty_base.tsv" --inline-file "$T/empty_inline.tsv" --baseline-file "$T/baseline.tsv" "$@"; }
c="$(ffan --ceiling 2>&1)"
okc=1
printf '%s\n' "$c" | grep -q '^OVER wide.h fanin=10 users=2$' || { okc=0; echo "         no OVER for wide.h fanin=10 users=2"; }
printf '%s\n' "$c" | grep -q '^UMBRELLA umb.h$' || { okc=0; echo "         no UMBRELLA umb.h"; }
printf '%s\n' "$c" | grep -q '^summary over=1 umbrellas=1$' || { okc=0; echo "         summary is not over=1 umbrellas=1: $(printf '%s' "$c" | tail -1)"; }
ffan --unused 2>&1 | grep -q '^u2.c.*wide.h' || { okc=0; echo "         no unused include wide.h for u2.c"; }
ffan --bare 2>&1 | grep -q '^q/q.c.*wide.h' || { okc=0; echo "         no bare include wide.h for q/q.c"; }
ffan 2>&1 | awk -F'\t' '$7 == "inl.h" && $5 == 1 { f = 1 } END { exit !f }' || { okc=0; echo "         inl.h does not read exactly one long inline body"; }
ffan --recompiles tiny.h 2>&1 | grep -q '^recompiles=1 of units=10$' || { okc=0; echo "         --recompiles tiny.h is not 1 of 10"; }
cl="$T/clean"; mkdir -p "$cl/src" "$cl/obj"
for i in 1 2 3; do
    printf '#ifndef A%s_H\n#define A%s_H\nint a%s_fn(void);\n#endif\n' "$i" "$i" "$i" > "$cl/src/a$i.h"; printf '#include "a%s.h"\nint x%s(void) { return a%s_fn(); }\n' "$i" "$i" "$i" > "$cl/src/x$i.c"
    printf 'x%s.o: src/x%s.c \\\n src/a%s.h\n' "$i" "$i" "$i" > "$cl/obj/x$i.d"
done
cc="$(python3 -I "$FAN" --root "$cl" --obj "$cl/obj" --min-units 1 --base-file "$T/empty_base.tsv" --ceiling 2>&1 | tail -1)"
[ "$cc" = "summary over=0 umbrellas=0" ] || { okc=0; echo "         the clean fixture reads: $cc"; }
if [ "$okc" = 1 ]; then echo "  ok   ARM 6: the instrument names the over-ceiling header, umbrella, unused include, bare include and long inline body of a fixture, and reads a clean one clean"
else echo "  RED  ARM 6: the instrument did not read the fixture it was built from"; fail=1; fi
ok7=1
ffan --write-baseline >/dev/null 2>&1 || ok7=0
for a in fanin umbrella inline bare unused; do ffan --ratchet "$a" >/dev/null 2>&1 || { ok7=0; echo "         an equal baseline reds arm $a"; }; done
python3 - "$T/baseline.tsv" <<'EOF'
import sys
p = sys.argv[1]
rows = []
for ln in open(p):
    f = ln.rstrip('\n').split('\t')
    if len(f) == 6 and not ln.startswith('#'):
        if f[0] == 'hdr' and f[1] == 'wide.h':
            f[2], f[5] = '3', '0'
        if f[0] == 'hdr' and f[1] == 'inl.h':
            f[4] = '0'
        if f[0] == 'umbrella':
            continue
        if f[0] in ('bare', 'unused'):
            f[2] = '0'
    rows.append('\t'.join(f))
open(p, 'w').write('\n'.join(rows) + '\n')
EOF
for a in fanin umbrella inline bare unused; do
    if ffan --ratchet "$a" >/dev/null 2>&1; then ok7=0; echo "         a lowered baseline does not red arm $a"; fi
done
ffan --write-baseline >/dev/null 2>&1 && { ok7=0; echo "         --write-baseline did not refuse a raise"; }
if [ "$ok7" = 1 ]; then echo "  ok   ARM 7: an equal baseline reads 0 on every arm, a lowered one reds each arm by name, and --write-baseline refuses a raise"
else echo "  RED  ARM 7: the ratchet does not hold the baseline"; fail=1; fi
ok8=1
A="$T/oa"; B="$T/ob"; mkdir -p "$A/rt_pic-aaaaaaaaaa" "$B/rt_pic-bbbbbbbbbb"
printf 'int f(void) { return 1; }\n' > "$T/f.c"; printf 'int g(void) { return 2; }\n' > "$T/g.c"; printf 'int g(void) { return 3; }\n' > "$T/g2.c"
cc_o() { bash "$HERE/util_cc_slot.sh" gcc -g -c "$1" -o "$2" 2>/dev/null; }
cc_o "$T/f.c" "$A/rt_pic-aaaaaaaaaa/f.o" && cc_o "$T/g.c" "$A/rt_pic-aaaaaaaaaa/g.o" && cc_o "$T/f.c" "$B/rt_pic-bbbbbbbbbb/f.o" && cc_o "$T/g.c" "$B/rt_pic-bbbbbbbbbb/g.o" || ok8=0
r="$(bash "$OBJ" "$A" "$B" 2>&1)"; rc=$?
{ [ "$rc" = 0 ] && [ "$r" = "objects=2 identical=2 differing=0" ]; } || { ok8=0; echo "         identical trees read rc=$rc: $r"; }
cc_o "$T/g2.c" "$B/rt_pic-bbbbbbbbbb/g.o" || ok8=0
r="$(bash "$OBJ" "$A" "$B" 2>&1)"; rc=$?
{ [ "$rc" = 1 ] && printf '%s\n' "$r" | grep -q '^DIFF obj:rt_pic/g.o$' && printf '%s\n' "$r" | tail -1 | grep -q 'differing=1'; } || { ok8=0; echo "         a changed object reads rc=$rc: $r"; }
cc_o "$T/g.c" "$B/rt_pic-bbbbbbbbbb/g.o"; rm -f "$B/rt_pic-bbbbbbbbbb/f.o"
r="$(bash "$OBJ" "$A" "$B" 2>&1)"; rc=$?
{ [ "$rc" = 1 ] && printf '%s\n' "$r" | grep -q '^ONLY-A obj:rt_pic/f.o$'; } || { ok8=0; echo "         a missing object reads rc=$rc: $r"; }
if [ "$ok8" = 1 ]; then echo "  ok   ARM 8: util_objects_identical_stripped.sh passes identical trees, names a changed object and a missing one, and pairs across a build-id suffix"
else echo "  RED  ARM 8: the object comparison is not trustworthy"; fail=1; fi
s="$(printf '%s\n' "$out" | grep '^summary over=')"
if [ "$fail" = 0 ]; then echo "GATE PASS(0) [no_header_reaches_more_units_than_its_users]: 8 arm(s) -- $s"; exit 0; fi
echo "GATE FAIL(1) [no_header_reaches_more_units_than_its_users]: $s"; exit 1
