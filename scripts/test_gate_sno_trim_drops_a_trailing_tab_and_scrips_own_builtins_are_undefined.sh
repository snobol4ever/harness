#!/usr/bin/env bash
# test_gate_sno_trim_drops_a_trailing_tab_and_scrips_own_builtins_are_undefined.sh -- TRIM drops a trailing tab as well as blanks (and nothing else), and VALUE, UCASE and LCASE -- functions neither SPITBOL nor CSNOBOL4 has (SCRIP's own additions, no history before the import) -- are undefined: error 22 with &ERRTEXT 'undefined function called', in both modes, as SPITBOL answers it. A DATA field named VALUE still works as its accessor.
#
# # ⛔ THE DEFECTS (row snobol4-eight-run-time-errors-diag1-expects-are-not-raised; csnobol4_suite/diag1, Budne's standing red). Three of the four causes
#   that made diag1 differ from sbl -bf, all in the runtime's builtin namespace:
#   (A) TRIM stripped trailing BLANKS only (TRIM_fn in string_builtins.c and bn_trim in by_name_dispatch.c); SPITBOL's TRIM strips trailing
#       blanks and TABs and keeps CR, LF, VT and FF. diag1's self-test TRIM('abc' tab) reported an error SCRIP alone raised (statement 232).
#   (B) SCRIP registered VALUE, UCASE and LCASE as functions in the default dialect. Neither SPITBOL nor CSNOBOL4 has them as functions (UCASE and
#       LCASE exist only as the keywords &UCASE and &LCASE; read in the CSNOBOL4 source). diag1 calls VALUE('b') before its DATA statement and expects error 22 -- trapped by its SETEXIT,
#       which is where sbl's &ERRLIMIT 998, &ERRTYPE 22 and the handler's own second error come from. Nobody calls UCASE( or LCASE( anywhere in the
#       corpus. VALUE keeps ONE role: the accessor of a live DATA field of that name (Gimpel's stack and list libraries), so the by-name VALUE arm
#       now answers a live field and otherwise raises 22.
#   (C) the error-22 text was 'Undefined function called'; SPITBOL's is 'undefined function called' and &ERRTEXT is program-visible (diag1 dumps it).
#
#   CEO-1507 (Lon's CEO-1293 word stands): VALUE is restored as a function and no longer undefined; UCASE and LCASE stay deleted. VALUE's own gate is test_gate_sno_value_is_restored_and_diag1_test1_grade_under_ceo1293_rows.sh.
#
# THE ARMS (expectations cut from sbl -bf AT RUN TIME):
#   1-2  m3 / m4 TRIM: direct, through APPLY(.TRIM,...) and through a name; a tab, two tabs, blank-tab-blank dropped; a leading tab, CR, LF, VT, FF and an
#        inner blank kept                                                                                               -- RED on base
#   3-4  m3 / m4 UNDEFINED: UCASE, LCASE and their lower-case spellings (and lower-case value) each trap error 22 with the lower-case text  -- RED on base
#   5-6  CONTROL m3 / m4: a DATA field named VALUE is read and assigned through its accessor; LPAD, RPAD, REVERSE, REPLACE, DUPL and the
#        &UCASE and &LCASE keywords answer as before
# EXIT: 0 all arms pass · 1 an arm failed · 2 REFUSED (no binary, no oracle, no tmpdir, the oracle's answer moved).
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
SCRIP="$ROOT/scrip"
RT_DIR="$ROOT/out"
NAME=sno_trim_drops_a_trailing_tab_and_scrips_own_builtins_are_undefined
refuse() { echo "GATE REFUSE(2) [$NAME]: $*"; exit 2; }
[ -x "$SCRIP" ] || refuse "no scrip binary at $SCRIP -- cannot measure"
[ -f "$RT_DIR/libscrip_rt.so" ] || refuse "no $RT_DIR/libscrip_rt.so -- cannot measure mode 4"
. "$HERE/lib_oracle_flags.sh" 2>/dev/null || true
SBL="$(sbl_correctness_bin 2>/dev/null || true)"; [ -n "${SBL:-}" ] && [ -x "$SBL" ] || SBL=/home/resources/x64/bin/sbl
[ -x "$SBL" ] || refuse "no sbl oracle -- cannot measure (a missing oracle prints a full false table)"
T="$(mktemp -d)" || refuse "no tmpdir"
trap 'rm -rf "$T"' EXIT
cat > "$T/tr.sno" <<'EOF'
        T = 'abc' CHAR(9)
        OUTPUT = SIZE(TRIM(T)) ' direct tab'
        OUTPUT = SIZE(APPLY(.TRIM,T)) ' apply tab'
        OUTPUT = SIZE(TRIM('abc' CHAR(9) CHAR(9))) ' two tabs'
        OUTPUT = SIZE(TRIM('abc ' CHAR(9) ' ')) ' blank tab blank'
        OUTPUT = SIZE(TRIM(CHAR(9) 'abc')) ' leading tab kept'
        OUTPUT = SIZE(TRIM('abc' CHAR(13))) ' cr kept'
        OUTPUT = SIZE(TRIM('abc' CHAR(10))) ' lf kept'
        OUTPUT = SIZE(TRIM('abc' CHAR(11))) ' vt kept'
        OUTPUT = SIZE(TRIM('abc' CHAR(12))) ' ff kept'
        OUTPUT = SIZE(TRIM('a b' CHAR(9))) ' inner blank kept'
        F = .TRIM
        OUTPUT = SIZE(APPLY(F,T)) ' apply via name'
END
EOF
cat > "$T/un.sno" <<'EOF'
        &ERRLIMIT = 100
        SETEXIT('E')
        X = UCASE('abc')
        X = LCASE('ABC')
        X = value('abc')
        X = ucase('abc')
        X = lcase('ABC')
        OUTPUT = 'done'                        :(END)
E       OUTPUT = 'trapped ' &ERRTYPE ' [' &ERRTEXT ']'
        SETEXIT('E')                           :(CONTINUE)
END
EOF
cat > "$T/ct.sno" <<'EOF'
        DATA('CLUNK(VALUE,LSON)')
        C = CLUNK('hello','left')
        OUTPUT = VALUE(C) ' ' LSON(C)
        VALUE(C) = 'changed'
        OUTPUT = VALUE(C)
        OUTPUT = LPAD('ab',5,'.') RPAD('cd',5,'.') REVERSE('xyz')
        OUTPUT = REPLACE('abc','ab','xy') DUPL('-',3)
        OUTPUT = &UCASE &LCASE
END
EOF

want() { timeout -k 5 30 "$SBL" -bf "$T/$1.sno" < /dev/null > "$T/$1.want" 2>/dev/null; [ -s "$T/$1.want" ] || refuse "sbl -bf produced no output for $1 -- the oracle's answer moved"; }
want tr; want un; want ct
grep -q '^3 direct tab$' "$T/tr.want" && grep -q 'undefined function called' "$T/un.want" || refuse "sbl -bf no longer answers the TRIM tab and the undefined-function text as cut"
fail=0; pass=0
arm() { local n="$1" what="$2" got="$3" w="$4"
    if cmp -s "$w" "$got"; then pass=$((pass + 1)); echo "  arm $n PASS  $what"
    else fail=$((fail + 1)); echo "  arm $n FAIL  $what"; diff "$w" "$got" | head -8 | sed 's/^/      /'; fi; }
m3() { timeout -k 5 30 "$SCRIP" "$T/$1.sno" < /dev/null > "$T/$1.m3" 2>/dev/null; }
m4() { : > "$T/$1.m4"
       if timeout -k 5 120 "$SCRIP" --compile --out="$T/$1.s" "$T/$1.sno" < /dev/null > /dev/null 2>&1 \
          && gcc -no-pie "$T/$1.s" -L"$RT_DIR" -lscrip_rt -lm -Wl,-rpath,"$RT_DIR" -o "$T/$1.bin" 2>/dev/null
       then timeout -k 5 30 "$T/$1.bin" < /dev/null > "$T/$1.m4" 2>/dev/null; else echo COMPILE-FAILED > "$T/$1.m4"; fi; }
m3 tr; arm 1 "m3 TRIM strips trailing blanks and tabs, nothing else" "$T/tr.m3" "$T/tr.want"
m4 tr; arm 2 "m4 TRIM: the same" "$T/tr.m4" "$T/tr.want"
m3 un; arm 3 "m3 UCASE/LCASE and the lower-case value are undefined functions (error 22, lower-case text; VALUE is restored, CEO-1507)" "$T/un.m3" "$T/un.want"
m4 un; arm 4 "m4 undefined functions: the same" "$T/un.m4" "$T/un.want"
m3 ct; arm 5 "CONTROL m3: a DATA field VALUE, LPAD/RPAD/REVERSE/REPLACE/DUPL, &UCASE/&LCASE" "$T/ct.m3" "$T/ct.want"
m4 ct; arm 6 "CONTROL m4: the same" "$T/ct.m4" "$T/ct.want"
if [ "$fail" -eq 0 ]; then echo "GATE PASS(0) [$NAME]: $pass arms -- TRIM drops a trailing tab, UCASE/LCASE are undefined, both modes"; exit 0; fi
echo "GATE FAIL(1) [$NAME]: $fail of $((pass + fail)) arms red"; exit 1
