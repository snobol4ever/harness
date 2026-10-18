#!/usr/bin/env bash
# test_gate_the_runtime_binds_its_own_functions_and_keeps_its_data_and_instrument_entries_interposable.sh
#
# THE ROW (startup-the-runtime-binds-its-own-symbols-once-the-compiler-carries-no-copy-relocation-hello-under-1-6m-ir-ceo-1795, cto 2026-10-15): a one-process
# program spent most of its startup in ld.so resolving the runtime's references to its OWN symbols (3,721 JUMP_SLOT, 656 GLOB_DAT, 600 R_X86_64_64; a mode-4 Icon hello
# 2,535,562 Ir). RT_BIND in the Makefile links the runtime with --dynamic-list-data --dynamic-list=src/runtime/rt_interposable.list -z pack-relative-relocs: every
# FUNCTION binds inside the library except the ones an instrument interposes by name, every DATUM stays interposable, the relative relocations are packed (hello
# 1,710,925 Ir). The three hazards CEO-1501 kept the flag off for are held here, each by its own arm:
#   1. the functions bind inside: the runtime's JUMP_SLOT relocations are under 400 (3,721 before);
#   2. the data do not: rtccb and g_gc_pending, which every mode-4 program reads rip-relatively and so COPIES, keep a dynamic relocation in the runtime, so the library
#      reads the executable's copy (bound locally the library reads its own and the program the other: split state, full -Bsymbolic's defect);
#   3. every name in rt_interposable.list is an exported symbol the runtime still reaches through a dynamic relocation;
#   4. pointer identity: no executable SCRIP builds or emits carries a canonical-PLT function (an undefined FUNC with an address), the only road by which an
#      executable holds a runtime function's address the library does not -- ./scrip, out/scrip-ipp, out/parser_*, and a mode-4 hello linked -pie and -no-pie;
#   5. ./scrip carries no R_X86_64_COPY (the driver is compiled -fPIC; 34 before);
#   6. the phase profiler's road: a preloaded rt_time_ns counts both TIME() calls of a SNOBOL4 program in mode 3 and in mode 4;
#   7. the parser tools' road: out/parser_icon under PARSER_LEX_CLOCK=1 counts its lexer calls.
#   8. THE DATA BIND INSIDE TOO (cto 2026-10-17, row startup-an-empty-mode-4-program-costs-...): --dynamic-list-data is gone, so a datum stays
#      interposable only by name in rt_interposable.list; every R_X86_64_COPY in every executable above (libc's stdin, stdout and stderr aside)
#      names a symbol in that list, or that executable writes a copy the runtime never reads. Measured at the landing: rtccb (mode 4, scrip-ipp),
#      sno_nerrors and rebus_nerrors (the parser tools); the runtime's GLOB_DAT relocations 252 -> 73, an empty mode-4 program 863,359 -> 756,573 Ir; with the C++ objects built -fno-gnu-unique (an inline function's static no longer a GNU-unique symbol, SCRIP d2e301195) 73 -> 25 and 715,103 Ir.
# FAIL-ONCE: arms 1 and 5 read red on the parent of the landing (3,721 and 34); arm 8 reads red on the parent of the data landing (the
# parser tools' sno_nerrors and rebus_nerrors were in no list). Arms 6 and 7 read 0 against a runtime linked with plain -Bsymbolic-functions (no
# list), measured at the landing: TSHIM 0 in both modes, lex_calls=0, where this link reads 2, 2 and 1,449.
# rc=0 clean · rc=1 a hazard present · rc=2 REFUSAL.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
B="$(cd "$HERE/../../SCRIP" && pwd)"
SO="$B/out/libscrip_rt.so"
LIST="$B/src/runtime/rt_interposable.list"
refuse() { echo "⛔ REFUSES rc=2: $*"; exit 2; }
[ -x "$B/scrip" ] || refuse "$B/scrip is not built -- cannot measure"
[ -f "$SO" ] || refuse "out/libscrip_rt.so is not built"
[ -f "$LIST" ] || refuse "$LIST is absent"
command -v readelf > /dev/null || refuse "readelf is absent"
"$HERE/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
D="$(mktemp -d)" || refuse "no scratch dir"
trap 'rm -rf "$D"' EXIT
red=0
say() { echo "$1"; case "$1" in RED*) red=1;; esac; }
readelf -rW "$SO" > "$D/rel.txt" || refuse "readelf -r failed on $SO"
js=$(grep -c 'R_X86_64_JUMP_SLOT' "$D/rel.txt")
[ "$js" -lt 400 ] && say "GREEN arm 1: the runtime's JUMP_SLOT relocations read $js (under 400)" || say "RED   arm 1: the runtime's JUMP_SLOT relocations read $js -- its functions are not bound inside it"
for s in rtccb g_gc_pending; do
    n=$(awk -v s="$s" '$5 == s || $5 ~ "^"s"[+@]"' "$D/rel.txt" | wc -l)
    [ "$n" -ge 1 ] && say "GREEN arm 2: the runtime reaches $s through $n dynamic relocation(s)" || say "RED   arm 2: the runtime binds $s to its own copy -- a mode-4 program's copy relocation splits it"
done
nm -D --defined-only "$SO" | awk '{ print $3 }' | sort -u > "$D/funcs.txt"
names=$(tr -d '{};' < "$LIST" | tr -s ' \n' '\n' | grep -v '^$')
[ -n "$names" ] || refuse "$LIST names no function"
for s in $names; do
    grep -qx "$s" "$D/funcs.txt" || { say "RED   arm 3: $s is in the list but the runtime exports no symbol of that name"; continue; }
    n=$(awk -v s="$s" '$5 == s || $5 ~ "^"s"[+@]"' "$D/rel.txt" | wc -l)
    [ "$n" -ge 1 ] && say "GREEN arm 3: $s stays interposable ($n dynamic relocation(s))" || say "RED   arm 3: $s is bound inside the runtime -- the instrument that interposes it reads nothing"
done
printf 'procedure main()\n   write("hi");\nend\n' > "$D/h.icn"
"$B/scrip" --compile -o "$D/h.s" "$D/h.icn" < /dev/null > /dev/null 2>&1 || refuse "the hello did not compile"
gcc "$D/h.s" -L"$B/out" -lscrip_rt -lm -lpthread -Wl,-rpath,"$B/out" -o "$D/h.pie" 2> /dev/null || refuse "the hello did not link -pie"
gcc -no-pie "$D/h.s" -L"$B/out" -lscrip_rt -lm -lpthread -Wl,-rpath,"$B/out" -o "$D/h.nopie" 2> /dev/null || refuse "the hello did not link -no-pie"
[ "$("$D/h.pie" < /dev/null)" = hi ] || refuse "the -pie hello did not print hi"
for x in "$B/scrip" "$B/out/scrip-ipp" "$B"/out/parser_* "$D/h.pie" "$D/h.nopie"; do
    [ -x "$x" ] || continue
    c=$(readelf --dyn-syms -W "$x" | awk '$4 == "FUNC" && $7 == "UND" && $2 !~ /^0+$/ { print $8 }' | sort -u)
    [ -z "$c" ] && say "GREEN arm 4: $(basename "$x") holds no canonical-PLT function" || say "RED   arm 4: $(basename "$x") holds a canonical-PLT address for: $(echo $c | head -c 300)"
done
for x in "$B/scrip" "$B/out/scrip-ipp" "$B"/out/parser_* "$D/h.pie" "$D/h.nopie"; do
    [ -x "$x" ] || continue
    bad=""
    for s in $(readelf -rW "$x" | awk '/R_X86_64_COPY/ { print $5 }' | sed 's/@.*//' | sort -u); do
        case "$s" in stdin|stdout|stderr) continue;; esac
        printf '%s\n' $names | grep -qx "$s" || bad="$bad $s"
    done
    [ -z "$bad" ] && say "GREEN arm 8: $(basename "$x") copies no runtime datum outside rt_interposable.list" || say "RED   arm 8: $(basename "$x") copies$bad, which the runtime binds inside itself -- split state"
done
cp=$(readelf -rW "$B/scrip" | grep -c 'R_X86_64_COPY')
[ "$cp" -eq 0 ] && say "GREEN arm 5: ./scrip carries no copy relocation" || say "RED   arm 5: ./scrip carries $cp copy relocation(s)"
cat > "$D/tshim.c" <<'EOF'
#define _GNU_SOURCE
#include <dlfcn.h>
#include <stdint.h>
#include <stdio.h>
static int64_t (*real_t)(void);
static long n;
int64_t rt_time_ns(void) { if (!real_t) real_t = (int64_t (*)(void))dlsym(RTLD_NEXT, "rt_time_ns"); n++; return real_t(); }
__attribute__((destructor)) static void rep(void) { fprintf(stderr, "TSHIM %ld\n", n); }
EOF
gcc -shared -fPIC -o "$D/tshim.so" "$D/tshim.c" -ldl 2> /dev/null || refuse "the rt_time_ns shim did not build"
printf "\tT1 = TIME()\n\tT2 = TIME()\n\tOUTPUT = 'ok'\nEND\n" > "$D/t.sno"
"$B/scrip" --compile -o "$D/t.s" "$D/t.sno" < /dev/null > /dev/null 2>&1 || refuse "the TIME() witness did not compile"
gcc "$D/t.s" -L"$B/out" -lscrip_rt -lm -lpthread -Wl,-rpath,"$B/out" -o "$D/t.m4" 2> /dev/null || refuse "the TIME() witness did not link"
m3=$(cd "$D" && LD_PRELOAD="$D/tshim.so" timeout -k 5 30 "$B/scrip" t.sno < /dev/null 2>&1 | sed -n 's/^TSHIM //p')
m4=$(cd "$D" && LD_PRELOAD="$D/tshim.so" timeout -k 5 30 ./t.m4 < /dev/null 2>&1 | sed -n 's/^TSHIM //p')
[ -n "$m3" ] && [ -n "$m4" ] || refuse "the shim reported nothing (m3 '$m3', m4 '$m4') -- the witness did not run"
[ "$m3" = 2 ] && [ "$m4" = 2 ] && say "GREEN arm 6: a preloaded rt_time_ns sees both TIME() calls in mode 3 ($m3) and mode 4 ($m4)" || say "RED   arm 6: a preloaded rt_time_ns sees $m3 (mode 3) and $m4 (mode 4) of 2 TIME() calls"
make -s -C "$B" out/parser_icon > "$D/mk.txt" 2>&1 || refuse "out/parser_icon did not build ($(tail -1 "$D/mk.txt"))"
printf 'procedure main()\n   every write(1 to 3);\nend\n' > "$D/p.icn"
echo "$D/p.icn" > "$D/files.txt"
PARSER_FILES="$D/files.txt" PARSER_LEX_CLOCK=1 timeout -k 5 30 "$B/out/parser_icon" > /dev/null 2> "$D/pm.txt"
lc=$(sed -n 's/.*lex_calls=\([0-9]*\).*/\1/p' "$D/pm.txt")
[ -n "$lc" ] || refuse "out/parser_icon printed no lex_calls ($(head -c 200 "$D/pm.txt"))"
[ "$lc" -gt 0 ] && say "GREEN arm 7: out/parser_icon's lexer clock counts $lc lexer calls" || say "RED   arm 7: out/parser_icon's lexer clock counts 0 lexer calls -- icn_lex_next is bound inside the runtime"
[ "$red" -eq 0 ] && { echo "GATE GREEN"; exit 0; }
echo "GATE RED"
exit 1
