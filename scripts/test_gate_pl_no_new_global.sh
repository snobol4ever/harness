#!/usr/bin/env bash
# ../harness/scripts/test_gate_pl_no_new_global.sh -- no Prolog-only runtime global: the Prolog runtime DEFINES no global but the
# frozen survivors below, and out/libscrip_rt.so EXPORTS no Prolog-prefixed symbol.
#
# THE LAW. RULES.md section THE PROLOG REBUILD GATE, clause 1: zero Prolog-only runtime globals, and `nm -D
# out/libscrip_rt.so` names no g_pl_* g_plw_* g_resolve_* g_rt_pl_* pl_wot_* symbol; clause 2: the atom table stays;
# no DESIGN section-10 structure (choice-point, environment, value, mark or exception stack, meta-rail) returns as a
# global -- its state lives in a FRAME CELL or the TRAIL.
#
# THE RULING (ceo CEO-1573, 2026-10-08, row prolog-test-gate-pl-no-new-global-reads-the-runtimes-own-definitions-not-
# the-lowerers-extern-references-or-the-preludes-string-literals-ceo-1573): the gate reads DEFINITIONS in the Prolog
# RUNTIME set and the library's exported names -- never a reference the lowerer makes to another stage's global (an
# extern inside a function is not a definition) and never a token inside a string literal (PL_PRELUDE_SRC names GNU's
# g_assign/g_read/g_array predicates as atoms). A compile-time global of the lowerer or the parser is policed by
# audit_second_stacks_census.py and audit_runtime_globals_census.py, not here. The old gate grepped every g_* token
# referenced in the lowerer, the parser and the templates and read red on 31 such names with no row carrying it.
#
# THE ARMS. (1) SOURCE: in the Prolog-only runtime files every C statement head that defines an object -- the first
# statement of a column-zero line (file scope under the 200-column layout, CEO-1565) and every static statement anywhere
# on a line (a one-line body keeps its function-local static after the brace) -- with string and character literals
# blanked and const objects skipped; in every other src/runtime file (by_name_dispatch.c among them, which every
# language shares) only the Prolog prefixes.
# (2) OBJECTS: the data symbols in writable sections (.data, .bss, their TLS twins, COMMON; never .rodata or
# .data.rel.ro) of the same files' objects (every src/runtime object on the prefixes) in the out/rt_pic-<tag> set that
# out/libscrip_rt.so was linked from -- exact
# where a source layout hides a definition (a multi-line struct initialiser, an asm macro). (3) EXPORTS: nm -D of the
# library, the law's own arm. (0) SELF-TEST, every run: a fixture plants g_pl_planted_depth at column zero, a static
# g_pl_planted_choice_stack inside a one-line body, and an object exporting g_pl_planted_export with a file-scope
# g_pl_planted_local, and a shared-file fixture plants g_pl_planted_shared beside a non-Prolog g_not_prolog_shared; each
# arm must name its plant and must not name a struct tag, an extern reference, a string literal, a const table or the
# shared file's non-Prolog global, or the gate refuses rc=2 (an instrument that cannot see a plant proves nothing by
# passing; one that over-reads cannot be trusted to fail).
#
# RED BEFORE (origin 4a505a88a): the old gate rc 1 on 31 names, none of them a Prolog runtime definition -- 27 references
# and 4 string-literal words. GREEN AFTER (cfo 2026-10-08): the self-test trips all three arms; the tree passes.
#
# Usage: bash ../harness/scripts/test_gate_pl_no_new_global.sh
set -uo pipefail
GATE_NAME=test_gate_pl_no_new_global
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
RT="$ROOT/out"
. "$HERE/lib_gate.sh"
gate_parse_args "$@"
for t in python3 nm objdump gcc; do command -v "$t" >/dev/null || { echo "⛔ REFUSED(2) [$GATE_NAME]: $t is not on PATH"; exit 2; }; done
[ -x "$ROOT/scrip" ] || { echo "⛔ REFUSED(2) [$GATE_NAME]: no scrip binary -- run make first"; exit 2; }
"$HERE/util_require_fresh.sh" --gate "$GATE_NAME" "$ROOT/scrip" "$RT/libscrip_rt.so" || exit 2
SO="$(readlink -f "$RT/libscrip_rt.so")"; TAG="${SO##*/libscrip_rt-}"; TAG="${TAG%.so}"; OBJ="$RT/rt_pic-$TAG"
[ -d "$OBJ" ] || { echo "⛔ REFUSED(2) [$GATE_NAME]: no object set $OBJ beside $SO -- run make"; exit 2; }
cd "$ROOT"
# ---- the Prolog runtime set ----------------------------------------------------------------------------------------
PL_SRC="src/runtime/unification.c src/runtime/arithmetic.c src/runtime/rt/rt_pl_trail.c src/runtime/rt/rt_pl_trail.h src/runtime/rt/prolog_atom.c src/runtime/rt/prolog_atom.h src/runtime/rt/pl_rational.h"
PL_OBJ="unification arithmetic rt_pl_trail prolog_atom rtx_plunify"
for f in $PL_SRC; do [ -f "$f" ] || { echo "⛔ REFUSED(2) [$GATE_NAME]: $f is gone -- re-cut the runtime set"; exit 2; }; done
for o in $PL_OBJ by_name_dispatch; do [ -f "$OBJ/$o.o" ] || { echo "⛔ REFUSED(2) [$GATE_NAME]: $OBJ/$o.o is gone -- re-cut the runtime set"; exit 2; }; done
# every other runtime file, source and object (an object's source is the first prerequisite in its .d sidecar), is
# policed on the Prolog prefixes only: the lowerer, the parser, the driver and the templates are other stages
SHARED_SRC="$(find src/runtime -type f \( -name '*.c' -o -name '*.h' -o -name '*.inc' \) | sort | grep -vxF -f <(tr ' ' '\n' <<< "$PL_SRC"))"
SHARED_OBJ=""
for d in "$OBJ"/*.d; do
    src="$(awk 'NR==1{l=$0; sub(/^[^:]*:[ \t]*/,"",l); if (l !~ /^\\?$/) {split(l,a," "); print a[1]; exit}} NR==2{split($0,a," "); print a[1]; exit}' "$d")"
    o="$(basename "$d" .d)"
    case "${src#$ROOT/}" in src/runtime/*) case " $PL_OBJ " in *" $o "*) ;; *) SHARED_OBJ="$SHARED_OBJ $OBJ/$o.o";; esac;; esac
done
case "$SHARED_OBJ" in *"/by_name_dispatch.o"*) ;; *) echo "⛔ REFUSED(2) [$GATE_NAME]: the .d sidecars under $OBJ name no src/runtime object -- the runtime set is unreadable"; exit 2;; esac
# ---- the frozen survivors: a name is added only with its reason, never for a section-10 structure -------------------
# The atom table (prolog_atom.c; RULES.md rebuild gate clause 2, "the atom table stays"): the interned names, their
# lengths and hash, the functor table and its hash, the operator columns, the five well-known atoms and './2'.
ALLOW_ATOMS="g_runtime"
# g_pl_flags (by_name_dispatch.c): the ISO flag store of current_prolog_flag/2 and set_prolog_flag/2, per-process
# configuration sanctioned by Lon's directive (PL-ISO-12), not a stack.
# rtx_gate_plunify (rtx_plunify.s): the leaf's RTX switch, set once at startup by rtx_init.c from SCRIP_RTX_PLUNIFY.
ALLOW="$ALLOW_ATOMS g_pl_flags rtx_gate_plunify"
PREFIX='^(g_pl_|g_plw_|g_resolve_|g_rt_pl_|pl_wot_)'
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
cat > "$T/defs.py" <<'PY'
import os, re, subprocess, sys
LIT = re.compile(r'"(?:[^"\\\n]|\\.)*"|\'(?:[^\'\\\n]|\\.)*\'')
QUAL = r'(?:(?:static|extern|const|volatile|_Thread_local|__thread|unsigned|signed|long|short|struct|union|enum)\s+)*'
HEAD = re.compile(r'^(?P<head>' + QUAL + r'[A-Za-z_]\w*(?:\s*\*+\s*|\s+)(?:const\s+)?(?:\*\s*(?:const\s+)?)*)(?P<name>[A-Za-z_]\w*)\s*(?:\[[^\]]*\]\s*)*(?:=.*)?$', re.S)
SKIP = re.compile(r'(extern|typedef|return|goto|case|else|sizeof|do|if|for|while|switch)\b')
WRITABLE = re.compile(r'^(\.data(?!\.rel\.ro)|\.bss|\.tdata|\.tbss|\*COM\*)')
prefix = re.compile(os.environ['PLG_PREFIX'])
allow = set(os.environ['PLG_ALLOW'].split())
def const_object(head):
    h = head.rstrip()
    return bool(re.search(r'\bconst\b', h)) if '*' not in h else bool(re.search(r'\*\s*const$', h))
def source(path, every):
    src = LIT.sub('""', open(path, encoding='utf-8', errors='replace').read())
    for n, line in enumerate(src.split('\n'), 1):
        for i, seg in enumerate(re.split(r'[{};]', line)):
            s = seg.strip()
            top = i == 0 and line[:1] not in (' ', '\t', '') and not line.startswith('#')
            if not s or SKIP.match(s) or not (top or re.match(r'(static|_Thread_local|__thread)\b', s)): continue
            m = HEAD.match(s)
            if not m or '(' in m.group('head') or m.group('head').split()[-1] in ('struct', 'union', 'enum') or const_object(m.group('head')): continue
            if every or prefix.match(m.group('name')): yield n, m.group('name')
def objects(path, every):
    for line in subprocess.run(['objdump', '-t', path], capture_output=True, text=True).stdout.split('\n'):
        f = line.split()
        if len(f) < 5 or 'O' not in f[1:3]: continue
        sect, name = f[f.index('O') + 1], re.sub(r'\.\d+$', '', f[-1])
        if WRITABLE.match(sect) and (every or prefix.match(name)): yield sect, name
def exports(path):
    for line in subprocess.run(['nm', '-D', '--defined-only', path], capture_output=True, text=True).stdout.split('\n'):
        f = line.split()
        if f and prefix.match(f[-1]): yield f[-1]
env = lambda k: os.environ.get(k, '').split()
for p in env('PLG_SRC_ALL') + env('PLG_SRC_PREFIX'):
    for n, name in source(p, p in env('PLG_SRC_ALL')):
        if name not in allow: print(f'source  {p}:{n}  {name}')
for p in env('PLG_OBJ_ALL') + env('PLG_OBJ_PREFIX'):
    for sect, name in objects(p, p in env('PLG_OBJ_ALL')):
        if name not in allow: print(f'object  {os.path.basename(p)} {sect}  {name}')
for p in env('PLG_SO'):
    for name in exports(p): print(f'export  {os.path.basename(p)}  {name}')
PY
run_defs() { PLG_SRC_ALL="$1" PLG_SRC_PREFIX="$2" PLG_OBJ_ALL="$3" PLG_OBJ_PREFIX="$4" PLG_SO="$5" PLG_ALLOW="$ALLOW" PLG_PREFIX="$PREFIX" python3 "$T/defs.py"; }
echo "=== PL no-new-global gate ==="
# ---- (0) the self-test: every arm names its plant -------------------------------------------------------------------
cp src/runtime/unification.c "$T/unification.c"
printf 'int g_pl_planted_depth;\nstatic int plc_planted(void) { static long g_pl_planted_choice_stack[64]; return (int)g_pl_planted_choice_stack[0]; }\n' >> "$T/unification.c"
printf 'struct g_pl_not_tag { int a; };\nstatic int plc_not_ref(void) { extern int g_pl_not_extern; return g_pl_not_extern; }\nstatic const char *plc_not_str(void) { return "g_pl_not_string"; }\nstatic const int g_pl_not_const[2] = { 1, 2 };\n' >> "$T/unification.c"
printf 'int g_pl_planted_export = 1;\nstatic int g_pl_planted_local[4];\nint *plc_planted_touch(void) { return g_pl_planted_local; }\n' > "$T/fx.c"
printf 'int g_not_prolog_shared;\nstatic int g_pl_planted_shared;\nint *plc_planted_shared(void) { return g_not_prolog_shared ? &g_pl_planted_shared : 0; }\n' > "$T/shared.c"
gcc -O0 -fPIC -c "$T/fx.c" -o "$T/fx.o" && gcc -O0 -fPIC -c "$T/shared.c" -o "$T/shared.o" && gcc -shared "$T/fx.o" -o "$T/fx.so" || { echo "⛔ REFUSED(2) [$GATE_NAME]: the self-test fixture did not build"; exit 2; }
run_defs "$T/unification.c" "$T/shared.c" "$T/fx.o" "$T/shared.o" "$T/fx.so" > "$T/plant.out"
for want in 'source .*g_pl_planted_depth$' 'source .*g_pl_planted_choice_stack$' 'object .*g_pl_planted_local$' 'object .*g_pl_planted_export$' 'export .*g_pl_planted_export$' 'source .*shared.c.* g_pl_planted_shared$' 'object shared.o .* g_pl_planted_shared$'; do
    grep -qE "^$want" <(sed -E 's/  +/ /g' "$T/plant.out") || { echo "⛔ REFUSED(2) [$GATE_NAME]: the self-test plant was not seen (/$want/) -- the instrument is blind"; sed 's/^/    /' "$T/plant.out"; exit 2; }
done
if grep -qE 'g_pl_not_|g_not_prolog_shared' "$T/plant.out"; then echo "⛔ REFUSED(2) [$GATE_NAME]: the self-test named a non-definition (a struct tag, an extern reference, a string literal, a const table) or a non-Prolog global of a shared file -- the instrument over-reads"; grep -E 'g_pl_not_|g_not_prolog_shared' "$T/plant.out" | sed 's/^/    /'; exit 2; fi
echo "  ok    self-test: each arm names its plant and none names a struct tag, an extern reference, a string literal, a const table or a shared file's non-Prolog global"
# ---- (1)-(3) the tree --------------------------------------------------------------------------------------------
objs_all=""; for o in $PL_OBJ; do objs_all="$objs_all $OBJ/$o.o"; done
run_defs "$PL_SRC" "$SHARED_SRC" "$objs_all" "$SHARED_OBJ" "$SO" > "$T/tree.out"
if [ -s "$T/tree.out" ]; then
    echo "  FAIL  a Prolog runtime global that is not a frozen survivor (arm, where, name):"; sed 's/^/        /' "$T/tree.out"
    echo "        Put the state in a FRAME CELL or the TRAIL (RULES.md, THE PROLOG REBUILD GATE). A survivor that is not a"
    echo "        section-10 structure joins ALLOW in this gate with its reason, in the landing that adds it."
    echo "⛔ GATE RED [$GATE_NAME]"; exit 1
fi
echo "  ok    $(echo $PL_SRC | wc -w) Prolog runtime sources and $(echo $PL_OBJ | wc -w) objects define no global but the $(echo $ALLOW | wc -w) frozen survivors; $(echo "$SHARED_SRC" | wc -w) other runtime sources and $(echo $SHARED_OBJ | wc -w) objects define no Prolog-prefixed one; nm -D exports none"
echo "✅ GATE PASS [$GATE_NAME]"; exit 0
