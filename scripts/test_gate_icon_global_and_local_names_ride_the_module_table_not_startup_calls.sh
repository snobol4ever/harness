#!/usr/bin/env bash
set -u
cd "$(dirname "$0")/../../SCRIP" || exit 1
../harness/scripts/util_require_fresh.sh --gate "$(basename "$0" .sh)" || exit $?
# test_gate_icon_global_and_local_names_ride_the_module_table_not_startup_calls.sh -- AN ICON PROGRAM'S GLOBAL NAMES AND ITS PROCEDURES' PARAMETER, LOCAL AND OFFSET NAMES ARE STATIC DATA THE COMPILER EMITS AND
# ONE CALL INSTALLS BY POINTER, NOT ONE RUNTIME CALL PER NAME (row icon-the-startup-rebuilds-compile-time-tables-procedures-csets-globals-registered-by-c-calls-at-run-time-r-1969, slice 1).
# ⛔ THE MEASURED DEFECT: module_init called rt_icn_global_note once per global name (a LOWERER function, src/lower/lower_common.c, gset_add into g_lower.lc.icn_gnames, running inside every Icon process) and
# rt_proc_loc_add once per procedure with a name table, and gva_register noted every declared global again. The only reader of either table is display() and variable(), and RULES.md says every runtime table is
# built by lower. The compiler already held both, so it emits them as data: .Lstartup_gnames (a pointer array) and .Lstartup_icn_loc (48-byte rows), each behind a 32-byte arena block header (CT_MAGIC_BIG) so a
# later ct_grow copies it instead of aborting, and ONE call, rt_icn_tabs_install(names, n, rows, m), points the runtime's own vectors (g_lower.lc.icn_gnames.v, g_runtime.rt.proc_loc) at them. No new global, no
# exported symbol, no dynamic lookup beyond the one import the two removed calls had (measured on the empty Icon program 429,195 -> 428,489 and on tgrlink 661,990 -> 639,999 user instructions, equal-length RUNPATHs).
# THREE ARMS. STATIC: every Icon benchmark compiled in mode 4 has no call to rt_icn_global_note or rt_proc_loc_add, exactly ONE call to rt_icn_tabs_install (never one per name), and a CT_MAGIC_BIG header before
# each static array; the runtime library exports no rt_proc_loc_add; rt.c's gva_register no longer notes names. BEHAVIOURAL (goes red if the install does not run: display() then prints empty identifier lists):
# one program with globals, a record, parameters and locals runs display(2) from a callee and display(0) from main in BOTH modes, each byte-equal to the oracle (iconx 9.5.25a), and the oracle's own output must
# carry the lists it is compared on so an empty-equals-empty agreement cannot pass. FAIL-ONCE: the STATIC arm is red on SCRIP 5ac03c751 (205 global-note and 70 loc-add calls, no install over the 17 benchmarks).
# No plant anywhere in src/.
# Board line: ICON_MODULE_TABS_BOARD programs=<p> note_calls=<n> loc_add_calls=<n> installs=<i> headers=<h> lib_loc_add=<0|1> gva_notes=<0|1> m3=<same|differs> m4=<same|differs> lines=<l> (tree <hash>)
# rc 0 all arms green · rc 1 an arm red, named · rc 2 cannot measure (no oracle, no corpus benchmarks, a program did not compile, a witness did not build).
NAME=icon_global_and_local_names_ride_the_module_table_not_startup_calls
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(pwd)"
refuse() { echo "⛔ GATE REFUSE(2) [$NAME]: $*"; exit 2; }
. "$HERE/lib_oracle_flags.sh" || refuse "cannot source lib_oracle_flags.sh"
ICONT="$(icont_bin)" || refuse "no icont oracle (lib_oracle_flags icont_bin) -- a missing oracle prints a full, plausible, entirely false all-FAIL table"
ICONX="$(iconx_bin)" || refuse "no iconx oracle (lib_oracle_flags iconx_bin)"
[ -f "$ROOT/out/libscrip_rt.so" ] || refuse "out/libscrip_rt.so missing -- run make"
BENCH="$ROOT/../corpus/benchmarks/icon"
ls "$BENCH"/*.icn >/dev/null 2>&1 || refuse "no Icon benchmarks at $BENCH (a sparse corpus needs benchmarks/icon)"
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
bad=0; progs=0; note=0; locadd=0; installs=0; headers=0
MAGIC=$(printf '%d' 0x4354424c4f434b32)
for f in "$BENCH"/*.icn; do
    timeout -k 5 120 ./scrip --compile --out="$W/b.s" "$f" < /dev/null >/dev/null 2>&1 || refuse "$(basename "$f") did not compile in mode 4 -- the count would not cover the population"
    progs=$((progs + 1))
    n=$(grep -cE 'call[[:space:]]+(qword ptr \[rip \+ )?rt_icn_global_note\b' "$W/b.s"); note=$((note + n))
    n=$(grep -cE 'call[[:space:]]+(qword ptr \[rip \+ )?rt_proc_loc_add\b' "$W/b.s"); locadd=$((locadd + n))
    n=$(grep -cE 'call[[:space:]]+(qword ptr \[rip \+ )?rt_icn_tabs_install\b' "$W/b.s"); installs=$((installs + n))
    n=$(grep -cE "^[[:space:]]*\.quad[[:space:]]+$MAGIC\$" "$W/b.s"); headers=$((headers + n))
done
libloc=$(nm -D --defined-only "$ROOT/out/libscrip_rt.so" 2>/dev/null | grep -cE ' rt_proc_loc_add$')
gvan=0; awk '/^DESCR_t \*gva_register\(/{f=1} f&&/rt_icn_global_note/{c++} f&&/^}/{exit} END{exit c>0}' src/runtime/rt/rt.c || gvan=1
if [ "$note" -ne 0 ]; then echo "  STATIC RED: $note emitted call(s) to rt_icn_global_note over $progs Icon benchmarks -- the names must be the static .Lstartup_gnames table"; bad=1; fi
if [ "$locadd" -ne 0 ]; then echo "  STATIC RED: $locadd emitted call(s) to rt_proc_loc_add over $progs Icon benchmarks -- the rows must be the static .Lstartup_icn_loc array"; bad=1; fi
if [ "$installs" -ne "$progs" ]; then echo "  STATIC RED: $installs rt_icn_tabs_install call(s) over $progs Icon benchmarks -- want exactly one per program, never one per name"; bad=1; fi
if [ "$headers" -lt "$progs" ]; then echo "  STATIC RED: $headers arena block header(s) (CT_MAGIC_BIG) over $progs benchmarks -- a static array installed into a vector needs one so a later ct_grow copies it"; bad=1; fi
if [ "$libloc" -ne 0 ]; then echo "  STATIC RED: libscrip_rt.so still exports rt_proc_loc_add"; bad=1; fi
if [ "$gvan" -ne 0 ]; then echo "  STATIC RED: gva_register still calls rt_icn_global_note -- a lowerer function runs in every program's start-up"; bad=1; fi
cat > "$W/w.icn" <<'EOS'
global gi, gs, gl, gt
record pt(x, y)
procedure inner(a, b)
   local s, t;
   s := a || b;
   t := [a, b];
   display(2, &output);
   return s;
end
procedure main()
   local m, r;
   gi := 7;
   gs := "hello";
   gl := [3, [4, 5], pt(6, 7)];
   gt := table();
   gt["k"] := "v";
   m := 5;
   r := inner(1, "x");
   write("--", r, " ", image(variable("gi")));
   display(0, &output);
end
EOS
( cd "$W" && "$ICONT" -s -o oracle_bin w.icn >/dev/null 2>&1 ) || refuse "the oracle did not build the witness"
( cd "$W" && timeout -k 5 60 ./oracle_bin < /dev/null > oracle.out 2>&1 )
for k in "inner local identifiers:" "main local identifiers:" "global identifiers:" "   gi = 7" "   gt = table_1(1)" "   m = 5"; do
    grep -qF -- "$k" "$W/oracle.out" || refuse "the oracle's output lacks [$k]: the comparison would be empty against empty"
done
( cd "$W" && timeout -k 5 120 "$ROOT/scrip" w.icn < /dev/null > m3.out 2>&1 )
( cd "$W" && timeout -k 5 120 "$ROOT/scrip" --compile --out=w.s w.icn < /dev/null >/dev/null 2>&1 && gcc w.s -o w4 -L"$ROOT/out" -lscrip_rt -lm -lpthread -Wl,-rpath,"$ROOT/out" >/dev/null 2>&1 ) || refuse "the witness did not build in mode 4"
( cd "$W" && timeout -k 5 60 ./w4 < /dev/null > m4.out 2>&1 )
m3=same; m4=same
cmp -s "$W/oracle.out" "$W/m3.out" || { m3=differs; bad=1; echo "  BEHAVIOURAL RED: mode 3 differs from the oracle:"; diff "$W/oracle.out" "$W/m3.out" | head -8; }
cmp -s "$W/oracle.out" "$W/m4.out" || { m4=differs; bad=1; echo "  BEHAVIOURAL RED: mode 4 differs from the oracle (empty identifier lists mean the install did not run):"; diff "$W/oracle.out" "$W/m4.out" | head -8; }
lines=$(wc -l < "$W/m4.out")
echo "ICON_MODULE_TABS_BOARD programs=$progs note_calls=$note loc_add_calls=$locadd installs=$installs headers=$headers lib_loc_add=$libloc gva_notes=$gvan m3=$m3 m4=$m4 lines=$lines (tree $(git rev-parse --short HEAD))"
[ "$bad" = 0 ] && { echo "GATE OK [$NAME]: $progs benchmarks carry the tables as data and display() reads them in both modes"; exit 0; }
echo "GATE FAIL [$NAME]"; exit 1
