#!/usr/bin/env bash
# ⛔⭐ A USED MODULE KEEPS THE FILE-SCOPE VALUE ITS SUBS READ (row raku-every-suite-to-100-under-nonet-ceo-1266; hq_raku 2026-10-22 against SCRIP 218731c54 + the splice cure).
# THE DEFECT: `use XM` spliced only the module's DECLARATIONS (subs, classes, roles, grammars) into the program and dropped its top-level statements, so a module sub that read a
# file-scope `my $k = 5;` of its own file read a variable nobody assigned and the native emitter refused the whole program ("variable 'k' is read but never assigned and is not a
# parameter"): every Roast file that calls a Test::Util routine reading $VM-time-scale-multiplier (doesn't-hang) was a REJECT.
# THE CURE (rk_splice_modules, rk_syntax.c): the module's top-level declared assignments whose variable a spliced declaration reads (transitively, through the right sides) are
# spliced ahead of the declarations, so they run once at program start.
# PROVEN BY EXECUTION in mode 3 (--run) and mode 4 (--compile + link): a fixture module (a unit module with a file-scope scalar, a derived scalar, a plain sub, and a two-candidate
# multi) and a main program that uses it; the refs were cut by Rakudo 2026.05 (rakudo-local, -I lib) and are held here as text.
# ⭐ IT CAN FAIL, AND DID: GATE_SCRIP=<a scrip binary> GATE_RT=<its out dir> points the gate at another build (an instrument's own switch, never a seam in SCRIP); on the build
# before the cure (SCRIP 218731c54, a copy run with its own libscrip_rt.so) the program is refused and both modes read FAIL.
# EXIT 0 both modes match; 1 a mismatch or a refusal; 2 cannot measure (stale binary, no gcc).
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP -- this gate measures SCRIP and cannot from here"; exit 2; }
cd "$ROOT"
. "$HERE/lib_gate.sh"
GATE_NAME="raku_a_used_module_keeps_the_file_scope_value_its_subs_read"
gate_parse_args "$@"
BIN="${GATE_SCRIP:-$ROOT/scrip}"; RT="${GATE_RT:-$ROOT/out}"
[ -z "${GATE_SCRIP:-}" ] && gate_require_fresh "$ROOT" src "$ROOT/scrip" "$ROOT/out/libscrip_rt.so"
command -v gcc >/dev/null 2>&1 || { echo "⛔ REFUSE(rc=2) [$GATE_NAME]: gcc not found -- mode 4 cannot be linked, so half the population is unmeasured"; exit 2; }
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
mkdir -p "$W/lib"
cat > "$W/lib/XM.rakumod" <<'EOF'
unit module XM;
my $k = 5;
my $twice = $k * 2;
sub scaled($a) is export { $a * $k }
sub pair-up($a) is export { $a + $twice }
multi both(Int $a) is export { $a * $k }
multi both(Str $a) is export { $k }
EOF
cat > "$W/main.raku" <<'EOF'
use lib "lib";
use XM;
say scaled(3);
say pair-up(1);
say both(2);
say both("s");
EOF
printf '15\n11\n10\n5\n' > "$W/main.ref"
fails=0; GATE_EXAMINED=0
for m in m3 m4; do
    GATE_EXAMINED=$((GATE_EXAMINED + 1))
    if [ "$m" = m3 ]; then out="$(timeout -k 5 120 "$BIN" --run "$W/main.raku" 2>"$W/$m.err" </dev/null)"; rc=$?
    else
        if ! timeout -k 5 60 "$BIN" --compile --out="$W/main.s" "$W/main.raku" </dev/null >"$W/$m.err" 2>&1 \
           || ! gcc -o "$W/main.bin" "$W/main.s" -L"$RT" -lscrip_rt -Wl,-rpath,"$RT" -lm -lpthread >>"$W/$m.err" 2>&1; then
            printf '  FAIL main %s: did not build (%s)\n' "$m" "$(grep -m1 . "$W/$m.err" | cut -c1-120)"; fails=$((fails + 1)); continue; fi
        out="$(timeout -k 5 120 "$W/main.bin" 2>>"$W/$m.err" </dev/null)"; rc=$?
    fi
    if [ "$rc" -ne 0 ]; then printf '  FAIL main %s: rc=%s (%s)\n' "$m" "$rc" "$(grep -m1 . "$W/$m.err" | cut -c1-120)"; fails=$((fails + 1)); continue; fi
    if [ "$out" = "$(cat "$W/main.ref")" ]; then printf '  ok   main %s\n' "$m"
    else printf '  FAIL main %s: got [%s] want [%s]\n' "$m" "$(printf '%s' "$out" | tr '\n' ' ')" "$(tr '\n' ' ' < "$W/main.ref")"; fails=$((fails + 1)); fi
done
gate_verdict "$fails" "mode(s) wrong: a used module's subs lost the file-scope value they read"
