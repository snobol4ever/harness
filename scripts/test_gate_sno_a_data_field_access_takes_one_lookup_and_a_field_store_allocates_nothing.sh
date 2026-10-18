#!/usr/bin/env bash
export S4E_ONE_RUNNER_FIXTURE="gate arm ${0##*/}: a runner invoked as an instrument fixture, not a board (CEO-523)"
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
# test_gate_sno_a_data_field_access_takes_one_lookup_and_a_field_store_allocates_nothing.sh -- THREE DATA PATHS TREEBANK PAID FOR
# (ceo 2026-09-25, CEO-1258; notebook section 18; 487,460 field reads, 83,988 field stores and 12,290 constructor calls per x256 run):
# (1) a field accessor call `n(x)` walked the type's field list with strcmp in rt_call_name_sn4 and then AGAIN byte by byte in
# dat_field_get -- since this landing a direct-mapped inline cache keyed by the call site's name pointer and the instance's type
# pointer, confirmed by one strcmp, returns the instance's cell (~50 Ir against ~190); (2) a field used as a VARIABLE (`n(x) = v`,
# `a(x)[i] = v`) allocated a name-trap cell AND a "type.field" name string on every use -- since this landing rt_field_var returns
# the field's own cell as a plain cell name when nothing watches names (no monitor, no trace, no debug), which rt_assign_var stores
# through in three instructions; the trap is still built when comm_var_active(); (3) every record constructor formatted
# "<type>__TWEAK", scanned the procedure table with strcmp and hashed the name to learn that no such hook exists -- since this
# landing the negative answer is cached per type name under a generation that moves whenever a procedure or a type is added or
# the procedure table is reset, so a hook defined later still fires.
# ARMS: (1) the DATA witness prints the oracle's lines in m3 and m4 (two types sharing a field name, a nested record, a field as
# the assignment target, .n(x) names assigned through $, a record inside an array and a table, an array inside a field, COPY,
# 2,000 field stores in a loop); (2) SCRIP-only: a <type>__TWEAK hook fires on every constructor call, including for a type whose
# hook is defined after the type's first constructor call ran (the cache is keyed by generation); (3) gdb counts rt_agg_alloc hits
# over 3,000 field stores: at most 200 (pre-cure: one per store); (4) gdb counts dat_field_get hits over 6,000 field reads: at
# most 100 (pre-cure: one per read -- the second walk; the cache's one strcmp is inside rt_call_name_sn4); (5) gdb counts
# rt_call_arr_impl hits over 3,002 record constructions: at most 100 (pre-cure: one per construction, ~5,000 Ir each -- since
# this landing rt_call_arr_bl_sn4 remembers a site the full path resolved to a positional DATA construction and constructs
# directly, the same dat_construct and the same TWEAK hook); (6) gdb counts c_rt_call_bid_sn4 hits over 1,501 PROTOTYPE and
# 1,501 ARRAY calls: at most 100 (pre-cure: one per call -- PROTOTYPE, ARRAY and SNO$WANTNM now have direct-table rows).
# FAIL_ONCE (recorded): the pre-cure runtime at bf9613327 read rt_agg_alloc hits 3,002, dat_field_get hits 6,002, rt_call_arr_impl hits 3,004 and
# c_rt_call_bid_sn4 hits 3,004; this tree reads 0, 0, 4 and 0.
# EXIT 0 all arms; 1 a red (named); 2 REFUSED (oracle, gdb or the build missing).
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
. "$HERE/lib_oracle_flags.sh"
SBL="$(sbl_correctness_bin)"; [ -x "$SBL" ] || { echo "REFUSED(2): correctness oracle missing ($SBL)"; exit 2; }
[ -x "$ROOT/scrip" ] && [ -f "$ROOT/out/libscrip_rt.so" ] || { echo "REFUSED(2): $ROOT/scrip or out/libscrip_rt.so not built"; exit 2; }
command -v gdb >/dev/null 2>&1 || { echo "REFUSED(2): gdb missing"; exit 2; }
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
cat > "$W/data.sno" <<'SNO'
        DATA('pair(n,a)')
        DATA('node(n,kids,size)')
        DATA('cell(a)')
        p = pair(3, 4)
        q = node(10, pair(1, 2), 2)
        c = cell('z')
        OUTPUT = n(p) ' ' a(p) ' ' n(q) ' ' size(q) ' ' n(kids(q)) ' ' a(kids(q)) ' ' a(c)
        n(p) = 30
        a(p) = a(p) + 1
        OUTPUT = n(p) ' ' a(p) ' ' DATATYPE(p) ' ' DATATYPE(q)
        r = .n(p)
        $r = 99
        OUTPUT = n(p) ' ' DATATYPE(r) ' ' $r
        s = .kids(q)
        $s = 'replaced'
        OUTPUT = kids(q) ' ' DATATYPE(kids(q)) ' ' IDENT(kids(q), 'replaced') 'same'
        kids(q) = pair(7, 8)
        n(kids(q)) = n(kids(q)) * 10
        OUTPUT = n(kids(q)) ' ' a(kids(q))
        arr = ARRAY(3)
        arr[2] = pair(5, 6)
        n(arr[2]) = n(arr[2]) + 100
        OUTPUT = n(arr[2]) ' ' a(arr[2])
        a(p) = ARRAY('0:2')
        a(p)[1] = 'in array'
        OUTPUT = a(p)[1] ' ' PROTOTYPE(a(p))
        t = TABLE()
        t['k'] = pair(11, 12)
        a(t['k']) = a(t['k']) - 2
        OUTPUT = n(t['k']) ' ' a(t['k'])
        i = 0
loop    n(p) = n(p) + 1
        v = v + n(p)
        i = LT(i, 2000) i + 1                           :S(loop)
        OUTPUT = n(p) ' ' v ' ' IDENT(n(p), 2099) 'ident'
        u = p
        n(u) = -1
        OUTPUT = n(p) ' ' IDENT(u, p) 'same-record'
        w = COPY(p)
        n(w) = 555
        OUTPUT = n(p) ' ' n(w) ' ' DIFFER(w, p) 'copies'
END
SNO
"$SBL" $(sbl_lang_flags) "$W/data.sno" < /dev/null > "$W/data.ref" 2>&1 || true
[ -s "$W/data.ref" ] || { echo "REFUSED(2): the oracle printed nothing for the witness"; exit 2; }
red=0
( cd "$W" && timeout -k 5 30 "$ROOT/scrip" data.sno < /dev/null > "$W/data.m3" 2>&1 ); cmp -s "$W/data.m3" "$W/data.ref" && echo "ok  (1) m3 = oracle over $(wc -l < "$W/data.ref") lines" || { echo "RED (1) m3 differs from the oracle:"; diff "$W/data.ref" "$W/data.m3" | head -6; red=1; }
( cd "$W" && "$ROOT/scrip" --compile -o "$W/data.s" data.sno < /dev/null > /dev/null 2>&1 && gcc "$W/data.s" -L"$ROOT/out" -lscrip_rt -lm -Wl,-rpath,"$ROOT/out" -o "$W/data.bin" 2>/dev/null ) || { echo "REFUSED(2): the witness did not build in mode 4"; exit 2; }
( cd "$W" && timeout -k 5 30 ./data.bin < /dev/null > "$W/data.m4" 2>&1 ); cmp -s "$W/data.m4" "$W/data.ref" && echo "ok  (1) m4 = oracle" || { echo "RED (1) m4 differs from the oracle:"; diff "$W/data.ref" "$W/data.m4" | head -6; red=1; }
cat > "$W/tweak.sno" <<'SNO'
        DATA('pair(n,a)')
        DEFINE('pair__TWEAK(self)')                     :(tw_end)
pair__TWEAK  fired = fired + 1
        n(self) = n(self) * 100                         :(RETURN)
tw_end
        p = pair(1, 2)
        q = pair(3, 4)
        OUTPUT = fired ' ' n(p) ' ' n(q)
        DATA('cell(v)')
        c = cell(7)
        OUTPUT = fired ' ' v(c)
        DEFINE('cell__TWEAK(self)')                     :(tw2_end)
cell__TWEAK  fired = fired + 10
        v(self) = v(self) + 1                           :(RETURN)
tw2_end
        d = cell(8)
        e = cell(9)
        OUTPUT = fired ' ' v(c) ' ' v(d) ' ' v(e)
END
SNO
( cd "$W" && timeout -k 5 30 "$ROOT/scrip" tweak.sno < /dev/null > "$W/tweak.m3" 2>&1 )
if [ "$(sed -n '1p' "$W/tweak.m3")" = "2 100 300" ] && [ "$(sed -n '3p' "$W/tweak.m3")" = "32 8 9 10" ]; then echo "ok  (2) the __TWEAK hook fires on every constructor call, a later-defined hook included (SCRIP-only arm)"
else echo "RED (2) the __TWEAK hook did not fire as before:"; head -3 "$W/tweak.m3"; red=1; fi
cat > "$W/store.sno" <<'SNO'
        DATA('pair(n,a)')
        p = pair(0, 0)
        i = 0
loop    n(p) = n(p) + 1
        a(p) = i
        i = LT(i, 1500) i + 1                           :S(loop)
        OUTPUT = n(p) ' ' a(p)
END
SNO
( cd "$W" && "$ROOT/scrip" --compile -o "$W/store.s" store.sno < /dev/null > /dev/null 2>&1 && gcc "$W/store.s" -L"$ROOT/out" -lscrip_rt -lm -Wl,-rpath,"$ROOT/out" -o "$W/store.bin" 2>/dev/null ) || { echo "REFUSED(2): the store twin did not build"; exit 2; }
( cd "$W" && timeout -k 5 30 ./store.bin < /dev/null > "$W/store.out" 2>&1 ); grep -q '^1501 1500$' "$W/store.out" || { echo "REFUSED(2): the store twin did not print 1501 1500: $(head -1 "$W/store.out")"; exit 2; }
hits=$( cd "$W" && timeout -k 5 300 gdb -q -batch -ex 'set breakpoint pending on' -ex 'break rt_agg_alloc' -ex 'ignore 1 100000000' -ex 'run < /dev/null > /dev/null 2>&1' -ex 'info breakpoints' ./store.bin 2>&1 | grep -o 'already hit [0-9]* time' | grep -o '[0-9]*' | head -1 ); hits=${hits:-0}
if [ "$hits" -le 200 ]; then echo "ok  (3) rt_agg_alloc hits=$hits <= 200 over 3,000 field stores: a field store allocates no trap"
else echo "RED (3) rt_agg_alloc hits=$hits > 200 over 3,000 field stores: a field used as a variable allocates a name trap again"; red=1; fi
cat > "$W/read.sno" <<'SNO'
        DATA('pair(n,a)')
        p = pair(7, 3)
        i = 0
loop    s = a(p) + n(p)
        i = LT(i, 3000) i + 1                           :S(loop)
        OUTPUT = s
END
SNO
( cd "$W" && "$ROOT/scrip" --compile -o "$W/read.s" read.sno < /dev/null > /dev/null 2>&1 && gcc "$W/read.s" -L"$ROOT/out" -lscrip_rt -lm -Wl,-rpath,"$ROOT/out" -o "$W/read.bin" 2>/dev/null ) || { echo "REFUSED(2): the read twin did not build"; exit 2; }
( cd "$W" && timeout -k 5 30 ./read.bin < /dev/null > "$W/read.out" 2>&1 ); grep -q '^10$' "$W/read.out" || { echo "REFUSED(2): the read twin did not print 10"; exit 2; }
walks=$( cd "$W" && timeout -k 5 300 gdb -q -batch -ex 'set breakpoint pending on' -ex 'break dat_field_get' -ex 'ignore 1 100000000' -ex 'run < /dev/null > /dev/null 2>&1' -ex 'info breakpoints' ./read.bin 2>&1 | grep -o 'already hit [0-9]* time' | grep -o '[0-9]*' | head -1 ); walks=${walks:-0}
if [ "$walks" -le 100 ]; then echo "ok  (4) dat_field_get hits=$walks <= 100 over 6,000 field reads: the inline cache answers a read without the second walk"
else echo "RED (4) dat_field_get hits=$walks > 100 over 6,000 field reads: a field read walks the field list twice again"; red=1; fi
cat > "$W/ctor.sno" <<'SNO'
        DATA('pair(n,a)')
        i = 0
loop    p = pair(i, i + 1)
        q = pair()
        i = LT(i, 1500) i + 1                           :S(loop)
        OUTPUT = n(p) ' ' a(p) ' ' DATATYPE(q) ' ' IDENT(n(q)) 'null'
END
SNO
( cd "$W" && "$ROOT/scrip" --compile -o "$W/ctor.s" ctor.sno < /dev/null > /dev/null 2>&1 && gcc "$W/ctor.s" -L"$ROOT/out" -lscrip_rt -lm -Wl,-rpath,"$ROOT/out" -o "$W/ctor.bin" 2>/dev/null ) || { echo "REFUSED(2): the constructor twin did not build"; exit 2; }
( cd "$W" && timeout -k 5 30 ./ctor.bin < /dev/null > "$W/ctor.out" 2>&1 ); grep -q '^1500 1501 pair null$' "$W/ctor.out" || { echo "REFUSED(2): the constructor twin did not print 1500 1501 pair null: $(head -1 "$W/ctor.out")"; exit 2; }
slow=$( cd "$W" && timeout -k 5 300 gdb -q -batch -ex 'set breakpoint pending on' -ex 'break rt_call_arr_impl' -ex 'ignore 1 100000000' -ex 'run < /dev/null > /dev/null 2>&1' -ex 'info breakpoints' ./ctor.bin 2>&1 | grep -o 'already hit [0-9]* time' | grep -o '[0-9]*' | head -1 ); slow=${slow:-0}
if [ "$slow" -le 100 ]; then echo "ok  (5) rt_call_arr_impl hits=$slow <= 100 over 3,002 record constructions: the constructor site constructs directly after its first call"
else echo "RED (5) rt_call_arr_impl hits=$slow > 100 over 3,002 record constructions: every constructor call walks the full by-name path again"; red=1; fi
cat > "$W/proto.sno" <<'SNO'
        a = ARRAY('0:3')
        i = 0
loop    s = PROTOTYPE(a)
        b = ARRAY('1:2')
        i = LT(i, 1500) i + 1                           :S(loop)
        OUTPUT = s ' ' PROTOTYPE(b)
END
SNO
( cd "$W" && "$ROOT/scrip" --compile -o "$W/proto.s" proto.sno < /dev/null > /dev/null 2>&1 && gcc "$W/proto.s" -L"$ROOT/out" -lscrip_rt -lm -Wl,-rpath,"$ROOT/out" -o "$W/proto.bin" 2>/dev/null ) || { echo "REFUSED(2): the prototype twin did not build"; exit 2; }
( cd "$W" && timeout -k 5 30 ./proto.bin < /dev/null > "$W/proto.out" 2>&1 ); grep -q '^0:3 1:2$' "$W/proto.out" || { echo "REFUSED(2): the prototype twin did not print 0:3 1:2: $(head -1 "$W/proto.out")"; exit 2; }
ctail=$( cd "$W" && timeout -k 5 300 gdb -q -batch -ex 'set breakpoint pending on' -ex 'break c_rt_call_bid_sn4' -ex 'ignore 1 100000000' -ex 'run < /dev/null > /dev/null 2>&1' -ex 'info breakpoints' ./proto.bin 2>&1 | grep -o 'already hit [0-9]* time' | grep -o '[0-9]*' | head -1 ); ctail=${ctail:-0}
if [ "$ctail" -le 100 ]; then echo "ok  (6) c_rt_call_bid_sn4 hits=$ctail <= 100 over 1,501 PROTOTYPE and 1,501 ARRAY calls: both take the direct table"
else echo "RED (6) c_rt_call_bid_sn4 hits=$ctail > 100 over 1,501 PROTOTYPE and 1,501 ARRAY calls: they fall to the C by-name path again"; red=1; fi
[ "$red" -eq 0 ] && { echo "GATE OK: a field access takes one lookup, a field store allocates nothing, a constructor site constructs directly, PROTOTYPE and ARRAY take the direct table, the hook still fires, and every shape answers the oracle"; exit 0; }
echo "GATE FAILED: see the RED lines above"; exit 1
