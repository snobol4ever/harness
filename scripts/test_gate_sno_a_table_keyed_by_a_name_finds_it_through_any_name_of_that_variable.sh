#!/usr/bin/env bash
# test_gate_sno_a_table_keyed_by_a_name_finds_it_through_any_name_of_that_variable.sh -- a TABLE subscripted by a NAME finds the
# entry through any NAME of the same variable (.ABC, CONVERT('ABC','NAME'), evaluated again), as SPITBOL does: two NAMEs that IDENT
# calls the same are one table key.
#
# ⛔ THE DEFECT (hq_snobol4 2026-09-25; the IPC monitor bracket on aisnobol SIR, input cut to its first three sentences, with
# MONITOR_SKIP_VALUE_NAMES=MATCH1: step 82785, statement 1252 inside the library's GET -- spl continues to 1253, scr returns; at
# 1251 spl's LST is a list, scr's LST = ''). GET and PUT key the property-list table by CONVERT(UNAME,'NAME'). A NAME in its
# string form (slen 0, s = the variable's name) is freshly made at every evaluation, and the table hashed and compared DT_N by
# its raw pointer -- in C (aggregates.c's default arm) and in the rtx fast lookup (rtx_table.s table_find_pair_d hashed every type
# it did not list by pointer) -- so a NAME made by PUT was never found by the NAME GET made. THE CURE: DT_N hashes and compares as
# c_descr_identical does -- the string form by its characters, the cell form by pointer and form -- and the rtx lookup sends DT_N
# to the C path. SIR answers the oracle byte for byte after it.
#
# THE ARMS (expectations cut from sbl -bf AT RUN TIME):
#   1-2  m3 / m4: T<CONVERT('ABC','NAME')> is found through a second CONVERT, through .ABC and through ITEM
#   3    m3: T<.ABC> written and read with .ABC; a different name is a different key
#   4    m3: a STRING key 'ABC' and the NAME key .ABC are two keys, each found
# EXIT: 0 all arms pass · 1 an arm failed · 2 REFUSED (no binary, no oracle, the oracle's answer moved).
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
SCRIP="$ROOT/scrip"
RT_DIR="$ROOT/out"
NAME=sno_a_table_keyed_by_a_name_finds_it_through_any_name_of_that_variable
refuse() { echo "GATE REFUSE(2) [$NAME]: $*"; exit 2; }
[ -x "$SCRIP" ] || refuse "no scrip binary at $SCRIP -- cannot measure"
[ -f "$RT_DIR/libscrip_rt.so" ] || refuse "no $RT_DIR/libscrip_rt.so -- cannot measure mode 4"
. "$HERE/lib_oracle_flags.sh" 2>/dev/null || true
SBL="$(sbl_correctness_bin 2>/dev/null || true)"; [ -n "${SBL:-}" ] && [ -x "$SBL" ] || SBL=/home/resources/x64/bin/sbl
[ -x "$SBL" ] || refuse "no sbl oracle -- cannot measure (a missing oracle prints a full false table)"
T="$(mktemp -d)" || refuse "no tmpdir"
trap 'rm -rf "$T"' EXIT
cat > "$T/conv.sno" <<'EOF'
        T = TABLE()
        K1 = CONVERT('ABC', 'NAME')
        T[K1] = 'v1'
        K2 = CONVERT('ABC', 'NAME')
        OUTPUT = 'ident ' (IDENT(K1, K2) 'same', 'differ')
        OUTPUT = 'second convert [' T[K2] ']'
        OUTPUT = 'dot [' T[.ABC] ']'
        OUTPUT = 'item [' ITEM(T, K2) ']'
        T[.XYZ] = 'v2'
        OUTPUT = 'convert of a dot key [' T[CONVERT('XYZ','NAME')] ']'
END
EOF
cat > "$T/dot.sno" <<'EOF'
        T = TABLE()
        T[.ABC] = 'dotkey'
        OUTPUT = 'dot [' T[.ABC] '] other [' T[.ABD] ']'
END
EOF
cat > "$T/ctl.sno" <<'EOF'
        T = TABLE()
        T[.ABC] = 'name'
        T['ABC'] = 'string'
        OUTPUT = 'string [' T['ABC'] '] name [' T[.ABC] ']'
END
EOF
for w in conv dot ctl; do ( cd "$T" && timeout -k 5 10 "$SBL" -bf "$w.sno" < /dev/null > "$w.oracle" 2>&1 ) || refuse "sbl did not run $w cleanly"; done
grep -qx 'second convert \[v1\]' "$T/conv.oracle" && grep -qx 'string \[string\] name \[name\]' "$T/ctl.oracle" || refuse "sbl's answer moved: [$(cat "$T"/*.oracle | tr '\n' '|' | head -c 240)]"
fail=0; n=0
arm() { n=$((n+1)); if [ "$2" = ok ]; then echo "  ok   arm $n  $1"; else echo "  FAIL arm $n  $1 -- $2"; fail=1; fi; }
same() { [ "$1" = 0 ] || { echo "rc=$1"; return; }; cmp -s "$T/$2" "$T/$3" && echo ok || echo "got [$(tr '\n' '|' < "$T/$2" | head -c 110)] want [$(tr '\n' '|' < "$T/$3" | head -c 110)]"; }
m3() { ( cd "$T" && timeout -k 5 10 "$SCRIP" "$1.sno" < /dev/null > "$1.m3" 2>&1; echo $? ); }
rc=$(m3 conv); arm "m3: a NAME key is found through a second CONVERT, .ABC and ITEM" "$(same "$rc" conv.m3 conv.oracle)"
rc=$( cd "$T" && timeout -k 5 20 "$SCRIP" --compile --out=c.s conv.sno < /dev/null > /dev/null 2>&1 && gcc c.s -L"$RT_DIR" -lscrip_rt -Wl,-rpath,"$RT_DIR" -lm -o c.bin > /dev/null 2>&1 && timeout -k 5 10 ./c.bin < /dev/null > conv.m4 2>&1; echo $? )
arm "m4: a NAME key is found through a second CONVERT, .ABC and ITEM" "$(same "$rc" conv.m4 conv.oracle)"
rc=$(m3 dot); arm "m3: T<.ABC> read back with .ABC; another name is another key" "$(same "$rc" dot.m3 dot.oracle)"
rc=$(m3 ctl); arm "m3: a STRING key and the NAME key of one spelling are two keys, each found" "$(same "$rc" ctl.m3 ctl.oracle)"
[ "$fail" = 0 ] && { echo "PASS [$NAME]: $n arms"; exit 0; }
echo "FAIL [$NAME]"; exit 1
