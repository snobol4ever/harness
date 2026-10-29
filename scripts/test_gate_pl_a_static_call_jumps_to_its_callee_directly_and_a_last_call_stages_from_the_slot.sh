#!/usr/bin/env bash
# test_gate_pl_a_static_call_jumps_to_its_callee_directly_and_a_last_call_stages_from_the_slot.sh -- A STATIC CALL NEVER GOES THROUGH THE REGISTRY RECORD.
# hq_prolog 2026-10-04, row prolog-bb-a-static-call-jumps-to-its-callee-directly-and-stages-its-last-call-block-by-compile-time-cell-classes-not-a-four-hop-loop-586-registry-loads
# (ARCH-PROLOG-C-OUT-OF-THE-BOX.md section 9). ARM 1: the 23 kernels' mode-4 text loads g_rt_gen_procs ZERO times -- a static callee (file-defined,
# a registered compile-time graph or the predicate's own key; never declared dynamic, never a packet) is entered by lea rax, [rip + FN__callee];
# jmp rax in the text and through its sealed alpha cell in the slab (x86_jmp_via_cell, both media), not by the record's three dependent loads;
# a dynamic or run-time-defined callee keeps the registry jump, so arm 1 counts a load only when its callee is NOT declared dynamic in the kernel's
# own source: the callee is read off the jump itself -- the record offset after the load is 8 + 128 * proc index (PROC_FN at +8, the stride rt.c
# asserts) and the index names its .Lgccode_<name>_<index> label (the cto's ruling 2026-10-11, CEO-1663: nand.pl's two loads are its tail and
# non-tail arms of one staged call to the dynamic state_/2, unchanged since before CEO-1632; corpus 0bc5934ce had grown the census from 23 to 42
# kernels and nand is the first with a dynamic predicate). ARM 1b, the fail-once: a registry jump to a STATIC proc planted into nand's text is
# counted, and the planted jump to state_/2 is not. ARMS 2-3: two swipl-cut witnesses in m3 AND m4, the behaviour the cure keeps:
# (2) a 300,000-deep last-call recursion with variable arguments in the default stack (the tail arm fires: the block staged from each
# variable's own slot, one hop fewer than through its name cell), a last call passing a head variable down two frames, a last call passing a
# local bound by the previous goal, two locals aliased by =/2 then passed (the decline road); (3) a static clause whose last call is a
# DYNAMIC predicate, extended by assertz and shrunk by retract between calls (the registry must be followed), and an asserted clause whose
# last call is a static predicate.
# (4) THE VAR-VAR LINK (the code review of ebbf79a70, 2026-10-04): A = B between two unbound locals writes a DT_PLVAR link into one slot, and the
# tail-safe check followed only DT_N names, so the link was copied into the block VERBATIM -- a pointer into the frame the last call released
# (t4 printed nothing where swipl prints 44; the 9-argument twin printed block[1]); the check now follows a bound link as the deref macro does,
# a chain beyond four hops declines the tail arm (t8), an unbound link of this frame declines (t11), a link to a structure copies it (t12);
# (5) assertz and retract on a file-defined static predicate raise permission_error in both modes -- the invariant that lets the text pin
# FN__callee at assembly time while the slab reads the alpha cell at run time; (6) the mode-3 static jump does not depend on the mode-4
# seal knob: SCRIP_M4_ALPHA_SEAL=0 answers as the default (it once silenced rt_proc_seal_alpha, the slab's only seal: error 22).
# RED BEFORE on origin ec631d327: arm 1 counts 586 loads (every call box, two arms each); on ebbf79a70 w_link prints |||44||1|7|| for
# 44|f(1)|hello|44|6|5|7|g(12)| in both modes and the knob-off arm reads error 22.
set -u
GATE_NAME=test_gate_pl_a_static_call_jumps_to_its_callee_directly_and_a_last_call_stages_from_the_slot
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${S4E_HOME:-$(cd "$HERE/../.." && pwd)}"
SCRIP="${SCRIP_BIN:-$HERE/../../SCRIP/scrip}"
RT="${RT_DIR:-$(dirname "$SCRIP")/out}"
refuse() { echo "⛔ REFUSED(2) [$GATE_NAME]: $*" >&2; exit 2; }
[ -x "$SCRIP" ] || refuse "no scrip binary at $SCRIP -- run make first"
[ -n "${SCRIP_BIN:-}" ] || "$HERE/util_require_fresh.sh" --gate "$GATE_NAME" "$SCRIP" "$RT/libscrip_rt.so" || exit 2
TMPD="$(mktemp -d)"; trap 'rm -rf "$TMPD"' EXIT
red=0
B="${S4E_CORPUS:-$ROOT/corpus}/benchmarks/prolog/bench"
mkdir -p "$TMPD/k"
for p in "$B"/*.pl; do
    k="$(basename "$p" .pl)"; [ -f "$B/$k.ref" ] || continue
    timeout -k 5 120 "$SCRIP" --compile --out="$TMPD/k/$k.s" "$p" </dev/null 2>/dev/null || refuse "$k.pl did not compile"
    cp "$p" "$TMPD/k/$k.pl"
done
regjumps() {   # $1 = dir of <k>.s + <k>.pl; prints "<kernels> <static loads> <exempt loads> <per-kernel list>", rc 2 when nothing measured
python3 - "$1" <<'PY'
import os, re, sys
d = sys.argv[1]; ks = sorted(f[:-2] for f in os.listdir(d) if f.endswith(".s") and os.path.exists(os.path.join(d, f[:-2] + ".pl")))
if not ks: sys.exit(2)
dec = lambda n: re.sub(r"\$([0-9A-F]{2})", lambda m: chr(int(m.group(1), 16)), n)
tot = ex = 0; per = []
for k in ks:
    s = open(os.path.join(d, k + ".s"), errors="replace").read().split("\n"); src = open(os.path.join(d, k + ".pl"), errors="replace").read()
    src = re.sub(r"%[^\n]*", "", src); dyn = set()
    for m in re.finditer(r":-\s*dynamic\b(.*?)\.(?:\s|$)", src, re.S):
        for n, a in re.findall(r"([a-z][A-Za-z0-9_]*|'[^']*')\s*/\s*(\d+)", m.group(1)): dyn.add("%s/%s" % (n.strip("'"), a))
    lab = {}
    for ln in s:
        m = re.match(r"^\.Lgccode_(.+)_(\d+):", ln)
        if m: lab[int(m.group(2))] = dec(m.group(1))
    c = 0
    for i, ln in enumerate(s):
        if "g_rt_gen_procs" not in ln: continue
        callee = None
        for nx in s[i + 1:i + 4]:
            m = re.search(r"\[rax \+ (\d+)\]", nx)
            if m and int(m.group(1)) > 0 and (int(m.group(1)) - 8) % 128 == 0: callee = lab.get((int(m.group(1)) - 8) // 128); break
        if callee in dyn: ex += 1
        else: c += 1
    tot += c
    if c: per.append("%s=%d" % (k, c))
print(len(ks), tot, ex, " ".join(per))
PY
}
read -r nk nst nex nper <<<"$(regjumps "$TMPD/k")" || true
[ -n "${nk:-}" ] && [ "${nk:-0}" -gt 0 ] || refuse "the registry-jump census measured no kernel under $B"
if [ "$nst" = 0 ]; then echo "  ok  arm 1: zero registry loads with a static callee in the mode-4 text of $nk kernels ($nex to a declared-dynamic callee kept)"
else echo "  RED arm 1: $nst registry load(s) with a static callee remain in the mode-4 text of $nk kernels: $nper"; red=$((red+1)); fi
mkdir -p "$TMPD/plant"; cp "$B/nand.pl" "$TMPD/plant/nand.pl" 2>/dev/null && cp "$TMPD/k/nand.s" "$TMPD/plant/nand.s" 2>/dev/null || refuse "the fail-once needs nand.pl, the census's one kernel with a dynamic predicate"
pst=$(grep -m1 -oE '^\.Lgccode_[a-z][A-Za-z0-9_]*\$2F[0-9]+_[0-9]+:' "$TMPD/plant/nand.s" | grep -v 'state_' | sed 's/.*_\([0-9]*\):$/\1/')
pdy=$(grep -m1 -oE '^\.Lgccode_state_\$2F2_[0-9]+:' "$TMPD/plant/nand.s" | sed 's/.*_\([0-9]*\):$/\1/')
[ -n "$pst" ] && [ -n "$pdy" ] || refuse "the fail-once found no static and dynamic proc label in nand's text"
read -r _ b0 e0 _ <<<"$(regjumps "$TMPD/plant")"
for idx in "$pst" "$pdy"; do printf '        mov rax, qword ptr [rip + g_rt_gen_procs@GOTPCREL]\n        mov rax, qword ptr [rax + 0]\n        mov rax, qword ptr [rax + %d];        jmp   rax\n' $((8 + 128 * idx)) >> "$TMPD/plant/nand.s"; done
read -r _ b1 e1 _ <<<"$(regjumps "$TMPD/plant")"
if [ "$b1" = $((b0 + 1)) ] && [ "$e1" = $((e0 + 1)) ]; then echo "  ok  arm 1b: a planted registry jump to static proc $pst is counted, the planted jump to state_/2 (proc $pdy) is kept"
else echo "  RED arm 1b: the planted jumps read static $b0 -> $b1 and dynamic $e0 -> $e1, want +1 each"; red=$((red+1)); fi
mkw() { cat > "$TMPD/$1.pl"; }
mkw w_lco <<'EOP'
cnt(0, A, A) :- !.
cnt(N, A, R) :- N1 is N - 1, A1 is A + N, cnt(N1, A1, R).
t(X) :- u(X).
u(Y) :- Y = done.
v(L) :- L = [a, b, c].
r(L, R) :- length(L, R).
w(R) :- v(L), r(L, R).
a(R) :- X = Y, b(X, Y, R).
b(P, Q, R) :- P = 1, R = Q.
main :- cnt(300000, 0, S), write(S), nl, t(V), write(V), nl, w(N), write(N), nl, a(Q), write(Q), nl.
:- initialization(main).
EOP
mkw w_link <<'EOP'
last(X, X).
last9(X, _, _, _, _, _, _, _, X).
lastb(X, Y, R) :- X = 7, R = Y.
t4(R) :- A = B, B = 44, last(A, R).
t5(R) :- A = B, B = f(1), last(A, R).
t6(R) :- A = B, B = hello, last(A, R).
t7(R) :- B = 44, A = B, last(A, R).
t8(R) :- A = B, B = C, C = D, D = E, E = F, F = 6, last(A, R).
t9(R) :- A = B, B = 5, last9(A, 1, 2, 3, 4, 5, 6, 7, R).
t11(R) :- A = B, lastb(A, B, R).
t12(R) :- A = B, B = g(C), C = 12, last(A, R).
main :- t4(R4), write(R4), nl, t5(R5), write(R5), nl, t6(R6), write(R6), nl, t7(R7), write(R7), nl, t8(R8), write(R8), nl, t9(R9), write(R9), nl, t11(R11), write(R11), nl, t12(R12), write(R12), nl.
:- initialization(main).
EOP
mkw w_perm <<'EOP'
cnt(0, A, A) :- !.
cnt(N, A, R) :- N1 is N - 1, A1 is A + N, cnt(N1, A1, R).
main :- catch(assertz(cnt(0, 0, 0)), error(E, _), (write(E), nl)), catch(retract(cnt(0, _, _)), error(E2, _), (write(E2), nl)), cnt(3, 0, S), write(S), nl.
:- initialization(main).
EOP
mkw w_dyn <<'EOP'
:- dynamic(d/1).
d(1).
s(X) :- d(X).
cnt(0, A, A) :- !.
cnt(N, A, R) :- N1 is N - 1, A1 is A + N, cnt(N1, A1, R).
main :- findall(X, s(X), L0), write(L0), nl, assertz(d(2)), findall(Y, s(Y), L1), write(L1), nl, assertz((e(Z) :- cnt(10, 0, Z))), e(V), write(V), nl, retract(d(1)), findall(W, s(W), L2), write(L2), nl.
:- initialization(main).
EOP
want_w_lco='45000150000
done
3
1'
want_w_link='44
f(1)
hello
44
6
5
7
g(12)'
want_w_perm='permission_error(modify,static_procedure,cnt/3)
permission_error(modify,static_procedure,cnt/3)
6'
want_w_dyn='[1]
[1,2]
55
[2]'
for w in w_lco w_link w_perm w_dyn; do
    eval "want=\$want_$w"
    for mode in m3 m4; do
        if [ "$mode" = m3 ]; then got="$(cd "$TMPD" && timeout -k 5 60 "$SCRIP" "$w.pl" </dev/null 2>"$TMPD/err")"; rc=$?
        else
            timeout -k 5 120 "$SCRIP" --compile --out="$TMPD/$w.s" "$TMPD/$w.pl" </dev/null 2>"$TMPD/err" || { echo "  RED $w $mode: the compile refused: $(head -c 160 "$TMPD/err")"; red=$((red+1)); continue; }
            gcc -m64 -no-pie "$TMPD/$w.s" -o "$TMPD/$w.bin" -L"$RT" -lscrip_rt -Wl,-rpath,"$RT" -lm 2>"$TMPD/err" || { echo "  RED $w $mode: the assembler or linker refused: $(grep -m1 -E 'Error|error' "$TMPD/err" | head -c 200)"; red=$((red+1)); continue; }
            got="$(cd "$TMPD" && timeout -k 5 60 "./$w.bin" </dev/null 2>"$TMPD/err")"; rc=$?
            rm -f "$TMPD/$w.s" "$TMPD/$w.bin"
        fi
        if [ "$rc" = 0 ] && [ "$got" = "$want" ]; then echo "  ok  $w $mode"
        else echo "  RED $w $mode: rc=$rc out=[$(printf '%s' "$got" | tr '\n' '|' | cut -c1-200)] err=[$(head -c 160 "$TMPD/err" | tr '\n' '|')] want [$(printf '%s' "$want" | tr '\n' '|' | cut -c1-120)]"; red=$((red+1)); fi
    done
done
got="$(cd "$TMPD" && SCRIP_M4_ALPHA_SEAL=0 timeout -k 5 60 "$SCRIP" w_lco.pl </dev/null 2>"$TMPD/err")"; rc=$?
if [ "$rc" = 0 ] && [ "$got" = "$want_w_lco" ]; then echo "  ok  w_lco m3 with the seal knob off"
else echo "  RED w_lco m3 with the seal knob off: rc=$rc out=[$(printf '%s' "$got" | tr '\n' '|' | cut -c1-120)] err=[$(head -c 160 "$TMPD/err" | tr '\n' '|')]"; red=$((red+1)); fi
[ "$red" = 0 ] || { echo "GATE FAIL [$GATE_NAME]: $red arm(s) red"; exit 1; }
echo "GATE PASS [$GATE_NAME]: no static call of the bench kernels goes through the registry record, the last-call witnesses (the slot road, the var-var link, the static-permission invariant, the dynamic road) answer swipl's text in both modes, and the slab's static jump needs no knob"
exit 0
