#!/usr/bin/env bash
export S4E_ONE_RUNNER_FIXTURE="gate arm ${0##*/}: a runner invoked as an instrument fixture, not a board (CEO-523)"
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
# test_gate_sno_a_field_function_call_takes_the_name_entry.sh -- A SNOBOL4 CALL BY AN UNKNOWN NAME (no bid, not a system function:
# a DATA field function, a DATA constructor, a DEFINE'd function whose entry is pending) goes through that name's CALLEE RECORD,
# baked at the site: a pure field to rt_call_fld_sn4, every other such name to rt_call_callee_sn4 (the bake, Lon 2026-09-29: "You
# should have no by-name lookup for FUNCTION CALLS."; CEO-1360/1362, layers 5-7). This supersedes the name entry of CEO-1249 (ceo
# 2026-09-24: rt_call_name_sn4 answering the field access by the name, treebank's by-name calls 85% field accessors): the name entry
# survives only as the leaves' own slow road and is emitted at NO site. SCRIP_SN4_DIRECT=0 is the control arm (every such site calls
# rt_call_arr_bl_sn4). THREE ARMS: (1) the .s of the witness carries the baked leaves for the field and constructor calls under the
# cure, NO rt_call_name_sn4 site, and neither under the control arm; (2) the witness -- two types sharing a field name, a nested record, a field function called on the wrong type
# (SPITBOL: statement failure), a field used as an rvalue inside a pattern, a constructor and a user function taking a record --
# prints the oracle's lines in m3 and m4 under both arms; (3) the assignment forms (f(x) = v and .f(x)) still go their own way.
# ⛔ A field function applied to the WRONG datatype is left out of the witness on purpose: SPITBOL raises ERROR 041 (fatal without
# &ERRLIMIT) where SCRIP fails the statement -- a pre-existing divergence on both arms, the row
# snobol4-a-field-function-on-the-wrong-datatype-is-error-41-not-a-statement-failure, not this gate's subject.
# EXIT 0 all arms; 1 a red (named); 2 REFUSED (oracle or binary missing).
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
. "$HERE/lib_oracle_flags.sh"
SBL="$(sbl_correctness_bin)"; [ -x "$SBL" ] || { echo "REFUSED(2): correctness oracle missing ($SBL)"; exit 2; }
[ -x "$ROOT/scrip" ] || { echo "REFUSED(2): $ROOT/scrip not built"; exit 2; }
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
cat > "$W/fld.sno" <<'SNO'
        DATA('pair(n,a)')
        DATA('node(n,kids,size)')
        DEFINE('total(p)')                      :(START)
total   total = n(p) + a(p)                     :(RETURN)
START   p = pair(3, 4)
        q = node(10, pair(1, 2), 2)
        OUTPUT = n(p) ' ' a(p) ' ' n(q) ' ' size(q) ' ' n(kids(q)) ' ' a(kids(q))
        OUTPUT = total(p) ' ' total(kids(q))
        n(p) = 30
        a(p) = a(p) + 1
        OUTPUT = n(p) ' ' a(p) ' ' total(p)
        s = 'xyz'
        s LEN(1) . first
        OUTPUT = first (n(q) . x) x
        r = .n(p)
        $r = 99
        OUTPUT = n(p) ' ' DATATYPE(p) ' ' DATATYPE(q)
        i = 0
loop    i = i + 1
        k = pair(i, i * 2)
        acc = acc + n(k) + a(k)
        LT(i, 500)                              :S(loop)
        OUTPUT = acc
END
SNO
red=0
"$SBL" $(sbl_lang_flags) "$W/fld.sno" < /dev/null > "$W/fld.ref" 2>&1 || true
[ -s "$W/fld.ref" ] || { echo "REFUSED(2): the oracle printed nothing for the witness"; exit 2; }
for arm in on off; do
    if [ "$arm" = on ]; then unset SCRIP_SN4_DIRECT; else export SCRIP_SN4_DIRECT=0; fi
    ( cd "$W" && "$ROOT/scrip" --compile -o "$W/fld_$arm.s" fld.sno < /dev/null > /dev/null 2>&1 ) || { echo "RED: fld.sno did not compile (arm $arm)"; red=1; continue; }
    nn=$(grep -c 'call *rt_call_name_sn4' "$W/fld_$arm.s"); nb=$(grep -cE 'call *(rt_call_fld_sn4|rt_call_callee_sn4)' "$W/fld_$arm.s")
    if [ "$arm" = on ]; then [ "$nb" -ge 10 ] && [ "$nn" -eq 0 ] && echo "ok  arm on: $nb baked callee-record sites, 0 name-entry sites" || { echo "RED arm on: baked callee-record sites=$nb (want >= 10), name-entry sites=$nn (want 0)"; red=1; }
    else [ "$nn" -eq 0 ] && [ "$nb" -eq 0 ] && echo "ok  arm off: 0 baked and 0 name-entry sites" || { echo "RED arm off: $nb baked and $nn name-entry sites under SCRIP_SN4_DIRECT=0"; red=1; }; fi
    ( cd "$W" && timeout -k 5 20 "$ROOT/scrip" fld.sno < /dev/null > "$W/fld.$arm.m3" 2>&1 ); cmp -s "$W/fld.$arm.m3" "$W/fld.ref" && echo "ok  m3 arm $arm = oracle" || { echo "RED m3 arm $arm differs from the oracle:"; diff "$W/fld.ref" "$W/fld.$arm.m3" | head -8; red=1; }
    if gcc "$W/fld_$arm.s" -L"$ROOT/out" -lscrip_rt -lm -Wl,-rpath,"$ROOT/out" -o "$W/fld_$arm.bin" 2>/dev/null; then
        ( cd "$W" && timeout -k 5 20 "./fld_$arm.bin" < /dev/null > "$W/fld.$arm.m4" 2>&1 ); cmp -s "$W/fld.$arm.m4" "$W/fld.ref" && echo "ok  m4 arm $arm = oracle" || { echo "RED m4 arm $arm differs from the oracle:"; diff "$W/fld.ref" "$W/fld.$arm.m4" | head -8; red=1; }
    else echo "RED m4 arm $arm did not link"; red=1; fi
done
unset SCRIP_SN4_DIRECT
[ "$red" -eq 0 ] && { echo "GATE OK: field function and constructor calls take their baked callee records with no name-entry site, the control arm restores the by-name path, and both arms match the oracle in both modes"; exit 0; }
echo "GATE FAILED: see the RED lines above"; exit 1
