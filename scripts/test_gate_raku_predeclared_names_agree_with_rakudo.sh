#!/usr/bin/env bash
# test_gate_raku_predeclared_names_agree_with_rakudo.sh -- A NAME THE RUNTIME PROVIDES IS RESOLVED BY THE LOWERER, AND A USER'S OWN DEFINITION STILL WINS
# (row raku-every-suite-to-100-under-nonet-ceo-1266, Lon 2026-09-25: "use IPC sync-step monitor to crawl the test suites to 100%"; ceo CEO-1479).
#
# THE DEFECT, measured over Roast (1381 files that parse) with scrip --compile and nothing executed: only 629 compile, and 680 of the 746 refusals are
# ONE guard, graph_native_emittable_mode in src/driver/scrip.c ("variable X is read but never assigned and is not a parameter"). A large family of its names
# is not a user variable at all: Raku PREDECLARES them -- the Order enums Less Same More, Empty, the zero-argument terms now, time and rand, the Unicode
# constants pi tau and infinity, the dynamic variables $*PID $*PROGRAM $*PROGRAM-NAME $*CWD $*HOME $*TMPDIR $*USER $*EXECUTABLE %*ENV @*ARGS, $?FILE, and a
# bare die -- and nothing resolved them. THE CURE is one table in lower_raku.c (rk_predeclared) that lowers each to a call of the runtime provider __rk_pre(name)
# (by_name_dispatch.c rk_pre_value), NEVER over a class of that name, a user sub of that name or a name the table does not list; and a bareword that names a
# declared sub is a call with no arguments (Rakudo: `sub foo { 5 }; say foo` prints 5), which is what lets a user's own now, time or rand win.
# Measured after it: 699 of 1381 compile (70 files past the guard).
#
# THE WITNESSES, each graded in m3 (--run) and m4 (--compile + link) against a ref cut by Rakudo (/usr/bin/raku): names prints a boolean, a type or a constant
# for every provided name (so it is deterministic on any machine); shadow proves a user sub named now, time or rand, a user sub called as a bareword, one
# declared after its call, and a user-declared dynamic variable all keep their own meaning.
# FAILED ONCE, measured on SCRIP 523e3ce56: both witnesses are refused by the guard ([SMX] variable ... is read but never assigned) in both modes.
# NOT HERE, each its own mechanism with its own row: the OBJECT-valued names ($*OUT $*ERR $*IN need IO::Handle, $*KERNEL $*DISTRO $*VM need system objects,
# $/ and $! need a typed Match and exception objects, @_ and WhateverCode).
#
# EXIT: 0 both witnesses match in both modes; 1 a mismatch or a crash on a witness; 2 REFUSED (stale binary, no gcc).
# Usage: bash ../harness/scripts/test_gate_raku_predeclared_names_agree_with_rakudo.sh   (~3s, no oracle at run time, no network)
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
cd "$ROOT"
. "$HERE/lib_gate.sh"
GATE_NAME="raku_predeclared_names_agree_with_rakudo"
gate_parse_args "$@"
gate_require_fresh "$ROOT" src "$ROOT/scrip" "$ROOT/out/libscrip_rt.so"
command -v gcc >/dev/null 2>&1 || { echo "⛔ REFUSE(rc=2) [$GATE_NAME]: gcc not found -- mode 4 cannot be linked, so half the population is unmeasured"; exit 2; }
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
cat > "$W/names.raku" <<'EOF'
say π; say τ; say ∞; say -∞;
say Less; say Same; say More; say (Less == -1) ?? "y" !! "n";
say Empty.elems; my @a = Empty; say @a.elems;
say time > 1000000000; say time.WHAT;
my $t = now; say (now - $t) < 5; say (now - $t) >= 0;
my $r = rand; say $r >= 0; say $r < 1; say rand < 1;
say $*PID > 0; say $*PID.WHAT;
say $*PROGRAM-NAME.chars > 0; say $*PROGRAM.Str.chars > 0;
say $*CWD.Str.chars > 0; say $*HOME.Str.chars > 0; say $*TMPDIR.Str.chars > 0;
say %*ENV<HOME>.chars > 0; say %*ENV.elems > 0; say (%*ENV<NOPE_XYZ>:exists);
say @*ARGS.elems;
say $*EXECUTABLE.Str.chars > 0;
say $?LINE; say $?FILE.chars > 0;
my $rr = try { die; 5 }; say $rr.defined;
sub ff { die }; try { ff() }; say "caught";
EOF
printf '%s' '3.141592653589793
6.283185307179586
Inf
-Inf
Less
Same
More
y
0
0
True
(Int)
True
True
True
True
True
True
(Int)
True
True
True
True
True
True
True
False
0
True
13
True
False
caught
' > "$W/names.ref"
cat > "$W/shadow.raku" <<'EOF'
sub now { 42 }
sub time { 7 }
sub rand { 9 }
say now; say time; say rand;
sub foo($x = 1) { $x * 2 }
say foo; say foo(4);
my $y = foo; say $y + 1;
sub later-one { 11 }
say later-one;
my $*DYN = 3; say $*DYN;
EOF
printf '%s' '42
7
9
2
8
3
11
3
' > "$W/shadow.ref"
fails=0; GATE_EXAMINED=0
ck() {
    local w="$1" m="$2" out rc
    GATE_EXAMINED=$((GATE_EXAMINED + 1))
    if [ "$m" = m3 ]; then out="$(timeout -k 5 20 "$ROOT/scrip" --run "$W/$w.raku" 2>/dev/null </dev/null)"; rc=$?
    else
        if ! timeout -k 5 60 "$ROOT/scrip" --compile --out="$W/$w.s" "$W/$w.raku" </dev/null >"$W/$w.cerr" 2>&1 \
           || ! gcc -o "$W/$w.bin" "$W/$w.s" -L"$ROOT/out" -lscrip_rt -Wl,-rpath,"$ROOT/out" -lm -lpthread >>"$W/$w.cerr" 2>&1; then
            printf '  FAIL %-7s %s: did not build (%s)\n' "$w" "$m" "$(head -1 "$W/$w.cerr" | cut -c1-110)"; fails=$((fails + 1)); return; fi
        out="$(timeout -k 5 20 "$W/$w.bin" 2>/dev/null </dev/null)"; rc=$?
    fi
    if [ "$rc" -ge 124 ]; then printf '  FAIL %-7s %s: died rc=%s\n' "$w" "$m" "$rc"; fails=$((fails + 1)); return; fi
    if [ "$out" = "$(cat "$W/$w.ref")" ]; then printf '  ok   %-7s %s\n' "$w" "$m"
    else printf '  FAIL %-7s %s: got [%s] want [%s]\n' "$w" "$m" "$(printf '%s' "$out" | tr '\n' ' ' | cut -c1-110)" "$(tr '\n' ' ' < "$W/$w.ref" | cut -c1-110)"; fails=$((fails + 1)); fi
}
for w in names shadow; do for m in m3 m4; do ck "$w" "$m"; done; done
gate_verdict "$fails" "witness-mode pair(s) wrong: a predeclared name the lowerer does not resolve, or a user's own definition it hijacked"
