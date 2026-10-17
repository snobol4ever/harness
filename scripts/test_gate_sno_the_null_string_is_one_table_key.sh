#!/usr/bin/env bash
# test_gate_sno_the_null_string_is_one_table_key.sh -- in a SNOBOL4 TABLE the null string is ONE key, however it was made: an unset
# variable, an omitted parameter, a function that returns null, the literal '', an empty assignment, TRIM of blanks, a replaced
# string -- T<> and T<U> reach the same entry. Icon's table keeps &null and "" apart, as its oracle does.
#
# ⛔ THE DEFECT (hq_snobol4 2026-09-25, gimpel MFREAD_driver under the monitor bracket: step 206 "DATA = READ_TBL<U>" with U an
# omitted parameter -- spl fetched the RDATA stored at READ_TBL<>, scr got the null string, and step 208 took the other branch).
# The runtime spells the null string two ways, DT_SNUL (NULVCL: unset names, omitted arguments, null returns) and a zero-length
# DT_S ('' and every string operation that yields nothing), and the shared table hashed and compared them as different keys --
# which is right for Icon, where DT_SNUL is &null, and wrong for SNOBOL4, which has one null string. THE CURE: TBBLK_t.null_one,
# set by the SNOBOL4 constructors (TABLE(), CONVERT(,'TABLE'), COPY of such a table); under it c_table_find_pair_d, table_delete_d and
# table_set_descr_d canonicalise a zero-length DT_S key to NULVCL, and rtx_table.s's lookup sends a zero-length string key to the C path.
#
# THE ARMS (expectations cut from the oracles AT RUN TIME):
#   1-2  SOURCES m3 / m4: nine null-string sources index one entry, both directions (T<> then read, and read what NEVERSET wrote)
#   3    OMITTED m3: a table read through an omitted parameter finds the T<> entry (the MFREAD shape)
#   4    ICON CONTROL: an Icon table keeps t[&null] and t[""] as two keys, as icont does
# EXIT: 0 all arms pass · 1 an arm failed · 2 REFUSED (no binary, no oracle, oracle shape moved).
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
SCRIP="$ROOT/scrip"
RT_DIR="$ROOT/out"
NAME=sno_the_null_string_is_one_table_key
refuse() { echo "GATE REFUSE(2) [$NAME]: $*"; exit 2; }
[ -x "$SCRIP" ] || refuse "no scrip binary at $SCRIP -- cannot measure"
[ -f "$RT_DIR/libscrip_rt.so" ] || refuse "no $RT_DIR/libscrip_rt.so -- cannot measure mode 4"
. "$HERE/lib_oracle_flags.sh" 2>/dev/null || true
SBL="$(sbl_correctness_bin 2>/dev/null || true)"; [ -n "${SBL:-}" ] && [ -x "$SBL" ] || SBL=/home/resources/x64/bin/sbl
[ -x "$SBL" ] || refuse "no sbl oracle -- cannot measure (a missing oracle prints a full false table)"
ICONT="$(icont_bin 2>/dev/null || true)"; [ -n "${ICONT:-}" ] && [ -x "$ICONT" ] || ICONT=/home/resources/icon-master/bin/icont
[ -x "$ICONT" ] || refuse "no icont oracle -- the ICON CONTROL arm cannot measure"
T="$(mktemp -d)" || refuse "no tmpdir"
trap 'rm -rf "$T"' EXIT
cat > "$T/sources.sno" <<'EOF'
        T = TABLE()
        T[] = 'x'
        OUTPUT = 'unset[' T[NEVERSET] ']'
        E =
        OUTPUT = 'empty-asgn[' T[E] ']'
        OUTPUT = 'lit[' T[''] ']'
        DEFINE('F(P,U)')                        :(FE)
F       F = T[U]                                :(RETURN)
FE      OUTPUT = 'omitted[' F('a') ']'
        DEFINE('G()')                           :(GE)
G                                               :(RETURN)
GE      OUTPUT = 'fn-null[' T[G()] ']'
        OUTPUT = 'trim[' T[TRIM('  ')] ']'
        S = 'ab'
        S LEN(2) =
        OUTPUT = 'repl[' T[S] ']'
        T2 = TABLE()
        T2[NEVERSET2] = 'y'
        OUTPUT = 'rev-lit[' T2[''] ']'
        OUTPUT = 'rev-empty[' T2[] ']'
END
EOF
cat > "$T/omitted.sno" <<'EOF'
        READ_TBL = TABLE()
        READ_TBL[] = 'stdin-entry'
        DEFINE('MF(P,U)D')                      :(MF_END)
MF      D = READ_TBL[U]
        MF = IDENT(D) 'MISSED'                  :S(RETURN)
        MF = D                                  :(RETURN)
MF_END  OUTPUT = MF('x')
END
EOF
printf '%s\n' 'procedure main();' '  t := table();' '  t[&null] := 1;' '  t[""] := 2;' '  write(t[&null], " ", t[""], " ", *t);' 'end' > "$T/ctl.icn"
for w in sources omitted; do ( cd "$T" && timeout -k 5 10 "$SBL" -bf "$w.sno" < /dev/null > "$w.oracle" 2>/dev/null ) || refuse "sbl did not run $w cleanly"; done
grep -q '^unset\[x\]$' "$T/sources.oracle" && grep -q '^rev-lit\[y\]$' "$T/sources.oracle" || refuse "sbl's SOURCES answer moved: [$(tr '\n' '|' < "$T/sources.oracle")]"
( cd "$T" && "$ICONT" -s -o ctl.x ctl.icn > /dev/null 2>&1 && ./ctl.x > ctl.oracle 2>/dev/null ) || refuse "icont did not run the control"
[ "$(cat "$T/ctl.oracle")" = "1 2 2" ] || refuse "icont's control answer moved: [$(cat "$T/ctl.oracle")]"
fail=0; n=0
arm() { n=$((n+1)); if [ "$2" = ok ]; then echo "  ok   arm $n  $1"; else echo "  FAIL arm $n  $1 -- $2"; fail=1; fi; }
same() { [ "$1" = 0 ] || { echo "rc=$1"; return; }; cmp -s "$T/$2" "$T/$3" && echo ok || echo "got [$(tr '\n' '|' < "$T/$2" | head -c 120)] want [$(tr '\n' '|' < "$T/$3" | head -c 120)]"; }
rc=$( cd "$T" && SCRIP_SNO_STMTKW=1 timeout -k 5 10 "$SCRIP" sources.sno < /dev/null > sources.m3 2>/dev/null; echo $? )
arm "SOURCES m3: nine null-string sources are one key" "$(same "$rc" sources.m3 sources.oracle)"
rc=$( cd "$T" && SCRIP_SNO_STMTKW=1 timeout -k 5 20 "$SCRIP" --compile -o s.s sources.sno < /dev/null > /dev/null 2>&1 && gcc s.s -L"$RT_DIR" -lscrip_rt -Wl,-rpath,"$RT_DIR" -lm -o s.bin > /dev/null 2>&1 && timeout -k 5 10 ./s.bin < /dev/null > sources.m4 2>/dev/null; echo $? )
arm "SOURCES m4: nine null-string sources are one key" "$(same "$rc" sources.m4 sources.oracle)"
rc=$( cd "$T" && SCRIP_SNO_STMTKW=1 timeout -k 5 10 "$SCRIP" omitted.sno < /dev/null > omitted.m3 2>/dev/null; echo $? )
arm "OMITTED m3: an omitted parameter reads the T<> entry" "$(same "$rc" omitted.m3 omitted.oracle)"
rc=$( cd "$T" && timeout -k 5 10 "$SCRIP" ctl.icn < /dev/null > ctl.scrip 2>/dev/null; echo $? )
arm "ICON CONTROL: t[&null] and t[\"\"] stay two keys" "$(same "$rc" ctl.scrip ctl.oracle)"
[ "$fail" = 0 ] && { echo "PASS [$NAME]: $n arms"; exit 0; }
echo "FAIL [$NAME]"; exit 1
