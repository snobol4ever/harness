#!/usr/bin/env bash
# test_gate_no_implicit_declarations.sh -- THE TREE BUILDS WITH ALL WARNINGS OFF, SO THE COMPILER CANNOT TELL US A POINTER WAS TRUNCATED.
# ⛔ THE MEASURED DEFECT (ceo 2026-09-18, found while sweeping the four C allocator names): src/parsers/prolog/prolog_driver.c called
# lp_s_expr with NO PROTOTYPE IN SCOPE, so an implicit int-returning declaration TRUNCATED THE RETURNED tree_t* TO 32 BITS. It was
# invisible for as long as it has existed because libc's brk heap sits below 4 GiB -- and it became FATAL on the first Prolog compile
# the moment the compile-time arena moved to mmap at 0x7ffff. Makefile line 46 is WARN := -w, and it flows into CBASE, CXXRT and all
# four runtime object rules, so no compiler in this tree has ever said a word about it.
# ⛔ WHY THIS IS A GATE AND NOT A TIDY-UP (cfo 2026-09-18): the eradication of malloc/calloc/realloc/free converts ~1880 call sites to
# NEW functions (ct_alloc, rt_ws_alloc, the mmap wrappers). Every converted file that lacks the declaring header gets exactly the
# prolog_driver.c bug, and both the arena AND the collected heap now live high, so the truncation is fatal rather than latent. This
# gate is the one free instrument that grades that landing, and it costs no build.
# HOW IT MEASURES: `make -n -B` hands over the REAL per-file compile command (the union of every -I is NOT faithful -- it picks up the
# wrong headers and both invents and masks findings; measured 210 spurious errors that way). Each C command is replayed with -w swapped
# for the three truncating warning classes and with -c/-o/-MMD/-MP stripped for -fsyntax-only, so the gate writes NO object and NO .d
# sidecar and cannot disturb another seat's in-flight build.
# SCOPE, NOT A COUNT RATCHET: ../harness/scripts/implicit_decl_scope.txt lists the directories that must read zero. Everything else is measured and
# PRINTED WITH ITS OWNER but cannot fail the run -- a scope ratchet cannot go stale the way a count baseline does.
# ⛔ REFUSES rc=2 RATHER THAN PASSING VACUOUSLY: if make -n fails, if fewer than 80 C translation units are found, or if any replayed
# unit reports an error: (which would mean the replay is not faithful and its silence proves nothing).
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }; cd "$ROOT" || exit 2
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
WFLAGS="-Wimplicit-function-declaration -Wint-conversion -Wincompatible-pointer-types"
TU_FLOOR=80
if ! timeout -k 5 180 make -n -B > "$W/cmds.raw" 2>"$W/make.err"; then echo "REFUSES rc=2: make -n -B failed -- cannot obtain the real compile commands ($(tail -1 "$W/make.err"))"; exit 2; fi
grep -E '^[[:space:]]*gcc ' "$W/cmds.raw" > "$W/cmds.txt" || true
: > "$W/diag.txt"; tus=0
while IFS= read -r line; do
    src=$(printf '%s\n' "$line" | tr ' ' '\n' | grep -E '\.c$' | head -1)
    [ -n "$src" ] || continue
    tus=$((tus + 1))
    cmd=$(printf '%s' "$line" | sed -e "s/ -w / $WFLAGS /" -e 's/ -MMD -MP//' -e 's/ -c / /' -e 's/ -o [^ ]*//')
    eval "$cmd -fsyntax-only" 2>&1 | grep -E 'warning:|error:' | sed "s|^|${src#$ROOT/}\t|" >> "$W/diag.txt"
done < "$W/cmds.txt"
if [ "$tus" -lt "$TU_FLOOR" ]; then echo "REFUSES rc=2: only $tus C translation units measured, floor is $TU_FLOOR -- a census this small is not measuring the tree"; exit 2; fi
if grep -q 'error:' "$W/diag.txt"; then echo "REFUSES rc=2: a replayed translation unit reported error: -- the replay is not faithful, so its silence proves nothing"; grep -m3 'error:' "$W/diag.txt"; exit 2; fi
grep -E 'implicit-function-declaration|int-conversion|incompatible-pointer-types' "$W/diag.txt" > "$W/hits.txt" || true
echo "  measured $tus C translation units, $(wc -l < "$W/hits.txt") site(s) in the three truncating classes"
grep -vE '^[[:space:]]*#' ../harness/scripts/implicit_decl_scope.txt | grep -vE '^[[:space:]]*$' > "$W/scope.txt" || true
[ -s "$W/scope.txt" ] || { echo "REFUSES rc=2: ../harness/scripts/implicit_decl_scope.txt grades no directory -- a gate with an empty scope passes vacuously"; exit 2; }
bad=0
while IFS= read -r pfx; do
    n=$(awk -F'\t' -v p="$pfx" 'index($1, p) == 1' "$W/hits.txt" | wc -l)
    if [ "$n" -eq 0 ]; then echo "  GRADED $pfx PASS: 0 implicit declarations, 0 int<->pointer conversions, 0 incompatible pointer assignments"
    else echo "  GRADED $pfx RED: $n site(s) the compiler cannot check"; awk -F'\t' -v p="$pfx" 'index($1, p) == 1 {print "      " $2}' "$W/hits.txt" | head -20; bad=1; fi
done < "$W/scope.txt"
awk -F'\t' '{split($1, a, "/"); print a[1] "/" a[2] "/"}' "$W/hits.txt" | sort | uniq -c | sort -rn > "$W/bydir.txt" || true
while read -r n d; do
    grep -qxF "$d" "$W/scope.txt" && continue
    echo "  REPORTED $d: $n site(s) -- not graded, no seat has claimed this directory cured"
done < "$W/bydir.txt"
grep 'implicit declaration of function' "$W/hits.txt" | sed -E 's/^([^\t]+)\t.*implicit declaration of function .([A-Za-z_0-9]+).*/\1\t\2/' | sort -u > "$W/fns.txt" || true
while IFS=$'\t' read -r f fn; do
    [ -n "${fn:-}" ] || continue
    if grep -rhoE "^[A-Za-z_][A-Za-z_0-9 ]*\*+[[:space:]]*$fn[[:space:]]*\(" src/ --include=*.c --include=*.h 2>/dev/null | head -1 | grep -q . \
       || printf '%s\n' memchr memcpy memset memmove strchr strrchr strstr strpbrk strtok strdup strndup | grep -qx "$fn"; then
        msg="  ⛔ TRUNCATING: $f calls $fn with no prototype and $fn RETURNS A POINTER -- its high 32 bits are discarded"
        if awk -F'\t' -v p="$f" 'index(p, $0) == 1' "$W/scope.txt" | grep -q .; then echo "$msg [GRADED]"; bad=1; else echo "$msg [REPORTED -- this directory is not in the graded scope]"; fi
    fi
done < "$W/fns.txt"
if [ "$bad" -ne 0 ]; then echo "GATE FAIL(1) [no_implicit_declarations]: a graded directory calls a function the compiler has never seen declared"; exit 1; fi
echo "GATE PASS(0) [no_implicit_declarations]: every graded directory is clean over $tus translation units"
