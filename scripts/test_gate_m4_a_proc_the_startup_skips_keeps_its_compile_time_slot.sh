#!/usr/bin/env bash
# test_gate_m4_a_proc_the_startup_skips_keeps_its_compile_time_slot.sh -- in mode 4 every procedure the binary registers at
# startup sits in the registry slot the compiler gave it, so an index baked into a deterministic call names the same procedure
# at run time (hq_icon, ceo CEO-1433 row snobol4-in-mode-4-a-snobol4-define-before-a-call-into-the-icon-section-runs-its-c-calls-
# on-a-misaligned-stack).
#
# FOUND on the infinite_snobol4 SCRIPtix demo (corpus 3fb0f7045): mode 4 died in glibc malloc on a co-expression thread with
# its stack at 8 mod 16. THE BRACKET: `create inf_walks()` in inf_batch reached rt_proc_call_open_det(73) and entered
# FN__inf_batch -- the compiler's registry had inf_walks at 73 with the SNOBOL4 DEFINE's `render` at 20, while module_init skips
# a dyn-scope procedure (DEFINE registers it when the statement runs), so the binary's slot 73 held inf_batch and every Icon
# procedure after `render` was off by one. THE CURE (src/driver/scrip.c, m4_proc_startup_skip + m4_emit_proc_slot_keep): a
# procedure module_init skips that precedes one it registers keeps its slot under an inert "\001<slot>NAME" entry -- the \001
# convention of UNLOAD's tombstone, never found by a name lookup -- so the slots agree; trailing skips reserve nothing.
# THE ARMS, the witness one SCRIPtix file (a SNOBOL4 DEFINE ahead of Icon generator procedures the SNOBOL4 section drives):
#   1 m3 prints the Icon result and the SNOBOL4 function's result   2 m4 prints the same (without the cure: ERROR 246, two
#   resolves to drive and drive recurses)   3 DETECTOR -- the m4 asm keeps f's slot   4 CONTROL -- a SNOBOL4 program whose
#   DEFINE trails every registered procedure reserves no slot, so single-language output does not move
# EXIT: 0 every arm passes · 1 an arm failed · 2 REFUSED (no binary, a toolchain failure).
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
SCRIP="$ROOT/scrip"; RT_DIR="$ROOT/out"; NAME=m4_a_proc_the_startup_skips_keeps_its_compile_time_slot
refuse() { echo "GATE REFUSE(2) [$NAME]: $*"; exit 2; }
[ -x "$SCRIP" ] || refuse "no scrip binary at $SCRIP"
[ -f "$RT_DIR/libscrip_rt.so" ] || refuse "no $RT_DIR/libscrip_rt.so"
T="$(mktemp -d)" || refuse "no tmpdir"; trap 'rm -rf "$T"' EXIT
cat > "$T/w.md" <<'EOF'
```SNOBOL4
        DEFINE('f(x)')                                          :(f_end)
f       f = x                                                   :(RETURN)
f_end
        OUTPUT = drive()
        OUTPUT = f('snobol4')
END
```

```Icon
procedure one()
    suspend "one" | "uno";
end
procedure two()
    suspend "two" | "dos";
end
procedure drive()
    local s, c;
    s := "";
    every s ||:= one() || two() || ";";
    c := create two();
    s ||:= @c || @c;
    return s;
end
```
EOF
printf "         DEFINE('g(x)')                 :(g_end)\ng        g = x x                        :(RETURN)\ng_end    OUTPUT = g('ab')\nEND\n" > "$T/c.sno"
WANT="onetwo;onedos;unotwo;unodos;twodos|snobol4|"
graded=0; fail=0
arm() { graded=$((graded+1)); if [ "$2" = "$3" ]; then echo "  PASS $1  [$2]"; else echo "  FAIL $1  want[$2] got[$3]"; fail=$((fail+1)); fi; }
M3="$(cd "$T" && timeout -k 5 20 "$SCRIP" w.md < /dev/null 2>&1 | tr '\n' '|')"
( cd "$T" && timeout -k 5 60 "$SCRIP" --compile w.md -o w.s > /dev/null 2>&1 && gcc -no-pie w.s -L"$RT_DIR" -lscrip_rt -lm -lpthread -Wl,-rpath,"$RT_DIR" -o w.bin > /dev/null 2>&1 ) || refuse "mode-4 build of the witness failed -- a toolchain failure, not a verdict"
M4="$(cd "$T" && timeout -k 5 20 ./w.bin < /dev/null 2>&1 | tr '\n' '|')"
( cd "$T" && timeout -k 5 60 "$SCRIP" --compile c.sno -o c.s > /dev/null 2>&1 ) || refuse "mode-4 compile of the control failed -- a toolchain failure, not a verdict"
arm "m3-runs-the-icon-generators-and-the-snobol4-function" "$WANT" "$M3"
arm "m4-runs-the-same" "$WANT" "$M4"
arm "detector-m4-keeps-the-define-slot" "kept" "$(grep -q '"\\001<slot>f"' "$T/w.s" && echo kept || echo missing)"
arm "control-a-trailing-define-reserves-nothing" "0" "$(grep -c '<slot>' "$T/c.s")"
echo "graded=$graded FAIL=$fail"
[ "$graded" = 4 ] || refuse "expected 4 arms, graded $graded"
if [ "$fail" -ne 0 ]; then echo "GATE FAIL(1) [$NAME]: $fail/$graded"; exit 1; fi
echo "GATE PASS(0) [$NAME]: $graded/$graded"; exit 0
