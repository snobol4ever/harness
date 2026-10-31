#!/usr/bin/env bash
# test_gate_raku_test_module_is_setting_raku.sh -- RAKU'S Test MODULE IS RAKU SOURCE IN THE SETTING, NOT C (ARCH-RAKU-TO-100.md section 1.2 (c) and
# section 6 step 0; CEO-2044/2045; the cao's row raku-ladder-step-1-the-setting-in-raku-the-loader-and-test-rakumod-as-its-first-file-ceo-2044).
#
# THE LAW: `use Test` loads SCRIP/src/parsers/raku/setting/Test.rakumod (Rakudo's lib/Test.rakumod, Artistic 2.0, adapted), embedded by
# util_gen_raku_setting.py as src/parsers/raku/raku_setting.inc and read by the module road (import_module in rk_syntax.c), which splices in only the
# routines a program reaches (autoload per name, as the Prolog prelude). The C Test arms are DELETED (CEO-2045: a deletion carries its re-expression):
# the parser's rename of plan/ok/is/... to __rk_test_* (rk_tree.c), the lowerer's subtest and throws-like cases (lower_raku.c), the __rk_test_ block of
# by_name_dispatch.c with its TAP state (g_runtime.tap).
#
# THE ARMS: (1) corpus/tests/raku/setting/test_module.raku in mode 3 and mode 4 prints rakudo 2026.05's TAP byte for byte (test_module.ref) and exits
# with its code (test_module.rc); (2) no `__rk_test_` name is left in rk_tree.c, lower_raku.c, by_name_dispatch.c or builtins.tsv; (3) raku_setting.inc
# matches a fresh generation from the setting sources; (4) the Raku smoke (test_smoke_raku.sh) is green.
# PROVEN RED ONCE: on origin 65dbbc9bd (the C arms) arm 1 reads red in both modes and arm 2 names every C site.
#
# EXIT: 0 every arm green; 1 an arm red (named); 2 REFUSED (stale binary, no gcc, a missing witness).
# Usage: bash ../harness/scripts/test_gate_raku_test_module_is_setting_raku.sh   (from SCRIP; ~10 s, no oracle at run time)
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP"; exit 2; }
CORPUS="$(cd "$HERE/../../corpus" && pwd)" || { echo "REFUSE(2): no corpus beside harness at $HERE/../../corpus"; exit 2; }
cd "$ROOT"
. "$HERE/lib_gate.sh"
GATE_NAME="raku_test_module_is_setting_raku"
gate_parse_args "$@"
gate_require_fresh "$ROOT" src "$ROOT/scrip" "$ROOT/out/libscrip_rt.so"
command -v gcc >/dev/null 2>&1 || { echo "⛔ REFUSE(rc=2) [$GATE_NAME]: gcc not found -- mode 4 cannot be linked"; exit 2; }
WIT="$CORPUS/tests/raku/setting/test_module"
for f in "$WIT.raku" "$WIT.ref" "$WIT.rc"; do [ -f "$f" ] || { echo "⛔ REFUSE(rc=2) [$GATE_NAME]: missing $f"; exit 2; }; done
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
red=0
want_rc="$(cat "$WIT.rc")"
cp "$WIT.raku" "$W/w.raku"
( cd "$W" && timeout 30 "$ROOT/scrip" w.raku > o3 2> e3 < /dev/null ); rc3=$?
if cmp -s "$WIT.ref" "$W/o3" && [ "$rc3" = "$want_rc" ]; then echo "  GREEN m3 witness (rc $rc3)"; else echo "  RED   m3 witness: rc $rc3 want $want_rc"; diff "$WIT.ref" "$W/o3" | head -12; red=1; fi
( cd "$W" && timeout 60 "$ROOT/scrip" --compile --out=w.s w.raku < /dev/null > /dev/null 2> c4 && gcc w.s -L "$ROOT/out" -lscrip_rt -lm -Wl,-rpath,"$ROOT/out" -o w4 2>> c4 ) || { echo "  RED   m4 witness: compile or link failed"; head -3 "$W/c4"; red=1; }
if [ -x "$W/w4" ]; then
    ( cd "$W" && timeout 30 ./w4 > o4 2> e4 < /dev/null ); rc4=$?
    if cmp -s "$WIT.ref" "$W/o4" && [ "$rc4" = "$want_rc" ]; then echo "  GREEN m4 witness (rc $rc4)"; else echo "  RED   m4 witness: rc $rc4 want $want_rc"; diff "$WIT.ref" "$W/o4" | head -12; red=1; fi
fi
left="$(grep -n '__rk_test_' src/parsers/raku/rk_tree.c src/lower/lower_raku.c src/runtime/by_name_dispatch.c "$HERE/builtins.tsv" 2>/dev/null)"
if [ -z "$left" ]; then echo "  GREEN no __rk_test_ C site is left"; else echo "  RED   C Test sites remain:"; echo "$left" | cut -c1-160 | head -10; red=1; fi
if python3 "$HERE/util_gen_raku_setting.py" --check > "$W/gen" 2>&1; then echo "  $(cat "$W/gen")"; else echo "  RED   $(cat "$W/gen")"; red=1; fi
bash "$HERE/test_smoke_raku.sh" > "$W/smoke" 2>&1; src=$?
if [ "$src" = 0 ]; then echo "  GREEN the Raku smoke"; else echo "  RED   the Raku smoke (rc $src)"; grep -E 'FAIL|REFUSED' "$W/smoke" | head -5; red=1; fi
if [ "$red" = 0 ]; then echo "GATE $GATE_NAME: GREEN"; exit 0; fi
echo "GATE $GATE_NAME: RED"; exit 1
