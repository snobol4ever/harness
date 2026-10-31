#!/usr/bin/env bash
# util_rtx_leaf_push_census.sh -- THE PUSH CENSUS OF THE ASM LEAVES, READ FROM THE ASSEMBLED OBJECTS, WITH THE C-ONLY EXEMPTION
# COMPUTED (row rtx-leaves-carry-no-register-veneer-an-asm-runtime-call-is-not-a-c-function; the cto 2026-10-07 on
# re-review-veneer-1b-closed: "the exemption is COMPUTED, never a hand list ... a planted emitted call to either must read red
# by name").
#
# WHY THE OBJECTS: the row's first census grepped `push rbx|rbp|r8..r15` in src/runtime/rtx/*.s, and went blind on 2026-10-08
# when the CFI row (SCRIP 83f810283) spelled every push RTX_PUSH(x) / RTX_PUSHS(x): it read 0 while rtx_alloc.s pushed nine
# callee-saved registers. It never saw the pushes inside RTX_CCALL and RTX_CTAIL either. This census assembles every
# src/runtime/rtx/*.s the way the rtcc-four gate does and reads `objdump -d` after cpp and gas, so a macro hides nothing.
#
# A BODY runs from a global function symbol to the next one in its object (an RTX_ENTRY inside an RTX_FUNC opens its own body).
# A PUSH counted is a push of rbx, rbp or r8 to r15. A body is EXEMPT only when BOTH hold, each computed every run:
#   (a) no emitted code calls it: no witness .s names it -- every committed corpus *.s artifact plus fresh mode-4 compiles of
#       the first two corpus/benchmarks programs of each of the seven languages (the no-veneer gate's witness set);
#   (b) no file under src/emitter or src/templates names it (the generated entry table src/runtime/rt_entry_table.inc, which names every registered entry,
#       lies outside both trees; mode 3 calls by a baked address the emitter must name).
# NEGATIVE-TESTED IN EVERY RUN, per exempt body: a witness with an emitted GOT call to it, and a template file naming it, read
# through the same matcher, must each name it (PUSH_PLANT), so it would be COUNTED; a plant that is not seen refuses rc 2.
#
# PRINTS  PUSH_BODY entry=E pushes=N regs=R verdict=COUNTED|EXEMPT          (every body with a push)
#         PUSH_CENSUS counted=N exempt=M bodies=K witnesses=W                 (counted is the DONE-WHEN's reading)
# EXIT    0 measured; 2 could not measure.
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../SCRIP" && pwd)"
CORPUS="$ROOT/../corpus"
[ -x "$ROOT/scrip" ] || { echo "REFUSED(2): scrip is not built"; exit 2; }
[ -d "$CORPUS/benchmarks" ] || { echo "REFUSED(2): no corpus/benchmarks beside this tree"; exit 2; }
command -v objdump >/dev/null 2>&1 || { echo "REFUSED(2): objdump is not installed"; exit 2; }
INCS="$(python3 - "$ROOT/Makefile" "$ROOT" <<'PY'
import re, sys
mk, root = sys.argv[1], sys.argv[2]
txt = open(mk, encoding='utf-8', errors='replace').read().replace('\\\n', ' ')
m = re.search(r'^RT_INCS\s*:=\s*(.*)$', txt, re.M)
if not m: sys.exit(1)
v = m.group(1).split('#')[0]
v = v.replace('$(SRC)', root + '/src').replace('$(RT)', root + '/src/runtime')
print(' '.join(t for t in v.split() if t.startswith('-I')))
PY
)"
[ -n "$INCS" ] || { echo "REFUSED(2): could not read RT_INCS out of the Makefile"; exit 2; }
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/obj" "$WORK/wit"
for s in "$ROOT"/src/runtime/rtx/*.s; do
    o="$WORK/obj/$(basename "$s" .s).o"
    gcc -w -fPIC $INCS -I"$ROOT/src/runtime/rtx" -x assembler-with-cpp -c "$s" -o "$o" 2>"$o.err" || { echo "REFUSED(2): $(basename "$s") does not assemble:"; head -3 "$o.err"; exit 2; }
done
n=0
for le in snobol4:sno icon:icn prolog:pl pascal:pas raku:raku snocone:sc rebus:reb; do
    l=${le%%:*}; e=${le#*:}
    for f in $(find "$CORPUS/benchmarks/$l" -type f -name "*.$e" | sort | head -2); do
        ( cd "$WORK/wit" && timeout -k 5 60 "$ROOT/scrip" --compile --out="$WORK/wit/w$n.s" "$f" < /dev/null > /dev/null 2>&1 ) && n=$((n+1))
    done
done
[ "$n" -ge 10 ] || { echo "REFUSED(2): only $n fresh witnesses compiled (floor 10)"; exit 2; }
find "$CORPUS" -type f -name '*.s' > "$WORK/committed.txt"
python3 - "$WORK" "$ROOT" <<'PY'
import os, re, subprocess, sys, glob
work, root = sys.argv[1], sys.argv[2]
PUSH = re.compile(r'^\s*[0-9a-f]+:\s+push\s+(rbx|rbp|r8|r9|r1[0-5])\s*$')
SYM = re.compile(r'^[0-9a-f]+ <([^>]+)>:\s*$')
bodies = {}
glob_syms = set()
for o in sorted(glob.glob(os.path.join(work, 'obj', '*.o'))):
    r = subprocess.run(['objdump', '-t', o], capture_output=True, text=True)
    if r.returncode: print('REFUSED(2): objdump -t %s failed' % o); sys.exit(2)
    for ln in r.stdout.split('\n'):
        f = ln.split()
        if len(f) >= 6 and f[1] == 'g' and 'F' in f[2:4]: glob_syms.add(f[-1])
    r = subprocess.run(['objdump', '-d', '-M', 'intel', '--no-show-raw-insn', o], capture_output=True, text=True)
    if r.returncode: print('REFUSED(2): objdump -d %s failed' % o); sys.exit(2)
    cur = None
    for ln in r.stdout.split('\n'):
        m = SYM.match(ln)
        if m:
            cur = m.group(1) if m.group(1) in glob_syms else cur
            bodies.setdefault(cur, [])
            continue
        m = PUSH.match(ln)
        if m and cur: bodies[cur].append(m.group(1))
if len(glob_syms) < 50: print('REFUSED(2): the objects define %d global functions (floor 50)' % len(glob_syms)); sys.exit(2)
pushed = {k: v for k, v in bodies.items() if v}
wits = sorted(glob.glob(os.path.join(work, 'wit', '*.s'))) + [p for p in open(os.path.join(work, 'committed.txt')).read().split('\n') if p]
srcs = []
for d in ('src/emitter', 'src/templates'):
    for dp, _, fs in os.walk(os.path.join(root, d)):
        srcs += [os.path.join(dp, f) for f in fs]
if len(srcs) < 10: print('REFUSED(2): only %d emitter and template files found' % len(srcs)); sys.exit(2)
def named(paths, names):
    nf = os.path.join(work, 'names.txt')
    open(nf, 'w').write('\n'.join(sorted(names)) + '\n')
    r = subprocess.run(['xargs', '-0', 'grep', '-hoFw', '-f', nf, '--'], input='\0'.join(paths), capture_output=True, text=True, errors='replace')
    if r.returncode not in (0, 1, 123): print('REFUSED(2): grep over %d files failed: %s' % (len(paths), r.stderr.strip()[:200])); sys.exit(2)
    return set(r.stdout.split()) & set(names)
ex = set(pushed) - named(wits, pushed) - named(srcs, pushed)
if ex:
    pw = os.path.join(work, 'plant_w.s')
    open(pw, 'w').write(''.join('\tcall qword ptr [rip + %s@GOTPCREL]\n' % k for k in sorted(ex)))
    ps = os.path.join(work, 'plant_t.cpp')
    open(ps, 'w').write(''.join('x86_call_rtx("%s");\n' % k for k in sorted(ex)))
    for plant, what in ((pw, 'an emitted call'), (ps, 'a template naming')):
        blind = ex - named([plant], ex)
        if blind: print('REFUSED(2): %s %s was not seen -- the exemption is blind' % (what, ', '.join(sorted(blind)))); sys.exit(2)
        print('PUSH_PLANT %s seen for %s: verdict COUNTED' % (what.replace(' ', '_'), ','.join(sorted(ex))))
counted = 0
for k in sorted(pushed):
    v = 'EXEMPT' if k in ex else 'COUNTED'
    if v == 'COUNTED': counted += len(pushed[k])
    print('PUSH_BODY entry=%s pushes=%d regs=%s verdict=%s' % (k, len(pushed[k]), ','.join(pushed[k]), v))
print('PUSH_CENSUS counted=%d exempt=%d bodies=%d witnesses=%d' % (counted, sum(len(pushed[k]) for k in ex), len(pushed), len(wits)))
PY
