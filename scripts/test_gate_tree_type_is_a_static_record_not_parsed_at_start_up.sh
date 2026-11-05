#!/usr/bin/env bash
set -u
cd "$(dirname "$0")/../../SCRIP" || exit 1
../harness/scripts/util_require_fresh.sh --gate "$(basename "$0" .sh)" || exit $?
# test_gate_tree_type_is_a_static_record_not_parsed_at_start_up.sh -- THE RUNTIME'S PREDEFINED tree(t,v,n,c) DATA TYPE IS ONE STATIC DATBLK_t INSTALLED AT START-UP, NOT A SPEC STRING PARSED AND ALLOCATED BY
# DEFDAT_fn IN EVERY PROCESS (row icon-speed-the-empty-icon-program-starts-in-at-most-400000-user-instructions-ceo-2035; CTO-501 / CTO-510: a state record with static strings, installed while the type chain
# is empty so its next stays null and the collector never has to scan it; STATE-GLOBAL = the static tree record, its serial_next is the state).
# ⛔ THE MEASURED DEFECT: core_lib_init ran DEFDAT_fn("tree(t,v,n,c)") in every process of every language (a strtok pass over the spec, eight string duplications, a pointer vector, the name-index table): 4,198
# user instructions of the empty Icon program (hardware counter, skip-experiment 2026-11-04). The type is data the runtime already knows.
# THREE ARMS. STARTUP: the empty Icon program in mode 4, under gdb, makes NO DEFDAT_fn call whose spec starts "tree(" (one before). BEHAVIOURAL: two SNOBOL4 programs the oracle can answer (sbl -bf), one that
# declares DATA('tree(t,v,n,c)') itself twice (the second declaration must find the predefined record and add nothing) and one that redeclares tree with other fields and then declares another type, run in BOTH
# modes byte-equal to the oracle. COLLECTOR: the same two programs under SCRIP_GC_STRESS=1 in a 128 KB arena, both modes, still equal to the oracle (the static record sits in the type chain the collector walks).
# FAIL-ONCE: STARTUP is red on SCRIP 00580d758 (1 DEFDAT_fn("tree(t,v,n,c)") call). No plant anywhere in src/.
# Board line: TREE_STATIC_BOARD startup_tree_defdat=<n> t1_m3=<same|differs> t1_m4=<same|differs> t2_m3=<same|differs> t2_m4=<same|differs> stress=<ok|bad> (tree <hash>)
# rc 0 all arms green · rc 1 an arm red, named · rc 2 cannot measure (no gdb, no oracle, a program did not build).
NAME=tree_type_is_a_static_record_not_parsed_at_start_up
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(pwd)"
refuse() { echo "⛔ GATE REFUSE(2) [$NAME]: $*"; exit 2; }
. "$HERE/lib_oracle_flags.sh" || refuse "cannot source lib_oracle_flags.sh"
SBL="$(sbl_correctness_bin)" || refuse "no SNOBOL4 correctness oracle (lib_oracle_flags sbl_correctness_bin)"
command -v gdb >/dev/null 2>&1 || refuse "no gdb -- the STARTUP arm counts DEFDAT_fn calls"
[ -f "$ROOT/out/libscrip_rt.so" ] || refuse "out/libscrip_rt.so missing -- run make"
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
bad=0
printf 'procedure main();\nend\n' > "$W/e.icn"
cat > "$W/t1.sno" <<'EOS'
        DATA('tree(t,v,n,c)')
        T = tree('a', 'b', 'c', 'd')
        OUTPUT = t(T) v(T) n(T) c(T)
        DATA('tree(t,v,n,c)')
        U = tree(1, 2, 3, 4)
        OUTPUT = t(U) + v(U) + n(U) + c(U)
        OUTPUT = DATATYPE(T)
        t(T) = 'z'
        OUTPUT = t(T) v(T)
END
EOS
cat > "$W/t2.sno" <<'EOS'
        DATA('tree(left,right)')
        T = tree('l', 'r')
        OUTPUT = left(T) ' ' right(T)
        OUTPUT = DATATYPE(T)
        DATA('node(k)')
        N = node(5)
        OUTPUT = k(N)
        left(T) = 'm'
        OUTPUT = left(T)
END
EOS
build4() { ( cd "$W" && timeout -k 5 120 "$ROOT/scrip" --compile --out="$1.s" "$2" < /dev/null >/dev/null 2>&1 && gcc "$1.s" -o "$1" -L"$ROOT/out" -lscrip_rt -lm -lpthread -Wl,-rpath,"$ROOT/out" >/dev/null 2>&1 ); }
build4 e_icn e.icn || refuse "the empty Icon program did not build in mode 4"
cat > "$W/g.gdb" <<'EOS'
set pagination off
set confirm off
set breakpoint pending on
break DEFDAT_fn
commands
silent
printf "DEFDAT %s\n", (char *)$rdi
continue
end
run < /dev/null > /dev/null 2>&1
EOS
n=$( cd "$W" && timeout -k 5 200 gdb -q -batch -x g.gdb ./e_icn 2>&1 | grep -c '^DEFDAT tree(' )
[ "$n" = 0 ] || { bad=1; echo "  STARTUP RED: the empty Icon program parsed a tree(...) DATA spec through DEFDAT_fn $n time(s) at start-up"; }
res() { ( cd "$W" && "$@" 2>&1 ); }
for t in t1 t2; do
    ( cd "$W" && timeout -k 5 30 "$SBL" -bf "$t.sno" < /dev/null > "$t.ref" 2>&1 ) || true
    [ "$(wc -l < "$W/$t.ref")" -ge 4 ] || refuse "the oracle's answer to $t.sno is $(wc -l < "$W/$t.ref") lines -- the comparison would be nearly empty: $(head -c 120 "$W/$t.ref")"
    build4 "${t}_x" "$t.sno" || refuse "$t.sno did not build in mode 4"
done
t1m3=same; t1m4=same; t2m3=same; t2m4=same; stress=ok
for t in t1 t2; do
    ( cd "$W" && timeout -k 5 60 "$ROOT/scrip" "$t.sno" < /dev/null > "$t.m3" 2>&1 )
    ( cd "$W" && timeout -k 5 60 "./${t}_x" < /dev/null > "$t.m4" 2>&1 )
    cmp -s "$W/$t.ref" "$W/$t.m3" || { eval "${t}m3=differs"; bad=1; echo "  BEHAVIOURAL RED: $t.sno mode 3 differs from the oracle:"; diff -a "$W/$t.ref" "$W/$t.m3" | head -5; }
    cmp -s "$W/$t.ref" "$W/$t.m4" || { eval "${t}m4=differs"; bad=1; echo "  BEHAVIOURAL RED: $t.sno mode 4 differs from the oracle:"; diff -a "$W/$t.ref" "$W/$t.m4" | head -5; }
    ( cd "$W" && env SCRIP_HEAP_KB=128 SCRIP_GC_STRESS=1 timeout -k 5 120 "$ROOT/scrip" "$t.sno" < /dev/null > "$t.s3" 2>&1 )
    ( cd "$W" && env SCRIP_HEAP_KB=128 SCRIP_GC_STRESS=1 timeout -k 5 120 "./${t}_x" < /dev/null > "$t.s4" 2>&1 )
    cmp -s "$W/$t.ref" "$W/$t.s3" && cmp -s "$W/$t.ref" "$W/$t.s4" || { stress=bad; bad=1; echo "  COLLECTOR RED: $t.sno under SCRIP_GC_STRESS=1 differs from the oracle"; }
done
echo "TREE_STATIC_BOARD startup_tree_defdat=$n t1_m3=$t1m3 t1_m4=$t1m4 t2_m3=$t2m3 t2_m4=$t2m4 stress=$stress (tree $(git rev-parse --short HEAD))"
[ "$bad" = 0 ] && { echo "GATE OK [$NAME]: no tree spec is parsed at start-up and the oracle-answerable tree programs agree in both modes and under collector stress"; exit 0; }
echo "GATE FAIL [$NAME]"; exit 1
