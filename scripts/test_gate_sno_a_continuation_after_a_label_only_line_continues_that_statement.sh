#!/usr/bin/env bash
export S4E_MINT_NO_CRITERION="gate fixture: the row under test exercises the bus, not work (CEO-1386)"
# test_gate_sno_a_continuation_after_a_label_only_line_continues_that_statement.sh -- a line holding only a label, followed by a
# continuation line ('+' or '.' in column 1), is ONE statement: the label labels the continued body, and &STNO and &STCOUNT count one.
#
# ⛔ THE DEFECT (hq_snobol4 2026-09-25, found walking aisnobol SIR under the monitor bracket at SPITCORE's GENSYM). The lexer's
# LABEL state ended a label-only line on its newline and LABEL_DONE always returned T_STMT_END, so the continuation began a SECOND,
# unlabeled statement: "GENSYM" / "+ GENSYM = 'GSYM' &STCOUNT" parsed as (STMT :lbl GENSYM) (STMT :eq ...). Every statement number
# after the first such pair drifted by one against SPITBOL, and &STCOUNT -- which SPITCORE uses to mint GENSYM and LAMBDA names --
# counted an extra statement per execution. The BODY state already joins continuations through {CONT} in {W}; LABEL had no rule.
# THE CURE: <LABEL>{CONT} ends the label and enters BODY_START, beating <LABEL>\n by longest match.
#
# THE ARMS (expectations cut from sbl -bf AT RUN TIME):
#   1  m3: the witness's &STCOUNT and &STNO readings and its '.'-continued statement answer the oracle
#   2  m4: the same
#   3  PARSE: --dump-ast gives the '+'-continued label ONE statement that carries both the label and the assignment
#   4  CONTROL: the same program with each label written on its body's line answers the oracle in m3
# EXIT: 0 all arms pass · 1 an arm failed · 2 REFUSED (no binary, no oracle, oracle shape moved).
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
SCRIP="$ROOT/scrip"
RT_DIR="$ROOT/out"
NAME=sno_a_continuation_after_a_label_only_line_continues_that_statement
refuse() { echo "GATE REFUSE(2) [$NAME]: $*"; exit 2; }
[ -x "$SCRIP" ] || refuse "no scrip binary at $SCRIP -- cannot measure"
[ -f "$RT_DIR/libscrip_rt.so" ] || refuse "no $RT_DIR/libscrip_rt.so -- cannot measure mode 4"
. "$HERE/lib_oracle_flags.sh" 2>/dev/null || true
SBL="$(sbl_correctness_bin 2>/dev/null || true)"; [ -n "${SBL:-}" ] && [ -x "$SBL" ] || SBL=/home/resources/x64/bin/sbl
[ -x "$SBL" ] || refuse "no sbl oracle -- cannot measure (a missing oracle prints a full false table)"
T="$(mktemp -d)" || refuse "no tmpdir"
trap 'rm -rf "$T"' EXIT
cat > "$T/w.sno" <<'EOF'
        DEFINE('G()')                   :(G_END)
G
+       G = 'gg' &STCOUNT               :(RETURN)
G_END
        OUTPUT = G()
        OUTPUT = &STNO
L1
.       OUTPUT = 'dot-continued'
END
EOF
cat > "$T/c.sno" <<'EOF'
        DEFINE('G()')                   :(G_END)
G       G = 'gg' &STCOUNT               :(RETURN)
G_END
        OUTPUT = G()
        OUTPUT = &STNO
L1      OUTPUT = 'dot-continued'
END
EOF
for w in w c; do ( cd "$T" && timeout -k 5 10 "$SBL" -bf "$w.sno" < /dev/null > "$w.oracle" 2>/dev/null ) || refuse "the oracle did not run $w cleanly"; done
[ "$(tr '\n' '|' < "$T/w.oracle")" = "gg4|5|dot-continued|" ] || refuse "the oracle's answer moved: [$(tr '\n' '|' < "$T/w.oracle")]"
fail=0; n=0
arm() { n=$((n+1)); if [ "$2" = ok ]; then echo "  ok   arm $n  $1"; else echo "  FAIL arm $n  $1 -- $2"; fail=1; fi; }
same() { [ "$1" = 0 ] || { echo "rc=$1"; return; }; cmp -s "$T/$2" "$T/$3" && echo ok || echo "got [$(tr '\n' '|' < "$T/$2" | head -c 80)] want [$(tr '\n' '|' < "$T/$3" | head -c 80)]"; }
rc=$( cd "$T" && SCRIP_SNO_STMTKW=1 timeout -k 5 10 "$SCRIP" w.sno < /dev/null > w.m3 2>/dev/null; echo $? )
arm "m3: &STCOUNT, &STNO and the '.'-continued statement answer the oracle" "$(same "$rc" w.m3 w.oracle)"
rc=$( cd "$T" && SCRIP_SNO_STMTKW=1 timeout -k 5 20 "$SCRIP" --compile --out=w.s w.sno < /dev/null > /dev/null 2>&1 && gcc w.s -L"$RT_DIR" -lscrip_rt -Wl,-rpath,"$RT_DIR" -lm -o w.bin > /dev/null 2>&1 && timeout -k 5 10 ./w.bin < /dev/null > w.m4 2>/dev/null; echo $? )
arm "m4: &STCOUNT, &STNO and the '.'-continued statement answer the oracle" "$(same "$rc" w.m4 w.oracle)"
ast=$( cd "$T" && timeout -k 5 10 "$SCRIP" --dump-ast w.sno < /dev/null 2>/dev/null )
arm "PARSE: the '+'-continued label is one statement carrying the label and the assignment" "$(printf '%s\n' "$ast" | grep -qE '^\(STMT :lbl G :eq :subj \(TT_VAR G\)' && ! printf '%s\n' "$ast" | grep -qE '^\(STMT :lbl G\)$' && echo ok || echo "dump-ast: $(printf '%s\n' "$ast" | grep -E ':lbl G[ )]' | head -2 | tr '\n' '|')")"
rc=$( cd "$T" && SCRIP_SNO_STMTKW=1 timeout -k 5 10 "$SCRIP" c.sno < /dev/null > c.m3 2>/dev/null; echo $? )
arm "CONTROL: labels on their bodies' lines answer the oracle" "$(same "$rc" c.m3 c.oracle)"
[ "$fail" = 0 ] && { echo "PASS [$NAME]: $n arms"; exit 0; }
echo "FAIL [$NAME]"; exit 1
