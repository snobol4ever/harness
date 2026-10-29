#!/usr/bin/env bash
# test_gate_sno_substr_indexes_bytes_as_the_pattern_cursor_does.sh -- SNOBOL4's SUBSTR indexes BYTES, as SPITBOL does everywhere and as
# SCRIP's own pattern cursor, SIZE, LEN, TAB, POS, BREAK, SPAN and ANY already do, so a cursor taken by @ on a non-ASCII subject indexes
# the same byte in SUBSTR; Raku's .substr keeps counting characters, as Rakudo does.
#
# ⛔ THE DEFECT (row snobol4-the-pattern-cursor-counts-bytes-but-substr-indexes-characters-..., CEO-1295 (ii), found by hq_snocone: 42
# of 66 non-ASCII .pl sources refused under parser_prolog.sc on the SCRIP arm): SUBSTR_fn (string_builtins.c) counted UTF-8 code
# points, and the SNOBOL4 doors (_SUBSTR_ in core.c, bn_substr in by_name_dispatch.c) called it, so s = 'éé:-x'; s ? 'éé' @c;
# SUBSTR(s, c + 1, 1) read x where sbl reads ':'. A census of 24 indexing probes (SIZE, SUBSTR, @, LEN, TAB, RTAB, POS, RPOS,
# BREAK, SPAN, ANY, NOTANY, REVERSE, LPAD, RPAD, DUPL, TRIM, REPLACE, LGT, CONVERT) against sbl -bf found SUBSTR the only one.
# THE CURE: SUBSTR_bytes_fn, the same bounds with bytes for code points; the two SNOBOL4-family doors call it. SUBSTR_fn stays for
# Raku's .substr method (by_name_dispatch.c), whose oracle counts characters.
#
# THE ARMS (expectations cut from sbl -bf and, for the Raku control, fixed from rakudo):
#   1-2  m3 / m4: the 24-probe census on 'éé:-x' and 'aé' equals sbl -bf                               -- RED on base (SUBSTR lines)
#   3    CONTROL m3 Raku: 'éé:-x'.substr(2, 1) is ':' and .substr(0, 2) is 'éé' (characters)
# EXIT: 0 all arms pass · 1 an arm failed · 2 REFUSED (no binary, no oracle, the oracle's answer moved).
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
SCRIP="$ROOT/scrip"
RT_DIR="$ROOT/out"
NAME=sno_substr_indexes_bytes_as_the_pattern_cursor_does
refuse() { echo "GATE REFUSE(2) [$NAME]: $*"; exit 2; }
[ -x "$SCRIP" ] || refuse "no scrip binary at $SCRIP -- cannot measure"
[ -f "$RT_DIR/libscrip_rt.so" ] || refuse "no $RT_DIR/libscrip_rt.so -- cannot measure mode 4"
. "$HERE/lib_oracle_flags.sh" 2>/dev/null || true
SBL="$(sbl_correctness_bin 2>/dev/null || true)"; [ -n "${SBL:-}" ] && [ -x "$SBL" ] || SBL=/home/resources/x64/bin/sbl
[ -x "$SBL" ] || refuse "no sbl oracle -- cannot measure (a missing oracle prints a full false table)"
T="$(mktemp -d)" || refuse "no tmpdir"
trap 'rm -rf "$T"' EXIT
cat > "$T/census.sno" <<'EOF'
          s = 'éé:-x'
          OUTPUT = 'size ' SIZE(s)
          OUTPUT = 'substr12 [' SUBSTR(s, 1, 2) ']'
          OUTPUT = 'substr5 [' SUBSTR(s, 5, 1) ']'
          s ? 'éé' @c
          OUTPUT = 'cursor ' c
          s ? LEN(2) . v
          OUTPUT = 'len2 [' v ']'
          s ? TAB(4) . v
          OUTPUT = 'tab4 [' v ']'
          s ? RTAB(1) . v
          OUTPUT = 'rtab1 [' v ']'
          s ? POS(4) REM . v
          OUTPUT = 'pos4 [' v ']'
          s ? RPOS(3) REM . v
          OUTPUT = 'rpos3 [' v ']'
          s ? BREAK(':') @c
          OUTPUT = 'break ' c
          s ? SPAN('é') . v @c
          OUTPUT = 'span [' v '] ' c
          s ? ANY('é') @c
          OUTPUT = 'any ' c
          s ? NOTANY(':') @c
          OUTPUT = 'notany ' c
          OUTPUT = 'reverse [' REVERSE('aé') ']'
          OUTPUT = 'lpad [' LPAD('é', 4, '*') ']'
          OUTPUT = 'rpad [' RPAD('é', 4, '*') ']'
          OUTPUT = 'dupl ' SIZE(DUPL('é', 3))
          OUTPUT = 'trim [' TRIM('é  ') ']'
          OUTPUT = 'replace [' REPLACE('aéb', 'ab', 'xy') ']'
          OUTPUT = 'lgt ' (LGT('é', 'z') 'yes', 'no')
          OUTPUT = 'integer ' SIZE(CONVERT(SIZE(s), 'STRING'))
          t = 'aé'
          OUTPUT = 'substr22 [' SUBSTR(t, 2, 2) ']'
          OUTPUT = 'substr21 size ' SIZE(SUBSTR(t, 2, 1))
END
EOF
printf '%s\n' 'my $s = "éé:-x";' 'say $s.substr(2, 1);' 'say $s.substr(0, 2);' > "$T/rk.raku"
( cd "$T" && timeout -k 5 20 "$SBL" -bf census.sno < /dev/null > census.oracle 2>&1 ) || refuse "sbl did not run the census cleanly"
grep -qx 'substr5 \[:\]' "$T/census.oracle" && grep -qx 'cursor 4' "$T/census.oracle" || refuse "sbl's answer moved: [$(tr '\n' '|' < "$T/census.oracle" | head -c 160)]"
fail=0; n=0
arm() { n=$((n+1)); if [ "$2" = ok ]; then echo "  ok   arm $n  $1"; else echo "  FAIL arm $n  $1 -- $2"; fail=1; fi; }
same() { [ "$1" = 0 ] || { echo "rc=$1"; return; }; cmp -s "$T/$2" "$T/$3" && echo ok || echo "$(diff "$T/$3" "$T/$2" | grep '^[<>]' | tr '\n' '|' | head -c 160)"; }
m3() { ( cd "$T" && timeout -k 5 20 "$SCRIP" "$1.sno" < /dev/null > "$1.m3" 2>&1; echo $? ); }
m4() { ( cd "$T" && timeout -k 5 30 "$SCRIP" --compile --out="$1.s" "$1.sno" < /dev/null > /dev/null 2>&1 && gcc "$1.s" -L"$RT_DIR" -lscrip_rt -Wl,-rpath,"$RT_DIR" -lm -o "$1.bin" > /dev/null 2>&1 && timeout -k 5 20 "./$1.bin" < /dev/null > "$1.m4" 2>&1; echo $? ); }
rc=$(m3 census); arm "m3: 24 indexing probes on a UTF-8 subject equal sbl -bf" "$(same "$rc" census.m3 census.oracle)"
rc=$(m4 census); arm "m4: 24 indexing probes on a UTF-8 subject equal sbl -bf" "$(same "$rc" census.m4 census.oracle)"
got=$(cd "$T" && timeout -k 5 20 "$SCRIP" rk.raku < /dev/null 2>&1 | tr '\n' '|')
arm "CONTROL m3 Raku: .substr counts characters, as rakudo does" "$([ "$got" = ":|éé|" ] && echo ok || echo "got [$got] want [:|éé|]")"
[ "$fail" = 0 ] && { echo "PASS [$NAME]: $n arms"; exit 0; }
echo "FAIL [$NAME]"; exit 1
