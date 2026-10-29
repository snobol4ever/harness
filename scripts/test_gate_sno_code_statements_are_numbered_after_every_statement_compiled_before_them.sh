#!/usr/bin/env bash
# test_gate_sno_code_statements_are_numbered_after_every_statement_compiled_before_them.sh -- a CODE() block's statements are numbered
# after every statement compiled before it (the program's, then each earlier block's), a block consuming its count plus one, as SPITBOL
# does; &STNO inside the block and the monitor's LABEL events carry those numbers, and the program's END keeps its own.
#
# ⛔ THE DEFECT (hq_snobol4 2026-09-25; the IPC monitor bracket on aisnobol SIR stopped at step 2453, spl "LABEL 806" against
# scr "LABEL 1", at the first call of a DEXP/CODE-built function). code_at based every block on max(the program count, &STNO) and
# never advanced, so a second block reused the first block's numbers; and the lowerer read the parser's :stno for the statement
# anchors, IR_STATEMENT_BEGIN/END and the statement hook without the fragment's base, so a CODE-built function reported statement 1.
# THE CURE (CEO-1271, Lon's grant, .github 8bf3d53a): g_sno_stmt_compiled (long, runtime_eval.c, read and advanced only by code_at,
# seeded from the program statement count the lowerer passes); every :stno reader in sno_build_graph adds stno_base (scx_t carries it);
# a runtime fragment no longer raises g_mon_max_stno, so the END label stays the program's.
#
# THE ARMS (expectations cut from sbl -bf AT RUN TIME):
#   1-2  TWO BLOCKS m3 / m4: an 8-statement program's first block is statement 9, a second block's two statements are 11 and 12
#   3    IN A FUNCTION m3: a block compiled by CODE() inside a function body numbers after the program
#   4    MONITOR: a DEXP-built function called from the program agrees with the SPITBOL fork event-for-event, END included
#   5    MONITOR: the two-block program agrees event-for-event
#   6    CONTROL: a program with no CODE() agrees event-for-event
# EXIT: 0 all arms pass · 1 an arm failed · 2 REFUSED (no binary, no oracle, oracle shape moved, the monitor could not measure).
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
SCRIP="$ROOT/scrip"
RT_DIR="$ROOT/out"
NAME=sno_code_statements_are_numbered_after_every_statement_compiled_before_them
refuse() { echo "GATE REFUSE(2) [$NAME]: $*"; exit 2; }
[ -x "$SCRIP" ] || refuse "no scrip binary at $SCRIP -- cannot measure"
[ -f "$RT_DIR/libscrip_rt.so" ] || refuse "no $RT_DIR/libscrip_rt.so -- cannot measure mode 4"
. "$HERE/lib_oracle_flags.sh" 2>/dev/null || true
SBL="$(sbl_correctness_bin 2>/dev/null || true)"; [ -n "${SBL:-}" ] && [ -x "$SBL" ] || SBL=/home/resources/x64/bin/sbl
[ -x "$SBL" ] || refuse "no sbl oracle -- cannot measure (a missing oracle prints a full false table)"
MON="$HERE/monitor_run.sh"; [ -f "$MON" ] || refuse "no monitor_run.sh -- the MONITOR arms cannot measure"
T="$(mktemp -d)" || refuse "no tmpdir"
trap 'rm -rf "$T"' EXIT
cat > "$T/two.sno" <<'EOF'
        CODE('LIST OUTPUT = "in:" &STNO :(RETURN)')
        CODE('L2 OUTPUT = "in2:" &STNO ; OUTPUT = "in2b:" &STNO :(RETURN)')
        DEFINE('LIST()')
        DEFINE('L2()')
        LIST()
        L2()
        OUTPUT = 'top:' &STNO
END
EOF
cat > "$T/infn.sno" <<'EOF'
        DEFINE('MK(S)')                         :(MK_END)
MK      CODE(S)                                 :(RETURN)
MK_END  MK('LIST OUTPUT = "in:" &STNO :(RETURN)')
        DEFINE('LIST()')
        LIST()
        OUTPUT = 'top:' &STNO
END
EOF
cat > "$T/dexp.sno" <<'EOF'
        DEFINE('DEXP(PROTO)NAME,ARGS')          :(DEXP_END)
DEXP    PROTO BREAK('(') . NAME BAL . ARGS =    :F(FRETURN)
        CODE(NAME ' ' NAME PROTO ' :S(RETURN)F(FRETURN) ; ') :F(FRETURN)
        DEFINE(NAME ARGS)                       :(RETURN)
DEXP_END
        DEXP('LIST(S1,S2) = S1 S2')
        OUTPUT = LIST('a','b')
END
EOF
cat > "$T/ctl.sno" <<'EOF'
        DEFINE('F(X)')                          :(F_END)
F       F = X X                                 :(RETURN)
F_END   OUTPUT = F('ab')
END
EOF
for w in two infn; do ( cd "$T" && timeout -k 5 10 "$SBL" -bf "$w.sno" < /dev/null > "$w.oracle" 2>/dev/null ) || refuse "sbl did not run $w cleanly"; done
[ "$(tr '\n' '|' < "$T/two.oracle")" = "in:9|in2:11|in2b:12|top:7|" ] || refuse "sbl's TWO BLOCKS answer moved: [$(tr '\n' '|' < "$T/two.oracle")]"
fail=0; n=0
arm() { n=$((n+1)); if [ "$2" = ok ]; then echo "  ok   arm $n  $1"; else echo "  FAIL arm $n  $1 -- $2"; fail=1; fi; }
same() { [ "$1" = 0 ] || { echo "rc=$1"; return; }; cmp -s "$T/$2" "$T/$3" && echo ok || echo "got [$(tr '\n' '|' < "$T/$2" | head -c 90)] want [$(tr '\n' '|' < "$T/$3" | head -c 90)]"; }
rc=$( cd "$T" && SCRIP_SNO_STMTKW=1 timeout -k 5 10 "$SCRIP" two.sno < /dev/null > two.m3 2>/dev/null; echo $? )
arm "TWO BLOCKS m3: statements 9, then 11 and 12" "$(same "$rc" two.m3 two.oracle)"
rc=$( cd "$T" && SCRIP_SNO_STMTKW=1 timeout -k 5 20 "$SCRIP" --compile --out=two.s two.sno < /dev/null > /dev/null 2>&1 && gcc two.s -L"$RT_DIR" -lscrip_rt -Wl,-rpath,"$RT_DIR" -lm -o two.bin > /dev/null 2>&1 && timeout -k 5 10 ./two.bin < /dev/null > two.m4 2>/dev/null; echo $? )
arm "TWO BLOCKS m4: statements 9, then 11 and 12" "$(same "$rc" two.m4 two.oracle)"
rc=$( cd "$T" && SCRIP_SNO_STMTKW=1 timeout -k 5 10 "$SCRIP" infn.sno < /dev/null > infn.m3 2>/dev/null; echo $? )
arm "IN A FUNCTION m3: a block compiled inside a function body numbers after the program" "$(same "$rc" infn.m3 infn.oracle)"
mon() { local out rc; out=$( cd "$T" && S4E_HOME="$(cd "$ROOT/.." && pwd)" SCRIP_SNO_STMTKW=1 timeout -k 5 200 bash "$MON" "$T/$1.sno" --oracle 2>&1 ); rc=$?
        [ "$rc" = 2 ] && refuse "the monitor could not measure $1: $(printf '%s\n' "$out" | grep -m1 REFUSE | cut -c1-140)"
        [ "$rc" = 0 ] && printf '%s\n' "$out" | grep -q 'AGREE: participants' && echo ok || echo "rc=$rc: $(printf '%s\n' "$out" | grep -aE '^\| \*\*>' | head -1 | cut -c1-150)"; }
arm "MONITOR: a DEXP-built function agrees with the SPITBOL fork, END included" "$(mon dexp)"
arm "MONITOR: the two-block program agrees" "$(mon two)"
arm "CONTROL: a program with no CODE() agrees" "$(mon ctl)"
[ "$fail" = 0 ] && { echo "PASS [$NAME]: $n arms"; exit 0; }
echo "FAIL [$NAME]"; exit 1
